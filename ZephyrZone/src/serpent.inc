; =====================================================================
;  serpent.inc - segmented serpent boss engine (world modules include it)
;  The head weaves a figure-of-eight in front of the hero; NSEG body
;  segments (the last one a tail) follow the head's recorded path.
;  Segments are armoured (shots clink off); hit the head. It snaps its
;  jaw open, then spits a fan of three orbs. Each hit flashes the head
;  white-hot (frame 2), knocks it back and throws sparks.
;  Parameters (equ before including): NSEG, SP_XAMP, SP_YBASE, SP_YAMP,
;  SP_ZBASE, SP_ZAMP, SP_HR, SP_SEGHR
; =====================================================================

boss_start:
            ; make room: clear away creatures, their shots, explosions,
            ; power-ups and the far scenery (the boss needs 9 slots)
            ld ix,objs
            ld b,NOBJ
.cl:        ld a,(ix+O_KIND)
            cp K_SCEN
            jr nz,.cl1
            ld a,(ix+O_Z+1)
            cp 3
            jr c,.cln               ; near scenery stays
            jr .clk
.cl1:       cp K_BOLT
            jr z,.cln
            or a
            jr z,.cln
.clk:       ld (ix+O_KIND),0
.cln:       ld de,OSIZE
            add ix,de
            djnz .cl
            ld a,1
            ld (boss_on),a
            xor a
            ld (boss_t),a
            ld (bhist_p),a
            ld a,(diff)
            ld e,a
            ld d,0
            ld hl,boss_hps
            add hl,de
            ld a,(hl)
            ld (boss_hp),a
            ; head
            call obj_alloc
            ret c
            ld (ix+O_KIND),K_BOSS
            ld (ix+O_SPR),S_BOSSA
            ld (ix+O_FLAGS),F_HITS|F_SHOOT|F_SHADOW
            ld (ix+O_HR),SP_HR
            ld hl,2000
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ld (ix+O_Y),80
            ld hl,(camx)
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ld (ix+O_TIMER),0
            ld (ix+O_VX),90         ; fire countdown
            ; fill the history with the start position
            ld hl,bhist
            ld b,32
.fh:        ld de,(camx)
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld (hl),80
            inc hl
            ld (hl),250             ; z/8
            inc hl
            djnz .fh
            ; body + tail
            ld c,0
.seg:       push bc
            call obj_alloc
            pop bc
            ret c
            ld (ix+O_KIND),K_BSEG
            ld a,S_BOSSB
            ld (ix+O_HR),SP_SEGHR
            ld b,a
            ld a,c
            cp NSEG-1
            ld a,b
            jr nz,.nt
            ld a,S_BOSSC
            ld (ix+O_HR),12
.nt:        ld (ix+O_SPR),a
            ld (ix+O_FLAGS),F_HITS|F_SHOOT|F_SHADOW
            ld (ix+O_PARAM),c
            ld hl,2100
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ld (ix+O_STATE),0
            inc c
            ld a,c
            cp NSEG
            jr nz,.seg
            ld a,(boss_hp)
            ld (boss_max),a
            ld a,1
            ld (hud_dirty),a
            ret
boss_hps:   db 24,36,48

; the head
upd_boss:
            ld a,(ix+O_STATE)
            or a
            jp nz,.dying
            ld a,(ix+O_TIMER)
            or a
            jr z,.nf
            dec (ix+O_TIMER)
.nf:        ld a,(dt)
            ld hl,boss_t
            add a,(hl)
            ld (hl),a
            ; target x = camx + sin(t) * 210
            ld a,(boss_t)
            ld c,SP_XAMP
            call sinmul
            ld de,(camx)
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ; y = 70 + sin(2t) * 45
            ld a,(boss_t)
            add a,a
            ld c,SP_YAMP
            call sinmul
            ld a,SP_YBASE
            add a,l
            ld (ix+O_Y),a
            ; z: glide in to 380 + sin(t/2) * 120
            ld a,(boss_t)
            srl a
            add a,64
            ld c,SP_ZAMP
            call sinmul
            ld de,SP_ZBASE
            add hl,de
            ex de,hl                ; DE = target z
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            or a
            sbc hl,de
            jr c,.zin
            ; still coming in from the horizon: approach at 30/field
            ld a,h
            or a
            jr nz,.far
            ld a,l
            cp 90
            jr c,.zin
.far:       ld a,-30
            call mul_dt
            call z_add
            jr .rec
.zin:       ld (ix+O_Z),e
            ld (ix+O_Z+1),d
.rec:       ; record the path
            ld a,(bhist_p)
            inc a
            and 31
            ld (bhist_p),a
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,bhist
            add hl,de
            ld a,(ix+O_X)
            ld (hl),a
            inc hl
            ld a,(ix+O_X+1)
            ld (hl),a
            inc hl
            ld a,(ix+O_Y)
            ld (hl),a
            inc hl
            ld a,(ix+O_Z+1)
            ld e,(ix+O_Z)
            srl a
            rr e
            srl a
            rr e
            srl a
            rr e
            ld (hl),e
            ; jaw and fire
            ld a,(dt)
            ld c,a
            ld a,(ix+O_VX)
            sub c
            jr nc,.cd
            xor a
.cd:        ld (ix+O_VX),a
            cp 16
            ld a,0
            jr nc,.jaw
            inc a                   ; jaw open for the last 16 fields
.jaw:       ld c,a
            ld a,(ix+O_TIMER)       ; just hit: white-hot flash frame
            or a
            ld a,c
            jr z,.jw
            ld a,2
.jw:        ld (ix+O_FRAME),a
            ld a,(ix+O_VX)
            or a
            ret nz
            ld a,(diff)
            ld e,a
            ld d,0
            ld hl,boss_rate
            add hl,de
            ld a,(hl)
            ld (ix+O_VX),a
            ; fan of three: centre, and +-70 units sideways
            call spawn_fireball
            ld l,(ix+O_X)
            ld h,(ix+O_X+1)
            push hl
            ld de,70
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            call spawn_fireball
            pop hl
            push hl
            ld de,-70
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            call spawn_fireball
            pop hl
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ret
.dying:     ; flashing, then big explosion
            ld a,(dt)
            ld c,a
            ld a,(ix+O_TIMER)
            sub c
            jr nc,.dd
            xor a
.dd:        ld (ix+O_TIMER),a
            rrca
            and 1
            ld (ix+O_FRAME),a
            ld a,(ix+O_TIMER)
            or a
            ret nz
            ld a,SFX_BIG
            call sfx
            ld a,250
            call add_score10
            ld a,250
            call add_score10
            xor a
            ld (boss_on),a
            ld a,1
            ld (stage_done),a
            jp explode_ix
boss_rate:  db 110,80,60

boss_hit:
            ld a,(ix+O_STATE)
            or a
            ret nz
            ld (ix+O_TIMER),7       ; flash
            ld a,1
            ld (hud_dirty),a        ; boss meter
            ; knocked back a little
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld de,36
            add hl,de
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ; sparks where the bolt struck
            push ix
            pop iy
            push iy
            call obj_alloc
            jr c,.nsp
            ld (ix+O_KIND),K_BOOM
            ld (ix+O_SPR),T_SPARK
            ld (ix+O_FLAGS),0
            ld (ix+O_TIMER),0
            ld a,(iy+O_X)
            ld (ix+O_X),a
            ld a,(iy+O_X+1)
            ld (ix+O_X+1),a
            ld a,(iy+O_Y)
            add a,SP_HR
            ld (ix+O_Y),a
            ld l,(iy+O_Z)
            ld h,(iy+O_Z+1)
            ld de,-20
            add hl,de
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
.nsp:       pop ix
            ld a,(boss_hp)
            dec a
            ld (boss_hp),a
            jr z,.kill
            ld a,SFX_THUD
            jp sfx
.kill:      ld (ix+O_STATE),1
            ld (ix+O_TIMER),60
            ld (ix+O_FLAGS),F_SHADOW
            ; segments blow up one after another
            push ix
            ld ix,objs
            ld b,NOBJ
.s:         ld a,(ix+O_KIND)
            cp K_BSEG
            jr nz,.sn
            ld (ix+O_STATE),1
            ld a,(ix+O_PARAM)
            add a,a
            add a,a
            add a,a
            add a,6
            ld (ix+O_TIMER),a
            ld (ix+O_FLAGS),F_SHADOW
.sn:        ld de,OSIZE
            add ix,de
            djnz .s
            pop ix
            ld hl,0
            call music
            ld a,SFX_BOOM
            jp sfx

; a body segment: follow the head's path, (PARAM+1)*3 records behind
upd_bseg:
            ld a,(ix+O_STATE)
            or a
            jr z,.alive
            ld a,(dt)
            ld c,a
            ld a,(ix+O_TIMER)
            sub c
            jr nc,.d
            xor a
.d:         ld (ix+O_TIMER),a
            or a
            ret nz
            ld a,40
            call add_score10
            jp explode_ix
.alive:     ld a,(ix+O_PARAM)
            inc a
            ld c,a
            add a,a
            add a,c                 ; *3
            ld c,a
            ld a,(bhist_p)
            sub c
            and 31
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,bhist
            add hl,de
            ld a,(hl)
            ld (ix+O_X),a
            inc hl
            ld a,(hl)
            ld (ix+O_X+1),a
            inc hl
            ld a,(hl)
            sub 6
            jr nc,.y
            xor a
.y:         ld (ix+O_Y),a
            inc hl
            ld l,(hl)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ; a little further back than the head, so the body trails away
            ld a,(ix+O_PARAM)
            inc a
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ld (ix+O_FRAME),0
            ret
