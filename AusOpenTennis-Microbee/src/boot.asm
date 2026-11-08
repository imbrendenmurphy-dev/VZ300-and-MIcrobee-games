; start-up (the front end comes later; tests poke boot_mode)
start:
        ld a,(boot_mono)
        ld (monomode),a
        call font_init
        ld a,r
        ld l,a
        ld h,$5A
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        ld a,4
        ld (gamesper),a
        ld a,1
        ld (setsneed),a
        call frame_begin
        ld a,(boot_test)
        or a
        jp nz,test_match
        ld a,BLK_FRONT
        call map_blk
        jp front_start

; fonts into PCG banks 10..12 (glyph G_FONT1 on)
font_init:
        ld a,BLK_GFX
        call map_blk
        ld hl,GFX_FONTS
        ld de,G_FONT1
        ld bc,NFONTGLYPHS
        call glyphs_to_pcg
        ld a,BLK_RT
        jp map_blk

; HL = patterns (lower window), DE = first glyph, BC = count
glyphs_to_pcg:
.g:     ld a,b
        or c
        jr z,.d
        dec bc
        push bc
        ld a,e
        rla
        ld a,d
        rla
        or LV_SCREEN
        out (P_LV),a
        push de
        ld a,e
        or $80
        ld e,a
        ld d,$0F
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld bc,16
        ldir
        pop de
        inc de
        pop bc
        jr .g
.d:     ld a,LV_SCREEN
        out (P_LV),a
        ret

; a test: an exhibition (autoplay = the computer plays both)
test_match:
        ld a,(boot_mode)
        ld (mode),a
        ld a,(boot_venue)
        call set_surface
        ld ix,pl0
        ld a,(boot_opp)
        ld c,CTL_CPU
        ld b,0
        call setup_player
        ld ix,pl1
        ld a,8
        ld c,CTL_ANY
        ld b,0
        call setup_player
        ld a,1
        ld (autoplay),a
.m:     call play_match
        jr .m

boot_mode:  db MODE_EXHIB
boot_venue: db V_MELBOURNE
boot_opp:   db 2
boot_mono:  db 0
boot_test:  db 0
