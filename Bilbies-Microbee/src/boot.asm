; start-up: the front end, or (tests) one level played once
start:	ld a,(boot_mode)
	or a
	jp z,front_main
	call hud_glyphs
	ld a,(boot_mono)
	ld (monomode),a
	ld a,(boot_level)
	call level_load
	ld a,(boot_mode)
	cp 1			; 1 = played by its script, 2 = by the test's input
	ld a,1
	jr z,.d
	xor a
.d:	ld (v_demo),a
	ld (v_test),a
	call play_level
	ld a,1
	ld (boot_done),a
.halt:	call vschk
	jr .halt
boot_mode	db 0		; (poked by the test tools)
boot_level	db 0
boot_mono	db 0
boot_done	db 0
