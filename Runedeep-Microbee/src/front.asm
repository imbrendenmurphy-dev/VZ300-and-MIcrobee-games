; =====================================================================
;  FRONT END: the title (logo, the tale, the controls, the deep's
;  denizens), cycling pages to the title music. SPACE / fire starts,
;  ESC returns to CP/M.
; =====================================================================
front_end:
        call snd_quiet
        call display_off
        ld a,MP_TITLE
        out (P_MEM),a
        ld a,($0003)            ; rows
        ld l,a
        ld a,($0005)            ; columns
        ld e,a
        call mul8               ; HL = cells
        ld (tt_n),hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,6
        add hl,de               ; the glyphs
        ld de,(0)               ; how many
        xor a
        call pcg_load
        call screen_clear
        xor a
        call show_page
        call tt_logo
        ; the subtitle and the foot
        ld b,7
        ld c,6
        ld hl,t_subtitle
        ld a,BCYAN
        call print_at
        ld b,24
        ld c,11
        ld hl,t_credit
        ld a,GREY
        call print_at
        ld b,22
        ld c,8
        ld hl,t_press
        ld a,WHITE
        call print_at
        call display_on
        ld hl,mus_title
        call play_tune
        xor a
        ld (tt_page),a
        ld (cmd),a
        ld (pressed),a
.page:  call tt_show
        ld b,0                  ; ~6 s a page
.w:     push bc
        call frame
        call tt_blink
        pop bc
        ld a,(cmd)
        cp 27
        jp z,quit
        cp 'T'
        jr nz,.nt
        xor a
        ld (cmd),a
        ld a,(snd_mode)
        dec a
        jp p,.sm
        ld a,2
.sm:    ld (snd_mode),a
        cp 2
        jr nz,.nt
        ld hl,mus_title
        call play_tune
.nt:    ld a,(pressed)
        and 64
        jr nz,.go
        ld a,(cmd)
        cp '1'
        jr c,.k
        cp '4'
        jr nc,.k
        sub '1'
        ld (tt_page),a
        xor a
        ld (cmd),a
        jr .page
.k:     djnz .w
        ld a,(tt_page)
        inc a
        cp 3
        jr c,.p
        xor a
.p:     ld (tt_page),a
        jr .page
.go:    xor a
        ld (pressed),a
        ld (cmd),a
        call snd_quiet
        ld hl,sfx_stairs
        call sfx
        ret

; HL = L * E
mul8:   ld a,l
        ld hl,0
        ld d,0
        ld b,8
.l:     add hl,hl
        sla a
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; place the logo cells (both pages)
tt_logo:
        ld a,MP_TITLE
        out (P_MEM),a
        ld a,($0002)
        ld (tt_r),a
        ld ix,6                 ; codes
        ld a,($0003)
        ld b,a
.r:     push bc
        ld a,($0004)
        ld c,a                  ; first column
        ld a,($0005)
        ld b,a
.c:     push bc
        ld a,(tt_r)
        ld l,a
        ld h,0
        call rowcol             ; HL = cell
        push hl
        push ix
        pop hl
        ld b,(hl)               ; code
        ld de,(tt_n)
        add hl,de
        ld c,(hl)               ; attribute
        add hl,de
        ld a,(hl)               ; colour
        pop hl
        call put2
        inc ix
        pop bc
        inc c
        djnz .c
        ld hl,tt_r
        inc (hl)
        pop bc
        djnz .r
        ret

tt_r:       db 0
tt_n:       dw 0
tt_page:    db 0

; the page text: rows 10-20, cleared first
tt_show:
        ld b,10
.cl:    push bc
        ld c,0
        ld hl,t_blank38
        ld a,WHITE
        call print_at
        pop bc
        inc b
        ld a,b
        cp 21
        jr nz,.cl
        ld a,(tt_page)
        add a,a
        ld hl,tt_pages
        call add_a_hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ; lines: row, column, colour, text 0 ... row FF ends
.l:     ld a,(hl)
        cp $FF
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call print_at
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        jr .l

; the "press" line breathes
tt_blink:
        ld a,(tick)
        and 31
        ret nz
        ld a,(tick)
        and 32
        ld a,WHITE
        jr z,.c
        ld a,GREY
.c:     ld b,22
        ld c,8
        ld hl,t_press
        jp print_at

tt_pages:   dw tt_tale, tt_keys, tt_foes
