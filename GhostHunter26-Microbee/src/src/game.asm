; =====================================================================
;  GAME: the maze, the hunter, dots, items, power-ups, the HUD and the
;  round's state machine. Logic runs once a frame (25 frames a second).
;
;  The maze is a 13 x 7 grid of nodes, 12 units (24 pixels) apart; one
;  unit is 2 pixels. Node i is at coordinate 12 * (i + 1), so 0 and 168
;  are the two ends of a wrap-around tunnel, just off the screen.
;  Dots sit every 4 units, on the corners where four cells meet.
; =====================================================================
MAZE_ROW equ 1              ; the maze's top row on the screen
NG      equ 4
GSZ     equ 8
G_X     equ 0
G_Y     equ 1
G_DIR   equ 2
G_ST    equ 3
G_FR    equ 4               ; frightened
G_ACC   equ 5
G_TMR   equ 6
ST_PEN  equ 0
ST_LEAVE equ 1
ST_ROAM equ 2
ST_EYES equ 3
ST_ENTER equ 4

GS_READY equ 0
GS_PLAY equ 1
GS_HIT  equ 2
GS_DYING equ 3
GS_CLEAR equ 4
GS_OVER equ 5

RT_BUFFET equ 1
RT_PANIC equ 2

PEN_X   equ 84
PEN_Y   equ 48
DOOR_Y  equ 36
START_Y equ 72
ITEM_Y  equ 60
DOORNODE equ 2*13+6
ITEM_C  equ 19              ; the item's cells: columns 19-20, maze rows 13-14
ITEM_R  equ 13

NPART   equ 6
PSZ     equ 6
P_T     equ 0
P_X     equ 1               ; pixels / 2
P_Y     equ 2
P_VX    equ 3
P_VY    equ 4
P_INK   equ 5

MAXHEART equ 5

; ---------------------------------------------------------------------
;  small helpers
; ---------------------------------------------------------------------
; A = index, HL = table -> A = entry
tab_a:  add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ret
; A = direction -> A = its lane bit
dirbit: push hl
        ld hl,dirbits
        call tab_a
        pop hl
        ret
dirbits: db 1,2,4,8,0
; node coordinate of A (carry set if A is not on a node line)
nodeco: ld hl,nodetab
        call tab_a
        cp $FF
        ccf
        ret
; D = x, E = y -> A = node number (B = node x, C = node y), carry set if not on a node
node_at:
        ld a,d
        call nodeco
        ret c
        ld b,a
        ld a,e
        call nodeco
        ret c
        cp 7
        ccf
        ret c
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        add a,c                 ; 13 * y
        add a,b
        or a
        ret
; A = direction, D = x, E = y -> one unit along (round the tunnel)
step_de:
        or a
        jr z,.r
        dec a
        jr z,.l
        dec a
        jr z,.u
        inc e
        ret
.u:     dec e
        ret
.r:     inc d
        ld a,d
        cp 169
        ret c
        ld d,1
        ret
.l:     dec d
        ret nz
        ld d,168
        ret

; nodetab: node coordinate of an exact node line; neartab: the nearest node
; (nodetab and neartab are generated: tiledata.inc)

; ---------------------------------------------------------------------
;  drawing actors: A = frame, C = ink, D = x, E = y (+ a_ox, a_oy pixels)
; ---------------------------------------------------------------------
put_actor:
        push af
        ld a,c
        ld (spr_ink),a
        ld l,d
        ld h,0
        add hl,hl
        ld bc,-16
        add hl,bc
        ld a,(a_ox)
        ld c,a
        rla
        sbc a,a
        ld b,a
        add hl,bc
        ld (spr_x),hl
        ld l,e
        ld h,0
        add hl,hl
        ld bc,-8
        add hl,bc
        ld a,(a_oy)
        ld c,a
        rla
        sbc a,a
        ld b,a
        add hl,bc
        ld (spr_y),hl
        pop af
        jp spr_draw

; print HL at D (column), E (row) in colour A
print_at:
        ld (txt_col),a
        push hl
        ld hl,G_FONT
        ld (txt_font),hl
        pop hl
        jp print
; print HL centred on row E in colour A
print_mid:
        ld (txt_col),a
        push hl
        ld hl,G_FONT
        ld (txt_font),hl
        pop hl
        jp print_c
; icon HL at D, E in colour C
put_icon:
        push hl
        call cell_of
        pop de
        jp set_cell
; blank cells: D = col, E = row, B = width
blank_cells:
        ld hl,0
        ld (fc_glyph),hl
        xor a
        ld (txt_col),a
        ld c,1
        jp fill_cells

; ---------------------------------------------------------------------
;  the dot map
; ---------------------------------------------------------------------
; dot_cell: redraw corridor cell B (column), C (maze row) from the dot map
dot_cell:
        push bc
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or b
        ld l,a
        ld de,dmap
        add hl,de
        ld d,0                  ; mask of corners with something on them
        ld e,$FF                ; the corner with an energiser
        ld a,(hl)
        or a
        jr z,.c1
        set 0,d
        dec a
        jr z,.c1
        ld e,0
.c1:    inc hl
        ld a,(hl)
        or a
        jr z,.c2
        set 1,d
        dec a
        jr z,.c2
        ld e,1
.c2:    ld bc,63
        add hl,bc
        ld a,(hl)
        or a
        jr z,.c3
        set 2,d
        dec a
        jr z,.c3
        ld e,2
.c3:    inc hl
        ld a,(hl)
        or a
        jr z,.c4
        set 3,d
        dec a
        jr z,.c4
        ld e,3
.c4:    ld a,e
        inc a
        jr z,.plain
        ld a,(en_flash)
        or a
        jr nz,.hide
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        add a,16
        add a,d
        jr .g
.hide:  ld a,e                  ; the energiser's dark phase: leave it out
        call dirbit
        cpl
        and d
        jr .g
.plain: ld a,d
.g:     add a,G_DOT
        pop bc
        push bc
        ld e,a
        ld d,0
        push de
        ld d,b
        ld a,c
        add a,MAZE_ROW
        ld e,a
        call cell_of
        pop de
        ld a,(dotcol)
        ld c,a
        call set_cell
        pop bc
        ret
; dot_point: redraw the four cells round lattice point B, C
dot_point:
        dec b
        dec c
        call dot_cell
        inc b
        call dot_cell
        inc c
        call dot_cell
        dec b
        jp dot_cell

; the four energisers wink
energ_flash:
        ld a,(gtick)
        and 7
        ret nz
        ld a,(en_flash)
        xor 1
        ld (en_flash),a
        ld hl,energ_pts
        ld b,4
.l:     push bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        push bc
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or b
        ld l,a
        ld de,dmap
        add hl,de
        ld a,(hl)
        pop bc
        cp 2
        call z,dot_point
        pop hl
        pop bc
        djnz .l
        ret
energ_pts: db 2,5, 38,5, 2,17, 38,17

; ---------------------------------------------------------------------
;  score (DE = BCD points; doubled under the x2 power-up)
; ---------------------------------------------------------------------
add_score:
        ld a,(demo)
        or a
        ret nz
        ld a,(t_double)
        or a
        call nz,.add
.add:   ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld hl,hud_dirty
        set 0,(hl)
        ; an extra life at 10,000 and then every 50,000
        ld a,(nextlife)
        ld b,a
        ld a,(score)
        cp b
        ret c
        ld a,b
        cp 1
        ld a,4
        jr z,.nl
        ld a,5
.nl:    add a,b
        daa
        ld (nextlife),a
        ld a,(lives)
        cp 5
        ret nc
        inc a
        ld (lives),a
        ld hl,hud_dirty
        set 1,(hl)
        ld a,SFX_LIFE
        call play_sfx
        push de
        ld hl,s_extra
        call say
        pop de
        ret
s_extra: db "EXTRA LIFE!",0

; HL -> 3 BCD bytes -> numbuf: 6 digits
score_text:
        ld de,numbuf
        ld b,3
.l:     ld a,(hl)
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
        djnz .l
        xor a
        ld (de),a
        ret

; ---------------------------------------------------------------------
;  the HUD: row 0 (score, best, round, hearts), row 23 (lives, power bar),
;  row 24 (messages)
; ---------------------------------------------------------------------
draw_hud:
        ld hl,s_1up
        ld de,0*256+0
        ld a,BRED
        call print_at
        ld hl,s_hi
        ld de,12*256+0
        ld a,BRED
        call print_at
        ld hl,s_rd
        ld de,23*256+0
        ld a,BRED
        call print_at
        ld a,(round)
        inc a
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld hl,numbuf
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,numbuf
        ld de,26*256+0
        ld a,WHITE
        call print_at
        ld a,$FF
        ld (bar_lab),a
        call hud_score
        call hud_hearts
        jp hud_power
s_1up:  db "1UP",0
s_hi:   db "HI",0
s_rd:   db "RD",0

hud_score:
        ld hl,score
        call score_text
        ld hl,numbuf
        ld de,4*256+0
        ld a,WHITE
        call print_at
        ; the best score follows the player's once it is beaten
        ld hl,score
        ld de,hs_tab
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.mine
        jr nz,.best
        inc hl
        inc de
        djnz .c
.best:  ld hl,hs_tab
        jr .p
.mine:  ld hl,score
.p:     call score_text
        ld hl,numbuf
        ld de,15*256+0
        ld a,WHITE
        jp print_at

hud_hearts:
        ld b,0
.h:     ld a,b
        cp MAXHEART
        jr z,.lives
        ld c,BRED
        ld hl,IC_HEART
        ld a,(hearts)
        ld e,a
        ld a,b
        cp e
        jr c,.hl
        ld c,DGREY
        ld hl,IC_HEART_E
        cp 3
        jr c,.hl
        ld hl,0                 ; hearts 4 and 5 show only when held
        ld c,0
.hl:    ld a,b
        add a,30
        ld d,a
        ld e,0
        push bc
        call put_icon
        pop bc
        inc b
        jr .h
.lives: ld b,0
.l:     ld a,b
        cp 5
        jr z,.sh
        ld hl,0
        ld c,0
        ld a,(lives)
        or a
        jr z,.ll
        dec a                   ; the life in play is not shown
        ld e,a
        ld a,b
        cp e
        jr nc,.ll
        ld hl,IC_LIFE
        ld c,YELLOW
.ll:    ld d,b
        ld e,23
        push bc
        call put_icon
        pop bc
        inc b
        jr .l
.sh:    ld hl,s_shield
        ld a,(shield)
        or a
        jr nz,.sp
        ld hl,s_blank4
.sp:    ld de,36*256+0
        ld a,BCYAN
        jp print_at
s_shield: db "SHLD",0
s_blank4: db "    ",0

; the power bar: the strongest thing running, and how long it has left
hud_power:
        ld a,(rtype)
        or a
        jr z,.nb
        ld b,a                  ; label 1 BUFFET, 2 PANIC
        ld a,(bonus_t)
        srl a
        jr .have
.nb:    ld b,3
        ld a,(t_hunter)
        or a
        jr nz,.q34
        ld b,4
        ld a,(fr_time)
        or a
        jr nz,.q34
        ld b,5
        ld a,(t_freeze)
        or a
        jr nz,.have
        ld b,6
        ld a,(t_speed)
        or a
        jr nz,.q34
        ld b,7
        ld a,(t_double)
        srl a
        or a
        jr nz,.have
        ld b,0
        jr .have
.q34:   ld c,a                  ; three quarters
        srl a
        srl a
        ld d,a
        ld a,c
        sub d
.have:  cp 80
        jr c,.ok
        ld a,79
.ok:    ld c,a                  ; C = bar length in pixels
        ld a,(bar_lab)
        cp b
        jr nz,.label
        ld a,(bar_px)
        cp c
        ret z
        jr .bar
.label: ld a,b
        ld (bar_lab),a
        push bc
        add a,a
        add a,a
        add a,a
        add a,b                 ; x 9
        ld e,a
        ld d,0
        ld hl,bar_names
        add hl,de
        ld a,(hl)               ; colour
        inc hl
        ld de,7*256+23
        call print_at
        pop bc
.bar:   ld a,c
        ld (bar_px),a
        ld b,0                  ; cell
.c:     ld a,c
        cp 8
        jr c,.part
        ld a,8
.part:  ld e,a
        ld a,c
        sub e
        ld c,a
        ld d,0
        ld hl,IC_BAR0
        add hl,de
        push bc
        ld a,b
        add a,16
        ld d,a
        ld e,23
        ld c,YELLOW
        ld a,(bar_lab)
        cp 4
        jr nz,.pc
        ld c,BBLUE
.pc:    call put_icon
        pop bc
        inc b
        ld a,b
        cp 10
        jr nz,.c
        ret
bar_names:
        db WHITE,"       ",0
        db BMAGENTA,"BUFFET ",0
        db BGREEN,"PANIC  ",0
        db YELLOW,"HUNTER ",0
        db BBLUE,"POWER  ",0
        db BCYAN,"FREEZE ",0
        db YELLOW,"SPEED  ",0
        db BMAGENTA,"DOUBLE ",0

; say: message HL on the bottom row for a couple of seconds
say:    push hl
        ld de,0*256+24
        ld b,40
        call blank_cells
        pop hl
        ld e,24
        ld a,BCYAN
        call print_mid
        ld a,60
        ld (say_t),a
        ret
say_tick:
        ld a,(say_t)
        or a
        ret z
        dec a
        ld (say_t),a
        ret nz
        ld de,0*256+24
        ld b,40
        jp blank_cells

; "READY!" under the pen (corridor cells: put back from the dot map)
MSG_C   equ 17
show_ready:
        ld de,MSG_C*256+ITEM_R+MAZE_ROW
        ld a,YELLOW
        jp print_at
hide_ready:
        ld b,MSG_C
.l:     ld c,ITEM_R
        push bc
        call dot_cell
        pop bc
        inc b
        ld a,b
        cp MSG_C+6
        jr nz,.l
        ld a,(it_type)
        or a
        ret z
        jp item_show

; ---------------------------------------------------------------------
;  a round: the maze out of its block, everything reset
; ---------------------------------------------------------------------
rnd_maze: db 0,1,2,2,3,4,5,5
rnd_type: db 0,0,0,RT_BUFFET,0,0,0,RT_PANIC
tab_pspd: db 25,26,27,28,29,30,30,31,31,32,32,33
tab_gspd: db 20,22,23,24,25,26,27,28,29,30,30,31
tab_fr:  db 110,100,90,80,72,64,56,50,44,38,34,30

round_init:
        call stop_music
        xor a
        ld (tune),a
        call clear_screen
        ld a,(round)
        and 7
        ld e,a
        ld d,0
        ld hl,rnd_maze
        add hl,de
        ld a,(hl)
        ld (mazeidx),a
        ld hl,rnd_type
        add hl,de
        ld a,(hl)
        ld (rtype),a
        ld a,(round)
        cp 12
        jr c,.lv
        ld a,11
.lv:    ld (lvl),a
        ld hl,tab_pspd
        call tab_a
        ld (p_spd),a
        ld a,(lvl)
        ld hl,tab_gspd
        call tab_a
        ld (g_spd),a
        ld a,(lvl)
        ld hl,tab_fr
        call tab_a
        ld (fr_len),a
        ld hl,0
        ld a,(mazeidx)
        or a
        jr z,.r0
        ld b,a
        ld de,MAZE_REC
.m:     add hl,de
        djnz .m
.r0:    ld (mzrec),hl
        ld a,BLK_MAZE
        call map_blk
        ld hl,(mzrec)
        ld de,cur_lo+40*MAZE_ROW
        ld bc,880
        ldir
        ld de,cur_hi+40*MAZE_ROW
        ld bc,880
        ldir
        ld de,cur_col+40*MAZE_ROW
        ld bc,880
        ldir
        ld de,dmap
        ld bc,23*64
        ldir
        ld de,edges
        ld bc,91
        ldir
        ld de,home
        ld bc,91
        ldir
        ld de,dots_left
        ld bc,2
        ldir
        ld de,dotcol
        ld bc,2
        ldir
        ld de,mzname
        ld bc,17
        ldir
        ld a,BLK_RT
        call map_blk
        ld a,(monomode)
        or a
        jr z,.col
        ld a,WHITE
        ld (dotcol),a
.col:   ld a,$FF                ; the HUD rows take no sprites
        ld e,0
        ld c,1
        call block_rows
        ld a,$FF
        ld e,23
        ld c,2
        call block_rows
        call all_dirty
        xor a
        ld (it_type),a
        ld (it_count),a
        ld (it_seq),a
        ld (it_shown),a
        ld (t_double),a
        ld (shield),a
        ld (streak),a
        ld (say_t),a
        ld (en_flash),a
        ld (bonus_t),a
        ld a,(rtype)
        or a
        jr z,.nb
        ld a,125                ; GHOST BUFFET: 20 seconds
        ld (bonus_t),a
        ld a,(rtype)
        cp RT_PANIC
        jr nz,.nb
        ld a,156                ; PELLET PANIC: 25 seconds
        ld (bonus_t),a
.nb:    call actors_reset
        jp draw_hud

; everyone back to their places (round start, and after a life is lost)
actors_reset:
        ld a,PEN_X
        ld (p_x),a
        ld a,START_Y
        ld (p_y),a
        ld a,1
        ld (p_dir),a
        ld a,4
        ld (p_want),a
        xor a
        ld (p_acc),a
        ld (p_moving),a
        ld (p_inv),a
        ld (p_anim),a
        ld (fr_time),a
        ld (fr_chain),a
        ld (t_hunter),a
        ld (t_freeze),a
        ld (t_speed),a
        ld (pop_t),a
        ld (phase),a
        ld a,44
        ld (phase_t),a
        ld hl,trail
        ld b,8
.tr:    ld a,(p_x)
        ld (hl),a
        inc hl
        ld a,(p_y)
        ld (hl),a
        inc hl
        djnz .tr
        ld hl,parts
        ld b,NPART*PSZ
.pc:    ld (hl),0
        inc hl
        djnz .pc
        ld ix,ghosts
        ld hl,gstart
        ld b,NG
.g:     ld a,(hl)
        ld (ix+G_X),a
        inc hl
        ld a,(hl)
        ld (ix+G_Y),a
        inc hl
        ld a,(hl)
        ld (ix+G_ST),a
        inc hl
        ld a,(hl)
        ld (ix+G_TMR),a
        inc hl
        ld (ix+G_DIR),1
        ld (ix+G_ACC),0
        ld (ix+G_FR),0
        ld a,(rtype)
        cp RT_BUFFET
        jr nz,.nf
        ld (ix+G_FR),1
.nf:    cp RT_PANIC
        jr nz,.np
        ld (ix+G_ST),ST_PEN     ; asleep in the pen all round
        ld (ix+G_Y),PEN_Y
.np:    ld de,GSZ
        add ix,de
        djnz .g
        ; the later ghosts come out sooner as the rounds go by
        ld a,(lvl)
        add a,a
        add a,a
        ld b,a
        ld a,(ghosts+2*GSZ+G_TMR)
        sub b
        ld (ghosts+2*GSZ+G_TMR),a
        ld a,(ghosts+3*GSZ+G_TMR)
        sub b
        sub b
        ld (ghosts+3*GSZ+G_TMR),a
        ret
;       x, y, state, pen wait
gstart: db PEN_X,DOOR_Y,ST_ROAM,0
        db PEN_X,PEN_Y,ST_PEN,30
        db PEN_X-12,PEN_Y,ST_PEN,110
        db PEN_X+12,PEN_Y,ST_PEN,200

; ---------------------------------------------------------------------
;  the hunter
; ---------------------------------------------------------------------
player_update:
        ld a,(p_inv)
        or a
        jr z,.ni
        dec a
        ld (p_inv),a
.ni:    ld a,(demo)
        or a
        jr nz,.go
        ld a,(padnew)
        and 15
        jr nz,.pick
        ld a,(pad)
        and 15
        jr z,.go
.pick:  ld b,0
.pb:    rrca
        jr c,.pd
        inc b
        jr .pb
.pd:    ld a,b
        ld (p_want),a
.go:    ; the speed trail remembers where he was
        ld hl,trail+13
        ld de,trail+15
        ld bc,14
        lddr
        ld a,(p_x)
        ld (trail),a
        ld a,(p_y)
        ld (trail+1),a
        ld a,(p_spd)
        ld c,a
        ld a,(t_speed)
        or a
        jr z,.ns
        ld a,c
        add a,12
        ld c,a
.ns:    ld a,(p_acc)
        add a,c
        ld c,a
        and 15
        ld (p_acc),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 15
        ret z
        ld b,a
.st:    push bc
        call p_step
        pop bc
        djnz .st
        ld a,(p_moving)
        or a
        ret z
        ld hl,p_anim
        inc (hl)
        ret

p_step: ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        call node_at
        jr c,.mid
        push af
        ld a,(demo)
        or a
        call nz,demo_ai
        pop af
        ld hl,edges
        call tab_a
        ld c,a                  ; the lanes out of this node
        ld a,(p_want)
        call dirbit
        and c
        jr z,.keep
        ld a,(p_want)
        ld (p_dir),a
        jr .go
.keep:  ld a,(p_dir)
        call dirbit
        and c
        jr nz,.go
        xor a
        ld (p_moving),a
        ret
.mid:   ld a,(p_dir)            ; between nodes: he may turn back
        xor 1
        ld b,a
        ld a,(p_want)
        cp b
        jr nz,.go
        ld (p_dir),a
.go:    ld a,1
        ld (p_moving),a
        ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        ld a,(p_dir)
        call step_de
        ld a,d
        ld (p_x),a
        ld a,e
        ld (p_y),a
        ; fall into eat_check

; is he on a dot?
eat_check:
        ld a,(p_x)
        cp 12
        ret c
        cp 157
        ret nc
        and 3
        ret nz
        ld a,(p_y)
        and 3
        ret nz
        ld a,(p_x)
        rrca
        rrca
        and $3F
        dec a
        ld b,a                  ; lattice x
        ld a,(p_y)
        rrca
        rrca
        and $3F
        dec a
        ld c,a                  ; lattice y
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or b
        ld l,a
        ld de,dmap
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        push af
        call dot_point
        ld hl,(dots_left)
        dec hl
        ld (dots_left),hl
        pop af
        dec a
        jr nz,energiser
        ; a dot
        ld de,$0010
        call add_score
        ld a,(p_anim)
        and 2
        ld a,SFX_WAKA1
        jr z,.w
        ld a,SFX_WAKA2
.w:     call play_sfx
        ld a,20
        ld (streak_t),a
        ld hl,streak
        inc (hl)
        ld a,(hl)
        cp 30
        jr c,.items
        ld (hl),0
        ld de,$0300
        call add_score
        ld a,SFX_STREAK
        call play_sfx
        ld hl,s_streak
        call say
.items: ld hl,it_count
        inc (hl)
        ld a,(hl)
        cp 60
        ret c
        ld (hl),0
        jp item_spawn
s_streak: db "30 IN A ROW! +300",0

energiser:
        ld de,$0050
        call add_score
        ld a,SFX_ENERG
        call play_sfx
        ld a,(fr_len)
        ld (fr_time),a
        xor a
        ld (fr_chain),a
        ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        ld c,WHITE
        call burst
        ; fall into scare_all

; every ghost out of the eyes turns blue and turns round
scare_all:
        ld ix,ghosts
        ld b,NG
.g:     ld a,(ix+G_ST)
        cp ST_EYES
        jr nc,.nx
        ld (ix+G_FR),1
        cp ST_ROAM
        jr nz,.nx
        ld a,(ix+G_DIR)
        xor 1
        ld (ix+G_DIR),a
.nx:    ld de,GSZ
        add ix,de
        djnz .g
        ret
calm_all:
        ld a,(t_hunter)
        or a
        ret nz
        ld a,(fr_time)
        or a
        ret nz
        ld a,(rtype)
        cp RT_BUFFET
        ret z
        ld hl,ghosts+G_FR
        ld de,GSZ
        ld b,NG
.g:     ld (hl),0
        add hl,de
        djnz .g
        ret

; ---------------------------------------------------------------------
;  timers (every other frame): fright, powers, the scatter / chase beat
; ---------------------------------------------------------------------
timers: ld a,(streak_t)
        or a
        jr z,.s0
        dec a
        ld (streak_t),a
        jr nz,.s0
        ld (streak),a
.s0:    ld a,(gtick)
        and 1
        ret nz
        ld hl,fr_time
        ld a,(hl)
        or a
        jr z,.f0
        dec (hl)
        call z,calm_all
.f0:    ld hl,t_hunter
        ld a,(hl)
        or a
        jr z,.h0
        dec (hl)
        call z,calm_all
.h0:    ld hl,t_freeze
        ld a,(hl)
        or a
        jr z,.z0
        dec (hl)
.z0:    ld hl,t_speed
        ld a,(hl)
        or a
        jr z,.p0
        dec (hl)
.p0:    ld hl,t_double
        ld a,(hl)
        or a
        jr z,.d0
        dec (hl)
.d0:    ld a,(gtick)
        and 3
        ret nz
        call hud_power
        ld hl,bonus_t
        ld a,(hl)
        or a
        jr z,.b0
        dec (hl)
        ld a,(hl)
        cp 32
        jr nc,.b0
        and 3
        ld a,SFX_TICK
        call z,play_sfx
.b0:    ; scatter and chase take turns (the beat rests while ghosts are blue)
        ld a,(fr_time)
        or a
        ret nz
        ld a,(phase)
        cp 5
        ret nc
        ld hl,phase_t
        dec (hl)
        ret nz
        inc a
        ld (phase),a
        ld hl,ph_tab
        call tab_a
        ld (phase_t),a
        ld ix,ghosts
        ld b,NG
.g:     ld a,(ix+G_ST)
        cp ST_ROAM
        jr nz,.nx
        ld a,(ix+G_FR)
        or a
        jr nz,.nx
        ld a,(ix+G_DIR)
        xor 1
        ld (ix+G_DIR),a
.nx:    ld de,GSZ
        add ix,de
        djnz .g
        ret
ph_tab: db 44,125,31,125,31,255

; ---------------------------------------------------------------------
;  items on the node under the pen: power-ups and treasures
; ---------------------------------------------------------------------
item_spawn:
        ld a,(it_type)
        or a
        ret nz
        ld a,(rtype)
        or a
        ret nz
        ld hl,it_seq
        inc (hl)
        bit 0,(hl)
        jr z,.treasure
.rp:    ld b,5                  ; SPEED FREEZE DOUBLE SHIELD HEART
        call rand_n
        inc a
        cp IT_FREEZE
        jr nz,.n1
        ld b,a
        ld a,(round)
        cp 1
        jr c,.rp
        ld a,b
.n1:    cp IT_SHIELD
        jr nz,.n2
        ld b,a
        ld a,(round)
        cp 2
        jr c,.rp
        ld a,b
.n2:    cp IT_HEART
        jr nz,.set
        ld b,a
        ld a,(hearts)
        cp 3
        jr nc,.rp               ; hearts only turn up when he is short
        ld a,b
        jr .set
.treasure:
        ld a,(round)
        cp 6
        jr c,.tr
        ld a,5
.tr:    add a,NPOWER+1
.set:   ld (it_type),a
        ld a,125                ; ten seconds
        ld (it_timer),a
        ld a,SFX_SPAWN
        call play_sfx
        ; fall into item_show
item_show:
        ld a,1
        ld (it_shown),a
        ld a,(it_type)
        dec a
        ld d,ITEM_C
        ld e,ITEM_R+MAZE_ROW
        ; fall into put_tile
; put_tile: item A (0-based) with its top-left cell at D, E
put_tile:
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        add hl,hl
        add hl,hl               ; x 12
        ld bc,item_tab
        add hl,bc
        ld (t_ptr),hl
        ld b,0
.q:     push bc
        push de
        ld a,b
        and 1
        add a,d
        ld d,a
        ld a,b
        rrca
        and 1
        add a,e
        ld e,a
        call cell_of
        push hl
        ld hl,(t_ptr)
        ld a,b
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld hl,(t_ptr)
        ld a,b
        add a,8
        ld e,a
        ld d,0
        add hl,de
        ld c,(hl)
        pop de
        pop hl
        call set_cell
        pop de
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.q
        ret

item_hide:
        xor a
        ld (it_shown),a
        ld b,ITEM_C
        ld c,ITEM_R
        call dot_cell
        ld b,ITEM_C+1
        ld c,ITEM_R
        call dot_cell
        ld b,ITEM_C
        ld c,ITEM_R+1
        call dot_cell
        ld b,ITEM_C+1
        ld c,ITEM_R+1
        jp dot_cell

items_update:
        ld a,(it_type)
        or a
        ret z
        ; taken?
        ld a,(p_x)
        sub PEN_X
        jr nc,.ax
        neg
.ax:    cp 4
        jr nc,.time
        ld a,(p_y)
        sub ITEM_Y
        jr nc,.ay
        neg
.ay:    cp 4
        jr c,item_take
.time:  ld a,(gtick)
        and 1
        ret nz
        ld hl,it_timer
        dec (hl)
        jr z,.gone
        ld a,(hl)
        cp 25
        ret nc
        and 3                   ; the last two seconds: it blinks
        ret nz
        ld a,(it_shown)
        or a
        jp z,item_show
        jp item_hide
.gone:  xor a
        ld (it_type),a
        jp item_hide

item_take:
        call item_hide
        ld a,(it_type)
        ld b,a
        xor a
        ld (it_type),a
        ld a,b
        cp NPOWER+1
        jr nc,.treasure
        push bc
        ld a,SFX_POWER
        call play_sfx
        ld d,PEN_X
        ld e,ITEM_Y
        ld c,YELLOW
        call burst
        pop bc
        ld a,b
        dec a
        jr z,.speed
        dec a
        jr z,.freeze
        dec a
        jr z,.double
        dec a
        jr z,.shield
        dec a
        jr z,.heart
        ; the star: HUNTER MODE
        ld a,100
        ld (t_hunter),a
        call scare_all
        ld hl,s_hunter
        jp say
.speed: ld a,100
        ld (t_speed),a
        ld hl,s_speed
        jp say
.freeze:
        ld a,75
        ld (t_freeze),a
        ld a,SFX_FREEZE
        call play_sfx
        ld hl,s_freeze
        jp say
.double:
        ld a,150
        ld (t_double),a
        ld hl,s_double
        jp say
.shield:
        ld a,1
        ld (shield),a
        ld hl,hud_dirty
        set 1,(hl)
        ld hl,s_shieldm
        jp say
.heart: ld a,(hearts)
        cp MAXHEART
        jr nc,.full
        inc a
        ld (hearts),a
.full:  ld hl,hud_dirty
        set 1,(hl)
        ld hl,s_heart
        jp say
.treasure:
        sub NPOWER+1
        push af
        ld a,SFX_ITEM
        call play_sfx
        ld d,PEN_X
        ld e,ITEM_Y
        ld c,WHITE
        call burst
        pop af
        push af
        add a,a
        ld hl,tre_val
        call tab_a
        ld d,a
        ld e,0
        call add_score
        pop af
        add a,a
        ld e,a
        ld d,0
        ld hl,tre_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp say
tre_val: db $01,0,$03,0,$05,0,$07,0,$10,0,$20,0
tre_names: dw s_tr0,s_tr1,s_tr2,s_tr3,s_tr4,s_tr5
s_tr0:  db "CANDY! 100",0
s_tr1:  db "PUMPKIN! 300",0
s_tr2:  db "POTION! 500",0
s_tr3:  db "SKULL! 700",0
s_tr4:  db "GEM! 1000",0
s_tr5:  db "CROWN! 2000",0
s_speed: db "ZOOM!",0
s_freeze: db "BRRR! GHOSTS ON ICE",0
s_double: db "DOUBLE POINTS!",0
s_shieldm: db "SHIELD UP!",0
s_heart: db "A HEART!",0
s_hunter: db "HUNTER MODE! 1000 A GHOST",0

; ---------------------------------------------------------------------
;  sparks: a burst of four from D, E (units) in colour C; they fly apart
; ---------------------------------------------------------------------
burst:  ld hl,parts
        ld b,4
.p:     ld (hl),10
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        inc hl
        push de
        push hl
        ld a,b
        dec a
        add a,a
        ld hl,burst_v
        call tab_a
        pop hl
        ld (hl),a
        inc hl
        push hl
        ld a,b
        dec a
        add a,a
        inc a
        ld hl,burst_v
        call tab_a
        pop hl
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        pop de
        djnz .p
        ret
burst_v: db 1,1, -1,1, 1,-1, -1,-1

parts_update:
        ld ix,parts
        ld b,NPART
.p:     ld a,(ix+P_T)
        or a
        jr z,.nx
        dec (ix+P_T)
        ld a,(ix+P_X)
        add a,(ix+P_VX)
        ld (ix+P_X),a
        ld a,(ix+P_Y)
        add a,(ix+P_VY)
        ld (ix+P_Y),a
.nx:    ld de,PSZ
        add ix,de
        djnz .p
        ret
parts_draw:
        xor a
        ld (a_ox),a
        ld (a_oy),a
        ld ix,parts
        ld b,NPART
.p:     push bc
        ld a,(ix+P_T)
        or a
        jr z,.nx
        ld d,(ix+P_X)
        ld e,(ix+P_Y)
        ld a,d
        cp 10
        jr c,.nx
        cp 160
        jr nc,.nx
        ld a,e
        cp 12
        jr c,.nx
        cp 86
        jr nc,.nx
        ld a,4
        ld (a_ox),a
        ld (a_oy),a
        ld c,(ix+P_INK)
        ld a,(ix+P_T)
        and 2
        rrca
        add a,SF_SPARK0
        call put_actor
.nx:    pop bc
        ld de,PSZ
        add ix,de
        djnz .p
        ret

; ---------------------------------------------------------------------
;  drawing the hunter
; ---------------------------------------------------------------------
mouth_seq: db 0,1,2,1
hat_of:  db SF_HAT_R,SF_HAT_L,SF_HAT_F,SF_HAT_F
hunt_col: db WHITE,YELLOW,BRED,YELLOW

draw_player:
        xor a
        ld (a_ox),a
        ld (a_oy),a
        ld a,(p_inv)
        or a
        jr z,.vis
        ld a,(gtick)
        and 1
        ret nz
.vis:   ld a,(t_speed)
        or a
        jr z,.nt
        ; the speed trail: two dim echoes
        ld a,(trail+6)
        ld d,a
        ld a,(trail+7)
        ld e,a
        ld c,BLUE
        call .face
        ld a,(trail+2)
        ld d,a
        ld a,(trail+3)
        ld e,a
        ld c,BROWN
        call .face
.nt:    ld a,(shield)
        or a
        jr z,.ns
        ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        ld a,(gtick)
        rrca
        rrca
        and 1
        add a,SF_RING0
        ld c,BCYAN
        call put_actor
.ns:    ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        ld a,(p_dir)
        ld hl,hat_of
        call tab_a
        ld c,BRED
        push de
        call put_actor
        pop de
        ld c,YELLOW
        ld a,(t_hunter)
        or a
        jr z,.face
        ld a,(gtick)
        rrca
        and 3
        ld hl,hunt_col
        call tab_a
        ld c,a
.face:  ld a,(p_anim)
        rrca
        and 3
        ld hl,mouth_seq
        call tab_a
        ld b,a                  ; mouth 0..2
        ld a,(p_dir)
        cp 2
        jr nc,.ud
        ; frames: FACE_R0, FACE_L0, FACE_R1, FACE_L1, FACE_R2, FACE_L2
        add a,b
        add a,b
        add a,SF_FACE_R0
        jp put_actor
.ud:    ; FACE_U0, FACE_D0, FACE_U1, FACE_D1
        sub 2
        srl b
        jr nc,.u0
        inc b
.u0:    bit 0,b
        jr z,.u1
        add a,2
.u1:    add a,SF_FACE_U0
        jp put_actor

; the last moments: the head shrinks away and the hat drops
draw_death:
        xor a
        ld (a_ox),a
        ld (a_oy),a
        ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        ld a,(gtimer)
        cp 44
        jr c,.an
        push de
        ld a,SF_HAT_F
        ld c,BRED
        call put_actor
        pop de
        ld a,SF_FACE_D0
        ld c,YELLOW
        jp put_actor
.an:    ld b,a
        ld a,43
        sub b
        rrca
        rrca
        rrca
        and 7                   ; 0..5
        cp 4
        jr c,.fr
        ld a,8                  ; the hat alone, on the floor
        ld (a_oy),a
        ld a,SF_HAT_F
        ld c,BRED
        jp put_actor
.fr:    push af
        push de
        add a,SF_DIE0
        ld c,YELLOW
        call put_actor
        pop de
        pop af
        add a,a
        ld (a_oy),a
        ld a,SF_HAT_F
        ld c,BRED
        jp put_actor

draw_pop:
        ld a,(pop_t)
        or a
        ret z
        dec a
        ld (pop_t),a
        xor a
        ld (a_ox),a
        ld a,4
        ld (a_oy),a
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        ld a,(pop_f)
        ld c,BCYAN
        jp put_actor

; everything that moves, back to front
draw_all:
        call draw_ghosts
        ld a,(gstate)
        cp GS_DYING
        jp z,draw_death
        cp GS_OVER
        ret z
        cp GS_HIT
        call nz,draw_player     ; (the score stands in for him while he chews)
        call parts_draw
        jp draw_pop

; ---------------------------------------------------------------------
;  the in-play tune follows the mood
; ---------------------------------------------------------------------
tune_pick:
        ld b,3
        ld a,(t_hunter)
        or a
        jr nz,.have
        dec b
        ld a,(fr_time)
        or a
        jr nz,.have
        ld a,(rtype)
        cp RT_BUFFET
        jr z,.have
        dec b
.have:  ld a,(tune)
        cp b
        ret z
        ld a,b
        ld (tune),a
        dec a
        jr z,.game
        dec a
        jr z,.fright
        ld hl,mus_hunter_0
        ld de,mus_hunter_1
        jp play_music
.fright:
        ld hl,mus_fright_0
        ld de,mus_fright_1
        jp play_music
.game:  ld hl,mus_game_0
        ld de,mus_game_1
        jp play_music

; the walls flash when a maze is cleared
flash_walls:
        ld hl,cur_col+40*MAZE_ROW
        ld bc,880
.l:     ld a,(hl)
        xor $0F
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        jp all_dirty

; ---------------------------------------------------------------------
;  game_run: a whole game (or the attract demo). -> A = 0 game over,
;  1 given up (ESC), 2 the demo ended, 3 the demo was interrupted by start
; ---------------------------------------------------------------------
game_run:
        xor a
        ld (round),a
        ld hl,score
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld a,1
        ld (nextlife),a
        ld a,3
        ld (lives),a
        ld (hearts),a
        ld hl,0
        ld (att_t),hl
.round: call round_init
        ld hl,mzname
        call say
        ld a,(rtype)
        or a
        jr z,.rj
        ld hl,s_buffet
        dec a
        jr z,.bs
        ld hl,s_panic
.bs:    call say
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        jr .rm
.rj:    ld hl,mus_ready_0
        ld de,mus_ready_1
.rm:    call play_music
        ld a,56
.ready: ld (gtimer),a
        ld a,GS_READY
        ld (gstate),a
        xor a
        ld (paused),a
        ld (tune),a
        ld hl,s_ready
        call show_ready
        ; ---- the frame loop
.loop:  call frame_begin
        call read_input
        ld a,(demo)
        or a
        jr z,.keys
        ; the demo: start begins a game, time runs out
        ld a,(padnew)
        and $10
        ld b,a
        ld a,(keysnew)
        and $20
        or b
        ld a,3
        jp nz,.exit
        ld hl,(att_t)
        inc hl
        ld (att_t),hl
        ld de,700
        or a
        sbc hl,de
        ld a,2
        jp nc,.exit
        jr .run
.keys:  ld a,(keysnew)
        bit 0,a
        ld a,1
        jp nz,.exit
        ld a,(keysnew)
        bit 2,a
        call nz,toggle_sound
        ld a,(keysnew)
        bit 1,a
        jr z,.np
        ld a,(paused)
        xor 1
        ld (paused),a
        ld hl,s_paused
        call nz,say
.np:    ld a,(paused)
        or a
        jr z,.run
        call draw_all
        call input_used
        call frame_end
        jr .loop
.run:   ld hl,gtick
        inc (hl)
        ld a,(gstate)
        or a
        jr z,.s_ready
        dec a
        jr z,.s_play
        dec a
        jr z,.s_hit
        dec a
        jp z,.s_dying
        dec a
        jp z,.s_clear
        ; ---- GAME OVER
        ld hl,gtimer
        dec (hl)
        jp nz,.common
        xor a
        jp .exit
.s_ready:
        ld hl,gtimer
        dec (hl)
        jp nz,.common
        call hide_ready
        ld a,GS_PLAY
        ld (gstate),a
        jp .common
.s_hit: ld hl,gtimer
        dec (hl)
        jp nz,.common
        ld a,GS_PLAY
        ld (gstate),a
        jp .common
.s_play:
        call player_update
        call ghosts_update
        call collide
        ld a,(gstate)
        cp GS_PLAY
        jp nz,.common
        call timers
        call items_update
        call energ_flash
        call tune_pick
        ; cleared? (or the bonus round's time is up)
        ld hl,(dots_left)
        ld a,h
        or l
        jp z,.clear
        ld a,(rtype)
        or a
        jp z,.common
        ld a,(bonus_t)
        or a
        jp nz,.common
.clear: ld a,GS_CLEAR
        ld (gstate),a
        ld a,64
        ld (gtimer),a
        call stop_music
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld a,(rtype)
        cp RT_PANIC
        jp nz,.common
        ld hl,(dots_left)
        ld a,h
        or l
        jp nz,.common
        ld de,$5000
        call add_score
        ld hl,s_panicwin
        call say
        jp .common
.s_dying:
        ld hl,gtimer
        dec (hl)
        jp nz,.common
        ld hl,lives
        dec (hl)
        jp z,.over
        ld a,3
        ld (hearts),a
        ld hl,hud_dirty
        set 1,(hl)
        call actors_reset
        ld a,30
        jp .ready
.over:  ld a,GS_OVER
        ld (gstate),a
        ld a,90
        ld (gtimer),a
        ld hl,s_over
        ld de,15*256+ITEM_R+MAZE_ROW
        ld a,BRED
        call print_at
        ld hl,mus_over_0
        ld de,mus_over_1
        call play_music
        jp .common
.s_clear:
        ld a,(gtimer)
        and 7
        call z,flash_walls
        ld hl,gtimer
        dec (hl)
        jp nz,.common
        ld hl,round
        inc (hl)
        ld a,(demo)
        or a
        jp nz,.round
        ld a,(round)
        and 7
        cp 2
        ld a,0
        call z,intermission
        ld a,(round)
        and 7
        cp 5
        ld a,1
        call z,intermission
        jp .round
.common:
        call parts_update
        call say_tick
        ld a,(hud_dirty)
        or a
        jr z,.nh
        ld b,a
        xor a
        ld (hud_dirty),a
        push bc
        bit 0,b
        call nz,hud_score
        pop bc
        bit 1,b
        call nz,hud_hearts
.nh:    call draw_all
        call sound_tick
        call input_used
        call frame_end
        jp .loop
.exit:  push af
        call input_used
        call stop_music
        pop af
        ld (gresult),a
        ret
s_ready: db "READY!",0
s_over: db "GAME  OVER",0
s_paused: db "PAUSED - H TO GO ON",0
s_buffet: db "GHOST BUFFET! EAT THEM ALL!",0
s_panic: db "PELLET PANIC! CLEAR IT FOR 5000",0
s_panicwin: db "CLEARED! +5000",0

toggle_sound:
        ld a,(musicon)
        xor 1
        ld (musicon),a
        ld (sfxon),a
        xor a
        ld (tune),a
        jp stop_music
