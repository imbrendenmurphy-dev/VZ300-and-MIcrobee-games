;=====================================================================
; CHAPTER I - THE ARRIVAL
; darkness -> a point of light -> the entity -> drifting through stars
; -> a planet rises -> descent into a vast alien sunset
;=====================================================================
C1_DUR  equ 3072

ch_arrival:
        xor a
        call setmode
        xor a
        call chbegin
        call initstars
.loop:  call ltime
        ld (T),hl
        ld de,C1_DUR
        or a
        sbc hl,de
        ret nc
        xor a
        call cclear
        ld hl,(T)
        ld de,200
        or a
        sbc hl,de
        jp c,.show              ; pure darkness
        ld hl,(T)
        ld de,2200
        or a
        sbc hl,de
        jp nc,.sunset
        ; --- space part ---
        ; star speed: 0 before 500, ramps to 3, eases to 1 for the planet
        ld hl,(T)
        ld de,500
        or a
        sbc hl,de
        jr c,.nostars
        ld a,h
        or a
        ld a,3
        jr nz,.sp1
        ld a,l
        rrca
        rrca
        rrca
        rrca
        rrca
        rrca
        and 3
.sp1:   ld hl,(T)
        ld de,1500
        or a
        sbc hl,de
        jr c,.sp2
        ld a,1
.sp2:   ld (SSPD),a
        ; floating camera centre
        ld a,(T)
        call sin8
        sra a
        sra a
        sra a
        sra a
        add a,32
        ld (SCX),a
        ld a,(T)
        add a,a
        add a,40
        call sin8
        sra a
        sra a
        sra a
        sra a
        sra a
        add a,16
        ld (SCY),a
        call drawstars
.nostars:
        ; planet after 1500
        ld hl,(T)
        ld de,1500
        or a
        sbc hl,de
        jr c,.noplan
        call planet
.noplan:
        ; entity: grows 200..650 then floats
        ld hl,(T)
        ld de,200
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.full
        ld a,l
        cp 150
        ld b,0
        jr c,.esz
        inc b
        cp 230
        jr c,.esz
        inc b
        jr .esz
.full:  ld b,3
        ld hl,(T)
        ld de,450
        or a
        sbc hl,de
        jr nc,.esz
        ld b,2
.esz:   push bc
        ; position: centre, then a slow lissajous drift once stars move
        ld a,(T)
        add a,a
        call sin8
        sra a
        sra a
        sra a
        ld d,a
        ld hl,(T)
        ld a,h
        or a
        jr nz,.dr
        ld a,l
        cp 250
        jr nc,.dr
        ld d,0
.dr:    ld a,32
        add a,d
        ld d,a
        ld a,(T)
        ld b,a
        add a,a
        add a,b
        call sin8
        sra a
        sra a
        sra a
        sra a
        ld hl,(T)
        ld e,a
        ld a,h
        or a
        jr nz,.dr2
        ld e,0
.dr2:   ld a,15
        add a,e
        ld e,a
        pop bc
        ld a,b
        call entity
        ; fades around the space -> sunset cut
        ld hl,(T)
        ld de,2140
        or a
        sbc hl,de
        jr c,.show
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 7
        cp 4
        jr c,.fd
        ld a,4
.fd:    call setfade
        jr .show
.sunset:
        call sunset
.show:  call present
        jp .loop

;---------------------------------------------------------------------
; A = fade level 0 (full) .. 4 (black)
setfade:
        add a,a
        ld hl,FADETAB
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ld (FADEA),a
        inc hl
        ld a,(hl)
        ld (FADEB),a
        ret
FADETAB: db $FF,$FF, $FE,$F7, $F9,$F6, $F8,$F1, $F0,$F0

;---------------------------------------------------------------------
NSTARS  equ 36
initstars:
        ld hl,STARS
        ld b,NSTARS
.l:     call rnd
        ld (hl),a
        inc hl
        call rnd
        sra a
        ld (hl),a
        inc hl
        call rnd
        or 16
        ld (hl),a
        inc hl
        djnz .l
        ret

drawstars:
        ld ix,STARS
        ld b,NSTARS
.l:     push bc
        ld a,(SSPD)
        ld c,a
        ld a,(ix+2)
        sub c
        jr c,.resp
        cp 14
        jr nc,.ok
.resp:  call rnd
        ld (ix+0),a
        call rnd
        sra a
        ld (ix+1),a
        ld a,255
.ok:    ld (ix+2),a
        ; RT[z]
        ld l,a
        ld h,RTAB>>8
        ld e,(hl)
        push de
        ld a,(ix+0)
        call mulsu
        ld a,(SCX)
        add a,h
        ld d,a
        pop bc
        push de
        ld e,c
        ld a,(ix+1)
        call mulsu
        ld a,(SCY)
        add a,h
        pop de
        ld e,a
        ; colour by depth
        ld a,(ix+2)
        cp 170
        ld a,3
        jr nc,.c
        ld a,(ix+2)
        cp 80
        ld a,6
        jr nc,.c
        ld a,5
.c:     call pset
        TICK
        ld bc,3
        add ix,bc
        pop bc
        djnz .l
        ret

;---------------------------------------------------------------------
; Planet rising: p = T-1500 (0..700)
planet: ld hl,(T)
        ld de,1500
        or a
        sbc hl,de
        ; r = 8 + p/24
        push hl
        ld a,l
        ld b,h
        ld c,24
        call div16_8            ; A = HL/24
        add a,8
        ld (PR),a
        pop hl
        ; cy = 58 - p/18
        ld c,18
        call div16_8
        ld b,a
        ld a,58
        sub b
        ld (PCY),a
        ld a,38
        ld (PCX),a
        ; rows
        ld a,(PR)
        ld b,a
        ld l,a
        ld h,0
        ld e,a
        inc e
        call mul16x8s
        srl h
        rr l
        ld de,CIRCW
        add hl,de
        ld (DTB),hl
        ld a,(PR)
        neg
        ld (DDY),a
.row:   ld a,(PCY)
        ld hl,DDY
        add a,(hl)
        ld (PY),a
        cp 32
        jp nc,.next
        ld a,(DDY)
        bit 7,a
        jr z,.p
        neg
.p:     ld e,a
        ld d,0
        ld hl,(DTB)
        add hl,de
        ld a,(hl)
        ld (PW),a
        ; segments by fraction of 2w (lit from upper right)
        ; boundaries k/16 of width from left edge: dark..
        ld ix,PBANDS
.seg:   ld a,(ix+0)
        cp $FF
        jr z,.next
        ; x0 = cx - w + (2w*f0)>>4 ; x1 = cx - w + (2w*f1)>>4 - 1
        ld a,(PW)
        add a,a
        ld e,a
        ld a,(ix+0)
        ; row dither: shift by row parity
        ld hl,PY
        bit 0,(hl)
        jr z,.nd
        or a
        jr z,.nd
        dec a
.nd:    call mulu
        call shr4
        ld b,a
        ld a,(PCX)
        ld hl,PW
        sub (hl)
        jr nc,.k0
        xor a
.k0:    add a,b
        ld d,a
        push de
        TICK
        ld a,(PW)
        add a,a
        ld e,a
        ld a,(ix+1)
        call mulu
        call shr4
        ld b,a
        ld a,(PCX)
        ld hl,PW
        sub (hl)
        jr nc,.k1
        xor a
.k1:    add a,b
        cp 64
        jr c,.k2
        ld a,63
.k2:    ld b,a
        pop de
        ld a,(PY)
        ld e,a
        ld c,(ix+2)
        call hspan
        TICK
        inc ix
        inc ix
        inc ix
        jr .seg
.next:  ld a,(DDY)
        inc a
        ld (DDY),a
        dec a
        ld hl,PR
        cp (hl)
        jp nz,.row
        ret
; band: from,to (in 16ths), colour
PBANDS: db 0,9,0, 9,11,3, 11,14,4, 14,15,8, 15,16,6, $FF

shr4:   ld a,l
        srl h
        rra
        srl h
        rra
        srl h
        rra
        srl h
        rra
        ret

; A = HL / C (unsigned, result < 256)
div16_8:
        ld b,8
        ld a,h
        ld d,0
        ; simple restoring division of HL by C -> L quotient
        ld b,16
        xor a
.d:     add hl,hl
        rla
        cp c
        jr c,.s
        sub c
        inc l
.s:     djnz .d
        ld a,l
        ret

;---------------------------------------------------------------------
; Alien sunset. q = T-2200 (0..871)
sunset: ld hl,(T)
        ld de,2200
        or a
        sbc hl,de
        ld (Q),hl
        ; horizon rises 27 -> 21 over first 300 frames (descent)
        ld c,50
        call div16_8
        cp 6
        jr c,.h
        ld a,6
.h:     ld b,a
        ld a,27
        sub b
        ld (HOR),a
        ; sky offset darkens: q/48 rows
        ld hl,(Q)
        ld c,72
        call div16_8
        ld (SKO),a
        ; sky rows
        ld b,0
.sk:    push bc
        ld a,(HOR)
        cp b
        jr z,.skd
        jr c,.skd
        ; gradient index = (HOR - y) ... colour from horizon upward
        sub b                   ; distance above horizon (1..)
        dec a
        ld hl,SKO
        add a,(hl)              ; darken with time
        cp 31
        jr c,.g
        ld a,31
.g:     ld hl,SKYGRAD
        add a,l
        ld l,a
        jr nc,.g2
        inc h
.g2:    ld a,(hl)               ; pair byte (two colours)
        bit 0,b
        jr z,.g3
        rlca
        rlca
        rlca
        rlca
.g3:    ld e,b
        call hrowfill
        pop bc
        inc b
        jr .sk
.skd:   pop bc
        ; stars appear in the darkening sky
        ld a,(SKO)
        cp 8
        jr c,.nost
        ld b,10
        ld hl,SUNSTARS
.ss:    push bc
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl
        ld a,(HOR)
        sub 5
        cp e
        jr c,.ssn
        ld a,(Q)
        add a,d
        and 7
        jr z,.ssn
        ld a,5
        call pset
.ssn:   pop hl
        pop bc
        djnz .ss
.nost:  ; sun: sinks from HOR-7 to HOR+9
        ld hl,(Q)
        ld c,54
        call div16_8
        ld b,a
        ld a,(HOR)
        sub 7
        add a,b
        ld (SUNY),a
        ld d,36
        ld e,a
        ld b,9
        ld c,8
        call disc
        ld a,(SUNY)
        ld e,a
        ld d,36
        ld b,6
        ld c,2
        call disc
        ; retro stripes through the lower sun (show sky colour as dark)
        ld a,(SUNY)
        inc a
        ld e,a
        ld b,4
.st:    push bc
        push de
        ld d,20
        ld b,52
        ld c,4
        ld a,e
        ld hl,HOR
        cp (hl)
        jr nc,.stx
        call hspan
.stx:   pop de
        pop bc
        inc e
        inc e
        inc e
        djnz .st
        ; far mountains (dark blue), then near silhouette (black)
        ld hl,(Q)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        ld (SCR1),a
        ld hl,(Q)
        srl h
        rr l
        ld a,l
        ld (SCR2),a
        ld d,0
.mf:    push de
        ld a,(SCR1)
        add a,d
        ld l,a
        ld h,MTN>>8
        ld a,(hl)
        srl a
        srl a
        ld b,a
        ld a,(HOR)
        sub b
        ld e,a
        ld a,(HOR)
        ld b,a
        ld c,3
        call vspan
        TICK
        ; near layer
        pop de
        push de
        ld a,(SCR2)
        add a,d
        add a,d
        add a,90
        ld l,a
        ld h,MTN>>8
        ld a,(hl)
        srl a
        srl a
        srl a
        ld b,a
        ld a,(HOR)
        add a,2
        sub b
        ld e,a
        ld b,31
        ld c,0
        call vspan
        TICK
        pop de
        inc d
        ld a,d
        cp 64
        jr nz,.mf
        ; ground below horizon stays black. Entity hovers, leading on.
        ld a,(Q)
        call sin8
        sra a
        sra a
        sra a
        sra a
        add a,14
        ld d,a
        ld a,(Q)
        add a,a
        call sin8
        sra a
        sra a
        sra a
        sra a
        sra a
        ld b,a
        ld a,(HOR)
        sub 11
        add a,b
        ld e,a
        ld a,3
        call entity
        ; fade at the end of the chapter into night
        ld hl,(Q)
        ld de,800
        or a
        sbc hl,de
        jr c,.f0
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 7
        cp 4
        jr c,.f1
        ld a,4
.f1:    call setfade
        ret
.f0:    ld hl,(Q)
        ld a,h
        or a
        ld a,0
        jr nz,.f2
        ld a,l
        cp 64
        ld a,0
        jr nc,.f2
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 3
        ld b,a
        ld a,4
        sub b
.f2:    jp setfade

; fill chunky row E with pair byte A (32 bytes)
hrowfill:
        push af
        ld d,0
        call caddr
        pop af
        ld b,16
.l:     ld (hl),a
        inc l
        ld (hl),a
        inc l
        djnz .l
        TICK
        ret

; sky gradient (pair bytes), index 0 = just above horizon
SKYGRAD:
        db $22,$28,$88,$88,$84,$48,$44,$44,$47,$74,$77,$77,$73,$37,$33,$33
        db $30,$03,$30,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
SUNSTARS:
        db 5,2, 17,4, 29,1, 44,3, 58,6, 9,8, 51,9, 23,10, 38,7, 62,12
