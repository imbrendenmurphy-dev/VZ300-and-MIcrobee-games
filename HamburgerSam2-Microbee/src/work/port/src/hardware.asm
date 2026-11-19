hw_init:
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
        ld a,1
        ld (draw_page),a
        ld hl,$8000
        ld (page_end),hl
        ld hl,NATIVE
        ld de,NATIVE+1
        ld bc,16000-1
        ld (hl),0
        ldir
        ld hl,DIRTY_LIST
        ld (dirty_end),hl
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
        ld a,(sprite_phase)
        or a
        jr z,.normal
        push hl
        ld a,l
        and $F0
        or 13
        ld l,a
        ld a,(hl)
        or a
        jr nz,.listed
        ld (hl),1
        ld a,l
        and $F0
        ld l,a
        ex de,hl
        ld hl,(old_end)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (old_end),hl
.listed:pop hl
.normal:ld a,l
        or 15
        ld l,a
        ld a,(hl)
        or a
        jr nz,.done
        ld (hl),1
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
.done:  pop af
        pop de
        pop hl
        ret

; Copy every dirty cell to the hidden PCG page.  Pass 1 moves the pixel
; rows (selecting a PCG bank only when it changes); pass 2 writes all the
; colour bytes with colour RAM switched in once, and clears the dirty marks.
video_flush:
        ld hl,(dirty_end)
        ld (list_stop),hl
        ld a,$FF
        ld (flush_bank),a
        ld a,(draw_page)
        rlca
        rlca
        rlca
        or $80
        ld (flush_page),a
        ld hl,DIRTY_LIST
.next:  ld de,(list_stop)
        or a
        sbc hl,de
        add hl,de
        jr z,.colours
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld a,h
        sub NATIVE/256
        rrca
        rrca
        rrca
        and 7
        ld c,a
        ld a,(flush_page)
        or c
        ld c,a
        ld a,(flush_bank)
        cp c
        jr z,.same
        ld a,c
        ld (flush_bank),a
        out ($1C),a
.same:  ld a,h
        and 7
        or $F8
        ld d,a
        ld e,l
        ld a,(mono_mode)
        or a
        jr nz,.mono
        REPT 10
        ldi
        ENDR
        jr .copied
.mono:  call transfer_mono
.copied:pop hl
        ld a,l
        and 31
        call z,hw_clock
        jr .next
.colours:
        ld a,$80
        out ($1C),a
        ld a,$40
        out ($08),a
        ld a,(draw_page)
        add a,a
        add a,a
        add a,$F8
        ld (flush_page),a
        ld hl,DIRTY_LIST
.cnext: ld de,(list_stop)
        or a
        sbc hl,de
        add hl,de
        jr z,.done
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld a,l
        or 14
        ld l,a
        ld c,(hl)
        inc l
        ld (hl),0
        and $F0
        ld l,a
        ld a,h
        sub NATIVE/256
        ld h,a
        REPT 4
        srl h
        rr l
        ENDR
        ld a,(flush_page)
        add a,h
        ld h,a
        ld a,(mono_mode)
        or a
        ld a,c
        jr z,.col
        ld a,15
.col:   ld (hl),a
        pop hl
        ld a,l
        and 31
        call z,hw_clock
        jr .cnext
.done:  xor a
        out ($08),a
        ld hl,DIRTY_LIST
        ld (dirty_end),hl
        ret

; A second complete 1000-character page uses PCG banks 8..15.
present:
        ld hl,(dirty_end)
        ld (current_end),hl
        ld ix,$8000
.merge: ld hl,(page_end)
        push ix
        pop de
        or a
        sbc hl,de
        jr z,.copy
        ld l,(ix+0)
        ld h,(ix+1)
        call dirty_cell
        inc ix
        inc ix
        jr .merge
.copy:  ld hl,(current_end)
        ld de,-DIRTY_LIST
        add hl,de
        ld b,h
        ld c,l
        ld de,$8000
        ld hl,DIRTY_LIST
        ld a,b
        or c
        jr z,.empty
        ldir
.empty: ld (page_end),de
        call video_flush
        ld a,12
        out ($0C),a
        ld a,(draw_page)
        add a,a
        add a,a
        out ($0D),a
        ld a,13
        out ($0C),a
        xor a
        out ($0D),a
        ld a,(draw_page)
        xor 1
        ld (draw_page),a
        ret
transfer_mono:
        push hl
        ld a,l
        or 14
        ld l,a
        ld a,(hl)
        and 15
        ld hl,mono_masks
        call idx_byte
        ld c,a
        pop hl
        ld b,10
.row:   ld a,(hl)
        and c
        ld (de),a
        inc hl
        inc de
        rrc c
        djnz .row
        ret
mono_masks: db 0,$88,$AA,$AA,$88,$88,$AA,$EE,$AA,$AA,$EE,$FF,$AA,$EE,$EE,$FF

