; ===================================================================
;  worldgen.asm - procedural world generator
;  Heights are built in TERR, moisture in OBJ, then classified.
; ===================================================================
SEA     equ 100

; ---- random ----
rand:   ld hl,(seed)            ; xorshift16 -> A random, HL new seed
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
        ret
; A = random 0..B-1
rand_n: push hl
        push de
        call rand
        ld e,b
        ld h,a
        call mul8               ; HL = A*B
        ld a,h
        pop de
        pop hl
        ret
; HL = H * E (unsigned)
mul8:   ld d,0
        ld l,d
        ld b,8
.l:     add hl,hl
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; ---- address helpers ----
; tile_addr: B = y, C = x -> HL = TERR + y*MAPW + x
tile_addr:
        push de
        ld l,b
        ld h,0
        add hl,hl
        ld de,rowtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld l,c
        ld h,0
        add hl,de
        pop de
        ret

make_rowtab:
        ld hl,TERR
        ld de,MAPW
        ld ix,rowtab
        ld b,MAPH
.l:     ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        add hl,de
        djnz .l
        ret

; ---- progress text ----
gen_status:                     ; HL = message
        push hl
        ld b,12
        ld c,1
        ld a,C_PANEL
        call shadow_clear_rows
        pop hl
        ld b,12
        ld c,24
        ld a,C_PANEL
        call puts_at
        ld b,12
        ld c,1
        jp present_rows

gen_bar:                        ; A = 0..40 progress
        ld (barval),a
        ld b,14
        ld c,20
        call cell_off
        ld a,(barval)
        ld b,a
        or a
        jr z,.e
.l:     push bc
        ld hl,G_FR_BAR
        ld a,COL(BGREEN,BLACK)
        call put_g
        inc de
        pop bc
        djnz .l
.e:     ld b,14
        ld c,1
        jp present_rows

; ---------------------------------------------------------------
; gen_octave: B = shift (3 or 4), C = amplitude, A = 0 store / 1 add
;             dest = TERR (height) or OBJ (moisture) in (gdest)
gen_octave:
        ld (gmode),a
        ld a,b
        ld (gshift),a
        ld a,c
        ld (gamp),a
        ; spacing
        ld a,1
        ld b,a
        ld a,(gshift)
        ld b,a
        ld a,1
.sp:    add a,a
        djnz .sp
        ld (gsp),a              ; 8 or 16
        ; grid width = MAPW/sp + 2
        ld b,a
        ld a,MAPW
        ld c,0
.dv:    inc c
        sub b
        jr nz,.dv
        ld a,c
        ld (gcells),a           ; cells across
        add a,2
        ld (ggw),a
        ; fill grid gw*gw with rand*amp>>8
        ld hl,grid
        ld a,(ggw)
        ld e,a
        ld h,a
        call mul8               ; HL = gw*gw
        ld b,h
        ld c,l
        ld hl,grid
.gf:    push bc
        push hl
        ld a,(gamp)
        ld b,a
        call rand_n
        pop hl
        ld (hl),a
        inc hl
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.gf
        ; rows
        xor a
        ld (gy),a
.row:   ld a,(gy)
        cp MAPH
        jp z,.done
        ; gyi = y>>shift, fy = y & (sp-1)
        ld b,a
        ld a,(gshift)
        ld c,a
        ld a,b
.sh:    srl a
        dec c
        jr nz,.sh
        ld (gyi),a
        ld a,(gsp)
        dec a
        and b
        ld (gfy),a
        ; pointer to grid row gyi
        ld a,(gyi)
        ld h,a
        ld a,(ggw)
        ld e,a
        call mul8
        ld de,grid
        add hl,de               ; HL = &G[gyi][0]
        ld (gptr),hl
        ; column values
        ld a,(ggw)
        ld b,a
        ld ix,colv
.cv:    push bc
        ld hl,(gptr)
        ld a,(hl)               ; a = top
        ld (gta),a
        ld a,(ggw)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)               ; b = bottom
        ld hl,(gptr)
        inc hl
        ld (gptr),hl
        ; diff = b - a  (signed 16) in DE
        ld e,a
        ld d,0
        ld a,(gta)
        ld l,a
        ld h,0
        ex de,hl
        or a
        sbc hl,de               ; HL = b - a
        ; prod = diff * fy
        ld a,(gfy)
        ld b,a
        ex de,hl
        ld hl,0
        or a
        jr z,.pz
.pm:    add hl,de
        djnz .pm
.pz:    ; arithmetic shift right by gshift
        ld a,(gshift)
        ld b,a
.as:    sra h
        rr l
        djnz .as
        ld a,(gta)
        add a,l
        ld (ix+0),a
        inc ix
        pop bc
        djnz .cv
        ; horizontal interpolation into destination row
        ld a,(gy)
        ld b,a
        ld c,0
        call tile_addr
        ld de,(gdest)
        add hl,de
        ld (gout),hl
        ld ix,colv
        ld a,(gcells)
        ld b,a
.hc:    push bc
        ; step = ((b-a)<<8)>>shift = (b-a) << (8-shift)
        ld a,(ix+0)
        ld (gta),a
        ld l,(ix+1)
        ld h,0
        ld e,a
        ld d,0
        or a
        sbc hl,de               ; HL = b-a (signed)
        ld a,(gshift)
        ld b,a
        ld a,8
        sub b
        ld b,a
.st:    add hl,hl
        djnz .st
        ex de,hl                ; DE = step (8.8)
        ld a,(gta)
        ld h,a
        ld l,80h                ; v = a.5
        ld a,(gsp)
        ld b,a
        push ix
        ld ix,(gout)
.px:    ld a,(gmode)
        or a
        ld a,h
        jr z,.store
        add a,(ix+0)
        jr nc,.store
        ld a,255
.store: ld (ix+0),a
        inc ix
        add hl,de
        djnz .px
        ld (gout),ix
        pop ix
        inc ix
        pop bc
        djnz .hc
        ld a,(gy)
        inc a
        ld (gy),a
        jp .row
.done:  ret

; ---------------------------------------------------------------
; world type parameters: amp16, amp8, falloff shift, raise, moisture bias(signed)
wtparams:
        db 176, 72, 5, 46, 0            ; 0 balanced
        db  96,150, 5, 18, 10           ; 1 island
        db 200, 48, 5, 56, 0            ; 2 continental
        db 176, 64, 6, 32, 40           ; 3 frontier
        db 150,100, 5, 72, 0C4h         ; 4 harsh (-60)

wt_get:                         ; A = param index -> A
        push hl
        push de
        ld e,a
        ld a,(worldtype)
        ld l,a
        add a,a
        add a,a
        add a,l                 ; *5
        add a,e
        ld e,a
        ld d,0
        ld hl,wtparams
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

generate_world:
        call make_rowtab
        ld hl,msg_gen1
        call gen_status
        xor a
        call gen_bar
        ; heights
        ld hl,0                 ; offset of height layer from TERR
        ld (gdest),hl
        xor a
        call wt_get
        ld c,a
        ld b,4
        xor a
        call gen_octave
        ld a,6
        call gen_bar
        ld a,1
        call wt_get
        ld c,a
        ld b,3
        ld a,1
        call gen_octave
        ld a,12
        call gen_bar
        ; moisture
        ld hl,MAPSIZE           ; moisture layer (OBJ)
        ld (gdest),hl
        ld b,4
        ld c,200
        xor a
        call gen_octave
        ld b,3
        ld c,56
        ld a,1
        call gen_octave
        ld a,18
        call gen_bar
        ld hl,msg_gen2
        call gen_status
        call shape_pass
        ld a,24
        call gen_bar
        ld hl,msg_gen3
        call gen_status
        call carve_rivers
        ld a,30
        call gen_bar
        ld hl,msg_gen4
        call gen_status
        call classify
        call place_ruins
        ld a,36
        call gen_bar
        ; clear object layer
        ld hl,OBJ
        ld de,OBJ+1
        ld (hl),0
        ld bc,MAPSIZE-1
        ldir
        call find_start
        ld a,40
        jp gen_bar

; falloff + raise + moisture bias
shape_pass:
        ld a,2
        call wt_get
        ld (gfall),a
        ld a,3
        call wt_get
        ld (graise),a
        ld a,4
        call wt_get
        ld (gmbias),a
        ld b,0                  ; y
.y:     ld c,0
.x:     push bc
        call tile_addr          ; HL -> height
        push hl
        ; d2 = dx^2 + dy^2
        ld a,c
        sub MAPW/2
        jr nc,.ax
        neg
.ax:    call sq16               ; HL = a^2
        push hl
        ld a,b
        sub MAPH/2
        jr nc,.ay
        neg
.ay:    call sq16
        pop de
        add hl,de               ; HL = d2
        ld a,(gfall)
        ld b,a
.f:     srl h
        rr l
        djnz .f
        ld a,h
        or a
        jr z,.ok
        ld l,255
.ok:    ld e,l                  ; E = falloff
        pop hl
        ld a,(hl)
        ld d,a
        ld a,(graise)
        add a,d
        jr nc,.r
        ld a,255
.r:     sub e
        jr nc,.s
        xor a
.s:     ld (hl),a
        ; moisture bias
        ld de,MAPSIZE
        add hl,de
        ld a,(gmbias)
        bit 7,a
        jr nz,.neg
        add a,(hl)
        jr nc,.ms
        ld a,254
        jr .ms
.neg:   add a,(hl)
        jr c,.ms
        xor a
.ms:    cp 255
        jr nz,.m2
        dec a
.m2:    ld (hl),a
        pop bc
        inc c
        ld a,c
        cp MAPW
        jr nz,.x
        inc b
        ld a,b
        cp MAPH
        jr nz,.y
        ret

sq16:                           ; HL = A*A (A<=60)
        push de
        push bc
        ld h,a
        ld e,a
        call mul8
        pop bc
        pop de
        ret

; rivers: walk downhill from high ground, marking moisture = 255
carve_rivers:
        ld a,14
        ld (gcount),a
.next:  ld a,(gcount)
        or a
        ret z
        dec a
        ld (gcount),a
        ; find a source (up to 60 tries)
        ld a,60
        ld (gtries),a
.try:   ld b,MAPW-8
        call rand_n
        add a,4
        ld c,a
        ld b,MAPH-8
        call rand_n
        add a,4
        ld b,a
        call tile_addr
        ld a,(hl)
        cp SEA+55
        jr c,.bad
        cp SEA+105
        jr c,.walk
.bad:   ld a,(gtries)
        dec a
        ld (gtries),a
        jr nz,.try
        jr .next
.walk:  ld a,200
        ld (gsteps),a
.step:  ; mark current
        call tile_addr
        push hl
        ld de,MAPSIZE
        add hl,de
        ld (hl),255
        pop hl
        ld a,(hl)
        ld (gcur),a
        ; examine 4 neighbours, choose lowest
        ld a,255
        ld (glow),a
        ld a,c
        or a
        jr z,.n1
        dec c
        call .cand
        inc c
.n1:    ld a,c
        cp MAPW-1
        jr z,.n2
        inc c
        call .cand
        dec c
.n2:    ld a,b
        or a
        jr z,.n3
        dec b
        call .cand
        inc b
.n3:    ld a,b
        cp MAPH-1
        jr z,.n4
        inc b
        call .cand
        dec b
.n4:    ld a,(glow)
        cp SEA
        jr c,.next              ; reached the sea
        ld e,a
        ld a,(gcur)
        cp e
        jr c,.lake              ; nothing lower: form a small lake
        jr z,.lake
        ld bc,(glowxy)
        ld a,(gsteps)
        dec a
        ld (gsteps),a
        jr nz,.step
        jr .next
.lake:  ; mark 3x3 around as river/lake
        dec b
        dec c
        ld e,3
.ly:    ld d,3
        push bc
.lx:    ld a,b
        cp MAPH
        jr nc,.ls
        ld a,c
        cp MAPW
        jr nc,.ls
        push hl
        call tile_addr
        push de
        ld de,MAPSIZE
        add hl,de
        pop de
        ld (hl),255
        pop hl
.ls:    inc c
        dec d
        jr nz,.lx
        pop bc
        inc b
        dec e
        jr nz,.ly
        jp .next
.cand:  ; B,C = neighbour; compare height with glow; prefer unmarked
        push hl
        call tile_addr
        ld a,(hl)
        ld e,a
        ld a,(glow)
        cp e
        jr c,.cx
        jr z,.cx
        ld a,e
        ld (glow),a
        ld (glowxy),bc
.cx:    pop hl
        ret

; classify heights/moisture into terrain ids
classify:
        ld b,0
.y:     ld c,0
.x:     call tile_addr
        push hl
        ld a,(hl)               ; height
        ld d,a
        push de
        ld de,MAPSIZE
        add hl,de
        pop de
        ld e,(hl)               ; moisture
        pop hl
        ld a,d
        cp SEA-30
        ld a,T_DEEP
        jr c,.set
        ld a,d
        cp SEA
        ld a,T_SHALLOW
        jr c,.set
        ld a,e
        cp 255
        ld a,T_RIVER
        jr z,.set
        ld a,d
        cp SEA+5
        ld a,T_BEACH
        jr c,.set
        ld a,d
        cp SEA+98
        ld a,T_SNOW
        jr nc,.set
        ld a,d
        cp SEA+78
        ld a,T_MOUNT
        jr nc,.set
        ld a,d
        cp SEA+56
        jr c,.low
        ; hills, sometimes rocks
        call hash_xy
        and 7
        ld a,T_ROCK
        jr z,.set
        ld a,T_HILLS
        jr .set
.low:   ld a,e
        cp 46
        ld a,T_DESERT
        jr c,.set
        ld a,e
        cp 200
        jr c,.nm
        ld a,d
        cp SEA+18
        ld a,T_MARSH
        jr c,.set
.nm:    ld a,e
        cp 168
        ld a,T_DENSE
        jr nc,.set
        ld a,e
        cp 126
        ld a,T_FOREST
        jr nc,.set
        call hash_xy
        and 7
        ld a,T_MEADOW
        jr z,.set
        ld a,T_GRASS
.set:   ld (hl),a
        inc c
        ld a,c
        cp MAPW
        jr nz,.x
        inc b
        ld a,b
        cp MAPH
        jr nz,.y
        ret

; hash of (B=y, C=x) -> A pseudo random, stable
hash_xy:
        push hl
        push de
        ld a,b
        ld e,a
        ld d,0
        ld hl,rtab
        add hl,de
        ld a,(hl)
        add a,c
        ld e,a
        ld hl,rtab
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

place_ruins:
        ld a,7
        ld (gcount),a
.l:     ld b,MAPW
        call rand_n
        ld c,a
        ld b,MAPH
        call rand_n
        ld b,a
        call tile_addr
        ld a,(hl)
        cp T_GRASS
        jr c,.no
        cp T_MOUNT
        jr nc,.no
        ld (hl),T_RUINS
.no:    ld a,(gcount)
        dec a
        ld (gcount),a
        jr nz,.l
        ret

; find a start: 2x2 grass/meadow block, preferring near centre
find_start:
        ld a,0
        ld (gtries),a
.try:   ld a,(gtries)
        inc a
        ld (gtries),a
        cp 250
        jr z,.force
        ; radius grows with tries
        srl a
        srl a
        add a,8
        cp 50
        jr c,.r
        ld a,50
.r:     ld e,a
        ld (grad),a
        add a,a
        ld b,a
        call rand_n
        ld d,a
        ld a,(grad)
        ld e,a
        ld a,MAPW/2
        sub e
        add a,d
        ld c,a
        ld a,(grad)
        add a,a
        ld b,a
        call rand_n
        ld d,a
        ld a,(grad)
        ld e,a
        ld a,MAPH/2
        sub e
        add a,d
        ld b,a
        ; check 2x2 (+ margin 3) grass-like
        ld a,b
        cp 4
        jr c,.try
        cp MAPH-6
        jr nc,.try
        ld a,c
        cp 4
        jr c,.try
        cp MAPW-6
        jr nc,.try
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
        ; need some forest within 5 and not too barren: count forest tiles
        call count_forest5
        cp 3
        jr c,.try
        jr .found
.force: ld b,MAPH/2
        ld c,MAPW/2
        call tile_addr
        ld (hl),T_GRASS
        inc hl
        ld (hl),T_GRASS
        ld de,MAPW-1
        add hl,de
        ld (hl),T_GRASS
        inc hl
        ld (hl),T_GRASS
.found: ld (startxy),bc
        ret

grasslike:                      ; B,C -> Z if grass or meadow
        call tile_addr
        ld a,(hl)
        and 1Fh
        cp T_GRASS
        ret z
        cp T_MEADOW
        ret

count_forest5:                  ; count forest/dense in +-5 box -> A
        push bc
        ld a,0
        ld (gcnt),a
        ld a,b
        sub 5
        ld b,a
        ld e,11
.y:     push bc
        ld a,c
        sub 5
        ld c,a
        ld d,11
.x:     ld a,b
        cp MAPH
        jr nc,.s
        ld a,c
        cp MAPW
        jr nc,.s
        call tile_addr
        ld a,(hl)
        and 1Fh
        cp T_FOREST
        jr z,.c
        cp T_DENSE
        jr nz,.s
.c:     ld a,(gcnt)
        inc a
        ld (gcnt),a
.s:     inc c
        dec d
        jr nz,.x
        pop bc
        inc b
        dec e
        jr nz,.y
        pop bc
        ld a,(gcnt)
        ret

msg_gen1: db "SHAPING THE CONTINENTS...",0
msg_gen2: db "RAISING THE MOUNTAINS...",0
msg_gen3: db "CARVING RIVERS...",0
msg_gen4: db "PLANTING FORESTS...",0
