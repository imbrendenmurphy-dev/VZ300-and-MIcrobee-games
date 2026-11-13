; =====================================================================
;  MICROBEE MEGADEMO 2026 - VIBED BY BPM 2026
;  for the Microbee Premium Plus (1MB RAM, 32K PCG)
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"

	ORG $8000
entry:	di
	ld sp,STACK
	jp start

	INCLUDE "kernel.s"
	INCLUDE "core.s"
	INCLUDE "demo.s"
	INCLUDE "music.s"
	INCLUDE "p_title.s"
	INCLUDE "p_twister.s"
	INCLUDE "p_plasma.s"
	INCLUDE "p_kefrens.s"
	INCLUDE "p_crt.s"
	INCLUDE "p_boot.s"
	INCLUDE "p_live.s"
	INCLUDE "p_fx.s"
	INCLUDE "p_credits.s"
	INCLUDE "p_vector.s"

script:
	dw crton_part
	dw bt_part
	dw title_part
	dw twister_part
	dw plasma_part
	dw kefrens_part
	dw live_part
	dw tunnel_part
	dw floor_part
	dw swirl_part
	dw twist_part
	dw vector_part
	dw credits_part
	dw crtoff_part
	dw 0

	INCLUDE "song.inc"
	INCLUDE "assets.inc"

prog_end:
	INCLUDE "vars.s"
	ASSERT vars_end <= LP
	SAVEBIN "../build/MEGA.BIN",$8000,prog_end-$8000
