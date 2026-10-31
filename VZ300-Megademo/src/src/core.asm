; =====================================================================
;  core.asm : startup, calibration, frame sync, SD streaming, music
; =====================================================================

; ---------------------------------------------------------------------
; variables (in code area, BSS-like)
; ---------------------------------------------------------------------
lines_per_frame: dw 312
sp_save:         dw STACKTOP
fs_low_count:    dw 0
fs_high_count:   dw 0
frame_count:     dw 0
hphase:          db 22          ; horizontal phase, 4T units (0..31)
kernel_pairs:    db 147         ; pairs of lines run by kernel each frame
sd_ok:           db 0
sd_sectors_read: dw 0
latch_shadow:    db M0

; ---------------------------------------------------------------------
; calibrate: measure the frame length in scanlines (silent, ~3 frames)
; ---------------------------------------------------------------------
calibrate:
        ld hl,LATCH
        call .edge
        call .measure
        call .measure           ; second measurement is the one we keep
        ld hl,(fs_high_count)
        ex de,hl
        push hl
        or a
        sbc hl,de
        ld (fs_low_count),hl
        pop de
        ; DE = iterations of 30T -> lines = DE*30/228 (rounded)
        ex de,hl                ; HL = count
        push hl
        ; multiply by 30: hl*32 - hl*2
        add hl,hl               ; *2
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *32
        or a
        sbc hl,bc               ; *30
        ld bc,114               ; + half a line for rounding
        add hl,bc
        ; divide by 228
        ld de,0
.div:   ld bc,228
        or a
        sbc hl,bc
        jr c,.dived
        inc de
        jr .div
.dived: pop hl
        ; sanity: accept 300..330 lines, else assume 312
        ex de,hl
        ld (lines_per_frame),hl
        ld bc,300
        or a
        sbc hl,bc
        jr c,.use312
        ld hl,(lines_per_frame)
        ld bc,331
        or a
        sbc hl,bc
        jr c,.okl
.use312:
        ld hl,312
        ld (lines_per_frame),hl
.okl:
        ; kernel pairs = (lines - 18) / 2
        ld hl,(lines_per_frame)
        ld bc,18
        or a
        sbc hl,bc
        srl h
        rr l
        ld a,l
        ld (kernel_pairs),a
        ret

.edge:  ; wait for FS rising edge
.e0:    bit 7,(hl)
        jr nz,.e0
.e1:    bit 7,(hl)
        jr z,.e1
        ret

.measure:                       ; from a rising edge to the next one, count 30T loops
        ld de,0
.m0:    inc de                  ; 6
        bit 7,(hl)              ; 12
        jr nz,.m0               ; 12   -> 30T while high
        ld (fs_high_count),de
.m1:    inc de
        bit 7,(hl)
        jr z,.m1                ; 30T while low
        ret

; ---------------------------------------------------------------------
; frame sync: wait for FS rising edge, then delay by hphase.
; Must be CALLed. Exits (RET) at a fixed T after the edge (+/-12T jitter).
; The fixed part is tuned so that the caller's first kernel line starts
; at edge + SYNC_BASE + 4*hphase.
; ---------------------------------------------------------------------
frame_sync:
        ld hl,LATCH
.s0:    bit 7,(hl)
        jr nz,.s0
.s1:    bit 7,(hl)
        jr z,.s1                ; edge detected here (exit 7T after test)
frame_sync_edge:
        ld a,(hphase)           ; 13
        and 31                  ; 7
        cpl                     ; 4
        add a,32+1              ; 7     a = 32 - hphase
        ld l,a                  ; 4
        ld h,0                  ; 7
        ld de,.slide            ; 10
        add hl,de               ; 11
        jp (hl)                 ; 4
.slide:
        DUP 32
        nop
        EDUP
        ret                     ; 10

; ---------------------------------------------------------------------
; SD streaming from the demo's single data file
; ---------------------------------------------------------------------
        INCLUDE "../build/datname.inc"

sd_open:
        ld hl,SCRATCH           ; as 13 Ghosts does: DOS copy target set before OpenFile
        ld (DOSDEST),hl
        ld hl,datname
        ld a,1
        call DOSOPEN
        di
        ld a,($FB03)
        cp 1
        jr nz,.fail
        ld a,($FB05)
        cp 1
        jr z,.fail
        ld a,1
        ld (sd_ok),a
        ld hl,0
        ld (sd_sectors_read),hl
        or a
        ret
.fail:  xor a
        ld (sd_ok),a
        scf
        ret

; sd_read: HL = destination, B = number of 512 byte sectors
; Border flashes (mode(1) green/buff) like a tape loader, speaker clicks.
sd_read:
        ld a,b
        or a
        ret z
.next:  push bc
        push hl
        ld (DOSDEST),hl
        ; first sector of the file comes from SelectHandle
        ld hl,(sd_sectors_read)
        ld a,h
        or l
        jr nz,.ns
        ld a,1
        call DOSSEL
        jr .done1
.ns:    call DOSNEXT
.done1: di
        ld hl,(sd_sectors_read)
        inc hl
        ld (sd_sectors_read),hl
        ; loader stripes: toggle colour set + speaker every sector
        ld a,(sd_quiet)
        or a
        jr nz,.nostripe
        ld a,l
        rrca
        ld a,M1G
        jr nc,.st
        ld a,M1W xor $21
.st:    ld (LATCH),a
.nostripe:
        pop hl
        ld de,512
        add hl,de
        pop bc
        djnz .next
        ret
sd_quiet: db 0                  ; 0 = show loader stripes

; sd_skip: skip B sectors (read into a scratch area)
sd_skip:
        ld hl,SCRATCH
.l:     push bc
        push hl
        ld b,1
        call sd_read
        pop hl
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; sound state helpers
; ---------------------------------------------------------------------
snd_silence:                    ; voices off, drums to silence
        exx
        ld de,0
        ld bc,0
        ld hl,$8000
        exx
        ld iy,0
        ld ix,silence
        xor a
        ld i,a
        ret

; ---------------------------------------------------------------------
; clear VRAM to value A
; ---------------------------------------------------------------------
cls:    ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),a
        ldir
        ret

; copy 512 bytes HL -> VRAM
show512:
        ld de,VRAM
        ld bc,512
        ldir
        ret

        IFNDEF NO_KCOPY
; ---------------------------------------------------------------------
; kcopy: copy BC bytes HL->DE using the line kernel (music keeps playing).
; A = latch value to show meanwhile. Up to (kernel_pairs-3)*12 bytes per
; frame, the beam-following copy looks like a wipe.
; ---------------------------------------------------------------------
kc_src:  dw 0
kc_dst:  dw 0
kc_len:  dw 0
kc_c1:   db 1
kc_c2:   db 1
KC_SU   MACRO
        ld hl,(kc_src)
        ld de,(kc_dst)
        WAIT 115-36
        ENDM
KC_SU2  MACRO
        ld (kc_src),hl
        ld (kc_dst),de
        WAIT 115-36
        ENDM
kcopy:
        ld (kc_src),hl
        ld (kc_dst),de
        ld (kc_len),bc
        ld hl,kc_tab
        ld de,kc_tab+1
        ld bc,639
        ld (hl),a
        ldir
        call music_apply
kc_frame:
        ; pairs this frame
        ld hl,(kc_len)
        ld de,0
kc_d12:   ld bc,12
        or a
        sbc hl,bc
        jr c,kc_dd
        inc de
        jr kc_d12
kc_dd:    ; DE = number of 12-byte blocks remaining
        ld a,d
        or e
        jp z,kc_tail
        ld a,(kernel_pairs)
        sub 3
        ld c,a
        ld b,0
        ex de,hl
        or a
        sbc hl,bc
        add hl,bc
        jr c,kc_few
        ld l,c
kc_few:   ld a,l
        ld (kc_c1),a
        ld b,a
        ld a,(kernel_pairs)
        sub 2
        sub b
        ld (kc_c2),a
        ld (sp_save),sp
        call frame_sync
        ld sp,kc_tab
        xor a
        SEG kca, kcax, RAST, 105, KC_SU, W_COPY, W_COPY, kc_c1
        SEG kcb, kcbx, RAST, 105, KC_SU2, W_IDLE, W_IDLE, kc_c2
        ld sp,(sp_save)
        call music_save
        call music_tick
        call music_apply
        ; len -= 12*c1
        ld a,(kc_c1)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl               ; *4
        ld b,h
        ld c,l
        add hl,hl               ; *8
        add hl,bc               ; *12
        ex de,hl
        ld hl,(kc_len)
        or a
        sbc hl,de
        ld (kc_len),hl
        jp kc_frame
kc_tail:  ld bc,(kc_len)
        ld a,b
        or c
        ret z
        ld hl,(kc_src)
        ld de,(kc_dst)
        ldir
        ret
kc_tab:  ds 640
        ENDIF
