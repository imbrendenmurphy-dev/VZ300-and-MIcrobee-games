; =====================================================================
;  HUD: row 0 score line, row 24 the upgrade bar (both pages).
;  row 0:  1UP 000000000  hearts  lives   HI 000000000 / boss bar
;  row 24: SPEED MISSL DOUBL LASER OPTN SHLD OI!  + the bell power
; =====================================================================
HUD_COL     equ WHITE+(BLACK<<4)
BAR_COL     equ BCYAN+(BLUE<<4)
BAR_LIT     equ BLACK+(YELLOW<<4)
BAR_MAX     equ DGREY+(BLUE<<4)

hud_full:
        ld a,HUD_COL
        ld (txt_col),a
        ld hl,0
        ld (fc_glyph),hl
        ld de,0
        ld bc,40*256+1
        call fill_cells
        ld de,24
        ld bc,40*256+1
        call fill_cells
        ld a,YELLOW+(BLACK<<4)
        ld (txt_col),a
        ld hl,s_1up
        ld de,0*256+0
        call print
        ld a,1
        ld (hud_dirty),a
        jp hud_update.go
s_1up:  db "1UP",0

hud_update:
        ld a,(warn_msg)
        or a
        jr z,.nw
        ld a,(ticks)
        and 3
        jr nz,.nw
        ld a,1
        ld (hud_dirty),a
.nw:    ld a,(hud_dirty)
        or a
        ret z
        ld a,(ticks)            ; at most every fourth frame (score runs
        and 3                   ; would otherwise redraw it every frame)
        ret nz
.go:    xor a
        ld (hud_dirty),a
        ; score
        ld a,WHITE+(BLACK<<4)
        ld (txt_col),a
        ld hl,score
        ld de,4*256+0
        call print_bcd
        ; hearts: full, empty, or none (cols 14-18)
        ld d,14
        ld c,0
.h:     push bc
        push de
        ld a,c
        ld hl,hearts
        cp (hl)
        jr c,.full
        ld hl,maxhearts
        cp (hl)
        jr c,.empty
        xor a
        ld b,BLACK
        jr .put
.full:  ld a,IC_HEART
        ld b,BRED+(BLACK<<4)
        jr .put
.empty: ld a,IC_HEARTE
        ld b,DGREY+(BLACK<<4)
.put:   ld e,0
        call put_icon
        pop de
        pop bc
        inc d
        inc c
        ld a,c
        cp 5
        jr nz,.h
.lv:    ; lives
        ld de,20*256+0
        ld a,IC_LIFE
        ld b,YELLOW+(BLACK<<4)
        call put_icon
        ld a,(lives)
        add a,'0'
        ld (s_lives+1),a
        ld a,WHITE+(BLACK<<4)
        ld (txt_col),a
        ld hl,s_lives
        ld de,21*256+0
        call print
        ; the right side: hi score, the boss's bar or the warning
        ld a,(warn_msg)
        or a
        jr z,.nwarn
        ld a,(ticks)
        and 4
        ld a,BLACK+(YELLOW<<4)
        jr z,.wc
        ld a,YELLOW+(RED<<4)
.wc:    ld (txt_col),a
        ld a,(warn_msg)         ; the stage's own words (OVL+24 / +26)
        ld hl,(OVL+24)
        dec a
        jr z,.w1
        ld hl,(OVL+26)
.w1:    ld de,24*256+0
        call print
        jr .bar
.nwarn: ld a,(boss_on)
        or a
        jr nz,.boss
        ld a,GREY+(BLACK<<4)
        ld (txt_col),a
        ld hl,s_hi
        ld de,24*256+0
        call print
        ld a,WHITE+(BLACK<<4)
        ld (txt_col),a
        ld hl,hiscore
        ld de,27*256+0
        call print_bcd
        ld hl,s_pad4            ; (wipes the end of a warning)
        ld de,36*256+0
        call print
        jr .bar
.boss:  ld a,BRED+(BLACK<<4)
        ld (txt_col),a
        ld hl,s_boss
        ld de,24*256+0
        call print
        ; 11 cells of bar for hp / hpmax
        ld hl,(boss_hp)
        ld a,l
        ld b,11
        call mul_div            ; A = hp * 11 / hpmax
        ld c,a
        ld d,29
        ld b,11
.bb:    push bc
        push de
        ld a,c
        or a
        ld a,IC_HBAR
        ld b,BRED+(BLACK<<4)
        jr nz,.bf
        ld a,IC_HBARE
        ld b,DGREY+(BLACK<<4)
.bf:    ld e,0
        call put_icon
        pop de
        pop bc
        ld a,c
        or a
        jr z,.bz
        dec c
.bz:    inc d
        djnz .bb
        ; ---- the upgrade bar
.bar:   ld b,7
        ld c,1
        ld hl,bar_names
        ld d,0
.s:     push bc
        push hl
        push de
        ld a,(barpos)
        cp c
        ld a,BAR_LIT
        jr z,.sc
        ld a,c
        push hl
        call slot_maxed
        pop hl
        ld a,BAR_MAX
        jr c,.sc
        ld a,BAR_COL
.sc:    ld (txt_col),a
        ld e,24
        call print
        pop de
        pop hl
        ld bc,6
        add hl,bc
        ld a,d
        add a,5
        ld d,a
        pop bc
        inc c
        djnz .s
        ; the bell power
        ld a,(bellpow)
        ld e,a
        add a,a
        add a,e
        add a,a                 ; *6
        ld e,a
        ld d,0
        ld hl,pow_names
        add hl,de
        ld a,(bellpow)
        ld e,a
        ld d,0
        push hl
        ld hl,bell_ink
        add hl,de
        ld a,(hl)
        add a,BLACK<<4
        ld (txt_col),a
        pop hl
        ld de,35*256+24
        jp print

s_lives:    db "X3",0
s_hi:       db "HI",0
s_boss:     db "BOSS",0
s_pad4:     db "    ",0
bar_names:
        db "SPEED",0,"MISSL",0,"DOUBL",0,"LASER",0,"OPTN ",0,"SHLD ",0,"  !? ",0
pow_names:
        db "     ",0,"     ",0,"MEGA!",0,"BIG! ",0,"RAPID",0,"SLOW ",0

; put_icon: A = glyph, B = colour, D = col, E = row
put_icon:
        push de
        push hl
        push bc
        ld c,b
        ld l,a
        ld h,0
        ex de,hl
        push de
        ld d,h
        ld e,l
        call cell_of_de
        pop de
        call put_both
        pop bc
        pop hl
        pop de
        ret
cell_of_de:                     ; H = col, L = row -> HL = cell
        ld d,h
        ld e,l
        jp cell_of

; print_bcd: 4 BCD bytes at HL as 8 digits and a 0, at D, E
print_bcd:
        push de
        ld de,numbuf
        ld b,4
.d:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .d
        ld a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        pop de
        ld hl,numbuf
        jp print
numbuf: ds 10

; mul_div: A = value, B = scale -> A = value * scale / (boss_hpmax) (8-bit)
mul_div:
        ld e,a
        ld d,0
        ld hl,0
.m:     add hl,de
        djnz .m
        ld a,(boss_hpmax)
        ld c,a
        ld b,0
        ld e,0
.q:     or a
        sbc hl,bc
        jr c,.x
        inc e
        jr .q
.x:     add hl,bc
        ld a,h
        or l
        ld a,e
        ret z
        inc a                   ; round up so a sliver shows
        ret
