; =====================================================================
;  GHOSTS: four minds of their own.
;   GRUMBLE  (red)     heads straight for the hunter; angrier as dots run out
;   SNEAKY   (green)   aims two nodes ahead of him to cut him off
;   DIZZY    (magenta) chases from afar, wanders off up close, turns on a whim
;   PEEKABOO (cyan)    comes round the other side, using GRUMBLE's position
;  They take turns to scatter to their corners and to chase; blue ghosts
;  run at random; eyes go home by the shortest way (the maze's home table).
; =====================================================================
FR_SPD  equ 13
EYE_SPD equ 48

ghosts_update:
        ld a,(p_x)
        ld hl,neartab
        call tab_a
        ld (pn_x),a
        ld a,(p_y)
        ld hl,neartab
        call tab_a
        ld (pn_y),a
        xor a
        ld (g_id),a
        ld ix,ghosts
.g:     call ghost_one
        ld de,GSZ
        add ix,de
        ld hl,g_id
        inc (hl)
        ld a,(hl)
        cp NG
        jr nz,.g
        ret

ghost_one:
        ld a,(ix+G_ST)
        or a
        jr z,.pen
        dec a
        jr z,.leave
        dec a
        jr z,.roam
        dec a
        jp z,.eyes
        ; going in through the door
        inc (ix+G_Y)
        inc (ix+G_Y)
        ld a,(ix+G_Y)
        cp PEN_Y
        ret c
        ld (ix+G_Y),PEN_Y
        ld (ix+G_ST),ST_PEN
        ld (ix+G_TMR),25
        ld (ix+G_FR),0
        ld a,SFX_HOME
        jp play_sfx
.pen:   ld a,(rtype)
        cp RT_PANIC
        ret z
        ld a,(ix+G_TMR)
        or a
        jr z,.rel
        dec (ix+G_TMR)
        ret
.rel:   ld (ix+G_ST),ST_LEAVE
        ret
.leave: ld a,(t_freeze)
        or a
        ret nz
        ld a,(ix+G_X)
        cp PEN_X
        jr z,.up
        jr c,.inc
        dec (ix+G_X)
        ret
.inc:   inc (ix+G_X)
        ret
.up:    dec (ix+G_Y)
        ld a,(ix+G_Y)
        cp DOOR_Y
        ret nz
        ld (ix+G_ST),ST_ROAM
        call random
        and 1
        ld (ix+G_DIR),a
        ld (ix+G_ACC),0
        ld a,(t_hunter)
        or a
        jr nz,.blue
        ld a,(rtype)
        cp RT_BUFFET
        ret nz
.blue:  ld (ix+G_FR),1
        ret
.roam:  ld a,(t_freeze)
        or a
        ret nz
        ld c,FR_SPD
        ld a,(ix+G_FR)
        or a
        jr nz,.sp
        ld a,(g_spd)
        ld c,a
        ld a,(g_id)
        or a
        jr nz,.sp
        ld hl,(dots_left)       ; GRUMBLE gets cross when few dots are left
        ld a,h
        or a
        jr nz,.sp
        ld a,l
        cp 30
        jr nc,.sp
        inc c
        inc c
        inc c
.sp:    ld a,(ix+G_X)           ; slow in the tunnels
        cp 12
        jr c,.half
        cp 157
        jr c,.run
.half:  srl c
        jr .run
.eyes:  ld c,EYE_SPD
.run:   ld a,(ix+G_ACC)
        add a,c
        ld c,a
        and 15
        ld (ix+G_ACC),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 15
        ret z
        ld b,a
.st:    push bc
        call ghost_step
        pop bc
        ld a,(ix+G_ST)
        cp ST_ENTER
        ret z
        djnz .st
        ret

; one unit along; at a node, decide where to go
ghost_step:
        ld d,(ix+G_X)
        ld e,(ix+G_Y)
        call node_at
        jr c,.move
        ld (g_node),a
        ld a,b
        ld (g_nx),a
        ld a,c
        ld (g_ny),a
        ld a,(ix+G_ST)
        cp ST_EYES
        jr nz,.ai
        ld a,(g_node)
        cp DOORNODE
        jr nz,.home
        ld (ix+G_ST),ST_ENTER
        ret
.home:  ld hl,home
        call tab_a
        cp 4
        jr nc,.ai
        ld (ix+G_DIR),a
        jr .move
.ai:    call ghost_choose
.move:  ld d,(ix+G_X)
        ld e,(ix+G_Y)
        ld a,(ix+G_DIR)
        call step_de
        ld (ix+G_X),d
        ld (ix+G_Y),e
        ret

ghost_choose:
        ld a,(g_node)
        ld hl,edges
        call tab_a
        ld c,a
        ld a,(ix+G_DIR)
        xor 1
        call dirbit
        cpl
        and c
        jr nz,.ex
        ld a,c                  ; nowhere but back
.ex:    ld (g_exits),a
        ld a,(ix+G_FR)
        or a
        jp nz,.random
        ld a,(g_id)
        cp 2
        jr nz,.aim
        call random             ; DIZZY: more whims as the rounds go by
        and 7
        ld b,a
        ld a,(lvl)
        srl a
        inc a
        cp b
        jr nc,.random
.aim:   call ghost_target
        ld a,255
        ld (g_best),a
        ld hl,try_order
        ld b,4
.t:     push bc
        push hl
        ld a,(hl)
        ld (t_k),a
        call dirbit
        ld b,a
        ld a,(g_exits)
        and b
        jr z,.nx
        ; the node that way
        ld a,(t_k)
        ld hl,dir_dx
        call tab_a
        ld b,a
        ld a,(g_nx)
        add a,b
        ld b,a
        ld a,(t_tx)
        sub b
        jp p,.ax
        neg
.ax:    cp 14
        jr c,.ax2
        ld a,13
.ax2:   ld hl,sqtab
        call tab_a
        ld c,a
        ld a,(t_k)
        ld hl,dir_dy
        call tab_a
        ld b,a
        ld a,(g_ny)
        add a,b
        ld b,a
        ld a,(t_ty)
        sub b
        jp p,.ay
        neg
.ay:    ld hl,sqtab
        call tab_a
        add a,c
        ld hl,g_best
        cp (hl)
        jr nc,.nx
        ld (hl),a
        ld a,(t_k)
        ld (g_bdir),a
.nx:    pop hl
        pop bc
        inc hl
        djnz .t
        ld a,(g_bdir)
        ld (ix+G_DIR),a
        ret
.random:
        call random
        and 3
.r:     ld b,a
        call dirbit
        ld c,a
        ld a,(g_exits)
        and c
        jr nz,.got
        ld a,b
        inc a
        and 3
        jr .r
.got:   ld (ix+G_DIR),b
        ret
try_order: db 2,1,3,0
dir_dx: db 1,-1,0,0
dir_dy: db 0,0,-1,1
sqtab:  db 0,1,4,9,16,25,36,49,64,81,100,121,144,169
corners: db 12,0, 0,0, 0,6, 12,6

; where is this ghost heading? -> t_tx, t_ty (a node)
ghost_target:
        ld a,(g_id)
        ld b,a
        ; scatter beats (GRUMBLE stops scattering once he is cross)
        ld a,(phase)
        and 1
        jr nz,.chase
        ld a,b
        or a
        jr nz,.corner
        ld hl,(dots_left)
        ld a,h
        or a
        jr nz,.corner
        ld a,l
        cp 30
        jr c,.chase
.corner:
        ld a,b
        add a,a
        ld hl,corners
        call tab_a
        ld (t_tx),a
        ld a,b
        add a,a
        inc a
        ld hl,corners
        call tab_a
        ld (t_ty),a
        ret
.chase: ld a,(pn_x)
        ld (t_tx),a
        ld a,(pn_y)
        ld (t_ty),a
        ld a,b
        or a
        ret z                   ; GRUMBLE: straight at him
        dec a
        jr z,.sneaky
        dec a
        jr z,.dizzy
        ; PEEKABOO: as far past the hunter as GRUMBLE is short of him
        ld a,(ghosts+G_X)
        ld hl,neartab
        call tab_a
        ld c,a
        ld a,(pn_x)
        add a,a
        sub c
        call .clampx
        ld (t_tx),a
        ld a,(ghosts+G_Y)
        ld hl,neartab
        call tab_a
        ld c,a
        ld a,(pn_y)
        add a,a
        sub c
        call .clampy
        ld (t_ty),a
        ret
.sneaky:
        ld a,(p_dir)
        ld hl,dir_dx
        call tab_a
        add a,a
        ld c,a
        ld a,(pn_x)
        add a,c
        call .clampx
        ld (t_tx),a
        ld a,(p_dir)
        ld hl,dir_dy
        call tab_a
        add a,a
        ld c,a
        ld a,(pn_y)
        add a,c
        call .clampy
        ld (t_ty),a
        ret
.dizzy: ; within three nodes he loses his nerve and heads for his corner
        ld a,(g_nx)
        ld c,a
        ld a,(pn_x)
        sub c
        jp p,.d1
        neg
.d1:    cp 4
        ret nc
        ld a,(g_ny)
        ld c,a
        ld a,(pn_y)
        sub c
        jp p,.d2
        neg
.d2:    cp 4
        ret nc
        jp .corner
.clampx:
        bit 7,a
        jr z,.cx
        xor a
        ret
.cx:    cp 13
        ret c
        ld a,12
        ret
.clampy:
        bit 7,a
        jr z,.cy
        xor a
        ret
.cy:    cp 7
        ret c
        ld a,6
        ret

; ---------------------------------------------------------------------
;  hunter meets ghost
; ---------------------------------------------------------------------
collide:
        ld ix,ghosts
        ld b,NG
.g:     push bc
        ld a,(ix+G_ST)
        cp ST_ROAM
        jr nz,.nx
        ld a,(p_x)
        sub (ix+G_X)
        jr nc,.ax
        neg
.ax:    cp 6
        jr nc,.nx
        ld a,(p_y)
        sub (ix+G_Y)
        jr nc,.ay
        neg
.ay:    cp 6
        jr nc,.nx
        ld a,(ix+G_FR)
        or a
        jr nz,.eat
        ld a,(t_freeze)
        or a
        jr nz,.nx
        ld a,(p_inv)
        or a
        jr nz,.nx
        call hurt
        jr .nx
.eat:   call eat_ghost
.nx:    pop bc
        ld de,GSZ
        add ix,de
        djnz .g
        ret

eat_ghost:
        ld (ix+G_ST),ST_EYES
        ld (ix+G_FR),0
        ld a,(ix+G_X)
        ld (pop_x),a
        ld d,a
        ld a,(ix+G_Y)
        ld (pop_y),a
        ld e,a
        ld c,BCYAN
        call burst
        ld a,22
        ld (pop_t),a
        ld a,SFX_EAT
        call play_sfx
        ld a,GS_HIT
        ld (gstate),a
        ld a,9
        ld (gtimer),a
        ld a,(t_hunter)
        or a
        jr z,.chain
        ld a,SF_N1000
        ld (pop_f),a
        ld de,$1000
        jp add_score
.chain: ld a,(rtype)
        cp RT_BUFFET
        jr nz,.norm
        ld a,SF_N400
        ld (pop_f),a
        ld de,$0400
        jp add_score
.norm:  ld a,(fr_chain)
        cp 4
        jr c,.c
        ld a,3
.c:     ld b,a
        add a,SF_N200
        ld (pop_f),a
        ld a,b
        ld hl,chain_val
        call tab_a
        ld d,a
        ld e,0
        call add_score
        ld hl,fr_chain
        inc (hl)
        ld a,(hl)
        cp 4
        ret nz
        ; all four on one energiser: the star appears
        ld a,(it_type)
        or a
        call nz,item_hide
        ld a,IT_STAR
        ld (it_type),a
        ld a,125
        ld (it_timer),a
        call item_show
        ld hl,s_perfect
        jp say
chain_val: db $02,$04,$08,$16
s_perfect: db "PERFECT! GRAB THE STAR!",0

; a ghost catches him: a heart goes (the ghost is sent packing), or the
; shield takes it; the last heart costs a life
hurt:   ld (ix+G_ST),ST_EYES
        ld (ix+G_FR),0
        ld a,(shield)
        or a
        jr z,.heart
        xor a
        ld (shield),a
        ld a,40
        ld (p_inv),a
        ld a,SFX_SHIELD
        call play_sfx
        ld hl,hud_dirty
        set 1,(hl)
        ld hl,s_pop
        jp say
.heart: ld a,(demo)
        or a
        jr nz,.safe
        ld hl,hearts
        dec (hl)
        jr z,.dead
.safe:  ld hl,hud_dirty
        set 1,(hl)
        ld a,62
        ld (p_inv),a
        ld a,SFX_HURT
        call play_sfx
        ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        ld c,BRED
        call burst
        ld hl,s_ouch
        jp say
.dead:  ld hl,hud_dirty
        set 1,(hl)
        ld (ix+G_ST),ST_ROAM
        ld a,GS_DYING
        ld (gstate),a
        ld a,62
        ld (gtimer),a
        xor a
        ld (tune),a
        call stop_music
        ld hl,mus_death_0
        ld de,mus_death_1
        jp play_music
s_pop:  db "SHIELD POPPED!",0
s_ouch: db "OUCH! MIND YOUR HEARTS",0

; ---------------------------------------------------------------------
;  drawing
; ---------------------------------------------------------------------
gcols:  db BRED,BGREEN,BMAGENTA,BCYAN

draw_ghosts:
        ld a,(gstate)
        cp GS_DYING
        jr nz,.go
        ld a,(gtimer)
        cp 44
        ret c                   ; they slip away while he falls
.go:    xor a
        ld (t_n),a
        ld ix,ghosts
.g:     call draw_ghost
        ld de,GSZ
        add ix,de
        ld hl,t_n
        inc (hl)
        ld a,(hl)
        cp NG
        jr nz,.g
        ret

draw_ghost:
        xor a
        ld (a_ox),a
        ld (a_oy),a
        ld d,(ix+G_X)
        ld e,(ix+G_Y)
        ld a,(ix+G_ST)
        cp ST_EYES
        jr c,.body
        ld a,(ix+G_DIR)
        add a,SF_EYES_R
        ld c,WHITE
        jp put_actor
.body:
.nb:    ld a,(gtick)
        rrca
        rrca
        rrca
        and 1
        ld b,a                  ; skirt frame
        ld a,(ix+G_FR)
        or a
        jr z,.norm
        ld a,b
        add a,SF_FR0
        ld b,a
        ld c,BBLUE
        ld a,(t_hunter)
        or a
        jr z,.nh
        ld a,(gtick)
        rrca
        and 3
        ld hl,hunt_col
        call tab_a
        ld c,a
        jr .put
.nh:    ld a,(fr_time)
        or a
        jr z,.put
        cp 25
        jr nc,.put
        ld a,(gtick)
        and 4
        jr z,.put
        ld c,WHITE              ; nearly over: they flash
.put:   ld a,b
        jp put_actor
.norm:  ld a,(t_n)
        ld hl,gcols
        call tab_a
        ld c,a
        ld a,(t_freeze)
        or a
        jr z,.nf
        ld c,WHITE
        ld a,(gtick)
        and 2
        jr z,.nf
        ld (a_ox),a             ; shivering
        ld c,BCYAN
.nf:    ld a,(ix+G_DIR)
        add a,a
        add a,b
        ld b,a
        ld a,(t_n)
        add a,a
        add a,a
        add a,a
        add a,b
        add a,SF_G0R0
        jp put_actor

; ---------------------------------------------------------------------
;  the demo's hunter: at a node (B = node x, C = node y) look down each lane:
;  dots are good, a ghost within two nodes is bad, turning back is dull
; ---------------------------------------------------------------------
demo_ai:
        ld a,b
        ld (g_nx),a
        ld a,c
        ld (g_ny),a
        add a,a
        add a,c
        add a,a
        add a,a
        add a,c
        add a,b
        ld hl,edges
        call tab_a
        ld (g_exits),a
        xor a
        ld (g_best),a
        ld a,(p_dir)
        ld (g_bdir),a
        xor a
        ld (t_k),a
.d:     ld a,(t_k)
        call dirbit
        ld b,a
        ld a,(g_exits)
        and b
        jp z,.nx
        call random
        and 7
        add a,60
        ld (t_c),a              ; this lane's score
        ; a dot one step down the lane?
        ld a,(p_x)
        ld d,a
        ld a,(p_y)
        ld e,a
        ld b,4
.s4:    push bc
        ld a,(t_k)
        call step_de
        pop bc
        djnz .s4
        ld a,d
        cp 12
        jr c,.nd
        cp 157
        jr nc,.nd
        rrca
        rrca
        and $3F
        dec a
        ld b,a
        ld a,e
        rrca
        rrca
        and $3F
        dec a
        ld l,a
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
        jr z,.nd
        ld a,(t_c)
        add a,30
        ld (t_c),a
.nd:    ld a,(p_dir)            ; turning back is dull
        xor 1
        ld b,a
        ld a,(t_k)
        cp b
        jr nz,.gh
        ld a,(t_c)
        sub 12
        ld (t_c),a
.gh:    ; ghosts down that lane
        ld a,(t_k)
        ld hl,dir_dx
        call tab_a
        ld (t_tx),a
        ld a,(t_k)
        ld hl,dir_dy
        call tab_a
        ld (t_ty),a
        ld ix,ghosts
        ld b,NG
.g:     push bc
        ld a,(ix+G_ST)
        cp ST_ROAM
        jr nz,.gn
        ld a,(ix+G_X)
        ld hl,neartab
        call tab_a
        ld d,a
        ld a,(ix+G_Y)
        ld hl,neartab
        call tab_a
        ld e,a
        ; is the ghost's node 1 or 2 nodes down this lane (or right here)?
        ld a,(g_nx)
        ld h,a
        ld a,(g_ny)
        ld l,a
        ld b,3
.k:     ld a,h
        cp d
        jr nz,.kn
        ld a,l
        cp e
        jr nz,.kn
        ld a,(ix+G_FR)
        or a
        ld a,(t_c)
        jr z,.bad
        add a,40                ; a blue ghost: go and get it
        jr .ks
.bad:   sub 60
        jr nc,.ks
        xor a
.ks:    ld (t_c),a
        jr .gn
.kn:    ld a,(t_tx)
        add a,h
        ld h,a
        ld a,(t_ty)
        add a,l
        ld l,a
        djnz .k
.gn:    pop bc
        ld de,GSZ
        add ix,de
        djnz .g
        ld a,(t_c)
        ld hl,g_best
        cp (hl)
        jr c,.nx
        ld (hl),a
        ld a,(t_k)
        ld (g_bdir),a
.nx:    ld hl,t_k
        inc (hl)
        ld a,(hl)
        cp 4
        jp nz,.d
        ld a,(g_bdir)
        ld (p_want),a
        ret
