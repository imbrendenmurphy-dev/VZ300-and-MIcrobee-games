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
title:
        ld a,$0F
        call cls
        ld hl,t_name
        ld de,$050E
        ld c,YELLOW
        call print
        ld hl,t_l1
        ld de,$0808
        ld c,WHITE
        call print
        ld hl,t_l2
        ld de,$0A09
        ld c,WHITE
        call print
        ld hl,t_l3
        ld de,$0F0B
        ld c,BCYAN
        call print
        ld hl,t_l4
        ld de,$110B
        ld c,BCYAN
        call print
        ld hl,t_l5
        ld de,$160B
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
        jp game_start

t_name: db "FRILLSEEKER",0
t_l1:   db "AN ENGINE PROTOTYPE FOR",0
t_l2:   db "THE MICROBEE PREMIUM PLUS",0
t_l3:   db "C - COLOUR MONITOR",0
t_l4:   db "M - MONO MONITOR",0
t_l5:   db "VIBED BY BPM 2026",0

; ---------------------------------------------------------------------
game_start:
        ld a,3
        ld (hearts),a
        xor a
        ld (bugs),a
        ld hl,collected
        ld b,8
.c:     ld (hl),0
        inc hl
        djnz .c
        ld a,1
        ld (want_start),a
        ld (mus_on),a
        ld hl,tune
        ld (mus_ptr),hl
        xor a
        call enter_room

main_loop:
        call read_input
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
        ld de,WALKV+1
        or a
        sbc hl,de
        add hl,de
        jr c,.sx
        ld hl,WALKV
        jr .sx
.left:  ld a,1
        ld (h_face),a
        ld hl,(hvx)
        ld de,-ACC
        add hl,de
        bit 7,h
        jr z,.sx
        ld de,WALKV
        add hl,de
        bit 7,h
        jr z,.lok
        ld hl,0
.lok:   ld de,-WALKV
        add hl,de
.sx:    ld (hvx),hl
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
        ; ---- fell out of the world, or into the billabong
        ld hl,(hy)
        ld a,h
        or a
        jr nz,.chkpit
        ld a,l
        cp 176
        jr nc,.pit
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
.chkpit:
        bit 7,h
        jr z,.pit
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
        cp T_ONEWAY
        jr nz,.fno
        ld a,(h_drop)
        or a
        jr nz,.fno
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
        ; out of hearts: the prototype just starts you again
        ld (hl),3
        ld a,1
        ld (want_start),a
        xor a
        ld (newroom),a
        ret

hero_fell:
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
        cp O_TOAD
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
        ld a,(h_run)
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
