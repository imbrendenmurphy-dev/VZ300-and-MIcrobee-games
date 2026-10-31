;=====================================================================
; CHAPTER VII - THE PASSAGE
; A living tunnel rendered per semigraphic cell from angle/depth tables
; (48x24, so the vanishing point can wander). Per-frame tables shape
; it: MODT (breathing / star lobes), TWT (twist), CMAP (colour bands,
; cycling) and PATS (cell patterns, solid when it dissolves to colour).
;=====================================================================
C7_BAR  equ 110
C7_DUR  equ 2560
MODT    equ $F900           ; 256  (free RAM above arrays)
TWT     equ $FA00           ; 256

ch_passage:
        xor a
        call setmode
        xor a
        call setfade
        ld a,C7_BAR
        call chbegin
.loop:  call ltime
        ld (T),hl
        ld de,C7_DUR
        or a
        sbc hl,de
        ret nc
        call tparams
        call tbuild
        call trender
        call tentity
        call pcopy
        jp .loop

;---------------------------------------------------------------------
; per-frame parameters from the timeline
tparams:
        ; phase index = t / 256 (0..9)
        ld a,(T+1)
        ld (TPH),a
        ; rotation: accumulates faster later
        ld hl,(T)
        ld a,l
        srl h
        rr l
        add a,l                 ; t*1.5 low
        ld b,a
        ld a,(TPH)
        cp 4
        jr c,.r1
        ld a,b
        add a,b
        ld b,a
.r1:    ld a,b
        ld (TROT),a
        ; z position (speed grows with phase)
        ld hl,(T)
        ld a,(TPH)
        cp 6
        jr c,.z1
        add hl,hl
.z1:    add hl,hl
        add hl,hl
        ld a,l
        ld (TZ),a
        ; lobes / amplitude shift / twist per phase (table)
        ld a,(TPH)
        cp 10
        jr c,.p
        ld a,9
.p:     ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,TPHT
        add hl,de
        ld a,(hl)
        ld (TLOB),a
        inc hl
        ld a,(hl)
        ld (TSH),a
        inc hl
        ld a,(hl)
        ld (TTW),a
        inc hl
        ld a,(hl)
        ld (TPAT),a
        ; wandering vanishing point (offset into 48x24 tables)
        ld a,(T)
        call sin8
        sra a
        sra a
        sra a
        sra a
        sra a
        add a,8
        ld (TOX),a
        ld a,(T)
        add a,a
        add a,32
        call sin8
        sra a
        sra a
        sra a
        sra a
        sra a
        add a,4
        ld (TOY),a
        ; colour band offset cycles (and jumps with the kick)
        ld a,(T)
        rrca
        rrca
        ld b,a
        ld a,(DUTY1)
        rrca
        rrca
        rrca
        rrca
        and 3
        add a,b
        ld (TCOL),a
        ret

; per-frame tables
tbuild: ; MODT[a] = sin(a*lobes + t*2) >> sh
        ld a,(T)
        add a,a
        ld (TMP1),a             ; phase
        ld hl,MODT
        ld c,0                  ; running a*lobes
.m:     ld a,(TMP1)
        add a,c
        call sin8
        ld b,a
        ld a,(TSH)
        or a
        jr z,.z
.s:     sra b
        dec a
        jr nz,.s
        ld a,b
        jr .w
.z:     xor a
.w:     ld (hl),a
        ld a,(TLOB)
        add a,c
        ld c,a
        inc l
        ld a,l
        and 1
        jr nz,.nt
        TICK
.nt:    ld a,l
        or a
        jr nz,.m
        ; TWT[d] = (d * twist) >> 6
        ld hl,TWT
        ld de,0
        ld a,(TTW)
        ld c,a
        ld b,0
.t:     ld a,d
        ld (hl),a
        ex de,hl
        add hl,bc
        add hl,bc
        ex de,hl
        inc l
        ld a,l
        and 3
        jr nz,.nt2
        TICK
.nt2:   ld a,l
        or a
        jr nz,.t
        ; CMAP[32] from palette set with offset
        ld a,(TPAT)
        and $F0
        ld e,a                  ; palette base (16 per set * 2)
        ld d,0
        ld hl,TPALS
        add hl,de
        add hl,de
        ld (TMP2),hl
        ld de,CMAP
        ld b,32
        ld c,0
.c:     ld a,(TCOL)
        srl a
        srl a
        add a,c
        and 31
        push hl
        ld hl,(TMP2)
        add a,l
        ld l,a
        jr nc,.cn
        inc h
.cn:    ld a,(hl)
        pop hl
        ld (de),a
        inc de
        inc c
        djnz .c
        ret

; render 32x16 cells straight into the cell buffer (CHUNKY top rows)
trender:
        ld a,(TPAT)
        and $0F
        add a,a
        add a,a
        add a,a
        add a,a                 ; 16 patterns per set
        ld e,a
        ld d,0
        ld hl,PATS
        add hl,de
        ld (TPATP),hl
        ld b,0                  ; cy
.row:   push bc
        ; table row pointer = (cy+TOY)*48 + TOX
        ld a,(TOY)
        add a,b
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *48
        ld a,(TOX)
        ld e,a
        ld d,0
        add hl,de
        ld (TRP),hl
        ; dst = CHUNKY + cy*64
        pop bc
        push bc
        ld a,b
        rrca
        rrca
        ld l,a
        and $3F
        add a,CHUNKY>>8
        ld h,a
        ld a,l
        and $C0
        ld l,a
        ld (TDST),hl
        ld c,32
.cell:  ld hl,(TRP)
        ld de,TA
        add hl,de
        ld a,(hl)               ; angle
        ld hl,(TRP)
        ld de,TD
        add hl,de
        ld e,(hl)               ; raw depth
        ; a += twist[d] + rot
        ld l,e
        ld h,TWT>>8
        add a,(hl)
        ld hl,TROT
        add a,(hl)
        ld b,a                  ; angle'
        ; d' = d + mod[angle] + z
        ld l,a
        ld h,MODT>>8
        ld a,e
        add a,(hl)
        ld hl,TZ
        add a,(hl)
        ld e,a                  ; depth'
        ; colour (wide bands)
        rrca
        rrca
        rrca
        rrca
        and 15
        ld hl,CMAP
        add a,l
        ld l,a
        jr nc,.cm
        inc h
.cm:    ld d,(hl)
        ; pattern index = (angle>>4 & 3) | (depth>>1 & 12)
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and 3
        ld b,a
        ld a,e
        rrca
        and 12
        or b
        ld hl,(TPATP)
        add a,l
        ld l,a
        jr nc,.pp
        inc h
.pp:    ld a,(hl)
        or d
        ld hl,(TDST)
        ld (hl),a
        inc hl
        ld (TDST),hl
        ld hl,(TRP)
        inc hl
        ld (TRP),hl
        ld a,c
        and 1
        jr nz,.nt
        TICK
.nt:    dec c
        jp nz,.cell
        pop bc
        inc b
        ld a,b
        cp 16
        jp nz,.row
        ret

; the entity glimpsed ahead at the vanishing point, every other bar
tentity:
        ld a,(T)
        and $80
        ret z
        ld a,(TOX)
        neg
        add a,24
        ld d,a
        ld a,(TOY)
        neg
        add a,12
        ld e,a                  ; cell coords of tunnel centre
        ld a,d
        cp 31
        ret nc
        ld a,e
        cp 16
        ret nc
        ld a,e
        rrca
        rrca
        ld l,a
        and $3F
        add a,CHUNKY>>8
        ld h,a
        ld a,l
        and $C0
        add a,d
        ld l,a
        call rnd
        and 1
        ld a,$CF                ; buff full cell
        jr z,.e
        ld a,$9F                ; yellow
.e:     ld (hl),a
        inc l
        ld (hl),$C6
        ret

TPHT:   ; lobes, amp shift (0=none, 3 big .. 5 small), twist, pattern/palette set
        db 0,0,0,$00,   0,0,2,$00,   3,5,3,$00,   3,4,4,$10
        db 5,4,6,$11,   5,4,8,$21,   4,3,10,$22,  4,3,12,$32
        db 6,4,8,$31,   0,0,2,$40
