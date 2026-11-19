; =====================================================================
;  BELLARIUS!
;  a comedy shoot-'em-up for the Microbee Premium Plus (1MB RAM, 32K PCG)
;  VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"

        ORG $8000
entry:  di
        ld sp,STACK
        call hw_init
        jp start

        INCLUDE "core.asm"
        INCLUDE "input.asm"
        INCLUDE "render.asm"
        INCLUDE "sound.asm"
        INCLUDE "stage.asm"
        INCLUDE "game.asm"
        INCLUDE "player.asm"
        INCLUDE "enemy.asm"
        INCLUDE "boss.asm"
        INCLUDE "hud.asm"
        INCLUDE "frontstub.asm"
        INCLUDE "notes.inc"
        INCLUDE "gen.inc"
code_end:
        ASSERT code_end <= OVL
        SAVEBIN "../build/SKY.BIN",$8000,code_end-$8000
        DISPLAY "code end: ",code_end

; the tunes live in the front block's lower window copy (sound_tick maps it)
        ORG MUSIC_AT
mus_start:
        INCLUDE "music.inc"
mus_end:
        ASSERT mus_end <= $8000
        SAVEBIN "../build/MUS.BIN",MUSIC_AT,mus_end-MUSIC_AT
        DISPLAY "music: ",mus_end-MUSIC_AT

        ORG VARS
        INCLUDE "vars.asm"
        ASSERT vars_end <= STACK-256
        DISPLAY "vars end: ",vars_end
