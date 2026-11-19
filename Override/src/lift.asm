; =====================================================================
;  lift.asm - the lift: the ship in side view, ride the shaft up and
;  down, fire to step out.  In: lf_deck, lf_shaft. Out: A = deck.
;  console.asm - the deck map and the droid files
; =====================================================================
LIFT_Y0     equ 10

lift_main:
            ld a,$08
            call fe_setlatch
            ld a,(lf_deck)
            ld (lm_sel),a
            ld a,FX_LIFT
            call fe_sfx
            call lift_draw
            ld hl,1500
            ld (t_time),hl
.f:         call lift_car
            call fe_frame
            call fe_frame
            call read_input
            ld a,(demo)
            or a
            jr z,.real
            ; the autopilot rides one deck down (or up from the bottom)
            ld a,(fe_frames)
            and 63
            jr nz,.n3
            call lift_auto
            jr .go
.real:      ld a,(in_new)
            and K_UP
            jr z,.n1
            ld c,-1
            call lift_move
.n1:        ld a,(in_new)
            and K_DOWN
            jr z,.n2
            ld c,1
            call lift_move
.n2:        ld a,(in_new)
            and K_FIRE
            jr nz,.go
.n3:        ld hl,(t_time)
            dec hl
            ld (t_time),hl
            ld a,h
            or l
            jr nz,.f
.go:        ld a,FX_SELECT
            call fe_sfx
            ld a,10
            call fe_delay
            ld a,(lm_sel)
            ret

; demo: pick the next deck on this shaft that still has droids
lift_auto:
            ld c,1
            call .try
            ret nz
            ld c,-1
.try:       ld b,8
.l:         push bc
            call lift_move
            pop bc
            ld a,(lm_sel)
            call alive_slot
            ld a,(hl)
            inc hl
            or (hl)
            ret nz
            djnz .l
            ret

; C = direction: move the selection to the next deck the shaft serves
lift_move:
            ld a,(lm_sel)
            ld b,a
.l:         ld a,b
            add a,c
            bit 7,a
            ret nz
            ld hl,shipinfo+SI_NDECKS
            cp (hl)
            ret nc
            ld b,a
            call deck_has_shaft
            jr z,.l
            ld a,(lm_sel)
            ld c,a
            ld a,b
            ld (lm_sel),a
            push bc
            ld a,c
            call lift_bar           ; old selection back to normal
            pop bc
            ld a,b
            call lift_bar
            ld a,FX_LIFT
            call fe_sfx
            jp lift_label

; A = deck: NZ if lf_shaft runs through it
deck_has_shaft:
            push bc
            call sd_ptr
            ld de,SD_SHAFTS
            add hl,de
            ld a,(lf_shaft)
            ld b,a
            inc b
            ld a,(hl)
.s:         rrca
            djnz .s
            and $80
            pop bc
            ret

; A = deck -> HL = its ship-info entry
sd_ptr:
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,de
            add hl,hl               ; *18
            ld de,shipinfo+SI_DECKS
            add hl,de
            ret

lift_draw:
            ld a,$AA
            call fe_cls
            ld de,$0102
            call txt_colour
            ld hl,shipinfo+SI_NAME
            ld e,1
            call fe_strc
            ld a,(shipinfo+SI_NDECKS)
            ld b,a
            ld c,0
.d:         push bc
            ld a,c
            call lift_bar
            pop bc
            inc c
            djnz .d
            ; the shaft: a red line through the decks it serves
            ld a,(lf_shaft)
            ld e,a
            ld d,0
            ld hl,shipinfo+SI_SHAFTS
            add hl,de
            ld a,(hl)
            add a,a
            add a,2
            ld (lm_x),a
            ld a,(shipinfo+SI_NDECKS)
            ld c,0
            ld b,a
.s:         push bc
            ld a,c
            call deck_has_shaft
            pop bc
            push bc
            jr z,.ns
            ld a,c
            ld e,a
            add a,a
            add a,e
            add a,a                 ; 6d
            add a,LIFT_Y0-1
            ld c,a
            ld b,7
.sl:        push bc
            ld a,(lm_x)
            ld b,a
            ld a,3
            call fe_px
            pop bc
            inc c
            djnz .sl
.ns:        pop bc
            inc c
            djnz .s
            ld de,$0002
            call txt_colour
            ld hl,lift_txt
            ld e,58
            call fe_strc
            jp lift_label

; deck A's bar: green (droids aboard), blue-green (cleared), yellow (selected)
lift_bar:
            ld (lb_d),a
            call sd_ptr
            push hl
            pop ix
            ld a,(ix+SD_OFF)
            srl a                   ; 2 px a tile -> byte = off / 2
            ld d,a
            ld a,(ix+SD_W)
            srl a
            ld b,a
            ld a,(lb_d)
            ld e,a
            add a,a
            add a,e
            add a,a
            add a,LIFT_Y0
            ld e,a
            ld c,4
            ld a,(lb_d)
            ld hl,lm_sel
            cp (hl)
            ld a,$55
            jr z,.c
            ld a,(lb_d)
            push de
            call alive_slot
            ld a,(hl)
            inc hl
            or (hl)
            pop de
            ld a,$00
            jr nz,.c
            ld a,$22                ; cleared: green with blue
.c:         call fe_box
            ; you are here
            ld a,(lb_d)
            ld hl,lf_deck
            cp (hl)
            ret nz
            ld a,(lb_d)
            ld e,a
            add a,a
            add a,e
            add a,a
            add a,LIFT_Y0+1
            ld e,a
            ld d,0
            ld b,1
            ld c,2
            ld a,$FF
            jp fe_box

; the car blinks on the selected deck
lift_car:
            ld a,(fe_frames)
            and 7
            ret nz
            ld a,(lm_sel)
            ld e,a
            add a,a
            add a,e
            add a,a
            add a,LIFT_Y0
            ld c,a
            ld a,(lm_x)
            ld b,a
            ld a,(fe_frames)
            and 8
            ld a,1
            jr z,.p
            ld a,3
.p:         push bc
            call fe_px
            pop bc
            inc c
            ld a,(fe_frames)
            and 8
            ld a,1
            jr z,.q
            ld a,3
.q:         jp fe_px

; the name of the selected deck
lift_label:
            ld a,50
            ld b,6
            ld c,$AA
            call fe_rows
            ld a,(lm_sel)
            call sd_ptr
            push hl
            ld de,$0102
            call txt_colour
            ld a,(lm_sel)
            add a,'1'
            ld (t_buf+5),a
            ld hl,deck_txt
            ld de,t_buf
            ld bc,5
            ldir
            ld a,' '
            ld (t_buf+6),a
            pop hl
            ld de,t_buf+7
            call copy0
            ld hl,t_buf
            ld e,50
            jp fe_strc
deck_txt:   db "DECK "
lift_txt:   db "UP/DOWN RIDE, FIRE STEP OUT",0

; =====================================================================
; console: the deck map, then the droid files (up to your class)
console_main:
            ld a,$08
            call fe_setlatch
            ld a,FX_BEEP
            call fe_sfx
            call con_map
            ld hl,600
            ld (t_time),hl
.m:         call con_dots
            call fe_frame
            call fe_frame
            call read_input
            ld a,(in_new)
            and K_FIRE
            jr nz,.files
            ld hl,(t_time)
            dec hl
            ld (t_time),hl
            ld a,h
            or l
            jr nz,.m
            ret
.files:     ld a,FX_SELECT
            call fe_sfx
            ld a,(plr+O_TYPE)
            ld (cn_t),a
.show:      call con_file
.w:         call fe_frame
            call fe_frame
            call read_input
            ld a,(in_new)
            and K_FIRE
            ret nz
            ld a,(in_new)
            and K_UP|K_LEFT
            jr z,.dn
            call con_prev
            jr .show
.dn:        ld a,(in_new)
            and K_DOWN|K_RIGHT
            jr z,.w
            call con_next
            jr .show

; the files you can read: types whose class is no higher than your host's
con_next:
            ld a,(cn_t)
.l:         inc a
            cp NTYPES
            jr c,.c
            xor a
.c:         call con_ok
            jr nz,.l
            ld (cn_t),a
            ld a,FX_MOVE
            jp fe_sfx
con_prev:
            ld a,(cn_t)
.l:         dec a
            jp p,.c
            ld a,NTYPES-1
.c:         call con_ok
            jr nz,.l
            ld (cn_t),a
            ld a,FX_MOVE
            jp fe_sfx
; A = type: Z if readable (keeps A)
con_ok:
            push af
            ld c,T_CLASS
            call type_stat
            ld b,a
            ld a,(plr+O_TYPE)
            ld c,T_CLASS
            call type_stat
            cp b
            jr c,.no
            pop af
            cp a
            ret
.no:        pop af
            or 1
            ret

con_file:
            ld a,$AA
            call fe_cls
            ld de,$0102
            call txt_colour
            ld hl,dfile_txt
            ld e,1
            call fe_strc
            ld a,(cn_t)
            ld (r_page),a
            ld a,12
            call roster_entry
            ; the blurb
            ld de,$0002
            call txt_colour
            ld a,(cn_t)
            add a,a
            ld hl,r_blurbs
            call str_index
            push hl
            ld e,34
            call fe_strc
            pop hl
.e:         ld a,(hl)
            inc hl
            or a
            jr nz,.e
            ld e,40
            call fe_strc
            ld de,$0302
            call txt_colour
            ld hl,cfile_txt
            ld e,57
            jp fe_strc
dfile_txt:  db "CONSOLE: DROID FILES",0
cfile_txt:  db "UP/DOWN BROWSE, FIRE EXIT",0

; the deck map: 2 pixels x 2 rows a tile
con_map:
            ld a,$AA
            call fe_cls
            ld de,$0102
            call txt_colour
            ld hl,dinfo+DI_NAME
            ld e,1
            call fe_strc
            ld de,$0302
            call txt_colour
            ld hl,cmap_txt
            ld e,58
            call fe_strc
            xor a
            ld (cn_y),a
.r:         ld a,(cn_y)
            call map_row            ; -> BOUNCE (64 tiles)
            ; build 32 bytes: two tiles a byte
            ld hl,BOUNCE
            ld de,cn_line
            ld b,32
.b:         push bc
            ld a,(hl)
            call con_px
            add a,a
            add a,a
            add a,a
            add a,a
            ld c,a
            inc hl
            ld a,(hl)
            call con_px
            or c
            ld (de),a
            inc hl
            inc de
            pop bc
            djnz .b
            ; two rows of the buffer
            ld a,(cn_y)
            add a,a
            add a,8
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,FEBB
            add hl,de
            ex de,hl
            ld hl,cn_line
            ld bc,32
            ldir
            ld hl,cn_line
            ld bc,32
            ldir
            ld hl,cn_y
            inc (hl)
            ld a,(deck_h)
            cp (hl)
            jr nz,.r
            jp fe_markall

; A = tile -> A = two pixels (4 bits) of its map colour
con_px:
            push hl
            ld hl,tattr
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            pop hl
            bit 6,a                 ; void: blue
            jr nz,.blue
            push af
            and A_DOOR|A_LIFT|A_CONSOLE|A_ENERGY
            jr nz,.yel
            pop af
            and A_SOLID             ; walls and props: red, floor: green
            ret z
            ld a,$0F
            ret
.yel:       pop af
            ld a,$05
            ret
.blue:      ld a,$0A
            ret

; droids (red) and you (blinking yellow) on the map
con_dots:
            ld a,(fe_frames)
            and 7
            ret nz
            ld ix,droids
            ld b,MAXDROIDS
.d:         push bc
            ld a,(fe_frames)        ; droids blink red / blue
            and 8
            ld a,3
            jr z,.dc
            ld a,2
.dc:        bit 7,(ix+O_FLAGS)
            call nz,con_dot
            ld de,OSZ
            add ix,de
            pop bc
            djnz .d
            ld ix,plr
            ld a,(fe_frames)
            and 8
            ld a,1
            jr z,con_dot
            ld a,0
; IX = object, A = colour: a pixel at its tile
con_dot:
            ld (cd_c),a
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld bc,6
            add hl,bc
            srl h
            rr l
            srl h
            rr l                    ; x / 4 = 2 px a tile
            ld b,l
            ld a,(ix+O_Y)
            add a,4
            ld l,a
            ld h,HIGH(DIV6)
            ld a,(hl)               ; y / 6
            add a,a
            add a,8
            ld c,a
            call .two
            inc c
.two:       ld a,(cd_c)             ; two pixels side by side
            push bc
            call fe_px
            pop bc
            push bc
            inc b
            ld a,(cd_c)
            call fe_px
            pop bc
            ret
cmap_txt:   db "FIRE: DROID FILES",0

lm_sel:     ds 1
lm_x:       ds 1
lb_d:       ds 1
cn_t:       ds 1
cn_y:       ds 1
cd_c:       ds 1
cn_line:    ds 32
