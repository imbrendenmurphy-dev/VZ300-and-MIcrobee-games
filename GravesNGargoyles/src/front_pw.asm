; password entry screen: lives in the front-end pack (only used from the menu)
; ---------------------------------------------------------------- password
; four letters: up/down choose, left/right move, fire on the last checks it.
; Letters can also be typed.  Returns NC when valid (pw_ok set), C if
; abandoned or wrong.
password_screen:
        xor a
        ld (pw_cur),a
        ld hl,pw_idx
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld (t_t),a
.lp:    ld hl,t_t
        inc (hl)
        call menu_bg
        ld hl,STR_PWTITLE
        ld c,14
        ld a,(col_yel)
        call text_fbc
        ; the four letters, spaced out
        ld hl,pw_idx
        ld de,text_buf
        ld b,4
.mk:    push hl
        ld a,(hl)
        ld l,a
        ld h,0
        push de
        ld de,PW_ALPHA
        add hl,de
        pop de
        ld a,(hl)
        ld (de),a
        inc de
        ld a,' '
        ld (de),a
        inc de
        pop hl
        inc hl
        djnz .mk
        dec de
        xor a
        ld (de),a
        ld hl,text_buf
        ld c,28
        ld a,(col_red)
        call text_fbc
        ; cursor (blinks)
        ld a,(t_t)
        and 8
        jr z,.nc
        ld a,(pw_cur)
        add a,a
        add a,a
        add a,a                 ; 8 px per letter pair
        add a,49
        ld b,a
        ld c,35
        ld hl,STR_CURSOR
        ld a,(col_yel)
        call text_fb
.nc:    ld hl,STR_PWHELP
        ld c,46
        ld a,(col_grn)
        call text_fbc
        call show_full
        call read_input
        ld a,(pw_cur)
        ld e,a
        ld d,0
        ld hl,pw_idx
        add hl,de
        ; a typed letter takes priority (P Q A W are also control keys)
        push hl
        call read_letter        ; A = new ascii key or 0
        pop hl
        or a
        jr z,.nokey
        ld c,a
        ld de,PW_ALPHA
        ld b,0
.f:     ld a,(de)
        cp c
        jr z,.typed
        inc de
        inc b
        ld a,b
        cp 32
        jr c,.f
        jp .lp
.nokey: ld a,(keys_new)
        bit K_UP,a
        jr nz,.up
        bit K_DOWN,a
        jr nz,.dn
        bit K_LEFT,a
        jr nz,.lf
        bit K_RIGHT,a
        jr nz,.rt
        and (1<<K_FIRE)|(1<<K_SWAP)
        jr nz,.fire
        jp .lp
.typed: ld (hl),b
        call .tick
        jr .rt
.up:    ld a,(hl)
        inc a
        and 31
        ld (hl),a
        call .tick
        jp .lp
.dn:    ld a,(hl)
        dec a
        and 31
        ld (hl),a
        call .tick
        jp .lp
.lf:    ld a,(pw_cur)
        or a
        jp z,.lp
        dec a
        ld (pw_cur),a
        jp .lp
.rt:    ld a,(pw_cur)
        cp 3
        jp nc,.lp
        inc a
        ld (pw_cur),a
        jp .lp
.fire:  ld a,(pw_cur)
        cp 3
        jr c,.rt
        call pw_decode
        jr c,.bad
        ld a,1
        ld (pw_ok),a
        ld a,SFX_SELECT_ID
        call play_sfx
        xor a                   ; A = 0 (start the game), NC
        ret
.bad:   call menu_bg
        ld hl,STR_PWBAD
        ld c,30
        ld a,(col_red)
        call text_fbc
        ld hl,60
        call card_wait
        scf
        ret
.tick:  ld a,SFX_SELECT_ID
        jp play_sfx

; read_letter -> A = ascii of a newly pressed letter/digit key, else 0
read_letter:
        ld hl,KEYCHARS
        ld de,$68FE
        ld c,0                  ; found
.row:   ld a,(de)
        cpl
        ld b,6
.bit:   rrca
        jr nc,.nx
        push af
        ld a,(hl)
        or a
        jr z,.nf
        ld c,a
.nf:    pop af
.nx:    inc hl
        djnz .bit
        rlc e
        ld a,e
        cp $FE
        jr nz,.row
        ld a,(rl_last)
        cp c
        ld a,c
        ld (rl_last),a
        jr nz,.new
        xor a
        ret
.new:   ld a,c
        ret
KEYCHARS:                       ; per row, bits 0..5 (bit 0 = last key listed)
        db "T","W",0,"E","Q","R"
        db "G","S",0,"D","A","F"
        db "B","X",0,"C","Z","V"
        db "5","2",0,"3","1","4"
        db "N",0,0,0,0,"M"
        db "6","9",0,"8","0","7"
        db "Y",0,0,"I","P","U"
        db "H","L",0,"K",0,"J"

STR_PWTITLE: db "ENTER PASSWORD",0
STR_PWHELP:  db "TYPE IT, OR USE THE STICK",0
STR_PWBAD:   db "THAT IS NOT A PASSWORD",0

