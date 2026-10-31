; ---------------------------------------------------------------------------
; The panel (rows 44-63):
;   44      scroll bar (where the window is in the level)
;   45-49   status: what's under the cursor, OUT, IN %, time
;   51-63   12 buttons (2 bytes each): rate - +, 8 skills, pause, nuke
;           and the minimap (bytes 24-31)
; ---------------------------------------------------------------------------
PROW        equ 44
SROW        equ 45
BROW0       equ 51
NROW        equ 52              ; button numbers
MMROW       equ 52              ; minimap interior rows 52-62
MMCOL       equ 24

panel_init:
        ld hl,PANELIMG
        ld de,VRAM+PROW*32
        ld bc,20*32
        ldir
        ld a,$FF
        ld (v_psig),a           ; force the status line
        ld (v_pselold),a
        call panel_nums
        call panel_sel
        call mm_build
        call mm_show
        jp panel_status

; per loop: redraw what changed
panel_update:
        call panel_status
        ld a,(v_pdirty)
        or a
        call nz,panel_nums
        xor a
        ld (v_pdirty),a
        ld a,(v_sel)
        ld hl,v_pselold
        cp (hl)
        call nz,panel_sel
        call scrollbar
        ld a,(v_gtick)
        and 3
        ret nz
        ld a,(v_mmdone)
        or a
        ret nz
        inc a
        ld (v_mmdone),a
        call mm_column
        jp mm_show

; ---- status line ----------------------------------------------------------------
panel_status:
        ; signature of what's shown: hover state, count, out, saved, seconds
        call count_out
        ld b,a
        ld a,(v_hst)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,(v_hcount)
        add a,c
        add a,b
        ld c,a
        ld a,(v_saved)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld c,a
        ld a,(v_tleft)
        add a,c
        ld hl,v_psig
        cp (hl)
        ret z
        ld (hl),a
        ; build the line in sbuf (32 chars)
        ld hl,sbuf
        ld de,sbuf+1
        ld bc,31
        ld (hl),' '
        ldir
        ld a,(v_hcount)
        or a
        jr z,.nh
        ld a,(v_hst)
        add a,a
        ld l,a
        ld h,0
        ld de,STNAMES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,sbuf
.cp:    ld a,(hl)
        or a
        jr z,.ce
        ld (de),a
        inc hl
        inc de
        jr .cp
.ce:    inc de
        push de
        ld a,(v_hcount)
        call num_str
        pop de
        call .cpy
.nh:    ld de,sbuf+11
        ld hl,s_out
        call .cpy
        push de
        call count_out
        call num_str
        pop de
        call .cpy
        ld de,sbuf+18
        ld hl,s_in
        call .cpy
        push de
        call pct_saved
        call num_str
        pop de
        call .cpy
        ld a,'%'
        ld (de),a
        ; time m:ss at the right
        ld hl,(v_tleft)
        ld c,0
.mn:    ld de,60
        or a
        sbc hl,de
        jr c,.md
        inc c
        jr .mn
.md:    add hl,de               ; L = seconds
        ld a,c
        add a,'0'
        ld (sbuf+28),a
        ld a,':'
        ld (sbuf+29),a
        ld a,l
        call num_str2
        ld de,sbuf+30
        call .cpy
        ld a,'~'                ; clock
        ld (sbuf+26),a
        ; print: names green, numbers yellow (two passes, one colour each)
        ld a,C_GRN
        ld b,C_BLU
        call txt_quick
        ld c,0
        call .pass
        ld a,C_YEL
        ld b,C_BLU
        call txt_quick
        ld c,1
.pass:  ld hl,sbuf
        ld de,VRAM+SROW*32
        ld b,32
.pr:    ld a,(hl)
        inc hl
        push hl
        push bc
        push de
        ; digits / ':' / '%' are numbers
        cp '%'
        jr z,.isn
        cp '0'
        jr c,.isl
        cp ':'+1
        jr c,.isn
.isl:   bit 0,c
        jr nz,.sk
        jr .go
.isn:   bit 0,c
        jr z,.sk
.go:    call pchar
        call int_poll
.sk:    pop de
        pop bc
        pop hl
        inc de
        djnz .pr
        ret
; copy a zero-terminated string HL to DE
.cpy:   ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr .cpy
s_out:  db "OUT ",0
s_in:   db "IN ",0

; set the text colours only if they changed (the table is rebuilt otherwise)
txt_quick:
        ld c,a
        ld a,(t_fg)
        cp c
        jr nz,.ch
        ld a,(t_bg)
        cp b
        ret z
.ch:    ld a,c
        jp txt_colour

; saved * 100 / n -> A
pct_saved:
        ld a,(v_saved)
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; x3
        add hl,hl
        add hl,hl
        add hl,hl               ; x24
        add hl,de               ; x25
        add hl,hl
        add hl,hl               ; x100
        ld a,(v_ncrt)
        ld e,a
        ld d,0
        ld c,0
.d:     or a
        sbc hl,de
        jr c,.e
        inc c
        jr .d
.e:     ld a,c
        ret

; ---- button numbers: rate (min, current), 8 skill counts ----------------------
panel_nums:
        ld a,(v_minrate)
        ld c,0
        call bnum
        ld a,(v_rate)
        ld c,1
        call bnum
        ld hl,v_skill
        ld c,2
.l:     ld a,(hl)
        push hl
        push bc
        call bnum
        pop bc
        pop hl
        inc hl
        inc c
        ld a,c
        cp 10
        jr nz,.l
        ret

; A = value (0-99), C = button -> two digits in rows 52-56 (pixels 1-3, 5-7)
bnum:
        ld b,a
        ld a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,VRAM+NROW*32
        add hl,de
        ld (v_bnaddr),hl
        ld a,b
        ld d,'0'-1
.t:     inc d
        sub 10
        jr nc,.t
        add a,10+'0'
        ld e,a                  ; units
        ld a,d
        cp '0'
        jr nz,.tn
        ld d,' '                ; no leading zero
.tn:    ld a,b
        or a
        jr nz,.nz
        ld d,' '
        ld e,' '                ; blank when none are left
.nz:    ld a,d
        call glyph
        ld (v_g1),hl
        ld a,e
        call glyph
        ld (v_g2),hl
        ld a,C_YEL
        ld b,C_BLU
        call txt_quick
        ld hl,(v_bnaddr)
        ld b,5
.r:     push bc
        push hl
        ld hl,(v_g1)
        ld a,(hl)
        inc hl
        ld (v_g1),hl
        call .ex
        and $3F
        ld c,a
        pop hl
        ld a,(hl)
        and $C0                 ; keep the border pixel
        or c
        ld (hl),a
        inc hl
        push hl
        ld hl,(v_g2)
        ld a,(hl)
        inc hl
        ld (v_g2),hl
        call .ex
        pop hl
        ld (hl),a
        ld de,31
        add hl,de
        pop bc
        djnz .r
        ret
; font row A -> pixels shifted right one (EXPT of row >> 1)
.ex:    srl a
        ld de,EXPT
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        ld a,(de)
        ret

; A = character -> HL = its 5 font rows
glyph:
        push de
        sub 32
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,FONT
        add hl,de
        pop de
        ret

; ---- selection frame -----------------------------------------------------------
panel_sel:
        ld a,(v_pselold)
        cp 12
        jr nc,.n
        ld c,C_RED
        call frame_btn
.n:     ld a,(v_sel)
        ld (v_pselold),a
        ld c,C_YEL
; A = button, C = colour: left/right border columns, top and bottom rows
frame_btn:
        ld (v_fcol),a
        ld a,c
        ld (v_fc),a
        ld a,(v_fcol)
        add a,a
        call .col
        ld a,(v_fcol)
        add a,a
        add a,2
        call .col
        ld a,BROW0
        call .row
        ld a,63
.row:   ld b,a
        ld a,(v_fcol)
        add a,a
        ld c,a
        ld a,b
        call scr_addr
        ld a,(v_fc)
        ld b,a
        call fillcol4
        ld (de),a
        inc de
        ld (de),a
        inc de
        jp px0
; byte column A, rows 51..63: pixel 0
.col:   ld c,a
        ld a,BROW0
        call scr_addr
        ld b,13
.cl:    call px0
        ld a,e
        add a,32
        ld e,a
        jr nc,.cn
        inc d
.cn:    djnz .cl
        ret
; pixel 0 of (DE) := colour v_fc
px0:    ld a,(v_fc)
        rrca
        rrca
        ld c,a
        ld a,(de)
        and $3F
        or c
        ld (de),a
        ret
; A = 4 pixels of colour B
fillcol4:
        ld a,b
        and 3
        ld c,a
        rlca
        rlca
        or c
        ld c,a
        rlca
        rlca
        rlca
        rlca
        or c
        ret

; ---- scroll bar on row 44: the window's place in the level ---------------------
scrollbar:
        ld a,(v_scrb)
        ld hl,v_psb
        cp (hl)
        ret z
        ld (hl),a
        ld hl,VRAM+PROW*32
        ld b,32
.c:     ld (hl),$FF             ; red line
        inc hl
        djnz .c
        ; bar from scrb*32/lwb, length 32*32/lwb bytes
        ld a,(v_lwb)
        ld e,a
        ld a,(v_scrb)
        call div32
        ld b,a                  ; start byte
        ld a,32
        call div32              ; length
        or a
        jr nz,.l1
        inc a
.l1:    ld c,a
        ld a,b
        ld hl,VRAM+PROW*32
        add a,l
        ld l,a
        ld b,c
.f:     ld (hl),$55
        inc hl
        djnz .f
        ret
; A * 32 / E -> A
div32:
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,0
        ld c,0
.d:     or a
        sbc hl,de
        jr c,.e
        inc c
        jr .d
.e:     ld a,c
        pop bc
        ret

; ---- minimap (bytes 24-31, rows 52-61: 31 x 10 pixels, each 16 x 8 of the level)
; MMB: 8 x 10 bytes, solid red, air blue (built from the mask)
MMROWS      equ 10
mm_build:
        ld hl,MMB
        ld de,MMB+1
        ld bc,8*MMROWS-1
        ld (hl),BG
        ldir
        xor a
        ld (v_mmcol),a
        ld b,32
.l:     push bc
        call mm_column
        pop bc
        djnz .l
        ret
mm_column:
        ld a,(v_mmcol)
        inc a
        and 31
        ld (v_mmcol),a
        ld c,a
        and 3
        ld hl,PMSK
        add a,l
        ld l,a
        ld a,(hl)
        ld (v_mmm),a
        ld a,c
        rrca
        rrca
        and 7
        ld e,a
        ld d,0
        ld hl,MMB
        add hl,de
        ex de,hl                ; DE = MMB column byte
        ld a,c
        add a,a
        ld l,a
        ld h,MASK>>8            ; HL = mask row 0, bytes 2p, 2p+1
        ld b,MMROWS
.r:     push bc
        push hl
        xor a
        ld b,8
.s:     or (hl)
        inc l
        or (hl)
        dec l
        ld c,a
        ld a,l
        add a,64
        ld l,a
        jr nc,.sn
        inc h
.sn:    ld a,c
        djnz .s
        ld c,a
        ld a,(v_mmm)
        ld b,a
        ld a,c
        or a
        ld a,(de)
        jr z,.air
        or b                    ; red (11)
        jr .put
.air:   ld c,a
        ld a,b
        cpl
        and c
        ld c,a
        ld a,b
        and $AA                 ; blue (10)
        or c
.put:   ld (de),a
        ld a,e
        add a,8
        ld e,a
        jr nc,.dn
        inc d
.dn:    pop hl
        inc h
        inc h                   ; 8 mask rows on
        pop bc
        djnz .r
        ret

; copy MMB to the screen with the bilbies as yellow dots, the window in green
mm_show:
        xor a
        ld (v_mmdone),a
        ld hl,MMB
        ld de,MMS
        ld bc,8*MMROWS
        ldir
        ld ix,CRT
        ld b,NCRT
.l:     push bc
        ld a,(ix+C_ST)
        or a
        jr z,.n
        cp ST_GONE
        jr nc,.n
        ld l,(ix+C_XL)
        ld h,(ix+C_XH)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; x * 16 -> H = x / 16
        ld c,h
        ld a,(ix+C_Y)
        rrca
        rrca
        rrca
        and 31
        cp MMROWS
        jr nc,.n
        ld b,a
        call mm_dot
.n:     ld de,CSZ
        add ix,de
        pop bc
        djnz .l
        ld hl,MMS
        ld de,VRAM+MMROW*32+MMCOL
        ld bc,MMROWS*256+8
        call put_raw
        ; window across: green marks on the top and bottom frame rows
        ld a,(v_scrb)
        rrca
        rrca
        and $3F                 ; scrb / 4 = minimap pixel
        ld (v_mmw),a
        ld hl,VRAM+BROW0*32+MMCOL
        call .fr
        ld hl,VRAM+63*32+MMCOL
        call .fr
        ; window down: green marks on the left frame column
        ld hl,VRAM+MMROW*32+MMCOL
        ld b,MMROWS+1
        ld a,(v_scry)
        rrca
        rrca
        rrca
        and 31
        ld c,a                  ; first row
.vc:    ld a,MMROWS+1
        sub b                   ; row index
        sub c
        cp 6
        ld a,(hl)
        jr c,.vg
        or $C0                  ; red frame
        jr .vs
.vg:    and $3F                 ; green
.vs:    ld (hl),a
        ld de,32
        add hl,de
        djnz .vc
        ret
.fr:    push hl
        ld b,8
.fc:    ld (hl),$FF
        inc hl
        djnz .fc
        pop hl
        ld a,(v_mmw)
        ld b,8
.gp:    cp 32
        ret nc
        push af
        push bc
        push hl
        ld c,a
        rrca
        rrca
        and 7
        add a,l
        ld l,a
        ld a,c
        and 3
        ld de,PMSK
        add a,e
        ld e,a
        ld a,(de)
        cpl
        and (hl)
        ld (hl),a
        pop hl
        pop bc
        pop af
        inc a
        djnz .gp
        ret

; a yellow dot at minimap pixel C, row B (into MMS)
mm_dot:
        ld a,b
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,c
        cp 32
        ret nc
        rrca
        rrca
        and 7
        add a,e
        ld e,a
        ld d,0
        ld hl,MMS
        add hl,de
        ld a,c
        and 3
        push hl
        ld hl,PMSK
        add a,l
        ld l,a
        ld b,(hl)
        pop hl
        ld a,(hl)
        xor $55
        and b
        xor (hl)
        ld (hl),a
        ret
