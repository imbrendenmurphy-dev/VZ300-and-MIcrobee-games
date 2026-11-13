; =====================================================================
;  STAGE 3: locale files, scenery table with culling, many runways
; =====================================================================

; ---- load the locale named on the command line (default CORAL.LOC)
;      through CP/M, before the program takes over the machine.
loadloc:
        ld a,(5Dh)
        cp ' '+1
        jr nc,ll1               ; a name was typed after SCROSS
        ld hl,defname
        ld de,5Dh
        ld bc,8
        ldir
ll1:    ld hl,loctyp
        ld de,65h
        ld bc,3
        ldir
        ld hl,68h               ; extent, record counts, cr
        ld b,21
ll2:    ld (hl),0
        inc hl
        djnz ll2
        ld c,15                 ; open
        ld de,5Ch
        call 5
        inc a
        jr z,llbad
        ld hl,LOCBUF
llr:    push hl
        ex de,hl
        ld c,26                 ; set DMA
        call 5
        ld c,20                 ; read sequential
        ld de,5Ch
        call 5
        pop hl
        or a
        jr nz,lldone
        ld de,128
        add hl,de
        ld a,h
        cp LOCEND/256
        jr c,llr
lldone: ld c,16                 ; close
        ld de,5Ch
        call 5
        ld a,(LOCBUF)
        cp 'S'
        jr nz,llbad
        ld a,(LOCBUF+1)
        cp 'C'
        jr nz,llbad
        ld a,(LOCBUF+2)
        cp 4
        jr nz,llbad
        ld a,1
        jr llset
llbad:  ld hl,homeloc
        ld de,LOCBUF
        ld bc,HOMELEN
        ldir
        xor a
llset:  ld (locok),a
        ld hl,(LOCBUF+19)
        ld (objp),hl
        ld hl,(LOCBUF+21)
        ld (rwyp),hl
        ld a,(LOCBUF+23)
        ld (nrwy),a
        ld hl,(LOCBUF+24)
        ld (misp),hl
        ld a,(LOCBUF+26)
        ld (nmis),a
        ld hl,LOCBUF+3          ; area name into the title line
        ld de,paneltext+F_LOC-512
        ld bc,16
        ldir
        ret

defname: db "CORAL   "
loctyp:  db "LOC"

; ---- scenery: walk the locale's object table
drawloc:
        ld hl,(objp)
dlo0:   ld a,(hl)
        or a
        ret z
        ld (otype),a
        inc hl
        ld a,(detail)
        cp (hl)
        jr c,dloskip
        inc hl
        ld a,(hl)
        ld (ocull),a
        inc hl
        ld a,(hl)
        ld (orad),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(px)
        ex de,hl
        or a
        sbc hl,de
        ld (odx),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(pz)
        ex de,hl
        or a
        sbc hl,de
        ld (odz),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (optr),de
        push hl
        call vbpoll
        call dlcull
        jr c,dlonext
        ld hl,(optr)
        ld a,(otype)
        and 7Fh
        cp 1
        jr nz,dlos
        call dobj
        jr dlonext
dlos:   call dser
dlonext:
        pop hl
        jr dlo0
dloskip:
        ld de,9
        add hl,de
        jr dlo0

; carry = object can't be seen (too far, or behind / well off to the side)
dlcull: xor a
        ld (lodfar),a
        ld hl,(odx)
        bit 7,h
        call nz,neghl
        ld a,(ocull)
        dec a
        cp h
        ret c                   ; |dx| >= cull*256
        ld hl,(odz)
        bit 7,h
        call nz,neghl
        ld a,(ocull)
        dec a
        cp h
        ret c
        ld a,(otype)            ; flat on the ground and so far away that
        rla                     ; it lies on the horizon: skip
        jr nc,dlc0
        ld hl,(odx)
        bit 7,h
        call nz,neghl
        ex de,hl
        ld hl,(odz)
        bit 7,h
        call nz,neghl
        or a
        sbc hl,de
        add hl,de
        jr nc,dlcf1
        ex de,hl                ; HL = max(|dx|, |dz|)
dlcf1:  ld a,(orad)             ; minus the radius (16 m units)
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        or a
        sbc hl,de
        jr c,dlc0               ; we are inside it
        ex de,hl                ; DE = nearest distance
        ld hl,(alt)             ; limit = 64 x (height + 2 m): any further and
        inc hl                  ; it is within ~3 pixels of the horizon
        inc hl
        ld a,h
        cp 2
        jr nc,dlc0              ; 512 m up or more: no limit worth having
        ld h,l
        ld l,0
        srl h
        rr l
        srl h
        rr l                    ; *64
        or a
        sbc hl,de
        ret c                   ; further than the limit
dlc0:   ld a,(pitch+1)          ; steep nose up/down: distance cull only
        call absa
        cp 22
        ret nc
        ld a,(orad)             ; rad = radius in metres
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (orm),hl
        ; f = dx*sin(h) + dz*cos(h)  (ahead)
        ld hl,(odx)
        ld a,(sh)
        call mul168
        push hl
        ld hl,(odz)
        ld a,(ch)
        call mul168
        pop de
        add hl,de
        ld (ofw),hl
        ld de,(orm)
        add hl,de
        bit 7,h
        scf
        ret nz                  ; wholly behind
        xor a                   ; level of detail from the size on screen
        ld (lodfar),a           ; (about 256 x radius / distance pixels)
        ld hl,(orm)
        ld a,h
        cp 2
        jr nc,dlc2              ; big objects: always full
        add hl,hl
        add hl,hl               ; 4 x radius
        push hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; 12 x radius: under ~21 pixels -> far set
        ld de,(ofw)
        or a
        sbc hl,de
        jr nc,dlc1
        ld a,1
        ld (lodfar),a
dlc1:   pop hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl               ; 24 x radius: under ~10 pixels -> not drawn
        ld de,(ofw)
        or a
        sbc hl,de
        ret c
dlc2:
        ; r = dx*cos(h) - dz*sin(h)  (to the right)
        ld hl,(odz)
        ld a,(sh)
        call mul168
        push hl
        ld hl,(odx)
        ld a,(ch)
        call mul168
        pop de
        or a
        sbc hl,de
        bit 7,h
        call nz,neghl
        push hl                 ; |r|
        ld hl,(ofw)
        add hl,hl
        ld de,(orm)
        add hl,de
        add hl,de
        add hl,de               ; 2f + 3 rad
        pop de
        bit 7,h
        scf
        ret nz
        or a
        sbc hl,de               ; carry if |r| > 2f + 3 rad
        ret

; ---- runway frame.  HL -> runway entry.  Works out, for the direction
; the aircraft is heading: (ral) distance past that end's threshold,
; (rac) metres right of the centreline, (rrh) heading error, (rrev).
rwfr:   ld (rwp),hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(px)
        or a
        sbc hl,de
        ld (rdx),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(pz)
        or a
        sbc hl,de
        ld (rdz),hl
        pop hl
        ld a,(hl)
        inc hl
        ld (rax),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (rlen),de
        ld a,(hl)
        inc hl
        ld (rhw),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (raim),de
        ld a,(rax)
        or a
        jr nz,rwf1
        ld hl,(rdz)             ; runs north: along = dz, right = +x
        ld (ral),hl
        ld hl,(rdx)
        ld (rac),hl
        ld a,(hdg+1)
        jr rwf2
rwf1:   ld hl,(rdx)             ; runs east: along = dx, right = -z
        ld (ral),hl
        ld hl,(rdz)
        call neghl
        ld (rac),hl
        ld a,(hdg+1)
        sub 64
rwf2:   ld (rrh),a
        add a,64
        and 80h
        ld (rrev),a
        ret z
        ld a,(rrh)              ; heading the other way: use the far end
        add a,128
        ld (rrh),a
        ld hl,(rlen)
        ld de,(ral)
        or a
        sbc hl,de
        ld (ral),hl
        ld hl,(rac)
        call neghl
        ld (rac),hl
        ret

; after rwfr: carry if the aircraft is on that runway
rwon:   ld hl,(ral)
        bit 7,h
        jr nz,rwno
        ex de,hl
        ld hl,(rlen)
        or a
        sbc hl,de
        jr c,rwno
        ld hl,(rac)
        bit 7,h
        call nz,neghl
        ld a,h
        or a
        jr nz,rwno
        ld a,(rhw)
        add a,2
        cp l
        jr c,rwno
        scf
        ret
rwno:   or a
        ret

; carry if on any runway (frame left set up for it)
rwfind: ld a,(nrwy)
        or a
        ret z
        ld b,a
        ld hl,(rwyp)
rwfd1:  push bc
        push hl
        call rwfr
        call rwon
        pop hl
        pop bc
        ret c
        ld de,20
        add hl,de
        djnz rwfd1
        or a
        ret

; ---- pick the runway being approached (or rolled along)
rwsel:  xor a
        ld (selok),a
        ld hl,10000
        ld (srng),hl
        ld a,(nrwy)
        or a
        ret z
        ld b,a
        ld hl,(rwyp)
rws1:   push bc
        push hl
        call rwfr
        ld a,(ongnd)
        or a
        jr z,rws3
        call rwon
        jr nc,rws9
        call rwtake
        pop hl
        pop bc
        ret
rws3:   ld hl,(raim)            ; range to the aim point
        ld de,(ral)
        or a
        sbc hl,de
        bit 7,h
        jr nz,rws9
        ld a,h
        or l
        jr z,rws9
        ld (rtmp),hl
        ld de,(srng)
        or a
        sbc hl,de
        jr nc,rws9              ; not nearer than the best so far
        ld hl,(rac)             ; inside a ~27 degree cone (off-line < range/2)
        bit 7,h
        call nz,neghl
        ex de,hl
        ld hl,(rtmp)
        srl h
        rr l
        or a
        sbc hl,de
        jr c,rws9
        ld a,(rrh)              ; heading within 45 degrees
        add a,32
        cp 65
        jr nc,rws9
        call rwtake
rws9:   pop hl
        pop bc
        ld de,20
        add hl,de
        djnz rws1
        ret
rwtake: ld a,1
        ld (selok),a
        ld hl,(raim)
        ld de,(ral)
        or a
        sbc hl,de
        ld (srng),hl
        ld hl,(rac)
        ld (sac),hl
        ld hl,(rwp)
        ld (selp),hl
        ld a,(rrev)
        ld (srev),a
        ld a,(rax)
        ld (sax),a
        ret

; HL -> runway entry, A = axis, C = reversed flag, DE = dest:
; write "NAME NN" (trimmed), DE moves past it
rwname: push bc
        push af
        ld bc,10
        add hl,bc
        ld b,9
rwn1:   ld a,(hl)
        cp ' '
        jr nz,rwn2
        inc hl
        ld a,(hl)
        dec hl
        cp ' '
        jr z,rwn3               ; two spaces: end of name
        ld a,' '
rwn2:   ld (de),a
        inc hl
        inc de
        djnz rwn1
rwn3:   ld a,' '
        ld (de),a
        inc de
        pop af
        add a,a
        pop bc
        bit 7,c
        jr z,rwn4
        inc a
rwn4:   add a,a
        ld c,a
        ld b,0
        ld hl,rwnums
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        ret
rwnums: db "36180927"

; ---- put the aircraft at runway (curfld): A = 0 threshold, 1 final
rwplace:
        ld (rpm),a
        ld a,(nrwy)
        or a
        ret z
        ld a,(curfld)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *20
        ld de,(rwyp)
        add hl,de
        ld (rwp),hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (px),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pz),de
        ld a,(hl)
        ld (rax),a
        ld de,4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; aim
        ld hl,20
        ld a,(rpm)
        or a
        jr z,rwp1
        ld hl,-1500
        add hl,de               ; aim - 1500
rwp1:   ld a,(rax)
        or a
        jr nz,rwp2
        ld de,(pz)
        add hl,de
        ld (pz),hl
        ld hl,0
        ld (hdg),hl
        jr rwp3
rwp2:   ld de,(px)
        add hl,de
        ld (px),hl
        ld hl,64*256
        ld (hdg),hl
rwp3:   ; message
        ld a,(rpm)
        or a
        ld hl,m_on
        jr z,rwp4
        ld hl,m_tofin
rwp4:   call setmsg
        ld hl,(rwp)
        ld a,(rax)
        ld c,0
        call rwname
        ld a,(rpm)
        or a
        ld hl,m_rwy
        jr z,rwp5
        ld hl,m_fin
rwp5:   jp ps2

; ---- N: next airfield, on final
nextfld:
        ld a,(nrwy)
        or a
        ret z
        ld b,a
        ld a,(curfld)
        inc a
        cp b
        jr c,nxf1
        xor a
nxf1:   ld (curfld),a
        jp resetfin

; ---- approach line of the panel (row 5)
pnappr: call rwsel
        ld de,F_RWN
        call fadr
        ld hl,s_blank12
        push de
        call ps2
        pop de
        ld a,(selok)
        or a
        jp z,pnanone
        ld hl,(selp)
        ld a,(srev)
        ld c,a
        ld a,(sax)
        call rwname
        ; centreline offset
        ld hl,(sac)
        ld a,h
        ld (ltmp),a
        bit 7,h
        call nz,neghl
        ld a,h
        or a
        jr nz,pna0
        ld a,l
        cp 3
        jr nc,pna1
        ld hl,s_cntr
        jr pna3
pna0:   ld hl,999
pna1:   ld de,F_LIN
        call fadr
        ld b,3
        call mnum
        ld hl,s_left
        ld a,(ltmp)
        bit 7,a
        jr nz,pna2
        ld hl,s_right
pna2:   call ps2
        jr pna4
pna3:   ld de,F_LIN
        call pstr
pna4:   ld a,(ongnd)
        or a
        jp nz,pnaoff
        ld hl,(srng)
        bit 7,h
        jp nz,pnaoff
        ld a,h
        or l
        jp z,pnaoff
        ld de,10000
        or a
        sbc hl,de
        add hl,de
        jp nc,pnaoff
        jp pnapapi
pnanone:
        ld hl,s_blank13
        ld de,F_LIN
        call pstr
        jp pnaoff

; ---- landed: which runway, and where on it (carry = on a runway)
tdwhere:
        call rwfind
        ret nc
        ld hl,(ral)
        ld (tddist),hl
        ld hl,(rac)
        bit 7,h
        call nz,neghl
        ld (tdoff),hl
        ld a,(rrh)
        ld (tdrh),a
        scf
        ret

s_blank12: db "            ",0
s_blank13: db "             ",0
m_on:    db "ON ",0
m_tofin: db "ON FINAL TO ",0
m_noloc: db "AREA FILE NOT FOUND ON THIS DISK - HOME FIELD ONLY.",0
