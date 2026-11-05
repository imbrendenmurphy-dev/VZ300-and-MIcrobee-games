; ===================================================================
;  EMPIRES : THE LIVING WORLD
;  An original civilisation / city-building game for the
;  Microbee Premium Plus (80x24, 32K PCG, colour + monochrome)
;  ViBED by BPM 2026
;
;  CP/M .COM - launch from the DOS prompt:  A>EMPIRES
; ===================================================================
        include "defs.inc"

        org 0100h
start:  ld (oldsp),sp
        ld sp,stacktop
        ; enough TPA?  BDOS entry (0006h) must be above our top of memory
        ld hl,(6)
        ld de,MEMTOP
        or a
        sbc hl,de
        jr nc,.memok
        ld de,txt_nomem
        ld c,9
        call 5
        ld sp,(oldsp)
        ret
.memok: di
        ; remember the DOS screen colour so we can restore it on exit
        ld a,40h
        out (P_COL),a
        ld a,(HIRAM)
        ld (dos_colour),a
        xor a
        out (P_COL),a
        ld a,r
        ld (seed),a
        ld a,1
        ld (sound_on),a
        call video_init
        ld a,20h                ; serial TXD at mark, speaker off
        out (P_PIOB),a
        call mouse_init
        call pcg_clear
        call pcg_upload         ; pattern data is overwritten by the maps after this
        call startup_choice
menu:   call title_screen
        or a
        jr z,exit_dos
        call wait_release
        ld a,C_TEXT
        call shadow_clear
        call present_all
        ld b,10
        ld c,30
        ld hl,txt_building_world
        ld a,C_TITLE
        call puts_at
        call present_all
        call generate_world
        call new_game
        ld hl,tune_start
        call play_tune
        xor a
        ld (quit_flag),a
        call game_loop
        call wait_release
        jr menu

exit_dos:
        ; restore a clean DOS screen
        ld a,(dos_colour)
        call shadow_clear
        call present_all
        call pcg_clear
        xor a
        out (P_EXT),a           ; extended graphics off (attributes ignored)
        out (P_COL),a
        ld a,20h
        out (P_PIOB),a
        ei
        ld de,txt_bye
        ld c,9
        call 5
        jp 0                    ; warm boot back to the A> prompt

txt_nomem:  db "EMPIRES needs more free memory (TPA).",13,10,"$"
txt_bye:    db 26,"Thanks for playing EMPIRES : THE LIVING WORLD - ViBED by BPM",13,10,"$"
txt_building_world: db "BUILDING A NEW WORLD",0

        include "video.asm"
        include "input.asm"
        include "mouse.asm"
        include "sound.asm"
        include "worldgen.asm"
        include "render.asm"
        include "game.asm"
        include "title.asm"
        include "art.inc"
        include "vars.asm"
; ---- boot-only PCG patterns live where the world maps go ----
TERR    equ $
        include "art_pcg.inc"
OBJ     equ TERR+MAPSIZE
MEMTOP  equ OBJ+MAPSIZE
        assert pcg_end <= MEMTOP
