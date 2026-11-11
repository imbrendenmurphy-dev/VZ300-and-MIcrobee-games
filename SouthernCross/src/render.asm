; ============================================================================
;  RENDER: background, masked pre-shifted sprites, pixels, HUD panels
; ============================================================================

; ---------------------------------------------------------------- background
; Copy the 64 visible strip rows (from row `top`, wrapping at 256) into the
; frame buffer with an unrolled LDI chain (16 T per byte).
compose_bg:
        ld a,(top)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; *8
        ld d,h
        ld e,l
        add hl,hl               ; *16
        add hl,de               ; *24
        ld de,SRAMSTRIP
        add hl,de               ; source
        ld de,FBVIS
        ld a,(top)
        neg                     ; rows before the wrap = 256 - top (0 = 256)
        jr z,.one
        cp 64
        jr nc,.one
        ; two segments: A rows, then 64-A rows from the strip start
        ld (.n2+1),a
        call ldi_rows
.n2:    ld a,0
        neg
        add a,64
        ld hl,SRAMSTRIP
        jr ldi_rows
.one:   ld a,64
; A = rows (1..64), HL = source, DE = destination
ldi_rows:
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc               ; bytes = rows*24
        add hl,hl               ; *2 (LDI is 2 bytes)
        ex de,hl                ; HL = dest, DE = code length
        push hl
        ld hl,LDICHAIN_END
        or a
        sbc hl,de
        push hl
        pop ix
        pop de
        pop hl
        jp (ix)

; ---------------------------------------------------------------- sprites
; HL = sprite descriptor (db height, width bytes / dw shift 0-3)
; B = x (0-95; caller keeps the sprite inside the playfield)
; C = frame buffer row (0-79; 8 = top screen row)
draw_spr:
        ld a,(hl)
        ld (ds_rows),a
        inc hl
        ld a,(hl)
        ld (ds_wb),a
        inc hl
        ld a,b
        and 3
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = mask/data pairs
        ld h,YTAB>>8
        ld a,c
        add a,a
        ld l,a
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,b
        rrca
        rrca
        and $3F
        add a,l
        ld l,a
        jr nc,$+3
        inc h                   ; HL = destination
        ld a,(ds_rows)
        ld b,a
        ld a,(ds_wb)
        cp 3
        jr z,ds3
        cp 2
        jr z,ds2
        cp 4
        jr z,ds4
        ; general width
        ld c,a
        ld a,FBW
        sub c
        ld (.sk+1),a
.row:   ld a,(ds_wb)
        ld c,a
.by:    ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        dec c
        jr nz,.by
.sk:    ld a,0
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        djnz .row
        ret

ds2:
.row:   ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        ld a,l
        add a,FBW-1
        ld l,a
        jr nc,$+3
        inc h
        djnz .row
        ret

ds3:
.row:   ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        ld a,l
        add a,FBW-2
        ld l,a
        jr nc,$+3
        inc h
        djnz .row
        ret

ds4:
.row:   ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        ld a,l
        add a,FBW-3
        ld l,a
        jr nc,$+3
        inc h
        djnz .row
        ret

; draw a sprite at an object position: HL = descriptor, B = x, C = y16
; (skipped unless 8 <= y16 <= 80, i.e. inside the frame buffer margins)
draw_obj:
        ld a,c
        cp 8
        ret c
        cp 81
        ret nc
        sub 8
        ld c,a
        jp draw_spr

; ---------------------------------------------------------------- pixels
; address of pixel (B = x, C = y16) in the frame buffer -> HL, A = x&3
; carry set if outside rows 0..77 of the visible area +margins
pix_addr:
        ld a,c
        sub 8
        ret c
        cp 78
        ccf
        ret c
        add a,a
        ld l,a
        ld h,YTAB>>8
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,b
        rrca
        rrca
        and $3F
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,b
        and 3
        or a                    ; clear carry
        ret

; vertical streak, 3 rows, yellow (player shot).  B = x, C = y16
draw_shot:
        call pix_addr
        ret c
        ld e,a
        ld d,0
        push hl
        ld hl,PIXMASK
        add hl,de
        ld c,(hl)
        ld hl,PIXYEL
        add hl,de
        ld b,(hl)
        pop hl
        ld de,FBW
        ld a,(hl)
        and c
        or b
        ld (hl),a
        add hl,de
        ld a,(hl)
        and c
        or b
        ld (hl),a
        add hl,de
        ld a,(hl)
        and c
        or b
        ld (hl),a
        ret

; 2x2 dot at an even x.  B = x, C = y16, E = colour byte for both nibbles
; ($FF red, $55 yellow)
draw_dot:
        call pix_addr
        ret c
        and 2
        ld a,$F0
        jr z,.hi
        ld a,$0F
.hi:    ld d,a                  ; D = pixels to set
        cpl
        ld c,a                  ; C = keep mask
        ld a,e
        and d
        ld e,a
        ld a,(hl)
        and c
        or e
        ld (hl),a
        ld a,l
        add a,FBW
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        and c
        or e
        ld (hl),a
        ret

PIXMASK: db $3F,$CF,$F3,$FC
PIXYEL:  db $40,$10,$04,$01

; ---------------------------------------------------------------- HUD
; copy B rows of 4 bytes from HL into the HUD shadow at DE (stride 8)
hud_rows4:
        push bc
        ld bc,4
        ldir
        pop bc
        ld a,e
        add a,4
        ld e,a
        jr nc,$+3
        inc d
        djnz hud_rows4
        ld a,1
        ld (hud_dirty),a
        ret

; digit A (0-9) -> HUD byte column DE (5 rows, stride 8)
hud_digit:
        ld l,a
        add a,a
        add a,a
        add a,l                 ; *5
        ld l,a
        ld h,0
        ld bc,DIGITS
        add hl,bc
        ld b,5
.r:     ld a,(hl)
        ld (de),a
        inc hl
        ld a,e
        add a,8
        ld e,a
        jr nc,$+3
        inc d
        djnz .r
        ret

; 4 BCD digits from (HL), (HL+1) at HUD row DE
hud_bcd4:
        push hl
        push de
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        call hud_digit
        pop de
        inc de
        pop hl
        push hl
        push de
        ld a,(hl)
        and $0F
        call hud_digit
        pop de
        inc de
        pop hl
        inc hl
        push hl
        push de
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        call hud_digit
        pop de
        inc de
        pop hl
        ld a,(hl)
        and $0F
        push de
        call hud_digit
        pop de
; keep the red rule (pixel 15) beside a digit in the last column
        ld b,5
.ru:    ld a,(de)
        and $FC
        or $03
        ld (de),a
        ld a,e
        add a,8
        ld e,a
        jr nc,$+3
        inc d
        djnz .ru
        ret

hud_score:
        ld hl,score
        ld de,HUDBUF+8*8
        call hud_bcd4
        ld hl,score+2
        ld de,HUDBUF+14*8
        call hud_bcd4
        ld a,1
        ld (hud_dirty),a
        ret

hud_hi:
        ld hl,hiscore
        ld de,HUDBUF+28*8
        call hud_bcd4
        ld hl,hiscore+2
        ld de,HUDBUF+34*8
        call hud_bcd4
        ld a,1
        ld (hud_dirty),a
        ret

hud_stage:
        ld a,1
        ld de,HUDBUF+50*8+1
        call hud_digit
        ld a,1
        ld (hud_dirty),a
        ret

hud_stars:
        ld a,(stars_mask)
        and 15
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl               ; *4
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *64
        or a
        sbc hl,de               ; *60
        ld de,STARDIAG
        add hl,de
        ld de,HUDBUF+2*8+4
        ld b,15
        jp hud_rows4

hud_weapon:
        ld a,(wlevel)
        dec a
        ld l,a
        add a,a
        add a,a
        add a,l                 ; *5
        add a,a
        add a,a                 ; *20
        ld l,a
        ld h,0
        ld de,WEAPROWS
        add hl,de
        ld de,HUDBUF+20*8+4
        ld b,5
        jp hud_rows4

hud_lives:
        ld a,(lives)
        or a
        jr z,.z
        dec a
.z:     cp 3
        jr c,.ok
        ld a,2
.ok:    add a,a
        add a,a
        add a,a
        add a,a                 ; *16
        ld l,a
        ld h,0
        ld de,LIVESROWS
        add hl,de
        ld de,HUDBUF+28*8+4
        ld b,4
        jp hud_rows4

; spare CPU bar, refreshed every 8 frames: v = spare passes * 13 / 1024
hud_cpu:
        ld hl,cpubar_tm
        inc (hl)
        ld a,(hl)
        and 7
        ret nz
        ld hl,(spare_last)
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl               ; *12
        add hl,de               ; *13
        ld a,h
        rrca
        rrca
        and $3F
        cp 14
        jr c,.ok
        ld a,13
.ok:    add a,a
        add a,a
        add a,a                 ; *8
        ld l,a
        ld h,0
        ld de,CPUBAR
        add hl,de
        ld de,HUDBUF+57*8+4
        ld b,2
        jp hud_rows4

hud_all:
        call hud_score
        call hud_hi
        call hud_stage
        call hud_stars
        call hud_weapon
        jp hud_lives
