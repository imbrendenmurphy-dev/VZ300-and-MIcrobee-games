; =====================================================================
;  fe.asm - the front end, upper bank 0 (mapping 3), from OVCOM.DAT
;  Interrupts are off throughout; music plays in each frame's idle time.
; =====================================================================
            include "gen/mainsym.inc"
            org $B800
j_fe_main:      jp title_main
j_fe_transfer:  jp xfer_main
j_fe_lift:      jp lift_main
j_fe_console:   jp console_main
j_fe_shipcard:  jp shipcard_main
j_fe_shipdone:  jp shipdone_main
j_fe_gameover:  jp gameover_main
j_fe_ending:    jp ending_main

            include "fesys.asm"
            include "title.asm"
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
par_x:      ds 4
par_t:      ds 1
tk_p:       ds 2
tk_n:       ds 1
re_y:       ds 1
hs_n:       ds 1
he_slot:    ds 1
he_name:    ds 2
he_pos:     ds 1
fe_end:
            assert fe_end <= FEBB
