; =====================================================================
;  fe0.asm - pack 0 (GLXS0.DAT, $B800-$E3FF): the front end.
;  Built like a stage so the title can scroll its own backdrop:
;  title, high scores, cast select, name entry and the ending.
; =====================================================================
            org STAGE
            jp f0_init
            jp f0_ret
            jp f0_ret
            jp f0_ret
            jp f0_ret
            jp seg_next
            jp f0_ret
            dw GTILES, STILES, SMAP, f0_segs, 0, 0
            org FE_TITLE
            jp title_screen
            jp fe_scores
            jp ending
            org STG_SPRTAB
            include "gen/stg_spr_tab.inc"
            org STG_CODE
f0_segs:    dw GMAP_TITLE, TITLE_C, $FFFF : db SG_LOOP
f0_init:    ld a,L_MODE|L_SPK0
            ld hl,f0_tl
            ld de,tune_title
            jp stg_setup
f0_ret:     ret
f0_tl:      dw $7FFF : db TL_END

fe_scores:  call hi_enter
            ret

            include "fe.asm"
            include "hiscore.asm"
            include "ending.asm"
hi_default: db "GX"
            db $00,$50,$00,"BPM"
            db $00,$40,$00,"GAZ"
            db $00,$30,$00,"CUP"
            db $00,$25,$00,"TST"
            db $00,$20,$00,"PAV"
            db $00,$15,$00,"SNG"
            db $00,$10,$00,"ESK"
            db $00,$05,$00,"MAG"
            include "gen/logo.inc"
            include "gen/stg_tunes.inc"
            include "gen/stg_scen.inc"
            include "gen/stg_spr_rec.inc"
stg_end:
            assert stg_end <= STAGE_END
