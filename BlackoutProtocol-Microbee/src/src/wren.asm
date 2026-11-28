; ---------------------------------------------------------------------------
; Agent Wren: movement, physics and drawing.
; wx = box left in half-pixels (2 px), wy = box top in pixels; the box is 24 x 24.
; Frames are 24 x 24 (mask + pixels), drawn shifted by (wx & 3) * 2 pixels and
; mirrored through tables when facing left.
; ---------------------------------------------------------------------------
WS_GROUND equ 0
WS_VAULT equ 1
WS_FALL  equ 2
WS_SEARCH equ 3
WS_RIDE  equ 4
WS_LAND  equ 5
K_LEFT   equ 0
K_RIGHT  equ 1
K_UP     equ 2
K_DOWN   equ 3
K_FIRE   equ 4
WX_EXIT_R equ 152
ROOM_MAP equ $E400
ROOM_COL equ $E7A0
VAULT_PREP equ 4
VAULT_AIR equ 36
VAULT_AIR_LG equ 52
SEARCH_TIME equ 96

read_keys:
        ld c,0
        ld hl,key_tab
.k:     ld a,(hl)
        cp $FF
        jr z,.done
        inc hl
        call scan_key
        ld a,(hl)
        inc hl
        jr z,.k
        or c
        ld c,a
        jr .k
.done:  ld a,(demo_on)          ; the attract demo: Wren drives herself
        or a
        call nz,demo_keys
        ld a,(kbits)
        cpl
        and c
        ld (knew),a
        ld a,c
        ld (kbits),a
        ret
K_DECK  equ 5
key_tab:
        db KEY_O,1<<K_LEFT, 59,1<<K_LEFT
        db KEY_P,1<<K_RIGHT, 62,1<<K_RIGHT
        db KEY_Q,1<<K_UP, 56,1<<K_UP
        db KEY_A,1<<K_DOWN, 58,1<<K_DOWN
        db KEY_SPACE,1<<K_FIRE
        db KEY_W,1<<K_DECK
        db $FF

wren_update:
        call read_keys
        ld a,(wstate)
        add a,a
        ld l,a
        ld h,0
        ld de,.jt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.jt:    dw st_ground, st_vault, st_fall, st_search, st_ride, st_land, st_term, st_dead

; ---------------------------------------------------------------- on the ground
st_ground:
        ld a,(gmode)
        or a
        jr z,.room
        ld a,(knew)             ; the shaft tunnels: walking, and the wrist-deck
        bit K_DECK,a
        jp nz,deck_open
        jp .walk
.room:
        ld a,(knew)
        bit K_DECK,a
        jp nz,deck_open
        bit K_FIRE,a
        jp nz,start_vault
        ld a,(kbits)
        and (1<<K_UP)|(1<<K_DOWN)
        jr z,.nolock
        ld a,(srch_lock)
        or a
        jr nz,.walk
        call pad_under
        cp $FF
        jr z,.search
        call pad_go
        ret nz
.search:
        ld a,(kbits)
        bit K_UP,a
        jr z,.walk
        call term_under
        bit 2,a
        jp nz,start_term
        bit 3,a
        jp nz,splice_open
        call searchable
        jr nc,.walk
        ld a,WS_SEARCH
        ld (wstate),a
        xor a
        ld (wtim),a
        ld (sprog),a
        ld hl,str_blank
        jp msg_show
.nolock:
        xor a
        ld (srch_lock),a
.walk:  xor a
        ld (wmove),a
        ld a,(kbits)
        bit K_RIGHT,a
        jr nz,.right
        bit K_LEFT,a
        jr nz,.left
        jr .anim
.right: call mist_skip           ; spore mist: every other step only
        jr c,.anim
        ld a,(wface)
        or a
        call nz,.turn
        xor a
        ld (wface),a
        ld a,(wxmax)
        ld b,a
        ld a,(wx)
        cp b
        jr nc,.anim
        inc a
        ld (wx),a
        jr .moved
.left:  call mist_skip
        jr c,.anim
        ld a,(wface)
        or a
        call z,.turn
        ld a,1
        ld (wface),a
        ld a,(wxmin)
        ld b,a
        ld a,(wx)
        cp b
        jr z,.anim
        jr c,.anim
        dec a
        ld (wx),a
.moved: ld a,1
        ld (wmove),a
.anim:  call floor_fx            ; conveyors and ice
        ld a,(turnt)
        or a
        jr z,.noturn
        dec a
        ld (turnt),a
        ld b,a                  ; three in-betweens over six ticks
        ld a,5
        sub b
        srl a
        add a,F_TURN
        jr .setf
.noturn:
        ld a,(wmove)
        or a
        jr nz,.run
        ld a,2                  ; stopped: start the next run on a stride
        ld (runfr),a
        xor a
        ld (runsub),a
        ld a,F_STAND
        jr .setf
.run:   ld hl,runsub
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.rf
        ld (hl),0
        ld a,(runfr)            ; 10 frames a stride pair (Muybridge, plate 60)
        inc a
        cp RUN_FRAMES
        jr c,.nw
        xor a
.nw:    ld (runfr),a
        cp 1                    ; a foot comes down on frames 1 and 6
        call z,sfx_step
        ld a,(runfr)
        cp 6
        call z,sfx_step
.rf:    ld a,(runfr)
        add a,F_RUN
.setf:  ld (wframe),a
        ld a,(gmode)
        or a
        ret nz
        call on_floor           ; walked off an edge?
        ret c
        jp start_fall
.turn:  ld a,(wmove)            ; (called with the old facing still set)
        ld a,6
        ld (turnt),a
        ret

; ---------------------------------------------------------------- vault
; Spore mist round Wren's middle: carry on odd frames (the step is skipped).
mist_skip:
        ld a,(gmode)
        or a
        ret nz                  ; (carry clear)
        call on_floor
        ret nc                  ; (not on a floor: no mist)
        dec b
        ld c,b
        ld a,(wx)
        add a,6
        srl a
        srl a
        call tile_flags_at
        and $40
        ret z
        ld a,(frames)
        rrca
        ret

; A = flags of the tile at column A, row C.
tile_flags_at:
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
        ret

; Conveyors carry Wren; on ice he keeps sliding after he lets go.
floor_fx:
        ld a,(gmode)
        or a
        ret nz
        call on_floor
        ret nc
        ld a,c
        ld c,b
        call tile_flags_at
        ld b,a
        bit 4,b                 ; conveyor right
        jr z,.cl
        ld a,(frames)
        and 1
        ret nz
        jp push_right
.cl:    bit 5,b                 ; conveyor left
        jr z,.ice
        ld a,(frames)
        and 1
        ret nz
        jp push_left
.ice:   bit 7,b
        jr z,.dry
        ld a,(wmove)
        or a
        jr z,.slide
        ld a,14                 ; moving: build up momentum
        ld (slide),a
        ret
.slide: ld a,(slide)
        or a
        ret z
        dec a
        ld (slide),a
        ld a,(wface)
        or a
        jp z,push_right
        jp push_left
.dry:   xor a
        ld (slide),a
        ret
push_right:
        ld a,(wxmax)
        ld b,a
        ld a,(wx)
        cp b
        ret nc
        inc a
        ld (wx),a
        ret
push_left:
        ld a,(wxmin)
        ld b,a
        ld a,(wx)
        cp b
        ret z
        ret c
        dec a
        ld (wx),a
        ret

start_vault:
        call sfx_vault
        ld a,WS_VAULT
        ld (wstate),a
        xor a
        ld (wtim),a
        ld a,(wy)
        ld (wy0),a
        ld a,F_VAULT
        ld (wframe),a
        ret

st_vault:
        ld hl,wtim
        inc (hl)
        ld a,(hl)
        cp VAULT_PREP
        ret c                   ; crouching
        sub VAULT_PREP
        ld c,a                  ; t = 0 .. air time - 1
        ld a,(lowgrav)
        or a
        ld a,c
        jr nz,.lg
        cp VAULT_AIR
        jr nc,.end
        jr .air
.lg:    cp VAULT_AIR_LG         ; low gravity: a longer, higher, slower arc
        jr nc,.end
        srl a                   ; (the spin frames run at half speed)
        ld c,a
.air:
        ld a,(wface)            ; forward one step
        or a
        jr nz,.l
        ld a,(wxmax)
        ld b,a
        ld a,(wx)
        cp b
        jr nc,.y
        inc a
        ld (wx),a
        jr .y
.l:     ld a,(wxmin)
        ld b,a
        ld a,(wx)
        cp b
        jr z,.y
        jr c,.y
        dec a
        ld (wx),a
.y:     ld b,0
        ld hl,vault_dy
        ld a,(lowgrav)
        or a
        jr z,.dy
        ld a,(wtim)
        sub VAULT_PREP
        ld e,a
        ld d,0
        ld hl,vault_dy_lg
        add hl,de
        jr .dy2
.dy:    add hl,bc
.dy2:
        ld a,(wy0)
        add a,(hl)
        ld (wy),a
        ld a,c                  ; frame: takeoff, 7 spin frames, open
        cp 3
        ld a,F_VAULT+1
        jr c,.f
        ld a,c
        cp 31
        ld a,F_VAULT+9
        jr nc,.f
        ld a,c
        sub 3
        srl a
        srl a
        add a,F_VAULT+2
.f:     ld (wframe),a
        ret
.end:   ld a,(wy0)
        ld (wy),a
        call on_floor
        jp nc,start_fall
land:   call sfx_land
        ld a,WS_LAND
        ld (wstate),a
        xor a
        ld (wtim),a
        ld a,F_VAULT+10
        ld (wframe),a
        ret

st_land:
        ld hl,wtim
        inc (hl)
        ld a,(hl)
        cp 5
        ret c
        xor a
        ld (wstate),a
        ld a,F_STAND
        ld (wframe),a
        ret

; ---------------------------------------------------------------- falling
start_fall:
        ld a,WS_FALL
        ld (wstate),a
        xor a
        ld (vy),a
        ld (wtim),a
        ld a,F_FALL
        ld (wframe),a
        ret

st_fall:
        ld hl,wtim
        inc (hl)
        ld a,(hl)
        push af                 ; flailing: two frames
        rrca
        rrca
        and 1
        add a,F_FALL
        ld (wframe),a
        pop af
        and 1
        jr nz,.go
        ld a,(lowgrav)          ; low gravity: a slow fall
        or a
        jr z,.ng
        ld a,(wtim)
        and 3
        jr nz,.go
        ld a,(vy)
        cp 2
        jr nc,.go
        jr .inc
.ng:    ld a,(vy)
        cp 6
        jr nc,.go
.inc:   ld a,(vy)
        inc a
        ld (vy),a
.go:    ld a,(vy)
        or a
        ret z
        ld b,a
.px:    ld a,(wy)
        inc a
        ld (wy),a
        cp ROOM_WY+1
        jp nc,start_death       ; below the bottom floor
        push bc
        call on_floor
        pop bc
        jp c,land
        djnz .px
        ret

start_death:
        ld a,WS_DEAD
        ld (wstate),a
        xor a
        ld (wtim),a
        ld a,F_DIE
        ld (wframe),a
        ld hl,deaths
        inc (hl)
        jp sfx_die

st_dead:
        ld hl,wtim
        inc (hl)
        ld a,(hl)
        ld b,F_DIE+3            ; jolt, jolt..., slump, then flat
        cp 40
        jr nc,.df
        dec b
        cp 24
        jr nc,.df
        rrca
        rrca
        and 1
        add a,F_DIE
        ld b,a
.df:    ld a,b
        ld (wframe),a
        ld a,(hl)
        cp 60
        ret c
; Caught or fell: ten minutes off the clock, back to the door.
wren_die:
        ld a,(clk_m)
        ld hl,pen_min
        sub (hl)
        jr nc,.m
        add a,60
        ld hl,clk_h
        dec (hl)
        jp m,game_over
.m:     ld (clk_m),a
        call show_clock
        ld a,(deaths)           ; MERIDIAN gloats now and then
        and 1
        ld a,SPK_AGAIN
        call nz,say
        ld hl,str_penalty
        call msg_show
        ld a,(arr_x)
        ld (wx),a
        ld a,(arr_face)
        ld (wface),a
        ld a,(arr_y)
        ld (wy),a
        call robots_reset
        ld a,(grace_n)          ; and a moment's grace
        ld (grace),a
        xor a
        ld (wstate),a
        ld a,F_STAND
        ld (wframe),a
        ret

; Carry set if Wren's feet are on something solid.  B = floor row, C = column.
on_floor:
        ld a,(wy)
        add a,24
        ld e,a                  ; feet
        ld l,a
        ld h,0
        push hl
        ld de,yline
        add hl,de
        ld a,(hl)
        pop hl
        or a
        ret nz                  ; (carry clear) not on a cell boundary
        ld de,ycell
        add hl,de
        ld b,(hl)               ; floor row
        ld a,(wx)
        add a,6
        srl a
        srl a
        ld c,a                  ; column under Wren's middle
        call pad_at
        ret c
        push bc
        ld a,c                  ; column
        ld c,b                  ; row
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
        rra                     ; bit 0 -> carry
        ret

; HL = row C * 42 + column A.  Preserves BC.
map_index:
        push af
        ld l,c
        ld h,0
        call times42
        pop af
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; Carry set if furniture you can search stands behind Wren.
searchable:
        call on_floor
        ret nc
        dec b
        ld a,b                  ; the row above the floor
        ld (srch_row),a
        ld a,(wx)
        add a,6
        srl a
        srl a
        ld (srch_c0),a
        call .try               ; right behind Wren
        ret c
        ld a,(wface)            ; else a cell to the side she faces, else the other
        or a
        ld a,1
        jr z,.f
        ld a,$FF
.f:     ld (srch_d),a
        ld hl,srch_d
        ld a,(srch_c0)
        add a,(hl)
        call .try
        ret c
        ld hl,srch_d
        ld a,(srch_c0)
        sub (hl)
.try:   cp 42                   ; (off the edge: nothing)
        ret nc
        ld (srch_col),a
        ld a,(srch_row)
        ld c,a
        ld a,(srch_col)
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
        and 2
        ret z                   ; (NC: nothing to search here)
        ld a,(srch_row)         ; already searched?
        ld b,a
        ld a,(srch_col)
        ld c,a
        call fit_find
        cp $FF
        jr nz,.have
        ld a,(srch_col)         ; the right half of a two-cell fitting?
        or a
        scf
        ret z
        dec a
        ld c,a
        ld a,(srch_row)
        ld b,a
        call fit_find
        cp $FF
        scf
        ret z                   ; (searchable, no record: a search finds nothing)
        ld hl,srch_col
        dec (hl)
.have:  call fit_searched
        scf
        ret z
        or a
        ret

; ---------------------------------------------------------------- searching
st_search:
        ld a,(kbits)
        bit K_UP,a
        jr nz,.on
        xor a                   ; let go: stop
        ld (wstate),a
        ld hl,str_blank
        jp msg_show
.on:    ld hl,wtim
        inc (hl)
        ld a,(hl)
        rrca
        rrca
        rrca
        and 3                   ; kneel, reach, rummage, rummage
        add a,F_SEARCH
        ld (wframe),a
        ld hl,sprog
        inc (hl)
        ld a,(hl)
        cp SEARCH_TIME
        jr nc,.done
        and 7
        ret nz
        ld a,(hl)               ; another block on the bar
        rrca
        rrca
        rrca
        and $1F
        push af
        call sfx_tick
        pop af
        add a,MSG_COL-1
        ld (pr_col),a
        ld a,$4D
        ld (pr_ink),a
        ld c,23
        ld a,'#'
        jp put_char
.done:  xor a
        ld (wstate),a
        ld a,1
        ld (srch_lock),a        ; wait for UP to be released
        ld a,F_STAND
        ld (wframe),a
        jp loot_found

; HUD message area: row 23, columns MSG_COL.., 12 characters.
MSG_COL equ 19
msg_show:
        ld a,MSG_COL
        ld (pr_col),a
        ld a,$4F
        ld (pr_ink),a
        ld b,14
.c:     ld a,(hl)
        or a
        jr z,.pad
        inc hl
        jr .put
.pad:   ld a,' '
.put:   push bc
        push hl
        ld c,23
        call put_char
        ld hl,pr_col
        inc (hl)
        pop hl
        pop bc
        djnz .c
        ret

; ---------------------------------------------------------------- lift pads
; Per pad: column, floor count, up to four floor rows (top first), current
; level, y (pixels, top of the pad), old y, direction (0 / -2 / +2), target y.
pads_init:
        ld hl,(STAGE+2)
        ld de,STAGE
        add hl,de
        ld a,(hl)
        ld (npads),a
        inc hl
        ld b,a
        ld c,0
        or a
        ret z
.p:     push bc
        ld a,(hl)
        ld (ix_c),a
        inc hl
        ld a,(hl)
        ld (ix_n),a
        inc hl
        push hl
        ld a,c                  ; copy into the pad's slots
        call pad_ptr            ; IX = pad record
        ld a,(ix_c)
        ld (ix+P_COL),a
        ld a,(ix_n)
        ld (ix+P_N),a
        dec a
        ld (ix+P_LV),a
        pop hl
        push hl
        ld a,(hl)
        ld (ix+P_FL),a
        inc hl
        ld a,(hl)
        ld (ix+P_FL+1),a
        inc hl
        ld a,(hl)
        ld (ix+P_FL+2),a
        inc hl
        ld a,(hl)
        ld (ix+P_FL+3),a
        ld a,(ix+P_LV)          ; resting on its bottom floor
        call pad_floor_y
        ld (ix+P_Y),a
        ld (ix+P_OY),a
        xor a
        ld (ix+P_DIR),a
        ld (ix+P_MOVED),a
        call pad_bake
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        pop bc
        inc c
        djnz .p
        ret

P_COL   equ 0
P_N     equ 1
P_FL    equ 2
P_LV    equ 6
P_Y     equ 7
P_OY    equ 8
P_DIR   equ 9
P_TGT   equ 10
P_MOVED equ 11
P_SIZE  equ 12

pad_ptr:
        ld ix,pads
        or a
        ret z
        ld de,P_SIZE
.a:     add ix,de
        dec a
        jr nz,.a
        ret

; A = level -> A = that floor's y in pixels (row * 12)
pad_floor_y:
        push ix
        pop hl
        ld de,P_FL
        add hl,de
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld l,a
        add a,a
        add a,l                 ; *3
        add a,a
        add a,a                 ; *12
        ret

; Carry set if a pad at row B (its top on Wren's feet) covers column C.
pad_at: ld a,(npads)
        or a
        ret z
        push bc
        ld e,a
        ld a,b                  ; row -> y
        add a,a
        add a,b
        add a,a
        add a,a
        ld d,a
        ld ix,pads
.p:     ld a,(ix+P_Y)
        cp d
        jr nz,.n
        ld a,c
        sub (ix+P_COL)
        cp 3
        jr c,.yes
.n:     push de
        ld de,P_SIZE
        add ix,de
        pop de
        dec e
        jr nz,.p
        pop bc
        or a
        ret
.yes:   pop bc
        scf
        ret

; A = index of the resting pad Wren stands on, or $FF.
pad_under:
        call on_floor
        ld a,$FF
        ret nc
        ld a,(npads)
        or a
        ld a,$FF
        ret z
        ld a,b                  ; feet y
        add a,a
        add a,b
        add a,a
        add a,a
        ld d,a
        ld a,(npads)
        ld e,a
        ld ix,pads
        ld l,0
.p:     ld a,(ix+P_DIR)
        or a
        jr nz,.n
        ld a,(ix+P_Y)
        cp d
        jr nz,.n
        ld a,c
        sub (ix+P_COL)
        cp 3
        ld a,l
        ret c
.n:     push de
        ld de,P_SIZE
        add ix,de
        pop de
        inc l
        dec e
        jr nz,.p
        ld a,$FF
        ret

; Start pad A moving up or down if a key asks for it.  NZ if it went.
pad_go: call pad_ptr
        ld a,(kbits)
        bit K_UP,a
        jr z,.down
        ld a,(ix+P_LV)
        or a
        ret z
        dec a
        jr .go
.down:  ld a,(ix+P_LV)
        inc a
        cp (ix+P_N)
        jr c,.go
        xor a
        ret
.go:    ld (ix+P_LV),a
        call pad_floor_y
        ld (ix+P_TGT),a
        ld b,2
        cp (ix+P_Y)
        jr nc,.dir
        ld b,-2
.dir:   ld (ix+P_DIR),b
        ld (ix+P_MOVED),0
        call pad_unbake
        ld a,WS_RIDE
        ld (wstate),a
        ld (ride_ix),ix
        ld a,F_STAND
        ld (wframe),a
        or 1
        ret

st_ride:
        ld ix,(ride_ix)
        ld a,(ix+P_Y)
        sub 24
        ld (wy),a
        ld a,(ix+P_DIR)
        or a
        ret nz
        xor a                   ; the pad has stopped
        ld (wstate),a
        ret

; Move every pad that's going (before drawing).
pads_update:
        call pads_moving
        or a
        call nz,sfx_hum
        ld a,(npads)
        or a
        ret z
        ld b,a
        ld ix,pads
.p:     ld a,(ix+P_DIR)
        or a
        jr z,.n
        ld a,(ix+P_Y)           ; (P_OY is where it was last DRAWN: pads_draw sets it,
        add a,(ix+P_DIR)        ;  so two or three ticks in one frame leave no trail)
        ld (ix+P_Y),a
        ld (ix+P_MOVED),1
        cp (ix+P_TGT)
        jr nz,.n
        ld (ix+P_DIR),0         ; arrived (baked in pads_draw)
.n:     ld de,P_SIZE
        add ix,de
        djnz .p
        ret

; A = 1 if any pad is moving or just stopped (everything near it redraws).
pads_moving:
        ld a,(npads)
        or a
        ret z
        ld b,a
        ld ix,pads
.p:     ld a,(ix+P_DIR)
        or (ix+P_MOVED)
        jr nz,.y
        ld de,P_SIZE
        add ix,de
        djnz .p
        xor a
        ret
.y:     ld a,1
        ret

; After Wren is erased: redraw moving pads, bake the ones that just stopped.
pads_draw:
        ld a,(npads)
        or a
        ret z
        ld b,a
        ld ix,pads
.p:     push bc
        ld a,(ix+P_MOVED)
        or a
        jr z,.n
        ld (ix+P_MOVED),0
        ld a,(ix+P_OY)          ; restore the old rows
        call pad_rows
.r:     ld a,(prow1)
        cp c
        jr c,.drawn
        ld a,(ix+P_COL)
        call cell_addr
        ld b,3
.c:     push bc
        call restore_cell
        ld de,16
        add hl,de
        pop bc
        djnz .c
        inc c
        jr .r
.drawn: ld a,(ix+P_Y)            ; drawn here now
        ld (ix+P_OY),a
        ld a,(ix+P_DIR)
        or a
        jr nz,.mv
        call pad_bake
        jr .n
.mv:    call pad_paint
.n:     ld de,P_SIZE
        add ix,de
        pop bc
        djnz .p
        ret

; A = y -> C = first cell row, prow1 = last cell row of a 5-line pad
pad_rows:
        ld l,a
        ld h,0
        ld de,ycell
        add hl,de
        ld c,(hl)
        ld de,4
        add hl,de
        ld a,(hl)
        ld (prow1),a
        ret

; NATIVE cell at HL back to BACK's copy, queued.  Preserves HL, C.
restore_cell:
        push bc
        push hl
        ld d,h
        ld e,l
        ld a,h
        sub $40
        ld h,a
        ld bc,13
        ldir
        pop hl
        pop bc
        jp dirty_cell

; Draw pad IX at its y into NATIVE (moving).
pad_paint:
        ld a,T_LIFT
        call tile_ptr
        ld (ppat),hl
        ld a,(ix+P_Y)
        ld (py),a
        ld b,5
.l:     push bc
        ld a,(py)
        ld l,a
        ld h,0
        ld de,ycell
        add hl,de
        ld c,(hl)               ; cell row
        ld de,yline-ycell
        add hl,de
        ld a,(hl)
        ld (pline),a
        ld a,(ix+P_COL)
        call cell_addr
        ld a,(pline)
        or l
        ld l,a
        ld de,(ppat)
        ld a,(de)
        ld (pbyte),a
        inc de
        ld (ppat),de
        ld b,3
.c:     ld a,(pbyte)
        or (hl)
        ld (hl),a
        push hl
        ld a,l
        and $F0
        or 12
        ld l,a
        ld a,(hl)
        and $F0
        or $0B
        ld (hl),a
        call dirty_cell
        pop hl
        ld de,16
        add hl,de
        djnz .c
        ld hl,py
        inc (hl)
        pop bc
        djnz .l
        ret
; Pad IX at rest: draw it into BACK at its row (and queue it).
pad_bake:
        ld a,(ix+P_Y)
        ld l,a
        ld h,0
        ld de,ycell
        add hl,de
        ld c,(hl)
        ld a,(ix+P_COL)
        ld b,3
.c:     push af
        push bc
        call map_index
        ld de,ROOM_COL
        add hl,de
        ld a,(hl)
        and $F0
        or $0B
        ld e,a
        ld d,T_LIFT
        pop bc
        pop af
        push af
        push bc
        call redraw_cell
        pop bc
        pop af
        inc a
        djnz .c
        ret

; Pad IX leaves: its row's cells back to the room's own tiles.
pad_unbake:
        ld a,(ix+P_Y)
        ld l,a
        ld h,0
        ld de,ycell
        add hl,de
        ld c,(hl)
        ld a,(ix+P_COL)
        ld b,3
.c:     push af
        push bc
        call map_index
        push hl
        ld de,ROOM_MAP
        add hl,de
        ld d,(hl)
        pop hl
        push de
        ld de,ROOM_COL
        add hl,de
        pop de
        ld e,(hl)
        pop bc
        pop af
        push af
        push bc
        call redraw_cell
        pop bc
        pop af
        inc a
        djnz .c
        ret

; Cell (column A, row C) = tile D in colour E, in BACK and NATIVE (queued).
redraw_cell:
        call cell_addr          ; HL = NATIVE cell
        push hl
        ld a,h
        sub $40
        ld h,a
        push de
        ld a,d
        ex de,hl                ; DE = BACK cell
        call tile_ptr
        pop bc
        ld a,c                  ; colour
        call put_cell
        pop hl                  ; NATIVE cell
        ld d,h
        ld e,l
        ld a,h
        sub $40
        ld h,a                  ; HL = BACK cell
        ld bc,13
        ldir
        ex de,hl
        ld bc,-13
        add hl,bc
        jp dirty_cell
str_blank:   db 0
str_penalty: db "- 10 MINUTES",0
