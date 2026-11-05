; ===========================================================================
;  sd.asm - load a .DAT file from the BennVenn SD card through the DOS
;  Protocol (as used by 13 Ghosts):
;    (FB80) = sector buffer, HL -> "NAME", A = 1, CALL $5F00   open
;    (FB03) must be 1 and (FB05) must not be 1
;    A = 1, CALL $5F03   first 512-byte sector -> (FB80)
;    (FB80) = buffer, CALL $5F09   next sector
;  The DOS lives in SRAM bank 1 ($37 = dos_map) and owns RAM $FA00-$FFFF.
;  Data for SRAM bank 3 is copied with $37 = 3, then the DOS is mapped back.
; ===========================================================================

DOS_OPEN    equ $5F00
DOS_FIRST   equ $5F03
DOS_NEXT    equ $5F09
DOS_BUFPTR  equ $FB80
DOS_STAT1   equ $FB03
DOS_STAT2   equ $FB05

; sd_load: IX = file entry (dw size ; db '"NAME"',0), DE = destination,
;          A = 1 if the destination is in SRAM bank 3.  Leaves bank 3 mapped.
sd_load:
            ld (sd_bank),a
            ld (sd_dst),de
            ld l,(ix+0)
            ld h,(ix+1)
            ld (sd_left),hl
            push ix
            ld a,(dos_map)
            out ($37),a
            ld hl,SECBUF
            ld (DOS_BUFPTR),hl
            push ix
            pop hl
            inc hl
            inc hl                  ; -> "NAME"
            ld a,1
            call DOS_OPEN
            ld a,(DOS_STAT1)
            cp 1
            jr nz,sd_fail
            ld a,(DOS_STAT2)
            cp 1
            jr z,sd_fail
            ld a,1
            call DOS_FIRST
.copy:      ; bc = min(left, 512)
            ld hl,(sd_left)
            ld bc,512
            ld a,h
            cp 2
            jr nc,.full
            ld b,h
            ld c,l
.full:      push bc
            ld hl,SECBUF
            ld de,(sd_dst)
            ld a,(sd_bank)
            or a
            jr z,.main
            ld a,3
            out ($37),a
            ldir
            ld a,(dos_map)
            out ($37),a
            jr .moved
.main:      ldir
.moved:     ld (sd_dst),de
            pop bc
            ld hl,(sd_left)
            or a
            sbc hl,bc
            ld (sd_left),hl
            ld a,h
            or l
            jr z,.done
            ld hl,SECBUF
            ld (DOS_BUFPTR),hl
            call DOS_NEXT
            jr .copy
.done:      pop ix
            jp bank3

; a missing file is fatal: say which one on a mode 0 screen
sd_fail:    pop ix
            xor a
            ld (LATCH),a
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,511
            ld (hl),$20
            ldir
            ld hl,str_sdfail
            ld de,VRAM+32*6+2
            call .p
            push ix
            pop hl
            inc hl
            inc hl
            ld de,VRAM+32*8+2
            call .p
.h:         jr .h
.p:         ld a,(hl)
            or a
            ret z
            and $3F
            ld (de),a
            inc hl
            inc de
            jr .p
str_sdfail: db "CAN'T LOAD GAME FILE:",0
