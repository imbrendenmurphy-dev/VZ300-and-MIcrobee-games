; ---------------------------------------------------------------------------
; Lift shaft screen.
; The Premium Plus only lets the CPU at video RAM between scan lines, so:
;  * on entry (screen blanked) every cell of rows 0..21 except the "band"
;    (rows 9..12, where Wren walks) is mapped to a combo character: tile pair
;    A over B at fine offset sho.  Page 0's combos live in PCG bank 1, page 1's
;    in bank 9, so each page flips cleanly.
;  * while the lift moves the band joins in (except Wren's region, rows 9..12
;    cols 18..23, which never changes), the ~10 combo characters are rebuilt
;    every frame and, every 12 lines, only the cells whose pair changed are
;    rewritten.
;  * when the lift stops, the band goes back to ordinary cells, so Wren can
;    walk off into a tunnel.  The picture doesn't change at any point.
; ---------------------------------------------------------------------------
LIFT_STEP equ 6                 ; pixels a frame (divides the 12-pixel cell)
BAND_R0  equ 9
BAND_R1  equ 12
REG_C0   equ 18
REG_C1   equ 23
LIFT_ROW equ 12
LIFT_WX  equ 78                 ; Wren's x on the lift (half-pixels)
SHAFT_WY equ LIFT_ROW*12-24

; A = 0/1 for the hidden page (the one pagebase points at)
hidden_idx:
        ld hl,(pagebase)
        ld a,h
        or l
        ret z
        ld a,1
        ret

; HL = page_state + hidden page (A preserved? no)
pstate: push af
        call hidden_idx
        ld (hpage),a
        pop af
        ld l,a                  ; A = offset of the per-page array
        ld h,0
        ld de,page_vars
        add hl,de
        ld a,(hpage)
        add a,l
        ld l,a
        ret                     ; (page_vars never crosses a 256 boundary)

PV_BAND  equ 0                  ; band rows mapped to combos?
PV_Y     equ 2                  ; coarse y the combo rows show

; ------------------------------------------------------------- present hooks
; Before the flush: a stopped lift gives the hidden page's band back to
; ordinary cells and queues them.
shaft_pre:
        ld a,(lift_dir)
        or a
        ret nz
        ld a,PV_BAND
        call pstate
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        ld b,BAND_R0
        ld c,BAND_R1
        call map_identity
        ld c,BAND_R0            ; queue the band
.r:     xor a
        call cell_addr
        ld b,COLS
.c:     call dirty_cell
        ld de,16
        add hl,de
        djnz .c
        inc c
        ld a,c
        cp BAND_R1+1
        jr nz,.r
        ret

; After the flush: a moving lift keeps the hidden page's combos up to date.
shaft_post:
        ld a,(lift_dir)
        or a
        ret z
        ld a,PV_Y
        call pstate
        ld a,(shy)
        cp (hl)
        jr z,.ysame
        ld b,(hl)
        ld (hl),a
        call diff_rows          ; B = old y
.ysame: ld a,PV_BAND
        call pstate
        ld a,(hl)
        or a
        jr nz,.band
        ld (hl),1
        ld b,BAND_R0
        ld c,BAND_R1
        call map_combo
.band:  jp gen_combos

; ------------------------------------------------------------- mapping
; Screen + attribute RAM of the hidden page, rows B..C, back to
; "position n shows PCG character n".
map_identity:
        push bc
        ld a,b
        call row_pos            ; HL = position of row B
        pop bc
        ld a,c
        sub b
        inc a
        ld b,a                  ; rows
.r:     push bc
        ld b,COLS
.c:     ld a,$80
        out ($1C),a
        ld a,h
        or $F0
        ld d,a
        ld e,l
        ld a,l
        or $80
        ld (de),a
        ld a,$90
        out ($1C),a
        ld a,l
        rla
        ld a,h
        rla                     ; n >> 7
        ld (de),a
        inc hl
        djnz .c
        pop bc
        djnz .r
        ld a,$80
        out ($1C),a
        ret

; HL = page position of row A of the hidden page.  Preserves nothing much.
row_pos:
        ld l,a
        ld h,0
        call times42
        ld de,(pagebase)
        add hl,de
        ret

; HL = HL * 42.  Preserves BC.
times42:
        push bc
        add hl,hl
        ld b,h
        ld c,l                  ; 2x
        add hl,hl
        add hl,hl               ; 8x
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl               ; 32x
        add hl,de
        add hl,bc
        pop bc
        ret

; HL = shaft_pm row A.
; The map is a row table (PM_ROWS bytes: which distinct row goes where) and then
; the distinct rows, 42 pair indices each: floors are a whole room apart now, and
; most rows repeat, so this keeps a tall shaft within the data window.
pm_row: ld l,a
        ld h,0
        ld de,SHAFT_PM
        add hl,de
        ld l,(hl)
        ld h,0
        call times42
        ld de,SHAFT_PM+PM_ROWS
        add hl,de
        ret

; Combo bank of the hidden page: 1 or 9.
combo_bank:
        call hidden_idx
        add a,a
        add a,a
        add a,a
        inc a
        ret

; Map rows B..C of the hidden page to combos at coarse y shy: attribute,
; column colour and screen byte, skipping Wren's region.
map_combo:
        call combo_bank
        ld (tmp_bank),a
.row:   push bc
        ld a,b
        call row_pos
        ld de,$F000
        add hl,de               ; HL = screen address of the row
        push hl
        ld a,(shy)
        add a,b
        call pm_row
        ex de,hl                ; DE = pair map row
        pop hl
        ld c,0
.c:     ld a,b                  ; region?
        cp BAND_R0
        jr c,.do
        cp BAND_R1+1
        jr nc,.do
        ld a,c
        cp REG_C0
        jr c,.do
        cp REG_C1+1
        jr c,.skip
.do:    ld a,$90
        out ($1C),a
        ld a,(tmp_bank)
        ld (hl),a
        ld a,$80
        out ($1C),a
        ld a,(de)
        ld (hl),a
        ld a,$40
        out ($08),a
        push hl
        ld hl,(cur_colcol)
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        set 3,h
        ld (hl),a
        res 3,h
        xor a
        out ($08),a
.skip:  inc hl
        inc de
        inc c
        ld a,c
        cp COLS
        jr nz,.c
        pop bc
        ld a,b
        inc b
        cp c
        jr nz,.row
        ret

; The view moved from coarse y B to shy: rewrite only the screen bytes whose
; pair changed, in every combo-mapped row of the hidden page.
diff_rows:
        ld a,$80
        out ($1C),a
        ld a,b
        ld (tmp_oldy),a
        ld c,0                  ; row
.row:   ld a,c
        cp BAND_R0
        jr c,.ok
        cp BAND_R1+1
        jr nc,.ok
        push hl
        ld a,PV_BAND
        push bc
        call pstate
        pop bc
        ld a,(hl)
        pop hl
        or a
        jr z,.next              ; band not mapped: nothing to do
.ok:    push bc
        ld a,c
        ld (tmp_row),a
        call row_pos
        ld de,$F000
        add hl,de
        ld (tmp_scr),hl
        ld a,(tmp_oldy)
        ld b,a
        ld a,(tmp_row)
        add a,b
        call pm_row
        ld (tmp_old),hl
        ld a,(shy)
        ld b,a
        ld a,(tmp_row)
        add a,b
        call pm_row             ; HL = new row
        ld de,(tmp_old)
        ld bc,(tmp_scr)
        ld a,(tmp_row)
        ld ixl,a
        ld ixh,0                ; column
.c:     ld a,ixl
        cp BAND_R0
        jr c,.cmp
        cp BAND_R1+1
        jr nc,.cmp
        ld a,ixh
        cp REG_C0
        jr c,.cmp
        cp REG_C1+1
        jr c,.nx
.cmp:   ld a,(de)
        cp (hl)
        jr z,.nx
        ld a,(hl)
        ld (bc),a
.nx:    inc hl
        inc de
        inc bc
        inc ixh
        ld a,ixh
        cp COLS
        jr nz,.c
        pop bc
.next:  inc c
        ld a,c
        cp ROOM_ROWS
        jr nz,.row
        ret

; Rebuild every combo character for fine offset sho in the hidden page's bank.
gen_combos:
        call combo_bank
        or $80
        out ($1C),a
        ld a,(sho)
        ld (cntb),a
        ld b,a
        ld a,12
        sub b
        ld (cnta),a
        ld hl,cmb_list          ; only this shaft's combos (cmb_scan)
        ld b,(hl)
        inc hl
.k:     push bc
        ld a,(hl)
        inc hl
        push hl
        ld l,a                  ; IX = combo_src + k*4, DE = F800 + k*16
        ld h,0
        add hl,hl
        add hl,hl
        ld de,combo_src
        add hl,de
        push hl
        pop ix
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,$F800
        add hl,de
        ex de,hl
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(sho)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(cnta)
        ld c,a
        ld b,0
        ldir
        ld a,(cntb)
        or a
        jr z,.nb
        ld l,(ix+2)
        ld h,(ix+3)
        ld c,a
        ld b,0
        ldir
.nb:    pop hl
        pop bc
        djnz .k
        ld a,$80
        out ($1C),a
        ret

; The combos the loaded shaft uses -> cmb_list (count, then their numbers).  A shaft
; uses a few dozen of the ~100 there are; making only those each frame keeps the
; ride fast.
cmb_scan:
        ld hl,BOUNCE            ; 128 flags (BOUNCE is free once far_load is done)
        ld de,BOUNCE+1
        ld bc,127
        ld (hl),0
        ldir
        call shaft_rec          ; the map's length: rows after the row table
        inc hl
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld hl,-PM_ROWS
        add hl,bc
        ld b,h
        ld c,l
        ld hl,SHAFT_PM+PM_ROWS
.s:     ld a,(hl)
        and $7F
        ld e,a
        ld d,BOUNCE>>8
        ld a,1
        ld (de),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.s
        ld hl,BOUNCE
        ld de,cmb_list+1
        ld b,0                  ; count
        ld c,0                  ; k
.l:     ld a,(hl)
        or a
        jr z,.n
        ld a,c
        ld (de),a
        inc de
        inc b
.n:     inc hl
        inc c
        ld a,c
        cp NCOMBOS
        jr c,.l
        ld a,b
        ld (cmb_list),a
        ret

; Draw the stopped shaft view at shy into BACK, with the lift.
shaft_render:
        ld de,BACK
        ld b,ROOM_ROWS
.r:     push bc
        ld a,ROOM_ROWS          ; this row of the map (rows aren't adjacent in the
        sub b                   ;  compact map: look each one up)
        ld hl,shy
        add a,(hl)
        push de
        call pm_row
        pop de
        ld c,0
.c:     push hl
        ld a,(hl)
        and $7F
        ld hl,combo_a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)               ; tile A of the pair
        call tile_ptr
        push hl
        ld hl,(cur_colcol)
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        call put_cell
        pop hl
        inc hl
        inc c
        ld a,c
        cp COLS
        jr nz,.c
        pop bc
        djnz .r
        ld c,LIFT_ROW
        ld a,REG_C0
        call cell_addr
        ld a,h
        sub $40
        ld d,a
        ld e,l
        ld a,T_LIFT
        call tile_ptr
        ld a,$0B
        ld b,REG_C1-REG_C0+1
.l:     call put_cell
        djnz .l
        ret

; ---------------------------------------------------------------- shaft mode
; cur_shaft set; A = level, B = arrival (0 left tunnel, 1 right tunnel, 2 on the lift)
enter_shaft:
        push bc
        call set_level
        xor a
        ld (sho),a
        ld (lift_dir),a
        ld (wstate),a
        ld (sleep_t),a
        ld (sleep_t+1),a
        pop bc
        ld a,b
        cp 2
        ld a,LIFT_WX
        jr z,.side
        ld a,b
        or a
        ld a,6
        jr z,.side
        ld a,146
.side:  ld (wx),a
        ld a,SHAFT_WY
        ld (wy),a
        call shaft_rec          ; its letter and column colours first
        ld de,5+3*NLEVELS
        add hl,de
        ld a,(hl)
        ld (str_shaft+11),a
        inc hl
        ld (cur_colcol),hl
        call shaft_rec          ; this shaft's pair map from the banks
        ld de,SHAFT_PM
        call far_load
        call cmb_scan           ; which combos this shaft uses (gen_combos makes only those)
        call shaft_render
        ld hl,str_shaft
        call hud_draw
        call show_level
        call full_redraw
        call show_all           ; screen off: both pages as ordinary cells
        call blank_on           ; then everything but the band to combos
        ld b,0
        call .setup
        call swap_hidden
        ld b,0
        call .setup
        call swap_hidden
        call blank_off
        ld a,1
        ld (gmode),a
        jp wren_place
.setup: ld c,BAND_R0-1
        call map_combo
        ld b,BAND_R1+1
        ld c,ROOM_ROWS-1
        call map_combo
        ld a,PV_Y
        call pstate
        ld a,(shy)
        ld (hl),a
        ld a,PV_BAND
        call pstate
        ld (hl),0
        jp gen_combos

; HL = this shaft's record in shaft_tab.
shaft_rec:
        ld a,(cur_shaft)
        ld hl,shaft_tab
        or a
        ret z
        ld de,SHAFT_REC
.a:     add hl,de
        dec a
        jr nz,.a
        ret

; A = level: shy, the rooms on either side, walking limits.
set_level:
        ld (cur_level),a
        ld c,a
        add a,a
        add a,c
        add a,5
        push af
        call shaft_rec
        pop af
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (shy),a
        inc hl
        ld a,(hl)
        ld (lvl_left),a
        inc hl
        ld a,(hl)
        ld (lvl_right),a
        ld a,(lvl_left)
        inc a
        ld a,0
        jr nz,.l
        ld a,68
.l:     ld (wxmin),a
        ld a,(lvl_right)
        inc a
        ld a,WX_EXIT_R
        jr nz,.r
        ld a,84
.r:     ld (wxmax),a
        ret

show_level:
        ld hl,str_level
        ld a,24
        ld c,23
        ld e,$4D
        call print_at
        ld a,(cur_level)
        inc a
        add a,'0'
        ld c,23
        jp put_c1

shaft_update:
        ld a,(lift_dir)
        or a
        jp nz,.moving
        call wren_update
        ld a,(wx)               ; off the edge into a room?
        or a
        jr nz,.notl
        ld a,(lvl_left)
        cp $FF
        jr z,.notl
        ld b,1                  ; arrive through the room's right door
        jp enter_room
.notl:  ld a,(wx)
        cp WX_EXIT_R
        jr c,.notr
        ld a,(lvl_right)
        cp $FF
        jr z,.notr
        cp CORE_ROOM            ; the core stays sealed until all keys are online
        jr nz,.open
        ld a,(keys_done)
        cp (1<<NKEYS)-1
        jr z,.open
        ld a,140
        ld (wx),a
        ld hl,str_sealed
        call msg_show
        call present
        ld a,SPK_DENIED
        jp say
.open:  ld a,(lvl_right)
        ld b,0
        jp enter_room
.notr:  ld a,(wx)               ; on the lift? (anywhere on the platform)
        sub LIFT_WX-10
        cp 21
        ret nc
        ld a,(kbits)            ; Q / A or the arrow keys (read by wren_update)
        bit K_UP,a
        jr nz,.up
        bit K_DOWN,a
        ret z
        ld a,(cur_level)        ; down
        inc a
        cp NLEVELS
        ret nc
        ld b,2
        jr .go
.up:    ld a,(cur_level)
        or a
        ret z
        dec a
        ld b,1
.go:    ld (tgt_level),a
        ld a,b
        ld (lift_dir),a
        ld a,(tgt_level)
        call level_y
        ld (tgt_y),a
        call wren_erase         ; stand Wren in the middle of the lift
        ld a,LIFT_WX
        ld (wx),a
        jp wren_place

.moving:
        call sfx_hum
        ld a,(lift_dir)
        dec a
        jr nz,.down
        ld a,(sho)              ; up: the view moves up
        sub LIFT_STEP
        jr nc,.u1
        add a,12
        ld hl,shy
        dec (hl)
.u1:    ld (sho),a
        jr .arrive
.down:  ld a,(sho)
        add a,LIFT_STEP
        cp 12
        jr c,.d1
        sub 12
        ld hl,shy
        inc (hl)
.d1:    ld (sho),a
.arrive:
        ld a,(sho)
        or a
        ret nz
        ld a,(tgt_y)
        ld b,a
        ld a,(shy)
        cp b
        ret nz
        ld a,(tgt_level)        ; arrived; keep going if the key is still held
        ld (cur_level),a
        call show_level
        call read_keys          ; (Q / A or the arrow keys)
        ld a,(lift_dir)
        dec a
        jr nz,.hd
        ld a,(kbits)
        bit K_UP,a
        jr z,.stop
        ld a,(cur_level)
        or a
        jr z,.stop
        dec a
        jr .more
.hd:    ld a,(kbits)
        bit K_DOWN,a
        jr z,.stop
        ld a,(cur_level)
        inc a
        cp NLEVELS
        jr nc,.stop
.more:  ld (tgt_level),a
        call level_y
        ld (tgt_y),a
        ret
.stop:  xor a                   ; the band becomes ordinary cells again
        ld (lift_dir),a
        ld a,(cur_level)
        call set_level
        call shaft_render       ; the settled view onto BOTH pages, as on entry (the
        ld hl,str_shaft         ; scroll leaves the two pages out of step, which
        call hud_draw           ; flickered until you left the shaft)
        call show_level
        call full_redraw
        call show_all
        ld a,LIFT_WX
        ld (wx),a
        jp wren_place

; A = level -> A = its coarse y
level_y:
        ld c,a
        add a,a
        add a,c
        add a,5
        push af
        call shaft_rec
        pop af
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ret
