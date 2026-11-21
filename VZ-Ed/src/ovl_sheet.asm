; ===========================================================================
;  ovl_sheet.asm - overlay slot 1: the sheet view (CTRL+V).  Built by build.py
;  against the main program's symbols (mainsym.inc); runs at OVLA+2.
;
;  Graphics mode 1 (128 x 64, 4 colours), one pixel per character: blue for a
;  letter, green for a space.  Word wrap off: one pixel row per line, the first
;  128 columns (scrolled if the box goes further right).  Word wrap on: one
;  pixel row per screen row (32 wide), in four strips of 64 rows side by side.
;  The box (the editor's screen: 32 columns x docrows rows) is yellow, its
;  letters red.  Cursor keys / R C (a screen) / T B move it, RETURN goes there,
;  Q, CTRL+Q or CTRL+V go back without moving.
;
;  "Rows" are lines (wrap off) or screen rows (wrap on), numbered from 0.
;  zAT[k] = start of row 64k (whole text, one pass at the start); zRT[i] =
;  start of row zS0+i for the rows on show (rows past the end = text length).
;  The text is only read: the gap must not move while an overlay runs.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)

zs_go:  ld a,1
        ld (waitrel),a      ; CTRL+V is still held
        ld a,(docrows)
        ld (zDR),a
        ld a,(wrap)
        or a
        ld hl,64
        ld a,128
        ld de,(hs)
        jr z,zs_1
        ld hl,256
        ld a,32
        ld de,0
zs_1:   ld (zSH),hl
        ld (zW),a
        ld a,e              ; (a multiple of 4)
        and $FC
        ld e,a
        ld (zBH),de
        ld hl,0
        ld (zH0),hl
        ld (zS0),hl
        ld (zB),hl
        ld (zR),hl
        ld (zP),hl
zp_l:   ld hl,(zR)          ; one pass: zAT, zNR, and the row of top = zB
        ld a,l
        and 63
        jr nz,zp_1
        call zs_atk
        ld de,(zP)
        ld (hl),e
        inc hl
        ld (hl),d
zp_1:   ld hl,(zP)
        ld de,(top)
        or a
        sbc hl,de
        jr nz,zp_2
        ld hl,(zR)
        ld (zB),hl
zp_2:   ld hl,(zP)
        call zs_next
        ld (zP),hl
        ld hl,(zR)
        inc hl
        ld (zR),hl
        jr nc,zp_l
        ld (zNR),hl
        ld a,$08            ; graphics mode 1, cleared
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),0
        ldir
        call zs_fix
        call zs_rt
        call zs_all
        call zs_old

zk_lp:  call waitkey
        cp K_UP
        jr z,zk_up
        cp K_DOWN
        jr z,zk_dn
        cp K_PGUP
        jr z,zk_pu
        cp K_PGDN
        jr z,zk_pd
        cp K_TOP
        jr z,zk_top
        cp K_BOT
        jr z,zk_bot
        cp K_LEFT
        jr z,zk_lt
        cp K_RIGHT
        jr z,zk_rt
        cp K_RET
        jp z,zk_go
        cp K_FIRE
        jp z,zk_go
        cp K_QUIT
        jp z,zk_q
        cp K_SHEET
        jp z,zk_q
        or $20
        cp 'q'
        jp z,zk_q
        jr zk_lp

zk_up:  ld hl,(zB)
        ld a,h
        or l
        jr z,zk_lp
        dec hl
        jr zk_setb
zk_dn:  ld hl,(zB)
        inc hl
        jr zk_clb
zk_pu:  call zs_dr
        ld hl,(zB)
        or a
        sbc hl,de
        jr nc,zk_setb
        ld hl,0
        jr zk_setb
zk_pd:  call zs_dr
        ld hl,(zB)
        add hl,de
zk_clb: ld de,(zNR)         ; no further than the last row
        dec de
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,zk_setb
        ex de,hl
zk_setb: ld (zB),hl
        jr zk_draw
zk_top: ld hl,0
        ld (zBH),hl
        jr zk_setb
zk_bot: call zs_dr          ; the box ends at the last row
        ld hl,(zNR)
        or a
        sbc hl,de
        jr nc,zk_setb
        ld hl,0
        jr zk_setb
zk_lt:  ld hl,(zBH)
        ld de,8
        or a
        sbc hl,de
        jr nc,zk_sbh
        ld hl,0
        jr zk_sbh
zk_rt:  ld hl,(zBH)
        ld de,8
        add hl,de
        ld a,h
        cp $20
        jp nc,zk_lp
zk_sbh: ld a,(wrap)         ; (wrap on: the box is always the full width)
        or a
        jp nz,zk_lp
        ld (zBH),hl

zk_draw: call zs_fix
        ld hl,(zS0)
        ld de,(zOS0)
        or a
        sbc hl,de
        jr z,zd_1
        call zs_rt
        jr zd_all
zd_1:   ld hl,(zH0)
        ld de,(zOH0)
        or a
        sbc hl,de
        jr nz,zd_all
        ld hl,(zOB)         ; only the rows of the old and the new box
        call zd_box
        ld hl,(zB)
        call zd_box
        jr zd_sv
zd_all: call zs_all
zd_sv:  call zs_old
        jp zk_lp

zk_go:  ld hl,(zB)          ; RETURN: the editor shows the box
        ld de,(zS0)
        or a
        sbc hl,de
        add hl,hl
        ld de,zRT
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (top),hl
        ld a,(wrap)
        or a
        jr nz,zg_x
        push hl
        call next_line      ; HL = length of the line
        ld de,(zBH)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,zg_1           ; shorter than the box column: its end
        ex de,hl
zg_1:   pop de
        add hl,de
        ld de,(zBH)
        ld (hs),de
zg_x:   push hl
        call zs_back
        pop hl
        scf
        ret
zk_q:   call zs_back
        or a
        ret
zs_back: call set_display
        jp invalidate

zs_dr:  ld a,(zDR)          ; DE = docrows
        ld e,a
        ld d,0
        ret

zs_old: ld hl,(zB)
        ld (zOB),hl
        ld hl,(zS0)
        ld (zOS0),hl
        ld hl,(zH0)
        ld (zOH0),hl
        ret

zs_atk: ld b,6              ; HL = row (a multiple of 64) -> HL = &zAT[row/64]
zat_s:  srl h
        rr l
        djnz zat_s
        add hl,hl
        ld de,zAT
        add hl,de
        ret

; HL = logical start of a row -> HL = start of the next row; C = that was the
; last row (HL = text length).  Past the end it keeps giving the text length.
zs_next: ld a,(wrap)
        or a
        jr z,zn_nw
        call log2phys
        call wrow
        push af
        call phys2log
        pop af
        ret
zn_nw:  call next_line
        ld a,d
        and e
        inc a
        jr z,zn_end
        ex de,hl
        or a
        ret
zn_end: call textlen
        scf
        ret

; keep the box on show: zS0 (first row shown) and zH0 (first column shown)
zs_fix: ld hl,(zB)          ; box rows on show: leave the sheet where it is
        ld de,(zS0)
        or a
        sbc hl,de
        jr c,zf_c
        call zs_dr
        add hl,de
        ld de,(zSH)
        or a
        sbc hl,de
        jr c,zf_2
        jr z,zf_2
zf_c:   call zs_dr          ; else centre the box: S0 = b - (SH-docrows)/2,
        ld hl,(zSH)         ; at least 0 and at most NR-SH
        or a
        sbc hl,de
        srl h
        rr l
        ex de,hl
        ld hl,(zB)
        or a
        sbc hl,de
        jr nc,zf_s
        ld hl,0
zf_s:   push hl
        ld hl,(zNR)
        ld de,(zSH)
        or a
        sbc hl,de
        jr nc,zf_m
        ld hl,0
zf_m:   pop de
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,zf_st
        ex de,hl
zf_st:  ld (zS0),hl
zf_2:   ld hl,(zBH)
        ld de,(zH0)
        or a
        sbc hl,de
        jr nc,zf_3
        ld hl,(zBH)
        ld (zH0),hl
        ret
zf_3:   ld de,97            ; box column more than 96 past H0: H0 = bh - 96
        or a
        sbc hl,de
        ret c
        ld hl,(zBH)
        ld de,96
        or a
        sbc hl,de
        ld (zH0),hl
        ret

; zRT[0..SH] = starts of rows S0 .. S0+SH (walked from zAT[S0/64])
zs_rt:  ld hl,(zS0)
        ld a,l
        and $C0
        ld l,a
        call zs_atk
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(zS0)
        and 63
        jr z,zr_f
        ld b,a
zr_s:   push bc
        call zs_next
        pop bc
        djnz zr_s
zr_f:   ld de,zRT
        ld bc,(zSH)
        inc bc
zr_l:   ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        push bc
        push de
        call zs_next
        pop de
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,zr_l
        ret

zs_all: ld a,(zSH)          ; every row (64, or 256 as 0)
        ld b,a
        xor a
za_l:   push af
        push bc
        call zs_row
        pop bc
        pop af
        inc a
        djnz za_l
        ret

zd_box: call zs_dr          ; rows HL .. HL+docrows-1, those on show
        ld b,e
zdb_l:  push bc
        push hl
        ld de,(zS0)
        or a
        sbc hl,de
        jr c,zdb_n
        ld de,(zSH)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,zdb_n
        ld a,l
        call zs_row
zdb_n:  pop hl
        inc hl
        pop bc
        djnz zdb_l
        ret

; draw row zS0+A of the sheet
zs_row: ld (zI),a
        and 63              ; video address: y*32 + strip*8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(zI)
        and $C0
        rrca
        rrca
        rrca
        or l
        ld l,a
        ld de,VRAM
        add hl,de
        ld (zV),hl
        ld a,(zI)           ; DE = row start, HL = its length
        ld l,a
        ld h,0
        add hl,hl
        ld de,zRT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or a
        sbc hl,de
        push de             ; columns from H0
        ld de,(zH0)
        or a
        sbc hl,de
        pop de
        jr nc,zw_1
        ld hl,0
        jr zw_2
zw_1:   push hl
        ld hl,(zH0)
        add hl,de
        ex de,hl
        pop hl
zw_2:   ld a,(zW)           ; at most the width
        ld c,a
        ld b,0
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,zw_3
        ld h,b
        ld l,c
zw_3:   ld a,l
        ld (zN),a
        ex de,hl
        ld b,d
        ld c,e
        ld a,b
        or c
        call nz,zs_get      ; zLB = the characters, then 3 spaces
        ld a,(zN)
        ld e,a
        ld d,0
        ld hl,zLB
        add hl,de
        ld a,' '
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld a,(zN)           ; bytes with characters in them
        add a,3
        rrca
        rrca
        and $3F
        ld (zK),a
        ld hl,zLB
        ld de,(zV)
        or a
        jr z,zp_t
        ld b,a
zp_b:   ld a,(hl)           ; four pixels a byte: 10 = a letter, 00 = not
        inc hl
        cp 33
        ccf
        rl c
        sla c
        ld a,(hl)
        inc hl
        cp 33
        ccf
        rl c
        sla c
        ld a,(hl)
        inc hl
        cp 33
        ccf
        rl c
        sla c
        ld a,(hl)
        inc hl
        cp 33
        ccf
        rl c
        sla c
        ld a,c
        ld (de),a
        inc de
        djnz zp_b
zp_t:   ld a,(zW)           ; the rest of the row: green
        rrca
        rrca
        and $3F
        ld hl,zK
        sub (hl)
        jr z,zp_x
        ld b,a
        xor a
zp_z:   ld (de),a
        inc de
        djnz zp_z
zp_x:   ld a,(zI)           ; in the box? +1 on its 32 pixels (yellow / red)
        ld l,a
        ld h,0
        ld de,(zS0)
        add hl,de
        ld de,(zB)
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,(zDR)
        ld b,a
        ld a,l
        cp b
        ret nc
        ld hl,(zBH)         ; (bh and H0 are multiples of 4)
        ld de,(zH0)
        or a
        sbc hl,de
        srl h
        rr l
        srl h
        rr l
        ld de,(zV)
        add hl,de
        ld b,8
zp_bx:  ld a,(hl)
        or $55
        ld (hl),a
        inc hl
        djnz zp_bx
        ret

; copy BC characters from logical position HL to zLB (around the gap)
zs_get: ld (zGs),hl
        ld (zGn),bc
        call curpos
        ld de,(zGs)
        or a
        sbc hl,de           ; cursor - start
        jr c,zg_aft
        jr z,zg_aft
        ld bc,(zGn)
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,zg_spl
        ld hl,(zGs)         ; all before the gap
        ld de,BUFS
        add hl,de
        ld de,zLB
        ldir
        ret
zg_spl: ld b,h              ; part before, the rest after the gap
        ld c,l
        ld hl,(zGs)
        ld de,BUFS
        add hl,de
        ld de,zLB
        push bc
        ldir
        pop bc
        ld hl,(zGn)
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        ld hl,(ge)
        ldir
        ret
zg_aft: ld hl,(zGs)
        call log2phys
        ld bc,(zGn)
        ld de,zLB
        ldir
        ret

zs_cend:                    ; (what is in the file ends here; work RAM follows)
        assert zs_cend <= OVLA+OVLSEC*512
zDR     equ zs_cend
zW      equ zDR+1
zI      equ zW+1
zSH     equ zI+1
zNR     equ zSH+2
zB      equ zNR+2
zBH     equ zB+2
zH0     equ zBH+2
zS0     equ zH0+2
zOB     equ zS0+2
zOS0    equ zOB+2
zOH0    equ zOS0+2
zV      equ zOH0+2
zR      equ zV+2
zP      equ zR+2
zGs     equ zP+2
zGn     equ zGs+2
zN      equ zGn+2
zK      equ zN+1
zAT     equ zK+1           ; 194 entries (12,289 rows at most)
zRT     equ zAT+194*2       ; 257 entries
zLB     equ zRT+257*2       ; 128 characters / colours
zs_wend equ zLB+128
        assert zs_wend <= OVLEND
