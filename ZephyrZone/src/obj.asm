; =====================================================================
;  obj.asm - world objects: projection, depth sorting, drawing
;  Object (OSIZE bytes, IX):
;   +0 kind (0 = free)   +1 spr (sprite type)   +2/3 x (signed)
;   +4 y (height 0-255)   +5 frame   +6/7 z   +8 vx +9 vy +10 vz (signed)
;   +11 timer  +12 hp  +13 state  +14 flags  +15 param
;   +16/17 sx  +18/19 sy  +20 level  +21 visible  +22 ground row  +23 aux
;  flags: bit0 fixed in the world (scrolls with the ground)
;         bit1 hits the player     bit2 shadow     bit3 shootable
;         bit4 enemy shot          bit5 obstacle (scenery you can bump)
; =====================================================================
O_KIND      equ 0
O_SPR       equ 1
O_X         equ 2
O_Y         equ 4
O_FRAME     equ 5
O_Z         equ 6
O_VX        equ 8
O_VY        equ 9
O_VZ        equ 10
O_TIMER     equ 11
O_HP        equ 12
O_STATE     equ 13
O_FLAGS     equ 14
O_PARAM     equ 15
O_SX        equ 16
O_SY        equ 18
O_LEV       equ 20
O_VIS       equ 21
O_GY        equ 22
O_AUX       equ 23
O_BX        equ 24             ; base x (wavers) / x fraction (shots)
O_BY        equ 26             ; base height
O_PH        equ 27             ; phase
O_AMP       equ 28             ; amplitude
O_BEH       equ 29             ; behaviour
O_PTS       equ 30             ; score / 10
O_HR        equ 31             ; hit radius (units)
O_PHASE     equ 32             ; creatures: 0 approach, 1 hover, 2 charge
O_HOLD      equ 33             ; hover time left (fields)
O_VFALL     equ 34             ; falling speed
O_HOLDZ     equ 35             ; hover depth / 8
OSIZE       equ 40
F_WORLD     equ 1
F_HITS      equ 2
F_SHADOW    equ 4
F_SHOOT     equ 8
F_ESHOT     equ 16
F_OBST      equ 32
CAMH        equ 96
ZFAR        equ 2047

; z index of DE (z) -> A (0..223), C if too far
zindex:
            ld a,d
            cp 2
            jr nc,.far
            ; z < 512: z >> 2
            ld a,e
            srl d
            rra
            srl d
            rra
            or a
            ret
.far:       cp 8
            jr nc,.out
            ; 128 + (z - 512) >> 4
            ld a,e
            sub 0
            ld l,a
            ld a,d
            sub 2
            ld h,a
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl               ; (z-512) << 4 -> H = (z-512) >> 4
            ld a,h
            add a,128
            or a
            ret
.out:       scf
            ret

; mulshift: DE = magnitude, C = mantissa, B = shift (7..12) -> HL
mulshift:
            ld a,b
            ld (pj_e),a
            ld a,c
            ld (pj_m),a
            ld a,d
            or a
            jr nz,.big
            ld a,e
            call mul88              ; HL = E*M
            ld a,(pj_e)
            sub 8
            jr c,.e7
            ld l,h
            ld h,0
            jr .sh
.e7:        add hl,hl               ; shift 7: (HL<<1)>>8
            ld l,h
            ld h,0
            ret
.big:       push de
            ld a,e
            call mul88              ; lo * M
            pop de
            push hl
            ld a,(pj_m)
            ld c,a
            ld a,d
            call mul88              ; hi * M
            pop de                  ; DE = lo product
            ld a,d
            add a,l
            ld l,a
            ld a,h
            adc a,0
            ld h,a                  ; HL = (product >> 8)
            ld a,(pj_e)
            sub 8
            jr nc,.sh
            ; shift 7: HL = HL*2 + (E >> 7)
            add hl,hl
            rl e
            ret nc
            inc hl
            ret
.sh:        or a
            ret z
.l:         srl h
            rr l
            dec a
            jr nz,.l
            ret

; project IX: computes sx, sy, level, visible, ground row.  Needs mapping 7.
project:
            ld e,(ix+O_Z)
            ld d,(ix+O_Z+1)
            ld a,d
            or a
            jr nz,.zok
            ld a,e
            cp 48
            jp c,.hide              ; too close
.zok:       call zindex
            jp c,.hide
            ld (pj_zi),a
            ld l,a
            ld h,HIGH(PRJ_E)
            ld b,(hl)               ; shift
            ld h,HIGH(PRJ_LV)
            ld a,(hl)
            ld (ix+O_LEV),a
            ld h,HIGH(PRJ_MY)
            ld a,(hl)
            ld (pj_my),a
            ld h,HIGH(PRJ_MX)
            ld c,(hl)
            push bc
            ; ---- x: dx = x - camx
            ld l,(ix+O_X)
            ld h,(ix+O_X+1)
            ld de,(camx)
            or a
            sbc hl,de
            ld a,h
            ld (pj_neg),a
            bit 7,h
            jr z,.xp
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
.xp:        ; |dx| >= 256: only far objects can be on screen; halve dx (and
            ; the shift) until it fits in 8 bits, so one multiply does
            ld a,h
            or a
            jr z,.x8
            ld a,b
            cp 9
            jr c,.hidep             ; near and far to the side: off screen
            ld a,h
            cp 4
            jr nc,.hidep            ; |dx| >= 1024
.xs:        srl h
            rr l
            dec b
            ld a,h
            or a
            jr nz,.xs
.x8:        ex de,hl
            call mulshift
            jr .xm
.hidep:     pop bc
            jp .hide
.xm:
            ld a,(pj_neg)
            rla
            jr nc,.xpos
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
.xpos:      ld de,64
            add hl,de
            ld (ix+O_SX),l
            ld (ix+O_SX+1),h
            ; ---- ground row: hz + table
            pop bc
            ld a,(pj_zi)
            ld l,a
            ld h,HIGH(PRJ_GY)
            ld a,(hz)
            add a,(hl)
            jr nc,.g1
            ld a,255
.g1:        ld (ix+O_GY),a
            ld a,(ix+O_Y)
            or a
            jr nz,.ny
            ld a,(ix+O_GY)
            ld (ix+O_SY),a
            ld (ix+O_SY+1),0
            ld (ix+O_VIS),1
            ret
.ny:        ld a,(pj_my)
            ld c,a
            ; ---- y: dy = CAMH - y (negative above the camera)
            ld a,(ix+O_Y)
            cp CAMH+1
            jr nc,.yneg
            ld e,a
            ld a,CAMH
            sub e
            ld e,a
            ld d,0
            call mulshift
            jr .ypos
.yneg:      sub CAMH
            ld e,a
            ld d,0
            call mulshift
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
.ypos:      ld a,(hz)
            ld e,a
            ld d,0
            add hl,de
            ld (ix+O_SY),l
            ld (ix+O_SY+1),h
            ld (ix+O_VIS),1
            ret
.hide:      ld (ix+O_VIS),0
            ret

; IX = object A (index)
obj_ix:
            add a,a
            ld l,a
            ld h,0
            ld de,objtab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            push hl
            pop ix
            ret
objtab:
I_          = 0
            REPT NOBJ
            dw objs+I_*OSIZE
I_          = I_+1
            ENDR

; ---------------------------------------------------------------------
; level entry of sprite type A, frame B, level C -> HL (mapping set to suit)
; ---------------------------------------------------------------------
spr_rec:
            cp 16
            jr nc,.w
            ld e,a
            ld a,MAP_FE
            ld (cur_map),a
            out (BANKPORT),a
            ld a,e
            ld hl,C_DIR
            jr .d
.w:         sub 16
            ld e,a
            ld a,MAP_GAME
            ld (cur_map),a
            out (BANKPORT),a
            ld a,e
            ld hl,W_DIR
.d:         add a,a
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)               ; frame table
            inc hl
            ld a,b                  ; frame beyond the set? use frame 0
            cp (hl)
            jr c,.fok
            ld b,0
.fok:       inc hl
            ld a,(hl)               ; nlevels
            dec a
            cp c
            jr nc,.lok
            ld c,a                  ; clamp level
.lok:       ex de,hl
            ld a,b
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a                  ; level table
            ld a,c
            add a,a
            add a,a
            ld e,a
            add hl,de
            ret

; draw every visible object in depth order (an object's shadow just before
; it): walk the depth buckets that project_all filled, far to near
draw_objects:
            ld c,NBKT-1
.b:         ld b,0
            ld hl,bkt
            add hl,bc
            ld a,(hl)
.o:         or a
            jr z,.nb
            push bc
            dec a
            call obj_ix
            call draw_one
            ld a,(ix+O_AUX)         ; next in this bucket
            pop bc
            jr .o
.nb:        dec c
            jp p,.b
            jp map_game

draw_one:
            ; on screen? -48 <= sx < 176
            ld l,(ix+O_SX)
            ld h,(ix+O_SX+1)
            ld de,48
            add hl,de
            ld a,h
            or a
            ret nz
            ld a,l
            cp 224
            ret nc
            ld de,-48
            add hl,de
            ld (spr_x),hl
            bit 2,(ix+O_FLAGS)
            jr z,.nsh
            ld a,(ix+O_LEV)
            add a,2                 ; shadows a little smaller
            cp NLEV
            jr nc,.nsh
            ld c,a
            ld l,(ix+O_GY)
            ld h,0
            ld (spr_y),hl
            ld a,T_SHADOW
            ld b,0
            call spr_rec
            call draw_sprite
            ld l,(ix+O_SX)
            ld h,(ix+O_SX+1)
            ld (spr_x),hl
.nsh:       ld l,(ix+O_SY)
            ld h,(ix+O_SY+1)
            ld (spr_y),hl
            ld a,(ix+O_SPR)
            ld b,(ix+O_FRAME)
            ld c,(ix+O_LEV)
            call spr_rec
            call draw_sprite
            ld a,(ix+O_KIND)        ; shot down: it burns as it falls
            cp K_FALL
            jp nz,maybe_ei
            ld l,(ix+O_SX)
            ld h,(ix+O_SX+1)
            ld (spr_x),hl
            ld a,(anim)
            rrca
            and 1
            ld b,a
            ld c,(ix+O_LEV)
            ld a,T_FLAME
            call spr_rec
            call draw_sprite
            jp maybe_ei

; free object slot -> IX, NC ; C if none
obj_alloc:
            ld ix,objs
            ld b,NOBJ
            ld de,OSIZE
.l:         ld a,(ix+O_KIND)
            or a
            jr z,.f
            add ix,de
            djnz .l
            scf
            ret
.f:         push ix
            pop hl
            ld d,h
            ld e,l
            inc de
            ld (hl),0
            ld bc,OSIZE-1
            ldir
            or a
            ret
