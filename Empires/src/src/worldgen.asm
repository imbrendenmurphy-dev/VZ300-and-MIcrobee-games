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
        call puts_at_far
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
        ; cells across = (W-1)>>shift + 1, grid width = cells + 2
        ld a,(gshift)
        ld b,a
        ld a,(mapwm1)
.dv:    srl a
        djnz .dv
        inc a
        ld (gcells),a
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
        ld a,(gfy)
        or a
        jr nz,.cstep
        ; start of a grid band: acc = top << 8 (+0.5), step = (bottom-top) << (8-shift)
        ld a,(gyi)
        ld h,a
        ld a,(ggw)
        ld e,a
        call mul8
        ld de,grid
        add hl,de               ; HL = &G[gyi][0]
        ld a,(ggw)
        ld b,a
        ld ix,colacc
.ci:    push bc
        push hl
        ld a,(hl)               ; top
        ld (ix+1),a
        ld (ix+0),80h
        ld e,a
        ld a,(ggw)
        ld c,a
        ld b,0
        add hl,bc
        ld l,(hl)               ; bottom
        ld h,0
        ld d,0
        or a
        sbc hl,de               ; bottom - top (signed)
        ld a,(gshift)
        ld b,a
        ld a,8
        sub b
        ld b,a
.cs:    add hl,hl
        djnz .cs
        ld (ix+2),l
        ld (ix+3),h
        ld de,4
        add ix,de
        pop hl
        inc hl
        pop bc
        djnz .ci
        jr .cdone
.cstep: ld a,(ggw)
        ld b,a
        ld hl,colacc
.cn:    ld e,(hl)
        inc hl
        ld d,(hl)               ; acc
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a                  ; step
        add hl,de
        ex de,hl
        pop hl
        dec hl
        dec hl
        dec hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc hl
        inc hl
        djnz .cn
.cdone: ; colv[j] = acc high byte
        ld a,(ggw)
        ld b,a
        ld hl,colacc+1
        ld de,colv
.cv:    ld a,(hl)
        ld (de),a
        inc de
        inc hl
        inc hl
        inc hl
        inc hl
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
        ld bc,(gout)
        ld a,(gmode)
        or a
        jr nz,.addm
        ld a,(gsp)
        cp 8
        jr z,.s8
        call px_set16
        jr .pd
.s8:    call px_set8
        jr .pd
.addm:  ld a,(gsp)
        cp 8
        jr z,.a8
        call px_add16
        jr .pd
.a8:    call px_add8
.pd:    ld (gout),bc
        inc ix
        pop bc
        djnz .hc
        ld a,(gy)
        inc a
        ld (gy),a
        ld e,a
        ld a,(maphm1)
        inc a
        sub e
        jp nz,.row
        ret


; unrolled interpolation: HL = value (8.8), DE = step, BC = destination
px_set16:
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
px_set8:
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ld a,h
        ld (bc),a
        inc bc
        add hl,de
        ret
px_add16:
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
px_add8:
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ld a,(bc)
        add a,h
        jr nc,$+4
        ld a,255
        ld (bc),a
        inc bc
        add hl,de
        ret

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
        call map_clear
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
        ld hl,OBJOFF            ; moisture layer (object layer during generation)
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
        ; clear object layer in every band
        xor a
.cb:    push af
        call map_band
        ld hl,OBJOFF
        ld de,OBJOFF+1
        ld bc,3FFFh
        ld (hl),0
        ldir
        pop af
        inc a
        cp 4
        jr nz,.cb
        call find_start
        ld a,40
        jp gen_bar

; falloff + raise + moisture bias.  falloff(x,y) ~ min(255, fx[x] + fy)
; with fx[x] = (x-cx)^2 >> f and fy = (y-cy)^2 >> f: no multiplies per tile
shape_pass:
        ld a,2
        call wt_get
        ld b,a
        ld a,(worldsize)
        add a,a
        add a,b
        ld (gfall),a
        ld a,3
        call wt_get
        ld (graise),a
        ld a,4
        call wt_get
        ld (gmbias),a
        ; biome thresholds move instead of every moisture value
        ld hl,th_base
        ld de,th_desert
        ld b,4
.th:    ld a,(gmbias)
        ld c,a
        ld a,(hl)
        sub c                   ; threshold - bias (signed bias)
        bit 7,c
        jr nz,.tn
        jr nc,.tw
        ld a,1                  ; underflow: keep >= 1
        jr .tw
.tn:    jr c,.tw                ; negative bias: a borrow is the normal case
        ld a,254
.tw:    ld (de),a
        inc hl
        inc de
        djnz .th
        ; column table in grid[0..255]
        ld c,0
.fx:    ld a,c
        ld hl,mapcx
        call .fall
        ld hl,grid
        ld e,c
        ld d,0
        add hl,de
        ld (hl),a
        inc c
        ld a,(mapwm1)
        inc a
        sub c
        jr nz,.fx
        ld b,0
.y:     ld a,b
        ld hl,mapcy
        call .fall
        ld (gfy),a
        ld c,0
        call tile_addr
        ld de,grid
.x:     ld a,(de)
        push hl
        ld hl,gfy
        add a,(hl)
        jr nc,.f1
        ld a,255
.f1:    ld (gta),a              ; falloff for this tile
        ld a,(graise)
        pop hl
        add a,(hl)
        jr nc,.r
        ld a,255
.r:     push hl
        ld hl,gta
        sub (hl)
        pop hl
        jr nc,.s
        xor a
.s:     ld (hl),a
        inc hl
        inc de
        inc c
        ld a,(mapwm1)
        inc a
        sub c
        jr nz,.x
        inc b
        ld a,(maphm1)
        inc a
        sub b
        jr nz,.y
        ret
.fall:  ; A = coordinate, HL -> centre: A = min(255, (A-centre)^2 >> gfall)
        sub (hl)
        jr nc,.p
        neg
.p:     call sq16
        ld a,(gfall)
        push bc
        ld b,a
.sh:    srl h
        rr l
        djnz .sh
        pop bc
        ld a,h
        or a
        ld a,l
        ret z
        ld a,255
        ret

th_base: db 46,200,168,126      ; desert, marsh, dense, forest (moisture)
sq16:                           ; HL = A*A
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
.try:   ld a,(mapwm1)
        sub 7
        ld b,a
        call rand_n
        add a,4
        ld c,a
        ld a,(maphm1)
        sub 7
        ld b,a
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
        ld de,OBJOFF
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
        call iswm1
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
        call ishm1
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
        call cph
        jr nc,.ls
        ld a,c
        call cpw
        jr nc,.ls
        push hl
        call tile_addr
        push de
        ld de,OBJOFF
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
        ld de,OBJOFF
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
.low:   ld a,(th_desert)        ; moisture < desert threshold
        dec a
        cp e
        ld a,T_DESERT
        jr nc,.set
        ld a,(th_marsh)
        dec a
        cp e
        jr nc,.nm
        ld a,d
        cp SEA+18
        ld a,T_MARSH
        jr c,.set
.nm:    ld a,(th_dense)
        dec a
        cp e
        ld a,T_DENSE
        jr c,.set
        ld a,(th_forest)
        dec a
        cp e
        ld a,T_FOREST
        jr c,.set
        call hash_xy
        and 7
        ld a,T_MEADOW
        jr z,.set
        ld a,T_GRASS
.set:   ld (hl),a
        inc c
        ld a,(mapwm1)
        inc a
        sub c
        jr nz,.x
        inc b
        ld a,(maphm1)
        inc a
        sub b
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
.l:     ld a,(mapwm1)
        ld b,a
        call rand_n
        ld c,a
        ld a,(maphm1)
        ld b,a
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
        ld a,(mapcx)
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
        ld a,(mapcy)
        sub e
        add a,d
        ld b,a
        ; check 2x2 (+ margin 3) grass-like
        ld a,b
        cp 4
        jr c,.try
        ld e,a
        ld a,(maphm1)
        sub 6
        cp e
        ld a,e
        jr c,.try
        ld a,c
        cp 4
        jr c,.try
        ld e,a
        ld a,(mapwm1)
        sub 6
        cp e
        ld a,e
        jr c,.try
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
.force: ld a,(mapcy)
        ld b,a
        ld a,(mapcx)
        ld c,a
        call tile_addr
        ld (hl),T_GRASS
        inc hl
        ld (hl),T_GRASS
        inc b
        call tile_addr
        ld (hl),T_GRASS
        inc hl
        ld (hl),T_GRASS
        dec b
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
        call cph
        jr nc,.s
        ld a,c
        call cpw
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

