; title-screen bats (front pack only)
title_bats:
        ld hl,(bat1_x)
        inc hl
        inc hl
        ld (bat1_x),hl
        ld de,200
        or a
        sbc hl,de
        jr c,.b1
        ld hl,-40
        ld (bat1_x),hl
.b1:    ld hl,(bat2_x)
        dec hl
        dec hl
        ld (bat2_x),hl
        ld a,h
        cp $FF
        jr nz,.b2
        ld a,l
        cp -60
        jr nc,.b2
        ld hl,190
        ld (bat2_x),hl
.b2:    ld hl,F_TBAT_0
        ld a,(t_t)
        and 4
        jr z,$+5
        ld hl,F_TBAT_1
        push hl
        ld bc,(bat1_x)
        ld a,(t_t)
        and 15
        cp 8
        jr c,$+4
        neg
        add a,24
        sra a
        add a,16
        ld e,0
        call draw_spr
        pop hl
        ld bc,(bat2_x)
        ld a,(t_t)
        rrca
        and 7
        add a,30
        ld e,1
        jp draw_spr

