; =====================================================================
;  fe.asm - the front end, upper bank 0 (mapping 3), from OVCOM.DAT
;  Interrupts are off throughout; music plays in each frame's idle time.
;  The title, attract pages and cards live in the overlay OVTTL.DAT
;  ($4000, low bank 3), loaded whenever no deck is live.
; =====================================================================
            include "gen/mainsym.inc"
            org $B800
j_fe_main:      jp title_main
j_fe_transfer:  jp xfer_main
j_fe_lift:      jp lift_main
j_fe_console:   jp console_main
j_fe_shipcard:  jp shipcard_ent
j_fe_shipdone:  jp shipdone_ent
j_fe_gameover:  jp gameover_ent
j_fe_ending:    jp ending_ent

OV_ATTRACT  equ $4000
OV_SHIPCARD equ $4003
OV_SHIPDONE equ $4006
OV_GAMEOVER equ $4009
OV_ENDING   equ $400C

; the attract loop: the overlay's intro, title and pages, then a game
; (or the demo), round and round
title_main:
            ld a,$08
            call fe_setlatch
            call hi_init
            xor a
            ld (t_tune),a
            ld (r_page),a
.loop:      call ov_load
            ld a,0
            jr c,.go                ; no overlay: straight into a game
            call OV_ATTRACT         ; A = 0 play, 1 demo
.go:        push af
            call m_stop
            xor a
            ld (t_tune),a
            pop af
            call game_new
            ld a,$08
            call fe_setlatch
            jr .loop

; load the overlay (C if it can't be read)
ov_load:
            call m_stop
            ld hl,ov_name
            jp sd_load
ov_name:    db '"OVTTL"',0

; the cards: load the overlay over the (finished) deck, then run them
shipcard_ent:
            ld hl,OV_SHIPCARD
            jr ov_run
shipdone_ent:
            ld hl,OV_SHIPDONE
            jr ov_run
gameover_ent:
            ld hl,OV_GAMEOVER
            jr ov_run
ending_ent:
            ld hl,OV_ENDING
ov_run:
            push hl
            call ov_load
            pop hl
            ret c
            jp (hl)

            include "fesys.asm"
            include "fecommon.asm"
            include "xfer.asm"
            include "lift.asm"
            include "gen/songs.inc"
            include "gen/fedata.inc"

; ---- front-end variables
t_buf:      ds 40
t_buf2:     ds 40
t_time:     ds 2
t_tune:     ds 1
r_page:     ds 1
re_y:       ds 1
fe_end:
            assert fe_end <= FEBB
