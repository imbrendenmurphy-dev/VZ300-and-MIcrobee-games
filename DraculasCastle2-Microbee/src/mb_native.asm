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
            call wait_frame
            call vram_black             ; nothing stale shows during the mode change
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

; LZ2 decoder. The packed input is streamed through a buffer in
; upper RAM ($D600, 1K), refilled from its bank before it can run short, so a
; token never has to check the buffer: literals are one LDIR, matches one
; LDIR. Destination: unpack_bank, or RAM 2. DE = where to write.
DECBUF      equ $D600
native_unpack:
            ld a,(unpack_bank)
            or a
            jr nz,.dest
            ld a,2
.dest:      ld (dec_dest),a
            ld hl,DECBUF+1024
            call dec_refill
.token:     ld a,h
            cp (DECBUF>>8)+3
            call nc,dec_refill
            ld a,(hl)
            inc hl
            bit 7,a
            jr nz,.match
            inc a
            ld c,a
            ld b,0
            ldir
            jr .token
.match:     ld b,a
            ld a,(hl)
            inc hl
            push hl
            cpl
            ld l,a
            ld a,b
            and $0F
            cpl
            ld h,a
            add hl,de               ; HL = DE - offset - 1
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
            ex (sp),hl
            ld a,(hl)
            inc hl
            ex (sp),hl
            cp $FF
            jr z,.end
            add a,10
            ld c,a
            ld a,b
            adc a,0
            ld b,a
.copy:      ldir
            pop hl
            jr .token
.end:       pop hl
            ret

; Keep the unread bytes from HL, then fill the buffer up from the source.
dec_refill: push de
            ld a,(native_anim_loading)
            or a
            jr z,.move
            push hl
            call wait_frame         ; the Ghost's poses load while the tune plays
            pop hl
.move:      ld de,DECBUF
            push hl
            ld hl,DECBUF+1024
            pop bc
            or a
            sbc hl,bc               ; bytes still unread
            ld a,h
            or l
            jr z,.fill
            push hl
            ld h,b
            ld l,c
            pop bc
            ldir
.fill:      ld hl,DECBUF+1024
            or a
            sbc hl,de
            ld b,h
            ld c,l
            ld a,(native_bank)
            call mb_bank
            ld hl,(native_src)
            ldir
            ld (native_src),hl
            ld a,(dec_dest)
            call mb_bank
            ld hl,DECBUF
            pop de
            ret

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

