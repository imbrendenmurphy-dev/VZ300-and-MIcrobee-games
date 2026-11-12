; ==========================================================================
; ui.asm - overlay text in the sky, big letters, HUD, score, autopilot
;                                                          ViBED by BPM 2026
;
;  Overlay: screen rows 1..8 can carry text over the sky.  Each row keeps
;  64 codes + 64 attributes (code 20h / attr 0 = transparent: sky shows)
;  and one ink colour; the paper is whatever sky colour is behind it.
;  Rows are painted onto a page only when they changed (or the sky under
;  them was redrawn), so the overlay costs nothing in steady state.
;  Big letters: the HUD font doubled twice (16 x 32 px), built on demand in
;  PCG bank 12, with racing speed-cuts in the lower half.
; ==========================================================================

OVR_N   equ 8
BIGBANK equ 12

; ovr_clear: remove all overlay text (the sky is redrawn under it)
ovr_clear:
        ld a,(OVRACT)
        ld c,a
        ld b,0
.r      srl c
        push bc
        ld a,b
        call c,ovr_blank
        pop bc
        inc b
        ld a,b
        cp OVR_N
        jr c,.r
        xor a
        ld (OVRACT),a
        ld (OVRDIRTY),a
        ld (OVRDIRTY+1),a
        ld (OVRCD),a
        ld (OVRCD+1),a
        ld (bigslot),a
sky_redraw:
        ld a,0FFh
        ld (lastsky),a
        ld (lastsky+2),a
        ret

; ovr_rowoff: A = screen row (1..8) -> its text removed
ovr_rowoff:
        dec a
        push af
        call ovr_blank
        pop af
        call row_bit
        cpl
        ld c,a
        ld a,(OVRACT)
        and c
        ld (OVRACT),a
        jr sky_redraw

; ovr_blank: A = row index 0..7 -> codes 20h, attrs 0
ovr_blank:
        push af
        call vbpoll
        pop af
        call ovr_rowptr
        ld b,64
.c      ld (hl),20h
        inc hl
        djnz .c
        ld b,64
.a      ld (hl),0
        inc hl
        djnz .a
        ret

; ovr_rowptr: A = row index -> HL = OVRBUF + 128*A
ovr_rowptr:
        rrca
        ld l,a
        and 7Fh
        ld h,a
        ld a,l
        and 80h
        ld l,a
        ld de,OVRBUF
        add hl,de
        ret

; row_bit: A = row index -> A = 1 << A
row_bit:
        ld b,a
        inc b
        xor a
        scf
.s      rla
        djnz .s
        ret

; ovr_activate: A = row index, B = ink -> active, dirty on both pages
ovr_activate:
        push af
        ld e,a
        ld d,0
        ld hl,OVRF
        add hl,de
        ld (hl),b
        pop af
        call row_bit
        ld c,a
        ld hl,OVRACT
        or (hl)
        ld (hl),a
        ld hl,OVRDIRTY
        ld a,c
        or (hl)
        ld (hl),a
        inc hl
        ld a,c
        or (hl)
        ld (hl),a
        ret

; ovr_setfg: A = screen row, B = ink (0FFh = invisible) -> recolour only
ovr_setfg:
        dec a
        ld e,a
        ld d,0
        ld hl,OVRF
        add hl,de
        ld c,a
        ld a,(hl)
        cp b
        ret z
        ld (hl),b
        ld a,c
        call row_bit
        ld c,a
        ld hl,OVRCD
        or (hl)
        ld (hl),a
        inc hl
        ld a,c
        or (hl)
        ld (hl),a
        ret

; ovr_text_c: A = screen row, HL -> string (0 end), B = ink: centred text
ovr_text_c:
        push af
        push hl
        push bc
        call vbpoll
        pop bc
        pop hl
        pop af
        dec a
        ld (ot_row),a
        ld a,b
        ld (ot_ink),a
        ld (ot_str),hl
        ld c,0                  ; length
.l      ld a,(hl)
        or a
        jr z,.n
        inc hl
        inc c
        jr .l
.n      ld a,64
        sub c
        srl a
        ld (ot_col),a
        ld a,(ot_row)
        call ovr_blank
        ld a,(ot_row)
        call ovr_rowptr
        ld a,(ot_col)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl                ; DE -> codes
        ld hl,(ot_str)
.c      ld a,(hl)
        or a
        jr z,.done
        inc hl
        push hl
        sub 32
        add a,a
        ld l,a
        ld h,0
        ld bc,FONTMAP
        add hl,bc
        ld a,(hl)
        ld (de),a               ; code
        inc hl
        ld a,(hl)
        ld hl,64
        add hl,de
        ld (hl),a               ; attribute
        inc de
        pop hl
        jr .c
.done   ld a,(ot_ink)
        ld b,a
        ld a,(ot_row)
        jp ovr_activate
ot_row: db 0
ot_ink: db 0
ot_col: db 0
ot_str: dw 0

; ovr_name: A = row, HL -> 14-char field (padded), B = ink -> centred, trimmed
ovr_name:
        push af
        push bc
        ld de,TXTBUF
        ld b,14
.s      ld a,(hl)               ; skip leading spaces
        cp ' '
        jr nz,.c
        inc hl
        djnz .s
.c      ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .c
.t      dec de                  ; trim trailing spaces
        ld a,(de)
        cp ' '
        jr z,.t
        inc de
        xor a
        ld (de),a
        pop bc
        pop af
        ld hl,TXTBUF
        jp ovr_text_c

; ovr_big_c: A = screen row (uses this row and the next), HL -> string,
;            B = ink: centred big letters
ovr_big_c:
        dec a
        ld (ot_row),a
        ld a,b
        ld (ot_ink),a
        ld (ot_str),hl
        ld c,0
.l      ld a,(hl)
        or a
        jr z,.n
        inc hl
        inc c
        jr .l
.n      ld a,32                 ; column = (64 - 2*len)/2
        sub c
        ld (ot_col),a
        ld a,(ot_row)
        call ovr_blank
        ld a,(ot_row)
        inc a
        call ovr_blank
        ld hl,(ot_str)
.g      ld a,(hl)
        or a
        jr z,.fin
        inc hl
        ld (ot_str),hl
        cp ' '
        jr z,.sp
        ld c,a
        ld a,(bigslot)
        cp 128
        jr nc,.sp               ; out of big-letter characters
        ld b,a
        add a,4
        ld (bigslot),a
        push bc
        ld a,c
        call big_glyph          ; B = slot
        ld a,(ot_row)
        call ovr_rowptr
        ld a,(ot_col)
        ld e,a
        ld d,0
        add hl,de               ; HL -> upper codes at the column
        pop bc
        ld a,b
        or 80h
        ld (hl),a               ; upper: slot, slot+1
        inc hl
        inc a
        ld (hl),a
        ld de,64
        add hl,de               ; upper attributes
        ld (hl),BIGBANK
        dec hl
        ld (hl),BIGBANK
        add hl,de               ; lower codes
        inc a
        ld (hl),a
        inc hl
        inc a
        ld (hl),a
        add hl,de               ; lower attributes
        ld (hl),BIGBANK
        dec hl
        ld (hl),BIGBANK
.sp     ld a,(ot_col)
        add a,2
        ld (ot_col),a
        ld hl,(ot_str)
        jr .g
.fin    ld a,(ot_ink)
        ld b,a
        ld a,(ot_row)
        push bc
        call ovr_activate
        pop bc
        ld a,(ot_row)
        inc a
        jp ovr_activate

; big_glyph: A = ascii, B = slot (4 consecutive characters of bank 12):
;   slot, slot+1 = upper left/right, slot+2, slot+3 = lower left/right
big_glyph:
        push af
        push bc
        call vbpoll
        pop bc
        pop af
        push bc
        sub 32
        add a,a
        ld l,a
        ld h,0
        ld de,FONTMAP
        add hl,de
        ld a,(hl)               ; code
        inc hl
        ld c,(hl)               ; attr (static bank)
        ld hl,BIGBUF
        ld b,64
.z      ld (hl),0
        inc hl
        djnz .z
        cp 20h
        jr z,.up
        and 7Fh                 ; source = PCGDATA + ((attr-9)*128 + code)*16
        ld l,a
        ld a,c
        sub PCG_FIRST
        ld h,a
        rrca
        and 80h
        or l
        ld l,a
        srl h
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGDATA
        add hl,de               ; HL -> 16 scanlines (8 logical lines doubled)
        ld c,0                  ; logical line
.ll     ld a,(hl)               ; 4 logical px in pixel pairs
        inc hl
        inc hl
        push hl
        ld b,a
        xor a
        bit 7,b
        jr z,.b1
        or 0F0h
.b1     bit 5,b
        jr z,.b2
        or 0Fh
.b2     ld (.lb),a
        xor a
        bit 3,b
        jr z,.b3
        or 0F0h
.b3     bit 1,b
        jr z,.b4
        or 0Fh
.b4     ld (.rb),a
        ld a,c                  ; destination: upper cells for lines 0-3
        cp 4
        ld hl,BIGBUF
        jr c,.up4
        ld hl,BIGBUF+32
.up4    and 3
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de               ; left cell, scanline 4*(l&3)
        ld b,4
.sc     ld a,c                  ; speed cut: last scanline of the lower blocks
        cp 5
        jr c,.full
        ld a,b
        dec a
        jr nz,.full
        ld (hl),a
        ld de,16
        add hl,de
        ld (hl),a
        jr .nx
.full   ld a,(.lb)
        ld (hl),a
        ld de,16
        add hl,de
        ld a,(.rb)
        ld (hl),a
.nx     ld de,-15
        add hl,de
        djnz .sc
        pop hl
        inc c
        ld a,c
        cp 8
        jr c,.ll
.up     pop bc                  ; copy the 64 bytes into bank 12
        ld a,BIGBANK
        or X1C
        out (PORT_1C),a
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl
        ld hl,BIGBUF
        ld bc,64
        ldir
        ld a,X1C
        out (PORT_1C),a
        ret
.lb     db 0
.rb     db 0

; ovr_logo: A = first screen row -> the BEELINE logo on 3 rows
ovr_logo:
        dec a
        ld (ot_row),a
        xor a
        ld (ot_col),a           ; logo row
.row    ld a,(ot_row)
        call ovr_blank
        ld a,(ot_row)
        call ovr_rowptr
        ld de,(64-LOGOW)/2
        add hl,de
        push hl
        ld a,(ot_col)
        rrca
        rrca
        rrca                    ; *32
        ld e,a
        ld d,0
        ld hl,LOGOC
        add hl,de
        pop de                  ; DE -> codes
        push hl
        push de
        ld bc,LOGOW
        ldir
        pop de
        pop hl
        ld bc,LOGOA-LOGOC
        add hl,bc
        ex de,hl
        ld bc,64
        add hl,bc
        ex de,hl
        ld bc,LOGOW
        ldir
        ld a,(ot_col)
        ld e,a
        ld d,0
        ld hl,LOGOINK
        add hl,de
        ld b,(hl)
        ld a,(ot_row)
        call ovr_activate
        ld hl,ot_row
        inc (hl)
        ld hl,ot_col
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.row
        ret
LOGOINK: db 11,11,9
LUMA:   db 0,58,115,173,19,77,134,192,96,77,153,230,26,102,179,255

; --------------------------------------------------------------------------
; ovr_paint: after the page is drawn - paint the overlay rows that changed
; on this page (codes, attributes, colours) and recolour blinking ones
; --------------------------------------------------------------------------
ovr_paint:
        ld a,(page)
        ld e,a
        ld d,0
        ld hl,OVRDIRTY
        add hl,de
        ld a,(hl)
        ld (hl),0
        ld (.full),a
        ld hl,OVRCD
        add hl,de
        ld a,(hl)
        ld (hl),0
        ld hl,.full
        or (hl)
        ret z
        ld (.any),a
        xor a
        ld (.ri),a
.r      ld a,(.any)
        rrca
        ld (.any),a
        jr nc,.nx
        ld a,(.ri)
        inc a
        ld (crow),a
        call row_addr
        ld (.scr),hl
        ld a,(.ri)
        call ovr_rowptr
        ld (.src),hl
        ld a,(.ri)
        ld e,a
        ld d,0
        ld hl,OVRF
        add hl,de
        ld a,(hl)
        ld (.ink),a
        ld a,(.ri)              ; full repaint of this row?
        call row_bit
        ld hl,.full
        and (hl)
        call nz,.codes
        call vbpoll
        call .colours
        call rowtype_ptr        ; road drawing must restore this row
        ld (hl),3
        call vbpoll
.nx     ld a,(.ri)
        inc a
        ld (.ri),a
        cp OVR_N
        jr c,.r
        ret
.codes  ld hl,(.src)            ; pass 1 codes, pass 2 attributes
        ld de,(.scr)
        ld b,64
.c1     ld a,(hl)
        cp 20h
        jr nz,.w1
        push hl
        ld a,l
        add a,64
        ld l,a
        jr nc,.n1
        inc h
.n1     ld a,(hl)
        pop hl
        or a
        jr z,.s1
        ld a,20h
.w1     ld (de),a
.s1     inc hl
        inc de
        ld a,b
        cp 33
        jr nz,.s5
        push hl
        push de
        push bc
        call vbpoll
        pop bc
        pop de
        pop hl
.s5     djnz .c1
        call vbpoll
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,(.src)
        ld de,(.scr)
        ld b,64
.c2     ld a,(hl)
        push hl
        ld a,l
        add a,64
        ld l,a
        jr nc,.n2
        inc h
.n2     ld c,(hl)
        pop hl
        cp 20h
        jr nz,.w2
        ld a,c
        or a
        jr z,.s2
.w2     ld a,c
        ld (de),a
.s2     inc hl
        inc de
        djnz .c2
        ld a,X1C
        out (PORT_1C),a
        ret
.colours                        ; ink over the sky's paper
        ld a,40h
        out (PORT_08),a
        ld hl,(.src)
        ld de,(.scr)
        ld a,d
        add a,8
        ld d,a
        ld b,64
.c3     ld a,(hl)
        cp 20h
        jr nz,.w3
        push hl
        ld a,l
        add a,64
        ld l,a
        jr nc,.n3
        inc h
.n3     ld a,(hl)
        pop hl
        or a
        jr z,.s3
.w3     ld a,(de)
        and 0F0h
        ld c,a
        rrca
        rrca
        rrca
        rrca
        ld (.pap),a
        ld a,(.ink)
        cp 0FFh
        jr nz,.i2
        ld a,(.pap)             ; invisible: ink = paper
        jr .i3
.i2     push hl                 ; ink too close to the paper in brightness:
        push de                 ; black or white instead
        ld e,a
        ld d,0
        ld hl,LUMA
        add hl,de
        ld e,(hl)
        ld a,(.pap)
        ld l,a
        ld h,0
        push de
        ld de,LUMA
        add hl,de
        pop de
        ld a,(hl)
        ld d,a                  ; D = paper luma, E = ink luma
        sub e
        jr nc,.ab
        neg
.ab     cp 70
        ld a,(.ink)
        jr nc,.ok
        ld a,d
        cp 128
        ld a,0
        jr nc,.ok
        ld a,15
.ok     pop de
        pop hl
.i3     or c
        ld (de),a
.s3     inc hl
        inc de
        ld a,b
        cp 33
        jr nz,.s4
        push hl
        push de
        push bc
        xor a
        out (PORT_08),a
        call vbpoll
        ld a,40h
        out (PORT_08),a
        pop bc
        pop de
        pop hl
.s4     djnz .c3
        xor a
        out (PORT_08),a
        ret
.full   db 0
.any    db 0
.ri     db 0
.pap    db 0
.ink    db 0
.scr    dw 0
.src    dw 0

; --------------------------------------------------------------------------
; HUD: row 0, 64 characters in HUDTXT; draw_hud writes only the characters
; that differ from what this page shows
; --------------------------------------------------------------------------
HUD_TIME  equ 5
HUD_SCORE equ 16
HUD_POS   equ 31
HUD_LEG   equ 43
HUD_SPEED equ 55
HUD_HI    equ 11

H_RACE:  db "TIME 70   SCORE 00000000   POS 20/20   LEG 1/5   SPEED 000 KMH "
H_TITLE: db "  HI-SCORE 00000000                            VIBED BY BPM 2026"

hud_mode_title:
        xor a
        ld hl,H_TITLE
        jr hud_mode
hud_mode_race:
        ld a,1
        ld hl,H_RACE
hud_mode:
        ld (hudmode),a
        ld de,HUDTXT
        ld bc,64
        ldir
        jp hud_update

; hud_update: fill the numbers in HUDTXT
hud_update:
        ld a,(hudmode)
        or a
        jr nz,.race
        ld hl,HISC+3
        ld de,HUDTXT+HUD_HI
        ld b,4
        jp put_bcd
.race   ld a,(tsec)
        ld l,a
        ld h,0
        ld de,HUDTXT+HUD_TIME
        call put2
        ld hl,SCORE
        ld de,HUDTXT+HUD_SCORE
        ld b,4
        call put_bcd
        ld a,(rivals)
        inc a
        ld l,a
        ld h,0
        ld de,HUDTXT+HUD_POS
        call put2
        ld a,(leg)
        add a,'1'
        ld (HUDTXT+HUD_LEG),a
        ld hl,(speed)           ; km/h = speed*3/4
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        srl h
        rr l
        srl h
        rr l
        ld de,HUDTXT+HUD_SPEED
        jp put3

; hud_static: whole HUD row of the current page (text, attrs, colours)
hud_static:
        xor a
        ld (crow),a
        call row_addr
        push hl
        ld de,HUDTXT
        ld b,64
        ld c,0
        call .w
        call vbpoll
        ld a,X1C_ATTR
        out (PORT_1C),a
        pop hl
        push hl
        ld de,HUDTXT
        ld b,64
        ld c,1
        call .w
        call vbpoll
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        pop hl
        ld de,800h
        add hl,de
        ld a,(HUDCOL)
        ld b,64
        call fillb
        xor a
        out (PORT_08),a
        call hudlast_ptr        ; this page now shows HUDTXT
        ex de,hl
        ld hl,HUDTXT
        ld bc,64
        ldir
        ret
.w      ld a,(de)
        call fontcell
        ld (hl),a
        inc hl
        inc de
        djnz .w
        ret

; fontcell: A = ascii, C = 0 code / 1 attribute -> A
fontcell:
        push hl
        push de
        sub 32
        add a,a
        add a,c
        ld e,a
        ld d,0
        ld hl,FONTMAP
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

hudlast_ptr:
        ld a,(page)
        or a
        ld hl,HUDLAST
        ret z
        ld hl,HUDLAST+64
        ret

draw_hud:
        call hudlast_ptr
        ex de,hl
        xor a
        ld (crow),a
        call row_addr
        ex de,hl                ; HL -> last shown, DE -> screen row
        ld bc,HUDTXT
        ld a,64
.l      ex af,af'
        ld a,(bc)
        cp (hl)
        jr z,.s
        ld (hl),a               ; changed: code now, attribute below
        push bc
        ld c,0
        call fontcell
        ld (de),a
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld a,(hl)
        ld c,1
        call fontcell
        ld (de),a
        ld a,X1C
        out (PORT_1C),a
        pop bc
.s      inc bc
        inc hl
        inc de
        ex af,af'
        dec a
        ret z
        cp 32
        jr nz,.l
        ex af,af'
        push hl
        push de
        push bc
        call vbpoll
        pop bc
        pop de
        pop hl
        ex af,af'
        jr .l

; put_bcd: HL -> B BCD bytes (big-endian) -> 2B ascii digits at DE
put_bcd:
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 0Fh
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz put_bcd
        ret

; --------------------------------------------------------------------------
; score (4 BCD bytes, big-endian: SCORE+3 holds the units)
; --------------------------------------------------------------------------
add_score_a:                    ; A = 0..99 binary
        ld b,0
.t      cp 10
        jr c,.b
        sub 10
        inc b
        jr .t
.b      ld c,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or c
        ld hl,SCORE+3
        ld b,4
        jr add_bcd
add_score_100:                  ; A = BCD hundreds (10h = 1000)
        ld hl,SCORE+2
        ld b,3
        jr add_bcd
add_score_10k:                  ; A = BCD ten-thousands
        ld hl,SCORE+1
        ld b,2
add_bcd:
        add a,(hl)
        daa
        ld (hl),a
.p      dec b
        ret z
        ret nc
        dec hl
        ld a,(hl)
        add a,1
        daa
        ld (hl),a
        jr .p

; --------------------------------------------------------------------------
; autopilot (attract mode, initials entry, finish): flat out, steering
; around the nearest rival ahead.  -> B = key bits
; --------------------------------------------------------------------------
autopilot:
        ld hl,0
        ld (.tx),hl
        ld hl,9*256
        ld (.bd),hl
        ld ix,TCARS
        ld b,NT
.c      push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,(camPos)
        or a
        sbc hl,de
        ld de,PLAYZ
        call cmp_signed
        jr c,.n
        ld de,(.bd)
        call cmp_signed
        jr nc,.n
        push hl
        ld a,(ix+7)
        call lx_world
        ld (.cx),hl
        ld de,(camX)
        or a
        sbc hl,de
        bit 7,h
        call nz,neghl
        ld de,110
        or a
        sbc hl,de
        pop hl
        jr nc,.n
        ld (.bd),hl             ; nearest rival in our way
        ld hl,(.cx)
        ld de,-140
        bit 7,h
        jr z,.side
        ld de,140
.side   add hl,de
        ld (.tx),hl
.n      ld de,CARSZ
        add ix,de
        pop bc
        djnz .c
        ld b,4
        ld hl,(camX)
        ld de,(.tx)
        or a
        sbc hl,de               ; camX - target
        ld de,-30
        call cmp_signed
        jr nc,.a1
        set 1,b
.a1     ld de,30
        call cmp_signed
        ret c
        set 0,b
        ret
.tx     dw 0
.bd     dw 0
.cx     dw 0

; input_filter: what the player's keys may do in this state
input_filter:
        ld a,(gstate)
        cp GS_COUNT
        jr nz,.t
        xor a
        ld (keys),a
        ret
.t      cp GS_TIMEUP
        ret nz
        ld a,(keys)
        and 3
        ld (keys),a
        ret

; ---------------------------------------------------------------- variables
gstate:  db 0
stimer:  dw 0
apilot:  db 0
rawkeys: db 0
ekeys:   db 0
ekprev:  db 0FFh
titlet:  dw 0
tpage:   db 0
cdown:   db 0
msgt:    db 0
gover:   db 0
erank:   db 0
ename:   ds 3
epos:    db 0
tsec:    db 0
tfld:    db 0
hudmode: db 0
bigslot: db 0
SCORE:   ds 4
OVRACT:  db 0
OVRDIRTY: db 0,0
OVRCD:   db 0,0
OVRF:    ds OVR_N
HUDTXT:  ds 64
HUDLAST: ds 128
PAUSEBUF: ds 64
TXTBUF:  ds 48
BIGBUF:  ds 64
; ---- overlay rows live in the runtime buffers at 8000h (see race.asm)
