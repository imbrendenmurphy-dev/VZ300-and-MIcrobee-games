; =====================================================================
;  FRONT END: attract sequence, tribute pages, menus, briefing, results
; =====================================================================

cls:    ld hl,vram
        ld de,vram+1
        ld bc,2047
        ld (hl),a
        ldir
        ret

jphl:   jp (hl)

; ---------------------------------------------------------------- page scripts
; 0 end | 1 addr ink text | 2 css paper (clear) | 3 dest src rows | 4 border on
; 5 tune | 6 music off | 7 rowaddr ink text (centred)
runscript:
        xor a
        ld (bordon),a
        push hl
        call setopq
        pop hl
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        cp 1
        jr nz,.n2
        call .addr
        call ptext
        jr .l
.n2:    cp 2
        jr nz,.n3
        ld a,(hl)
        inc hl
        or $08
        ld (latchv),a
        ld (latch),a
        ld a,(hl)
        inc hl
        ld (pc_pap),a
        push hl
        call cls
        pop hl
        jr .l
.n3:    cp 3
        jr nz,.n4
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
.pr:    ld bc,32
        ldir
        dec a
        jr nz,.pr
        pop hl
        jr .l
.n4:    cp 4
        jr nz,.n5
        ld a,1
        ld (bordon),a
        jr .l
.n5:    cp 5
        jr nz,.n6
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        call musplay
        pop hl
        jr .l
.n6:    cp 6
        jr nz,.n7
        call musstop
        jr .l
.n7:    call .addr
        call ptextc
        jr .l
.addr:  ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (pc_ink),a
        ret

; ---------------------------------------------------------------- colour-cycling border
bordtick:
        ld a,(bordon)
        or a
        ret z
        ld a,(ftick)
        rrca
        rrca
        and 7
        ld c,a
        ld hl,vram
        ld b,32
.t:     ld a,b
        srl a
        add a,c
        and 7
        call bpat
        ld (hl),a
        push hl
        ld de,32
        add hl,de
        ld (hl),a
        ld de,61*32
        add hl,de
        ld (hl),a
        ld de,32
        add hl,de
        ld (hl),a
        pop hl
        inc hl
        djnz .t
        ld hl,vram+2*32
        ld b,60
.s:     ld a,b
        srl a
        add a,c
        and 7
        call bpat
        ld d,a
        and $f0
        ld e,a
        ld a,(hl)
        and $0f
        or e
        ld (hl),a
        push hl
        ld a,l
        add a,31
        ld l,a
        ld a,d
        and $0f
        ld e,a
        ld a,(hl)
        and $f0
        or e
        ld (hl),a
        pop hl
        ld de,32
        add hl,de
        djnz .s
        ret

bpat:   push hl
        ld hl,btab
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        pop hl
        ret
btab:   db $ff,$dd,$55,$11,$00,$22,$aa,$ee

; ---------------------------------------------------------------- page wait
; B = seconds; ticks (tickv) every field; returns A=1 if a key was pressed
pwait:  ld l,b
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ex de,hl
        ld hl,(ftick)
        add hl,de
        ld (pgend),hl
.w:     call waitf
        call bordtick
        ld hl,(tickv)
        ld a,h
        or l
        call nz,jphl
        call kedge
        and $7f
        jr nz,.key
        ld hl,(ftick)
        ld de,(pgend)
        or a
        sbc hl,de
        jr c,.w
        xor a
        ret
.key:   ld a,1
        ret

; ---------------------------------------------------------------- attract sequence
attract:
        call keyrel
        ld hl,attab
.nx:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr nz,.s
        ld hl,(titleobj+4)
        ld de,sh_cessna
        or a
        sbc hl,de
        jr nz,.sw
        ld de,sh_heli
.sw:    ld (titleobj+4),de
        ld hl,attab
        jr .nx
.s:     ld a,(hl)
        inc hl
        ld (pgsec),a
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (atptr),hl
        ld (tickv),bc
        ld a,e
        and d
        inc a
        jr nz,.pg
        call rundemo
        jr .chk
.pg:    ex de,hl
        call runscript
        ld a,(pgsec)
        ld b,a
        call pwait
.chk:   or a
        jp nz,menu
        ld hl,(atptr)
        jr .nx

attab:  dw ps_title
        db 14
        dw ttick
        dw ps_syd
        db 10
        dw 0
        dw ps_time
        db 12
        dw 0
        dw ps_pole
        db 10
        dw 0
        dw ps_vz
        db 10
        dw 0
        dw ps_ctrl
        db 10
        dw 0
        dw ps_locs
        db 9
        dw 0
        dw $ffff
        db 0
        dw 0
        dw 0

titleobj: dw 0,0,sh_cessna
        db 0,62,6,0

; title tick: orbiting camera around the aircraft model + blinking credit line
ttick:  ld hl,(tang)
        ld de,220
        add hl,de
        ld (tang),hl
        call sin
        ex de,hl
        ld bc,70*256
        call fmul
        ld ix,px
        call st88
        ld hl,(tang)
        call cos
        ex de,hl
        ld bc,70*256
        call fmul
        ld ix,pz
        call st88
        ld hl,14*256
        ld ix,py
        call st88
        ld hl,(tang)
        ld a,h
        add a,$80
        ld h,a
        ld (cyaw),hl
        ld hl,-1600
        ld (cpitch),hl
        ld hl,0
        ld (croll),hl
        call calctrig
        call setcam
        call buildmat
        ld hl,buf
        ld a,$aa
        ld b,48
.c:     call fill32
        djnz .c
        ld ix,titleobj
        call drawobj
        ld hl,buf+13*32+1
        ld de,vram+27*32+1
        ld b,23
.cp:    push bc
        ld bc,30
        ldir
        ld bc,2
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        djnz .cp
        ; alternate credit line
        ld a,(ftick)
        and $80
        ld hl,txt_vibed
        jr z,.t
        ld hl,txt_press
.t:     push hl
        ld hl,vram+57*32+1
        ld b,5
.cl:    push bc
        push hl
        ld (hl),$aa
        ld d,h
        ld e,l
        inc de
        ld bc,29
        ldir
        pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .cl
        pop hl
        ld a,(ftick)
        and $80
        ld a,$ff
        jr z,.i
        ld a,$00
.i:     ld (pc_ink),a
        ld de,vram+57*32
        call setopq
        jp ptextc

; HL (8.8 signed) -> 16.16 at IX
st88:   ld (ix+0),0
        ld (ix+1),l
        ld (ix+2),h
        ld a,h
        add a,a
        sbc a,a
        ld (ix+3),a
        ret

txt_vibed: text "VIBED BY BPM 2026"
txt_press: text "PRESS SPACE OR FIRE"

; ---------------------------------------------------------------- demo flight
rundemo:
        call musstop
        ld a,1
        ld (demo),a
        ld hl,(loctab)
        ld (curloc),hl
        ld hl,demomis
        ld (curmis),hl
        ld hl,0
        ld (wpp),hl
        xor a
        ld (bordon),a
        call startmis
        ld hl,(ftick)
        ld de,2500
        add hl,de
        ld (demoend),hl
        call flyloop
        xor a
        ld (demo),a
        ld (engdly),a
        ld a,$08
        ld (latchv),a
        ld (latch),a
        ld a,(quitf)
        cp 2
        ld a,1
        ret z
        xor a
        ret

; ---------------------------------------------------------------- menu
getloc: ld a,(locidx)
        add a,a
        ld e,a
        ld d,0
        ld hl,loctab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        pop ix
        ret

; mission pointer for (locidx, misidx) -> HL
getmis: call getloc
        ld a,(misidx)
        add a,a
        add a,23
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

menu:   call musstop
        xor a
        ld (demo),a
        ld (engdly),a
        call keyrel
.idle:  ld hl,(ftick)
        ld de,45*50
        add hl,de
        ld (pgend),hl
.draw:  call drawmenu
.l:     call waitf
        call bordtick
        ld hl,(ftick)
        ld de,(pgend)
        or a
        sbc hl,de
        jp nc,attract
        call kedge
        or a
        jr z,.l
        ld c,a
        ld hl,(ftick)
        ld de,45*50
        add hl,de
        ld (pgend),hl
        call getloc
        ld b,(ix+22)
        ld a,c
        and $30
        jp nz,brief
        bit 0,c
        jr z,.d
        ld a,(misidx)
        or a
        jr nz,.u1
        ld a,b
.u1:    dec a
        ld (misidx),a
        call click
        jr .draw
.d:     bit 1,c
        jr z,.lf
        ld a,(misidx)
        inc a
        cp b
        jr c,.d1
        xor a
.d1:    ld (misidx),a
        call click
        jr .draw
.lf:    bit 2,c
        jr z,.rt
        ld a,(locidx)
        dec a
        and 3
        jr .lc
.rt:    bit 3,c
        jr z,.l
        ld a,(locidx)
        inc a
        and 3
.lc:    ld (locidx),a
        xor a
        ld (misidx),a
        call click
        jr .draw

click:  ld b,30
        ld c,6
        jp beep

drawmenu:
        ld a,$08
        ld (latchv),a
        ld (latch),a
        ld a,$aa
        ld (pc_pap),a
        call cls
        call setopq
        ld a,$ff
        ld (pc_ink),a
        ld hl,txt_choose
        ld de,vram+3*32
        call ptextc
        call getloc
        ld a,$55
        ld (pc_ink),a
        ld de,vram+10*32+2
        ld a,ch_lt
        call chout
        ld de,vram+10*32+29
        ld a,ch_gt
        call chout
        ld l,(ix+0)
        ld h,(ix+1)
        ld de,vram+10*32
        call ptextc
        ld a,$00
        ld (pc_ink),a
        ld l,(ix+20)
        ld h,(ix+21)
        ld de,vram+16*32
        call ptextc
        ld a,$ff
        ld (pc_ink),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,vram+22*32+1
        call ptextm
        ; mission list
        ld a,(ix+22)
        ld b,a
        ld c,0
        ld hl,vram+33*32
.ml:    push bc
        push hl
        ld (rowp),hl
        push ix
        push bc
        ld a,c
        add a,a
        add a,23
        ld e,a
        ld d,0
        add ix,de
        ld l,(ix+0)
        ld h,(ix+1)
        push hl
        pop iy
        pop bc
        pop ix
        ld a,(misidx)
        cp c
        ld a,$00
        jr nz,.m1
        ld hl,(rowp)
        ld de,2
        add hl,de
        ex de,hl
        ld a,$ff
        ld (pc_ink),a
        ld a,ch_gt
        call chout
        ld a,$55
.m1:    ld (pc_ink),a
        ld hl,(rowp)
        ld de,3
        add hl,de
        ex de,hl
        ld l,(iy+0)
        ld h,(iy+1)
        call ptext
        ; best time / free
        ld hl,(rowp)
        ld de,22
        add hl,de
        ex de,hl
        ld a,(iy+21)
        or a
        jr nz,.tm
        ld hl,txt_free
        call ptext
        jr .mn
.tm:    push de
        ld a,(iy+20)
        call bestof
        pop de
        ld a,h
        or l
        jr nz,.bt
        ld hl,txt_none
        call ptext
        jr .mn
.bt:    push bc
        call ptime
        pop bc
        inc de
        push de
        ld a,(iy+20)
        call rankof
        pop de
        call stars
.mn:    pop hl
        ld de,6*32
        add hl,de
        pop bc
        inc c
        dec b
        jp nz,.ml
        ld a,$00
        ld (pc_ink),a
        ld hl,txt_hint
        ld de,vram+57*32
        call ptextc
        ld a,1
        ld (bordon),a
        ret

; A = mission id -> HL = best seconds (0 = none)
bestof: add a,a
        ld e,a
        ld d,0
        ld hl,bestt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

rankof: ld e,a
        ld d,0
        ld hl,bestr
        add hl,de
        ld a,(hl)
        ret

; A = rank 1..4 -> print stars at DE
stars:  ld hl,txt_s3
        cp 1
        jr z,.p
        ld hl,txt_s2
        cp 2
        jr z,.p
        ld hl,txt_s1
        cp 3
        ret nz
.p:     ld a,$ff
        ld (pc_ink),a
        jp ptext

txt_choose: text "CHOOSE YOUR FLIGHT"
txt_hint:   text "Q/A FLIGHT  M/, PLACE  SPACE"
txt_free:   text " FREE"
txt_none:   text "--:--"
txt_s3:     text "***"
txt_s2:     text "**"
txt_s1:     text "*"

; ---------------------------------------------------------------- briefing
brief:  call getloc
        ld (curloc),hl
        call getmis
        ld (curmis),hl
        ld hl,(ftick)
        ld (pgend),hl
        call click
        ld a,$aa
        ld (pc_pap),a
        call cls
        call setopq
        ld iy,(curmis)
        ld a,$ff
        ld (pc_ink),a
        ld l,(iy+0)
        ld h,(iy+1)
        ld de,vram+3*32
        call ptextc
        ld a,$00
        ld (pc_ink),a
        ld hl,txt_plane
        ld a,(iy+4)
        or a
        jr z,.ac
        ld hl,txt_heli
.ac:    ld de,vram+9*32
        call ptextc
        ld a,$55
        ld (pc_ink),a
        ld l,(iy+2)
        ld h,(iy+3)
        ld de,vram+16*32+1
        call ptextm
        ld a,$00
        ld (pc_ink),a
        ld hl,txt_bhint
        ld de,vram+57*32
        call ptextc
        ld a,1
        ld (bordon),a
        call keyrel
.l:     call waitf
        call bordtick
        call kedge
        bit 5,a
        jp nz,menu
        and $10
        jr z,.l
fly:    call musstop
        xor a
        ld (bordon),a
        ld (demo),a
        call startmis
        call flyloop
        xor a
        ld (engdly),a
        ld a,(quitf)
        cp 3
        jp nz,menu

; ---------------------------------------------------------------- results
results:
        ld iy,(curmis)
        ld a,(crashes)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,(msec)
        add hl,de
        ld (score),hl
        ld e,(iy+18)
        ld d,(iy+19)
        ld b,1
        call .cmp
        jr c,.rk
        ld b,2
        push de
        ld h,d
        ld l,e
        srl h
        rr l
        add hl,de
        ex de,hl
        call .cmp
        pop de
        jr c,.rk
        ld b,3
        ex de,hl
        add hl,hl
        ex de,hl
        call .cmp
        jr c,.rk
        ld b,4
.rk:    ld a,b
        ld (rank),a
        ; best time table
        xor a
        ld (newbest),a
        ld a,(iy+20)
        add a,a
        ld e,a
        ld d,0
        ld hl,bestt
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        ld a,d
        or e
        jr z,.nb
        push hl
        ld hl,(score)
        or a
        sbc hl,de
        pop hl
        jr nc,.ob
.nb:    ld de,(score)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,1
        ld (newbest),a
        ld a,(iy+20)
        ld e,a
        ld d,0
        ld hl,bestr
        add hl,de
        ld a,(rank)
        ld (hl),a
.ob:    ; ---- page
        ld a,$08
        ld (latchv),a
        ld (latch),a
        ld a,$aa
        ld (pc_pap),a
        call cls
        call setopq
        ld a,$ff
        ld (pc_ink),a
        ld hl,txt_mcomp
        ld de,vram+4*32
        call ptextc
        ld a,$55
        ld (pc_ink),a
        ld l,(iy+0)
        ld h,(iy+1)
        ld de,vram+11*32
        call ptextc
        ld a,$00
        ld (pc_ink),a
        ld hl,txt_ftime
        ld de,vram+20*32+4
        call ptext
        ld hl,txt_crsh
        ld de,vram+26*32+4
        call ptext
        ld hl,txt_score
        ld de,vram+32*32+4
        call ptext
        ld a,$55
        ld (pc_ink),a
        ld hl,(msec)
        ld de,vram+20*32+22
        call ptime
        ld a,(crashes)
        ld l,a
        ld h,0
        ld b,2
        ld de,vram+26*32+25
        call prnum
        ld hl,(score)
        ld de,vram+32*32+22
        call ptime
        ld a,(rank)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,ranktab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,vram+39*32
        call ptextc
        ld a,(rank)
        ld hl,txt_s3
        cp 1
        jr z,.st
        ld hl,txt_s2
        cp 2
        jr z,.st
        ld hl,txt_s1
        cp 3
        jr z,.st
        ld hl,txt_keep
.st:    ld a,$ff
        ld (pc_ink),a
        ld de,vram+45*32
        call ptextc
        ld a,(newbest)
        or a
        jr z,.ob2
        ld a,$ff
        ld (pc_ink),a
        ld hl,txt_newb
        ld de,vram+51*32
        call ptextc
        jr .ob3
.ob2:   ld a,$00
        ld (pc_ink),a
        ld hl,txt_bestis
        ld de,vram+51*32+7
        call ptext
        ld a,$55
        ld (pc_ink),a
        ld a,(iy+20)
        call bestof
        ld de,vram+51*32+19
        call ptime
.ob3:   ld a,$00
        ld (pc_ink),a
        ld hl,txt_cont
        ld de,vram+57*32
        call ptextc
        ld a,1
        ld (bordon),a
        call keyrel
.w:     call waitf
        call bordtick
        call kedge
        and $30
        jr z,.w
        jp menu
; carry set if score <= DE
.cmp:   ld hl,(score)
        or a
        sbc hl,de
        ret c
        ld a,h
        or l
        scf
        ret z
        or a
        ret

ranktab: dw txt_r1,txt_r2,txt_r3,txt_r4
txt_r1:  text "RATING: ACE AVIATOR"
txt_r2:  text "RATING: CAPTAIN"
txt_r3:  text "RATING: FIRST OFFICER"
txt_r4:  text "RATING: STUDENT PILOT"
txt_keep: text "KEEP PRACTISING!"
txt_mcomp: text "MISSION COMPLETE!"
txt_ftime: text "FLIGHT TIME"
txt_crsh:  text "CRASHES (+15 S)"
txt_score: text "SCORE"
txt_newb:  text "NEW BEST SCORE!"
txt_bestis: text "BEST"
txt_cont:  text "PRESS SPACE"
txt_plane: text "AIRCRAFT: LIGHT PLANE"
txt_heli:  text "AIRCRAFT: HELICOPTER"
txt_bhint: text "SPACE TO FLY   RETURN BACK"
