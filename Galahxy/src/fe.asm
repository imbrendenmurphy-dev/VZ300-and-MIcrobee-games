; =====================================================================
;  fe.asm - front end (GLXCOM.DAT, upper bank 1): title, high scores,
;  cast select, name entry and the attract cycle
; =====================================================================
HI_N        equ 8
HI_SZ       equ 6              ; 3 bytes BCD score, 3 letters

hi_init:
            ld a,(HISCORES)
            cp 'G'
            jr nz,.new
            ld a,(HISCORES+1)
            cp 'X'
            jr z,.ok
.new:       ld hl,hi_default
            ld de,HISCORES
            ld bc,2+HI_N*HI_SZ
            ldir
.ok:        ld hl,HISCORES+2
            ld de,hiscore
            ld bc,3
            ldir
            ret
hi_default: db "GX"
            db $00,$50,$00,"BPM"
            db $00,$40,$00,"GAZ"
            db $00,$30,$00,"CUP"
            db $00,$25,$00,"TST"
            db $00,$20,$00,"PAV"
            db $00,$15,$00,"SNG"
            db $00,$10,$00,"ESK"
            db $00,$05,$00,"MAG"

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
.nd:        ; the chosen flyer shows off in the arena strip at the bottom
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
            call bar_msg
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
            call hi_enter
            jp title_screen

str_pick:   db "PICK YOUR FLYER",0
str_pick2:  db "< > CHOOSE   ^ v SKILL   FIRE GO",0
cast_txt:   dw ct_gaz, ct_cup, ct_toast
ct_gaz:     db "GAZZA THE GALAH",0,"SHOT: SPREADING SEEDS",0,"BOMB: MACADAMIA DROP",0
ct_cup:     db "CAPTAIN CUPPA",0,"SHOT: PIERCING STEAM",0,"BOMB: TEA BAGS UP+DOWN",0
ct_toast:   db "TOASTIE",0,"SHOT: TOAST FRONT+BACK",0,"BOMB: VEGEMITE SEEKERS",0
diff_txt:   dw dt_e, dt_n, dt_h
dt_e:       db "SKILL: CRUISY (5 LIVES)",0
dt_n:       db "SKILL: FAIR DINKUM",0
dt_h:       db "SKILL: FLAT OUT",0

; ---------------------------------------------------------------------
; a new high score? enter three letters
; ---------------------------------------------------------------------
hi_enter:
            ; find the rank: first entry with a lower score
            ld hl,HISCORES+2
            ld b,0
.f:         push hl
            ld de,score
            ld a,(de)
            cp (hl)
            jr nz,.cmp
            inc hl
            inc de
            ld a,(de)
            cp (hl)
            jr nz,.cmp
            inc hl
            inc de
            ld a,(de)
            cp (hl)
.cmp:       pop hl
            jr z,.nx
            jr nc,.got              ; ours is higher
.nx:        ld de,HI_SZ
            add hl,de
            inc b
            ld a,b
            cp HI_N
            jr nz,.f
            ret                     ; not good enough
.got:       ld a,b
            ld (ent_rank),a
            ; shift the lower entries down
            push hl
            ld a,HI_N-1
            sub b
            jr z,.ns
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,de
            add hl,hl               ; *6
            ld b,h
            ld c,l
            ld hl,HISCORES+2+(HI_N-1)*HI_SZ-1
            ld de,HISCORES+2+HI_N*HI_SZ-1
            lddr
.ns:        pop hl
            push hl
            ex de,hl
            ld hl,score
            ld bc,3
            ldir
            ld a,'A'
            ld (de),a
            ld (ent_name),a
            inc de
            ld (de),a
            ld (ent_name+1),a
            inc de
            ld (de),a
            ld (ent_name+2),a
            xor a
            ld (ent_pos),a
            pop hl
            inc hl
            inc hl
            inc hl
            push hl                 ; where the name goes
            call silence
            ld hl,tune_title
            call music
.loop:      call read_input
            call sound_tick
            ld a,(ent_pos)
            ld e,a
            ld d,0
            ld hl,ent_name
            add hl,de
            ld a,(in_new)
            bit 0,a
            jr z,.nu
            ld a,(hl)
            inc a
            cp 'Z'+1
            jr c,.u
            ld a,' '
            jr .u
.u:         cp ' '+1
            jr nz,.u2
            ld a,'A'
.u2:        ld (hl),a
            ld a,SFX_MENU
            call sfx
.nu:        ld a,(in_new)
            bit 1,a
            jr z,.nd
            ld a,(hl)
            cp 'A'
            jr nz,.d1
            ld a,' '
            jr .d2
.d1:        cp ' '
            jr nz,.d3
            ld a,'Z'
            jr .d2
.d3:        dec a
.d2:        ld (hl),a
            ld a,SFX_MENU
            call sfx
.nd:        ld a,(in_new)
            and K_FIRE|K_ARM|K_RIGHT
            jr z,.nf
            ld a,SFX_COIN
            call sfx
            ld hl,ent_pos
            inc (hl)
            ld a,(hl)
            cp 3
            jp nc,.done
.nf:        ld a,(in_new)
            bit 2,a
            jr z,.dr
            ld hl,ent_pos
            ld a,(hl)
            or a
            jr z,.dr
            dec (hl)
.dr:        ; draw
            call bb_wait
            ld a,$AA
            call cls_bb
            ld a,10
            ld b,10
            ld c,$FF
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,str_ent1
            ld a,10
            call big_centre
            ld a,1
            ld c,2
            call text_col
            ld hl,str_ent2
            ld a,26
            call small_centre
            ld hl,ent_name
            ld de,34*32+13
            call bbde
            ld b,3
            ld c,0
.ch:        push bc
            ld a,(ent_pos)
            cp c
            ld a,1
            jr nz,.ci
            ld a,(frames)
            and 4
            ld a,3
            jr z,.ci
            ld a,1
.ci:        push hl
            push de
            ld c,2
            call text_col
            pop de
            pop hl
            ld a,(hl)
            push hl
            call putc2
            pop hl
            inc hl
            inc de
            inc de
            pop bc
            inc c
            djnz .ch
            ld a,0
            ld c,2
            call text_col
            ld hl,str_ent3
            ld a,52
            call small_centre
            call present
            jp .loop
.done:      pop de
            ld hl,ent_name
            ld bc,3
            ldir
            ld hl,HISCORES+2
            ld de,hiscore
            ld bc,3
            ldir
            ld a,SFX_LIFE
            call sfx
            ld a,30
            call wait_fields
            call hi_table
            ret
str_ent1:   db "BONZER!",0
str_ent2:   db "ENTER YOUR NAME",0
str_ent3:   db "^ v LETTER   FIRE NEXT",0
