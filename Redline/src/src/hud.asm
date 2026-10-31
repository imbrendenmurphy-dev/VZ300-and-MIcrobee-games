; =====================================================================
;  hud.asm - race information in the sky (VRAM rows 0-11), messages
;  drawn into the back buffer, the section-loading banner
; =====================================================================
FONT      equ font_data
BIGF      equ font_data+320

MSG_GO     equ 0
MSG_CHECK  equ 1
MSG_FINISH equ 2
MSG_TIMEUP equ 3
MSG_CRASH  equ 4
MSG_EXTEND equ 5
MSG_READY  equ 6
MSG_1      equ 7
MSG_2      equ 8
MSG_3      equ 9

; nibble (4 px) -> byte with fg/bg colours
; build exp tables: (hud_fg),(hud_bg) -> exps ; (big_fg),(big_bg) -> expb
hud_colours:
        ld hl,exps
        ld a,(hud_fg)
        ld d,a
        ld a,(hud_bg)
        ld e,a
        call .mk
        ld hl,expb
        ld a,(big_fg)
        ld d,a
        ld a,(big_bg)
        ld e,a
.mk:    ld c,0
.l:     ld a,c
        call nib_mask           ; A = pixel mask
        ld b,a
        and d
        ld (.t+1),a
        ld a,b
        cpl
        and e
.t:     or 0
        ld (hl),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.l
        ret

; A = nibble (bit3 = leftmost pixel) -> A = 2-bit-per-pixel mask
nib_mask:
        push bc
        ld b,4
        ld c,0
.l:     sla c
        sla c
        bit 3,a
        jr z,.n
        set 1,c
        set 0,c
.n:     add a,a
        djnz .l
        ld a,c
        pop bc
        ret

; draw text HL (0-terminated) at VRAM row B (top), column C
hud_text:
        ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call hud_char
        pop bc
        pop hl
        inc hl
        inc c
        jr hud_text

; A = char, B = row, C = column  (VRAM)
hud_char:
        sub 32
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *5
        ld de,FONT
        add hl,de
        ex de,hl                ; DE = glyph
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        add a,l
        ld l,a
        ld a,h
        adc a,high VRAM
        ld h,a
        ld b,5
.r:     ld a,(de)
        and 15
        push hl
        ld hl,exps
        add a,l
        ld l,a
        jr nc,.c
        inc h
.c:     ld a,(hl)
        pop hl
        ld (hl),a
        inc de
        ld a,l
        add a,32
        ld l,a
        jr nc,.n
        inc h
.n:     djnz .r
        ret

; big digit A (0-9) at VRAM column C, rows 1-10
hud_big:
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *10
        ld de,BIGF
        add hl,de
        ex de,hl
        ld hl,VRAM+32
        ld a,l
        add a,c
        ld l,a
        ld b,10
.r:     ld a,(de)
        push hl
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        ld hl,expb
        add a,l
        ld l,a
        jr nc,.c1
        inc h
.c1:    ld c,(hl)
        pop af
        and 15
        ld hl,expb
        add a,l
        ld l,a
        jr nc,.c2
        inc h
.c2:    ld a,(hl)
        pop hl
        ld (hl),c
        inc l
        ld (hl),a
        dec l
        inc de
        ld a,l
        add a,32
        ld l,a
        jr nc,.n
        inc h
.n:     djnz .r
        ret

; ---------------------------------------------------------------- full HUD
hud_init:
        call hud_colours
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,12*32-1
        ld a,(hud_bg)
        ld (hl),a
        ldir
        ; time box: columns 12-19, rows 0-11
        ld hl,VRAM+12
        ld b,12
.bx:    push bc
        push hl
        ld a,(big_bg)
        ld b,8
.bxr:   ld (hl),a
        inc l
        djnz .bxr
        pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .bx
        ld hl,t_sc
        ld bc,$0100
        call hud_text
        ld hl,t_hi
        ld bc,$0700
        call hud_text
        ld hl,t_stage
        ld bc,$0116
        call hud_text
        ld hl,t_kmh
        ld bc,$071D
        call hud_text
        ld a,(leg)
        add a,'1'
        ld b,1
        ld c,28
        call hud_char
        ld hl,t_of
        ld bc,$011D
        call hud_text
        call hud_hiscore
        ld a,1
        ld (hud_tdirty),a
        ld (hud_sdirty),a
        ld hl,$FFFF
        ld (hud_lastk),hl
        ret
hud_lastk: dw 0
t_sc:   db "SC",0
t_hi:   db "HI",0
t_stage: db "STAGE",0
t_kmh:  db "KMH",0
t_of:   db "/5",0

hud_update:
        ld a,(hud_tdirty)
        or a
        jr z,.s
        xor a
        ld (hud_tdirty),a
        ld a,(tleft)
        call bin2bcd
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        ld c,14
        call hud_big
        pop af
        and 15
        ld c,16
        call hud_big
.s:     ; speed (every other frame, 3 digits at columns 25-27, row 7)
        ld a,(frames)
        rra
        jr c,.ks2
        ld hl,(speed)
        ld a,h                  ; kmh = speed/64
        ld e,l
        sla e
        rla
        sla e
        rla
        ld l,a
        ld h,0
        ld a,(speed+1)
        cp 64
        jr c,.k
        inc h                   ; >= 256 km/h
        ld a,l
        ld l,a
.k:     ld de,(hud_lastk)
        or a
        push hl
        sbc hl,de
        pop hl
        jr z,.ks
        ld (hud_lastk),hl
        call bin3
        ld hl,numbuf
        ld bc,$0719
        call hud_text
.ks:
.ks2:   ld a,(hud_sdirty)
        or a
        ret z
        xor a
        ld (hud_sdirty),a
        ld hl,score
        ld de,numbuf
        call bcd6
        ld hl,numbuf
        ld bc,$0103
        jp hud_text

hud_hiscore:
        ld hl,hiscore
        ld de,numbuf
        call bcd6
        ld hl,numbuf
        ld bc,$0703
        jp hud_text

; HL -> 3 BCD bytes -> DE: 6 digits + 0 trailing "0" (scores x10)
bcd6:   ld b,3
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

; A (0..99) -> A = BCD
bin2bcd:
        ld b,0
.l:     cp 10
        jr c,.d
        sub 10
        inc b
        jr .l
.d:     ld c,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or c
        ret

; HL (0..999) -> numbuf: 3 digits, leading blanks
bin3:   ld de,numbuf
        ld bc,-100
        call .dg
        ld bc,-10
        call .dg
        ld a,l
        add a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld a,(numbuf)
        cp '0'
        ret nz
        ld a,' '
        ld (numbuf),a
        ld a,(numbuf+1)
        cp '0'
        ret nz
        ld a,' '
        ld (numbuf+1),a
        ret
.dg:    ld a,'0'-1
.d1:    inc a
        add hl,bc
        jr c,.d1
        sbc hl,bc
        ld (de),a
        inc de
        ret
numbuf: ds 10

; ---------------------------------------------------------------- messages
show_msg:
        ld (msg_id),a
        ld a,24
        ld (msg_t),a
        ret

; draw the current message into the back buffer (rows 15-19, centred)
draw_msg:
        ld a,(msg_t)
        or a
        ret z
        dec a
        ld (msg_t),a
        and 2                   ; flash for the last frames
        jr nz,.on
        ld a,(msg_t)
        cp 6
        ret c
.on:    ld a,(msg_id)
        add a,a
        ld l,a
        ld h,0
        ld de,msg_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ; length -> start column
        push hl
        ld b,0
.ln:    ld a,(hl)
        or a
        jr z,.lz
        inc hl
        inc b
        jr .ln
.lz:    ld a,32
        sub b
        srl a
        ld c,a
        pop hl
        push hl
        push bc
        ld a,(msg_shadow)
        ld (bt_col),a
        ld b,16
        call bb_text
        pop bc
        pop hl
        ld a,(msg_col)
        ld (bt_col),a
        ld b,15
        jp bb_text

msg_tab: dw m_go,m_check,m_finish,m_timeup,m_crash,m_extend,m_ready,m_1,m_2,m_3
m_go:    db "GO!",0
m_check: db "CHECKPOINT",0
m_finish: db "STAGE CLEAR",0
m_timeup: db "TIME UP",0
m_crash: db "CRASH!",0
m_extend: db "EXTENDED TIME",0
m_ready: db "GET READY",0
m_1:    db "- 1 -",0
m_2:    db "- 2 -",0
m_3:    db "- 3 -",0

; text HL into the back buffer at row B, column C, colour (bt_col), transparent
bb_text:
        ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call bb_char
        pop bc
        pop hl
        inc hl
        inc c
        jr bb_text
bb_char:
        sub 32
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,FONT
        add hl,de
        ex de,hl
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        add a,l
        ld l,a
        ld a,h
        adc a,high BBR0
        ld h,a
        ld a,l
        add a,low BBR0
        ld l,a
        jr nc,.a
        inc h
.a:     ld b,5
.r:     ld a,(de)
        and 15
        call nib_mask
        ld c,a
        ld a,(bt_col)
        and c
        push af
        ld a,c
        cpl
        and (hl)
        ld c,a
        pop af
        or c
        ld (hl),a
        inc de
        ld a,l
        add a,32
        ld l,a
        jr nc,.n
        inc h
.n:     djnz .r
        ret
bt_col: db 0

; ---------------------------------------------------------------- loading banner
; straight into VRAM over the frozen picture: rows 30-38
load_banner:
        ld hl,VRAM+30*32
        ld b,9
        ld a,(big_bg)
.r:     push bc
        ld b,32
.c:     ld (hl),a
        inc hl
        djnz .c
        pop bc
        djnz .r
        ld a,(hud_fg)
        push af
        ld a,(big_fg)
        ld (hud_fg),a
        ld a,(hud_bg)
        push af
        ld a,(big_bg)
        ld (hud_bg),a
        call hud_colours
        ld hl,t_load
        ld bc,$1F06
        call hud_text
        pop af
        ld (hud_bg),a
        pop af
        ld (hud_fg),a
        jp hud_colours
t_load: db "LOADING NEXT SECTION",0

font_data: incbin "../build/font.bin"
exps:   ds 16
expb:   ds 16
