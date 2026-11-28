; =====================================================================
;  hud.asm - the status panel (back-buffer rows 0-9, copied by the ISR
;  only when it changes)
;   rows 2-6: host number, host name (or a message), score
;   rows 7-8: energy bar, lives          row 9: red rule
; =====================================================================

hud_update:
            ld a,(msg_t)
            or a
            jr z,.m
            dec a
            ld (msg_t),a
            jr nz,.blink
            ld a,1                  ; message over: name back
            ld (hud_n),a
            jr .m
.blink:     cp 20
            jr c,.m
            and 7
            jr nz,.m
            ld a,1
            ld (hud_n),a
.m:         ld a,(hud_all)
            or a
            jr nz,hud_all_draw
            ld a,(hud_n)
            or a
            call nz,hud_name
            ld a,(hud_e)
            or a
            call nz,hud_energy
            ld a,(hud_s)
            or a
            call nz,hud_score
            ret

hud_all_draw:
            xor a
            ld (hud_all),a
            call txt_game
            ld hl,BB
            ld bc,BBW*9
            ld a,$AA                ; blue
            call fill
            ld hl,BB+BBW*9
            ld bc,BBW
            ld a,$FF                ; red rule
            call fill
            ld d,1
            ld e,2
            call txt_colour
            ; host number
            ld a,(plr+O_TYPE)
            ld de,hud_buf
            call type_num
            ld hl,hud_buf
            ld de,$0002
            call draw_str
            call hud_name
            call hud_energy
            call hud_score
            call hud_lives
            ld a,1
            ld (hud_dirty),a
            ret

; the name / message field: columns 4-21
hud_name:
            xor a
            ld (hud_n),a
            call txt_game
            ld d,1
            ld e,2
            call txt_colour
            ld hl,blank18
            ld de,$0402
            call draw_str
            ld a,(msg_t)
            or a
            jr z,.name
            cp 20                   ; blink while it is new
            jr c,.show
            and 8
            jr z,.done
.show:      ld d,3
            ld e,2
            call txt_colour
            ld hl,(msg_p)
            ld de,$0402
            call draw_str
            jr .done
.name:      ld a,(plr+O_TYPE)
            call type_name          ; HL = name
            ld de,$0402
            call draw_str
.done:      ld a,1
            ld (hud_dirty),a
            ret

; A = type -> HL = name (12 chars max, in upper bank 1)
type_name:
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,de
            add hl,hl
            add hl,hl               ; *12
            ld de,tnames
            add hl,de
            ret

hud_score:
            xor a
            ld (hud_s),a
            call txt_game
            ld d,1
            ld e,2
            call txt_colour
            ld hl,score
            ld de,hud_buf
            ld b,3
            call bcd_str
            ld hl,hud_buf
            ld de,$1A02
            call draw_str
            ld a,1
            ld (hud_dirty),a
            ret

; energy bar: 64 pixels at columns 1-16, rows 7-8
hud_energy:
            xor a
            ld (hud_e),a
            ; filled pixels = energy * 64 / max
            ld a,(plr+O_EN)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(plr+O_MAXE)
            or a
            jr nz,.d
            inc a
.d:         ld c,a
            call div_hl_c
            ld a,l
            cp 65
            jr c,.ok
            ld a,64
.ok:        ld (he_px),a
            ; colour: red under a quarter
            ld a,(plr+O_EN)
            add a,a
            add a,a
            ld b,a
            ld a,(plr+O_MAXE)
            cp b
            ld a,$55
            jr c,.col
            ld a,$FF
.col:       ld (he_col),a
            ld hl,BB+BBW*7+BBG+1
            call .row
            ld hl,BB+BBW*8+BBG+1
            call .row
            ld a,1
            ld (hud_dirty),a
            ret
.row:       ld a,(he_px)
            ld c,a
            ld b,16
.b:         ld a,c
            cp 4
            jr c,.part
            ld a,(he_col)
            ld (hl),a
            ld a,c
            sub 4
            ld c,a
            jr .nx
.part:      ; 0-3 filled pixels: mask the colour
            push hl
            ld hl,partmask
            add a,l
            ld l,a
            jr nc,.pm
            inc h
.pm:        ld a,(hl)
            pop hl
            ld e,a
            ld a,(he_col)
            and e
            ld d,a
            ld a,e
            cpl
            and $88                 ; the rest: a dotted track
            or d
            ld (hl),a
            ld c,0
.nx:        inc hl
            djnz .b
            ret
partmask:   db $00,$C0,$F0,$FC

; lives: the number of spare probes in red, then a probe (a yellow ring,
; red eye, green feelers), in the text rows between the name field
; (columns 4-21) and the score (26-31): column 22, then 23-24
hud_lives:
            ld a,(lives)
            dec a                   ; spare probes
            add a,'0'
            ld hl,hud_buf
            ld (hl),a
            inc hl
            ld (hl),0
            ld de,$0302
            call txt_colour
            ld hl,hud_buf
            ld de,$1602
            call draw_str
            ld hl,BB+BBW*2+BBG+23
            ld de,probe_icon
            ld b,5
.r:         ld a,(de)
            ld (hl),a
            inc de
            inc hl
            ld a,(de)
            ld (hl),a
            inc de
            push bc
            ld bc,BBW-1
            add hl,bc
            pop bc
            djnz .r
            ret
probe_icon: db $A5,$6A              ; ..YY Y...
            db $9F,$DA              ; .YRR RY..
            db $1F,$D2              ; GYRR RYG.
            db $9F,$DA
            db $A5,$6A

; HL = message (0 ends) shown in the name field for a few seconds
show_msg:
            ld (msg_p),hl
            ld a,90
            ld (msg_t),a
            ld a,1
            ld (hud_n),a
            ret

blank18:    db "                  ",0
