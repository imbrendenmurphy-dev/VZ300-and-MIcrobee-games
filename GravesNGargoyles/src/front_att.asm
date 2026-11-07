; attract sequence + bestiary (runs from SRAM, see BLOB2)
; ---------------------------------------------------------------- attract
; returns A = 0 if the player pressed fire (go to menu), 1 when complete
attract:
        call ensure_front
        ld a,2
        ld (arm_cur),a
        call build_hero
        ld hl,STORY1
        call story_page
        jr nz,.pressed
        call bestiary
        jr nz,.pressed
        call demo_game
        jr nz,.pressed
        call hiscore_card
        ld a,1
        ret
.pressed:
        xor a
        ret

; enemy gallery
bestiary:
        ld hl,BEAST
        ld (bs_p),hl
.next:  ld hl,(bs_p)
        ld a,(hl)
        inc hl
        or (hl)
        jr z,.done
        xor a
        ld (t_t),a
.lp:    call cls_card
        ld hl,STR_BEAST
        ld c,4
        ld a,(col_yel)
        call text_fbc
        ld hl,(bs_p)
        ld e,(hl)
        inc hl
        ld d,(hl)               ; sprite frame 0
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; frame 1
        inc hl
        push hl
        ld a,(t_t)
        and 8
        jr z,.f0
        ld e,c
        ld d,b
.f0:    ex de,hl
        ld bc,58
        ld a,14
        ld e,0
        call draw_spr
        pop hl
        push hl
        ld c,38
        ld a,(col_grn)
        call text_fbc
        pop hl
.sk:    ld a,(hl)
        inc hl
        or a
        jr nz,.sk
        push hl
        ld c,46
        ld a,(col_yel)
        call text_fbc
        call show_full
        call read_input
        pop hl
        ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_SWAP)
        ret nz
        ld a,(t_t)
        inc a
        ld (t_t),a
        cp 60
        jr c,.lp
        ; advance past the second string
.sk2:   ld a,(hl)
        inc hl
        or a
        jr nz,.sk2
        ld (bs_p),hl
        jr .next
.done:  xor a
        ret

