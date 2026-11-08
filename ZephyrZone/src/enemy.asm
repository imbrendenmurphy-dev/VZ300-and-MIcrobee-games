; =====================================================================
;  enemy.asm - everything that moves: shots, creatures, formations,
;  explosions, power-ups, collisions
; =====================================================================
K_SCEN      equ 1
K_BOLT      equ 2
K_ENEMY     equ 3
K_ESHOT     equ 4
K_BOOM      equ 5
K_ORB       equ 6
K_BOSS      equ 7
K_BSEG      equ 8
K_FALL      equ 9           ; shot down: tumbling to the ground in flames
K_GFIRE     equ 10          ; burning on the ground

B_WAVE      equ 0           ; approach, weaving x (and a little y)
B_RING      equ 1           ; approach, circling
B_HOP       equ 2           ; bouncing along the ground
B_SWOOP     equ 3           ; fly away into the distance, then turn and attack
B_DIVE      equ 4           ; approach high, then dive at the hero's height
B_SPIRAL    equ 5           ; a ring that opens out as it turns


BOLT_V      equ 56          ; bolt speed (units per field, away from us)
HERO_CY     equ 28          ; hero's centre above his feet (units)

; ---------------------------------------------------------------------
; helpers
; ---------------------------------------------------------------------
; HL = A (signed) * dt
mul_dt:
            ld l,a
            rla
            sbc a,a
            ld h,a
            ld a,(dt)
            dec a
            ret z
            ld d,h
            ld e,l
.l:         add hl,de
            dec a
            jr nz,.l
            ret

; z(IX) += HL
z_add:
            ld e,(ix+O_Z)
            ld d,(ix+O_Z+1)
            add hl,de
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ret

; HL = sin(A) * C / 128 (signed), A = phase 0..255
sinmul:
            rrca
            rrca
            and 63
            ld e,a
            ld d,0
            ld hl,sintab
            add hl,de
            ld a,(hl)
            or a
            jp p,.p
            neg
            call mul88
            add hl,hl
            ld l,h
            ld h,0
            xor a
            sub l
            ld l,a
            sbc a,a
            ld h,a
            ret
.p:         call mul88
            add hl,hl
            ld l,h
            ld h,0
            ret

; free the object (bookkeeping for bolts)
kill_ix:
            ld a,(ix+O_KIND)
            cp K_BOLT
            jr nz,.k
            ld hl,nbolts
            dec (hl)
.k:         ld (ix+O_KIND),0
            ret

; ---------------------------------------------------------------------
; update every object (mapping 7)
; ---------------------------------------------------------------------
update_objects:
            ; list the shootable objects once (the bolts check only these)
            ld ix,objs
            ld hl,tgt_list
            ld b,NOBJ
            ld c,0
.t:         ld a,(ix+O_KIND)
            or a
            jr z,.tn
            bit 3,(ix+O_FLAGS)
            jr z,.tn
            ld (dl_t),ix
            ld a,(dl_t)
            ld (hl),a
            inc hl
            ld a,(dl_t+1)
            ld (hl),a
            inc hl
            inc c
.tn:        ld de,OSIZE
            add ix,de
            djnz .t
            ld a,c
            ld (tgt_n),a
            ld ix,objs
            ld b,NOBJ
.l:         push bc
            ld a,(ix+O_KIND)
            or a
            jr z,.n
            add a,a
            ld e,a
            ld d,0
            ld hl,kind_tab-2
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            call .jp
.n:         ld de,OSIZE
            add ix,de
            pop bc
            djnz .l
            ret
.jp:        jp (hl)
kind_tab:   dw upd_none,upd_bolt,upd_enemy,upd_eshot,upd_boom,upd_orb,WJ_BUPD,WJ_BSEG,upd_fall,upd_gfire
upd_none:   ret

; ---------------------------------------------------------------------
; the hero's bolts
; ---------------------------------------------------------------------
upd_bolt:
            ld a,BOLT_V
            call mul_dt
            call z_add
            ld de,2100
            or a
            sbc hl,de
            jp nc,kill_ix
            ; spread
            ld a,(ix+O_VX)
            or a
            jr z,.nx
            call mul_dt
            ld e,(ix+O_X)
            ld d,(ix+O_X+1)
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
.nx:        ; collide with anything shootable whose z is in [z - v*dt - 50, z + 40]
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld de,40
            add hl,de
            ld (cz_hi),hl
            ld a,BOLT_V+20
            call mul_dt
            ld de,10
            add hl,de
            ex de,hl
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            or a
            sbc hl,de
            jr nc,.lo
            ld hl,0
.lo:        ld (cz_lo),hl
            push ix
            pop iy
            ld a,(tgt_n)
            or a
            jp z,.none
            ld b,a
            ld hl,tgt_list
.c:         ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (tgt_p),hl
            ld (dl_t),de
            ld ix,(dl_t)
            bit 3,(ix+O_FLAGS)
            jp z,.cn
            ld a,(ix+O_KIND)
            or a
            jp z,.cn
            ; z window
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld de,(cz_lo)
            or a
            sbc hl,de
            jr c,.cn
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld de,(cz_hi)
            or a
            sbc hl,de
            jr nc,.cn
            ; |dx| < hr + 8
            ld l,(ix+O_X)
            ld h,(ix+O_X+1)
            ld e,(iy+O_X)
            ld d,(iy+O_X+1)
            or a
            sbc hl,de
            call abs_hl
            ld a,(ix+O_HR)
            add a,8
            ld e,a
            ld d,0
            or a
            sbc hl,de
            jr nc,.cn
            ; scenery stands on the ground: hit anywhere up its height
            ld a,(ix+O_KIND)
            cp K_SCEN
            jr nz,.ny
            ld a,(ix+O_BY)
            add a,24                ; (generous: a bolt just over the top counts)
            jr c,.hit
            cp (iy+O_Y)
            jr c,.cn
            jr .hit
.ny:        ; |(y + hr) - by| < hr + 8
            ld a,(ix+O_Y)
            add a,(ix+O_HR)
            ld l,a
            ld h,0
            jr nc,.y1
            inc h
.y1:        ld e,(iy+O_Y)
            ld d,0
            or a
            sbc hl,de
            call abs_hl
            ld a,(ix+O_HR)
            add a,8
            ld e,a
            ld d,0
            or a
            sbc hl,de
            jr nc,.cn
.hit:       call hit_obj
            push iy
            pop ix
            jp kill_ix
.cn:        ld hl,(tgt_p)
            dec b
            jp nz,.c
.none:      push iy
            pop ix
            ret

abs_hl:
            bit 7,h
            ret z
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
            ret

; a bolt hit IX
hit_obj:
            ld a,(ix+O_KIND)
            cp K_BSEG
            jr nz,.nseg
            ld a,SFX_CLINK          ; armoured segments just shrug
            jp sfx
.nseg:      cp K_BOSS
            jr nz,.nb
            push iy                 ; (the bolt: the boss code uses IY)
            call WJ_BHIT
            pop iy
            ret
.nb:
            dec (ix+O_HP)
            jr z,.dead
            ld (ix+O_TIMER),4       ; flash
            ld a,SFX_KNOCK
            jp sfx
.dead:      ; score
            ld a,(ix+O_PTS)
            call add_score10
            ld a,(ix+O_KIND)
            cp K_ENEMY
            jp nz,explode_ix        ; scenery blows apart
            ld hl,(kills)
            inc hl
            ld (kills),hl
            ; formation bookkeeping: whole formation down -> power-up orb
            ld a,(ix+O_STATE)
            and 7
            ld e,a
            ld d,0
            ld hl,fkill
            add hl,de
            inc (hl)
            ld a,(hl)
            ld hl,fcount
            add hl,de
            cp (hl)
            jr nz,.nodrop
            ld a,(hl)
            cp 3
            jr c,.nodrop
            call spawn_orb_here
.nodrop:    ; tumble down in flames, carried along with the ground
            ld (ix+O_KIND),K_FALL
            ld (ix+O_FLAGS),F_WORLD|F_SHADOW
            ld (ix+O_VFALL),1
            ld a,SFX_KILL
            jp sfx

upd_fall:
            ld a,(dt)
            ld b,a
.f:         ld a,(ix+O_VFALL)
            inc a
            cp 9
            jr c,.v
            ld a,8
.v:         ld (ix+O_VFALL),a
            ld c,a
            ld a,(ix+O_Y)
            sub c
            jr c,.land
            jr z,.land
            ld (ix+O_Y),a
            djnz .f
            ld a,(anim)             ; tumbling
            rrca
            and 1
            ld (ix+O_FRAME),a
            ret
.land:      ld (ix+O_Y),0
            ld (ix+O_KIND),K_GFIRE
            ld (ix+O_SPR),T_FLAME
            ld (ix+O_TIMER),0
            ld (ix+O_FLAGS),F_WORLD
            ld a,SFX_BOOM
            jp sfx

upd_gfire:
            ld a,(dt)
            add a,(ix+O_TIMER)
            ld (ix+O_TIMER),a
            cp 90
            jp nc,kill_ix
            ld a,(anim)
            rrca
            and 1
            ld (ix+O_FRAME),a
            ret

; turn IX into an explosion where it is
explode_ix:
            ld (ix+O_KIND),K_BOOM
            ld (ix+O_SPR),T_BOOM
            ld (ix+O_FRAME),0
            ld (ix+O_TIMER),0
            ld (ix+O_FLAGS),F_WORLD
            ld a,SFX_BOOM
            jp sfx

; ---------------------------------------------------------------------
; creatures
; ---------------------------------------------------------------------
upd_enemy:
            ; flash timer
            ld a,(ix+O_TIMER)
            or a
            jr z,.nf
            dec (ix+O_TIMER)
.nf:        ; approach, hover in front of the hero for a while, then charge
            ld a,(ix+O_PHASE)
            or a
            jr nz,.ph1
            ld a,(ix+O_VZ)
            or a
            jp p,.mv                ; (swoopers fly away first)
            ld a,(ix+O_Z+1)         ; z/8 reached the hover depth?
            cp 8
            jr nc,.mv               ; (still beyond 2048: z/8 won't fit a byte)
            ld b,(ix+O_Z)
            srl a
            rr b
            srl a
            rr b
            srl a
            rr b
            ld a,b
            cp (ix+O_HOLDZ)
            jr nc,.mv
            ld (ix+O_PHASE),1
            ld l,(ix+O_HOLDZ)       ; settle exactly at the hover depth
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            jr .hov
.ph1:       dec a
            jr nz,.mv               ; charging: full speed
            ld a,(dt)
            ld b,a
            ld a,(ix+O_HOLD)
            sub b
            jr nc,.hl
            xor a
.hl:        ld (ix+O_HOLD),a
            or a
            jr nz,.hov
            ld (ix+O_HOLD),HOVER_T  ; they stay until they are shot down
.hov:       xor a                   ; holding station (weaving in place)
            jr .mv2
.mv:        ld a,(ix+O_VZ)
.mv2:       call mul_dt
            call z_add
            ; passed us or gone far away?
            ld a,h
            or a
            jr nz,.zfar
            ld a,l
            cp 64
            jp c,kill_ix
            cp 240                  ; level with the hero or behind, and not
            jr nc,.zok              ; flying away (a swooper setting off):
            ld a,(ix+O_VZ)          ; out of reach, so it leaves the stage
            dec a
            jp m,kill_ix
            jr .zok
.zfar:      cp 9
            jp nc,kill_ix           ; z >= 2304
.zok:       ; phase
            ld a,(ix+O_PARAM)
            ld b,a
            ld a,(dt)
            ld c,a
            xor a
.ph:        add a,b
            dec c
            jr nz,.ph
            add a,(ix+O_PH)
            ld (ix+O_PH),a
            ; behaviour
            ld a,(ix+O_BEH)
            add a,a
            ld e,a
            ld d,0
            ld hl,beh_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            call upd_none_jp
            ; keep within the hero's reach: he can fly 150 either side of the
            ; middle, so a creature further out than 140 could never be shot
            ld l,(ix+O_X)
            ld h,(ix+O_X+1)
            bit 7,h
            jr nz,.xn
            ld de,-141
            add hl,de
            jr nc,.xok
            ld hl,140
            jr .xs
.xn:        ld de,141
            add hl,de
            jr c,.xok
            ld hl,-140
.xs:        ld (ix+O_X),l
            ld (ix+O_X+1),h
.xok:       ; animation: frames cycle with the clock
            ld a,(anim)
            rrca
            rrca
            and 3
            cp 3
            jr c,.fr
            ld a,1
.fr:        ld (ix+O_FRAME),a
            ; firing: O_VY = interval (0 = never), O_VX = countdown
            ld a,(ix+O_VY)
            or a
            ret z
            ld a,(ix+O_PHASE)
            cp 2
            ret z
            ld a,(ix+O_Z+1)
            or a
            ret z                   ; closer than 256: no more shots
            cp 6
            ret nc                  ; farther than 1536
            ld a,(dt)
            ld c,a
            ld a,(ix+O_VX)
            sub c
            jr c,.fire
            jr z,.fire
            ld (ix+O_VX),a
            ret
.fire:      ld a,(ix+O_VY)
            ld (ix+O_VX),a
            jp spawn_fireball
upd_none_jp: jp (hl)
beh_tab:    dw beh_wave,beh_ring,beh_hop,beh_swoop,beh_dive,beh_spiral

; x = bx + sin(ph) * amp ; y = by + sin(2 ph) * amp / 4
beh_wave:
            ld a,(ix+O_PH)
            ld c,(ix+O_AMP)
            call sinmul
            ld e,(ix+O_BX)
            ld d,(ix+O_BX+1)
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ld a,(ix+O_AMP)
            srl a
            srl a
            ld c,a
            ld a,(ix+O_PH)
            add a,a
            call sinmul
            ld a,(ix+O_BY)
            add a,l
            ld (ix+O_Y),a
            ret

; x = bx + cos(ph) * amp ; y = by + sin(ph) * amp / 2
beh_ring:
            ld a,(ix+O_PH)
            add a,64
            ld c,(ix+O_AMP)
            call sinmul
            ld e,(ix+O_BX)
            ld d,(ix+O_BX+1)
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ld a,(ix+O_AMP)
            srl a
            ld c,a
            ld a,(ix+O_PH)
            call sinmul
            ld a,(ix+O_BY)
            add a,l
            ld (ix+O_Y),a
            ret

; ring opening out to its full size (BY holds the target radius in O_HR's place)
beh_spiral:
            ld a,(ix+O_AMP)
            cp 120
            jp nc,beh_ring
            inc a
            inc a
            ld (ix+O_AMP),a
            jp beh_ring

; y = |sin(ph)| * amp (bouncing); squash frames follow the bounce
beh_hop:
            ld a,(ix+O_PH)
            and $7F
            ld c,(ix+O_AMP)
            call sinmul
            ld a,l
            ld (ix+O_Y),a
            ret

; fly away (vz > 0) until z > 1400, then turn round and come back weaving
beh_swoop:
            ld a,(ix+O_VZ)
            or a
            jp m,beh_wave
            ld a,(ix+O_Z+1)
            cp 5
            jr c,.go
            ld a,(ix+O_Z)
            cp $78
            jr c,.go
            ld (ix+O_VZ),-18        ; z > $578 (1400): turn
            ld (ix+O_BEH),B_WAVE
            ld l,(ix+O_X)
            ld h,(ix+O_X+1)
            ld (ix+O_BX),l
            ld (ix+O_BX+1),h
            ld (ix+O_PH),0
.go:        ; drift towards the middle while flying away
            ld l,(ix+O_X)
            ld h,(ix+O_X+1)
            ld de,(camx)
            or a
            sbc hl,de
            ld a,(dt)
            ld de,-3
            bit 7,h
            jr z,.r
            ld de,3
.r:         ld l,(ix+O_X)
            ld h,(ix+O_X+1)
.d:         add hl,de
            dec a
            jr nz,.d
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ret

; approach high; once nearer than 1000 sink towards the hero's height
beh_dive:
            call beh_wave
            ld a,(ix+O_Z+1)
            cp 4
            ret nc
            ld a,(py)
            add a,10
            ld c,a
            ld a,(ix+O_BY)
            cp c
            ret z
            jr c,.up
            sub 3
            jr .s
.up:        add a,3
.s:         ld (ix+O_BY),a
            ret

; ---------------------------------------------------------------------
; enemy fireballs: aimed at where the hero is now, 8.8 fixed x/y
; ---------------------------------------------------------------------
MAXSHOT     equ 6           ; enemy orbs in the air at once
HOVER_T     equ 250         ; fields a formation holds station
ESHOT_T     equ 110         ; fields to reach the hero's depth (approx)
spawn_fireball:
            push ix
            pop iy
            ld a,K_ESHOT
            call count_kind
            ld a,c
            cp MAXSHOT
            jp nc,.no               ; enough orbs in the air
            ld a,(sr_free)
            cp 4
            jp c,.no                ; keep slots for the hero's bolts
            call obj_alloc
            jp c,.no
            ld (ix+O_KIND),K_ESHOT
            ld (ix+O_SPR),T_FIREBALL
            ld (ix+O_FLAGS),F_HITS|F_ESHOT
            ld (ix+O_HR),7
            ld a,(iy+O_X)
            ld (ix+O_X),a
            ld a,(iy+O_X+1)
            ld (ix+O_X+1),a
            ld a,(iy+O_Y)
            add a,6
            ld (ix+O_Y),a
            ld a,(iy+O_Z)
            ld (ix+O_Z),a
            ld a,(iy+O_Z+1)
            ld (ix+O_Z+1),a
            ; vz = -ceil((z - ZP) / ESHOT_T) whole units a field; then the real
            ; flight time T = (z - ZP) / |vz|, so x and y arrive just as it does
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld de,ZP
            or a
            sbc hl,de
            jp c,.gone              ; (level with the hero: no shot)
            push hl
            ld c,ESHOT_T
            call div16_8            ; HL / C -> HL, A = remainder
            or a
            jr z,.q
            inc l
.q:         ld a,l
            or a
            jr nz,.q1
            inc a
.q1:        ld c,a
            neg
            ld (ix+O_VZ),a
            pop hl
            call div16_8            ; T = (z - ZP) / |vz|
            ld a,l
            or a
            jr nz,.t1
            inc a
.t1:        ld (sh_t),a
            ; vx (8.8) = (px - x) * 256 / T  -> store in BX (lo, hi) ; frac in AMP
            ld hl,(px)
            ld e,(ix+O_X)
            ld d,(ix+O_X+1)
            or a
            sbc hl,de
            call fx_div_t
            ld (ix+O_BX),l
            ld (ix+O_BX+1),h
            ; vy (8.8) = (py + HERO_CY - y) * 256 / T  -> PH (lo), BEH (hi)
            ld a,(py)
            add a,HERO_CY
            ld l,a
            ld h,0
            ld e,(ix+O_Y)
            ld d,0
            or a
            sbc hl,de
            call fx_div_t
            ld (ix+O_PH),l
            ld (ix+O_BEH),h
            ld (ix+O_AMP),0         ; x fraction
            ld (ix+O_PTS),0         ; y fraction
            ld a,SFX_SPIT
            call sfx
.no:        push iy
            pop ix
            ret
.gone:      call kill_ix
            jr .no

; HL (signed) * 256 / ESHOT_T -> HL (8.8 per field)
fx_div_t:
            ld a,h
            push af
            call abs_hl
            ld h,l
            ld l,0                  ; *256 (|v| < 256 assumed)
            ld a,(sh_t)             ; over the orb's real flight time
            ld c,a
            call div16_8
            pop af
            rla
            ret nc
            jp neg_hl

neg_hl:
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
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

upd_eshot:
            ld a,(ix+O_VZ)
            call mul_dt
            call z_add
            ld a,h
            or a
            jr nz,.ok
            ld a,l
            cp 70
            jp c,kill_ix
.ok:        ld a,(dt)
            ld b,a
.st:        ; x += vx (8.8)
            ld a,(ix+O_AMP)
            add a,(ix+O_BX)
            ld (ix+O_AMP),a
            ld a,(ix+O_X)
            adc a,(ix+O_BX+1)
            ld (ix+O_X),a
            ld a,(ix+O_BX+1)
            rla
            sbc a,a
            adc a,(ix+O_X+1)
            ld (ix+O_X+1),a
            ; y += vy (8.8)
            ld a,(ix+O_PTS)
            add a,(ix+O_PH)
            ld (ix+O_PTS),a
            ld a,(ix+O_Y)
            adc a,(ix+O_BEH)
            ld (ix+O_Y),a
            djnz .st
            ld a,(anim)
            rrca
            and 1
            ld (ix+O_FRAME),a
            ret

; ---------------------------------------------------------------------
; explosions and power-up orbs
; ---------------------------------------------------------------------
upd_boom:
            ld a,(dt)
            add a,(ix+O_TIMER)
            ld (ix+O_TIMER),a
            cp 15
            jp nc,kill_ix
            ld e,0
            cp 5
            jr c,.f
            inc e
            cp 10
            jr c,.f
            inc e
.f:         ld (ix+O_FRAME),e
            ret

spawn_orb_here:
            push iy                 ; (the caller's bolt)
            push ix
            pop iy
            call obj_alloc
            jr c,.no
            ld (ix+O_KIND),K_ORB
            ld (ix+O_SPR),T_ORB
            ld (ix+O_FLAGS),F_WORLD|F_SHADOW
            ld (ix+O_HR),14
            ld a,(iy+O_X)
            ld (ix+O_X),a
            ld a,(iy+O_X+1)
            ld (ix+O_X+1),a
            ld a,(iy+O_Y)
            ld (ix+O_BY),a
            ld a,(iy+O_Z)
            ld (ix+O_Z),a
            ld a,(iy+O_Z+1)
            ld (ix+O_Z+1),a
.no:        push iy
            pop ix
            pop iy
            ret

upd_orb:
            ld a,(anim)
            rrca
            rrca
            and 1
            ld (ix+O_FRAME),a
            ; drift towards the hero's height so he can catch it
            ld a,(py)
            add a,10
            ld c,a
            ld a,(ix+O_BY)
            cp c
            jr z,.b
            jr c,.u
            dec a
            jr .s
.u:         inc a
.s:         ld (ix+O_BY),a
.b:         ld a,(anim)
            add a,a
            add a,a
            ld c,10
            call sinmul
            ld a,(ix+O_BY)
            add a,l
            ld (ix+O_Y),a
            ret

; ---------------------------------------------------------------------
; formations: spawn from a stage event (HL -> parameters)
;   db pattern, spr, count, x/4 (signed), y, amp, speed, fire, pts/10, hp
; ---------------------------------------------------------------------
P_LINE      equ 0
P_SNAKE     equ 1
P_RING      equ 2
P_HOP       equ 3
P_SWOOP     equ 4
P_DIVE      equ 5
P_CROSS     equ 6           ; pairs sweeping in from both sides, crossing
P_SPIRAL    equ 7           ; a tight ring that turns and opens out

spawn_wave:
            ld de,wv_pat
            ld bc,10
            ldir
            push hl
            ; formation slot
            ld a,(fnext)
            inc a
            and 7
            ld (fnext),a
            ld e,a
            ld d,0
            ld hl,fkill
            add hl,de
            ld (hl),0
            ld hl,fcount
            add hl,de
            ld a,(wv_n)
            ld (hl),a
            xor a
            ld (wv_i),a
.m:         call obj_alloc
            jp c,.done
            ld (ix+O_KIND),K_ENEMY
            ld a,(wv_spr)
            ld (ix+O_SPR),a
            ld (ix+O_FLAGS),F_HITS|F_SHOOT
            ld a,(wv_hp)
            ld (ix+O_HP),a
            ld a,(wv_pts)
            ld (ix+O_PTS),a
            ld a,(fnext)
            ld (ix+O_STATE),a
            ld a,(wv_spr)           ; this world's hit radius for the type
            sub S_EN1
            ld e,a
            ld d,0
            ld hl,W_EHR
            add hl,de
            ld a,(hl)
            ld (ix+O_HR),a
            ld a,(wv_amp)
            ld (ix+O_AMP),a
            ld a,(wv_y)
            ld (ix+O_BY),a
            ld (ix+O_Y),a
            ld a,(wv_spd)
            neg
            ld (ix+O_VZ),a
            ld a,(wv_fire)
            ld (ix+O_VY),a          ; fire interval (0 = never)
            ; first shot after a random wait
            or a
            jr z,.nfire
            call random
            and 63
            ld (ix+O_VX),a
.nfire:     ld (ix+O_PARAM),4       ; phase speed
            ; base x = x/4 * 4 + camx
            ld a,(wv_x)
            ld l,a
            rla
            sbc a,a
            ld h,a
            add hl,hl
            add hl,hl
            ld de,(camx)
            add hl,de
            ld (ix+O_BX),l
            ld (ix+O_BX+1),h
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ld hl,1900
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ld a,(wv_i)
            ld c,a
            ; hover in front of the hero: depth z/8 = 38 + 7i (300 + 56i units)
            add a,a
            add a,a
            add a,a
            sub c
            add a,38
            ld (ix+O_HOLDZ),a
            ld (ix+O_HOLD),HOVER_T
            ; approach at 3/4 of the wave's speed
            ld a,(wv_spd)
            ld b,a
            srl a
            srl a
            sub b
            ld (ix+O_VZ),a
            ; per pattern placement
            ld a,(wv_pat)
            or a
            jr nz,.ns0
            ; LINE: spread 70 units apart, phases staggered
            ld (ix+O_BEH),B_WAVE
            ld a,c
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a
            ld (ix+O_PH),a
            ld a,(wv_n)
            dec a
            ld b,a
            ld a,c
            add a,a
            sub b                   ; 2i - (n-1)
            ld l,a
            rla
            sbc a,a
            ld h,a
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl               ; *32
            add hl,de
            add hl,de
            add hl,de               ; *35
            ld e,(ix+O_BX)
            ld d,(ix+O_BX+1)
            add hl,de
            ld (ix+O_BX),l
            ld (ix+O_BX+1),h
            jp .next
.ns0:       dec a
            jr nz,.ns1
            ; SNAKE: one behind another, same path, phase lag
            ld (ix+O_BEH),B_WAVE
            ld a,c
            add a,a
            add a,a
            add a,a
            add a,a
            neg
            ld (ix+O_PH),a
            ld (ix+O_PARAM),3
            call .zstep
            jp .next
.ns1:       dec a
            jr nz,.ns2
            ; RING: spaced round a circle
            ld (ix+O_BEH),B_RING
            ld b,c
            xor a
            inc b
.rg:        dec b
            jr z,.rg2
            add a,43
            jr .rg
.rg2:       ld (ix+O_PH),a
            ld (ix+O_PARAM),3
            jp .next
.ns2:       dec a
            jr nz,.ns3
            ; HOP: on the ground, staggered
            ld (ix+O_BEH),B_HOP
            ld (ix+O_BY),0
            ld (ix+O_FLAGS),F_HITS|F_SHOOT|F_SHADOW
            ld a,c
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a
            ld (ix+O_PH),a
            ld (ix+O_PARAM),5
            call .zstep
            ld a,c
            and 1
            ld hl,60
            jr z,.hx
            ld hl,-60
.hx:        ld e,(ix+O_BX)
            ld d,(ix+O_BX+1)
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            jp .next
.ns3:       dec a
            jr nz,.ns4
            ; SWOOP: from beside the hero out into the distance and back
            ld (ix+O_BEH),B_SWOOP
            ld a,(wv_spd)
            ld (ix+O_VZ),a
            ld hl,150
            ld a,c
            add a,a
            add a,a
            add a,a
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            jr .next
.ns4:       dec a
            jr z,.ns5
            dec a
            jr nz,.ns6
            ; CROSS: weave right across the view, alternate members opposite
            ld (ix+O_BEH),B_WAVE
            ld (ix+O_PARAM),3
            ld a,c
            rrca
            and $80
            ld (ix+O_PH),a
            ld a,c
            srl a
            ld c,a
            call .zstep
            jr .next
.ns6:       ; SPIRAL: starts as a tight ring, opens out while turning
            ld (ix+O_BEH),B_SPIRAL
            ld (ix+O_AMP),10
            ld (ix+O_PARAM),5
            ld b,c
            xor a
            inc b
.sp:        dec b
            jr z,.sp2
            add a,43
            jr .sp
.sp2:       ld (ix+O_PH),a
            jr .next
.ns5:       ; DIVE: high, then down at the hero
            ld (ix+O_BEH),B_DIVE
            ld a,c
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a
            ld (ix+O_PH),a
            call .zstep
.next:      ld a,(wv_i)
            inc a
            ld (wv_i),a
            ld hl,wv_n
            cp (hl)
            jp c,.m
.done:      pop hl
            ret
.zstep:     ; z += i * 110
            ld a,c
            or a
            ret z
            ld b,a
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld de,110
.zs:        add hl,de
            djnz .zs
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ret

; ---------------------------------------------------------------------
; the hero bumps into things
; ---------------------------------------------------------------------
hero_collide:
            ld a,(dead)
            or a
            ret nz
            ld ix,objs
            ld b,NOBJ
.l:         push bc
            ld a,(ix+O_KIND)
            or a
            jr z,.n
            ; z within ZP-36 .. ZP+36 ?
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld de,ZP-36
            or a
            sbc hl,de
            jr c,.n
            ld de,72
            sbc hl,de
            jr nc,.n
            ld a,(ix+O_KIND)
            cp K_SCEN
            jr z,.scen
            cp K_ORB
            jr z,.orb
            bit 1,(ix+O_FLAGS)
            jr z,.n
            call .near
            jr nc,.n
            ; hit by a creature or a fireball
            ld a,(ix+O_KIND)
            cp K_ENEMY
            jr nz,.nk
            push ix
            call explode_ix
            pop ix
            jr .hurt
.nk:        cp K_ESHOT
            jr nz,.hurt
            call kill_ix
.hurt:      call hero_hurt
            jr .n
.orb:       call .near
            jr nc,.n
            call kill_ix
            call powerup
            jr .n
.scen:      bit 5,(ix+O_FLAGS)
            jr z,.n
            ld a,(py)
            cp (ix+O_BY)            ; obstacle height
            jr nc,.n
            call .dx
            jr nc,.n
            call hero_hurt
.n:         ld de,OSIZE
            add ix,de
            pop bc
            dec b
            jp nz,.l
            ret
; C if |x - px| < hr + 10 and |y + hr - (py + HERO_CY)| < hr + 16
.near:      call .dx
            ret nc
            ld a,(ix+O_Y)
            add a,(ix+O_HR)
            ld l,a
            ld h,0
            jr nc,.y
            inc h
.y:         ld a,(py)
            add a,HERO_CY
            ld e,a
            ld d,0
            or a
            sbc hl,de
            call abs_hl
            ld a,(ix+O_HR)
            add a,16
            ld e,a
            ld d,0
            or a
            sbc hl,de
            ret
.dx:        ld l,(ix+O_X)
            ld h,(ix+O_X+1)
            ld de,(px)
            or a
            sbc hl,de
            call abs_hl
            ld a,(ix+O_HR)
            add a,10
            ld e,a
            ld d,0
            or a
            sbc hl,de
            ret

; take a hit (unless invulnerable or shielded)
hero_hurt:
            ld a,(inv)
            or a
            ret nz
            ld a,(shield)
            or a
            jr z,.ns
            xor a
            ld (shield),a           ; the shield absorbs one hit
            ld a,40
            ld (inv),a
            ld a,SFX_CLINK
            jp sfx
.ns:        ld a,(diff)
            cp 2
            ld b,1
            jr nz,.d
            ld b,1
.d:         ld a,(health)
            sub b
            jr nc,.h
            xor a
.h:         ld (health),a
            ld a,1
            ld (hud_dirty),a
            ld a,70
            ld (inv),a
            ld a,(wlevel)           ; lose one weapon level
            or a
            jr z,.w
            dec a
            ld (wlevel),a
.w:         ld a,(health)
            or a
            jr z,.die
            ld a,SFX_HURT
            jp sfx
.die:       ld a,1
            ld (dead),a
            ret

powerup:
            ld a,SFX_POWER
            call sfx
            ld a,50
            call add_score10
            ld a,(wlevel)
            cp 2
            jr nc,.full
            inc a
            ld (wlevel),a
            jr .msg
.full:      ; weapon maxed: heal and shield instead
            ld a,(maxhealth)
            ld hl,health
            cp (hl)
            jr z,.sh
            inc (hl)
.sh:        ld a,250
            ld (shield),a
.msg:       ld a,1
            ld (hud_dirty),a
            ld a,M_POWER
            call to_fe
            dw show_msg
            ret

; count objects of kind A -> C ; free slots -> (sr_free)
count_kind:
            ld (.k+1),a
            ld hl,objs
            ld de,OSIZE
            ld bc,NOBJ*256
            xor a
            ld (sr_free),a
.l:         ld a,(hl)
            or a
            jr nz,.k
            ld a,(sr_free)
            inc a
            ld (sr_free),a
            jr .n
.k:         cp 0
            jr nz,.n
            inc c
.n:         add hl,de
            djnz .l
            ret
