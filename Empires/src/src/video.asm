; ===================================================================
;  video.asm - shadow planes, PCG upload, present, text, cells
; ===================================================================

; ---- init video: keep CP/M's 80x24 CRTC timing, home the display ----
video_init:
        ld a,12                 ; display start = 2000h as the CP/M BIOS sets it
        out (P_CRTCA),a         ; (MA13 selects the character ROM set)
        ld a,20h
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        call cursor_hide
        xor a
        out (P_COL),a
        ld a,EXT_ON
        out (P_EXT),a
        ret

cursor_hide:                    ; park hardware cursor beyond visible 1920 cells
        ld a,14
        out (P_CRTCA),a
        ld a,07h
        out (P_CRTCD),a
        ld a,15
        out (P_CRTCA),a
        ld a,0FFh
        out (P_CRTCD),a
        ret

; ---- upload both PCG sets (colour -> banks 0-7, mono -> banks 8-15) ----
pcg_upload:                     ; patterns come from the art block (lower window)
        ld a,BLK_ART
        call with_block
        ld hl,pcg_colour
        ld c,0                  ; bank offset 0
        call .set
        ld hl,pcg_mono
        ld c,8
        call .set
        ld a,EXT_ON
        out (P_EXT),a
        jp map_home
.set:   ; HL = pattern data, C = bank base
        ld de,0                 ; G counter
.lp:    ld a,d
        cp high(NCHARS)
        jr nz,.go
        ld a,e
        cp low(NCHARS)
        ret z
.go:    ; bank = (G>>7) + C
        ld a,e
        rla
        ld a,d
        rla                     ; A = G>>7 (G<1024)
        add a,c
        or EXT_ON
        out (P_EXT),a
        push de
        ld a,e
        and 7Fh
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        or high(HIRAM)
        ld h,a
        ex de,hl                ; DE = F800 + (G&127)*16
        push bc
        ld bc,11
        ldir
        xor a
        ld b,5
.z:     ld (de),a
        inc de
        djnz .z
        pop bc
        pop de
        inc de
        jr .lp

; ---- clear entire PCG (all 16 banks) ----
pcg_clear:
        ld b,16
.b:     ld a,b
        dec a
        or EXT_ON
        out (P_EXT),a
        ld hl,HIRAM
        ld de,HIRAM+1
        ld (hl),0
        push bc
        ld bc,2047
        ldir
        pop bc
        djnz .b
        ld a,EXT_ON
        out (P_EXT),a
        ret

; ---- shadow plane helpers ----
; clear shadow: chars = space, attr = 0, colour = A
shadow_clear:
        ld hl,SCOL
        ld de,SCOL+1
        ld (hl),a
        ld bc,SCRSIZE-1
        ldir
        ld hl,SCHR
        ld de,SCHR+1
        ld (hl),' '
        ld bc,SCRSIZE-1
        ldir
        ld hl,SATR
        ld de,SATR+1
        ld (hl),0
        ld bc,SCRSIZE-1
        ldir
        ret

; clear rows: B = first row, C = number of rows, A = colour
shadow_clear_rows:
        push af
        call row_off            ; DE = B*80
        ld h,0
        ld l,c
        call mul80              ; HL = C*80
        ld b,h
        ld c,l
        pop af
        push bc
        push de
        ld hl,SCOL
        add hl,de
        call .fill
        pop de
        pop bc
        push bc
        push de
        ld a,' '
        ld hl,SCHR
        add hl,de
        call .fill
        pop de
        pop bc
        xor a
        ld hl,SATR
        add hl,de
.fill:  ; HL=start, BC=count, A=value (count >= 2)
        push bc
        ld (hl),a
        ld d,h
        ld e,l
        inc de
        dec bc
        ldir
        pop bc
        ret

row_off:                        ; DE = B*80
        push hl
        ld h,0
        ld l,b
        call mul80
        ex de,hl
        pop hl
        ret

mul80:                          ; HL = HL*80
        push de
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *16
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl               ; *64
        add hl,de               ; *80
        pop de
        ret

; ---- present: copy shadow rows to hardware.  B=first row, C=row count ----
present_all:
        ld b,0
        ld c,ROWS
present_rows:
        call row_off            ; DE = offset
        ld (pr_off),de
        ld h,0
        ld l,c
        call mul80
        ld (pr_len),hl
        ld a,EXT_ON
        out (P_EXT),a
        ld hl,SCHR
        ld bc,SCRN
        call .cp
        ld a,EXT_ATTR
        out (P_EXT),a
        ld hl,SATR
        ld bc,SCRN
        call .cp
        ld a,EXT_ON
        out (P_EXT),a
        ld a,40h
        out (P_COL),a
        ld hl,SCOL
        ld bc,HIRAM
        call .cp
        xor a
        out (P_COL),a
        ret
.cp:    ld de,(pr_off)
        add hl,de
        push hl
        ld h,b
        ld l,c
        add hl,de
        ex de,hl
        pop hl
        ld bc,(pr_len)
        ldir
        ret

; ---- put one cell into shadow -------------------------------------
; DE = cell offset, H = screen code, L = PCG bank (0-7), A = colour
; mono mode: bank += 8, colour forced to 0Fh.  Preserves BC DE HL.
put_cell:
        push bc
        push hl
        ld c,a
        ld a,(mono)
        or a
        jr z,.c
        ld a,l
        add a,8
        ld l,a
        ld c,0Fh
.c:     ld b,l
        ld a,h
        ld hl,SCHR
        add hl,de
        ld (hl),a
        push de
        ld de,SCRSIZE
        add hl,de
        ld (hl),b
        add hl,de
        ld (hl),c
        pop de
        pop hl
        pop bc
        ret

; put a G-indexed PCG glyph: DE=offset, HL=G (0-1023), A=colour
put_g:
        push bc
        push hl
        push af
        ld a,l
        rla
        ld a,h
        rla                     ; A = G>>7
        ld b,a
        ld a,l
        or 80h
        ld h,a
        ld l,b
        pop af
        call put_cell
        pop hl
        pop bc
        ret

; put glyph using its default colour from char_col: DE=offset, HL=G
put_gc:
        push hl
        push bc
        ld bc,char_col
        add hl,bc
        ld a,(hl)
        pop bc
        pop hl
        jr put_g

; ---- text -----------------------------------------------------------
; puts: HL = 0-terminated string, DE = offset, A = colour.  Returns DE after.
puts:   ld (txtcol),a           ; text uses the Roman font in PCG bank FONT_BANK
.lp:    ld a,(hl)
        or a
        ret z
        push hl
        or 80h
        ld h,a
        ld l,FONT_BANK
        ld a,(txtcol)
        call put_cell
        pop hl
        inc hl
        inc de
        jr .lp

; puts_at: B=row C=col HL=string A=colour
puts_at:
        push af
        call row_off
        ld a,e
        add a,c
        ld e,a
        jr nc,.n
        inc d
.n:     pop af
        jr puts

; offset for B=row C=col -> DE
cell_off:
        call row_off
        ld a,e
        add a,c
        ld e,a
        ret nc
        inc d
        ret

; putch: A=char at DE with txtcol, DE++
putch:  push hl
        or 80h
        ld h,a
        ld l,FONT_BANK
        ld a,(txtcol)
        call put_cell
        pop hl
        inc de
        ret

; ---- numbers: HL -> decimal at DE (no leading zeros), colour txtcol ----
putnum: push bc                 ; (uses IX)
        ld ix,numbuf
        ld bc,-10000
        call .dig
        ld bc,-1000
        call .dig
        ld bc,-100
        call .dig
        ld bc,-10
        call .dig
        ld a,l
        add a,'0'
        ld (ix+0),a
        ld (ix+1),0
        ; skip leading zeros
        ld hl,numbuf
.sk:    ld a,(hl)
        cp '0'
        jr nz,.pr
        inc hl
        ld a,(hl)
        or a
        jr nz,.sk
        dec hl
.pr:    ld a,(txtcol)
        call puts
        pop bc
        ret
.dig:   ld a,'0'-1
.d1:    inc a
        add hl,bc
        jr c,.d1
        sbc hl,bc
        ld (ix+0),a
        inc ix
        ret

; pad: write A spaces at DE
putspc: or a
        ret z
        push bc
        ld b,a
.l:     ld a,' '
        call putch
        djnz .l
        pop bc
        ret

; ---- direct hardware colour poke (cursor): DE=offset, A=colour ----
hw_colour:
        push hl
        push af
        ld a,40h
        out (P_COL),a
        ld hl,HIRAM
        add hl,de
        pop af
        ld (hl),a
        xor a
        out (P_COL),a
        pop hl
        ret

; swap nibbles of A
swapnib:
        rrca
        rrca
        rrca
        rrca
        ret
