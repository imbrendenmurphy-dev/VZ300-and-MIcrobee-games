; ---------------------------------------------------------------------------
; Auto-boot for disk A: our own CCP.SYS.
;
; The Microbee CP/M boot code (in the disk's system tracks) loads SHELL.SYS if the
; disk has one, otherwise CCP.SYS, at CB00 and jumps to it.  Disk A has no SHELL.SYS
; (the game does NOT use the Microbee shell); in place of the CP/M command processor
; it carries this tiny loader, which reads BLACKOUT.COM into 0100 through the BDOS
; and runs it, exactly as typing BLACKOUT at the A> prompt would.  So the disk boots
; straight into the game, works write-protected, and stays an ordinary CP/M disk
; (DIR it from any other boot disk).  The real CCP.SYS is in resources/.
;
; File layout copies the Microbee CCP.SYS: a 128-byte header (bytes 0-1 kept as in the
; original, load address CB00 at 2-3, code length at 4-5), then the code.
; ---------------------------------------------------------------------------
        DEVICE NOSLOT64K
BDOS    equ $0005
LOAD    equ $CB00

        org LOAD-$80
header: db $00,$E4
        dw LOAD
        dw code_end-LOAD
        ds LOAD-$, 0

        org LOAD
        jp start                ; (cold and warm boot both enter here)
        jp start
start:  ld sp,$D3A0             ; where the real CCP keeps its stack
        ld c,13                 ; reset the disk system: drive A, DMA 0080
        call BDOS
        ld de,fcb
        ld c,15                 ; open BLACKOUT.COM
        call BDOS
        inc a
        jr z,missing
        ld hl,$0100
.rd:    push hl
        ex de,hl
        ld c,26                 ; DMA = next 128 bytes of the TPA
        call BDOS
        ld de,fcb
        ld c,20                 ; read sequential
        call BDOS
        pop hl
        or a
        jr nz,.go               ; end of file
        ld de,128
        add hl,de
        jr .rd
.go:    ld de,$0080
        ld c,26
        call BDOS
        xor a
        ld ($0080),a            ; an empty command tail
        jp $0100

missing:
        ld de,msg
        ld c,9
        call BDOS
.halt:  jr .halt

; The program to run: 8-letter name + 3-letter type, space padded (change for another game).
fcb:    db 0,"BLACKOUTCOM"
        ds 24,0
msg:    db 13,10,"PROGRAM MISSING FROM THIS DISK",13,10,"$"
code_end:
        ASSERT code_end < $D300
        SAVEBIN "../build/CCP.SYS",header,(code_end-header+127)/128*128
