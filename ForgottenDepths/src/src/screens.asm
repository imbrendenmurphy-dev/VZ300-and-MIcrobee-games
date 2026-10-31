; =====================================================================
;  screens.asm : title + attract pages, automap (mode 1), inventory, ending
; =====================================================================

; unpack a ZX0 page HL -> VRAM (bank 1 must be mapped)
show_page:
        ld de,VRAM
        jp dzx0

; ---------------------------------------------------------------------
; title: returns when the player starts a new game
; ---------------------------------------------------------------------
t_scroll:  dw SCROLLTXT
t_sub:     db 0
t_idle:    dw 0
t_page:    db 0
t_mode:    db 1             ; 1 new game, 2 password

title:
        ld a,M0O
        ld (lbase),a
        ld (LATCH),a
        ld a,TR_TITLE
        call music_play
.show:  ld hl,TITLE_Z
        call show_page
        ld hl,0
        ld (t_idle),hl
.loop:  call wait_frame
        call title_anim
        call sound_tick
        call read_input
        call title_keys
        ret c                   ; start game
        jr nz,.show             ; returned from a page
        ld hl,(t_idle)
        inc hl
        ld (t_idle),hl
        ld de,750               ; 15 s -> attract page
        or a
        sbc hl,de
        jr c,.loop
        ; attract: cycle story / help / credits
        ld a,(t_page)
        inc a
        cp 4
        jr c,.p
        xor a
.p:     ld (t_page),a
        cp 1
        jr nz,.nd
        call demo_run           ; story, demo, help, credits ...
        ret c
        jp .show
.nd:    ld hl,PAGE_STORY
        or a
        jr z,.pg
        dec a
        ld hl,PAGE_HELP
        dec a
        jr z,.pg
        ld hl,PAGE_CREDITS
.pg:    call page_wait
        ret c
        jr .show

; keys on the title: N / SPACE / FIRE start (carry); S, I, K pages (NZ after)
title_keys:
        ld a,1
        ld (t_mode),a
        ld a,(in_new)
        and (1<<IN_FIRE)
        jr nz,.go
        ld a,(KR4)
        bit 0,a                 ; N
        jr z,.go
        ld a,(KR2)
        bit 3,a                 ; C: password
        jr nz,.npw
        call pw_entry
        jr nc,.pwok
        or 1                    ; NZ, NC: back to the title
        ret
.pwok:  ld a,2
        ld (t_mode),a
        scf
        ret
.npw:
        ld a,(KR1)
        bit 1,a                 ; S story
        ld hl,PAGE_STORY
        jr z,.pg
        ld a,(KR6)
        bit 3,a                 ; I help
        ld hl,PAGE_HELP
        jr z,.pg
        ld a,(KR7)
        bit 3,a                 ; K credits
        ld hl,PAGE_CREDITS
        jr z,.pg
        xor a
        ret                     ; Z, NC
.go:    scf
        ret
.pg:    call page_wait
        ret c
        or 1                    ; NZ, NC
        ret

; show page HL for up to 10 s; carry if N/fire pressed (start game)
page_wait:
        call show_page
        ld bc,500
.l:     push bc
        call wait_frame
        call sound_tick
        call read_input
        pop bc
        ld a,(in_new)
        and (1<<IN_FIRE)
        jr nz,.go
        ld a,(KR4)
        bit 0,a
        jr z,.go
        ; any other key returns early
        ld a,(KR6)
        bit 2,a
        jr z,.ret
        dec bc
        ld a,b
        or c
        jr nz,.l
.ret:   or a
        ret
.go:    scf
        ret

title_anim:
        ; torch flames
        ld a,(frame)
        and 3
        jr nz,.nt
        ld hl,TITLE_TORCH
        ld b,2
.t:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        call rnd
        and 3
        push hl
        ld hl,TFLAME
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (de),a
        pop hl
        djnz .t
.nt:    ; logo shimmer: a bright diagonal band sweeps across the letters
        ld a,(frame)
        and 1
        jr nz,.ns
        ld hl,TITLE_LOGO
        ld b,TITLE_NLOGO
.s:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,e
        and 31
        ld c,a
        ld a,e
        rlca
        rlca
        rlca
        and 7
        add a,c
        ld c,a
        ld a,(frame)
        rrca
        and 63
        sub c
        and 63
        cp 3
        ld a,(hl)               ; original byte
        inc hl
        jr nc,.keep
        and $8F
        or $40                  ; buff highlight
.keep:  ld (de),a
        djnz .s
.ns:    ; bottom scroller (row 15)
        ld a,(frame)
        and 3
        ret nz
        ld hl,VRAM+15*32+1
        ld de,VRAM+15*32
        ld bc,31
        ldir
        ld hl,(t_scroll)
        ld a,(hl)
        cp 255
        jr nz,.sc
        ld hl,SCROLLTXT
        ld a,(hl)
.sc:    inc hl
        ld (t_scroll),hl
        ld (VRAM+15*32+31),a
        ret
TFLAME: db $80|(1<<4)|13, $80|(7<<4)|11, $80|(1<<4)|7, $80|(4<<4)|12

; ---------------------------------------------------------------------
; automap: mode(1) 128x64, one pixel per cell, explored cells only
; ---------------------------------------------------------------------
automap:
        ld a,M1W
        ld (lbase),a
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),0
        ldir
        ld h,MAPH
        ld de,VRAM+9*32
        ld c,MAPROWS
.r:     ld l,0
.b:     ld b,4
        xor a
        ld (am_acc),a
.p:     ld a,(hl)
        bit 7,a
        jr z,.u
        and $7F
        push hl
        ld l,a
        ld h,MAPCOL>>8
        ld a,l
        add a,MAPCOL&255
        ld l,a
        ld a,(hl)
        pop hl
        jr .px
.u:     xor a
.px:    push bc
        ld c,a
        ld a,(am_acc)
        add a,a
        add a,a
        or c
        ld (am_acc),a
        pop bc
        inc l
        djnz .p
        ld a,(am_acc)
        ld (de),a
        inc de
        bit 7,l
        jr z,.b
        inc h
        dec c
        jr nz,.r
        ; frame lines above and below
        ld hl,VRAM+6*32
        ld b,32
.fl:    ld (hl),$FF
        inc hl
        djnz .fl
        ld hl,VRAM+56*32
        ld b,32
.fl2:   ld (hl),$FF
        inc hl
        djnz .fl2
        ; screen boundaries hint: none - blink the player
.wait:  call wait_frame
        call sound_tick
        ld a,(frame)
        and 8
        ld c,2
        jr z,.bl
        ld c,0
.bl:    call am_plot
        call read_input
        ld a,(in_new)
        or a
        jr z,.wait
        ; back to the dungeon
        ld a,(scr_y)
        add a,a
        add a,a
        ld b,a
        ld a,(scr_x)
        add a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,LVBUF+LV_SCREENS
        add hl,de
        ld a,(hl)
        or a
        ld a,M0G
        jr z,.g
        ld a,M0O
.g:     ld (lbase),a
        ld (LATCH),a
        xor a
        ld (in_new),a
        call render_window
        call draw_status
        ld a,1
        ld (light_dirty),a
        ret
am_acc: db 0

; plot the player pixel with colour C
am_plot:
        ld a,(p_y)
        add a,9
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *32
        ld a,(p_x)
        rrca
        rrca
        and $1F
        ld e,a
        ld d,VRAM>>8
        add hl,de
        ld a,(p_x)
        and 3
        ld b,a
        ld a,3
        sub b
        ld b,a
        inc b
        ld a,c
        ld e,3
.sh:    dec b
        jr z,.ok
        rlca
        rlca
        rlc e
        rlc e
        jr .sh
.ok:    ld d,a
        ld a,e
        cpl
        and (hl)
        or d
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; inventory / status page
; ---------------------------------------------------------------------
inventory:
        call bank1
        ld hl,PAGE_INV
        call show_page
        ld a,(p_lvl)
        add a,48
        ld (VRAM+3*32+11),a
        ld a,(p_xp)
        call num2
        ld (VRAM+3*32+20),hl
        ld de,VRAM+4*32+11
        ld a,(p_hp)
        ld c,a
        ld a,(p_hpmax)
        ld b,a
        ld a,G_HPF
        call pips
        ld de,VRAM+5*32+11
        ld a,(p_mp)
        ld c,a
        ld a,(p_mpmax)
        ld b,a
        ld a,G_MPF
        call pips
        ld a,(p_gems)
        call num2
        ld (VRAM+6*32+11),hl
        ld de,VRAM+8*32+4
        ld a,(p_staff)
        ld hl,INV_STAFF
        call .line
        ld a,(p_boots)
        ld hl,INV_BOOTS
        call .line
        ld a,(p_sun)
        ld hl,INV_SUN
        call .line
        ld a,(p_ring)
        ld hl,INV_RING
        call .line
        ld a,(p_blade)
        ld hl,INV_BLADE
        call .line
        ld a,(p_key)
        ld hl,INV_KEY
        call .line
        call bank0
.w:     call wait_frame
        call sound_tick
        call read_input
        ld a,(in_new)
        or a
        jr z,.w
        xor a
        ld (in_new),a
        call render_window
        call draw_status
        ld a,1
        ld (light_dirty),a
        ret
; A = owned flag, HL = 24-char line, DE = vram -> next free line
.line:  or a
        ret z
        push de
        ld bc,24
        ldir
        pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        ret

; A = 0..99 -> HL = two digit screen codes (L first digit)
num2:   ld b,0
.t:     sub 10
        jr c,.d
        inc b
        jr .t
.d:     add a,10+48
        ld h,a
        ld a,b
        add a,48
        ld l,a
        ret

; ---------------------------------------------------------------------
; leaving a chapter by the stairs: the lantern gutters out
; ---------------------------------------------------------------------
chapter_exit:
        call music_stop
        ld hl,SFX_CHAPTER
        call sfx
        ld a,1
        ld (p_dead),a           ; lantern off
        ld (light_dirty),a
        ld b,70
.f:     push bc
        call wait_frame
        ld a,(light_dirty)
        or a
        call nz,light_update
        call anim_tick
        call sound_tick
        pop bc
        djnz .f
        xor a
        ld (p_dead),a
        ret

; ---------------------------------------------------------------------
; the Ember is rekindled: dawn picture, epilogue, credits
; ---------------------------------------------------------------------
final_ending:
        ld a,TR_END
        call music_play
        ld hl,SFX_VICTORY
        call sfx
        ld b,100
.f:     push bc
        call wait_frame
        call anim_tick
        call sound_tick
        pop bc
        djnz .f
        call bank1
        ld hl,(LB_PIC2)
        call show_picture
        ld bc,400
        call .hold
        ld a,M0O
        ld (lbase),a
        ld (LATCH),a
        call bank1
        ld hl,PAGE_END
        call show_page
        ld a,(p_gems)
        call num2
        ld (VRAM+6*32+21),hl
        ld hl,END_GEMS
        ld de,VRAM+6*32+9
        ld bc,11
        ldir
        call bank0
        ld bc,3000
.hold:  push bc
        call wait_frame
        call sound_tick
        call read_input
        pop bc
        ld a,(in_new)
        or a
        ret nz
        dec bc
        ld a,b
        or c
        jr nz,.hold
        ret

; ---------------------------------------------------------------------
; password entry: 6 letters, CTRL deletes, RETURN accepts, SPACE cancels
; NC = valid password (state set), C = cancelled
; ---------------------------------------------------------------------
pw_entry:
        ld a,(bank_cur)
        push af
        call bank1
        ld hl,PAGE_PW
        call show_page
        pop af
        call bank_set
.rel:   call wait_frame         ; wait until the C key is released
        call sound_tick
        call any_input
        jr nz,.rel
        xor a
        ld (sk_last),a
        ld c,0                  ; length
.redraw:
        push bc
        ld hl,VRAM+7*32+13
        ld b,6
.d:     ld (hl),$80|(1<<4)|3    ; yellow underline blocks
        inc hl
        djnz .d
        pop bc
        ld a,c
        or a
        jr z,.loop
        ld hl,pw_buf
        ld de,VRAM+7*32+13
        ld b,c
.dc:    ld a,(hl)
        call ascii2vz
        ld (de),a
        inc hl
        inc de
        djnz .dc
.loop:  push bc
        call wait_frame
        call sound_tick
        call scan_key
        pop bc
        or a
        jr z,.loop
        cp ' '
        jr z,.cancel
        cp 1                    ; CTRL = delete
        jr nz,.nd
        ld a,c
        or a
        jr z,.loop
        dec c
        jr .redraw
.nd:    cp 13
        jr z,.enter
        ld b,a
        ld a,c
        cp 6
        jr nc,.loop
        ; only password letters
        ld hl,PWALPHA
        ld e,32
.ok:    ld a,(hl)
        cp b
        jr z,.add
        inc hl
        dec e
        jr nz,.ok
        jr .loop
.add:   ld hl,pw_buf
        ld e,c
        ld d,0
        add hl,de
        ld (hl),b
        inc c
        push bc
        ld hl,SFX_STEP
        call sfx
        pop bc
        jr .redraw
.enter: ld a,c
        cp 6
        jr nz,.loop
        push bc
        call pw_decode
        pop bc
        ret nc
        ; wrong
        ld hl,T_BADPW
        call show_msg
        ld hl,STATROW
        ld de,VRAM+13*32
        ld bc,32
        ldir
        ld a,M0O
        ld (LATCH),a
        call draw_border_bottom
        ld c,0
        ld hl,SFX_NOMP
        call sfx
        jp .redraw
.cancel:
        scf
        ret
draw_border_bottom:
        ld hl,VRAM+15*32
        ld b,32
.b:     ld (hl),$80|(7<<4)|12
        inc hl
        djnz .b
        ret

; scan the keyboard: A = ascii of a newly pressed key (0 none, 1 CTRL, 13 RETURN)
sk_last: db 0
scan_key:
        ld hl,$68FE
        ld de,KEYMAP
        ld c,8
.r:     ld a,(hl)
        cpl
        and $3F
        jr nz,.hit
        ld a,e
        add a,6
        ld e,a
        jr nc,$+3
        inc d
        rlc l
        dec c
        jr nz,.r
        xor a
        ld (sk_last),a
        ret
.hit:   ld b,a
.bt:    rr b
        jr c,.f
        inc de
        jr .bt
.f:     ld a,(de)
        ld b,a
        ld a,(sk_last)
        cp b
        ld a,b
        ld (sk_last),a
        jr nz,.new
        xor a
        ret
.new:   ld a,b
        ret
KEYMAP: db "TW",0,"EQR"
        db "GS",1,"DAF"
        db "BX",0,"CZV"
        db "52",0,"314"
        db "N.",0,", M"
        db "69",0,"807"
        db "YO",13,"IPU"
        db "HL",0,"K;J"
