; =====================================================================
;  screens.asm - title, level intro, clear, game over; 2-channel player
; =====================================================================

        jp title_screen
        jp level_intro
        jp level_complete
        jp game_over_screen
        jp ending
        jp ovl_load_level
        jp ovl_load_player
        jp hiscore
        jp ta_menu
        jp ta_result

; ---------------------------------------------------------------- VRAM helpers
vfill:  ; A = fill byte
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ret

; vtext: HL = zero-terminated text, C = byte column, B = pixel row
vtext:
.l:     ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call vchar
        pop bc
        pop hl
        inc hl
        inc c
        jr .l
vchar:  ; A = char, C = column, B = row  (yellow on blue)
        sub 32
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,font_sky
        add hl,de
        push hl
        call vaddr
        pop de
        ld b,5
.r:     ld a,(de)
        ld (hl),a
        inc de
        push de
        ld de,32
        add hl,de
        pop de
        djnz .r
        ret
vaddr:  ; HL = VRAM + B*32 + C
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,0
        add hl,bc
        ld bc,VRAM
        add hl,bc
        ret

; vplot: D = x (0..127), E = y (0..63), A = colour
vplot:
        push hl
        push bc
        push de
        ld c,a
        ld a,e
        cp 64
        jr nc,.x
        ld a,d
        cp 128
        jr nc,.x
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,d
        srl a
        srl a
        add a,l
        ld l,a
        ld a,h
        adc a,high VRAM
        ld h,a
        ld a,d
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,pixmask
        add hl,de
        ld b,(hl)
        ld e,c
        ld hl,colfill
        add hl,de
        ld a,(hl)
        and b
        ld c,a
        ld a,b
        cpl
        pop hl
        and (hl)
        or c
        ld (hl),a
.x:     pop de
        pop bc
        pop hl
        ret

; vblock: D=x E=y A=colour, size in (vb_s)
vb_s    db 3
vblock:
        push de
        ld c,a
        ld a,(vb_s)
        ld b,a
.y:     push bc
        push de
        ld a,(vb_s)
        ld b,a
.x:     ld a,c
        call vplot
        inc d
        djnz .x
        pop de
        pop bc
        inc e
        djnz .y
        pop de
        ret

; draw_big: HL = packed 2bpp sprite (bytes per row = W/4), B = rows,
; C = bytes per row, D = x, E = y ; scale (vb_s); colour 0 transparent
draw_big:
.row:   push bc
        push de
.byte:  ld a,(hl)
        inc hl
        push hl
        ld b,4
.px:    rlca
        rlca
        push af
        and 3
        jr z,.t
        push bc
        call vblock
        pop bc
.t:     ld a,(vb_s)
        add a,d
        ld d,a
        pop af
        djnz .px
        pop hl
        dec c
        jr nz,.byte
        pop de
        ld a,(vb_s)
        add a,e
        ld e,a
        pop bc
        djnz .row
        ret

; draw a level tile straight to VRAM: A = tile, C = tile x (0..15), B = tile y (0..7)
vtile:
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,tiles
        add hl,de
        ex de,hl
        ld a,b
        add a,a
        add a,a
        add a,a
        ld b,a
        sla c
        call vaddr
        ld b,8
.l:     ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        push de
        ld de,31
        add hl,de
        pop de
        djnz .l
        pop bc
        ret

; big logo letter: A = char, D = x, E = y. Font scaled x4, red shadow.
logo_char:
        push af
        push de
        inc d
        inc d
        inc e
        inc e
        ld c,3
        call .draw
        pop de
        pop af
        ld c,1
.draw:  push af
        push de
        sub 32
        ld l,a
        ld h,0
        ld b,l
        ld a,l
        add hl,hl
        add hl,hl
        ld e,b
        ld d,0
        add hl,de
        ld de,font_hud
        add hl,de               ; rows: fg pixels = colour 1
        pop de
        ld a,4
        ld (vb_s),a
        ld b,5
.r:     push bc
        push de
        ld a,(hl)
        inc hl
        ld b,4
.p:     rlca
        rlca
        push af
        and 3
        cp 1
        jr nz,.n
        ld a,c
        push bc
        call vblock
        pop bc
.n:     ld a,d
        add a,4
        ld d,a
        pop af
        djnz .p
        pop de
        ld a,e
        add a,4
        ld e,a
        pop bc
        djnz .r
        pop af
        ret

; ---------------------------------------------------------------- 3-voice player
; Title, jingles and ending.  Three square-wave voices are written to the
; speaker in turn every 199 T (17.8 kHz), plus noise/sweep drums.  Each note
; can retrigger a pulse-width envelope on voices 1 and 2: the pulse starts
; wide and narrows every 256 loops, so notes sound loud then fade - "blippy"
; without silent gaps.  (Idea from the Cybernoid title player.)
; event: dw inc1 (lead), inc2 (bass double), inc3 (bass), loops : db flags
;   flags bits 0-1 drum (1 kick, 2 snare, 3 hat), bit 2 retrigger lead,
;   bit 3 retrigger echo, bit 4 retrigger bass.  loops = 0 ends.  Returns NZ if a key was pressed
;   (when (tp_brk) is set).
DUTY1   equ $80
DUTY2   equ $80
DUTY3   equ $80
DMIN    equ $34
t_ph1   dw 0
t_ph2   dw 0
t_ph3   dw 0
tp_np   dw $0100
tp_brk  db 0
tp_hook dw tp_nohook
tp_nohook: ret
play_tune:                      ; HL = events
        push iy
        call pt_main
        pop iy
        ret
pt_main:
        ld a,(latchv)
        or $20
        ld (.x1+1),a
        ld (.x2+1),a
        ld (.x3+1),a
        ld (pt_drum.xk+1),a
        ld (pt_drum.xn+1),a
.ev:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tp_i1),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tp_i2),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tp_i3),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z                   ; end of tune (Z: no key)
        ld (tp_len),de
        ld a,(hl)
        inc hl
        push hl
        bit 2,a
        jr z,.nr1
        ld c,DUTY1
        ld b,a
        ld a,c
        ld (.d1+1),a
        ld a,b
.nr1:   bit 3,a
        jr z,.nr2
        ld c,a
        ld a,DUTY2
        ld (.d2+1),a
        ld a,c
.nr2:   bit 4,a
        jr z,.nr3
        ld c,a
        ld a,DUTY3
        ld (.d3+1),a
        ld a,c
.nr3:   and 3
        call nz,pt_drum
        exx
        ld bc,(tp_i2)
        ld hl,(t_ph2)
        ld de,(tp_i3)
        exx
        ld bc,(tp_i1)
        ld hl,(t_ph1)
        ld iy,(t_ph3)
        ld de,(tp_len)
.lp:    add hl,bc               ; voice 1: lead
        ld a,h
.d1:    cp DUTY1
        sbc a,a
        and $21
.x1:    xor $20|LATBASE
        ld (LATCH),a
        exx
        add hl,bc               ; voice 2: echo
        ld a,h
.d2:    cp DUTY2
        sbc a,a
        and $21
.x2:    xor $20|LATBASE
        ld (LATCH),a
        add iy,de               ; voice 3: bass
        ld a,iyh
.d3:    cp DUTY3
        sbc a,a
        and $21
.x3:    xor $20|LATBASE
        ld (LATCH),a
        exx
        dec de
        ld a,e
        or a
        jp nz,.lp
        ld a,d                  ; every 256 loops: narrow the pulses
        or a
        jr z,.done
        ld a,(tp_brk)           ; and answer a key press straight away
        or a
        jr z,.nb
        push hl
        push de
        push bc
        call any_key
        pop bc
        pop de
        pop hl
        jr nz,.brk
.nb:    ld a,(.d1+1)
        cp DMIN
        jr c,.e1
        sub 8
        ld (.d1+1),a
.e1:    ld a,(.d2+1)
        cp $58
        jr c,.e2
        sub 3
        ld (.d2+1),a
.e2:    ld a,(.d3+1)
        cp $58
        jp c,.lp
        sub 3
        ld (.d3+1),a
        jp .lp
.done:  ld (t_ph1),hl
        ld (t_ph3),iy
        exx
        ld (t_ph2),hl
        exx
        ld hl,(tp_hook)
        call jp_hl
        pop hl
        ld a,(tp_brk)
        or a
        jp z,.ev
        call any_key
        jp z,.ev
        ret                     ; NZ: key pressed
.brk:   ld (t_ph1),hl
        pop hl
        ld a,1
        or a
        ret                     ; NZ: key pressed

; pt_drum: A = 1 kick, 2 snare, 3 hat.  Each drum loop is ~100 T, so the
; note is shortened by half the drum's loop count to keep the tempo.
pt_drum:
        cp 1
        jr nz,.noise
        ld b,0                  ; kick: a square wave sweeping down
        ld hl,0
        ld de,$0300
.k:     add hl,de
        ld a,h
        cp $80
        sbc a,a
        and $21
.xk:    xor $20|LATBASE
        ld (LATCH),a
        ld a,e
        sub 2
        ld e,a
        jr nc,.k1
        dec d
.k1:    djnz .k
        ld de,128
        jr .sub
.noise: ld b,160                ; snare: noise fading out
        ld c,$90
        cp 2
        jr z,.n0
        ld b,40                 ; hat: a short tick of noise
        ld c,$50
.n0:    ld hl,(tp_np)
        push bc
.n:     ld a,(hl)
        inc hl
        cp c
        sbc a,a
        and $21
.xn:    xor $20|LATBASE
        ld (LATCH),a
        ld a,b
        and 15
        jr nz,.n1
        ld a,c
        sub 8
        ld c,a
.n1:    djnz .n
        res 6,h                 ; stay inside the ROM
        res 7,h
        ld (tp_np),hl
        pop bc
        ld e,b
        srl e
        ld d,0
.sub:   ld hl,(tp_len)
        or a
        sbc hl,de
        jr nc,.s1
        ld hl,1
.s1:    ld (tp_len),hl
        ret
tp_i1   dw 0
tp_i2   dw 0
tp_i3   dw 0
tp_len  dw 0

; ---------------------------------------------------------------- title
title_bix:
        ; idle / blink / twitch frames packed (2 bytes x 10 rows)
        incbin "../build/bigbix.bin"

title_screen:
        xor a
        ld (tloops),a
title_redraw:
        di
        ld a,(latchv)
        ld (LATCH),a
        ld a,$AA
        call vfill
        ; stars
        ld hl,title_stars
.st:    ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld a,d
        cp $FF
        jr z,.std
        ld a,1
        call vplot
        jr .st
.std:   ; moon
        ld a,T_MOONTL
        ld bc,$000E
        call vtile
        ld a,T_MOONTR
        ld bc,$000F
        call vtile
        ld a,T_MOONBL
        ld bc,$010E
        call vtile
        ld a,T_MOONBR
        ld bc,$010F
        call vtile
        ; ground strip + hills
        ld c,0
.g:     ld b,7
        ld a,T_GRASS
        call vtile
        ld a,c
        cp 12
        jr c,.g2
        ld b,6
        and 3
        ld a,T_HILLB
        jr nz,.g1
        ld a,T_HILLM
.g1:    call vtile
.g2:
        inc c
        ld a,c
        cp 16
        jr nz,.g
        ld a,T_FLOWER
        ld bc,$0602
        call vtile
        ld a,T_BUSH
        ld bc,$0609
        call vtile
        ld a,T_TUFT
        ld bc,$0605
        call vtile
        ; logo
        ld a,'B'
        ld de,$0302
        call logo_char
        ld a,'I'
        ld de,$1102
        call logo_char
        ld a,'X'
        ld de,$1F02
        call logo_char
        ld hl,txt_the
        ld bc,$040C
        call vtext
        ld hl,txt_star
        ld bc,$0B0C
        call vtext
        ld hl,txt_digger
        ld bc,$120C
        call vtext
        ld hl,txt_credit
        ld bc,$1A01
        call vtext
        ld hl,txt_ctl1
        ld bc,$2201
        call vtext
        ld hl,txt_ctl2
        ld bc,$2901
        call vtext
        xor a
        ld (tframe),a
        ld hl,0
        ld (tb_last),hl
        call title_drawbix
        call wait_release
        ld hl,title_anim
        ld (tp_hook),hl
        ld a,1
        ld (tp_brk),a
.loop:  ld hl,title_song
        call play_tune
        jr nz,.key
        ld hl,tloops
        inc (hl)
        ld a,(hl)
        cp 2
        jr nc,.dem
        call hiscore_show       ; between title tunes: the high-score table
        jp title_redraw
.dem:   ld a,1                  ; nobody pressed anything: run the demo
        jr .out
.key:   call mode_menu          ; STORY or TIME ATTACK
.out:   push af
        ld hl,tp_nohook
        ld (tp_hook),hl
        xor a
        ld (tp_brk),a
        call wait_release
        pop af
        ret
tloops  db 0

tframe  db 0
title_anim:                     ; called after every note
        ld hl,tframe
        inc (hl)
        ld a,(hl)
        and 3
        jr nz,.nb
        ; blink the PRESS SPACE line
        ld a,(hl)
        and 4
        jr z,.on
        ld b,$31
        ld c,4
        ld hl,txt_blank
        call vtext
        jr .nb
.on:    ld b,$31
        ld c,4
        ld hl,txt_press
        call vtext
.nb:    ; Bix: blink every 16 notes, twitch every 24
        call title_drawbix
        ; twinkle a star
        call random
        and $7F
        ld d,a
        call random
        and $1F
        ld e,a
        ld a,(tframe)
        and 1
        add a,1
        jp vplot
tb_last dw 0
title_drawbix:
        jr tdb_sel
tb_clear:
        ; clear area x 88..119, y 24..55 to sky
        ld b,24
.c:     push bc
        ld c,22
        call vaddr
        ld b,8
.cl:    ld (hl),$AA
        inc hl
        djnz .cl
        pop bc
        inc b
        ld a,b
        cp 56
        jr nz,.c
        ret
tdb_sel: ld a,(tframe)
        and 15
        cp 15
        ld hl,title_bix+20      ; blink
        jr z,.d
        ld a,(tframe)
        and 31
        cp 24
        jr c,.i
        cp 28
        ld hl,title_bix+40      ; twitch
        jr c,.d
.i:     ld hl,title_bix
.d:     ld de,(tb_last)
        or a
        sbc hl,de
        add hl,de
        ret z                   ; same frame as last time: nothing to redraw
        ld (tb_last),hl
        push hl
        call tb_clear
        pop hl
        ld a,3
        ld (vb_s),a
        ld b,10
        ld c,2
        ld de,$5A1A
        jp draw_big

title_stars:
        db 3,3, 20,1, 47,9, 61,2, 77,6, 84,1, 118,22, 102,18, 70,24, 9,25, 33,22, 124,4, 52,23
        db $FF,$FF
txt_the:     db "THE",0
txt_star:    db "STAR",0
txt_digger:  db "DIGGER",0
txt_credit:  db "2026 VIBED BY BPM",0
txt_ctl1:    db "O/P RUN  SPC JUMP",0
txt_ctl2:    db "A DIG DOWN",0
txt_press:   db "PRESS SPACE",0
txt_blank:   db "           ",0

; ---------------------------------------------------------------- level intro
lvtext:                         ; per level: world line, name, hint
        dw t_w11, t_n11, t_h11,  t_w12, t_n11, t_back, t_w13, t_n12, t_h12
        dw t_w21, t_n21, t_h21,  t_w22, t_n21, t_back, t_w23, t_n22, t_h22
        dw t_w31, t_n31, t_h31,  t_w32, t_n31, t_back, t_w33, t_n32, t_h32
        dw t_w41, t_n41, t_h41,  t_w42, t_n41, t_back, t_w43, t_n42, t_h42
        dw t_w51, t_n51, t_h51,  t_w52, t_n51, t_back, t_fin, t_n52, t_h52
t_w11:  db "WORLD 1-1",0
t_w12:  db "WORLD 1-2",0
t_w13:  db "WORLD 1-3",0
t_w21:  db "WORLD 2-1",0
t_w22:  db "WORLD 2-2",0
t_w23:  db "WORLD 2-3",0
t_w31:  db "WORLD 3-1",0
t_w32:  db "WORLD 3-2",0
t_w33:  db "WORLD 3-3",0
t_w41:  db "WORLD 4-1",0
t_w42:  db "WORLD 4-2",0
t_w43:  db "WORLD 4-3",0
t_w51:  db "WORLD 5-1",0
t_w52:  db "WORLD 5-2",0
t_fin:  db "FINAL BATTLE",0
t_back: db "THE WAY BACK!",0
t_n11:  db "GUMLEAF GULLY",0
t_h11:  db "DIG FOR STARS!",0
t_n12:  db "KING CANE",0
t_h12:  db "STOMP OR BURST!",0
t_n21:  db "CRYSTAL CAVERNS",0
t_h21:  db "DIG THROUGH!",0
t_n22:  db "THE GEODE GOLEM",0
t_h22:  db "BURST FROM BELOW!",0
t_n31:  db "CLOCKWORK WORKS",0
t_h31:  db "MIND THE CRUSHERS",0
t_n32:  db "RUST-O-TRON",0
t_h32:  db "HIT IT WHEN IT LANDS",0
t_n41:  db "SKYWARD ISLES",0
t_h41:  db "RIDE THE WIND!",0
t_n42:  db "THUNDERHAWK",0
t_h42:  db "DODGE THE DIVE",0
t_n51:  db "MOLTEN PEAKS",0
t_h51:  db "RIDE THE VENTS",0
t_n52:  db "THE MAGMA DRAGON",0
t_h52:  db "BRING THE STARS HOME",0
clrtext: dw t_c11, t_cb, t_c12, t_c21, t_cb, t_c22, t_c31, t_cb, t_c32
         dw t_c41, t_cb, t_c42, t_c51, t_cb, t_c52
t_cb:   db "HOME AGAIN!",0
t_c11:  db "GULLY CLEARED!",0
t_c12:  db "KING CANE BEATEN!",0
t_c21:  db "CAVERNS CLEARED!",0
t_c22:  db "GOLEM CRUMBLED!",0
t_c31:  db "WORKS SHUT DOWN!",0
t_c32:  db "TRON SCRAPPED!",0
t_c41:  db "ISLES CLEARED!",0
t_c42:  db "HAWK GROUNDED!",0
t_c51:  db "PEAKS CONQUERED!",0
t_c52:  db "THE DRAGON SLEEPS!",0

; HL = table, A = index (words) -> HL = entry
tab_get:
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
; centre text: HL = string, B = row
vtext_c:
        push hl
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc c
        jr .l
.e:     ld a,32
        sub c
        srl a
        ld c,a
        pop hl
        jp vtext

level_intro:
        di
        ld a,(latchv)
        ld (LATCH),a
        ld a,$AA                ; colour 2 behind the yellow/cyan text
        call vfill
        ld c,0
.g:     ld b,7
        ld a,T_GRASS
        call vtile
        ld a,(tiles)
        cp $AA                  ; only dress the strip if the sky matches
        jr nz,.g2
        ld b,6
        ld a,T_TUFT
        bit 0,c
        jr z,.g1
        ld a,T_SKY
.g1:    call vtile
.g2:
        inc c
        ld a,c
        cp 16
        jr nz,.g
        ld a,(levnum)
        ld b,a
        add a,a
        add a,b                 ; *3 words
        push af
        ld hl,lvtext
        call tab_get
        ld b,$17
        call vtext_c
        pop af
        push af
        inc a
        ld hl,lvtext
        call tab_get
        ld b,$1F
        call vtext_c
        pop af
        add a,2
        ld hl,lvtext
        call tab_get
        ld b,$28
        call vtext_c
        ld a,(bossmode)
        or a
        jr nz,.boss
        ; Bix celebrating
        ld a,2
        ld (vb_s),a
        ld hl,title_bix+60
        ld b,10
        ld c,2
        ld de,$3802
        call draw_big
        jr .j
.boss:  ld a,1
        ld (vb_s),a
        ld hl,BOSSG
        ld b,20
        ld c,6
        ld de,$3402
        call draw_big
.j:     ld hl,jingle_start
        ld a,(bossmode)
        or a
        jr z,.j1
        ld hl,jingle_boss
.j1:    call play_tune
        ld bc,30000
        call delay
        ret

; ---------------------------------------------------------------- clear / over
level_complete:
        call flush_frame
        di
        ld hl,0
        call snd_set
        ld a,$AA
        call vfill
        ld a,(levnum)
        ld hl,clrtext
        call tab_get
        ld b,$08
        call vtext_c
        ld hl,txt_stars
        ld bc,$1208
        call vtext
        ld a,(nstars)
        ld b,0
.s:     cp 10
        jr c,.s1
        sub 10
        inc b
        jr .s
.s1:    push af
        ld a,b
        add a,'0'
        ld bc,$1210
        call vchar
        pop af
        add a,'0'
        ld bc,$1211
        call vchar
        ld hl,txt_score
        ld bc,$1A08
        call vtext
        call score_text
        ld hl,txtbuf
        ld bc,$1A0E
        call vtext
        ld hl,txt_lives
        ld bc,$2208
        call vtext
        ld a,(lives)
        cp 10
        jr c,.lv
        ld a,9
.lv:    add a,'0'
        ld bc,$2210
        call vchar
        ld a,2
        ld (vb_s),a
        ld hl,title_bix+60
        ld b,10
        ld c,2
        ld de,$5C26
        call draw_big
        ld hl,txt_time
        ld bc,$2A08
        call vtext
        ld hl,(tsec)
        ld bc,$2A10
        call vnum3
        ld hl,jingle_clear
        call play_tune
        ; time bonus: every second left is worth 10 points, tallied up
.tal:   ld hl,(tsec)
        ld a,h
        or l
        jr z,.tdone
        ld de,3
        ld a,3
        or a
        sbc hl,de
        jr nc,.t3
        add hl,de               ; fewer than 3 left: take what remains
        ld a,l
        ld hl,0
.t3:    ld (tsec),hl
        call add_score_a        ; (score is kept in tens: +A = +10*A points)
        ld hl,(tsec)
        ld bc,$2A10
        call vnum3
        call score_text
        ld hl,txtbuf
        ld bc,$1A0E
        call vtext
        ld a,(latchv)           ; a click per step
        xor $21
        ld (LATCH),a
        ld bc,600
        call delay
        ld a,(latchv)
        ld (LATCH),a
        jr .tal
.tdone: call wait_release
        ld bc,0
        call wait_key
        call wait_release
        ret
txt_time:   db "TIME",0
txt_stars:  db "STARS",0
txt_score:  db "SCORE",0
txt_lives:  db "LIVES",0

game_over_screen:
        call flush_frame
        di
        ld hl,0
        call snd_set
        ld a,$AA
        call vfill
        ld hl,txt_over
        ld bc,$100B
        call vtext
        ld hl,txt_score
        ld bc,$1A08
        call vtext
        call score_text
        ld hl,txtbuf
        ld bc,$1A0E
        call vtext
        ld hl,jingle_over
        call play_tune
        call wait_release
        ld hl,txt_cont
        ld bc,$2808
        call vtext
        ld a,'9'
.cd:    push af
        ld bc,$2813
        call vchar
        ld bc,42000             ; about a second per digit
        call wait_key
        jr nz,.yes
        pop af
        dec a
        cp '0'-1
        jr nz,.cd
        xor a
        ret
.yes:   pop af
        call wait_release
        ld a,1
        ret
txt_over:   db "GAME OVER",0
txt_cont:   db "CONTINUE?",0

; ---------------------------------------------------------------- ending
endpages:
        dw e1a, e1b, e1c
        dw e2a, e2b, e2c
        dw e3a, e3b, e3c
        dw e4a, e4b, e4c
        dw e5a, e5b, e5c
        dw 0
e1a: db "THE LOST STARS",0
e1b: db "ARE SHINING",0
e1c: db "AGAIN!",0
e2a: db "BIX DUG THEM UP",0
e2b: db "FROM GULLY TO",0
e2c: db "VOLCANO!",0
e3a: db "BIX THE BILBY",0
e3b: db "THE STAR DIGGER",0
e3c: db 0
e4a: db "CREATED AND",0
e4b: db "VIBED BY BPM",0
e4c: db "2026",0
e5a: db "THANKS FOR",0
e5b: db "PLAYING!",0
e5c: db "THE END",0
epage   dw 0
ending:
        call flush_frame
        di
        ld hl,0
        call snd_set
        ld a,LATBASE
        call set_latch
        ld a,$AA
        call vfill
        ld hl,title_stars
.st:    ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld a,d
        cp $FF
        jr z,.std
        ld a,1
        call vplot
        jr .st
.std:   ld hl,endpages
        ld (epage),hl
        xor a
        ld (tframe),a
        ld hl,end_hook
        ld (tp_hook),hl
        call end_page
        ld b,3
.lp:    push bc
        ld hl,ending_song
        call play_tune
        pop bc
        djnz .lp
        ld hl,tp_nohook
        ld (tp_hook),hl
        call wait_release
        ld bc,0
        call wait_key
        call wait_key
        call wait_release
        ret
end_hook:
        ld hl,tframe
        inc (hl)
        ld a,(hl)
        and 7
        ret nz
end_page:
        ; clear text band rows 30..55
        ld b,30
.c:     push bc
        ld c,0
        call vaddr
        ld b,32
.cl:    ld (hl),$AA
        inc hl
        djnz .cl
        pop bc
        inc b
        ld a,b
        cp 56
        jr nz,.c
        ld hl,(epage)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr nz,.p
        ld hl,endpages          ; loop the pages
        ld (epage),hl
        jr end_page
.p:     dec hl
        push hl
        ex de,hl
        ld b,32
        call vtext_c
        pop hl
        inc hl
        inc hl
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld b,40
        call vtext_c
        pop hl
        inc hl
        inc hl
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld b,48
        call vtext_c
        pop hl
        inc hl
        inc hl
        ld (epage),hl
        ; big Bix (alternating cheer / idle)
        ld a,(tframe)
        and 8
        ld hl,title_bix+60
        jr z,.b
        ld hl,title_bix
.b:     push hl
        ld b,2
.bc:    push bc
        ld c,13
        call vaddr
        ld b,6
.bcl:   ld (hl),$AA
        inc hl
        djnz .bcl
        pop bc
        inc b
        ld a,b
        cp 28
        jr nz,.bc
        pop hl
        ld a,2
        ld (vb_s),a
        ld b,10
        ld c,2
        ld de,$3404
        jp draw_big

score_text:                     ; score -> txtbuf "dddddd0"
        ld hl,score
        ld de,txtbuf
        ld b,3
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .l
        ld a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

font_sky: incbin "../build/font_sky.bin"
        include "../build/music.inc"

        include "loader.asm"

; ---------------------------------------------------------------- menus
msel    db 0
mode_menu:
        ld hl,tp_nohook
        ld (tp_hook),hl
        call wait_release
        xor a
        ld (msel),a
        ld (demo),a
.draw:  ld hl,mm_story
        ld a,(msel)
        or a
        jr z,.d1
        ld hl,mm_story2
.d1:    ld bc,$2201
        call vtext
        ld hl,mm_ta2
        ld a,(msel)
        or a
        jr z,.d2
        ld hl,mm_ta
.d2:    ld bc,$2901
        call vtext
        ld hl,txt_blank
        ld bc,$3104
        call vtext
        call idle_reset
.w:     ld bc,2500
        call delay
        call read_input
        call idle_chk
        jr nc,.nto
        ld a,1                  ; nobody chose: run the attract demo instead
        ret
.nto:   ld a,(kedge)
        and K_U|K_D|K_L|K_R
        jr nz,.t
        ld a,(kedge)
        and K_J
        jr z,.w
        call wait_release
        ld a,(msel)
        add a,a                 ; 0 story, 2 time attack
        ret
.t:     ld a,(msel)
        xor 1
        ld (msel),a
        jp .draw
mm_story:  db "* STORY           ",0
mm_story2: db "  STORY           ",0
mm_ta:     db "* TIME ATTACK     ",0
mm_ta2:    db "  TIME ATTACK     ",0

; ---------------------------------------------------------------- high scores
hiscore_show:
        ld hl,tp_nohook
        ld (tp_hook),hl
        ld a,$AA
        call vfill
        ld hl,t_best
        ld b,4
        call vtext_c
        ld ix,hitab
        ld b,14
        ld c,'1'
.l:     push bc
        ld a,c
        ld c,8
        call vchar
        pop bc
        push bc
        ; name
        ld a,(ix+3)
        ld c,10
        call vchar
        pop bc
        push bc
        ld a,(ix+4)
        ld c,11
        call vchar
        pop bc
        push bc
        ld a,(ix+5)
        ld c,12
        call vchar
        pop bc
        push bc
        ; score
        push ix
        pop hl
        ld de,score
        push de
        ld bc,3
        ld de,hs_tmp
        ldir                    ; borrow score_text via a temporary swap
        pop de
        call hs_swap
        call score_text
        call hs_swap
        pop bc
        push bc
        ld hl,txtbuf
        ld c,15
        call vtext
        pop bc
        ld de,6
        add ix,de
        ld a,b
        add a,8
        ld b,a
        inc c
        ld a,c
        cp '6'
        jr nz,.l
        ld bc,0                 ; ~10 s (it was twice that)
        call wait_key
        ret
hs_swap:                        ; exchange score <-> hs_tmp
        ld hl,score
        ld de,hs_tmp
        ld b,3
.s:     ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        inc hl
        inc de
        djnz .s
        ret
hs_tmp  ds 3
t_best: db "BEST STAR DIGGERS",0

; hiscore: after a story game; enter initials if the score made the table
hiscore:
        ld ix,hitab
        ld b,0
.f:     ld a,(score)
        cp (ix+0)
        jr c,.n
        jr nz,.ins
        ld a,(score+1)
        cp (ix+1)
        jr c,.n
        jr nz,.ins
        ld a,(score+2)
        cp (ix+2)
        jr c,.n
        jr z,.n
        jr .ins
.n:     ld de,6
        add ix,de
        inc b
        ld a,b
        cp 5
        jr nz,.f
        jp hiscore_show
.ins:   ; shift lower entries down
        push ix
        ld hl,hitab+23
        ld de,hitab+29
.sh:    push hl
        push ix
        pop bc
        or a
        sbc hl,bc
        pop hl
        jr c,.sd
        ld a,(hl)
        ld (de),a
        dec hl
        dec de
        jr .sh
.sd:    pop ix
        ld a,(score)
        ld (ix+0),a
        ld a,(score+1)
        ld (ix+1),a
        ld a,(score+2)
        ld (ix+2),a
        ; name entry
        ld a,$AA
        call vfill
        ld hl,t_newhi
        ld b,10
        call vtext_c
        ld hl,t_enter
        ld b,20
        call vtext_c
        ld a,'A'
        ld (ix+3),a
        ld (ix+4),a
        ld (ix+5),a
        call wait_release
        call idle_reset
        ld c,0                  ; letter index
.le:    push bc
        ; draw the three letters + cursor
        ld a,(ix+3)
        ld bc,$200E
        call vchar
        ld a,(ix+4)
        ld bc,$200F
        call vchar
        ld a,(ix+5)
        ld bc,$2010
        call vchar
        ld hl,t_cur0
        ld bc,$270E
        call vtext
        pop bc
        push bc
        ld a,c
        add a,14
        ld c,a
        ld a,'^'-32+32
        ld a,'*'
        ld b,$27
        call vchar
        pop bc
.lw:    push bc
        ld bc,2500
        call delay
        call read_input
        call idle_chk
        pop bc
        jp c,hiscore_show       ; nobody there: keep the name as it is
        ld a,(kedge)
        and K_J
        jr nz,.next
        ld a,(kedge)
        and K_L|K_R|K_U|K_D
        jr z,.lw
        ; change the letter
        push ix
        pop hl
        ld de,3
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        ld a,(kedge)
        and K_R|K_U
        ld a,(hl)
        jr z,.dn
        inc a
        cp 'Z'+1
        jr c,.st
        ld a,' '
        jr .st
.dn:    dec a
        cp 'A'
        jr nc,.st
        cp ' '
        jr z,.st
        ld a,'Z'
.st:    cp ' '+1
        jr nz,.st2
        ld a,'A'
.st2:   ld (hl),a
        jp .le
.next:  inc c
        ld a,c
        cp 3
        jp nz,.le
        call wait_release
        jp hiscore_show
t_newhi: db "A NEW HIGH SCORE!",0
t_enter: db "ENTER YOUR NAME",0
t_cur0:  db "   ",0

; ---------------------------------------------------------------- time attack
tatab:  db 0,1,3,4,6,7,9,10,12,13
tasel   db 0
ta_menu:
        call wait_release
        ld a,LATBASE
        call set_latch
.draw:  ld a,$AA
        call vfill
        ld hl,t_ta
        ld b,4
        call vtext_c
        ld a,(tasel)
        ld e,a
        ld d,0
        ld hl,tatab
        add hl,de
        ld a,(hl)
        ld (ta_lv),a
        ld b,a
        add a,a
        add a,b
        push af
        ld hl,lvtext
        call tab_get
        ld b,16
        call vtext_c
        pop af
        inc a
        ld hl,lvtext
        call tab_get
        ld b,24
        call vtext_c
        ld hl,t_bestt
        ld bc,$2209
        call vtext
        call ta_best
        ld a,h
        and l
        cp $FF
        ld hl,t_none
        jr z,.nb
        call ta_best
        call fmt_time
        ld hl,txtbuf
.nb:    ld bc,$220E
        call vtext
        ld hl,t_tah1
        ld b,46
        call vtext_c
        ld hl,t_tah2
        ld b,54
        call vtext_c
        call idle_reset
.w:     ld bc,2500
        call delay
        call read_input
        call idle_chk
        jp c,.back              ; left alone: back to the title
        ld a,(kedge)
        and K_J
        jr nz,.go
        ld a,(kedge)
        and K_D
        jr nz,.back
        ld a,(kedge)
        and K_L|K_R
        jr z,.w
        and K_R
        ld a,(tasel)
        jr z,.lft
        inc a
        cp 10
        jr c,.s
        xor a
        jr .s
.lft:   or a
        jr nz,.l1
        ld a,10
.l1:    dec a
.s:     ld (tasel),a
        jp .draw
.go:    call wait_release
        ld a,(ta_lv)
        ret
.back:  call wait_release
        ld a,$FF
        ret
ta_lv   db 0
ta_best:                        ; HL = record for (ta_lv)
        ld a,(ta_lv)
        add a,a
        ld e,a
        ld d,0
        ld hl,besttime
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
t_ta:    db "TIME ATTACK",0
t_bestt: db "BEST",0
t_none:  db "-:--.-",0
t_tah1:  db "O/P PICK  SPACE GO",0
t_tah2:  db "A BACK",0

ta_result:
        di
        ld hl,0
        call snd_set
        ld a,$AA
        call vfill
        ld a,(levnum)
        ld (ta_lv),a
        ld hl,clrtext
        call tab_get
        ld b,8
        call vtext_c
        ld hl,t_time
        ld bc,$1609
        call vtext
        ld hl,(timer)
        call fmt_time
        ld hl,txtbuf
        ld bc,$160E
        call vtext
        ; new record?
        call ta_best
        ld de,(timer)
        or a
        sbc hl,de
        jr c,.no
        jr z,.no
        ld a,(ta_lv)
        add a,a
        ld e,a
        ld d,0
        ld hl,besttime
        add hl,de
        ld de,(timer)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,t_rec
        ld b,32
        call vtext_c
        ld hl,jingle_clear
        call play_tune
        jr .w
.no:    ld hl,t_bestt
        ld bc,$2009
        call vtext
        call ta_best
        call fmt_time
        ld hl,txtbuf
        ld bc,$200E
        call vtext
        ld hl,jingle_start
        call play_tune
.w:     call wait_release
        ld bc,0
        call wait_key
        jp wait_release
t_time: db "TIME",0
t_rec:  db "NEW RECORD!",0

; ---------------------------------------------------------------- idle time-out
; Menus that wait for the player give up after ~20 s with no input, so an
; unattended machine drifts back to the title and the attract demo.
IDLE_MAX equ 1100
idlec   dw 0
idle_reset:
        ld hl,0
        ld (idlec),hl
        ret
idle_chk:                       ; call after read_input; carry = timed out
        ld a,(keys)
        or a
        jr nz,idle_reset        ; (returns with carry clear)
        ld hl,(idlec)
        inc hl
        ld (idlec),hl
        ld de,IDLE_MAX
        or a
        sbc hl,de
        ccf
        ret

; vnum3: HL = 0..999 as three digits at row B, column C (title font)
vnum3:
        push bc
        ld c,10
        call div16_8
        ld (vn_d+2),a
        ld c,10
        call div16_8
        ld (vn_d+1),a
        ld a,l
        ld (vn_d),a
        pop bc
        ld hl,vn_d
        ld e,3
.l:     ld a,(hl)
        add a,'0'
        push bc
        push de
        push hl
        call vchar
        pop hl
        pop de
        pop bc
        inc hl
        inc c
        dec e
        jr nz,.l
        ret
vn_d    ds 3
