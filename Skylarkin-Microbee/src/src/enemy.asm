; =====================================================================
;  ENEMIES, enemy bullets, capsules, bells, effects, waves, collisions.
;  y values biased by 32. Enemy x: screen pixels (signed 16).
; =====================================================================
; enemy fields
E_TYPE      equ 0
E_ST        equ 1
E_XL        equ 2
E_XH        equ 3
E_XF        equ 4
E_Y         equ 5
E_YF        equ 6
E_DXL       equ 7
E_DXH       equ 8
E_DYL       equ 9
E_DYH       equ 10
E_HP        equ 11
E_T         equ 12
E_FLASH     equ 13
E_P1        equ 14
E_P2        equ 15
E_GRP       equ 16
E_FLAGS     equ 17          ; b0 capsule, b1 bell, b2 no shots hurt it
E_FIRE      equ 18
E_ANIM      equ 19
EF_CAPS     equ 1
EF_BELL     equ 2
EF_SHIELD   equ 4

; enemy types: dw handler, db first frame, db frames, db ink, db hp, db w, db h, dw score/10 (BCD)
ET_SIZE     equ 10
E_PLANE     equ 1
E_SHEET     equ 2
E_STAPLER   equ 3
E_MUG       equ 4
E_CHAIR     equ 5
E_PRINTER   equ 6
E_BALLOON   equ 7
E_BUBBLE    equ 8
E_SWARM     equ 9
E_CRUMPLE   equ 10
E_RPLANE    equ 11
etype_tab:
        dw 0 : db 0,1,0,1,8,8 : dw 0
        dw en_line    : db SF_PLANE0,2,WHITE,1,12,6 : dw $0010
        dw en_sine    : db SF_SHEET0,2,WHITE,1,8,7 : dw $0010
        dw en_hover   : db SF_STAPLER0,2,BRED,3,12,8 : dw $0030
        dw en_mug     : db SF_MUG0,2,BROWN,2,10,10 : dw $0020
        dw en_chair   : db SF_CHAIR0,2,GREY,4,14,12 : dw $0030
        dw en_turret  : db SF_PRINTER0,2,WHITE,6,14,8 : dw $0050
        dw en_balloon : db SF_BALLOON,1,BMAGENTA,1,10,9 : dw $0010
        dw en_bubble  : db SF_BUBBLE,1,BCYAN,1,6,5 : dw $0005
        dw en_swarm   : db SF_SHEET0,2,WHITE,1,8,7 : dw $0001
        dw en_crumple : db SF_CRUMPLE,1,WHITE,99,5,5 : dw $0000
        dw en_line    : db SF_PLANE0,2,BRED,2,12,6 : dw $0020

; IY -> the type entry of enemy IX
etype_iy:
        ld a,(ix+E_TYPE)
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a                 ; *10
        ld e,a
        ld d,0
        ld iy,etype_tab
        add iy,de
        ret

; en_new: A = type, HL = x, C = y -> IX (C flag: none free)
en_new: push af
        push hl
        ld ix,enemies
        ld de,EN_SIZE
        ld b,NENEMY
.f:     ld a,(ix+E_TYPE)
        or a
        jr z,.got
        add ix,de
        djnz .f
        pop hl
        pop af
        scf
        ret
.got:   push bc
        push ix
        pop hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,EN_SIZE-1
        ldir
        pop bc                  ; C = y
        pop hl
        pop af
        ld (ix+E_TYPE),a
        ld (ix+E_XL),l
        ld (ix+E_XH),h
        ld (ix+E_Y),c
        push iy
        call etype_iy
        ld a,(iy+5)
        ld b,a
        ld a,(difficulty)
        cp 2
        jr nz,.h
        ld a,b
        cp 3
        jr c,.h
        inc b                   ; hard: tougher
.h:     ld (ix+E_HP),b
        pop iy
        ld a,(cur_grp)
        ld (ix+E_GRP),a
        or a
        ret

; ---------------------------------------------------------------------
; waves
wave_start:
        ld (wv_y),a
        ld a,c
        ld (wv_yv),a
        ld a,(wv_y)
        add a,a
        ld l,a
        ld h,0
        ld de,wave_jt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        xor a
        ld (cur_grp),a
        jp (hl)
wave_jt:
        dw wv_vplanes,wv_snake,wv_staplers,wv_mugs,wv_chairs,wv_printer,wv_balloon,wv_bubbles,wv_carrier

; a formation: (cur_grp) = a fresh group of B enemies
new_group:
        ld hl,groups
        ld c,1
.f:     ld a,(hl)
        or a
        jr z,.g
        inc hl
        inc hl
        inc c
        ld a,c
        cp 9
        jr c,.f
        xor a                   ; none free: no bonus
        ld (cur_grp),a
        ret
.g:     ld (hl),b
        inc hl
        ld (hl),0
        ld a,c
        ld (cur_grp),a
        ret

wv_vplanes:
        ld b,5
        call new_group
        ld hl,vform
        ld b,5
.l:     push bc
        ld e,(hl)
        inc hl
        ld a,(wv_yv)
        add a,32
        add a,(hl)
        inc hl
        push hl
        ld c,a
        ld l,e
        ld h,0
        ld de,328
        add hl,de
        ld a,E_PLANE
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD       ; -2.5
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
.n:     pop hl
        pop bc
        djnz .l
        ret
vform:  db 0,0, 14,-12, 14,12, 28,-24, 28,24

wv_snake:
        ld b,6
        call new_group
        ld b,6
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a                 ; 16 px apart
        ld l,a
        ld h,0
        ld de,312
        add hl,de
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_SHEET
        call en_new
        jr c,.n
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FE       ; -2
        ld a,(ix+E_Y)
        ld (ix+E_P1),a          ; the middle line
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        ld (ix+E_T),a           ; phase
.n:     pop bc
        djnz .l
        ret

wv_staplers:
        ld b,3
.l:     push bc
        ld a,b
        dec a
        ld c,a
        add a,a
        add a,c                 ; 0, 3, 6
        add a,a
        add a,a
        add a,a                 ; *8: 0, 24, 48
        ld c,a
        ld a,(wv_yv)
        cp 100
        jr c,.y
        ld a,100
.y:     add a,32
        add a,c
        ld c,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,320
        add hl,de
        ld a,E_STAPLER
        call en_new
        jr c,.n
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,196               ; where it stops
        ld (ix+E_P1),a
        ld (ix+E_FIRE),20
.n:     pop bc
        djnz .l
        ret

wv_mugs:
        ld b,3
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; 32 px apart
        ld l,a
        ld h,0
        ld de,300
        add hl,de
        ld a,b
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,(wv_yv)
        cp 90
        jr c,.y
        ld a,90
.y:     add a,32
        add a,c
        ld c,a
        ld a,E_MUG
        call en_new
        jr c,.n
        ld (ix+E_DXL),$C0
        ld (ix+E_DXH),$FE       ; -1.25
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld (ix+E_FIRE),a
.n:     pop bc
        djnz .l
        ret

wv_chairs:
        ld b,2
.l:     push bc
        ld a,b
        dec a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; 0 or 64
        ld l,a
        ld h,0
        ld de,330
        add hl,de
        ld c,32+160
        ld a,E_CHAIR
        call en_new
        jr c,.n
        ld (ix+E_DXH),$FC       ; -4
.n:     pop bc
        djnz .l
        ld a,(difficulty)
        or a
        ret z
        ; one sneaks up from behind
        ld hl,-16
        ld c,32+160
        ld a,E_CHAIR
        call en_new
        ret c
        ld (ix+E_DXH),$02
        ld (ix+E_P2),1
        ret

wv_printer:
        ld hl,332
        ld c,32+150
        ld a,E_PRINTER
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_FIRE),40
        ret

wv_balloon:
        ld hl,328
        ld a,(wv_yv)
        add a,32+40
        cp 32+150
        jr c,.y
        ld a,32+150
.y:     ld c,a
        ld a,E_BALLOON
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_BELL
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FF       ; -1
        ld (ix+E_DYL),$B0
        ld (ix+E_DYH),$FF       ; floats up
        ret

wv_bubbles:
        ld b,4
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,220
        add hl,de
        ld c,32+170
        ld a,E_BUBBLE
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FE
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        neg
        ld (ix+E_DYL),a
        ld (ix+E_DYH),$FC       ; jumps up
.n:     pop bc
        djnz .l
        ret

wv_carrier:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_RPLANE
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_DXH),$FD       ; -3
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        ret

; ---------------------------------------------------------------------
enemies_update:
        ld a,(bellpow)
        cp BP_WHITE
        jr nz,.go
        ld a,(ticks)
        and 1
        ret nz                  ; slow-mo: every other frame
.go:    ld ix,enemies
        ld b,NENEMY
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        ld a,(ix+E_FLASH)
        or a
        jr z,.f
        dec (ix+E_FLASH)
.f:     inc (ix+E_T)
        inc (ix+E_ANIM)
        call etype_iy
        ld l,(iy+0)
        ld h,(iy+1)
        call .jp
        call en_offscreen
.n:     ld de,EN_SIZE
        add ix,de
        pop bc
        djnz .l
        ret
.jp:    jp (hl)

; move by the velocity (8.8)
en_move:
        ld a,(ix+E_XF)
        add a,(ix+E_DXL)
        ld (ix+E_XF),a
        ld a,(ix+E_XL)
        adc a,(ix+E_DXH)
        ld (ix+E_XL),a
        ld a,(ix+E_DXH)
        add a,a
        sbc a,a
        adc a,(ix+E_XH)
        ld (ix+E_XH),a
        ld a,(ix+E_YF)
        add a,(ix+E_DYL)
        ld (ix+E_YF),a
        ld a,(ix+E_Y)
        adc a,(ix+E_DYH)
        ld (ix+E_Y),a
        ret

; en_vis: NC if enemy IX is on screen (0 <= x < 320)
en_vis: ld l,(ix+E_XL)
        ld h,(ix+E_XH)
x_vis:  ld a,h
        or a
        ret z
        dec a
        scf
        ret nz
        ld a,l
        cp 64
        ccf
        ret

; leaving: far off any side -> gone (its formation loses the bonus)
en_offscreen:
        ld a,(ix+E_TYPE)
        or a
        ret z
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,48
        add hl,de
        ld a,h
        cp 2
        jr nc,en_gone           ; < -48 or > 464
        ld a,(ix+E_Y)
        cp 8
        jr c,en_gone
        cp 32+200
        ret c
en_gone:
        ld a,(ix+E_GRP)
        or a
        call nz,grp_fail
        ld (ix+E_TYPE),0
        ret
grp_fail:
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,groups
        add hl,de
        ld (hl),0
        ret

; ---- behaviours
en_line:                        ; straight, a little wobble
        ld a,(ix+E_T)
        and 15
        jr nz,en_move
        ld a,(ix+E_T)
        and 16
        ld a,$20
        jr z,.u
        ld a,$E0
.u:     ld (ix+E_DYL),a
        add a,a
        sbc a,a
        ld (ix+E_DYH),a
        jp en_move

en_sine:                        ; a snake of sheets: y = middle + sin(t)
        call en_move
        ld a,(ix+E_T)
        add a,a
        add a,a
        call sin8               ; -> A signed -64..64
        sra a
        sra a                   ; +-16... *1.5
        ld c,a
        sra a
        add a,c
        add a,(ix+E_P1)
        ld (ix+E_Y),a
        ret

en_hover:                       ; fly in, stop, snap and shoot, leave
        ld a,(ix+E_ST)
        or a
        jr nz,.h
        ; flying in at -3
        ld (ix+E_DXL),0
        ld (ix+E_DXH),$FD
        call en_move
        ld a,(ix+E_XH)
        or a
        ret nz
        ld a,(ix+E_XL)
        cp (ix+E_P1)
        ret nc
        ld (ix+E_ST),1
        ld (ix+E_T),0
        ret
.h:     cp 1
        jr nz,.leave
        ld (ix+E_ANIM),0        ; mouth shut
        ld a,(ix+E_T)
        cp 70
        jr nc,.go
        dec (ix+E_FIRE)
        ret nz
        ld (ix+E_FIRE),30
        ld (ix+E_ANIM),2        ; snap!
        call en_aim
        ld a,SFX_SNAP
        jp play_sfx
.go:    ld (ix+E_ST),2
        ret
.leave: ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD
        ld (ix+E_DYL),$80
        ld (ix+E_DYH),$FF
        jp en_move

en_mug:                         ; drifts, bobs, drips coffee
        call en_move
        ld a,(ix+E_T)
        add a,a
        add a,a
        add a,a
        call sin8
        sra a
        sra a
        sra a
        add a,(ix+E_P1)
        ld (ix+E_Y),a
        dec (ix+E_FIRE)
        ret nz
        ld (ix+E_FIRE),40
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        inc hl
        inc hl
        ld a,(ix+E_Y)
        add a,10
        ld c,a
        ld de,$1000             ; drops straight down
        jp bullet_new

en_chair:                       ; rolls along the floor
        call en_move
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,7
        add hl,de
        ld a,h
        cp 2
        ret nc
        srl h
        rr l
        ld a,l
        call floor_at
        add a,32-12
        ld (ix+E_Y),a
        ret

en_turret:                      ; sits on the floor and shoots
        ld (ix+E_DXL),0
        ld (ix+E_DXH),$FE       ; with the scenery
        ld a,(scrolling)
        or a
        jr nz,.m
        ld (ix+E_DXH),0
.m:     call en_move
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,7
        add hl,de
        ld a,h
        cp 2
        jr nc,.f
        srl h
        rr l
        ld a,l
        call floor_at
        add a,32-8
        ld (ix+E_Y),a
.f:     call en_vis
        ret c
        dec (ix+E_FIRE)
        ret nz
        ld a,(difficulty)
        ld b,60
        or a
        jr z,.r
        ld b,40
.r:     ld (ix+E_FIRE),b
        ld (ix+E_ANIM),2
        jp en_aim

en_balloon:
        call en_move
        ld a,(ix+E_Y)
        cp 32+20
        ret nc
        ld (ix+E_DYL),0
        ld (ix+E_DYH),0
        ret

en_bubble:                      ; bounces along the floor
        call en_move
        ld a,(ix+E_DYL)
        add a,$20
        ld (ix+E_DYL),a
        jr nc,.g
        inc (ix+E_DYH)
.g:     ld a,(ix+E_Y)
        cp 32+176
        ret c
        ld a,(ix+E_DYH)
        bit 7,a
        ret nz
        ld (ix+E_DYL),$00
        ld (ix+E_DYH),$FC       ; boing
        ld a,32+175
        ld (ix+E_Y),a
        ret

en_swarm:                       ; the copier's paper: flutters at the pilot
        ld a,(ix+E_T)
        and 7
        jr nz,.m
        ld a,(py)
        add a,4
        cp (ix+E_Y)
        ld a,$60
        jr nc,.d
        ld a,$A0
.d:     ld (ix+E_DYL),a
        add a,a
        sbc a,a
        ld (ix+E_DYH),a
.m:     jp en_move

en_crumple:                     ; screwed-up paper flying back into the copier
        ld (ix+E_DXL),0
        ld (ix+E_DXH),6
        call en_move
        ld a,(boss_on)
        or a
        ret z
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,(boss_x)
        or a
        sbc hl,de
        ret c
        ld (ix+E_TYPE),0        ; swallowed
        ld hl,boss_jam
        inc (hl)
        ld a,SFX_GULP
        jp play_sfx

; en_aim: an aimed pellet from enemy IX
en_aim: ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        add a,2
        ld c,a
        jp bullet_aimed

; ---------------------------------------------------------------------
draw_enemies:
        ld ix,enemies
        ld b,NENEMY
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        call nz,.one
        ld de,EN_SIZE
        add ix,de
        pop bc
        djnz .l
        ret
.one:   call etype_iy
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld (spr_x),hl
        ld a,(ix+E_Y)
        sub 24
        ld l,a
        ld h,0
        jr nc,.p
        dec h
.p:     ld (spr_y),hl
        ld a,(iy+4)
        ld b,a
        ld a,(ix+E_FLASH)
        or a
        jr z,.i
        ld b,WHITE
        and 1
        jr nz,.i
        ld b,YELLOW
.i:     ld a,b
        ld (spr_ink),a
        ld a,(iy+3)             ; frames
        dec a
        ld a,0
        jr z,.fr
        ld a,(ix+E_ANIM)
        rrca
        rrca
        and 1
.fr:    add a,(iy+2)
        jp spr_draw

; ---------------------------------------------------------------------
; enemy bullets: dw x*16, dw y*16 (biased), db dx, db dy (1/16 px), db kind
; ---------------------------------------------------------------------
B_X         equ 1
B_Y         equ 3
B_DX        equ 5
B_DY        equ 6
; bullet_new: HL = x, C = y (biased), D = dy, E = dx (1/16 px a frame)
bullet_new:
        ld a,(demo)
        or a
        jr z,.d
        ld a,(ticks)            ; the attract demo: fewer
        and 1
        ret nz
.d:     push hl
        ld hl,bullets
        ld b,NBUL
        push de
        ld de,BU_SIZE
.f:     ld a,(hl)
        or a
        jr z,.got
        add hl,de
        djnz .f
        pop de
        pop hl
        ret
.got:   pop de
        ld (hl),1
        inc hl
        ex (sp),hl              ; HL = x, (sp) -> slot+1
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex (sp),hl
        pop bc                  ; BC = x*16
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld a,(tmp+6)            ; (C was overwritten: the caller's y is in tmp+6)
        ld c,a
        ld b,0
        push hl
        ld l,c
        ld h,b
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        pop hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; bullet_aimed: from HL, C (biased y) at the pilot
bullet_aimed:
        ld a,c
        ld (tmp+6),a
        push hl
        ; dx = pilot middle - x (clamped), dy likewise
        ld de,(px)
        ex de,hl
        ld bc,8
        add hl,bc
        or a
        sbc hl,de               ; HL = pilot x - bullet x
        ld (tmp),hl
        ld a,(py)
        add a,6
        ld b,a
        ld a,(tmp+6)
        ld c,a
        ld a,b
        sub c                   ; signed (small enough)
        ld (tmp+2),a
        call aim_dir            ; -> E = dx, D = dy (1/16 px)
        pop hl
        jr bullet_new_y

bullet_new_y:
        ld a,(tmp+6)
        ld c,a
        jp bullet_new

; aim_dir: (tmp) = dx (signed 16), (tmp+2) = dy (signed 8) -> E dx, D dy:
; one of 16 directions at the difficulty's speed
aim_dir:
        ld hl,(tmp)
        ld a,h
        bit 7,a
        jr z,.p
        ld a,l                  ; |dx| (clamped to 255)
        neg
        ld l,a
        ld a,h
        cpl
        jr nz,.big
        ld a,l
        jr .ax
.p:     or a
        jr nz,.big
        ld a,l
        jr .ax
.big:   ld a,255
.ax:    ld b,a                  ; B = |dx|
        ld a,(tmp+2)
        bit 7,a
        jr z,.q
        neg
.q:     ld c,a                  ; C = |dy|
        ; the angle in 0..4 of a quadrant: compare dy against dx * tan
        ld e,0
        ld a,b
        srl a
        srl a                   ; dx/4  (tan 14 deg)
        cp c
        jr nc,.got
        inc e
        ld a,b
        srl a
        ld h,a
        srl a
        srl a
        add a,h                 ; dx * 0.625 (tan 32)
        cp c
        jr nc,.got
        inc e
        ld a,c                  ; dy > dx * 1.6 (tan 58): now compare the other way
        srl a
        ld h,a
        srl a
        srl a
        add a,h
        cp b
        jr c,.got
        inc e
        ld a,c
        srl a
        srl a
        cp b
        jr c,.got
        inc e
.got:   ld a,(difficulty)
        ld d,a
        add a,a
        add a,a
        add a,d                 ; *5
        add a,e
        ld l,a
        ld h,0
        ld de,dir_tab
        add hl,de
        ld a,(hl)               ; cos part
        ld e,a
        ld bc,15
        add hl,bc
        ld d,(hl)               ; sin part
        ; signs
        ld a,(tmp+1)
        bit 7,a
        jr z,.sx
        ld a,e
        neg
        ld e,a
.sx:    ld a,(tmp+2)
        bit 7,a
        ret z
        ld a,d
        neg
        ld d,a
        ret
; |dx| and |dy| parts (1/16 px a frame) at 0, 22.5, 45, 67.5, 90 degrees, per difficulty
dir_tab:
        db 32,30,23,12,0, 40,37,28,15,0, 48,44,34,18,0
        db 0,12,23,30,32, 0,15,28,37,40, 0,18,34,44,48

bullets_update:
        ld a,(bellpow)
        cp BP_WHITE
        jr nz,.go
        ld a,(ticks)
        and 1
        ret nz
.go:    ld ix,bullets
        ld b,NBUL
.l:     ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+B_X)
        ld h,(ix+B_X+1)
        ld a,(ix+B_DX)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        add hl,de
        ld (ix+B_X),l
        ld (ix+B_X+1),h
        ld a,h
        cp 21                   ; x*16 >= 5376 (336) or negative
        jr nc,.kill
        ld l,(ix+B_Y)
        ld h,(ix+B_Y+1)
        ld a,(ix+B_DY)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        add hl,de
        ld (ix+B_Y),l
        ld (ix+B_Y+1),h
        ld a,h
        cp 14                   ; y*16: below 224 biased
        jr nc,.kill
        cp 1
        jr c,.kill              ; above 16 biased
        jr .n
.kill:  ld (ix+0),0
.n:     ld de,BU_SIZE
        add ix,de
        djnz .l
        ret

draw_bullets:
        ld a,WHITE
        ld (spr_ink),a
        ld ix,bullets
        ld b,NBUL
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+B_X)
        ld h,(ix+B_X+1)
        call .s4
        ld de,-2
        add hl,de
        ld (spr_x),hl
        ld l,(ix+B_Y)
        ld h,(ix+B_Y+1)
        call .s4
        ld de,-24-2
        add hl,de
        ld (spr_y),hl
        ld a,K_PELLET
        call obj_draw
.n:     ld de,BU_SIZE
        add ix,de
        pop bc
        djnz .l
        ret
.s4:    sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ret

; ---------------------------------------------------------------------
; capsules: db on, dw x, db y, db t
capsule_at:                     ; HL = x, C = y (biased)
        push hl
        ld hl,capsules
        ld de,CA_SIZE
        ld b,NCAP
.f:     ld a,(hl)
        or a
        jr z,.g
        add hl,de
        djnz .f
        pop hl
        ret
.g:     pop de
        ld (hl),1
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        ret

capsules_update:
        ld ix,capsules
        ld b,NCAP
.l:     ld a,(ix+0)
        or a
        jr z,.n
        inc (ix+4)
        ld a,(ix+4)
        and 1
        jr nz,.n
        ld l,(ix+1)
        ld h,(ix+2)
        dec hl
        ld (ix+1),l
        ld (ix+2),h
        bit 7,h
        jr z,.n
        ld a,l
        cp -12
        jr nc,.n
        ld (ix+0),0
.n:     ld de,CA_SIZE
        add ix,de
        djnz .l
        ret

draw_capsules:
        ld ix,capsules
        ld b,NCAP
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+1)
        ld h,(ix+2)
        ld (spr_x),hl
        ld a,(ix+3)
        sub 24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(ix+4)
        and 4
        ld a,BRED
        jr z,.c
        ld a,YELLOW
.c:     ld (spr_ink),a
        ld a,(ix+4)
        rrca
        rrca
        rrca
        and 1
        add a,SF_CAPS0
        call spr_draw
.n:     ld de,CA_SIZE
        add ix,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; bells: on, dw x, db xf, db y, db yf, dw dy (8.8), db hits, db colour, db bonks, db t
BL_X        equ 1
BL_XF       equ 3
BL_Y        equ 4
BL_YF       equ 5
BL_DY       equ 6
BL_HITS     equ 8
BL_COL      equ 9
BL_BONK     equ 10
BL_T        equ 11
bell_at:                        ; HL = x, C = y
        push hl
        ld hl,bells
        ld de,BE_SIZE
        ld b,NBELL
.f:     ld a,(hl)
        or a
        jr z,.g
        add hl,de
        djnz .f
        pop hl
        ret
.g:     push hl
        pop ix
        pop hl
        ld (ix+0),1
        ld (ix+BL_X),l
        ld (ix+BL_X+1),h
        ld (ix+BL_Y),c
        xor a
        ld (ix+BL_XF),a
        ld (ix+BL_YF),a
        ld (ix+BL_HITS),a
        ld (ix+BL_BONK),a
        ld (ix+BL_T),a
        ld (ix+BL_DY),$00
        ld (ix+BL_DY+1),$FD     ; pops up
        ld (ix+BL_COL),BP_GOLD
        ld a,SFX_DING
        jp play_sfx

bells_update:
        ld ix,bells
        ld b,NBELL
.l:     push bc
        ld a,(ix+0)
        or a
        call nz,.one
        ld de,BE_SIZE
        add ix,de
        pop bc
        djnz .l
        ret
.one:   inc (ix+BL_T)
        ; drift left with the wind
        ld a,(ix+BL_T)
        and 1
        jr nz,.g
        ld l,(ix+BL_X)
        ld h,(ix+BL_X+1)
        dec hl
        ld (ix+BL_X),l
        ld (ix+BL_X+1),h
        bit 7,h
        jr z,.g
        ld a,l
        cp -10
        jr nc,.g
        ld (ix+0),0
        ret
.g:     ; gravity (gentle), capped
        ld l,(ix+BL_DY)
        ld h,(ix+BL_DY+1)
        ld de,$0014
        add hl,de
        ld a,h
        cp 2
        jr nz,.c
        ld hl,$0200
.c:     ld (ix+BL_DY),l
        ld (ix+BL_DY+1),h
        ld a,(ix+BL_YF)
        add a,l
        ld (ix+BL_YF),a
        ld a,(ix+BL_Y)
        adc a,h
        ld (ix+BL_Y),a
        cp 16
        jr nc,.top
        ld (ix+BL_Y),16
        ld (ix+BL_DY),0
        ld (ix+BL_DY+1),0
.top:   cp 32+186
        ret c
        ld (ix+0),0             ; dropped: gone
        ld a,SFX_DENY
        jp play_sfx

; a shot hit bell IX: up it goes; every third hit, the next colour
bell_hit:
        ld (ix+BL_DY),$00
        ld (ix+BL_DY+1),$FD
        ld l,(ix+BL_X)
        ld h,(ix+BL_X+1)
        inc hl
        inc hl
        inc hl
        ld (ix+BL_X),l
        ld (ix+BL_X+1),h
        ld de,$0010
        call add_score
        inc (ix+BL_HITS)
        ld a,(ix+BL_HITS)
        cp 3
        jr c,.s
        ld c,a
.m3:    sub 3
        jr z,.next
        jr nc,.m3
.s:     ld a,SFX_DING
        jp play_sfx
.next:  ld a,(ix+BL_COL)
        inc a
        cp 6
        jr c,.k
        ld a,1
.k:     ld (ix+BL_COL),a
        ld a,SFX_DONG
        jp play_sfx

bell_ink:
        db 0,YELLOW,BBLUE,BGREEN,BRED,WHITE

draw_bells:
        ld ix,bells
        ld b,NBELL
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+BL_X)
        ld h,(ix+BL_X+1)
        ld (spr_x),hl
        ld a,(ix+BL_Y)
        sub 24
        ld l,a
        ld h,0
        jr nc,.p
        dec h
.p:     ld (spr_y),hl
        ld a,(ix+BL_COL)
        ld e,a
        ld d,0
        ld hl,bell_ink
        add hl,de
        ld a,(hl)
        ld c,a
        ld a,(ix+BL_HITS)       ; a hot bell flashes
        cp 3
        jr c,.i
        ld a,(ix+BL_T)
        and 2
        jr z,.i
        ld c,WHITE
        ld a,(ix+BL_COL)
        cp BP_WHITE
        jr nz,.i
        ld c,YELLOW
.i:     ld a,c
        ld (spr_ink),a
        ld a,(ix+BL_T)
        rrca
        rrca
        and 3
        cp 3
        jr nz,.f
        ld a,0
.f:     add a,SF_BELL0
        call spr_draw
.n:     ld de,BE_SIZE
        add ix,de
        pop bc
        djnz .l
        ret

; the pilot caught bell IX
bell_take:
        ld (ix+0),0
        ld a,(ix+BL_COL)
        cp BP_GOLD
        jr nz,.pow
        ; gold: the ladder, times the juggle multiplier
        ld a,(goldrun)
        ld e,a
        ld d,0
        ld hl,gold_ladder
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(ix+BL_BONK)
        inc a
        ld b,a
.m:     push bc
        push de
        call add_score
        pop de
        pop bc
        djnz .m
        ld a,(goldrun)
        cp 5
        jr nc,.g
        inc a
        ld (goldrun),a
.g:     ld a,SFX_BELLGET
        jp play_sfx
.pow:   push af
        xor a
        ld (goldrun),a
        ld de,$0100
        call add_score
        pop af
        cp BP_BLUE
        jr nz,.t
        call megaphone
        ld a,SFX_OI
        jp play_sfx
.t:     ld (bellpow),a
        ld b,75
        cp BP_RED
        jr nz,.tt
        ld b,100
.tt:    ld a,b
        ld (belltime),a
        ld a,1
        ld (hud_dirty),a
        ld a,SFX_BELLGET
        jp play_sfx
gold_ladder:    dw $0050,$0100,$0200,$0300,$0500,$1000

; ---------------------------------------------------------------------
; effects: db frame (0 = free), dw x, db y, db kind
fx_boom:                        ; HL = x, C = y
        push hl
        ld hl,effects
        ld de,FX_SIZE
        ld b,NFX
.f:     ld a,(hl)
        or a
        jr z,.g
        add hl,de
        djnz .f
        pop hl
        ret
.g:     pop de
        ld (hl),1
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        ret

effects_update:
        ld hl,effects
        ld b,NFX
.l:     ld a,(hl)
        or a
        jr z,.n
        inc a
        cp 13
        jr c,.k
        xor a
.k:     ld (hl),a
.n:     ld de,FX_SIZE
        add hl,de
        djnz .l
        ret

draw_effects:
        ld ix,effects
        ld b,NFX
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+1)
        ld h,(ix+2)
        ld (spr_x),hl
        ld a,(ix+3)
        sub 24
        ld l,a
        ld h,0
        jr nc,.p
        dec h
.p:     ld (spr_y),hl
        ld a,(ix+0)
        and 2
        ld a,YELLOW
        jr z,.c
        ld a,BRED
.c:     ld (spr_ink),a
        ld a,(ix+0)
        dec a
        srl a
        srl a                   ; 0..2 -> 3 frames each
        cp 4
        jr c,.f
        ld a,3
.f:     add a,SF_BOOM0
        call spr_draw
.n:     ld de,FX_SIZE
        add ix,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; damage: enemy IX takes E; kills it at 0
en_damage:
        ld a,(ix+E_TYPE)
        or a
        ret z
        ld a,(ix+E_FLAGS)
        and EF_SHIELD
        ret nz
        ld a,(ix+E_HP)
        sub e
        jr z,en_kill
        jr c,en_kill
        ld (ix+E_HP),a
        ld (ix+E_FLASH),4
        ld a,SFX_TINK
        jp play_sfx
en_kill:
        ld a,(ix+E_TYPE)
        cp E_SWARM
        jr nz,.n
        ; a sheet of copier paper: screwed up, it flies back at the copier
        ld (ix+E_TYPE),E_CRUMPLE
        ld (ix+E_HP),99
        ld (ix+E_FLAGS),EF_SHIELD
        ld a,SFX_CRUMPLE
        jp play_sfx
.n:     push iy
        call etype_iy
        ld e,(iy+8)
        ld d,(iy+9)
        pop iy
        call add_score
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        sub 2
        ld c,a
        push hl
        push bc
        call fx_boom
        pop bc
        pop hl
        ld a,(ix+E_FLAGS)
        and EF_CAPS
        call nz,capsule_at
        ld a,(ix+E_FLAGS)
        and EF_BELL
        jr z,.nb
        push ix
        call bell_at
        pop ix
.nb:    ; its formation
        ld a,(ix+E_GRP)
        or a
        jr z,.x
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,groups
        add hl,de
        ld a,(hl)
        or a
        jr z,.x
        inc hl
        inc (hl)
        cp (hl)
        jr nz,.x
        dec hl
        ld (hl),0               ; the whole formation: a capsule
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld c,(ix+E_Y)
        call capsule_at
.x:     ld (ix+E_TYPE),0
        ld a,SFX_POP
        jp play_sfx

; area_damage: HL = x, C = y (biased), B = radius, E = damage
area_damage:
        ld (ad_x),hl
        ld a,c
        ld (ad_y),a
        ld a,b
        ld (ad_r),a
        ld a,e
        ld (ad_d),a
        ld ix,enemies
        ld b,NENEMY
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,(ad_x)
        or a
        sbc hl,de
        call abs_hl
        ld a,h
        or a
        jr nz,.n
        ld a,(ad_r)
        cp l
        jr c,.n
        ld a,(ix+E_Y)
        ld b,a
        ld a,(ad_y)
        sub b
        jr nc,.p
        neg
.p:     ld b,a
        ld a,(ad_r)
        cp b
        jr c,.n
        ld a,(ad_d)
        ld e,a
        call en_damage
.n:     ld de,EN_SIZE
        add ix,de
        pop bc
        djnz .l
        ; and the boss
        ld a,(ad_d)
        ld e,a
        jp boss_area
abs_hl: bit 7,h
        ret z
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        ret

; megaphone / OI!: every ordinary enemy on screen goes, bullets become points
megaphone:
oi_shout:
        ld a,4
        ld (shake_t),a
        ld ix,enemies
        ld b,NENEMY
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        cp E_CRUMPLE
        jr z,.n
        call en_vis
        jr c,.n
        ld e,12
        call en_damage
.n:     ld de,EN_SIZE
        add ix,de
        pop bc
        djnz .l
        ld hl,bullets
        ld b,NBUL
        ld de,BU_SIZE
.b:     ld a,(hl)
        or a
        jr z,.bn
        ld (hl),0
        push hl
        push de
        push bc
        ld de,$0010
        call add_score
        pop bc
        pop de
        pop hl
.bn:    add hl,de
        djnz .b
        ld e,10
        call boss_area
        ld a,SFX_OI
        jp play_sfx

; nearest_enemy: -> C = middle y of the closest one ahead, NZ (Z if none)
nearest_enemy:
        push ix
        ld ix,enemies
        ld b,NENEMY
        ld c,0
        ld e,255
.l:     ld a,(ix+E_TYPE)
        or a
        jr z,.n
        cp E_CRUMPLE
        jr z,.n
        ld a,(ix+E_XH)
        or a
        jr nz,.n
        ld a,(ix+E_XL)
        cp e
        jr nc,.n
        ld e,a
        ld a,(ix+E_Y)
        add a,4
        ld c,a
.n:     push de
        ld de,EN_SIZE
        add ix,de
        pop de
        djnz .l
        pop ix
        ld a,c
        or a
        ret

; ---------------------------------------------------------------------
; collisions. Boxes in "half x" (x/2, 0..167 on screen) and biased y.
; ---------------------------------------------------------------------
collide_all:
        call en_boxes
        call shots_vs
        call player_vs
        ret

; en_boxes: for each enemy, x0, x1, y0, y1 (half x; x0 = 255: none)
en_boxes:
        ld ix,enemies
        ld hl,ebox
        ld b,NENEMY
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.no
        push hl
        call etype_iy
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,16
        add hl,de               ; (biased by 16 so the left edge stays positive)
        ld a,h
        cp 2
        jr nc,.nop
        srl h
        rr l
        ld c,l
        pop hl
        ld (hl),c
        inc hl
        ld a,(iy+6)
        srl a
        add a,c
        ld (hl),a
        inc hl
        ld a,(ix+E_Y)
        ld (hl),a
        inc hl
        add a,(iy+7)
        ld (hl),a
        inc hl
        jr .n
.nop:   pop hl
.no:    ld (hl),255
        inc hl
        inc hl
        inc hl
        inc hl
.n:     pop bc
        ld de,EN_SIZE
        add ix,de
        djnz .l
        ret

; shot IX's box -> sx0, sx1 (half x +8), sy0, sy1. NC if on screen.
shot_box:
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,16
        add hl,de
        ld a,(ix+0)
        cp ST_BEAM
        jr nz,.nb
        ; a beam: from head - length to head
        push hl
        ld e,(ix+11)
        ld d,0
        or a
        sbc hl,de
        ld a,0
        bit 7,h
        jr nz,.b0
        srl h
        rr l
        ld a,l
.b0:    ld (sx0),a
        pop hl
        ld a,h
        cp 2
        ld a,255
        jr nc,.b1
        srl h
        rr l
        ld a,l
.b1:    ld (sx1),a
        ld a,(ix+3)
        ld (sy0),a
        add a,2
        ld (sy1),a
        or a
        ret
.nb:    ld a,h
        cp 2
        ccf
        ret c
        srl h
        rr l
        ld a,l
        ld (sx0),a
        ld c,a
        ld a,(ix+0)
        ld b,4                  ; half width
        ld e,3                  ; height
        cp ST_DASH
        jr nz,.k1
        ld b,3
        ld e,2
.k1:    cp ST_RING
        jr nz,.k2
        ld a,(ix+6)
        srl a
        srl a
        and 3
        inc a
        add a,a
        add a,a
        ld b,a
        add a,a
        ld e,a
        ld a,(ix+3)
        sub b
        ld (ix+9),a
        jr .k3
.k2:    cp ST_BOOMER
        jr nz,.k3
        ld b,7
        ld e,8
.k3:    ld a,c
        add a,b
        ld (sx1),a
        ld a,(ix+3)
        ld (sy0),a
        add a,e
        ld (sy1),a
        or a
        ret

shots_vs:
        call make_elist
        xor a                   ; any bells about?
        ld hl,bells
        ld de,BE_SIZE
        ld b,NBELL
.bc:    or (hl)
        add hl,de
        djnz .bc
        ld (sv_bells),a
        ld ix,shots
        ld b,NSHOT
.l:     push bc
        ld a,(ix+0)
        or a
        call nz,.one
        ld de,SH_SIZE
        add ix,de
        pop bc
        djnz .l
        ret
.one:   call shot_box
        ret c
        ld a,(sv_bells)         ; bells first: a shot bounces them
        or a
        call nz,shot_bells
        ld a,(ix+0)
        or a
        ret z
        ld a,(boss_on)
        or a
        call nz,shot_boss
        ld a,(ix+0)
        or a
        ret z
        ld a,(nelist)
        or a
        ret z
        ld b,a
        ld hl,ELIST
        ld a,(sx1)
        ld c,a
        ld a,(sx0)
        ld d,a
        ld a,(sy1)
        ld e,a
.e:     ld a,c
        cp (hl)                 ; shot right edge < x0?
        jr c,.n0
        inc l
        ld a,d
        cp (hl)                 ; shot left edge >= x1?
        jr nc,.n1
        inc l
        ld a,e
        cp (hl)                 ; shot bottom < y0?
        jr c,.n2
        inc l
        ld a,(sy0)
        cp (hl)                 ; shot top >= y1?
        jr nc,.n3
        ; a hit: the enemy pointer follows
        inc l
        ld a,(hl)
        inc l
        push hl
        ld h,(hl)
        ld l,a
        push bc
        push de
        push ix
        pop iy                  ; IY = the shot
        push hl
        pop ix                  ; IX = the enemy
        ld a,(ix+E_TYPE)
        or a
        jr z,.back              ; (destroyed by this frame's earlier shots)
        ld a,(iy+0)
        cp ST_BEAM
        jr z,.pierce
        cp ST_RING
        jr z,.pierce
        cp ST_BOOMER
        jr z,.pierce
        cp ST_BOMB
        jr z,.bomb
        ld (iy+0),0
        ld e,(iy+7)
        call en_damage
        jr .back
.pierce:
        ld a,(ix+E_FLASH)
        or a
        jr nz,.back
        ld e,(iy+7)
        call en_damage
        jr .back
.bomb:  push iy
        pop ix
        push ix
        call bomb_burst
        pop iy
.back:  push iy
        pop ix
        pop de
        pop bc
        pop hl
        inc l
        ld a,(ix+0)
        or a
        ret z                   ; the shot is spent
        djnz .e
        ret
.n0:    inc l
.n1:    inc l
.n2:    inc l
.n3:    inc l
        inc l
        inc l
        djnz .e
        ret

; make_elist: the live enemy boxes from ebox, packed: x0 x1 y0 y1, dw enemy
make_elist:
        ld hl,ebox
        ld de,ELIST
        ld ix,enemies
        ld b,NENEMY
        ld c,0
.l:     ld a,(hl)
        cp 255
        jr z,.n
        inc c
        push bc
        ldi
        ldi
        ldi
        ldi
        pop bc
        ld a,ixl
        ld (de),a
        inc e
        ld a,ixh
        ld (de),a
        inc e
        dec hl
        dec hl
        dec hl
        dec hl
.n:     inc hl
        inc hl
        inc hl
        inc hl
        push de
        ld de,EN_SIZE
        add ix,de
        pop de
        djnz .l
        ld a,c
        ld (nelist),a
        ret

; shot IX vs the bells
shot_bells:
        push ix
        pop iy
        ld ix,bells
        ld b,NBELL
.l:     ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+BL_X)
        ld h,(ix+BL_X+1)
        ld de,16
        add hl,de
        ld a,h
        cp 2
        jr nc,.n
        srl h
        rr l
        ld c,l                  ; bell x0
        ld a,(sx1)
        cp c
        jr c,.n
        ld a,c
        add a,5
        ld c,a
        ld a,(sx0)
        cp c
        jr nc,.n
        ld a,(ix+BL_Y)
        ld c,a
        ld a,(sy1)
        cp c
        jr c,.n
        ld a,c
        add a,10
        ld c,a
        ld a,(sy0)
        cp c
        jr nc,.n
        ; bounce it; the shot is spent (beams go through)
        push bc
        call bell_hit
        pop bc
        ld a,(iy+0)
        cp ST_BEAM
        jr z,.n
        ld (iy+0),0
        jr .x
.n:     ld de,BE_SIZE
        add ix,de
        djnz .l
.x:     push iy
        pop ix
        ret

; the pilot against enemies, bullets, capsules, bells; hot bells against enemies
player_vs:
        ld a,(pdead)
        or a
        ret nz
        ; the pilot's hitbox: a small core (half x)
        ld hl,(px)
        ld de,16+8
        add hl,de
        srl h
        rr l
        ld a,l
        sub 2
        ld (hx0),a
        add a,4
        ld (hx1),a
        ld a,(py)
        add a,4
        ld (hy0),a
        add a,5
        ld (hy1),a
        ; enemies (whole bodies)
        ld hl,ebox
        ld ix,enemies
        ld b,NENEMY
.e:     push bc
        ld a,(hl)
        cp 255
        jr z,.ne
        call box_hits
        jr nc,.ne
        ld a,(ix+E_TYPE)
        cp E_CRUMPLE
        jr z,.ne
        push hl
        ld a,(bellpow)
        cp BP_GREEN
        jr nz,.hurt
        ld e,20                 ; BIG BIRD: rams them
        call en_damage
        pop hl
        jr .ne
.hurt:  call hit_player
        ld e,2
        call en_damage
        pop hl
.ne:    ld de,4
        add hl,de
        ld de,EN_SIZE
        add ix,de
        pop bc
        djnz .e
        ; bullets
        ld ix,bullets
        ld b,NBUL
.b:     ld a,(ix+0)
        or a
        jr z,.nb
        ld l,(ix+B_X)
        ld h,(ix+B_X+1)
        ld de,16*16
        add hl,de
        call shr5               ; -> half x
        ld c,a
        ld a,(hx1)
        cp c
        jr c,.nb
        ld a,c
        add a,2
        ld c,a
        ld a,(hx0)
        cp c
        jr nc,.nb
        ld l,(ix+B_Y)
        ld h,(ix+B_Y+1)
        call shr4
        ld c,a
        ld a,(hy1)
        cp c
        jr c,.nb
        ld a,c
        add a,3
        ld c,a
        ld a,(hy0)
        cp c
        jr nc,.nb
        ld (ix+0),0
        push bc
        call hit_player
        pop bc
.nb:    ld de,BU_SIZE
        add ix,de
        djnz .b
        call boss_touch
        ; capsules and bells: the whole pilot picks them up
        ld hl,(px)
        ld de,16
        add hl,de
        srl h
        rr l
        ld a,l
        ld (hx0),a
        add a,8
        ld (hx1),a
        ld a,(py)
        ld (hy0),a
        add a,12
        ld (hy1),a
        ld ix,capsules
        ld b,NCAP
.c:     ld a,(ix+0)
        or a
        jr z,.nc
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,16
        add hl,de
        srl h
        rr l
        ld a,l
        ld c,a
        ld a,(hx1)
        cp c
        jr c,.nc
        ld a,c
        add a,5
        ld c,a
        ld a,(hx0)
        cp c
        jr nc,.nc
        ld a,(ix+3)
        ld c,a
        ld a,(hy1)
        cp c
        jr c,.nc
        ld a,c
        add a,8
        ld c,a
        ld a,(hy0)
        cp c
        jr nc,.nc
        ld (ix+0),0
        push bc
        call capsule_got
        pop bc
.nc:    ld de,CA_SIZE
        add ix,de
        djnz .c
        ld ix,bells
        ld b,NBELL
.bl:    push bc
        ld a,(ix+0)
        or a
        jr z,.nbl
        call bell_box
        call box_hits
        jr nc,.hot
        call bell_take
        jr .nbl
.hot:   ld a,(ix+BL_HITS)
        cp 3
        call nc,bell_bonk
.nbl:   ld de,BE_SIZE
        add ix,de
        pop bc
        djnz .bl
        ret

; bell IX's box -> HL -> 4 bytes (bbox)
bell_box:
        ld l,(ix+BL_X)
        ld h,(ix+BL_X+1)
        ld de,16
        add hl,de
        srl h
        rr l
        ld a,l
        ld hl,bbox
        ld (hl),a
        inc hl
        add a,5
        ld (hl),a
        inc hl
        ld a,(ix+BL_Y)
        ld (hl),a
        inc hl
        add a,10
        ld (hl),a
        ld hl,bbox
        ret

; box_hits: HL -> x0, x1, y0, y1 against hx0..hy1 -> C if they overlap
box_hits:
        ld a,(hx1)
        cp (hl)
        jr c,.no
        inc hl
        ld a,(hl)
        dec hl
        ld c,a
        ld a,(hx0)
        cp c
        jr nc,.no
        inc hl
        inc hl
        ld a,(hy1)
        cp (hl)
        dec hl
        dec hl
        jr c,.no
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        dec hl
        ld c,a
        ld a,(hy0)
        cp c
        ccf
        ret
.no:    or a
        ret

; a hot bell IX against the enemies: BONK
bell_bonk:
        call bell_box
        ld a,(hx0)
        push af
        ld a,(hx1)
        push af
        ld a,(hy0)
        push af
        ld a,(hy1)
        push af
        ld a,(bbox)
        ld (hx0),a
        ld a,(bbox+1)
        ld (hx1),a
        ld a,(bbox+2)
        ld (hy0),a
        ld a,(bbox+3)
        ld (hy1),a
        push ix
        pop iy
        ld hl,ebox
        ld ix,enemies
        ld b,NENEMY
.e:     ld a,(hl)
        cp 255
        jr z,.n
        push hl
        call box_hits
        pop hl
        jr nc,.n
        ld a,(ix+E_TYPE)
        cp E_CRUMPLE
        jr z,.n
        ld a,(ix+E_FLASH)
        or a
        jr nz,.n
        push hl
        push bc
        ld e,2
        call en_damage
        pop bc
        pop hl
        ld a,(iy+BL_BONK)
        cp 4
        jr nc,.m
        inc a
        ld (iy+BL_BONK),a
.m:     ld a,SFX_BONK
        call play_sfx
.n:     ld de,4
        add hl,de
        ld de,EN_SIZE
        add ix,de
        djnz .e
        push iy
        pop ix
        pop af
        ld (hy1),a
        pop af
        ld (hy0),a
        pop af
        ld (hx1),a
        pop af
        ld (hx0),a
        ret

shr5:   srl h
        rr l
shr4:   srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        ret

; sin8: A = angle (0..255) -> A = 64 * sin (signed)
sin8:   ld e,a
        and $7F
        cp 64
        jr c,.q
        ld c,a
        ld a,128
        sub c
.q:     ld l,a
        ld h,0
        ld bc,sintab
        add hl,bc
        ld a,(hl)
        bit 7,e
        ret z
        neg
        ret
sintab:
        db 0,2,3,5,6,8,9,11,12,14,16,17,19,20,22,23,24,26,27,29,30,32,33,34,36,37,38,39,41,42,43,44
        db 45,46,47,48,49,50,51,52,53,54,55,56,56,57,58,59,59,60,60,61,61,62,62,62,63,63,63,64,64,64,64,64,64

wv_y:   db 0
wv_yv:  db 0
cur_grp:    db 0
groups:     ds 16           ; per group: size (0 = free), killed
ebox:       ds NENEMY*4
nelist:     db 0
sv_bells:   db 0
bbox:       ds 4
sx0:    db 0
sx1:    db 0
sy0:    db 0
sy1:    db 0
hx0:    db 0
hx1:    db 0
hy0:    db 0
hy1:    db 0
ad_x:   dw 0
ad_y:   db 0
ad_r:   db 0
ad_d:   db 0
shake_t:    db 0
