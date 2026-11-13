; =====================================================================
;  objects.asm - enemies, pickups and effects; enemy bullets;
;  collisions; scoring; the stage timeline
;  Type record (10 bytes): beh, spr, hp, ox, oy, w, h, score(BCD x10),
;  flags, param. Types 1-31 come from the stage pack, 32+ are common.
; =====================================================================
TSZ         equ 10
T_BEH       equ 0
T_SPR       equ 1
T_HP        equ 2
T_OX        equ 3
T_OY        equ 4
T_W         equ 5
T_H         equ 6
T_SC        equ 7
T_FLG       equ 8
T_PAR       equ 9
F_CARRY     equ 4              ; type flag: always drops a PAV
F_HOOK      equ 7              ; type flag: tell the stage when killed

T_BOOM      equ 32
T_PAV       equ 33
T_COIN      equ 34
T_PIE       equ 35
T_SHOP      equ 37
T_SPARK     equ 36
; behaviours
BH_NONE     equ 0
BH_SINE     equ 1
BH_LINE     equ 2
BH_DART     equ 3
BH_SWOOP    equ 4
BH_BOUNCE   equ 5
BH_GROUND   equ 6
BH_ARC      equ 7
BH_PICK     equ 8
BH_FX       equ 9
BH_STAGE    equ 10
BH_BOSS     equ 11
BH_ARM      equ 12
BH_RISE     equ 13
BH_WALK     equ 14
BH_TURRET   equ 15

com_types:  ; 32 BOOM, 33 PAV, 34 COIN, 35 PIE, 36 SPARK
            db BH_FX,   SPR_BOOM, 0, 0,0,0,0, $00, (1<<F_FX), 3
            db BH_PICK, SPR_PAV,  0, 0,0,5,4, $00, (1<<F_PICK)|(1<<F_ANIM), 0
            db BH_PICK, SPR_COIN, 0, 0,0,4,4, $00, (1<<F_PICK)|(1<<F_ANIM), 0
            db BH_PICK, SPR_PIE,  0, 0,0,5,3, $00, (1<<F_PICK), 0
            db BH_FX,   SPR_SPARK,0, 0,0,0,0, $00, (1<<F_FX), 1
            db BH_PICK, SPR_SHOPBAL,0, 0,0,10,9, $00, (1<<F_PICK), 0

beh_tab:    dw beh_none, beh_sine, beh_line, beh_dart, beh_swoop, beh_bounce
            dw beh_ground, beh_arc, beh_pick, beh_fx, beh_stage
            dw beh_boss, beh_arm, beh_rise, beh_walk, beh_turret

; A = type -> HL = type record
type_rec:
            cp 32
            jr nc,.com
            ld l,a
            ld h,0
            ld de,STG_TYPES
            jr .m
.com:       sub 32
            ld l,a
            ld h,0
            ld de,com_types
.m:         ld b,h
            ld c,l
            add hl,hl
            add hl,hl
            add hl,bc
            add hl,hl               ; *10
            add hl,de
            ret

; spawn type A at B=x, C=y (stored coordinates) -> IX, NC ok / C full
spawn_obj:
            push bc
            push af
            ld ix,objs
            ld de,OSZ
            ld b,NOBJ
.f:         ld a,(ix+O_T)
            or a
            jr z,.got
            add ix,de
            djnz .f
            pop af
            pop bc
            scf
            ret
.got:       pop af
            ld (ix+O_T),a
            push ix
            pop hl
            inc hl
            ld b,OSZ-1
.z:         ld (hl),0
            inc hl
            djnz .z
            pop bc
            ld (ix+O_X),b
            ld (ix+O_Y),c
            ld a,(ix+O_T)
            push bc
            call type_rec
            pop bc
            inc hl
            ld a,(hl)
            ld (ix+O_SPR),a
            inc hl
            ld a,(hl)
            ld (ix+O_HP),a
            ld de,T_FLG-T_HP
            add hl,de
            ld a,(hl)
            and (1<<F_FX)|(1<<F_PICK)|(1<<F_ANIM)|(1<<F_GROUND)|(1<<F_HARM)
            ld (ix+O_FL),a
            inc hl
            ld a,(hl)
            ld (ix+O_P),a
            or a                    ; NC
            ret

; ---------------------------------------------------------------------
objects_update:
            ld ix,objs
            ld b,NOBJ
.l:         ld a,(ix+O_T)
            or a
            jr z,.n
            push bc
            ld a,(scrolled)
            or a
            jr z,.ns
            bit F_GROUND,(ix+O_FL)
            jr z,.ns
            dec (ix+O_X)
.ns:        ld a,(ix+O_T)
            call type_rec
            ld a,(hl)               ; behaviour
            ld (cur_trec),hl
            add a,a
            ld e,a
            ld d,0
            ld hl,beh_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            call .jp
            ; off screen? (bosses keep themselves on)
            ld a,(ix+O_T)
            or a
            jr z,.dn
            ld a,(ix+O_X)
            cp 6
            jr c,.gone
            cp 236
            jr nc,.gone
            ld a,(ix+O_Y)
            cp 4
            jr c,.gone
            cp 84
            jr c,.dn
.gone:      call obj_escape
.dn:        pop bc
.n:         ld de,OSZ
            add ix,de
            djnz .l
            ret
.jp:        jp (hl)

; an object left the playfield: free it, and its formation loses the bonus
obj_escape:
            ld a,(ix+O_GRP)
            or a
            jr z,.f
            ld e,a
            ld d,0
            ld hl,wave_left-1
            add hl,de
            ld (hl),$FF
.f:         ld (ix+O_T),0
            ret

; add the 8.8 velocity to the position
obj_move:
            ld l,(ix+O_XF)
            ld h,(ix+O_X)
            ld e,(ix+O_VX)
            ld d,(ix+O_VX+1)
            add hl,de
            ld (ix+O_XF),l
            ld (ix+O_X),h
            ld l,(ix+O_YF)
            ld h,(ix+O_Y)
            ld e,(ix+O_VY)
            ld d,(ix+O_VY+1)
            add hl,de
            ld (ix+O_YF),l
            ld (ix+O_Y),h
            ret

beh_none:   ret

; snake along a sine path: vx from the param's low nibble, amplitude from bits 4-5
beh_sine:
            ld a,(ix+O_ST)
            or a
            jr nz,.go
            inc (ix+O_ST)
            ld a,(ix+O_Y)
            ld (ix+O_GRP+0),a       ; (GRP is kept; base y goes in VY high)
            ld (ix+O_VY+1),a
.go:        ld a,(ix+O_P)
            and 15
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl               ; vx = nibble * 32/256 px
            ex de,hl
            ld l,(ix+O_XF)
            ld h,(ix+O_X)
            or a
            sbc hl,de
            ld (ix+O_XF),l
            ld (ix+O_X),h
            ld a,(ix+O_TM)
            add a,2
            ld (ix+O_TM),a
            rrca
            rrca
            and 63
            ld e,a
            ld d,0
            ld hl,sine16
            add hl,de
            ld a,(hl)               ; -16..16
            ld c,a
            ld a,(ix+O_P)
            rlca
            rlca
            rlca
            rlca
            and 3
            jr z,.amp
            ld b,a
.sh:        sra c
            djnz .sh
.amp:       ld a,(ix+O_VY+1)        ; base y
            add a,c
            ld (ix+O_Y),a
            ret

beh_line:
            ld a,(ix+O_ST)
            or a
            jr nz,.go
            inc (ix+O_ST)
            ; param: speed in px/frame*32 to the left
            ld a,(ix+O_P)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl               ; *8 -> 8.8 (param/32 px)
            call neg_hl
            ld (ix+O_VX),l
            ld (ix+O_VX+1),h
.go:        jp obj_move

neg_hl:
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
            ret

; blowfly: fly in, hover with a buzz, then dart at the player
beh_dart:
            ld a,(ix+O_ST)
            or a
            jr nz,.s1
            ; approach to x = 96..120
            ld a,(ix+O_X)
            sub 2
            ld (ix+O_X),a
            cp 120+XOFF
            ret nc
            ld a,(ix+O_P)
            ld (ix+O_TM),a
            inc (ix+O_ST)
            ret
.s1:        dec a
            jr nz,.s2
            call random             ; jitter
            and 3
            jr nz,.nj
            call random
            and 1
            add a,a
            dec a
            add a,(ix+O_Y)
            ld (ix+O_Y),a
.nj:        dec (ix+O_TM)
            ret nz
            inc (ix+O_ST)
            ; aim at the player
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld e,64                 ; 2 px per frame
            call aim
            ld (ix+O_VX),l
            ld (ix+O_VX+1),h
            ld (ix+O_VY),e
            ld (ix+O_VY+1),d
            ret
.s2:        jp obj_move

; magpie: drop from above towards the player's height, then pull out left
beh_swoop:
            ld a,(ix+O_ST)
            or a
            jr nz,.s1
            inc (ix+O_ST)
            ld hl,-$0140
            ld (ix+O_VX),l
            ld (ix+O_VX+1),h
            ld hl,$0100
            ld (ix+O_VY),l
            ld (ix+O_VY+1),h
.s1:        cp 1
            jr nz,.s2
            ld a,(p_y)
            sub (ix+O_Y)
            jr nc,.mv
            ; reached the player's height: level out and climb away
            inc (ix+O_ST)
            ld hl,-$0200
            ld (ix+O_VX),l
            ld (ix+O_VX+1),h
            ld hl,-$0080
            ld (ix+O_VY),l
            ld (ix+O_VY+1),h
            ld a,(ix+O_P)
            or a
            call nz,obj_fire        ; parting shot
.mv:        jp obj_move
.s2:        jp obj_move

; thong: hops along the ground in arcs
beh_bounce:
            ld l,(ix+O_VY)
            ld h,(ix+O_VY+1)
            ld de,$0018
            add hl,de
            ld (ix+O_VY),l
            ld (ix+O_VY+1),h
            ld a,(ix+O_ST)
            or a
            jr nz,.go
            inc (ix+O_ST)
            ld hl,-$00C0
            ld (ix+O_VX),l
            ld (ix+O_VX+1),h
.go:        call obj_move
            ld a,(ix+O_Y)
            cp PF_BOT-4+YOFF
            ret c
            ld (ix+O_Y),PF_BOT-4+YOFF
            ld hl,-$0280            ; bounce
            ld (ix+O_VY),l
            ld (ix+O_VY+1),h
            ld a,SFX_KNOCK
            ld hl,frames
            bit 0,(hl)
            ret nz
            ret

; ground fixture: rides the scroll; param = fire interval (0 = never)
beh_ground:
            ld a,(ix+O_P)
            or a
            ret z
            inc (ix+O_TM)
            ld a,(ix+O_TM)
            cp (ix+O_P)
            ret c
            ld (ix+O_TM),0
            ld a,(ix+O_X)
            cp 130+XOFF
            ret nc                  ; not until on screen
            cp 12+XOFF
            ret c
            ; sprinkler fan: three drops up-left, up, up-right with gravity
            ld b,(ix+O_X)
            inc b
            ld c,(ix+O_Y)
            ld de,$C0E0             ; vy -64/32, vx -32/32
            call eb_new_g
            ld de,$B0F8
            call eb_new_g
            ld de,$C010
            jp eb_new_g

; ballistic: gravity on vy
beh_arc:
            ld l,(ix+O_VY)
            ld h,(ix+O_VY+1)
            ld de,$0010
            add hl,de
            ld (ix+O_VY),l
            ld (ix+O_VY+1),h
            jp obj_move

; pickups drift left with a wobble
beh_pick:
            ld a,(ix+O_ST)
            or a
            jr nz,.go
            inc (ix+O_ST)
            ld hl,-$0060
            ld (ix+O_VX),l
            ld (ix+O_VX+1),h
.go:        inc (ix+O_TM)
            ld a,(ix+O_TM)
            and 15
            jr nz,.mv
            ld a,(ix+O_TM)
            and 16
            ld hl,$0040
            jr z,.d
            ld hl,-$0040
.d:         ld (ix+O_VY),l
            ld (ix+O_VY+1),h
.mv:        jp obj_move

; effects: animate frames every O_P+1 frames, then vanish
beh_fx:
            inc (ix+O_TM)
            ld a,(ix+O_TM)
            cp 3
            ret c
            ld (ix+O_TM),0
            inc (ix+O_SPR)
            inc (ix+O_ST)
            ld a,(ix+O_ST)
            cp (ix+O_P)
            ret c
            ld (ix+O_T),0
            ret

beh_stage:  jp STG_OBJ

; ---------------------------------------------------------------------
; aiming: B,C = from (stored), E = speed (1/32 px) -> HL = vx, DE = vy (8.8)
; ---------------------------------------------------------------------
aim:
            ld a,e
            ld (aim_s),a
            ld a,(p_x)
            add a,3
            sub b
            ld (aim_dx),a
            ld a,(p_y)
            add a,2
            sub c
            ld (aim_dy),a
            ; m = max(|dx|,|dy|)
            ld a,(aim_dx)
            call abs_a
            ld b,a
            ld a,(aim_dy)
            call abs_a
            cp b
            jr nc,.m
            ld a,b
.m:         or a
            jr nz,.nz
            inc a
.nz:        ld (aim_m),a
            ld a,(aim_dx)
            call aim_c
            push hl
            ld a,(aim_dy)
            call aim_c
            ex de,hl
            pop hl
            ret
; A = signed delta -> HL = delta*speed/m as 8.8 (speed in 1/32 px)
aim_c:
            ld (aim_sg),a
            call abs_a
            ld h,a
            ld a,(aim_s)
            ld e,a
            call mul8               ; HL = |d|*s
            ld a,(aim_m)
            ld c,a
            call div16_8            ; HL = HL / C
            add hl,hl
            add hl,hl
            add hl,hl               ; 1/32 px -> 8.8
            ld a,(aim_sg)
            bit 7,a
            ret z
            jp neg_hl
abs_a:      bit 7,a
            ret z
            neg
            ret
; HL = HL / C (unsigned), A = remainder
div16_8:
            xor a
            ld b,16
.l:         add hl,hl
            rla
            jr c,.s
            cp c
            jr c,.n
.s:         sub c
            inc l
.n:         djnz .l
            ret

; object IX fires an aimed pellet
obj_fire:
            ld a,(ix+O_X)
            cp 128+XOFF
            ret nc
            ld b,a
            ld c,(ix+O_Y)
            inc c
fire_at:    ; B,C = from
            push bc
            ld a,(round)            ; 1.25 px per frame, quicker on harder
            add a,a                 ; skills and later rounds
            add a,a
            add a,a
            ld e,a
            ld a,(diff)
            add a,a
            add a,a
            add a,a
            add a,e
            add a,36
            ld e,a
            call aim
            ; 8.8 -> 1/32 units: >>3
            ld a,l
            sra h
            rra
            sra h
            rra
            sra h
            rra
            ld l,a
            ld a,e
            sra d
            rra
            sra d
            rra
            sra d
            rra
            ld d,a
            ld e,l
            ld a,d
            ld d,e
            ld e,a                  ; D = vx, E = vy ... swap to D=vy E=vx
            ld a,d
            ld d,e
            ld e,a
            pop bc
            jp eb_new

; ---------------------------------------------------------------------
; enemy bullets: B,C = position, E = vx, D = vy (1/32 px per frame)
; ---------------------------------------------------------------------
eb_new_g:   ld a,3                  ; with gravity
            jr eb_put
eb_new:     xor a
eb_put:     ld (eb_grav),a
            ld hl,ebul
            push bc
            ld b,NEB
.f:         ld a,(hl)
            or a
            jr z,.got
            ld a,l
            add a,EBSZ
            ld l,a
            jr nc,.n
            inc h
.n:         djnz .f
            pop bc
            ret
.got:       pop bc
            ld (hl),SPR_PELLET      ; E_T
            inc hl
            ld (hl),0
            inc hl
            ld (hl),b
            inc hl
            ld (hl),0
            inc hl
            ld (hl),c
            inc hl
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld a,(eb_grav)
            ld (hl),a
            ret

ebul_update:
            ld ix,ebul
            ld b,NEB
.l:         ld a,(ix+E_T)
            or a
            jr z,.n
            ld a,(ix+E_VY)          ; gravity
            add a,(ix+E_G)
            jp pe,.ng               ; (overflow guard)
            ld (ix+E_VY),a
.ng:        ld a,(ix+E_VX)
            call sx8
            ld a,(ix+E_XF)
            add a,l
            ld (ix+E_XF),a
            ld a,(ix+E_X)
            adc a,h
            ld (ix+E_X),a
            cp XOFF-4
            jr c,.k
            cp 128+XOFF+2
            jr nc,.k
            ld a,(ix+E_VY)
            call sx8
            ld a,(ix+E_YF)
            add a,l
            ld (ix+E_YF),a
            ld a,(ix+E_Y)
            adc a,h
            ld (ix+E_Y),a
            cp PF_TOP+YOFF-3
            jr c,.k
            cp PF_BOT+YOFF+2
            jr c,.n
.k:         ld (ix+E_T),0
.n:         ld de,EBSZ
            add ix,de
            djnz .l
            ret
; A = signed 1/32 units -> HL = 8.8 (A*8)
sx8:        ld l,a
            rlca
            sbc a,a
            ld h,a
            add hl,hl
            add hl,hl
            add hl,hl
            ret

draw_ebul:
            ld ix,ebul
            ld b,NEB
.l:         ld a,(ix+E_T)
            or a
            jr z,.n
            push bc
            ld b,(ix+E_X)
            ld c,(ix+E_Y)
            call blit
            pop bc
.n:         ld de,EBSZ
            add ix,de
            djnz .l
            ret

clear_ebul:
            ld hl,ebul
            ld de,ebul+1
            ld bc,NEB*EBSZ-1
            ld (hl),0
            ldir
            ret

; ---------------------------------------------------------------------
draw_objects:
            ld ix,objs
            ld b,NOBJ
.l:         ld a,(ix+O_T)
            or a
            jr z,.n
            push bc
            ld a,(frames)           ; hit flash one frame in four
            and 3
            ld a,0
            jr nz,.nfl
            ld a,(ix+O_FL)
            and 1<<F_FLASH
.nfl:       ld (bl_flash),a
            res F_FLASH,(ix+O_FL)
            ld a,(ix+O_SPR)
            bit F_ANIM,(ix+O_FL)
            jr z,.na
            ld c,a
            ld a,(frames)
            rrca
            rrca
            and 1
            add a,c
.na:        ld b,(ix+O_X)
            ld c,(ix+O_Y)
            call blit
            xor a
            ld (bl_flash),a
            pop bc
.n:         ld de,OSZ
            add ix,de
            djnz .l
            ret

clear_objs:
            ld hl,objs
            ld de,objs+1
            ld bc,NOBJ*OSZ-1
            ld (hl),0
            ldir
            ld hl,pshots
            ld de,pshots+1
            ld bc,NPS*PSZ-1
            ld (hl),0
            ldir
            jp clear_ebul

; ---------------------------------------------------------------------
; collisions
; ---------------------------------------------------------------------
; object hit box -> hb_x, hb_y, hb_w, hb_h (from its type)
obj_box:
            ld a,(ix+O_T)
            call type_rec
            ld de,T_OX
            add hl,de
            ld a,(ix+O_X)
            add a,(hl)
            ld (hb_x),a
            inc hl
            ld a,(ix+O_Y)
            add a,(hl)
            ld (hb_y),a
            inc hl
            ld a,(hl)
            ld (hb_w),a
            inc hl
            ld a,(hl)
            ld (hb_h),a
            ret

collide:
            ; ---- player shots against shootable objects
            ld ix,objs
            ld b,NOBJ
.ol:        ld a,(ix+O_T)
            or a
            jp z,.on
            ld a,(ix+O_FL)
            and (1<<F_FX)|(1<<F_PICK)
            jp nz,.on
            push bc
            call obj_box
            ld a,(hb_w)
            or a
            jr z,.sd
            ld iy,pshots
            ld b,NPS
.sl:        ld a,(iy+P_T)
            or a
            jr z,.sn
            ; overlap: sx < bx+bw && bx < sx+sw (same for y)
            ld e,a
            ld d,0
            ld hl,PK_W
            add hl,de
            ld c,(hl)               ; shot w
            ld a,(hb_x)
            ld hl,hb_w
            add a,(hl)
            cp (iy+P_X)
            jr c,.sn
            jr z,.sn
            ld a,(iy+P_X)
            add a,c
            ld hl,hb_x
            cp (hl)
            jr c,.sn
            jr z,.sn
            ld hl,PK_H
            add hl,de
            ld c,(hl)
            ld a,(hb_y)
            ld hl,hb_h
            add a,(hl)
            cp (iy+P_Y)
            jr c,.sn
            jr z,.sn
            ld a,(iy+P_Y)
            add a,c
            ld hl,hb_y
            cp (hl)
            jr c,.sn
            jr z,.sn
            ; hit
            ld hl,PK_DMG
            add hl,de
            ld c,(hl)
            ld hl,PK_PIERCE
            add hl,de
            ld a,(hl)
            or a
            jr z,.kshot
            ld a,(ix+O_HP)          ; steam goes through small fry, not bosses
            cp 6
            jr c,.pierce
.kshot:     ld (iy+P_T),0
.pierce:    push bc
            ld a,c
            call obj_damage
            pop bc
            ld a,(ix+O_T)
            or a
            jr z,.sd                ; destroyed
.sn:        ld de,PSZ
            add iy,de
            djnz .sl
.sd:        pop bc
.on:        ld de,OSZ
            add ix,de
            dec b
            jp nz,.ol
            ; ---- the player against objects and bullets
            ld a,(p_dead)
            or a
            ret nz
            ld a,(stg_phase)
            cp 3
            ret nc
            ld a,(p_x)
            add a,3
            ld (pb_x),a             ; player box: 4 x 2 in the middle of the body
            ld a,(p_y)
            add a,3
            ld (pb_y),a
            ld ix,objs
            ld b,NOBJ
.pl:        ld a,(ix+O_T)
            or a
            jr z,.pn
            bit F_FX,(ix+O_FL)
            jr nz,.pn
            push bc
            call obj_box
            pop bc
            ld a,(hb_w)
            or a
            jr z,.pn
            ld c,4
            ld e,2
            call .ov
            jr nc,.pn
            bit F_PICK,(ix+O_FL)
            jr nz,.pick
            bit F_HARM,(ix+O_FL)
            jr z,.pn
            push bc
            call player_hit
            pop bc
            jr .pn
.pick:      push bc
            call take_pickup
            pop bc
.pn:        ld de,OSZ
            add ix,de
            djnz .pl
            ; bullets: 2x1 core
            ld ix,ebul
            ld b,NEB
.bl:        ld a,(ix+E_T)
            or a
            jr z,.bn
            ld a,(ix+E_X)
            inc a
            ld (hb_x),a
            ld a,(ix+E_Y)
            inc a
            ld (hb_y),a
            ld a,2
            ld (hb_w),a
            dec a
            ld (hb_h),a
            ld c,4
            ld e,2
            call .ov
            jr nc,.bn
            ld (ix+E_T),0
            push bc
            call player_hit
            pop bc
.bn:        ld de,EBSZ
            add ix,de
            djnz .bl
            ret
; player box (pb_x,pb_y, C x E) against hb_*: C flag = overlap
.ov:        ld a,(hb_x)
            ld hl,hb_w
            add a,(hl)
            ld hl,pb_x
            cp (hl)
            jr c,.no
            jr z,.no
            ld a,(pb_x)
            add a,c
            ld hl,hb_x
            cp (hl)
            jr c,.no
            jr z,.no
            ld a,(hb_y)
            ld hl,hb_h
            add a,(hl)
            ld hl,pb_y
            cp (hl)
            jr c,.no
            jr z,.no
            ld a,(pb_y)
            add a,e
            ld hl,hb_y
            cp (hl)
            jr c,.no
            jr z,.no
            scf
            ret
.no:        or a
            ret

; damage object IX by A
obj_damage:
            ld c,a
            set F_FLASH,(ix+O_FL)
            ld a,(ix+O_T)
            push bc
            call type_rec
            pop bc
            ld de,T_BEH
            add hl,de
            ld a,(hl)
            cp BH_STAGE
            jp z,STG_HIT            ; stage specials take damage their own way
            cp BH_BOSS
            jp z,boss_hit
            cp BH_ARM
            jp z,arm_hit
            ld a,(ix+O_HP)
            sub c
            jr c,kill_obj
            jr z,kill_obj
            ld (ix+O_HP),a
            ld a,SFX_KNOCK
            jp sfx

; destroy object IX: score x chain, explosion, formation bonus
kill_obj:
            ld a,(ix+O_T)
            call type_rec
            push hl
            ld de,T_SC
            add hl,de
            ld a,(hl)
            call score_chain
            pop hl
            ld de,T_FLG
            add hl,de
            ld a,(hl)
            ld (kill_flags),a
            bit F_HOOK,a
            call nz,STG_KILL
            ld hl,(kills)
            inc hl
            ld (kills),hl
            ld a,SFX_KILL
            call sfx
            ; formation bookkeeping
            ld a,(ix+O_GRP)
            or a
            jr z,.ng
            ld e,a
            ld d,0
            ld hl,wave_left-1
            add hl,de
            ld a,(hl)
            cp $FF
            jr z,.ng
            dec (hl)
            jr nz,.ng
            ; whole formation shot down: PAV + 500 bonus
            ld de,$0050
            call add_score
            jr .pav
.ng:        ld a,(kill_flags)
            and 1<<F_CARRY
            jr nz,.pav
            ld a,(kill_flags)       ; ground things always pay a coin,
            and 1<<F_GROUND         ; flyers one time in four
            ld a,T_COIN
            jr nz,.drop
            call random
            and 3
            ld a,T_COIN
            jr z,.drop
            xor a
            jr .drop
.pav:       ld a,T_PAV
.drop:      push af
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld (ix+O_T),0
            push bc
            ld a,T_BOOM
            call spawn_obj
            pop bc
            pop af
            or a
            ret z
            jp spawn_obj

take_pickup:
            ld a,(ix+O_T)
            ld (ix+O_T),0
            cp T_PAV
            jp z,collect_pav
            cp T_COIN
            jr nz,.pie
            ld hl,coins
            inc (hl)
            ld hl,wallet
            ld a,(hl)
            cp 99
            jr nc,.wf
            inc (hl)
.wf:        ld a,SFX_COIN
            call sfx
            ld a,$20                ; 200 x chain
            jp score_chain
.pie:       cp T_SHOP
            jp z,shop
            cp T_PIE
            ret nz
            ld a,SFX_HEAL
            call sfx
            ld a,(p_health)
            cp 3
            jr nc,.full
            inc a
            ld (p_health),a
            ld a,1
            ld (hud_dirty),a
            ret
.full:      ld de,$0100             ; 1000 points
            jp add_score

; ---------------------------------------------------------------------
player_hit:
            ld a,(p_inv)
            or a
            ret nz
            ld a,(p_dead)
            or a
            ret nz
            ld a,(trainer)
            or a
            jr nz,.flash
            ld a,(p_shield)
            or a
            jr z,.hp
            dec a
            ld (p_shield),a
            ld a,30
            ld (p_inv),a
            ld a,SFX_KNOCK
            jp sfx
.flash:     ld a,30
            ld (p_inv),a
            ld a,SFX_HURT
            jp sfx
.hp:        xor a
            ld (chain),a
            ld hl,p_hits
            inc (hl)
            ld a,1
            ld (hud_dirty),a
            ld a,(p_health)
            dec a
            ld (p_health),a
            jr z,.die
            ld a,50
            ld (p_inv),a
            ld a,SFX_HURT
            jp sfx
.die:       ld a,SFX_DIE
            call sfx
            ld hl,p_lives
            dec (hl)
            ld a,60
            ld (p_dead),a
            ; fair recovery: lose one level of SHOT, BUDDY and SPEED, keep the
            ; rest; two PAVs float out to win some of it back
            ld hl,p_shot
            call .dec
            ld hl,p_buddy
            call .dec
            ld hl,p_speed
            call .dec
            xor a
            ld (p_shield),a
            ld a,1
            ld (bar_dirty),a
            ld a,(p_x)
            ld b,a
            ld a,(p_y)
            ld c,a
            push bc
            ld a,T_BOOM
            call spawn_obj
            pop bc
            push bc
            ld a,b
            add a,20
            ld b,a
            ld a,c
            sub 6
            ld c,a
            ld a,T_PAV
            call spawn_obj
            pop bc
            ld a,b
            add a,32
            ld b,a
            ld a,c
            add a,6
            ld c,a
            ld a,T_PAV
            jp spawn_obj
.dec:       ld a,(hl)
            or a
            ret z
            dec (hl)
            ret

; ---------------------------------------------------------------------
; scoring (score is BCD tens, 3 bytes, high first)
; ---------------------------------------------------------------------
; A = BCD tens; multiplied by the chain, which grows with quick kills
score_chain:
            ld e,a
            ld d,0
            ld a,(chain_t)
            or a
            ld a,(chain)
            jr z,.reset
            cp 8
            jr nc,.k
            inc a
            jr .k
.reset:     ld a,1
.k:         ld (chain),a
            ld hl,chain_max
            cp (hl)
            jr c,.m
            ld (hl),a
.m:         ld a,40
            ld (chain_t),a
            ld a,1
            ld (hud_dirty),a
            ld a,(chain)
            ld b,a
.add:       push bc
            push de
            call add_score
            pop de
            pop bc
            djnz .add
            ret

; DE = BCD tens (up to 9999 = 99,990 points)
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
            ld a,1
            ld (hud_dirty),a
            ; extra life? (score high byte = hundred-thousands/ten-thousands)
            ld a,(extra_at)
            ld b,a
            ld a,(score)
            cp b
            ret c
            ld a,b
            add a,1                 ; next one 100,000 later
            daa
            ld (extra_at),a
            ld hl,p_lives
            ld a,(hl)
            cp 9
            ret nc
            inc (hl)
            ld a,SFX_LIFE
            jp sfx

; chain timer, once per frame
chain_tick:
            ld a,(chain_t)
            or a
            ret z
            dec a
            ld (chain_t),a
            ret nz
            xor a
            ld (chain),a
            inc a
            ld (hud_dirty),a
            ret

; ---------------------------------------------------------------------
; the stage timeline: dw column, db command, args
; ---------------------------------------------------------------------
TL_END      equ 0
TL_FORM     equ 1              ; type, count, y, gap, group
TL_SPAWN    equ 2              ; type, x, y
TL_MSG      equ 3              ; dw string, db time
TL_HOLD     equ 4
TL_CALL     equ 5              ; dw routine
TL_IFROUTE  equ 6              ; db route, dw skip-to (if route differs)
TL_GOTO     equ 7              ; dw where
TL_MUSIC    equ 8              ; dw tune

timeline:
            call spawn_tick
            ld a,(tl_hold)
            or a
            ret nz
.ev:        ld hl,(tl_p)
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            push hl
            ld hl,(tl_col)
            or a
            sbc hl,de
            pop hl
            ret c                   ; not yet
            ld a,(hl)
            inc hl
            or a
            jr nz,.c1
            dec hl                  ; END: stay here
            dec hl
            dec hl
            ld (tl_p),hl
            ld hl,$7FFF
            ld (tl_col),hl
            ret
.c1:        cp TL_FORM
            jr nz,.c2
            ld a,(hl)
            ld (spawn_q),a
            inc hl
            ld a,(hl)
            ld (spawn_n),a
            inc hl
            ld a,(hl)
            add a,YOFF
            ld (spawn_y),a
            inc hl
            ld a,(hl)
            ld (spawn_gap),a
            inc hl
            ld a,(hl)
            ld (spawn_grp),a
            inc hl
            ld (tl_p),hl
            ; the formation's bonus needs every member
            ld a,(spawn_grp)
            or a
            jr z,.f0
            ld e,a
            ld d,0
            ld hl,wave_left-1
            add hl,de
            ld a,(spawn_n)
            ld (hl),a
.f0:        xor a
            ld (spawn_t),a
            jr .ev
.c2:        cp TL_SPAWN
            jr nz,.c3
            ld a,(hl)
            inc hl
            ld b,(hl)
            inc hl
            ld c,(hl)
            inc hl
            ld (tl_p),hl
            call spawn_obj
            jr .ev
.c3:        cp TL_MSG
            jr nz,.c4
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld a,(hl)
            inc hl
            ld (tl_p),hl
            ld (msg_p),de
            ld (msg_t),a
            jp .ev
.c4:        cp TL_HOLD
            jr nz,.c5
            ld (tl_p),hl
            ld a,1
            ld (tl_hold),a
            ret
.c5:        cp TL_CALL
            jr nz,.c6
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (tl_p),hl
            ex de,hl
            call .jp
            jp .ev
.c6:        cp TL_IFROUTE
            jr nz,.c7
            ld a,(route)
            cp (hl)
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            jr z,.same
            ex de,hl
.same:      ld (tl_p),hl
            jp .ev
.c7:        cp TL_GOTO
            jr nz,.c8
            ld e,(hl)
            inc hl
            ld d,(hl)
            ex de,hl
            ld (tl_p),hl
            jp .ev
.c8:        ld e,(hl)               ; TL_MUSIC
            inc hl
            ld d,(hl)
            inc hl
            ld (tl_p),hl
            ex de,hl
            call music
            jp .ev
.jp:        jp (hl)

; release formation members one at a time
spawn_tick:
            ld a,(spawn_n)
            or a
            ret z
            ld a,(spawn_t)
            or a
            jr z,.go
            dec a
            ld (spawn_t),a
            ret
.go:        ld a,(spawn_gap)
            ld (spawn_t),a
            ld hl,spawn_n
            dec (hl)
            ld a,(spawn_q)
            ld b,132+XOFF
            ld hl,spawn_y
            ld c,(hl)
            call spawn_obj
            ret c
            ld a,(spawn_grp)
            ld (ix+O_GRP),a
            ret

; ---------------------------------------------------------------------
; on-screen message (drawn into the back buffer each frame)
; ---------------------------------------------------------------------
draw_msg:
            ld a,(msg_t)
            or a
            ret z
            dec a
            ld (msg_t),a
            cp 12                   ; blink for the last moments
            jr nc,.on
            ld a,(frames)
            and 4
            ret z
.on:        ld hl,(msg_p)
            ld de,(msg_last)
            or a
            sbc hl,de
            call nz,msg_render
            ; copy the text's columns (msg_c0, msg_w) into rows 12-16
            ld a,(msg_w)
            or a
            ret z
            ld (.w+1),a
            ld a,(msg_c0)
            ld e,a
            ld d,0
            ld hl,msg_buf
            add hl,de
            push hl
            ld hl,12*32
            add hl,de
            call bbp
            ex de,hl
            pop hl
            ld a,5
.r:         push hl
            push de
.w:         ld bc,0
            ldir
            pop hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop hl
            add hl,bc
            dec a
            jr nz,.r
            ret
; render msg_p (db column, text) into msg_buf once
msg_render:
            ld hl,(msg_p)
            ld (msg_last),hl
            ld hl,msg_buf
            ld de,msg_buf+1
            ld bc,159
            ld (hl),SKYBYTE
            ldir
            ld a,1
            ld c,2
            call text_col
            ld hl,(msg_p)
            ld a,(hl)
            ld (msg_c0),a
            inc hl
            call strlen
            ld (msg_w),a
            ld a,(msg_c0)
            ld e,a
            ld d,0
            push hl
            ld hl,msg_buf
            add hl,de
            ex de,hl
            pop hl
            jp print
