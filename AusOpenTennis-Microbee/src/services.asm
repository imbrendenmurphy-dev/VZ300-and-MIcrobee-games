; =====================================================================
;  SERVICES for the front end (upper memory): calls that change the
;  lower window put the front end's block back afterwards (UCALL).
; =====================================================================
; upc: call (kb_tgt), then map the caller's block back. Registers pass
; through both ways (HL is preserved into the target).
upc:    push af
        ld a,(curblk)
        ld (kb_blk),a
        pop af
        call .go
        push af
        ld a,(kb_blk)
        call map_port
        pop af
        ret
.go:    push hl
        ld hl,(kb_tgt)
        ex (sp),hl
        ret

; ---------------------------------------------------------------------
; pictures: 0..4 courts, 5 title, 6 information page, 7 trophy
; (pic_tab: id*2 + mono). The front-end ones are kept unpacked.
BLK_CACHE equ 23                ; 23, 24, 25: title, info, trophy
BLK_PORT  equ 26                ; portraits (colour at 0, mono at 4000h)
G_PORT    equ 1568              ; three portrait slots of 50 glyphs

cache_pics:
        ld a,5
.l:     push af
        add a,BLK_CACHE-5
        call map_blk
        pop af
        push af
        add a,a
        ld hl,monomode
        add a,(hl)
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,court_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,0
        call unlzb_x
        pop af
        inc a
        cp 8
        jr nz,.l
        ret

; show_pic: A = 5..7 -> the picture on screen (glyphs from 512 on)
show_pic:
        add a,BLK_CACHE-5
        push af
        xor a
        ld (ump_pose),a
        ld (crowdtim),a
        ld hl,512
        ld (lp_first),hl
        pop af
        ld hl,0
        jp load_picture

; show_portrait: A = character, D = column, E = row (10 x 5 cells)
show_portrait:
        push de
        ld e,a
        ld d,0
        ld hl,850
        call mul16              ; HL = 850 * character
        ld a,(monomode)
        or a
        jr z,.c
        ld de,$4000
        add hl,de
.c:     push hl
        ld a,(port_slot)
        inc a
        cp 3
        jr c,.s
        xor a
.s:     ld (port_slot),a
        ld e,a
        add a,a
        add a,a
        add a,e                 ; *5
        add a,a                 ; *10
        ld e,a
        add a,a
        add a,a
        add a,e                 ; *50
        ld e,a
        ld d,0
        ld hl,G_PORT
        add hl,de
        ld (sp_g),hl
        ex de,hl
        pop hl
        push hl
        ld a,BLK_PORT
        call map_blk
        ld bc,50
        call glyphs_to_pcg      ; HL left after the patterns: the colours
        ld (sp_col),hl
        pop hl
        pop de
        ; the 10 x 5 cells
        ld c,5
.r:     push de
        ld b,10
.k:     push bc
        push de
        call cell_of_de
        ld a,BLK_PORT
        call map_blk
        push hl
        ld hl,(sp_col)
        ld c,(hl)
        inc hl
        ld (sp_col),hl
        pop hl
        ld de,(sp_g)
        push de
        inc de
        ld (sp_g),de
        pop de
        call set_cell
        pop de
        inc d
        pop bc
        djnz .k
        pop de
        inc e
        dec c
        jr nz,.r
        ret

; HL = DE * HL (16 bit)
mul16:  ld b,h
        ld c,l
        ld hl,0
        ld a,16
.l:     add hl,hl
        ex de,hl
        add hl,hl
        ex de,hl
        jr nc,.n
        add hl,bc
.n:     dec a
        jr nz,.l
        ret
