;=====================================================================
; Shared chunky-screen graphics helpers
;=====================================================================

; A signed * E unsigned -> HL signed
mulsu:  bit 7,a
        jp z,mulu
        neg
        call mulu
negHL:  ld a,h
        cpl
        ld h,a
        ld a,l
        cpl
        ld l,a
        inc hl
        ret

; hspan: E=y, D=x0, B=x1 (inclusive, clipped 0-63), C=colour
hspan:  ld a,e
        cp 32
        ret nc
        ld a,d
        bit 7,a
        jr z,.x0
        ld d,0
.x0:    ld a,b
        bit 7,a
        ret nz
        cp 64
        jr c,.x1
        ld b,63
.x1:    ld a,d
        cp 64
        ret nc
        cp b
        jr z,.go
        ret nc
.go:    push bc
        call caddr              ; HL
        pop bc
        ld a,c
        rlca
        rlca
        rlca
        rlca
        or c
        ld (.full+1),a          ; colour pair
        ; leading odd pixel
        bit 0,d
        jr z,.ev
        ld a,(hl)
        and $F0
        or c
        ld (hl),a
        inc hl
        inc d
        ld a,b
        cp d
        ret c
.ev:    ; number of full pairs = (b - d + 1) >> 1
        ld a,b
        sub d
        inc a
        ld e,a                  ; pixel count
        srl a
        jr z,.tail
        push bc
        ld b,a
.full:  ld a,0
.fl:    ld (hl),a
        inc hl
        djnz .fl
        pop bc
.tail:  bit 0,e
        ret z
        ld a,c
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(hl)
        and $0F
        or c
        ld (hl),a
        ret

; vspan: D=x, E=y0, B=y1 inclusive (clipped), C=colour
vspan:  ld a,d
        cp 64
        ret nc
        ld a,e
        bit 7,a
        jr z,.y0
        ld e,0
.y0:    ld a,b
        bit 7,a
        ret nz
        cp 32
        jr c,.y1
        ld b,31
.y1:    ld a,e
        cp 32
        ret nc
        ld a,b
        sub e
        ret c
        inc a
        push af
        call caddr
        pop af
        ld b,a
        bit 0,d
        jr nz,.odd
        ld a,c
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld de,32
.le:    ld a,(hl)
        and $0F
        or c
        ld (hl),a
        add hl,de
        djnz .le
        ret
.odd:   ld de,32
.lo:    ld a,(hl)
        and $F0
        or c
        ld (hl),a
        add hl,de
        djnz .lo
        ret

; filled disc: D=cx E=cy (signed bytes ok), B=radius, C=colour
; uses CIRCW table: half-width for row dy at radius r: CIRCW[r*(r+1)/2+dy]
disc:   ld a,b
        or a
        jr nz,.r
        jp pset2
.r:     ld (.cx+1),a            ; temp hold radius
        ld a,d
        ld (DCX),a
        ld a,e
        ld (DCY),a
        ld a,b
        ld (DR),a
        ld a,c
        ld (DCOL),a
        ; table base for r
        ld l,b
        ld h,0
        ld e,b
        ld d,0
        inc e
        call mul16x8s           ; HL = r*(r+1)
        srl h
        rr l
        ld de,CIRCW
        add hl,de
        ld (DTB),hl
        ld a,(DR)
        neg
        ld (DDY),a              ; dy from -r..r
.lp:    ld a,(DDY)
        bit 7,a
        jr z,.p
        neg
.p:     ld e,a
        ld d,0
        ld hl,(DTB)
        add hl,de
        ld a,(hl)               ; half width (in pixels, aspect-corrected)
        ld b,a
        ld a,(DCX)
        sub b
        jr nc,.a0
        xor a
.a0:    ld d,a
        ld a,(DCX)
        add a,b
        jr c,.a1
        cp 64
        jr c,.a2
.a1:    ld a,63
.a2:    ld b,a
        ld a,(DCY)
        ld hl,DDY
        add a,(hl)
        ld e,a
        ld a,(DCOL)
        ld c,a
        call hspan
.sk:    TICK
        ld a,(DDY)
        inc a
        ld (DDY),a
        ld hl,DR
        dec a
        cp (hl)
        jr nz,.lp
.cx:    ret

pset2:  ld a,c
        jp pset

; HL = L * E (8x8 unsigned, small) - simple loop multiply
mul16x8s:
        ld a,e
        ld e,l
        ld d,0
        ld hl,0
        or a
        ret z
.m:     add hl,de
        dec a
        jr nz,.m
        ret

;---------------------------------------------------------------------
; THE ENTITY: luminous electrical star. D=x E=y (chunky), A=size 0-3
; glow follows the motif channel duty (DUTY2) and random flicker.
entity: ld (ENTSZ),a
        ld a,d
        ld (ENTX),a
        ld a,e
        ld (ENTY),a
        ld a,(ENTSZ)
        or a
        jr nz,.big
        ; tiny point: flickers between buff and blue
        call rnd
        and 3
        ret z
        ld a,5
        jp pset
.big:   ; glow ring radius from music
        ld a,(DUTY2)
        rrca
        rrca
        rrca
        rrca
        rrca
        and 3
        ld b,a
        ld a,(ENTSZ)
        add a,b
        cp 5
        jr c,.g
        ld a,4
.g:     ld (ENTG),a
        ; random glow pixels around centre
        ld a,(ENTSZ)
        add a,a
        add a,a
        add a,4
        ld b,a
.gl:    push bc
        call rnd
        ld c,a
        and 7
        ld hl,ENTG
        cp (hl)
        jr c,.ok
        jr z,.ok
        sub (hl)
.ok:    ld b,a                  ; distance
        ld a,c
        rlca
        rlca
        rlca
        and 7                   ; direction
        call dirstep            ; D,E = offset*dist
        ld a,(ENTX)
        add a,d
        ld d,a
        ld a,(ENTY)
        add a,e
        ld e,a
        call rnd
        and 3
        ld hl,GLOWCOL
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,(hl)
        call pset
        TICK
        pop bc
        djnz .gl
        ; core
        ld a,(ENTX)
        ld d,a
        ld a,(ENTY)
        ld e,a
        ld a,5
        call pset
        inc d
        call pset
        ld a,(ENTSZ)
        cp 2
        jr c,.sp
        inc e
        ld a,5
        call pset
        dec d
        call pset
.sp:    ; spark: occasional electrical filament
        call rnd
        cp 70
        ret nc
        ld a,(ENTSZ)
        add a,3
        ld b,a
        call rnd
        and 7
        ld (ENTDIR),a
        ld a,(ENTX)
        ld (ENTSX),a
        ld a,(ENTY)
        ld (ENTSY),a
.spl:   push bc
        ld a,(ENTDIR)
        ld b,1
        call dirstep
        call rnd
        and 3
        jr nz,.st
        ; jag
        ld a,(ENTDIR)
        inc a
        and 7
        ld (ENTDIR),a
.st:    ld a,(ENTSX)
        add a,d
        ld (ENTSX),a
        ld d,a
        ld a,(ENTSY)
        add a,e
        ld (ENTSY),a
        ld e,a
        ld a,6
        call pset
        TICK
        pop bc
        djnz .spl
        TICK
        ret

; A = direction 0-7, B = distance -> D=dx, E=dy
dirstep:
        add a,a
        ld hl,DIRS
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld d,0
        ld e,0
        ld a,b
        or a
        ret z
.l:     ld a,d
        add a,(hl)
        ld d,a
        inc hl
        ld a,e
        add a,(hl)
        ld e,a
        dec hl
        djnz .l
        ret

DIRS:   db 1,0, 1,1, 0,1, -1,1, -1,0, -1,-1, 0,-1, 1,-1
GLOWCOL: db 2,8,2,6
