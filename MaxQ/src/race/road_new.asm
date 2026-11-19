; =====================================================================
;  RASTER ROAD (v0.12) - mirrors road_ref.py step for step
;  The road is 32 fixed depth slots (d = 32 near .. 1 far).  Walking from
;  near to far:  dx += CURV[section], x += dx  bends it;
;                dh += SLP[section] - SLP[here], h += dh  makes the hills.
;  Registers in the slot loop: HL' x, DE' dx, BC' road slide, IX h, IY dh.
;  Slot tables (page XCA):  +d XC (centre, screen x + 64)   +$40+d curve px
;                           +$80+d screen row               +$C0+d rows hidden below
;  Each visible slot gets one span list (SL + (d-1)*16) that all its screen
;  rows share; rows find it through RLPL/RLPH, and their dither half through
;  the pattern page in ROWPG (even rows RDP0/RDP1, odd rows RDP0O/RDP1O).
;  Page ZTL (constants): +d depth low, +$40+d depth high, +$80+d half-width, +$C0+d rumble
; =====================================================================
render:
        ld hl,(CAM_I)           ; heading for the skyline, eased across the section
        ld de,TRK_H
        add hl,de
        ld a,(hl)
        ld (HC),a
        ld hl,(CAM_I)
        inc hl
        ld a,h
        and 1
        ld h,a
        add hl,de
        ld a,(HC)
        ld b,a
        ld a,(hl)
        sub b
        ld b,a
        ld a,(CAM_F)
        srl a
        ld c,a
        call mul8
        add hl,hl
        ld a,(HC)
        add a,h
        ld (HC),a
        ld hl,(CAM_I)           ; our own slope: a steady climb looks flat
        ld de,TRK_SL
        add hl,de
        ld a,(hl)
        ld (.s0+1),a
        ld a,(CAM_F)            ; camera position into the section sums
        ld (.cf+1),a
        ld a,(CAM_I)
        ld (.ci+1),a
        ld a,(CAM_I+1)
        ld (.ch+1),a
        ld a,(CAM_LAT)          ; the road slides under the craft: -lat px at the bottom row,
        call sext               ; tapering to nothing at the horizon
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        ld (.lsl+1),a
        ld a,h
        ld (.lsh+1),a
        ld a,(CAM_LAT)
        neg
        exx
        ld b,a
        ld c,0                  ; BC' = slide
        ld hl,0                 ; HL' = x
        ld d,h
        ld e,l                  ; DE' = dx
        exx
        ld ix,0                 ; IX = h
        ld iy,0                 ; IY = dh
        ld a,64
        ld (RTOP),a
        ld a,ND
.lp:    ld (RD),a
        ld l,a                  ; section at this slot = camera + depth
        add a,HZ0
        ld d,a                  ; D = HZ0 + d
        ld h,ZTL/256
        ld a,(hl)
.cf:    add a,0
        set 6,l
        ld a,(hl)
.ci:    adc a,0
        ld c,a
.ch:    ld a,0
        adc a,0
        and 1
        ld b,a                  ; BC = section
        exx                     ; centre = 128 + (x + slide) / 256, curve px = x / 256
        ld a,l
        add a,c
        ld a,h
        adc a,b
        ex af,af'
        ld a,h
        exx
        ld h,XCA/256
        ld (hl),a               ; (L = $40 + d) curve px
        res 6,l
        ex af,af'
        add a,128
        ld (hl),a               ; centre
        ld e,a                  ; E = centre
        ld a,ixh                ; screen row = HZ0 + d - h/1024
        sra a
        sra a
        neg
        add a,d
        ld d,a                  ; D = y
        set 7,l
        ld (hl),a
        set 6,l
        ld a,(RTOP)
        ld (hl),a
        cp d                    ; top - y
        jr c,.hid
        jr z,.hid               ; behind a crest
        ld (.otop+1),a
        ld a,d
        cp RYMIN
        jr nc,.y1
        ld a,RYMIN
.y1:    ld (RTOP),a
        ld d,a                  ; D = first row of this slot
.otop:  ld a,0
        sub d
        jr z,.hid
        ld (.nrows+1),a
        ld l,a                  ; same centre, section and rows as last frame? nothing to do
        ld a,b
        rrca
        or l
        ld (.sn+1),a            ; (rows | section bit 8)
        ld a,(RD)
        ld l,a
        ld h,SCC/256
        ld a,e
        cp (hl)
        jr nz,.chg
        set 6,l
        ld a,c
        cp (hl)
        jr nz,.chg
        set 7,l
        res 6,l
        ld a,d
        cp (hl)
        jr nz,.chg
        set 6,l
        ld a,(.sn+1)
        cp (hl)
        jr z,.hid
.chg:   ld a,(RD)
        ld l,a
        ld (hl),e
        set 6,l
        ld (hl),c
        set 7,l
        res 6,l
        ld (hl),d
        set 6,l
.sn:    ld (hl),0
        push bc
        call .slot
        pop bc
.hid:   ld hl,TRK_CV            ; bend: dx += curve, x += dx
        add hl,bc
        ld a,(hl)
        inc h
        inc h
        ld c,(hl)               ; (slope, 512 bytes on)
        exx
        or a
        jp p,.cp
        dec d
.cp:    add a,e
        ld e,a
        jr nc,.cq
        inc d
.cq:    add hl,de
        ld a,c                  ; slide eases off towards the horizon
.lsl:   add a,0
        ld c,a
        ld a,b
.lsh:   adc a,0
        ld b,a
        exx
        ld a,c                  ; hill: dh += slope - ours, h += dh
.s0:    sub 0
        ld e,a
        rla
        sbc a,a
        ld d,a
        add iy,de
        push iy
        pop de
        add ix,de
        ld a,(RD)
        dec a
        jp nz,.lp
        ld a,(RTOP)
        ld (SPLIT),a
        ; ---- sky rows (bands spread down to the horizon), one list per row;
        ; unchanged unless the horizon row or the sky moved
        ld hl,(SKYTAB)
        ld de,(SKYKEY)
        or a
        sbc hl,de
        jr nz,.skn
        ld a,(SKYKEY+2)
        ld b,a
        ld a,(SPLIT)
        cp b
        ret z
.skn:   ld hl,(SKYTAB)
        ld (SKYKEY),hl
        ld a,(SPLIT)
        ld (SKYKEY+2),a
        sub TOPROW
        ld (RN),a
        ld hl,LISTS+TOPROW*32+1
        ld de,ROWPG+TOPROW
        ld c,TOPROW
        ld b,0
        ld a,2
        ld (RBAND),a
.sk:    ld a,(SPLIT)
        cp c
        ret z
        push de
        ld e,c                  ; this row's list
        ld d,RLPL/256
        ld a,l
        dec a
        ld (de),a
        inc d
        ld a,h
        ld (de),a
        pop de
        push hl
        ld hl,(SKYTAB)
        ld a,(RBAND)
        add a,l
        ld l,a
        jr nc,.s1
        inc h
.s1:    ld a,(hl)
        pop hl
        bit 0,c
        jr z,.ev
        add a,16
.ev:    ld (hl),a
        inc l
        ld (hl),128
        ld a,l
        add a,31
        ld l,a
        jr nc,.s2
        inc h
.s2:    ld a,PATTAB/256
        ld (de),a
        inc e
        ld a,b
        add a,3
        ld b,a
        push hl
        ld hl,RN
        cp (hl)
        jr c,.s3
        sub (hl)
        ld b,a
        ld hl,RBAND
        inc (hl)
.s3:    pop hl
        inc c
        jr .sk

        ; ---- a visible slot: its span list, and its rows D .. D+n-1 pointed at it
        ; BC = section, E = centre, D = first row
.slot:  ld a,d
        ld (.row0+1),a
        ld a,e
        ld (XCV),a
        ld a,RDP0/256           ; band pages (even, odd rows): two sections light, two dark
        ld h,RDP0O/256
        bit 1,c
        jr z,.b0
        ld a,RDP1/256
        ld h,RDP1O/256
.b0:    ld (.pe+1),a
        ld a,h
        ld (.po+1),a
        ld a,c                  ; surface: B = road colour, C = second colour on a ramp (else 0)
        and 126
        cp 40
        jr nz,.n1
        ld a,c                  ; boost pad
        and 1
        add a,PAD_ID
        ld b,a
        ld c,0
        jr .key
.n1:    cp 100                  ; jump ramp on half the road: 100/101 left, 228/229 right
        jr nz,.n2
        ld a,c
        and 1
        add a,RAMP_ID
        bit 7,c
        jr nz,.rr2
        ld b,a                  ; left: ramp, then plain road from the centre
        ld c,C_ID
        jr .key
.rr2:   ld c,a                  ; right: plain road, then ramp from the centre
        ld b,C_ID
        jr .key
.n2:    ld a,c                  ; start line or plain road
        or b
        ld b,LINE_ID
        jr z,.k0
        ld b,C_ID
.k0:    ld c,0
.key:   ld a,b
        ld (.c1+1),a
        ld a,c
        ld (.c2+1),a
        rlca
        rlca
        rlca
        or b
        ld b,a                  ; B = what the list depends on besides the centre
        ld a,(RD)
        ld l,a
        ld h,SLPT/256           ; list address for this slot
        ld a,(hl)
        ld (.lo+1),a
        ld e,a
        inc h
        ld a,(hl)
        ld (.hi+1),a
        ld d,a
        ld h,SLC/256            ; same centre and surface as last frame? the list still stands
        ld a,(XCV)
        cp (hl)
        jr nz,.miss
        set 6,l
        ld a,b
        cp (hl)
        jp z,.row0h
        res 6,l
        ld a,(XCV)
.miss:  ld (hl),a
        set 6,l
        ld (hl),b
        res 6,l
        set 7,l                 ; B = half-width, C = rumble width
        ld h,ZTL/256
        ld b,(hl)
        set 6,l
        ld c,(hl)
        xor a                   ; list head: x 0, ground
        ld (de),a
        inc e
        ld (de),a
        ld h,CLT/256            ; (CLT: screen x + 64, saturated -> clamped 0..128)
        ld a,(XCV)
        sub b
        jr nc,.a1
        xor a
.a1:    ld l,a
        ld a,(hl)
        ex af,af'               ; A' = inner left edge
        ld a,l
        sub c
        jr nc,.a2
        xor a
.a2:    ld l,a
        ld a,(hl)               ; outer left edge
        or a
        jr z,.o0
        cp 128
        jr z,.end
        inc e
        ld (de),a
        inc e
.o0:    ld a,R_ID
        ld (de),a
        ex af,af'
        or a
        jr z,.o1
        cp 128
        jr z,.end
        inc e
        ld (de),a
        inc e
.o1:
.c1:    ld a,0
        ld (de),a
        ld a,(.c2+1)
        or a
        jr z,.ns
        ld a,(XCV)              ; ramp: the centre line splits the road
        ld l,a
        ld a,(hl)
        or a
        jr z,.o2
        cp 128
        jr z,.end
        inc e
        ld (de),a
        inc e
.o2:
.c2:    ld a,0
        ld (de),a
.ns:    ld a,(XCV)
        add a,b
        jr nc,.a3
        ld a,255
.a3:    ld l,a
        ld a,(hl)               ; inner right edge
        or a
        jr z,.o3
        cp 128
        jr z,.end
        inc e
        ld (de),a
        inc e
.o3:    ld a,R_ID
        ld (de),a
        ld a,l
        add a,c
        jr nc,.a4
        ld a,255
.a4:    ld l,a
        ld a,(hl)               ; outer right edge
        or a
        jr z,.o4
        cp 128
        jr z,.end
        inc e
        ld (de),a
        inc e
.o4:    ld a,G_ID
        ld (de),a
.end:   inc e
        ld a,128
        ld (de),a
.row0:  ld a,0                  ; rows (new list): list pointer, pattern page, and redraw them
        ld l,a
        ld h,RLPL/256
        add a,ROWPG & 255
        ld e,a
        ld d,ROWPG/256
        ld a,(.nrows+1)
        ld b,a
        ld a,(.lo+1)
        ld c,a
.rlm:   ld (hl),c
        inc h
        ld a,(.hi+1)
        ld (hl),a
        inc h
        ld (hl),1               ; RDIRTY
        dec h
        dec h
        bit 0,l
        ld a,(.pe+1)
        jr z,.pm
        ld a,(.po+1)
.pm:    ld (de),a
        inc e
        inc l
        djnz .rlm
        ret
.row0h: ld a,(.row0+1)          ; rows (list unchanged): redraw only rows whose list or page moved
        ld l,a
        ld h,RLPL/256
        add a,ROWPG & 255
        ld e,a
        ld d,ROWPG/256
.nrows: ld b,0
.rl:    ld c,0                  ; C = changed
.lo:    ld a,0
        cp (hl)
        jr z,.r1
        ld (hl),a
        inc c
.r1:    inc h
.hi:    ld a,0
        cp (hl)
        jr z,.r2
        ld (hl),a
        inc c
.r2:    bit 0,l
.pe:    ld a,0
        jr z,.pz
.po:    ld a,0
.pz:    ex de,hl
        cp (hl)
        jr z,.r3
        ld (hl),a
        inc c
.r3:    ex de,hl
        inc h
        ld a,c
        or a
        jr z,.r4
        ld (hl),1               ; RDIRTY
.r4:    dec h
        dec h
        inc e
        inc l
        djnz .rl
        ret

; ---------------------------------------------------------------------
; RV_PROJECT: screen position, size, view and crest clip of every record
; in view (rivals, pickups, arrows, missile, mine).  R_D sections + R_FR
; ahead of the camera -> depth slot -> row, centre and width.
; ---------------------------------------------------------------------
rv_project:
        ld ix,RV
        ld b,NREC
.r:     push bc
        ld (ix+R_VIS),0
        ld a,(ix+R_D)
        cp 255
        jp z,.nx
        cp 16
        jr c,.near
        cp 21
        ld a,3
        jr c,.gd
        ld a,2
        jr .gd
.near:  rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(ix+R_FR)
        rrca
        rrca
        rrca
        rrca
        and 15
        or c
        ld l,a
        ld h,DIDX/256
        ld a,(hl)
.gd:    ld e,a                  ; E = slot
        ld l,a
        ld h,XCA/256
        ld d,(hl)               ; D = road centre there
        set 7,l
        ld a,(hl)
        add a,65
        ld (ix+R_SY),a          ; sits on its row
        set 6,l
        ld a,(hl)
        add a,64
        ld (ix+R_YCL),a         ; rows from here down are behind a crest
        res 7,l
        ld a,(hl)               ; curve offset: which way the road there has turned
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
        ld a,e                  ; width: the craft is 24 px at slot 27
        rrca
        rrca
        rrca
        rrca
        and 15
        neg
        add a,e
        ld (ix+R_W),a
        push de
        ld b,(ix+R_LAT)         ; x = centre + lat * d / 32
        ld c,e
        call mul8
        add hl,hl
        add hl,hl
        add hl,hl
        pop de
        ld a,h
        or a
        jp m,.neg
        add a,d
        jr nc,.sok
        ld a,255
        jr .sok
.neg:   add a,d
        jr c,.sok
        xor a
.sok:   ld (ix+R_SX),a
        ld (ix+R_VIS),1
.nx:    ld de,32
        add ix,de
        pop bc
        dec b
        jp nz,.r
        ret
