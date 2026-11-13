; =====================================================================
;  GAME: Bluff, the toads, the bugs. All motion is in pixels (320 x 176
;  playfield of 20 x 11 tiles), 8.8 fixed point, one tick = one 50 Hz field.
; =====================================================================
WALKV       EQU $0140       ; 1.25 px a tick
ACC         EQU $0028
FRIC        EQU $0038
GRAV        EQU $0026
JUMPV       EQU $0390
MAXFALL     EQU $0400
GLIDEV      EQU $0078       ; sink rate under the frill
BOUNCEV     EQU $0500       ; off a toad on its back
HERO_H      EQU 15          ; he fits under a ledge one tile up

T_SOLID     EQU 1
T_ONEWAY    EQU 2
T_WATER     EQU 3

O_BUG       EQU 1
O_TOAD      EQU 2
O_START     EQU 3
O_SPARK     EQU 4
O_GOAL      EQU 5
O_MAGPIE    EQU 6
O_GOANNA    EQU 7
E_A         EQU 11          ; (magpie) home x, a word
E_C         EQU 13          ; (magpie) set up
E_D         EQU 14          ; cool-down before it attacks again
SPRINTV     EQU $0200       ; 2 px a tick
SPRINT_T    EQU 40          ; ticks of flat-out running before he bolts
WATER_T     EQU 45          ; ticks he can sprint on water

NENT        EQU 8
E_TYPE      EQU 0
E_STATE     EQU 1
E_X         EQU 2
E_Y         EQU 4
E_T         EQU 6
E_FACE      EQU 7
E_OFF       EQU 8           ; height above its ground line
E_HOME      EQU 9
E_OBJ       EQU 10
E_SIZE      EQU 16

; ---------------------------------------------------------------------
monitor_select:
        ld a,$0F
        call cls
        ld hl,t_name
        ld de,$050E
        ld c,YELLOW
        call print
        ld hl,t_l1
        ld de,$080C
        ld c,WHITE
        call print
        ld hl,t_l2
        ld de,$0A0E
        ld c,WHITE
        call print
        ld hl,t_l3
        ld de,$0F0B
        ld c,BCYAN
        call print
        ld hl,t_l4
        ld de,$110C
        ld c,BCYAN
        call print
        ld hl,t_credit
        ld de,$160A
        ld c,BGREEN
        call print
        call display_on
.w:     call read_menu
        call rnd
        ld a,(pad)
        bit 6,a
        jr nz,.col
        bit 5,a
        jr z,.w
        ld a,1
        ld (mono),a
        ld a,BLK_ROOMM
        jr .go
.col:   xor a
        ld (mono),a
        ld a,BLK_ROOMC
.go:    ld (roomblk0),a
        ; fall into the title

; ---------------------------------------------------------------------
;  the title: the picture, the theme in two voices, SPACE to play
; ---------------------------------------------------------------------
title_screen:
        ld sp,STACK
        ld a,$80                ; from the top
attract:
        push af
        xor a
        ld (mus_on),a
        ld (sfx_on),a
        ld (demo),a
        out (P_PIOB),a
        pop af
        call front_attract      ; -> 0: play; else region + 1 to demonstrate, HL = its script
        or a
        jp z,game_start
        dec a
        ld (region),a
        ld (dm_ptr),hl
        ld a,1
demo_go:
        ld (demo),a
        ld a,(region)
        push af
        ld hl,gtick             ; the same game every time: everything from the same start
        ld b,dm_ptr-gtick
.z:     ld (hl),0
        inc hl
        djnz .z
        pop af
        ld (region),a
        ld hl,$2A17
        ld (rseed),hl
        call new_game
        jp region_restart
; tools/demo.py starts a recording here, with (region) set
demo_rec:
        ld sp,STACK
        ld a,2
        jr demo_go

; the front end, in its own block (src/front.asm)
front_attract:
        ld hl,$0100
        jr front
front_jingle:
        ld hl,$0103
front:  push af
        ld a,BLK_FRONT
        call map_blk
        pop af
        jp (hl)
; (from the front end) the title picture, and back
far_title:
        call title_show
        ld a,BLK_FRONT
        jp map_blk

; a tick of a demonstration: the pad comes from the script, pairs of
; (pad, ticks), 0 ticks at the end
demo_pad:
        ld hl,(dm_n)
        inc hl
        ld (dm_n),hl
        dec a
        jr nz,.hold             ; (recording: the pad is put in dm_pad from outside)
        ld a,(dm_left)
        or a
        jr nz,.run
        ld a,(cur_blk)
        push af
        ld a,BLK_FRONT
        call map_blk
        ld hl,(dm_ptr)
        ld a,(hl)
        ld (dm_pad),a
        inc hl
        ld a,(hl)
        inc hl
        ld (dm_ptr),hl
        ld (dm_left),a
        pop af
        call map_blk
        ld a,(dm_left)
        or a
        jr nz,.run
        ld a,3                  ; the script is over
        ld (game_end),a
        ret
.run:   dec a
        ld (dm_left),a
.hold:  ld hl,dm_prev
        ld a,(dm_pad)
        ld b,a
        ld a,(hl)
        cpl
        and b
        ld (padnew),a
        ld a,b
        ld (hl),a
        ld (pad),a
        ret

t_name:   db "FRILLSEEKER",0
t_l1:     db "FOR THE MICROBEE",0
t_l2:     db "PREMIUM PLUS",0
t_l3:     db "C - COLOUR MONITOR",0
t_l4:     db "M - MONO MONITOR",0
t_credit: db " VIBED BY BPM 2026 ",0
t_demo:   db "DEMO",0

; ---------------------------------------------------------------------
;  the end of a game: the region cleared, or out of hearts
; ---------------------------------------------------------------------
end_game:
        ld sp,STACK
        ld b,a
        ld a,(demo)
        or a
        jr z,.real
        xor a                   ; a demonstration: on with the attract sequence
        jp attract
.real:  ld a,b
        push af
        xor a
        ld (sfx_on),a
        ld (mus_on),a
        out (P_PIOB),a
        call display_off
        ld a,$0F
        call cls
        pop af
        dec a
        jp nz,.over
        ; a region cleared
        ld a,(region)
        call reg_name_a
        ld d,3
        ld c,YELLOW
        call print_centred
        ld hl,t_isclear
        ld d,5
        ld c,YELLOW
        call print_centred
        ld hl,t_found
        ld de,$090A
        ld c,WHITE
        call print
        ld a,(bugs)
        ld de,$0915
        ld c,YELLOW
        call print_num
        ld a,(region)
        ld hl,reg_total
        call index_hl
        ld de,$091B
        ld c,YELLOW
        call print_num
        ld a,(region)
        inc a
        cp NREGIONS
        jr nc,.last
        ld hl,t_next
        ld d,14
        ld c,WHITE
        call print_centred
        ld a,(region)
        inc a
        call reg_name_a
        ld d,16
        ld c,BCYAN
        call print_centred
        call .press
        xor a
        call front_jingle
        call z,wait_key         ; a key during the jingle counts
        ld hl,region
        inc (hl)
        jp region_restart
.last:  ld hl,t_clear3
        ld d,14
        ld c,BCYAN
        call print_centred
        ld hl,t_clear4
        ld d,16
        ld c,BCYAN
        call print_centred
        call .press
        xor a
        call front_jingle
        call z,wait_key         ; a key during the jingle counts
        jp title_screen
.over:  ld hl,t_over1
        ld d,8
        ld c,BRED
        call print_centred
        ld hl,t_over2
        ld d,12
        ld c,WHITE
        call print_centred
        ld hl,t_over3
        ld d,17
        ld c,BGREEN
        call print_centred
        ld hl,t_over4
        ld d,19
        ld c,GREY
        call print_centred
        call display_on
        ld a,1
        call front_jingle
        call z,wait_choice
        and $80
        jp nz,title_screen
        jp region_restart
.press: ld hl,t_again
        ld d,22
        ld c,BGREEN
        call print_centred
        jp display_on

t_isclear: db "IS CLEAR!",0
t_found:  db "BUGS FOUND    OF",0
t_next:   db "NEXT STOP",0
t_clear3: db "MORE OF THE TOP END",0
t_clear4: db "COMING SOON",0
t_over1:  db "GAME OVER",0
t_over2:  db "THE TOADS HAVE IT - FOR NOW",0
t_over3:  db "SPACE - TRY AGAIN",0
t_over4:  db "ESC - BACK TO THE TITLE",0
t_again:  db "PRESS SPACE",0

; HL = string, D = row, C = colour: printed in the middle of the row
print_centred:
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc b
        inc hl
        jr .l
.d:     ld a,40
        sub b
        srl a
        ld e,a
        pop hl
        jp print

; wait for SPACE or ESC: NZ = ESC
wait_choice:
.r:     call read_menu
        ld a,(pad)
        and $90
        jr nz,.r
.w:     call read_menu
        ld a,(padnew)
        and $90
        jr z,.w
        and $80
        ret

; A = number (0-99), D = row, E = column, C = colour: two digits
print_num:
        ld b,'0'-1
.d:     inc b
        sub 10
        jr nc,.d
        add a,10+'0'
        push af
        push de
        push bc
        ld a,b
        call putch
        pop bc
        pop de
        pop af
        inc e
        jp putch

; wait for SPACE (or fire) to be let go of, then pressed
wait_key:
.r:     call read_menu
        ld a,(pad)
        and $10
        jr nz,.r
.w:     call read_menu
        ld a,(padnew)
        and $10
        jr z,.w
        ret

; ---------------------------------------------------------------------
game_start:
        xor a
        ld (demo),a
        ld (region),a
        call new_game
        jr region_restart
new_game:
        xor a
        ld (bugs),a
        ld hl,collected
        ld b,16
.c:     ld (hl),0
        inc hl
        djnz .c
        ret
        ; fall into region_restart

; (re)start the current region at its first room, three hearts. Bugs
; already found stay found.
region_restart:
        ld sp,STACK
        ld a,3
        ld (hearts),a
        xor a
        ld (game_end),a
        ld (h_hurt),a
        ld (h_inv),a
        ld hl,0
        ld (hvx),hl
        ld (hvy),hl
        call sprint_stop
        ld a,1
        ld (want_start),a
        ld (mus_on),a
        ld hl,tune
        ld (mus_ptr),hl
        ld a,(region)
        ld hl,reg_start
        call index_hl
        call enter_room
        jp main_loop

; HL = table, A = index -> A = (HL + A)
index_hl:
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ret

; A = region -> HL = its name
reg_name_a:
        add a,a
        ld e,a
        ld d,0
        ld hl,reg_name
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

main_loop:
        ld a,(demo)
        or a
        jr z,.live
        call read_menu          ; a demonstration: any key ends it
        ld a,(pad)
        and $90
        jp nz,title_screen
        jr .go
.live:  call read_input
        ld a,(pad)
        rla                     ; ESC: back to the title
        jp c,title_screen
.go:
        ld a,(fields)
        or a
        jr nz,.f1
        inc a
.f1:    cp 4
        jr c,.f2
        ld a,3
.f2:    ld b,a
        ld (lastfields),a
        xor a
        ld (fields),a
.t:     push bc
        call game_tick
        pop bc
        ld a,(newroom)
        inc a
        jr nz,.room
        djnz .t
        ld a,(game_end)
        or a
        jp nz,end_game
        call vpoll
        call frame_begin
        call draw_all
        call restores
        call present
        call anim_service
        ld a,(hud_dirty)
        or a
        call nz,hud_stats
        jr main_loop
.room:  dec a
        call enter_room
        jr main_loop

game_tick:
        ld a,(demo)
        or a
        call nz,demo_pad
        ld hl,gtick
        inc (hl)
        call hero_tick
        call ents_tick
        call anim_tick
        jp snd_tick

; A = room: load it, spawn what lives there, draw the panel
enter_room:
        call room_load
        ld a,$FF
        ld (newroom),a
        ; entities
        ld hl,ENTS
        ld de,ENTS+1
        ld bc,NENT*E_SIZE-1
        ld (hl),0
        ldir
        ld hl,R_OBJ
        call room_ptr
        ld iy,ENTS
        ld c,0                  ; object index
.o:     ld a,(hl)
        or a
        jr z,.bugs
        cp O_START
        jr nz,.no_start
        ld a,(want_start)
        or a
        jr z,.next
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (hx),de
        inc hl
        ld e,(hl)
        ld d,0
        ld (hy),de
        dec hl
        dec hl
        dec hl
        jr .next
.no_start:
        bit 7,a                 ; a bug: it lives in the background (below)
        jr nz,.next
        ld (iy+E_TYPE),a
        inc hl
        ld a,(hl)
        ld (iy+E_X),a
        inc hl
        ld a,(hl)
        ld (iy+E_X+1),a
        inc hl
        ld a,(hl)
        ld (iy+E_Y),a
        ld (iy+E_Y+1),0
        dec hl
        dec hl
        dec hl
        ld (iy+E_OBJ),c
        call rnd
        and 63
        add a,20
        ld (iy+E_T),a
        ld (iy+E_STATE),0
        ld (iy+E_OFF),0
        call rnd
        and 1
        ld (iy+E_FACE),a
        ld de,E_SIZE
        add iy,de
.next:  inc hl
        inc hl
        inc hl
        inc hl
        inc c
        ld a,c
        cp 8
        jr c,.o
.bugs:  ; the bugs: eaten ones go back to scenery, the rest get an entity
        ld ix,ANIMS
        ld b,1
.b:     ld a,(ix+A_TYPE)
        cp 2
        jr nz,.bn
        push bc
        call anim_tail          ; object index, x (word), y
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (iy+E_Y),a
        ld (iy+E_Y+1),0
        pop af                  ; set number + 1
        push af
        ld (iy+E_HOME),a
        ld (iy+E_OBJ),c
        ld (iy+E_X),e
        ld (iy+E_X+1),d
        call col_ptr
        ld a,(hl)
        ld b,c
        inc b
.sh:    rrca
        djnz .sh
        jr nc,.alive
        xor a
        ld (an_video),a
        pop af
        push af
        push ix
        call anim_kill
        pop ix
        jr .bd
.alive: ld (iy+E_TYPE),O_BUG
        ld de,E_SIZE
        add iy,de
.bd:    pop bc
.bn:    ld de,A_SIZE
        add ix,de
        inc b
        ld a,b
        cp NANIM+1
        jr c,.b
        xor a
        ld (want_start),a
        ld hl,(hx)
        ld (rs_x),hl
        ld hl,(hy)
        ld (rs_y),hl
        call room_show
        call hud_all
        jp display_on

; HL = this room's "collected" byte
col_ptr:
        ld a,(room)
        add a,collected & 255
        ld l,a
        ld h,collected >> 8
        ret

; ---------------------------------------------------------------------
;  the status panel (cell rows 0-1)
; ---------------------------------------------------------------------
hud_all:
        ld hl,R_NAME
        call room_ptr
        ld de,hudname
        ld bc,16
        ldir
        xor a
        ld (de),a
        ld hl,hudname
        ld de,$0014
        ld c,BCYAN
        call print
        ld hl,t_bugs
        ld de,$0006
        ld c,WHITE
        call print
        ld a,(demo)
        or a
        jr z,hud_stats
        ld hl,t_demo
        ld de,$0024
        ld c,BRED
        call print
hud_stats:
        xor a
        ld (hud_dirty),a
        ; hearts
        ld e,0
.h:     ld a,(hearts)
        ld b,a
        ld a,e
        cp b
        ld a,'['
        ld c,BRED
        jr c,.full
        ld a,']'
        ld c,DGREY
.full:  push de
        ld d,0
        call putch
        pop de
        inc e
        ld a,e
        cp 3
        jr nz,.h
        ; bugs: two digits
        ld a,(bugs)
        ld b,'0'-1
.d:     inc b
        sub 10
        jr nc,.d
        add a,10+'0'
        push af
        ld a,b
        ld de,$000B
        ld c,YELLOW
        call putch
        pop af
        ld de,$000C
        ld c,YELLOW
        jp putch
t_bugs: db "BUGS",0

; ---------------------------------------------------------------------
;  tiles. DE = x, HL = y (playfield pixels, signed) -> A = tile flag
; ---------------------------------------------------------------------
tile_at:
        ld a,h
        or a
        jr nz,.none
        ld a,l
        cp 176
        jr nc,.none
        ld a,d
        or a
        jr z,.xin
        dec a
        jr nz,.xout
        ld a,e
        cp ROOM_W-256
        jr nc,.xout
.xin:   ld a,l                  ; row * 20
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,row20tab & 255
        ld l,a
        ld h,row20tab >> 8
        ld l,(hl)
        srl d                   ; x / 16
        rr e
        srl e
        srl e
        srl e
        ld a,e
        add a,l
        ld l,a
        ld h,TMAP >> 8
        ld a,(hl)
        ret
.none:  xor a
        ret
.xout:  bit 7,d
        ld a,(nb_left)
        jr nz,.x1
        ld a,(nb_right)
.x1:    inc a
        jr z,.wall
        xor a
        ret
.wall:  ld a,T_SOLID
        ret

; ---------------------------------------------------------------------
;  Bluff
; ---------------------------------------------------------------------
hero_tick:
        ld a,(h_inv)
        or a
        jr z,.i0
        dec a
        ld (h_inv),a
.i0:    ld a,(h_drop)
        or a
        jr z,.d0
        dec a
        ld (h_drop),a
.d0:    xor a
        ld (h_glide),a
        ld a,(h_hurt)
        or a
        jr z,.ctl
        dec a
        ld (h_hurt),a
        jp .phys
.ctl:   ; the bluff: on the ground, frill held
        ld a,(pad)
        bit PB_FRILL,a
        jr z,.noflare
        ld a,(h_on)
        or a
        jr z,.noflare
        ld hl,0
        ld (hvx),hl
        call sprint_stop
        ld a,(h_flare)
        inc a
        cp 56
        jr c,.fl1
        ld a,24
.fl1:   ld (h_flare),a
        cp 8
        call z,scare
        jp .jump
.noflare:
        xor a
        ld (h_flare),a
        ld a,(pad)
        bit PB_RIGHT,a
        jr nz,.right
        bit PB_LEFT,a
        jr nz,.left
        ; friction
        ld hl,(hvx)
        ld a,h
        or l
        jr z,.jump
        bit 7,h
        jr nz,.fn
        ld de,-FRIC
        add hl,de
        bit 7,h
        jr z,.sx
        ld hl,0
        jr .sx
.fn:    ld de,FRIC
        add hl,de
        bit 7,h
        jr nz,.sx
        ld hl,0
        jr .sx
.right: xor a
        ld (h_face),a
        ld hl,(hvx)
        ld de,ACC
        add hl,de
        bit 7,h
        jr nz,.sx
        ld de,(h_vmax)
        inc de
        or a
        sbc hl,de
        add hl,de
        jr c,.sx
        ld hl,(h_vmax)
        jr .sx
.left:  ld a,1
        ld (h_face),a
        ld hl,(hvx)
        ld de,-ACC
        add hl,de
        bit 7,h
        jr z,.sx
        ld de,(h_vmax)
        add hl,de
        bit 7,h
        jr z,.lok
        ld hl,0
.lok:   or a
        sbc hl,de
.sx:    ld (hvx),hl
        call sprint_tick
.jump:  ld a,(padnew)
        bit PB_JUMP,a
        jr z,.j1
        ld a,6
        ld (h_jbuf),a
.j1:    ld a,(h_jbuf)
        or a
        jr z,.j9
        dec a
        ld (h_jbuf),a
        ld a,(h_coy)
        or a
        jr z,.j9
        ; down + jump on a branch: drop through
        ld a,(pad)
        bit PB_DOWN,a
        jr z,.j2
        ld a,10
        ld (h_drop),a
        xor a
        ld (h_jbuf),a
        ld (h_coy),a
        jr .j9
.j2:    ld hl,-JUMPV
        ld (hvy),hl
        ld a,1
        ld (h_jump),a
        xor a
        ld (h_coy),a
        ld (h_jbuf),a
        ld (h_flare),a
        ld hl,sfx_jump
        call play_sfx
.j9:
.phys:  ; gravity
        ld hl,(hvy)
        ld de,GRAV
        add hl,de
        bit 7,h
        jr z,.falling
        ; rising from a jump: let go of the key for a short hop
        ld a,(h_jump)
        or a
        jr z,.sy
        ld a,(pad)
        bit PB_JUMP,a
        jr nz,.sy
        ld de,GRAV*2
        add hl,de
        jr .sy
.falling:
        ld a,(h_on)
        or a
        jr nz,.nogl
        ld a,(h_hurt)
        or a
        jr nz,.nogl
        ld a,(pad)
        bit PB_FRILL,a
        jr z,.nogl
        ld a,1
        ld (h_glide),a
        ld de,GLIDEV+1
        or a
        sbc hl,de
        add hl,de
        jr c,.sy
        ; ease down to the glide speed
        ld de,-$0060
        add hl,de
        ld de,GLIDEV
        or a
        sbc hl,de
        add hl,de
        jr nc,.sy
        ld hl,GLIDEV
        jr .sy
.nogl:  ld de,MAXFALL+1
        or a
        sbc hl,de
        add hl,de
        jr c,.sy
        ld hl,MAXFALL
.sy:    ld (hvy),hl

        ; ---- move across
        ld hl,(hvx)
        ld a,h
        or l
        jp z,.hdone
        ld a,(hxf)
        add a,l
        ld (hxf),a
        ld e,h
        ld d,0
        bit 7,h
        jr z,.hx1
        dec d
.hx1:   ld hl,(hx)
        adc hl,de
        ld (hx),hl
        ld a,(hvx+1)
        bit 7,a
        jr nz,.hleft
        ld de,5
        add hl,de
        ex de,hl
        call hprobe
        jr z,.hdone
        ld a,e
        and $F0
        ld l,a
        ld h,d
        ld de,-6
        add hl,de
        jr .hstop
.hleft: ld de,-6
        add hl,de
        ex de,hl
        call hprobe
        jr z,.hdone
        ld a,e
        and $F0
        ld l,a
        ld h,d
        ld de,22
        add hl,de
.hstop: ld (hx),hl
        call sprint_stop        ; a wall ends the sprint
        ld hl,0
        ld (hvx),hl
        xor a
        ld (hxf),a
.hdone:
        ; ---- move down / up
        ld hl,(hy)
        ld (oldy),hl
        ld hl,(hvy)
        ld a,(hyf)
        add a,l
        ld (hyf),a
        ld e,h
        ld d,0
        bit 7,h
        jr z,.hy1
        dec d
.hy1:   ld hl,(hy)
        adc hl,de
        ld (hy),hl
        ld a,(h_on)
        ld (h_was),a
        xor a
        ld (h_on),a
        ld a,(hvy+1)
        bit 7,a
        jr nz,.rising
        ld hl,(hx)
        ld de,-4
        add hl,de
        ex de,hl
        call .foot
        jr c,.land
        ld hl,(hx)
        ld de,3
        add hl,de
        ex de,hl
        call .foot
        jr c,.land
        ; in the air
        ld a,(h_coy)
        or a
        jr z,.vdone
        dec a
        ld (h_coy),a
        jr .vdone
.land:  ld hl,(hy)
        ld a,l
        and $F0
        ld l,a
        ld (hy),hl
        ld hl,0
        ld (hvy),hl
        xor a
        ld (hyf),a
        inc a
        ld (h_on),a
        ld a,6
        ld (h_coy),a
        ld a,(h_was)
        or a
        jr nz,.vdone
        ld hl,sfx_land
        call play_sfx
        ; solid ground is where a fall puts you back
        ld de,(hx)
        ld hl,(hy)
        call tile_at
        cp T_SOLID
        jr nz,.vdone
        ld hl,(hx)
        ld (rs_x),hl
        ld hl,(hy)
        ld (rs_y),hl
        jr .vdone
.rising:
        ld hl,(hx)
        ld de,-4
        add hl,de
        ex de,hl
        call .head
        jr z,.bonk
        ld hl,(hx)
        ld de,3
        add hl,de
        ex de,hl
        call .head
        jr nz,.vdone
.bonk:  ld hl,(oldy)
        ld (hy),hl
        ld hl,0
        ld (hvy),hl
.vdone:
        ; ---- off the side of the room?
        ld hl,(hx)
        bit 7,h
        jr nz,.goleft
        ld de,ROOM_W
        or a
        sbc hl,de
        jr c,.inroom
        ld (hx),hl
        ld a,(nb_right)
        ld (newroom),a
        ret
.goleft:
        ld de,ROOM_W
        add hl,de
        ld (hx),hl
        ld a,(nb_left)
        ld (newroom),a
        ret
.inroom:
        ; ---- off the top or bottom: the room above or below, or a fall
        ld hl,(hy)
        bit 7,h
        jr z,.notup
        ld a,(nb_up)
        cp $FF
        jp z,.anim
        ld de,176
        add hl,de
        ld (hy),hl
        ld (newroom),a
        ret
.notup: ld a,h
        or a
        jr nz,.down
        ld a,l
        cp 176
        jr nc,.down
        ; water under the feet?
        ld de,-3
        add hl,de
        ld de,(hx)
        call tile_at
        cp T_WATER
        jr nz,.anim
        ld a,(hy)
        and 15
        cp 8
        jr c,.anim
.pit:   call hero_fell
        jr .anim
.down:  ld a,(nb_down)
        cp $FF
        jr z,.pit
        ld de,-176
        add hl,de
        ld (hy),hl
        ld (newroom),a
        ret
.anim:  ld a,(hvx+1)
        ld hl,hvx
        or (hl)
        ret z
        ld hl,h_run
        inc (hl)
        ret

; DE = x: is there ground under the feet line? carry = land
.foot:  ld hl,(hy)
        call tile_at
        cp T_SOLID
        scf
        ret z
        cp T_WATER
        jr nz,.f1
        ld a,(h_spr)            ; sprinting: water holds him up
        or a
        jr z,.fno
        jr .above
.f1:    cp T_ONEWAY
        jr nz,.fno
        ld a,(h_drop)
        or a
        jr nz,.fno
.above:
        ; only from above: was the old feet line at or above the tile top?
        ld hl,(hy)
        ld a,l
        and $F0
        ld l,a
        ld de,(oldy)
        or a
        sbc hl,de
        jp m,.fno
        scf
        ret
.fno:   or a
        ret
; DE = x: Z if the head would be in a solid tile
.head:  ld hl,(hy)
        ld bc,-HERO_H
        add hl,bc
        call tile_at
        cp T_SOLID
        ret

; the sprint: run flat out on the ground for a moment and he rears up and
; bolts. It lasts while a direction is held and he keeps going; on water
; he stays up for a second, then sinks.
sprint_tick:
        ld a,(pad)
        and 3
        jr z,sprint_stop
        ld hl,(hvx)
        ld a,h
        or l
        jr z,sprint_stop
        ld a,(h_face)
        ld hl,h_sface
        cp (hl)
        ld (hl),a
        jr nz,sprint_stop
        ld a,(h_spr)
        or a
        jr nz,.on
        ld a,(h_on)
        or a
        ret z
        ld hl,h_scnt
        inc (hl)
        ld a,(hl)
        cp SPRINT_T
        ret c
        ld a,1
        ld (h_spr),a
        ld hl,SPRINTV
        ld (h_vmax),hl
        ld hl,sfx_sprint
        jp play_sfx
.on:    ld a,(h_on)
        or a
        jr z,.dry
        ld de,(hx)
        ld hl,(hy)
        call tile_at
        cp T_WATER
        jr nz,.dry
        ld hl,h_wet
        inc (hl)
        ld a,(hl)
        cp WATER_T
        jr nc,sprint_stop
        and 7
        ret nz
        ld hl,sfx_splash
        jp play_sfx
.dry:   xor a
        ld (h_wet),a
        ret
sprint_stop:
        xor a
        ld (h_scnt),a
        ld (h_spr),a
        ld (h_wet),a
        ld hl,WALKV
        ld (h_vmax),hl
        ret

; DE = x -> NZ if a solid tile is in the way at any of three heights
hprobe:
        ld hl,(hy)
        ld bc,-2
        add hl,bc
        push de
        call tile_at
        pop de
        cp T_SOLID
        jr z,.hit
        ld hl,(hy)
        ld bc,-8
        add hl,bc
        push de
        call tile_at
        pop de
        cp T_SOLID
        jr z,.hit
        ld hl,(hy)
        ld bc,-14
        add hl,bc
        push de
        call tile_at
        pop de
        cp T_SOLID
        jr z,.hit
        xor a
        ret
.hit:   or 1
        ret

hero_hurt:
        ld a,(h_inv)
        or a
        ret nz
        call sprint_stop
        ld a,16
        ld (h_hurt),a
        ld hl,-$0280
        ld (hvy),hl
        xor a
        ld (h_jump),a
        ld hl,$0120
        ld a,(h_face)
        or a
        jr nz,.r
        ld hl,-$0120
.r:     ld (hvx),hl
        xor a
        ld (h_on),a
        ld (h_coy),a
        ld (h_flare),a
lose_heart:
        ld a,100
        ld (h_inv),a
        ld a,1
        ld (hud_dirty),a
        ld hl,sfx_hurt
        call play_sfx
        ld hl,hearts
        dec (hl)
        ret nz
        ; out of hearts
        ld a,2
        ld (game_end),a
        ret

hero_fell:
        call sprint_stop
        ld hl,(rs_x)
        ld (hx),hl
        ld hl,(rs_y)
        ld (hy),hl
        ld hl,0
        ld (hvx),hl
        ld (hvy),hl
        xor a
        ld (h_inv),a
        jr lose_heart

; the frill is up: every toad close by takes fright
scare:  ld hl,sfx_hiss
        call play_sfx
        ld ix,ENTS
        ld b,NENT
.l:     ld a,(ix+E_TYPE)
        cp O_MAGPIE
        jr nz,.nm
        ld a,(ix+E_STATE)
        cp 3
        jr z,.n
        call ent_dx
        cp 88
        jr nc,.n
        call ent_dy
        cp 88
        jr nc,.n
        ld (ix+E_STATE),3       ; off it goes, the other way
        call ent_face_hero
        xor 1
        ld (ix+E_FACE),a
        ld hl,sfx_squawk
        call play_sfx
        jr .n
.nm:    cp O_GOANNA
        jr nz,.nt
        ld a,(ix+E_STATE)       ; a goanna is not impressed
        dec a
        jr z,.n
        call ent_dx
        cp 120
        jr nc,.n
        call goanna_charge
        jr .n
.nt:    cp O_TOAD
        jr nz,.n
        ld a,(ix+E_STATE)
        cp 2
        jr nc,.n
        call ent_dx
        cp 72
        jr nc,.n
        call ent_dy
        cp 40
        jr nc,.n
        ld (ix+E_STATE),2
        ld (ix+E_T),0
.n:     ld de,E_SIZE
        add ix,de
        djnz .l
        ret

; A = |entity x - hero x| (255 if far)
ent_dx: ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld de,(hx)
        or a
        sbc hl,de
        jr absb
; A = |entity y - (hero y - 10)|
ent_dy: ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        ld de,(hy)
        or a
        sbc hl,de
        ld de,10
        add hl,de
absb:   bit 7,h
        jr z,.p
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.p:     ld a,h
        or a
        ld a,l
        ret z
        ld a,255
        ret

; ---------------------------------------------------------------------
;  everything else that moves
; ---------------------------------------------------------------------
ents_tick:
        ld ix,ENTS
        ld b,NENT
.l:     push bc
        ld a,(ix+E_TYPE)
        cp O_BUG
        call z,bug_tick
        cp O_TOAD
        call z,toad_tick
        cp O_SPARK
        call z,spark_tick
        cp O_GOAL
        call z,goal_tick
        cp O_MAGPIE
        call z,magpie_tick
        cp O_GOANNA
        call z,goanna_tick
        pop bc
        ld de,E_SIZE
        add ix,de
        djnz .l
        ret

bug_tick:
        call ent_dx
        cp 10
        jr nc,.no
        call ent_dy
        cp 14
        jr nc,.no
        ld a,(killq)            ; one at a time
        or a
        jr nz,.no
        ; yum
        ld a,(ix+E_HOME)
        ld (killq),a
        ld (ix+E_TYPE),O_SPARK
        ld (ix+E_T),14
        ld hl,bugs
        inc (hl)
        ld a,1
        ld (hud_dirty),a
        call col_ptr
        ld b,(ix+E_OBJ)
        inc b
        xor a
        scf
.sh:    rla
        djnz .sh
        or (hl)
        ld (hl),a
        ld hl,sfx_bug
        call play_sfx
.no:    ld a,O_BUG
        ret

; King Bufo's larder: reach it and the region is clear
goal_tick:
        call ent_dx
        cp 12
        jr nc,.n
        call ent_dy
        cp 16
        jr nc,.n
        ld a,1
        ld (game_end),a
.n:     ld a,O_GOAL
        ret

spark_tick:
        dec (ix+E_T)
        ld a,O_SPARK
        ret nz
        ld (ix+E_TYPE),0
        xor a
        ret

; toad states: 0 sitting, 1 hopping, 2 startled (in the air), 3 on its back
toad_tick:
        ld a,(ix+E_STATE)
        or a
        jr z,.sit
        dec a
        jr z,.hop
        dec a
        jr z,.eek
        ; on its back
        dec (ix+E_T)
        jp nz,.touch
        ld (ix+E_STATE),0
        ld (ix+E_T),40
        jr .touch
.eek:   inc (ix+E_T)
        ld a,(ix+E_T)
        cp 24
        jr nc,.flop
        ld l,a
        ld h,0
        ld de,eekarc
        add hl,de
        ld a,(hl)
        ld (ix+E_OFF),a
        jr .touch
.flop:  ld (ix+E_STATE),3
        ld (ix+E_T),250
        ld (ix+E_OFF),0
        ld hl,sfx_croak
        call play_sfx
        jr .touch
.sit:   dec (ix+E_T)
        jr nz,.touch
        call toad_look
        ld (ix+E_STATE),1
        ld (ix+E_T),0
        jr .touch
.hop:   ld a,(ix+E_T)
        cp 16
        jr nc,.sat
        ld l,a
        ld h,0
        ld de,hoparc
        add hl,de
        ld a,(hl)
        ld (ix+E_OFF),a
        inc (ix+E_T)
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld a,(ix+E_FACE)
        or a
        jr nz,.hl
        inc hl
        inc hl
.hl:    dec hl
        ld (ix+E_X),l
        ld (ix+E_X+1),h
        jr .touch
.sat:   ld (ix+E_STATE),0
        ld (ix+E_OFF),0
        call rnd
        and 31
        add a,24
        ld (ix+E_T),a
.touch: call ent_dx
        cp 11
        jr nc,.done
        ; hero box hy-20..hy against toad box y-9..y
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        ld e,(ix+E_OFF)
        ld d,0
        or a
        sbc hl,de               ; toad's feet line
        ld de,(hy)
        or a
        sbc hl,de               ; toad feet - hero feet
        ; overlap when -9 < that < 20+... : hero feet below toad top (d < 9)
        ; and hero head above toad feet (d > -20)
        ld de,20
        add hl,de               ; 0..28 = touching
        ld a,h
        or a
        jr nz,.done
        ld a,l
        cp 29
        jr nc,.done
        ld a,(ix+E_STATE)
        cp 3
        jr z,.spring
        cp 2
        jr z,.done
        call hero_hurt
        jr .done
.spring:
        ; a toad on its back is a trampoline, from above
        ld a,(hvy+1)
        bit 7,a
        jr nz,.done
        ld a,(h_on)
        or a
        jr nz,.done
        ld a,l
        cp 18                   ; feet near the belly
        jr c,.done
        ld hl,-BOUNCEV
        ld (hvy),hl
        xor a
        ld (h_jump),a
        ld hl,sfx_boing
        call play_sfx
.done:  ld a,O_TOAD
        ret

; turn round unless there is ground to hop onto
toad_look:
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld de,16
        ld a,(ix+E_FACE)
        or a
        jr z,.r
        ld de,-16
.r:     add hl,de
        bit 7,h
        jr nz,.turn
        push hl
        ld bc,-10
        add hl,bc
        pop hl
        jr nc,.turn
        push hl
        ld bc,-(ROOM_W-10)
        add hl,bc
        pop hl
        jr c,.turn
        ex de,hl
        push de
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        call tile_at
        pop de
        or a
        jr z,.turn
        cp T_WATER
        jr z,.turn
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        ld bc,-5
        add hl,bc
        call tile_at
        cp T_SOLID
        ret nz
.turn:  ld a,(ix+E_FACE)
        xor 1
        ld (ix+E_FACE),a
        ret

; ---------------------------------------------------------------------
;  draw everything, back to front
; ---------------------------------------------------------------------
;  entity helpers
; ---------------------------------------------------------------------
; A = signed step: x += A
ent_addx:
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        add hl,de
        ld (ix+E_X),l
        ld (ix+E_X+1),h
        ret
; A = signed step: y += A
ent_addy:
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        add hl,de
        ld (ix+E_Y),l
        ld (ix+E_Y+1),h
        ret
; A = n -> A = n the way the entity faces
ent_dirstep:
        bit 0,(ix+E_FACE)
        ret z
        neg
        ret
; turn to face Bluff (A = the new facing)
ent_face_hero:
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld de,(hx)
        or a
        sbc hl,de
        ld a,0
        jr c,.r
        ld a,1
.r:     ld (ix+E_FACE),a
        ret

; ---------------------------------------------------------------------
;  the magpie: drifts about its home in the sky, and when Bluff walks
;  underneath it swoops. A bluff sends it off, squawking.
;  states: 0 drifting, 1 swooping, 2 climbing back, 3 leaving
; ---------------------------------------------------------------------
magpie_tick:
        ld a,(ix+E_C)
        or a
        jr nz,.go
        inc (ix+E_C)
        ld a,(ix+E_X)
        ld (ix+E_A),a
        ld a,(ix+E_X+1)
        ld (ix+E_A+1),a
        ld a,(ix+E_Y)
        ld (ix+E_HOME),a
        ld (ix+E_D),60
.go:    ld a,(ix+E_STATE)
        or a
        jr z,.drift
        dec a
        jp z,.dive
        dec a
        jp z,.climb
        ; leaving: up and away, then gone until Bluff comes back
        ld a,3
        call ent_dirstep
        call ent_addx
        ld a,-3
        call ent_addy
        bit 7,(ix+E_Y+1)
        jr z,.ret
        ld (ix+E_TYPE),0
.ret:   ld a,O_MAGPIE
        ret
.drift: inc (ix+E_T)
        bit 0,(ix+E_T)
        jr nz,.cool
        ld a,1
        call ent_dirstep
        call ent_addx
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld e,(ix+E_A)
        ld d,(ix+E_A+1)
        or a
        sbc hl,de
        call absb
        cp 40
        jr c,.cool
        call .homeward
.cool:  ld a,(ix+E_D)
        or a
        jr z,.look
        dec (ix+E_D)
        jp .touch
.look:  call ent_dx
        cp 44
        jr nc,.touch
        ld hl,(hy)              ; Bluff well below?
        ld de,-12
        add hl,de
        ld e,(ix+E_Y)
        ld d,(ix+E_Y+1)
        or a
        sbc hl,de
        jr c,.touch
        ld (ix+E_STATE),1
        ld (ix+E_T),0
        call ent_face_hero
        ld hl,sfx_swoop
        call play_sfx
        jr .touch
.dive:  ld a,2
        call ent_dirstep
        call ent_addx
        ld a,3
        call ent_addy
        inc (ix+E_T)
        ld a,(ix+E_T)
        cp 45
        jr nc,.up
        ld hl,(hy)              ; down to Bluff's head
        ld de,-8
        add hl,de
        ld e,(ix+E_Y)
        ld d,(ix+E_Y+1)
        or a
        sbc hl,de
        jr c,.up
        ld a,(ix+E_Y)
        cp 168
        jr c,.touch
.up:    ld (ix+E_STATE),2
        jr .touch
.climb: ld a,2
        call ent_dirstep
        call ent_addx
        ld a,-2
        call ent_addy
        ld a,(ix+E_Y)
        cp (ix+E_HOME)
        jr z,.home
        jr nc,.touch
.home:  ld (ix+E_STATE),0
        ld (ix+E_D),90
        call .homeward
.touch: ld a,(ix+E_STATE)
        cp 3
        jp z,.ret
        call ent_dx
        cp 10
        jp nc,.ret
        call ent_dy
        cp 12
        call c,hero_hurt
        jp .ret
; face back towards home
.homeward:
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld e,(ix+E_A)
        ld d,(ix+E_A+1)
        or a
        sbc hl,de
        ld a,0
        jr c,.hw
        ld a,1
.hw:    ld (ix+E_FACE),a
        ret

; ---------------------------------------------------------------------
;  the goanna: patrols its patch, and when Bluff is on its level it
;  charges, faster than he can walk. It cannot be bluffed (a bluff just
;  sets it off): jump it, climb away, or sprint.
;  states: 0 patrolling, 1 charging, 2 resting, tongue out
; ---------------------------------------------------------------------
goanna_tick:
        ld a,(ix+E_STATE)
        or a
        jr z,.patrol
        dec a
        jr z,.charge
        dec (ix+E_T)
        jr nz,.touch
        ld (ix+E_STATE),0
        ld (ix+E_D),50
        jr .touch
.patrol:
        inc (ix+E_T)
        bit 0,(ix+E_T)
        jr nz,.p2
        call toad_look
        ld a,1
        call ent_dirstep
        call ent_addx
.p2:    ld a,(ix+E_D)
        or a
        jr z,.see
        dec (ix+E_D)
        jr .touch
.see:   call ent_dy
        cp 20
        jr nc,.touch
        call ent_dx
        cp 120
        jr nc,.touch
        call goanna_charge
        jr .touch
.charge:
        inc (ix+E_T)
        ld a,(ix+E_FACE)
        push af
        call toad_look
        pop bc
        ld a,(ix+E_FACE)
        cp b
        jr nz,.stop             ; an edge or a wall ahead
        ld a,(ix+E_T)
        and 1
        inc a                   ; 1, 2, 1, 2: a pixel and a half a tick
        call ent_dirstep
        call ent_addx
        ld a,(ix+E_T)
        cp 110
        jr c,.touch
.stop:  ld (ix+E_STATE),2
        ld (ix+E_T),60
.touch: call ent_dx
        cp 16
        jr nc,.r
        call ent_dy
        cp 12
        call c,hero_hurt
.r:     ld a,O_GOANNA
        ret
goanna_charge:
        ld (ix+E_STATE),1
        ld (ix+E_T),0
        call ent_face_hero
        ld hl,sfx_goanna
        jp play_sfx

; ---------------------------------------------------------------------
draw_all:
        ; Bluff first: where sprites share a cell, his colour wins
        ld a,(h_inv)
        and 4
        jr nz,.ents
        ld hl,(hx)
        ld (sd_x),hl
        ld hl,(hy)
        ld (sd_y),hl
        ld a,(h_face)
        ld (sd_face),a
        ld a,YELLOW
        ld b,a
        ld a,(mono)
        or a
        jr z,.hc
        ld b,WHITE
.hc:    ld a,b
        ld (ds_col),a
        call hero_frame
        ld (sd_frame),a
        call sprite
        call vpoll
.ents:
        ld ix,ENTS
        ld b,NENT
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jp z,.n
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld (sd_x),hl
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        ld e,(ix+E_OFF)
        ld d,0
        or a
        sbc hl,de
        ld (sd_y),hl
        ld a,(ix+E_FACE)
        ld (sd_face),a
        ld a,(ix+E_TYPE)
        cp O_BUG
        jp z,.n
        cp O_SPARK
        jr z,.spark
        cp O_GOAL
        jr z,.jar
        cp O_MAGPIE
        jr z,.mag
        cp O_GOANNA
        jr z,.goa
        ; toad
        ld c,BGREEN
        ld a,(ix+E_STATE)
        ld b,SF_TOAD_SIT
        or a
        jr z,.go
        ld b,SF_TOAD_HOP
        dec a
        jr z,.go
        ld b,SF_TOAD_EEK
        dec a
        jr z,.go
        ld b,SF_TOAD_BACK0
        ld a,(ix+E_T)
        cp 50                   ; about to get up: kick harder
        jr nc,.slow
        add a,a
.slow:  and 16
        jr z,.go
        ld b,SF_TOAD_BACK1
        jr .go
.mag:   ld c,WHITE
        ld b,SF_MAG_DIVE
        ld a,(ix+E_STATE)
        cp 1
        jr z,.go
        ld b,SF_MAG_UP
        ld a,(gtick)
        and 4
        jr z,.go
        ld b,SF_MAG_DOWN
        jr .go
.goa:   ld c,GREY
        ld b,SF_GOAN2
        ld a,(ix+E_STATE)
        cp 2
        jr z,.go
        ld b,SF_GOAN0
        ld a,(ix+E_X)
        and 4
        jr z,.go
        ld b,SF_GOAN1
        jr .go
.jar:   ld c,BCYAN
        ld b,SF_JAR
        jr .go
.spark: ld c,YELLOW
        ld b,SF_SPARK0
        ld a,(ix+E_T)
        cp 7
        jr nc,.go
        ld b,SF_SPARK1
.go:    ld a,b
        ld (sd_frame),a
        ld a,(mono)
        or a
        jr z,.gc
        ld c,WHITE
.gc:    ld a,c
        ld (ds_col),a
        push ix
        call sprite
        call vpoll
        pop ix
.n:     pop bc
        ld de,E_SIZE
        add ix,de
        dec b
        jp nz, .l
        ret

hero_frame:
        ld a,(h_hurt)
        or a
        ld b,SF_HURT
        jr nz,.r
        ld a,(h_flare)
        or a
        jr z,.nf
        ld b,SF_FLARE0
        cp 4
        jr c,.r
        ld b,SF_FLARE1
        cp 8
        jr c,.r
        ld b,SF_FLARE2
        and 8
        jr z,.r
        ld b,SF_FLARE3
        jr .r
.nf:    ld a,(h_on)
        or a
        jr nz,.gnd
        ld a,(h_coy)
        or a
        jr nz,.gnd
        ld a,(h_glide)
        or a
        jr z,.air
        ld b,SF_GLIDE0
        ld a,(gtick)
        and 8
        jr z,.r
        ld b,SF_GLIDE1
        jr .r
.air:   ld b,SF_JUMP
        ld a,(hvy+1)
        bit 7,a
        jr nz,.r
        ld b,SF_FALL
        jr .r
.gnd:   ld a,(hvx+1)
        ld hl,hvx
        or (hl)
        jr z,.idle
        ld a,(h_spr)
        or a
        jr z,.walk
        ld a,(h_run)
        and 7
        add a,SF_SPR0
        ret
.walk:  ld a,(h_run)
        rrca
        and 7
        add a,SF_RUN0
        ret
.idle:  ld a,(gtick)
        rrca
        rrca
        rrca
        rrca
        and 7
        ld l,a
        ld h,0
        ld de,idleseq
        add hl,de
        ld a,(hl)
        ret
.r:     ld a,b
        ret
idleseq: db SF_IDLE0,SF_IDLE1,SF_IDLE1,SF_IDLE0,SF_IDLE3,SF_IDLE0,SF_IDLE2,SF_IDLE1
