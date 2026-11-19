; =====================================================================
;  sd.asm - (overlay, first 2K: fixed RAM) load a stage pack from the SD card
;  through the BennVenn DOS, the way 13 Ghosts / Dracula's Castle II /
;  Graves 'n' Gargoyles / Galahxy do it on the real machine:
;    (FB80) = sector buffer, HL -> '"NAME"', A = 1, CALL $5F00   open
;    (FB03) must be 1 and (FB05) must not be 1
;    A = 1, CALL $5F03   first 512-byte sector ; (FB80) = buffer, CALL $5F09 next
;  During the calls: the DOS's mapping (its low bank + upper bank 0), IM 1,
;  interrupts off (DI after every call), a 2K stack at $F000-$F7FF, and the
;  ROM/DOS system area $7800-$7BFF put back the way the DOS left it (the game
;  keeps its variables there, so they are parked in upper bank 0 meanwhile).
;  This code must sit below $B800: upper bank 1 is not mapped while it runs.
; =====================================================================
DOS_OPEN    equ $5F00
DOS_FIRST   equ $5F03
DOS_NEXT    equ $5F09
DOS_BUFPTR  equ $FB80
DOS_STAT1   equ $FB03
DOS_STAT2   equ $FB05
PK_MAGIC    equ 0           ; "B2"
PK_LEV      equ 2           ; level number
PK_ID       equ 3           ; build id (must match this program)
PK_LEN      equ 5           ; file length
PK_REC      equ 8           ; level record (LVSIZE bytes)

; sd_stage: A = level.  Returns when upper bank 0 holds that stage's pack.
sd_stage:
        ld b,a
        ld a,(packlv)
        cp b
        ret z                   ; already there (the title and demo reuse 1-1)
        ld a,b
        ld (sd_lv),a
.again: ld a,(sd_lv)
        call sd_name
        call sd_load
        jr c,.fail
        ; is it the right file, from this build?
        ld hl,PACK
        ld de,sd_hdr
        ld bc,8
        call bfetch
        ld a,(sd_hdr+PK_MAGIC)
        cp 'B'
        jr nz,.bad
        ld a,(sd_hdr+PK_MAGIC+1)
        cp '2'
        jr nz,.bad
        ld a,(sd_lv)
        ld b,a
        ld a,(sd_hdr+PK_LEV)
        cp b
        jr nz,.bad
        ld hl,(sd_hdr+PK_ID)
        ld de,BUILD_ID
        or a
        sbc hl,de
        jr nz,.bad
        ld a,(sd_lv)
        ld (packlv),a
        ret
.bad:   ld hl,t_sdold
        jr .msg
.fail:  ld hl,t_sderr
.msg:   ld a,$FF
        ld (packlv),a
        call sd_error
        jr .again

; sd_name: A = level 0..19 -> sd_fn = '"BIX2Lnn"'
sd_name:
        inc a
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,'0'+10
        ld (sd_fn+7),a
        ld a,b
        ld (sd_fn+6),a
        ret

; sd_load: read file sd_fn into PACK (upper bank 0).  C set if it failed.
sd_load:
        di
        ld (sd_sp),sp
        bank BK_UPPER
        ; park the game's $7800-$7BFF, give the DOS its system area back
        ld hl,$7800
        ld de,GAMESAVE
        ld bc,$400
        ldir
        ld hl,SYSSAVE
        ld de,$7800
        ld bc,$400
        ldir
        ld sp,DOS_SP
        im 1
        ld a,3
        ld (sd_try),a
.open:  ld a,(GAMESAVE+dosmap-$7800)   ; (our variables are parked)
        out (BANKPORT),a
        ld hl,SECBUF
        ld (DOS_BUFPTR),hl
        ld hl,sd_fn
        ld a,1
        call DOS_OPEN
        di
        ld a,(DOS_STAT1)
        cp 1
        jr nz,.retry
        ld a,(DOS_STAT2)
        cp 1
        jr nz,.opened
.retry: ld hl,sd_try
        dec (hl)
        jr nz,.open
        scf
        jr .out
.opened:
        ld a,1
        call DOS_FIRST
        di
        ld hl,PACK
        ld (sd_dst),hl
        ld hl,(SECBUF+PK_LEN)   ; file length from the header
        ld de,PACK_MAX+1
        or a
        sbc hl,de
        add hl,de
        jr c,.lok
        ld hl,PACK_MAX          ; (a bad header: don't run past the pack area)
.lok:   ld (sd_left),hl
.sec:   ld hl,(sd_left)
        ld bc,512
        or a
        sbc hl,bc
        jr nc,.full
        ld bc,(sd_left)         ; last, partial sector
        ld hl,0
.full:  ld (sd_left),hl
        ld hl,SECBUF
        ld de,(sd_dst)
        ldir
        ld (sd_dst),de
        ld hl,(sd_left)
        ld a,h
        or l
        jr z,.done
        ld hl,SECBUF
        ld (DOS_BUFPTR),hl
        call DOS_NEXT
        di
        jr .sec
.done:  or a
.out:   ; (flags carry the result)
        push af
        pop bc                  ; (not on the DOS stack after the switch)
        ld a,BK_UPPER
        out (BANKPORT),a
        ld hl,$7800             ; the DOS's system area as it is now
        ld de,SYSSAVE
        push bc
        ld bc,$400
        ldir
        ld hl,GAMESAVE          ; and the game's variables back
        ld de,$7800
        ld bc,$400
        ldir
        pop bc
        ld sp,(sd_sp)
        push bc
        im 2
        bank BK_HOME
        pop af
        ret

; sd_error: HL = message.  Shows it with the file name; SPACE / fire retries.
sd_error:
        push hl
        call flush_frame
        di
        ld a,LATBASE
        ld (LATCH),a
        ld a,$AA
        call vfill
        pop hl
        ld b,$10
        call vtext_c
        ld hl,sd_fn+1
        ld de,sd_show
        ld bc,7
        ldir
        ld hl,sd_show
        ld b,$1A
        call vtext_c
        ld hl,t_sdspc
        ld b,$28
        call vtext_c
        call wait_release
.w:     call any_key
        jr z,.w
        jp wait_release

sd_lv   db 0
sd_try  db 0
sd_sp   dw 0
sd_dst  dw 0
sd_left dw 0
sd_hdr  ds 8
sd_fn   db '"BIX2L01"',0
sd_show db "BIX2L01.DAT",0
t_sderr db "CAN'T READ SD FILE",0
t_sdold db "OLD SD FILE - COPY AGAIN",0
t_sdspc db "SPACE TO TRY AGAIN",0
sd_end:
        ASSERT sd_end <= $B800, "SD loader must stay in fixed RAM"
