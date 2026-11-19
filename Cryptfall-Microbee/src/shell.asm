; =====================================================================
;  SHELL.SYS - the Microbee's CP/M loads this in place of CCP.SYS when it
;  is on the disk, so CRYPTFALL starts by itself when the disk is booted.
;  It loads CRYPT.COM at 0100h and runs it.      VIBED BY BPM 2026
;  (Record 0 of the file is the system's header: dw E400h, load address,
;  length.  tools/build_disk.py adds it.)
; =====================================================================
BDOS    equ 5
        ORG $CB00
        jp start
        jp start
start:  ld sp,$CB00
        ld de,fcb
        ld c,15
        call BDOS
        inc a
        jr z,fail
        ld de,$0100
.lp:    push de
        ld c,26
        call BDOS
        ld de,fcb
        ld c,20
        call BDOS
        pop de
        or a
        jr nz,.done
        ld hl,128
        add hl,de
        ex de,hl
        jr .lp
.done:  ld de,$0080
        ld c,26
        call BDOS
        jp $0100
fail:   ld de,msg
        ld c,9
        call BDOS
.h:     jr .h
msg:    db 13,10,"CRYPTFALL: CRYPT.COM is missing from this disk.",13,10,"$"
fcb:    db 0,"CRYPT   COM",0,0,0,0
        ds 21
endc:
        SAVEBIN "../build/SHELL.BIN",$CB00,endc-$CB00
