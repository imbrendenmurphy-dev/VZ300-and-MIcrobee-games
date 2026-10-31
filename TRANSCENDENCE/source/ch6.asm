;=====================================================================
; CHAPTER VI - FLIGHT
; World-locked terrain slices at increasing depth, projected with
; perspective and drawn front-to-back with a y-buffer (32 columns of
; 2 pixels). Camera accelerates, banks, climbs and dives; the land
; slowly turns into geometry.
;=====================================================================
C6_BAR  equ 94
C6_DUR  equ 2048
NROWS   equ 12

ch_flight:
        call buildconv
        xor a
        call setmode
        xor a
        call setfade
        ld a,C6_BAR
        call chbegin
.loop:  call ltime
        ld (T),hl
        ld de,C6_DUR
        or a
        sbc hl,de
        ret nc
        xor a
        call cclear
        ; depth position CZ (8.8) = t*(t+800)/64
        ld hl,(T)
        ld de,800
        add hl,de
        ld b,h
        ld c,l
        ld de,(T)
        call mul32              ; HL:DE = t*(t+800)
        ; >>6
        ld b,6
.sh:    srl h
        rr l
        rr d
        rr e
        djnz .sh
        ld (CZ),de
        ; altitude, horizon, bank, sideways drift
        ld a,(T)
        add a,a
        add a,a
        add a,64
        ld b,a
        ld a,(T+1)
        rlca
        rlca
        add a,b                 ; ~t*4/... slow
        call sin8
        sra a
        sra a
        sra a
        sra a
        add a,22
        ld (ALT),a
        ld hl,(T)
        add hl,hl
        ld a,h
        add a,l
        call sin8
        sra a
        sra a
        sra a
        sra a
        sra a
        add a,11
        ld (HORY),a
        ; bank grows with speed
        ld hl,(T)
        ld a,l
        srl h
        rr l
        ld a,l
        add a,a
        call sin8
        ld b,a
        ld a,(T+1)
        inc a
        ld e,a
        ld a,b
        call muls
        ld a,h
        sra a
        ld (BANK),a
        ld a,(T)
        call sin8
        sra a
        sra a
        add a,128
        ld (CAMXW),a
        ; profile: terrain, later geometry
        ld hl,(T)
        ld de,1300
        or a
        sbc hl,de
        ld a,MTN>>8
        jr c,.pf
        ld a,GEO>>8
.pf:    ld (PROF),a
        ; init y-buffer to 32
        ld hl,YBUF
        ld b,32
.yb:    ld (hl),32
        inc hl
        djnz .yb
        ; rows near -> far
        xor a
        ld (ROWK),a
.row:   call fdrow
        ld a,(ROWK)
        inc a
        ld (ROWK),a
        cp NROWS
        jr nz,.row
        call fsky
        ; the entity, leading the way
        ld a,(T)
        add a,a
        call sin8
        sra a
        sra a
        sra a
        sra a
        add a,32
        ld d,a
        ld a,(HORY)
        sub 6
        ld e,a
        ld a,3
        call entity
        ; fade in / out
        ld hl,(T)
        ld a,h
        or a
        jr nz,.fo
        ld a,l
        cp 64
        jr nc,.fo
        rrca
        rrca
        rrca
        rrca
        and 3
        ld b,a
        ld a,4
        sub b
        call setfade
        jr .show
.fo:    ld hl,(T)
        ld de,C6_DUR-48
        or a
        sbc hl,de
        ld a,0
        jr c,.f2
        ; dissolve into the passage: colour flashes via fade masks
        ld a,l
        rrca
        rrca
        rrca
        and 3
.f2:    call setfade
.show:  call present
        jp .loop

; one terrain row (ROWK)
fdrow:  ; d = k + 2 - frac(CZ)  (8.8) ; slice j = int(CZ) + k
        ld a,(CZ)
        neg
        ld e,a
        ld a,(ROWK)
        add a,2
        ld d,a
        ld a,e
        or a
        jr z,.nf
        dec d
.nf:    ld (DROW),de            ; 8.8 distance
        ; scale s = SCL[d>>4]
        ld a,e
        srl d
        rra
        srl d
        rra
        srl d
        rra
        srl d
        rra
        ld l,a
        ld h,0
        add hl,hl
        ld bc,SCL
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (SROW),de
        ; YT[h] for h=0..20 : y = HOR + (ALT - h)*s/256
        ld a,(ALT)
        ld e,a
        ld bc,(SROW)
        ld a,b
        call mulu               ; ALT*s_hi
        ld h,l
        ld l,0
        push hl
        ld a,c
        call mulu               ; ALT*s_lo
        pop de
        add hl,de               ; ALT*s (8.8)
        ld a,(HORY)
        add a,h
        ld h,a                  ; y(0) in 8.8
        ld ix,YT
        ld de,(SROW)
        ld b,21
.yt:    ld (ix+0),h
        inc ix
        or a
        sbc hl,de               ; y -= s (one height unit)
        djnz .yt
        ; profile offset for this slice: (int(CZ)+k)*41 + camx - 16*step
        ld a,(CZ+1)
        ld hl,ROWK
        add a,(hl)
        ld e,41
        call mulu
        ld a,(CAMXW)
        add a,l
        ld (PIDX+1),a
        xor a
        ld (PIDX),a
        ; step per column = d * 0.9 (8.8)
        ld hl,(DROW)
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        ld (PSTEP),hl
        ; start = PIDX - 16*step
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(PIDX)
        or a
        sbc hl,de
        ld (PIDX),hl
        ; colour for this row
        ld a,(ROWK)
        ld hl,ROWPAL
        add a,l
        ld l,a
        jr nc,.rp
        inc h
.rp:    ld a,(hl)
        ld (RCOL),a
        ; bank tilt accumulator: acc = -16*bank, += bank per column, tilt = acc>>9
        ld a,(BANK)
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld (BKSTEP),hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (BKACC),hl
        ; columns
        ld c,0
.col:   push bc
        ld hl,(PIDX)
        ld l,h
        ld a,(PROF)
        ld h,a
        ld a,(hl)               ; h 0..20
        ld e,a
        ld d,0
        ld hl,YT
        add hl,de
        ld a,(hl)               ; projected y (signed)
        ; bank tilt
        ld b,a
        ld hl,(BKACC)
        ld de,(BKSTEP)
        add hl,de
        ld (BKACC),hl
        ld a,h
        sra a
        add a,b
        ; clamp to -1..32
        bit 7,a
        jr z,.p
        xor a
.p:     cp 33
        jr c,.p2
        ld a,32
.p2:    ld e,a                  ; top y
        ld hl,YBUF
        ld b,0
        add hl,bc
        ld a,(hl)
        cp e
        jr c,.skip
        jr z,.skip
        ; draw from e to (ybuf-1) in column c (2 px)
        ld (hl),e
        dec a
        ld b,a
        ld a,c
        add a,a
        ld d,a
        call fvspan2
.skip:  ld hl,(PIDX)
        ld de,(PSTEP)
        add hl,de
        ld (PIDX),hl
        pop bc
        ld a,c
        and 1
        jr nz,.nt
        TICK
.nt:    inc c
        ld a,c
        cp 32
        jr nz,.col
        ret

; 2-pixel-wide vertical span: D=x (even), E=y0, B=y1, colour RCOL; top pixel brighter
fvspan2:
        ld a,b
        cp e
        ret c
        cp 32
        jr c,.ok
        ld b,31
.ok:    ld a,b
        sub e
        ret c
        inc a
        push af
        call caddr
        pop af
        ld b,a
        ld a,(RCOL)
        ld de,32
.l:     ld (hl),a
        add hl,de
        djnz .l
        ret

; stars above the horizon + a faint horizon glow line
fsky:   ld hl,SUNSTARS
        ld b,10
.s:     push bc
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl
        ld a,(T)
        srl a
        srl a
        add a,d
        and 63
        ld d,a
        ld a,e
        srl a
        ld e,a
        ld hl,HORY
        cp (hl)
        jr nc,.n
        push de
        ld e,d
        srl e
        ld d,0
        ld hl,YBUF
        add hl,de
        pop de
        ld a,e
        cp (hl)
        jr nc,.n
        ld a,5
        call pset
.n:     pop hl
        pop bc
        djnz .s
        ret

; 32-bit product: DE * BC -> HL:DE (HL = high word)
mul32:  ld hl,0
        ld a,16
.l:     add hl,hl
        rl e
        rl d
        jr nc,.n
        add hl,bc
        jr nc,.n
        inc de
.n:     dec a
        jr nz,.l
        ex de,hl
        ret

ROWPAL: db $48,$84,$44,$44,$47,$74,$77,$73,$37,$33,$30,$03
