; ==========================================================================
; tunnel.asm - tunnels                                     ViBED by BPM 2026
;
;  Track segments flagged 1 (TRK_FL ring) are inside a tunnel.
;  Approach: the projection stops at the tunnel mouth (no road beyond it),
;    and the rows above the mouth's road line get the portal: a concrete
;    face with the opening (checker) cut into it.  Cells are static PCG
;    characters of bank 11 built at start-up: solid face, opening, and the
;    opening's left/right/top edges and corners at every sub-cell offset -
;    so the portal grows smoothly without compositing anything.
;  Inside: the sky rows show the tunnel's ceiling and walls (static picture
;    from mktunnel.py, PCG bank 13), with ceiling lights rushing towards you
;    (4 phases of the centre columns), and the TUNNEL colour theme.
; ==========================================================================

TUNTHEME equ 5
MBANK   equ 11
TBANK   equ 13
MOUTHCOL equ 07h                ; light grey on black
TUNCOL  equ 07h
; mouth character codes (bank 11)
MC_FACE equ 80h
MC_INT  equ 81h
MC_VL   equ 82h                 ; + s  (opening's left edge at 2s px)
MC_VR   equ 86h                 ; + s  (opening's right edge at 2s px)
MC_HT   equ 8Ah-1               ; + t  (opening's top at logical line t, 1..7)
MC_CL   equ 91h-4               ; + 4t + s  (top-left corner)
MC_CR   equ 0ADh-4              ; + 4t + s  (top-right corner)

        assert TUN_NCH <= 128

; --------------------------------------------------------------------------
; tunnel_init: build the portal characters, upload the tunnel picture
; --------------------------------------------------------------------------
tunnel_init:
        ld a,TBANK
        or X1C
        out (PORT_1C),a
        ld hl,TUNPCG
        ld de,PCGWIN
        ld bc,TUN_NCH*16
        ldir
        ld a,MBANK
        or X1C
        out (PORT_1C),a
        ld de,PCGWIN
        ld bc,0010h             ; face: 16 face lines
        call mkchar
        ld bc,0000h             ; opening
        call mkchar
        ld hl,MASKL             ; VL[s]: face left of 2s px
        ld c,0
        call .four
        ld hl,MASKR             ; VR[s]: face from 2s px
        call .four
        ld c,2                  ; HT[t]: face above line t
.ht     ld b,0
        call mkchar
        inc c
        inc c
        ld a,c
        cp 16
        jr c,.ht
        ld hl,MASKL             ; CL[t][s]
        call .corner
        ld hl,MASKR             ; CR[t][s]
        call .corner
        ld a,X1C
        out (PORT_1C),a
        ret
.corner ld c,2
.cl     push hl
        call .four
        pop hl
        inc c
        inc c
        ld a,c
        cp 16
        jr c,.cl
        ret
.four   ld b,4
.f      push bc
        ld b,(hl)
        call mkchar
        pop bc
        inc hl
        djnz .f
        ret
MASKL:  db 00h,0C0h,0F0h,0FCh
MASKR:  db 0FFh,3Fh,0Fh,03h

; mkchar: DE -> 16 bytes; C = face scanlines at the top, B = face pixel mask
;   (the rest is the opening's checker)
mkchar: push hl
        ld l,0
.l      ld a,l
        cp c
        ld a,0FFh
        jr c,.w
        ld a,l
        and 1
        ld a,0AAh
        jr z,.c
        ld a,55h
.c      ld h,a
        ld a,b
        cpl
        and h
        or b
.w      ld (de),a
        inc de
        inc l
        ld a,l
        cp 16
        jr c,.l
        pop hl
        ret

; --------------------------------------------------------------------------
; tunnel_state: once per frame after track_stream - inside?  mouth ahead?
; --------------------------------------------------------------------------
tunnel_state:
        ld a,(camPos+1)
        ld l,a
        ld h,high(TRK_FL)
        ld a,(hl)
        ld hl,intun
        cp (hl)
        jr z,.same
        ld (hl),a
        or a
        ld a,TUNTHEME
        jr nz,.th
        call leg_theme_id       ; out: the leg's colours again
.th     ld (theme),a
        call set_theme
.same   xor a
        ld (mouthk),a
        ld a,(intun)
        or a
        ret nz
        ld a,(camPos+1)         ; the first tunnel segment within view
        ld l,a
        ld h,high(TRK_FL)
        ld b,18
        ld c,1
.s      inc l
        ld a,(hl)
        or a
        jr nz,.m
        inc c
        djnz .s
        ret
.m      ld a,c
        ld (mouthk),a
        ret

; --------------------------------------------------------------------------
; draw_mouth: the portal over the rows above the mouth's road line
;   (PTS[kmax] is the mouth: project stopped there)
; --------------------------------------------------------------------------
draw_mouth:
        ld a,(mouthk)
        or a
        jp z,mouth_gone
        ld a,(kmax)             ; mouth geometry (logical px)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PTS
        add hl,de
        push hl
        pop ix
        ld l,(ix+4)             ; sw: road half width at the mouth
        ld h,(ix+5)
        ld (m_oh),hl            ; opening height = sw
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        add hl,de
        ld (m_ow),hl            ; opening half width = 1.25 sw
        add hl,hl
        ld de,4
        add hl,de
        ld (m_fw),hl            ; face half width = 2.5 sw + 4
        ld l,(ix+0)
        ld h,(ix+1)
        ld de,(m_oh)
        or a
        sbc hl,de
        ld (m_ot),hl            ; opening top = sy - sw
        srl d
        rr e
        or a
        sbc hl,de
        ld de,4
        sbc hl,de
        ld (m_ft),hl            ; face top = opening top - sw/2 - 4
        ; rows: r0 = max(1, ft>>3) .. r1 = (LTOP>>3) - 1
        bit 7,h
        ld a,1
        jr nz,.r0
        ld a,h
        or a
        jp nz,mouth_gone
        ld a,l
        rrca
        rrca
        rrca
        and 1Fh
        jr nz,.r0
        inc a
.r0     ld (m_r0),a
        ld a,(LTOP)
        rrca
        rrca
        rrca
        and 1Fh
        dec a
        cp 16
        jr c,.r1
        ld a,15
.r1     ld (m_r1),a
        ld b,a
        ld a,(m_r0)
        cp b
        jr z,.rok
        jp nc,mouth_gone
.rok    ; columns
        ld e,(ix+2)
        ld d,(ix+3)
        ld (m_sx),de
        ld hl,(m_fw)
        ex de,hl
        or a
        sbc hl,de
        call col_of
        ld (m_fc0),a
        ld hl,(m_sx)
        ld de,(m_fw)
        add hl,de
        call col_of
        ld (m_fc1),a
        ld hl,(m_sx)
        ld de,(m_ow)
        or a
        sbc hl,de
        call col_of
        ld (m_cl),a
        ld a,c
        ld (m_sl),a
        ld hl,(m_sx)
        ld de,(m_ow)
        add hl,de
        call col_of
        ld (m_cr),a
        ld a,c
        ld (m_sr),a
        ; the face's column span, clipped to the screen
        ld a,(m_fc0)
        bit 7,a
        jr z,.c0
        xor a
.c0     cp 64
        jp nc,mouth_gone
        ld (m_fc0),a
        ld a,(m_fc1)
        bit 7,a
        jp nz,mouth_gone
        cp 64
        jr c,.c1
        ld a,63
.c1     ld (m_fc1),a
        ; ---- rows
        ld a,(m_r0)
.row    ld (crow),a
        call vbpoll
        ld a,(m_fc0)            ; face across the span
        ld e,a
        ld d,high(ROWBUF)
        ld a,(m_fc1)
        sub e
        inc a
        ld b,a
        ld a,MC_FACE
.ff     ld (de),a
        inc e
        djnz .ff
        ld a,(crow)             ; opening in this row?  t = ot - 8*row
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,(m_ot)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.t0               ; opening top above the row: t = 0
        ld a,h
        or a
        jp nz,.copy             ; below the row: face only
        ld a,l
        cp 8
        jp nc,.copy
        jr .t
.t0     xor a
.t      ld (m_t),a
        or a                    ; codes for this t
        ld a,MC_INT
        ld c,MC_VL
        ld b,MC_VR
        jr z,.cod
        ld a,(m_t)
        add a,MC_HT
        ld (.mid),a
        ld a,(m_t)
        add a,a
        add a,a
        ld b,a
        add a,MC_CL
        ld c,a
        ld a,b
        add a,MC_CR
        ld b,a
        ld a,(.mid)
.cod    ld (.mid),a
        ld a,(m_sl)
        add a,c
        ld (.lft),a
        ld a,(m_sr)
        add a,b
        ld (.rgt),a
        ; mid cells cl+1 .. cr-1 within the span
        ld a,(m_cl)
        inc a
        ld c,a
        ld a,(m_fc0)
        cp c
        jr nc,.f1
        ld a,c
.f1     ld c,a                  ; first = max(cl+1, fc0)
        ld a,(m_cr)
        dec a
        bit 7,a
        jr nz,.edges
        ld b,a
        ld a,(m_fc1)
        cp b
        jr c,.l1
        ld a,b                  ; last = min(cr-1, fc1)
.l1     sub c
        jr c,.edges
        inc a
        ld b,a
        ld e,c
        ld d,high(ROWBUF)
        ld a,(.mid)
.mf     ld (de),a
        inc e
        djnz .mf
.edges  ld a,(m_cl)             ; left edge cell
        call .inspan
        jr nc,.e2
        ld e,a
        ld d,high(ROWBUF)
        ld a,(.lft)
        ld (de),a
.e2     ld a,(m_cr)             ; right edge cell
        call .inspan
        jr nc,.copy
        ld e,a
        ld d,high(ROWBUF)
        ld a,(.rgt)
        ld (de),a
.copy   call row_addr           ; codes onto the screen
        ld a,(m_fc0)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld l,a
        ld h,high(ROWBUF)
        ld a,(m_fc1)
        sub l
        inc a
        ld c,a
        ld b,0
        ldir
        ld a,(crow)
        inc a
        ld hl,m_r1
        cp (hl)
        jr z,.more
        jp nc,.attr
.more   jp .row
.inspan                         ; A = column (signed) -> carry if fc0 <= A <= fc1
        bit 7,a
        jr nz,.no
        ld c,a
        ld a,(m_fc1)
        cp c
        jr c,.no
        ld a,(m_fc0)
        ld b,a
        ld a,c
        cp b
        jr c,.no
        scf
        ret
.no     or a
        ret
.mid    db 0
.lft    db 0
.rgt    db 0
.attr   ; attributes and colours only when the portal grew past what this
        ; page already has (they are the same for every portal cell)
        ld a,(page)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,MCACHE
        add hl,de
        ld a,(m_r0)
        cp (hl)
        jr c,.paint
        inc hl
        ld a,(hl)
        ld b,a
        ld a,(m_r1)
        cp b
        jr z,.a1
        jr nc,.paint
.a1     inc hl
        ld a,(m_fc0)
        cp (hl)
        jr c,.paint
        inc hl
        ld a,(hl)
        ld b,a
        ld a,(m_fc1)
        cp b
        jr z,.done
        jr nc,.paint
.done   jr mouth_ovr
.paint  dec hl                  ; remember the painted rectangle
        dec hl
        dec hl
        ld a,(m_r0)
        ld (hl),a
        inc hl
        ld a,(m_r1)
        ld (hl),a
        inc hl
        ld a,(m_fc0)
        ld (hl),a
        inc hl
        ld a,(m_fc1)
        ld (hl),a
        ld a,(m_r0)
.pr     ld (crow),a
        call vbpoll
        call row_addr
        ld a,(m_fc0)
        ld e,a
        ld d,0
        add hl,de
        ld a,(m_fc1)
        sub e
        inc a
        ld b,a
        push hl
        push bc
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld a,MBANK
        call fillb
        ld a,X1C
        out (PORT_1C),a
        pop bc
        pop hl
        ld de,800h
        add hl,de
        ld a,40h
        out (PORT_08),a
        ld a,MOUTHCOL
        call fillb
        xor a
        out (PORT_08),a
        call rowtype_ptr        ; the road must restore these if it gets here
        ld (hl),3
        ld a,(crow)
        inc a
        ld hl,m_r1
        cp (hl)
        jr z,.pr
        jr c,.pr
mouth_ovr:
        ld a,1                  ; the sky under the portal needs restoring later
        ld (mshown),a
        ld a,(page)             ; overlay text over the portal: paint it again
        ld e,a
        ld d,0
        ld hl,OVRDIRTY
        add hl,de
        ld a,(OVRACT)
        or (hl)
        ld (hl),a
        ret

; mouth_gone: no portal this frame - if one was shown, redraw the sky
mouth_gone:
        ld a,(mshown)
        or a
        ret z
        xor a
        ld (mshown),a
        call sky_redraw
mouth_reset:
        ld hl,MCACHE            ; nothing painted on either page (any portal
        ld b,2                  ;  rectangle is "bigger": r0 FF r1 0 c0 FF c1 0)
.c      ld (hl),0FFh
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0FFh
        inc hl
        ld (hl),0
        inc hl
        djnz .c
        xor a
        ld (tunok),a
        ld (tunok+1),a
        ret

; col_of: HL = logical x (signed) -> A = column clamped to -1..64, C = sub (0..3)
col_of: ld a,l
        and 3
        ld c,a
        sra h
        rr l
        sra h
        rr l
        bit 7,h
        jr nz,.neg
        ld a,h
        or a
        ld a,64
        ret nz
        ld a,l
        cp 64
        ret c
        ld a,64
        ret
.neg    ld a,0FFh
        ret

; --------------------------------------------------------------------------
; tun_sky: inside a tunnel the sky rows show its ceiling and walls
; --------------------------------------------------------------------------
tun_sky:
        ld a,(LTOP)
        rrca
        rrca
        rrca
        and 1Fh
        ld (toprow),a
        ld e,a
        ld a,(page)
        ld c,a
        ld b,0
        ld hl,tunok
        add hl,bc
        ld a,(hl)
        cp e
        jr z,.lights
        ld (hl),e
        ld a,1                  ; whole picture
.pr     ld (crow),a
        ld hl,toprow
        cp (hl)
        jr nc,.lights
        call vbpoll
        call tun_prow           ; HL -> TUNI row for this screen row
        push hl
        call row_addr
        ex de,hl
        pop hl
        ld b,64
.cc     ld a,(hl)
        or 80h
        ld (de),a
        inc hl
        inc de
        djnz .cc
        call row_addr
        push hl
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld b,64
        ld a,TBANK
        call fillb
        ld a,X1C
        out (PORT_1C),a
        pop hl
        ld de,800h
        add hl,de
        ld a,40h
        out (PORT_08),a
        ld b,64
        ld a,TUNCOL
        call fillb
        xor a
        out (PORT_08),a
        call rowtype_ptr
        ld (hl),2
        ld a,(page)             ; overlay text must be painted again
        ld e,a
        ld d,0
        ld hl,OVRDIRTY
        add hl,de
        ld a,(OVRACT)
        or (hl)
        ld (hl),a
        ld a,(crow)
        inc a
        jr .pr
.lights ; ceiling lights: phase from the distance travelled
        ld a,(camPos)           ; (picture phases recede, so count down)
        rlca
        rlca
        cpl
        and 3
        ld (.ph),a
        ld a,1
.lr     ld (crow),a
        ld hl,toprow
        cp (hl)
        ret nc
        cp OVR_N+1              ; rows with overlay text keep their text
        jr nc,.lt
        dec a
        call row_bit
        ld hl,OVRACT
        and (hl)
        jr nz,.lnx
.lt        call tun_prow           ; picture row index in (.pri)
        ld a,(tun_pri)
        ld c,a                  ; TUNL + (phase*9 + row) * LCN
        ld a,(.ph)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b                 ; *9
        add a,c
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl               ; *6 (TUN_LCN)
        ld de,TUNL
        add hl,de
        push hl
        call row_addr
        ld de,TUN_LC0
        add hl,de
        ex de,hl
        pop hl
        ld b,TUN_LCN
.lc     ld a,(hl)
        or 80h
        ld (de),a
        inc hl
        inc de
        djnz .lc
.lnx    ld a,(crow)
        inc a
        jr .lr
.ph     db 0

; tun_prow: picture row for screen row (crow), bottom row aligned with the
;   row above the horizon row -> HL -> TUNI row, (tun_pri) = index
tun_prow:
        ld a,(toprow)
        ld b,a
        ld a,(crow)
        sub b
        add a,9                 ; 9 - (toprow - crow)
        jp p,.ok
        xor a
.ok     ld (tun_pri),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *64
        ld de,TUNI
        add hl,de
        ret

; leg_theme_id: A = this leg's colour theme
leg_theme_id:
        ld a,(leg)
        ld e,a
        ld d,0
        ld hl,LEGTHEME
        add hl,de
        ld a,(hl)
        ret

intun:  db 0
mouthk: db 0
mshown: db 0
tunok:  db 0,0
tun_pri: db 0
MCACHE: ds 8                    ; per page: r0, r1, fc0, fc1 of the painted portal
m_oh:   dw 0
m_ow:   dw 0
m_fw:   dw 0
m_ot:   dw 0
m_ft:   dw 0
m_sx:   dw 0
m_r0:   db 0
m_r1:   db 0
m_fc0:  db 0
m_fc1:  db 0
m_cl:   db 0
m_sl:   db 0
m_cr:   db 0
m_sr:   db 0
m_t:    db 0
