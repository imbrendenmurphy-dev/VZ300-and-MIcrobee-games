; hit counting (runs from SRAM, BLOB1)
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

