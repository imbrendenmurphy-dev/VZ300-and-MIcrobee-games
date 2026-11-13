; =====================================================================
;  MAX Q - race rules, rivals, attract sequence, sound
;  (game variables live in GVARS at $7D80, rivals at RV)
; =====================================================================
GS_ATTRACT EQU 0
GS_COUNT   EQU 1
GS_RACE    EQU 2
GS_FINISH  EQU 3
NLAPS      EQU 3
VNORM      EQU 110
VBOOST     EQU 150
VSTALL     EQU 40

SFX_BEEP   EQU 1
SFX_GO     EQU 2
SFX_BOOST  EQU 3
SFX_BUMP   EQU 4
SFX_LAP    EQU 5
SFX_STALL  EQU 6
SFX_WIN    EQU 7

; rival record (32 bytes)
R_I    EQU 0    ; section (2)
R_F    EQU 2    ; fraction
R_LAP  EQU 3
R_LAT  EQU 4    ; lateral (signed, +-60)
R_SPD  EQU 5
R_BASE EQU 6    ; cruising speed
R_OFF  EQU 7    ; preferred lane offset
R_VIS  EQU 8
R_SX   EQU 9
R_SY   EQU 10
R_W    EQU 11
R_YCL  EQU 12   ; rows at or below this (biased) are hidden by nearer track
R_D    EQU 13   ; sections ahead of the camera (255 = not in view)
R_FR   EQU 14
R_TGT  EQU 15
R_PT   EQU 16   ; camera-space point x, y, z (6)
R_VIEW EQU 22   ; 0..4 hard left .. hard right

; ---------------------------------------------------------------------
; RACE_RESET: grid positions, clock, shield
; ---------------------------------------------------------------------
race_reset:
        ld hl,0
        ld (CAM_I),hl
        ld (CAM_LAT),hl
        ld (RTIME),hl
        ld (LAPT0),hl
        dec hl
        ld (BESTLAP),hl
        xor a
        ld (CAM_F),a
        ld (LATV),a
        ld (SPEED),a
        ld (LAPN),a
        ld (BOOSTT),a
        ld (STALLT),a
        ld (BUMPT),a
        ld (BANT),a
        ld (STEER),a
        ld (WEAPON),a
        ld (AIRT),a
        ld (PHITT),a
        ld (OBJCOL),a
        ld (OBJCOL+1),a
        ld (REC_SHOT+R_ACT),a
        ld (REC_MINE+R_ACT),a
        ld (RV+R_HIT),a
        ld (RV+32+R_HIT),a
        ld (RV+64+R_HIT),a
        ld (RV+R_AIR),a
        ld (RV+32+R_AIR),a
        ld (RV+64+R_AIR),a
        ld hl,700
        ld (VOLTCD),hl
        ld hl,900
        ld (RAZECD),hl
        ld a,64
        ld (SHIELD),a
        ld hl,rv_grid
        ld de,RV
        ld b,3
.r:     push bc
        push de
        ld bc,8
        ldir
        pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret
rv_grid: ; I lo, I hi, F, lap, lat, speed, base, lane
        DB 4,0,0,0,-28,0,103,-28      ; VOLT
        DB 4,0,0,0,28,0,106,26        ; NOVA
        DB 2,0,96,0,26,0,101,-4       ; RAZE

; ---------------------------------------------------------------------
; STATE_FRAME: once per frame - attract cycle, start, finish
; ---------------------------------------------------------------------
state_frame:
        call read_start         ; A != 0 on a fresh SPACE / fire press
        ld c,a
        ld a,(GSTATE)
        cp GS_ATTRACT
        jr nz,.na
        ld a,c
        or a
        jp nz,cup_start
        ld hl,(ATIMER)          ; demo for ~450 frames, then the cards
        inc hl
        ld (ATIMER),hl
        ld de,450
        or a
        sbc hl,de
        ret c
        call attract_cards
        jp demo_reset
.na:    cp GS_FINISH
        ret nz
        ld hl,(STIMER)
        ld a,h
        or l
        ret nz
        jp cup_next             ; results, standings, next round

start_race:
        call race_reset
        ld a,GS_COUNT
        ld (GSTATE),a
        ld hl,160
        ld (STIMER),hl
        ld a,RACE_AUTOPILOT     ; 0 in the real game (1 only for automated testing)
        ld (AUTO),a
        ld hl,s_ready
        ld a,160
        call banner
        ld a,SFX_BEEP
        jp sfx

demo_reset:
        call race_reset
        ld a,GS_ATTRACT
        ld (GSTATE),a
        ld a,1
        ld (AUTO),a
        ld hl,0
        ld (ATIMER),hl
        ret

attract_cards:
        ld hl,lower_keys
        call title_card
        ld hl,lower_best
        call title_card
        ei
        ret

; fresh press of SPACE or joystick fire (or joystick up)
read_start:
        ld a,(KEYROW)
        cpl
        and $10
        ld c,a
        in a,($2E)
        cpl
        and $10
        or c
        ld hl,SPREV
        ld c,(hl)
        ld (hl),a
        or a
        ret z
        ld a,c
        or a
        ld a,0
        ret nz                  ; still held from before
        inc a
        ret

; ---------------------------------------------------------------------
; FIELD_TICK: everything that runs once per 50 Hz field
; ---------------------------------------------------------------------
field_tick:
        ld a,(BANT)             ; banner timer
        or a
        jr z,.b0
        dec a
        ld (BANT),a
.b0:    ld a,(GSTATE)
        cp GS_COUNT
        jr nz,.go
        ld hl,(STIMER)          ; countdown: the field is held on the grid
        dec hl
        ld (STIMER),hl
        ld a,h
        or a
        jr nz,.cd
        ld a,l
        or a
        jr z,.start
        cp 120
        jr z,.n3
        cp 80
        jr z,.n2
        cp 40
        jr z,.n1
.cd:    ret
.n3:    ld hl,s_3
        jr .nb
.n2:    ld hl,s_2
        jr .nb
.n1:    ld hl,s_1
.nb:    ld a,40
        call banner
        ld a,SFX_BEEP
        jp sfx
.start: ld a,GS_RACE
        ld (GSTATE),a
        ld hl,s_go
        ld a,40
        call banner
        ld a,SFX_GO
        jp sfx
.go:    cp GS_FINISH
        jr nz,.nf
        ld hl,(STIMER)
        ld a,h
        or l
        jr z,.nf
        dec hl
        ld (STIMER),hl
.nf:    call physics
        call rv_tick
        call weapon_tick
        ld hl,AIRT              ; airborne
        ld a,(hl)
        or a
        jr z,.na
        dec (hl)
        jr nz,.na
        ld a,SFX_BUMP           ; landing thump
        call sfx
.na:
        ld a,(GSTATE)           ; race clock
        cp GS_RACE
        jr nz,.nt
        ld hl,(RTIME)
        inc hl
        ld (RTIME),hl
.nt:    ld hl,BOOSTT
        ld a,(hl)
        or a
        jr z,.t1
        dec (hl)
.t1:    ld hl,BUMPT
        ld a,(hl)
        or a
        jr z,.t2
        dec (hl)
.t2:    ld hl,STALLT
        ld a,(hl)
        or a
        jr z,.t3
        dec (hl)
        jr nz,.t3
        ld a,32                 ; back on line with a third of the shield
        ld (SHIELD),a
.t3:    ld a,(FIELDS)           ; shield recharges slowly
        and 31
        ret nz
        ld a,(STALLT)
        or a
        ret nz
        ld hl,SHIELD
        ld a,(hl)
        cp 64
        ret nc
        inc (hl)
        ret

; A = shield damage (never fatal: an empty shield stalls the craft for a while)
hurt:   ld b,a
        ld a,(STALLT)
        or a
        ret nz
        ld a,(SHIELD)
        sub b
        jr c,.out
        jr z,.out
        ld (SHIELD),a
        ret
.out:   xor a
        ld (SHIELD),a
        ld a,120
        ld (STALLT),a
        ld hl,s_stall
        ld a,100
        call banner
        ld a,SFX_STALL
        jp sfx

; current speed limit
vcap:   ld a,(STALLT)
        or a
        ld a,VSTALL
        ret nz
        ld a,(BOOSTT)
        or a
        ld a,VBOOST
        ret nz
        ld a,VNORM
        ret

; called by physics when the camera enters a new section (HL = CAM_I)
new_section:
        ld a,h
        or l
        call z,lap_done
        call obj_section
        ld a,(CAM_I)            ; boost pad under the craft (one section ahead)?
        inc a
        and 126
        cp 40
        ret nz
        ld a,(BOOSTT)
        cp 60
        jr nc,.nb
        ld a,SFX_BOOST
        call sfx
.nb:    ld a,70
        ld (BOOSTT),a
        ret

lap_done:
        ld a,(GSTATE)
        cp GS_RACE
        jr z,.r
        ld hl,LAPN              ; demo / lap of honour: just count
        inc (hl)
        ret
.r:     ld hl,(RTIME)           ; lap time
        ld de,(LAPT0)
        ld (LAPT0),hl
        or a
        sbc hl,de
        ex de,hl
        ld hl,(BESTLAP)
        or a
        sbc hl,de
        jr c,.nbl
        ld (BESTLAP),de
.nbl:   xor a                   ; pickups come back each lap
        ld (OBJCOL),a
        ld (OBJCOL+1),a
        ld hl,LAPN
        inc (hl)
        ld a,(hl)
        cp NLAPS
        jr z,.fin
        cp NLAPS-1
        ld hl,s_lap2
        jr nz,.l2
        ld hl,s_final
.l2:    ld a,90
        call banner
        ld a,SFX_LAP
        jp sfx
.fin:   ld a,GS_FINISH
        ld (GSTATE),a
        ld hl,250
        ld (STIMER),hl
        ld a,1
        ld (AUTO),a
        call cup_score
        ld hl,s_finished
        ld a,250
        call banner
        call add_best
        ld a,SFX_WIN
        jp sfx

; insert RTIME into the best-times table (4 entries, ascending)
add_best:
        xor a
        ld (NEWBEST),a
        ld de,(RTIME)
        ld hl,TOPT
        ld b,0
.f:     ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        or a
        sbc hl,de               ; entry - new
        pop hl
        jr nc,.ins
        inc hl
        inc b
        ld a,b
        cp 4
        jr nz,.f
        ret
.ins:   ld a,b
        push af
        or a
        jr nz,.nb
        ld a,1                  ; fastest ever
        ld (NEWBEST),a
.nb:    pop af
        push af
        ld c,a
        ld a,3
        sub c
        jr z,.put
        add a,a
        ld c,a
        ld b,0
        push de
        ld hl,TOPT+5
        ld de,TOPT+7
        lddr
        pop de
.put:   pop af
        add a,a
        ld l,a
        ld h,0
        ld bc,TOPT
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; ---------------------------------------------------------------------
; banner text in the sky: HL = string, A = fields to show
; ---------------------------------------------------------------------
banner: ld (BANT),a
        ld (BANP),hl
        ret

draw_banner:
        ld a,(BANT)
        or a
        ret z
        ld a,(DMIN)
        cp 20
        jr c,.dm
        ld a,20
        ld (DMIN),a
.dm:
        ld hl,(BANP)
        ld b,0                  ; centre it: column = (32 - len) / 2
.l:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc b
        jr .l
.e:     ld a,32
        sub b
        srl a
        ld e,a
        ld d,0
        ld hl,BUFFER+20*32
        add hl,de
        ex de,hl
        ld hl,(BANP)
        ld a,(HUDFG)
        push af
        ld a,$55
        ld (HUDFG),a
        call text_t
        pop af
        ld (HUDFG),a
        ret

; ---------------------------------------------------------------------
; RIVALS
; ---------------------------------------------------------------------
; HL = rival - camera in whole sections (signed), C = fraction; IX = rival
rv_dist:
        ld a,(LAPN)
        add a,a
        ld d,a
        ld a,(CAM_I+1)
        add a,d
        ld d,a
        ld a,(ix+R_LAP)
        add a,a
        add a,(ix+R_I+1)
        ld e,a
        ld a,(CAM_F)
        ld c,a
        ld a,(ix+R_F)
        sub c
        ld c,a
        ld a,(CAM_I)
        ld b,a
        ld a,(ix+R_I)
        sbc a,b
        ld l,a
        ld a,e
        sbc a,d
        ld h,a
        ret

rv_tick:
        ld ix,RV
        ld b,3
.r:     push bc
        call rv_one
        ld de,32
        add ix,de
        pop bc
        djnz .r
        ret

rv_one: call rv_dist            ; rubber band: ease off far ahead, push on far behind
        ld (RVDH),hl
        ld a,c
        ld (RVDC),a
        ld e,(ix+R_BASE)
        bit 7,h
        jr nz,.bh
        ld a,h
        or a
        jr nz,.far
        ld a,l
        cp 11
        jr c,.tgt
.far:   ld a,e
        sub 16
        ld e,a
        jr .tgt
.bh:    ld a,h
        inc a
        jr nz,.wb
        ld a,l
        cp -6
        jr nc,.tgt
.wb:    ld a,e
        add a,14
        ld e,a
.tgt:   ld a,(ix+R_SPD)
        cp e
        jr z,.sp
        jr c,.up
        dec a
        jr .sp
.up:    inc a
.sp:    ld (ix+R_SPD),a
        add a,(ix+R_F)          ; move along the track
        ld (ix+R_F),a
        jr nc,.lat
        inc (ix+R_I)
        ld a,(ix+R_I)           ; boost pads work for rivals too
        and 126
        cp 40
        jr nz,.nbp
        ld a,(ix+R_SPD)
        cp 136
        jr nc,.nbp
        ld (ix+R_SPD),136
.nbp:   ld a,(ix+R_I)
        or a
        jr nz,.newsec
        ld a,(ix+R_I+1)
        xor 1
        ld (ix+R_I+1),a
        jr nz,.newsec
        inc (ix+R_LAP)
        jr .newsec
.lat:   ld b,(ix+R_TGT)         ; ease toward the racing line
        jr .mv
.newsec:        ld l,(ix+R_I)           ; racing line: inside of the bend ahead, plus own lane
        ld h,(ix+R_I+1)
        push hl
        ld de,4
        add hl,de
        ld a,h
        and 1
        ld h,a
        ld de,TRK_H
        add hl,de
        ld b,(hl)
        pop hl
        ld de,TRK_H
        add hl,de
        ld a,b
        sub (hl)
        ld b,a
        add a,a
        add a,b
        add a,(ix+R_OFF)
        cp 50                   ; clamp +-50
        jr c,.c1
        cp -50
        jr nc,.c1
        bit 7,a
        ld a,50
        jr z,.c1
        ld a,-50
.c1:    ld (ix+R_TGT),a
        ld b,a
.mv:    ld a,(ix+R_LAT)
        cp b
        jr z,.col
        sub b
        jp m,.inc
        dec (ix+R_LAT)
        jr .col
.inc:   inc (ix+R_LAT)
        ; ---- collision with the player craft (one section ahead of the camera)
.col:   call rv_extra
        ld a,(BUMPT)
        or a
        ret nz
        ld hl,(RVDH)
        ld a,(RVDC)
        ld c,a
        ld a,h
        or a
        ret nz
        ld a,l
        cp 2
        ret nc
        ld e,l                  ; E = 1: rival ahead of the craft
        ld h,l
        ld l,c
        ld bc,128
        or a
        sbc hl,bc
        ret c
        ld bc,256
        sbc hl,bc
        ret nc                  ; more than half a section apart
        ld a,(CAM_LAT)
        ld b,a
        ld a,(ix+R_LAT)
        sub b
        ld c,a
        jp p,.ab
        neg
.ab:    cp 26
        ret nc
        ld a,20                 ; bump!
        ld (BUMPT),a
        ld a,c                  ; push apart sideways
        or a
        ld a,-7
        jp p,.pl
        ld a,7
.pl:    ld (LATV),a
        neg
        add a,a
        add a,(ix+R_LAT)
        ld (ix+R_LAT),a
        dec e
        jr nz,.hb
        ld a,(SPEED)            ; we ran into it: lose a quarter of our speed
        ld b,a
        srl a
        srl a
        neg
        add a,b
        ld (SPEED),a
        ld a,(ix+R_SPD)
        add a,10
        ld (ix+R_SPD),a
        jr .hd
.hb:    ld a,(ix+R_SPD)         ; it ran into us: it loses speed, we get a shove
        ld b,a
        srl a
        srl a
        neg
        add a,b
        ld (ix+R_SPD),a
        ld a,(SPEED)
        add a,6
        ld (SPEED),a
.hd:    ld a,SFX_BUMP
        call sfx
        ld a,4
        jp hurt

; per frame, before rendering: which rivals are in view, race position
rv_prep:
        xor a
        ld (RVANY),a
        ld a,1
        ld (POS),a
        ld ix,RV
        ld b,3
.r:     push bc
        ld (ix+R_VIS),0
        ld (ix+R_D),255
        call rv_dist            ; HL sections ahead of the camera, C fraction
        bit 7,h
        jr nz,.nx
        ld a,h                  ; ahead of our craft (one section in front of the camera)?
        or a
        jr nz,.ah
        ld a,l
        cp 2
        jr nc,.ah
        cp 1
        jr nz,.nv
        ld a,c
        or a
        jr z,.nv
.ah:    ld a,(POS)
        inc a
        ld (POS),a
.nv:    ld a,h
        or a
        jr nz,.nx
        ld a,l
        or a
        jr z,.nx
        cp DEPTH-3
        jr nc,.nx
        ld (ix+R_D),a
        ld (ix+R_FR),c
        ld a,1
        ld (RVANY),a
.nx:    ld de,32
        add ix,de
        pop bc
        djnz .r
        ret

; transform hook: at each section step, place rivals that sit in it
rv_hook:
        push ix
        ld a,(DEPTHV)
        ld c,a
        ld ix,RV
        ld b,NREC
.h:     ld a,(ix+R_D)
        cp c
        jr nz,.n
        push bc
        call rv_point
        pop bc
.n:     ld de,32
        add ix,de
        djnz .h
        pop ix
        ret

; camera-space point of rival IX: section start (VX,VY,VZ) + fraction along + lateral across
rv_point:
        ld a,(DANG)             ; x += (sin*fr) >> 8 + (lat*cos) >> 6
        ld l,a
        ld h,SIN64/256
        ld b,(hl)
        ld a,(ix+R_FR)
        srl a
        ld c,a
        call mul8
        add hl,hl
        ld a,h
        call sext
        ld de,(VX)
        add hl,de
        push hl
        ld a,(DANG)
        ld l,a
        ld h,COS64/256
        ld b,(hl)
        ld c,(ix+R_LAT)
        call mul8
        add hl,hl
        add hl,hl
        ld a,h
        call sext
        pop de
        add hl,de
        ld (ix+R_PT),l
        ld (ix+R_PT+1),h
        ld a,(DANG)             ; z += (cos*fr) >> 8 - (lat*sin) >> 6
        ld l,a
        ld h,COS64/256
        ld b,(hl)
        ld a,(ix+R_FR)
        srl a
        ld c,a
        call mul8
        add hl,hl
        ld a,h
        call sext
        ld de,(VZ)
        add hl,de
        push hl
        ld a,(DANG)
        ld l,a
        ld h,SIN64/256
        ld b,(hl)
        ld c,(ix+R_LAT)
        call mul8
        add hl,hl
        add hl,hl
        ld a,h
        call sext
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (ix+R_PT+4),l
        ld (ix+R_PT+5),h
        ld hl,(TIDX)            ; y += (dy*fr) >> 8 + (lat*hby) >> 6
        ld de,TRK_DY
        add hl,de
        ld b,(hl)
        ld a,(ix+R_FR)
        srl a
        ld c,a
        call mul8
        add hl,hl
        ld a,h
        call sext
        ld de,(VY)
        add hl,de
        push hl
        ld hl,(TIDX)
        ld de,TRK_HBY
        add hl,de
        ld b,(hl)
        ld c,(ix+R_LAT)
        call mul8
        add hl,hl
        add hl,hl
        ld a,h
        call sext
        pop de
        add hl,de
        ld (ix+R_PT+2),l
        ld (ix+R_PT+3),h
        ld a,(DANG)             ; view: how far its section is turned from ours
        sra a
        sra a
        sra a
        bit 7,a
        jr nz,.vn
        cp 3
        jr c,.vk
        ld a,2
        jr .vk
.vn:    cp -2
        jr nc,.vk
        ld a,-2
.vk:    add a,2
        ld (ix+R_VIEW),a
        ld (ix+R_VIS),1
        ret

; after rendering: screen position, size and occlusion of each visible rival
rv_project:
        ld ix,RV
        ld b,NREC
.r:     push bc
        ld a,(ix+R_VIS)
        or a
        jr z,.nx
        ld (ix+R_VIS),0
        ld a,(ix+R_PT+5)        ; in front of the near plane?
        or a
        jr nz,.zf
        ld a,(ix+R_PT+4)
        cp NEARZ
        jr c,.nx
.zf:    push ix
        pop iy
        ld de,R_PT
        add iy,de
        call proj
        ld a,(PSX)
        ld (ix+R_SX),a
        ld a,(PSY)
        ld (ix+R_SY),a
        ld hl,(PKX)
        ld de,LOG_RIVW
        add hl,de
        call expt_or
        ld (ix+R_W),a
        ; nearer track: YTOP before the strip that holds the rival
        ld a,200
        ld (ix+R_YCL),a
        ld a,(CAM_I)
        ld c,a
        ld iy,SECS
        ld a,(NSEC)
        dec a
        jr z,.vis
        ld b,a
.s:     ld a,(iy+0)
        sub c
        cp (ix+R_D)
        jr z,.s1
        jr nc,.vis
.s1:    ld a,(iy+20)
        ld (ix+R_YCL),a
        ld de,32
        add iy,de
        djnz .s
.vis:   ld (ix+R_VIS),1
.nx:    ld de,32
        add ix,de
        pop bc
        djnz .r
        ret

; far ones first
; MARK[d] = 1 for every depth that holds a rival or an object this frame
mark_build:
        ld hl,MARK
        ld b,32
.c:     ld (hl),0
        inc l
        djnz .c
        ld ix,RV
        ld b,NREC
        ld de,32
.r:     ld a,(ix+R_D)
        cp 32
        jr nc,.n
        ld l,a
        ld (hl),1
.n:     add ix,de
        djnz .r
        ret

draw_rivals:
        ld c,DEPTH-3
.d:     ld l,c                  ; nothing at this depth: skip
        ld h,MARK/256
        ld a,(hl)
        or a
        jr z,.e
        ld ix,RV
        ld b,NREC
.r:     ld a,(ix+R_VIS)
        or a
        jr z,.n
        ld a,(ix+R_D)
        cp c
        jr nz,.n
        push bc
        ld a,b                  ; records 3.. are track objects
        cp NREC-2
        jr nc,.rv
        call draw_object
        jr .dn
.rv:    call draw_rival
.dn:    pop bc
.n:     ld de,32
        add ix,de
        djnz .r
.e:     dec c
        jr nz,.d
        ret

draw_rival:
        ld a,(ix+R_HIT)         ; spinning out: flicker
        and 4
        ret nz
        ld a,(ix+R_AIR)         ; in the air over a ramp: lift (sprite drawn higher)
        or a
        jr z,.ng
        cp 15
        jr c,.a1
        neg
        add a,30
.a1:    srl a
        neg
        add a,(ix+R_SY)
        ld (ix+R_SY),a
.ng:    ld a,(ix+R_SX)          ; keep well inside the biased range
        cp 24
        ret c
        cp 232
        ret nc
        ld a,(ix+R_SY)
        cp 72
        ret c
        ld a,(ix+R_W)
        ld iy,rv_pnear
        cp 20
        jp nc,rv_spr
        ld iy,rv_pmid
        cp 10
        jp nc,rv_spr
        call rv_team            ; far: a little wedge in team colours
        ld de,$FF55             ; red team: red body, yellow glow
        jr nz,.tm
        ld de,$AAFF             ; blue team: blue body, red glow
.tm:    ld a,(ix+R_W)
        cp 4
        jr nc,.sil
        ld a,e                  ; very far: just the glow
        call set_rcol
        ld a,(ix+R_SX)
        dec a
        ld (RX0),a
        inc a
        ld (RX1),a
        ld a,(ix+R_SY)
        dec a
        ld (RY0),a
        ld (RY1),a
        jp rv_rect
.sil:   push de
        ld a,d
        call set_rcol
        ld a,(ix+R_W)           ; body: w wide, w/4 tall, above the glow row
        srl a
        ld d,a
        srl a
        ld e,a
        ld a,(ix+R_SX)
        sub d
        ld (RX0),a
        ld a,(ix+R_SX)
        add a,d
        dec a
        ld (RX1),a
        ld a,(ix+R_SY)
        dec a
        ld (RY1),a
        sub e
        ld (RY0),a
        push de
        call rv_rect
        pop de
        ld a,(ix+R_SY)          ; deck: half width, one row above
        sub e
        dec a
        ld (RY0),a
        ld (RY1),a
        ld a,e
        srl a
        ld b,a
        ld a,(ix+R_SX)
        sub b
        ld (RX0),a
        ld a,(ix+R_SX)
        add a,b
        ld (RX1),a
        push de
        call rv_rect
        pop de
        pop bc                  ; glow row across the back
        push de
        ld a,c
        call set_rcol
        pop de
        ld a,(ix+R_SX)
        sub d
        inc a
        ld (RX0),a
        ld a,(ix+R_SX)
        add a,d
        sub 2
        ld (RX1),a
        ld a,(ix+R_SY)
        dec a
        ld (RY0),a
        ld (RY1),a
        ; fall through
rv_rect:                        ; clip to the rows not hidden by nearer track
        ld a,(ix+R_YCL)
        dec a
        ld b,a
        ld a,(RY1)
        cp b
        jr c,.ok
        ld a,b
        ld (RY1),a
.ok:    ld a,(RY0)
        ld b,a
        ld a,(RY1)
        cp b
        ret c
        jp rect

; Z set for the blue team (rival 1), clear for red
rv_team:
        ld a,ixl
        sub (RV+32) & 255
        ret

; sprite rival.  IY -> half width, rows, bytes, view size (2), shift size, red base (2), blue base (2), x limit
rv_pnear: DB 12, 8, 7
          DW 224
          DB 112
          DW SPR_N_RED0, SPR_N_BLUE0
          DB 100
rv_pmid:  DB 8, 6, 5
          DW 120
          DB 60
          DW SPR_M_RED0, SPR_M_BLUE0
          DB 108

rv_spr: ld a,(ix+R_SX)          ; left edge, on an even pixel
        sub 64
        sub (iy+0)
        ret c
        and $FE
        cp (iy+10)
        ret nc
        ld c,a
        call rv_team
        ld l,(iy+6)
        ld h,(iy+7)
        jr nz,.rd
        ld l,(iy+8)
        ld h,(iy+9)
.rd:    ld b,(ix+R_VIEW)        ; + view * view size
        ld e,(iy+3)
        ld d,(iy+4)
        inc b
        jr .v2
.v1:    add hl,de
.v2:    djnz .v1
        ld a,c                  ; + shift block for a 2-pixel offset
        and 2
        jr z,.s0
        ld e,(iy+5)
        ld d,0
        add hl,de
.s0:    ex de,hl                ; DE = source
        ld a,(ix+R_SY)          ; rows: top .. min(63, ycl-65)
        sub 64
        sub (iy+1)
        ret c
        ld b,a
        ld hl,DMIN
        cp (hl)
        jr nc,.dm
        ld (hl),a
.dm:    ld a,(ix+R_YCL)
        sub 65
        jr nc,.y1
        xor a
.y1:    cp 64
        jr c,.y2
        ld a,63
.y2:    sub b
        ret c
        inc a
        cp (iy+1)
        jr c,.y3
        ld a,(iy+1)
.y3:    push af
        ld l,b                  ; HL = BUFFER + top*32 + left/4
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        rrca
        rrca
        and $3F
        ld c,a
        ld b,0
        add hl,bc
        ld bc,BUFFER
        add hl,bc
        pop af
        ld b,a
        ld c,(iy+2)
        jp blit

; ---------------------------------------------------------------------
; EXPAND_SPRITES: map SRAM bank B at $4000 and build every pre-shifted copy
; (groups: source, destination, frames, rows, bytes per row, copies, step)
; ---------------------------------------------------------------------
expand_sprites:
        ld a,3
        out ($37),a
        ld ix,SPRDESC           ; per frame: source, destination, rows, bytes, copies | step<<4 | mirror<<7
.f:     ld a,(ix+4)
        or a
        ret z
        ld e,(ix+5)             ; bytes per copy = rows * bytes * 2
        ld d,0
        ld hl,0
.m:     add hl,de
        dec a
        jr nz,.m
        add hl,hl
        ld (EXS),hl
        ld l,(ix+0)
        ld h,(ix+1)
        ld e,(ix+2)
        ld d,(ix+3)
        ld (EXDST),de
        bit 7,(ix+6)
        jr nz,.mir
        ld bc,(EXS)
        ldir
        jr .cp
.mir:   call mirror_copy
.cp:    ld a,(ix+6)
        and 15
.s:     dec a
        jr z,.fd
        push af
        ld hl,(EXDST)           ; copy the last one, then shift it along
        ld bc,(EXS)
        push de
        ldir
        ld (EXFREE),de
        pop hl
        ld (EXDST),hl
        call shift_block
        ld de,(EXFREE)
        pop af
        jr .s
.fd:    ld de,7
        add ix,de
        jr .f

shift_block:                    ; HL = copy; shift each row right by the step
        ld a,(ix+4)
.r:     push af
        ld a,(ix+6)
        rrca
        rrca
        rrca
        rrca
        and 7
        ld b,a
.p:     push bc
        ld c,2
.bt:    push hl
        ld b,(ix+5)
        scf                     ; mask: transparent comes in
.mk:    rr (hl)
        inc hl
        inc hl
        djnz .mk
        pop hl
        push hl
        inc hl
        ld b,(ix+5)
        or a                    ; data: nothing comes in
.dt:    rr (hl)
        inc hl
        inc hl
        djnz .dt
        pop hl
        dec c
        jr nz,.bt
        pop bc
        djnz .p
        ld e,(ix+5)
        ld d,0
        add hl,de
        add hl,de
        pop af
        dec a
        jr nz,.r
        ret

mirror_copy:                    ; HL = source frame, DE = destination (left-right mirror image)
        ld b,(ix+4)
.r:     push bc
        ld a,(ix+5)
        dec a
        ld c,a                  ; pixel bytes in a row (the last byte is the spare)
        add a,a
        add a,l
        ld l,a
        jr nc,.n1
        inc h
.n1:    ld b,c
.p:     dec hl
        dec hl
        ld a,(hl)
        call rev2
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        call rev2
        ld (de),a
        inc de
        dec hl
        djnz .p
        ld a,$FF                ; spare byte stays transparent
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld a,(ix+5)
        add a,a
        add a,l
        ld l,a
        jr nc,.n2
        inc h
.n2:    pop bc
        djnz .r
        ret

rev2:   push bc                 ; reverse the four 2-bit pixels in A
        ld c,a
        ld b,8
.l:     srl c
        rla
        djnz .l
        ld c,a
        and $AA
        rrca
        ld b,a
        ld a,c
        and $55
        rlca
        or b
        pop bc
        ret

; ---------------------------------------------------------------------
; HUD text helpers
; ---------------------------------------------------------------------
; HL = time in fields -> "m:ss.t" at DE (DE advanced)
fmt_time:
        ld a,h
        cp $FF
        jr nz,.ok
        ld hl,s_notime
.cp:    ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr .cp
.ok:    push de
        ld c,50
        call div8               ; HL = seconds, A = fields left over
        ld b,0
.t:     sub 5
        jr c,.td
        inc b
        jr .t
.td:    ld a,b
        ld (TMPT),a             ; tenths
        ld c,60
        call div8               ; HL = minutes, A = seconds
        ld c,a
        pop de
        ld a,l
        cp 10
        jr c,.m
        ld a,9
.m:     add a,'0'
        ld (de),a
        inc de
        ld a,':'
        ld (de),a
        inc de
        ld a,c
        ld b,'0'-1
.s10:   inc b
        sub 10
        jr nc,.s10
        add a,10+'0'
        ld c,a
        ld a,b
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        ld a,'.'
        ld (de),a
        inc de
        ld a,(TMPT)
        add a,'0'
        ld (de),a
        inc de
        ret

; HL / C -> HL quotient, A remainder
div8:   xor a
        ld b,16
.l:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .l
        ret

; ---------------------------------------------------------------------
; title-card lower halves (drawn in colour set 0, below the split)
; ---------------------------------------------------------------------
lower_keys:
        ld hl,s_keys1
        ld de,BUFFER+32*40+2
        call text
        ld hl,s_keys2
        ld de,BUFFER+32*48+2
        call text
        ld hl,s_press
        ld de,BUFFER+32*57+7
        jp text

lower_best:
        ld hl,s_best
        ld de,BUFFER+32*35+11
        call text
        ld ix,TOPT
        ld hl,BUFFER+32*41+10
        ld (TPOS),hl
        ld c,'1'
.l:     ld hl,TBUF
        ld (hl),c
        inc hl
        ld (hl),' '
        inc hl
        ld (hl),' '
        inc hl
        ex de,hl
        ld l,(ix+0)
        ld h,(ix+1)
        push bc
        call fmt_time
        xor a
        ld (de),a
        ld hl,TBUF
        ld de,(TPOS)
        call text
        ld hl,(TPOS)
        ld de,6*32
        add hl,de
        ld (TPOS),hl
        inc ix
        inc ix
        pop bc
        inc c
        ld a,c
        cp '5'
        jr nz,.l
        ret

result_card:
        ld hl,lower_result
        call title_card
        ei
        ret

lower_result:
        ld hl,s_complete
        ld de,BUFFER+32*37+9
        call text
        ld hl,s_posn            ; "POSITION 2ND"
        ld de,TBUF
        ld bc,9
        ldir
        ld a,(FINPOS)
        add a,'0'
        ld (de),a
        inc de
        ld a,(FINPOS)
        dec a
        add a,a
        ld c,a
        ld b,0
        ld hl,s_ord
        add hl,bc
        ldi
        ldi
        xor a
        ld (de),a
        ld hl,TBUF
        ld de,BUFFER+32*44+10
        call text
        ld hl,s_time            ; "TIME 1:23.4"
        ld de,TBUF
        ld bc,5
        ldir
        ld hl,(RTIME)
        call fmt_time
        xor a
        ld (de),a
        ld hl,TBUF
        ld de,BUFFER+32*50+10
        call text
        ld a,(NEWBEST)
        or a
        ret z
        ld hl,s_record
        ld de,BUFFER+32*57+8
        jp text

; ---------------------------------------------------------------------
; SOUND: a short burst on the beeper at the end of each field interrupt
; ---------------------------------------------------------------------
sfx:    ld (SFXK),a             ; A = effect
        ld e,a
        ld d,0
        ld hl,sfx_len-1
        add hl,de
        ld a,(hl)
        ld (SFXT),a
        ret
sfx_len: DB 8, 16, 26, 8, 18, 40, 44

sfx_isr:
        ld a,(SFXT)
        or a
        ret z
        dec a
        ld (SFXT),a
        ld b,a                  ; B = time left
        ld a,(SFXK)
        dec a
        jr z,.beep
        dec a
        jr z,.go
        dec a
        jr z,.boost
        dec a
        jr z,.bump
        dec a
        jr z,.lap
        dec a
        jr z,.stall
        ld a,b                  ; win: four rising notes
        rrca
        rrca
        rrca
        and 7
        ld e,a
        ld d,0
        ld hl,.win
        add hl,de
        ld c,(hl)
        jr .play
.win:   DB 6, 7, 9, 12, 9, 7, 6, 6
.beep:  ld c,14
        jr .play
.go:    ld c,7
        jr .play
.boost: ld a,b                  ; rising, warbling
        add a,6
        bit 0,b
        jr z,.b1
        add a,3
.b1:    ld c,a
        jr .play
.bump:  ld a,r                  ; crunch
        and 31
        add a,8
        ld c,a
        jr .play
.lap:   ld c,10
        bit 2,b
        jr z,.play
        ld c,7
        jr .play
.stall: ld a,40                 ; falling
        sub b
        ld c,a
.play:  ld d,64                 ; ~1,000 T of square wave per field, half-period C*16 T
.cy:    ld a,(LATBASE)
        inc a
        ld (LATCH),a
        ld e,c
.d1:    dec e
        jr nz,.d1
        ld a,d
        sub c
        ld d,a
        jr c,.end
        ld a,(LATBASE)
        add a,$20
        ld (LATCH),a
        ld e,c
.d2:    dec e
        jr nz,.d2
        ld a,d
        sub c
        ld d,a
        jr nc,.cy
.end:   ld a,(LATBASE)
        ld (LATCH),a
        ret

; ---------------------------------------------------------------------
; strings
; ---------------------------------------------------------------------
s_ready:    DB "GET READY",0
s_3:        DB "3",0
s_2:        DB "2",0
s_1:        DB "1",0
s_go:       DB "GO!",0
s_lap2:     DB "LAP 2",0
s_final:    DB "FINAL LAP",0
s_finished: DB "FINISHED!",0
s_stall:    DB "SHIELD DOWN",0
s_notime:   DB "-:--.-",0
s_best:     DB "BEST TIMES",0
s_press:    DB "PRESS SPACE OR FIRE",0
s_complete: DB "RACE COMPLETE",0
s_posn:     DB "POSITION "
s_ord:      DB "STNDRDTH"
s_time:     DB "TIME "
s_record:   DB "NEW RECORD TIME!",0
s_demo:     DB "DEMO - PRESS SPACE",0
