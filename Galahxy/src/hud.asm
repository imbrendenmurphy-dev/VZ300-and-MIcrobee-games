; =====================================================================
;  hud.asm - the top six rows, written straight into video RAM
;  0012340 x8  &&&  @3   HI 0050000      (boss fights: BOSS ======)
; =====================================================================
HUD_PAPER   equ 2              ; blue
HUD_BYTE    equ $AA

draw_hud:
            ld a,(hud_dirty)
            or a
            ret z
            ld a,(frames)           ; at most every fourth frame
            and 3
            ret nz
hud_force:
            xor a
            ld (hud_dirty),a
            ld a,HUD_BYTE
            call cls_hud
            ld a,1
            ld c,HUD_PAPER
            call text_col
            ld hl,score
            ld de,VRAM+32
            call print_score
            ; chain multiplier
            ld a,(chain)
            cp 2
            jr c,.nch
            push af
            ld a,3
            ld c,HUD_PAPER
            call text_col
            ld de,VRAM+32+8
            ld a,'X'
            call putc
            inc de
            pop af
            add a,'0'
            call putc
.nch:       ; health hearts (red), lost ones dim (green)
            ld a,3
            ld c,HUD_PAPER
            call text_col
            ld de,VRAM+32+11
            ld a,(p_health)
            or a
            jr z,.nh
            ld b,a
.h:         push bc
            ld a,'&'
            call putc
            inc de
            pop bc
            djnz .h
.nh:        ld a,(p_health)
            ld b,a
            ld a,3
            sub b
            jr z,.nh2
            jr c,.nh2
            push af
            ld a,0
            ld c,HUD_PAPER
            call text_col
            pop bc
.h2:        push bc
            ld a,'&'
            call putc
            inc de
            pop bc
            djnz .h2
.nh2:       ; lives
            ld a,1
            ld c,HUD_PAPER
            call text_col
            ld de,VRAM+32+15
            ld a,'@'
            call putc
            inc de
            ld a,(p_lives)
            cp 10
            jr c,.lv
            ld a,9
.lv:        add a,'0'
            call putc
            ; boss bar or the high score
            ld a,(boss_bar)
            or a
            jr nz,.boss
            ld a,0
            ld c,HUD_PAPER
            call text_col
            ld hl,str_hi
            ld de,VRAM+32+19
            call print
            ld a,1
            ld c,HUD_PAPER
            call text_col
            ld hl,hiscore
            ld de,VRAM+32+22
            jp print_score
.boss:      ld a,3
            ld c,HUD_PAPER
            call text_col
            ld hl,str_boss
            ld de,VRAM+32+18
            call print
            ; bar: 10 bytes (40 px) at column 22, rows 2-4, filled by hp/max
            ld hl,VRAM+64+22
            ld b,3
.br:        push bc
            push hl
            ld (hl),$55             ; frame: yellow
            ld d,h
            ld e,l
            inc de
            ld bc,9
            ldir
            pop hl
            ld bc,32
            add hl,bc
            pop bc
            djnz .br
            ; fill = boss_hp * 38 / boss_max  pixels (red) inside row 3
            ld hl,(boss_hp)
            ld a,h
            or l
            ret z
            ld e,38
            ld h,l
            call mul8               ; (hp < 256) HL = hp*38
            ld a,(boss_max)
            ld c,a
            call div16_8
            ld a,l
            or a
            ret z
            ld b,a                  ; pixels
            ld hl,VRAM+96+22
            ld c,1                  ; pixel index from the left (skip frame px)
.px:        push bc
            ld a,c
            srl a
            srl a
            ld e,a
            ld d,0
            push hl
            add hl,de
            ld a,c
            and 3
            ld e,a
            ld d,0
            push hl
            ld hl,pxmask_r
            add hl,de
            ld a,(hl)
            pop hl
            ld d,a
            cpl
            and (hl)
            ld e,a
            ld a,d
            and $FF                 ; red in that pixel = 3s
            or e
            ld (hl),a
            pop hl
            pop bc
            inc c
            djnz .px
            ret
pxmask_r:   db $C0,$30,$0C,$03
str_hi:     db "HI",0
str_boss:   db "BOSS",0

; flash the HUD row now and then (called by events that change it)
hud_now:    ld a,1
            ld (hud_dirty),a
            ret
