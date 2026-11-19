; =====================================================================
;  sprite.asm - pre-shifted 16x8 masked sprites in the game back buffer
;  A sprite block is 256 bytes: 4 phases x 8 rows x 4 x (mask, data).
; =====================================================================

; build_sprite: HL = phase-0 image (32 data bytes, then 32 mask bytes),
; DE = destination block (256 bytes)
build_sprite:
            ld (bs_src),hl
            ld (bs_dst),de
            xor a
            ld (bs_p),a
.ph:        ld hl,(bs_src)
            ld (bs_row),hl
            ld b,8
.row:       push bc
            ; fetch data row -> bs_d, mask row -> bs_m
            ld hl,(bs_row)
            ld de,bs_d
            ld bc,4
            ldir
            ld (bs_row),hl
            ld bc,28
            add hl,bc
            ld de,bs_m
            ld bc,4
            ldir
            ; shift right by p pixels
            ld a,(bs_p)
            or a
            jr z,.out
            add a,a
            ld b,a                  ; 2p bits
.sh:        ld hl,bs_d
            srl (hl)
            inc hl
            rr (hl)
            inc hl
            rr (hl)
            inc hl
            rr (hl)
            ld hl,bs_m
            scf
            rr (hl)
            inc hl
            rr (hl)
            inc hl
            rr (hl)
            inc hl
            rr (hl)
            djnz .sh
.out:       ld de,(bs_dst)
            ld hl,bs_d
            ld b,4
.o:         push hl
            inc hl
            inc hl
            inc hl
            inc hl
            ld a,(hl)               ; mask (bs_m follows bs_d)
            pop hl
            ld (de),a
            inc de
            ld a,(hl)
            ld (de),a
            inc de
            inc hl
            djnz .o
            ld (bs_dst),de
            pop bc
            djnz .row
            ld hl,bs_p
            inc (hl)
            ld a,(hl)
            cp 4
            jr nz,.ph
            ret

; ---------------------------------------------------------------------
; draw_spr: HL = sprite block, BC = world x, DE = world y (pixels).
; spr_sil: 0 = normal, else a colour byte to fill the shape with.
; ---------------------------------------------------------------------
draw_spr:
            ld (ds_blk),hl
            ; sx = x - cam_x
            ld hl,(cam_x)
            ld a,c
            sub l
            ld c,a
            ld a,b
            sbc a,h
            ld b,a                  ; BC = sx (signed)
            ; visible if -15 <= sx <= 127
            ld hl,15
            add hl,bc               ; sx+15 in 0..142 ?
            ld a,h
            or a
            ret nz
            ld a,l
            cp 143
            ret nc
            ; sy = y - cam_y
            ld a,(cam_y)
            ld l,a
            ld h,0
            ex de,hl
            or a
            sbc hl,de               ; HL = sy (signed)
            ld de,7
            add hl,de               ; sy+7 in 0..60 ?
            ld a,h
            or a
            ret nz
            ld a,l
            cp VIEWROWS+7
            ret nc
            sub 7                   ; A = sy (may be negative, -7..53)
            ; rows to skip at the top / rows to draw
            ld d,0                  ; skip
            ld e,8                  ; count
            bit 7,a
            jr z,.t
            neg
            ld d,a
            ld a,8
            sub d
            ld e,a
            xor a
.t:         ld h,a                  ; H = first screen row
            add a,e
            sub VIEWROWS
            jr c,.b
            jr z,.b
            ld l,a
            ld a,e
            sub l
            ld e,a                  ; clip the bottom
.b:         ld a,e
            ld (ds_n),a
            ; source = block + phase*64 + skip*8
            ld a,c
            and 3
            rrca
            rrca                    ; phase * 64
            ld l,a
            ld a,d
            add a,a
            add a,a
            add a,a
            add a,l
            ld l,a
            push hl                 ; (H still = first row)
            ld a,(ds_blk)
            add a,l
            ld e,a
            ld a,(ds_blk+1)
            adc a,0
            ld d,a
            ld (ds_src),de
            pop hl
            ; destination = VIEWTOP + row*40 + (sx >> 2)
            ld a,h
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl               ; row*8
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl               ; row*32
            add hl,de               ; row*40
            sra b
            rr c
            sra b
            rr c                    ; BC = sx >> 2 (signed)
            add hl,bc
            ld de,VIEWTOP
            add hl,de
            ld a,(spr_sil)
            or a
            jr nz,draw_sil
            di
            ld (ds_sp),sp
            ld sp,(ds_src)
            ld a,(ds_n)
            ld e,a
.r:         REPT 4
            pop bc
            ld a,(hl)
            and c
            or b
            ld (hl),a
            inc hl
            ENDR
            ld bc,BBW-4
            add hl,bc
            dec e
            jp nz,.r
            ld sp,(ds_sp)
ds_ei:      ld a,(intoff)
            or a
            ret nz
            ei
            ret

; silhouette: the shape filled with colour byte spr_sil
draw_sil:
            ld d,a
            di
            ld (ds_sp),sp
            ld sp,(ds_src)
            ld a,(ds_n)
            ld e,a
.r:         REPT 4
            pop bc
            ld a,c
            cpl
            and d
            ld b,a
            ld a,(hl)
            and c
            or b
            ld (hl),a
            inc hl
            ENDR
            ld bc,BBW-4
            add hl,bc
            dec e
            jp nz,.r
            ld sp,(ds_sp)
            jr ds_ei

; ---------------------------------------------------------------------
; plot a 2x2 dot (shots): BC = world x, DE = world y, A = colour (0-3)
; ---------------------------------------------------------------------
plot_dot:
            ld hl,cfill
            add a,l
            ld l,a
            jr nc,.cf
            inc h
.cf:        ld a,(hl)
            ld (pd_c),a
            ld hl,(cam_x)
            ld a,c
            sub l
            ld c,a
            ld a,b
            sbc a,h
            ret nz                  ; off screen (or negative)
            ld a,c
            cp 127
            ret nc
            ld a,(cam_y)
            ld l,a
            ld a,e
            sub l
            ld l,a
            ld a,d
            sbc a,0
            ret nz
            ld a,l
            cp VIEWROWS-1
            ret nc
            ; row address
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,de               ; row*40
            ld de,VIEWTOP
            add hl,de
            ld a,c
            srl a
            srl a
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,c
            and 3
            push hl
            push af
            call dot2
            pop af
            pop hl
            ld de,BBW
            add hl,de
; two pixels side by side: HL = byte, A = first pixel (0-3)
dot2:
            push hl
            push af
            call set_px
            pop af
            pop hl
            inc a
            cp 4
            jr nz,set_px
            xor a
            inc hl
; set pixel A (0-3) of (HL) to the colour byte pd_c
set_px:
            ld de,pixmask
            add a,e
            ld e,a
            jr nc,.n
            inc d
.n:         ld a,(de)
            ld d,a
            cpl
            and (hl)
            ld e,a
            ld a,(pd_c)
            and d
            or e
            ld (hl),a
            ret

pixmask:    db $C0,$30,$0C,$03
cfill:      db $00,$55,$AA,$FF
