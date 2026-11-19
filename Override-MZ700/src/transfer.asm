; =====================================================================
;  transfer.asm - the circuit duel
;
;  Twelve rows of wiring on each side lead to a central column of
;  twelve cells.  Each side fires a limited number of pulses into its
;  ports; a pulse runs along the wire and, when it reaches the centre,
;  turns that cell to the side's colour and locks it for a while.
;  Wiring has splitters (one port feeds two cells), joiners (two ports
;  must both be live to feed one cell), dead ends and boosters (longer
;  lock).  When the clock runs out, the side with more cells wins.
; =====================================================================

TR_ROWS         equ 13
TR_TOP          equ 5               ; screen row of wire row 0
TR_TRAVEL       equ 15              ; frames for a pulse to cross
TR_HOLD         equ 70              ; lock time at the centre
TR_TIME         equ 250             ; 10 seconds

; wire types
WT_STRAIGHT     equ 0
WT_DEAD         equ 1
WT_SPLIT        equ 2
WT_SPLITB       equ 3
WT_JOIN         equ 4
WT_JOINB        equ 5
WT_BOOST        equ 6

; TRBUF layout (side 0 = player, side 1 = enemy; 12 bytes each)
TRT             equ TRBUF+0         ; wire type
TRP             equ TRBUF+2*TR_ROWS ; pulse travel timer
TRH             equ TRBUF+4*TR_ROWS ; input hold (joiners)
TRO             equ TRBUF+6*TR_ROWS ; output lock at the centre
TRC             equ TRBUF+8*TR_ROWS ; centre owner (0 / 1)
TRD             equ TRBUF+9*TR_ROWS ; drawn state cache, 2 per row
TRAI            equ TRBUF+11*TR_ROWS ; AI timers (2)

COL_P           equ YELLOW
COL_E           equ MAGENTA

transfer_game:
        call sfx_stop
.again: call tr_setup
        call tr_draw_all
        ; get ready
        ld hl,txt_tr_ready
        call tr_status
        ld hl,SONG_XFER
        call mus_play
        ld b,45
.rdy:   push bc
        call tr_frame_wait
        pop bc
        ld a,(event)
        cp EV_QUIT
        ret z
        djnz .rdy
        call mus_stop
        ld hl,txt_tr_go
        call tr_status
        call fe_reset
        ld a,TR_TIME
        ld (tr_time),a
        xor a
        ld (tr_sub),a
.loop:  call tr_frame_wait
        ld a,(event)
        cp EV_QUIT
        ret z
        call tr_input
        ld a,1
        call tr_ai                  ; enemy
        ld a,(demo)
        or a
        jr z,.nodemo
        xor a
        call tr_ai                  ; demo pilot plays our side
.nodemo:
        call tr_tick
        call tr_draw_dyn
        call tr_draw_time
        ld hl,tr_time
        dec (hl)
        jr nz,.loop
        ; let pulses still on the wire arrive
        ld b,TR_TRAVEL+1
.fin:   push bc
        call tr_tick
        call tr_draw_dyn
        call tr_frame_wait
        pop bc
        djnz .fin
        ; count
        ld hl,TRC
        ld b,TR_ROWS
        ld c,0
.cnt:   ld a,(hl)
        or a
        jr nz,$+3
        inc c
        inc hl
        djnz .cnt
        ld a,c                      ; player's cells (13 rows: no draws)
        cp 7
        jr nc,.win
        ld a,2
        ld (tr_result),a
        ld hl,txt_tr_lose
        call tr_status
        ld hl,SONG_LOSE
        call mus_play
        jr .show
.win:   ld a,1
        ld (tr_result),a
        ld hl,txt_tr_win
        call tr_status
        ld hl,SONG_WIN
        call mus_play
.show:  ld b,75
.sh:    push bc
        call tr_frame_wait
        call tr_flash_centre
        pop bc
        djnz .sh
        call mus_stop
        ret
.draw:  ld hl,txt_tr_draw
        call tr_status
        ld b,50
.dr:    push bc
        call tr_frame_wait
        pop bc
        djnz .dr
        jp .again

; wait for the next frame; in the demo a key aborts
tr_frame_wait:
        call wait_frame
        ld hl,frame
        inc (hl)
        ld a,(demo)
        or a
        ret z
        call anykey
        ret z
        ld a,1
        ld (demo_abort),a
        ld a,EV_QUIT
        ld (event),a
        ret

; ---------------------------------------------------------------------
; set up wiring and pulse counts
; ---------------------------------------------------------------------
tr_setup:
        ld hl,TRBUF
        ld b,0
        call zero_b                 ; 256 bytes
        ld hl,TRT
        call tr_wire_side
        ld hl,TRT+TR_ROWS
        call tr_wire_side
        ; centre starts alternating
        ld hl,TRC
        ld b,TR_ROWS
        ld a,1                      ; the defender starts with 7 of 13
.c:     ld (hl),a
        xor 1
        inc hl
        djnz .c
        ; pulses: 4 + class/2 (probe: 4)
        ld a,(DROIDS+D_TYPE)
        call tr_pulses
        add a,2
        ld (tr_shots),a
        ld a,(tr_enemy)
        call slot_iy
        ld a,(iy+D_TYPE)
        ld (tr_etype),a
        call tr_pulses
        ld (tr_shots+1),a
        xor a
        ld (tr_sel),a
        ld a,20
        ld (TRAI),a
        ld (TRAI+1),a
        ret

; A = type -> A = pulses
tr_pulses:
        call roster_ptr
        ld bc,R_CLASS
        add hl,bc
        ld a,(hl)
        srl a
        add a,3
        ret

; HL = 12 wire types for one side
tr_wire_side:
        ld c,0                      ; row
.r:     ld a,c
        cp TR_ROWS-1
        jr nc,.single
        push hl
        call rand
        pop hl
        cp 50
        jr c,.split
        cp 90
        jr c,.join
.single:
        push hl
        call rand
        pop hl
        cp 36
        ld a,WT_DEAD
        jr c,.put
        push hl
        call rand
        pop hl
        cp 30
        ld a,WT_BOOST
        jr c,.put
        ld a,WT_STRAIGHT
.put:   ld (hl),a
        inc hl
        inc c
        jr .next
.split: ld (hl),WT_SPLIT
        inc hl
        ld (hl),WT_SPLITB
        inc hl
        inc c
        inc c
        jr .next
.join:  ld (hl),WT_JOIN
        inc hl
        ld (hl),WT_JOINB
        inc hl
        inc c
        inc c
.next:  ld a,c
        cp TR_ROWS
        jr c,.r
        ret

; ---------------------------------------------------------------------
; drawing
; ---------------------------------------------------------------------
tr_draw_all:
        ld a,BLACK
        call cls
        ld hl,txt_tr_title
        ld c,0
        ld a,WHITE*16+BLUE
        push hl
        ld b,0
        ld c,1
        ld a,WHITE*16+BLUE
        call clear_rows
        pop hl
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        ; the two droids
        ld a,(DROIDS+D_TYPE)
        ld b,2
        ld c,2
        ld e,C_DL4
        call fe_droid
        ld a,(tr_etype)
        call roster_ptr
        ld de,R_CB
        add hl,de
        ld e,(hl)
        ld a,(tr_etype)
        ld b,35
        ld c,2
        call fe_droid
        ld hl,txt_tr_you
        ld b,6
        ld c,2
        ld a,COL_P*16
        call print_at
        ld hl,txt_tr_them
        ld b,28
        ld c,2
        ld a,COL_E*16
        call print_at
        ; centre frame
        ld de,VRAM+(TR_TOP-1)*40+17
        ld hl,tr_frame_top
        ld c,WHITE*16
        call print_raw
        ld de,VRAM+(TR_TOP+TR_ROWS)*40+17
        ld hl,tr_frame_bot
        ld c,WHITE*16
        call print_raw
        ; help
        ld a,(demo)
        or a
        jr nz,.nohelp
        ld hl,txt_tr_help
        ld c,22
        ld a,CYAN*16
        call print_centre
.nohelp:
        ; force a full draw of the dynamic parts
        ld hl,TRD
        ld b,2*TR_ROWS
.f:     ld (hl),0FFh
        inc hl
        djnz .f
        ld a,0FFh
        ld (tr_lasttime),a
        call tr_draw_shots
        call tr_draw_dyn
        jp tr_draw_time

txt_tr_title:   db "- C I R C U I T   T R A N S F E R -",0
txt_tr_you:     db "YOU",0
txt_tr_them:    db "TARGET",0
txt_tr_help:    db "UP/DOWN CHOOSE   FIRE SENDS A PULSE",0
txt_tr_ready:   db "GET READY",0
txt_tr_go:      db "SEND YOUR PULSES!",0
txt_tr_win:     db "TRANSFER COMPLETE - DROID SEIZED",0
txt_tr_lose:    db "TRANSFER FAILED - LINK BURNED OUT",0
txt_tr_draw:    db "DEADLOCK - RELINKING",0
tr_frame_top:   db 5Ch,78h,78h,78h,78h,5Dh,0
tr_frame_bot:   db 1Ch,78h,78h,78h,78h,1Dh,0

; status line (row 19), HL = text
tr_status:
        push hl
        ld b,19
        ld c,1
        xor a
        call clear_rows
        pop hl
        ld c,19
        ld a,WHITE*16
        jp print_centre

; draw a 3x2 droid on the screen: A = type, B = col, C = row, E = code base
fe_droid:
        push af
        ld a,e
        ld (fd_cb),a
        call vaddr                  ; DE = VRAM
        pop af
        push de
        call roster_ptr
        ld bc,R_D0
        add hl,bc
        ex de,hl                    ; DE = digits
        pop hl                      ; HL = VRAM
        push de
        ld a,(fd_cb)                ; code base -> (char, attr) via the tables
        ld b,a
        call .cell                  ; left dome
        ld a,b
        add a,4
        call .cell                  ; eye
        ld a,b
        inc a
        call .cell                  ; right dome
        ld de,37
        add hl,de
        pop de
        ld c,3
.dg:    ld a,(de)
        add a,b
        add a,7
        call .cell
        inc de
        dec c
        jr nz,.dg
        ret
.cell:  push de
        ld e,a
        ld d,high CHRTAB
        ld a,(de)
        ld (hl),a
        inc d
        ld a,(de)
        call fe_attr                ; black background on the front end
        set 3,h
        ld (hl),a
        res 3,h
        inc hl
        pop de
        ret

; deck attribute -> front-end attribute: the blue floor becomes black
fe_attr:
        push bc
        ld b,a
        and 7
        cp BLUE
        ld a,b
        jr nz,.k
        and 0F8h
.k:     pop bc
        ret

; wire templates, columns 1..16 for the player's side
tr_tpl:
        db 47h, 78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h  ; straight
        db 47h, 78h,78h,78h,78h,78h,78h,78h,78h,5Eh,0,0,0,0,0,0                 ; dead end
        db 47h, 78h,78h,78h,78h,78h,78h,78h,78h,5Fh,78h,78h,78h,78h,78h,78h     ; split
        db 0,   0,0,0,0,0,0,0,0,1Ch,78h,78h,78h,78h,78h,78h                     ; split, lower
        db 47h, 78h,78h,78h,78h,78h,78h,78h,78h,5Fh,78h,78h,78h,78h,78h,78h     ; join
        db 47h, 78h,78h,78h,78h,78h,78h,78h,78h,1Dh,0,0,0,0,0,0                 ; join, lower
        db 47h, 78h,78h,78h,78h,78h,78h,0F7h,78h,78h,78h,78h,78h,78h,78h,78h   ; booster

; mirror a box character for the enemy side
tr_mirror:
        cp 1Ch
        jr nz,$+5
        ld a,1Dh
        ret
        cp 1Dh
        jr nz,$+5
        ld a,1Ch
        ret
        cp 5Eh
        ret nz
        ld a,1Eh
        ret

; draw the wiring characters of every row (static)
tr_draw_shots:
        ld c,0
.r:     push bc
        ld a,c
        call tr_row_static
        pop bc
        inc c
        ld a,c
        cp TR_ROWS
        jr c,.r
        ret

; A = row: wire characters for both sides (colours come later)
tr_row_static:
        ld c,a
        add a,TR_TOP
        call row_addr               ; HL = VRAM row
        push hl
        ; player side: template at cols 1..16
        ld hl,TRT
        ld b,0
        add hl,bc
        ld a,(hl)
        call .tpl                   ; DE = template
        pop hl
        push hl
        inc hl
        ld b,16
.p:     ld a,(de)
        ld (hl),a
        inc de
        inc hl
        djnz .p
        ; enemy side: mirrored, cols 38 down to 23
        ld hl,TRT+TR_ROWS
        ld b,0
        add hl,bc
        ld a,(hl)
        call .tpl
        pop hl
        push bc
        ld bc,38
        add hl,bc
        pop bc
        ld b,16
.e:     ld a,(de)
        call tr_mirror
        ld (hl),a
        inc de
        dec hl
        djnz .e
        ret
.tpl:   add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,tr_tpl
        add hl,de
        ex de,hl
        pop hl
        ret

; is row C of side B lit?  (travelling, holding or locking)
; returns A = 0 dark, 1 lit; also the head column in L (0 = none)
tr_lit:
        ld a,b
        or a
        ld a,c
        jr z,$+4
        add a,TR_ROWS
        ld e,a
        ld d,0
        ld l,0
        ld ix,TRP
        add ix,de
        ld a,(ix+0)
        or a
        jr z,.nt
        ld a,TR_TRAVEL+1
        sub (ix+0)
        ld l,a                      ; head 1..15
.nt:    ld a,(ix+0)
        or (ix+TRH-TRP)
        or (ix+TRO-TRP)
        jr nz,.lit
        ; lower half of a splitter follows its upper row
        ld a,(ix+TRT-TRP)
        cp WT_SPLITB
        jr nz,.dark
        ld a,(ix+TRO-TRP)
        or (ix+TRP-TRP-1)
        or (ix+TRO-TRP-1)
        jr nz,.lit
.dark:  xor a
        ret
.lit:   ld a,1
        ret

; redraw colours of rows whose state changed
tr_draw_dyn:
        ld c,0
.r:     push bc
        ld b,0
        call tr_dyn_side
        pop bc
        push bc
        ld b,1
        call tr_dyn_side
        pop bc
        push bc
        call tr_dyn_centre
        pop bc
        inc c
        ld a,c
        cp TR_ROWS
        jr c,.r
        ; cursor
        ld a,(demo)
        or a
        ret nz
        ld c,0
.cu:    ld a,c
        add a,TR_TOP
        call row_addr
        ld a,(tr_sel)
        cp c
        ld a,0
        jr nz,$+4
        ld a,5Ah                    ; arrow
        ld (hl),a
        set 3,h
        ld (hl),WHITE*16
        inc c
        ld a,c
        cp TR_ROWS
        jr c,.cu
        ret

; B = side, C = row
tr_dyn_side:
        push bc
        call tr_lit
        pop bc
        ; state byte = lit*128 + head
        rrca
        or l
        ld d,a
        ; compare with cache
        ld a,b
        or a
        ld a,c
        jr z,$+4
        add a,TR_ROWS
        ld e,a
        push de
        ld d,0
        ld hl,TRD
        add hl,de
        pop de
        ld a,(hl)
        cp d
        ret z
        ld (hl),d
        ; draw: colour every wire cell, head as a bright block
        ld a,c
        add a,TR_TOP
        call row_addr
        ld a,d
        rlca
        and 1
        ld e,COL_P*16
        jr z,.dim
        ld a,b
        or a
        jr z,.cs
        ld e,COL_E*16
        jr .cs
.dim:   ld e,BLUE*16
.cs:    ; port colour always the side colour
        ld a,b
        or a
        push af
        ld a,COL_P*16
        jr z,$+4
        ld a,COL_E*16
        ld (tr_portcol),a
        pop af
        jr nz,.enemy
        inc hl                      ; col 1 = port
        set 3,h
        ld a,(tr_portcol)
        ld (hl),a
        ld b,15
.pc:    inc hl
        ld (hl),e
        djnz .pc
        res 3,h
        jr .head
.enemy: push bc
        ld bc,38
        add hl,bc
        pop bc
        set 3,h
        ld a,(tr_portcol)
        ld (hl),a
        ld b,15
.ec:    dec hl
        ld (hl),e
        djnz .ec
        res 3,h
        ld b,1
.head:  ld a,d
        and 7Fh
        ret z
        ; head column: player 1+head, enemy 38-head
        ld e,a
        ld a,c
        add a,TR_TOP
        call row_addr
        ld a,b
        or a
        jr nz,.eh
        ld a,e
        inc a
        jr .ph
.eh:    ld a,38
        sub e
.ph:    add a,l
        ld l,a
        jr nc,$+3
        inc h
        set 3,h
        ld (hl),WHITE*16
        ret

; centre cell of row C
tr_dyn_centre:
        ld b,0
        ld hl,TRC
        add hl,bc
        ld a,(hl)
        or a
        ld e,COL_P*16
        jr z,$+4
        ld e,COL_E*16
        ; locked?
        ld hl,TRO
        add hl,bc
        ld a,(hl)
        ld hl,TRO+TR_ROWS
        add hl,bc
        or (hl)
        ld d,0
        jr z,$+4
        ld d,WHITE*16
        ld a,c
        add a,TR_TOP
        call row_addr
        ld a,17
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),79h                 ; frame
        set 3,h
        ld (hl),WHITE*16
        res 3,h
        inc hl
        ld b,4
.c:     ld (hl),43h
        set 3,h
        ld (hl),e
        res 3,h
        inc hl
        djnz .c
        ld a,d                      ; lock marker in the frame
        or a
        ld a,79h
        jr z,$+4
        ld a,0BDh
        ld (hl),a
        set 3,h
        ld (hl),WHITE*16
        ret

tr_flash_centre:
        ld a,(frame)
        and 4
        ret z
        ld c,0
.r:     push bc
        call tr_dyn_centre
        pop bc
        inc c
        ld a,c
        cp TR_ROWS
        jr c,.r
        ret

; clock (big digits) and pulse counters
tr_draw_time:
        ld a,(tr_time)
        ; seconds = (time + 24) / 25
        add a,24
        ld b,0
.d:     sub 25
        jr c,.dd
        inc b
        jr .d
.dd:    ld a,b
        ld hl,tr_lasttime
        cp (hl)
        jr z,tr_draw_shots_left
        ld (hl),a
        ld c,0
.t:     sub 10
        jr c,.tt
        inc c
        jr .t
.tt:    add a,10
        ld de,VRAM+3*40+19
        push af
        ld a,c
        add a,20h
        ld (de),a
        set 3,d
        ld a,WHITE*16+80h
        ld (de),a
        res 3,d
        inc de
        pop af
        add a,20h
        ld (de),a
        set 3,d
        ld a,WHITE*16+80h
        ld (de),a
        ld a,(tr_time)
        cp 76
        jr nc,tr_draw_shots_left
        ld a,(tr_time)
        or a
        jr z,tr_draw_shots_left
        ld hl,SFX_TICK
        ld a,1
        call sfx

; pulses left as rows of dots under each droid
tr_draw_shots_left:
        ld de,VRAM+4*40+1
        ld a,(tr_shots)
        ld c,COL_P*16
        call .dots
        ld de,VRAM+4*40+30
        ld a,(tr_shots+1)
        ld c,COL_E*16
.dots:  ld b,9
        ld l,a
.l:     ld a,l
        or a
        ld a,47h
        jr nz,.on
        ld a,0
        jr .p
.on:    dec l
.p:     ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        djnz .l
        ret

; ---------------------------------------------------------------------
; logic
; ---------------------------------------------------------------------
tr_input:
        ld a,(demo)
        or a
        ret nz
        call fe_keys
        ld b,a
        bit B_UP,b
        jr z,.nu
        ld a,(tr_sel)
        or a
        jr z,.nu
        dec a
        ld (tr_sel),a
        call .click
.nu:    bit B_DOWN,b
        jr z,.nd
        ld a,(tr_sel)
        cp TR_ROWS-1
        jr nc,.nd
        inc a
        ld (tr_sel),a
        call .click
.nd:    bit B_FIRE,b
        ret z
        ld a,(tr_sel)
        ld c,a
        ld b,0
        jp tr_fire
.click: ld hl,SFX_CLICK
        ld a,1
        jp sfx

; B = side, C = row: launch a pulse if possible
tr_fire:
        ld hl,tr_shots
        ld a,b
        or a
        jr z,$+3
        inc hl
        ld a,(hl)
        or a
        jr z,.no
        push hl
        ld a,b
        or a
        ld a,c
        jr z,$+4
        add a,TR_ROWS
        ld e,a
        ld d,0
        ld ix,TRT
        add ix,de
        pop hl
        ld a,(ix+0)
        cp WT_SPLITB
        jr z,.no                    ; no port on this row
        ld a,(ix+TRP-TRT)
        or a
        jr nz,.no                   ; already a pulse on the way
        dec (hl)
        ld (ix+TRP-TRT),TR_TRAVEL
        push bc
        call tr_draw_shots_left
        pop bc
        ld a,b
        or a
        ld hl,SFX_PULSE
        jr z,$+5
        ld hl,SFX_EPULSE
        ld a,2
        jp sfx
.no:    ld a,b
        or a
        ret nz
        ld hl,SFX_BUZZ
        ld a,1
        jp sfx

; per frame: travel, arrival, timers
tr_tick:
        ld c,0                      ; index 0..23 (side*12 + row)
.l:     ld b,0
        ld ix,TRT
        add ix,bc
        ld a,(ix+TRH-TRT)
        or a
        jr z,$+5
        dec (ix+TRH-TRT)
        ld a,(ix+TRO-TRT)
        or a
        jr z,.o0
        dec (ix+TRO-TRT)
        jr nz,.o0
        call .redraw_c
.o0:    ld a,(ix+TRP-TRT)
        or a
        jr z,.n
        dec (ix+TRP-TRT)
        call z,tr_arrive
.n:     inc c
        ld a,c
        cp 2*TR_ROWS
        jr c,.l
        ret
.redraw_c:
        push bc
        ld a,c
        cp TR_ROWS
        jr c,$+4
        sub TR_ROWS
        ld c,a
        call tr_dyn_centre
        pop bc
        ret

; pulse at index C (IX = its TRT entry) reached the end of its wire
tr_arrive:
        ld a,(ix+0)
        cp WT_DEAD
        jr nz,.nd
        ld (ix+TRH-TRT),12          ; fizzles at the dead end
        ret
.nd:    cp WT_JOIN
        jr z,.join
        cp WT_JOINB
        jr z,.joinb
        ld d,TR_HOLD
        cp WT_BOOST
        jr nz,$+4
        ld d,TR_HOLD*2
        push af
        call tr_deliver
        pop af
        cp WT_SPLIT
        ret nz
        inc c                       ; splitter: the row below too
        inc ix
        call tr_deliver
        dec ix
        dec c
        ret
.join:  ld (ix+TRH-TRT),TR_HOLD/2
        ld a,(ix+TRH-TRT+1)
        or a
        ret z
        ld d,TR_HOLD
        jp tr_deliver
.joinb: ld (ix+TRH-TRT),TR_HOLD/2
        ld a,(ix+TRH-TRT-1)
        or a
        ret z
        dec c
        dec ix
        ld d,TR_HOLD
        call tr_deliver
        inc ix
        inc c
        ret

; deliver to index C (IX = its entry) with lock time D
tr_deliver:
        push bc
        push ix
        ld a,c
        ld b,0                      ; side
        cp TR_ROWS
        jr c,.s0
        sub TR_ROWS
        inc b
.s0:    ld c,a                      ; row
        ; the other side's lock
        ld a,b
        or a
        ld a,c
        jr nz,$+4
        add a,TR_ROWS
        ld e,a
        push de
        ld d,0
        ld hl,TRO
        add hl,de
        pop de
        ld a,(hl)
        or a
        jr nz,.blocked
        ld (ix+TRO-TRT),d
        ld e,c
        ld d,0
        ld hl,TRC
        add hl,de
        ld (hl),b
        call tr_dyn_centre
        ld hl,SFX_FLIP
        ld a,2
        call sfx
.blocked:
        pop ix
        pop bc
        ret

; ---------------------------------------------------------------------
; AI: A = side.  Fires now and then at the most useful row, keeping a
; pulse or two for the end.
; ---------------------------------------------------------------------
tr_ai:
        ld (tr_aiside),a
        ld e,a
        ld d,0
        ld hl,TRAI
        add hl,de
        dec (hl)
        ret nz
        ; next think: faster for higher classes
        push hl
        ld a,(tr_aiside)
        or a
        ld a,(DROIDS+D_TYPE)
        jr z,$+5
        ld a,(tr_etype)
        call roster_ptr
        ld bc,R_CLASS
        add hl,bc
        ld a,(hl)
        add a,a
        ld b,a
        ld a,30
        sub b
        ld b,a
        ld a,(tr_aiside)            ; the demo pilot has quick reflexes
        or a
        jr nz,$+4
        ld b,10
        call rand
        and 15
        add a,b
        pop hl
        ld (hl),a
        ; pulses left?
        ld hl,tr_shots
        ld a,(tr_aiside)
        or a
        jr z,$+3
        inc hl
        ld a,(hl)
        or a
        ret z
        ; save the last pulse for the final 3 seconds
        cp 2
        jr nc,.ok
        ld a,(tr_time)
        cp 80
        ret nc
.ok:    ; score every row; best wins
        ld a,0FFh
        ld (tr_best),a
        xor a
        ld (tr_bestv),a
        ld c,0
.r:     call tr_ai_value
        ld hl,tr_bestv
        cp (hl)
        jr c,.n
        jr nz,.take
        call rand                   ; tie: coin toss
        rla
        jr nc,.n
        ld hl,tr_bestv
        ld a,(hl)
.take:  ld (hl),a
        ld a,c
        ld (tr_best),a
.n:     inc c
        ld a,c
        cp TR_ROWS
        jr c,.r
        ld a,(tr_bestv)
        or a
        ret z
        ld a,(tr_best)
        ld c,a
        ld a,(tr_aiside)
        ld b,a
        jp tr_fire

; value of firing row C for side tr_aiside -> A
tr_ai_value:
        push bc
        ld a,(tr_aiside)
        or a
        ld a,c
        jr z,$+4
        add a,TR_ROWS
        ld e,a
        ld d,0
        ld ix,TRT
        add ix,de
        ld a,(ix+TRP-TRT)           ; busy
        or a
        jr nz,.zero
        ld a,(ix+0)
        cp WT_SPLITB
        jr z,.zero
        cp WT_DEAD
        jr nz,.nd
        call rand                   ; sometimes fooled by a dead end
        cp 40
        jr nc,.zero
        ld a,1
        jr .done
.nd:    cp WT_SPLIT
        jr nz,.ns
        call tr_cell_value
        ld b,a
        inc c
        call tr_cell_value
        add a,b
        jr .done
.ns:    cp WT_JOIN
        jr z,.j
        cp WT_JOINB
        jr nz,.single
        ld a,(ix+TRH-TRT-1)         ; partner live?
        dec c
        jr .j2
.j:     ld a,(ix+TRH-TRT+1)
.j2:    or a
        jr nz,.single
        call tr_cell_value          ; first half of a join: worth less
        srl a
        jr .done
.single:
        call tr_cell_value
        jr .done
.zero:  xor a
.done:  pop bc
        ret

; value of owning centre row C for side tr_aiside: 0 = already ours
; or locked by them, 3 = theirs, +1 when time is short
tr_cell_value:
        push de
        ld e,c
        ld d,0
        ld hl,TRC
        add hl,de
        ld a,(tr_aiside)
        cp (hl)
        jr z,.z
        ; their lock?
        ld a,(tr_aiside)
        or a
        ld a,c
        jr nz,$+4
        add a,TR_ROWS
        ld e,a
        ld hl,TRO
        add hl,de
        ld a,(hl)
        cp TR_TRAVEL
        jr nc,.z                    ; still locked when we'd arrive
        ld a,3
        ld e,a
        ld a,(tr_time)
        cp 90
        ld a,e
        jr nc,.x
        inc a
.x:     pop de
        ret
.z:     xor a
        pop de
        ret
