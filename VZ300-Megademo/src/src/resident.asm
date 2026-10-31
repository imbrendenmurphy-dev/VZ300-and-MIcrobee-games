; =====================================================================
;  VZ300 MEGADEMO 2026  -  ViBED by BPM
;  Resident core: engine, music, SD streaming, demo script.
;  Target: VZ300 + BennVenn SD loader (128K SRAM). Loads at $8000.
;  Parts are overlays streamed from VZMEGA.DAT into OVL.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "engine.inc"
        INCLUDE "../build/layout.inc"

        org $8000
start:
        di
        ld sp,STACKTOP
        im 1
        ld a,M0
        ld (LATCH),a
        call snd_silence
        ld a,$80
        call cls
        call calibrate
        call sram_test
        call sd_open
        jp c,no_data
        call music_init
        IFDEF STARTORD
        ld b,STARTORD
.sk:    push bc
        call m_load_order
        pop bc
        djnz .sk
        ENDIF
        ; ---- demo script ----
        ; part table entries: bank-1 sectors, overlay sectors (0 = end)
        ld hl,part_table
.next:  ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        or a
        jr z,.end
        push hl
        push af
        ld a,c
        or a
        jr z,.nob1
        ; preload a payload into SRAM bank 1 ($4000-$67FF) via the overlay area
        ld b,c
        push bc
        ld hl,OVL
        call sd_read
        pop bc
        ld a,(sram_ok)
        or a
        jr z,.nob1
        ld h,b
        ld l,0
        add hl,hl               ; bytes = sectors*512
        ld b,h
        ld c,l
        ld a,3
        out ($37),a
        ld hl,OVL
        ld de,$4000
        ldir
        ld a,1
        out ($37),a
.nob1:  pop af
        ld b,a
        ld hl,OVL
        call sd_read
        call OVL
        ld a,1
        out ($37),a             ; DOS bank back in (parts may have used bank 1)
        di
        pop hl
        jr .next
.end:   ; demo finished
        IFDEF LOOPTEST
        jp start
        ENDIF
        jr .end

no_data:
        ld a,$20
        call cls
        ld hl,msg_nodata
        ld de,VRAM+32*7
        ld bc,32
        ldir
.h:     jr .h
msg_nodata:
        db 22,26,13,5,7,1,46,4,1,20,32,14,15,20,32,6,15,21,14,4,32,15,14,32,19,4,32,3,1,18,4,32
        ; "VZMEGA.DAT NOT FOUND ON SD CARD "

; ---------------------------------------------------------------------
; SRAM bank test: can we use bank 1 of $4000-$67FF (port $37 = 3)
; without disturbing the DOS in bank 0?   sram_ok = 1 if yes.
; ---------------------------------------------------------------------
sram_ok: db 0
sram_test:
        ; 1) read-only check: with port $37 = 3 the DOS jump table at $5F00
        ;    must NOT be visible (otherwise bank select does nothing and a
        ;    write would corrupt the DOS)
        ld hl,$5F00
        ld de,sram_buf
        ld bc,16
        ldir
        ld a,3
        out ($37),a
        ld hl,$5F00
        ld de,sram_buf
        ld b,16
        ld c,0
.cmp:   ld a,(de)
        cp (hl)
        jr z,.same
        inc c
.same:  inc hl
        inc de
        djnz .cmp
        ld a,1
        out ($37),a
        ld a,c
        or a
        jr z,.fail              ; identical -> no separate bank
        ; 2) write / read back in bank 1
        ld a,3
        out ($37),a
        ld hl,$6700
        ld (hl),$A5
        inc hl
        ld (hl),$5A
        ld a,1
        out ($37),a
        ld a,($5F00)            ; DOS must still be intact
        ld hl,sram_buf
        cp (hl)
        jr nz,.fail
        ld a,3
        out ($37),a
        ld hl,$6700
        ld a,(hl)
        cp $A5
        jr nz,.fail
        inc hl
        ld a,(hl)
        cp $5A
        jr nz,.fail
        ld a,1
        out ($37),a
        ld a,1
        ld (sram_ok),a
        ret
.fail:  ld a,1
        out ($37),a
        xor a
        ld (sram_ok),a
        ret
sram_buf: ds 16


        INCLUDE "core.asm"
        INCLUDE "music.asm"
        INCLUDE "speech.asm"
part_table:
        INCLUDE "../build/parts.inc"
        db 0,0
        INCLUDE "../build/song.inc"
resident_end:
        DISPLAY "resident end: ", resident_end
        SAVEBIN "../build/resident.bin", start, resident_end - start
