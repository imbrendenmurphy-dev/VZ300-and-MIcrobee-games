; ---------------------------------------------------------------------------
; MERIDIAN's robots.  Up to four per room, each with one spark.
; Kinds: 0 patrol, 1 zapper (patrols, zaps at close range), 2 hunter (runs at
; Wren when he's on its floor), 3 sentry (stands, turns, zaps).
; A zap is a short electric bolt: a robot only fires when Wren is close in front
; of it (ZAP_REACH), and the bolt dies after ZAP_LIFE ticks, like a discharge, not
; a bullet across the room.
; Positions are in half-pixels like Wren's; a robot is 24 x 20.
; ---------------------------------------------------------------------------
MAXROB  equ 4
RB_KIND equ 0
RB_FLOOR equ 1
RB_LO   equ 2
RB_HI   equ 3
RB_X    equ 4
RB_DIR  equ 5
RB_SPD  equ 6
RB_ANIM equ 7
RB_COOL equ 8
RB_TURN equ 9
RB_X0   equ 10
RB_DIR0 equ 11
RB_RCX  equ 12
RB_RCY0 equ 13
RB_RCY1 equ 14
RB_DRAWN equ 15
SP_ON   equ 16
SP_X    equ 17
SP_Y    equ 18
SP_DIR  equ 19
SP_RCX  equ 20
SP_RCY0 equ 21
SP_RCY1 equ 22
SP_DRAWN equ 23
SP_LIFE equ 24
RB_SIZE equ 25
ZAP_REACH equ 44                ; half-pixels (~11 cells) in front
ZAP_LIFE  equ 10                ; ticks (3 half-pixels a tick: ~7 cells)
SLEEP_FRAMES equ 1000           ; 20 seconds

; Robots from the room record in STAGE.
robots_init:
        ld hl,robots
        ld de,robots+1
        ld bc,MAXROB*RB_SIZE-1
        ld (hl),0
        ldir
        ld hl,(STAGE+8)
        ld de,STAGE
        add hl,de
        ld a,(hl)
        cp MAXROB+1
        jr c,.n
        ld a,MAXROB
.n:     ld (nrob),a
        or a
        ret z
        ld b,a
        inc hl
        ld ix,robots
.r:     ld a,(hl)
        ld (ix+RB_KIND),a
        inc hl
        ld a,(hl)
        ld (ix+RB_FLOOR),a
        inc hl
        ld a,(hl)
        ld (ix+RB_LO),a
        inc hl
        ld a,(hl)
        ld (ix+RB_HI),a
        inc hl
        ld a,(hl)
        ld (ix+RB_X0),a
        inc hl
        ld a,(hl)
        ld (ix+RB_SPD),a
        inc hl
        ld a,(ix+RB_LO)         ; start facing the far end
        add a,(ix+RB_HI)
        rra
        cp (ix+RB_X0)
        ld a,0
        jr nc,.d
        inc a
.d:     ld (ix+RB_DIR0),a
        ld de,RB_SIZE
        add ix,de
        djnz .r
        jp robots_reset

; Back to where they started (after a death or on entry).
robots_reset:
        ld a,(nrob)
        or a
        ret z
        ld b,a
        ld ix,robots
.r:     ld a,(ix+RB_X0)
        ld (ix+RB_X),a
        ld a,(ix+RB_DIR0)
        ld (ix+RB_DIR),a
        ld (ix+SP_ON),0
        ld (ix+RB_COOL),40
        ld (ix+RB_TURN),100
        ld a,(ix+RB_KIND)       ; hazards start quiet, staggered by their phase
        cp 4
        jr c,.n
        ld (ix+RB_DIR),0
        ld a,(ix+RB_SPD)
        add a,20
        ld (ix+RB_TURN),a
.n:
        ld de,RB_SIZE
        add ix,de
        djnz .r
        ret

; Which floor row Wren stands on (for the robots' eyes), or $FF.
wren_floor_row:
        ld a,(wstate)
        cp WS_GROUND
        jr z,.on
        cp WS_SEARCH
        jr z,.on
        cp WS_LAND
        jr z,.on
        cp WS_TERM
        jr z,.on
        ld a,$FF
        ret
.on:    call on_floor
        ld a,$FF
        ret nc
        ld a,b
        ret

robots_update:
        ld a,(grace)
        or a
        jr z,.ng
        dec a
        ld (grace),a
        ret
.ng:    ld hl,(sleep_t)
        ld a,h
        or l
        jr z,.awake
        dec hl
        ld (sleep_t),hl
        ld a,h
        or l
        ret nz
        ld hl,str_waking
        jp msg_show
.awake: ld a,(wstate)
        cp WS_DEAD
        ret z
        call wren_floor_row
        ld (seen_row),a
        ld a,(nrob)
        or a
        ret z
        ld b,a
        ld ix,robots
.r:     push bc
        call robot_think
        call spark_move
        ld de,RB_SIZE
        add ix,de
        pop bc
        djnz .r
        ret

robot_think:
        ld a,(ix+RB_KIND)       ; timed hazards: RB_DIR = firing, RB_TURN counts down
        cp 4
        jr c,.bot
        dec (ix+RB_TURN)
        ret nz
        ld a,(ix+RB_DIR)
        xor 1
        ld (ix+RB_DIR),a
        ld b,50                 ; vent: 1 s of steam, 2 s quiet
        ld c,100
        ld a,(ix+RB_KIND)
        cp 4
        jr z,.ht
        ld b,100                ; laser: 2 s on, 1.5 s off
        ld c,75
.ht:    ld a,(ix+RB_DIR)
        or a
        ld a,b
        jr nz,.hs
        ld a,c
.hs:    ld (ix+RB_TURN),a
        ret
.bot:   ld a,(ix+RB_COOL)
        or a
        jr z,$+5
        dec (ix+RB_COOL)
        ld a,(seen_row)
        cp (ix+RB_FLOOR)
        ld a,0
        jr nz,.ns
        inc a
.ns:    ld (sees),a
        ld a,(ix+RB_KIND)
        cp 3
        jr z,.sentry
        cp 2
        jr z,.hunter
        call .patrol
        ld a,(ix+RB_KIND)
        cp 1
        ret nz
        jp robot_fire
.sentry:
        dec (ix+RB_TURN)
        jr nz,.sf
        ld (ix+RB_TURN),100
        ld a,(ix+RB_DIR)
        xor 1
        ld (ix+RB_DIR),a
.sf:    jp robot_fire
.hunter:
        ld a,(hunt_off)         ; Story: hunters just patrol
        or a
        jr nz,.patrol
        ld a,(sees)
        or a
        jr z,.patrol
        ld a,(wx)               ; turn towards Wren and run
        cp (ix+RB_X)
        ld a,0
        jr nc,.hd
        inc a
.hd:    ld (ix+RB_DIR),a
        ld a,(slow_hunt)        ; as fast as Wren runs, no faster
        or a                    ; (Story: half that)
        jp z,.step
        ld a,(frames)
        and 1
        ret nz
        jp .step
.patrol:
        ld a,(slow_hunt)        ; Story: every robot at half speed
        or a
        jr nz,.half
        ld a,(ix+RB_SPD)
        cp 2
        jr nc,.step
        ld a,(fast_pat)         ; Ghost: the slow ones walk at full speed
        or a
        jr nz,.step
.half:  ld a,(frames)
        and 1
        ret nz
.step:  inc (ix+RB_ANIM)
        ld a,(ix+RB_DIR)
        or a
        ld a,(ix+RB_X)
        jr nz,.left
        cp (ix+RB_HI)
        jr nc,.turnl
        inc a
        ld (ix+RB_X),a
        ret
.turnl: ld (ix+RB_DIR),1
        ret
.left:  cp (ix+RB_LO)
        jr z,.turnr
        jr c,.turnr
        dec a
        ld (ix+RB_X),a
        ret
.turnr: ld (ix+RB_DIR),0
        ret

; Fire along the floor if Wren is on it, in front, and the gun has cooled.
robot_fire:
        ld a,(sees)
        or a
        ret z
        ld a,(ix+RB_COOL)
        or a
        ret nz
        ld a,(ix+SP_ON)
        or a
        ret nz
        ld a,(wx)               ; in front?
        cp (ix+RB_X)
        ld a,0
        jr nc,.f
        inc a
.f:     cp (ix+RB_DIR)
        ret nz
        ld a,(wx)               ; and close?
        sub (ix+RB_X)
        jr nc,.ab
        neg
.ab:    cp ZAP_REACH
        ret nc
        ld (ix+SP_LIFE),ZAP_LIFE
        ld (ix+SP_ON),1
        ld a,(ix+RB_DIR)
        ld (ix+SP_DIR),a
        ld a,(ix+RB_X)
        or a
        jr nz,.x
        inc a
.x:     ld (ix+SP_X),a
        ld a,(ix+RB_FLOOR)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a                 ; floor * 12
        sub 11
        ld (ix+SP_Y),a
        ld a,(gun_cool)
        ld (ix+RB_COOL),a
        jp sfx_zap

spark_move:
        ld a,(ix+SP_ON)
        or a
        ret z
        dec (ix+SP_LIFE)        ; a discharge, not a bullet: it fizzles out
        jr z,.off
        ld a,(slow_hunt)        ; Story: slower shots
        ld c,3
        or a
        jr z,.sp
        dec c
.sp:    ld a,(ix+SP_DIR)
        or a
        ld a,(ix+SP_X)
        jr nz,.l
        add a,c
        cp 151
        jr nc,.off
        ld (ix+SP_X),a
        ret
.l:     sub c
        jr c,.off
        cp 2
        jr c,.off
        ld (ix+SP_X),a
        ret
.off:   ld (ix+SP_ON),0
        ret

; ------------------------------------------------------------ draw / erase
robots_erase:
        ld a,(nrob)
        or a
        ret z
        ld b,a
        ld ix,robots
.r:     push bc
        ld a,(ix+RB_DRAWN)
        or a
        jr z,.s
        ld (ix+RB_DRAWN),0
        ld b,(ix+RB_RCY0)
        ld c,(ix+RB_RCY1)
        ld a,(ix+RB_RCX)
        call erase_rect
.s:     ld a,(ix+SP_DRAWN)
        or a
        jr z,.n
        ld (ix+SP_DRAWN),0
        ld b,(ix+SP_RCY0)
        ld c,(ix+SP_RCY1)
        ld a,(ix+SP_RCX)
        call erase_rect
.n:     ld de,RB_SIZE
        add ix,de
        pop bc
        djnz .r
        ret

robots_draw:
        ld a,(nrob)
        or a
        ret z
        ld b,a
        ld ix,robots
.r:     push bc
        ld a,(ix+RB_X)
        ld (d_x),a
        ld a,(ix+RB_FLOOR)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        sub 20
        ld (d_y),a
        ld a,20
        ld (d_h),a
        ld a,(ix+RB_DIR)
        ld (d_face),a
        ld hl,(sleep_t)
        ld a,h
        or l
        ld a,4                  ; asleep
        ld c,$0C
        jr nz,.fr
        ld a,(ix+RB_ANIM)
        rrca
        rrca
        and 3
        ld c,$09
.fr:    ld b,a
        ld a,c
        ld (d_ink),a
        ld a,b                  ; robot_vt + frame * 3
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,robot_vt
        add hl,de
        ld (d_vt),hl
        call spr_rect
        ld a,(d_rcx)
        ld (ix+RB_RCX),a
        ld a,(d_rcy0)
        ld (ix+RB_RCY0),a
        ld a,(d_rcy1)
        ld (ix+RB_RCY1),a
        ld (ix+RB_DRAWN),1
        call spr_draw
        ld a,(ix+SP_ON)
        or a
        jr z,.n
        ld a,(ix+SP_X)
        ld (d_x),a
        ld a,(ix+SP_Y)
        ld (d_y),a
        ld a,6
        ld (d_h),a
        ld a,(ix+SP_DIR)
        ld (d_face),a
        ld a,$0B
        ld (d_ink),a
        ld a,(frames)
        and 1
        ld hl,spark_vt
        jr z,.sg
        ld hl,spark_vt+3
.sg:    ld (d_vt),hl
        call spr_rect
        ld a,(d_rcx)
        ld (ix+SP_RCX),a
        ld a,(d_rcy0)
        ld (ix+SP_RCY0),a
        ld a,(d_rcy1)
        ld (ix+SP_RCY1),a
        ld (ix+SP_DRAWN),1
        call spr_draw
.n:     ld de,RB_SIZE
        add ix,de
        pop bc
        dec b
        jp nz,.r
        ret

; ------------------------------------------------------------ collisions
; Wren's body box (x in half-pixels, y in pixels) against every awake robot
; and every spark.  A hit starts the death.
robots_hit:
        ld a,(grace)
        or a
        ret nz
        ld a,(wstate)
        cp WS_DEAD
        ret z
        ld hl,(sleep_t)
        ld a,h
        or l
        ld (asleep),a
        ld a,(wx)               ; Wren's box
        ld b,a
        ld a,(wy)
        ld c,a
        ld a,(wstate)
        cp WS_VAULT
        jr nz,.body
        ld a,(wtim)
        cp VAULT_PREP
        jr c,.body
        ld a,b                  ; tucked in the air: a ball
        add a,2
        ld (hx0),a
        add a,7
        ld (hx1),a
        ld a,c
        add a,6
        ld (hy0),a
        add a,12
        ld (hy1),a
        jr .test
.body:  ld a,b
        add a,3
        ld (hx0),a
        add a,5
        ld (hx1),a
        ld a,c
        add a,2
        ld (hy0),a
        add a,21
        ld (hy1),a
.test:  ld a,(nrob)
        or a
        ret z
        ld b,a
        ld ix,robots
.r:     push bc
        ld a,(ix+RB_KIND)
        cp 4
        jr c,.rb
        ld a,(ix+RB_DIR)        ; a hazard: only while it fires
        or a
        jr z,.n
        ld a,(ix+RB_KIND)
        ld e,4                  ; steam: x+2..x+9 ; laser: x+5..x+6
        ld d,2
        cp 4
        jr z,.hz
        ld d,5
        ld e,1
.hz:    ld a,(ix+RB_X)
        add a,d
        ld d,a
        add a,e
        add a,e
        ld e,a
        ld a,(ix+RB_FLOOR)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        sub 22
        ld b,a
        add a,21
        ld c,a
        call overlap
        jr c,.hit
        jr .n
.rb:    ld a,(asleep)
        or a
        jr nz,.sp
        ld a,(hb_trim)          ; robot box (trimmed on the easier levels)
        ld e,a
        ld a,(ix+RB_X)
        inc a
        add a,e
        ld d,a
        ld a,9
        sub e
        sub e
        add a,d
        ld e,a
        ld a,(ix+RB_FLOOR)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        sub 19
        ld b,a
        add a,18
        ld c,a
        call overlap
        jr c,.hit
.sp:    ld a,(ix+SP_ON)
        or a
        jr z,.n
        ld a,(ix+SP_X)
        inc a
        ld d,a
        add a,6
        ld e,a
        ld a,(ix+SP_Y)
        inc a
        ld b,a
        add a,3
        ld c,a
        call overlap
        jr c,.hit
.n:     ld de,RB_SIZE
        add ix,de
        pop bc
        dec b
        jp nz,.r
        ret
.hit:   pop bc
        ld hl,str_caught
        call msg_show
        jp start_death

; Carry if [D..E] x [B..C] overlaps Wren's box.
overlap:
        ld a,(hx1)
        cp d
        jr c,.no                ; Wren entirely left
        ld a,e
        ld hl,hx0
        cp (hl)
        jr c,.no                ; robot entirely left
        ld a,(hy1)
        cp b
        jr c,.no
        ld a,c
        ld hl,hy0
        cp (hl)
        jr c,.no
        scf
        ret
.no:    or a
        ret

str_caught: db "ZAPPED",0
str_waking: db "ROBOTS WAKE",0
