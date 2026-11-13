; =====================================================================
;  player.asm - the cast, movement, weapons, buddies, power bar
; =====================================================================
; per character: sprite, shot sound, rates
CH_GAZZA    equ 0
CH_CUPPA    equ 1
CH_TOASTIE  equ 2
char_spr:   db SPR_GAZZA, SPR_CUPPA, SPR_TOASTIE
char_rate:  db 4, 3, 7                  ; frames between shots
char_sfx:   db SFX_SHOT, SFX_BEAM, SFX_TOAST
; speed per level: 8.8 px per frame (x), y is 2/3 of it (tall pixels)
spd_x:      dw $0100, $0160, $01C0, $0220
spd_y:      dw $00B0, $00F0, $0130, $0170
PX_MIN      equ 0+XOFF
PX_MAX      equ 118+XOFF
PY_MIN      equ PF_TOP+YOFF
PY_MAX      equ PF_BOT-7+YOFF

player_reset:                           ; new life / new game position
            ld a,10+XOFF
            ld (p_x),a
            ld a,28+YOFF
            ld (p_y),a
            xor a
            ld (p_xf),a
            ld (p_yf),a
            ld (p_dead),a
            ld (p_cool),a
            ld (p_bcool),a
            ld a,3
            ld (p_health),a
            ld a,75
            ld (p_inv),a
            ; fill the buddy trail with the start position
            ld hl,p_hist
            ld b,32
.h:         ld a,(p_x)
            ld (hl),a
            inc hl
            ld a,(p_y)
            ld (hl),a
            inc hl
            djnz .h
            xor a
            ld (p_hpos),a
            ld a,1
            ld (hud_dirty),a
            ret

; ---------------------------------------------------------------------
player_update:
            ld a,(p_dead)
            or a
            jr z,.alive
            dec a
            ld (p_dead),a
            ret nz
            ld a,(p_lives)
            or a
            jp z,game_over_now
            jp player_reset
.alive:     ld a,(p_inv)
            or a
            jr z,.ni
            dec a
            ld (p_inv),a
.ni:        ld a,(stg_phase)
            cp 3
            jp nc,.auto             ; stage clear: fly off to the right
            ; ---- movement
            ld a,(p_speed)
            add a,a
            ld e,a
            ld d,0
            ld hl,spd_x
            add hl,de
            ld c,(hl)
            inc hl
            ld b,(hl)               ; BC = x speed
            ld hl,spd_y
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)               ; DE = y speed
            push de
            ld a,(in_now)
            ld e,a
            xor a
            ld (p_tilt),a
            bit 2,e
            jr z,.nl
            ld hl,(p_xf)
            or a
            sbc hl,bc
            ld a,h
            cp PX_MIN
            jr nc,.l1
            ld h,PX_MIN
            ld l,0
.l1:        ld (p_xf),hl
.nl:        bit 3,e
            jr z,.nr
            ld hl,(p_xf)
            add hl,bc
            ld a,h
            cp PX_MAX
            jr c,.r1
            ld h,PX_MAX
            ld l,0
.r1:        ld (p_xf),hl
.nr:        pop bc
            bit 0,e
            jr z,.nu
            ld hl,(p_yf)
            or a
            sbc hl,bc
            ld a,h
            cp PY_MIN
            jr nc,.u1
            ld h,PY_MIN
            ld l,0
.u1:        ld (p_yf),hl
            ld a,1
            ld (p_tilt),a
.nu:        bit 1,e
            jr z,.nd
            ld hl,(p_yf)
            add hl,bc
            ld a,h
            cp PY_MAX
            jr c,.d1
            ld h,PY_MAX
            ld l,0
.d1:        ld (p_yf),hl
            ld a,2
            ld (p_tilt),a
.nd:        ; ---- history for buddies
            ld a,(p_hpos)
            add a,2
            and 63
            ld (p_hpos),a
            ld e,a
            ld d,0
            ld hl,p_hist
            add hl,de
            ld a,(p_x)
            ld (hl),a
            inc hl
            ld a,(p_y)
            ld (hl),a
            ; ---- buy
            ld a,(in_new)
            and K_ARM
            call nz,buy_power
            ; ---- fire
            ld a,(p_cool)
            or a
            jr z,.cf
            dec a
            ld (p_cool),a
.cf:        ld a,(p_bcool)
            or a
            jr z,.cb
            dec a
            ld (p_bcool),a
.cb:        ld a,(in_now)
            and K_FIRE
            ret z
            ld a,(p_cool)
            or a
            jr nz,.bomb
            ld a,(p_char)
            ld e,a
            ld d,0
            ld hl,char_rate
            add hl,de
            ld a,(hl)
            ld (p_cool),a
            ld hl,char_sfx
            add hl,de
            ld a,(hl)
            call sfx
            ld a,(p_x)
            ld b,a
            ld a,(p_y)
            ld c,a
            call fire_main
            ; buddies copy the main shot
            ld a,(p_buddy)
            or a
            jr z,.bomb
            ld a,16
            call buddy_pos
            call fire_main
            ld a,(p_buddy)
            cp 2
            jr c,.bomb
            ld a,32
            call buddy_pos
            call fire_main
.bomb:      ld a,(p_bomb)
            or a
            ret z
            ld a,(p_bcool)
            or a
            ret nz
            ld a,22
            ld (p_bcool),a
            ld a,SFX_BOMB
            call sfx
            ld a,(p_x)
            ld b,a
            ld a,(p_y)
            ld c,a
            jp fire_bomb
.auto:      ; stage clear: drift right and off
            ld a,(p_x)
            cp 200
            ret nc
            inc a
            inc a
            ld (p_x),a
            ret

; A = trail offset (bytes back) -> B,C = buddy position
buddy_pos:
            ld b,a
            ld a,(p_hpos)
            sub b
            and 63
            ld e,a
            ld d,0
            ld hl,p_hist
            add hl,de
            ld b,(hl)
            inc hl
            ld c,(hl)
            ret

; ---------------------------------------------------------------------
; weapons: B,C = shooter position (top-left of an 8x6 sprite)
; ---------------------------------------------------------------------
; P_T kinds
PK_SEED     equ 1
PK_BEAM     equ 2
PK_TOAST    equ 3
PK_NUT      equ 4
PK_TEABAG   equ 5
PK_VEG      equ 6
PK_SPR:     db 0, SPR_SEED, SPR_BEAM, SPR_TOAST, SPR_NUT, SPR_TEABAG, SPR_VEGEMITE
PK_DMG:     db 0, 1, 1, 3, 2, 2, 2
PK_W:       db 0, 2, 8, 3, 2, 3, 3
PK_H:       db 0, 1, 1, 3, 2, 3, 3
PK_PIERCE:  db 0, 0, 1, 0, 0, 0, 0

fire_main:
            ld a,(p_char)
            or a
            jr z,.gazza
            dec a
            jr z,.cuppa
            ; TOASTIE: toast forward; L1 also backward; L2 double forward
            ld a,b
            add a,6
            ld b,a
            inc c
            ld de,$0040             ; vx 4 px, vy 0  (in 1/16 px)
            ld a,PK_TOAST
            call new_pshot
            ld a,(p_shot)
            or a
            ret z
            push bc
            ld a,b
            sub 8
            ld b,a
            ld de,$00D0             ; backwards
            ld a,PK_TOAST
            call new_pshot
            pop bc
            ld a,(p_shot)
            cp 2
            ret c
            ld a,c
            add a,3
            ld c,a
            ld de,$0040
            ld a,PK_TOAST
            jp new_pshot
.gazza:     ; GAZZA: twin seeds; L1 3-way; L2 5-way
            ld a,b
            add a,7
            ld b,a
            inc c
            ld de,$0060             ; 6 px/frame
            ld a,PK_SEED
            call new_pshot
            ld a,c
            add a,3
            ld c,a
            ld de,$0060
            ld a,PK_SEED
            call new_pshot
            dec c
            ld a,(p_shot)
            or a
            ret z
            ld de,$F458             ; up-forward
            ld a,PK_SEED
            call new_pshot
            ld de,$0C58             ; down-forward
            ld a,PK_SEED
            call new_pshot
            ld a,(p_shot)
            cp 2
            ret c
            ld de,$E84C
            ld a,PK_SEED
            call new_pshot
            ld de,$184C
            ld a,PK_SEED
            jp new_pshot
.cuppa:     ; CUPPA: piercing steam beam; L1 two beams; L2 three
            ld a,b
            add a,8
            ld b,a
            inc c
            inc c
            ld de,$007C             ; 7.75 px/frame
            ld a,PK_BEAM
            call new_pshot
            ld a,(p_shot)
            or a
            ret z
            dec c
            dec c
            ld de,$007C
            ld a,PK_BEAM
            call new_pshot
            ld a,(p_shot)
            cp 2
            ret c
            ld a,c
            add a,4
            ld c,a
            ld de,$007C
            ld a,PK_BEAM
            jp new_pshot

fire_bomb:
            ld a,(p_char)
            or a
            jr z,.nut
            dec a
            jr z,.tea
            ; TOASTIE: Vegemite seekers (home on the nearest enemy)
            ld a,b
            add a,4
            ld b,a
            ld de,$0030
            ld a,PK_VEG
            jp new_pshot
.nut:       ; GAZZA: macadamia nut drops forward and falls (hits ground things)
            ld a,b
            add a,4
            ld b,a
            ld a,c
            add a,4
            ld c,a
            ld de,$0028
            ld a,PK_NUT
            jp new_pshot
.tea:       ; CUPPA: tea bags up and down at 45 degrees
            ld a,b
            add a,4
            ld b,a
            ld de,$E030
            ld a,PK_TEABAG
            call new_pshot
            ld de,$2030
            ld a,PK_TEABAG
            jp new_pshot

; A = kind, B = x, C = y, D = vy, E = vx (1/16 px per frame, signed)
new_pshot:
            push bc
            push af
            ld hl,pshots
            ld b,NPS
.f:         ld a,(hl)
            or a
            jr z,.got
            ld a,l
            add a,PSZ
            ld l,a
            jr nc,.n
            inc h
.n:         djnz .f
            pop af
            pop bc
            ret
.got:       pop af
            pop bc
            ld (hl),a               ; P_T
            inc hl
            ld (hl),b               ; P_X
            inc hl
            ld (hl),0
            inc hl
            ld (hl),c               ; P_Y
            inc hl
            ld (hl),0
            inc hl
            ld (hl),e               ; P_VX
            inc hl
            ld (hl),d               ; P_VY
            inc hl
            ld (hl),40              ; P_A: life in frames
            ret

; ---------------------------------------------------------------------
; move player shots
; ---------------------------------------------------------------------
pshots_update:
            ld ix,pshots
            ld b,NPS
.l:         ld a,(ix+P_T)
            or a
            jp z,.next
            dec (ix+P_A)
            jp z,.kill
            cp PK_NUT
            jr nz,.nn
            ld a,(ix+P_VY)          ; nut: gravity
            add a,2
            cp $30
            jr nc,.nn0
            ld (ix+P_VY),a
.nn0:       jr .mv
.nn:        cp PK_VEG
            jr nz,.mv
            push bc
            call veg_steer
            pop bc
.mv:        ; x += vx/16
            ld a,(ix+P_VX)
            call sx16
            ld a,(ix+P_XF)
            add a,l
            ld (ix+P_XF),a
            ld a,(ix+P_X)
            adc a,h
            ld (ix+P_X),a
            ld c,a
            ld a,(ix+P_VX)
            bit 7,a
            jr nz,.left
            ld a,c
            cp 128+XOFF+4
            jr nc,.kill
            jr .y
.left:      ld a,c
            cp XOFF-12
            jr c,.kill
.y:         ld a,(ix+P_VY)
            call sx16
            ld a,(ix+P_YF)
            add a,l
            ld (ix+P_YF),a
            ld a,(ix+P_Y)
            adc a,h
            ld (ix+P_Y),a
            cp PF_TOP+YOFF-3
            jr c,.kill
            cp PF_BOT+YOFF+1
            jr nc,.kill
            jr .next
.kill:      ld (ix+P_T),0
.next:      ld de,PSZ
            add ix,de
            dec b
            jp nz,.l
            ret

; A = signed 1/16 units -> HL = 8.8 value (A*16)
sx16:
            ld l,a
            rlca
            sbc a,a
            ld h,a                  ; sign extend
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ret

; Vegemite seeker: turn vy towards the nearest live enemy
veg_steer:
            ld hl,objs
            ld b,NOBJ
            ld c,$FF                ; best distance
            ld d,0                  ; target y
.f:         ld a,(hl)
            or a
            jr z,.n
            push hl
            pop iy
            ld a,(iy+O_FL)
            and (1<<F_FX)|(1<<F_PICK)
            jr nz,.n
            ld a,(iy+O_X)
            sub (ix+P_X)
            jr c,.n                 ; only ahead
            cp c
            jr nc,.n
            ld c,a
            ld a,(iy+O_Y)
            add a,2
            ld d,a
.n:         ld a,l
            add a,OSZ
            ld l,a
            jr nc,.nc
            inc h
.nc:        djnz .f
            ld a,c
            inc a
            ret z                   ; nothing to chase
            ld a,d
            sub (ix+P_Y)
            jr z,.st
            ld a,(ix+P_VY)
            jr c,.up
            cp $10
            jr z,.st
            inc a
            inc a
            ld (ix+P_VY),a
            ret
.up:        cp $F0
            jr z,.st
            dec a
            dec a
            ld (ix+P_VY),a
            ret
.st:        ld a,(ix+P_VY)
            or a
            ret z
            bit 7,a
            jr z,.dn
            inc a
            ld (ix+P_VY),a
            ret
.dn:        dec a
            ld (ix+P_VY),a
            ret

draw_pshots:
            ld ix,pshots
            ld b,NPS
.l:         ld a,(ix+P_T)
            or a
            jr z,.n
            push bc
            ld e,a
            ld d,0
            ld hl,PK_SPR
            add hl,de
            ld a,(hl)
            ld b,(ix+P_X)
            ld c,(ix+P_Y)
            call blit
            pop bc
.n:         ld de,PSZ
            add ix,de
            djnz .l
            ret

; ---------------------------------------------------------------------
draw_player:
            ld a,(p_dead)
            or a
            ret nz
            ; buddies
            ld a,(p_buddy)
            or a
            jr z,.nb
            ld a,16
            call buddy_pos
            call .chick
            ld a,(p_buddy)
            cp 2
            jr c,.nb
            ld a,32
            call buddy_pos
            call .chick
.nb:        ld a,(p_inv)            ; flicker while invulnerable
            and 2
            jr nz,.sh
            ld a,(p_char)
            ld e,a
            ld d,0
            ld hl,char_spr
            add hl,de
            ld a,(frames)
            rrca
            rrca
            and 1
            add a,(hl)
            ld b,a
            ld a,(p_y)
            ld c,a
            ld a,(p_x)
            ld e,b
            ld b,a
            ld a,e
            call blit
.sh:        ld a,(p_shield)
            or a
            ret z
            ld a,(p_x)
            dec a
            ld b,a
            ld a,(p_y)
            ld c,a
            dec c
            ld a,(frames)
            and 1
            ret z                   ; the shield shimmers (every other frame)
            ld a,SPR_SHIELD
            jp blit
.chick:     ld a,b
            add a,2
            ld b,a
            inc c
            ld a,(frames)
            rrca
            rrca
            and 1
            add a,SPR_CHICK
            jp blit

; ---------------------------------------------------------------------
; the power bar: PAV capsules move the cursor, ARM buys
;   1 SPEED (3)  2 BOMB (1)  3 SHOT (2)  4 BUDDY (2)  5 SHIELD (refill)
; ---------------------------------------------------------------------
pw_max:     db 0, 3, 1, 2, 2, 9

; is slot A maxed? -> Z = maxed
pw_full:
            cp 5
            jr z,.no
            ld e,a
            ld d,0
            ld hl,p_speed-1
            add hl,de
            ld b,(hl)
            ld hl,pw_max
            add hl,de
            ld a,(hl)
            cp b
            ret
.no:        or a                    ; NZ
            ret

collect_pav:
            ld a,SFX_PAV
            call sfx
            ld a,6
            ld (work),a
            ld a,(p_cursor)
.adv:       inc a
            cp 6
            jr c,.ok
            ld a,1
.ok:        ld hl,work
            dec (hl)
            jr z,.set
            ld (work+1),a
            call pw_full
            ld a,(work+1)
            jr z,.adv               ; skip slots already maxed
.set:       ld (p_cursor),a
            ld a,1
            ld (bar_dirty),a
            ret

buy_power:
            ld a,(p_cursor)
            or a
            ret z
            push af
            call pw_full
            pop bc
            ret z
            ld a,b
            call apply_power
            xor a
            ld (p_cursor),a
            ret
; A = slot (1 speed 2 bomb 3 shot 4 buddy 5 shield): power it up
apply_power:
            cp 1
            jr nz,.b2
            ld hl,p_speed
            inc (hl)
            jr .done
.b2:        cp 2
            jr nz,.b3
            ld a,1
            ld (p_bomb),a
            jr .done
.b3:        cp 3
            jr nz,.b4
            ld hl,p_shot
            inc (hl)
            jr .done
.b4:        cp 4
            jr nz,.b5
            ld hl,p_buddy
            inc (hl)
            jr .done
.b5:        ld a,3
            ld (p_shield),a
.done:      ld a,1
            ld (bar_dirty),a
            ld a,SFX_BUY
            jp sfx

; draw the power bar straight into video RAM (rows 56-63) when it changes
BARV        equ VRAM+BAR_ROW*32
BART        equ VRAM+(BAR_ROW+2)*32
str_bar:    db " SPEED BOMB SHOT BUDDY SHIELD   ",0
bar_cols:   db 1, 7, 12, 17, 23, 30     ; slot start columns (end sentinel)
build_bar:
            xor a
            ld (bar_dirty),a
            ld hl,BARV              ; paper red, ink yellow
            ld de,BARV+1
            ld bc,255
            ld (hl),$FF
            ldir
            ld a,1
            ld c,3
            call text_col
            ld hl,str_bar
            ld de,BART
            call print
            ; maxed slots: dim (ink green); highlighted slot: a yellow box
            ld b,1
.s:         push bc
            ld a,b
            call pw_full
            pop bc
            push bc
            jr nz,.nf
            ld a,2
            ld c,3
            call .slot
.nf:        pop bc
            push bc
            ld a,(p_cursor)
            cp b
            jr nz,.nc
            ld a,2
            ld c,0
            call .slot
.nc:        pop bc
            inc b
            ld a,b
            cp 6
            jr nz,.s
            ret
; redraw slot B (with a space either side) in ink A on a box of paper C
.slot:      push bc
            push af
            ld a,c
            ld b,a
            add a,a
            add a,a
            or b
            ld b,a
            add a,a
            add a,a
            add a,a
            add a,a
            or b
            ld (.pap+1),a           ; paper colour in all four pixels
            pop af
            pop bc
            push bc
            call text_col
            pop bc
            ld e,b
            ld d,0
            ld hl,bar_cols-1
            add hl,de
            ld a,(hl)
            dec a
            ld e,a                  ; first column (the space before)
            inc hl
            ld a,(hl)
            sub e
            ld b,a                  ; characters to draw
            ld d,0
            push bc
            push de
            ld hl,BARV              ; the box
            add hl,de
            ld c,8
.bx:        push bc
            push hl
.pap:       ld a,0
.bl:        ld (hl),a
            inc hl
            djnz .bl
            pop hl
            ld bc,32
            add hl,bc
            pop bc
            dec c
            jr nz,.bx
            pop de
            pop bc
            ld hl,BART
            add hl,de
            push hl
            ld hl,str_bar
            add hl,de
            pop de
.sc:        push bc
            ld a,(hl)
            inc hl
            push hl
            call putc
            pop hl
            inc de
            pop bc
            djnz .sc
            ret

draw_bar:
            ld a,(bar_dirty)
            or a
            ret z
            jp build_bar
