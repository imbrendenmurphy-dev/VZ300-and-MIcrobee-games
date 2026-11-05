; =====================================================================
;  STAGE LOADING: level blob, PCG banks, scroll tables, sprite set
;  stage n: block BLK_STAGE+2n = glyphs (banks 2-9) + packed level blob,
;           block BLK_STAGE+2n+1 = tables (0000-1FFF) + sprite set (2000-)
; =====================================================================

stage_load:
	ld a,(lvlnum)
	add a,a
	add a,BLK_STAGE
	ld (pcgblk),a
	inc a
	ld (tabblk),a
	; level blob (VZ-TYPE format) -> LVLBUF
	ld a,(tabblk)
	call map_blk
	ld hl,$7800
	ld de,LVLBUF
	call unlzb
	MEMV BLK_WORK
	; PCG banks 2..9
	ld a,(pcgblk)
	ld (lb_src),a
	ld hl,0
	ld a,(mono)		; monochrome glyphs at 4000h
	or a
	jr z,$+5
	ld hl,$4000
	ld a,BK_TERR
.bk:	ld (lb_bank),a
	push hl
	call load_bank
	pop hl
	ld de,2048
	add hl,de
	ld a,(lb_bank)
	inc a
	cp BK_POOLA
	jr c,.bk
	; sprite set -> WORK 0000h-57FFh
	ld a,BLK_WORK
	ld (cb_dst),a
	ld a,(tabblk)
	ld hl,$2000
	ld de,$0000
	ld bc,$5800
	call blk_copy
	; stage header, boss body table
	ld a,(tabblk)
	call map_blk
	ld hl,BOSSC
	ld de,BOSSBUF
	ld bc,$0490
	ldir
	ld a,(SHDR)
	ld (bandrow),a
	ld a,(SHDR+1)
	ld (bandcol),a
	ld a,(SHDR+2)
	ld (starcol),a
	ld a,(mono)		; monochrome: everything white on black too, so
	or a			; the mode also looks right on a colour monitor
	call nz,mono_tabs
	MEMV BLK_WORK
	ld a,(mono)
	or a
	call nz,mono_sprites
	; no sprite cells pending on either page
	ld hl,CSLOT
	ld bc,$1000		; slot marks + band flags
	ld e,0
	call fill
	xor a
	ld (STQA+1),a
	ld (STQB+1),a
	xor a
	ld (qnA),a
	ld (qnB),a
	jp stars_init

; copy 2K from block (lb_src) offset HL into PCG bank (lb_bank) and the mirror
load_bank:
	ld b,8
.c:	push bc
	push hl
	ld a,(lb_src)
	call map_blk
	ld de,BOUNCE
	ld bc,256
	ldir
	MEMV BLK_MIRROR
	pop hl
	push hl
	ld a,(lb_bank)
	add a,a
	add a,a
	add a,a
	ld d,a
	ld a,h
	and 7
	add a,d
	ld d,a
	ld e,0
	ld hl,BOUNCE
	ld bc,256
	ldir
	MEMV BLK_WORK
	ld a,(lb_bank)
	or LV_SCREEN
	out (P_LV),a
	pop hl
	push hl
	ld a,h
	and 7
	or $F8
	ld d,a
	ld e,0
	ld hl,BOUNCE
	ld bc,256
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	pop hl
	inc h
	pop bc
	djnz .c
	ret
lb_src	db 0
lb_bank	db 0

; common glyphs (font, HUD, stars) into PCG banks 0-1
gfx_load:
	ld a,BLK_GFX
	ld (lb_src),a
	xor a
	ld (lb_bank),a
	ld hl,0
	call load_bank
	ld a,1
	ld (lb_bank),a
	ld hl,$0800
	jp load_bank

; monochrome monitor: every terrain / band colour becomes white on black
mono_tabs:
	ld hl,T0K
	ld b,128
	call .f
	ld hl,T1K
	ld b,64
	call .f
	ld hl,PXK
	ld b,0
	call .f
	ld hl,BANDK
	ld b,128
	call .f
	ld a,$0F
	ld (bandcol),a
	ld (starcol),a
	ret
.f:	ld (hl),$0F
	inc hl
	djnz .f
	ret
mono_sprites:	; every sprite cell ink -> white
	ld ix,SPRDESC
	ld b,NSPR
.s:	push bc
	ld a,(ix+0)
	or a
	jr z,.n
	ld e,(ix+3)
	ld d,(ix+4)
	ld a,(ix+0)
	call .tab
	ld e,(ix+8)
	ld d,(ix+9)
	ld a,(ix+5)
	call .tab
.n:	ld de,16
	add ix,de
	pop bc
	djnz .s
	ret
.tab:	; DE = colour table, A = columns: W*4*hcm entries
	add a,a
	add a,a
	ld b,a
	ld c,(ix+12)
	ex de,hl
.t1:	push bc
	ld b,c
.t2:	ld a,(hl)
	cp $FF
	jr z,$+4
	ld (hl),WHITE
	inc hl
	djnz .t2
	pop bc
	djnz .t1
	ret

; the game display: 64 x 16 characters, all black
play_screen:
	call crtc_game
	jp cls_all
