; =====================================================================
;  game.asm - game flow: new game, stage start, the play loop, pause,
;  stage clear tally, game over + continue, the attract-mode pilot
; =====================================================================
NSTAGES     equ 1              ; stages in this build (the vertical slice)

; A = character -> play until the game ends, then back to the caller
new_game:
            ld (p_char),a
            xor a
            ld (score),a
            ld (score+1),a
            ld (score+2),a
            ld (p_speed),a
            ld (p_bomb),a
            ld (p_shot),a
            ld (p_buddy),a
            ld (p_shield),a
            ld (p_cursor),a
            ld (round),a
            ld (credits),a
            ld (chain),a
            ld (trainer),a
            ld a,$01                ; first extra life at 100,000
            ld (extra_at),a
            ld a,(diff)
            ld e,a
            ld d,0
            ld hl,diff_lives
            add hl,de
            ld a,(hl)
            ld (p_lives),a
            ld a,1
            ld (stage_no),a
            ld (bar_dirty),a
.stage:     call stage_begin
            ret c                   ; (load failed: back to the title)
            call play_loop
            ld a,(stg_phase)
            cp PH_OVER
            jr z,.over
            call stage_clear
            ld a,(demo_on)
            or a
            ret nz
            ld hl,stage_no
            inc (hl)
            ld a,(hl)
            cp NSTAGES+1
            jr c,.stage
            ld (hl),1               ; all stages done: round two, a bit hotter
            ld hl,round
            inc (hl)
            call round_card
            jr .stage
.over:      ld a,(demo_on)
            or a
            ret nz
            call game_over_seq      ; NC = continue, C = really over
            ret c
            ld a,(diff)             ; carry on from the same spot
            ld e,a
            ld d,0
            ld hl,diff_lives
            add hl,de
            ld a,(hl)
            ld (p_lives),a
            xor a
            ld (score),a
            ld (score+1),a
            ld (score+2),a
            ld (stg_phase),a
            ld hl,credits
            inc (hl)
            call player_reset
            call play_loop
            ld a,(stg_phase)
            cp PH_OVER
            jr z,.over
            jr .cont
.cont:      call stage_clear
            ld hl,stage_no
            inc (hl)
            ld a,(hl)
            cp NSTAGES+1
            jp c,.stage
            ld (hl),1
            ld hl,round
            inc (hl)
            call round_card
            jp .stage
diff_lives: db 5, 3, 3

; ---------------------------------------------------------------------
; load and set up the stage, show its card. C = load failed.
; ---------------------------------------------------------------------
stage_begin:
            ld a,(stage_ld)
            ld b,a
            ld a,(stage_no)
            cp b
            jr z,.have
            ld (stage_ld),a
            call silence
            call loading_card
            ld a,(stage_no)
            add a,'0'
            ld (n_stage+5),a
            ld hl,n_stage
            call sd_load
            jr nc,.have
            xor a
            ld (stage_ld),a
            call load_error
            scf
            ret
.have:      xor a
            ld (stg_phase),a
            ld (tl_hold),a
            ld (boss_bar),a
            ld (msg_t),a
            ld (spawn_n),a
            ld (coins),a
            ld (bonus_sec),a
            ld (chain_max),a
            ld (p_hits),a
            ld (secrets),a
            ld (route),a
            ld (pause_on),a
            ld hl,0
            ld (tl_col),hl
            ld (stg_time),hl
            ld (kills),hl
            ld hl,wave_left
            ld b,8
.wl:        ld (hl),$FF
            inc hl
            djnz .wl
            call clear_objs
            call STG_INIT           ; timeline, segment, palette, tune
            call scroll_init
            call player_reset
            ld a,1
            ld (scroll_on),a
            ld a,40
            ld (cloud_x),a
            ld a,130
            ld (cloud_x+1),a
            ld a,210
            ld (cloud_x+2),a
            ld a,1
            ld (bar_dirty),a
            ld (hud_dirty),a
            ld a,(demo_on)
            or a
            ret nz                  ; (NC)
            jp stage_card

n_stage:    db '"GLXS1"',0

; ---------------------------------------------------------------------
; the play loop: returns when the stage is cleared or the game is over
; (or, in the attract demo, when a key is pressed or time runs out)
; ---------------------------------------------------------------------
play_loop:
            ld a,(demo_on)
            or a
            jr z,.in
            call demo_ai
.in:        call read_input
            ld a,(demo_on)
            or a
            jr z,.nd
            ld a,(in_demokey)
            or a
            jp nz,.demo_end
            ld hl,(demo_t)
            dec hl
            ld (demo_t),hl
            ld a,h
            or l
            jp z,.demo_end
            jr .go
.nd:        ld a,(in_new)
            and K_PAUSE
            call nz,do_pause
            call key_n
            jr z,.go
            ld a,(music_off)
            xor 1
            ld (music_off),a
.go:        xor a
            ld (scrolled),a
            ld a,(scroll_on)
            or a
            jr z,.ns
            call scroll_step
            ld a,1
            ld (scrolled),a
.ns:        call player_update
            call pshots_update
            call objects_update
            call ebul_update
            call STG_FRAME
            call timeline
            call collide
            call chain_tick
            call sound_tick
            ld hl,(stg_time)
            inc hl
            ld (stg_time),hl
            ; ---- draw (into the free buffer: no waiting)
            call draw_bg
            call draw_objects
            call draw_ebul
            call draw_pshots
            call draw_player
            call STG_DRAW
            call draw_msg
            ld a,(demo_on)
            or a
            call nz,demo_banner
            call draw_bar
            call draw_hud
            call present
            ld a,(stg_phase)
            cp PH_CLEAR
            jr z,.clear
            cp PH_OVER
            jp nz,play_loop
            ; game over: let the explosion play out a moment
            ret
.clear:     ld hl,clear_t
            dec (hl)
            jp nz,play_loop
            ret
.demo_end:  ld a,PH_OVER
            ld (stg_phase),a
            ret

; the player's last life is gone
game_over_now:
            ld a,PH_OVER
            ld (stg_phase),a
            ret

do_pause:
            ld a,1
            ld (pause_on),a
            call silence
            ld a,1
            ld c,2
            call text_col
            ld hl,str_paused
            ld de,VRAM+28*32+10
            call print2
.w:         call read_input
            call key_n
            jr z,.nm
            ld a,(music_off)
            xor 1
            ld (music_off),a
.nm:        ld a,1
            call wait_fields
            ld a,(in_new)
            and K_PAUSE|K_FIRE
            jr z,.w
            xor a
            ld (pause_on),a
            ld (in_new),a
            ret
str_paused: db "PAUSE",0

; ---------------------------------------------------------------------
; big text into the back buffer: HL = string, A = row; centred
; ---------------------------------------------------------------------
big_centre:
            push hl
            push af
            call strlen
            add a,a                 ; 2 bytes per character
            ld b,a
            ld a,32
            sub b
            srl a
            ld e,a
            pop af
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld d,0
            add hl,de
            call bbp
            ex de,hl
            pop hl
            jp print2
; small text into the back buffer: HL = string, A = row; centred
small_centre:
            push hl
            push af
            call strlen
            ld b,a
            ld a,32
            sub b
            srl a
            ld e,a
            pop af
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld d,0
            add hl,de
            call bbp
            ex de,hl
            pop hl
            jp print
; A = printable length of the string at HL (colour codes don't count)
strlen:
            push hl
            ld b,0
.l:         ld a,(hl)
            inc hl
            or a
            jr z,.e
            cp 5
            jr c,.l
            inc b
            jr .l
.e:         ld a,b
            pop hl
            ret

; a band of colour C across rows A.. for B rows (back buffer)
band_bb:
            push bc
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            call bbp
            pop bc
            ld a,c
.r:         push bc
            ld b,32
.c:         ld (hl),a
            inc hl
            djnz .c
            pop bc
            djnz .r
            ret

; present the back buffer as it is and hold it for A fields
show_hold:
            push af
            call present
            pop af
.w:         push af
            ld a,1
            call wait_fields
            call read_input
            call sound_tick
            pop af
            dec a
            ret z
            jr .w

; ---------------------------------------------------------------------
; stage card: the first frame of the stage with the stage's name over it
; ---------------------------------------------------------------------
stage_card:
            call bb_wait
            call draw_bg
            call draw_player
            ld a,22
            ld b,22
            ld c,$FF                ; red band
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,str_stage
            ld a,24
            call big_centre
            ld a,(stage_no)
            add a,'0'
            ld de,24*32+24
            call bbde
            call putc2
            ld a,1
            ld c,3
            call text_col
            ld hl,STG_CODE          ; the stage pack starts with its name
            ld a,36
            call small_centre
            ld a,0
            ld c,3
            call text_col
            ld hl,STG_CODE
            call strlen
            inc a
            ld e,a
            ld d,0
            add hl,de               ; then its premise line
            ld a,(round)
            or a
            jr z,.r1
            ld hl,str_round2
.r1:        ld a,30+6+6
            call small_centre
            ld a,1
            ld (hud_dirty),a
            call hud_force
            ld a,SFX_START
            call sfx
            ld a,120
            jp show_hold
str_stage:  db "STAGE  ",0
str_round2: db "ROUND 2: IT'S HOTTER!",0

round_card:
            ld a,$AA
            call cls_bb
            ld a,1
            ld c,2
            call text_col
            ld hl,str_round
            ld a,20
            call big_centre
            ld hl,str_round_b
            ld a,36
            call small_centre
            ld a,100
            jp show_hold
str_round:  db "ROUND 2",0
str_round_b: db "THE BACKYARD BITES BACK",0

loading_card:
            ld a,$AA
            call cls_bb
            ld a,1
            ld c,2
            call text_col
            ld hl,str_loading
            ld a,28
            call small_centre
            jp present
str_loading: db "LOADING...",0

load_error:
            ld a,$FF
            call cls_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,str_lerr
            ld a,24
            call small_centre
            ld hl,n_stage+1
            ld a,32
            call small_centre
            ld a,150
            jp show_hold
str_lerr:   db "CAN'T LOAD THE STAGE FILE",0

; ---------------------------------------------------------------------
; stage clear: tally the bonuses
; ---------------------------------------------------------------------
stage_clear:
            call silence
            ld hl,tune_clear
            call music
            ld a,$AA
            call cls_bb
            ld a,1
            ld c,2
            call text_col
            ld hl,str_clear
            ld a,8
            call big_centre
            ; no-hit bonus 10,000
            ld a,0
            ld c,2
            call text_col
            ld hl,str_b_nohit
            ld de,24*32+2
            call bbde
            call print
            ld a,(p_hits)
            or a
            ld de,0
            jr nz,.nh
            ld de,$1000
.nh:        ld a,24
            call tally_line
            ; best chain x 1,000
            ld hl,str_b_chain
            ld de,31*32+2
            call bbde
            call print
            ld a,(chain_max)
            add a,'0'
            ld de,31*32+13
            call bbde
            call putc
            ld a,(chain_max)
            call bcd_a
            ld d,a
            ld e,0
            ld a,31
            call tally_line
            ; coins x 100
            ld hl,str_b_coins
            ld de,38*32+2
            call bbde
            call print
            ld a,(coins)
            ld de,38*32+8
            call bbde
            call print_dec2
            ld a,(coins)
            call bcd_a              ; x100 points = x10 tens
            ld e,a
            rrca
            rrca
            rrca
            rrca
            and 15
            ld d,a
            ld a,e
            rlca
            rlca
            rlca
            rlca
            and $F0
            ld e,a
            ld a,38
            call tally_line
            ; secrets
            ld hl,str_b_secret
            ld de,45*32+2
            call bbde
            call print
            ld a,(bonus_sec)
            call bcd_a
            ld d,a
            ld e,0
            ld a,45
            call tally_line
            ld a,1
            ld c,2
            call text_col
            ld hl,str_b_total
            ld a,54
            call small_centre
            ld hl,score
            ld de,54*32+19
            call bbde
            call print_score
            call draw_hud
            ld a,200
            jp show_hold

; DE = bonus (BCD tens), A = row: print it at the right, add it to the score
tally_line:
            push de
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld bc,18
            add hl,bc
            call bbp
            ex de,hl                ; DE = where, HL = bonus
            ld a,h
            ld (work+1),a
            ld a,l
            ld (work+2),a
            xor a
            ld (work),a
            ld hl,work
            call print_score
            pop de
            call add_score
            ld a,SFX_COIN
            call sfx
            ld a,25
            jp show_hold

; A = 0..99 binary -> BCD
bcd_a:
            ld b,0
.t:         sub 10
            jr c,.d
            inc b
            jr .t
.d:         add a,10
            ld c,a
            ld a,b
            rlca
            rlca
            rlca
            rlca
            or c
            ret

str_clear:  db "STAGE CLEAR!",0
str_b_nohit: db "NO-HIT BONUS",0
str_b_chain: db "BEST CHAIN X",0
str_b_coins: db "COINS",0
str_b_secret: db "SECRETS",0
str_b_total: db "SCORE",0

; ---------------------------------------------------------------------
; game over: CONTINUE? 9..0. NC = continue, C = over
; ---------------------------------------------------------------------
game_over_seq:
            call silence
            ld hl,tune_over
            call music
            ld a,40
            call wait_fields
            ld a,9
            ld (fe_sel),a
.l:         call bb_wait
            call draw_bg
            call draw_objects
            ld a,20
            ld b,26
            ld c,$FF
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,str_gover
            ld a,22
            call big_centre
            ld hl,str_cont
            ld a,36
            call small_centre
            ld a,(fe_sel)
            add a,'0'
            ld de,36*32+24
            call bbde
            call putc
            ld a,0
            ld c,3
            call text_col
            ld hl,str_cont2
            ld a,42
            call small_centre
            call draw_hud
            ld a,SFX_MENU
            call sfx
            call present
            ld b,50
.w:         push bc
            ld a,1
            call wait_fields
            call read_input
            call sound_tick
            pop bc
            ld a,(in_new)
            and K_FIRE|K_ARM
            jr nz,.yes
            djnz .w
            ld hl,fe_sel
            ld a,(hl)
            or a
            scf
            ret z
            dec (hl)
            jr .l
.yes:       call silence
            or a
            ret
str_gover:  db "GAME OVER",0
str_cont:   db "CONTINUE?",0
str_cont2:  db "FIRE: CARRY ON FROM HERE",0

; ---------------------------------------------------------------------
; attract mode: the autopilot. Fires all the time, lines up with the
; nearest thing ahead, slides away from bullets, buys SHOT and BUDDY.
; ---------------------------------------------------------------------
demo_ai:
            ld e,K_FIRE
            ; dodge bullets first
            ld ix,ebul
            ld b,NEB
.bl:        ld a,(ix+E_T)
            or a
            jr z,.bn
            ld a,(ix+E_X)
            ld hl,p_x
            sub (hl)
            add a,6
            cp 26
            jr nc,.bn
            ld a,(ix+E_Y)
            ld hl,p_y
            sub (hl)
            add a,6
            cp 12
            jr nc,.bn
            cp 7                    ; bullet below our middle -> go up
            jr nc,.up
            set 1,e
            jr .lr
.up:        set 0,e
            jr .lr
.bn:        ld de,EBSZ
            add ix,de
            ld e,K_FIRE
            djnz .bl
            ; no danger: line up with the nearest object ahead (pickups first)
            ld ix,objs
            ld b,NOBJ
            ld c,$FF
            ld d,0
.ol:        ld a,(ix+O_T)
            or a
            jr z,.on
            bit F_FX,(ix+O_FL)
            jr nz,.on
            ld a,(ix+O_X)
            ld hl,p_x
            sub (hl)
            jr c,.on
            bit F_PICK,(ix+O_FL)
            jr z,.nk
            srl a                   ; pickups count as nearer
            srl a
.nk:        cp c
            jr nc,.on
            ld c,a
            ld a,(ix+O_Y)
            ld d,a
.on:        push de
            ld de,OSZ
            add ix,de
            pop de
            djnz .ol
            ld e,K_FIRE
            ld a,d
            or a
            jr z,.lr
            ld hl,p_y
            sub (hl)
            jr z,.lr
            jr c,.tu
            cp 3
            jr c,.lr
            set 1,e
            jr .lr
.tu:        cp -2
            jr nc,.lr
            set 0,e
.lr:        ; hold x near 16..40
            ld a,(p_x)
            cp 16+XOFF
            jr nc,.l1
            set 3,e
.l1:        cp 44+XOFF
            jr c,.l2
            set 2,e
.l2:        ; buy SPEED once, then SHOT and BUDDY whenever offered
            ld a,(demo_in)
            and K_ARM
            jr nz,.nb
            ld a,(p_cursor)
            cp 3
            jr z,.buy
            cp 4
            jr z,.buy
            cp 1
            jr nz,.nb
            ld a,(p_speed)
            or a
            jr nz,.nb
.buy:       set 5,e
.nb:        ld a,e
            ld (demo_in),a
            ret

demo_banner:
            ld a,(frames)
            and 16
            ret z
            ld a,1
            ld c,2
            call text_col
            ld hl,str_demo
            ld de,7*32+1
            call bbde
            jp print
str_demo:   db "DEMO - PRESS FIRE",0
