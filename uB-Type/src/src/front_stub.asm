; prototype front end: straight into stage 1, no screens yet
title:	ld a,(protostage)
	ld (lvlnum),a
	jp proto_game
proto_game:
	xor a
	ld (score),a
	ld (score+1),a
	ld (score+2),a
	ld (loopn),a
	ld a,3
	ld (lives),a
	ld a,1
	ld (nextlife),a
	xor a
	ld (podst),a
	ld (podw),a
	ld (sats),a
	ld a,1
	ld (pspeed),a
	jp level_start
protostage db 0
fe_stage_intro:
	ret
fe_congrats:
	ret
fe_quit:
	jp title
fe_game_over:
	jp title
init_hiscores:
	ld hl,hitab
	ld b,40
.c:	ld (hl),0
	inc hl
	djnz .c
	ld a,2
	ld (hiscore),a
	xor a
	ld (hiscore+1),a
	ld (hiscore+2),a
	ret
demo_input:
	ret
demo_check:
	jp mainloop
