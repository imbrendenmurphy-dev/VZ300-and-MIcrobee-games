; ===================================================================
;  EMPIRES : THE LIVING WORLD
;  An original civilisation / city-building game for the
;  Microbee Premium Plus (1MB RAM, 80x24, 32K PCG, colour + monochrome)
;  VIBED BY BPM 2026
;
;  Engine image: runs in block 0 at 8000-EFFF, started by EMPIRES.COM
;  (loader.asm).  The world map lives in banked RAM in the lower window.
;  One assembly produces three images:
;    EMPIRES.UP   engine          8000h  (block 0)
;    EMPIRES.OVL  overlay code    0000h  (block BLK_OVL)
;    EMPIRES.ART  PCG + animation 4000h  (block BLK_ART)
; ===================================================================
        include "defs.inc"

        org 8000h
        jp start
p_cpm_port:  db 0               ; 8003: set by the loader
p_cpm_block: db 0               ; 8004
p_result:    db 0               ; 8005: result of a loader disk job
        jp svc_resume           ; 8006: the loader returns here after a disk job

start:  ld sp,stacktop
        di
        ld a,0FFh
        ld (curband),a
        xor a
        call map_band           ; map band 0 in the lower window, video on
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
        call pio_setup
        ld a,20h                ; serial TXD at mark, speaker off
        out (P_PIOB),a
        call mouse_init
        call pcg_clear
        call pcg_upload
        ld hl,startup_choice
        call ovl_call
menu:   call title_screen
        or a
        jr z,exit_dos
        cp 3
        jr z,title_load
        call wait_release
        ld a,C_TEXT
        call shadow_clear
        call present_all
        ld b,10
        ld c,30
        ld hl,txt_building_world
        ld a,C_TITLE
        call puts_at_far
        call present_all
        call set_world_size
        call generate_world
        call new_game
        ld hl,scen_start
        call ovl_call
        ld hl,fx_start
        call sfx
        xor a
        ld (quit_flag),a
        call game_loop
        call wait_release
        jr menu

; ---- load a saved world from the title
title_load:
        call wait_release
        call read_heads
        ld a,1
        ld (fm_mode),a
        ld hl,file_menu
        call ovl_call
        ld a,(ovl_ret)
        or a
        jr z,menu
        and 0Fh
        call load_game
        or a
        jr z,.ok
        call sfx_error
        jr menu
.ok:    xor a
        ld (quit_flag),a
        ld (msgtimer),a
        ld hl,msg_loaded
        ld a,C_GOOD
        call set_msg
        call game_loop
        call wait_release
        jr menu

; ---- back to DOS: clean screen, then restore CP/M's memory from its
; snapshot with a stub in the unseen end of screen RAM (STUB, video window
; on), and return to the loader's resident code in CP/M's own block.
; The RAM hidden under the video window (F000-FFFF with the window off)
; holds part of CP/M's BIOS, so it must never be written.
exit_dos:
        ld a,(dos_colour)
        call shadow_clear
        call present_all
        call pcg_clear
        xor a
        out (P_EXT),a           ; extended graphics off (attributes ignored)
        out (P_COL),a
        ld a,20h
        out (P_PIOB),a
        call pio_restore
        di
        call map_home           ; video window on
        ld hl,exit_stub
        ld de,STUB
        ld bc,exit_stub_end-exit_stub
        ldir
        ld a,(p_cpm_port)
        ld (STUB+exit_cpm-exit_stub),a
        jp STUB
exit_stub:                      ; position independent
        ld a,BLK_CPM
        call blk_port
        out (P_MEM),a
        ld hl,0
        ld de,8000h
        ld bc,7000h
        ldir                    ; CP/M's upper memory is back (this engine is gone)
        db 3Eh                  ; ld a,n
exit_cpm:
        db 0
        and 0E7h                ; keep the video window on (at F000h) while we run in it
        out (P_MEM),a           ; lower window = CP/M's block
        jp 0103h                ; loader: svc_exit
exit_stub_end:
        assert exit_stub_end-exit_stub <= 120, "exit stub too long"

; PIO port A all inputs (joystick, parallel-port devices), as The Lantern
; Deep sets it; CP/M leaves it as the printer output port.
pio_setup:
        ld a,0CFh               ; mode 3 (bit control)
        out (P_PIOAC),a
        ld a,0FFh               ; every bit an input
        out (P_PIOAC),a
        ld a,07h                ; no interrupts from port A
        out (P_PIOAC),a
        ret
pio_restore:                    ; back to mode 0 (output) for the printer
        ld a,0Fh
        out (P_PIOAC),a
        ret


        include "banks.asm"
        include "video.asm"
        include "input.asm"
        include "mouse.asm"
        include "sound.asm"
        include "worldgen.asm"
        include "render.asm"
        include "game.asm"
        include "titleup.asm"
        include "save.asm"
        include "rivals.asm"
        include "art.inc"
        include "vars.asm"
engine_end:
        assert engine_end <= 0F000h, "engine image too big"
        savebin "../build/EMPIRES.UP",8000h,7000h

; ---- overlay block (lower window, 0000h) ----
        org 0000h
        include "overlay.asm"
        include "text.asm"
overlay_end:
        assert overlay_end <= 8000h, "overlay too big"
        savebin "../build/EMPIRES.OVL",0000h,8000h

; ---- art block (lower window, whole 32K) ----
        org 0000h
        include "art_pcg.inc"
        include "art_anim.inc"
art_end:
        assert art_end <= 8000h, "art too big"
        savebin "../build/EMPIRES.ART",0000h,8000h
