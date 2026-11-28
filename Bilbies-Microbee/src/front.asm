; =====================================================================
;  FRONT END: monitor choice, title (the bilbies live on the logo),
;  attract mode, level select, briefing, results, settings. Text screens
;  are drawn on page 0 with the panel font (PCG bank 12).
; =====================================================================
DEMOS:	db 0,3,14,19,8
NDEMO	equ 5

front_main:
	call hud_glyphs
	call load_game			; settings and progress from the disk
	call monitor_choice
.title:	call title_screen		; A = 0 play, 1 attract, 2 again
	or a
	jr z,.sel
	cp 2
	jr z,.title
	call attract
	jr .title
.sel:	call level_select		; NZ = back to the title
	jr nz,.title
.brief:	call briefing
	jr nz,.sel
	xor a
	ld (v_demo),a
	ld (v_test),a
	ld (v_quit),a
	ld (v_spawnfl),a
	ld (v_title),a
	ld a,(v_lvl)
	call level_load
	call mus_stop
	call play_level
	ld a,(v_quit)
	or a
	jr nz,.sel
	call results			; A = 0 next, 1 retry, 2 menu
	or a
	jr z,.next
	dec a
	jr z,.brief
	jr .sel
.next:	ld a,(v_lvl)
	inc a
	cp NLEVELS
	jr c,.n2
	call finale
	jr .title
.n2:	ld (v_lvl),a
	jr .brief

; level won: open the next one, save
progress:
	ld a,(v_lvl)
	inc a
	inc a				; levels open = this one + 1 more
	cp NLEVELS+1
	jr c,.p
	ld a,NLEVELS
.p:	ld hl,v_unlock
	cp (hl)
	ret c
	ret z
	ld (hl),a
	jp save_game

; ---------------------------------------------------------------------
;  text screens (page 0)
; ---------------------------------------------------------------------
; clear page 0 to blank font cells, colour A (paper<<4|ink), show it
tscr:	push af
	xor a
	call show_page
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,VIDEO
	ld bc,1024
	ld e,BLANK_CODE
	call fill
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,VIDEO
	ld bc,1024
	ld e,BK_HUD
	call fill
	ld a,LV_SCREEN
	out (P_LV),a
	pop af
	ld e,a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,COLWIN
	ld bc,1024
	call fill
	xor a
	out (P_COLCTL),a
	ret

; HL = text, D = row, E = column: page 0
tprint:	push de
	ld a,d
	rrca
	rrca
	ld d,a
	and $C0
	or e
	ld e,a
	ld a,d
	and 3
	or $F0
	ld d,a
.l:	ld a,(hl)
	or a
	jr z,.e
	sub 32
	or $80
	ld (de),a
	inc hl
	inc de
	jr .l
.e:	pop de
	ret
; HL = text, D = row: centred
tcentre:
	push hl
	ld b,0
.n:	ld a,(hl)
	or a
	jr z,.c
	inc hl
	inc b
	jr .n
.c:	ld a,64
	sub b
	srl a
	ld e,a
	pop hl
	jr tprint

; colour row D (page 0) with A
trow:	push af
	ld a,d
	rrca
	rrca
	ld l,a
	and $C0
	ld e,a
	ld a,l
	and 3
	or $F8
	ld h,a
	ld l,e
	ld a,COL_ON
	out (P_COLCTL),a
	pop af
	ld b,64
.l:	ld (hl),a
	inc hl
	djnz .l
	xor a
	out (P_COLCTL),a
	ret
; colour B cells from row D column E with A
tcells:	push af
	ld a,d
	rrca
	rrca
	ld l,a
	and $C0
	or e
	ld e,a
	ld a,l
	and 3
	or $F8
	ld h,a
	ld l,e
	ld a,COL_ON
	out (P_COLCTL),a
	pop af
.l:	ld (hl),a
	inc hl
	djnz .l
	xor a
	out (P_COLCTL),a
	ret

; colour helpers that follow the monitor setting
col_text:	; normal text
	ld a,(monomode)
	or a
	ld a,(BLUE<<4)|WHITE
	ret z
	ld a,(BLACK<<4)|GREY
	ret
col_head:	; headings
	ld a,(monomode)
	or a
	ld a,(BLUE<<4)|YELLOW
	ret z
	ld a,(BLACK<<4)|WHITE
	ret
col_lit:	; highlighted
	ld a,(monomode)
	or a
	ld a,(RED<<4)|WHITE
	ret z
	ld a,(DGREY<<4)|WHITE
	ret
col_dim:	; locked
	ld a,(monomode)
	or a
	ld a,(BLUE<<4)|BBLUE
	ret z
	ld a,(BLACK<<4)|DGREY
	ret

; ---- menu input: A = b0 up b1 down b2 left b3 right b4 fire (new presses),
; with auto-repeat for directions; mouse movement moves (cur_x, cur_y)
menu_keys:
	call vsync1
	call read_controls
	ld a,(ms_dyq)
	or a
	jr z,.nm
	call move_cursor
.nm:	ld a,(ct_now)
	ld c,a
	ld a,(ct_old)
	cpl
	and c
	ld b,a			; new presses
	ld a,c
	ld (ct_old),a
	and $0F
	jr z,.nr
	ld hl,mk_rep
	inc (hl)
	ld a,(hl)
	cp 12
	jr c,.nr
	ld (hl),9
	ld a,c
	and $0F
	or b
	ld b,a
	jr .k
.nr:	ld a,c
	and $0F
	jr nz,.k
	xor a
	ld (mk_rep),a
.k:	ld a,(kb_now)
	ld c,a
	ld a,(kb_old)
	cpl
	and c
	ld (mk_kb),a
	ld a,c
	ld (kb_old),a
	ld a,b
	ret

; wait until no key, button or fire is held
release:
	call vsync1
	call anykey
	jr nz,release
	ret

; ---------------------------------------------------------------------
;  monitor choice (at start-up; also in the settings)
; ---------------------------------------------------------------------
monitor_choice:
	call col_text
	call tscr
	ld hl,s_mon1
	ld d,4
	call tcentre
	ld hl,s_mon2
	ld d,7
	call tcentre
	ld hl,s_mon3
	ld d,9
	call tcentre
	ld hl,s_mon4
	ld d,12
	call tcentre
	call col_head
	ld d,4
	call trow
	call release
.w:	call vsync1
	ld a,K_C
	call key1
	jr nz,.c
	ld a,K_M
	call key1
	jr nz,.m
	call anykey
	jr z,.w
	ld a,(ct_now)		; fire / return / space: keep the saved choice
	bit 4,a
	jr z,.w
	jr .keep
.c:	xor a
	jr .set
.m:	ld a,1
.set:	ld hl,monomode
	cp (hl)
	ld (hl),a
	call nz,save_game
.keep:	jp release
s_mon1:	db "BILBIES!   FOR THE MICROBEE PREMIUM PLUS",0
s_mon2:	db "C  COLOUR MONITOR",0
s_mon3:	db "M  MONOCHROME MONITOR",0
s_mon4:	db "SPACE OR FIRE: AS LAST TIME",0

; ---------------------------------------------------------------------
;  title: the bilbies drop from the hatch, float down and walk the logo
; ---------------------------------------------------------------------
title_screen:
	ld a,LV_TITLE
	call level_load
	ld a,1
	ld (v_title),a
	ld (v_demo),a
	xor a
	ld (v_test),a
	ld (v_quit),a
	ld a,2
	ld (v_spawnfl),a		; everyone floats on the title
	ld hl,0
	ld (t_idle),hl
	xor a
	ld (t_drawn),a
	ld (t_choice),a
	ld hl,SONG_T
	call song_play
	call play_level			; returns on a key or when it's over
	xor a
	ld (v_title),a
	ld (v_spawnfl),a
	ld a,(t_choice)
	ret

; the title's panel rows (called from play_level's hud update)
title_panel:
	ld a,(t_drawn)
	or a
	jp nz,.keys
	ld a,1
	ld (t_drawn),a
	call col_text
	ld e,a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,$F800+10*64
	ld bc,384
	call fill
	ld hl,$FC00+10*64
	ld bc,384
	call fill
	xor a
	out (P_COLCTL),a
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,$F000+10*64
	ld bc,384
	ld e,BLANK_CODE
	call fill
	ld hl,$F400+10*64
	ld bc,384
	ld e,BLANK_CODE
	call fill
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,$F000+10*64
	ld bc,384
	ld e,BK_HUD
	call fill
	ld hl,$F400+10*64
	ld bc,384
	ld e,BK_HUD
	call fill
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,s_t1
	ld de,10*64+12
	call hud_text
	ld hl,s_t2
	ld de,12*64+8
	call hud_text
	ld hl,s_t3
	ld de,13*64+8
	call hud_text
	ld hl,s_t4
	ld de,15*64+4
	call hud_text
	call t_status
.keys:	; any key: what was pressed
	call read_controls
	ld a,(ct_now)
	bit 4,a
	jr nz,.play
	ld a,K_T
	call key1
	jr nz,.trainer
	ld a,K_S
	call key1
	jr nz,.settings
	ld a,K_ESC
	call key1
	jr nz,.play
	ld hl,(t_idle)
	inc hl
	ld (t_idle),hl
	ld de,750			; 30 seconds: the attract mode
	or a
	sbc hl,de
	ret c
	ld a,1
	jr .quit
.play:	xor a
.quit:	ld (t_choice),a
	ld a,1
	ld (v_quit),a
	xor a
	ld (t_drawn),a
	jp release
.trainer:
	ld a,(v_train)
	xor 1
	ld (v_train),a
	call t_status
	call sfx_click
	jp release
.settings:
	call settings
	xor a
	ld (t_drawn),a
	ld a,1				; the screen was used: start the scene again
	ld (v_quit),a
	ld a,2
	ld (t_choice),a
	ret
t_status:
	ld hl,s_toff
	ld a,(v_train)
	or a
	jr z,.s
	ld hl,s_ton
.s:	ld de,14*64+8
	jp hud_text
s_t1:	db "AN ORIGINAL GAME BY BPM",0
s_t2:	db "FIRE  SPACE  RETURN  OR  CLICK: PLAY",0
s_t3:	db "S: SETTINGS   T: TRAINER (EVERY LEVEL OPEN)",0
s_t4:	db "MICROBEE CODE AND GRAPHICS: CLAUDE (ANTHROPIC)  2026",0
s_toff:	db "                                 ",0
s_ton:	db "TRAINER ON: EVERY LEVEL IS OPEN  ",0

; ---------------------------------------------------------------------
;  attract mode: levels played by their solutions; a key ends it
; ---------------------------------------------------------------------
attract:
	ld a,(t_demo)
	inc a
	cp NDEMO
	jr c,.d
	xor a
.d:	ld (t_demo),a
	ld e,a
	ld d,0
	ld hl,DEMOS
	add hl,de
	ld a,(hl)
	call mus_stop
	call level_load
	ld a,1
	ld (v_demo),a
	xor a
	ld (v_test),a
	ld (v_quit),a
	ld (v_spawnfl),a
	call play_level
	xor a
	ld (v_demo),a
	jp release

; ---------------------------------------------------------------------
;  level select: two columns of twelve; NZ = back to the title
; ---------------------------------------------------------------------
level_select:
	ld hl,SONG_T
	call song_play
	call col_text
	call tscr
	ld hl,s_sel
	ld d,0
	call tcentre
	call col_head
	ld d,0
	call trow
	ld hl,s_selh
	ld d,15
	call tcentre
	; the list
	ld c,0
.ln:	push bc
	call sel_line
	pop bc
	inc c
	ld a,c
	cp NLEVELS
	jr c,.ln
	ld a,(v_lvl)
	ld (ls_cur),a
	call sel_hilite
	call release
.loop:	call menu_keys
	ld b,a
	ld a,(mk_kb)
	bit 6,a				; ESC
	jr nz,.back
	ld a,(ls_cur)
	ld c,a
	bit 0,b				; up
	jr z,.u
	dec c
.u:	bit 1,b				; down
	jr z,.dn
	inc c
.dn:	bit 2,b				; left: the other column
	jr z,.l
	ld a,c
	sub 12
	jr c,.l
	ld c,a
.l:	bit 3,b
	jr z,.r
	ld a,c
	add a,12
	ld c,a
.r:	; mouse: the line under the pointer
	ld a,(ms_seen)
	or a
	jr z,.nm
	ld a,(cur_y)
	rrca
	rrca
	rrca
	rrca
	and 15
	sub 2
	jr c,.nm
	cp 12
	jr nc,.nm
	ld e,a
	ld a,(cur_x+1)
	or a
	ld a,e
	jr z,.m1
	add a,12
.m1:	ld c,a
.nm:	ld a,c
	cp NLEVELS
	jr nc,.same
	ld a,(ls_cur)
	cp c
	jr z,.same
	push bc
	call sel_line			; repaint the old one plain
	pop bc
	ld a,c
	ld (ls_cur),a
	call sel_hilite
.same:	bit 4,b
	jr z,.loop
	; chosen: open?
	ld a,(ls_cur)
	call is_open
	jr nz,.ok
	call sfx_click
	jr .loop
.ok:	ld a,(ls_cur)
	ld (v_lvl),a
	call release
	xor a
	ret
.back:	call release
	or 1
	ret

; is level A open? NZ if so
is_open:
	ld c,a
	ld a,(v_train)
	or a
	ret nz
	ld a,(v_unlock)
	or a
	jr nz,.u
	inc a
.u:	cp c
	jr z,.no
	jr c,.no
	or 1
	ret
.no:	xor a
	ret

; line for level C: row 2 + C mod 12, column 0 or 32
sel_line:
	ld a,c
	ld b,0
	cp 12
	jr c,.c
	sub 12
	ld b,32
.c:	add a,2
	ld d,a
	ld e,b
	push de
	push bc
	; "MILD 1  NAME"
	ld a,c
	ld b,0
.rt:	cp 6
	jr c,.rd
	sub 6
	inc b
	jr .rt
.rd:	add a,'1'
	ld (sl_buf+7),a
	ld a,b
	add a,a
	add a,a
	add a,a
	ld l,a
	ld h,0
	ld de,RATINGS
	add hl,de
	ld de,sl_buf
	ld bc,7
	ldir
	ld a,' '
	ld (sl_buf+8),a
	ld (sl_buf+9),a
	pop bc
	push bc
	ld a,c
	call lv_name			; HL = name
	ld de,sl_buf+10
	ld b,20
.cp:	ld a,(hl)
	or a
	jr z,.pad
	ld (de),a
	inc hl
	inc de
	djnz .cp
	jr .z
.pad:	ld a,' '
.p2:	ld (de),a
	inc de
	djnz .p2
.z:	xor a
	ld (de),a
	pop bc
	pop de
	push de
	push bc
	ld hl,sl_buf
	inc e
	call tprint
	pop bc
	pop de
	ld a,c
	call is_open
	jr z,.lk
	call col_text
	jr .cl
.lk:	call col_dim
.cl:	ld b,32
	jp tcells
sel_hilite:
	ld a,(ls_cur)
	ld c,a
	ld b,0
	cp 12
	jr c,.c
	sub 12
	ld b,32
.c:	add a,2
	ld d,a
	ld e,b
	call col_lit
	ld b,32
	jp tcells

; A = level -> HL = its name
lv_name:
	ld hl,LVNAMES
	or a
	ret z
	ld b,a
.n:	ld a,(hl)
	inc hl
	or a
	jr nz,.n
	djnz .n
	ret

RATINGS:	db "MILD    ","TRICKY  ","TOUGH   ","WILD    "
s_sel:	db "CHOOSE A LEVEL",0
s_selh:	db "ARROWS / QAOP / JOYSTICK / MOUSE    FIRE: GO    ESC: TITLE",0

; ---------------------------------------------------------------------
;  briefing: the level, its numbers and a picture; NZ = back
; ---------------------------------------------------------------------
briefing:
	call col_text
	call tscr
	ld hl,s_wait
	ld d,8
	call tcentre
	call mus_stop
	ld a,(v_lvl)
	call level_load			; (1-2 seconds)
	ld hl,SONG_J
	call song_play
	call col_text
	call tscr
	call col_head
	ld d,1
	call trow
	ld a,(v_lvl)
	call lv_name
	ld d,1
	call tcentre
	; numbers from the header
	MEMV BLK_WORLD
	ld de,br_buf
	ld hl,s_b1
	call strcpy
	ld a,(WHDR+LH_N)
	call fmt_num
	ld hl,s_b2
	call strcpy
	ld a,(WHDR+LH_SAVE)
	call fmt_num
	xor a
	ld (de),a
	ld hl,br_buf
	ld d,3
	call tcentre
	ld de,br_buf
	ld hl,s_b3
	call strcpy
	ld a,(WHDR+LH_RATE)
	call fmt_num
	ld hl,s_b4
	call strcpy
	ld a,(WHDR+LH_MIN)
	call fmt_num
	ld hl,s_b5
	call strcpy
	xor a
	ld (de),a
	ld hl,br_buf
	ld d,4
	call tcentre
	; skills
	ld de,br_buf
	ld hl,WHDR+LH_SKILL
	ld b,8
	ld c,0
.sk:	ld a,(hl)
	or a
	jr z,.sn
	push hl
	push bc
	push af
	ld a,c
	add a,a
	ld l,a
	ld h,0
	ld bc,SKNAMES
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call strcpy
	pop af
	call fmt_num
	ld a,' '
	ld (de),a
	inc de
	ld (de),a
	inc de
	pop bc
	pop hl
.sn:	inc hl
	inc c
	djnz .sk
	xor a
	ld (de),a
	ld hl,br_buf
	ld d,13
	call tcentre
	ld hl,s_b6
	ld d,15
	call tcentre
	; the picture: the minimap glyphs, rows 6-10, columns 24-39
	call mm_glyphs
	ld b,5
	ld d,6
	ld c,0				; glyph
.pr:	push bc
	ld a,d
	rrca
	rrca
	ld l,a
	and $C0
	or 24
	ld e,a
	ld a,l
	and 3
	or $F0
	ld h,a
	ld l,e
	push hl
	ld b,16
.pc:	ld a,c
	or $80
	ld (hl),a
	inc hl
	inc c
	djnz .pc
	pop hl
	ld a,LV_ATTR
	out (P_LV),a
	ld b,16
	ld a,BK_HUD+3
.pa:	ld (hl),a
	inc hl
	djnz .pa
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(monomode)
	or a
	ld a,(BLACK<<4)|BROWN
	jr z,.mc
	ld a,(BLACK<<4)|GREY
.mc:	ld e,24
	ld b,16
	push de
	call tcells
	pop de
	pop bc
	ld a,c
	add a,16
	ld c,a
	inc d
	djnz .pr
	call release
.w:	call menu_keys
	ld a,(mk_kb)
	bit 6,a
	jr nz,.back
	ld a,b
	bit 4,b
	jr z,.w
	call release
	xor a
	ret
.back:	call release
	or 1
	ret
s_wait:	db "GETTING READY...",0
s_b1:	db "BILBIES ",0
s_b2:	db "   SAVE ",0
s_b3:	db "RELEASE RATE ",0
s_b4:	db "   TIME ",0
s_b5:	db " MINUTES",0
s_b6:	db "FIRE: START      ESC: CHOOSE AGAIN",0
SKNAMES:	dw sk0,sk1,sk2,sk3,sk4,sk5,sk6,sk7
sk0:	db "CLIMBERS ",0
sk1:	db "FLOATERS ",0
sk2:	db "BOMBERS ",0
sk3:	db "BLOCKERS ",0
sk4:	db "BUILDERS ",0
sk5:	db "BASHERS ",0
sk6:	db "MINERS ",0
sk7:	db "DIGGERS ",0

; the level's minimap into PCG bank 15 (glyphs 0-79)
mm_glyphs:
	MEMV BLK_WORLD
	ld a,LV_SCREEN+BK_HUD+3
	out (P_LV),a
	ld hl,WMMAP
	ld de,PCGWIN
	ld bc,1280
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; ---------------------------------------------------------------------
;  results: A = 0 next, 1 retry, 2 menu
; ---------------------------------------------------------------------
results:
	ld a,(v_saved)
	ld hl,v_tosave
	cp (hl)
	ld hl,SONG_L
	jr c,.song
	ld hl,SONG_W
.song:	call song_play
	call col_text
	call tscr
	call col_head
	ld d,2
	call trow
	ld a,(v_lvl)
	call lv_name
	ld d,2
	call tcentre
	ld a,(v_saved)
	ld hl,v_tosave
	cp (hl)
	ld hl,s_lost
	jr c,.l
	ld hl,s_won
.l:	ld d,5
	call tcentre
	ld de,br_buf
	ld hl,s_r1
	call strcpy
	ld a,(v_saved)
	call fmt_num
	ld hl,s_r2
	call strcpy
	ld a,(v_ncrt)
	call fmt_num
	ld hl,s_r3
	call strcpy
	ld a,(v_tosave)
	call fmt_num
	xor a
	ld (de),a
	ld hl,br_buf
	ld d,8
	call tcentre
	ld a,(v_saved)
	ld hl,v_tosave
	cp (hl)
	jr c,.lose
	call progress
	ld a,(v_lvl)
	cp NLEVELS-1
	ld hl,s_r4
	jr nz,.w1
	ld hl,s_r6
.w1:	ld d,12
	call tcentre
	ld a,(sv_error)
	or a
	jr z,.ok
	ld hl,s_sverr
	ld d,14
	call tcentre
.ok:	call release
.wk:	call menu_keys
	bit 4,a
	ld a,0
	jr nz,.done
	ld a,K_R
	call key1
	ld a,1
	jr nz,.done
	ld a,(mk_kb)
	bit 6,a
	ld a,2
	jr nz,.done
	jr .wk
.lose:	ld hl,s_r5
	ld d,12
	call tcentre
	call release
.wl:	call menu_keys
	bit 4,a
	ld a,1
	jr nz,.done
	ld a,(mk_kb)
	bit 6,a
	ld a,2
	jr nz,.done
	jr .wl
.done:	push af
	call release
	pop af
	ret
s_won:	db "WELL DONE!  HOME SAFE IN THE BURROW",0
s_lost:	db "NOT ENOUGH OF THEM MADE IT HOME",0
s_r1:	db "YOU SAVED ",0
s_r2:	db " OF ",0
s_r3:	db " AND NEEDED ",0
s_r4:	db "FIRE: NEXT LEVEL     R: TRY AGAIN     ESC: LEVELS",0
s_r5:	db "FIRE: TRY AGAIN      ESC: LEVELS",0
s_r6:	db "THAT WAS THE LAST BURROW!  FIRE: THE END",0
s_sverr:	db "(PROGRESS NOT SAVED: CHECK THE DISK)",0

finale:
	ld hl,SONG_W
	call song_play
	call col_head
	call tscr
	ld hl,s_f1
	ld d,5
	call tcentre
	ld hl,s_f2
	ld d,8
	call tcentre
	ld hl,s_f3
	ld d,10
	call tcentre
	call release
.w:	call vsync1
	call anykey
	jr z,.w
	jp release
s_f1:	db "EVERY LEVEL DONE!",0
s_f2:	db "THE BILBIES ARE ALL SAFE IN THEIR BURROWS.",0
s_f3:	db "THANK YOU FOR PLAYING  -  BPM",0

; ---------------------------------------------------------------------
;  settings: monitor, music, sound; saved to the disk
; ---------------------------------------------------------------------
settings:
	call col_text
	call tscr
	call col_head
	ld d,2
	call trow
	ld hl,s_st
	ld d,2
	call tcentre
	call release
.draw:	ld hl,s_s1
	ld a,(monomode)
	or a
	jr z,.m
	ld hl,s_s1m
.m:	ld de,5*64+16
	call tprint
	ld hl,s_s2
	ld de,7*64+16
	call tprint
	ld hl,s_on
	ld a,(sfx_on)
	or a
	jr nz,.s
	ld hl,s_off
.s:	ld de,7*64+40
	call tprint
	ld hl,s_s3
	ld de,9*64+16
	call tprint
	ld hl,s_on
	ld a,(mus_en)
	or a
	jr nz,.mu
	ld hl,s_off
.mu:	ld de,9*64+40
	call tprint
	ld hl,s_s4
	ld de,12*64+16
	call tprint
.w:	call vsync1
	ld a,K_C
	call key1
	jr nz,.col
	ld a,K_M
	call key1
	jr nz,.mono
	ld a,K_S
	call key1
	jr nz,.snd
	ld a,K_K
	call key1
	jr nz,.mus
	call anykey
	jr z,.w
	ld a,(kb_now)
	bit 6,a
	jr nz,.done
	ld a,(ct_now)
	bit 4,a
	jr nz,.done
	jr .w
.col:	xor a
	jr .setm
.mono:	ld a,1
.setm:	ld (monomode),a
	call release
	jp settings
.snd:	ld a,(sfx_on)
	xor 1
	ld (sfx_on),a
	call release
	jp .draw
.mus:	ld a,(mus_en)
	xor 1
	ld (mus_en),a
	call z,mus_stop
	ld hl,SONG_T
	call song_play
	call release
	jp .draw
.done:	call save_game
	ld a,(sv_error)
	or a
	jr z,.x
	ld hl,s_sverr
	ld de,14*64+12
	call tprint
	call release
.x2:	call vsync1
	call anykey
	jr z,.x2
.x:	jp release
s_st:	db "SETTINGS",0
s_s1:	db "C / M   MONITOR:   COLOUR     ",0
s_s1m:	db "C / M   MONITOR:   MONOCHROME ",0
s_s2:	db "S       SOUND EFFECTS:",0
s_s3:	db "K       MUSIC:",0
s_s4:	db "FIRE OR ESC: SAVE AND RETURN",0
s_on:	db "ON ",0
s_off:	db "OFF",0
