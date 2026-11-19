; =====================================================================
;  THE GAME: a run through the crypts, one cave at a time off the disk.
; =====================================================================
G_REVEAL equ 0
G_PLAY  equ 1
G_DYING equ 2
G_TALLY equ 3

R_DONE  equ 0
R_DEAD  equ 1
R_QUIT  equ 2
R_AGAIN equ 3

START_LIVES equ 5

; HL = a list of picture numbers ($FF ends): put each one's first frame in
; the next four glyphs of PCG bank 0 and build GT / CT (the glyphs and
; colours of every tile's four cells).  A cave brings its own list, so a
; cave can use any 31 of the library's pictures.
load_tiles:
        push hl
        ld hl,sgtab
        ld b,NARTS
.z:     ld (hl),0
        inc hl
        djnz .z
        pop hl
        ld c,4                  ; first glyph
.s:     ld a,(hl)
        inc hl
        cp $FF
        jr z,.tabs
        push hl
        push bc
        ld e,a
        ld d,0
        ld hl,sgtab
        add hl,de
        ld (hl),c
        ex de,hl
        add hl,hl
        ld de,art_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; the picture's frame table
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; its first frame
        ld a,c
        call pcg_tile
        pop bc
        pop hl
        ld a,c
        add a,4
        ld c,a
        jr .s
.tabs:  ld hl,tile_def
        ld c,0
.t:     ld a,(hl)
        inc hl
        push hl
        cp $FF
        jr z,.blank
        ld e,a
        ld d,0
        ld hl,sgtab
        add hl,de
        ld a,(hl)
        or a
        jr z,.blank
        add a,$80
        ld l,c
        ld h,GT>>8
        ld (hl),a
        set 6,l
        inc a
        ld (hl),a
        inc h
        res 6,l
        inc a
        ld (hl),a
        set 6,l
        inc a
        ld (hl),a
        jr .col
.blank: ld l,c
        ld h,GT>>8
        ld a,$80
        ld (hl),a
        set 6,l
        ld (hl),a
        inc h
        ld (hl),a
        res 6,l
        ld (hl),a
.col:   pop hl
        ld e,c
        ld d,CT>>8
        ld a,(hl)
        inc hl
        ld (de),a
        set 6,e
        ld a,(hl)
        inc hl
        ld (de),a
        inc d
        res 6,e
        ld a,(hl)
        inc hl
        ld (de),a
        set 6,e
        ld a,(hl)
        inc hl
        ld (de),a
        inc c
        ld a,c
        cp NTILES
        jr nz,.t
        ret

; the cave's own colours: pairs of tile, ink in its header
theme_apply:
        ld hl,CAVEBUF+CH_THEME
.t:     ld a,(hl)
        cp $FF
        ret z
        inc hl
        ld e,a
        ld d,CT>>8
        ld a,(hl)
        inc hl
        ld (de),a
        set 6,e
        ld (de),a
        inc d
        ld (de),a
        res 6,e
        ld (de),a
        jr .t

; A = frame, E = picture: rewrite that picture's glyphs, if the cave has it
anim_art:
        ld d,0
        ld hl,sgtab
        add hl,de
        ld c,(hl)
        inc c
        dec c
        ret z
        ld hl,art_tab
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp anim_set

; ---------------------------------------------------------------------
;  set the loaded cave (CAVEBUF) up for play
; ---------------------------------------------------------------------
cave_start:
        call stop_music
        ld hl,CAVEBUF+CH_SIZE   ; the map, as it came off the disk
        ld de,CAVE
        ld bc,CAVE_BYTES
        ldir
        ld hl,DMAP
        ld de,DMAP+1
        ld bc,CAVE_BYTES-1
        ld (hl),0
        ldir
        ld hl,cv_start          ; the cave's own variables
        ld de,cv_start+1
        ld bc,cv_end-cv_start-1
        ld (hl),0
        ldir
        ld a,(CAVEBUF+CH_W)
        ld (cave_w),a
        ld a,(CAVEBUF+CH_H)
        ld (cave_h),a
        ld hl,CAVE              ; where Mort comes in, and the way out
        ld bc,CAVE_BYTES
.f:     ld a,(hl)
        cp T_INBOX
        jr nz,.f1
        ld (p_ptr),hl
.f1:    cp T_EXITC
        jr nz,.f2
        ld (exit_ptr),hl
.f2:    inc hl
        dec bc
        ld a,b
        or c
        jr nz,.f
        ld a,(CAVEBUF+CH_QUOTA)
        ld (quota),a
        ld hl,(CAVEBUF+CH_TIME)
        ld (time),hl
        ld a,(CAVEBUF+CH_SLOW)
        ld (slow_t),a
        ld a,3
        ld (slime_rate),a
        ld a,INBOX_T
        ld (inbox_t),a
        ld a,(wards)
        or a
        jr nz,.w
        inc a
        ld (wards),a            ; every attempt starts with a ward
.w:     ld a,(cave_no)
        ld l,a
        ld h,$5A
        ld (seed),hl            ; the same cave always plays the same way
        ld hl,CHG_A
        ld (chg_cur),hl
        ld (chg_wr),hl
        ld hl,CHG_B
        ld (chg_prev),hl
        ld hl,$FFFF
        ld (scanptr),hl
        ld hl,CAVEBUF+CH_SLOTS
        call load_tiles
        call theme_apply
        ld a,(quota)
        or a
        jr nz,.q
        ld hl,(exit_ptr)        ; nothing to collect: the way out stands open
        ld (hl),T_EXITO
        ld a,1
        ld (exit_open),a
.q:     ; the view centred on Mort's way in
        ld hl,(p_ptr)
        call tile_xy
        ld a,c
        add a,a
        sub 19
        call clamp_sx
        ld (sx),a
        ld a,b
        add a,a
        sub 10
        call clamp_sy
        ld (sy),a
        ; both pages: text rows, the stone shutter over the playfield
        call draw_hidden
        call .page
        call wait_vb
        ld a,(dpage)
        xor 1
        call show_page
        call draw_hidden
        call .page
        ld a,(sx)
        ld (pg_sx),a
        ld (pg_sx+1),a
        ld a,(sy)
        ld (pg_sy),a
        ld (pg_sy+1),a
        ld a,2
        ld (hud_cnt),a
        call msg_name
        xor a
        ld (gstate),a
        ld (vcount),a
        ret
.page:  ld a,$80
        ld bc,$0100
        call fill_page
        call game_attrs
        ld b,0
.cy:    ld c,0
.cx:    push bc
        ld a,T_COVER
        call plot4
        pop bc
        inc c
        inc c
        ld a,c
        cp COLS
        jr nz,.cx
        push bc
        call vschk
        pop bc
        inc b
        inc b
        ld a,b
        cp PF_ROWS
        jr nz,.cy
        ret

; HL = cave cell -> C = tile column, B = tile row.  keeps HL
tile_xy:
        ld a,l
        and 63
        ld c,a
        ld a,l
        rlca
        rlca
        and 3
        ld b,a
        ld a,h
        sub CAVE>>8
        add a,a
        add a,a
        or b
        ld b,a
        ret

; A = wanted scroll (signed) -> A within the cave
clamp_sx:
        or a
        jp m,.z
        ld e,a
        ld a,(cave_w)
        add a,a
        sub COLS
        cp e
        ret c
        ld a,e
        ret
.z:     xor a
        ret
clamp_sy:
        or a
        jp m,.z
        ld e,a
        ld a,(cave_h)
        add a,a
        sub PF_ROWS
        cp e
        ret c
        ld a,e
        ret
.z:     xor a
        ret

; keep Mort in view: once he nears an edge the view follows, a cell a
; frame, until he is back near the middle
scroll_update:
        ld hl,(p_ptr)
        call tile_xy
        ld a,c
        add a,a
        ld c,a                  ; C = Mort's cell column in the cave
        ld a,b
        add a,a
        ld b,a
        ; across
        ld a,(sx)
        ld e,a
        ld a,c
        sub e                   ; column on screen
        ld d,a
        ld a,(scr_x)
        or a
        jr nz,.gx
        ld a,d
        cp 8
        jr c,.sxon
        cp 31
        jr c,.ydir
.sxon:  ld a,1
        ld (scr_x),a
.gx:    ld a,c
        sub 19
        call clamp_sx
        ld e,a
        ld a,(sx)
        cp e
        jr z,.xdone
        jr c,.xinc
        dec a
        jr .xset
.xinc:  inc a
.xset:  ld (sx),a
        jr .ydir
.xdone: xor a
        ld (scr_x),a
.ydir:  ld a,(sy)
        ld e,a
        ld a,b
        sub e
        ld d,a
        ld a,(scr_y)
        or a
        jr nz,.gy
        ld a,d
        cp 4
        jr c,.syon
        cp 17
        ret c
.syon:  ld a,1
        ld (scr_y),a
.gy:    ld a,b
        sub 10
        call clamp_sy
        ld e,a
        ld a,(sy)
        cp e
        jr z,.ydone
        jr c,.yinc
        dec a
        jr .yset
.yinc:  inc a
.yset:  ld (sy),a
        ret
.ydone: xor a
        ld (scr_y),a
        ret

; ---------------------------------------------------------------------
;  the cave appears: the shutter breaks up tile by tile
; ---------------------------------------------------------------------
reveal_step:
        call draw_hidden
        ld a,(sy)
        ld c,a
        srl a
        ld h,a
        ld l,0
        srl h
        rr l
        srl h
        rr l
        ld a,(sx)
        srl a
        add a,l
        ld l,a
        ld a,h
        add a,CAVE>>8
        ld h,a                  ; HL = top left tile in view
        ld a,c
        and 1
        add a,11
        ld b,a
.row:   push bc
        push hl
        ld a,(sx)
        and 1
        add a,20
        ld b,a
.col:   push bc
        ld a,l
        rrca
        rrca
        rrca
        xor l
        ld e,a
        ld a,h
        add a,a
        add a,a
        add a,h
        xor e
        and 15
        ld e,a
        ld a,(reveal_k)
        cp e
        jr z,.show
        dec a
        cp e
        jr nz,.no
.show:  push hl
        call draw_cell
        pop hl
.no:    pop bc
        inc hl
        djnz .col
        call vschk
        pop hl
        ld de,ROWLEN
        add hl,de
        pop bc
        djnz .row
        ld hl,reveal_k
        inc (hl)
        ld a,(hl)
        cp 18
        ret c
        ld a,G_PLAY
        ld (gstate),a
        ld a,(demo_on)
        or a
        jr z,.hint
        ld hl,t_demo
        ld a,WHITE
        ld b,0
        call set_msg
        jr .mus
.hint:  jp msg_hint             ; the crypt's hint for a few seconds, then its name
.mus:   ret                     ; (no tune in the crypts: the cave is the sound)
t_demo: db "DEMONSTRATION - PRESS A KEY TO PLAY",0

; ---------------------------------------------------------------------
;  messages on the bottom row
; ---------------------------------------------------------------------
; HL = text, A = colour, B = frames to show it (0 = until replaced)
set_msg:
        ld (msg_ptr),hl
        ld (msg_col),a
        ld a,b
        ld (msg_t),a
        ld a,2
        ld (msg_cnt),a
        ret
msg_name:
        ld hl,CAVEBUF+CH_NAME
        ld de,msgbuf
        ld bc,24
        ldir
        xor a
        ld (de),a
        ld hl,msgbuf+23         ; trim the padding
.t:     ld a,(hl)
        cp ' '
        jr nz,.d
        ld (hl),0
        dec hl
        jr .t
.d:     ld hl,msgbuf
        ld a,YELLOW
        ld b,0
        jr set_msg
msg_hint:
        ld hl,CAVEBUF+CH_HINT
        ld de,msgbuf
        ld bc,40
        ldir
        xor a
        ld (de),a
        ld hl,msgbuf
        ld a,BCYAN
        ld b,90
        jp set_msg

; the HUD (row 0), the border (row 1) and the message row on the hidden page
hud_draw:
        call draw_hidden
        ld a,(msg_t)
        or a
        jr z,.nm
        dec a
        ld (msg_t),a
        call z,msg_name
.nm:    ld a,(flash)
        or a
        jr z,.nf
        dec a
        ld (flash),a
        ld a,2
        ld (hud_cnt),a
.nf:    ld a,(hud_cnt)
        or a
        jr z,.msg
        dec a
        ld (hud_cnt),a
        call hud_row
.msg:   ld a,(msg_cnt)
        or a
        ret z
        dec a
        ld (msg_cnt),a
        ld b,MSG_ROW
        call clear_row
        ld a,(msg_col)
        ld (txt_col),a
        ld hl,(msg_ptr)
        ld b,MSG_ROW
        jp print_c

hud_row:
        xor a
        call row_addr
        ex de,hl
        ld a,BCYAN
        ld (txt_col),a
        ld a,'#'
        call put_char
        ld a,(quota)
        ld b,a
        ld a,(gems)
        cp b
        ld a,WHITE
        jr c,.g
        ld a,BGREEN
.g:     ld (txt_col),a
        ld a,(gems)
        ld l,a
        ld h,0
        call put_num3
        ld a,GREY
        ld (txt_col),a
        ld a,'/'
        call put_char
        ld a,(quota)
        ld l,a
        ld h,0
        call put_num3
        ld a,' '
        call put_char
        ld a,WHITE
        ld (txt_col),a
        ld a,'%'
        call put_char
        ld hl,(time)
        ld a,h
        or a
        jr nz,.tw
        ld a,l
        cp 10
        jr nc,.tw
        ld a,BRED
        ld (txt_col),a
.tw:    call put_num3
        ld a,' '
        call put_char
        ld a,BRED
        ld (txt_col),a
        ld a,'$'
        call put_char
        ld a,WHITE
        ld (txt_col),a
        ld a,(lives)
        add a,'0'
        call put_char
        ld a,' '
        call put_char
        ld a,BCYAN
        ld (txt_col),a
        ld a,';'
        call put_char
        ld a,WHITE
        ld (txt_col),a
        ld a,(wards)
        add a,'0'
        call put_char
        ld a,' '
        call put_char
        ld a,YELLOW
        ld (txt_col),a
        ld a,'@'
        call put_char
        ld a,WHITE
        ld (txt_col),a
        ld a,(keys_n)
        add a,'0'
        call put_char
        ld a,' '
        call put_char
        ld a,GREY
        ld (txt_col),a
        ld hl,t_crypt
.c:     ld a,(hl)
        or a
        jr z,.cn
        inc hl
        call put_char
        jr .c
.cn:    ld a,(cave_no)
        inc a
        call .two
        ld a,' '
        call put_char
        ld a,YELLOW
        ld (txt_col),a
        ld a,(score)
        call put_bcd
        ld a,(score+1)
        call put_bcd
        ld a,(score+2)
        call put_bcd
        ld a,'0'
        call put_char
        ; row 1: the border, white for a moment when the way out opens
        ld a,1
        call row_addr
        ex de,hl
        ld a,(flash)
        and 1
        ld a,DGREY
        jr z,.b
        ld a,WHITE
.b:     ld (txt_col),a
        ld b,COLS
.bl:    ld a,'['
        call put_char
        djnz .bl
        ret
.two:   push de
        call bin2bcd
        ld a,l
        pop de
        jp put_bcd
.sp2:   ld a,' '
        call put_char
        ld a,' '
        jp put_char
t_crypt: db "CRYPT ",0

; HL = 0..999 as three digits at DE
put_num3:
        ld bc,-100
        ld a,'0'-1
.h:     inc a
        add hl,bc
        jr c,.h
        sbc hl,bc
        push hl
        call put_char
        pop hl
        ld a,l
        push de
        call bin2bcd
        ld a,l
        pop de
        jp put_bcd

; ---------------------------------------------------------------------
;  tile animation, once a frame
; ---------------------------------------------------------------------
anim_frame:
        ld a,(framecount)
        ld (an_fc),a
        and 3
        jr z,.gem
        dec a
        jp z,.haunt
        dec a
        jr z,.gem
        ; knights, slime, the gate, the grate, the stone shutter
        ld a,(an_fc)
        rrca
        rrca
        and 1
        ld e,ART_KNIGHT
        call anim_art
        ld a,(an_fc)
        rrca
        rrca
        and 3
        cp 3
        jr nz,.s3
        ld a,1
.s3:    ld e,ART_SLIME
        call anim_art
        ld a,(exit_open)
        or a
        jr z,.ne
        ld a,(an_fc)
        rrca
        rrca
        and 1
        ld e,ART_EXITO
        call anim_art
.ne:    ld a,(magic_st)
        dec a
        ld a,0
        jr nz,.mg
        ld a,(an_fc)
        rrca
        rrca
        and 3
        inc a
.mg:    ld hl,magic_last        ; (only when it changes: it is a big picture)
        cp (hl)
        jr z,.nm
        ld (hl),a
        ld e,ART_MAGIC
        call anim_art
.nm:    ld a,(gstate)
        or a
        jr nz,.pose
        ld a,(an_fc)
        rrca
        rrca
        and 3
        ld e,ART_COVER
        call anim_art
        jr .pose
.gem:   ld a,(an_fc)            ; the three jewels twinkle out of step
        rrca
        and 3
        ld e,ART_GEM
        call anim_art
        ld a,(an_fc)
        rrca
        inc a
        and 3
        ld e,ART_RUBY
        call anim_art
        ld a,(an_fc)
        rrca
        add a,2
        and 3
        ld e,ART_EMERALD
        call anim_art
        jr .pose
.haunt: ld a,(an_fc)
        rrca
        rrca
        and 1
        push af
        ld e,ART_GHOST
        call anim_art
        pop af
        push af
        ld e,ART_BAT
        call anim_art
        pop af
        ld e,ART_SKULL
        call anim_art
.pose:  ; Mort (or, before he steps in, the flashing way in)
        ld a,(p_alive)
        or a
        jr nz,.alive
        ld a,(an_fc)
        rrca
        rrca
        and 1
        add a,POSE_INBOX0
        jr .set
.alive: ld a,(p_moving)
        or a
        jr z,.idle
        ld e,a
        xor a
        ld (idle_t),a
        ld a,(p_dir)
        ld d,a
        ld a,e
        cp 2
        jr nz,.walk
        ld a,d                  ; pushing or reaching
        cp 1
        ld a,POSE_PUSHR
        jr z,.set
        ld a,d
        cp 3
        ld a,POSE_PUSHL
        jr z,.set
.walk:  ld a,(p_steps)
        and 1
        ld e,a
        ld a,d
        add a,a
        ld c,a
        ld b,0
        ld hl,.wtab
        add hl,bc
        ld a,(hl)
        add a,e
        jr .set
.wtab:  db POSE_BACK,0,POSE_RIGHT1,0,POSE_DOWN1,0,POSE_LEFT1,0
.idle:  ld hl,idle_t
        inc (hl)
        ld a,(hl)
        ld e,a
        and 63
        cp 60
        ld a,POSE_BLINK
        jr nc,.set
        ld a,e
        cp 100
        ld a,POSE_FRONT
        jr c,.set
        ld a,e
        and 8
        ld a,POSE_FRONT
        jr z,.set
        ld a,POSE_TAP
.set:   ld hl,pose_last
        cp (hl)
        ret z
        ld (hl),a
        ld e,ART_PLAYER
        jp anim_art

; ---------------------------------------------------------------------
;  play the cave that has been set up.  -> A = R_xxx
; ---------------------------------------------------------------------
play:
.frame: call read_input
        call play_keys
        jp nz,.out              ; A = result
        ld a,(gstate)
        or a
        jr nz,.go
        call reveal_step
        jr .hud
.go:    cp G_TALLY
        jr nz,.live
        call tally
        jp nz,.out
        jr .draw
.live:  ld a,(paused)
        or a
        jr nz,.hud              ; (the map of the crypt is on the screen)
        call sd_step
        ld a,(phase)
        xor 1
        ld (phase),a
        jr nz,.nt
        call tick
        call after_tick
        jp nz,.out
.nt:    call scroll_update
.draw:  call render
        xor a
        ld (rn_tick),a
.hud:   call hud_draw
        ld a,FRAME_FIELDS
        call frame_end
        ld a,(dpage)
        xor 1
        call show_page
        call anim_frame
        jr .frame
.out:   push af
        call stop_music
        pop af
        ret

; after each cave step: time, the end of Mort, the way out.  NZ, A = result to stop
after_tick:
        ld a,(gstate)
        cp G_DYING
        jp z,.dying
        ld a,(p_dead)
        or a
        jr nz,.died
        ld a,(cave_done)
        or a
        jp nz,.done
        ld a,(p_alive)
        or a
        jr z,.ok
        ; the clock: a step is 6 fields
        ld a,(time_acc)
        add a,FRAME_FIELDS*2
        ld (time_acc),a
        cp 50
        jr c,.ok
        sub 50
        ld (time_acc),a
        ld a,2
        ld (hud_cnt),a
        ld a,(slow_t)
        or a
        jr z,.fast
        dec a
        ld (slow_t),a
        jr nz,.sl
.fast:  ld a,32
        ld (slime_rate),a
.sl:    ld hl,(time)
        ld a,h
        or l
        jr z,.ok
        dec hl
        ld (time),hl
        ld a,h
        or a
        jr nz,.ok
        ld a,l
        cp 10
        jr nc,.ok
        or a
        jr z,.tout
        ld a,SFX_TICK
        call play_sfx
        jr .ok
.tout:  ld hl,t_timeup
        ld a,BRED
        ld b,0
        call set_msg
        call kill_player
.ok:    xor a
        ret
.died:  ld a,G_DYING
        ld (gstate),a
        xor a
        ld (p_alive),a
        ld a,16
        ld (dying_t),a
        call stop_music
        ld a,SFX_OWW            ; "oww!" ...
        call play_sfx
        ld a,SFX_BOOM           ; ... trailing into the blast
        ld (sfxpend),a
        jr .ok
.dying: ld hl,dying_t
        dec (hl)
        jr nz,.ok
        ld a,(sd_on)            ; giving up costs no life: just start again
        or a
        ld a,R_DEAD
        jr z,.dd
        ld a,R_AGAIN
.dd:    or a
        ret
.done:  ld a,G_TALLY
        ld (gstate),a
        xor a
        ld (tally_t),a
        call stop_music
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld hl,t_cleared
        ld a,BGREEN
        ld b,0
        call set_msg
        jr .ok

; the cave is cleared: the time left turns into points.  NZ when it is over
tally:  ld hl,(time)
        ld a,h
        or l
        jr z,.wait
        dec hl
        ld (time),hl
        ld a,h
        or l
        jr z,.t0
        dec hl
        ld (time),hl
.t0:    ld a,1                  ; 10 points for every 2 seconds left
        call add_score
.t1:    ld a,SFX_COUNT
        call play_sfx
        ld a,2
        ld (hud_cnt),a
        xor a
        ret
.wait:  ld hl,tally_t
        inc (hl)
        ld a,(hl)
        cp 45
        jr nc,.end
        xor a
        ret
.end:   ld a,R_DONE
        or 1
        ld a,R_DONE
        ret

; P pause, R (twice) restart the crypt, ESC (twice) leave, S sound, M music.
; NZ, A = result to stop the cave
play_keys:
        ld a,(demo_on)
        or a
        jr z,.real
        call any_key            ; any key ends the demo
        or a
        jr z,.dend
        ld a,R_QUIT
        or a
        ret
.dend:  ld a,(demo_end)
        or a
        ret z
        ld a,R_QUIT
        or a
        ret
.real:  ld hl,keysnew
        ld a,(hl)
        ld (hl),0
        ld c,a
        bit 3,c
        call nz,sound_toggle
        bit 5,c
        call nz,music_toggle
        bit 1,c
        jr z,.np
        ld a,(paused)
        xor 1
        ld (paused),a
        jr z,.unp
        call stop_music
        push bc
        call map_show
        pop bc
        ld hl,t_paused
        ld a,WHITE
        ld b,0
        call set_msg
        jr .np
.unp:   push bc
        call map_hide
        call msg_name
        pop bc
.np:    ld a,(arm_t)
        or a
        jr z,.na
        dec a
        ld (arm_t),a
        jr nz,.na
        ld (arm_k),a
.na:    bit 2,c
        jr z,.nr
        ld a,(arm_k)
        cp 1
        jr z,.restart
        ld a,1
        ld hl,t_again
        jr .arm
.nr:    bit 0,c
        jr z,.no
        ld a,(arm_k)
        cp 2
        jr z,.quit
        ld a,2
        ld hl,t_quit
.arm:   ld (arm_k),a
        ld a,50
        ld (arm_t),a
        ld a,WHITE
        ld b,50
        call set_msg
.no:    xor a
        ret
.restart:
        xor a
        ld (arm_k),a
        ld a,(p_alive)          ; Mort gives up: a count of three, then he
        or a                    ; goes up in jewels and the crypt starts again
        jr z,.now
        ld a,(gstate)
        cp G_PLAY
        jr nz,.now
        ld a,(sd_t)
        or a
        jr nz,.no
        ld a,52
        ld (sd_t),a
        jr .no
.now:   ld a,R_AGAIN
        or a
        ret
.quit:  ld a,R_QUIT
        or a
        ret

; the count before Mort gives up (R twice): 3, 2, 1, and a blast of jewels
sd_step:
        ld a,(sd_t)
        or a
        ret z
        dec a
        ld (sd_t),a
        jr z,.bang
        ld hl,t_sd3
        cp 51
        jr z,.say
        ld hl,t_sd2
        cp 34
        jr z,.say
        ld hl,t_sd1
        cp 17
        ret nz
.say:   ld a,BRED
        ld b,0
        call set_msg
        ld a,SFX_COUNTDOWN
        jp play_sfx
.bang:  ld a,(p_alive)
        or a
        ret z
        ld a,1
        ld (sd_on),a
        xor a
        ld (invuln),a
        ld (wards),a
        ld (pg_sync),a
        ld (pg_sync+1),a
        ld hl,$FFFF
        ld (scanptr),hl
        ld hl,(p_ptr)
        ld c,1                  ; the jewelled kind
        jp explode

; ---------------------------------------------------------------------
;  the pause map: the whole crypt, two tiles to a character each way,
;  drawn from the solid things in it, with Mort and the gate marked
; ---------------------------------------------------------------------
MAP_ROW equ PF_TOP+3
MAP_COL equ 4
map_show:
        xor a
        call .pg
        ld a,1
.pg:    call draw_page
        ld a,LV_ATTR            ; the playfield in the text font's bank
        out (P_LV),a
        ld a,PF_TOP
        call row_addr
        push hl
        ld d,h
        ld e,l
        inc de
        ld (hl),1
        ld bc,PF_ROWS*COLS-1
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        pop hl
        push hl
        ld d,h
        ld e,l
        inc de
        ld (hl),$80
        ld bc,PF_ROWS*COLS-1
        ldir
        pop hl
        ld a,h
        add a,8
        ld h,a
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,PF_ROWS*COLS-1
        ldir
        ld hl,CAVE
        ld b,0
.row:   push bc
        push hl
        ld a,b
        add a,MAP_ROW
        call row_addr
        ld de,MAP_COL
        add hl,de
        ex de,hl
        pop hl
        push hl
        ld b,32
.col:   push bc
        push hl
        push de
        call map_cell
        pop de
        ld (de),a
        push de
        ld a,d
        add a,8
        ld d,a
        ld a,b
        ld (de),a
        pop de
        inc de
        pop hl
        inc hl
        inc hl
        pop bc
        djnz .col
        call vschk
        pop hl
        ld de,ROWLEN*2
        add hl,de
        pop bc
        inc b
        ld a,b
        cp 16
        jr nz,.row
        ret

; HL = the top left of four tiles -> A = character, B = colour
map_cell:
        ld bc,0                 ; B colour, C the four quarters
        ld d,0                  ; D: 1 Mort is here, 2 the gate
        ld e,1
        call .p
        inc hl
        ld e,2
        call .p
        push de
        ld de,ROWLEN-1
        add hl,de
        pop de
        ld e,4
        call .p
        inc hl
        ld e,8
        call .p
        ld a,d
        or a
        jr z,.plain
        dec a
        ld b,WHITE
        ld a,']'+$80-32
        ret z
        ld b,YELLOW
        ld a,'X'+$80-32
        ret
.plain: ld a,c
        add a,$80+64
        ret
.p:     ld a,(hl)
        and $7F
        cp T_PLAYER
        jr nz,.p1
        ld d,1
        ret
.p1:    cp T_EXITC
        jr z,.gate
        cp T_EXITO
        jr nz,.p2
.gate:  ld a,d
        or a
        ret nz
        ld d,2
        ret
.p2:    push hl
        ld l,a
        ld h,tflags>>8
        ld a,(hl)
        and F_SOLID
        jr z,.p3
        ld a,c
        or e
        ld c,a
        ld a,b
        or a
        jr nz,.p3
        ld h,CT>>8
        ld b,(hl)
.p3:    pop hl
        ret

; the playfield back as it was
map_hide:
        xor a
        call draw_page
        call game_attrs
        ld a,1
        call draw_page
        call game_attrs
        jp force_both

sound_toggle:
        ld a,(sfxon)
        xor 1
        ld (sfxon),a
        ret
music_toggle:
        ld a,(musicon)
        xor 1
        ld (musicon),a
        jp z,stop_music
        ret

t_paused:  db "PAUSED: THE CRYPT'S MAP - P TO GO ON",0
t_sd3:     db "MORT GIVES UP IN 3 ...",0
t_sd2:     db "MORT GIVES UP IN 2 ..",0
t_sd1:     db "MORT GIVES UP IN 1 .",0
t_again:   db "PRESS R AGAIN TO GIVE UP AND RETRY",0
t_quit:    db "PRESS ESC AGAIN TO LEAVE THE CASTLE",0
t_timeup:  db "THE CANDLE HAS BURNT OUT!",0
t_cleared: db "CRYPT CLEARED!",0
t_bonusover: db "BONUS ROOM OVER",0

; ---------------------------------------------------------------------
;  a whole game from crypt (start_cave)
; ---------------------------------------------------------------------
new_game:
        ld sp,STACK
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (wards),a
        ld (treasures),a
        ld a,START_LIVES
        ld (lives),a
        ld a,(start_cave)
        ld (cave_no),a
.cave:  call cave_load
        jp c,game_won
.again: call cave_start
        call play
        or a
        jr z,.done
        cp R_QUIT
        jp z,game_quit
        cp R_AGAIN
        jr z,.again
        ; Mort is dead
        ld a,(CAVEBUF+CH_FLAGS)
        and 1
        jr nz,.done             ; a bonus room costs nothing: on to the next crypt
        ld a,(demo_on)
        or a
        jp nz,game_quit
        xor a
        ld (wards),a
        ld hl,lives
        dec (hl)
        jr nz,.again
        jp game_over
.done:  ld a,(demo_on)
        or a
        jp nz,game_quit
        ld hl,cave_no
        inc (hl)
        call progress
        jr .cave
