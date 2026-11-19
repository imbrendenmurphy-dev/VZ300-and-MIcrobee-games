; Microbee Premium, 40 x 25 x 10 PAL. 32 KB PCG, double buffered, 2 KB VDU.
NATIVE equ $8000
DIRTY_LIST equ $C000
hw_init:
        ld a,4
        ld (text_origin),a
        ld (sprite_origin),a
        ld a,$04
        out ($50),a
        xor a
        out ($0B),a
        out ($08),a
        ld a,$CF
        out ($03),a
        ld a,$BF
        out ($03),a
        ld a,7
        out ($03),a
        ld a,1
        in a,($09)
        ; Black-on-black colour RAM first, so CP/M's font and colours are never
        ; shown in the new 40x25 mode before the first game frame is uploaded.
        ld a,$80
        out ($1C),a
        ld a,$40
        out ($08),a
        ld hl,$F800
        ld de,$F801
        ld bc,2047
        ld (hl),0
        ldir
        xor a
        out ($08),a
        ld hl,crtc_table
        ld c,0
.crtc:  ld a,c
        out ($0C),a
        ld a,(hl)
        out ($0D),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.crtc
        ; Unique PCG character for each displayed 8 x 10 cell.
        ld a,$80
        out ($1C),a
        ld hl,$F000
        ld bc,2048
.screen:ld a,l
        or $80
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.screen
        ld a,$90
        out ($1C),a
        ld hl,$F000
        ld de,0
        ld bc,2048
.attr:  ld a,d
        add a,a
        bit 7,e
        jr z,.even
        inc a
.even:  ld (hl),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.attr
        ld a,$80
        out ($1C),a
        ld hl,NATIVE
        ld de,NATIVE+1
        ld bc,16000-1
        ld (hl),0
        ldir
        ld hl,DIRTY_LIST
        ld (dirty_end),hl
        ld hl,$D000
        ld (dirty_end1),hl
        ld a,1
        ld (draw_page),a
        ret
crtc_table: db $35,$28,$2C,$34,$1E,$03,$19,$1C,$48,$09,$20,$09,0,0,0,0

; A = Microbee matrix key (A..Z = 1..26, SPACE=55, RETURN=59).
; CRTC update-address scan; Z if released. Preserves BC,DE,HL.
scan_key:
        push bc
        push de
        ld c,a
        rrca
        rrca
        rrca
        rrca
        and 3
        ld d,a
        ld a,18
        out ($0C),a
        ld a,d
        out ($0D),a
        ld a,19
        out ($0C),a
        ld a,c
        rlca
        rlca
        rlca
        rlca
        out ($0D),a
        ld a,1
        out ($0B),a
        ld a,16
        out ($0C),a
        in a,($0D)
        ld a,31
        out ($0C),a
        out ($0D),a
        ld b,64
.wait:  in a,($0C)
        bit 7,a
        jr nz,.sample
        djnz .wait
        xor a
        jr .done
.sample:in a,($0C)
        and $40
.done:  ld d,a
        xor a
        out ($0B),a
        ld a,16
        out ($0C),a
        in a,($0D)
        ld a,d
        or a
        pop de
        pop bc
        ret

; Queue the cell containing HL. Row bytes 0..9, colour 14, dirty 15.
; No scan of unchanged cells is needed during flush.
dirty_cell:
        push hl
        push de
        push af
        ld a,l
        or 15
        ld l,a
        bit 0,(hl)
        jr nz,.second
        set 0,(hl)
        push hl
        ld a,l
        and $F0
        ld l,a
        ex de,hl
        ld hl,(dirty_end)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (dirty_end),hl
        pop hl
.second:bit 1,(hl)
        jr nz,.done
        set 1,(hl)
        ld a,l
        and $F0
        ld l,a
        ex de,hl
        ld hl,(dirty_end1)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (dirty_end1),hl
.done:  pop af
        pop de
        pop hl
        ret

video_flush:
        call video_upload
.wait:  in a,($0C)
        and $20
        jr z,.wait
        jp video_present
; Upload the queued cells of the back page: 10 glyph rows to PCG and the
; colour byte to colour RAM. Per-page constants are worked out once per call.
video_upload:
        ld a,(draw_page)
        or a
        ld hl,(dirty_end)
        ld de,DIRTY_LIST
        ld bc,$FE80             ; page 0: PCG select $80, dirty-flag mask ~1
        jr z,.page
        ld hl,(dirty_end1)
        ld de,$D000
        ld bc,$FD88             ; page 1: PCG select $88, dirty-flag mask ~2
.page:  ld (vu_end),hl
        ld a,c
        ld (vu_sel),a
        ld a,b
        ld (vu_mask),a
        ld a,(draw_page)
        add a,a
        add a,a
        add a,$F8
        ld (vu_colhi),a         ; colour RAM page high byte
        ex de,hl                ; HL = list pointer
.next:  call hw_clock
        ex de,hl
        ld hl,(vu_end)
        or a
        sbc hl,de
        jr z,.done
        ex de,hl
        ld e,(hl)               ; DE = queued cell in NATIVE
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld a,d                  ; PCG bank = page*8 + (cell-$8000)>>11
        sub $80
        rrca
        rrca
        rrca
        and 7
        ld hl,vu_sel
        or (hl)
        out ($1C),a
        push de
        ex de,hl                ; HL = cell, DE = $F800 + glyph offset
        ld a,h
        and 7
        or $F8
        ld d,a
        ld e,l
        REPT 10
        ldi
        ENDR
        ld a,l                  ; HL = cell+10 -> colour at +14, flags at +15
        or 14
        ld l,a
        ld c,(hl)
        inc hl
        ld a,(vu_mask)
        and (hl)
        ld (hl),a               ; this page's copy is now current
        pop hl                  ; colour RAM = page base + (cell-$8000)/16
        ld a,h
        sub $80
        ld h,a
        REPT 4
        srl h
        rr l
        ENDR
        ld a,(vu_colhi)
        add a,h
        ld h,a
        ld a,$80
        out ($1C),a
        ld a,$40
        out ($08),a
        ld (hl),c
        xor a
        out ($08),a
        pop hl
        jp .next
.done:  ld a,(draw_page)
        or a
        jr nz,.reset1
        ld hl,DIRTY_LIST
        ld (dirty_end),hl
        jr .sync
.reset1:ld hl,$D000
        ld (dirty_end1),hl
.sync:  ret
video_present:
        call hw_clock
        ld a,12
        out ($0C),a
        ld a,(draw_page)
        rlca
        rlca
        out ($0D),a
        ld a,13
        out ($0C),a
        xor a
        out ($0D),a
        ld a,(draw_page)
        xor 1
        ld (draw_page),a
        ret

; Count real PAL edges during rendering. Busy scenes can skip a displayed
; frame without slowing the game rules, timers and movement by the same amount.
hw_clock:
        push af
        push hl
        in a,($0C)
        and $20
        ld hl,hw_vblank
        cp (hl)
        jr z,.done
        ld (hl),a
        or a
        jr z,.done
        ld hl,hw_pending
        ld a,(hl)
        cp 4
        jr nc,.done
        inc (hl)
.done:  pop hl
        pop af
        ret

; 20-column map coordinates. All helpers preserve BC,DE,HL.
row20:
        push bc
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,a
        add a,a
        pop bc
        ret
cell_col:
        sub 20
        jr nc,cell_col
        add a,20
        ret
cell_row:
        push bc
        ld b,0
.loop:  sub 20
        jr c,.done
        inc b
        jr .loop
.done:  ld a,b
        pop bc
        ret

