; =====================================================================
;  HUD: two character rows (rows 14-15) kept in buffers and written into
;  the page on screen after every flip (the page scroll moves them)
;
;  row 14:  SCORE 000000   BEAM [========================]  HI 000000  ST 1
;  row 15:  ship icons     SPEED >>>    POD S    HELPERS H
; =====================================================================
G_METER	equ $C0			; meter glyphs: $C0 + pixels filled (0..8)
G_LIFE	equ $C9			; ship icon (2 cells)
G_PIP	equ $CB			; speed pip on / off
G_PIPOFF equ $CC
G_LBRK	equ $CD			; meter brackets
G_RBRK	equ $CE
HM0	equ 21			; meter cells (always rewritten)
HM1	equ 46

C_LABEL	equ $06			; cyan
C_DIGIT	equ $0F			; white
C_METER	equ $0B			; yellow
C_METERF equ $09		; red when full
C_LIFE	equ $0E
C_WPN	equ $0D

hud_init:
	ld hl,HUDC
	ld bc,128
	ld e,BLANK_CODE
	call fill
	ld hl,HUDA
	ld bc,128
	ld e,BK_FONT
	call fill
	ld hl,HUDK
	ld bc,128
	ld e,C_LABEL
	call fill
	ld hl,hs_score
	ld de,HUDC+1
	call hstr
	ld hl,hs_beam
	ld de,HUDC+16
	call hstr
	ld hl,hs_hi
	ld de,HUDC+48
	call hstr
	ld hl,hs_st
	ld de,HUDC+59
	call hstr
	ld hl,hs_speed
	ld de,HUDC+64+16
	call hstr
	ld hl,hs_pod
	ld de,HUDC+64+30
	call hstr
	ld hl,hs_help
	ld de,HUDC+64+40
	call hstr
	ld a,G_LBRK
	ld (HUDC+21),a
	ld a,G_RBRK
	ld (HUDC+46),a
	ld hl,HUDK+7
	ld b,6
	ld a,C_DIGIT
.d1:	ld (hl),a
	inc hl
	djnz .d1
	ld hl,HUDK+51
	ld b,6
.d2:	ld (hl),a
	inc hl
	djnz .d2
	ld (HUDK+62),a
	ld a,$FF
	ld (hudflag),a
	ld (lastchg),a
	jp hud_update

hstr:	; HL = string (0 end) -> font codes at DE
	ld a,(hl)
	or a
	ret z
	sub 32
	or $80
	ld (de),a
	inc hl
	inc de
	jr hstr

hs_score	db "SCORE",0
hs_beam	db "BEAM",0
hs_hi	db "HI",0
hs_st	db "ST",0
hs_speed	db "SPEED",0
hs_pod	db "POD",0
hs_help	db "HELP",0

hud_update:
	; beam meter: charge 0..48 -> 0..192 pixels over 24 cells
	ld a,(charge)
	ld hl,lastchg
	cp (hl)
	jr nz,.chg
	ld a,(hudflag)
	or a
	ret z
	ld a,(charge)
.chg:	ld (hl),a
	push af
	ld a,1
	ld (hudall),a		; at least the meter changed
	pop af
	add a,a
	add a,a			; pixels 0..192
	ld c,a
	ld hl,HUDC+22
	ld de,HUDK+22
	ld b,24
.mb:	ld a,c
	cp 8
	jr c,.part
	sub 8
	ld c,a
	ld a,8
	jr .wr
.part:	ld c,0
.wr:	add a,G_METER
	ld (hl),a
	ld a,(charge)
	cp 44
	ld a,C_METER
	jr c,$+4
	ld a,C_METERF
	ld (de),a
	inc hl
	inc de
	djnz .mb
	ld a,(hudflag)
	or a
	ret z
	xor a
	ld (hudflag),a
	; score, hi score
	ld hl,HUDC+7
	ld de,score
	call hbcd
	ld hl,HUDC+51
	ld de,hiscore
	call hbcd
	; stage
	ld a,(lvlnum)
	add a,'1'-32
	or $80
	ld (HUDC+62),a
	; lives: ship icons (up to 5 spare ships)
	ld a,(lives)
	dec a
	ld c,a
	ld hl,HUDC+64+1
	ld de,HUDK+64+1
	ld b,5
.lv:	ld a,c
	or a
	jp m,.nol
	jr z,.nol
	dec c
	ld (hl),G_LIFE
	inc hl
	ld (hl),G_LIFE+1
	jr .lc
.nol:	ld (hl),BLANK_CODE
	inc hl
	ld (hl),BLANK_CODE
.lc:	inc hl
	ld a,C_LIFE
	ld (de),a
	inc de
	ld (de),a
	inc de
	djnz .lv
	; speed pips
	ld a,(pspeed)
	ld c,a
	ld hl,HUDC+64+22
	ld de,HUDK+64+22
	ld b,3
.sp:	ld a,c
	or a
	ld a,G_PIPOFF
	jr z,.s0
	dec c
	ld a,G_PIP
.s0:	ld (hl),a
	ld a,C_METER
	ld (de),a
	inc hl
	inc de
	djnz .sp
	; pod weapon letter
	ld a,(podw)
	or a
	ld a,'-'
	jr z,.w
	ld a,(podw)
	ld hl,wpn_l-1
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
.w:	sub 32
	or $80
	ld (HUDC+64+34),a
	ld a,C_WPN
	ld (HUDK+64+34),a
	; helpers
	ld a,(sats)
	or a
	ld a,'-'
	jr z,$+4
	ld a,'H'
	sub 32
	or $80
	ld (HUDC+64+45),a
	ld a,C_WPN
	ld (HUDK+64+45),a
	jp hud_diff
wpn_l	db "SLC"

hbcd:	; 3 BCD bytes at DE -> 6 digit codes at HL
	ld b,3
.l:	ld a,(de)
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,$80+16
	ld (hl),a
	inc hl
	ld a,(de)
	and 15
	add a,$80+16
	ld (hl),a
	inc hl
	inc de
	djnz .l
	ret
