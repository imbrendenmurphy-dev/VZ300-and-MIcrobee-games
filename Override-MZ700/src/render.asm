; =====================================================================
;  render.asm - deck view and HUD
;
;  The view is 40 x 23 cells (screen rows 1-23) cut from the deck map at
;  (camx, camy).  Sprites (droids, shots, explosions) are written into
;  the map itself for the duration of a frame (old codes saved in
;  OVLBUF), the window is compared with SHADOW and only changed cells go
;  to VRAM, then the map is restored.
; =====================================================================

; B = x, C = y -> HL = MAP + y*128 + x
mapaddr:
        ld a,c
        or a
        rra
        ld h,a
        ld a,0
        rra
        or b
        ld l,a
        ld a,h
        add a,high MAP
        ld h,a
        ret

draw_view:
        call overlay_all
        ld a,(camx)
        ld b,a
        ld a,(camy)
        ld c,a
        call mapaddr
        ex de,hl
        ld hl,SHADOW+40
        ld b,VIEWH
.row:   push bc
        push de
        DUP 40
        ld a,(de)
        cp (hl)
        call nz,wcell
        inc de
        inc hl
        EDUP
        call poll
        pop de
        ex de,hl
        ld bc,MAPW
        add hl,bc
        ex de,hl
        pop bc
        dec b
        jp nz,.row
        jp ovl_restore

; changed cell: A = new code, HL = shadow cell (DE kept, BC trashed)
wcell:
        ld (hl),a
        ld c,a
        ld b,high CHRTAB
        ld a,h
        add a,10h
        ld h,a
        ld a,(bc)
        ld (hl),a
        inc b
        ld a,(bc)
        set 3,h
        ld (hl),a
        ld a,h
        sub 18h
        ld h,a
        ret

; ---------------------------------------------------------------------
; overlay
; ---------------------------------------------------------------------
; HL = map cell, A = code: remember the old code and write the new one
; (HL, BC, DE kept)
ovl_put:
        push de
        push hl
        ex de,hl
        ld hl,(ovlptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex af,af'
        ld a,(de)
        ld (hl),a
        inc hl
        ld (ovlptr),hl
        ex af,af'
        ld (de),a
        pop hl
        pop de
        ret

ovl_restore:
        ld hl,(ovlptr)
.l:     ld a,l
        cp low OVLBUF
        jr nz,.go
        ld a,h
        cp high OVLBUF
        jr z,.done
.go:    dec hl
        ld a,(hl)
        dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)
        ld (de),a
        jr .l
.done:  ld (ovlptr),hl
        ret

overlay_all:
        ld hl,OVLBUF
        ld (ovlptr),hl
        ; shots
        ld ix,SHOTS
        ld b,NSHOTS
.s:     push bc
        ld a,(ix+S_LIFE)
        or a
        call nz,ovl_shot
        ld bc,SHOTSZ
        add ix,bc
        pop bc
        djnz .s
        ; enemies, then the player on top
        ld ix,DROIDS+DSZ
        ld b,NDROIDS-1
.d:     push bc
        call ovl_droid
        ld bc,DSZ
        add ix,bc
        pop bc
        djnz .d
        ld a,(pl_dead)
        or a
        jr nz,.nopl
        ld a,(invuln)               ; blink while invulnerable
        or a
        jr z,.vis
        ld a,(frame)
        and 1
        jr nz,.nopl
.vis:   ld a,(xmode)                ; transfer mode: flash white
        or a
        jr z,.dp
        ld a,(frame)
        and 2
        jr z,.dp
        ld a,1
        ld (DROIDS+D_FLASH),a
.dp:    ld ix,DROIDS
        call ovl_droid
.nopl:  ; explosions on top of everything
        ld ix,EXPLS
        ld b,NEXPL
.e:     push bc
        ld a,(ix+E_T)
        or a
        call nz,ovl_expl
        ld bc,EXPLSZ
        add ix,bc
        pop bc
        djnz .e
        ret

; is (B,C) roughly in the view? (carry clear = yes)
in_view:
        ld a,(camx)
        ld e,a
        ld a,b
        sub e
        add a,4
        cp 46
        ccf
        ret c
        ld a,(camy)
        ld e,a
        ld a,c
        sub e
        add a,3
        cp 28
        ccf
        ret

ovl_shot:
        ld b,(ix+S_X)
        ld c,(ix+S_Y)
        call in_view
        ret c
        call mapaddr
        ld a,(ix+S_OWN)
        or a
        ld a,C_SHP0
        jr z,.p
        ld a,C_SHE0
.p:     ld c,a
        ld a,(ix+S_KIND)
        add a,a
        add a,c
        ld c,a
        ld a,(dimmed)
        add a,c
        jp ovl_put

ovl_expl:
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        call in_view
        ret c
        call mapaddr
        ld a,(ix+E_F)
        ld e,a
        add a,a
        add a,e
        add a,a                     ; *6
        ld e,a
        ld d,0
        push hl
        ld hl,EXPLFR
        add hl,de
        ex de,hl                    ; DE = frame cells
        pop hl
        ld b,2
.r:     ld c,3
.c:     ld a,(de)
        inc de
        cp 0FFh
        jr z,.n
        add a,a
        add a,C_EX0
        push bc
        ld b,a
        ld a,(dimmed)
        add a,b
        pop bc
        call ovl_put
.n:     inc hl
        dec c
        jr nz,.c
        push de
        ld de,MAPW-3
        add hl,de
        pop de
        djnz .r
        ret

; explosion frames: 6 cells (3x2) of glyph index (FF = leave alone)
EXPLFR:
        db 0FFh,0,0FFh, 0FFh,1,0FFh
        db 1,0,1, 2,1,2
        db 2,1,2, 1,0,1
        db 3,2,3, 2,3,2
        db 4,3,4, 3,4,3
        db 5,4,5, 4,5,4
        db 0FFh,5,0FFh, 5,0FFh,5
        db 0FFh,0FFh,5, 0FFh,5,0FFh
NEXPLF  equ 8

; droid: dome (left, eye, right) over three digits
ovl_droid:
        ld a,(ix+D_TYPE)
        cp 0FFh
        ret z
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        call in_view
        ret c
        call mapaddr
        ; body code base
        ld a,(ix+D_FLASH)
        or a
        ld a,(ix+D_CB)
        jr z,.nf
        ld a,C_DL5                  ; white flash
.nf:    ld e,a
        ld a,(dimmed)
        add a,a
        ld d,a                      ; dome offset: 0 lit / 2 dim
        ld a,e
        add a,d
        call ovl_put                ; left dome
        inc hl
        ld a,(ix+D_ANIM)
        rrca
        rrca
        and 3
        ld c,a
        ld b,0
        push hl
        ld hl,eyeseq
        add hl,bc
        ld a,(hl)
        pop hl
        add a,e
        add a,4
        call ovl_put                ; eye
        inc hl
        ld a,e
        add a,d
        inc a
        call ovl_put                ; right dome
        ld bc,MAPW-2
        add hl,bc
        ; digits
        push hl
        ld a,(ix+D_TYPE)
        call roster_ptr             ; HL = roster entry
        ld bc,R_D0
        add hl,bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        pop hl
        push af
        ld a,b
        add a,e
        add a,7
        call ovl_put
        inc hl
        ld a,c
        add a,e
        add a,7
        call ovl_put
        inc hl
        pop af
        add a,e
        add a,7
        jp ovl_put

eyeseq: db 0,1,2,1

; A = type -> HL = roster entry
roster_ptr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; *32
        ld bc,ROSTER
        add hl,bc
        ret

; ---------------------------------------------------------------------
; HUD: row 0 = score / deck, row 24 = host droid and energy
; ---------------------------------------------------------------------
hud_full:
        ld b,0
        ld c,1
        ld a,BLUE*16+BLACK
        push af
        call clear_rows
        pop af
        ld b,24
        ld c,1
        call clear_rows
        ld hl,txt_score
        ld b,1
        ld c,0
        ld a,CYAN*16+BLACK
        call print_at
        ld a,1
        ld (hud_dirty),a
        ld (hud_deck),a
        jp hud_update

hud_update:
        ld a,(hud_deck)
        or a
        call nz,hud_deckname
        ld a,(hud_dirty)
        or a
        ret z
        xor a
        ld (hud_dirty),a
        ; score
        ld hl,score+2
        ld b,3
        ld de,VRAM+7
        ld c,WHITE*16+BLACK
        call print_bcd
        ; host number and name
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        push hl
        ld bc,R_D0
        add hl,bc
        ld de,VRAM+24*40+1
        ld c,BLACK*16+YELLOW
        ld b,3
.dg:    ld a,(hl)
        add a,20h
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc hl
        inc de
        djnz .dg
        pop hl
        ld bc,R_NAME
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,VRAM+24*40+5
        ld c,YELLOW*16+BLACK
        call print
        ld a,(VRAM+24*40+5)         ; pad name to 12 chars
        ld a,e
        sub low (VRAM+24*40+5)
        ld b,a
        ld a,12
        sub b
        jr z,.nopad
        jr c,.nopad
        ld b,a
.pad:   xor a
        ld (de),a
        inc de
        djnz .pad
.nopad: ; energy bar: 16 cells, half-cell resolution
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        ld bc,R_EN
        add hl,bc
        ld c,(hl)                   ; max
        ld a,(DROIDS+D_EN)
        cp c
        jr c,$+3
        ld a,c
        ; halves = energy*32/max
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,0
.dv:    ld a,l                      ; HL - C*... simple repeated subtraction
        sub c
        ld l,a
        ld a,h
        sbc a,0
        ld h,a
        jr c,.dvd
        inc b
        jr .dv
.dvd:   ld a,b                      ; A = halves 0..32
        ld (hud_halves),a
        ; colour by level
        ld c,GREEN*16+BLACK
        cp 17
        jr nc,.col
        ld c,YELLOW*16+BLACK
        cp 9
        jr nc,.col
        ld c,RED*16+BLACK
.col:   ld de,VRAM+24*40+22
        ld h,a
        ld b,16
.bar:   ld a,h
        cp 2
        jr c,.half
        sub 2
        ld h,a
        ld a,43h                    ; full block
        jr .put
.half:  or a
        ld h,0
        jr z,.empty
        ld a,7Bh                    ; left half block
        jr .put
.empty: ld a,0D0h                   ; dim checker
        ld (de),a
        set 3,d
        ld a,BLUE*16+BLACK
        ld (de),a
        res 3,d
        inc de
        djnz .bar
        jr .bdone
.put:   ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        djnz .bar
.bdone: ld hl,txt_en
        ld de,VRAM+24*40+19
        ld c,CYAN*16+BLACK
        call print
        ret

hud_deckname:
        xor a
        ld (hud_deck),a
        ld a,(msg_time)
        or a
        ret nz                      ; a message is showing there
        ld b,16
        ld c,1
        ld a,BLUE*16+BLACK
        call .clr
        ld hl,(deck_hdr)
        ld bc,DK_NAME
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ; right-align: find length
        push hl
        ld b,0
.n:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        inc b
        jr .n
.e:     pop hl
        ld a,39
        sub b
        ld e,a
        ld d,0
        push hl
        ld hl,VRAM
        add hl,de
        ex de,hl
        pop hl
        ld a,(dimmed)
        or a
        ld c,YELLOW*16+BLACK
        jr z,$+4
        ld c,BLUE*16+BLACK
        call print
        ; "DECK n" before it
        ld hl,(deck_hdr)
        ret
.clr:   ld de,VRAM+16               ; blank columns 16-39 of row 0
        ld b,24
.c:     xor a
        ld (de),a
        inc de
        djnz .c
        ret

; show a message on row 0 (HL = text) for A frames
hud_msg:
        ld (msg_time),a
        push hl
        ld de,VRAM+16
        ld b,24
.c:     xor a
        ld (de),a
        inc de
        djnz .c
        pop hl
        ld (msg_text),hl
        ld de,VRAM+16
        ld c,WHITE*16+BLACK
        call print
        ret

; per frame: flash the message, restore the deck name when it expires
hud_msg_tick:
        ld a,(msg_time)
        or a
        ret z
        dec a
        ld (msg_time),a
        jr nz,.flash
        ld a,1
        ld (hud_deck),a
        ret
.flash: and 4
        ld a,WHITE*16+BLACK
        jr z,$+4
        ld a,YELLOW*16+BLACK
        ld de,VRAM+16
        ld b,24
        jp fill_attr

txt_score:  db "SCORE",0
txt_en:     db "EN",0
