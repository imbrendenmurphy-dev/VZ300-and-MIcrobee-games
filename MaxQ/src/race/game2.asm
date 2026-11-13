; =====================================================================
;  MAX Q - cup, rival characters, pickups, weapons, jumps
;  (assembled at $D200; variables in CVARS at $7FE0)
; =====================================================================
NREC     EQU 9          ; records: 0-2 rivals, 3-6 track objects in view, 7 missile, 8 mine
R_TYPE   EQU 7          ; objects: type (rivals use this byte as their lane offset)
R_ACT    EQU 6          ; missile / mine: active
R_HIT    EQU 23         ; rivals: spin-out timer after a hit
R_AIR    EQU 24         ; rivals: airborne timer
OB_BOOST EQU 0
OB_NRG   EQU 1
OB_MSL   EQU 2
OB_MINE  EQU 3
OB_ARROW EQU 4
OB_SHOT  EQU 5
OB_MINED EQU 6          ; a mine lying on the track
REC_OBJ  EQU RV+3*32
REC_SHOT EQU RV+7*32
REC_MINE EQU RV+8*32
NOBJ     EQU 20

; ---------------------------------------------------------------------
; CUP
; ---------------------------------------------------------------------
cup_start:
        xor a
        ld (CUPN),a
        ld hl,PTS
        ld b,4
.z:     ld (hl),a
        inc hl
        djnz .z
race_setup:
        ld a,(CUPN)             ; races 2 and 4 are at dusk (colour set 1)
        and 1
        ld a,$08
        jr z,.d
        ld a,$18
.d:     ld (LATBASE),a
        call race_reset
        ld a,(CUPN)             ; the field gets a little quicker each round
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld ix,RV
        ld a,(ix+R_BASE)
        add a,b
        ld (ix+R_BASE),a
        ld a,(ix+32+R_BASE)
        add a,b
        ld (ix+32+R_BASE),a
        ld a,(ix+64+R_BASE)
        add a,b
        ld (ix+64+R_BASE),a
        ld hl,lower_intro
        call title_card
        ei
        ld a,GS_COUNT
        ld (GSTATE),a
        ld hl,160
        ld (STIMER),hl
        ld a,RACE_AUTOPILOT
        ld (AUTO),a
        ld hl,s_ready
        ld a,160
        call banner
        ld a,SFX_BEEP
        jp sfx

; end of a race: results, standings, next round or the champion
cup_next:
        call result_card
        ld hl,lower_stand
        call title_card
        ei
        ld hl,CUPN
        inc (hl)
        ld a,(hl)
        cp 4
        jp c,race_setup
        ld hl,lower_champ
        call title_card
        ld a,$08
        ld (LATBASE),a
        call attract_cards
        jp demo_reset

; finishing order when we cross the line (score = lead over the camera in sections)
cup_score:
        ld ix,RV
        ld iy,SCORES
        ld (iy+0),1             ; us: one section in front of the camera
        ld (iy+1),0
        ld b,3
.s:     push bc
        call rv_dist
        ld (iy+2),l
        ld (iy+3),h
        inc iy
        inc iy
        ld de,32
        add ix,de
        pop bc
        djnz .s
        ld c,0
.d:     ld a,c                  ; rank of driver C = 1 + drivers ahead of it
        call .get
        ld (TSC),hl
        ld e,1
        ld b,0
.o:     ld a,b
        cp c
        jr z,.n
        call .get
        push de
        ld de,(TSC)
        or a
        sbc hl,de
        pop de
        jr z,.tie
        jp m,.n
        inc e
        jr .n
.tie:   ld a,b
        cp c
        jr nc,.n
        inc e
.n:     inc b
        ld a,b
        cp 4
        jr nz,.o
        ld a,c
        or a
        jr nz,.nf
        ld a,e
        ld (FINPOS),a
.nf:    ld a,e                  ; points 10 / 6 / 3 / 1
        dec a
        ld hl,pts_tab
        add a,l
        ld l,a
        jr nc,.p1
        inc h
.p1:    ld a,(hl)
        ld hl,PTS
        ld b,0
        add hl,bc
        add a,(hl)
        ld (hl),a
        inc c
        ld a,c
        cp 4
        jr nz,.d
        ret
.get:   push de                 ; A = driver -> HL = its score
        ld l,a
        ld h,0
        add hl,hl
        ld de,SCORES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ret
pts_tab: DB 10, 6, 3, 1

; ---------------------------------------------------------------------
; TRACK OBJECTS: pickups and boost arrows, placed from OBJTAB each frame
; ---------------------------------------------------------------------
obj_prep:
        ld ix,REC_OBJ
        ld b,4
.c:     ld (ix+R_D),255
        ld (ix+R_VIS),0
        ld de,32
        add ix,de
        djnz .c
        ld ix,REC_OBJ
        ld iy,OBJTAB
        ld c,0                  ; object number (for the collected bits)
.o:     push bc
        call obj_taken
        jr nz,.nx
        ld l,(iy+0)             ; sections ahead of the camera (object sits mid-section)
        ld h,(iy+1)
        call sec_ahead
        jr c,.nx
        ld (ix+R_D),a
        ld (ix+R_FR),c
        ld a,(iy+2)
        ld (ix+R_LAT),a
        ld a,(iy+3)
        ld (ix+R_TYPE),a
        ld a,1
        ld (RVANY),a
        ld de,32
        add ix,de
        push ix                 ; four slots at most
        pop hl
        ld de,REC_OBJ+4*32
        or a
        sbc hl,de
        jr nz,.nx
        pop bc
        ret
.nx:    ld de,4
        add iy,de
        pop bc
        inc c
        ld a,c
        cp NOBJ
        jr nz,.o
        ret

; HL = section, frac 128 -> A = sections ahead of the camera, C = fraction; carry if not in view
sec_ahead:
        ld a,(CAM_F)
        ld c,a
        ld a,128
        sub c
        ld c,a
        ld de,(CAM_I)
        sbc hl,de               ; (borrow from the fraction)
        ld a,h
        and 1
        ld h,a
        or a
        scf
        ret nz
        ld a,l
        or a
        scf
        ret z
        cp DEPTH-3
        ccf
        ret

; Z set if object C has not been collected this lap
obj_taken:
        ld a,(iy+3)
        cp OB_ARROW
        jr nz,.t
        xor a                   ; arrows never go away
        ret
.t:     ld a,c
        ld hl,OBJCOL
        cp 8
        jr c,.lo
        inc hl
        sub 8
.lo:    ld b,a
        ld a,1
        inc b
        jr .s2
.s1:    add a,a
.s2:    djnz .s1
        and (hl)
        ret

; missile and mine records: in view?
dyn_prep:
        ld ix,REC_SHOT
        call .one
        ld ix,REC_MINE
.one:   ld (ix+R_D),255
        ld (ix+R_VIS),0
        ld a,(ix+R_ACT)
        or a
        ret z
        ld a,(CAM_F)
        ld c,a
        ld a,(ix+R_F)
        sub c
        ld c,a
        ld l,(ix+R_I)
        ld h,(ix+R_I+1)
        ld de,(CAM_I)
        sbc hl,de
        ld a,h
        and 1
        ret nz
        ld a,l
        or a
        ret z
        cp DEPTH-3
        ret nc
        ld (ix+R_D),a
        ld (ix+R_FR),c
        ld a,1
        ld (RVANY),a
        ret

; the craft enters a new section (CAM_I + 1 under the craft): pickups, mines, ramps
obj_section:
        ld hl,(CAM_I)
        inc hl
        ld a,h
        and 1
        ld h,a
        ld (OBJK),hl
        ld iy,OBJTAB
        ld c,0
.o:     push bc
        ld a,(iy+0)
        ld hl,OBJK
        cp (hl)
        jr nz,.nx
        ld a,(iy+1)
        inc hl
        cp (hl)
        jr nz,.nx
        call obj_taken
        jr nz,.nx
        ld a,(iy+3)
        cp OB_ARROW
        jr z,.nx
        ld a,(iy+2)             ; close enough sideways?
        call lat_near
        jr nc,.nx
        pop bc                  ; collect: set its bit
        push bc
        ld a,c
        ld hl,OBJCOL
        cp 8
        jr c,.lo
        inc hl
        sub 8
.lo:    ld b,a
        ld a,1
        inc b
        jr .s2
.s1:    add a,a
.s2:    djnz .s1
        or (hl)
        ld (hl),a
        ld a,(iy+3)
        call collect
.nx:    ld de,4
        add iy,de
        pop bc
        inc c
        ld a,c
        cp NOBJ
        jr nz,.o
        ; a mine on this section?
        ld ix,REC_MINE
        ld a,(ix+R_ACT)
        or a
        jr z,.ramp
        ld a,(MINEOWN)
        or a
        jr z,.ramp
        ld a,(OBJK)
        cp (ix+R_I)
        jr nz,.ramp
        ld a,(ix+R_LAT)
        call lat_near
        jr nc,.ramp
        ld (ix+R_ACT),0
        ld hl,s_minehit
        call player_hit
.ramp:  ld a,(OBJK)             ; jump ramp: sections (k & 255) == 228, 229
        cp 228
        ret nz
        ld a,(AIRT)
        or a
        ret nz
        ld a,(SPEED)
        cp 70
        ret c
        srl a
        srl a
        add a,8
        ld (AIRT),a
        ld (AIRTOT),a
        ld hl,s_jump
        ld a,40
        call banner
        ld a,SFX_GO
        jp sfx

; carry set if lateral A is within 22 of the craft
lat_near:
        ld b,a
        ld a,(CAM_LAT)
        sub b
        jp p,.p
        neg
.p:     cp 22
        ret

collect:
        or a
        jr nz,.n1
        ld a,SFX_BOOST          ; boost pod
        call sfx
        ld a,80
        ld (BOOSTT),a
        ld hl,s_boost
        jr .bn
.n1:    dec a
        jr nz,.n2
        ld a,(SHIELD)           ; energy: +32
        add a,32
        cp 65
        jr c,.e
        ld a,64
.e:     ld (SHIELD),a
        xor a
        ld (STALLT),a
        ld a,SFX_LAP
        call sfx
        ld hl,s_energy
        jr .bn
.n2:    dec a
        ld a,1                  ; missile or mine into the weapon slot
        jr z,.w
        inc a
.w:     ld (WEAPON),a
        ld a,SFX_BEEP
        call sfx
        ld hl,s_gotmsl
        ld a,(WEAPON)
        dec a
        jr z,.bn
        ld hl,s_gotmine
.bn:    ld a,50
        jp banner

; we are hit by a missile or a mine: HL = banner text
player_hit:
        ld a,60
        call banner
        ld a,(SPEED)
        srl a
        ld (SPEED),a
        ld a,20
        ld (BUMPT),a
        ld a,SFX_STALL
        call sfx
        ld a,8
        jp hurt

; ---------------------------------------------------------------------
; WEAPONS (per field)
; ---------------------------------------------------------------------
fire:   ld a,(WEAPON)           ; M or joystick fire
        or a
        ret z
        ld b,a
        xor a
        ld (WEAPON),a
        djnz .mine
        ld ix,REC_SHOT          ; missile: from the craft, homing on the nearest rival ahead
        ld hl,(CAM_I)
        inc hl
        ld a,h
        and 1
        ld h,a
        ld (ix+R_I),l
        ld (ix+R_I+1),h
        ld a,(CAM_F)
        ld (ix+R_F),a
        ld a,(CAM_LAT)
        ld (ix+R_LAT),a
        ld (ix+R_TYPE),OB_SHOT
        ld (ix+R_ACT),70        ; flight time
        call nearest_ahead
        ld (SHOTT),a
        ld a,SFX_GO
        call sfx
        ld hl,s_fire
        ld a,30
        jp banner
.mine:  ld ix,REC_MINE          ; mine: dropped behind the craft
        ld hl,(CAM_I)
        ld (ix+R_I),l
        ld (ix+R_I+1),h
        ld (ix+R_F),128
        ld a,(CAM_LAT)
        ld (ix+R_LAT),a
        ld (ix+R_TYPE),OB_MINED
        ld (ix+R_ACT),1
        xor a
        ld (MINEOWN),a
        ld a,SFX_BUMP
        call sfx
        ld hl,s_dropped
        ld a,30
        jp banner

; A = index of the nearest rival 1..16 sections ahead of the craft, 255 if none
nearest_ahead:
        ld ix,RV
        ld c,255
        ld e,17
        ld b,0
.r:     push bc
        push de
        call rv_dist
        pop de
        pop bc
        ld a,h
        or a
        jr nz,.n
        ld a,l
        cp 2
        jr c,.n
        cp e
        jr nc,.n
        ld e,a
        ld c,b
.n:     push de
        ld de,32
        add ix,de
        pop de
        inc b
        ld a,b
        cp 3
        jr nz,.r
        ld a,c
        ret

weapon_tick:
        ld ix,REC_SHOT
        ld a,(ix+R_ACT)
        or a
        jr z,.ai
        dec (ix+R_ACT)
        jr z,.ai
        ld a,(SPEED)            ; fly: our speed plus a lot
        add a,120
        ld b,a
        ld a,(ix+R_F)
        add a,b
        ld (ix+R_F),a
        jr nc,.tg
        inc (ix+R_I)
        jr nz,.tg
        ld a,(ix+R_I+1)
        xor 1
        ld (ix+R_I+1),a
.tg:    ld a,(SHOTT)            ; caught the target?
        cp 3
        jr nc,.ai
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,RV
        add hl,de
        push hl
        pop iy
        ld a,(iy+R_LAT)         ; home in sideways
        cp (ix+R_LAT)
        jr z,.lt
        jp m,.ld
        inc (ix+R_LAT)
        inc (ix+R_LAT)
        jr .lt
.ld:    dec (ix+R_LAT)
        dec (ix+R_LAT)
.lt:    ld a,(iy+R_F)           ; rival - missile (sections), negative = reached
        sub (ix+R_F)
        ld a,(iy+R_I)
        sbc a,(ix+R_I)
        ld l,a
        ld a,(iy+R_I+1)
        sbc a,(ix+R_I+1)
        and 1
        jr z,.ai
        ld a,l
        cp 200
        jr c,.ai
        ld (ix+R_ACT),0         ; hit!
        push iy
        pop ix
        call rival_hit
        ld hl,s_hitrival
        ld a,50
        call banner
        ; ---- rival characters' own tricks
.ai:    ld a,(GSTATE)
        cp GS_RACE
        ret nz
        ld hl,PHITT             ; VOLT's missile on its way to us
        ld a,(hl)
        or a
        jr z,.v0
        dec (hl)
        jr nz,.v0
        ld a,(AIRT)             ; jumping dodges it
        or a
        jr nz,.v0
        ld hl,s_voltgot
        call player_hit
.v0:    ld hl,(VOLTCD)
        ld a,h
        or l
        jr z,.v1
        dec hl
        ld (VOLTCD),hl
        jr .rz
.v1:    ld ix,RV                ; VOLT fires when 1..8 sections behind us
        call rv_dist
        ld a,h
        inc a
        jr nz,.rz
        ld a,l
        cp -7
        jr c,.rz
        ld hl,1000
        ld (VOLTCD),hl
        ld a,30
        ld (PHITT),a
        ld hl,s_voltfire
        ld a,40
        call banner
        ld a,SFX_GO
        call sfx
.rz:    ld hl,(RAZECD)
        ld a,h
        or l
        jr z,.r1
        dec hl
        ld (RAZECD),hl
        ret
.r1:    ld a,(REC_MINE+R_ACT)   ; RAZE drops a mine when 3..10 sections ahead of us
        or a
        ret nz
        ld ix,RV+64
        call rv_dist
        ld a,h
        or a
        ret nz
        ld a,l
        cp 3
        ret c
        cp 11
        ret nc
        ld hl,1300
        ld (RAZECD),hl
        ld iy,REC_MINE
        ld a,(ix+R_I)
        ld (iy+R_I),a
        ld a,(ix+R_I+1)
        ld (iy+R_I+1),a
        ld (iy+R_F),128
        ld a,(ix+R_LAT)
        ld (iy+R_LAT),a
        ld (iy+R_TYPE),OB_MINED
        ld (iy+R_ACT),1
        ld a,1
        ld (MINEOWN),a
        ld hl,s_razemine
        ld a,50
        jp banner

; IX = rival: spin out
rival_hit:
        ld (ix+R_HIT),60
        ld a,(ix+R_SPD)
        srl a
        ld (ix+R_SPD),a
        ld a,SFX_BUMP
        jp sfx

; per rival per field (IX = rival): spin, jumps, our mines
rv_extra:
        ld a,(ix+R_HIT)
        or a
        jr z,.j
        dec (ix+R_HIT)
        ld a,(FIELDS)           ; wobble while spinning
        and 4
        ld a,3
        jr z,.w
        ld a,-3
.w:     add a,(ix+R_LAT)
        ld (ix+R_LAT),a
.j:     ld a,(ix+R_AIR)
        or a
        jr z,.m
        dec (ix+R_AIR)
.m:     ld a,(ix+R_NEWS)        ; only when entering a section
        or a
        ret z
        ld (ix+R_NEWS),0
        ld a,(ix+R_I)
        cp 228                  ; ramp
        jr nz,.mn
        ld (ix+R_AIR),30
.mn:    ld iy,REC_MINE          ; one of our mines here?
        ld a,(iy+R_ACT)
        or a
        ret z
        ld a,(MINEOWN)
        or a
        ret nz
        ld a,(ix+R_I)
        cp (iy+R_I)
        ret nz
        ld a,(ix+R_LAT)
        sub (iy+R_LAT)
        jp p,.p
        neg
.p:     cp 22
        ret nc
        ld (iy+R_ACT),0
        call rival_hit
        ld hl,s_minerival
        ld a,50
        jp banner

; ---------------------------------------------------------------------
; drawing track objects (IX = record): pods float, arrows lie flat
; ---------------------------------------------------------------------
draw_object:
        ld a,(ix+R_SX)
        cp 24
        ret c
        cp 232
        ret nc
        ld a,(ix+R_SY)
        cp 72
        ret c
        ld a,(ix+R_W)           ; half pod = 3w/8, at least 1
        srl a
        srl a
        ld d,a
        srl a
        add a,d
        ld d,a
        or a
        jr nz,.s
        inc d
.s:     ld a,(ix+R_TYPE)
        cp OB_ARROW
        jp z,.arrow
        ld hl,obj_cols          ; outer, inner colour bytes by type
        add a,a
        ld e,a
        ld a,l
        add a,e
        ld l,a
        jr nc,.c
        inc h
.c:     ld a,(hl)
        inc hl
        ld e,(hl)
        push de
        call set_rcol
        pop de
        ld a,(ix+R_SY)          ; floats: bottom a pod-height above the track
        sub d
        dec a
        ld (RY1),a
        sub d
        sub d
        inc a
        ld (RY0),a
        ld a,(ix+R_SX)
        sub d
        ld (RX0),a
        ld a,(ix+R_SX)
        add a,d
        dec a
        ld (RX1),a
        push de
        call rv_rect
        pop de
        ld a,d                  ; inner light (pods 4 px and up)
        cp 2
        ret c
        ld a,e
        call set_rcol
        ld a,(RX0)
        add a,64
        ld b,d
        srl b
        add a,b
        ld (RX0),a
        ld a,(RX1)
        add a,64
        sub b
        ld (RX1),a
        ld a,(RY0)
        add a,64
        add a,b
        ld (RY0),a
        ld a,(RY1)
        add a,64
        sub b
        ld (RY1),a
        jp rv_rect
.arrow: ld a,$55                ; yellow chevron on the boost pad: two bars stepping out
        call set_rcol
        ld a,(ix+R_SY)
        dec a
        ld (RY0),a
        ld (RY1),a
        ld a,(ix+R_SX)
        sub d
        sub d
        ld (RX0),a
        ld a,(ix+R_SX)
        add a,d
        add a,d
        ld (RX1),a
        push de
        call rv_rect
        pop de
        ld a,(ix+R_SY)
        sub d
        dec a
        ld (RY0),a
        ld (RY1),a
        ld a,(ix+R_SX)
        sub d
        ld (RX0),a
        ld a,(ix+R_SX)
        add a,d
        ld (RX1),a
        jp rv_rect
obj_cols:       ; outer, inner
        DB $55, $FF     ; boost: yellow / red
        DB $AA, $55     ; energy: blue / yellow
        DB $FF, $55     ; missile: red / yellow
        DB $FF, $AA     ; mine pickup: red / blue
        DB $55, $55     ; arrow
        DB $FF, $55     ; missile in flight
        DB $AA, $FF     ; mine on the track: blue / red

; ---------------------------------------------------------------------
; cards (lower halves under the title logo)
; ---------------------------------------------------------------------
lower_intro:
        ld hl,s_cup
        ld de,BUFFER+32*35+11
        call hdr
        ld hl,s_racen
        ld de,TBUF
        ld bc,5
        ldir
        ld a,(CUPN)
        add a,'1'
        ld (de),a
        inc de
        ld hl,s_of4
        ld bc,6
        ldir
        ld hl,TBUF
        ld de,BUFFER+32*43+10
        call text
        ld hl,s_day
        ld a,(CUPN)
        and 1
        jr z,.d
        ld hl,s_dusk
.d:     ld de,BUFFER+32*50+10
        call text
        ld hl,s_rivals
        ld de,BUFFER+32*57+6
        jp text

lower_stand:
        ld hl,s_stand
        ld de,BUFFER+32*35+11
        call hdr
        call sort_pts
        ld ix,ORDERP
        ld hl,BUFFER+32*41+9
        ld (TPOS),hl
        ld c,'1'
.l:     ld hl,TBUF
        ld (hl),c
        inc hl
        ld (hl),' '
        inc hl
        ex de,hl
        ld a,(ix+0)             ; name
        call name_hl
        ld bc,4
        ldir
        ex de,hl
        ld (hl),' '
        inc hl
        ld (hl),' '
        inc hl
        ex de,hl
        ld a,(ix+0)             ; points
        ld hl,PTS
        add a,l
        ld l,a
        jr nc,.p
        inc h
.p:     ld a,(hl)
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld c,a
        ld a,b
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
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
        ld a,(TBUF)
        inc a
        ld c,a
        cp '5'
        jr nz,.l
        ret

lower_champ:
        ld hl,s_champ
        ld de,BUFFER+32*36+12
        call hdr
        call sort_pts
        ld a,(ORDERP)
        push af
        call name_hl
        ld de,TBUF
        ld bc,4
        ldir
        xor a
        ld (de),a
        ld hl,TBUF
        ld de,BUFFER+32*45+14
        call text
        pop af
        or a
        ret nz
        ld hl,s_welldone
        ld de,BUFFER+32*54+7
        jp text

; card heading: red letters with a green underline (the lower half is colour set 0,
; so with yellow text on blue all four of its colours are on screen with the four above)
hdr:    push de
        push hl
        ld a,(HUDFG)
        push af
        ld a,$FF
        ld (HUDFG),a
        call text_t
        pop af
        ld (HUDFG),a
        pop hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc b
        jr .l
.e:     pop hl
        ld de,5*32
        add hl,de
.g:     ld (hl),$00
        inc hl
        djnz .g
        ret

name_hl:                        ; A = driver -> HL = 4-letter name (DE kept)
        push de
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,s_names
        add hl,de
        pop de
        ret

; ORDERP = drivers sorted by points (highest first)
sort_pts:
        ld hl,ORDERP
        ld (hl),0
        inc hl
        ld (hl),1
        inc hl
        ld (hl),2
        inc hl
        ld (hl),3
        ld c,3
.p:     ld hl,ORDERP
        ld b,3
.i:     push bc
        ld a,(hl)
        inc hl
        ld e,(hl)
        push hl
        ld hl,PTS
        ld c,a
        ld b,0
        add hl,bc
        ld d,(hl)               ; D = pts[a]
        ld hl,PTS
        ld c,e
        add hl,bc
        ld a,(hl)               ; pts[e]
        pop hl
        cp d
        jr c,.k
        jr z,.k
        dec hl                  ; swap
        ld a,(hl)
        ld (hl),e
        inc hl
        ld (hl),a
.k:     pop bc
        djnz .i
        dec c
        jr nz,.p
        ret

; ---------------------------------------------------------------------
s_names:    DB "YOU VOLTNOVARAZE"
s_cup:      DB "MAX Q CUP",0
s_racen:    DB "RACE "
s_of4:      DB " OF 4",0
s_day:      DB "DAY RACE",0
s_dusk:     DB "DUSK RACE",0
s_rivals:   DB "VS VOLT NOVA RAZE",0
s_stand:    DB "STANDINGS",0
s_champ:    DB "CHAMPION",0
s_welldone: DB "WELL DONE, PILOT!",0
s_boost:    DB "BOOST!",0
s_energy:   DB "ENERGY",0
s_gotmsl:   DB "MISSILE - PRESS M",0
s_gotmine:  DB "MINE - PRESS M",0
s_fire:     DB "MISSILE AWAY",0
s_dropped:  DB "MINE DROPPED",0
s_hitrival: DB "DIRECT HIT!",0
s_minerival: DB "RIVAL HIT A MINE",0
s_minehit:  DB "MINE!",0
s_voltfire: DB "VOLT FIRES!",0
s_voltgot:  DB "HIT BY VOLT",0
s_razemine: DB "RAZE DROPS A MINE",0
s_jump:     DB "JUMP!",0
s_msl:      DB "MISSILE",0
s_mine:     DB "MINE",0
