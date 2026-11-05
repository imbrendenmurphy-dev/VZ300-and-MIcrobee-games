; =====================================================================
;  front.asm - title, attract, intro cards, game flow, hi-scores, ending
; =====================================================================

; ---------------------------------------------------------------------
;  game flow
; ---------------------------------------------------------------------
game_main:
        xor a
        ld (demo),a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (letters),a
        ld (lap),a
        ld (last_1up),a
        ld (gun_ammo),a
        ld (gun_lvl),a
        ld (shield),a
        ld a,(startst)
        ld (stage),a
        call start_lives
.st:    call run_stage
        ld a,(result)
        cp 2
        ret z                   ; quit to title
        or a
        jr nz,.over
        ; cleared
        ld a,(kind)
        or a
        call z,stage_tally
        ld a,(stage)
        inc a
        cp NSTAGES
        jr c,.nx
        call ending
        ld a,(lap)
        inc a
        cp 3
        jr c,$+4
        ld a,2
        ld (lap),a
        xor a
.nx:    ld (stage),a
        jr .st
.over:  call game_over
        jr nz,.done
        ; continue: same stage, fresh lives, score reset
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (last_1up),a
        call start_lives
        jr .st
.done:  jp check_hiscore

start_lives:
        ld a,(diff)
        ld b,a
        ld a,5
        sub b
        ld (lives),a            ; easy 5, normal 4, hard 3
        ret

; ---------------------------------------------------------------------
;  helpers for front-end screens
; ---------------------------------------------------------------------
; fe_clear: A = background colour index ; world 0 palette
fe_clear:
        push af
        xor a
        call apply_world
        pop af
        ld (fe_bg),a
        call colpat
        jp cls

; draw centred single-line string: HL = string, C = y
draw_str_c:
        ld a,1
        ld (txt_center),a
        call draw_str
        xor a
        ld (txt_center),a
        ret

; set text colours: A = fg, background = fe_bg
fe_txt:
        push bc
        ld b,a
        ld a,(fe_bg)
        ld c,a
        ld a,b
        call set_txt
        xor a
        ld (txt_mode),a
        pop bc
        ret

; fe_wait: B = frames; also animates via (fe_anim) callback. Z = fire pressed
fe_wait:
        push bc
        call sound_tick
        call frame_sync
        call read_input
        ld hl,(fe_anim)
        ld a,h
        or l
        call nz,.call
        pop bc
        ld a,(inp_new)
        and 1<<I_FIRE
        jr nz,.fire
        djnz fe_wait
        or 1
        ret
.fire:  xor a
        ret
.call:  jp (hl)

; big centred text: HL = string, C = y, A = fg pattern, (lg_sh) shadow
big_centred:
        ld (lg_fg),a
        push hl
        ld b,0
.l:     ld a,(hl)
        inc hl
        cp $FF
        jr z,.e
        inc b
        jr .l
.e:     pop hl
        ld a,b
        add a,a
        add a,a
        dec a                   ; width in bytes
        ld b,a
        ld a,32
        sub b
        srl a
        ld b,a
        jp draw_bigstr

; =====================================================================
;  TITLE
; =====================================================================
title_screen:
        ld a,2
        call fe_clear
        ld hl,mus_title
        ld de,mus_title_b
        ld a,2
        call play_music
        ; ATTACK OF THE
        ld a,1
        call fe_txt
        ld hl,s_attack
        ld c,0
        call draw_str_c
        ; KILLER (yellow, red bevel)
        ld a,$FF
        ld (lg_sh),a
        ld hl,big_killer
        ld c,7
        ld a,$55
        call big_centred
        ; TOMATOES (red, yellow bevel)
        ld a,$55
        ld (lg_sh),a
        ld hl,big_tomatoes
        ld b,0
        ld c,23
        ld a,$FF
        ld (lg_fg),a
        call draw_bigstr
        ; giant tomato
        call draw_big_tomato
        ; side text
        ld a,1
        call fe_txt
        ld hl,s_hi
        ld b,1
        ld c,42
        call draw_str
        ld hl,hiscores+3
        ld b,3
        ld de,VRAM+48*32+1
        call print_bcd
        ld a,3
        call fe_txt
        ld hl,s_resauced_short
        ld b,0
        ld c,53
        call draw_str
        call make_stars
        ld hl,title_anim
        ld (fe_anim),hl
        xor a
        ld (opt_show),a
        ld (drip_t),a
        ld hl,dripy
        ld b,8
.dz:    ld (hl),0
        inc hl
        djnz .dz
        ld b,0                  ; 256 frames
        call fe_wait
        jr z,.go
        ld b,0
        call fe_wait
        jr z,.go
        ld b,200
        call fe_wait
.go:    push af
        ld hl,0
        ld (fe_anim),hl
        call stop_music
        pop af
        ret

big_killer:   db G_K,G_I,G_L,G_L,G_E,G_R,$FF
big_tomatoes: db G_T,G_O,G_M,G_A,G_T,G_O,G_E,G_S,$FF

; title animation callback (every frame)
title_anim:
        call opt_keys
        ld a,(frame_cnt)
        ld c,a
        ; blinking PRESS FIRE + options on the right
        and 31
        jr nz,.nb
        ld a,(opt_show)
        or a
        jr z,.pf
        dec a
        ld (opt_show),a
        jr .nb
.pf:    ld a,(frame_cnt)
        and 32
        ld a,1
        jr z,$+4
        ld a,2
        call fe_txt
        ld hl,s_press
        ld b,24
        ld c,42
        call draw_str
        ld a,(frame_cnt)
        and 64
        jr nz,.o2
        ld hl,s_keys1
        jr .o3
.o2:    ld hl,s_keys2
.o3:    ld a,1
        call fe_txt
        ld b,24
        ld c,54
        call draw_str
.nb:    ; eyes & mouth every 4 frames
        ld a,(frame_cnt)
        and 3
        call z,tomato_face
        ; twinkle a star
        ld a,(frame_cnt)
        and 3
        jr nz,.nt
        ld a,16
        call rand_n
        add a,a
        ld hl,stars
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld b,(hl)
        inc hl
        ld c,(hl)
        call rand
        and 1
        inc a
        call pset
.nt:    ; drips
        call drips
        ; lightning
        ld a,(frame_cnt)
        or a
        ret nz
        call rand
        cp 100
        ret nc
        ld a,GFX|CSS
        call set_mode
        ld hl,sfx_thunder
        call play_sfx
        ld b,3
.lw:    push bc
        call frame_sync
        pop bc
        djnz .lw
        ld a,GFX
        jp set_mode

; make_stars: 16 stars in empty sky (bytes that are pure blue)
make_stars:
        ld de,stars
        ld b,16
.l:     push bc
.try:   ld a,128
        call rand_n
        ld b,a
        ld a,40
        call rand_n
        ld c,a
        call xyaddr
        ld a,(hl)
        cp $AA
        jr nz,.try
        ld a,b
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        push de
        ld a,1
        call pset
        pop de
        pop bc
        djnz .l
        ret

; ---- options on title: D difficulty, T trainer, L start stage ----
opt_keys:
        ld c,0
        ld a,($68FD)            ; D = row1 bit3
        bit 3,a
        jr nz,$+4
        set 0,c
        ld a,($68FE)            ; T = row0 bit0
        bit 0,a
        jr nz,$+4
        set 1,c
        ld a,($687F)            ; L = row7 bit1
        bit 1,a
        jr nz,$+4
        set 2,c
        ld a,(opt_prev)
        cpl
        and c
        ld b,a
        ld a,c
        ld (opt_prev),a
        ld a,b
        or a
        ret z
        bit 0,b
        jr z,.nd
        ld a,(diff)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (diff),a
.nd:    bit 1,b
        jr z,.nt
        ld a,(trainer)
        xor 1
        ld (trainer),a
.nt:    bit 2,b
        jr z,.show
        ld a,(startst)
        inc a
        cp NSTAGES
        jr c,$+3
        xor a
        ld (startst),a
.show:  ld a,4
        ld (opt_show),a
        ld hl,sfx_type
        call play_sfx
        ; options panel on the right
        ld b,24
        ld c,42
        ld d,8
        ld e,22
        ld a,$AA
        call fill_rect
        ld a,1
        call fe_txt
        ld hl,s_opt_diff
        ld b,24
        ld c,42
        call draw_str
        ld a,(diff)
        add a,a
        ld hl,diff_names
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,3
        call fe_txt
        ld b,24
        ld c,48
        call draw_str
        ld a,1
        call fe_txt
        ld hl,s_opt_train
        ld a,(trainer)
        or a
        jr nz,$+5
        ld hl,s_opt_normal
        ld b,24
        ld c,54
        call draw_str
        ld a,0
        call fe_txt
        ld hl,s_opt_start
        ld b,24
        ld c,59
        call draw_str
        ld hl,VRAM+59*32+29
        ld a,(startst)
        jp stage_label
diff_names: dw s_easy,s_normal,s_hard

; stage_label: A = stage index, HL = screen -> prints e.g. "1-2" / "1-B"
stage_label:
        push hl
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        add hl,de
        ld de,stage_tab
        add hl,de
        inc hl
        ld a,(hl)               ; world
        ld c,a
        inc hl
        ld a,(hl)               ; kind
        ld b,a
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)               ; siw
        pop hl
        push af
        ld a,b
        cp 2
        jr nz,.n
        pop af
        ld a,G_B
        call draw_char
        inc hl
        ld a,G_O
        call draw_char
        inc hl
        ld a,G_N
        jp draw_char
.n:     ld a,c
        add a,G_0+1
        call draw_char
        inc hl
        ld a,G_DASH
        call draw_char
        inc hl
        pop af
        ld c,a
        ld a,b
        or a
        ld a,G_B
        jr nz,.d
        ld a,c
        add a,G_0+1
.d:     jp draw_char

; ---- giant tomato: pre-rendered (tools/title_art.py) ----
draw_big_tomato:
        ld hl,tom_base
        ld b,TOMX
        ld c,TOMY
        ld d,TOMW
        ld e,TOMH
        jp blit
tomato_face:
        ; blink / look
        ld a,(look_t)
        dec a
        ld (look_t),a
        jr nz,.nl
        ld a,30
        ld (look_t),a
        ld a,5
        call rand_n
        cp 3
        jr c,$+4
        ld a,1
        ld (look),a
.nl:    ld a,(frame_cnt)
        and $7C
        cp $3C
        ld a,(look)
        jr nz,$+4
        ld a,3                  ; blink
        ld l,a
        ld h,0
        ld de,EYEW*EYEH
        call mul_hl_de_small
        ld de,tom_eyes
        add hl,de
        ld b,EYEX
        ld c,EYEY
        ld d,EYEW
        ld e,EYEH
        call blit
        ld a,(frame_cnt)
        and 16
        ld hl,tom_mouth0
        jr z,$+5
        ld hl,tom_mouth1
        ld b,MOUX
        ld c,MOUY
        ld d,MOUW
        ld e,MOUH
        jp blit
; HL = index (0..3), DE = size -> HL = index*size
mul_hl_de_small:
        ld a,l
        ld hl,0
        or a
        ret z
.l:     add hl,de
        dec a
        jr nz,.l
        ret
; blit: HL = src, B = xbyte, C = y, D = width bytes, E = rows
blit:
        push hl
        call xyaddr_b
        ex de,hl                ; DE = screen, H = w, L = rows
        ld b,h
        ld c,l
        pop hl
.r:     push bc
        push de
        ld c,b
        ld b,0
        ldir
        pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        dec c
        jr nz,.r
        ret

; drips under the TOMATOES letters (y 38..)
drips:
        ld hl,drip_t
        dec (hl)
        ret p
        ld (hl),3
        ld a,8
        call rand_n
        ld e,a
        ld d,0
        ld hl,dripy
        add hl,de
        ld a,(hl)
        inc a
        cp 5
        jr c,.grow
        ; reset drip: erase column
        ld (hl),0
        ld hl,dripx
        add hl,de
        ld b,(hl)
        ld c,38
.er:    push bc
        ld a,2
        call pset
        pop bc
        inc c
        ld a,c
        cp 43
        jr c,.er
        ret
.grow:  ld (hl),a
        add a,37
        ld c,a
        ld hl,dripx
        add hl,de
        ld b,(hl)
        ld a,3
        jp pset
dripx:  db 5,13,21,29,101,109,117,123

; =====================================================================
;  STORY
; =====================================================================
story:
        ld hl,story_pages
        ld b,4
.pg:    push bc
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,2
        call fe_clear
        call fe_border
        ld a,1
        call fe_txt
        ld a,2
        ld (str_delay),a
        pop hl
        ld b,2
        ld c,4
        call draw_str
        xor a
        ld (str_delay),a
        ld hl,story_anim
        ld (fe_anim),hl
        ld a,(frame_cnt)
        ld (march_x),a
        ld b,150
        call fe_wait
        ld hl,0
        ld (fe_anim),hl
        pop hl
        pop bc
        ret z
        inc hl
        inc hl
        djnz .pg
        or 1
        ret
story_pages: dw s_story1,s_story2,s_story3,s_story4

; red frame + floor strip
fe_border:
        ld a,$FF
        ld b,0
        ld c,0
        ld d,32
        ld e,2
        call fill_rect
        ld a,$FF
        ld b,0
        ld c,62
        ld d,32
        ld e,2
        call fill_rect
        ld a,$00
        ld b,0
        ld c,54
        ld d,32
        ld e,1
        jp fill_rect

; marching tomatoes chasing Mason along y=56
story_anim:
        ld a,(frame_cnt)
        and 1
        ret nz
        xor a
        ld b,0
        ld c,55
        ld d,32
        ld e,7
        call fill_rect
        ld a,(march_x)
        inc a
        inc a
        ld (march_x),a
        and $FE
        ld b,a
        ld c,56
        ld hl,spr_PR1
        ld a,(frame_cnt)
        and 8
        jr z,$+5
        ld hl,spr_PR2
        call spr_clip
        ld a,(march_x)
        sub 20
        and $FE
        ld b,a
        ld hl,spr_CH1
        call walk_alt
        call spr_clip
        ld a,(march_x)
        sub 34
        and $FE
        ld b,a
        ld hl,spr_RO1
        call walk_alt
        call spr_clip
        ld a,(march_x)
        sub 50
        and $FE
        ld b,a
        ld hl,spr_BF1
        call walk_alt
        jp spr_clip
walk_alt:
        ld a,(frame_cnt)
        and 8
        ret z
        ld de,10
        add hl,de
        ret
; spr_clip: draw sprite only if x in 0..120
spr_clip:
        ld a,b
        cp 121
        ret nc
        ld c,56
        push ix
        call draw_spr
        pop ix
        ret

; =====================================================================
;  CAST / BOSSES / POWER-UPS
; =====================================================================
cast_screens:
        ld hl,cast1
        call cast_page
        ret z
        ld hl,cast2
        call cast_page
        ret z
        call boss_page
        ret z
        jp power_page

; cast_page: HL = list of (sprite, sprite2, string) x4
cast_page:
        push hl
        ld a,2
        call fe_clear
        ld a,1
        call fe_txt
        ld hl,s_cast
        ld c,1
        call draw_str_c
        pop hl
        ld (cast_ptr),hl
        ld c,9
        ld b,4
.r:     push bc
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld b,4
        call draw_str
        pop hl
        inc hl
        pop bc
        ld a,c
        add a,14
        ld c,a
        djnz .r
        ld hl,cast_anim
        ld (fe_anim),hl
        call cast_anim0
        ld b,200
        call fe_wait
        push af
        ld hl,0
        ld (fe_anim),hl
        pop af
        ret
cast_anim:
        ld a,(frame_cnt)
        and 7
        ret nz
cast_anim0:
        ld hl,(cast_ptr)
        ld c,9
        ld b,4
.r:     push bc
        push hl
        ld a,(frame_cnt)
        and 8
        jr z,.f1
        inc hl
        inc hl
.f1:    ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        push bc
        ld b,0
        ld d,3
        ld e,5
        ld a,(fe_bg)
        call colpat
        call fill_rect
        pop bc
        pop hl
        ld b,4
        push ix
        call draw_spr
        pop ix
        pop hl
        ld de,6
        add hl,de
        pop bc
        ld a,c
        add a,14
        ld c,a
        djnz .r
        ret
cast1:  dw spr_CH1,spr_CH2,s_c1, spr_RO1,spr_RO2,s_c2, spr_BF1,spr_BF2,s_c3, spr_UN1,spr_UN2,s_c4
cast2:  dw spr_GO1,spr_GO2,s_c5, spr_HOP1,spr_HOP2,s_c6, spr_ROT1,spr_ROT2,s_c7, spr_BALL1,spr_BALL2,s_c8

boss_page:
        ld a,0
        call fe_clear
        ld a,3
        call fe_txt
        ld hl,s_wanted
        ld c,1
        call draw_str_c
        ld b,4
        ld c,9
        ld hl,spr_MAMA1
        ld a,4
        ld ixh,10
        call draw_big
        ld b,4
        ld c,25
        ld hl,spr_BARON1
        ld a,4
        ld ixh,10
        call draw_big
        ld b,4
        ld c,44
        ld hl,spr_GREAT1
        ld a,6
        ld ixh,15
        call draw_big
        ld a,2
        call fe_txt
        ld hl,s_b1
        ld b,7
        ld c,10
        call draw_str
        ld hl,s_b2
        ld b,7
        ld c,26
        call draw_str
        ld hl,s_b3
        ld b,9
        ld c,46
        call draw_str
        ld b,200
        jp fe_wait

power_page:
        ld a,0
        call fe_clear
        ld a,2
        call fe_txt
        ld hl,s_pow
        ld c,0
        call draw_str_c
        ld hl,pow_list
        ld c,7
        ld b,8
.r:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        push de
        push bc
        ld b,4
        call draw_str
        pop bc
        pop hl
        ld b,4
        push ix
        call draw_spr
        pop ix
        pop hl
        inc hl
        pop bc
        ld a,c
        add a,7
        ld c,a
        djnz .r
        ld b,220
        jp fe_wait
pow_list: dw tl_T_GUN,s_p1, tl_T_SNEAK,s_p2, tl_T_RECORD,s_p3, tl_T_X2,s_p4
          dw tl_T_COLAND,s_p5, tl_T_DISG,s_p6, tl_T_CAN,s_p7, tl_T_LS,s_p8

; =====================================================================
;  DEMO
; =====================================================================
demo_play:
        ld a,1
        ld (demo),a
        ld a,5
        call rand_n
        ld hl,demo_stages
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (stage),a
        ld a,1
        ld (lives),a
        xor a
        ld (gun_ammo),a
        ld (gun_lvl),a
        ld (shield),a
        ld (demo_key),a
        ld hl,1000
        ld (demo_timer),hl
        call run_stage
        xor a
        ld (demo),a
        call stop_music
        ld a,(demo_key)
        or a
        jr z,.nk
        xor a                   ; key pressed -> start game
        ret
.nk:    or 1
        ret
demo_stages: db 0,1,5,6,10

; =====================================================================
;  HIGH SCORES
; =====================================================================
init_hiscores:
        ld hl,hi_default
        ld de,hiscores
        ld bc,48
        ldir
        ret
hi_default:
        db G_M,G_A,G_S, $02,$50,$00
        db G_L,G_O,G_I, $02,$00,$00
        db G_S,G_A,G_M, $01,$50,$00
        db G_F,G_I,G_N, $01,$00,$00
        db G_A,G_P,G_O, $00,$75,$00
        db G_B,G_P,G_M, $00,$50,$00
        db G_V,G_Z,G_SP,$00,$25,$00
        db G_J,G_I,G_M, $00,$10,$00

hiscore_screen:
        ld a,2
        call fe_clear
        ld hl,mus_title
        ld de,mus_title_b
        ld a,2
        call play_music
        call draw_hiscores
        ld hl,story_anim
        ld (fe_anim),hl
        ld b,250
        call fe_wait
        push af
        ld hl,0
        ld (fe_anim),hl
        call stop_music
        pop af
        ret
draw_hiscores:
        ld a,1
        call fe_txt
        ld hl,s_hiscores
        ld c,1
        call draw_str_c
        ld hl,hiscores
        ld c,9
        ld b,1
.r:     push bc
        push hl
        ld a,(hi_rank)
        cp b
        ld a,1
        jr nz,$+4
        ld a,3
        call fe_txt
        pop de                  ; entry ptr
        pop bc
        push bc
        push de
        ld a,c
        call yaddr
        ld de,8
        add hl,de
        ld a,b
        add a,G_0
        call draw_char
        pop de
        push de
        inc hl
        inc hl
        ld b,3
.n:     ld a,(de)
        inc de
        push bc
        push de
        call draw_char
        pop de
        pop bc
        inc hl
        djnz .n
        inc hl
        inc hl
        ex de,hl
        ld b,3
        call print_bcd
        pop hl
        ld de,6
        add hl,de
        pop bc
        ld a,c
        add a,6
        ld c,a
        inc b
        ld a,b
        cp 9
        jr c,.r
        ret

; check_hiscore: insert score if it qualifies, name entry
check_hiscore:
        xor a
        ld (hi_rank),a
        ld a,(trainer)
        or a
        ret nz
        ld hl,hiscores+3
        ld b,8
        ld c,1
.f:     push hl
        ld de,score
        ld a,(de)
        cp (hl)
        jr nz,.cmp
        inc de
        inc hl
        ld a,(de)
        cp (hl)
        jr nz,.cmp
        inc de
        inc hl
        ld a,(de)
        cp (hl)
.cmp:   pop hl
        jr z,.nx
        jr nc,.ins
.nx:    ld de,6
        add hl,de
        inc c
        djnz .f
        ret
.ins:   ld a,c
        ld (hi_rank),a
        ; shift entries down from rank
        ld a,8
        sub c
        jr z,.last
        ld b,a
        ld hl,hiscores+6*7-1
        ld de,hiscores+6*8-1
.sh:    push bc
        ld bc,6
        lddr
        pop bc
        djnz .sh
.last:  ld a,(hi_rank)
        dec a
        ld l,a
        add a,a
        add a,l
        add a,a
        ld hl,hiscores
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hi_ptr),hl
        ld (hl),G_A
        inc hl
        ld (hl),G_A
        inc hl
        ld (hl),G_A
        inc hl
        ld a,(score)
        ld (hl),a
        inc hl
        ld a,(score+1)
        ld (hl),a
        inc hl
        ld a,(score+2)
        ld (hl),a
        jp enter_name

enter_name:
        ld a,2
        call fe_clear
        ld hl,mus_bonus
        ld de,mus_title_b
        ld a,2
        call play_music
        ld a,1
        call fe_txt
        ld hl,s_newhi
        ld b,6
        ld c,4
        call draw_str
        xor a
        ld (name_pos),a
.lp:    ; draw letters big
        ld hl,(hi_ptr)
        ld a,(hl)
        ld (name_buf),a
        inc hl
        ld a,(hl)
        ld (name_buf+1),a
        inc hl
        ld a,(hl)
        ld (name_buf+2),a
        ld a,$FF
        ld (name_buf+3),a
        ld a,$AA
        ld b,9
        ld c,28
        ld d,14
        ld e,22
        call fill_rect
        ld a,$55
        ld (lg_fg),a
        ld a,$FF
        ld (lg_sh),a
        ld hl,name_buf
        ld b,10
        ld c,30
        call draw_bigstr
        ; cursor under current letter
        ld a,(frame_cnt)
        and 8
        jr z,.nc
        ld a,(name_pos)
        add a,a
        add a,a
        add a,10
        ld b,a
        ld c,47
        ld d,3
        ld e,2
        ld a,$FF
        call fill_rect
.nc:    call sound_tick
        call frame_sync
        call read_joy_only
        push bc
        call scan_letter        ; A = glyph of a newly pressed letter key, or 0
        pop bc
        ld hl,(hi_ptr)
        ld e,a
        ld a,(name_pos)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,e
        or a
        jr z,.nk
        ld (hl),a
        ld c,1<<I_FIRE          ; typed: advance
        jr .nd
.nk:    bit I_UP,c
        jr z,.nu
        ld a,(hl)
        inc a
        cp G_Z+1
        jr c,$+4
        ld a,G_A
        ld (hl),a
        call .tick
.nu:    bit I_DN,c
        jr z,.nd
        ld a,(hl)
        dec a
        cp G_A
        jr nc,$+4
        ld a,G_Z
        ld (hl),a
        call .tick
.nd:    ld a,c
        and (1<<I_FIRE)|(1<<I_RT)
        jp z,.lp
        call .tick
        ld a,(name_pos)
        inc a
        ld (name_pos),a
        cp 3
        jp c,.lp
        call stop_music
        jp hiscore_screen
.tick:  push hl
        push bc
        ld hl,sfx_type
        call play_sfx
        pop bc
        pop hl
        ret

; read_joy_only: C = new presses from joysticks + RETURN/SPACE as fire (no letter keys)
read_joy_only:
        ld c,0
        ld a,($68BF)            ; RETURN
        bit 2,a
        jr nz,$+4
        set I_FIRE,c
        ld a,($68EF)            ; SPACE
        bit 4,a
        jr nz,$+4
        set I_FIRE,c
        ld a,(joy_on)
        or a
        jr z,.e
        in a,($2C)
        cpl
        and $0F
        or c
        ld c,a
        in a,($2E)
        bit 4,a
        jr nz,$+4
        set I_FIRE,c
        ld a,(joy_on)
        cp 2
        jr nz,.e
        in a,($29)
        cpl
        and $0F
        or c
        ld c,a
        in a,($2B)
        bit 4,a
        jr nz,$+4
        set I_FIRE,c
.e:     ld a,(jprev)
        cpl
        and c
        ld b,a
        ld a,c
        ld (jprev),a
        ld c,b
        ret

; scan_letter: returns A = glyph of a letter key newly pressed (edge), else 0
scan_letter:
        xor a
        ld (kl_new),a
        ld hl,keytab
        ld de,$68FE
        ld b,8
.r:     push bc
        ld a,(de)
        ld c,a
        ld b,6
.k:     srl c
        jr c,.n
        ld a,(hl)
        or a
        jr z,.n
        ld (kl_new),a
.n:     inc hl
        djnz .k
        pop bc
        scf
        rl e
        djnz .r
        ld a,(kl_new)
        ld hl,kl_last
        cp (hl)
        ld (hl),a
        ret nz
        xor a
        ret
keytab: ; per row, bits 0..5
        db G_T,G_W,0,G_E,G_Q,G_R
        db G_G,G_S,0,G_D,G_A,G_F
        db G_B,G_X,0,G_C,G_Z,G_V
        db 0,0,0,0,0,0
        db G_N,0,0,0,0,G_M
        db 0,0,0,0,0,0
        db G_Y,G_O,0,G_I,G_P,G_U
        db G_H,G_L,0,G_K,0,G_J

; =====================================================================
;  STAGE INTRO CARD
; =====================================================================
stage_intro:
        ld a,(demo)
        or a
        ret nz
        ; palette of the coming world
        ld a,(stage)
        ld (tmp+3),a
        call stage_entry        ; HL -> entry
        inc hl
        ld a,(hl)               ; world
        ld (fe_world),a
        inc hl
        ld a,(hl)
        ld (fe_kind),a
        ld a,(fe_world)
        call apply_world
        ld a,7
        call wget
        ld (fe_bg),a
        call colpat
        call cls
        ld a,0
        ld c,0
        ld b,0
        ld d,32
        ld e,1
        ld a,$FF
        call fill_rect
        ; world banner
        ld a,8
        call wget
        call fe_txt
        ld a,(fe_kind)
        cp 2
        jr z,.bon
        ld a,(fe_world)
        add a,a
        ld hl,world_names
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,2
        call draw_str_c
        ; big stage label
        ld a,(fe_kind)
        or a
        ld hl,big_boss
        jr nz,.bl
        ld hl,big_lbl
        ld a,(fe_world)
        add a,G_0+1
        ld (hl),a
        ld a,(stage)
        call stage_entry
        ld de,6
        add hl,de
        ld a,(hl)
        add a,G_0+1
        ld (big_lbl+2),a
        ld hl,big_lbl
.bl:    ld a,$FF
        ld (lg_sh),a
        ld c,16
        ld a,$55
        call big_centred
        jr .name
.bon:   ld hl,s_bonus
        ld b,4
        ld c,4
        call draw_str
.name:  ; stage name + tip
        ld a,8
        call wget
        call fe_txt
        ld a,(stage)
        call stage_entry
        ld de,7
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld c,34
        call draw_str_c
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld a,(fe_bg)
        xor 2
        and 3
        ld a,1
        call fe_txt
        ld b,2
        ld c,42
        call draw_str
        pop hl
        ; tonight's menu: unique enemy types from waves
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (menu_ptr),de
        ld a,(fe_kind)
        cp 1
        jr z,.boss
        cp 2
        jp z,.go
        xor a
        ld (seen_types),a
        ld a,4
        ld (menu_x),a
.ml:    ld hl,(menu_ptr)
        ld a,(hl)
        cp $FF
        jp z,.go
        inc hl
        inc hl
        inc hl
        ld (menu_ptr),hl
        and $7F
        sub T_CHERRY
        ld (tmp),a
        ld b,a
        inc b
        ld a,1
.sb:    dec b
        jr z,.sd
        add a,a
        jr .sb
.sd:    ld b,a
        ld a,(seen_types)
        and b
        jr nz,.ml
        ld a,(seen_types)
        or b
        ld (seen_types),a
        ld a,(tmp)
        add a,a
        add a,a
        ld hl,walk_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(menu_x)
        ld b,a
        add a,12
        ld (menu_x),a
        ld c,55
        push ix
        call draw_spr
        pop ix
        jr .ml
.boss:  ld a,(stage)
        call stage_entry
        ld de,5
        add hl,de
        ld a,(hl)               ; boss id
        cp 3
        jr z,.b3
        dec a
        add a,a
        add a,a
        ld hl,boss_tab
        add a,l
        ld l,a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,56
        ld c,48
        ld a,4
        ld ixh,10
        call draw_big
        jr .go
.b3:    ld hl,spr_GREAT1
        ld b,52
        ld c,47
        ld a,6
        ld ixh,15
        call draw_big
.go:    ld hl,sfx_armed
        call play_sfx
        ld b,150
        call wait_frames
        ret

stage_entry:                    ; A = stage -> HL = entry
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        add hl,de
        ld de,stage_tab
        add hl,de
        ret
world_names: dw s_world1,s_world2,s_world3
big_lbl: db 0,G_DASH,0,$FF
big_boss: db G_B,G_O,G_S,G_S,G_EXCL,$FF

; =====================================================================
;  STAGE TALLY (after a normal stage)
; =====================================================================
stage_tally:
        ld hl,mus_clear
        ld de,0
        ld a,1
        call play_music
        ld b,4
        ld c,22
        ld d,24
        ld e,30
        call draw_box
        call hud_colours
        ld hl,s_clear
        ld c,25
        call draw_str_c
        ; time bonus: remaining half-seconds * 20
        ld a,(hurry_t)
        add a,a
        ld hl,stime
        sub (hl)
        jr nc,$+3
        xor a
        ld (tmp+3),a
        ld hl,s_tbonus
        ld b,6
        ld c,33
        call draw_str
.tb:    ld a,(tmp+3)
        or a
        jr z,.td
        dec a
        ld (tmp+3),a
        ld de,$0020
        call add_score
        ld a,(tmp+3)
        and 3
        jr nz,.tb
        ld hl,sfx_type
        call play_sfx
        call draw_hud
        call sound_tick
        call frame_sync
        jr .tb
.td:    ld a,(damaged)
        or a
        jr nz,.wt
        ld hl,s_nodmg
        ld b,6
        ld c,41
        call draw_str
        ld de,$2000
        call add_score
        call draw_hud
.wt:    ld b,120
        jp wait_frames

; =====================================================================
;  GAME OVER (Z = continue)
; =====================================================================
game_over:
        ld hl,mus_over
        ld de,0
        ld a,1
        call play_music
        ld a,2
        call fe_clear
        ld a,$55
        ld (lg_sh),a
        ld hl,big_game
        ld c,3
        ld a,$FF
        call big_centred
        ld hl,big_over
        ld c,20
        ld a,$FF
        call big_centred
        ld hl,spr_GREAT2
        ld b,52
        ld c,38
        ld a,6
        ld ixh,15
        call draw_big
        ld a,1
        call fe_txt
        ld hl,s_haha
        ld b,22
        ld c,40
        call draw_str
        ld a,9
        ld (tmp+3),a
.cd:    ld a,1
        call fe_txt
        ld hl,s_continue
        ld b,1
        ld c,57
        call draw_str
        ld hl,VRAM+57*32+19
        ld a,(tmp+3)
        call print_dig
        ld b,50
        call wait_frames
        ret z
        ld a,(tmp+3)
        dec a
        ld (tmp+3),a
        jr nz,.cd
        or 1
        ret
big_game: db G_G,G_A,G_M,G_E,$FF
big_over: db G_O,G_V,G_E,G_R,$FF

; =====================================================================
;  ENDING
; =====================================================================
ending:
        ld hl,mus_end
        ld de,mus_title_b
        ld a,2
        call play_music
        ld hl,end_pages
        ld b,4
.pg:    push bc
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,0
        call fe_clear
        call fe_border
        ld a,1
        call fe_txt
        ld a,2
        ld (str_delay),a
        pop hl
        ld b,2
        ld c,4
        call draw_str
        xor a
        ld (str_delay),a
        pop hl
        pop bc
        push bc
        push hl
        ld a,b
        cp 2
        jr nz,.nc
        ; the carrot rises...
        ld b,6
.cr:    push bc
        push bc
        ld b,15
        ld c,40
        ld d,2
        ld e,12
        xor a
        call fill_rect
        pop bc
        ld a,b
        add a,40
        ld c,a
        ld b,60
        ld hl,spr_CARROT
        push ix
        call draw_spr
        pop ix
        ld b,12
        call wait_frames
        pop bc
        djnz .cr
.nc:    ld b,200
        call wait_frames
        pop hl
        pop bc
        inc hl
        inc hl
        djnz .pg
        ; lap message
        ld a,1
        call fe_clear
        ld a,2
        call fe_txt
        ld hl,s_lap2
        ld b,4
        ld c,24
        call draw_str
        ld b,150
        jp wait_frames
end_pages: dw s_end1,s_end2,s_end3,s_end4
