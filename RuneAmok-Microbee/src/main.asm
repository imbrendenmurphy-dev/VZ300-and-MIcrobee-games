; =====================================================================
;  RUNE AMOK - The Vault of the Hollow King
;  A first-person dungeon crawl for the Microbee Premium Plus.
;  VIBED BY BPM 2026
;
;  1MB RAM, 32K PCG, the 40-column mode (40 x 25 cells of 8 x 10).
;  The view is composed from pre-rendered tiles (tools/views.py,
;  tools/walls.py, tools/sprites.py), so a step costs a tile list walk
;  and about 1,150 bytes of video writes in the blanking.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"

        ORG $8000
entry:  di
        ld sp,STACK
        ld hl,VARS
        ld de,VARS+1
        ld bc,$4FF
        ld (hl),0
        ldir
        call hw_init
        call snd_init
        call ui_init
.main:  call front_end          ; title, story, controls: returns to play
        call new_game
        call play
        jr .main

; ---------------------------------------------------------------------
;  one frame: sound until the vertical blanking, then the blanking's
;  video work, then the input
; ---------------------------------------------------------------------
frame:
        call snd_field          ; plays until the blanking starts
        call vb_commit
        call vb_anim
        call vb_ui
        ld hl,tick
        inc (hl)
        call snd_tick
        jp read_input

; wait A frames
frames: or a
        ret z
.l:     push af
        call frame
        pop af
        dec a
        jr nz,.l
        ret

; ESC: give CP/M its screen back and warm-boot (what MODES.COM does)
quit:   di
        ld sp,STACK
        xor a
        out (P_PIOB),a          ; speaker off
        in a,(P_CLK40)          ; the normal dot clock (A = 0)
        ld hl,crtc80
        call crtc_set
        ld a,(EXIT_VID)
        or MP_SAVE
        out (P_MEM),a           ; block 16 low, video window as CP/M has it
        ld a,$81
        out (P_LV),a
        ld hl,$2000
        ld de,PCGWIN
        ld bc,$800
        ldir
        ld a,$80
        out (P_LV),a
        ld hl,$1800
        ld de,PCGWIN
        ld bc,$800
        ldir
        ld a,COL_ON
        out (P_COLCTL),a
        ld hl,$1000
        ld de,PCGWIN
        ld bc,$800
        ldir
        xor a
        out (P_COLCTL),a
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,$0800
        ld de,VIDEO
        ld bc,$800
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ld hl,$0000
        ld de,VIDEO
        ld bc,$800
        ldir
        xor a
        out (P_LV),a
        ; CP/M's BIOS back (E000-EFFF, saved by the loader) - this RAM
        ; held our variables and stack, so nothing may use them now
        ld a,(EXIT_PORT)
        ex af,af'
        ld hl,$2800
        ld de,$E000
        ld bc,$1000
        ldir
        ex af,af'
        out (P_MEM),a           ; CP/M's own lower block
        ei
        jp 0                    ; CP/M warm boot

        INCLUDE "video.asm"
        INCLUDE "view.asm"
        INCLUDE "input.asm"
        INCLUDE "ui.asm"
        INCLUDE "game.asm"
        INCLUDE "combat.asm"
        INCLUDE "sound.asm"
        INCLUDE "front.asm"
        INCLUDE "../build/gen.inc"
        INCLUDE "tables.asm"
        INCLUDE "texts.asm"
prog_end:
        ASSERT prog_end <= MAP
        DISPLAY "program ends ", prog_end
        INCLUDE "vars.asm"
        SAVEBIN "../build/RUNE.BIN",$8000,prog_end-$8000
