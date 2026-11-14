; =====================================================================
;  GALAHXY                                        VIBED BY BPM 2026
;  main program (GALAHXY.VZ, loads at $8000)
; =====================================================================
            include "defs.asm"
            include "vars.asm"
            org $8000
entry:      di
            ld sp,STACK_TOP
            jp boot

            include "sys.asm"
            include "sd.asm"
            include "blit.asm"
            include "scroll.asm"
            include "sound.asm"
            include "text.asm"
            include "player.asm"
            include "objects.asm"
            include "hud.asm"
            include "game.asm"
            include "shop.asm"

; ---------------------------------------------------------------------
boot:
            ; where does the DOS sit? (SRAM -> mapping 1, ROM -> 0) - as 13 Ghosts
            ld hl,$5FFF
            ld b,(hl)
            ld a,b
            cpl
            ld (hl),a
            ld a,(hl)
            xor b
            ld (hl),b
            and 1
            ld (dos_map),a
            ld (cur_map),a
            ld hl,VARS
            ld de,VARS+1
            ld bc,BB-VARS-1
            push af
            ld (hl),0
            ldir
            pop af
            ld (dos_map),a
            ld (cur_map),a
            ld hl,$6A5B
            ld (rng),hl
            ld a,L_MODE|L_SPK0      ; main palette (CSS0); pastel stages set CSS1
            ld (latchv),a
            ld a,HIGH(BB)
            ld (bbh),a
            ld (cps),a
            ; the 128K expansion: SRAM bank 3 must hold its own data
            ld a,MAP_GAME
            out (BANKPORT),a
            ld hl,$5000
            ld (hl),$A5
            ld a,(hl)
            cp $A5
            jp nz,no_sram
            ld (hl),$5A
            ld a,(hl)
            cp $5A
            jp nz,no_sram
            ld hl,$C000             ; and the upper bank
            ld (hl),$C3
            ld a,(hl)
            cp $C3
            jp nz,no_sram
            ld a,(dos_map)
            out (BANKPORT),a
            call boot_msg
            call joy_detect
            ld hl,n_com
            call sd_load
            jp c,load_fail
            ld a,MAP_GAME
            call setmap
            call init_im2
            call silence
            xor a
            call cls_bb
            ld a,(latchv)
            ld (LATCH),a
            ld a,1
            ld (diff),a
            ld (start_stage),a
            ld a,$FF
            ld (stage_ld),a
; ---- the shell: front end (pack 0) <-> the game (packs 1..)
shell:      ld sp,STACK_TOP
            xor a
            ld (demo_on),a
            ld (in_game),a
            call load_pack
            jr c,shell
            call FE_TITLE           ; A = 0 play, 1 run the demo
            or a
            jr nz,.demo
            ld a,(fe_sel)
            call new_game
            ld a,(trainer)
            or a
            jr nz,shell
            xor a
            call load_pack
            jr c,shell
            ld a,L_MODE|L_SPK0      ; the front end is always in the main palette
            ld (latchv),a
            ld a,(game_won)
            or a
            call nz,FE_ENDING
            call FE_SCORES
            jr shell
.demo:      ld a,1
            ld (demo_on),a
            ld hl,1500
            ld (demo_t),hl
            ld hl,attract_n         ; each demo shows the next stage
            ld a,(hl)
            inc a
            cp NSTAGES+1
            jr c,.d1
            ld a,1
.d1:        ld (hl),a
            ld (start_stage),a
            call random
            and 3
            cp 3
            jr c,.d2
            xor a
.d2:        call new_game
            xor a
            ld (demo_on),a
            ld (demo_in),a
            ld a,(in_demokey)
            ld (fe_skip),a
            jr shell

n_com:      db '"GLXCOM"',0

; text-mode message while loading
boot_msg:
            xor a
            ld (LATCH),a
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,511
            ld (hl),$60
            ldir
            ld hl,str_boot
            ld de,VRAM+32*7+9
print0:     ld a,(hl)
            or a
            ret z
            and $3F
            ld (de),a
            inc hl
            inc de
            jr print0
str_boot:   db "GALAHXY LOADING",0

no_sram:    ld hl,str_nosram
            jr fatal
load_fail:  ld hl,str_nofile
fatal:      di
            push hl
            ld a,(dos_map)
            out (BANKPORT),a
            xor a
            ld (LATCH),a
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,511
            ld (hl),$20
            ldir
            pop hl
            ld de,VRAM+32*7+1
            call print0
.h:         jr .h
str_nosram: db "NEEDS BENNVENN SD + 128K RAM",0
str_nofile: db "CAN'T LOAD GLXCOM.DAT",0
str_ver:    db "GLX*.DAT FILES DON'T MATCH",0

            include "gen/sine.inc"
            include "gen/buildid.inc"
code_end:
            assert code_end <= VARS

; ---------------------------------------------------------------------
; GLXCOM.DAT: common sprites + front end (upper bank 1, $E400-$FFFF)
; and the logo / high scores (bank 3, $5E00-$66FF)
; ---------------------------------------------------------------------
            org COM_HI
            include "gen/comspr.inc"
            include "boss.asm"
com_hi_end:
            assert com_hi_end <= BB1
            org COM_LO
            include "gen/font.inc"
            include "gen/txtab.inc"
            include "gen/comspr_lo.inc"
            include "gen/sound.inc"
            include "comtext.asm"
com_lo_end:
            assert com_lo_end <= HISCORES

; ---------------------------------------------------------------------
; the pack being built (GLXSn.DAT, $B800-$E3FF): tools/build.py picks it
; ---------------------------------------------------------------------
            include "gen/stage.inc"
