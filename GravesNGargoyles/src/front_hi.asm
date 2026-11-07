; high score table + initials entry (runs from SRAM, see BLOB1)
hiscore_card:
        ld de,hs_draw
        ld hl,400
        jp card_wait
hs_draw:
        ld hl,STR_HIGH
        ld c,4
        ld a,(col_yel)
        call text_fbc
        ld ix,hiscores
        ld b,5
        ld c,16
.lp:    push bc
        push bc
        push ix
        pop hl
        call bcd_to_str
        ; "AAA 000000"
        ld a,(ix+3)
        ld (text_buf),a
        ld a,(ix+4)
        ld (text_buf+1),a
        ld a,(ix+5)
        ld (text_buf+2),a
        ld a,' '
        ld (text_buf+3),a
        ld (text_buf+4),a
        ld hl,num_buf
        ld de,text_buf+5
        ld bc,8
        ldir
        pop bc
        ld hl,text_buf
        ld a,c
        cp 16
        ld a,(col_grn)
        jr nz,$+5
        ld a,(col_yel)
        call text_fbc
        ld de,6
        add ix,de
        pop bc
        ld a,c
        add a,8
        ld c,a
        djnz .lp
        ret

; insert the current score if it qualifies, entering initials
hiscore_check:
        ; find position
        ld ix,hiscores
        ld b,0
.f:     ld a,(score)
        cp (ix+0)
        jr c,.nx
        jr nz,.ins
        ld a,(score+1)
        cp (ix+1)
        jr c,.nx
        jr nz,.ins
        ld a,(score+2)
        cp (ix+2)
        jr c,.nx
        jr z,.nx
        jr .ins
.nx:    ld de,6
        add ix,de
        inc b
        ld a,b
        cp 5
        jr c,.f
        ret
.ins:   ; shift entries down
        push ix
        ld a,4
        sub b
        jr z,.ns
        ld c,a
        ld b,0
        ld hl,0
        ld de,6
.ml:    add hl,de
        dec c
        jr nz,.ml
        ld b,h
        ld c,l
        ld hl,hiscores+4*6-1
        ld de,hiscores+5*6-1
        lddr
.ns:    pop ix
        ld a,(score)
        ld (ix+0),a
        ld a,(score+1)
        ld (ix+1),a
        ld a,(score+2)
        ld (ix+2),a
        ld a,'A'
        ld (ix+3),a
        ld (ix+4),a
        ld (ix+5),a
        ; enter initials
        ld c,0
.ent:   push bc
        call cls_card
        ld hl,STR_NEWHI
        ld c,10
        ld a,(col_yel)
        call text_fbc
        ld hl,STR_ENTER
        ld c,20
        ld a,(col_grn)
        call text_fbc
        ld a,(ix+3)
        ld (text_buf),a
        ld a,(ix+4)
        ld (text_buf+1),a
        ld a,(ix+5)
        ld (text_buf+2),a
        xor a
        ld (text_buf+3),a
        ld hl,text_buf
        ld c,34
        ld a,(col_yel)
        call text_fbc
        pop bc
        push bc
        ; cursor under the current letter
        ld a,c
        add a,14
        ld b,a
        ld c,41
        ld hl,STR_CURSOR
        ld a,(col_grn)
        call text_fb
        call show_full
        call read_input
        pop bc
        push ix
        pop hl
        ld de,3
        add hl,de
        ld e,c
        add hl,de
        ld a,(keys_new)
        bit K_UP,a
        jr nz,.up
        bit K_RIGHT,a
        jr nz,.up
        bit K_DOWN,a
        jr nz,.dn
        bit K_LEFT,a
        jr nz,.dn
        and (1<<K_FIRE)|(1<<K_SWAP)
        jr z,.ent
        ld a,SFX_SELECT_ID
        call play_sfx
        inc c
        ld a,c
        cp 3
        jr c,.ent
        jp hiscore_card
.up:    ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,$+4
        ld a,'A'
        ld (hl),a
        jr .ent
.dn:    ld a,(hl)
        dec a
        cp 'A'
        jr nc,$+4
        ld a,'Z'
        ld (hl),a
        jr .ent

