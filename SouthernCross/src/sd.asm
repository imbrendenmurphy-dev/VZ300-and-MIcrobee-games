; ============================================================================
;  SD LOADING (BennVenn DOS, called exactly as Graves 'n' Gargoyles 0.3.4 and
;  Dracula's Castle II call it on the real machine)
;   ($FB80)   = sector buffer address
;   $5F00     A=1, HL -> "NAME"   open; OK if ($FB03)=1 and ($FB05)<>1
;   $5F03     A=1                 read first sector into ($FB80)
;   $5F09                         read next sector into ($FB80)
;  The DOS runs from SRAM bank A (the loader's mapping) and keeps its own RAM
;  at $FA00 and up, which this program never touches.  It gets the frame
;  buffer as its stack (it needs well over 1K) and interrupts are disabled
;  after every call.  Sectors bound for SRAM bank B are copied with port $37
;  switched to 3 around the LDIR, as the 13 Ghosts loader does.
; ============================================================================
SECBUF  equ $F800
DOSSTK  equ $F800

; at start-up, before touching port $37: is the DOS bank writable RAM?
dos_probe:
        ld hl,$5FFF
        ld b,(hl)
        ld a,b
        cpl
        ld (hl),a
        ld a,(hl)
        xor b
        ld (hl),b
        and 1
        ld (DOSMAP),a
        ret

; HL = pack entry (dw dest, dw length, db 1 if SRAM bank B, quoted name)
; carry set on failure.  Leaves interrupts disabled and SRAM bank B mapped.
load_pack:
        di
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ld_dest),de
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (ld_left),bc
        ld a,(hl)
        inc hl
        ld (ld_bank),a
        ld (ld_name),hl
        ld (ld_sp),sp
        ld sp,DOSSTK
        ld a,(DOSMAP)
        out ($37),a
        ld hl,SECBUF
        ld ($FB80),hl
        ld hl,(ld_name)
        ld a,1
        call $5F00
        di
        ld a,($FB03)
        cp 1
        jr nz,.err
        ld a,($FB05)
        cp 1
        jr z,.err
        ld a,1
        call $5F03
        di
.lp:    ld bc,(ld_left)
        ld a,b
        cp 2
        jr c,.part
        ld bc,$200
.part:  push bc
        ld a,(ld_bank)
        or a
        jr z,.cp
        ld a,3                  ; SRAM bank B in for the copy
        out ($37),a
.cp:    ld hl,SECBUF
        ld de,(ld_dest)
        ldir
        ld (ld_dest),de
        ld a,(DOSMAP)           ; and the DOS back
        out ($37),a
        pop bc
        ld hl,(ld_left)
        or a
        sbc hl,bc
        ld (ld_left),hl
        ld a,h
        or l
        jr z,.ok
        ld hl,SECBUF
        ld ($FB80),hl
        call $5F09
        di
        jr .lp
.ok:    or a
        jr .out
.err:   scf
.out:   ld sp,(ld_sp)           ; (flags survive)
        push af
        ld a,3
        out ($37),a
        pop af
        ret

; load a pack, retrying until it works (red screen + FIRE between tries)
must_load:
        push hl
        call load_pack
        pop hl
        ret nc
        push hl
        call sd_error
        pop hl
        jr must_load

; red screen with a yellow bar; wait for FIRE (interrupts off)
sd_error:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$FF
        ldir
        ld hl,VRAM+28*32
        ld de,VRAM+28*32+1
        ld bc,8*32-1
        ld (hl),$55
        ldir
.w1:    call read_input         ; wait for release, then a press
        ld a,(keys)
        and (1<<K_FIRE)|(1<<K_BURST)
        jr nz,.w1
.w2:    call read_input
        ld a,(keys)
        and (1<<K_FIRE)|(1<<K_BURST)
        jr z,.w2
        ret

PK_FRONT:
        dw FRONT_START,FR_END-FRONT_START
        db 0
        db '"SCROSS00"'
PK_STAGE1:
        dw $4000,STG_END-$4000
        db 1
        db '"SCROSS01"'
