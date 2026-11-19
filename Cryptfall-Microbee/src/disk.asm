; =====================================================================
;  DISK: everything goes through CP/M's BDOS, so the game runs from any
;  drive the Microbee's own system can read.
;    CAVES.DAT  record 0: "CRYPTFALL-CAVES1", dw number of caves
;               then 18 records a cave (a 256-byte header and a map of 32
;               rows of 64): any number of them
;    CRYPT.HI   one record: the high scores and the furthest crypt reached
;    DEMO.DAT   the attract mode's recorded run
; =====================================================================
; BDOS call.  The game's video window and latches are put back after it.
bdos:   ei
        call BDOS
        push af
        call hw_video
        pop af
        ret

; HL = FCB: clear everything after the name
fcb_clear:
        ld de,12
        add hl,de
        ld b,24
.z:     ld (hl),0
        inc hl
        djnz .z
        ret

; open the caves file and read how many caves it holds.  (ncaves) = 0 if
; it is not there
disk_init:
        ld hl,0
        ld (ncaves),hl
        ld hl,fcb_caves
        call fcb_clear
        ld de,fcb_caves
        ld c,15
        call bdos
        inc a
        ret z
        ld hl,0
        ld de,CAVEBUF
        call cv_rec
        ret nz
        ld hl,CAVEBUF
        ld de,cv_magic
        ld b,16
.m:     ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .m
        ld hl,(CAVEBUF+16)
        ld (ncaves),hl
        ret
cv_magic: db "CRYPTFALL-CAVES2"

; read record HL of the caves file to DE.  NZ on error
cv_rec: ld (fcb_caves+33),hl
        xor a
        ld (fcb_caves+35),a
        ld c,26
        call bdos
        ld de,fcb_caves
        ld c,33
        call bdos
        or a
        ret

; load cave (cave_no) into CAVEBUF.  Carry if there is no such cave
cave_load:
        ld a,(cave_no)
        ld l,a
        ld h,0
        ld de,(ncaves)
        or a
        sbc hl,de
        ccf
        ret c
        add hl,de
        add hl,hl               ; x 18 records a cave
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        inc hl                  ; first record
        ld de,CAVEBUF
        ld b,CAVE_RECS
.r:     push bc
        push hl
        push de
        call cv_rec
        pop de
        pop hl
        pop bc
        scf
        ret nz
        inc hl
        ld a,e
        add a,128
        ld e,a
        jr nc,.n
        inc d
.n:     djnz .r
        or a
        ret

; ---- the attract mode's recording -------------------------------------
demo_load:
        ld a,$FF                ; (no recording)
        ld (DEMOBUF),a
        ld hl,fcb_demo
        call fcb_clear
        ld de,fcb_demo
        ld c,15
        call bdos
        inc a
        ret z
        ld de,DEMOBUF
        ld b,4                  ; up to 512 bytes
.r:     push bc
        push de
        ld c,26
        call bdos
        ld de,fcb_demo
        ld c,20
        call bdos
        pop de
        pop bc
        or a
        ret nz
        ld a,e
        add a,128
        ld e,a
        jr nc,.n
        inc d
.n:     djnz .r
        ret

; ---- high scores --------------------------------------------------------
HI_N    equ 8
HI_SZ   equ 12                  ; name 8, score 3 (BCD), crypt 1
; hibuf: 0 magic(8)  8 furthest crypt  10 table (8 x 12)  127 checksum
hi_load:
        xor a
        ld (hi_ok),a
        ld hl,fcb_hi
        call fcb_clear
        ld de,fcb_hi
        ld c,15
        call bdos
        inc a
        jr z,hi_default
        ld a,1
        ld (hi_ok),a
        ld de,hibuf
        ld c,26
        call bdos
        ld de,fcb_hi
        ld c,20
        call bdos
        or a
        jr nz,hi_default
        ld hl,hibuf
        ld de,hi_magic
        ld b,8
.m:     ld a,(de)
        cp (hl)
        jr nz,hi_default
        inc hl
        inc de
        djnz .m
        call hi_sum
        ld hl,hibuf+127
        cp (hl)
        ret z
hi_default:
        ld hl,hi_init
        ld de,hibuf
        ld bc,10+HI_N*HI_SZ
        ldir
        ld h,d
        ld l,e
        inc de
        ld (hl),0
        ld bc,127-10-HI_N*HI_SZ
        ldir
        ret
hi_sum: ld hl,hibuf
        ld b,127
        xor a
.s:     add a,(hl)
        rlca
        inc hl
        djnz .s
        ret
hi_magic: db "CRYPTHI1"

; write the table back.  -> A = 0 saved, 1 the disk is write-protected,
; 2 no score file on this disk / disk error.  A protected disk is found
; out first from the drive's status, so the system never has to complain.
hi_save:
        ld a,(hi_ok)
        or a
        ld a,2
        ret z
        call hi_sum
        ld (hibuf+127),a
        ld hl,fcb_hi
        call fcb_clear
        ld de,fcb_hi
        ld c,15                 ; open (this also selects the drive)
        call bdos
        inc a
        ld a,2
        ret z
        ld a,$D0                ; WD2793 force interrupt: the status then
        out (P_FDCST),a         ; shows the write-protect line (bit 6)
        ld b,40
.d:     djnz .d
        in a,(P_FDCST)
        and $40
        ld a,1
        ret nz
        ld de,hibuf
        ld c,26
        call bdos
        ld de,fcb_hi
        ld c,21                 ; write sequential: record 0, in place
        call bdos
        or a
        ld a,2
        ret nz
        ld de,fcb_hi
        ld c,16
        call bdos
        inc a
        ld a,2
        ret z
        xor a
        ret

fcb_caves: db 0,"CAVES   DAT"
        ds 25
fcb_hi: db 0,"CRYPT   HI "
        ds 25
fcb_demo: db 0,"DEMO    DAT"
        ds 25
