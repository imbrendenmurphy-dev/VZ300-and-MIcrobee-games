; HIRES test: 256x192 mono (6847 RG6) grid + diagonal across all three 2K pages.
; Drives both mods at once:
;   Australian SHRG: OUT 32,(28+page)  (mode 7 = GM 111, page in bits 0-1), AG from latch bit 3
;   German:          latch bit 1 -> GM0+GM2 (GM1 tied high), VRAM bank OUT ($D0),page
        org $8000
start:  di
        ld a,$0A                ; AG=1 + German hi-res bit
        ld ($6800),a
        ld c,0                  ; page 0..2
pagel:  ld a,c
        add a,28
        out (32),a
        ld a,c
        out ($D0),a
        ld hl,$7000
        ld a,c
        rrca
        rrca                    ; a = page*64 = first row
        ld d,a                  ; d = y
        ld b,64
rowl:   push bc
        ld a,d
        and 15
        ld e,$80                ; vertical grid lines every 8 px
        jr nz,notline
        ld e,$FF                ; horizontal line every 16 rows
notline:
        ld a,d
        and 7
        ld b,a
        ld a,$80
        jr z,mdone
mshift: rrca
        djnz mshift
mdone:  ld (mask),a
        ld a,d
        rrca
        rrca
        rrca
        and 31
        ld (dcol),a
        ld b,0
coll:   ld a,(dcol)
        cp b
        ld a,e
        jr nz,nod
        push hl
        ld hl,mask
        or (hl)
        pop hl
nod:    ld (hl),a
        inc hl
        inc b
        ld a,b
        cp 32
        jr nz,coll
        inc d
        pop bc
        djnz rowl
        inc c
        ld a,c
        cp 3
        jr nz,pagel
        ld a,28
        out (32),a
        xor a
        out ($D0),a
hang:   jr hang
mask:   db 0
dcol:   db 0
