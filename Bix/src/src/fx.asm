; =====================================================================
;  fx.asm - particles, sparkles, score, HUD, sound engine
; =====================================================================

; ---------------------------------------------------------------- random
random:                         ; A = pseudo random (xorshift-ish)
        push hl
        ld hl,(rnd)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rnd),hl
        pop hl
        ret

; ---------------------------------------------------------------- particles
; entry: +0 life +1/2 x +3 y +4 vx +5 vy +6 colour +7 gravity
; spawn_part: HL = x, A = y, B = vx, C = vy, D = colour, E = life,
;             (pgrav) = gravity flag
pgrav   db 0
spawn_part:
        push hl
        push af
        ld hl,PARTS
        ld a,NPART
.l:     push af
        ld a,(hl)
        or a
        jr z,.f
        pop af
        push de
        ld de,8
        add hl,de
        pop de
        dec a
        jr nz,.l
        pop af
        pop hl
        ret
.f:     pop af
        ld (hl),e
        inc hl
        pop af
        ex (sp),hl              ; hl = x , stack = ptr
        ex de,hl                ; de = x, hl = colour/life
        ex (sp),hl              ; hl = ptr, stack = colour/life
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),a
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        pop de
        ld (hl),d
        inc hl
        ld a,(pgrav)
        ld (hl),a
        ret

parts_update:
        ld ix,PARTS
        ld b,NPART
.l:     ld a,(ix+0)
        or a
        jr z,.n
        dec (ix+0)
        ld a,(ix+4)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+1)
        ld h,(ix+2)
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld a,(ix+3)
        add a,(ix+5)
        ld (ix+3),a
        ld a,(ix+7)
        or a
        jr z,.n
        ld a,(frame)
        and 1
        jr z,.n
        inc (ix+5)
.n:     ld de,8
        add ix,de
        djnz .l
        ret

parts_draw:
        ld ix,PARTS
        ld b,NPART
.l:     ld a,(ix+0)
        or a
        jr z,.n
        push bc
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,(camx)
        or a
        sbc hl,de
        ld a,(camy)
        ld b,a
        ld a,(ix+3)
        sub b
        ld c,(ix+6)
        call plot
        pop bc
.n:     ld de,8
        add ix,de
        djnz .l
        ret

dust_puff:
        xor a
        ld (pgrav),a
        call getpos
        ld hl,(ppx)
        ld a,(ppy)
        add a,9
        ld bc,$FF00
        ld de,$0104
        call spawn_part
        ld hl,(ppx)
        ld de,7
        add hl,de
        ld a,(ppy)
        add a,9
        ld bc,$0100
        ld de,$0104
        jp spawn_part

dirt_spray:
        ld a,1
        ld (pgrav),a
        ld b,6
.l:     push bc
        call random
        and 3
        sub 2
        jr nz,.v
        inc a
.v:     ld b,a
        call random
        and 3
        add a,2
        neg
        ld c,a
        call random
        and 1
        ld a,3
        jr z,.c
        ld a,1
.c:     ld d,a
        ld e,10
        ld hl,(ppx)
        inc hl
        inc hl
        inc hl
        ld a,(ppy)
        add a,7
        call spawn_part
        pop bc
        djnz .l
        ret

dirt_bit:
        ld a,1
        ld (pgrav),a
        call random
        and 3
        sub 1
        ld b,a
        ld c,-2
        ld de,$0306
        ld hl,(ppx)
        inc hl
        inc hl
        inc hl
        ld a,(ppy)
        add a,4
        jp spawn_part

block_debris:
        ld a,1
        ld (pgrav),a
        ld hl,(ppx)
        inc hl
        ld a,(ppy)
        ld bc,$FFFD
        ld de,$010C
        call spawn_part
        ld hl,(ppx)
        ld de,6
        add hl,de
        ld a,(ppy)
        ld bc,$01FD
        ld de,$030C
        call spawn_part
        ld hl,(ppx)
        ld de,3
        add hl,de
        ld a,(ppy)
        ld bc,$00FC
        ld de,$010A
        jp spawn_part

; sparkle_burst: HL = x, A = y (world) : 4-way twinkle
sparkle_burst:
        ld (tmp2),hl
        ld (tmp3),a
        xor a
        ld (pgrav),a
        ld bc,$FE00
        call .one
        ld bc,$0200
        call .one
        ld bc,$00FE
        call .one
        ld bc,$0002
.one:   ld hl,(tmp2)
        inc hl
        inc hl
        inc hl
        ld a,(tmp3)
        add a,3
        ld de,$0106
        jp spawn_part

; sparkle_one: HL = x, A = y (world): a single twinkle nearby
sparkle_one:
        ld (tmp2),hl
        ld (tmp3),a
        xor a
        ld (pgrav),a
        call random
        and 7
        ld e,a
        ld d,0
        ld hl,(tmp2)
        add hl,de
        call random
        and 7
        ld b,a
        ld a,(tmp3)
        add a,b
        ld bc,0
        ld de,$0103
        jp spawn_part

; ---------------------------------------------------------------- star twinkle
build_starlist:
        ld hl,MAP
        ld de,STARL
        xor a
        ld (nstarl),a
        ld (tmp1),a             ; tx lo
        ld (tmp1+1),a
        ld bc,0                 ; c = ty
.l:     push hl
        push de
        ld e,(hl)
        ld d,high tattr
        ld a,(de)
        pop de
        and A_STAR
        jr z,.n
        ld a,(nstarl)
        cp STARMAX
        jr nc,.n
        inc a
        ld (nstarl),a
        ld a,(tmp1)
        ld (de),a
        inc de
        ld a,(tmp1+1)
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
.n:     pop hl
        inc hl
        inc c
        ld a,c
        cp 12
        jr nz,.c
        ld c,0
        push hl
        ld hl,(tmp1)
        inc hl
        ld (tmp1),hl
        ld de,(levw)
        ld a,l
        cp e
        jr nz,.c1
        ld a,h
        cp d
        jr nz,.c1
        pop hl
        ret
.c1:    pop hl
.c:     jr .l

star_twinkle:
        ld a,(colgen)           ; skip on frames that rendered a ring column
        or a
        ret nz
        ld a,(nstarl)
        or a
        ret z
        ld b,8
.l:     push bc
        ld a,(starscan)
        inc a
        ld hl,nstarl
        cp (hl)
        jr c,.i
        xor a
.i:     ld (starscan),a
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,STARL
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)               ; ty
        ; visible?  tx*8 - camx in 0..120
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (tmp1),hl
        ld de,(camx)
        or a
        sbc hl,de
        jr c,.n
        ld a,h
        or a
        jr nz,.n
        ld a,l
        cp 121
        jr nc,.n
        ; still a star?
        ld hl,(tmp1)
        ld a,c
        add a,a
        add a,a
        add a,a
        ld (tmp3),a
        call tile_at
        and A_STAR
        jr z,.n
        pop bc
        ld hl,(tmp1)
        ld a,(tmp3)
        jp sparkle_one
.n:     pop bc
        djnz .l
        ret

; ---------------------------------------------------------------- shake
shake_y db 0
shake_on:
        ld a,(camy)
        ld (shake_y),a
        ld a,(shake)
        or a
        ret z
        dec a
        ld (shake),a
        and 1
        ld a,(camy)
        jr z,.d
        or a
        ret z
        dec a
        ld (camy),a
        ret
.d:     cp RROWS-PFROWS
        ret nc
        inc a
        ld (camy),a
        ret
shake_off:
        ld a,(shake_y)
        ld (camy),a
        ret

; ---------------------------------------------------------------- score
; add_score_a: score/10 += A (BCD)
add_score_a:
        ld hl,score+2
        add a,(hl)
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,1
        ld (hudflag),a
        ret

; ---------------------------------------------------------------- HUD
; VRAM rows 0..6 red bar with yellow 3x5 text, row 7 divider
hud_draw_all:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,32*7-1
        ld (hl),$FF
        ldir
        ld hl,VRAM+32*7
        ld de,VRAM+32*7+1
        ld bc,31
        ld (hl),$00
        ldir
        ld hl,hud_text
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.d
        push hl
        push bc
        call hud_char
        pop bc
        pop hl
        inc hl
        inc c
        jr .l
.d:     ; level label "W-A" at column 14
        ld a,(levnum)
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,lvlabels
        add hl,de
        ld c,14
        ld b,3
.lb:    ld a,(hl)
        push hl
        push bc
        call hud_char
        pop bc
        pop hl
        inc hl
        inc c
        djnz .lb
        ld a,1
        ld (hudflag),a
        jp hud_update
lvlabels: db "1-1","1-2","1-3","2-1","2-2","2-3","3-1","3-2","3-3","4-1","4-2","4-3","5-1","5-2","5-3"
hud_text:
        db "#      * 00   1-1      0000000",0

; hud_char: A = char, C = column
hud_char:
        ld hl,VRAM+32
hud_char_at:                    ; A = char, C = column, HL = row base address
        push hl
        sub 32
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,font_hud
        add hl,de
        ex de,hl
        ld l,c
        ld h,0
        pop bc
        add hl,bc
        ld b,5
.l:     ld a,(de)
        ld (hl),a
        inc de
        push de
        ld de,32
        add hl,de
        pop de
        djnz .l
        ret

hud_digit:                      ; A = 0..9, C = column
        add a,'0'
        jp hud_char

hud_update:
        ld a,(hudflag)
        or a
        ret z
        xor a
        ld (hudflag),a
        ; lives
        ld a,(lives)
        cp 10
        jr c,.l1
        ld a,9
.l1:    ld c,1
        call hud_digit
        ; health gumnuts
        ld b,0
.h:     push bc
        ld a,(health)
        cp b
        ld a,' '
        jr z,.h0
        jr c,.h0
        ld a,'@'
.h0:    ld c,b
        inc c
        inc c
        inc c
        call hud_char
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.h
        ; stars (decimal 2 digits)
        ld a,(nstars)
        ld b,0
.s:     cp 10
        jr c,.s1
        sub 10
        inc b
        jr .s
.s1:    push af
        ld a,b
        ld c,9
        call hud_digit
        pop af
        ld c,10
        call hud_digit
        ; story clock (columns 18-20), not on boss levels
        ld a,(mode)
        ld b,a
        ld a,(demo)
        or b
        ld b,a
        ld a,(bossmode)
        or b
        jr nz,.nclk
        ld hl,(tsec)
        ld c,18
        call hud_num3
.nclk:  ; boss energy replaces the level label
        ld a,(bossmode)
        or a
        jr z,.nb
        ld b,0
.bh:    push bc
        ld a,(bosshp)
        cp b
        ld a,' '
        jr z,.b1
        jr c,.b1
        ld a,'@'
.b1:    push af
        ld a,b
        add a,13
        ld c,a
        pop af
        call hud_char
        pop bc
        inc b
        ld a,b
        cp DRAGON_HP
        jr nz,.bh
.nb:    ld a,(mode)
        or a
        jr z,.sco
        ld hl,(timer)           ; time attack: show the clock instead
        call fmt_time
        ld hl,txtbuf
        ld c,23
.tc:    ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call hud_char
        pop bc
        pop hl
        inc hl
        inc c
        jr .tc
.sco:   ; score 6 BCD digits + trailing 0
        ld hl,score
        ld c,23
        ld b,3
.sc:    push bc
        push hl
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        call hud_digit
        pop hl
        pop bc
        push bc
        push hl
        ld a,(hl)
        and 15
        inc c
        call hud_digit
        pop hl
        pop bc
        inc c
        inc c
        inc hl
        djnz .sc
        ret

; ---------------------------------------------------------------- sound
; The speaker is driven from inside the two big copy loops (draw_bg and the
; ISR copy): each row adds a 16-bit increment to a phase accumulator and
; outputs its top bit.  snd_set patches that increment into both loops.
snd_set:                        ; HL = increment (0 = silence)
        ld a,l
        ld (draw_bg.tk1l+1),a
        ld (isr.tk2l+1),a
        ld a,h
        ld (draw_bg.tk1h+1),a
        ld (isr.tk2h+1),a
        ld (curtone),hl
        ret

sfx_play:                       ; A = sfx id
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,de               ; *6
        ld de,sfx_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sfx_n),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sfx_d),de
        ld a,(hl)
        ld (sfx_t),a
        inc hl
        ld a,(hl)
        ld (sfx_noise),a
        ret

music_tick:
        ld a,(sfx_t)
        or a
        jr z,.mus
        dec a
        ld (sfx_t),a
        ld hl,(sfx_n)
        ld de,(sfx_d)
        add hl,de
        ld (sfx_n),hl
        ld a,(sfx_noise)
        or a
        jp z,snd_set
        call random
        and $1F
        or $08
        ld h,a
        call random
        ld l,a
        jp snd_set
.mus:   ld hl,(mus_ptr)
        ld a,(musoff)
        or a
        jr z,.mon
        ld h,a                  ; music switched off: keep silent
        dec h
        ld l,h
.mon:   ld a,h
        or l
        jr nz,.m1
        ld hl,0
        jp snd_set
.m1:    ld a,(mus_t)
        or a
        jr nz,.m3
        ; next note
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,e
        and d
        cp $FF
        jr nz,.m2
        ld hl,(mus_base)
        ld (mus_ptr),hl
        jr .m1
.m2:    ld a,(hl)
        inc hl
        ld (mus_ptr),hl
        ld (mus_t),a
        ld (mus_len),a
        ld (mus_n),de
.m3:    ld a,(mus_t)
        dec a
        ld (mus_t),a
        ld hl,0
        jp z,snd_set            ; last frame of each note is a gap (articulation)
        ld b,a                  ; blip: only the first BLIPF frames of a note sound
        ld a,(mus_len)
        sub b
        cp BLIPF+1
        jp nc,snd_set
        ld hl,(mus_n)
        jp snd_set
mus_n   dw 0
mus_len db 0
BLIPF   equ 3

music_start_level:
        ld hl,songbuf
        ld (mus_base),hl
        ld (mus_ptr),hl
        xor a
        ld (mus_t),a
        ld (sfx_t),a
        ret
music_stop:
        ld hl,0
        ld (mus_ptr),hl
        ret

; sfx: start increment, delta per frame, frames, noise
SFX_JUMP    equ 0
SFX_SPRING  equ 1
SFX_BONUS   equ 2
SFX_BREAK   equ 3
SFX_STAR    equ 4
SFX_ONEUP   equ 5
SFX_HURT    equ 6
SFX_DIE     equ 7
SFX_WIN     equ 8
SFX_DIG     equ 9
SFX_DIGSTEP equ 10
SFX_BURST   equ 11
SFX_CHECK   equ 12
SFX_SWOOP   equ 13
SFX_HOP     equ 14
SFX_STOMP   equ 15
SFX_POWER   equ 16
sfx_tab:
        dw 4200, 900    : db 6, 0       ; jump: rising chirp
        dw 2500, 1400   : db 10, 0      ; spring: long boing up
        dw 9000, -500   : db 8, 0       ; bonus
        dw 0, 0         : db 5, 1       ; break: noise
        dw 14000, 3000  : db 3, 0       ; star: bright blip
        dw 7000, 900    : db 16, 0      ; 1up
        dw 6000, -600   : db 8, 0       ; hurt
        dw 9000, -400   : db 22, 0      ; die: long fall
        dw 7000, 700    : db 20, 0      ; win
        dw 0, 0         : db 6, 1       ; dig in: noise
        dw 0, 0         : db 1, 1       ; dig step: tick of noise
        dw 3000, 1800   : db 9, 0       ; burst: whoosh up
        dw 10000, 1000  : db 10, 0      ; checkpoint
        dw 11000, -700  : db 8, 0       ; swoop
        dw 3000, 400    : db 3, 0       ; hop
        dw 8000, -1400  : db 5, 0       ; stomp
        dw 5000, 1200   : db 14, 0      ; power up

; fmt_time: HL = game frames (25/s) -> txtbuf "m:ss.t " (zero terminated)
fmt_time:
        ld a,h
        cp $60
        jr c,.ok
        ld hl,$5FFF
.ok:    add hl,hl
        ld c,5
        call div16_8            ; tenths
        ld c,10
        call div16_8
        push af                 ; tenths digit
        ld c,60
        call div16_8            ; HL = minutes, A = seconds
        push af
        ld a,l
        cp 10
        jr c,.m
        ld a,9
.m:     add a,'0'
        ld (txtbuf),a
        ld a,':'
        ld (txtbuf+1),a
        pop af
        ld b,'0'-1
.s:     inc b
        sub 10
        jr nc,.s
        add a,10+'0'
        ld (txtbuf+3),a
        ld a,b
        ld (txtbuf+2),a
        ld a,'.'
        ld (txtbuf+4),a
        pop af
        add a,'0'
        ld (txtbuf+5),a
        ld a,' '
        ld (txtbuf+6),a
        xor a
        ld (txtbuf+7),a
        ret
txtbuf  ds 9

; hud_num3: HL = 0..999 drawn as three digits at column C
hud_num3:
        push bc
        ld c,10
        call div16_8
        ld (hn_d+2),a
        ld c,10
        call div16_8
        ld (hn_d+1),a
        ld a,l
        ld (hn_d),a
        pop bc
        ld hl,hn_d
        ld b,3
.l:     push bc
        push hl
        ld a,(hl)
        call hud_digit
        pop hl
        pop bc
        inc hl
        inc c
        djnz .l
        ret
hn_d    ds 3
