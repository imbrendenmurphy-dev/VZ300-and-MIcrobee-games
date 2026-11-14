; =====================================================================
;  THE TITLE ON THE MUSIC: SWIRL has all of the CPU, so the title's
;  picture is static and its life comes from the music's ticks: once a
;  tick the hook paints one column of the logo (diagonal bands of colour
;  that roll across it), one letter of the prompt, twinkles a star and
;  looks at one key. Each costs only a few video writes.
; =====================================================================
NTSTAR      EQU 28
LOGO_C0     EQU (40-LOGO_W)/2
PROMPT_C0   EQU 6
PROMPT_LEN  EQU 28
TITLE_TICKS EQU 14*59

; the bands' colours (monochrome: the logo stays still)
psy_pal:    db BRED,YELLOW,BGREEN,BCYAN,BBLUE,BMAGENTA,WHITE,MAGENTA
star_pal:   db DGREY,GREY,WHITE,BCYAN,BLUE,BBLUE,DGREY,BMAGENTA
; rows the stars may use (the rest hold the logo and the text)
star_rows:  db 1,7,9,10,11,12,13,14,15,17,18,20,22,24,10,13

; HL = cell, A = colour: the colour of a cell on both pages
col_both:
        push hl
        push de
        ld e,a
        ld a,COL_ON
        out (P_COLCTL),a
        push hl
        ld a,h
        add a,VIDEO>>8|8
        ld h,a
        ld (hl),e
        pop hl
        ld a,h
        add a,(VIDEO+PAGE1)>>8|8
        ld h,a
        ld (hl),e
        xor a
        out (P_COLCTL),a
        pop de
        pop hl
        ret

; scatter the title's stars (static cells, a dot glyph each)
tstars_init:
        ld ix,tstars
        ld b,NTSTAR
.l:     push bc
        call random
        and 15
        ld e,a
        ld d,0
        ld hl,star_rows
        add hl,de
        ld a,(hl)               ; row
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        add hl,hl
        add hl,hl
        pop de
        add hl,de               ; row * 40
.c:     call random
        and 63
        cp 40
        jr nc,.c
        ld e,a
        ld d,0
        add hl,de
        push hl                 ; a cell already holding text: try again
        ld de,CELLHI
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr z,.free
        pop bc
        jr .l
.free:  ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        call random
        and 15
        add a,$81               ; one of the sixteen dot glyphs
        ld b,BK_POOL0
        ld c,GREY
        call put_s
        pop bc
        djnz .l
        ret

; the title's hook: Z to carry on; NZ and A = 1 start, 2 time up,
; 3 colour monitor, 4 monochrome
title_hook:
        ld hl,(scr_tim)
        dec hl
        ld (scr_tim),hl
        ld a,h
        or l
        ld a,2
        jp z,.ret
        ld a,(tm_tick)
        inc a
        ld (tm_tick),a
        ; the picture changes only while the beam is in the blanking: video
        ; writes then cost nothing (in the picture the 6545 holds the CPU,
        ; and the music would stop for it)
        in a,(P_CRTCA)
        and $20
        jr z,.keys
        call tm_logo
        call tm_prompt
        call tm_twinkle
.keys:  ld a,1
        out (P_ROMLAT),a
        ; SPACE every tick (a quick tap must never be missed) ...
        ld a,K_SPACE
        call keytest
        ld c,0
        jr z,.k0
        ld c,$FF
.k0:    ld d,1
        call tm_edge
        jr nz,.start
        ; ... and C, M, S in turn
        ld a,(tm_tick)
.mod:   sub 3
        jr nc,.mod
        add a,3+1               ; 1..3
        ld e,a
        ld d,0
        ld hl,tm_keycodes
        add hl,de
        ld a,(hl)
        call keytest
        ld c,0
        jr z,.k1
        ld c,$FF
.k1:    ld hl,tm_bits
        add hl,de
        ld d,(hl)
        call tm_edge
        jr z,.stick
        ld a,d
        cp 8
        jr z,.snd
        ld a,(tm_where)         ; C / M: on the title only
        or a
        jr nz,.stick
        ld a,d
        cp 2
        ld a,3                  ; C: a colour monitor
        jr z,.ret
        ld a,4                  ; M: monochrome
        jr .ret
.snd:   ld a,(sndmode)          ; S: the sound mode, round
        dec a
        jp p,.sm
        ld a,2
.sm:    ld (sndmode),a
        call mus_mute
.stick: xor a
        out (P_ROMLAT),a
        ; the stick's fire, edge-triggered like a key
        in a,(P_PIOA)
        cpl
        and $80
        ld b,a
        ld a,(tm_fire)
        ld c,a
        ld a,b
        ld (tm_fire),a
        or a
        jr z,.ok
        ld a,c
        or a
        jr nz,.ok
.start: xor a
        out (P_ROMLAT),a
        ld a,1
.ret:   or a
        ret
.ok:    xor a
        ret

; D = a key's bit in tm_held, C = FFh if it is down now: NZ if it has
; just gone down (tm_held updated)
tm_edge:
        ld a,(tm_held)
        ld h,a
        and d
        ld l,a                  ; was down
        ld a,d
        cpl
        and h                   ; the others
        ld h,a
        ld a,c
        and d                   ; down now
        ld e,a
        or h
        ld (tm_held),a
        ld a,l
        or a
        jr z,.new
        xor a                   ; down already: Z
        ret
.new:   ld a,e
        or a
        ret                     ; NZ = just pressed
tm_keycodes: db K_SPACE,K_C,K_M,K_S
tm_bits:     db 1,2,4,8

; one column of the logo
tm_logo:
        ld a,(tm_where)         ; the title only
        ld b,a
        ld a,(mono)
        or b
        ret nz
        ld a,(tm_col)
        inc a
        cp LOGO_W
        jr c,.c
        ld a,(tm_phase)
        dec a
        ld (tm_phase),a
        xor a
.c:     ld (tm_col),a
        ld e,a
        ld d,0
        ld hl,2*40+LOGO_C0
        add hl,de
        ld b,LOGO_H
.r:     push bc
        ld a,(tm_phase)
        add a,e
        add a,b
        and 7
        push hl
        ld hl,psy_pal
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        pop hl
        call col_both
        ld bc,40
        add hl,bc
        pop bc
        djnz .r
        ret

; one letter of the prompt: a slower band of colour
tm_prompt:
        ld a,(tm_pcol)
        inc a
        cp PROMPT_LEN
        jr c,.c
        xor a
.c:     ld (tm_pcol),a
        ld e,a
        ld d,0
        ld hl,(tm_prow)
        add hl,de
        ld a,(tm_phase)
        rra
        add a,e
        rra
        and 7
        ld de,psy_pal
        add a,e
        ld e,a
        jr nc,.n
        inc d
.n:     ld a,(mono)
        or a
        ld a,(de)
        jp z,col_both
        ld a,(tm_tick)          ; monochrome: it blinks instead
        and $20
        ld a,WHITE
        jp z,col_both
        ld a,DGREY
        jp col_both

; a star changes its colour
tm_twinkle:
        call random
        and 31
        cp NTSTAR
        ret nc
        add a,a
        ld e,a
        ld d,0
        ld hl,tstars
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call random
        and 7
        ld hl,star_pal
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ld hl,colmap            ; through the monitor's map
        add a,l
        ld l,a
        jr nc,.m
        inc h
.m:     ld a,(hl)
        ex de,hl
        jp col_both

; set the hook up for a screen: A = 0 the title, 1 the hall of fame;
; HL = the prompt's first cell
tm_setup:
        ld (tm_where),a
        ld (tm_prow),hl
        ld a,$0F                ; keys and fire must be let go first
        ld (tm_held),a
        ld a,$80
        ld (tm_fire),a
        ret
