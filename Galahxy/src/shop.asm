; =====================================================================
;  shop.asm - the Fantasy-Zone-style shop (main RAM)
; =====================================================================
; ---------------------------------------------------------------------
; THE SHOP: touch the SHOP balloon and spend your coins
; ---------------------------------------------------------------------
SHOP_N      equ 8
shop:
            ld a,(demo_on)          ; (the demo pilot just waves)
            or a
            ret nz
            push ix
            push iy
            call silence
            ld hl,tune_select
            call music
            ld hl,str_shopbar
            call bar_msg
            xor a
            ld (fe_sel),a
            ld a,SFX_SECRET
            call sfx
.loop:      call read_input
            call sound_tick
            ld a,(in_new)
            bit 0,a
            jr z,.nu
            ld hl,fe_sel
            ld a,(hl)
            or a
            jr z,.nu
            dec (hl)
            ld a,SFX_MENU
            call sfx
.nu:        ld a,(in_new)
            bit 1,a
            jr z,.nd
            ld hl,fe_sel
            ld a,(hl)
            cp SHOP_N-1
            jr nc,.nd
            inc (hl)
            ld a,SFX_MENU
            call sfx
.nd:        ld a,(in_new)
            and K_ARM
            jp nz,.out
            ld a,(in_new)
            and K_FIRE
            call nz,.buy
            ld a,(fe_sel)
            cp $80                  ; (EXIT bought)
            jp z,.out
            ; ---- draw
            ld a,$AA
            call cls_bb
            ld a,6
            ld b,8
            ld c,$FF
            call band_bb
            ld a,0
            ld c,3
            call text_col
            ld hl,str_shop
            ld de,7*32+1
            call bbde
            call print
            ld a,(wallet)
            ld de,7*32+28
            call bbde
            call print_dec2
            ; the items
            ld b,0
.it:        push bc
            ld a,b
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl               ; *4
            ld de,shop_items
            add hl,de
            push hl
            ; colour: chosen orange (blinks), can't afford cyan, else buff
            ld a,(fe_sel)
            cp b
            ld a,3
            jr z,.ci
            inc hl
            inc hl
            ld a,(wallet)
            cp (hl)
            ld a,0
            jr nc,.ci
            ld a,1
.ci:        ld c,2
            call text_col
            pop hl
            pop bc
            push bc
            push hl
            ld a,b
            ld l,a
            add a,a
            add a,a
            add a,l                 ; 5 rows a line
            add a,16
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,3
            add hl,de
            ex de,hl
            call bbde
            pop hl
            push hl
            push de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            call print
            pop de
            pop hl
            inc hl
            inc hl
            ld a,(hl)
            or a
            jr z,.np
            ld hl,23
            add hl,de
            ex de,hl
            call print_dec2
.np:        pop bc
            ld a,(fe_sel)
            cp b
            jr nz,.na
            push bc
            ld a,b
            ld l,a
            add a,a
            add a,a
            add a,l
            add a,16
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,1
            add hl,de
            ex de,hl
            call bbde
            ld a,'>'
            call putc
            pop bc
.na:        inc b
            ld a,b
            cp SHOP_N
            jp nz,.it
            call present
            jp .loop
.out:       ld a,1
            ld (bar_dirty),a
            ld (hud_dirty),a
            ld a,60
            ld (p_inv),a
            xor a
            ld (in_new),a
            call silence
            ld hl,(stage_tune)
            call music
            pop iy
            pop ix
            ret
; fire on the chosen item
.buy:       ld a,(fe_sel)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            ld de,shop_items+2
            add hl,de
            ld a,(hl)               ; price
            ld c,a
            inc hl
            ld a,(hl)               ; what it is
            or a
            jr nz,.b1
            ld a,$80                ; EXIT
            ld (fe_sel),a
            ret
.b1:        ld b,a
            ld a,(wallet)
            cp c
            jr c,.no
            ld a,b
            cp 6
            jr nc,.special
            push bc
            call pw_full
            pop bc
            jr z,.no
            ld a,b
            call apply_power
            jr .paid
.special:   cp 6
            jr nz,.life
            ld a,(p_health)
            cp 3
            jr nc,.no
            ld a,3
            ld (p_health),a
            ld a,SFX_HEAL
            call sfx
            jr .paid
.life:      ld hl,p_lives
            ld a,(hl)
            cp 9
            jr nc,.no
            inc (hl)
            ld a,SFX_LIFE
            call sfx
.paid:      ld hl,wallet
            ld a,(hl)
            sub c
            ld (hl),a
            ld a,1
            ld (hud_dirty),a
            ret
.no:        ld a,SFX_KNOCK
            jp sfx

shop_items: ; name, price, what (1-5 power slot, 6 heart, 7 life, 0 exit)
            dw si_speed : db 5, 1
            dw si_bomb  : db 6, 2
            dw si_shot  : db 10, 3
            dw si_buddy : db 10, 4
            dw si_shield : db 8, 5
            dw si_heart : db 6, 6
            dw si_life  : db 30, 7
            dw si_exit  : db 0, 0
