; ---------------------------------------------------------------------
; gallery.inc - the storyboard parade (each world module carries it, as
; main RAM is full): the world's scenery, creatures and boss pass by over
; the stilled landscape, each named as it comes to the middle. A serpent
; boss (no name for its body) passes as one chain: head, four body
; segments, tail. Entered from main's gallery: by jumping to W_GAL-3.
; ---------------------------------------------------------------------
gal_show:
            ld c,7                  ; a serpent (no name for its body)? then the
            call gal_name           ; body and tail follow the head as one chain
            ld a,(hl)
            ld (gal_chain),a
.f:         call read_input
            ld a,(dtf)
            ld (dt),a
            call sound_tick
            ld a,(dt)
            ld hl,anim
            add a,(hl)
            ld (hl),a
            call map_game
            call render_bg
            ld hl,BB                ; the top rows (no HUD here): sky
            ld de,BB+1
            ld bc,6*32-1
            ld a,(sky_byte)
            ld (hl),a
            ldir
            ; parade: type 16+i at x = 160 + 64i - s
            ld c,0
.p:         push bc
            ld a,c
            add a,a
            add a,a
            add a,a
            add a,a
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl               ; 64i
            ld de,160
            add hl,de
            ld de,(gal_s)
            or a
            sbc hl,de
            ld (spr_x),hl
            ld de,40
            add hl,de
            ld a,h
            or a
            jr nz,.pn               ; off to the left or far right
            ld a,l
            cp 210
            jr nc,.pn
            pop bc
            push bc
            call gal_name           ; HL -> name; empty: a serpent's body or
            ld a,(hl)               ; tail, or not shown
            or a
            jr nz,.dr
            ld a,(gal_chain)
            or a
            jr nz,.pn               ; (named body: nothing to chain)
            pop bc
            push bc
            ld a,c
            cp 7
            jr z,.body
            cp 8
            jr nz,.pn
            ld de,-34               ; the tail: right behind the last segment
            call .shift
            jr .dr
.body:      ld de,-42               ; the body: four segments behind the head
            call .shift
            ld b,3                  ; (and the fourth at .dr)
.bl:        push bc
            call .draw
            ld de,18
            call .shift
            pop bc
            djnz .bl
.dr:        pop bc
            push bc
            call .draw
.pn:        pop bc
            inc c
            ld a,c
            cp 9
            jr c,.p
            ; caption: the one passing the middle, i = (s - 64) / 64
            ld hl,(gal_s)
            ld de,-64
            add hl,de
            jr nc,.cap0
            add hl,hl
            add hl,hl
            ld a,h
            cp 9
            jr nc,.cap0
            ld hl,gal_c
            cp (hl)
            jr z,.cap0
            ld (hl),a
            ld c,a
            call gal_name
            ld a,(hl)
            or a
            jr z,.cap0
            ld de,wname_buf
            ld bc,17
            ldir
            ld a,M_NAME1
            call to_fe
            dw show_msg
.cap0:      ld a,200
            ld (msg_t),a
            ld a,8
            call msg_blit
            call map_game
            xor a
            ld (dirty_top),a
            call present
            ld a,(in_new)
            and $9F
            ret nz
            ld hl,(gal_s)
            inc hl
            inc hl
            ld (gal_s),hl
            ld de,64*9+200
            or a
            sbc hl,de
            jp c,.f
            ret

; draw world sprite C at (spr_x)
.draw:      push bc
            ld a,c                  ; ground things stand lower
            ld hl,58
            cp 3
            jr c,.gy
            cp 5
            jr z,.gy
            ld hl,46
.gy:        ld (spr_y),hl
            ld a,(anim)
            rrca
            rrca
            rrca
            and 3
            ld b,a
            ld e,c
            ld d,0
            ld hl,gal_lev
            add hl,de
            ld a,c
            add a,16
            ld c,(hl)
            call spr_rec
            call draw_sprite
            pop bc
            ret
; move (spr_x) by DE
.shift:     ld hl,(spr_x)
            add hl,de
            ld (spr_x),hl
            ret
gal_lev:    db 2,2,0,0,0,1,2,2,2     ; storyboard sizes (0 = biggest)
gal_chain:  db 0
; HL = name of world sprite C (0..8) (mapping 7)
gal_name:
            call map_game
            ld hl,(W_GAL)
            inc c
.n:         dec c
            ret z
.s:         ld a,(hl)
            inc hl
            or a
            jr nz,.s
            jr .n
