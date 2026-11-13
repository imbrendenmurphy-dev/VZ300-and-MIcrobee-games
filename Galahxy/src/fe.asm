; =====================================================================
;  fe.asm - front end (GLXCOM.DAT, upper bank 1): title, high scores,
;  cast select, name entry and the attract cycle
; =====================================================================
HI_N        equ 8
HI_SZ       equ 6              ; 3 bytes BCD score, 3 letters

; ---------------------------------------------------------------------
; make sure stage 1 is in memory (for the title backdrop and the demo)
; ---------------------------------------------------------------------
fe_stage1:
            ld a,1
            ld (stage_no),a
            ld a,(stage_ld)
            cp 1
            ret z
            call loading_card
            ld a,1
            ld (stage_ld),a
            ld a,'1'
            ld (n_stage+5),a
            ld hl,n_stage
            call sd_load
            ret nc
            xor a
            ld (stage_ld),a
            ld hl,str_nostage
            jp fatal
str_nostage: db "CAN'T LOAD GLXS1.DAT",0

; ---------------------------------------------------------------------
title_screen:
            ld sp,STACK_TOP
            xor a
            ld (demo_on),a
            ld (trainer),a
            call fe_stage1
            call STG_INIT
            call scroll_init
            call clear_objs
            call silence
            ld hl,tune_title
            call music
            ld a,1
            ld (hud_dirty),a
            xor a
            ld (boss_bar),a
            ld (p_shot),a
            ld (p_buddy),a
            ld (p_speed),a
            ld (p_char),a
            ld (p_inv),a
            ld (p_dead),a
            ld (p_shield),a
            ld a,10+XOFF
            ld (p_x),a
            ld a,30+YOFF
            ld (p_y),a
            ld hl,0
            ld (fe_t),hl
            ld a,2
            ld (minfields),a
            ld hl,str_credit
            call bar_msg
.loop:      call read_input
            call key_n
            jr z,.nk
            ld a,(music_off)
            xor 1
            ld (music_off),a
.nk:        call scroll_step
            ; the hero loops about, showing off; a new cast member every 256 frames
            ld hl,(fe_t)
            inc hl
            ld (fe_t),hl
            ld a,l
            add a,a
            and 63
            ld e,a
            ld d,0
            ld hl,sine16
            add hl,de
            ld a,(hl)
            sra a
            sra a
            add a,38+YOFF
            ld (p_y),a
            ld a,(fe_t)
            and 127
            cp 64
            jr c,.px
            cpl
            and 63
.px:        add a,4+XOFF
            ld (p_x),a
            ld hl,(fe_t)
            ld a,l
            and 7
            jr nz,.nf
            ld a,(p_x)
            ld b,a
            ld a,(p_y)
            ld c,a
            call fire_main
.nf:        ld hl,(fe_t)
            ld a,l
            or a
            jr nz,.nc
            ld a,(p_char)           ; every 256 frames: the next character
            inc a
            cp 3
            jr c,.c3
            xor a
.c3:        ld (p_char),a
.nc:        call pshots_update
            call sound_tick
            ; draw
            call bb_wait
            call draw_bg
            call draw_logo
            call draw_pshots
            call draw_player
            ; PRESS FIRE (blinking) on a blue strip
            ld a,(frames)
            and 16
            jr z,.nb
            ld a,27
            ld b,7
            ld c,$AA
            call band_bb
            ld a,1
            ld c,2
            call text_col
            ld hl,str_press
            ld a,28
            call small_centre
.nb:        call draw_hud
            call present
            ld a,(in_new)
            and K_FIRE|K_ARM
            jp nz,cast_select
            ld hl,(fe_t)
            ld de,700
            or a
            sbc hl,de
            jp c,.loop
            ; time out: high scores, then the demo
            call hi_table
            jp c,cast_select
            jp attract
str_credit: db "VIBED BY BPM 2026",0
str_press:  db "PRESS FIRE",0

; HL = string: the bottom bar (VRAM rows 56-63) in red with it centred
bar_msg:
            push hl
            ld hl,VRAM+BAR_ROW*32
            ld de,VRAM+BAR_ROW*32+1
            ld bc,255
            ld (hl),$FF
            ldir
            ld a,1
            ld c,3
            call text_col
            pop hl
            call strlen
            ld b,a
            ld a,32
            sub b
            srl a
            ld e,a
            ld d,0
            push hl
            ld hl,VRAM+(BAR_ROW+2)*32
            add hl,de
            ex de,hl
            pop hl
            jp print

; the GALAHXY logo (LOGO_H rows of 32 bytes) at row 9, with a bob
draw_logo:
            ld hl,logo_data
            ld de,9*32
            call bbde
            ld bc,LOGO_H*32
            ldir
            ret

; ---------------------------------------------------------------------
; high-score table. C = fire was pressed
; ---------------------------------------------------------------------
hi_table:
            ld hl,str_credit
            call bar_msg
            call bb_wait
            ld a,$AA
            call cls_bb
            ld a,6
            ld b,9
            ld c,$FF
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,str_best
            ld a,8
            call small_centre
            ld hl,HISCORES+2
            ld de,16*32+7
            call bbde
            ld b,HI_N
            ld c,1                  ; rank
.r:         push bc
            push hl
            push de
            ld a,b
            and 1
            jr z,.ink               ; alternate yellow and green lines
            ld a,1
.ink:       ld c,2
            call text_col
            pop de
            pop hl
            pop bc
            push bc
            ld a,c
            add a,'0'
            push hl
            call putc
            inc de
            inc de
            pop hl
            push hl
            push de
            call print_score
            pop de
            ld a,e
            add a,9
            ld e,a
            pop hl
            inc hl
            inc hl
            inc hl
            ld b,3
.nm:        ld a,(hl)
            push hl
            push bc
            call putc
            pop bc
            pop hl
            inc hl
            inc de
            djnz .nm
            ld a,e                  ; next line, 5 rows down
            sub 14
            ld e,a
            jr nc,.n0
            dec d
.n0:        push hl
            ld hl,32*5
            add hl,de
            ex de,hl
            pop hl
            pop bc
            inc c
            djnz .r
            call present
            ld b,0
.w:         push bc
            ld a,1
            call wait_fields
            call read_input
            call sound_tick
            pop bc
            ld a,(in_new)
            and K_FIRE|K_ARM
            scf
            ret nz
            djnz .w
            or a
            ret
str_best:   db "TOP GALAHS",0

; ---------------------------------------------------------------------
; the attract demo: the autopilot plays stage 1 for a while
; ---------------------------------------------------------------------
attract:
            ld a,1
            ld (demo_on),a
            ld hl,1500
            ld (demo_t),hl
            ld hl,attract_n
            ld a,(hl)
            inc (hl)
            call random
            and 3
            cp 3
            jr c,.c
            xor a
.c:         push af
            ld a,1
            ld (diff),a
            pop af
            call new_game
            xor a
            ld (demo_on),a
            ld (demo_in),a
            ld a,(in_demokey)
            or a
            jp nz,cast_select
            jp title_screen

; ---------------------------------------------------------------------
; cast select: left/right picks a flyer, up/down the difficulty
; ---------------------------------------------------------------------
cast_select:
            call silence
            ld hl,tune_select
            call music
            ld a,(fe_sel)
            cp 3
            jr c,.s
            xor a
            ld (fe_sel),a
.s:         call clear_objs
            ld hl,0
            ld (fe_t),hl
.loop:      call read_input
            call sound_tick
            ld a,(in_new)
            bit 2,a
            jr z,.nl
            ld hl,fe_sel
            ld a,(hl)
            or a
            jr z,.nl
            dec (hl)
            ld a,SFX_MENU
            call sfx
.nl:        ld a,(in_new)
            bit 3,a
            jr z,.nr
            ld hl,fe_sel
            ld a,(hl)
            cp 2
            jr nc,.nr
            inc (hl)
            ld a,SFX_MENU
            call sfx
.nr:        ld a,(in_new)
            bit 0,a
            jr z,.nu
            ld hl,diff
            ld a,(hl)
            or a
            jr z,.nu
            dec (hl)
            ld a,SFX_MENU
            call sfx
.nu:        ld a,(in_new)
            bit 1,a
            jr z,.nd
            ld hl,diff
            ld a,(hl)
            cp 2
            jr nc,.nd
            inc (hl)
            ld a,SFX_MENU
            call sfx
.nd:        ld a,($68FE)            ; T: trainer (endless lives, no high score)
            cpl
            and 1
            ld hl,fe_sub
            ld b,(hl)
            ld (hl),a
            jr z,.nt
            cp b
            jr z,.nt
            ld a,(trainer)
            xor 1
            ld (trainer),a
            ld a,SFX_SECRET
            call sfx
.nt:        ; the chosen flyer shows off in the arena strip at the bottom
            ld a,(fe_sel)
            ld (p_char),a
            ld hl,(fe_t)
            inc hl
            ld (fe_t),hl
            ld a,l
            and 7
            jr nz,.nf
            ld a,6+XOFF
            ld b,a
            ld a,46+YOFF
            ld c,a
            call fire_main
.nf:        call pshots_update
            ; ---- draw
            call bb_wait
            ld a,$AA
            call cls_bb
            ld a,6
            ld b,9
            ld c,$FF
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,str_pick
            ld a,7
            call small_centre
            ld hl,str_pick2
            ld a,13
            ld c,3
            call small_centre
            ; three portraits
            ld b,0
.pp:        push bc
            ld a,b
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a                 ; 32 px apart... (x = 20 + 40*i)
            ld c,a
            ld a,b
            add a,a
            add a,a
            add a,a
            add a,c
            add a,18+XOFF
            ld (work),a
            ld a,(fe_sel)
            cp b
            jr nz,.nfr
            ; selected: yellow frame
            ld a,(work)
            sub XOFF+4
            rrca
            rrca
            and $3F
            ld e,a
            ld d,0
            ld hl,18*32
            call bbp
            add hl,de
            ld b,16
.fr:        ld (hl),$00
            inc hl
            ld (hl),$00
            inc hl
            ld (hl),$00
            inc hl
            ld (hl),$00
            inc hl
            ld (hl),$00
            inc hl
            ld (hl),$00
            ld de,32-5
            add hl,de
            djnz .fr
.nfr:       pop bc
            push bc
            ld a,b
            add a,SPR_BIGGAZ
            ld e,a
            ld a,(work)
            ld b,a
            ld c,20+YOFF
            ld a,e
            call blit
            pop bc
            inc b
            ld a,b
            cp 3
            jr nz,.pp
            ; name and weapons of the chosen one
            ld a,1
            ld c,2
            call text_col
            ld a,(fe_sel)
            add a,a
            ld e,a
            ld d,0
            ld hl,cast_txt
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            push hl
            ld a,36
            call small_centre
            pop hl
            call strlen
            inc a
            ld e,a
            ld d,0
            add hl,de
            push hl
            ld a,0
            ld c,2
            call text_col
            pop hl
            push hl
            ld a,42
            call small_centre
            pop hl
            call strlen
            inc a
            ld e,a
            ld d,0
            add hl,de
            ld a,48
            call small_centre
            call draw_pshots
            ; difficulty strip
            ld a,(diff)
            add a,a
            ld e,a
            ld d,0
            ld hl,diff_txt
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld a,(trainer)
            or a
            jr z,.ntr
            ld hl,str_trainer
.ntr:       call bar_msg
            call present
            ld a,(in_new)
            and K_FIRE|K_ARM
            jp z,.loop
            ; go!
            call silence
            ld a,SFX_START
            call sfx
            ld a,(fe_sel)
            call new_game
            ld a,(trainer)
            or a
            call z,hi_enter
            jp title_screen

str_pick:   db "PICK YOUR FLYER",0
str_trainer: db "TRAINER: NO HIGH SCORE",0
str_pick2:  db "< > CHOOSE   ^ v SKILL   FIRE GO",0
cast_txt:   dw ct_gaz, ct_cup, ct_toast
ct_gaz:     db "GAZZA THE GALAH",0,"SHOT: SPREADING SEEDS",0,"BOMB: MACADAMIA DROP",0
ct_cup:     db "CAPTAIN CUPPA",0,"SHOT: PIERCING STEAM",0,"BOMB: TEA BAGS UP+DOWN",0
ct_toast:   db "TOASTIE",0,"SHOT: TOAST FRONT+BACK",0,"BOMB: VEGEMITE SEEKERS",0
diff_txt:   dw dt_e, dt_n, dt_h
dt_e:       db "SKILL: CRUISY (5 LIVES)",0
dt_n:       db "SKILL: FAIR DINKUM",0
dt_h:       db "SKILL: FLAT OUT",0



; shop strings (the shop code is in main RAM)
si_speed:   db "SPEED UP",0
si_bomb:    db "BOMBS",0
si_shot:    db "BIGGER SHOT",0
si_buddy:   db "A BUDDY CHICK",0
si_shield:  db "BUBBLE SHIELD",0
si_heart:   db "CUPCAKE (HEARTS)",0
si_life:    db "EXTRA LIFE",0
si_exit:    db "BACK TO THE PARTY",0
str_shop:   db "WELCOME TO THE SHOP! COINS",0
str_shopbar: db "FIRE BUY   ^ v CHOOSE",0
