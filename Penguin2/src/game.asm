; =====================================================================
;  PENGUIN 2 - gameplay
; =====================================================================
G_EMPTY equ 0
G_ICE   equ 1
G_EGG   equ 2
G_CRYS  equ 3
G_ROCK  equ 4
G_BREAK equ 5
G_ITEM  equ 6
G_WALL  equ $FF
; actor / block record (16 bytes)
A_TYPE  equ 0                   ; monsters: 1 blob 2 chomper 3 flitter 4 wisp ; blocks: active flag
A_ST    equ 1                   ; monster state ; blocks: grid code carried
A_CX    equ 2
A_CY    equ 3
A_SUB   equ 4
A_DIR   equ 5
A_SPD   equ 6                   ; blocks: kill count
A_ACC   equ 7
A_TIM   equ 8
A_X     equ 9
A_Y     equ 10
A_AUX   equ 12                  ; munch dir / carrying block index / block index
A_PH    equ 13                  ; wisp phased inside ice
A_CH    equ 14                  ; chase chance
ST_HATCH equ 1
ST_WALK equ 2
ST_STUN equ 3
ST_CARRY equ 4
ST_DIE  equ 5
ST_POOF equ 6
ST_MUNCH equ 7
; popup strings
P_100   equ 0
P_400   equ 1
P_1600  equ 2
P_3200  equ 3
P_6400  equ 4
P_500   equ 5
P_1000  equ 6
P_2000  equ 7
P_10000 equ 8
P_5000  equ 9
P_1UP   equ 10
P_GOLD  equ 11

dxtab:  db 1,$FF,0,0
dytab:  db 0,0,$FF,1
dirbit: db 1,2,4,8

; ---------------------------------------------------------------------
; grid helpers
; step_bc: move B,C one cell in direction A (A preserved in E)
step_bc:
        push hl
        ld e,a
        ld d,0
        ld hl,dxtab
        add hl,de
        ld a,b
        add a,(hl)
        ld b,a
        ld hl,dytab
        add hl,de
        ld a,c
        add a,(hl)
        ld c,a
        ld a,e
        pop hl
        ret
; cell_ptr: B,C -> HL (in range only)
cell_ptr:
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        or $80
        ld l,a
        ld h,GRID/256
        ret
; cell_get: B,C -> A (G_WALL if outside)
cell_get:
        ld a,b
        cp 15
        jr nc,.w
        ld a,c
        cp 8
        jr nc,.w
        push hl
        call cell_ptr
        ld a,(hl)
        pop hl
        ret
.w:     ld a,G_WALL
        ret
; cell_set: A code at B,C
cell_set:
        push hl
        push af
        call cell_ptr
        pop af
        ld (hl),a
        pop hl
        ret

; tile for the code in A at B,C -> A
tile_for:
        cp G_EMPTY
        jr nz,.ne
        ld a,b
        add a,a
        add a,b
        ld e,a
        ld a,c
        add a,a
        add a,a
        add a,c
        add a,e
        and 7
        ld a,T_EMPTY
        ret nz
        ld a,T_SPARK
        ret
.ne:    cp G_CRYS
        jr nz,.nc
        ld a,T_CRYS
        ret
.nc:    cp G_ROCK
        jr nz,.nr
        ld a,T_ROCK
        ret
.nr:    cp G_ITEM
        jr nz,.ni
        ld a,(itemkind)
        add a,T_FISH
        ret
.ni:    ld a,(goldmode)
        or a
        ld a,T_ICE
        ret z
        ld a,T_GOLDB
        ret

; draw_cell: B,C (from the grid code)
draw_cell:
        push bc
        call cell_get
        call tile_for
        pop bc
; draw_tile: A = tile, B,C = cell
draw_tile:
        push bc
        push de
        ld d,a
        ld a,b
        add a,a
        inc a
        ld b,a                  ; byte column
        ld a,c
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e
        add a,YOFF
        ld e,a                  ; pixel row
        ld a,d
        ld d,b
        call draw_tile_at
        pop de
        pop bc
        ret
; draw_tile_at: A = tile, D = byte column, E = pixel row (BG, queued unless noq)
draw_tile_at:
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,bc               ; *14
        ld bc,tiles
        add hl,bc
        push hl
        call scraddr
        ld a,h
        or $88
        ld h,a
        pop de
        ld b,7
.r:     ld a,(de)
        ld (hl),a
        inc de
        inc l
        ld a,(de)
        ld (hl),a
        inc de
        dec l
        ld a,l
        add a,32
        ld l,a
        jr nc,.nc
        inc h
.nc:    djnz .r
        pop de
        ld a,(noq)
        or a
        ret nz
        ld b,2
        ld c,7
        jp queue_rect

; draw every cell (no queue: used before a reveal / to repair a region)
draw_all_cells:
        ld a,1
        ld (noq),a
        ld c,0
.y:     ld b,0
.x:     push bc
        call draw_cell
        pop bc
        inc b
        ld a,b
        cp 15
        jr nz,.x
        inc c
        ld a,c
        cp 8
        jr nz,.y
        xor a
        ld (noq),a
        ret

; walls: A = side (0 R,1 L,2 U,3 D), B = byte
draw_wall_side:
        push af
        ld a,b
        ld (tmpx),a
        pop af
        ld de,$1F05
        ld bc,$013B
        or a
        jr z,.go
        ld de,$0005
        dec a
        jr z,.go
        ld de,$0005
        ld bc,$2001
        dec a
        jr z,.go
        ld de,$003E
        ld bc,$2002
.go:    ld a,(tmpx)
        jp fill_rect
draw_walls:
        ld b,$AA
        xor a
        call .one
        ld a,1
        call .one
        ld a,2
        call .one
        ld a,3
.one:   push bc
        call draw_wall_side
        pop bc
        ret

; ---------------------------------------------------------------------
; calc_xy: IX record -> A_X, A_Y
calc_xy:
        ld a,(ix+A_CX)
        add a,a
        add a,a
        add a,a
        add a,XOFF
        ld b,a
        ld a,(ix+A_CY)
        ld c,a
        add a,a
        add a,a
        add a,a
        sub c
        add a,YOFF
        ld c,a
        ld a,(ix+A_SUB)
        or a
        jr z,.st
        ld e,a
        ld d,0
        ld a,(ix+A_DIR)
        or a
        jr z,.r
        dec a
        jr z,.l
        dec a
        jr z,.u
        ld hl,ytab
        add hl,de
        ld a,c
        add a,(hl)
        ld c,a
        jr .st
.r:     ld a,b
        add a,e
        ld b,a
        jr .st
.l:     ld a,b
        sub e
        ld b,a
        jr .st
.u:     ld hl,ytab
        add hl,de
        ld a,c
        sub (hl)
        ld c,a
.st:    ld (ix+A_X),b
        ld (ix+A_Y),c
        ret

; rounded cell of IX (the cell it is mostly in) -> B,C
round_cell:
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_SUB)
        cp 4
        ret c
        ld a,(ix+A_DIR)
        cp 4
        ret nc
        jp step_bc

; abs difference: A = |A - B|
absdiff:
        sub b
        ret nc
        neg
        ret

; ---------------------------------------------------------------------
; LEVEL SETUP
; ---------------------------------------------------------------------
setup_level:
        ld hl,peng
        ld de,peng+1
        ld bc,particles+60-peng-1
        ld (hl),0
        ldir
        xor a
        ld (hurry),a
        ld (crystal_done),a
        ld (fishval),a
        ld (golds),a
        ld (skatetim),a
        ld (walltim),a
        ld (labeltim),a
        ld (pushtim),a
        ld (invuln),a
        ld (framesub),a
        ld (flashtim),a
        ld hl,0
        ld (itemtim),hl
        ld (curlabel),hl
        ld a,(level)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,leveltab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (lvptr),hl           ; name
        ex de,hl
        ld a,(hl)
        ld (startx),a
        inc hl
        ld a,(hl)
        ld (starty),a
        inc hl
        ld a,(hl)
        ld (lv_eggs),a
        inc hl
        ld a,(hl)
        ld (lv_max),a
        inc hl
        ld a,(hl)
        ld (lv_roster),a
        inc hl
        ld a,(hl)
        ld (lv_speed),a
        inc hl
        ld a,(hl)
        ld (goldmode),a
        inc hl
        inc hl
        ld de,GRID
        ld bc,128
        ldir
        ld a,(goldmode)
        or a
        ld a,MODE1|CSS1
        jr z,.p
        ld a,MODE1
.p:     ld (palbase),a
        ld a,(goldmode)
        or a
        ld a,99
        jr z,.t
        ld a,30
.t:     ld (timesec),a
        ; hide the eggs inside random ice blocks, away from the start
        ld a,(lv_eggs)
        ld (eggs_left),a
        or a
        jr z,.ne
        ld b,a
.pl:    push bc
        ld d,0
.try:   inc d
        jr z,.give              ; give up after 256 tries
        call random
        and $7F
        ld c,a
        and 15
        cp 15
        jr z,.try
        ld l,c
        set 7,l
        ld h,GRID/256
        ld a,(hl)
        cp G_ICE
        jr nz,.try
        push hl
        ld a,c
        and 15
        ld b,a
        ld a,(startx)
        call absdiff_ab
        ld e,a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 7
        ld b,a
        ld a,(starty)
        call absdiff_ab
        add a,e
        pop hl
        cp 3
        jr c,.try
        ld (hl),G_EGG
        pop bc
        djnz .pl
        jr .ne
.give:  pop bc
        ld hl,eggs_left
        ld a,(hl)
        sub b
        ld (hl),a
.ne:    xor a
        ld (alive),a
        ld a,40
        ld (hatchdelay),a
        call init_breaks
        call init_popups
        ; penguin
        ld ix,peng
        ld (ix+A_TYPE),1
        ld a,(startx)
        ld (ix+A_CX),a
        ld a,(starty)
        ld (ix+A_CY),a
        ld (ix+A_DIR),3
        ld a,3
        ld (facing),a
        call calc_xy
        ; build the screen in BG
        xor a
        call cls_bg
        call draw_walls
        call draw_all_cells
        call hud_full
        ret
absdiff_ab:     ; A = |A - B|
        sub b
        ret nc
        neg
        ret

; respawn after a death
respawn:
        ld hl,blks
        ld de,blks+1
        ld bc,31
        ld (hl),0
        ldir
        ; monsters get a short daze so the player has a moment
        ld ix,mons
        ld b,4
.m:     ld a,(ix+A_TYPE)
        or a
        jr z,.mn
        ld a,(ix+A_ST)
        cp ST_WALK
        jr z,.st
        cp ST_MUNCH
        jr nz,.mn
.st:    ld (ix+A_ST),ST_STUN
        ld (ix+A_TIM),100
.mn:    ld de,16
        add ix,de
        djnz .m
        ; spawn cell: start if empty, else nearest empty
        ld a,(startx)
        ld b,a
        ld a,(starty)
        ld c,a
        call cell_get
        or a
        jr z,.ok
        ld a,$FF
        ld (bestd),a
        ld c,0
.y:     ld b,0
.x:     call cell_get
        or a
        jr nz,.nx
        push bc
        ld a,(startx)
        ld e,b
        ld b,a
        ld a,e
        call absdiff_ab
        ld d,a
        pop bc
        push bc
        ld a,(starty)
        ld e,c
        ld b,a
        ld a,e
        call absdiff_ab
        add a,d
        pop bc
        ld e,a
        ld a,(bestd)
        cp e
        jr c,.nx
        jr z,.nx
        ld a,e
        ld (bestd),a
        ld a,b
        ld (tmpx),a
        ld a,c
        ld (tmpy),a
.nx:    inc b
        ld a,b
        cp 15
        jr nz,.x
        inc c
        ld a,c
        cp 8
        jr nz,.y
        ld a,(tmpx)
        ld b,a
        ld a,(tmpy)
        ld c,a
.ok:    ld ix,peng
        ld (ix+A_CX),b
        ld (ix+A_CY),c
        ld (ix+A_SUB),0
        ld (ix+A_DIR),3
        ld a,3
        ld (facing),a
        xor a
        ld (pushtim),a
        ld (skatetim),a
        ld a,120
        ld (invuln),a
        call calc_xy
        jp hud_label_restore

; ---------------------------------------------------------------------
; stage intro: reveal, banner, flashing eggs.  NZ = demo aborted
; ---------------------------------------------------------------------
stage_intro:
        call wipe_show
        ld a,(goldmode)
        or a
        jr z,.n
        ld hl,s_goldrush
        call banner
        ld hl,s_goldrush2
        call banner2
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        call play_music
        jr .w
.n:     ld hl,s_stage
        ld de,tbuf
        ld bc,6
        ldir
        call stage_text
        ld hl,tbuf
        call banner
        ld hl,(lvptr)
        call banner2
        ld a,(demo)
        or a
        jr nz,.w
        ld hl,mus_start_0
        ld de,mus_start_1
        call play_music
.w:     ld b,110
        ld a,(demo)
        or a
        jr z,.lp
        ld b,50
.lp:    push bc
        ; eggs flash so you can see where the monsters will come from
        ld a,b
        and 7
        jr nz,.nf
        ld a,b
        and 8
        call show_eggs
.nf:    call build_drawlist
        call do_frame
        pop bc
        ld a,(demo)
        or a
        jr z,.nc
        call check_start
        ret nz
.nc:    djnz .lp
        xor a
        call show_eggs
        call banner_clear
        xor a
        ret
s_stage: db "STAGE "
s_goldrush: db "* GOLD RUSH! *",0
s_goldrush2: db "SMASH THE GOLD!",0
; stage_text: append "W-S" (S = 1..4) to tbuf+6
stage_text:
        ld a,(level)
        ld b,0
.d:     cp 5
        jr c,.dd
        sub 5
        inc b
        jr .d
.dd:    add a,'1'
        ld c,a
        ld a,b
        add a,'1'
        ld hl,tbuf+6
        ld (hl),a
        inc hl
        ld (hl),'-'
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        ret
; show_eggs: A = 0 -> eggs look like ice, else draw the egg tile
show_eggs:
        ld (tmpd),a
        ld c,0
.y:     ld b,0
.x:     call cell_get
        cp G_EGG
        jr nz,.n
        push bc
        ld a,(tmpd)
        or a
        ld a,T_EGG
        jr nz,.t
        ld a,(goldmode)
        or a
        ld a,T_ICE
        jr z,.t
        ld a,T_GOLDB
.t:     call draw_tile
        pop bc
.n:     inc b
        ld a,b
        cp 15
        jr nz,.x
        inc c
        ld a,c
        cp 8
        jr nz,.y
        ret

; READY! (after the intro and after every death).  NZ = demo aborted
ready_sequence:
        ld hl,s_ready
        call banner
        ld b,50
.w:     push bc
        call build_drawlist
        call do_frame
        pop bc
        ld a,(demo)
        or a
        jr z,.nc
        call check_start
        ret nz
.nc:    djnz .w
        call banner_clear
        call stop_music
        ld a,(goldmode)
        or a
        jr z,.g
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        call play_music
        xor a
        ret
.g:     ld a,(demo)
        or a
        call z,game_music
        xor a
        ret
s_ready: db "READY!",0

; banner box in the middle of the playfield
banner:
        push hl
        ld a,1
        ld (noq),a
        ld de,$0619
        ld bc,$140F
        ld a,$AA
        call fill_rect
        ld a,3
        ld b,2
        call set_ink
        pop hl
        ld e,28
        call print_c
        xor a
        ld (noq),a
        ; queue the box in three slices so each fits a frame's budget
        ld de,$0619
        ld bc,$1405
        call queue_rect
        ld de,$061E
        ld bc,$1405
        call queue_rect
        ld de,$0623
        ld bc,$1405
        jp queue_rect
banner2:
        push hl
        ld a,0
        ld b,2
        call set_ink
        pop hl
        ld e,34
        jp print_c
banner_clear:
        ld a,1
        ld (noq),a
        ld c,2
.y:     ld b,0
.x:     push bc
        call draw_cell
        pop bc
        inc b
        ld a,b
        cp 15
        jr nz,.x
        inc c
        ld a,c
        cp 5
        jr nz,.y
        xor a
        ld (noq),a
        ld de,$0614
        ld bc,$1407
        call queue_rect
        ld de,$061B
        ld bc,$1407
        call queue_rect
        ld de,$0622
        ld bc,$1407
        jp queue_rect

; ---------------------------------------------------------------------
; HUD (rows 0-4): score | lives | stage | monsters left | time | label
; ---------------------------------------------------------------------
hud_full:
        ld de,$0000
        ld bc,$2005
        ld a,$AA
        call fill_rect
        call hud_score
        call hud_lives
        call hud_stage
        call hud_count
        call hud_time
        jp hud_label_restore
hud_score:
        ld a,3
        ld b,2
        call set_ink
        ld hl,score
        ld b,3
        ld de,$0000
        jp print_bcd
hud_lives:
        ld a,0
        ld b,2
        call set_ink
        ld a,(lives)
        add a,'0'
        ld (tbuf+1),a
        ld a,'['
        ld (tbuf),a
        xor a
        ld (tbuf+2),a
        ld hl,tbuf
        ld de,$0700
        jp print
hud_stage:
        ld a,1
        ld b,2
        call set_ink
        call stage_text
        ld a,(goldmode)
        or a
        jr z,.n
        ld a,'$'
        ld (tbuf+8),a
.n:     ld hl,tbuf+6
        ld de,$0A00
        jp print
hud_count:
        ld a,1
        ld b,2
        call set_ink
        ld a,(goldmode)
        or a
        ld a,']'
        jr z,.e
        ld a,'$'
.e:     ld (tbuf),a
        xor a
        ld (tbuf+1),a
        ld hl,tbuf
        ld de,$0E00
        call print
        ld a,0
        ld b,2
        call set_ink
        ld a,(goldmode)
        or a
        jr nz,.g
        ld a,(eggs_left)
        ld b,a
        ld a,(alive)
        add a,b
        jr .p
.g:     ld a,(golds)
.p:     ld de,$0F00
        jp print_dec2
hud_time:
        ld a,1
        ld b,2
        call set_ink
        ld a,'@'
        ld (tbuf),a
        xor a
        ld (tbuf+1),a
        ld hl,tbuf
        ld de,$1200
        call print
        ld a,(timesec)
        cp 11
        ld a,0
        jr nc,.c
        ld a,3
.c:     ld b,2
        call set_ink
        ld a,(timesec)
        ld de,$1300
        jp print_dec2
; hud_label: HL = permanent label (10 chars max)
hud_label:
        ld (curlabel),hl
        xor a
        ld (labeltim),a
        jr hud_label_print
; temporary label for ~1.5 s
hud_label_tmp:
        ld a,80
        ld (labeltim),a
        jr hud_label_print
hud_label_restore:
        xor a
        ld (labeltim),a
        ld hl,(curlabel)
        ld a,h
        or l
        jr nz,hud_label_print
        ld hl,s_blank
hud_label_print:
        ld de,lbuf
        ld b,10
.c:     ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .c
        jr .e
.pad:   ld a,' '
.p:     ld (de),a
        inc de
        djnz .p
.e:     xor a
        ld (de),a
        ld a,0
        ld b,2
        call set_ink
        ld hl,lbuf
        ld de,$1600
        jp print
s_blank: db 0
update_label:
        ld a,(labeltim)
        or a
        ret z
        dec a
        ld (labeltim),a
        ret nz
        jp hud_label_restore

; ---------------------------------------------------------------------
; score: DE = 4-digit BCD points
; ---------------------------------------------------------------------
add_score:
        ld hl,score+2
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
        jr nc,.nov
        ld a,$99
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
.nov:   ; extra life?
        ld hl,score
        ld de,nextlife
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.ge                ; next < score
        jr nz,.done             ; next > score
        inc hl
        inc de
        djnz .c
.ge:    ld a,(nextlife)
        add a,$04
        daa
        ld (nextlife),a
        ld a,(lives)
        cp 9
        jr nc,.done
        inc a
        ld (lives),a
        call hud_lives
        ld hl,s_xlife
        call hud_label_tmp
        ld a,SFX_GET
        call play_sfx
.done:  jp hud_score
s_xlife: db "EXTRA LIFE",0

; ---------------------------------------------------------------------
; MAIN LOGIC (one frame)
; ---------------------------------------------------------------------
game_logic:
        xor a
        ld (result),a
        ld a,(autoplay)         ; (test hook: AI plays a real game)
        ld b,a
        ld a,(demo)
        or b
        call nz,ai_think
        call update_penguin
        call update_blocks
        call update_monsters
        call check_hits
        call update_breaks
        call update_item
        call hatch_logic
        call update_time
        call update_wall
        call update_label
        jp check_clear

; ---------------------------------------------------------------------
; PENGUIN
; ---------------------------------------------------------------------
want_dir:       ; -> A = dir or $FF
        ld a,(inpnew)
        and $0F
        jr nz,.g
        ld a,(inp)
        and $0F
        jr nz,.g
        ld a,$FF
        ret
.g:     ld b,0
.l:     rrca
        jr c,.f
        inc b
        jr .l
.f:     ld a,b
        ret

update_penguin:
        ld ix,peng
        ld a,(invuln)
        or a
        jr z,.ni
        dec a
        ld (invuln),a
.ni:    ld a,(pushtim)
        or a
        jr z,.np
        dec a
        ld (pushtim),a
.np:    ld a,(skatetim)
        or a
        jr z,.ns
        dec a
        ld (skatetim),a
.ns:    call want_dir
        ld (tmpd),a
        ld a,(ix+A_SUB)
        or a
        jr nz,.moving
        ld a,(inpnew)
        bit 4,a
        jr z,.nopush
        ld a,(facing)
        call do_push
        jr .done
.nopush:
        ld a,(tmpd)
        cp $FF
        jr z,.done
        ld (facing),a
        ld (ix+A_DIR),a
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        call step_bc
        call peng_can_enter
        jr nz,.done
        call peng_step
        jr .done
.moving:
        ld a,(tmpd)
        ld b,a
        ld a,(ix+A_DIR)
        xor 1
        cp b
        jr nz,.fw
        ; reverse in mid-cell
        ld a,(ix+A_DIR)
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        call step_bc
        ld (ix+A_CX),b
        ld (ix+A_CY),c
        ld a,8
        sub (ix+A_SUB)
        ld (ix+A_SUB),a
        ld a,(ix+A_DIR)
        xor 1
        ld (ix+A_DIR),a
        ld (facing),a
.fw:    call peng_step
.done:  jp calc_xy

peng_step:
        ld b,1
        ld a,(skatetim)
        or a
        jr z,.s
        inc b
.s:     ld a,(ix+A_SUB)
        add a,b
        cp 8
        jr c,.st
        ld a,(ix+A_DIR)
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        call step_bc
        ld (ix+A_CX),b
        ld (ix+A_CY),c
        ld (ix+A_SUB),0
        call cell_get
        cp G_ITEM
        ret nz
        jp collect_item
.st:    ld (ix+A_SUB),a
        ret

; Z if the penguin may walk into B,C
peng_can_enter:
        call cell_get
        cp G_EMPTY
        jr z,.b
        cp G_ITEM
        ret nz
.b:     ld hl,0
        ld (curblk),hl
        jp blocks_free_at

; Z if no sliding block (other than curblk) occupies B,C
blocks_free_at:
        push ix
        ld ix,blks
        ld e,2
.l:     ld a,(ix+A_TYPE)
        or a
        jr z,.n
        push ix
        pop hl
        push de
        ld de,(curblk)
        or a
        sbc hl,de
        pop de
        jr z,.n
        ld a,(ix+A_CX)
        cp b
        jr nz,.nx
        ld a,(ix+A_CY)
        cp c
        jr z,.busy
.nx:    ld a,(ix+A_SUB)
        or a
        jr z,.n
        push bc
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_DIR)
        push de
        call step_bc
        pop de
        ld a,b
        ld h,c
        pop bc
        cp b
        jr nz,.n
        ld a,h
        cp c
        jr z,.busy
.n:     push de
        ld de,16
        add ix,de
        pop de
        dec e
        jr nz,.l
        pop ix
        xor a
        ret
.busy:  pop ix
        or 1
        ret

; Z if a sliding block may enter B,C
block_can_enter:
        call cell_get
        cp G_EMPTY
        jr z,.e
        cp G_ITEM
        ret nz
.e:     ; penguin in the way?
        push ix
        ld ix,peng
        ld a,(ix+A_CX)
        cp b
        jr nz,.p2
        ld a,(ix+A_CY)
        cp c
        jr z,.no
.p2:    ld a,(ix+A_SUB)
        or a
        jr z,.ok
        push bc
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_DIR)
        call step_bc
        ld a,b
        ld h,c
        pop bc
        cp b
        jr nz,.ok
        ld a,h
        cp c
        jr z,.no
.ok:    pop ix
        jp blocks_free_at
.no:    pop ix
        or 1
        ret

; ---------------------------------------------------------------------
; push (fire): A = direction
do_push:
        ld (tmpd),a
        ld a,10
        ld (pushtim),a
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(tmpd)
        call step_bc
        call cell_get
        cp G_WALL
        jp z,wall_shake
        cp G_ICE
        jr z,.blk
        cp G_EGG
        jr z,.blk
        cp G_CRYS
        jr z,.blk
        cp G_ROCK
        ret nz
.clunk: ld a,SFX_CLUNK
        jp play_sfx
.blk:   ld (tmpx),a             ; code
        ld a,b
        ld (tmpy),a
        push bc
        ld a,(tmpd)
        call step_bc
        ld hl,0
        ld (curblk),hl
        call block_can_enter
        pop bc
        jr nz,.blocked
        ; free slot?
        ld iy,blks
        ld a,(iy+A_TYPE)
        or a
        jr z,.slot
        ld iy,blks+16
        ld a,(iy+A_TYPE)
        or a
        ret nz
.slot:  ld a,G_EMPTY
        call cell_set
        push bc
        call draw_cell
        pop bc
        ld (iy+A_TYPE),1
        ld a,(tmpx)
        ld (iy+A_ST),a
        ld (iy+A_CX),b
        ld (iy+A_CY),c
        ld (iy+A_SUB),0
        ld a,(tmpd)
        ld (iy+A_DIR),a
        ld (iy+A_SPD),0
        push iy
        pop hl
        ld a,l
        sub blks&255
        rrca
        rrca
        rrca
        rrca
        and 1
        ld (iy+A_AUX),a
        push ix
        push iy
        pop ix
        call calc_xy
        pop ix
        ld a,SFX_SLIDE
        jp play_sfx
.blocked:
        ld a,(tmpx)
        cp G_CRYS
        jr z,.clunk
        cp G_EGG
        jr z,.egg
        ; plain ice crumbles
        ld a,2
        call start_break
        ld a,SFX_CRUMBLE
        call play_sfx
        ld a,(goldmode)
        or a
        jr nz,.gold
        ld de,$0030
        jp add_score
.gold:  ld hl,golds
        inc (hl)
        call hud_count
        ld de,$0100
        call add_score
        ld a,b
        add a,a
        inc a
        ld b,a
        ld a,c
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e
        add a,YOFF
        ld c,a
        ld e,P_100
        jp popup_add
.egg:   ld a,1
        call start_break
        ld hl,eggs_left
        dec (hl)
        call hud_count
        ld a,SFX_EGG
        call play_sfx
        push bc
        ld de,$0500
        call add_score
        pop bc
        push bc
        call cell_px            ; B,C -> pixel centre
        ld a,2
        call burst
        pop bc
        ld a,b
        add a,a
        ld b,a
        ld a,c
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e
        add a,YOFF
        ld c,a
        ld e,P_500
        jp popup_add

; cell centre in pixels: B,C cell -> B,C pixel
cell_px:
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,XOFF+4
        ld b,a
        ld a,c
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e
        add a,YOFF+3
        ld c,a
        ret

; push against the border: stun monsters touching that wall
wall_shake:
        ld a,(tmpd)
        ld (wallside),a
        ld a,14
        ld (walltim),a
        ld b,$FF
        call draw_wall_side
        ld a,SFX_SHAKE
        call play_sfx
        push ix
        ld ix,mons
        ld a,4
.m:     push af
        ld a,(ix+A_TYPE)
        or a
        jr z,.n
        ld a,(ix+A_ST)
        cp ST_WALK
        jr z,.c
        cp ST_MUNCH
        jr nz,.n
.c:     call round_cell
        ld a,(wallside)
        or a
        jr nz,.s1
        ld a,b
        cp 14
        jr z,.hit
        jr .n
.s1:    dec a
        jr nz,.s2
        ld a,b
        or a
        jr z,.hit
        jr .n
.s2:    dec a
        jr nz,.s3
        ld a,c
        or a
        jr z,.hit
        jr .n
.s3:    ld a,c
        cp 7
        jr nz,.n
.hit:   ld (ix+A_ST),ST_STUN
        ld (ix+A_TIM),160
.n:     ld de,16
        add ix,de
        pop af
        dec a
        jr nz,.m
        pop ix
        ret
update_wall:
        ld a,(walltim)
        or a
        ret z
        dec a
        ld (walltim),a
        ret nz
        ld a,(wallside)
        ld b,$AA
        jp draw_wall_side

; ---------------------------------------------------------------------
; SLIDING BLOCKS
; ---------------------------------------------------------------------
update_blocks:
        ld ix,blks
        call .one
        ld ix,blks+16
.one:   ld a,(ix+A_TYPE)
        or a
        ret z
        ld (curblk),ix
        ld a,2
.ss:    push af
        ld a,(ix+A_SUB)
        or a
        jr nz,.adv
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_DIR)
        call step_bc
        push bc
        call block_can_enter
        pop bc
        jr nz,.stop
        call cell_get
        cp G_ITEM
        jr nz,.adv
        ld a,G_EMPTY            ; a sliding block flattens an item
        call cell_set
        call draw_cell
        ld hl,0
        ld (itemtim),hl
.adv:   ld a,(ix+A_SUB)
        add a,2
        cp 8
        jr c,.s
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_DIR)
        call step_bc
        ld (ix+A_CX),b
        ld (ix+A_CY),c
        xor a
.s:     ld (ix+A_SUB),a
        pop af
        dec a
        jr nz,.ss
        call calc_xy
        jp carry_check
.stop:  pop af
        call calc_xy
        ; block comes to rest
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_ST)
        call cell_set
        call draw_cell
        ld (ix+A_TYPE),0
        ld a,SFX_THUD
        call play_sfx
        ld a,(ix+A_SPD)         ; kills
        or a
        jr z,.nk
        call crush_monsters
.nk:    ld a,(ix+A_ST)
        cp G_CRYS
        ret nz
        jp check_crystals

; monsters touching the front of a sliding block get carried along
carry_check:
        ld iy,mons
        ld a,4
.l:     push af
        ld a,(iy+A_TYPE)
        or a
        jp z,.n
        ld a,(iy+A_ST)
        cp ST_CARRY
        jr nz,.free
        ld a,(iy+A_AUX)
        cp (ix+A_AUX)
        jp nz,.n
        jr .stick
.free:  cp ST_WALK
        jr z,.c
        cp ST_STUN
        jr z,.c
        cp ST_MUNCH
        jp nz,.n
.c:     ld a,(iy+A_PH)
        or a
        jp nz,.n
        ld a,(iy+A_X)
        sub (ix+A_X)
        ld d,a                  ; dx (signed)
        jp p,.dxp
        neg
.dxp:   cp 7
        jp nc,.n
        ld a,(iy+A_Y)
        sub (ix+A_Y)
        ld e,a                  ; dy
        jp p,.dyp
        neg
.dyp:   cp 6
        jp nc,.n
        ; must be ahead of the block
        ld a,(ix+A_DIR)
        or a
        jr nz,.d1
        ld a,d
        add a,2
        jp m,.n
        jr .take
.d1:    dec a
        jr nz,.d2
        ld a,d
        sub 3
        jp p,.n
        jr .take
.d2:    dec a
        jr nz,.d3
        ld a,e
        sub 3
        jp p,.n
        jr .take
.d3:    ld a,e
        add a,2
        jp m,.n
.take:  ld (iy+A_ST),ST_CARRY
        ld a,(ix+A_AUX)
        ld (iy+A_AUX),a
        inc (ix+A_SPD)
        ld a,SFX_KICK
        call play_sfx
.stick: ; carried monster rides squashed against the block front
        ld a,(ix+A_DIR)
        ld e,a
        ld d,0
        ld hl,dxtab
        add hl,de
        ld a,(hl)
        add a,a
        add a,a
        add a,(hl)              ; *5
        add a,(ix+A_X)
        ld (iy+A_X),a
        ld hl,dytab
        add hl,de
        ld a,(hl)
        add a,a
        add a,a                 ; *4
        add a,(ix+A_Y)
        ld (iy+A_Y),a
.n:     ld de,16
        add iy,de
        pop af
        dec a
        jp nz,.l
        ret

; block IX stopped with A kills: squash them
crush_monsters:
        ld (cnt),a
        ld iy,mons
        ld b,4
.l:     ld a,(iy+A_TYPE)
        or a
        jr z,.n
        ld a,(iy+A_ST)
        cp ST_CARRY
        jr nz,.n
        ld a,(iy+A_AUX)
        cp (ix+A_AUX)
        jr nz,.n
        ld (iy+A_ST),ST_DIE
        ld (iy+A_TIM),40
        ld hl,alive
        dec (hl)
        push bc
        ld a,(iy+A_X)
        add a,4
        ld b,a
        ld a,(iy+A_Y)
        add a,4
        ld c,a
        ld a,3
        call burst
        pop bc
.n:     ld de,16
        add iy,de
        djnz .l
        call hud_count
        ld a,SFX_CRUSH
        call play_sfx
        ld a,5
        ld (flashtim),a
        ld a,(hatchdelay)
        cp 70
        jr nc,.hd
        ld a,70
        ld (hatchdelay),a
.hd:    ; 1:400 2:1600 3:3200 4:6400
        ld a,(cnt)
        dec a
        and 3
        ld e,a
        ld d,0
        ld hl,crushpts
        add hl,de
        add hl,de
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        pop de
        ld a,e
        add a,P_400
        ld e,a
        ld a,(ix+A_X)
        srl a
        srl a
        ld b,a
        ld a,(ix+A_Y)
        sub 6
        jr nc,.y
        xor a
.y:     ld c,a
        jp popup_add
crushpts: dw $0400,$1600,$3200,$6400

; ---------------------------------------------------------------------
; CRYSTALS: line all three up for a big bonus
; ---------------------------------------------------------------------
check_crystals:
        ld a,(crystal_done)
        or a
        ret nz
        ; collect positions into attr_v (x0,y0,x1,y1,x2,y2)
        xor a
        ld (cnt),a
        ld hl,attr_v
        ld c,0
.y:     ld b,0
.x:     call cell_get
        cp G_CRYS
        jr nz,.nx
        ld a,(cnt)
        cp 3
        jr nc,.nx
        inc a
        ld (cnt),a
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
.nx:    inc b
        ld a,b
        cp 15
        jr nz,.x
        inc c
        ld a,c
        cp 8
        jr nz,.y
        ld a,(cnt)
        cp 3
        ret nz
        ; same row & consecutive x ?
        ld a,(attr_v+1)
        ld b,a
        ld a,(attr_v+3)
        cp b
        jr nz,.col
        ld a,(attr_v+5)
        cp b
        jr nz,.col
        ; scanned left to right: x0<x1<x2
        ld a,(attr_v)
        inc a
        ld b,a
        ld a,(attr_v+2)
        cp b
        ret nz
        inc a
        ld b,a
        ld a,(attr_v+4)
        cp b
        ret nz
        jr .yes
.col:   ld a,(attr_v)
        ld b,a
        ld a,(attr_v+2)
        cp b
        ret nz
        ld a,(attr_v+4)
        cp b
        ret nz
        ld a,(attr_v+1)
        inc a
        ld b,a
        ld a,(attr_v+3)
        cp b
        ret nz
        inc a
        ld b,a
        ld a,(attr_v+5)
        cp b
        ret nz
.yes:   ld a,1
        ld (crystal_done),a
        ; touching the border?  5000, else 10000
        ld hl,attr_v
        ld b,3
        ld c,0
.e:     ld a,(hl)
        or a
        jr z,.edge
        cp 14
        jr z,.edge
        inc hl
        ld a,(hl)
        or a
        jr z,.edge
        cp 7
        jr z,.edge
        inc hl
        djnz .e
        jr .ne
.edge:  ld c,1
.ne:    push bc
        ld de,$5000
        call add_score
        pop bc
        ld e,P_5000
        ld a,c
        or a
        jr nz,.pp
        push bc
        ld de,$5000
        call add_score
        pop bc
        ld e,P_10000
.pp:    ld a,(attr_v+2)
        add a,a
        ld b,a
        ld a,(attr_v+3)
        ld c,a
        add a,a
        add a,a
        add a,a
        sub c
        ld c,a
        call popup_add
        ld hl,s_crystal
        call hud_label_tmp
        ld a,24
        ld (flashtim),a
        call stun_all_long
        ; sparkle bursts on each crystal
        ld hl,attr_v
        ld a,3
.b:     push af
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call cell_px
        ld a,3
        call burst
        pop hl
        pop af
        dec a
        jr nz,.b
        ld hl,mus_crystal_0
        ld de,mus_crystal_1
        jp play_music
s_crystal: db "CRYSTALS!",0
stun_all_long:
        ld b,250
        jr stun_all
; stun every walking monster for B frames
stun_all:
        push ix
        ld ix,mons
        ld c,4
.m:     ld a,(ix+A_TYPE)
        or a
        jr z,.n
        ld a,(ix+A_ST)
        cp ST_WALK
        jr z,.s
        cp ST_MUNCH
        jr z,.s
        cp ST_STUN
        jr nz,.n
.s:     ld (ix+A_ST),ST_STUN
        ld (ix+A_TIM),b
.n:     ld de,16
        add ix,de
        dec c
        jr nz,.m
        pop ix
        ret

; ---------------------------------------------------------------------
; CRUMBLING ICE: start_break B,C, A flags (bit0 egg, bit1 item allowed)
; ---------------------------------------------------------------------
start_break:
        push hl
        ld e,a
        ld hl,breaks
        ld d,8
.f:     ld a,(hl)
        cp $FF
        jr z,.got
        inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        ; list full: just remove it at once
        ld a,G_EMPTY
        call cell_set
        call draw_cell
        pop hl
        ret
.got:   ld a,G_BREAK
        call cell_set
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        inc hl
        ld (hl),e
        pop hl
        ret
init_breaks:
        ld hl,breaks
        ld b,8
.l:     ld (hl),$FF
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        ret
update_breaks:
        ld hl,breaks
        ld d,8
.l:     ld a,(hl)
        cp $FF
        jr z,.n
        push hl
        push de
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        inc (hl)
        ld a,(hl)
        inc hl
        ld e,(hl)
        cp 2
        ld d,T_CR1
        jr z,.t
        cp 6
        ld d,T_CR2
        jr z,.t
        cp 10
        ld d,T_CR3
        jr z,.t
        cp 14
        jr nz,.done
        ; finished
        dec hl
        dec hl
        dec hl
        ld (hl),$FF
        ld a,G_EMPTY
        call cell_set
        push de
        call draw_cell
        pop de
        bit 1,e
        jr z,.done
        ld a,(itemtim)
        ld l,a
        ld a,(itemtim+1)
        or l
        jr nz,.done
        call random
        cp 52
        call c,spawn_item
        jr .done
.t:     ld a,d
        call draw_tile
.done:  pop de
        pop hl
.n:     inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; ITEMS hidden in the ice
; ---------------------------------------------------------------------
spawn_item:
        push bc
        call random
        and 15
        ld e,0                  ; fish
        cp 8
        jr c,.k
        inc e                   ; snowflake
        cp 11
        jr c,.k
        inc e                   ; skates
        cp 14
        jr c,.k
        ld e,3                  ; heart (only when short of lives)
        ld a,(lives)
        cp 5
        jr c,.k
        ld e,0
.k:     ld a,e
        ld (itemkind),a
        pop bc
        ld a,b
        ld (itemcx),a
        ld a,c
        ld (itemcy),a
        ld hl,450
        ld (itemtim),hl
        ld a,G_ITEM
        call cell_set
        call draw_cell
        ld a,SFX_ITEM
        jp play_sfx
update_item:
        ld hl,(itemtim)
        ld a,h
        or l
        ret z
        dec hl
        ld (itemtim),hl
        ld a,h
        or l
        jr z,.gone
        ; blink in the last two seconds
        ld a,h
        or a
        ret nz
        ld a,l
        cp 100
        ret nc
        and 7
        ret nz
        ld a,(itemcx)
        ld b,a
        ld a,(itemcy)
        ld c,a
        call cell_get
        cp G_ITEM
        ret nz
        ld a,l
        and 8
        jp nz,draw_cell
        ld a,T_EMPTY
        jp draw_tile
.gone:  ld a,(itemcx)
        ld b,a
        ld a,(itemcy)
        ld c,a
        call cell_get
        cp G_ITEM
        ret nz
        ld a,G_EMPTY
        call cell_set
        jp draw_cell

; penguin reached an item at B,C
collect_item:
        ld a,G_EMPTY
        call cell_set
        call draw_cell
        ld hl,0
        ld (itemtim),hl
        ld a,SFX_GET
        call play_sfx
        ld a,(itemkind)
        or a
        jr nz,.n0
        ; fish: 500 / 1000 / 2000
        ld a,(fishval)
        ld e,a
        cp 2
        jr nc,.f
        inc a
        ld (fishval),a
.f:     ld d,0
        ld hl,fishpts
        add hl,de
        add hl,de
        push de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        call add_score
        pop de
        ld hl,fishpop
        add hl,de
        ld e,(hl)
        ld a,(ix+A_X)
        srl a
        srl a
        ld b,a
        ld a,(ix+A_Y)
        sub 6
        ld c,a
        jp popup_add
.n0:    dec a
        jr nz,.n1
        ld b,250
        call stun_all
        ld a,SFX_FREEZE
        call play_sfx
        ld hl,s_freeze
        jp hud_label_tmp
.n1:    dec a
        jr nz,.n2
        ld a,250
        ld (skatetim),a
        ld hl,s_skates
        jp hud_label_tmp
.n2:    ld a,(lives)
        cp 9
        jr nc,.nl
        inc a
        ld (lives),a
.nl:    call hud_lives
        ld hl,s_xlife
        call hud_label_tmp
        ld hl,mus_oneup_0
        ld de,mus_oneup_1
        ld a,(soundmode)
        cp 2
        ret z                   ; keep the game music going
        jp play_music
fishpts: dw $0500,$1000,$2000
fishpop: db P_500,P_1000,P_2000
s_freeze: db "FREEZE!",0
s_skates: db "SKATES!",0

; ---------------------------------------------------------------------
; MONSTERS
; ---------------------------------------------------------------------
hatch_logic:
        ld a,(goldmode)
        or a
        ret nz
        ld a,(hatchdelay)
        or a
        jr z,.go
        dec a
        ld (hatchdelay),a
        ret
.go:    ld a,(eggs_left)
        or a
        ret z
        ld a,(alive)
        ld b,a
        ld a,(lv_max)
        cp b
        ret z
        ret c
        ; free slot
        ld ix,mons
        ld b,4
.fs:    ld a,(ix+A_TYPE)
        or a
        jr z,.slot
        ld de,16
        add ix,de
        djnz .fs
        ret
.slot:  ; count egg cells
        ld e,0
        ld hl,GRID
        ld b,128
.c:     ld a,(hl)
        cp G_EGG
        jr nz,.c1
        inc e
.c1:    inc hl
        djnz .c
        ld a,e
        or a
        jr nz,.some
        ld (eggs_left),a        ; eggs all smashed
        jp hud_count
.some:  ld b,e
        call rand_n
        ld e,a
        ld hl,GRID
.k:     ld a,(hl)
        cp G_EGG
        jr nz,.k1
        ld a,e
        or a
        jr z,.found
        dec e
.k1:    inc hl
        jr .k
.found: ld a,l
        and 15
        ld b,a
        ld a,l
        and $70
        rrca
        rrca
        rrca
        rrca
        ld c,a
        ld (ix+A_CX),b
        ld (ix+A_CY),c
        ld a,G_BREAK
        call cell_set
        ld a,T_HATCH
        call draw_tile
        ; pick a type from the level's roster
.pt:    call random
        and 3
        ld e,a
        inc a
        ld d,a
        ld a,(lv_roster)
.sh:    rrca
        dec d
        jr nz,.sh
        jr nc,.pt
        ld a,e
        inc a
        ld (ix+A_TYPE),a
        ld (ix+A_ST),ST_HATCH
        ld (ix+A_TIM),70
        ld (ix+A_SUB),0
        ld (ix+A_DIR),$FF
        ld (ix+A_ACC),0
        ld (ix+A_PH),0
        ; speed & chase from the type table
        ld d,0
        ld hl,typetab
        add hl,de
        add hl,de
        ld a,(lap)
        add a,a
        add a,a
        add a,a
        ld b,a
        add a,a
        add a,b                 ; lap*24
        ld b,a
        ld a,(lv_speed)
        add a,(hl)
        jr c,.cl
        add a,b
        jr nc,.ok
.cl:    ld a,250
.ok:    ld c,a
        ld a,(demo)
        or a
        ld a,c
        jr z,.ok2
        sub 50
.ok2:   ld (ix+A_SPD),a
        inc hl
        ld a,(hl)
        ld (ix+A_CH),a
        call calc_xy
        ld hl,eggs_left
        dec (hl)
        ld hl,alive
        inc (hl)
        call hud_count
        ld a,45
        ld (hatchdelay),a
        ld a,SFX_HATCH
        jp play_sfx
; speed offset (signed), chase chance /256
typetab: db 0,120, -18,150, 60,50, -25,170

update_monsters:
        ld ix,mons
        ld b,4
.l:     push bc
        ld a,(ix+A_TYPE)
        or a
        call nz,mon_one
        ld de,16
        add ix,de
        pop bc
        djnz .l
        ret
mon_one:
        ld a,(ix+A_ST)
        cp ST_WALK
        jp z,m_walk
        cp ST_HATCH
        jr z,m_hatch
        cp ST_STUN
        jr z,m_stun
        cp ST_DIE
        jr z,m_die
        cp ST_POOF
        jr z,m_die
        cp ST_MUNCH
        jr z,m_munch
        ret
m_hatch:
        dec (ix+A_TIM)
        ret nz
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,G_EMPTY
        call cell_set
        call draw_cell
        ld (ix+A_ST),ST_WALK
        ret
m_die:  dec (ix+A_TIM)
        ret nz
        ld (ix+A_TYPE),0
        ret
m_stun: dec (ix+A_TIM)
        ret nz
        ld (ix+A_ST),ST_WALK
        ret
m_munch:
        dec (ix+A_TIM)
        ld a,(ix+A_TIM)
        and 15
        jr nz,.n
        ld a,SFX_MUNCH
        call play_sfx
.n:     ld a,(ix+A_TIM)
        or a
        ret nz
        ld (ix+A_ST),ST_WALK
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_AUX)
        call step_bc
        call cell_get
        cp G_ICE
        ret nz
        xor a
        call start_break
        ld a,SFX_CRUMBLE
        jp play_sfx

m_walk: ld a,(ix+A_SPD)
        ld b,a
        ld a,(hurry)
        or a
        jr z,.nh
        ld a,b
        add a,45
        jr nc,.hc
        ld a,250
.hc:    ld b,a
.nh:    ld a,(ix+A_ACC)
        add a,b
        ld (ix+A_ACC),a
        ret nc
        ld a,(ix+A_SUB)
        or a
        jr nz,.mv
        call m_decide
        ld a,(ix+A_ST)
        cp ST_WALK
        ret nz
        ld a,(ix+A_DIR)
        cp 4
        jr nc,.ph
.mv:    inc (ix+A_SUB)
        ld a,(ix+A_SUB)
        cp 8
        jr c,.ph
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,(ix+A_DIR)
        call step_bc
        ld (ix+A_CX),b
        ld (ix+A_CY),c
        ld (ix+A_SUB),0
.ph:    call calc_xy
        ld a,(ix+A_TYPE)
        cp 4
        ret nz
        call round_cell
        call cell_get
        ld e,1
        cp G_ICE
        jr z,.in
        cp G_EGG
        jr z,.in
        ld e,0
.in:    ld (ix+A_PH),e
        ret

; Z if monster IX may walk into B,C
m_passable:
        call cell_get
        cp G_EMPTY
        ret z
        cp G_ITEM
        ret z
        ld e,a
        ld a,(ix+A_TYPE)
        cp 4
        ret nz
        ld a,e
        cp G_ICE
        ret z
        cp G_EGG
        ret

; pick a direction at a cell centre
m_decide:
        xor a
        ld (cnt),a
        ld d,0                  ; dir
.dl:    ld a,(ix+A_DIR)
        cp 4
        jr nc,.nr
        xor 1
        cp d
        jr z,.skip
.nr:    ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,d
        push de
        call step_bc
        call m_passable
        pop de
        jr nz,.skip
        ld hl,cand
        ld a,(cnt)
        add a,l
        ld l,a
        jr nc,.ad
        inc h
.ad:    ld (hl),d
        ld hl,cnt
        inc (hl)
.skip:  inc d
        ld a,d
        cp 4
        jr nz,.dl
        ld a,(cnt)
        or a
        jr nz,.have
        ; dead end: turn back if possible
        ld a,(ix+A_DIR)
        cp 4
        jr nc,.stuck
        xor 1
        ld d,a
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        push de
        call step_bc
        call m_passable
        pop de
        jr nz,.stuck
        ld (ix+A_DIR),d
        ret
.stuck: ld (ix+A_DIR),$FF
        ld a,(ix+A_TYPE)
        cp 2
        ret nz
        ; chomper boxed in: eat a neighbouring block
        call random
        and 3
        ld d,a
        ld e,4
.mt:    ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,d
        push de
        call step_bc
        call cell_get
        pop de
        cp G_ICE
        jp z,m_start_munch
        ld a,d
        inc a
        and 3
        ld d,a
        dec e
        jr nz,.mt
        ret
.have:  ; chomper: sometimes bite through the ice toward the penguin
        ld a,(ix+A_TYPE)
        cp 2
        jr nz,.nc
        call random
        cp 45
        jr nc,.nc
        call m_dir_to_peng
        ld d,a
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        push de
        call step_bc
        call cell_get
        pop de
        cp G_ICE
        jr z,m_start_munch
.nc:    call random
        cp (ix+A_CH)
        jr nc,.rnd
        ; chase: candidate closest to the penguin
        ld a,$FF
        ld (bestd),a
        ld hl,cand
        ld a,(cnt)
        ld e,a
.cl:    push hl
        push de
        ld d,(hl)
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,d
        call step_bc
        call dist_peng
        pop de
        pop hl
        ld b,a
        ld a,(bestd)
        cp b
        jr c,.cn
        jr z,.cn
        ld a,b
        ld (bestd),a
        ld a,(hl)
        ld (best),a
.cn:    inc hl
        dec e
        jr nz,.cl
        ld a,(best)
        ld (ix+A_DIR),a
        ret
.rnd:   ld a,(cnt)
        ld b,a
        call rand_n
        ld e,a
        ld d,0
        ld hl,cand
        add hl,de
        ld a,(hl)
        ld (ix+A_DIR),a
        ret
m_start_munch:
        ld (ix+A_AUX),d
        ld (ix+A_ST),ST_MUNCH
        ld (ix+A_TIM),48
        ld (ix+A_DIR),$FF
        ret
; manhattan distance from cell B,C to the penguin -> A
dist_peng:
        ld a,(peng+A_CX)
        call absdiff_ab
        ld e,a
        ld a,(peng+A_CY)
        ld b,c
        call absdiff_ab
        add a,e
        ret
; greedy direction toward the penguin -> A
m_dir_to_peng:
        ld a,(peng+A_CX)
        sub (ix+A_CX)
        ld d,a
        jp p,.p1
        neg
.p1:    ld b,a
        ld a,(peng+A_CY)
        sub (ix+A_CY)
        ld e,a
        jp p,.p2
        neg
.p2:    cp b
        jr nc,.vert
        ld a,d
        or a
        ld a,0
        ret p
        inc a
        ret
.vert:  ld a,e
        or a
        ld a,3
        ret p
        dec a
        ret

; monster vs penguin
check_hits:
        ld a,(peng+A_TYPE)
        or a
        ret z
        ld ix,mons
        ld b,4
.l:     push bc
        ld a,(ix+A_TYPE)
        or a
        jp z,.n
        ld a,(ix+A_PH)
        or a
        jr nz,.n
        ld a,(ix+A_ST)
        cp ST_WALK
        jr z,.c
        cp ST_MUNCH
        jr z,.c
        cp ST_STUN
        jr nz,.n
.c:     ld a,(peng+A_X)
        ld b,a
        ld a,(ix+A_X)
        call absdiff_ab
        cp 6
        jr nc,.n
        ld a,(peng+A_Y)
        ld b,a
        ld a,(ix+A_Y)
        call absdiff_ab
        cp 5
        jr nc,.n
        ld a,(ix+A_ST)
        cp ST_STUN
        jr z,.kick
        ld a,(invuln)
        or a
        jr nz,.n
        ld a,(godmode)          ; (test hook)
        or a
        jr nz,.n
        ld a,2
        ld (result),a
        jr .n
.kick:  ld (ix+A_ST),ST_POOF
        ld (ix+A_TIM),24
        ld hl,alive
        dec (hl)
        call hud_count
        ld a,(hatchdelay)
        cp 60
        jr nc,.hd
        ld a,60
        ld (hatchdelay),a
.hd:    ld de,$0100
        call add_score
        ld a,SFX_KICK
        call play_sfx
        ld a,(ix+A_X)
        srl a
        srl a
        ld b,a
        ld a,(ix+A_Y)
        sub 6
        ld c,a
        ld e,P_100
        call popup_add
.n:     ld de,16
        add ix,de
        pop bc
        dec b
        jp nz,.l
        ret

check_clear:
        ld a,(result)
        or a
        ret nz
        ld a,(forceclear)       ; (test hook)
        or a
        jr z,.nf
        xor a
        ld (forceclear),a
        inc a
        ld (result),a
        ret
.nf:
        ; no sliding blocks
        ld a,(blks+A_TYPE)
        ld b,a
        ld a,(blks+16+A_TYPE)
        or b
        ret nz
        ld a,(goldmode)
        or a
        jr nz,.gold
        ld a,(eggs_left)
        ld b,a
        ld a,(alive)
        or b
        ret nz
        ld a,(mons+A_TYPE)
        ld b,a
        ld a,(mons+16+A_TYPE)
        or b
        ld b,a
        ld a,(mons+32+A_TYPE)
        or b
        ld b,a
        ld a,(mons+48+A_TYPE)
        or b
        ret nz
        ld a,1
        ld (result),a
        ret
.gold:  ; all gold gone (and nothing still crumbling)?
        ld hl,GRID
        ld b,128
.g:     ld a,(hl)
        cp G_ICE
        ret z
        cp G_BREAK
        ret z
        inc hl
        djnz .g
        ld a,1
        ld (result),a
        ret

update_time:
        ld hl,framesub
        inc (hl)
        ld a,(hl)
        cp 50
        ret c
        ld (hl),0
        ld a,(timesec)
        or a
        ret z
        dec a
        ld (timesec),a
        call hud_time
        ld a,(timesec)
        or a
        jr z,.out
        cp 11
        ret nc
        ld a,SFX_TICK
        jp play_sfx
.out:   ld a,(goldmode)
        or a
        jr z,.hurry
        ld a,3
        ld (result),a
        ret
.hurry: ld a,1
        ld (hurry),a
        ld hl,s_hurry
        call hud_label
        ld a,10
        ld (flashtim),a
        ld a,(demo)
        or a
        ret nz
        jp game_music
s_hurry: db "HURRY UP!",0

; ---------------------------------------------------------------------
; DRAW LIST
; ---------------------------------------------------------------------
build_drawlist:
        call dl_reset
        ; sliding blocks
        ld ix,blks
        call .blk
        ld ix,blks+16
        call .blk
        call update_monster_sprites
        ; penguin
        ld ix,peng
        ld a,(ix+A_TYPE)
        or a
        jr z,.np
        ld a,(invuln)
        or a
        jr z,.vis
        ld a,(framecount)
        and 4
        jr nz,.np
.vis:   call peng_sprite
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        call dl_add
.np:    call update_particles
        jp update_popups
.blk:   ld a,(ix+A_TYPE)
        or a
        ret z
        ld a,(ix+A_ST)
        cp G_CRYS
        ld a,SPR_BCRYS
        jr z,.b
        ld a,SPR_BICE
.b:     ld b,(ix+A_X)
        ld c,(ix+A_Y)
        jp dl_add

peng_sprite:
        ld a,(pushtim)
        or a
        jr z,.walk
        ld a,(facing)
        add a,SPR_PPR
        ret
.walk:  ld a,(facing)
        ld e,a
        ld d,0
        ld hl,walkbase
        add hl,de
        ld a,(ix+A_SUB)
        srl a
        srl a
        and 1
        add a,(hl)
        ret
walkbase: db SPR_PR0,SPR_PL0,SPR_PU0,SPR_PD0

update_monster_sprites:
        ld ix,mons
        ld b,4
.l:     push bc
        ld a,(ix+A_TYPE)
        or a
        call nz,mon_sprite
        ld de,16
        add ix,de
        pop bc
        djnz .l
        ret
mon_sprite:
        ld a,(ix+A_TYPE)
        dec a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,montab
        add hl,de               ; HL -> f0,f1,stun,phased
        ld a,(ix+A_ST)
        cp ST_HATCH
        jr nz,.n1
        ld a,(ix+A_TIM)
        cp 24
        ld a,SPR_HATCH0
        jr nc,.go
        ld a,SPR_HATCH1
        jr .go
.n1:    cp ST_DIE
        jr nz,.n2
        ld a,SPR_SQUASH
        jr .go
.n2:    cp ST_POOF
        jr nz,.n3
        ld a,(ix+A_TIM)
        cp 12
        ld a,SPR_POOF0
        jr nc,.go
        ld a,SPR_POOF1
        jr .go
.n3:    cp ST_STUN
        jr z,.stun
        cp ST_CARRY
        jr z,.stun
        cp ST_MUNCH
        jr nz,.n4
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,(hl)
        jr .go
.n4:    ld a,(ix+A_PH)
        or a
        jr z,.walk
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        jr .go
.walk:  ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,(hl)
        jr .go
.stun:  inc hl
        inc hl
        ld a,(hl)
.go:    ld b,(ix+A_X)
        ld c,(ix+A_Y)
        jp dl_add
montab: db SPR_BLOB0,SPR_BLOB0,SPR_BLOBS,SPR_BLOB0
        db SPR_CHOMP0,SPR_CHOMP0,SPR_CHOMPS,SPR_CHOMP0
        db SPR_FLIT0,SPR_FLIT0,SPR_FLITS,SPR_FLIT0
        db SPR_WISP0,SPR_WISP0,SPR_WISPS,SPR_WISPP

; ---------------------------------------------------------------------
; POPUPS (col, row, timer, string)  and  PARTICLES
; ---------------------------------------------------------------------
; popup_add: B = col, C = row, E = string index
; Popups are printed into the background once (no per-frame cost) and the
; cells underneath are redrawn when they expire.
popup_add:
        ld a,c
        cp 6
        jr nc,.r
        ld c,6
.r:     cp 57
        jr c,.r2
        ld c,56
.r2:    ld a,b
        or a
        jr nz,.c0
        inc b
.c0:    ld a,b
        cp 27
        jr c,.cc
        ld b,26
.cc:    ld hl,popups
        ld d,4
.f:     ld a,(hl)
        cp $FF
        jr z,.got
        inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        ret                     ; all busy: skip this one
.got:   push hl
        ; string
        ld a,e
        add a,a
        ld e,a
        ld d,0
        ld hl,popstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld e,0
.ln:    ld a,(hl)
        or a
        jr z,.lnd
        inc e
        inc hl
        jr .ln
.lnd:   pop hl
        ex (sp),hl              ; HL = slot, string on stack
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),40
        inc hl
        ld (hl),e
        push bc
        ld a,(popcol)
        ld a,3
        ld b,2
        call set_ink
        pop de                  ; D = col, E = row
        pop hl
        jp print
init_popups:
        ld hl,popups
        ld b,4
.l:     ld (hl),$FF
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        ld hl,particles
        ld b,10
.p:     ld (hl),0
        ld de,6
        add hl,de
        djnz .p
        ret
update_popups:
        ld hl,popups
        ld d,4
.l:     ld a,(hl)
        cp $FF
        jr z,.n
        push hl
        inc hl
        inc hl
        dec (hl)
        pop hl
        jr nz,.n
        push hl
        push de
        call popup_erase
        pop de
        pop hl
        ld (hl),$FF
.n:     inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.l
        ret
; redraw the cells under the popup at HL (col,row,tim,len)
popup_erase:
        ld a,(hl)               ; col
        ld (ai_bx),a
        inc hl
        ld a,(hl)
        ld (ai_by),a            ; row
        inc hl
        inc hl
        ld a,(hl)
        ld (tmpd),a             ; len
        ld a,(goldmode)
        ld (cnt),a
        ; cell x range: (col*4-4)/8 .. ((col+len)*4-5)/8
        ld a,(ai_bx)
        add a,a
        add a,a
        sub 4
        jr nc,.x0
        xor a
.x0:    rrca
        rrca
        rrca
        and 31
        ld (tmpx),a
        ld a,(ai_bx)
        ld b,a
        ld a,(tmpd)
        add a,b
        add a,a
        add a,a
        sub 5
        rrca
        rrca
        rrca
        and 31
        cp 15
        jr c,.x1
        ld a,14
.x1:    ld (best),a
        ; cell y range: (row-6)/7 .. (row-2)/7
        ld a,(ai_by)
        sub 6
        ld c,0
.y0:    sub 7
        jr c,.y0d
        inc c
        jr .y0
.y0d:   ld a,(ai_by)
        sub 2
        ld e,0
.y1:    sub 7
        jr c,.y1d
        inc e
        jr .y1
.y1d:   ld a,e
        cp 8
        jr c,.y2
        ld e,7
.y2:    ld a,e
        ld (bestd),a
.yl:    ld a,(tmpx)
        ld b,a
.xl:    push bc
        call draw_cell
        pop bc
        ld a,(best)
        cp b
        jr z,.xe
        inc b
        jr .xl
.xe:    ld a,(bestd)
        cp c
        ret z
        inc c
        jr .yl
draw_popups:
        ret

; burst: A = colour, B = x, C = y : spawn 6 particles
burst:
        ld (burstcol),a
        ld a,4
        ld (bcount),a
        ld hl,particles
        ld e,10
.f:     ld a,(hl)
        or a
        jr nz,.n
        push de
        push hl
        ld (hl),12
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ex de,hl
        ld a,(burstidx)
        inc a
        and 7
        ld (burstidx),a
        add a,a
        ld l,a
        ld h,0
        push bc
        ld bc,burstdir
        add hl,bc
        pop bc
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        ld a,(burstcol)
        ld (de),a
        pop hl
        pop de
        ld a,(bcount)
        dec a
        ld (bcount),a
        ret z
.n:     ld a,l
        add a,6
        ld l,a
        jr nc,.nc
        inc h
.nc:    dec e
        jr nz,.f
        ret
burstdir: db 2,0, -2,0, 0,-1, 0,1, 1,-1, -1,-1, 1,1, -1,1

update_particles:
        ld hl,particles
        ld d,10
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        jr z,.n
        push hl
        push de
        inc hl
        ld b,(hl)               ; x
        inc hl
        ld c,(hl)               ; y
        inc hl
        ld a,(hl)               ; vx
        add a,b
        ld b,a
        inc hl
        ld a,(hl)               ; vy
        add a,c
        ld c,a
        inc hl
        ld e,(hl)               ; colour
        dec hl
        dec hl
        dec hl
        ld (hl),c
        dec hl
        ld (hl),b
        ; inside the screen?
        ld a,b
        cp 128
        jr nc,.kill
        ld a,c
        cp 6
        jr c,.kill
        cp 62
        jr nc,.kill
        call dl_pixel
        jr .d
.kill:  dec hl
        ld (hl),0
.d:     pop de
        pop hl
.n:     ld a,l
        add a,6
        ld l,a
        jr nc,.nc
        inc h
.nc:    dec d
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; DEMO AI
; ---------------------------------------------------------------------
ai_think:
        xor a
        ld (inp),a
        ld (inpnew),a
        ld ix,peng
        ld a,(ix+A_SUB)
        or a
        ret nz
        ld a,(ai_cool)
        or a
        jr z,.t
        dec a
        ld (ai_cool),a
        ret
.t:     ; 1. can a push kill something?
        ld d,0
.pd:    push de
        call ai_line_kill
        pop de
        jp z,.kill
        inc d
        ld a,d
        cp 4
        jr nz,.pd
        ; 2. otherwise pick the move that keeps about 3 cells from danger
        ld a,$FF
        ld (best),a
        xor a
        ld (bestd),a            ; best score (0 = none)
        ld d,0
.cd:    ld b,(ix+A_CX)
        ld c,(ix+A_CY)
        ld a,d
        push de
        call step_bc
        push bc
        call peng_can_enter
        pop bc
        pop de
        jr nz,.cn
        push de
        call ai_score_cell      ; A = distance to nearest danger from B,C
        pop de
        cp 3
        ld e,1
        jr c,.sc
        sub 4
        jr nc,.p
        neg
.p:     cp 10
        jr c,.p2
        ld a,10
.p2:    ld e,a
        ld a,20
        sub e
        ld e,a
        call random
        and 3
        add a,e
        ld e,a
        ld a,(facing)
        xor 1
        cp d
        jr z,.ex
        inc e
        inc e
        inc e
.ex:    push de
        call ai_exits           ; A = open neighbours of B,C
        pop de
        add a,a
        add a,e
        ld e,a
        ; a kill set up from there?
        push de
        ld a,b
        ld (ai_bx),a
        ld a,c
        ld (ai_by),a
        ld d,0
.kl:    ld a,(ai_bx)
        ld b,a
        ld a,(ai_by)
        ld c,a
        push de
        call ai_line_kill_at
        pop de
        jr z,.kf
        inc d
        ld a,d
        cp 4
        jr nz,.kl
        pop de
        jr .sc
.kf:    pop de
        ld a,e
        add a,10
        ld e,a
.sc:    ld a,(bestd)
        cp e
        jr nc,.cn
        ld a,e
        ld (bestd),a
        ld a,d
        ld (best),a
.cn:    inc d
        ld a,d
        cp 4
        jp nz,.cd
        ld a,(best)
        cp 4
        ret nc
        jr .press
.kill:  ld a,(facing)
        cp d
        jr nz,.turn
        ld a,$10
        ld (inpnew),a
        ld (inp),a
        ld a,8
        ld (ai_cool),a
        ret
.turn:  ld a,d
.press: ld e,a
        ld d,0
        ld hl,dirbit
        add hl,de
        ld a,(hl)
        ld (inp),a
        ld (inpnew),a
        ret

; Z if pushing in direction D would send a block into a monster
ai_line_kill:
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
; same, standing at B,C
ai_line_kill_at:
        ld a,d
        call step_bc
        call cell_get
        cp G_ICE
        jr z,.b
        cp G_EGG
        jr z,.b
        cp G_CRYS
        jr nz,.no
.b:     ld e,14
.walk:  ld a,d
        push de
        call step_bc
        pop de
        call cell_get
        cp G_EMPTY
        jr z,.ok
        cp G_ITEM
        jr nz,.no
.ok:    push de
        push bc
        call ai_monster_at
        pop bc
        pop de
        ret z
        dec e
        jr nz,.walk
.no:    or 1
        ret
; Z if a live monster is (mostly) in cell B,C
ai_monster_at:
        push ix
        ld ix,mons
        ld e,4
.l:     ld a,(ix+A_TYPE)
        or a
        jr z,.n
        ld a,(ix+A_ST)
        cp ST_WALK
        jr z,.c
        cp ST_STUN
        jr z,.c
        cp ST_MUNCH
        jr nz,.n
.c:     push bc
        push de
        ld h,b
        ld l,c
        call round_cell
        ld a,b
        cp h
        jr nz,.no
        ld a,c
        cp l
.no:    pop de
        pop bc
        jr z,.yes
.n:     ld bc,16
        add ix,bc
        ld b,h
        ld c,l
        dec e
        jr nz,.l
        pop ix
        or 1
        ret
.yes:   pop ix
        xor a
        ret
; number of open neighbours of B,C -> A (B,C preserved)
ai_exits:
        ld a,b
        ld (tmpx),a
        ld a,c
        ld (cnt),a
        ld h,0
        ld d,0
.l:     ld a,(tmpx)
        ld b,a
        ld a,(cnt)
        ld c,a
        ld a,d
        push de
        push hl
        call step_bc
        call cell_get
        pop hl
        pop de
        or a
        jr z,.o
        cp G_ITEM
        jr nz,.n
.o:     inc h
.n:     inc d
        ld a,d
        cp 4
        jr nz,.l
        ld a,(tmpx)
        ld b,a
        ld a,(cnt)
        ld c,a
        ld a,h
        ret
; distance (cells) from the penguin to the nearest dangerous monster
ai_nearest:
        ld b,(ix+A_CX)
        ld c,(ix+A_CY)
; A = distance from B,C to the nearest walking monster (255 if none)
ai_score_cell:
        ld a,b
        ld (tmpx),a
        ld a,c
        ld (cnt),a
        ld l,255
        push ix
        ld ix,mons
        ld h,4
.l:     ld a,(ix+A_TYPE)
        or a
        jr z,.n
        ld a,(ix+A_ST)
        cp ST_WALK
        jr z,.c
        cp ST_MUNCH
        jr nz,.n
.c:     push hl
        call round_cell
        ld a,(tmpx)
        call absdiff_ab
        ld e,a
        ld a,(cnt)
        ld b,c
        call absdiff_ab
        add a,e
        pop hl
        cp l
        jr nc,.n
        ld l,a
.n:     ld de,16
        add ix,de
        dec h
        jr nz,.l
        pop ix
        ld a,(tmpx)
        ld b,a
        ld a,(cnt)
        ld c,a
        ld a,l
        ret

popstr: dw ps0,ps1,ps2,ps3,ps4,ps5,ps6,ps7,ps8,ps9,ps10,ps11
ps0:    db "100",0
ps1:    db "400",0
ps2:    db "1600",0
ps3:    db "3200",0
ps4:    db "6400",0
ps5:    db "500",0
ps6:    db "1000",0
ps7:    db "2000",0
ps8:    db "10000",0
ps9:    db "5000",0
ps10:   db "1UP",0
ps11:   db "GOLD",0
