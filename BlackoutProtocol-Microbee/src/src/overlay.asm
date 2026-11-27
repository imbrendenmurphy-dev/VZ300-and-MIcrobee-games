; ---------------------------------------------------------------------------
; The overlay: information screens, loaded at DATA_WIN only while they run.
; ---------------------------------------------------------------------------
        jp title_page_open
        jp deck_page_open
        jp splice_puzzle
        jp won_open
        jp over_open
deck_page_open:
        call page_begin
        ld hl,deck_page
        call page_run
        ld b,0                  ; key rows 2..7
.k:     push bc
        ld a,b
        add a,2
        ld c,a
        ld (tmp_x),a
        ld hl,str_key
        ld a,3
        ld e,$0F
        call print_at
        ld a,b
        inc a
        call put_digit
        ld a,b                  ; three shard slots at columns 10, 12, 14
        add a,a
        add a,b
        ld (tmp_k),a
        ld d,10
.s:     ld a,(tmp_k)
        call shard_have
        ld a,T_SLOT_ON
        ld e,$0A
        jr nz,.have
        ld a,T_SLOT_OFF
        ld e,$08
.have:  push bc
        push af
        ld a,(tmp_x)
        ld b,a
        ld c,d
        pop af
        call put_tile
        pop bc
        ld hl,tmp_k
        inc (hl)
        inc d
        inc d
        ld a,d
        cp 16
        jr nz,.s
        pop bc
        push bc
        ld a,(keys_done)        ; online?
        inc b
.kb:    rrca
        djnz .kb
        ld hl,str_online
        ld e,$A0
        jr c,.on
        ld hl,str_offline
        ld e,$08
.on:    ld a,(tmp_x)
        ld c,a
        ld a,17
        call print_at
        pop bc
        inc b
        ld a,b
        cp NKEYS
        jr nz,.k
        call show_clock_at_top
        ld a,38                 ; codes
        ld (pr_col),a
        ld a,$0B
        ld (pr_ink),a
        ld c,5
        ld a,(n_sleep)
        call put_digit
        ld a,38
        ld (pr_col),a
        ld c,7
        ld a,(n_reset)
        call put_digit
        call deck_map
        call page_show
        call wait_up
        ld hl,mus_deck
        ld a,KEY_W
        ld b,KEY_S
        call mus_loop
        ld a,KEY_S
        call scan_key
        push af
        call wait_up
        pop af
        ld a,OVL_SAVE
        jp nz,ovl_call
        jp resume_room

deck_page:
        db PG_PANEL,1,1,9,24,$0E
        db PG_HEAD,1,3,$0D,"OVERRIDE KEYS",0
        db PG_PANEL,1,26,9,40,$0E
        db PG_HEAD,1,28,$0B,"STATUS",0
        db PG_BUL,3,28
        db PG_BUL,5,28
        db PG_TEXT,5,30,$0F,"SLEEP",0
        db PG_BUL,7,28
        db PG_TEXT,7,30,$0F,"RESET",0
        db PG_PANEL,11,1,21,40,$0E
        db PG_HEAD,11,3,$0A,"STATION MAP",0
        db PG_TEXT,20,3,$0B,"HERE",0
        db PG_TEXT,20,9,$0E,"SEEN",0
        db PG_TEXT,20,15,$0A,"CLEARED",0
        db PG_TEXT,20,24,$08,"UNKNOWN",0
        db PG_KEY,22,2," W ",0
        db PG_TEXT,22,6,$0F,"BACK TO THE MISSION",0
        db PG_KEY,22,27," S ",0
        db PG_TEXT,22,31,$0F,"SAVE",0
        db PG_END

show_clock_at_top:
        ld a,30                 ; HH:MM:SS in the status panel
        ld (pr_col),a
        ld a,$0B
        ld (pr_ink),a
        ld c,3
        ld a,(clk_h)
        call put2
        ld a,':'
        call put_c1
        ld a,(clk_m)
        call put2
        ld a,':'
        call put_c1
        ld a,(clk_s)
        jp put2

; The station: shaft lines with letters, room tags coloured by what you know.
deck_map:
        ld b,0                  ; shafts: a letter over a pair of rails
.sh:    push bc
        ld a,b
        ld c,a
        add a,a
        add a,c
        add a,4                 ; x = 4 + 3s
        ld (tmp_x),a
        ld (pr_col),a
        ld a,$0C
        ld (pr_ink),a
        ld a,b
        add a,'A'
        ld c,12
        call put_char
        ld c,13
.ln:    push bc
        ld b,c
        ld a,(tmp_x)
        ld c,a
        ld a,T_SHAFTW
        ld e,$04
        call put_tile
        pop bc
        inc c
        ld a,c
        cp 20
        jr nz,.ln
        pop bc
        inc b
        ld a,b
        cp NSHAFTS
        jr nz,.sh
        ld b,0                  ; rooms: a block each, coloured by what you know
.rm:    push bc
        ld a,b
        add a,a
        ld l,a
        ld h,0
        ld de,room_mapinfo
        add hl,de
        ld c,(hl)               ; column
        inc hl
        ld a,(hl)
        push af                 ; row
        call room_ink
        ld e,a
        pop af
        ld b,a
        ld a,T_SLOT_ON
        call put_tile
        pop bc
        inc b
        ld a,b
        cp NROOMS
        jr nz,.rm
        ret

; A = the map ink for room B: here yellow, cleared green, seen cyan, unknown grey.
room_ink:
        ld a,(cur_room)
        cp b
        ld a,$0B
        ret z
        call visited_bit
        ld a,$08
        ret z
        push bc                 ; count its searched fittings
        ld a,b
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,srch_bits
        add hl,de
        ld c,0
        ld d,4
.by:    ld a,(hl)
        ld e,8
.bi:    rrca
        jr nc,$+3
        inc c
        dec e
        jr nz,.bi
        inc hl
        dec d
        jr nz,.by
        ld hl,room_nfits
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,c
        cp (hl)
        pop bc
        ld a,$0A
        ret nc
        ld a,$0E
        ret

splice_puzzle:
        ld a,(sp_key)
        ld b,a
        add a,a
        add a,b
        ld hl,splice_tgt
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld de,sp_tgt
        ld bc,3
        ldir
        ld b,3                  ; scramble each shard by 1..3 turns
        ld hl,sp_tgt
        ld de,sp_cur
.sc:    ld a,(frames)
        add a,b
        and 3
        jr nz,$+3
        inc a
        ld c,a
        ld a,(hl)
.rt:    call rot_mask
        dec c
        jr nz,.rt
        ld (de),a
        inc hl
        inc de
        djnz .sc
        call page_begin
        ld hl,splice_page
        call page_run
        ld a,18
        ld (pr_col),a
        ld a,$0D
        ld (pr_ink),a
        ld c,3
        ld a,(sp_key)
        inc a
        call put_digit
        ld b,0                  ; the three targets, dim
.g:     push bc
        ld hl,sp_tgt
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld c,b
        ld b,15
        ld e,$08
        call shard_draw
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.g
        call sp_redraw
        call page_show
.loop:  call present
        ld b,0
.key:   push bc
        ld a,b
        add a,KEY_1
        call scan_key
        ld c,a
        pop bc
        ld hl,sp_down
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,c
        or a
        jr z,.rel
        ld a,(hl)               ; new press?
        or a
        jr nz,.nk
        ld (hl),1
        ld hl,sp_cur
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        call rot_mask
        ld (hl),a
        push bc
        call sfx_blip
        call sp_redraw
        pop bc
        jr .nk
.rel:   ld (hl),0
.nk:    inc b
        ld a,b
        cp 3
        jr nz,.key
        ld hl,sp_cur            ; solved?
        ld de,sp_tgt
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.unsolved
        inc hl
        inc de
        djnz .cmp
        ld a,(sp_key)           ; key online
        ld b,a
        ld a,1
        inc b
.bit:   dec b
        jr z,.set
        add a,a
        jr .bit
.set:   ld hl,keys_done
        or (hl)
        ld (hl),a
        ld hl,str_sp_done
        ld a,24
        ld c,3
        ld e,$A0
        call page_text
        call present
        ld hl,mus_keyok
        xor a
        call mus_play
        ld a,SPK_KEYOK
        call say
        call autosave           ; a key online: the autosave slot
        ld b,25
.w:     push bc
        call present
        pop bc
        djnz .w
        jp resume_room
.unsolved:
        ld a,KEY_X
        call scan_key
        jp z,.loop
        jp resume_room

sp_redraw:
        ld b,0
.s:     push bc
        ld hl,sp_cur
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld hl,sp_tgt-sp_cur-0
        push af
        ld hl,sp_tgt
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        pop af
        ld e,$09                ; red until it lines up
        cp (hl)
        jr nz,.c
        ld e,$0A
.c:     ld c,b
        ld b,7
        call shard_draw
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.s
        ret

; Shard: mask A (N1 E2 S4 W8) as a 3 x 3 cell node, top row B, slot C (0..2), ink E.
shard_draw:
        ld (sd_mask),a
        ld a,e
        ld (sd_ink),a
        ld a,c                  ; column = 8 + slot * 10
        add a,a
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,8
        ld (sd_col),a
        ld a,b
        ld (sd_row),a
        ld d,0                  ; cell 0..8
.c:     push de
        ld a,d
        ld e,T_EMPTY
        cp 4
        jr nz,.n1
        ld e,T_CIRN
.n1:    ld b,a
        ld a,(sd_mask)
        ld c,a
        ld a,b
        cp 1
        jr nz,.n2
        bit 0,c
        jr z,.n2
        ld e,T_CIRV
.n2:    ld a,b
        cp 7
        jr nz,.n3
        bit 2,c
        jr z,.n3
        ld e,T_CIRV
.n3:    ld a,b
        cp 5
        jr nz,.n4
        bit 1,c
        jr z,.n4
        ld e,T_CIRH
.n4:    ld a,b
        cp 3
        jr nz,.n5
        bit 3,c
        jr z,.n5
        ld e,T_CIRH
.n5:    ld d,e                  ; tile
        ld a,(sd_ink)
        ld e,a
        ld a,b                  ; row / column of cell b
        ld c,0
.dv:    cp 3
        jr c,.dd
        sub 3
        inc c
        jr .dv
.dd:    push af
        ld a,(sd_row)
        add a,c
        ld c,a
        pop af
        ld hl,sd_col
        add a,(hl)
        call redraw_cell
        pop de
        inc d
        ld a,d
        cp 9
        jr nz,.c
        ret

; Rotate an N/E/S/W mask a quarter turn clockwise.
rot_mask:
        add a,a
        bit 4,a
        jr z,.r
        or 1
.r:     and 15
        ret

title_page_open:
        ld sp,STACKTOP
        call page_begin
        ld hl,title_page
        call page_run
.shown: call page_show
        ld a,3                  ; MERIDIAN's voice lives on disk D
        call pack_try
        ld a,0
        jr c,.nov
        inc a
.nov:   ld (speech_ok),a
        ld hl,str_blank14       ; tidy away the disk message
        ld a,MSG_COL
        ld c,23
        ld e,0
        call print_at
        ld a,(speech_ok)        ; say so if MERIDIAN's voice couldn't be read
        or a
        jr nz,.voice
        ld hl,str_novoice
        ld a,7
        ld c,23
        ld e,$0B
        call print_at
.voice:
        call present
        ld a,(title_n)          ; MERIDIAN welcomes you the first time round
        or a
        ld a,SPK_WELCOME
        call z,say
        ld hl,title_n
        inc (hl)
        ld hl,title_far         ; the tune into the scratch buffer (the last-frame
        ld de,DIRTY_PREV        ; dirty list, empty and unused while the title is up)
        call far_load
        ld hl,DIRTY_PREV
        ld (prev_end),hl
        ld a,KEY_L
        ld (mus_key2),a
        ld hl,DIRTY_PREV
        ld a,KEY_SPACE
        call mus_play           ; once through (~90 s); NZ if a key stopped it
        push af
        xor a
        ld (mus_key2),a
        out (SPK),a
        pop af
        jp z,demo_start         ; nobody pressed anything: the attract demo
        ld a,KEY_L
        call scan_key
        push af
        call wait_up
        pop af
        ld a,OVL_LOAD
        jp nz,ovl_call
        ld a,OVL_LEVEL          ; then choose a level
        jp ovl_call

title_page:
        db PG_LOGO
        db PG_TEXT,6,3,$0D,"AGENT WREN  -  HALCYON ARRAY  -  2091",0
        db PG_PANEL,8,2,14,39,$0E
        db PG_HEAD,8,4,$0E,"MISSION",0
        db PG_TEXT,9,4,$0F,"MERIDIAN, THE STATION AI, WILL CUT",0
        db PG_TEXT,10,4,$0F,"THE PLANET'S POWER IN EIGHT HOURS.",0
        db PG_TEXT,11,4,$0F,"SIX WINGS. EACH HIDES THREE CIPHER",0
        db PG_TEXT,12,4,$0F,"SHARDS: SPLICE THEM INTO ITS KEY,",0
        db PG_TEXT,13,4,$0F,"THEN USE ALL SIX ON THE CORE.",0
        db PG_PANEL,15,2,20,39,$0E
        db PG_HEAD,15,4,$0B,"CONTROLS",0
        db PG_KEY,16,4," O ",0
        db PG_KEY,16,8," P ",0
        db PG_TEXT,16,12,$0F,"RUN",0
        db PG_KEY,16,21," SPACE ",0
        db PG_TEXT,16,29,$0F,"VAULT",0
        db PG_KEY,17,4," Q ",0
        db PG_KEY,17,8," A ",0
        db PG_TEXT,17,12,$0F,"LIFTS",0
        db PG_KEY,17,21," Q ",0
        db PG_TEXT,17,25,$0F,"SEARCH, USE",0
        db PG_KEY,18,4," W ",0
        db PG_TEXT,18,8,$0F,"WRIST-DECK",0
        db PG_KEY,18,21," S ",0
        db PG_KEY,18,24," R ",0
        db PG_TEXT,18,28,$0F,"SLEEP/RESET",0
        db PG_TEXT,19,4,$08,"OR THE ARROW KEYS",0
        db PG_KEY,19,27,"ESC",0
        db PG_TEXT,19,31,$08,"PAUSE",0
        db PG_KEY,22,3," L ",0
        db PG_TEXT,22,7,$08,"LOAD A SAVED GAME",0
        db PG_BUL,21,10
        db PG_TEXT,21,12,$0A,"PRESS SPACE TO BEGIN",0
        db PG_TEXT,22,27,$0D,"VIBED BY BPM",0
        db PG_END

won_open:
        ld sp,STACKTOP
        ld a,SPK_CANCEL
        ld (end_say),a
        ld hl,mus_win
        ld (end_tune),hl
        call page_begin
        ld hl,won_page
        jr end_common
over_open:
        ld sp,STACKTOP
        ld a,SPK_DARK
        ld (end_say),a
        ld hl,mus_lose
        ld (end_tune),hl
        call page_begin
        ld hl,lost_page
end_common:
        call page_run
        ld hl,report_page
        call page_run
        ld a,27                 ; time left
        ld (pr_col),a
        ld a,$0B
        ld (pr_ink),a
        ld c,11
        ld a,(clk_h)
        call put2
        ld a,':'
        call put_c1
        ld a,(clk_m)
        call put2
        ld a,':'
        call put_c1
        ld a,(clk_s)
        call put2
        ld a,33                 ; keys online
        ld (pr_col),a
        ld c,13
        ld a,(keys_done)
        ld b,0
.kc:    srl a
        jr nc,$+3
        inc b
        or a
        jr nz,.kc
        ld a,b
        call put_digit
        ld a,33
        ld (pr_col),a
        ld c,15
        ld a,(searches)
        call put2
        ld a,33
        ld (pr_col),a
        ld c,17
        ld a,(deaths)
        call put2
        call page_show
        ld a,(end_say)
        call say
        ld hl,(end_tune)
        xor a
        call mus_play
        ld a,KEY_SPACE
        call wait_key
        jp title

won_page:
        db PG_PANEL,3,5,21,36,$0A
        db PG_HEAD,3,7,$0A,"MISSION REPORT",0
        db PG_TEXT,6,12,$A0," MERIDIAN  OFFLINE ",0
        db PG_TEXT,8,9,$0F,"THE GRID IS SAFE, AGENT.",0
        db PG_END
lost_page:
        db PG_PANEL,3,5,21,36,$09
        db PG_HEAD,3,7,$09,"MISSION REPORT",0
        db PG_TEXT,6,11,$90," THE GRID WENT DARK ",0
        db PG_TEXT,8,8,$0F,"THE BLACKOUT PROTOCOL RAN.",0
        db PG_END
report_page:
        db PG_SEP,9,7,34
        db PG_BUL,11,8
        db PG_TEXT,11,10,$0F,"TIME LEFT",0
        db PG_BUL,13,8
        db PG_TEXT,13,10,$0F,"KEYS ONLINE",0
        db PG_TEXT,13,34,$0F,"/6",0
        db PG_BUL,15,8
        db PG_TEXT,15,10,$0F,"SEARCHES",0
        db PG_BUL,17,8
        db PG_TEXT,17,10,$0F,"DEATHS",0
        db PG_KEY,22,13," SPACE ",0
        db PG_TEXT,22,21,$0F,"TO GO AGAIN",0
        db PG_END

splice_page:
        db PG_PANEL,1,2,21,39,$0D
        db PG_HEAD,1,4,$0D,"SPLICE TERMINAL",0
        db PG_TEXT,3,5,$0F,"OVERRIDE KEY",0
        db PG_TEXT,5,5,$0E,"SHARDS",0
        db PG_SEP,12,4,37
        db PG_TEXT,13,5,$08,"TARGET CIRCUIT",0
        db PG_KEY,19,5," 1 ",0
        db PG_KEY,19,9," 2 ",0
        db PG_KEY,19,13," 3 ",0
        db PG_TEXT,19,17,$0F,"TURN A SHARD",0
        db PG_KEY,20,5," X ",0
        db PG_TEXT,20,9,$0F,"LEAVE THE TERMINAL",0
        db PG_END

str_deck:    db "WRIST-DECK",0
str_keys:    db "OVERRIDE KEYS",0
str_key:     db "KEY ",0
str_online:  db "ONLINE",0
str_blank14: db "              ",0
str_offline: db "------",0
str_codes:   db "SLEEP CODES ",0
str_codes2:  db "   RESET CODES ",0
str_map:     db "STATION MAP",0
str_back:    db "W  BACK TO THE MISSION",0
str_splice:  db "SPLICE OVERRIDE KEY ",0
str_sp_help: db "1  2  3  TURN A SHARD",0
str_sp_help2: db "X  LEAVE THE TERMINAL",0
str_sp_ghost: db "MATCH THE CIRCUIT:",0
str_sp_done: db " KEY ONLINE ",0
str_won1:    db "MERIDIAN  OFFLINE",0
str_won2:    db "THE GRID IS SAFE, AGENT.",0
str_won3:    db "TIME TO SPARE",0
str_lost1:   db "THE GRID WENT DARK",0
str_lost2:   db "MERIDIAN'S BLACKOUT PROTOCOL RAN.",0
str_stats:   db "SEARCHES ",0
str_stats2:  db "   DEATHS ",0
str_novoice: db "NO VOICE: DISK UNREADABLE",0
str_again:   db "PRESS SPACE",0
