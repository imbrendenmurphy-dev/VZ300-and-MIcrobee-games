; health bar drawing + armour refill (runs from SRAM, BLOB2)
; full armour and a full bar
arm_full:
        ld a,(arm_max)
; A = armour level: wear it with a full bar
set_arm:
        ld (arm_cur),a
        push af
        ld a,HP_MAX
        ld (hero_hp),a
        ld a,1
        ld (hud_need),a
        pop af
        ret


; the bar: HP_MAX segments at the right of the HUD
hp_hud:
        ld a,(col_hud)
        and 3
        ld d,a
        ld a,(col_red)
        and $FC
        or d
        ld c,a                  ; full segment
        ld a,(col_grn)
        and $FC
        or d
        ld d,a                  ; empty segment
        ld hl,HUDBUF+2*32+27
        ld b,4
.r:     push bc
        ld a,(hero_hp)
        ld e,a
        ld b,HP_MAX
.c:     ld a,e
        or a
        ld a,d
        jr z,.e
        dec e
        ld a,c
.e:     ld (hl),a
        inc hl
        djnz .c
        ld a,l
        add a,32-HP_MAX
        ld l,a
        jr nc,$+3
        inc h
        pop bc
        djnz .r
        ret
