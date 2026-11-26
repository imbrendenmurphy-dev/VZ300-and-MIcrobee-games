; ---------------------------------------------------------------------------
; FDCTEST.COM - what does this Premium Plus answer to direct WD2793 access?
;
; For drives A-D it does what the game's own disk reader does (src/fdc.asm):
; select through the latch (port 48), RESTORE, SEEK to cylinder 2, READ SECTOR
; ID 26 (CP/M data-area logical sector 8 = block 1, where each disk's first file
; starts), then READ ADDRESS (the ID of the next sector that passes the head).
; It prints every status byte, how many bytes came in, and the first 16 of them.
; Everything has a timeout.  Run it from the A> prompt; photograph the screen.
; ---------------------------------------------------------------------------
        DEVICE NOSLOT64K
        org $0100
FDC_CMD   equ $44
FDC_TRK   equ $45
FDC_SEC   equ $46
FDC_DAT   equ $47
FDC_LATCH equ $48

start:  ld de,s_title
        call print
        ld a,0
.dr:    ld (drive),a
        call test_drive
        ld a,(drive)
        inc a
        cp 4
        jr nz,.dr
        ld a,0                  ; leave drive A selected for CP/M
        out (FDC_LATCH),a
        ei
        ld de,s_done
        call print
        ret                     ; back to CP/M (warm boot path via the stack)

test_drive:
        ld de,s_nl
        call print
        ld a,(drive)
        add a,'A'
        call putc
        ld de,s_colon
        call print
        di
        ld a,(drive)
        or 8                    ; side 0, double density
        out (FDC_LATCH),a
        ld de,s_rst             ; RESTORE
        call print
        di
        ld a,$00
        out (FDC_CMD),a
        call wait
        call hexsp
        ld de,s_seek            ; SEEK to cylinder 2
        call print
        ld a,2
        out (FDC_DAT),a
        di
        ld a,$10
        out (FDC_CMD),a
        call wait
        call hexsp
        ld de,s_trk
        call print
        in a,(FDC_TRK)
        call hexsp
        ld de,s_read            ; READ SECTOR, ID 26
        call print
        ld a,26
        out (FDC_SEC),a
        di                      ; (CP/M's console output turns interrupts back on)
        ld a,$80
        out (FDC_CMD),a
        ld hl,buf
        call rdata
        call hexsp
        ld de,s_n
        call print
        ld a,(count+1)
        call hex
        ld a,(count)
        call hexsp
        ld de,s_nl2
        call print
        ld hl,buf               ; the first 16 bytes
        ld b,16
.b:     ld a,(hl)
        inc hl
        push bc
        push hl
        call hexsp
        pop hl
        pop bc
        djnz .b
        ld de,s_nl2
        call print
        ld de,s_addr            ; READ ADDRESS: track, side, sector, size, CRC
        call print
        di
        ld a,$C0
        out (FDC_CMD),a
        ld hl,buf
        call rdata
        call hexsp
        ld de,s_id
        call print
        ld hl,buf
        ld b,4
.a:     ld a,(hl)
        inc hl
        push bc
        push hl
        call hexsp
        pop hl
        pop bc
        djnz .a
        ret

; Bytes in on DRQ (latch bit 7 = DRQ or INTRQ) until INTRQ, with a timeout.
; A = final status (FF = timed out).  count = bytes read.
rdata:  push hl
        ld bc,0                 ; ~1 s for the first request (35 T a poll), else give up
.w0:    in a,(FDC_LATCH)
        rla
        jr c,.rq
        djnz .w0
        dec c
        jr nz,.w0
        ld a,$D0                ; force interrupt
        out (FDC_CMD),a
        pop hl
        ld hl,0
        ld (count),hl
        ld a,$FF
        ret
.w:     in a,(FDC_LATCH)        ; then the game's own tight loop (src/bank.asm fdc_rd)
        rla
        jr nc,.w
.rq:    in a,(FDC_CMD)
        bit 1,a
        jr z,.end
        in a,(FDC_DAT)
        ld (hl),a
        inc hl
        jr .w
.end:   pop de                  ; count = HL - start
        push af
        or a
        sbc hl,de
        ld (count),hl
        pop af
        ret

; Wait for INTRQ on a type I command (timeout ~3 s).  A = status (FF = timed out).
wait:   ld b,0
        djnz $
        ld d,4
.o:     ld bc,0
.w:     in a,(FDC_LATCH)
        rla
        jr c,.ok
        dec bc
        ld a,b
        or c
        jr nz,.w
        dec d
        jr nz,.o
        ld a,$D0
        out (FDC_CMD),a
        ld a,$FF
        ret
.ok:    in a,(FDC_CMD)
        ret

hexsp:  call hex
        ld a,' '
        jr putc
hex:    push af
        rrca
        rrca
        rrca
        rrca
        call .n
        pop af
.n:     and 15
        add a,'0'
        cp '9'+1
        jr c,putc
        add a,7
putc:   push hl
        push bc
        push de
        ld e,a
        ld c,2
        call 5
        pop de
        pop bc
        pop hl
        ret
print:  ld c,9
        jp 5

s_title: db 13,10,"FDCTEST - direct WD2793 reads (status in hex; FF = no answer)",13,10,"$"
s_nl:    db 13,10,"$"
s_nl2:   db 13,10,"    $"
s_colon: db ": $"
s_rst:   db "HOME $"
s_seek:  db "SEEK $"
s_trk:   db "TRK $"
s_read:  db "READ $"
s_n:     db "BYTES $"
s_addr:  db "ADDR $"
s_id:    db "ID $"
s_done:  db 13,10,13,10,"Done.  Please photograph this screen.",13,10,"$"
drive:   db 0
count:   dw 0
buf:     ds 600,0
end:
        SAVEBIN "../build/FDCTEST.COM",start,end-start
