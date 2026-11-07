; =====================================================================
;  uB-TYPE  -  for the Microbee Premium Plus
;  A conversion of VZ-TYPE (VZ300). The game logic is VZ-TYPE's own
;  (game.asm, enemy.asm, boss.asm, vzeng.asm), in the same coordinates
;  and at the same 25 frames per second; the display, sound output,
;  input and presentation are new for the Premium's PCG graphics.
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"

NENT	equ 20
ENTSZ	equ 16
NSHOT	equ 10
NBUL	equ 12
NBUL_THIN equ 6		; at most this many when thinning
PFH	equ 56			; playfield height (VZ pixel rows)
NTR	equ 14			; tile rows

E_TYPE	equ 0
E_X	equ 1
E_Y	equ 2
E_HP	equ 3
E_ST	equ 4
E_TM	equ 5
E_FR	equ 6
E_VX	equ 7
E_VY	equ 8
E_P1	equ 9
E_P2	equ 10
E_P3	equ 11
E_SPR	equ 12
E_W	equ 13
E_H	equ 14
E_FL	equ 15
FL_TERR	equ 1
FL_INV	equ 2
FL_HARM	equ 4
FL_FLASH equ 8

T_SWIM	equ 1
T_DART	equ 2
T_TURF	equ 3
T_TURC	equ 4
T_HOP	equ 5
T_CARR	equ 6
T_SPIN	equ 7
T_GUNS	equ 8
T_SPORE	equ 9
T_FRAG	equ 10
T_CAPS	equ 11
T_EXPL	equ 12
T_BOSS	equ 13
T_BORB	equ 14
T_SNAKE	equ 15
T_SEG	equ 16
T_SSEG	equ 17
T_BPART	equ 18
T_CORE	equ 19

; =====================================================================
	ORG $8000
start:	di
	ld sp,STACKTOP
	im 1
	ld hl,code_end		; variables start at zero
	ld de,code_end+1
	ld bc,vars_end-code_end-1
	ld (hl),0
	ldir
	call hw_init
	ld hl,$1234
	ld (rseed),hl
	xor a
	ld (trainer),a
	ld (demomode),a
	call gfx_load
	ld a,(protostage)	; (test harness: straight into a stage)
	inc a
	jp z,fe_boot
	dec a
	ld (lvlnum),a
	jp new_game_at

	INCLUDE "core.asm"
	INCLUDE "eng.asm"
	INCLUDE "hud.asm"
	INCLUDE "stage.asm"
	INCLUDE "vzeng.asm"
	INCLUDE "game.asm"
	INCLUDE "enemy.asm"
	INCLUDE "boss.asm"
	INCLUDE "bosscell.asm"
	INCLUDE "demo.asm"
	INCLUDE "dcache.asm"
	INCLUDE "../build/vzdata.inc"
SP_BIG	equ NSPR
code_end:

; =====================================================================
;  variables and buffers (upper block, below the stack)
; =====================================================================
vcount	ds 1
vblast	ds 1
frame	ds 1
inp	ds 1
joyraw	ds 1
inpold	ds 1
inpedge	ds 1
joyok	ds 1
rseed	ds 2
pbank	ds 1
trainer	ds 1
demomode ds 1
sats	ds 1
sx1	ds 1
sy1	ds 1
sx2	ds 1
sy2	ds 1
scrollx	ds 2
scol	ds 2
gencol	ds 2
scrollon ds 1
scrolled ds 1
lvlcols	ds 2
lvlnum	ds 1
loopn	ds 1
lvlptr	ds 2
objptr	ds 2
objbase	ds 2
spnptr	ds 2
spnbase	ds 2
palT	ds 1
palA	ds 1
palB	ds 1
palC	ds 1
palcss	ds 1
px	ds 1
py	ds 1
pspeed	ds 1
pstate	ds 1
ptimer	ds 1
pinv	ds 1
firehold ds 1
charge	ds 1
podst	ds 1
podx	ds 1
pody	ds 1
podw	ds 1
podfr	ds 1
score	ds 3
hiscore	ds 3
lives	ds 1
nextlife ds 1
hudflag	ds 1
bossidx	ds 1
bossent	ds 2
bosshp	ds 1
lvldone	ds 1
deadtm	ds 1
sfxper	ds 1
sfxcnt	ds 1
sfxon	ds 1
sfxdp	ds 1
sfxnz	ds 1
sfxpri	ds 1
sfxfr	ds 1
sfxptr	ds 2
spkbit	ds 1
tmp1	ds 2
tmp2	ds 2
lastchg	ds 1
bgbaked	ds 1
bodybaked ds 1
snkhead	ds 2
snkhist	ds 128
fstars	ds 2*20
ENTS	ds NENT*ENTSZ
SHOTS	ds NSHOT*8
BULS	ds NBUL*8
hitab	ds 5*8
; ---- renderer state
rpage	ds 1
phase	ds 1
pstart	ds 2
nextstart ds 2
dispstart ds 2
curL	ds 2
lastLA	ds 2
pphaseA	ds 1
lastLB	ds 2
pphaseB	ds 1
poolbank ds 1
poolnext ds 1
qptr	ds 2
qnA	ds 1
qnB	ds 1
pcgblk	ds 1
tabblk	ds 1
bandrow	ds 1
bandcol	ds 1
starcol	ds 1
colbuf	ds 3*PROWS
	ALIGN 16
BGBUF	ds 16
QA	ds 2*320
QB	ds 2*320
STQA	ds 3*13+2
STQB	ds 3*13+2
	ALIGN 256
HUDC	ds 256			; codes (128 used), page aligned
HUDA	ds 256
HUDK	ds 256
hudndif	ds 1
hudall	ds 1
hudlastA ds 2
hudlastB ds 2
	ALIGN 256
BOUNCE	ds 256
PROFR	ds 256
TRING	ds 64*16
LVLBUF	ds 2048
BOSSBUF	ds $490
; boss-part glyph cache (dcache.asm)
	ALIGN 256
CMAP	ds 2048			; cached glyph code per ring cell
CTABA	ds 6*64			; boss-part caches, page A (6 x 64)
CTABB	ds 6*64			; page B
vars_end:
STACKTOP equ $EFFE
	DISPLAY "vars_end ",/H,vars_end
	ASSERT vars_end <= $EE00

	DISPLAY "code end: ",/H,code_end,"  vars end: ",/H,vars_end
	SAVEBIN "../build/UBTYPE.BIN",$8000,code_end-$8000
	ASSERT code_end <= $C000	; (the loader copies 4000h bytes)

; =====================================================================
;  the front-end overlay: assembled to run at FEBASE, over the level
;  buffers; stored in block 1 (FRONT.BNK) and copied in when needed
; =====================================================================
FEBASE	equ PROFR
	ORG FEBASE
	INCLUDE "front.asm"
fe_end:
FE_SIZE	equ fe_end-FEBASE
	ASSERT fe_end <= $EE00
	DISPLAY "front end: ",/H,FEBASE,"-",/H,fe_end
	SAVEBIN "../build/FRONT.BNK",FEBASE,FE_SIZE
