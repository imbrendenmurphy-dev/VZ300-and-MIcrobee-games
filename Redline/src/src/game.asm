; =====================================================================
;  game.asm - the race: handling, traffic, collisions, checkpoints
;  One game frame = 3 fields (16.7 fps, locked).  Speeds in km/h*64.
; =====================================================================
NCARS     equ 6
C_ON      equ 0
C_F       equ 1               ; position: frac (units), seg lo, seg hi
C_SL      equ 2
C_SH      equ 3
C_X       equ 4               ; lateral, units/3 (signed)
C_SPD     equ 5               ; km/h / 2
C_TYPE    equ 6
C_FRM     equ 7               ; animation frame
C_TX      equ 8               ; target lane x
C_FF      equ 9               ; sub-unit fraction
C_BUMP    equ 10
C_ADV     equ 12
C_LEN     equ 14

PLAYERZ   equ 263             ; player car sits this far ahead of the camera
SPDMAX    equ 300*64
SPDOFF    equ 110*64
XLIM      equ ROADW+280
FPS_FIELDS equ 3

ST_RACE   equ 0
ST_CRASH  equ 1
ST_COUNT  equ 2
ST_OVER   equ 3
ST_DONE   equ 4

; ---------------------------------------------------------------- input
; bits: 0 left 1 right 2 accel 3 brake
K_LEFT  equ 1
K_RIGHT equ 2
K_ACC   equ 4
K_BRK   equ 8
read_input:
        ld c,0
        ld a,($68BF)            ; row 6: Y O RET I P U  (O bit1, P bit4)
        bit 1,a
        jr nz,.k1
        set 0,c
.k1:    bit 4,a
        jr nz,.k2
        set 1,c
.k2:    ld a,($68FB)            ; row 2: B X SHIFT C Z V (Z bit4, X bit1)
        bit 4,a
        jr nz,.k3
        set 0,c
.k3:    bit 1,a
        jr nz,.k4
        set 1,c
.k4:    ld a,($68EF)            ; row 4: N . - , SPACE M (SPACE bit4, M bit5)
        and $30
        cp $30
        jr z,.k5
        set 2,c
.k5:    ld a,($68FE)            ; row 0: T W - E Q R  (Q bit4)
        bit 4,a
        jr nz,.k6
        set 2,c
.k6:    ld a,($68FD)            ; row 1: G S CTRL D A F (A bit4)
        bit 4,a
        jr nz,.k7
        set 3,c
.k7:    push bc
        call joy_read           ; bit0 up 1 down 2 left 3 right 4 fire
        pop bc
        rra
        jr nc,.j1
        set 2,c                 ; up = accelerate
.j1:    rra
        jr nc,.j2
        set 3,c                 ; down = brake
.j2:    rra
        jr nc,.j3
        set 0,c
.j3:    rra
        jr nc,.j4
        set 1,c
.j4:    rra
        jr nc,.j5
        set 2,c                 ; fire = accelerate
.j5:    ld a,(joyarm)
        or a
        jr z,.j6
        set 3,c                 ; ARM button = brake
.j6:    ld a,(demo)
        or a
        jr z,.j7
        call demo_input
.j7:    ld a,c
        ld (keys),a
        ret

; ---------------------------------------------------------------- frame update
game_update:
        ld a,(gstate)
        cp ST_COUNT
        jp z,upd_count
        cp ST_CRASH
        jp z,upd_crash
        cp ST_DONE
        jp z,upd_coast
        cp ST_OVER
        jp z,upd_coast
        call read_input
        call upd_speed
        call upd_steer
        call advance_player
        call upd_traffic
        call collide_cars
        call collide_objects
        call upd_checkpoint
        call upd_timer
        ret

upd_count:
        call upd_traffic
        ld hl,cnt_t
        dec (hl)
        ret nz
        ld (hl),17              ; one light per second
        ld hl,cnt_n
        dec (hl)
        ld a,(hl)
        or a
        jr z,.go
        cp 4
        ret nc
        add a,MSG_1-1           ; 3, 2, 1
        call show_msg
        jp sfx_beep
.go:    ld a,ST_RACE
        ld (gstate),a
        call sfx_go
        ld a,MSG_GO
        jp show_msg

upd_coast:                      ; finished / out of time: roll to a stop
        ld hl,(speed)
        ld de,-5*64
        add hl,de
        jr c,.s
        ld hl,0
.s:     ld (speed),hl
        call advance_player
        call upd_traffic
        ld hl,end_t
        dec (hl)
        ret

upd_crash:
        ld hl,crash_t
        dec (hl)
        jr z,.done
        ld hl,(speed)
        ld de,-12*64
        add hl,de
        jr c,.s
        ld hl,0
.s:     ld (speed),hl
        call advance_player
        call upd_traffic
        ld a,(crash_t)          ; spin frame
        and 7
        ld (pframe_spin),a
        ret
.done:  ; back on the road, slowly, centred on the nearer lane
        ld hl,(camx)
        bit 7,h
        ld hl,-96
        jr nz,.l
        ld hl,96
.l:     ld (camx),hl
        ld a,ST_RACE
        ld (gstate),a
        ld hl,0
        ld (speed),hl
        ret

; ---------------------------------------------------------------- speed
upd_speed:
        ld a,(keys)
        ld hl,(speed)
        bit 3,a
        jr nz,.brake
        bit 2,a
        jr z,.coast
        ; accelerate: rate falls with speed
        ld a,h
        cp 100*64/256
        ld de,5*64
        jr c,.a1
        cp 200*64/256
        ld de,3*64
        jr c,.a1
        cp 260*64/256
        ld de,100
        jr c,.a1
        ld de,45
.a1:    add hl,de
        ld de,SPDMAX
        call clamp_hi
        jr .off
.brake: ld de,-10*64
        add hl,de
        jr c,.off
        ld hl,0
        jr .off
.coast: ld de,-64
        add hl,de
        jr c,.off
        ld hl,0
.off:   ld (speed),hl
        ; off the road: drag down towards 110 km/h, rumble
        call offroad_test
        ld (offroad),a
        or a
        ret z
        ld hl,(speed)
        ld de,SPDOFF
        or a
        sbc hl,de
        ret c
        ld hl,(speed)
        ld de,-6*64
        add hl,de
        ld (speed),hl
        ret

clamp_hi:                       ; HL = min(HL, DE)
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; A = 1 if the player is off the tarmac (beyond the rumble strips)
offroad_test:
        ld hl,(camx)
        bit 7,h
        jr z,.p
        NEGHL
.p:     ld de,ROADW+28
        or a
        sbc hl,de
        ld a,0
        ret c
        inc a
        ret

; ---------------------------------------------------------------- steering
upd_steer:
        ; steer rate = 10 + kmh/16 units per frame (none when stopped)
        ld hl,(speed)
        ld a,h                  ; kmh/4
        or a
        jr nz,.mv
        ld a,l
        cp 4*64/4
        jr c,.cf                ; < 4 km/h: no steering
.mv:    srl a
        srl a                   ; kmh/16
        add a,10
        ld e,a
        ld d,0
        ld a,(keys)
        ld hl,(camx)
        bit 0,a
        jr z,.r
        or a
        sbc hl,de
        ld b,-1
        jr .s
.r:     bit 1,a
        ld b,0
        jr z,.s0
        add hl,de
        ld b,1
        jr .s
.s0:    ld b,0
.s:     ld (camx),hl
        ld a,b
        ld (steerdir),a
.cf:    ; centrifugal: x -= curve * kmh^2 / 2^17
        call cur_curve          ; A = curve here (signed)
        or a
        jr z,.lim
        ld e,a
        ld hl,(speed)
        ld a,h                  ; kmh/4 (0..75)
        ld l,a
        ld h,0
        ; (kmh/4)^2 ~ 0..5625 ; *16 = kmh^2 ; want kmh^2/2^17 * curve = (kmh/4)^2*curve/8192
        push de
        ld e,a
        call mul8u              ; HL = (kmh/4)^2
        pop de
        ld a,h                  ; /256
        ld b,l
        ld l,a
        ld h,0                  ; HL = (kmh/4)^2 / 256  (0..21)
        ld a,l
        call smul8              ; HL = curve * that
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l                    ; /32
        ex de,hl
        ld hl,(camx)
        or a
        sbc hl,de
        ld (camx),hl
.lim:   ; hard limits
        ld hl,(camx)
        ld de,XLIM
        bit 7,h
        jr nz,.n
        call clamp_hi
        ld (camx),hl
        ret
.n:     NEGHL
        call clamp_hi
        NEGHL
        ld (camx),hl
        ret

; A = curve of the segment under the player
cur_curve:
        ld hl,(pos_s)
        inc hl
        ld de,TRK_CURV
        add hl,de
        ld a,(hl)
        ret

; ---------------------------------------------------------------- movement
; pos += kmh * 147 / 256 units (+ sub-unit fraction)
advance_player:
        ld hl,(speed)
        ; kmh = speed/64 -> units/frame*256 = kmh*147 = speed*147/64
        ld a,h
        ld e,l
        sla e
        rla
        sla e
        rla                     ; A = speed/64 (kmh), max 300 -> overflow!
        ld c,a                  ; (kmh capped at 255 here; 255..300 handled below)
        ld a,h
        cp 256*64/256/1         ; speed >= 256 km/h? (h >= 64)
        jr c,.lo
        ld hl,(speed)           ; kmh * 147 for kmh >= 256: (kmh-256)*147 + 37632
        ld de,-256*64
        add hl,de
        ld a,h
        ld e,l
        sla e
        rla
        sla e
        rla
        ld e,147
        call mul8u
        ld de,37632
        add hl,de
        jr .add
.lo:    ld a,c
        ld e,147
        call mul8u              ; HL = kmh*147 (units*256)
.add:   ld (adv),hl
        ld a,(pos_ff)
        add a,l
        ld (pos_ff),a
        ld a,(pos_f)
        adc a,h
        ld (pos_f),a
        ret nc
        ld hl,(pos_s)
        inc hl
        ld (pos_s),hl
        ld hl,(dist)
        inc hl
        ld (dist),hl
        ret

; ---------------------------------------------------------------- camera
; altitude under the camera, panorama drift
upd_camera:
        ld hl,(pos_s)
        ld de,TRK_ALTL
        add hl,de
        ld e,(hl)
        inc hl
        ld c,(hl)
        ld a,h
        add a,high (TRK_ALTH-TRK_ALTL)
        ld h,a
        ld b,(hl)               ; BC = alt[s+1]
        dec hl
        ld d,(hl)               ; DE = alt[s]
        push de
        ld h,b
        ld l,c
        or a
        sbc hl,de
        ld a,(pos_f)
        call mul_s8
        pop de
        add hl,de
        ld (camalt),hl
        ; the panorama slides against the bend
        call cur_curve
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld hl,(speed)
        ld a,h
        srl a
        srl a                   ; kmh/16
        ld b,a
        ld hl,0
        or a
        jr z,.p
.pm:    add hl,de
        djnz .pm
.p:     sra h
        rr l
        sra h
        rr l
        ex de,hl
        ld hl,(panox)
        add hl,de
        ld (panox),hl
        ret

; ---------------------------------------------------------------- traffic
upd_traffic:
        ld ix,cars
        ld b,NCARS
.l:     push bc
        ld a,(ix+C_ON)
        or a
        call z,car_spawn
        ld a,(ix+C_ON)
        or a
        jr z,.n
        ; move: units*256 per step, precomputed at spawn (C_ADV)
        ld l,(ix+C_ADV)
        ld h,(ix+C_ADV+1)
        ld a,(ix+C_FF)
        add a,l
        ld (ix+C_FF),a
        ld a,(ix+C_F)
        adc a,h
        ld (ix+C_F),a
        jr nc,.m1
        inc (ix+C_SL)
        jr nz,.m1
        inc (ix+C_SH)
.m1:    ; steer towards the target lane
        ld a,(ix+C_TX)
        sub (ix+C_X)
        jr z,.ln
        ld a,(ix+C_X)
        jp m,.ml
        inc a
        jr .ms
.ml:    dec a
.ms:    ld (ix+C_X),a
.ln:    ; follow the road: the projection already bends the lanes
        ; despawn when far behind or far ahead
        ld l,(ix+C_SL)
        ld h,(ix+C_SH)
        ld de,(pos_s)
        or a
        sbc hl,de
        jr c,.behind
        ld a,h
        or a
        jr nz,.kill
        ld a,l
        cp 34
        jr nc,.kill
        jr .anim
.behind: ld a,l
        cp -6
        jr nc,.anim
.kill:  ld (ix+C_ON),0
.anim:  ; wheel / exhaust animation
        ld a,(ix+C_FRM)
        inc a
        and 3
        ld (ix+C_FRM),a
        ld a,(ix+C_BUMP)
        or a
        jr z,.n
        dec (ix+C_BUMP)
.n:     ld de,C_LEN
        add ix,de
        pop bc
        dec b
        jp nz,.l
        ret

; spawn a car out of sight ahead (density from the section header)
car_spawn:
        call rand
        and 15
        ld b,a
        ld a,(traffic)
        cp b
        ret c                   ; probability ~ density/16 per frame
        ret z
        call rand
        and 3
        add a,25                ; 25..28 segments ahead
        ld e,a
        ld d,0
        ld hl,(pos_s)
        add hl,de
        ld (ix+C_SL),l
        ld (ix+C_SH),h
        call rand
        ld (ix+C_F),a
        ld (ix+C_FF),0
        call rand
        and 1
        ld a,-30
        jr z,.ln
        ld a,30
.ln:    ld (ix+C_X),a
        ld (ix+C_TX),a
        call rand
        and 31
        add a,45                ; 90..152 km/h (stored /2)
        ld (ix+C_SPD),a
        ld e,147
        call mul8u
        add hl,hl
        ld (ix+C_ADV),l
        ld (ix+C_ADV+1),h
        call rand
        and 3
        cp 3
        jr nz,.t
        xor a
.t:     ld (ix+C_TYPE),a
        ld (ix+C_ON),1
        ld (ix+C_BUMP),0
        ret

rand:   push hl
        ld hl,(seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (seed),hl
        pop hl
        ret

; ---------------------------------------------------------------- collisions
; player z (units) relative to a car: dz = car - (cam + PLAYERZ)
collide_cars:
        ld a,(gstate)
        or a
        ret nz
        ld ix,cars
        ld b,NCARS
.l:     push bc
        ld a,(ix+C_ON)
        or a
        jr z,.n
        ld a,(ix+C_BUMP)
        or a
        jr nz,.n
        ld a,(pos_s)
        ld e,a
        ld a,(ix+C_SL)
        sub e
        cp 3
        jr nc,.n                ; more than 2 segments apart (or behind)
        ; dz = (car_s - pos_s)*256 + car_f - pos_f - PLAYERZ
        ld a,(pos_s)
        ld e,a
        ld a,(ix+C_SL)
        sub e
        ld h,a
        ld a,(pos_s+1)
        ld e,a
        ld a,(ix+C_SH)
        sbc a,e
        jr nz,.n                ; > 256 segments apart
        ld l,(ix+C_F)
        ld a,(pos_f)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,PLAYERZ
        sbc hl,de               ; HL = dz
        ; |dz| < 150 ?
        ld de,150
        add hl,de
        ld de,300
        or a
        sbc hl,de
        jr nc,.n
        ; |dx| < 52 units: car x*3 vs camx
        ld a,(ix+C_X)
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; x*3
        ld de,(camx)
        or a
        sbc hl,de
        ld de,52
        add hl,de
        ld de,104
        or a
        sbc hl,de
        jr nc,.n
        call car_hit
.n:     ld de,C_LEN
        add ix,de
        pop bc
        djnz .l
        ret

; the player has touched car IX
car_hit:
        ld (ix+C_BUMP),12
        ; closing speed = player kmh - car kmh
        ld hl,(speed)
        ld a,h
        add hl,hl
        add hl,hl               ; H = kmh (approx, /64*256)
        ld a,(ix+C_SPD)
        add a,a
        ld e,a
        ld a,h
        sub e
        jr c,.slow              ; car is faster: just a nudge
        cp 150
        jr nc,.crash
        ; bump: drop to the car's speed less a bit, push the car on
.slow:  ld a,(ix+C_SPD)
        add a,a
        sub 20
        jr nc,.s1
        xor a
.s1:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *64
        ld de,(speed)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.ns               ; never speed the player up
        ld (speed),hl
.ns:    ld a,(ix+C_F)           ; car shoved forward 80 units
        add a,80
        ld (ix+C_F),a
        jr nc,.s2
        inc (ix+C_SL)
        jr nz,.s2
        inc (ix+C_SH)
.s2:    ; and sideways, away from the player
        ld a,(ix+C_X)
        ld hl,(camx)
        sra h
        rr l
        ld b,a
        ld a,l                  ; (approx camx/2 vs x*3; sign is what matters)
        ld a,b
        bit 7,h
        jr nz,.r
        sub 12
        jr .w
.r:     add a,12
.w:     ld (ix+C_X),a
        ld (ix+C_TX),a
        jp sfx_bump
.crash: jp start_crash

; roadside objects: only when well off the road and fast
collide_objects:
        ld a,(gstate)
        or a
        ret nz
        ld a,(offroad)
        or a
        ret z
        ld hl,(speed)
        ld de,90*64
        or a
        sbc hl,de
        ret c
        ld hl,(obj_ptr)
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp $FF
        ret z
        push hl
        ld hl,(pos_s)
        inc hl
        ex de,hl
        or a
        sbc hl,de               ; obj - (pos+1)
        bit 7,h
        jr nz,.behind
        ld a,h
        or a
        jr nz,.stop
        ld a,l
        cp 2
        jr nc,.stop
        pop hl
        ; type and x
        ld a,(hl)
        push hl
        ld hl,solid_tab
        add a,l
        ld l,a
        jr nc,.t
        inc h
.t:     ld a,(hl)
        pop hl
        or a
        jr z,.nx
        inc hl
        ld a,(hl)               ; x/3
        dec hl
        push hl
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,(camx)
        or a
        sbc hl,de
        ld de,60
        add hl,de
        ld de,120
        or a
        sbc hl,de
        pop hl
        jp c,start_crash
.nx:    inc hl
        inc hl
        jr .l
.behind: pop hl
        jr .nx
.stop:  pop hl
        ret

start_crash:
        ld a,ST_CRASH
        ld (gstate),a
        ld a,30
        ld (crash_t),a
        call sfx_crash
        ld a,MSG_CRASH
        jp show_msg

; ---------------------------------------------------------------- checkpoints / gantries
upd_checkpoint:
        ld a,(gan_seg+1)
        cp $FF
        ret z
        ld hl,(gan_seg)
        ld de,(pos_s)
        inc de                  ; the player is ~1 segment ahead of the camera
        or a
        sbc hl,de
        ret nc                  ; not reached yet
        ; passed this gantry
        ld a,(gan_kind)
        cp G_CHECK
        jr z,.check
        cp G_FINISH
        jr z,.finish
        cp G_SECTION
        jr z,.section
        jr .next
.check: call add_time
        call sfx_check
        ld a,MSG_CHECK
        call show_msg
        jr .next
.section:
        call add_time
        call sfx_check
        ld a,1
        ld (want_load),a        ; load the next section at the end of this frame
        jr .next
.finish:
        ld a,ST_DONE
        ld (gstate),a
        ld a,60
        ld (end_t),a
        call sfx_finish
        ld a,MSG_FINISH
        call show_msg
.next:  jp next_gantry

; fetch the next gantry from the section's list into gan_seg/gan_kind/gan_time
next_gantry:
        ld hl,(gan_ptr)
        ld a,MAP_RACE
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (gan_seg),de
        ld a,(hl)
        inc hl
        ld (gan_kind),a
        ld a,(hl)
        inc hl
        ld (gan_time),a
        ld (gan_ptr),hl
        ret

add_time:
        ld a,(gan_time)
        ld hl,tleft
        add a,(hl)
        cp 100
        jr c,.t
        ld a,99
.t:     ld (hl),a
        ld a,1
        ld (hud_tdirty),a
        ret

; ---------------------------------------------------------------- timer
upd_timer:
        ld a,(dtf)
        ld hl,tsub
        add a,(hl)
        ld (hl),a
        cp 50
        ret c
        sub 50
        ld (hl),a
        ld hl,tleft
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ld a,1
        ld (hud_tdirty),a
        ld a,(hl)
        cp 6
        call c,sfx_tick
        ld a,(tleft)
        or a
        ret nz
        ld a,ST_OVER
        ld (gstate),a
        ld a,80
        ld (end_t),a
        ld a,MSG_TIMEUP
        jp show_msg

; ---------------------------------------------------------------- score
; distance travelled + overtakes: add speed/64/16 each frame
upd_score:
        ld a,(gstate)
        or a
        ret nz
        ld hl,(speed)
        ld a,h
        srl a
        srl a
        ret z
        cp 10                   ; (to BCD: 0..18)
        jr c,.bcd
        add a,6
.bcd:   ld b,a
        ld hl,score+2
        ld a,(hl)
        add a,b
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,(frames)
        and 7
        ret nz
        ld a,1
        ld (hud_sdirty),a
        ret

; ---------------------------------------------------------------- engine sound
; pitch follows rpm: 5 gears, rpm = (kmh - gear base) scaled
upd_engine:
        ld hl,(speed)
        ld a,h                  ; kmh/4 (0..75)
        ld b,0
        ld c,a
.g:     ld a,c
        cp 16
        jr c,.r
        sub 13
        ld c,a
        inc b
        ld a,b
        cp 4
        jr c,.g
.r:     ld a,c                  ; 0..~23 within the gear
        add a,a
        add a,a
        add a,a
        add a,30
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld a,(gstate)
        cp ST_CRASH
        jr nz,.e
        ld hl,0
.e:     ld (snd_inc),hl
        ld a,(offroad)
        ld (snd_noise),a
        ret
