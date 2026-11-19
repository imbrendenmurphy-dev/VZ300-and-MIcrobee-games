; =====================================================================
;  att.asm - the intro cinematic (OVATT.DAT, loaded into low bank 3 at
;  $4000 at the start of every attract cycle; runs in the front end's
;  mapping). A starfield, the Kestrel freighter gliding in, red alert,
;  the probe's launch, a flash into the title. Fire skips it.
; =====================================================================
            include "gen/mainsym.inc"
            include "gen/fesym.inc"
            org $4000
att_entry:  jp intro

NSTAR       equ 18
SHIP_Y      equ 24
EV_TEXT     equ 1
EV_CLRB     equ 2
EV_SHIP     equ 3
EV_ALERT    equ 4
EV_PROBE    equ 5
EV_FLASH    equ 6
EV_END      equ 7
EV_CLRT     equ 8

; the script: time (fields), event, argument
script:     dw 30
            db EV_TEXT
            dw t_belt
            dw 110
            db EV_SHIP
            dw 0
            dw 190
            db EV_TEXT
            dw t_dark1
            dw 250
            db EV_TEXT
            dw t_dark2
            dw 470
            db EV_CLRB
            dw 0
            dw 475
            db EV_ALERT
            dw 0
            dw 480
            db EV_TEXT
            dw t_rogue1
            dw 540
            db EV_TEXT
            dw t_rogue2
            dw 660
            db EV_CLRB
            dw 0
            dw 662
            db EV_CLRT
            dw 0
            dw 665
            db EV_PROBE
            dw 0
            dw 700
            db EV_TEXT
            dw t_probe
            dw 800
            db EV_FLASH
            dw 0
            dw 812
            db EV_END
            dw 0
            dw $FFFF

; text: row, then the string
t_belt:     db 3,"2391. THE OUTER BELT.",0
t_dark1:    db 48,"THE KESTREL FREIGHTERS",0
t_dark2:    db 55,"HAVE GONE DARK.",0
t_rogue1:   db 48,"A ROGUE MIND RULES",0
t_rogue2:   db 55,"EVERY DROID ABOARD.",0
t_probe:    db 55,"ONE PROBE. ONE CHANCE.",0

intro:
            ld a,$08
            call fe_setlatch
            ld hl,song_intro
            call m_playhl
            ld a,$AA
            call fe_cls
            ; stars in the two bands clear of the text and the ship
            ld hl,stars
            ld b,NSTAR
.si:        call random
            and 127
            ld (hl),a
            inc hl
            call random
            and 15
            cp 10
            jr c,.up
            add a,39-10             ; rows 39-44
            jr .sy
.up:        add a,11                ; rows 11-20
.sy:        ld (hl),a
            inc hl
            call random
            and 1
            inc a
            ld (hl),a
            inc hl
            djnz .si
            ld hl,0
            ld (at_t),hl
            ld hl,script
            ld (at_ev),hl
            xor a
            ld (at_tp+1),a
            ld (at_ship),a
            ld (at_alert),a
            ld (at_probe),a
            ld (at_end),a
            ld a,128
            ld (at_sx),a
.f:         call fe_frame
            call read_input
            ld a,(in_new)
            and K_FIRE|K_ANY
            jr nz,.skip
            call at_events
            ld a,(fe_frames)
            and 1
            call z,at_stars
            call at_type
            call at_shipmove
            call at_alertf
            call at_probef
            ld hl,(at_t)
            inc hl
            ld (at_t),hl
            ld a,(at_end)
            or a
            jr z,.f
.skip:      ld a,$08
            call fe_setlatch
            call m_stop
            xor a
            ret

; run the events that are due
at_events:
            ld hl,(at_ev)
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld hl,(at_t)
            or a
            sbc hl,de
            ret c                   ; not yet
            ld hl,(at_ev)
            inc hl
            inc hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (at_ev),hl
            cp EV_TEXT
            jr z,.text
            cp EV_CLRB
            jr z,.clrb
            cp EV_CLRT
            jr z,.clrt
            cp EV_SHIP
            jr z,.ship
            cp EV_ALERT
            jr z,.alert
            cp EV_PROBE
            jr z,.probe
            cp EV_FLASH
            jr z,.flash
            ld a,1                  ; EV_END
            ld (at_end),a
            ret
.text:      ld a,(de)
            ld (at_row),a
            inc de
            ld (at_tp),de
            ; centre it
            ex de,hl
            ld b,0
.ln:        ld a,(hl)
            or a
            jr z,.lc
            inc b
            inc hl
            jr .ln
.lc:        ld a,32
            sub b
            srl a
            ld (at_col),a
            jr at_events
.clrb:      ld a,46
            ld b,18
            jr .clr
.clrt:      xor a
            ld b,10
.clr:       ld c,$AA
            call fe_rows
            jr at_events
.ship:      ld a,1
            ld (at_ship),a
            jr at_events
.alert:     ld a,64
            ld (at_alert),a
            jr at_events
.probe:     ld a,1
            ld (at_probe),a
            xor a
            ld (at_px),a
            ld a,58
            ld (at_py),a
            jp at_events
.flash:     xor a
            ld b,64
            ld c,$55
            call fe_rows
            ld a,FX_ZAP
            call fe_sfx
            jp at_events

; typewriter: a character every other field
at_type:
            ld hl,(at_tp)
            ld a,h
            or a
            ret z
            ld a,(fe_frames)
            and 1
            ret nz
            ld a,(hl)
            or a
            jr z,.done
            inc hl
            ld (at_tp),hl
            push af
            ld de,$0102
            call txt_colour
            call fe_txt
            pop af
            push af
            ld a,(at_col)
            ld d,a
            inc a
            ld (at_col),a
            ld a,(at_row)
            ld e,a
            pop af
            push de
            push af
            call draw_char
            pop af
            pop de
            cp ' '
            jr z,.m
            push de
            ld a,FX_TYPE
            call fe_sfx
            pop de
.m:         ld a,e
            ld b,5
            jp fe_mark
.done:      xor a
            ld (at_tp+1),a
            ret

; stars drift left (erase, move, draw)
at_stars:
            ld hl,stars
            ld b,NSTAR
.s:         push bc
            push hl
            ld b,(hl)
            inc hl
            ld c,(hl)
            push hl
            push bc
            ld a,2
            call fe_px              ; old spot back to blue
            pop bc
            pop hl
            inc hl
            ld a,b
            sub (hl)                ; speed
            and 127
            ld b,a
            pop hl
            ld (hl),a
            push hl
            ld a,(hl)
            and 3
            ld a,1                  ; mostly yellow, some green
            jr nz,.c
            xor a
.c:         call fe_px
            pop hl
            inc hl
            inc hl
            inc hl
            pop bc
            djnz .s
            ret

; the freighter glides in: a pixel every 4 fields to x = 44
at_shipmove:
            ld a,(at_ship)
            or a
            ret z
            ld a,(fe_frames)
            and 3
            ret nz
            ld a,(at_sx)
            cp 44
            jr z,at_shipdraw
            dec a
            ld (at_sx),a
at_shipdraw:
            ld a,(at_sx)
            cp 128
            ret nc
            ld c,a
            ; source = art + phase * 168
            and 3
            ld l,a
            ld h,0
            ld de,168
            call mul16x8_de         ; HL = phase*168
            ld de,ship_art
            add hl,de
            ld (at_src),hl
            ; bytes to draw: min(12, 32 - col)
            ld a,c
            srl a
            srl a
            ld (at_scol),a
            ld b,a
            ld a,32
            sub b
            cp 13
            jr c,.w
            ld a,12
.w:         ld (at_sw),a
            ld a,SHIP_Y
            ld (at_sr),a
            ld b,14
.r:         push bc
            ld a,(at_sr)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(at_scol)
            add a,l
            ld l,a
            ld de,FEBB
            add hl,de
            ex de,hl
            ld hl,(at_src)
            push hl
            ld a,(at_sw)
            ld c,a
            ld b,0
            ldir
            pop hl
            ld bc,12
            add hl,bc
            ld (at_src),hl
            ld hl,at_sr
            inc (hl)
            pop bc
            djnz .r
            ld a,SHIP_Y
            ld b,14
            jp fe_mark

; HL = L * DE (L small)
mul16x8_de:
            ld a,l
            ld hl,0
            or a
            ret z
.l:         add hl,de
            dec a
            jr nz,.l
            ret

; red alert: the palette flips between the colour sets, with a siren
at_alertf:
            ld a,(at_alert)
            or a
            ret z
            dec a
            ld (at_alert),a
            ld b,a
            and 15
            jr nz,.n
            ld a,FX_ALARM
            call fe_sfx
.n:         ld a,b
            and 4
            ld a,$08
            jr z,.s
            ld a,$18
.s:         jp fe_setlatch

; the probe streaks from the bottom left to the freighter's hull
at_probef:
            ld a,(at_probe)
            or a
            ret z
            ld a,(fe_frames)
            and 1
            ret nz
            ; erase the old dot
            ld a,(at_px)
            ld b,a
            ld a,(at_py)
            ld c,a
            ld a,2
            push bc
            call fe_px
            pop bc
            inc b
            ld a,2
            call fe_px
            ld a,(at_px)
            cp 56
            jr nc,.hit
            inc a
            ld (at_px),a
            ; y = 58 - x*7/16
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,hl
            or a
            sbc hl,de               ; x*7
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a,58
            sub l
            ld (at_py),a
            ld c,a
            ld a,(at_px)
            ld b,a
            ld a,1
            push bc
            call fe_px
            pop bc
            inc b
            ld a,1
            jp fe_px
.hit:       xor a
            ld (at_probe),a
            ld a,FX_ZAP
            call fe_sfx
            jp at_shipdraw          ; mend the hull where the dot was

            include "gen/att.inc"

; ---- variables
at_t:       ds 2
at_ev:      ds 2
at_tp:      ds 2
at_row:     ds 1
at_col:     ds 1
at_ship:    ds 1
at_sx:      ds 1
at_alert:   ds 1
at_probe:   ds 1
at_px:      ds 1
at_py:      ds 1
at_end:     ds 1
at_src:     ds 2
at_scol:    ds 1
at_sw:      ds 1
at_sr:      ds 1
stars:      ds NSTAR*3
att_end:
            assert att_end <= $6000
