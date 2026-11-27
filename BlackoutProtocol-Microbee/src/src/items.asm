; ---------------------------------------------------------------------------
; What Wren finds and uses: fittings (searchable furniture) and their contents,
; searched marks, security terminals (SLEEP / RESET codes), the inventory.
; Room record parts in STAGE: +8 robots, +10 fittings (n, then row, col, item).
; Items: 0 nothing, $10+k shard k, $20 SLEEP code, $30 RESET code.
; ---------------------------------------------------------------------------
WS_TERM  equ 6
WS_DEAD  equ 7
KEY_R    equ 18
KEY_S    equ 19
KEY_W    equ 23
KEY_X    equ 24
KEY_1    equ 33
KEY_0    equ 32
KEY_L    equ 12
KEY_RET  equ 52
INK_SEARCHED equ $08

; A = fitting index of cell (row B, col C) in this room, or $FF.
fit_find:
        ld hl,(STAGE+10)
        ld de,STAGE
        add hl,de
        ld a,(hl)
        or a
        ld a,$FF
        ret z
        ld e,(hl)               ; count
        inc hl
        ld d,0                  ; index
.f:     ld a,(hl)
        cp b
        jr nz,.n
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr nz,.n
        ld a,d
        ret
.n:     inc hl
        inc hl
        inc hl
        inc d
        ld a,d
        cp e
        jr nz,.f
        ld a,$FF
        ret

; HL = the searched-flag byte for fitting A of this room, C = its bit mask.
fit_flag:
        push af
        ld a,(cur_room)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,srch_bits
        add hl,de
        pop af
        push af
        rrca
        rrca
        rrca
        and 3
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        pop af
        and 7
        ld c,1
        jr z,.m
.s:     sla c
        dec a
        jr nz,.s
.m:     ret

; Z if fitting A has not been searched.
fit_searched:
        call fit_flag
        ld a,(hl)
        and c
        ret

; Dim fitting at (row B, col C): it and the cell above it take the
; "searched" ink, in BACK and NATIVE.
fit_dim:                        ; ... and its right half, if it has one
        push bc
        call fit_dim1
        pop bc
        inc c
        ld a,c
        cp 42
        ret nc
        push bc
        call fit_find           ; a record of its own: another fitting
        pop bc
        cp $FF
        ret nz
        push bc
        ld a,c
        ld c,b
        call map_index
        ld de,ROOM_MAP
        add hl,de
        ld a,(hl)
        ld hl,tile_flags
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop bc
        and 2
        ret z
fit_dim1:
        ld a,c
        push bc
        call .cell
        pop bc
        dec b
        ld a,c
.cell:  ld c,b
        call cell_addr
        push hl
        ld a,h
        sub $40
        ld h,a
        call .ink
        pop hl
        call .ink
        jp dirty_cell
.ink:   push hl
        push bc
        ld b,12                 ; a checkerboard through the pixels (mono screens)
        ld c,$AA
.d:     ld a,(hl)
        and c
        ld (hl),a
        inc hl
        ld a,c
        cpl
        ld c,a
        djnz .d
        ld a,(hl)               ; (HL = the colour byte, 12)
        and $F0
        or INK_SEARCHED
        ld (hl),a
        pop bc
        pop hl
        ret

; On entry to a room, on Story and Agent: if a shard still hides in one of its
; fittings, say so (and blip).  Explorers find the rooms worth searching; which
; fitting is still up to them.
str_signal: db "SHARD SIGNAL",0
shard_hint:
        ld a,(skill)
        cp 2
        ret nc
        ld hl,(STAGE+10)
        ld de,STAGE
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
        ld c,0                  ; fitting index
.f:     push bc
        push hl
        inc hl
        inc hl
        ld a,(hl)               ; its item
        cp $40
        jr c,.n
        ld a,c
        call fit_searched
        jr nz,.n
        pop hl
        pop bc
        ld hl,str_signal
        call msg_show
        jp sfx_tick
.n:     pop hl
        pop bc
        inc hl
        inc hl
        inc hl
        inc c
        djnz .f
        ret

; On entry to a room: dim everything already searched.
marks_apply:
        ld hl,(STAGE+10)
        ld de,STAGE
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
        xor a
.f:     push bc
        push hl
        push af
        call fit_searched
        jr z,.n
        pop af
        pop hl
        push hl
        push af
        ld b,(hl)
        inc hl
        ld c,(hl)
        call fit_dim
.n:     pop af
        pop hl
        pop bc
        inc a
        inc hl
        inc hl
        inc hl
        djnz .f
        ret

; Search finished at the fitting behind Wren (srch_row, srch_col).
loot_found:
        ld a,(srch_row)
        ld b,a
        ld a,(srch_col)
        ld c,a
        call fit_find
        cp $FF
        jr z,.empty
        push hl
        push af
        call fit_flag
        ld a,(hl)
        or c
        ld (hl),a
        pop af
        pop hl
        inc hl
        inc hl
        ld a,(hl)               ; the item
        push af
        ld a,(srch_row)
        ld b,a
        ld a,(srch_col)
        ld c,a
        call fit_dim
        ld hl,searches
        inc (hl)
        pop af
        or a
        jr z,.empty
        cp $20
        jr z,.sleep
        cp $30
        jr z,.reset
        and $3F                 ; a shard: set its bit
        ld (tmp_k),a
        call shard_bit
        or (hl)
        ld (hl),a
        call sfx_found
        ld hl,str_shard         ; "SHARD n FOUND"
        ld de,msgbuf
        ld bc,13
        ldir
        ld a,(tmp_k)            ; "SHARD n FOUND": its number within the key
        ld c,0
.d3:    cp 3
        jr c,.d3d
        sub 3
        jr .d3
.d3d:   add a,'1'
        ld (msgbuf+6),a
        ld hl,msgbuf
        jp msg_show
.sleep: ld hl,n_sleep
        inc (hl)
        call sfx_found
        ld hl,str_gsleep
        jp msg_show
.reset: ld hl,n_reset
        inc (hl)
        call sfx_found
        ld hl,str_greset
        jp msg_show
.empty: ld hl,str_nothing
        jp msg_show

; HL = the byte holding shard A's flag, A = its mask.
shard_bit:
        ld hl,shards
        jp flag_bit

; Flags (bit 2 security, bit 3 splice) of the terminal behind Wren, or 0.
term_under:
        call on_floor
        ld a,0
        ret nc
        dec b
        ld c,b
        ld a,(wx)
        add a,6
        srl a
        srl a
        call map_index
        ld de,ROOM_MAP
        add hl,de
        ld a,(hl)
        ld hl,tile_flags
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        and $0C
        ret

start_term:
        ld a,WS_TERM
        ld (wstate),a
        ld a,1
        ld (srch_lock),a
        ld a,F_STAND
        ld (wframe),a
        call sfx_blip
        ld hl,str_term
        jp msg_show

st_term:
        ld a,(kbits)
        and (1<<K_LEFT)|(1<<K_RIGHT)|(1<<K_DOWN)
        jr nz,.leave
        ld a,KEY_S
        call scan_key
        jr nz,.sleep
        ld a,KEY_R
        call scan_key
        ret z
        ld a,(n_reset)          ; RESET: every lift pad back to its floor
        or a
        jr z,.nocode
        dec a
        ld (n_reset),a
        call pads_reset
        call sfx_found
        ld hl,str_lifts
        jr .done
.sleep: ld a,(n_sleep)
        or a
        jr z,.nocode
        dec a
        ld (n_sleep),a
        ld hl,SLEEP_FRAMES
        ld (sleep_t),hl
        call sfx_sleep
        ld hl,str_asleep
        jr .done
.nocode:
        call sfx_deny
        ld hl,str_nocode
.done:  call msg_show
.leave: xor a
        ld (wstate),a
        ret

; Every pad back to the bottom floor it started on.
pads_reset:
        ld a,(npads)
        or a
        ret z
        ld b,a
        ld ix,pads
.p:     push bc
        ld a,(ix+P_DIR)
        or a
        jr nz,.n
        ld a,(ix+P_N)
        dec a
        cp (ix+P_LV)
        jr z,.n
        push af
        call pad_unbake
        pop af
        ld (ix+P_LV),a
        call pad_floor_y
        ld (ix+P_Y),a
        ld (ix+P_OY),a
        call pad_bake
.n:     ld de,P_SIZE
        add ix,de
        pop bc
        djnz .p
        ret

str_nothing: db "NOTHING HERE",0
str_shard:   db "SHARD n FOUND",0
str_gsleep:  db "SLEEP CODE",0
str_greset:  db "RESET CODE",0
str_term:    db "S=SLEEP R=RST",0
str_lifts:   db "LIFTS RESET",0
str_asleep:  db "ROBOTS SLEEP",0
str_nocode:  db "NO CODE LEFT",0
