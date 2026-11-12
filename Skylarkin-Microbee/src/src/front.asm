; =====================================================================
;  FRONT END: monitor choice, title, pilot select, difficulty.
; =====================================================================
demo:       db 0

; the font and ready-made glyphs from the common store (block BLK_SPR)
front_glyphs:
        ld a,BLK_SPR
        call map_blk
        ld hl,0
        ld de,0
        ld bc,128
        jp glyphs_in

choose_monitor:
        call front_glyphs
        ld a,WHITE
        ld (txt_col),a
        call cls
        call page_show0
        ld a,YELLOW
        ld (txt_col),a
        ld hl,s_cm1
        ld e,9
        call print_c
        ld a,WHITE
        ld (txt_col),a
        ld hl,s_cm2
        ld e,12
        call print_c
        ld hl,s_cm3
        ld e,14
        call print_c
.w:     call wait_frame
        ld a,(keysnew)
        and 8
        jr nz,.c
        ld a,(keysnew)
        and 16
        jr z,.w
        ld a,1
        jr .s
.c:     xor a
.s:     ld (monomode),a
        jp input_used

; wait one frame (two fields), read the keys
wait_frame:
        call input_used
        call sound_tick
        ld a,2
        call frame_wait
        jp read_input

; show page 0 (front-end screens draw on both pages anyway)
page_show0:
        ld a,12
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld (rpage),a
        ret

s_cm1:  db "SKYLARKIN'!",0
s_cm2:  db "PRESS  C  FOR A COLOUR MONITOR",0
s_cm3:  db "OR  M  FOR MONOCHROME",0

; ---------------------------------------------------------------------
front_main:
        ld sp,STACK
        call stop_music
        xor a
        ld (demo),a
        ld (boss_on),a
        ld (warn_msg),a
        ld (shake_off),a
        call front_glyphs
        ld a,WHITE
        ld (txt_col),a
        call cls
        call page_show0
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
        ld a,BYELLOW
        ld (txt_col),a
        ld hl,s_t1
        ld e,3
        call print_c
        ld a,WHITE
        ld (txt_col),a
        ld hl,s_t2
        ld e,5
        call print_c
        ld a,BCYAN
        ld (txt_col),a
        ld hl,s_t3
        ld e,20
        call print_c
        ld a,GREY
        ld (txt_col),a
        ld hl,s_t4
        ld e,23
        call print_c
        call draw_pilots
        call draw_diff
.w:     call wait_frame
        ld a,(padnew)
        bit 0,a
        jr z,.nr
        ld a,(pilot)
        inc a
        cp 4
        jr c,.p
        xor a
.p:     ld (pilot),a
        call draw_pilots
        ld a,SFX_MENU
        call play_sfx
.nr:    ld a,(padnew)
        bit 1,a
        jr z,.nl
        ld a,(pilot)
        dec a
        jp p,.q
        ld a,3
.q:     ld (pilot),a
        call draw_pilots
        ld a,SFX_MENU
        call play_sfx
.nl:    ld a,(padnew)
        and 12
        jr z,.nd
        ld a,(difficulty)
        inc a
        cp 3
        jr c,.d
        xor a
.d:     ld (difficulty),a
        call draw_diff
        ld a,SFX_MENU
        call play_sfx
.nd:    ld a,(padnew)
        and 16
        jr nz,.go
        ld a,(keysnew)
        and 32
        jr z,.w
.go:    call input_used
        call stop_music
        jp new_game

BYELLOW equ YELLOW
s_t1:   db "S K Y L A R K I N ' !",0
s_t2:   db "A FAIR DINKUM SHOOT-'EM-UP",0
s_t3:   db "LEFT/RIGHT PILOT  UP/DOWN SKILL  SPACE GO",0
s_t4:   db "VIBED BY BPM 2026",0

draw_pilots:
        ld b,4
        ld c,0
.l:     push bc
        ld a,(pilot)
        cp c
        ld a,GREY
        jr nz,.c
        ld a,BLACK+(YELLOW<<4)
.c:     ld (txt_col),a
        ld a,c
        add a,a
        ld l,a
        ld h,0
        ld de,pilot_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,c
        add a,c                 ; *10
        inc a
        ld d,a
        ld e,9
        call print
        pop bc
        inc c
        djnz .l
        ; the chosen pilot's kit
        ld a,WHITE
        ld (txt_col),a
        ld hl,0
        ld (fc_glyph),hl
        ld de,0*256+12
        ld bc,40*256+4
        call fill_cells
        ld a,(pilot)
        add a,a
        ld l,a
        ld h,0
        ld de,pilot_desc
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,12
.dl:    push hl
        call print_c
        pop hl
.z:     ld a,(hl)
        inc hl
        or a
        jr nz,.z
        inc e
        ld a,(hl)
        or a
        jr nz,.dl
        ret

pilot_names:    dw pn0,pn1,pn2,pn3,pn4
pn0:    db " BAZZA  ",0
pn1:    db " SHEILA ",0
pn2:    db " WALLY  ",0
pn3:    db " QUEENIE",0
pn4:    db " LOCKIE ",0
pilot_desc:     dw pd0,pd1,pd2,pd3,pd4
pd0:    db "THE BIN CHICKEN - FLYING WHEELIE BIN",0
        db "MISSILE ROTTEN BANANA  DOUBLE CHICKEN BONE",0
        db "LASER STINK LINE  OPTIONS BABY BINS",0
        db "HANDLING: MEDIUM, 3 HEARTS",0,0
pd1:    db "THE KOALA - FLYING HILLS HOIST",0
        db "MISSILE PEG DROP  DOUBLE UNDIES FLING",0
        db "LASER SPIN CYCLE  OPTIONS FLYING SOCKS",0
        db "HANDLING: SLOW AND STEADY",0,0
pd2:    db "THE WOMBAT - FLYING UTE",0
        db "MISSILE GUMNUT BOMB  DOUBLE SPREAD",0
        db "LASER KABOOMERANG  OPTIONS HARD HATS",0
        db "HANDLING: SLOW, TOUGH, 4 HEARTS",0,0
pd3:    db "THE MICROBEE - FLYING KEYBOARD",0
        db "MISSILE BYTE BUGS  DOUBLE TWIN",0
        db "LASER DOT MATRIX  OPTIONS FLOPPY DISKS",0
        db "HANDLING: FAST, SMALL, ONLY 2 HEARTS",0,0
pd4:    db "THE LYREBIRD - MIMICS EVERYONE",0,0

draw_diff:
        ld a,YELLOW
        ld (txt_col),a
        ld a,(difficulty)
        add a,a
        ld l,a
        ld h,0
        ld de,diff_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,17
        jp print_c
diff_names:     dw dn0,dn1,dn2
dn0:    db "  SKILL: EASY (5 HEARTS)  ",0
dn1:    db " SKILL: NORMAL (3 HEARTS) ",0
dn2:    db "  SKILL: HARD (ONE HIT)   ",0

demo_input:
        ret
demo_quit:
        jp front_main
