; Native 40x32 / 8x8 PCG presentation. Assets decompress into RAM block 2.
; Compressed input is streamed via upper RAM, never mapped over the decoder.
native_enter:
            xor a
            ld (native_anim_enabled),a
            ld (world_loaded),a
            ld (native_page),a
            ld a,1
            in a,($09)             ; half-rate Premium video clock
            ld hl,native_crtc
            call native_crtc_set
            ld a,1
            ld (native_active),a
            ret
native_crtc: db 53,40,44,$34,38,0,32,35,$48,7,$20,0,0,0,0,0
native_crtc_set:
            ld c,0
.loop:      ld a,c
            out ($0C),a
            ld a,(hl)
            out ($0D),a
            inc hl
            inc c
            ld a,c
            cp 16
            jr nz,.loop
            ret

native_leave:
            xor a
            ld (native_anim_enabled),a
            ld (world_loaded),a
            in a,($09)
            ld hl,mb_crtc
            call native_crtc_set
            xor a
            ld (native_active),a
            ld (native_battle_active),a
            out ($0B),a
            out ($08),a
            ld a,14
            call mb_bank
            ld hl,0
            ld d,$80
.pcg:       ld a,d
            out ($1C),a
            push de
            ld de,$F800
            ld bc,$0800
            ldir
            pop de
            inc d
            ld a,d
            cp $90
            jr nz,.pcg
            ld a,1
            call mb_bank
            ld a,$80
            out ($1C),a
            jp mb_invalidate

; Standalone title; gallery/combat use shared-glyph groups. Select mono variant.
native_show:
            push ix
            push af
            xor a
            ld (native32_scene),a
            pop af
            ld a,(mb_mode)
.index:     ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,native_assets
            add hl,de
            ld a,(hl)
            ld (native_bank),a
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld (native_src),de
            xor a
            ld (native_left),a
            ld a,2
            call mb_bank
            ld de,0
            call native_unpack
            call native32_blank
            xor a
            out ($0B),a
            out ($08),a
            ld hl,0
            ld d,$80
            ld b,10
.pcg:       ld a,d
            out ($1C),a
            push bc
            push de
            ld de,$F800
            ld bc,2048
            ldir
            pop de
            pop bc
            inc d
            djnz .pcg
            ld a,2
            ld (native32_from),a
            ld hl,$5000
            ld de,$0A00
            ld bc,1280
            call native32_copy
            ld hl,0
            ld de,0
            ld bc,1280
.codes:     ld a,l
            or $80
            ld (de),a
            inc hl
            inc de
            dec bc
            ld a,b
            or c
            jr nz,.codes
            ld hl,0
            ld de,$0500
            ld bc,1280
.attrs:     push bc
            ld a,l
            rlca
            and 1
            ld b,a
            ld a,h
            add a,a
            or b
            ld (de),a
            pop bc
            inc hl
            inc de
            dec bc
            ld a,b
            or c
            jr nz,.attrs
            call native32_font
            call native32_commit
            pop ix
            ret

native_get:
            ld a,(native_left)      ; fast path: the next byte is buffered
            or a
            jr z,.refill
            dec a
            ld (native_left),a
            push hl
            ld hl,(native_read)
            ld a,(hl)
            inc hl
            ld (native_read),hl
            pop hl
            ret
.refill:    push bc
            push de
            push hl
            ld a,(native_anim_loading)
            or a
            jr z,.fetch
            ld a,(native_anim_load_tick)
            inc a
            and 7
            ld (native_anim_load_tick),a
            call z,wait_frame
.fetch:
            ld a,(native_bank)
            call mb_bank
            ld hl,(native_src)
            ld de,$E300
            ld bc,128
            ldir
            ld (native_src),hl
            ld a,(unpack_bank)
            or a
            jr nz,.destination
            ld a,2
.destination:
            call mb_bank
            ld hl,$E300
            ld (native_read),hl
            ld a,128
            ld (native_left),a
.ready:     ld hl,native_left
            dec (hl)
            ld hl,(native_read)
            ld a,(hl)
            inc hl
            ld (native_read),hl
            pop hl
            pop de
            pop bc
            ret

native_unpack:
.token:     call native_get
            bit 7,a
            jr nz,.match
            inc a
            ld b,a
.literal:   ld a,(native_left)
            or a
            jr nz,.buffered
            call native_get
            ld (de),a
            inc de
            djnz .literal
            jr .token
.buffered:  cp b
            jr c,.partial
            sub b
            ld (native_left),a
            ld c,b
            xor a
            jr .literal_copy
.partial:   ld c,a
            xor a
            ld (native_left),a
            ld a,b
            sub c
.literal_copy:
            push af
            ld b,0
            ld hl,(native_read)
            ldir
            ld (native_read),hl
            pop af
            or a
            jr z,.token
            ld b,a
            jr .literal
.match:     ld b,a
            call native_get
            cpl
            ld l,a
            ld a,b
            and $0F
            cpl
            ld h,a
            add hl,de
            ld a,b
            rrca
            rrca
            rrca
            rrca
            and 7
            add a,3
            ld c,a
            ld b,0
            cp 10
            jr nz,.copy
            call native_get
            cp $FF
            ret z
            add a,10
            ld c,a
            ld a,0
            adc a,0
            ld b,a
.copy:      ldir
            jr .token

; HL = zero-terminated ASCII, DE = F000-based destination cell.
native_text:
            ld c,15
native_text_colour:
            ld a,3
            call mb_bank
.next:      ld a,(hl)
            or a
            ret z
            inc hl
            push hl
            push de
            sub 32
            or $80
            call native32_char
            pop de
            pop hl
            inc de
            jr .next

            include "gen/native.inc"

