; =====================================================================
;  BILBIES! for the Microbee Premium Plus
;  an original puzzle game by BPM: guide the bilbies home
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"
VARBASE	equ $CC00
GVARS	equ $E910
WSCRIPT	equ WHDR+$100
STACK	equ $EFF0

	ORG $8000
entry:	di
	ld sp,STACK
	call hw_init
	call render_init
	jp start

	INCLUDE "core.asm"
	INCLUDE "render.asm"
	INCLUDE "game.asm"
	INCLUDE "play.asm"
	INCLUDE "hud.asm"
	INCLUDE "sound.asm"
	INCLUDE "music.asm"
	INCLUDE "tables.asm"
	INCLUDE "spridx.inc"
	INCLUDE "levels.asm"
	INCLUDE "front.asm"
	INCLUDE "save.asm"
	INCLUDE "boot.asm"
	INCLUDE "levels.inc"
code_end:
	ASSERT code_end <= VARBASE
	INCLUDE "vars.asm"
	ASSERT $ <= STACK-256
	SAVEBIN "../build/BILBIES.BIN",$8000,code_end-$8000
