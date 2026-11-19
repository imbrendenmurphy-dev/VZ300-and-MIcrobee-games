; ---------------------------------------------------------------- things: creatures, pickups, furniture
; object (8 bytes): type, x(2), y(2), hp, flags (bit 7 awake, low 4 hurt timer), bite cooldown
; type record (16 bytes at TYPET+type*16): page0, page1, height frac, aspect x64, raise, hp, speed,
;   bite, flags (1 boss, 2 bursts, 4 faster when hurt, 8 flies), kill message (2)
; Sprites are drawn a column at a time from inside render (sprcol), straight after that column's wall,
; so they never flicker in the direct modes.
; VIS entry (16 bytes): h, left, right, page, uacc(2), ustep per ray(2), rows, v, vstep, screen offset(2)

VISMAX  equ 12
EMARG   equ 72

objects:
        ld a,(zminc)            ; farthest wall seen last frame; anything smaller is hidden
        ld (zminl),a
        ld l,a                  ; and how far away that is (allowing for the edges of the view)
        ld h,DFL>>8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld (dthr),de
        ld a,255
        ld (zminc),a
        ld hl,MASKS             ; no sprite columns yet
        ld de,MASKS+1
        ld bc,79
        ld (hl),0
        ldir
        xor a
        ld (nvis),a
        ld (tgth),a
        ld hl,0
        ld (target),hl
        ld a,(pang)
        ld l,a
        ld h,SGN>>8
        ld a,(hl)
        ld (psgn),a
        ld h,COSM>>8
        ld a,(hl)
        ld (pcosm),a
        ld h,SINM>>8
        ld a,(hl)
        ld (psinm),a
        ld iy,OBJ
        ld b,NOBJ
ob_l:   push bc
        ld a,(iy+0)
        or a
        jp z,ob_n
        ld (otype),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,TYPET
        add hl,de
        ld (otp),hl
        ld l,(iy+1)
        ld h,(iy+2)
        ld de,(px)
        or a
        sbc hl,de
        ld (dx),hl
        call abshl
        ld (adx),hl
        ld l,(iy+3)
        ld h,(iy+4)
        ld de,(py)
        or a
        sbc hl,de
        ld (dy),hl
        call abshl
        ld (ady),hl
        xor a
        ld (oframe),a
        ld a,(otype)
        cp T_HEALTH
        jr nc,ob_p
        call ai
        jr ob_q
ob_p:   cp DECOR
        jr nc,ob_q
        ld hl,(adx)             ; a pickup: close enough to grab?
        ld a,h
        or a
        jr nz,ob_q
        ld a,l
        cp 0x70
        jr nc,ob_q
        ld hl,(ady)
        ld a,h
        or a
        jr nz,ob_q
        ld a,l
        cp 0x70
        jr nc,ob_q
        push iy
        pop hl
        call pick
        ld a,(iy+0)
        or a
        jr z,ob_n
ob_q:   call proj
        call poll
ob_n:   ld de,8
        add iy,de
        pop bc
        dec b
        jp nz,ob_l
        call addgun
; mark which columns each entry covers: bit k of MASKS[col] = ORD position k
        ld a,(nvis)
        ld b,a
        ld c,0
        ld de,1
mk_l:   push bc
        ld a,c
        add a,ORDLO
        ld l,a
        ld h,VIS>>8
        ld l,(hl)
        inc l
        ld a,(hl)               ; left
        inc l
        ld b,(hl)               ; right
        ld c,a
        ld a,b
        sub c
        ld b,a                  ; width in columns
        ld l,c
        ld h,0
        add hl,hl
        push de
        ld de,MASKS
        add hl,de
        pop de
mk_c:   ld a,(hl)
        or e
        ld (hl),a
        inc hl
        ld a,(hl)
        or d
        ld (hl),a
        inc hl
        djnz mk_c
        pop bc
        sla e
        rl d
        inc c
        djnz mk_l
        ret

; ---- creature behaviour (ported from DROPBEAR 3D)
ai:     ld a,(iy+6)
        and 0x0F
        jr z,ai1
        dec (iy+6)
ai1:    ld a,(iy+6)
        ld (oflags),a
        ld a,(lastf)
        ld b,a
        ld a,(iy+7)
        sub b
        jr nc,ai2
        xor a
ai2:    ld (iy+7),a
        ld (ocool),a
        ld a,(oflags)
        and 0x0F
        jr nz,ai3
        ld a,(ocool)
        cp 36
        jr c,ai4
ai3:    ld a,1
        ld (oframe),a
ai4:    ld hl,(otp)
        ld de,8
        add hl,de
        ld a,(hl)
        ld (oflg),a
        and 8
        jr z,ai4b
        ld a,(animt)            ; flyers flap
        rrca
        rrca
        and 1
        ld (oframe),a
ai4b:   ld a,(oflags)
        rlca
        jr c,ai_aw
        ld a,(adx+1)            ; asleep: wakes when you come within three cells
        cp 3
        ret nc
        ld a,(ady+1)
        cp 3
        ret nc
        set 7,(iy+6)
        ret
ai_aw:  ld hl,(adx)             ; awake: close enough to bite?
        ld a,h
        or a
        jr nz,ai_ch
        ld a,l
        cp 0xB0
        jr nc,ai_ch
        ld hl,(ady)
        ld a,h
        or a
        jr nz,ai_ch
        ld a,l
        cp 0xB0
        jr nc,ai_ch
        ld a,(ocool)
        or a
        ret nz
        ld (iy+7),40
        ld a,1
        ld (huddirty),a
        ld a,(oflg)
        and 8
        jr nz,ai5
        ld a,1
        ld (oframe),a
ai5:    ld hl,(otp)
        ld de,7
        add hl,de
        ld b,(hl)
        ld a,(hp)
        sub b
        jr nc,ai6
        xor a
ai6:    ld (hp),a
        ld hl,MSG_OUCH
        call setmsg
        ld de,1400              ; a low grunt
        ld a,6
        jp sound
ai_ch:  ld hl,(otp)
        ld de,6
        add hl,de
        ld c,(hl)               ; speed
        ld a,(oflg)
        bit 1,a
        jr z,ac0a
        ld a,(animt)            ; chargers rush, then catch their breath
        and 0x40
        ret z
        ld a,(oflg)
ac0a:   bit 2,a
        jr z,ac0
        ld a,32                 ; the angrier, the faster
        sub (iy+5)
        ld c,a
ac0:    ld a,(lastf)
        ld b,a
        xor a
ac1:    add a,c
        djnz ac1
        srl a
        ld (estep),a
        ld hl,(adx)
        ld a,h
        or a
        jr nz,ac2
        ld a,l
        cp 0x50
        jr c,ac6
ac2:    ld l,(iy+1)
        ld h,(iy+2)
        ld a,(estep)
        ld c,a
        ld b,0
        ld a,(dx+1)
        rlca
        jr c,ac3
        or a
        sbc hl,bc
        ld (newp),hl
        ld de,0-EMARG
        jr ac4
ac3:    add hl,bc
        ld (newp),hl
        ld de,EMARG
ac4:    add hl,de
        ld a,h
        ld (tx),a
        ld a,(iy+4)
        call testcell
        jr nz,ac6
        ld hl,(newp)
        ld (iy+1),l
        ld (iy+2),h
ac6:    ld hl,(ady)
        ld a,h
        or a
        jr nz,ac7
        ld a,l
        cp 0x50
        ret c
ac7:    ld l,(iy+3)
        ld h,(iy+4)
        ld a,(estep)
        ld c,a
        ld b,0
        ld a,(dy+1)
        rlca
        jr c,ac8
        or a
        sbc hl,bc
        ld (newp),hl
        ld de,0-EMARG
        jr ac9
ac8:    add hl,bc
        ld (newp),hl
        ld de,EMARG
ac9:    add hl,de
        ld a,(iy+2)
        ld (tx),a
        ld a,h
        call testcell
        ret nz
        ld hl,(newp)
        ld (iy+3),l
        ld (iy+4),h
        ret

; HL signed, A = magnitude 0..255, C bit 0 = negate -> HL = HL*A/256 (signed)
smul:   bit 7,h
        jr z,smu1
        push af
        call neghl
        pop af
        inc c
smu1:   push bc
        ld b,a
        push hl
        ld c,l
        call qmul               ; low byte x A
        ld a,h
        pop de
        push af
        ld c,d
        call qmul               ; high byte x A
        pop af
        add a,l
        ld l,a
        jr nc,smu2
        inc h
smu2:   pop bc
        bit 0,c
        ret z
neghl:  xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; HL = A * E
mula:   ld b,a
        ld c,e
; HL = B * C by quarter squares: (b+c)^2/4 - (b-c)^2/4. Keeps B and C.
qmul:   ld a,b
        sub c
        jr nc,qm1
        neg
qm1:    ld l,a
        ld h,QSL>>8
        ld e,(hl)
        inc h
        inc h
        ld d,(hl)
        ld a,b
        add a,c
        ld l,a
        ld a,QSL>>8
        adc a,0
        ld h,a
        ld a,(hl)
        inc h
        inc h
        ld h,(hl)
        ld l,a
        or a
        sbc hl,de
        ret

; ---- place one object on screen (IY -> object). Adds a VIS entry if any of it can be seen.
proj:   ld hl,(adx)             ; quick cull: max(|dx|,|dy|) beyond the farthest wall
        ld de,(ady)
        or a
        sbc hl,de
        add hl,de
        jr nc,pq1
        ex de,hl
pq1:    ld de,(dthr)
        or a
        sbc hl,de
        ret nc
        ld a,(nvis)
        cp VISMAX-1
        ret nc
        ld a,(psgn)             ; depth z = dx cos + dy sin
        and 1
        ld c,a
        ld hl,(dx)
        ld a,(pcosm)
        call smul
        push hl
        ld a,(psgn)
        rrca
        and 1
        ld c,a
        ld hl,(dy)
        ld a,(psinm)
        call smul
        pop de
        add hl,de
        bit 7,h
        ret nz
        ld a,h
        or a
        jr nz,pj1
        ld a,l
        cp 0x30                 ; too close (or behind)
        ret c
pj1:    ld (oz),hl
        ld a,(psgn)             ; across: lat = dy cos - dx sin
        and 1
        ld c,a
        ld hl,(dy)
        ld a,(pcosm)
        call smul
        push hl
        ld a,(psgn)
        rrca
        and 1
        xor 1
        ld c,a
        ld hl,(dx)
        ld a,(psinm)
        call smul
        pop de
        add hl,de
        ld (olat),hl
        ld hl,(oz)              ; height on screen, from the same table as the walls
        ld a,h
        cp 16
        jr c,pj2
        ld hl,0x0FFF
pj2:    srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,h
        add a,HGT>>8
        ld h,a
        ld a,(hl)
        ld (oh),a
        ld hl,zminl             ; farther than every wall we saw: can't be seen
        cp (hl)
        ret c
        ld hl,(olat)            ; centre column = 20 + lat*h
        ld c,0
        call smul
        ld de,20
        add hl,de
        ld (ocen),hl
        ld hl,(otp)             ; sprite height and width
        inc hl
        inc hl
        ld e,(hl)
        ld a,(oh)
        call mula
        ld a,h
        or a
        jr nz,pj3
        inc a
pj3:    ld (ohs),a
        ld hl,(otp)
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        call mula
        ld a,h
        cp 0x40
        ld a,255
        jr nc,pj4
        add hl,hl
        add hl,hl
        ld a,h
        or a
        jr nz,pj4
        inc a
pj4:    ld (ows),a
        ; ---- columns
        srl a
        ld e,a
        ld d,0
        ld hl,(ocen)
        or a
        sbc hl,de
        ld (oleft),hl
        ld a,(ows)
        ld e,a
        add hl,de               ; right
        bit 7,h
        ret nz
        ld a,h
        or l
        ret z
        ld a,h
        or a
        jr nz,pj5
        ld a,l
        cp 41
        jr c,pj6
pj5:    ld a,40
pj6:    ld (oright),a
        ld hl,(oleft)
        bit 7,h
        jr nz,pj7
        ld a,h
        or a
        ret nz
        ld a,l
        cp 40
        ret nc
pj7:    ld a,(ows)              ; u step per column
        ld l,a
        ld h,USTL>>8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld (oust),de
        srl d
        rr e
        ld (ouacc),de           ; start in the middle of the first column
        ld hl,(oleft)
pj8:    bit 7,h                 ; clipped on the left: skip those columns
        jr z,pj9
        push hl
        ld hl,(ouacc)
        ld de,(oust)
        add hl,de
        ld (ouacc),hl
        pop hl
        inc hl
        jr pj8
pj9:    ld a,l
        ld (oleftc),a
        ld a,(m_colstep)
        cp 2
        jr nz,pj10
        ld a,(oleftc)           ; 2-wide rays sample even columns only
        bit 0,a
        jr z,pj10
        inc a
        ld (oleftc),a
        ld hl,(ouacc)
        ld de,(oust)
        add hl,de
        ld (ouacc),hl
pj10:   ld a,(oright)
        ld b,a
        ld a,(oleftc)
        cp b
        ret nc
        ld a,b                  ; nearer than last frame's wall in at least one of its columns?
        ld hl,oleftc
        sub (hl)
        ld b,a
        ld e,(hl)
        ld d,0
        ld hl,ZB
        add hl,de
        ld a,(oh)
        ld c,a
pz1:    ld a,(hl)
        cp c
        jr c,pz2
        inc hl
        djnz pz1
        ret
pz2:
        ; ---- rows: wall top = (22-h)/2, floor = top+h, sprite sits raise*h above the floor
        ld a,(oh)
        ld e,a
        ld d,0
        ld hl,VIEWH
        or a
        sbc hl,de
        sra h
        rr l
        add hl,de
        push hl
        ld hl,(otp)
        ld de,4
        add hl,de
        ld e,(hl)
        ld a,(oh)
        call mula
        ld e,h
        ld d,0
        pop hl
        or a
        sbc hl,de
        ld (osb),hl             ; bottom row (exclusive)
        ld a,(ohs)
        ld e,a
        ld d,0
        or a
        sbc hl,de               ; top row
        ld a,(ohs)
        ld e,a
        ld d,SVSTEP>>8
        ld a,(de)
        ld (ovs),a
        srl a
        ld (ovi),a
pv0:    bit 7,h                 ; clipped at the top
        jr z,pv1
        ld a,(ovs)
        ld b,a
        ld a,(ovi)
        add a,b
        ld (ovi),a
        inc hl
        jr pv0
pv1:    ld a,h
        or a
        ret nz
        ld a,l
        cp VIEWH
        ret nc
        ld (otop),a
        ld hl,(osb)
        bit 7,h
        ret nz
        ld a,h
        or a
        jr nz,pv2
        ld a,l
        cp VIEWH+1
        jr c,pv3
pv2:    ld a,VIEWH
pv3:    ld hl,otop
        sub (hl)
        ret z
        ret c
        ld (orows),a
        ; ---- aiming: the nearest creature covering the centre column
        ld a,(otype)
        cp NENEMY+1
        jr nc,pa1
        ld a,(oleftc)
        cp 21
        jr nc,pa1
        ld a,(oright)
        cp 21
        jr c,pa1
        ld a,(tgth)
        ld b,a
        ld a,(oh)
        cp b
        jr c,pa1
        ld (tgth),a
        ld (target),iy
pa1:    ; ---- write the entry
        ld a,(nvis)
        add a,a
        add a,a
        add a,a
        add a,a
        ld (oentry),a
        ld l,a
        ld h,VIS>>8
        push hl
        pop ix
        ld a,(oh)
        ld (ix+0),a
        ld a,(oleftc)
        ld (ix+1),a
        ld a,(oright)
        ld (ix+2),a
        ld hl,(otp)
        ld a,(oframe)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (ix+3),a
        ld hl,(ouacc)
        ld (ix+4),l
        ld (ix+5),h
        ld hl,(oust)
        ld a,(m_colstep)
        cp 2
        jr nz,pw1
        add hl,hl
pw1:    ld (ix+6),l
        ld (ix+7),h
        ld a,(orows)
        ld (ix+8),a
        ld a,(ovi)
        ld (ix+9),a
        ld a,(ovs)
        ld (ix+10),a
        ld a,(otop)
        call times40
        ld (ix+11),l
        ld (ix+12),h
        jp insord

; A -> HL = A*40
times40:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ret

; insert entry (oentry) into ORD, kept sorted far (small h) to near
insord: ld a,(nvis)
        ld c,a
        inc a
        ld (nvis),a
        ld a,(oentry)
        ld l,a
        ld h,VIS>>8
        ld b,(hl)               ; its h
io1:    ld a,c
        or a
        jr z,io2
        ld l,c
        dec l
        ld a,l
        add a,ORDLO
        ld l,a
        ld e,(hl)               ; previous entry
        push hl
        ld l,e
        ld a,(hl)
        pop hl
        cp b
        jr c,io2
        jr z,io2
        inc l
        ld (hl),e
        dec c
        jr io1
io2:    ld a,c
        add a,ORDLO
        ld l,a
        ld a,(oentry)
        ld (hl),a
        ret

; the gun is the nearest thing of all, drawn by the same column code
addgun: ld a,(nvis)
        add a,a
        add a,a
        add a,a
        add a,a
        ld (oentry),a
        ld l,a
        ld h,VIS>>8
        push hl
        pop ix
        ld (ix+0),255
        ld (ix+1),GUNL
        ld (ix+2),GUNL+GUNW
        ld a,(gunflash)
        or a
        ld a,GUN0>>8
        jr z,ag1
        ld a,GUN1>>8
ag1:    ld (ix+3),a
        ld (ix+4),0x80
        ld (ix+5),0
        ld (ix+6),0
        ld a,(m_colstep)
        ld (ix+7),a
        ld (ix+8),GUNH
        ld (ix+9),8
        ld (ix+10),16
        ld (ix+11),(VIEWH-GUNH)*40&255
        ld (ix+12),(VIEWH-GUNH)*40>>8
        jp insord

; ---- per-column hook, called from render after each wall column
sprcol: ld a,(hgt)              ; remember this column's wall for next frame's culling
        ld c,a
        ld hl,zminc
        cp (hl)
        jr nc,sc00
        ld (hl),a
sc00:   ld a,(ray)
        ld b,a
        ld a,(m_colstep)
        cp 2
        ld a,b
        jr nz,sc0
        add a,a
        ld e,a
        ld d,0
        ld hl,ZB+1
        add hl,de
        ld (hl),c
sc0:    ld (scol),a
        ld e,a
        ld d,0
        ld hl,ZB
        add hl,de
        ld (hl),c
        cp 20
        jr nz,sc1
        ld a,c
        ld (cwall),a
sc1:    ld hl,MASKS             ; which entries cover this column?
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h
        ret z
        ld (smask),hl
        ld hl,VIS+ORDLO
sc_l:   push hl
        ld hl,(smask)
        srl h
        rr l
        ld (smask),hl
        pop hl
        jp nc,sc_skip
        push hl
        ld e,(hl)
        ld d,VIS>>8
        push de
        pop ix
        ld l,(ix+4)             ; texture column, then step along
        ld h,(ix+5)
        ld c,h
        ld e,(ix+6)
        ld d,(ix+7)
        add hl,de
        ld (ix+4),l
        ld (ix+5),h
        ld a,(hgt)              ; hidden behind this column's wall?
        cp (ix+0)
        jr nc,sc_n
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        exx
        ld c,a                  ; C' = column * 16
        ld b,(ix+3)             ; B' = page
        ld d,(ix+9)             ; D' = v
        ld e,(ix+10)            ; E' = v step
        exx
        ld hl,(destp)
        ld e,(ix+11)
        ld d,(ix+12)
        add hl,de
        ld de,40
        ld b,(ix+8)
        ld a,(m_colstep)
        cp 2
        jr z,sl2
sl1:    exx
        ld a,d
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        or c
        ld l,a
        ld h,b
        ld a,d
        add a,e
        ld d,a
        ld a,(hl)
        exx
        cp 0xFF
        jr z,sl1s
        ld (hl),a
sl1s:   add hl,de
        djnz sl1
        jr sc_n
sl2:    exx
        ld a,d
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        or c
        ld l,a
        ld h,b
        ld a,d
        add a,e
        ld d,a
        ld a,(hl)
        exx
        cp 0xFF
        jr z,sl2s
        ld (hl),a
        inc hl
        ld (hl),a
        dec hl
sl2s:   add hl,de
        djnz sl2
sc_n:   pop hl
sc_skip:
        inc hl
        ld a,(smask)
        ld b,a
        ld a,(smask+1)
        or b
        jp nz,sc_l
        ret

; ---- shooting
fire:   ld a,(inp)
        bit 6,a
        ret z
        ld a,(firecd)
        or a
        ret nz
        ld a,14
        ld (firecd),a
        ld a,(ammo)
        or a
        jr nz,fi1
        ld de,3000              ; click: nothing left
        ld a,1
        jp sound
fi1:    dec a
        ld (ammo),a
        ld a,1
        ld (huddirty),a
        ld a,2
        ld (gunflash),a
        ld de,180               ; crack
        ld a,3
        call sound
        ld hl,(target)
        ld a,h
        or l
        ret z
        ld a,(cwall)            ; a wall in the way?
        ld b,a
        ld a,(tgth)
        cp b
        ret c
        ret z
        push hl
        pop iy
        ld a,(iy+0)
        or a
        ret z
        ld a,(iy+6)
        or 0x84                 ; awake, and flinching
        ld (iy+6),a
        dec (iy+5)
        jr z,fi2
        ld de,700               ; thwack
        ld a,3
        jp sound
fi2:    ld a,(iy+0)
        ld (iy+0),0
        ld hl,0
        ld (target),hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,TYPET+8
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push af
        ex de,hl
        call setmsg
        ld de,2200              ; squelch
        ld a,8
        call sound
        pop af
        rrca
        ret nc
        jp opengates            ; a boss: whatever it guarded is open now

; ---- sound on the 8253: DE = count (894.9 kHz / frequency), A = fields to play
sound:  ld (sndt),a
        ld a,0x36
        ld (0xE007),a
        ld a,e
        ld (0xE004),a
        ld a,d
        ld (0xE004),a
        ld a,1
        ld (0xE008),a
        ret
