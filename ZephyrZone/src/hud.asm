; =====================================================================
;  hud.asm - score / health / weapon bar (VRAM rows 0-5) and the big
;  centre-screen messages (rendered once into a sprite, drawn per frame)
; =====================================================================
HUD_BG      equ $AA             ; colour 2 band
HUD_FG      equ 1

; byte for a 3-bit glyph row (+1 px gap) in colour 1 on colour 2
; score += A * 10 (A binary 0-255)
add_score10:
            ; A -> BCD (hundreds, tens/units)
            ld c,0
.h:         cp 100
            jr c,.t
            sub 100
            inc c
            jr .h
.t:         ld b,a
            xor a
.tl:        ld e,a
            ld a,b
            cp 10
            jr c,.u
            sub 10
            ld b,a
            ld a,e
            add a,$10
            jr .tl
.u:         ld a,e
            or b                    ; A = tens/units BCD, C = hundreds
            ; value*10: shift the BCD left one digit: units->tens...
            ld b,a
            rlca
            rlca
            rlca
            rlca
            and $F0                 ; units*10 -> low byte high nibble
            ld e,a
            ld a,b
            rrca
            rrca
            rrca
            rrca
            and $0F                 ; tens -> hundreds digit
            ld d,a
            ld a,c
            rlca
            rlca
            rlca
            rlca
            or d
            ld d,a                  ; D = thousands/hundreds, E = tens/units
            ld hl,score+2
            ld a,(hl)
            add a,e
            daa
            ld (hl),a
            dec hl
            ld a,(hl)
            adc a,d
            daa
            ld (hl),a
            dec hl
            ld a,(hl)
            adc a,0
            daa
            ld (hl),a
            ld a,1
            ld (hud_dirty),a
            ret

; ---------------------------------------------------------------------
; big messages: show_msg A = message id (shown for ~2.5 s)
; rendered into MSGREC (a key-0 sprite record, 2x size font, colour 1)
; ---------------------------------------------------------------------
M_STAGE     equ 0
M_NAME1     equ 1
M_READY     equ 2
M_POWER     equ 3
M_WARN      equ 4
M_BOSS1     equ 5
M_CLEAR     equ 6
M_OVER      equ 7
M_PAUSE     equ 8
M_CONT      equ 9
M_LOOP      equ 10
M_SHIELD    equ 11
M_FIRE      equ 12
M_CASUAL    equ 13
M_TOGR      equ 16
M_FROM      equ 17
M_HINT      equ 18

; draw the current message (if any) centred at row 12
draw_msg:
            ld a,(msg_t)
            or a
            ret z
            ld b,a
            ld a,(dt)
            ld c,a
            ld a,b
            sub c
            jr nc,.t
            xor a
.t:         ld (msg_t),a
            cp 20                   ; blink out at the end
            jr nc,.d
            ld a,(anim)
            and 4
            ret nz
.d:         ld a,(msg_y)
; draw both halves of the rendered message with their top at row A
msg_blit:
            ld (mb_y),a
            ld a,MAP_FE             ; the records live in upper bank 0
            call setmap
            ld hl,(MSG_ENT)
            ld a,h
            or l
            ld hl,MSG_ENT
            call nz,.one
            ld hl,(MSG_ENT+4)
            ld a,h
            or l
            ld hl,MSG_ENT+4
            call nz,.one
            jp map_game
.one:       push hl
            ld hl,64
            ld (spr_x),hl
            ld a,(mb_y)
            ld l,a
            ld h,0
            ld (spr_y),hl
            pop hl
            jp draw_sprite
