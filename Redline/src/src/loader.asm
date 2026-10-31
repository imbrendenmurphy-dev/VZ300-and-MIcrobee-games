; =====================================================================
;  loader.asm - SD card data files at run time (the "13 Ghosts" DOS calls,
;  as proven on this machine by the New Zealand Story conversion).
;  The DOS is called through its jump table at $5F00 with its own
;  mapping (DOS RAM low + upper bank 0), interrupts off, IM 1; its sector
;  buffer is $F800-$F9FF of upper bank 0 and its workspace ($FA00-$FFFF)
;  is never touched.  Each sector is passed through main RAM (the back
;  buffer) and copied to its destination with that chunk's mapping.
;
;  File format: chunks of  db map, dw dest, dw length, data...;  map 0 ends.
;  This code must live in main RAM ($8000-$B7FF).
; =====================================================================
DOS_FIND  equ $5F00
DOS_FIRST equ $5F03
DOS_NEXT  equ $5F09
DOS_BUF   equ $FB80
DOS_OK    equ $FB03
DOS_ERR   equ $FB05
SDBUF     equ $F800
SECBUF    equ BB              ; 512 bytes of main RAM

; HL -> file name ("NAME" without .DAT, quoted, 0-terminated as the DOS wants)
; returns NC = ok, C = file missing
load_dat:
        di
        ld (ld_name),hl
        ld (ld_sp),sp
        ld sp,ld_stack
        im 1
        ld a,(dosmap)
        out (BANKPORT),a
        ld hl,SDBUF
        ld (DOS_BUF),hl
        ld hl,(ld_name)
        ld a,1
        call DOS_FIND
        ld a,(DOS_OK)
        cp 1
        jp nz,.fail
        ld a,(DOS_ERR)
        cp 1
        jp z,.fail
        ld a,1
        call DOS_FIRST
        xor a
        ld (ld_state),a         ; 0 = expecting a chunk header
        ld (ld_hn),a
.sector:
        ; sector -> main RAM (DOS mapping: both visible)
        ld hl,SDBUF
        ld de,SECBUF
        ld bc,512
        ldir
        ld hl,SECBUF
        ld (ld_p),hl
        ld hl,512
        ld (ld_left),hl
.proc:  ld hl,(ld_left)
        ld a,h
        or l
        jp z,.next
        ld a,(ld_state)
        or a
        jp nz,.data
        ; header byte
        ld hl,(ld_p)
        ld a,(hl)
        inc hl
        ld (ld_p),hl
        ld hl,(ld_left)
        dec hl
        ld (ld_left),hl
        ld hl,ld_hn
        ld e,(hl)
        inc (hl)
        ld d,0
        ld hl,ld_hdr
        add hl,de
        ld (hl),a
        ld a,e
        or a
        jp nz,.h1
        ld a,(ld_hdr)           ; map 0: end of file
        or a
        jp z,.done
.h1:    ld a,(ld_hn)
        cp 5
        jp nz,.proc
        xor a
        ld (ld_hn),a
        inc a
        ld (ld_state),a
        jp .proc
.data:  ; copy min(remaining chunk, left in sector)
        ld hl,(ld_hdr+3)        ; chunk bytes remaining
        ld de,(ld_left)
        push hl
        or a
        sbc hl,de
        pop hl
        jp c,.n1
        ex de,hl
.n1:    ld b,h
        ld c,l                  ; BC = n
        push bc
        ld a,(ld_hdr)
        out (BANKPORT),a        ; destination mapping (source is main RAM)
        ld hl,(ld_p)
        ld de,(ld_hdr+1)
        ldir
        ld (ld_hdr+1),de
        ld (ld_p),hl
        ld a,(dosmap)
        out (BANKPORT),a
        pop bc
        ld hl,(ld_left)
        or a
        sbc hl,bc
        ld (ld_left),hl
        ld hl,(ld_hdr+3)
        or a
        sbc hl,bc
        ld (ld_hdr+3),hl
        ld a,h
        or l
        jp nz,.proc
        xor a
        ld (ld_state),a
        jp .proc
.next:  ld hl,SDBUF
        ld (DOS_BUF),hl
        call DOS_NEXT
        jp .sector
.done:  call .back
        or a
        ret
.fail:  call .back
        scf
        ret
.back:  pop hl                  ; return address on our stack
        ld sp,(ld_sp)
        push hl
        ld a,(race_map)
        out (BANKPORT),a
        im 2
        ld a,(fieldctr)         ; fields lost while loading don't count
        ld (lastcopy),a
        ld (lastfr),a
        xor a
        ld (intoff),a
        ld (ready),a
        ei
        ret

ld_name  dw 0
ld_sp    dw 0
ld_p     dw 0
ld_left  dw 0
ld_state db 0
ld_hn    db 0
ld_hdr   ds 5
dosmap   db 1
race_map db MAP_FE
         ds 64
ld_stack:
