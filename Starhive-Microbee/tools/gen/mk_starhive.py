"""Build src/starhive.asm from src/shiptest.asm (the engine test) by
swapping the test objects for the game."""
from pathlib import Path
R = Path(__file__).resolve().parents[2]
s = (R / 'src/shiptest.asm').read_text()


def rep(a, b):
    global s
    assert a in s, a[:90]
    s = s.replace(a, b)


def between(a, b, new):
    global s
    i = s.index(a)
    j = s.index(b, i)
    s = s[:i] + new + s[j:]


rep(s[:s.index("\tDEVICE")], """; =====================================================================
;  S T A R H I V E  -  a vertical shoot-'em-up for the Microbee Premium
;  Plus (40 x 24 characters of 8 x 11, frame always 312 lines)
;  Scenery fine scroll by PCG phase banks 0-10, far stars in bank 11,
;  sprites composed into double-buffered pools (banks 12-15) and written
;  row by row just ahead of the beam. 25 frames a second.
;  VIBED BY BPM 2026
; =====================================================================
""")
rep("""	ld a,2
	ld (speed),a
	ld (fields),a
	ld (spdshow),a
""", """	ld a,2
	ld (fields),a
	ld a,ST_TITLE
	ld (state),a
	ld hl,hisc		; HI 005000
	ld (hl),0
	inc hl
	ld (hl),$50
	inc hl
	ld (hl),0
	ld hl,$ACE1
	ld (seed),hl
	xor a
	ld (spk),a
	ld (snd_len),a
	ld (level),a
	ld (calm),a
""")
between("""	ld hl,0
	ld (scrS),hl
	ld (page),a""", "	; load every pair of the first screen (group 21)",
        """	ld hl,0
	ld (scrS),hl
	ld (page),a
	ld (nslot),a
	ld (scrolled),a
	ld (sp_count),a
	ld a,BLK_W		; no sprite cells yet
	call blkport
	out (P_MEM),a
	call buckets_clear
""")
rep("""	ld a,1
	ld (hudd),a
	call star_off
main:""", """	call star_off
	call state_init
main:""")
rep("""main:	call vschk		; (fields) fields since the last commit?""", """main:	call vschk		; steady pacing: 2 fields a frame (25 fps),
	ld a,(vbcount)		; or 3 for a while after a frame that
	cp 2			; needed more than 2
	jr c,.fit
	ld a,3
	ld (fields),a
	ld a,100
	ld (calm),a
	jr .pace
.fit:	ld hl,calm
	ld a,(hl)
	or a
	jr z,.two
	dec (hl)
	jr .pace
.two:	ld a,2
	ld (fields),a
.pace:	call vschk		; (fields) fields since the last commit?""")
rep(""".wt:	call vblank		; no: wait for them""", """.wt:	call vblank_snd		; no: wait for them""")
rep(""".late:	call vblank		; overran: on the next edge""", """.late:	call vblank_snd		; overran: on the next edge""")
between("""	call advance
	call vschk
	call readinp""", """	ld a,(fields)
	add a,a
	add a,2			; loads per frame""",
        """	call advance
	call vschk
	call game_tick
	call vschk
	ld a,BLK_W
	call blkport
	out (P_MEM),a
	call frame_begin
	call draw_game
	call vschk
	call finish_frame
	call vschk
""")
rep(""".cl:
	ld a,(s88)""", """.cl:	ld a,c
	ld (scrolled),a
	ld a,(s88)""")
between("keys:\tld hl,speedkeys", "; count rising edges", """; wait for a rising edge of vertical blanking, playing the sound
vblank_snd:
	in a,(P_CRTCA)
	and $20
	jr z,.w
	call snd_step
	jr vblank_snd
.w:	call snd_step
	in a,(P_CRTCA)
	and $20
	jr z,.w
	ret

""")
between("; HUD buffers from the texts", "; wait for a rising edge of vertical blanking, playing",
        (R / 'tools/gen/hud.asm.txt').read_text())
rep("""	INCLUDE "objs.asm"
""", """	INCLUDE "game.asm"
""")
rep("""objs_init:			; px, py, drones (copied at the start)
	dw 152+16
	db 190+16, 4
objs_init_end:
""", "")
rep("""frame	ds 1
firecd	ds 1
dphase	ds 1
dl_frame ds 2
px	ds 2
py	ds 1
ndr	ds 1
drones	ds NDRONE*3
shots	ds NSHOTS*3
buls	ds NBULS*3
""", (R / 'tools/gen/vars.asm.txt').read_text())
rep("""	ld a,LV_SCREEN
	out (P_LV),a
	ld a,2
	ld (fields),a""", """	ld a,LV_SCREEN|13	; overlays: bullets in bank 13, shots in 15
	out (P_LV),a
	ld hl,ovl_bul_gl
	ld b,ovl_bul_n
	call ovl_up
	ld a,LV_SCREEN|15
	out (P_LV),a
	ld hl,ovl_shot_gl
	ld b,ovl_shot_n
	call ovl_up
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,2
	ld (fields),a""")
rep("""; count rising edges""", """ovl_up:	ld de,PCGWIN		; B glyphs of 11 bytes from HL
.u:	push bc
	ld bc,CL
	ldir
	ld a,e
	add a,16-CL
	ld e,a
	jr nc,$+3
	inc d
	pop bc
	djnz .u
	ret

; count rising edges""")
rep('SAVEBIN "../build/SHIPTEST.BIN"', 'SAVEBIN "../build/STARHIVE.BIN"')
(R / 'src/starhive.asm').write_text(s)
print('src/starhive.asm written')
