; ===================================================================
;  rivals.asm - rival civilisations
;
;  Up to three rival peoples, each with a town hall (2x2) and buildings
;  that grow on the map in its own colour (and with a banner, so they can
;  be told apart in monochrome).  Rival buildings are map objects
;  20h + rival*8 + type (0-3 town hall, 4 hut, 5 house, 6 farm, 7 tower).
;  They are met when their town hall is explored; diplomacy (gifts, trade,
;  alliance) is done on the envoys screen (overlay.asm).  Warlike peoples
;  may raid; watchtowers turn raiders back.
; ===================================================================
MAXRIV  equ 3
RREC    equ 16
R_ACT   equ 0
R_X     equ 1
R_Y     equ 2
R_RAD   equ 3
R_POP   equ 4                   ; word
R_NB    equ 6
R_ATT   equ 7                   ; attitude, signed -100..100
R_STAT  equ 8
R_PERS  equ 9
R_NAME  equ 10
R_COL   equ 11
R_TIMER equ 12
O_RIVAL equ 20h
ST_UNMET equ 0
ST_PEACE equ 1
ST_TRADE equ 2
ST_ALLY  equ 3
ST_WAR   equ 4
P_TRADER equ 0
P_BUILDER equ 1
P_SCHOLAR equ 2
P_WARLIKE equ 3
P_ISOLATE equ 4

riv_colour: db BMAGENTA,BCYAN,BRED
pers_att:   db 20,0,10,-30,-10
rbld_g:     db G_RTC_TL_L,G_RTC_TR_L,G_RTC_BL_L,G_RTC_BR_L,G_RHUT_L,G_RHOUSE_L,G_RFARM_L,G_RTOWER_L

; IX = record of rival A
riv_ix: push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,rivals
        add hl,de
        push hl
        pop ix
        pop de
        ret

; ---- placement at world creation ----
place_rivals:
        ld hl,rivals
        ld de,rivals+1
        ld bc,MAXRIV*RREC-1
        ld (hl),0
        ldir
        ld a,(opt_rivals)
        cp 0FFh
        jr nz,.n
        ld a,(worldsize)        ; default: 2 rivals, 3 on a large world
        add a,2
.n:     ld (nrivals),a
        or a
        ret z
        xor a
        ld (pr_r),a
.next:  ld a,(pr_r)
        call riv_ix
        ld a,250
        ld (pr_try),a
.try:   ld a,(pr_try)
        dec a
        ld (pr_try),a
        jp z,.skip
        ld a,(mapwm1)
        sub 12
        ld b,a
        call rand_n
        add a,5
        ld c,a
        ld a,(maphm1)
        sub 12
        ld b,a
        call rand_n
        add a,5
        ld b,a
        ; far from the player's town
        ld hl,(startxy)         ; L = x, H = y
        ld a,(worldsize)
        or a
        ld e,26
        jr z,.d
        ld e,48
.d:     call far_enough
        jr c,.try
        ; and from the rivals already placed
        push bc
        ld a,(pr_r)
        ld d,a
        ld iy,rivals
.o:     ld a,d
        or a
        jr z,.od
        ld l,(iy+R_X)
        ld h,(iy+R_Y)
        ld e,20
        call far_enough
        jr c,.ob
        push de
        ld de,RREC
        add iy,de
        pop de
        dec d
        jr .o
.ob:    pop bc
        jr .try
.od:    pop bc
        ; 2x2 of grass
        call grasslike
        jr nz,.try
        inc c
        call grasslike
        jr nz,.try
        inc b
        call grasslike
        jr nz,.try
        dec c
        call grasslike
        jr nz,.try
        dec b
        ; found: the town hall
        ld (ix+R_ACT),1
        ld (ix+R_X),c
        ld (ix+R_Y),b
        ld (ix+R_RAD),5
        ld (ix+R_POP),8
        ld (ix+R_NB),0
        ld (ix+R_STAT),ST_UNMET
        ld (ix+R_TIMER),20
        push bc
        ld b,5
        call rand_n
        ld (ix+R_PERS),a
        ld e,a
        ld d,0
        ld hl,pers_att
        add hl,de
        ld a,(hl)
        ld (ix+R_ATT),a
        ld a,(pr_r)
        ld e,a
        ld hl,riv_colour
        add hl,de
        ld a,(hl)
        ld (ix+R_COL),a
        ; a name not taken yet: rival r gets name (seed + 3r) mod 8
        ld a,(pr_r)             ; base name: from the seed for rival 0
        or a
        ld a,(seed)
        jr z,.nm
        ld a,(rivals+R_NAME)
.nm:    and 7
        ld b,a
        ld a,(pr_r)
        ld c,a
        add a,a
        add a,c
        add a,b
        ld c,a
        ld a,(pr_r)             ; rival 0 keeps the base itself
        or a
        ld a,c
        jr nz,.nm2
        ld a,b
.nm2:   and 7
        ld (ix+R_NAME),a
        pop bc
        ld a,(pr_r)
        add a,a
        add a,a
        add a,a
        add a,O_RIVAL
        ld e,a
        call set_obj            ; TL
        inc a
        inc c
        call set_obj            ; TR
        inc a
        dec c
        inc b
        call set_obj            ; BL
        inc a
        inc c
        call set_obj            ; BR
        ; a few huts and a farm to start with
        ld a,(pr_r)
        ld (ri_cur),a
        ld b,4
.h:     push bc
        call riv_build
        pop bc
        djnz .h
.skip:  ld a,(pr_r)
        inc a
        ld (pr_r),a
        ld hl,nrivals
        cp (hl)
        jp nz,.next
        ret

; far_enough: B,C = y,x; H,L = y,x of another place; E = distance
; -> carry if closer than E on both axes (too close)
far_enough:
        ld a,c
        sub l
        call abs_a
        cp e
        jr nc,.ok
        ld a,b
        sub h
        call abs_a
        cp e
        ret                     ; carry if too close
.ok:    or a
        ret

; ---- a rival builds something: rival in (ri_cur), IX = its record ----
riv_build:
        ld a,(ri_cur)
        call riv_ix
        ld a,8
        ld (ri_try),a
.try:   ld a,(ri_try)
        dec a
        ld (ri_try),a
        ret z
        ld a,(ix+R_RAD)
        add a,a
        inc a
        ld b,a
        call rand_n
        sub (ix+R_RAD)
        add a,(ix+R_X)
        ld c,a
        call cpw
        jr nc,.try
        ld a,(ix+R_RAD)
        add a,a
        inc a
        ld b,a
        call rand_n
        sub (ix+R_RAD)
        add a,(ix+R_Y)
        ld b,a
        call cph
        jr nc,.try
        call oget
        or a
        jr nz,.try
        call tget
        cp T_GRASS
        jr z,.land
        cp T_MEADOW
        jr z,.land
        cp T_FIELD
        jr z,.land
        cp T_HILLS
        jr z,.land
        cp T_BEACH
        jr nz,.try
.land:  call in_territory       ; never inside the player's lands
        jr z,.try
        ; what to build: tower every 7th, farm every 3rd, else a hut
        ld a,(ix+R_NB)
        inc a
        ld (ix+R_NB),a
        ld e,4                  ; hut
        ld d,a
.m7:    sub 7
        jr z,.tow
        jr nc,.m7
        ld a,d
.m3:    sub 3
        jr z,.farm
        jr nc,.m3
        jr .put
.tow:   ld e,7
        ld a,(ix+R_RAD)
        add a,2
        ld (ix+R_RAD),a
        jr .put
.farm:  ld e,6
.put:   ld a,(ri_cur)
        add a,a
        add a,a
        add a,a
        add a,O_RIVAL
        add a,e
        call set_obj
        ; the lands widen as the town grows (up to 12, towers add more)
        ld a,(ix+R_NB)
        and 3
        jr nz,.r
        ld a,(ix+R_RAD)
        cp 12
        jr nc,.r
        inc a
        ld (ix+R_RAD),a
.r:     jp refresh_tile

; in_rival_land: B,C -> NZ if within a rival's lands (A = rival)
in_rival_land:
        push ix
        push bc
        ld a,(nrivals)
        or a
        jr z,.no
        ld d,a
        ld e,0
.l:     ld a,e
        call riv_ix
        ld a,(ix+R_ACT)
        or a
        jr z,.n
        ld a,c
        sub (ix+R_X)
        call abs_a
        cp (ix+R_RAD)
        jr z,.cy
        jr nc,.n
.cy:    ld a,b
        sub (ix+R_Y)
        call abs_a
        cp (ix+R_RAD)
        jr z,.yes
        jr c,.yes
.n:     inc e
        dec d
        jr nz,.l
.no:    pop bc
        pop ix
        xor a
        ret
.yes:   ld a,e
        pop bc
        pop ix
        or 80h                  ; NZ, A = 80h + rival
        ret

; ---- every week ----
riv_week:
        ld a,(nrivals)
        or a
        ret z
        xor a
        ld (ri_cur),a
.l:     ld a,(ri_cur)
        call riv_ix
        ld a,(ix+R_ACT)
        or a
        jp z,.n
        ; growth
        ld l,(ix+R_POP)
        ld h,(ix+R_POP+1)
        inc hl
        ld a,(ix+R_PERS)
        cp P_BUILDER
        jr nz,.g1
        inc hl
.g1:    ld a,(ix+R_NB)          ; cap = 5 per building + 10
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,10
        ld e,a
        ld d,0
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.g2
        ex de,hl
.g2:    ld (ix+R_POP),l
        ld (ix+R_POP+1),h
        ; build when the people need room (one try in three weeks)
        call rand
        and 3
        jr nz,.nb
        ld a,(ix+R_NB)
        cp 60
        jr nc,.nb
        add a,a
        add a,a                 ; 4 per building
        ld e,a
        ld d,0
        ld l,(ix+R_POP)
        ld h,(ix+R_POP+1)
        or a
        sbc hl,de
        jr c,.nb
        call riv_build
        ld a,(ri_cur)
        call riv_ix
.nb:    ; met yet?
        ld a,(ix+R_STAT)
        or a
        jr nz,.met
        ld c,(ix+R_X)
        ld b,(ix+R_Y)
        call tile_addr
        bit 7,(hl)
        jp z,.n
        ld (ix+R_STAT),ST_PEACE
        ld hl,msg_meet
        call riv_msg
        ld a,C_GOOD
        call set_msg
        ld hl,fx_good
        call sfx
        ld a,1
        ld (dirty_view),a
        jp .n
.met:   ; diplomacy, once every four weeks
        ld a,(week)
        and 3
        jp nz,.n
        ld a,(ix+R_STAT)
        cp ST_TRADE
        jr c,.nt
        cp ST_WAR
        jr z,.nt
        ld hl,(gold)            ; trade and alliance pay
        ld de,8
        add hl,de
        ld a,(ix+R_PERS)
        cp P_TRADER
        jr nz,.tg
        ld de,4
        add hl,de
.tg:    ld (gold),hl
        ld a,1
        call riv_att
        ld a,(ix+R_STAT)
        cp ST_ALLY
        jr nz,.nt
        ld hl,(rpoints)         ; allies share their learning
        inc hl
        inc hl
        ld (rpoints),hl
.nt:    ; temperament
        ld a,(ix+R_PERS)
        cp P_WARLIKE
        jr nz,.ni
        ld a,(ix+R_STAT)
        cp ST_ALLY
        jr z,.ni
        ld a,-2
        call riv_att
.ni:    ld a,(ix+R_PERS)
        cp P_ISOLATE            ; isolationists drift back to indifference
        jr nz,.wr
        ld a,(ix+R_ATT)
        or a
        jr z,.wr
        ld a,-1
        bit 7,(ix+R_ATT)
        jr z,.id
        ld a,1
.id:    call riv_att
.wr:    ; war and peace
        ld a,(ix+R_STAT)
        cp ST_WAR
        jr z,.atwar
        ld a,(ix+R_ATT)
        cp -40
        jr nc,.n
        bit 7,a
        jr z,.n
        ld (ix+R_STAT),ST_WAR   ; attitude below -40: war
        ld hl,msg_war
        call riv_msg
        ld a,C_WARN
        call set_msg
        ld hl,fx_bad
        call sfx
        jr .n
.atwar: ld a,(ix+R_ATT)         ; peace again when attitude recovers
        bit 7,a
        jr nz,.raid
        ld (ix+R_STAT),ST_PEACE
        ld hl,msg_peace
        call riv_msg
        ld a,C_GOOD
        call set_msg
        jr .n
.raid:  dec (ix+R_TIMER)
        jr nz,.n
        ld a,16
        ld (ix+R_TIMER),a
        call early_years        ; never in the first two years
        jr c,.n
        ld a,(ntower)
        cp 2
        jr c,.hit
        ld hl,msg_repel         ; two watchtowers see them coming
        call riv_msg
        ld a,C_GOOD
        call set_msg
        jr .n
.hit:   ld hl,(gold)            ; lose a quarter of the gold and food
        srl h
        rr l
        srl h
        rr l
        ex de,hl
        ld hl,(gold)
        or a
        sbc hl,de
        ld (gold),hl
        ld hl,(food)
        srl h
        rr l
        srl h
        rr l
        ex de,hl
        ld hl,(food)
        or a
        sbc hl,de
        ld (food),hl
        ld hl,msg_raid
        call riv_msg
        ld a,C_WARN
        call set_msg
        ld hl,fx_raid
        call sfx
.n:     ld a,(ri_cur)
        inc a
        ld (ri_cur),a
        ld hl,nrivals
        cp (hl)
        jp nz,.l
        ret

; riv_att: A = signed change to IX's attitude, kept within -100..100
riv_att:
        add a,(ix+R_ATT)
        jp pe,.ovf
        cp 101
        jr c,.ok
        bit 7,a
        jr nz,.neg
        ld a,100
        jr .ok
.neg:   cp -100
        jr nc,.ok
        ld a,-100
.ok:    ld (ix+R_ATT),a
        ret
.ovf:   bit 7,a                 ; wrapped negative: it was a big rise
        ld a,100
        jr nz,.ok
        ld a,-100
        jr .ok

; riv_msg: HL = prefix text (overlay block), IX = rival -> HL = msgbuf
; "<prefix><THE NAME>."
riv_msg:
        push hl
        ld a,(ix+R_NAME)
        add a,a
        ld l,a
        ld h,0
        ld de,riv_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = name (overlay block)
        pop hl
; join2: HL = first text, DE = second text (both overlay block) -> msgbuf
join2:
        push de
        call far_str
        ld de,msgbuf
.c1:    ld a,(hl)
        ld (de),a
        or a
        jr z,.n
        inc hl
        inc de
        jr .c1
.n:     pop hl
        push de
        call far_str
        pop de
.c2:    ld a,(hl)
        ld (de),a
        or a
        jr z,.e
        inc hl
        inc de
        jr .c2
.e:     ld a,'.'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld hl,msgbuf
        ret

riv_names: dw rn0,rn1,rn2,rn3,rn4,rn5,rn6,rn7

; overview: mark the cells holding met rival towns (bitmap ovriv)
ov_mark_rivals:
        ld hl,ovriv
        ld de,ovriv+1
        ld bc,22*8-1
        ld (hl),0
        ldir
        ld a,(nrivals)
        or a
        ret z
        ld b,a
        ld ix,rivals
.l:     push bc
        ld a,(ix+R_ACT)
        or a
        jr z,.n
        ld a,(ix+R_STAT)
        or a
        jr z,.n
        ld a,(ovcw)
        ld c,a
        ld a,(ix+R_X)
        call div_a_c
        ld e,a
        ld a,(ovch)
        ld c,a
        ld a,(ix+R_Y)
        call div_a_c
        cp 22
        jr nc,.n
        call ov_bitaddr
        ld de,ovriv-ovtown
        add hl,de
        or (hl)
        ld (hl),a
.n:     ld de,RREC
        add ix,de
        pop bc
        djnz .l
        ret
