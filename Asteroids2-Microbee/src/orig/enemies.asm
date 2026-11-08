; ---------------------------------------------------------------------------
; enemies.asm - enemies, enemy fire, jewels, pickups, rock specials
; ---------------------------------------------------------------------------
T_SAUCER equ $20
T_HUNTER equ $21
T_STING  equ $22
T_MINE   equ $23
T_JEWEL  equ $30        ; + colour 0 topaz 1 ruby 2 emerald
T_PICK   equ $38        ; + kind
PK_SHIELD equ 0
PK_BOMB   equ 1
PK_SPREAD equ 2
PK_RAPID  equ 3
PK_LIFE   equ 4

; ---------------- geometry ----------------
; signed dx,dy from object IY to the ship (wrap aware) -> D = dx, E = dy
vec_to_ship:
        ld a,(OBJ_SHIP+O_XH)
        sub (iy+O_XH)
        and 127
        cp 64
        jr c,.x
        sub 128
.x:     ld d,a
        ld a,(OBJ_SHIP+O_YH)
        sub (iy+O_YH)
        jp p,.yp
        cp -29
        jr nc,.y
        add a,PF_ROWS
        jr .y
.yp:    cp 30
        jr c,.y
        sub PF_ROWS
.y:     ld e,a
        ret

; angle (0..63, 0 = up, clockwise) of vector D = dx (px), E = dy (rows)
atan64:
        ld a,d
        call abs_a
        add a,a
        ld b,a                  ; X = |dx|*2
        ld a,e
        call abs_a
        ld c,a
        add a,a
        add a,c
        ld c,a                  ; Y = |dy|*3
        ld a,b
        or c
        ret z                   ; zero vector -> 0
        ld a,b
        cp c
        jr c,.ylong
        ; X >= Y : r = Y*16/X
        ld l,c
        ld h,0
        call .r16
        ld e,a                  ; keep sign info: D=dx, need dy sign -> saved below
        ld a,(at_dy)
        bit 7,a
        ld a,(at_dx)
        jr z,.down1
        ; up
        bit 7,a
        ld a,16
        jr nz,.ul
        sub e                   ; right-up: 16 - a
        ret
.ul:    ld a,48
        add a,e                 ; left-up: 48 + a
        and 63
        ret
.down1: bit 7,a
        ld a,16
        jr nz,.dl
        add a,e
        ret
.dl:    ld a,48
        sub e
        ret
.ylong: ld l,b
        ld h,0
        ld b,c
        call .r16
        ld e,a
        ld a,(at_dy)
        bit 7,a
        ld a,(at_dx)
        jr z,.down2
        bit 7,a
        ld a,e
        ret z                   ; up-right: a
        ld a,64
        sub e
        and 63
        ret
.down2: bit 7,a
        ld a,32
        jr nz,.dl2
        sub e
        ret
.dl2:   add a,e
        ret
; A = atan table[(HL*16)/B]
.r16:   add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,b
        ld d,0
        xor a
.d:     or a
        sbc hl,de
        jr c,.e
        inc a
        cp 16
        jr c,.d
.e:     ld e,a
        ld d,0
        ld hl,atan_tab
        add hl,de
        ld a,(hl)
        ret
atan_tab: db 0,1,1,2,2,3,3,4,4,4,5,5,6,6,6,7,8

; angle to ship for object IY -> A
aim_at_ship:
        call vec_to_ship
        ld a,d
        ld (at_dx),a
        ld a,e
        ld (at_dy),a
        jp atan64

; set velocity of IY to direction A (0..63) * B / 4
set_dir_vel:
        push af
        ld e,a
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        push bc
        call smul
        ld b,2
        call sra_hl
        ld (iy+O_VXL),l
        ld (iy+O_VXH),h
        pop bc
        pop af
        ld e,a
        ld d,0
        ld hl,cosy
        add hl,de
        ld a,(hl)
        call smul
        ld b,2
        call sra_hl
        ld (iy+O_VYL),l
        ld (iy+O_VYH),h
        ret

; ---------------- enemy fire ----------------
; fire from IY in direction A (0..63)
enemy_fire:
        push af
        push ix
        ld ix,OBJ_EBUL
        ld b,N_EBUL
        call find_free
        jr z,.x
        pop hl                  ; old ix
        push hl
        ld (ix+O_TYPE),T_EBUL
        ld (ix+O_TMR),32
        ld a,(iy+O_XH)
        ld (ix+O_XH),a
        ld a,(iy+O_YH)
        ld (ix+O_YH),a
        ld (ix+O_XL),$80
        ld (ix+O_YL),$80
        pop hl
        pop af
        push af
        push hl
        ld e,a
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        ld b,3
        call smul
        ld (ix+O_VXL),l
        ld (ix+O_VXH),h
        pop hl
        pop af
        push af
        push hl
        ld e,a
        ld d,0
        ld hl,cosy
        add hl,de
        ld a,(hl)
        ld b,3
        call smul
        ld (ix+O_VYL),l
        ld (ix+O_VYH),h
        ld a,SFX_EFIRE
        call sfx_play
.x:     pop ix
        pop af
        ret

; ---------------- spawning ----------------
enemy_wave_init:
        xor a
        ld (enemy_count),a
        ; first enemy after 8..12 s, sooner on later waves
        ld a,(wave)
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,250
        sub b
        jr nc,.ok
        xor a
.ok:    cp 90
        jr nc,.ok2
        ld a,90
.ok2:   ld (enemy_tmr),a
        ret

enemy_spawner:
        ld a,(ship_state)
        or a
        ret nz
        ld hl,enemy_tmr
        dec (hl)
        ret nz
        call enemy_wave_init    ; reload timer
        ; how many may be alive: 1 + wave/3 (max 3)
        ld a,(wave)
        ld b,0
.d3:    inc b
        sub 3
        jr nc,.d3
        ld a,b
        cp 4
        jr c,.m
        ld a,3
.m:     ld c,a
        ld a,(enemy_count)
        cp c
        ret nc
        ; choose type by wave
        ld a,(wave)
        dec a
        ld c,a                  ; types allowed: 0..min(3,wave-1)
        cp 4
        jr c,.t
        ld c,3
.t:     call rnd
        and 3
        cp c
        jr c,.ty
        jr z,.ty
        ld a,c
        call rnd
        and 1
        jr z,.ty0
        ld a,c
        jr .ty
.ty0:   xor a
.ty:    ; A = 0 saucer 1 mine 2 sting 3 hunter
        ld (spawn_type),a
        ld iy,OBJ_ENEMY
        ld b,N_ENEMY
        push iy
        pop ix
        call find_free
        ret z
        push ix
        pop iy
        ld hl,OBJ_ENEMY         ; clear slot
        push iy
        pop hl
        ld bc,OBJSZ
        call clear_mem
        ; edge position
        call rnd
        and 31
        add a,12
        ld (iy+O_YH),a
        call rnd
        and 1
        ld c,a                  ; 0 = from left (move right)
        ld a,126
        jr z,.fl
        ld a,2
.fl:    ld (iy+O_XH),a          ; start just inside the opposite edge (wraps in)
        ld a,(spawn_type)
        or a
        jr nz,.n0
        ; saucer
        ld (iy+O_TYPE),T_SAUCER
        ld (iy+O_SPR),SPR_SAUCER
        ld (iy+O_RX),7
        ld (iy+O_RY),3
        ld (iy+O_HP),2
        ld (iy+O_FRM),220       ; lifetime
        ld (iy+O_TMR),30
        ld a,c
        or a
        ld hl,160
        jr z,.sv
        ld hl,-160
.sv:    ld (iy+O_VXL),l
        ld (iy+O_VXH),h
        ld a,SFX_SAUCER
        call sfx_play
        jp .done
.n0:    dec a
        jr nz,.n1
        ; mine
        ld (iy+O_TYPE),T_MINE
        ld (iy+O_SPR),SPR_MINE
        ld (iy+O_RX),4
        ld (iy+O_RY),3
        ld (iy+O_HP),1
        ld (iy+O_TMR),1
        ld a,SFX_MINE
        call sfx_play
        jp .done
.n1:    dec a
        jr nz,.n2
        ; stinger
        ld (iy+O_TYPE),T_STING
        ld (iy+O_SPR),SPR_STING
        ld (iy+O_RX),4
        ld (iy+O_RY),3
        ld (iy+O_HP),1
        ld (iy+O_FRM),0         ; dash timer
        ld (iy+O_TMR),20
        ld (iy+O_AUX),16
        ld a,c
        or a
        jr z,.sr
        ld (iy+O_AUX),48
.sr:    ld a,SFX_STING
        call sfx_play
        jp .done
.n2:    ; hunter
        ld (iy+O_TYPE),T_HUNTER
        ld (iy+O_SPR),SPR_HUNTER
        ld (iy+O_RX),4
        ld (iy+O_RY),2
        ld (iy+O_HP),1
        ld (iy+O_FRM),200
        ld (iy+O_TMR),25
        ld a,c
        or a
        ld hl,260
        jr z,.hv
        ld hl,-260
.hv:    ld (iy+O_VXL),l
        ld (iy+O_VXH),h
        ld a,SFX_HUNTER
        call sfx_play
.done:  ld hl,enemy_count
        inc (hl)
        ret

; ---------------- update ----------------
update_enemies:
        call enemy_spawner
        xor a
        ld (enemy_count),a
        ld iy,OBJ_ENEMY
        ld b,N_ENEMY
.l:     ld a,(iy+O_TYPE)
        or a
        jr z,.n
        push bc
        ld hl,enemy_count
        inc (hl)
        ld a,(iy+O_AUX)
        cp T_SAUCER             ; (no-op compare to keep flags simple)
        ld a,(iy+O_TYPE)
        cp T_SAUCER
        call z,upd_saucer
        ld a,(iy+O_TYPE)
        cp T_HUNTER
        call z,upd_hunter
        ld a,(iy+O_TYPE)
        cp T_STING
        call z,upd_sting
        ld a,(iy+O_TYPE)
        cp T_MINE
        call z,upd_mine
        ld a,(iy+O_TYPE)
        or a
        jr z,.gone
        push iy
        pop ix
        call move_obj
.gone:  pop bc
.n:     ld de,OBJSZ
        add iy,de
        djnz .l
        ; stop enemy sirens when none remain
        ld a,(enemy_count)
        or a
        ret nz
        ld a,(ch0+CH_PRIO)
        cp 3
        ret nz
        xor a
        ld (ch0+CH_PTR),a
        ld (ch0+CH_PTR+1),a
        ret

upd_saucer:
        dec (iy+O_FRM)
        jp z,enemy_leave
        ld a,(iy+O_FRM)
        and 31
        jr nz,.nz
        ; new vertical drift
        call rnd
        and 127
        sub 64
        call sext
        ld (iy+O_VYL),l
        ld (iy+O_VYH),h
.nz:    dec (iy+O_TMR)
        ret nz
        ld a,(wave)
        add a,a
        ld b,a
        ld a,46
        sub b
        cp 18
        jr nc,.t
        ld a,18
.t:     ld (iy+O_TMR),a
        ; 1 in 3 aimed, otherwise random
        call rnd
        and 3
        jr nz,.rand
        call aim_at_ship
        jp enemy_fire
.rand:  call rnd
        and 63
        jp enemy_fire

upd_hunter:
        dec (iy+O_FRM)
        jp z,enemy_leave
        ld a,(iy+O_FRM)
        and 15
        jr nz,.nz
        call rnd
        and 255
        sub 128
        call sext
        ld (iy+O_VYL),l
        ld (iy+O_VYH),h
.nz:    dec (iy+O_TMR)
        ret nz
        ld (iy+O_TMR),22
        call aim_at_ship
        ld c,a
        call rnd
        and 3
        sub 1                   ; slight spread -1..2
        add a,c
        and 63
        jp enemy_fire

upd_sting:
        ; turn towards the ship every 2 frames, dash in bursts
        ld a,(frame_ct)
        and 1
        jr nz,.nt
        call aim_at_ship
        ld c,a
        ld a,(iy+O_AUX)
        sub c
        and 63
        jr z,.nt
        cp 32
        ld a,(iy+O_AUX)
        jr c,.dec
        inc a
        inc a
.dec:   dec a
        and 63
        ld (iy+O_AUX),a
.nt:    inc (iy+O_FRM)
        ld a,(iy+O_FRM)
        and 63
        cp 40
        ld b,7                  ; dash speed
        jr c,.sp
        ld b,3                  ; coast
.sp:    ld a,(iy+O_AUX)
        call set_dir_vel
        ld a,(iy+O_FRM)
        and 63
        ret nz
        ld a,SFX_STING
        jp sfx_play

upd_mine:
        dec (iy+O_TMR)
        ret nz
        ld (iy+O_TMR),20
        call aim_at_ship
        ld b,2
        call set_dir_vel
        ld a,SFX_MINE
        jp sfx_play

enemy_leave:
        ld (iy+O_TYPE),0
        ld a,PC_GEM
        ld (part_col),a
        ld d,(iy+O_XH)
        ld e,(iy+O_YH)
        ld b,6
        ld c,$1F
        ld a,3
        jp burst

draw_enemies:
        ld ix,OBJ_ENEMY
        ld b,N_ENEMY
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        push bc
        ld c,(ix+O_SPR)
        cp T_STING
        jr nz,.ns
        ld a,(ix+O_AUX)
        add a,4
        rrca
        rrca
        rrca
        and 7
        jr .dr
.ns:    ld a,(frame_ct)
        rrca
        and 1
.dr:    add a,c
        ld d,(ix+O_XH)
        ld e,(ix+O_YH)
        call draw_obj_spr
        pop bc
.n:     ld de,OBJSZ
        add ix,de
        djnz .l
        ret

; ---------------- enemy death ----------------
; points table (BCD hi, lo) by type-$20
enemy_pts: db $02,$00, $10,$00, $05,$00, $01,$50

enemy_destroy:          ; IY = enemy
        ld a,(iy+O_XH)
        ld (kill_x),a
        ld a,(iy+O_YH)
        ld (kill_y),a
        ld a,(iy+O_TYPE)
        ld (tmp3),a
        sub T_SAUCER
        add a,a
        ld e,a
        ld d,0
        ld hl,enemy_pts
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        push de
        call add_score
        pop de
        call popup_points
        ld (iy+O_TYPE),0
        ld a,(iy+O_XH)
        ld (kill_x),a
        ld (spawn_x),a
        ld d,a
        ld a,(iy+O_YH)
        ld (kill_y),a
        ld (spawn_y),a
        ld e,a
        push de
        ld a,PC_FIRE
        ld (part_col),a
        ld b,14
        ld c,$5F
        ld a,6
        call burst
        pop de
        ld a,PC_RED
        ld (part_col),a
        ld b,6
        ld c,$3F
        ld a,4
        call burst
        ld a,10
        ld (ring_tmr),a
        ld a,(kill_x)
        ld (ring_x),a
        ld a,(kill_y)
        ld (ring_y),a
        ld a,SFX_EBOOM
        call sfx_play
        ; rewards
        ld a,(tmp3)
        cp T_SAUCER
        jr nz,.r1
        jp drop_pickup
.r1:    cp T_HUNTER
        jr nz,.r2
        ld a,2
        jp drop_jewel
.r2:    cp T_STING
        jr nz,.r3
        call rnd
        and 1
        ret z
        ld a,1
        jp drop_jewel
.r3:    ; mine: shrapnel burst
        jp volatile_blast

bomb_enemies:
        ld iy,OBJ_ENEMY
        ld b,N_ENEMY
.l:     ld a,(iy+O_TYPE)
        or a
        jr z,.n
        push bc
        call enemy_destroy
        pop bc
.n:     ld de,OBJSZ
        add iy,de
        djnz .l
        ret

; ---------------- collisions ----------------
coll_bullets_enemies:
        xor a
        ld (coll_mx),a
        ld (coll_my),a
        ld ix,OBJ_PBUL
        ld b,N_PBUL
.b:     ld a,(ix+O_TYPE)
        or a
        jr z,.nb
        ld a,(ix+O_XH)
        ld (coll_x),a
        ld a,(ix+O_YH)
        ld (coll_y),a
        push bc
        ld iy,OBJ_ENEMY
        ld b,N_ENEMY
.r:     ld a,(iy+O_TYPE)
        or a
        jr z,.nr
        push bc
        call hit_test
        pop bc
        jr nc,.nr
        ld (ix+O_TYPE),0
        dec (iy+O_HP)
        jr z,.kill
        ld a,PC_SPARK
        ld (part_col),a
        ld d,(iy+O_XH)
        ld e,(iy+O_YH)
        ld b,4
        ld c,$1F
        ld a,3
        call burst
        ld a,SFX_CLINK
        call sfx_play
        jp .done
.kill:  push ix
        call enemy_destroy
        pop ix
        jp .done
.nr:    ld de,OBJSZ
        add iy,de
        djnz .r
.done:  pop bc
.nb:    ld de,OBJSZ
        add ix,de
        djnz .b
        ret

coll_ship_enemies:
        ld a,(ship_state)
        or a
        ret nz
        ld a,(OBJ_SHIP+O_XH)
        ld (coll_x),a
        ld a,(OBJ_SHIP+O_YH)
        ld (coll_y),a
        ld a,2
        ld (coll_mx),a
        ld a,1
        ld (coll_my),a
        ld iy,OBJ_ENEMY
        ld b,N_ENEMY
.r:     ld a,(iy+O_TYPE)
        or a
        jr z,.nr
        push bc
        call hit_test
        pop bc
        jr nc,.nr
        push bc
        call ship_struck
        call enemy_destroy
        pop bc
        ld a,(ship_state)
        or a
        ret nz
.nr:    ld de,OBJSZ
        add iy,de
        djnz .r
        ; enemy bullets and shrapnel vs ship: treat bullets as targets with radius
        ld a,3
        ld (coll_mx),a
        ld a,2
        ld (coll_my),a
        ld iy,OBJ_EBUL
        ld b,N_EBUL
        call .bul
        ld iy,OBJ_PBUL
        ld b,N_PBUL
.bul:   ld a,(iy+O_TYPE)
        cp T_EBUL
        jr z,.t
        cp T_SHRAP
        jr nz,.nb
        ld a,(iy+O_TMR)
        cp 8                    ; fresh shrapnel can't hurt (lets it clear the rock)
        jr nc,.nb
.t:     ld a,(iy+O_RX)
        push af
        ld (iy+O_RX),1
        ld (iy+O_RY),1
        push bc
        call hit_test
        pop bc
        pop af
        jr nc,.nb
        ld (iy+O_TYPE),0
        push bc
        call ship_struck
        pop bc
        ld a,(ship_state)
        or a
        ret nz
.nb:    ld de,OBJSZ
        add iy,de
        djnz .bul
        ret

; ship was hit by something: shield absorbs, else death
ship_struck:
        ld a,(ship_state)
        or a
        ret nz
        ld a,(invuln)
        or a
        ret nz
        ld a,(shield_hp)
        or a
        jp z,kill_ship
        dec a
        ld (shield_hp),a
        ld a,25
        ld (invuln),a
        ld hl,hud_dirty
        set 0,(hl)
        ld a,PC_SPARK
        ld (part_col),a
        ld a,(OBJ_SHIP+O_XH)
        ld d,a
        ld a,(OBJ_SHIP+O_YH)
        ld e,a
        ld b,10
        ld c,$3F
        ld a,4
        call burst
        ld a,SFX_SHIELD
        jp sfx_play

; ---------------- rock specials ----------------
; ore rock destroyed (tmp3 = type): jewels
ore_reward:
        ld a,(tmp3)
        and 3
        jr nz,.m
        ld a,1                  ; large -> ruby
        call drop_jewel
        xor a
        jp drop_jewel           ; and a topaz
.m:     cp 1
        jr nz,.s
        xor a
        jp drop_jewel
.s:     call rnd
        and 1
        ret z
        xor a
        jp drop_jewel

; volatile rock / mine: 8 shrapnel shards from (kill_x, kill_y)
volatile_blast:
        ld a,SFX_SHRAP
        call sfx_play
        ld a,6
        ld (flash_tmr),a
        ld a,6
        ld (shake),a
        push ix
        ld c,0                  ; angle
.l:     push bc
        ld ix,OBJ_PBUL
        ld b,N_PBUL
        call find_free
        pop bc
        jr z,.x
        ld (ix+O_TYPE),T_SHRAP
        ld (ix+O_TMR),11
        ld a,(kill_x)
        ld (ix+O_XH),a
        ld a,(kill_y)
        ld (ix+O_YH),a
        ld (ix+O_XL),$80
        ld (ix+O_YL),$80
        push bc
        ld e,c
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        ld b,5
        call smul
        ld (ix+O_VXL),l
        ld (ix+O_VXH),h
        ld hl,cosy
        add hl,de
        ld a,(hl)
        ld b,5
        call smul
        ld (ix+O_VYL),l
        ld (ix+O_VYH),h
        pop bc
        ld a,c
        add a,8
        ld c,a
        cp 64
        jr c,.l
.x:     pop ix
        ld a,PC_RED
        ld (part_col),a
        ld a,(kill_x)
        ld d,a
        ld a,(kill_y)
        ld e,a
        ld b,10
        ld c,$7F
        ld a,6
        jp burst

; ---------------- items ----------------
; drop jewel colour A at (spawn_x, spawn_y)
drop_jewel:
        add a,T_JEWEL
        ld (tmp2),a
        call spawn_item
        ret z
        ld (ix+O_RX),3
        ld (ix+O_RY),3
        ld a,SFX_GEMDROP
        jp sfx_play

; drop a weighted random pickup
drop_pickup:
        call rnd
        ld c,PK_SPREAD
        cp 80
        jr c,.k
        ld c,PK_RAPID
        cp 150
        jr c,.k
        ld c,PK_SHIELD
        cp 215
        jr c,.k
        ld c,PK_BOMB
        cp 248
        jr c,.k
        ld c,PK_LIFE
.k:     ld a,c
        add a,T_PICK
        ld (tmp2),a
        call spawn_item
        ret z
        ld (ix+O_RX),4
        ld (ix+O_RY),3
        ret

; IX = new item of type (tmp2) at spawn_x/y, slow random drift. Z if none.
spawn_item:
        push iy
        ld ix,OBJ_ITEM
        ld b,N_ITEM
        call find_free
        pop iy
        ret z
        ld a,(tmp2)
        ld (ix+O_TYPE),a
        ld a,(spawn_x)
        ld (ix+O_XH),a
        ld a,(spawn_y)
        ld (ix+O_YH),a
        ld (ix+O_XL),$80
        ld (ix+O_YL),$80
        ld (ix+O_TMR),0         ; life 256 frames (counts down from 0)
        ld (ix+O_FRM),0
        call rnd
        and 63
        sub 32
        call sext
        ld (ix+O_VXL),l
        ld (ix+O_VXH),h
        call rnd
        and 31
        sub 16
        call sext
        ld (ix+O_VYL),l
        ld (ix+O_VYH),h
        or 1                    ; NZ
        ret

update_items:
        ld ix,OBJ_ITEM
        ld b,N_ITEM
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        push bc
        call move_obj
        inc (ix+O_FRM)
        dec (ix+O_TMR)
        jr nz,.alive
        ld (ix+O_TYPE),0
        jr .nx
.alive: ; jewels sparkle now and then
        ld a,(ix+O_TYPE)
        cp T_PICK
        jr nc,.nx
        call rnd
        and 15
        jr nz,.nx
        ld a,PC_GEM
        ld (part_col),a
        ld d,(ix+O_XH)
        ld e,(ix+O_YH)
        ld b,1
        ld c,$0F
        ld a,4
        call burst
.nx:    pop bc
.n:     ld de,OBJSZ
        add ix,de
        djnz .l
        ret

draw_items:
        ld ix,OBJ_ITEM
        ld b,N_ITEM
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        ; blink during the last 64 frames
        ld a,(ix+O_TMR)
        cp 64
        jr nc,.vis
        ld a,(frame_ct)
        and 2
        jr z,.n
.vis:   push bc
        ld a,(ix+O_TYPE)
        cp T_PICK
        jr nc,.pick
        sub T_JEWEL
        add a,a
        add a,a
        ld c,a
        ld a,(ix+O_FRM)
        rrca
        rrca
        and 3
        add a,c
        add a,SPR_JEWEL_TOPAZ
        jr .dr
.pick:  sub T_PICK
        add a,a
        ld c,a
        ld a,(ix+O_FRM)
        rrca
        rrca
        rrca
        and 1
        add a,c
        add a,SPR_PICK_SHIELD
.dr:    ld d,(ix+O_XH)
        ld e,(ix+O_YH)
        call draw_obj_spr
        pop bc
.n:     ld de,OBJSZ
        add ix,de
        djnz .l
        ret

; jewel values (BCD) topaz 250, ruby 500, emerald 1000
jewel_pts: db $02,$50, $05,$00, $10,$00

coll_ship_items:
        ld a,(ship_state)
        or a
        ret nz
        ld a,(OBJ_SHIP+O_XH)
        ld (coll_x),a
        ld a,(OBJ_SHIP+O_YH)
        ld (coll_y),a
        ld a,3
        ld (coll_mx),a
        ld a,2
        ld (coll_my),a
        ld iy,OBJ_ITEM
        ld b,N_ITEM
.r:     ld a,(iy+O_TYPE)
        or a
        jr z,.nr
        push bc
        call hit_test
        call c,collect_item
        pop bc
.nr:    ld de,OBJSZ
        add iy,de
        djnz .r
        ret

collect_item:
        ld a,(iy+O_TYPE)
        ld (iy+O_TYPE),0
        ld (tmp3),a
        ld a,(iy+O_XH)
        ld (kill_x),a
        ld d,a
        ld a,(iy+O_YH)
        ld (kill_y),a
        ld e,a
        ld a,PC_GEM
        ld (part_col),a
        ld b,10
        ld c,$3F
        ld a,5
        call burst
        ld a,(tmp3)
        cp T_PICK
        jr nc,.pick
        ; jewel: value * chain multiplier
        sub T_JEWEL
        add a,a
        ld e,a
        ld d,0
        ld hl,jewel_pts
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld a,(chain_tmr)
        or a
        jr z,.first
        ld a,(chain_mul)
        cp 4
        jr nc,.cm
        inc a
        ld (chain_mul),a
.cm:    jr .mul
.first: ld a,1
        ld (chain_mul),a
.mul:   ld a,60
        ld (chain_tmr),a
        ; total = value * chain_mul (BCD add loop)
        ld a,(chain_mul)
        ld b,a
        ld hl,0
.ad:    ld a,l
        add a,e
        daa
        ld l,a
        ld a,h
        adc a,d
        daa
        ld h,a
        djnz .ad
        ex de,hl
        push de
        call add_score
        pop de
        call popup_points
        ld a,(chain_mul)
        cp 2
        ld a,SFX_JEWEL
        jr c,.sj
        ld a,SFX_CHAIN
.sj:    jp sfx_play
.pick:  sub T_PICK
        ld (tmp3),a
        ld a,SFX_PICKUP
        call sfx_play
        ld hl,hud_dirty
        set 0,(hl)
        ld a,(tmp3)
        or a
        jr nz,.p1
        ld a,3
        ld (shield_hp),a
        ld hl,txt_p_shield
        jr .pop
.p1:    dec a
        jr nz,.p2
        ld a,(bombs)
        cp 5
        jr nc,.bm
        inc a
        ld (bombs),a
.bm:    ld hl,txt_p_bomb
        jr .pop
.p2:    dec a
        jr nz,.p3
        ld a,1
        ld (weapon),a
        ld a,255
        ld (weapon_tmr),a
        ld hl,txt_p_spread
        jr .pop
.p3:    dec a
        jr nz,.p4
        ld a,2
        ld (weapon),a
        ld a,255
        ld (weapon_tmr),a
        ld hl,txt_p_rapid
        jr .pop
.p4:    ld a,(lives)
        cp 9
        jr nc,.lv
        inc a
        ld (lives),a
.lv:    ld hl,txt_p_life
.pop:   ld de,popup_txt
        ld bc,6
        ldir
        jr popup_place

; popup showing BCD points DE (suppress leading zeros)
popup_points:
        ld hl,popup_txt
        ld a,d
        rrca
        rrca
        rrca
        rrca
        and $0F
        jr z,.z1
        add a,'0'
        ld (hl),a
        inc hl
.z1:    ld a,d
        and $0F
        add a,'0'
        ld (hl),a
        inc hl
        ld a,e
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,'0'
        ld (hl),a
        inc hl
        ld a,e
        and $0F
        add a,'0'
        ld (hl),a
        inc hl
        ld (hl),0
        ; strip a single leading '0' (e.g. 0250 -> 250)
        ld a,(popup_txt)
        cp '0'
        jr nz,popup_place
        ld hl,popup_txt+1
        ld de,popup_txt
        ld bc,5
        ldir
popup_place:
        ld a,(kill_x)
        rrca
        rrca
        and 31
        cp 26
        jr c,.x
        ld a,25
.x:     ld (popup_x),a
        ld a,(kill_y)
        sub 7
        jr nc,.y
        add a,12
.y:     cp PF_ROWS-6
        jr c,.y2
        ld a,PF_ROWS-7
.y2:    ld (popup_y),a
        ld a,25
        ld (popup_tmr),a
        ret
