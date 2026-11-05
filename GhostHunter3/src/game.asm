; =====================================================================
;  GHOST HUNTER 2 - gameplay
; =====================================================================
XOFF    equ 0                   ; actors, particles and popups live in map pixels
YOFF    equ 0
A_X     equ 0
A_Y     equ 1
A_DIR   equ 2
A_NEXT  equ 3
A_FRAC  equ 4
A_SPD   equ 5
A_ST    equ 6
A_ANIM  equ 7
A_ID    equ 8
A_TIM   equ 9
A_CX    equ 10
A_CY    equ 11
A_TX    equ 12
A_TY    equ 13
A_FLG   equ 14
A_SPR   equ 15
ST_HOUSE equ 0
ST_EXIT  equ 1
ST_ACT   equ 2
ST_FRT   equ 3
ST_EYES  equ 4
ST_ENTER equ 5
PLAYER  equ actors
GHOST1  equ actors+16
DOORX   equ 78                  ; px of column 13 (the house is always centred)

; popup string indices
P_100 equ 0
P_200 equ 1
P_300 equ 2
P_400 equ 3
P_500 equ 4
P_700 equ 5
P_800 equ 6
P_1000 equ 7
P_1600 equ 8
P_2000 equ 9
P_3200 equ 10
P_5000 equ 11
P_X2 equ 12
P_SPEED equ 13
P_FREEZE equ 14
P_DECOY equ 15
P_SHIELD equ 16
P_HUNT equ 17
P_PERFECT equ 18
P_STREAK equ 19
P_POP equ 20
P_250 equ 21
P_50 equ 22

popstr: dw s100,s200,s300,s400,s500,s700,s800,s1000,s1600,s2000,s3200,s5000
        dw sx2,sspeed,sfreeze,sdecoy,sshield,shunt,sperfect,sstreak,spop,s250,s50
        dw sboo,seek,szzz,swow
popval: dw $0100,$0200,$0300,$0400,$0500,$0700,$0800,$1000,$1600,$2000,$3200,$5000
s100: db "100",0
s200: db "200",0
s300: db "300",0
s400: db "400",0
s500: db "500",0
s700: db "700",0
s800: db "800",0
s1000: db "1000",0
s1600: db "1600",0
s2000: db "2000",0
s3200: db "3200",0
s5000: db "5000",0
sx2: db "X2!",0
sspeed: db "ZOOM!",0
sfreeze: db "BRRR!",0
sdecoy: db "DECOY",0
sshield: db "SHIELD",0
shunt: db "HUNT!",0
sperfect: db "PERFECT",0
sstreak: db "STREAK",0
spop: db "POP!",0
s250: db "250",0
s50: db "50",0
sboo: db "BOO!",0
seek: db "EEK!",0
szzz: db "ZZZ",0
swow: db "WOW!",0

dxtab:  db 1,-1,0,0
dytab:  db 0,0,-1,1

; ---------------------------------------------------------------------
; grid helpers
; cell_at: B = cx (may be -1/27 -> wraps), C = cy -> A = code, HL = addr
cell_at:
        ld a,(maph)
        dec a
        cp c
        jr nc,.cy
        ld a,3                  ; outside vertically = wall
        ret
.cy:    ld a,b
        cp MAPW
        jr c,.cx
        cp $F0
        ld a,0
        jr c,.cx2               ; 27+ -> 0
        ld a,MAPW-1             ; negative -> 26
.cx2:   ld b,a
.cx:    call cell_addr
        push de
        ld e,(hl)
        ld d,codetab>>8
        ld a,(de)
        pop de
        ret

; neighbour: B,C cell, A = dir -> B,C = neighbour, A = code
neighbour:
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
        call cell_at
        pop hl
        ret

; passable code? A -> carry set if passable
passable:
        cp 3
        ret c
        cp 6
        ccf
        ret

; is_aligned: IX -> Z if centred on a cell, B = cx, C = cy
is_aligned:
        ld e,(ix+A_X)
        ld d,0
        ld hl,div6
        add hl,de
        ld b,(hl)
        ld a,b
        add a,a
        add a,b
        add a,a                 ; 6*cx
        sub e
        ret nz                  ; not on a column
        ld e,(ix+A_Y)
        ld hl,div5
        add hl,de
        ld c,(hl)
        ld a,c
        add a,a
        add a,a
        add a,c                 ; 5*cy
        sub e
        ret

; nearest cell of an actor -> B,C
actor_cell:
        ld a,(ix+A_X)
        add a,3
        ld e,a
        ld d,0
        ld hl,div6
        add hl,de
        ld b,(hl)
        ld a,b
        cp MAPW
        jr c,.a1
        ld b,0
.a1:    ld a,(ix+A_Y)
        add a,2
        ld e,a
        ld hl,div5
        add hl,de
        ld c,(hl)
        ret

; ---------------------------------------------------------------------
; move_actor: IX, A = speed (0..255 = px/frame*256)
move_actor:
        ld b,a
        ld a,(ix+A_DIR)
        cp 2
        ld a,b
        jr c,.h
        ld e,a
        ld d,0
        ld hl,mul23
        add hl,de
        ld a,(hl)
.h:     add a,(ix+A_FRAC)
        ld (ix+A_FRAC),a
        ret nc
; one pixel step
one_step:
        call is_aligned
        jr nz,.mid
        ld (ix+A_CX),b
        ld (ix+A_CY),c
        ld a,(ix+A_ID)
        or a
        jr nz,.gh
        push bc
        call player_arrive
        pop bc
        ret c
        call player_choose
        ret c
        jr .go
.gh:    call ghost_choose
        ret c
        jr .go
.mid:   ld a,(ix+A_ID)
        or a
        jr nz,.go
        ; player may reverse mid-cell
        ld a,(ix+A_NEXT)
        cp $FF
        jr z,.go
        ld b,a
        ld a,(ix+A_DIR)
        xor 1
        cp b
        jr nz,.go
        ld (ix+A_DIR),a
.go:    res 0,(ix+A_FLG)        ; moving
        ld a,(ix+A_DIR)
        ld e,a
        ld d,0
        ld hl,dxtab
        add hl,de
        ld a,(ix+A_X)
        add a,(hl)
        cp MAPWPX
        jr nz,.w1
        xor a
.w1:    cp $FF
        jr nz,.w2
        ld a,MAPWPX-1
.w2:    ld (ix+A_X),a
        ld hl,dytab
        add hl,de
        ld a,(ix+A_Y)
        add a,(hl)
        ld (ix+A_Y),a
        inc (ix+A_ANIM)
        ret

; ---------------------------------------------------------------------
; PLAYER
player_choose:
        ld a,(demo)
        ld hl,autoplay
        or (hl)
        call nz,demo_ai
        ld a,(ix+A_NEXT)
        cp $FF
        jr z,.keep
        push bc
        call neighbour
        call passable
        pop bc
        jr nc,.keep
        ld a,(ix+A_NEXT)
        ld (ix+A_DIR),a
        or a
        ret
.keep:  ld a,(ix+A_DIR)
        push bc
        call neighbour
        call passable
        pop bc
        ccf
        ret nc
        set 0,(ix+A_FLG)        ; stopped
        scf
        ret

; arrival at a cell centre: B,C = cell. returns carry if teleported
player_arrive:
        ld a,b
        cp (ix+A_TX)
        jr nz,.new
        ld a,c
        cp (ix+A_TY)
        jr nz,.new
        or a
        ret
.new:   ld (ix+A_TX),b
        ld (ix+A_TY),c
        call cell_at
        cp 1
        jp z,eat_pellet
        cp 2
        jp z,eat_energiser
        cp 6
        jp z,teleport
        or a
        ret

eat_pellet:
        ld (hl),0
        call erase_pellet
        ld de,$0010
        call add_score
        call pellet_count
        ; streak
        ld a,(streaktim)
        or a
        jr z,.s0
        ld a,(streak)
        inc a
        ld (streak),a
        cp 30
        jr nz,.s1
        xor a
        ld (streak),a
        ld de,$0500
        call add_score
        ld a,P_STREAK
        call popup_at_player
        jr .s1
.s0:    xor a
        ld (streak),a
.s1:    ld a,40
        ld (streaktim),a
        ld a,(wakaflip)
        xor 1
        ld (wakaflip),a
        call play_sfx
        or a
        ret

eat_energiser:
        ld (hl),0
        call erase_pellet
        ld de,$0050
        call add_score
        call pellet_count
        push ix                 ; (frighten_all walks IX over the ghosts)
        call frighten_all
        pop ix
        ld a,SFX_POWER
        call play_sfx
        or a
        ret

pellet_count:
        ld hl,(pellets)
        dec hl
        ld (pellets),hl
        ld hl,(eaten)
        inc hl
        ld (eaten),hl
        ret

; erase pellet graphics at cell B,C (the grid already says empty)
erase_pellet:
        push ix
        push bc
        push de
        ld a,1                  ; rows 1..3 of the cell (pellet row 2, power pill 1..3)
        ld e,3
        call regen_rows
        pop de
        pop bc
        pop ix
        ret

; cell_pix: B,C -> D = pixel x, E = pixel y
cell_pix:
        ld a,b
        add a,a
        add a,b
        add a,a                 ; *6
        add a,XOFF
        ld d,a
        ld a,c
        add a,a
        add a,a
        add a,c                 ; *5
        add a,YOFF
        ld e,a
        ret

teleport:
        ; find partner teleporter: list tele_list of up to 4 (cx,cy); partner = index xor 3
        ld hl,tele_list
        ld e,0
.f:     ld a,(hl)
        cp b
        jr nz,.n
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr z,.found
.n:     inc hl
        inc hl
        inc e
        ld a,(ntele)
        cp e
        jr nz,.f
        or a
        ret
.found: push de
        ld a,1
        ld (swoopreq),a
        ld a,(ix+A_X)
        add a,XOFF+3
        ld b,a
        ld a,(ix+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,1
        call burst
        pop de
        ld a,(ntele)
        cp 2
        ld a,e
        jr nz,.x3
        xor 1
        jr .xp
.x3:    xor 3
.xp:    add a,a
        ld e,a
        ld d,0
        ld hl,tele_list
        add hl,de
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld (ix+A_TX),b          ; mark as already arrived
        ld (ix+A_TY),c
        call cell_pix
        ld a,d
        sub XOFF
        ld (ix+A_X),a
        ld a,e
        sub YOFF
        ld (ix+A_Y),a
        ld a,(ix+A_X)
        add a,XOFF
        ld b,a
        ld a,(ix+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,3
        call burst
        ld a,SFX_TELE
        call play_sfx
        scf
        ret

; ---------------------------------------------------------------------
; GHOSTS
ghost_choose:
        ld a,(ix+A_ST)
        cp ST_EYES
        jr nz,.ne
        ld a,b
        cp 13
        jr nz,.ne
        ld a,(exitcy)
        cp c
        jr nz,.ne
        ld (ix+A_ST),ST_ENTER
        scf
        ret
.ne:    ; pending reverse?
        bit 1,(ix+A_FLG)
        jr z,.nrev
        res 1,(ix+A_FLG)
        ld a,(ix+A_DIR)
        xor 1
        push bc
        call neighbour
        call passable
        pop bc
        jr nc,.nrev
        ld a,(ix+A_DIR)
        xor 1
        ld (ix+A_DIR),a
        or a
        ret
.nrev:  ld a,(ix+A_ST)
        cp ST_FRT
        jr z,.random
        ; DIZZY random turns
        ld a,(ix+A_ID)
        cp 3
        jr nz,.tgt
        call random
        ld hl,dizzy_chance
        cp (hl)
        jr c,.random
.tgt:   push bc
        call ghost_target       ; sets A_TX, A_TY
        pop bc
        ld a,$FF
        ld (best),a
        ld a,127
        ld (bestd),a
        ld hl,dirorder
        ld a,4
.dl:    push af
        ld a,(hl)
        inc hl
        push hl
        ld d,a
        ld a,(ix+A_DIR)
        xor 1
        cp d
        jr z,.skip
        ld a,d
        push bc
        push de
        call neighbour
        call passable
        jr nc,.skip2
        ; distance |b-tx| + |c-ty|
        ld a,b
        sub (ix+A_TX)
        jp p,.p1
        neg
.p1:    ld e,a
        ld a,c
        sub (ix+A_TY)
        jp p,.p2
        neg
.p2:    add a,e
        ld hl,bestd
        cp (hl)
        jr nc,.skip2
        ld (hl),a
        pop de
        push de
        ld a,d
        ld (best),a
.skip2: pop de
        pop bc
.skip:  pop hl
        pop af
        dec a
        jr nz,.dl
        ld a,(best)
        cp $FF
        jr nz,.set
        ld a,(ix+A_DIR)
        xor 1
.set:   ld (ix+A_DIR),a
        or a
        ret
.random:
        call random
        and 3
        ld (best),a
        ld d,4
.r1:    push de
        ld a,(best)
        ld e,a
        ld a,(ix+A_DIR)
        xor 1
        cp e
        jr z,.r2
        ld a,e
        push bc
        call neighbour
        call passable
        pop bc
        jr c,.r3
.r2:    ld a,(best)
        inc a
        and 3
        ld (best),a
        pop de
        dec d
        jr nz,.r1
        ld a,(ix+A_DIR)
        xor 1
        ld (ix+A_DIR),a
        or a
        ret
.r3:    pop de
        ld a,(best)
        ld (ix+A_DIR),a
        or a
        ret

dirorder: db 2,1,3,0

; target selection
ghost_target:
        ld a,(ix+A_ST)
        cp ST_EYES
        jr nz,.n1
        ld (ix+A_TX),13
        ld a,(exitcy)
        ld (ix+A_TY),a
        ret
.n1:    ld a,(decoytim)
        or a
        jr z,.n2
        ld a,(decoycx)
        ld (ix+A_TX),a
        ld a,(decoycy)
        ld (ix+A_TY),a
        ret
.n2:    ld a,(ix+A_ID)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,scatter_t
        add hl,de
        ld a,(chasemode)
        or a
        jr nz,.chase
        ld a,(ix+A_ID)
        cp 1
        jr nz,.sc
        ld a,(elroy)            ; enraged GRUMBLE never scatters
        or a
        jr nz,.chase
.sc:    ld a,(hl)
        ld (ix+A_TX),a
        inc hl
        ld a,(hl)
        cp $80
        jr nz,.sc1
        ld a,(maph)
        add a,2
.sc1:   ld (ix+A_TY),a
        ret
.chase: push hl
        ; player cell
        push ix
        ld ix,PLAYER
        call actor_cell
        ld a,(ix+A_DIR)
        pop ix
        ld (pdir_),a
        pop hl
        ld a,(ix+A_ID)
        cp 1
        jr z,.direct
        cp 2
        jr z,.ahead
        cp 3
        jr z,.dizzy
        ; PEEKABOO: 2*(player+2ahead) - grumble
        ld a,2
        call ahead_n
        ld a,b
        add a,a
        ld b,a
        ld a,c
        add a,a
        ld c,a
        ld a,(GHOST1+A_CX)
        ld d,a
        ld a,b
        sub d
        ld (ix+A_TX),a
        ld a,(GHOST1+A_CY)
        ld d,a
        ld a,c
        sub d
        ld (ix+A_TY),a
        ret
.direct:
        ld (ix+A_TX),b
        ld (ix+A_TY),c
        ret
.ahead: ld a,3
        call ahead_n
        jr .direct
.dizzy: ; far: chase, near: scatter
        ld a,b
        sub (ix+A_CX)
        jp p,.d1
        neg
.d1:    ld e,a
        ld a,c
        sub (ix+A_CY)
        jp p,.d2
        neg
.d2:    add a,e
        cp 6
        jr nc,.direct
        jr .sc
; B,C += A * dir(pdir_)
ahead_n:
        ld d,a
        ld a,(pdir_)
        and 3
        ld e,a
        push de
        ld d,0
        ld hl,dxtab
        add hl,de
        ld a,(hl)
        ld hl,dytab
        add hl,de
        ld l,(hl)
        ld h,a
        pop de
.ax:    ld a,b
        add a,h
        ld b,a
        ld a,c
        add a,l
        ld c,a
        dec d
        jr nz,.ax
        ret

scatter_t: db MAPW+1,-3, -2,-3, -2,$80, MAPW+1,$80     ; $80 = below the maze

; ghost_update: IX
ghost_update:
        ld a,(ix+A_ST)
        cp ST_HOUSE
        jr z,.house
        cp ST_EXIT
        jr z,.exit
        cp ST_ENTER
        jp z,.enter
        ; moving states
        cp ST_EYES
        jr z,.eyes
        ld a,(freezetim)
        or a
        ret nz                  ; frozen solid
        call ghost_speed
        jp move_actor
.eyes:  ld a,230
        call move_actor
        ld a,(ix+A_ST)
        cp ST_EYES
        ret nz
        ld a,230
        jp move_actor
.house: ; bob
        inc (ix+A_ANIM)
        ld a,(ix+A_ANIM)
        and 15
        jr nz,.h1
        ld a,(ix+A_Y)
        xor 1
        ld (ix+A_Y),a
.h1:    ld a,(roundtype)
        cp 2
        ret z                   ; pellet panic: ghosts stay home asleep
        ld a,(ix+A_TIM)
        or a
        jr z,.go
        dec (ix+A_TIM)
        ret
.go:    ld (ix+A_ST),ST_EXIT
        ret
.exit:  inc (ix+A_ANIM)
        ld a,(ix+A_ANIM)
        and 1
        ret nz
        ld a,(ix+A_X)
        cp DOORX
        jr z,.up
        jr c,.right
        dec (ix+A_X)
        ld (ix+A_DIR),1
        ret
.right: inc (ix+A_X)
        ld (ix+A_DIR),0
        ret
.up:    ld (ix+A_DIR),2
        dec (ix+A_Y)
        ld a,(exity)
        cp (ix+A_Y)
        ret nz
        ld (ix+A_ST),ST_ACT
        ld a,(roundtype)
        cp 1
        jr z,.fr
        ld a,(supertim)
        or a
        jr z,.nf
.fr:    ld (ix+A_ST),ST_FRT
.nf:    ld (ix+A_DIR),1
        ld (ix+A_FRAC),0
        call random
        and 1
        ld (ix+A_DIR),a
        ret
.enter: ld (ix+A_DIR),3
        ld (ix+A_X),DOORX
        inc (ix+A_Y)
        ld a,(housey)
        cp (ix+A_Y)
        ret nz
        ld (ix+A_ST),ST_HOUSE
        ld (ix+A_TIM),20
        ret

; speed for a moving ghost -> A
ghost_speed:
        ld a,(ix+A_ST)
        cp ST_FRT
        jr nz,.n
        ld a,(fspeed)
        ret
.n:     ; tunnel slowdown
        ld a,(ix+A_CY)
        ld e,a
        ld d,0
        ld hl,tunrow
        add hl,de
        ld a,(hl)
        or a
        jr z,.nt
        ld a,(ix+A_CX)
        cp 4
        jr c,.tun
        cp MAPW-4
        jr c,.nt
.tun:   ld a,110
        ret
.nt:    ld a,(gspeed)
        ld b,a
        ld a,(ix+A_ID)
        cp 1
        ld a,b
        ret nz
        ld a,(elroy)
        or a
        ld a,b
        ret z
        add a,22
        ret nc
        ld a,255
        ret

; frighten all roaming ghosts
frighten_all:
        ld a,(roundtype)
        or a
        ret nz
        ld a,(frighttime)
        ld (frighttim),a
        ld (frightmax),a
        xor a
        ld (chain),a
        ld ix,GHOST1
        ld b,4
.l:     ld a,(ix+A_ST)
        cp ST_ACT
        jr z,.f
        cp ST_FRT
        jr nz,.n
.f:     ld (ix+A_ST),ST_FRT
        set 1,(ix+A_FLG)        ; reverse
.n:     ld de,16
        add ix,de
        djnz .l
        ; a quick CSS1 flash (the whole maze lights up), then the normal palette
        ld a,10
        ld (flashtim),a
        ret

unfrighten_all:
        ld ix,GHOST1
        ld b,4
.l:     ld a,(ix+A_ST)
        cp ST_FRT
        jr nz,.n
        ld (ix+A_ST),ST_ACT
.n:     ld de,16
        add ix,de
        djnz .l
        xor a
        ld (palbase),a
        ret

; ---------------------------------------------------------------------
; scoring
add_score:
        push de
        call .add
        pop de
        ld a,(x2tim)
        or a
        jr z,.d
        call .add
.d:     ld a,(hud_dirty)
        or 1
        ld (hud_dirty),a
        ; extra life at 10000
        ld a,(extragiven)
        or a
        ret nz
        ld a,(score)
        or a
        ret z
        ld a,1
        ld (extragiven),a
        ld a,3
        ld (hud_dirty),a
        ld hl,lives
        inc (hl)
        ld a,SFX_PUP
        jp play_sfx
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
        ret

; popup at player position: A = string index
popup_at_player:
        ld b,a
        ld a,(PLAYER+A_X)
        ld d,a
        ld a,(PLAYER+A_Y)
        ld e,a
        ld a,b
; popup: A = index, D = px, E = py (map coords)
popup:
        push af
        ld hl,popups
        ld b,3
.f:     ld a,(hl)
        or a
        jr z,.got
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .f
        ld hl,popups            ; overwrite first
.got:   ld (hl),50              ; timer
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        inc hl
        pop af
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; particles: 12 x 8 bytes: xlo,xhi,ylo,yhi,dx,dy,life,col
; burst: B = x, C = y, A = colour
burst:
        ld (burstcol),a
        ld d,8
.l:     push de
        push bc
        call new_particle
        pop bc
        pop de
        dec d
        jr nz,.l
        ret
new_particle:   ; B,C pos; random velocity
        call find_pslot
        ret nc
.got:   ld (hl),0
        inc hl
        ld (hl),b
        inc hl
        ld (hl),0
        inc hl
        ld (hl),c
        inc hl
        push hl
        call random
        pop hl
        ld (hl),a               ; dx (signed, 1/64 px)
        inc hl
        push hl
        call random
        pop hl
        sra a
        ld (hl),a               ; dy
        inc hl
        push hl
        call random
        pop hl
        and 7
        add a,10
        ld (hl),a               ; life
        inc hl
        ld a,(burstcol)
        ld (hl),a
        ret
; trail dot: B,C pos, A colour (no velocity)
trail_dot:
        ld (burstcol),a
        call find_pslot
        ret nc
.got:   ld (hl),0
        inc hl
        ld (hl),b
        inc hl
        ld (hl),0
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),8
        inc hl
        ld a,(burstcol)
        ld (hl),a
        ret

find_pslot:
        push bc
        ld hl,particles+6
        ld de,8
        ld b,12
.f:     ld a,(hl)
        or a
        jr z,.got
        add hl,de
        djnz .f
        pop bc
        or a
        ret
.got:   ld de,-6
        add hl,de
        pop bc
        scf
        ret

update_particles:
        ld ix,particles
        ld b,12
.l:     push bc
        ld a,(ix+6)
        or a
        jr z,.n
        dec (ix+6)
        jr z,.n
        ; x += dx*4
        ld a,(ix+4)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        ld e,(ix+0)
        ld d,(ix+1)
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        ld a,(ix+5)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        ld e,(ix+2)
        ld d,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ; to screen
        ld a,(camx)
        ld e,a
        ld a,(ix+1)
        sub e
        jr c,.n
        cp 128
        jr nc,.n
        ld b,a
        ld a,(camy)
        ld e,a
        ld a,h
        sub e
        jr c,.n
        cp VPROWS
        jr nc,.n
        add a,VPTOP
        ld c,a
        ld e,(ix+7)
        ld a,(ix+6)
        cp 4
        jr nc,.col
        ld e,0                  ; fade to green before dying
.col:   call dl_pixel
        jr .n
.kill:  ld (ix+6),0
.n:     ld de,8
        add ix,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; HUD
draw_hud_static:
        ld a,1
        ld (textdest),a
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_hi
        ld de,$0700
        call print
        ld hl,s_lv
        ld de,$1000
        call print
        ld a,3
        ld (hud_dirty),a
        ret
s_hi:   db "HI",0
s_lv:   db "L",0
update_hud:
        ld a,(hud_dirty)
        or a
        ret z
        ; while the view pans, the score waits for a quieter frame (up to 4)
        ld a,(panflag)
        or a
        jr z,.go
        ld a,(framecount)
        and 3
        ret nz
.go:    ld a,(hud_dirty)
        ld c,a
        xor a
        ld (hud_dirty),a
        ld a,c
        cp 3
        jr nz,.part
        ; full redraw: forget the digit caches
        ld hl,hudcache
        ld b,12
.fc:    ld (hl),$FF
        inc hl
        djnz .fc
.part:  push bc
        xor a
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,score
        ld de,$0000
        ld ix,hudcache
        call hud_num
        pop bc
        push bc
        ld a,(demo)
        or a
        jr nz,.nohi
        ld hl,score
        ld de,hiscore
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.newhi
        jr nz,.nohi
        inc hl
        inc de
        djnz .c
        jr .nohi
.newhi: ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        ld hl,hiscore
        ld de,$0900
        ld ix,hudcache+6
        call hud_num
.nohi:  pop bc
        bit 1,c
        ret z
        ld hl,hiscore
        ld de,$0900
        ld ix,hudcache+6
        call hud_num
        ld a,(level)
        ld de,$1100
        call print_dec2
        ; lives icons at cols 28..31
        ld a,1
        ld b,2
        call set_ink
        ld a,(lives)
        or a
        jr z,.l0
        dec a
.l0:    ld c,a
        ld d,28
.lv:    ld a,' '
        ld b,c
        inc b
        dec b
        jr z,.blank
        ld a,'['
        dec c
.blank: push bc
        push de
        ld e,0
        call putchar
        pop de
        pop bc
        inc d
        ld a,d
        cp 32
        jr nz,.lv
        ret

; hud_num: HL = 3 BCD bytes, D/E = position, IX = 6-byte cache. Prints changed digits.
hud_num:
        ld b,6
.d:     ld a,(hl)
        bit 0,b
        jr z,.hi
        and $0F
        inc hl
        jr .dg
.hi:    rrca
        rrca
        rrca
        rrca
        and $0F
.dg:    cp (ix+0)
        jr z,.same
        ld (ix+0),a
        add a,'0'
        push hl
        push bc
        push de
        call putchar
        pop de
        pop bc
        pop hl
.same:  inc ix
        inc d
        djnz .d
        ret

; label area cols 20..27: HL = string (8 chars max), A = colour
hud_label:
        push hl
        ld b,2
        call set_ink
        ld a,1
        ld (textdest),a
        ld hl,s_blank8
        ld de,$1400
        call print
        pop hl
        ld de,$1400
        jp print
s_blank8: db "        ",0

; bottom timer bar: A = length 0..32, B = colour byte
draw_bar:
        ld c,a
        ld a,(lastbar)
        cp c
        jr nz,.ch
        ld a,(lastbarc)
        cp b
        ret z
.ch:    ld a,c
        ld (lastbar),a
        ld a,b
        ld (lastbarc),a
        ld hl,VRAM+5*32
        ld e,32
.l:     ld a,c
        or a
        ld a,$AA
        jr z,.bg
        dec c
        ld a,b
.bg:    ld (hl),a
        inc l
        dec e
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; LEVEL SETUP
; round table by (level-1)%8: maze index, round type (0 normal,1 buffet,2 panic), intermission after
roundtab:
        db 0,0,0                ; THE CRYPT
        db 1,0,1                ; HAUNTED HALLS      -> intermission 1
        db 2,0,0                ; THE GRAVEYARD
        db 3,1,0                ; THE CATACOMBS: GHOST BUFFET
        db 4,0,2                ; THE BELFRY         -> intermission 2
        db 5,0,0                ; MISTY MANOR
        db 3,0,0                ; THE CATACOMBS
        db 6,2,0                ; PELLET PANIC

setup_round:
        ld a,(level)
        dec a
        and 7
        ld b,a
        add a,a
        add a,b
        ld e,a
        ld d,0
        ld hl,roundtab
        add hl,de
        ld a,(demo)
        or a
        jr z,.nd
        ld a,(demomaze)
        ld (mazeidx),a
        xor a
        ld (roundtype),a
        ld (intermission),a
        jr .gotr
.nd:    ld a,(hl)
        ld (mazeidx),a
        inc hl
        ld a,(hl)
        ld (roundtype),a
        inc hl
        ld a,(hl)
        ld (intermission),a
.gotr:  ; difficulty: lv = min(level,12)
        ld a,(level)
        cp 13
        jr c,.l1
        ld a,12
.l1:    ld b,a
        ; player speed 196 + 4*lv
        add a,a
        add a,a
        add a,196
        ld (pspeed),a
        ; ghost speed 170 + 6*lv
        ld a,b
        add a,a
        add a,b
        add a,a
        add a,170
        ld (gspeed),a
        ld a,112
        ld (fspeed),a
        ; fright time 190 - 12*lv, min 45
        ld a,b
        add a,a
        ld c,a
        add a,a
        add a,a
        sub c                   ; 6*lv
        add a,a                 ; 12*lv
        ld c,a
        ld a,190
        sub c
        jr c,.fm
        cp 45
        jr nc,.fo
.fm:    ld a,45
.fo:    ld (frighttime),a
        ; dizzy random chance: 30 + 6*lv
        ld a,b
        add a,a
        add a,b
        add a,a
        add a,30
        ld (dizzy_chance),a
        ; siren speed
        ld a,b
        add a,3
        ld (sirenspd),a
        ; build the maze
        ld a,(mazeidx)
        call build_level
        ; house geometry from the door: house row below, exit row above
        ld a,(doorcy)
        dec a
        ld (exitcy),a
        ld b,a
        add a,a
        add a,a
        add a,b
        ld (exity),a            ; py of the exit row
        add a,10
        ld (housey),a           ; py of the house row
        ; bonus round adjustments
        ld a,(roundtype)
        cp 1
        jr nz,.nb
        ; buffet: remove all pellets and power pills
        ld hl,GRID
        ld bc,GSTRIDE*MAXH
.rb:    ld a,(hl)
        cp T_PELLET*4
        jr z,.rb0
        cp T_ENERG0*4
        jr z,.rb0
        cp T_ENERG1*4
        jr nz,.rb1
.rb0:   ld (hl),0
.rb1:   inc hl
        dec bc
        ld a,b
        or c
        jr nz,.rb
        ld hl,0
        ld (pellets),hl
        ld (pellets_total),hl
        xor a
        ld (nener),a
.nb:    ld hl,0
        ld (eaten),hl
        ; item spawn step = total pellets / 6
        ld hl,(pellets_total)
        ld de,6
        ld bc,0
.dv6:   or a
        sbc hl,de
        jr c,.dv6e
        inc bc
        jr .dv6
.dv6e:  ld (spawnstep),bc
        ld a,$FF
        ld (lastbar),a
        ret

; draw the HUD and reveal the maze (called with the screen blue)
reveal_maze:
        call draw_hud_static
        ld a,3
        ld (hud_dirty),a
        call update_hud
        call cam_centre
        call fill_ring
        call build_srctab
        ; blinds reveal of the viewport, 8 interleaved passes
        ld c,0
.p:     push bc
        ld b,c
.r:     push bc
        ld a,b
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,srctab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld a,b
        add a,VPTOP
        ld e,a
        ld d,0
        call scraddr
        ex de,hl
        pop hl
        ld bc,32
        ldir
        pop bc
        ld a,b
        add a,8
        ld b,a
        cp VPROWS
        jr c,.r
        call blank_frame
        pop bc
        inc c
        ld a,c
        cp 8
        jr nz,.p
        call clear_erase
        xor a
        ld (panflag),a
        ret

; place actors at start positions
reset_actors:
        ld hl,actors
        ld de,actors+1
        ld bc,16*5-1
        ld (hl),0
        ldir
        ld ix,PLAYER
        ld a,(startcx)
        ld b,a
        ld a,(startcy)
        ld c,a
        call cell_pix
        ld (ix+A_X),d
        ld (ix+A_Y),e
        ld (ix+A_DIR),1
        ld (ix+A_NEXT),1
        ld (ix+A_ID),0
        ld (ix+A_TX),$FF
        ld a,(pspeed)
        ld (ix+A_SPD),a
        ld ix,GHOST1
        ld hl,ghost_start
        ld b,4
        ld c,1
.g:     ld a,(hl)
        inc hl
        ld (ix+A_X),a
        ld a,(hl)
        inc hl
        or a
        ld a,(exity)
        jr z,.gy
        ld a,(housey)
.gy:    ld (ix+A_Y),a
        ld a,(hl)
        inc hl
        ld (ix+A_ST),a
        ld a,(hl)
        inc hl
        ld (ix+A_TIM),a
        ld (ix+A_ID),c
        ld (ix+A_DIR),1
        inc c
        ld de,16
        add ix,de
        djnz .g
        ; faster release on later levels
        ld a,(level)
        cp 4
        jr c,.nr
        ld a,(GHOST1+16*2+A_TIM)
        srl a
        ld (GHOST1+16*2+A_TIM),a
        ld a,(GHOST1+16*3+A_TIM)
        srl a
        ld (GHOST1+16*3+A_TIM),a
.nr:    ld a,(roundtype)
        cp 2
        jr nz,.npn
        ld ix,GHOST1
        ld (ix+A_ST),ST_HOUSE
        ld a,(housey)
        ld (ix+A_Y),a
        ld (ix+A_X),DOORX-6
.npn:   cp 1
        jr nz,.nb
        ; buffet: everyone out quickly and frightened
        ld ix,GHOST1+16
        ld (ix+A_TIM),10
        ld (ix+16+A_TIM),30
        ld (ix+32+A_TIM),50
.nb:    xor a
        ld (frighttim),a
        ld (freezetim),a
        ld (speedtim),a
        ld (x2tim),a
        ld (shieldtim),a
        ld (supertim),a
        ld (decoytim),a
        ld (itemtim),a
        ld (chasemode),a
        ld (modephase),a
        ld (hitstop),a
        ld (streak),a
        ld (streaktim),a
        ld (elroy),a
        ld (palbase),a
        ld (swoopreq),a
        ld hl,350
        ld (modetim),hl
        ld hl,particles
        ld de,particles+1
        ld bc,12*8-1
        ld (hl),0
        ldir
        ld hl,popups
        ld b,12
.pp:    ld (hl),0
        inc hl
        djnz .pp
        ret
ghost_start:    ; x, 0 = exit row / 1 = house row, state, release timer
        db DOORX,0,ST_ACT,0
        db DOORX,1,ST_HOUSE,40
        db DOORX-12,1,ST_HOUSE,160
        db DOORX+12,1,ST_HOUSE,250

; ---------------------------------------------------------------------
; build draw list for the play field (map coords -> screen via the camera)
build_drawlist:
        call dl_reset
        ; item
        ld a,(itemtim)
        or a
        jr z,.noitem
        cp 100
        jr nc,.iv
        ld a,(framecount)
        and 4
        jr nz,.noitem
.iv:    ld a,(itemspr)
        cp SPR_I_STAR
        jr nz,.is
        ld a,(framecount)
        and 4
        ld a,SPR_I_STAR
        jr z,.is
        ld a,SPR_I_STAR2
.is:    ld hl,(itemx)
        ld b,l
        ld c,h
        push af
        push bc
        call dl_add_map
        pop bc
        pop af
        jr nc,.noitem
        ; off screen: a twinkling blip at the edge shows where it is
        ld a,(framecount)
        and 8
        jr z,.noitem
        ld a,SPR_BLIP_Y
        call dl_blip
.noitem:
        ; decoy
        ld a,(decoytim)
        or a
        jr z,.nodecoy
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_DECOY_0
        push af
        ld a,(decoyx)
        ld b,a
        ld a,(decoyy)
        ld c,a
        pop af
        call dl_add_map
.nodecoy:
        ; ghosts
        ld ix,GHOST1
        ld b,4
.gl:    push bc
        call ghost_sprite
        cp $FF
        jr z,.gn
        ld e,a
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        ld a,(freezetim)
        or a
        jr z,.gs
        ld a,(ix+A_ST)
        cp ST_ACT
        jr c,.gs
        cp ST_EYES
        jr nc,.gs
        ld a,(framecount)
        and 2
        jr z,.gs
        inc b                   ; shiver
.gs:    ld a,e
        push bc
        call dl_add_map
        pop bc
        jr nc,.gn
        ; off screen: blip at the viewport edge in the ghost's colour
        call ghost_blip
        cp $FF
        jr z,.gn
        call dl_blip
.gn:    ld de,16
        add ix,de
        pop bc
        djnz .gl
        ; player
        ld a,(pvisible)
        or a
        jr z,.nopl
        ld ix,PLAYER
        call player_sprite
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        push bc
        call dl_add_map
        pop bc
        ld a,(shieldtim)
        or a
        jr z,.nopl
        cp 60
        jr nc,.sh
        ld a,(framecount)
        and 4
        jr nz,.nopl
.sh:    ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BUBBLE_0
        call dl_add_map
.nopl:  ; popups (map coords -> text cells)
        ld hl,popups
        ld b,3
.pl:    ld a,(hl)
        or a
        jr z,.pn
        dec (hl)
        push hl
        push bc
        inc hl
        ld a,(camx)
        ld e,a
        ld a,(hl)               ; x
        sub e
        jr nc,.px
        xor a
.px:    cp 128
        jr c,.px1
        ld a,124
.px1:   srl a
        srl a
        or a
        jr z,.c0
        dec a
.c0:    cp 26
        jr c,.c1
        ld a,26
.c1:    ld b,a
        inc hl
        ld a,(camy)
        ld e,a
        ld a,(hl)               ; y
        sub e
        jr nc,.py
        xor a
.py:    cp 52
        jr c,.py1
        ld a,52
.py1:   add a,VPTOP
        ld c,a
        inc hl
        ld e,(hl)
        call dl_text
        pop bc
        pop hl
.pn:    inc hl
        inc hl
        inc hl
        inc hl
        djnz .pl
        jp update_particles

; blip for the ghost IX -> A sprite id ($FF none)
ghost_blip:
        ld a,(ix+A_ST)
        cp ST_EYES
        jr nc,.none
        cp ST_ACT
        jr c,.none              ; in the house
        cp ST_FRT
        jr nz,.n
        ld a,(framecount)
        and 4
        jr nz,.none
        ld a,SPR_BLIP_Y
        ret
.n:     ld a,(ix+A_ID)
        cp 4
        jr nz,.n2
        ; PEEKABOO: only while he can be seen
        call ghost_sprite
        cp SPR_EYES_R
        jr nc,.none
        ld a,SPR_BLIP_G
        ret
.n2:    cp 2
        ld a,SPR_BLIP_G
        ret z
        ld a,(ix+A_ID)
        cp 3
        ld a,SPR_BLIP_R
        ret nz
        ld a,(framecount)
        and 8
        ld a,SPR_BLIP_R
        ret z
        ld a,SPR_BLIP_G
        ret
.none:  ld a,$FF
        ret

; dl_blip: A = blip sprite, B,C = map coords of the thing (px,py) -> at the edge
dl_blip:
        push af
        ld a,(camx)
        ld e,a
        ld a,b
        add a,2
        sub e
        jr nc,.x1
        xor a                   ; left of the view
        jr .x3
.x1:    cp 125
        jr c,.x3
        ld a,125
.x3:    add a,8
        ld b,a
        ld a,(camy)
        ld e,a
        ld a,c
        add a,1
        sub e
        jr nc,.y1
        xor a
        jr .y3
.y1:    cp VPROWS-2
        jr c,.y3
        ld a,VPROWS-2
.y3:    add a,VPTOP+16
        ld c,a
        pop af
        jp dl_add

; ghost sprite id for IX -> A ($FF = hidden)
ghost_sprite:
        ld a,(ix+A_ST)
        cp ST_EYES
        jp nc,.eyes
        cp ST_FRT
        jr z,.fright
        ld a,(freezetim)
        or a
        jr z,.nofz
        ld a,(ix+A_ST)
        cp ST_ACT
        jr nz,.nofz
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_FROZEN_0
        ret
.nofz:  ; PEEKABOO invisibility
        ld a,(ix+A_ID)
        cp 4
        jr nz,.body
        ld a,(level)
        cp 2
        jr c,.body
        ld a,(demo)
        or a
        jr nz,.pk
        ld a,(level)
        cp 2
        jr c,.body
.pk:    ld a,(framecount+1)
        ld b,a
        ld a,(framecount)
        rr b
        rra                     ; frames/2
        and $FF
        cp 160
        jr c,.body
        cp 176
        jr c,.flick
        cp 240
        jr c,.eyes
.flick: ld a,(framecount)
        and 2
        jr z,.body
        jr .eyes
.body:  ld a,(ix+A_ID)
        dec a
        add a,a
        add a,a
        add a,a                 ; *8
        add a,SPR_G_GRUMBLE_0
        ld b,a
        ld a,(ix+A_DIR)
        and 3
        add a,a
        add a,b
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,b
        ret
.fright:
        ld a,(frighttim)
        cp 50
        jr nc,.f1
        ld a,(framecount)
        and 8
        jr z,.f1
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_FLASH_0
        ret
.f1:    ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_FRIGHT_0
        ret
.eyes:  ld a,(ix+A_DIR)
        and 3
        add a,SPR_EYES_R
        ret

player_sprite:
        ld a,(supertim)
        or a
        jr z,.n
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_SHERO_0
        ret
.n:     ld a,(ix+A_ANIM)
        rrca
        and 3
        cp 3
        jr nz,.a
        ld a,1
.a:     ld b,a
        bit 0,(ix+A_FLG)
        jr z,.m
        ld b,1
.m:     ld a,(ix+A_DIR)
        and 3
        ld c,a
        add a,a
        add a,c                 ; *3
        add a,b
        add a,SPR_HERO_R0
        ret

; ---------------------------------------------------------------------
; per-frame game logic.  returns: A = 0 continue, 1 level clear, 2 death, 3 time up
game_logic:
        ld a,(hitstop)
        or a
        jr z,.run
        dec a
        ld (hitstop),a
        xor a
        ret
.run:   ; player input -> next dir
        ld a,(demo)
        ld hl,autoplay
        or (hl)
        jr nz,.noinp
        ld a,(inp)
        and $0F
        jr z,.noinp
        ld b,a
        ld a,(inpnew)
        and b
        jr nz,.pick
        ld a,b
.pick:  ld c,0
.pk:    rrca
        jr c,.got
        inc c
        jr .pk
.got:   ld a,c
        ld (PLAYER+A_NEXT),a
.noinp: call tick_timers
        ; player movement
        ld ix,PLAYER
        ld a,(pspeed)
        ld b,a
        ld a,(speedtim)
        ld c,a
        ld a,(supertim)
        or c
        ld a,b
        jr z,.ps
        ; boosted: two passes at 3/4 speed
        srl a
        ld c,a
        srl a
        add a,c
        push af
        call move_actor
        ld ix,PLAYER
        pop af
.ps:    call move_actor
        ; ghosts
        ld ix,GHOST1
        ld b,4
.gu:    push bc
        call ghost_update
        pop bc
        ld de,16
        add ix,de
        djnz .gu
        call collisions
        or a
        ret nz
        call item_logic
        ; level clear?
        ld a,(roundtype)
        cp 1
        jr z,.timed
        ld hl,(pellets)
        ld a,h
        or l
        jr nz,.nc
        ld a,1
        ret
.nc:    ld a,(roundtype)
        cp 2
        jr z,.timed
        xor a
        ret
.timed: ld hl,(roundtim)
        dec hl
        ld (roundtim),hl
        ld a,h
        or l
        ld a,0
        ret nz
        ld a,3
        ret

; timers
tick_timers:
        ld a,(streaktim)
        or a
        jr z,.t0
        dec a
        ld (streaktim),a
.t0:    call animate_map
.t1:    ld a,(roundtype)
        cp 1
        jr nz,.tf
        ld a,200
        ld (frighttim),a
.tf:    ; fright
        ld a,(frighttim)
        or a
        jr z,.t2
        ld b,a
        ld a,(framecount)
        and 1
        jr nz,.t2
        dec b
        ld a,b
        ld (frighttim),a
        jr nz,.t2
        ld a,(supertim)
        or a
        jr nz,.t2
        ld a,(roundtype)
        cp 1
        jr z,.t2
        call unfrighten_all
.t2:    ld hl,freezetim
        call dec_hl_tim
        ld hl,speedtim
        call dec_hl_tim
        ld hl,x2tim
        call dec_hl_tim
        ld hl,shieldtim
        call dec_hl_tim
        ld hl,decoytim
        call dec_hl_tim
        ld hl,itemtim
        call dec_hl_tim
        ; super
        ld a,(supertim)
        or a
        jr z,.t3
        ld b,a
        ld a,(framecount)
        and 1
        jr nz,.t3
        dec b
        ld a,b
        ld (supertim),a
        jr nz,.trail
        call unfrighten_all
        jr .t3
.trail: ; super / speed trail
.t3:    ld a,(speedtim)
        ld b,a
        ld a,(supertim)
        or b
        jr z,.t4
        ld a,(framecount)
        and 1
        jr nz,.t4
        ld a,(PLAYER+A_X)
        add a,XOFF+3
        ld b,a
        ld a,(PLAYER+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,(framecount)
        and 2
        ld a,3
        jr z,.tc
        ld a,1
.tc:    call trail_dot
.t4:    ; scatter/chase schedule (paused while frightened)
        ld a,(frighttim)
        or a
        jr nz,.t5
        ld a,(modephase)
        cp 5
        jr nc,.t5
        ld hl,(modetim)
        dec hl
        ld (modetim),hl
        ld a,h
        or l
        jr nz,.t5
        ld a,(modephase)
        inc a
        ld (modephase),a
        and 1
        ld (chasemode),a
        ld a,(modephase)
        ld e,a
        ld d,0
        sla e
        ld hl,modetimes
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (modetim),hl
        ; reverse roaming ghosts
        ld ix,GHOST1
        ld b,4
.rv:    ld a,(ix+A_ST)
        cp ST_ACT
        jr nz,.rv1
        set 1,(ix+A_FLG)
.rv1:   ld de,16
        add ix,de
        djnz .rv
.t5:    ; elroy
        ld hl,(pellets_total)
        srl h
        rr l
        srl h
        rr l
        ld a,(level)
        cp 5
        jr c,.e1
        ld hl,(pellets_total)
        srl h
        rr l
        ld de,(pellets_total)
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de               ; 3/8
.e1:    ld de,(pellets)
        or a
        sbc hl,de
        ld a,0
        jr c,.e2
        inc a
.e2:    ld (elroy),a
        ; siren mode
        ld b,1
        ld a,(frighttim)
        or a
        jr z,.s1
        ld b,2
.s1:    ld ix,GHOST1
        ld c,4
.s2:    ld a,(ix+A_ST)
        cp ST_EYES
        jr nz,.s3
        ld b,3
.s3:    ld de,16
        add ix,de
        dec c
        jr nz,.s2
        ld a,b
        ld (sirenmode),a
        ret
dec_hl_tim:
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret
modetimes: dw 350,1000,350,1000,250,0

; ---------------------------------------------------------------------
; collisions: returns A = 2 on death
collisions:
        ld ix,GHOST1
        ld b,4
.l:     push bc
        ld a,(ix+A_ST)
        cp ST_ACT
        jr z,.chk
        cp ST_FRT
        jr nz,.n
.chk:   ld a,(PLAYER+A_X)
        sub (ix+A_X)
        jp p,.a1
        neg
.a1:    cp 4
        jr nc,.n
        ld a,(PLAYER+A_Y)
        sub (ix+A_Y)
        jp p,.a2
        neg
.a2:    cp 3
        jr nc,.n
        ld a,(ix+A_ST)
        cp ST_FRT
        jr z,.eat
        ld a,(supertim)
        or a
        jr nz,.eat
        ld a,(freezetim)
        or a
        jr nz,.n
        ld a,(shieldtim)
        or a
        jr nz,.shield
        ld a,(godmode)
        or a
        jr nz,.n
        pop bc
        ld a,2
        ret
.shield:
        xor a
        ld (shieldtim),a
        ld (ix+A_ST),ST_EYES
        ld a,P_POP
        call popup_at_player
        call ghost_burst
        ld a,SFX_SHIELD
        call play_sfx
        ld a,6
        ld (flashtim),a
        jr .n
.eat:   call eat_ghost
.n:     ld de,16
        add ix,de
        pop bc
        djnz .l
        ; decoy vs ghosts: nothing. done
        xor a
        ret

eat_ghost:
        ld (ix+A_ST),ST_EYES
        ld a,(supertim)
        or a
        jr z,.chain
        ld a,P_1000
        jr .score
.chain: ld a,(chain)
        inc a
        ld (chain),a
        ld e,a
        ld d,0
        ld hl,chainpop-1
        add hl,de
        ld a,e
        cp 6
        jr c,.c1
        ld hl,chainpop+4
.c1:    ld a,(hl)
.score: push af
        add a,a
        ld e,a
        ld d,0
        ld hl,popval
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        pop af
        ld d,(ix+A_X)
        ld e,(ix+A_Y)
        call popup
        call ghost_burst
        ld a,SFX_EATG
        call play_sfx
        ld a,14
        ld (hitstop),a
        ld a,4
        ld (flashtim),a
        ; perfect chain -> super star
        ld a,(roundtype)
        or a
        ret nz
        ld a,(chain)
        cp 4
        ret nz
        ld a,P_PERFECT
        ld a,(exity)
        ld e,a
        ld d,DOORX
        ld a,P_PERFECT
        call popup
        call place_item
        ld a,SPR_I_STAR
        ld (itemspr),a
        ld a,250
        ld (itemtim),a
        ld a,SFX_SPAWN
        jp play_sfx
chainpop: db P_200,P_400,P_800,P_1600,P_3200

ghost_burst:
        ld a,(ix+A_X)
        add a,XOFF+3
        ld b,a
        ld a,(ix+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,(framecount)
        and 1
        add a,1
        jp burst

; ---------------------------------------------------------------------
; items: spawn & collect
item_logic:
        ld a,(roundtype)
        or a
        ret nz
        ; five items per maze, at 1/6, 2/6 .. 5/6 of the pellets
        ld a,(itemtim)
        or a
        jp nz,.active
        ld a,(spawned)
        cp 5
        ret nc
        ; threshold = (spawned+1) * total/6
        inc a
        ld hl,0
        ld bc,(spawnstep)
.m:     add hl,bc
        dec a
        jr nz,.m
        ld de,(eaten)
        or a
        sbc hl,de
        ret nc
        ; spawn
        call place_item
        ld a,(spawned)
        inc a
        ld (spawned),a
        cp 2
        jr z,.power
        cp 4
        jr z,.power
        cp 3
        jr nz,.treasure
        ld a,(level)
        cp 3
        jr nc,.power
.treasure:
        ld a,(level)
        dec a
        cp 6
        jr c,.t1
        ld a,5
.t1:    ld e,a
        ld d,0
        ld hl,treasure_spr
        add hl,de
        ld a,(hl)
        jr .set
.power: ; pick unlocked power-up
        ld a,(level)
        cp 5
        jr c,.p1
        ld a,5
.p1:    inc a                   ; count = level+1 (2..6) -> but cap 5
        cp 6
        jr c,.p2
        ld a,5
.p2:    ld b,a
        call random
.p3:    sub b
        jr nc,.p3
        add a,b
        ld e,a
        ld d,0
        ld hl,power_spr
        add hl,de
        ld a,(hl)
.set:   ld (itemspr),a
        ld a,250
        ld (itemtim),a
        ld a,SFX_SPAWN
        jp play_sfx
.active:
        ; collect?
        ld a,(itemx)
        ld b,a
        ld a,(PLAYER+A_X)
        sub b
        jp p,.c1
        neg
.c1:    cp 4
        ret nc
        ld a,(itemy)
        ld b,a
        ld a,(PLAYER+A_Y)
        sub b
        jp p,.c2
        neg
.c2:    cp 3
        ret nc
        xor a
        ld (itemtim),a
        ld a,(itemspr)
        cp SPR_I_SPEED
        jp z,pu_speed
        cp SPR_I_FREEZE
        jp z,pu_freeze
        cp SPR_I_DECOY
        jp z,pu_decoy
        cp SPR_I_X2
        jp z,pu_x2
        cp SPR_I_SHIELD
        jp z,pu_shield
        cp SPR_I_STAR
        jp z,pu_super
        ; treasure
        ld e,0
        ld hl,treasure_spr
.ts:    cp (hl)
        jr z,.tf
        inc hl
        inc e
        jr .ts
.tf:    ld d,0
        ld hl,treasure_pop
        add hl,de
        ld a,(hl)
        push af
        add a,a
        ld e,a
        ld hl,popval
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        pop af
        call popup_at_player
        call item_burst_pos
        ld a,1
        call burst
        ld a,SFX_ITEM
        jp play_sfx
item_burst_pos:
        ld a,(itemx)
        add a,3
        ld b,a
        ld a,(itemy)
        add a,2
        ld c,a
        ret

; place_item: pick an item spot (away from the hero if possible) -> itemx, itemy
place_item:
        ld a,(nspots)
        or a
        jr nz,.sp
        ; no spots: under the ghost house
        ld a,DOORX
        ld (itemx),a
        ld a,(housey)
        add a,10
        ld (itemy),a
        ret
.sp:    ld b,a
        call random
.mod:   sub b
        jr nc,.mod
        add a,b
        ld c,a                  ; first choice
        ld a,4
        ld (pitry),a
.try:   ld a,c
        add a,a
        ld l,a
        ld h,0
        ld de,spots
        add hl,de
        push bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        call cell_pix
        pop bc
        ld a,d
        ld (itemx),a
        ld a,e
        ld (itemy),a
        ; far enough from the hero (more than 20 rows or 40 px)?
        ld a,(PLAYER+A_Y)
        sub e
        jp p,.d1
        neg
.d1:    cp 20
        ret nc
        ld a,(PLAYER+A_X)
        sub d
        jp p,.d2
        neg
.d2:    cp 40
        ret nc
        inc c
        ld a,c
        cp b
        jr c,.t2
        ld c,0
.t2:    ld hl,pitry
        dec (hl)
        jr nz,.try
        ret
treasure_spr: db SPR_T_CANDY,SPR_T_PUMPKIN,SPR_T_POTION,SPR_T_SKULL,SPR_T_GEM,SPR_T_CROWN
treasure_pop: db P_100,P_300,P_500,P_700,P_1000,P_2000
power_spr: db SPR_I_SPEED,SPR_I_X2,SPR_I_FREEZE,SPR_I_DECOY,SPR_I_SHIELD

pu_common:      ; A = popup
        call popup_at_player
        call item_burst_pos
        ld a,3
        call burst
        ld a,SFX_PUP
        jp play_sfx
pu_speed:
        ld a,220
        ld (speedtim),a
        ld (pumax),a
        ld a,1
        ld (pukind),a
        ld a,P_SPEED
        jp pu_common
pu_freeze:
        ld a,220
        ld (freezetim),a
        ld (pumax),a
        ld a,2
        ld (pukind),a
        ld a,SFX_FREEZE
        call play_sfx
        ld a,P_FREEZE
        call popup_at_player
        ret
pu_decoy:
        ld a,250
        ld (decoytim),a
        ld (pumax),a
        ld a,3
        ld (pukind),a
        ld a,(PLAYER+A_X)
        add a,XOFF
        ld (decoyx),a
        ld a,(PLAYER+A_Y)
        add a,YOFF
        ld (decoyy),a
        push ix
        ld ix,PLAYER
        call actor_cell
        pop ix
        ld a,b
        ld (decoycx),a
        ld a,c
        ld (decoycy),a
        ld a,P_DECOY
        jp pu_common
pu_x2:
        ld a,250
        ld (x2tim),a
        ld (pumax),a
        ld a,4
        ld (pukind),a
        ld a,P_X2
        jp pu_common
pu_shield:
        ld a,250
        ld (shieldtim),a
        ld (pumax),a
        ld a,5
        ld (pukind),a
        ld a,P_SHIELD
        jp pu_common
pu_super:
        ld a,200
        ld (supertim),a
        ld a,6
        ld (pukind),a
        ld a,200
        ld (pumax),a
        ; everyone roaming becomes prey
        ld a,(frighttime)
        push af
        ld a,250
        ld (frighttime),a
        call frighten_all
        pop af
        ld (frighttime),a
        ld a,250
        ld (frighttim),a
        ld a,12
        ld (flashtim),a
        ld hl,mus_super_0
        ld de,mus_super_1
        call play_music
        ld a,P_HUNT
        jp pu_common

; HUD power label + bar each frame
hud_power:
        ; bonus rounds show their own timer
        ld a,(roundtype)
        or a
        jp nz,.h7
        ; choose most important active timer
        ld a,(supertim)
        or a
        jr z,.h1
        ld hl,s_super
        ld b,$FF
        ld c,200
        jp .show
.h1:    ld a,(frighttim)
        or a
        jr z,.h2
        ld hl,s_power
        ld b,$55
        ld c,a
        ld a,(frightmax)
        ld e,a
        ld a,c
        jp .showm
.h2:    ld a,(freezetim)
        or a
        jr z,.h3
        ld hl,s_freeze
        ld b,$00
        ld c,220
        jp .show
.h3:    ld a,(speedtim)
        or a
        jr z,.h4
        ld hl,s_speed
        ld b,$FF
        ld c,220
        jp .show
.h4:    ld a,(decoytim)
        or a
        jr z,.h5
        ld hl,s_decoy
        ld b,$55
        ld c,250
        jp .show
.h5:    ld a,(x2tim)
        or a
        jr z,.h6
        ld hl,s_x2
        ld b,$FF
        ld c,250
        jp .show
.h6:    ld a,(shieldtim)
        or a
        jr z,.h7
        ld hl,s_shield
        ld b,$00
        ld c,250
        jp .show
.h7:    ld a,(roundtype)
        or a
        jp z,.none
        ; bonus timer: bar = roundtim/80
        ld hl,(roundtim)
        ld de,80
        ld a,0
.bd:    or a
        sbc hl,de
        jr c,.bt
        inc a
        jr .bd
.bt:    cp 33
        jr c,.bt2
        ld a,32
.bt2:   ld b,$FF
        call draw_bar
        ld hl,(roundtype_lbl)
        jr .lbl
.none:  xor a
        ld b,0
        call draw_bar
        ld hl,s_blank8
        ld a,(demo)
        or a
        jr z,.lbl
        ld hl,s_demo
        jr .lbl
.show:  ld e,c
.showm: ; A = timer, E = max -> bar = A*32/E
        inc e
        dec e
        jr nz,.em
        ld e,200
.em:    push hl
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *32
        ld d,0
        ld b,0
.dv:    or a
        sbc hl,de
        jr c,.dd
        inc b
        jr .dv
.dd:    ld a,b
        pop bc
        call draw_bar
        pop hl
.lbl:   ld de,(lastlabel)
        or a
        sbc hl,de
        add hl,de
        ret z
        ld (lastlabel),hl
        ld a,(pause)
        or a
        ret nz
        ld a,1
        jp hud_label
s_super: db "HUNTER!",0
s_power: db "POWER",0
s_freeze: db "FREEZE",0
s_speed: db "SPEED",0
s_decoy: db "DECOY",0
s_x2: db "DOUBLE",0
s_shield: db "SHIELD",0
s_buffet: db "BUFFET",0
s_panic: db "PANIC!",0
s_demo: db "DEMO",0

; ---------------------------------------------------------------------
; DEMO AI: chooses A_NEXT for the player at a cell centre (B,C = cell)
demo_ai:
        push bc
        ld a,$80
        ld (best),a             ; best score (signed, -128 start)
        ld a,(ix+A_DIR)
        ld (bestdir),a
        ; find a target pellet: scan for nearest pellet (Manhattan)
        ld a,(aitx)
        ld b,a
        ld a,(aity)
        ld c,a
        call cell_at
        cp 1
        jr z,.keept
        cp 2
        jr z,.keept
        ; any pellet right next to us? then no need to search
        ld a,0
.nb:    pop bc
        push bc
        push af
        call neighbour
        cp 1
        jr z,.nbp
        cp 2
        jr z,.nbp
        pop af
        inc a
        cp 4
        jr nz,.nb
        pop bc
        push bc
        call nearest_pellet     ; -> D,E = target cell (or player cell)
        ld a,d
        ld (aitx),a
        ld a,e
        ld (aity),a
        jr .keept
.nbp:   pop af
.keept:
        pop bc
        push bc
        ld a,0
.dl:    ld (aidir),a
        pop bc
        push bc
        call neighbour
        call passable
        jp nc,.next
        ; score this direction
        ld a,0
        ld (aiscore),a
        ; reversing penalty
        ld a,(aidir)
        xor 1
        cp (ix+A_DIR)
        jr nz,.nr
        ld a,-6
        ld (aiscore),a
.nr:    ; pellet in next cell
        push bc
        call cell_at
        pop bc
        cp 1
        jr c,.np
        cp 3
        jr nc,.np
        ld a,(aiscore)
        add a,12
        ld (aiscore),a
.np:    ; towards target pellet
        ld a,(aitx)
        ld e,a
        ld a,b
        sub e
        jp p,.q1
        neg
.q1:    ld d,a
        ld a,(aity)
        ld e,a
        ld a,c
        sub e
        jp p,.q2
        neg
.q2:    add a,d
        ld d,a                  ; new dist
        ld a,(aiscore)
        sub d
        sub d
        ld (aiscore),a
        ; ghosts danger
        push ix
        ld ix,GHOST1
        ld e,4
.gd:    ld a,(ix+A_ST)
        cp ST_ACT
        jr z,.dang
        cp ST_FRT
        jr nz,.gn
        ; frightened ghost nearby is tasty
        call ai_gdist
        cp 5
        jr nc,.gn
        ld a,(aiscore)
        add a,8
        ld (aiscore),a
        jr .gn
.dang:  ld a,(freezetim)
        or a
        jr nz,.gn
        call ai_gdist
        cp 2
        jr nc,.g2
        ld a,(aiscore)
        sub 60
        ld (aiscore),a
        jr .gn
.g2:    cp 4
        jr nc,.gn
        ld a,(aiscore)
        sub 25
        ld (aiscore),a
.gn:    push de
        ld de,16
        add ix,de
        pop de
        dec e
        jr nz,.gd
        pop ix
        ; randomness
        call random
        and 3
        ld e,a
        ld a,(aiscore)
        add a,e
        ld (aiscore),a
        ; compare signed with best
        ld e,a
        ld a,(best)
        sub e
        jp pe,.ov
        jp m,.better
        jr .next
.ov:    jp p,.better
        jr .next
.better:
        ld a,(aiscore)
        ld (best),a
        ld a,(aidir)
        ld (bestdir),a
.next:  ld a,(aidir)
        inc a
        cp 4
        jp nz,.dl
        pop bc
        ld a,(bestdir)
        ld (ix+A_NEXT),a
        ret
; distance from cell B,C to ghost IX -> A
ai_gdist:
        push bc
        push de
        push bc
        call actor_cell
        ld d,b
        ld e,c
        pop bc
        ld a,b
        sub d
        jp p,.a
        neg
.a:     ld d,a
        ld a,c
        sub e
        jp p,.b
        neg
.b:     add a,d
        pop de
        pop bc
        ret
; nearest pellet to cell B,C -> D,E. Searches 3 rows either side; if that
; band is empty it sweeps 6 more rows of the maze per call (cheap) and falls
; back to the hero's own cell, so the demo hunter keeps moving meanwhile.
nearest_pellet:
        ld a,b
        ld (npx),a
        ld a,c
        ld (npy),a
        ld d,b
        ld e,c
        ld a,99
        ld (npd),a
        ld a,c
        sub 3
        jr nc,.w0
        xor a
.w0:    ld (npy0),a
        ld a,c
        add a,4
        ld hl,maph
        cp (hl)
        jr c,.w1
        ld a,(hl)
.w1:    ld (npy1),a
        call .scan
        ld a,(npd)
        cp 99
        ret nz
        ; sweep a band further away
        ld a,(npsweep)
        add a,6
        ld hl,maph
        cp (hl)
        jr c,.s1
        xor a
.s1:    ld (npsweep),a
        ld (npy0),a
        add a,6
        cp (hl)
        jr c,.s2
        ld a,(hl)
.s2:    ld (npy1),a
.scan:  ld a,(npy0)
        ld c,a
.y:     ld b,0
        push de
        call cell_addr
        pop de
.x:     ld a,(hl)
        dec a
        cp 12                   ; pellet (4) or power pill (8, 12)
        jr c,.p
.n:     inc hl
        inc b
        ld a,b
        cp MAPW
        jr nz,.x
        inc c
        ld a,(npy1)
        cp c
        jr nz,.y
        ret
.p:     push de
        ld a,(npx)
        sub b
        jp p,.a
        neg
.a:     ld d,a
        ld a,(npy)
        sub c
        jp p,.b
        neg
.b:     add a,d
        pop de
        push hl
        ld hl,npd
        cp (hl)
        jr nc,.n2
        ld (hl),a
        ld d,b
        ld e,c
.n2:    pop hl
        jr .n
