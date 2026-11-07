; ============================================================================
;  HEALTH: every armour level (and the bare knight) takes HP_MAX hits before
;  it breaks.  Resident.
; ============================================================================
HP_MAX  equ 5

; a hit landed: NZ = just a bruise, Z = the hits ran out (bar refilled)
hp_take:
        ld hl,hero_hp
        dec (hl)
        jr z,.out
        ld a,(hl)
        cp HP_MAX
        jr nc,.out
        ld a,1
        ld (hud_need),a
        ld a,SFX_HIT_ID
        call play_sfx
        or 1
        ret
.out:   ld (hl),HP_MAX
        xor a
        ret

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

