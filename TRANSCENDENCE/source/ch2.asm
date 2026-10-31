;=====================================================================
; CHAPTER II - THE SEARCH
; Night. A world that exists only where the entity's light touches it.
;=====================================================================
C2_BAR  equ 24
C2_DUR  equ 2560

ch_search:
        xor a
        call setfade
        ld a,C2_BAR
        call chbegin
.loop:  call ltime
        ld (T),hl
        ld de,C2_DUR
        or a
        sbc hl,de
        ret nc
        xor a
        call cclear
        ; camera: camx = min(t,2150)*3/32 (8-bit world wraps)
        ld hl,(T)
        ld de,2150
        or a
        sbc hl,de
        ld hl,(T)
        jr c,.cm
        ld hl,2150
.cm:
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld a,l
        srl h
        rra
        srl h
        rra
        srl h
        rra
        srl h
        rra
        srl h
        rra
        ld (CAMX),a
        ; entity in screen space
        ld a,(T)
        rrca
        and $7F
        ld b,a
        ld a,(T+1)
        rrca
        and $80
        or b                    ; t/2 low byte
        call sin8
        sra a
        sra a
        sra a
        add a,32
        ld (EX),a
        ld a,(T)
        ld b,a
        ld a,(T+1)
        rra
        ld a,b
        rra
        ld b,a
        srl a
        add a,b                 ; ~t*0.75/2
        call sin8
        sra a
        sra a
        sra a
        sra a
        add a,12
        ld (EY),a
        ; the ending: descend to the figure (t >= 2150)
        ld hl,(T)
        ld de,2150
        or a
        sbc hl,de
        jr c,.noend
        ; k = (t-2150)/8 (0..51) clamp 40
        ld a,l
        srl h
        rra
        srl h
        rra
        srl h
        rra
        cp 40
        jr c,.k
        ld a,40
.k:     ld (KEND),a
        ; EX -> 40, EY -> 19 linearly
        ld b,a
        ld a,(EX)
        ld c,40
        call lerp8
        ld (EX),a
        ld a,(KEND)
        ld b,a
        ld a,(EY)
        ld c,19
        call lerp8
        ld (EY),a
.noend:
        call heights            ; HF[], HN[]
        call nstars
        call lightpool
        call monuments
        call lake
        call dlights
        ; the human, revealed at the end
        ld hl,(T)
        ld de,1900
        or a
        sbc hl,de
        call nc,figure
        ld a,(EX)
        ld d,a
        ld a,(EY)
        ld e,a
        ld a,3
        call entity
        ; fade in at start, out at the very end
        ld hl,(T)
        ld a,h
        or a
        jr nz,.fo
        ld a,l
        cp 80
        jr nc,.fo
        rrca
        rrca
        rrca
        rrca
        and 7
        ld b,a
        ld a,4
        sub b
        jr nc,.fs
        xor a
.fs:    call setfade
        jr .show
.fo:    ld hl,(T)
        ld de,C2_DUR-70
        or a
        sbc hl,de
        ld a,0
        jr c,.fs2
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 7
        cp 4
        jr c,.fs2
        ld a,4
.fs2:   call setfade
.show:  call present
        jp .loop

; A = a, C = target, B = k (0..40): a + (c-a)*k/40
lerp8:  ld d,a
        ld a,c
        sub d
        push de
        ld e,b
        call muls               ; HL = (c-a)*k signed
        ; divide by 40 ~ *205 >> 13 ; use /32 + /128 approx (=/25.6..) -> use exact-ish: *51>>11
        ld a,h
        ld c,l
        ; HL signed / 40: shift by 3 then /5 via table-free: multiply by 51, >> 8
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l                    ; /8
        ld a,l
        ld e,51
        call muls               ; *51
        ld a,h                  ; /256 -> total /40.2
        pop de
        add a,d
        ret

; terrain heights for the visible 64 columns
heights:
        ld b,0
        ld ix,HN
.l:     ld a,(CAMX)
        add a,b
        ld c,a                  ; world x
        ; near ground: 21 + mtn/5, lake flat 120..169
        cp 120
        jr c,.g
        cp 170
        jr nc,.g
        ld a,24
        jr .s
.g:     ld l,c
        ld h,MTN>>8
        ld a,(hl)
        srl a
        srl a
        ld d,a
        ld a,25
        sub d
.s:     ld (ix+0),a
        ; far hills (parallax 1/2)
        ld a,(CAMX)
        srl a
        add a,b
        add a,70
        ld l,a
        ld h,MTN>>8
        ld a,(hl)
        srl a
        ld d,a
        ld a,20
        sub d
        ld (ix+64),a
        inc ix
        inc b
        ld a,b
        and 7
        call z,snd
        ld a,b
        cp 64
        jr nz,.l
        TICK
        ret

; stars above the far hills, slow parallax, twinkling
nstars: ld hl,NSTARP
        ld b,28
.l:     push bc
        ld a,(CAMX)
        srl a
        srl a
        ld c,a
        ld a,(hl)
        sub c
        and 63
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        push hl
        ; hidden behind far hills?
        ld l,d
        ld h,0
        ld bc,HF
        add hl,bc
        ld a,e
        cp (hl)
        jr nc,.n
        call rnd
        and 15
        jr z,.n
        ld a,e
        and 3
        ld a,5
        jr nz,.c
        ld a,3
.c:     call pset
.n:     pop hl
        TICK
        pop bc
        djnz .l
        ret

; the entity's light on the ground and ridges
lightpool:
        ld a,(EX)
        sub 12
        ld (LPX),a
        ld b,25
.col:   push bc
        ld a,(LPX)
        cp 64
        jp nc,.nc
        ld d,a
        ld l,a
        ld h,0
        ld bc,HN
        add hl,bc
        ld e,(hl)               ; ground top
        ; dx^2
        ld a,(EX)
        sub d
        jr nc,.p
        neg
.p:     add a,a
        ld l,a
        ld h,SQL>>8
        ld a,(hl)
        inc h
        inc h
        ld h,(hl)
        ld l,a                  ; dx^2
        ld (DX2),hl
        ; ridge line (blue) within range
        ld a,1
        ld (FIRST),a
        ; rows from ground top to EY+9
.row:   ld a,(EY)
        add a,9
        cp e
        jr c,.nc
        ld a,e
        cp 32
        jr nc,.nc
        ; dy = y-EY ; d2 = dx2 + 2.25*dy^2
        ld a,(EY)
        sub e
        jr nc,.q
        neg
.q:     add a,a
        ld l,a
        ld h,SQL>>8
        ld c,(hl)
        inc h
        inc h
        ld b,(hl)               ; dy^2
        ld h,b
        ld l,c
        add hl,hl               ; 2dy^2
        srl b
        rr c
        srl b
        rr c
        add hl,bc               ; 2.25 dy^2
        ld bc,(DX2)
        add hl,bc
        ld a,h
        or a
        jr nz,.far
        ld a,l
        cp 14
        ld c,6
        jr c,.plot
        cp 40
        jr nc,.m2
        ld a,d
        xor e
        rra
        ld c,3
        jr c,.plot
        ld c,6
        jr .plot
.m2:    cp 90
        jr nc,.m3
        ld c,3
        ld a,d
        xor e
        rra
        jr nc,.plot
        jr .skip
.m3:    cp 170
        jr nc,.far
        ld a,d
        and e
        rra
        jr nc,.skip
        ld c,3
        jr .plot
.far:   ld a,(FIRST)
        or a
        jr z,.skip
        ; ridge-top glint if within 20 columns
        ld hl,(DX2)
        ld a,h
        or a
        jr nz,.skip
        ld a,l
        cp 200
        jr nc,.skip
        ld c,3
.plot:  ld a,c
        call pset
.skip:  xor a
        ld (FIRST),a
        inc e
        jp .row
.nc:    TICK
        ld hl,LPX
        inc (hl)
        pop bc
        dec b
        jp nz,.col
        ret

; standing stones: black silhouettes, lit when the entity is close
monuments:
        ld hl,MONS
.l:     ld a,(hl)
        cp $FF
        ret z
        ld c,a
        inc hl
        ld b,(hl)               ; height
        inc hl
        push hl
        ld a,(CAMX)
        ld d,a
        ld a,c
        sub d                   ; screen x
        cp 64
        jr nc,.n
        ld d,a
        ; base y = HN[x]
        push bc
        ld l,a
        ld h,0
        ld bc,HN
        add hl,bc
        ld a,(hl)
        pop bc
        ld (MBASE),a
        sub b
        ld e,a                  ; top
        ; colour by distance to entity
        ld a,(EX)
        sub d
        jr nc,.p
        neg
.p:     ld c,0
        cp 4
        jr nc,.p2
        ld c,5
        jr .dr
.p2:    cp 9
        jr nc,.p3
        ld c,2
        jr .dr
.p3:    cp 14
        jr nc,.dr
        ld c,3
.dr:    ld a,(MBASE)
        ld b,a
        push de
        push bc
        call vspan
        TICK
        pop bc
        pop de
        inc d
        inc e
        ld a,(MBASE)
        ld b,a
        ld a,c
        cp 5
        jr nz,.d2
        ld c,2
.d2:    call vspan
        TICK
.n:     pop hl
        jr .l

; the lake mirrors stars and the entity
lake:   ld b,0
.l:     ld a,(CAMX)
        add a,b
        cp 120
        jr c,.n
        cp 170
        jr nc,.n
        ; ripple glints
        call rnd
        and 31
        jr nz,.n
        push bc
        ld d,b
        call rnd
        and 3
        add a,25
        ld e,a
        ld a,3
        call pset
        pop bc
.n:     inc b
        ld a,b
        and 7
        call z,snd
        ld a,b
        cp 64
        jr nz,.l
        TICK
        ; entity reflection when over the lake
        ld a,(CAMX)
        ld b,a
        ld a,(EX)
        add a,b
        cp 122
        ret c
        cp 168
        ret nc
        ld a,(EY)
        ld b,a
        ld a,48
        sub b
        cp 32
        ret nc
        ld e,a
        call rnd
        and 1
        ld b,a
        ld a,(EX)
        add a,b
        ld d,a
        ld a,6
        call pset
        inc d
        ld a,3
        call pset
        dec d
        dec d
        jp pset

; distant lights blinking on the far ridge
dlights:
        ld hl,DLIT
        ld b,3
.l:     push bc
        ld a,(CAMX)
        srl a
        ld c,a
        ld a,(hl)
        sub c
        and 63
        ld d,a
        inc hl
        push hl
        ld l,d
        ld h,0
        ld bc,HF
        add hl,bc
        ld a,(hl)
        dec a
        ld e,a
        ld a,(T)
        add a,d
        and 63
        cp 40
        jr nc,.n
        ld a,7
        call pset
.n:     pop hl
        pop bc
        djnz .l
        ret

; the resting human, discovered (lying on the ground near x=40)
figure: ld a,(CAMX)
        ld b,a
        ld a,235
        sub b
        cp 60
        ret nc
        ld (FIGX),a
        ld l,a
        ld h,0
        ld bc,HN+4
        add hl,bc
        ld a,(hl)
        sub 2
        ld (FIGY),a
        ld a,(KEND)
        ld b,a                  ; brightness grows
        ld hl,FIGP
.l:     ld a,(hl)
        cp $FF
        ret z
        ld c,a
        ld a,(FIGX)
        add a,c
        ld d,a
        inc hl
        ld a,(FIGY)
        add a,(hl)
        ld e,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,b
        cp 24
        jr nc,.br
        ld c,3
        cp 6
        jr nc,.br
        ld c,0
.br:    ld a,c
        call pset
        jr .l

MONS:   db 58,9, 62,6, 96,13, 101,5, 178,8, 184,12, 190,8, 214,10, $FF
NSTARP: db 3,2, 11,6, 19,1, 27,9, 33,4, 41,11, 49,3, 57,7, 63,12, 7,13, 15,10
        db 23,5, 37,8, 45,1, 53,14, 61,5, 29,13, 1,9, 17,15, 43,6, 51,10, 59,2
        db 9,4, 25,11, 35,1, 47,13, 55,8, 21,7
DLIT:   db 13, 39, 52
; figure pixels: dx, dy, colour  (head at left)
FIGP:   db 0,0,5, 1,0,5, 2,1,2, 3,1,2, 4,1,2, 5,1,2, 6,1,2, 7,1,2, 8,1,5, 9,1,5
        db 3,0,2, 5,0,2, $FF
