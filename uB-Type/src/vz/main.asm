; =====================================================================
;  VZ-TYPE  -  an original horizontal shooter for the Dick Smith VZ300
;  Target: VZ300 + BennVenn 128K / SD loader. Loads as .VZ at $8000.
;  All code, graphics, levels and music are original.
; =====================================================================
	DEVICE NOSLOT64K

LATCH	equ $6800
VRAM	equ $7000
COMPOSE	equ $4000		; 64 rows x 32 bytes off-screen frame
SHB	equ $4800		; 4 pre-shifted background buffers, $800 apart
ROWB	equ 36			; ring width (bytes) of each shift buffer
PFH	equ 56			; playfield height (pixel rows)
NTR	equ 14			; tile rows
NENT	equ 20
ENTSZ	equ 16
NSHOT	equ 10
NBUL	equ 12

; ---- entity field offsets
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
; flags
FL_TERR	equ 1		; scrolls with the terrain
FL_INV	equ 2		; shots pass through / no damage
FL_HARM	equ 4		; harmless to player (explosions)
FL_FLASH equ 8

; ---- enemy types
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
;  variables ($7800-$7FFF, stack grows down from $8000)
; =====================================================================
	ORG $7A00
latch	ds 1
vcount	ds 1
fsprev	ds 1
frame	ds 1
inp	ds 1
inpold	ds 1
inpedge	ds 1
joyok	ds 1
rseed	ds 2
idlec	ds 2
dbgcol	ds 2
pbank	ds 1
fe_built ds 1		; front-end caches valid (kept in main RAM: the game writes it)
trainer	ds 1
sats	ds 1
sx1	ds 1
sy1	ds 1
sx2	ds 1
sy2	ds 1
scrollx	ds 2
scol	ds 2
gencol	ds 2
vring	ds 1
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
dsW	ds 1
dsH	ds 1
dsSkip	ds 1
dsCnt	ds 1
dsRows	ds 1
dsSS	ds 1
sfxper	ds 1
sfxcnt	ds 1
sfxon	ds 1
sfxdp	ds 1
sfxnz	ds 1
sfxpri	ds 1
sfxfr	ds 1
sfxptr	ds 2
tmp1	ds 2
tmp2	ds 2
hcol	ds 1
hudblit	ds 1
lastchg	ds 1
snkhead	ds 2
snkhist	ds 128
cache_tab ds 6*72
fstars	ds 2*20
ENTS	ds NENT*ENTSZ
SHOTS	ds NSHOT*8
BULS	ds NBUL*8
hitab	ds 5*8			; 5 entries: 3 score bytes + 3 name chars + 2 pad
VAREND

; =====================================================================
	ORG $8000
start:
	di
	ld sp,$8000
	im 1
	ld a,$01		; speaker legs (bits 0 and 5) must start opposite
	ld (latch),a
	ld (LATCH),a
	ld a,$80
	ld (fsprev),a
	ld hl,$1234
	ld (rseed),hl
	ld hl,0
	ld (dbgcol),hl
	xor a
	ld (trainer),a
	ld (fe_built),a		; trainer mode is off until T is pressed on the title
	; joystick present?  floating/absent interfaces read $FF (= nothing pressed)
	in a,($2C)
	and $1f
	ld (joyok),a		; 0 -> pins all low -> ignore joystick
	ld hl,VRAM		; black screen while the front end unpacks
	ld de,VRAM+1
	ld bc,511
	ld (hl),$80
	ldir
	; unpack the front end into the second 10K SRAM bank (port $37 = 3);
	; the game itself only ever uses the home bank (port $37 = 1)
	ld a,3
	out ($37),a
	ld hl,ovlpak
	ld de,OVL
	call unlzb
	call init_hiscores
	jp title

; ---------------------------------------------------------------------
;  utilities
; ---------------------------------------------------------------------
jphl:	jp (hl)

rnd:	; returns A random (8-bit Galois LFSR on 16 bits)
	push hl
	ld hl,(rseed)
	add hl,hl
	jr nc,.n
	ld a,l
	xor $2d
	ld l,a
.n:	ld (rseed),hl
	ld a,l
	add a,h
	pop hl
	ret

; vsync edge counter: call often (gaps < 12000 T). keeps all regs but AF
vschk:	ld a,(LATCH)
	and $80
	jr z,.low
	ld (fsprev),a
	ret
.low:	ld a,(fsprev)
	or a
	ret z
	xor a
	ld (fsprev),a
	ld a,(vcount)
	inc a
	ld (vcount),a
	ret

; ---------------------------------------------------------------------
;  SOUND EFFECTS. An effect is: priority, then segments of
;  (frames, period, delta/frame, flags) ending with 0. flags: 1 = noise.
;  sfx_frame steps the envelope once per game update; the speaker is
;  driven from the idle loop (sfx_out) and once per row while the screen
;  and background are copied (sndrow), so effects keep sounding through
;  the busy parts of the frame.
; ---------------------------------------------------------------------
waitframe:
.w:	ld hl,(idlec)
	inc hl
	ld (idlec),hl
	call vschk
	ld a,(vcount)
	cp 2
	jr nc,.done
	ld a,(sfxon)
	or a
	jr z,.w
	ld hl,sfxcnt
	dec (hl)
	jr nz,.w
	call sfx_tog
	jr .w
.done:	xor a
	ld (vcount),a
	jp sfx_frame

; wait for one vsync edge (front end use)
vsync1:	xor a
	ld (vcount),a
.l:	call vschk
	ld a,(vcount)
	or a
	jr z,.l
	ret

; per-row speaker service (keeps BC,DE,HL); a row is ~3 idle-loop units
sndrow:	ld a,(sfxon)
	or a
	ret z
	ld a,(sfxcnt)
	sub 3
	jr z,.t
	jr c,.t
	ld (sfxcnt),a
	ret
.t:	push hl
	call sfx_tog
	pop hl
	ret
sfx_tog:	; toggle the speaker and reload the period counter (keeps BC,DE)
	ld a,(latch)
	xor $21
	ld (latch),a
	ld (LATCH),a
	ld a,(sfxnz)
	or a
	ld a,(sfxper)
	jr z,.s
	ld hl,(rseed)
	add hl,hl
	jr nc,$+4
	ld a,l
	xor $2d
	ld l,a
	ld (rseed),hl
	ld a,(sfxper)
	and l
	or 1
.s:	ld (sfxcnt),a
	ret

sfx_frame:
	ld a,(sfxon)
	or a
	ret z
	ld a,(sfxdp)
	ld hl,sfxper
	add a,(hl)
	jr nz,$+4
	ld a,1
	ld b,a
	ld a,(sfxdp)
	bit 7,a
	ld a,b
	jr nz,.dn
	cp (hl)
	jr nc,.ok		; no wrap upwards
	ld a,255
	jr .ok
.dn:	cp (hl)
	jr c,.ok
	jr z,.ok
	ld a,1			; no wrap downwards
.ok:	ld (hl),a
	ld hl,sfxfr
	dec (hl)
	ret nz
	ld hl,(sfxptr)
	jr sfx_seg

; start effect HL (if its priority is at least the current one's)
sfx:	ld a,(sfxon)
	or a
	jr z,.go
	ld a,(sfxpri)
	cp (hl)
	jr z,.go
	ret nc
.go:	ld a,(hl)
	ld (sfxpri),a
	inc hl
sfx_seg:	; HL -> segment
	ld a,(hl)
	or a
	jr z,.end
	ld (sfxfr),a
	inc hl
	ld a,(hl)
	ld (sfxper),a
	ld (sfxcnt),a
	inc hl
	ld a,(hl)
	ld (sfxdp),a
	inc hl
	ld a,(hl)
	ld (sfxnz),a
	inc hl
	ld (sfxptr),hl
	ld a,1
	ld (sfxon),a
	ret
.end:	xor a
	ld (sfxon),a
	ret

; charging whine: a soft rising tone while fire is held (lowest priority)
sfx_charge:
	ld a,(sfxon)
	or a
	jr z,.go
	ld a,(sfxpri)
	cp 2
	ret nc
.go:	ld a,1
	ld (sfxpri),a
	ld (sfxfr),a
	ld (sfxon),a
	ld a,(charge)
	srl a
	cpl
	add a,44		; 44 - charge/2 : pitch rises with charge
	ld (sfxper),a
	xor a
	ld (sfxdp),a
	ld (sfxnz),a
	ld hl,sfx_null
	ld (sfxptr),hl
	ret
sfx_null	db 0

; ---- effects (all original): pri, {frames,period,delta,noise}..., 0
sfx_shot:	db 2,  2,9,3,0, 1,16,0,0, 0
sfx_beam:	db 5,  2,6,-1,0, 3,4,2,0, 10,5,2,1, 0
sfx_beam1:	db 4,  2,10,-2,0, 6,8,3,1, 0
sfx_pop:	db 3,  2,5,0,0, 6,6,3,1, 0
sfx_hit:	db 2,  1,5,0,0, 1,30,0,1, 0
sfx_clank:	db 3,  1,4,0,0, 2,9,4,0, 2,8,0,1, 0
sfx_boom:	db 6,  3,8,4,1, 12,24,3,1, 0
sfx_bigboom:	db 8,  4,6,2,1, 10,18,3,1, 20,40,4,1, 0
sfx_die:	db 9,  4,8,-1,0, 4,10,6,0, 30,20,3,1, 0
sfx_power:	db 7,  3,28,0,0, 3,22,0,0, 3,18,0,0, 5,14,0,0, 0
sfx_life:	db 9,  3,20,0,0, 3,16,0,0, 3,13,0,0, 3,10,0,0, 3,13,0,0, 6,10,0,0, 0
sfx_pod:	db 4,  6,40,-5,0, 0
sfx_podback:	db 4,  6,12,5,0, 0
sfx_caps:	db 5,  2,12,0,0, 2,9,0,0, 2,12,0,0, 2,9,0,0, 0
sfx_open:	db 2,  4,30,-4,0, 0
sfx_expose:	db 8,  4,30,-3,0, 4,40,-3,0, 6,50,-4,0, 0
sfx_ebul:	db 1,  2,20,6,0, 0
sfx_warn:	db 7,  6,20,0,0, 6,28,0,0, 6,20,0,0, 6,28,0,0, 6,20,0,0, 6,28,0,0, 0
sfx_clear:	db 9,  4,24,0,0, 4,20,0,0, 4,16,0,0, 4,12,0,0, 10,10,0,0, 0

; read keyboard + joystick -> inp (bit0 up,1 down,2 left,3 right,4 fire,5 pod)
readinp:
	ld c,0
	ld a,($68FE)		; Q
	bit 4,a
	jr nz,$+4
	set 0,c
	ld a,($68FD)		; A
	bit 4,a
	jr nz,$+4
	set 1,c
	ld a,($68BF)		; O / P
	bit 1,a
	jr nz,$+4
	set 2,c
	bit 4,a
	jr nz,$+4
	set 3,c
	ld a,($68EF)		; SPACE / M
	bit 4,a
	jr nz,$+4
	set 4,c
	bit 5,a
	jr nz,$+4
	set 5,c
	ld a,($68FB)		; Z also launches/recalls the pod
	bit 4,a
	jr nz,$+4
	set 5,c
	ld a,(joyok)
	or a
	jr z,.nj
	in a,($2C)
	cpl
	and $0f
	or c
	ld c,a
	in a,($2E)
	bit 4,a
	jr nz,$+4
	set 4,c
	in a,($2D)
	bit 4,a
	jr nz,$+4
	set 5,c
.nj:	ld a,(inp)
	ld (inpold),a
	cpl
	and c
	ld (inpedge),a
	ld a,c
	ld (inp),a
	ret

anykey:	; NZ if any key / fire is down
	ld a,($6800)
	and $3f
	cp $3f
	ret nz
	ld a,(joyok)
	or a
	ret z
	in a,($2E)
	cpl
	and $10
	ret

; ---- LZB unpack: HL = packed source, DE = destination (see lzb.py)
unlzb:	ld (lzb_tab),hl
	ld bc,16
	add hl,bc
	ld a,(hl)
	ld (lzb_n),a
	inc hl
	ld a,(hl)
	ld (lzb_n+1),a
	inc hl
	ld c,$80
.loop:	push hl
	ld hl,(lzb_n)
	ld a,h
	or l
	pop hl
	ret z
	call gbit
	jr c,.match
	call gbit
	jr c,.lit8
	ld b,4
	call gbits
	push hl
	ld hl,(lzb_tab)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	jr .put
.lit8:	ld b,8
	call gbits
.put:	ld (de),a
	inc de
	push hl
	ld hl,(lzb_n)
	dec hl
	ld (lzb_n),hl
	pop hl
	jr .loop
.match:	ld b,1
.gz:	call gbit
	jr c,.g1
	inc b
	jr .gz
.g1:	ld a,1
	dec b
	jr z,.gd
.gl:	call gbit
	rla
	djnz .gl
.gd:	inc a
	ld (lzb_len),a
	call gbit
	jr c,.o12
	ld b,7
	call gbits
	ld b,0
	jr .od
.o12:	ld b,4
	call gbits
	ld (lzb_hi),a
	ld b,8
	call gbits
	push af
	ld a,(lzb_hi)
	ld b,a			; B = high 4 bits
	pop af
.od:	; A = low byte, B = high: copy from DE - (B:A) - 1
	push hl
	push bc
	ld c,a
	ld a,e
	sub c
	ld l,a
	ld a,d
	sbc a,b
	ld h,a
	dec hl
	pop bc			; restore bit buffer in C
	push bc
	ld a,(lzb_len)
	ld c,a
	ld b,0
	ldir
	pop bc
	; n -= len
	ld hl,(lzb_n)
	ld a,(lzb_len)
	push de
	ld e,a
	ld d,0
	or a
	sbc hl,de
	ld (lzb_n),hl
	pop de
	pop hl
	jp .loop
gbits:	xor a			; B bits -> A
.l:	call gbit
	rla
	djnz .l
	ret
gbit:	sla c			; next bit -> carry
	ret nz
	ld c,(hl)
	inc hl
	scf
	rl c
	ret
lzb_tab	dw 0
lzb_n	dw 0
lzb_len	db 0
lzb_hi	db 0

clearcompose:
	ld hl,COMPOSE
	ld de,COMPOSE+1
	ld bc,2047
	ld (hl),0
	ldir
	ret

; copy compose to video RAM (races ahead of the beam)
blit:	ld hl,COMPOSE
	ld de,VRAM
	ld a,(hudblit)
	or a
	ld a,56
	jr z,.r
	xor a
	ld (hudblit),a
	ld a,64
.r:	REPT 32
	ldi
	ENDR
	ex af,af'
	call sndrow
	ex af,af'
	bit 4,a
	jr z,.nc
	ex af,af'
	call vschk
	ex af,af'
.nc:	dec a
	jr nz,.r
	ret

	INCLUDE "engine.asm"
	INCLUDE "game.asm"
	INCLUDE "enemy.asm"
	INCLUDE "parallax.asm"
	INCLUDE "boss.asm"
	INCLUDE "data.inc"

; ---- front end lives in SRAM bank 3 at $4300; the game uses bank 1
fe_stage_intro:
	ld a,3
	out ($37),a
	call stage_intro
	jr bank1
fe_congrats:
	ld a,3
	out ($37),a
	call congrats
bank1:	ld a,1
	out ($37),a
	ret
fe_quit:	; leave a game early: trainer games go straight to the title
	ld a,3
	out ($37),a
	ld a,(trainer)
	or a
	jp z,game_over
	jp title
fe_game_over:
	ld a,3
	out ($37),a
	jp game_over
codeend:			; (the packed front end below is only needed at boot)
ovlpak:	INCBIN "ovl.pak"
imgend:

; ---- runtime tables (not saved in the .VZ)
RT	equ (codeend+255) & $ff00
TRING	equ RT			; 64 cols x 16 bytes
PROFR	equ RT+$400		; terrain profile ring
TILEG	equ RT+$500		; 64 tiles x 4 (remapped)
LVLBUF	equ RT+$600		; unpacked stage data, then the sprite caches
REMAPT	equ $4000		; level-start only tables live in the idle compose buffer
REMAPD	equ $4100
MASKT	equ $4200
THTMP	equ $4300		; theme tiles + far band, unpacked at stage start
FARBUF	equ $7800		; 4 shifts x 8 rows x 16 bytes far parallax band
SP_BIG	equ NSPR
	ASSERT LVLBUF+LVNEED <= $10000
	DISPLAY "free at top: ",/D,$10000-LVLBUF-LVNEED

	ASSERT imgend <= $F9F0
	SAVEBIN "vztype.bin",$8000,imgend-$8000

; =====================================================================
	ORG $4300		; front end runs from the BennVenn SRAM (game buffers live there in play)
OVL:
	INCLUDE "front.asm"
	INCLUDE "music.asm"
	INCLUDE "fdata.inc"
ovlend:
	ASSERT ovlend <= $6800
	ASSERT FECSZ+7*4*GLH*2 <= $D00
	ASSERT LVLBUF+$E00+GLH*32 <= $10000
	DISPLAY "overlay size: ",/D,ovlend-OVL
	SAVEBIN "ovl.bin",OVL,ovlend-OVL
