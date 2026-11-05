; =====================================================================
;  CIRCUS 2 - attract sequence, title, info screens, high scores
; =====================================================================

attract:
        ld a,1
        ld (title_first),a
.cycle:
        call title_screen
        jr nz,.start
        ; gameplay demonstration
        ld a,(demo_act)
        add a,2
        cp NACTS
        jr c,$+4
        sub NACTS
        ld (demo_act),a
        xor a
        ld (demo_key),a
        ld a,1
        call game_main
        ld a,(demo_key)
        or a
        jr nz,.start
        call howto_screen
        jr nz,.start
        call powerups_screen
        jr nz,.start
        call hiscore_screen
        jr nz,.start
        call preview_screen
        jr nz,.start
        jr .cycle
.start: call stop_music
        call wait_release
        xor a
        call game_main
        jr .cycle

wait_release:
        call rearm
        call anykey
        jr nz,wait_release
        ld a,(frames)
        ld (nextframe),a
        ld a,4
        jp waitframes

; ---------------------------------------------------------------------
; helper: theme + compose BG for an info screen, then show it
; A = bg colour, B = css
; ---------------------------------------------------------------------
info_begin:
        call set_theme
        ld hl,BG
        ld a,(colpat)
        call fill2k
        ld hl,BG
        ld (text_buf),hl
        ; decorative border: candy stripes top & bottom rows 0..1, 62..63
        ld hl,BG
        call .stripe
        ld hl,BG+62*32
.stripe:
        ld b,64
.l:     ld a,b
        and 2
        ld a,(colpat+3)
        jr z,$+5
        ld a,(colpat+1)
        ld (hl),a
        inc hl
        djnz .l
        ret

info_show:      ; copy BG to VRAM
        ld hl,BG
        ld de,VRAM
        ld b,64
        jp copyrows

; run an info screen for A updates; calls (anim_hook) each update.
; returns NZ if a key was pressed (start game)
info_wait:
        ld (iw_n),a
        ld a,(frames)
        ld (nextframe),a
.lp:    call snd_tick
        ld a,2
        call syncframe
        ld hl,(anim_hook)
        ld a,h
        or l
        call nz,.call
        call anykey
        jr nz,.key
        ld hl,iw_n
        dec (hl)
        jr nz,.lp
        xor a
        ret
.key:   ld a,1
        or a
        ret
.call:  jp (hl)

ensure_music:   ; start title march if not running
        ld a,(mus_on)
        or a
        ret nz
        ld hl,mus_title0
        ld de,mus_title1
        ld a,1
        jp play_music

; ---------------------------------------------------------------------
; TITLE SCREEN
; ---------------------------------------------------------------------
title_screen:
        ld a,0
        ld b,0
        call set_theme          ; physical CSS0, sprites as designed
        ld hl,title_lz
        ld de,BG
        call unlz
        call info_show
        call ensure_music
        ld hl,VRAM
        ld (text_buf),hl
        xor a
        ld (t_msg),a
        ld (t_tick),a
        ld a,1
        ld (t_msgt),a
        ld a,255
        ld (t_msg),a
        ; floating balloons init
        ld ix,t_bal
        ld b,4
        ld c,0
.bi:    ld a,c
        cp 3
        jr c,$+3
        xor a
        ld (ix+0),a             ; sprite idx
        ld a,c
        and 1
        ld a,3
        jr z,$+4
        ld a,120
        ld (ix+1),a             ; x
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,10
        ld (ix+2),a             ; y
        ld (ix+3),0
        ld de,4
        add ix,de
        inc c
        djnz .bi
        ld a,(frames)
        ld (nextframe),a
        ld hl,375
        ld (t_time),hl
.lp:    call snd_tick
        ld a,2
        call syncframe
        call title_anim
        ; keys: S sound, D difficulty, others start
        ld b,$FD
        ld c,$02
        call keydown
        jr z,.ns
        ld a,(snd_on)
        xor 1
        ld (snd_on),a
        ld a,2
        call opt_feedback
        jr .lp2
.ns:    ld b,$FD
        ld c,$08                ; D
        call keydown
        jr z,.nd
        ld a,(difficulty)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (difficulty),a
        ld a,3
        call opt_feedback
        jr .lp2
.nd:    call anykey
        jr z,.lp2
        ld a,1
        or a
        ret
.lp2:   ld hl,(t_time)
        dec hl
        ld (t_time),hl
        ld a,h
        or l
        jr nz,.lp
        xor a
        ret

opt_feedback:   ; A = message index to show now; wait for release
        ld (t_msg),a
        ld a,50
        ld (t_msgt),a
        call click
        call title_msg_force
.w:     call rearm
        call anykey
        jr nz,.w
        ld hl,375
        ld (t_time),hl
        ld a,(frames)
        ld (nextframe),a
        ret

title_anim:
        ld hl,t_tick
        inc (hl)
        ; ---- chasing marquee lights
        ld hl,title_lights
        ld c,0
.ml:    ld a,(hl)
        cp $FF
        jr z,.mld
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld (tmpy),a
        ld a,(t_tick)
        srl a
        add a,c
.m3:    sub 3
        jr nc,.m3
        add a,3
        ld e,$55                ; lit: yellow
        jr z,$+4
        ld e,$FF                ; unlit: red
        push bc
        ld a,(tmpy)
        ld c,a
        push de
        call plotv
        pop de
        inc b
        call plotv
        pop bc
        pop hl
        inc c
        jr .ml
.mld:   ; ---- twinkling stars
        ld hl,title_stars
        ld c,0
.st:    ld a,(hl)
        cp $FF
        jr z,.std
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
        push hl
        push bc
        ld d,c
        ld c,a
        ld a,(t_tick)
        add a,d
        add a,d
        add a,d
        and 15
        ld e,$55
        jr nz,$+4
        ld e,$AA
        call plotv
        pop bc
        pop hl
        inc c
        jr .st
.std:   ; ---- peeking clown (winks)
        ld a,(t_tick)
        and 31
        cp 28
        ld hl,BIGCLOWN1
        jr c,$+5
        ld hl,BIGCLOWN2
        ld b,59
        ld c,44
        call drawv
        ; ---- floating balloons at the sides
        ld ix,t_bal
        ld b,4
.bl:    push bc
        ; erase old
        ld b,(ix+1)
        ld c,(ix+2)
        ld d,2
        ld e,5
        call restore_rect
        ; move up every other tick
        ld a,(t_tick)
        and 1
        jr nz,.nm
        dec (ix+2)
        ld a,(ix+2)
        cp 250
        jr c,.nm
        cp 252
        jr nc,.nm
        ld (ix+2),52
.nm:    ld a,(ix+2)
        cp 53
        jr nc,.nd               ; hidden below grass line
        bit 7,a
        jr nz,.nd
        ld a,(ix+0)
        add a,a
        ld hl,balspr_norm
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,(ix+1)
        ld c,(ix+2)
        call drawv
.nd:    ld de,4
        add ix,de
        pop bc
        djnz .bl
        ; ---- bottom message cycle
        ld hl,t_msgt
        dec (hl)
        ret nz
        ld (hl),50
        ld a,(t_msg)
        inc a
        cp 6
        jr c,$+3
        xor a
        ld (t_msg),a
title_msg_force:
        ; clear band rows 58..62 (grass)
        ld hl,BG+58*32
        ld de,VRAM+58*32
        ld bc,5*32
        ldir
        ld a,(t_msg)
        add a,a
        ld hl,title_msgs
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

title_msgs:     dw tm_press,tm_hi,tm_opts,tm_diff,tm_credit,tm_keys

tm_press:
        ld hl,txt_press
        jr tm_show
tm_credit:
        ld hl,txt_credit
        jr tm_show
tm_keys:
        ld hl,txt_tkeys
        jr tm_show
tm_opts:
        ld hl,txt_sound
        ld de,strbuf
        call strcpy
        ld hl,txt_on
        ld a,(snd_on)
        or a
        jr nz,$+5
        ld hl,txt_off
        call strcpy
        ld hl,strbuf
        jr tm_show
tm_diff:
        ld hl,txt_diff
        ld de,strbuf
        call strcpy
        ld a,(difficulty)
        add a,a
        ld hl,difftxt
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call strcpy
        ld hl,strbuf
        jr tm_show
tm_hi:
        ld hl,txt_hi
        ld de,strbuf
        call strcpy
        ld hl,hiscores
        call hs_fmt             ; appends "NAM 012345"
        ld hl,strbuf
tm_show:
        ld c,58
        ld e,$55
        jp textc

difftxt:        dw txt_easy,txt_normal,txt_hard

; plot directly in VRAM: B=x C=y E=pattern
plotv:
        ld a,c
        cp 64
        ret nc
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,b
        rrca
        rrca
        and $1F
        add a,l
        ld l,a
        ld a,h
        adc a,high VRAM
        ld h,a
        ld a,b
        and 3
        push hl
        ld hl,pixmask
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld d,(hl)
        pop hl
        ld a,d
        and e
        ld e,a
        ld a,d
        cpl
        and (hl)
        or e
        ld (hl),a
        ret

; draw sprite HL at B,C directly into VRAM (y must be 0..63-h)
drawv:
        push hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,VRAM
        add hl,de
        ld (dsbase),hl
        pop hl
        jp drawspr_b

; restore rect from BG to VRAM: B=x(pixel) C=y D=bytes wide E=rows
restore_rect:
        ld a,c
        cp 64
        ret nc
        ld a,d
        ld (rr_w),a
        ld a,e
        ld (rr_h),a
        jp rr_go

; ---------------------------------------------------------------------
; HOW TO PLAY
; ---------------------------------------------------------------------
howto_screen:
        ld a,0
        ld b,1
        call info_begin
        ld hl,txt_howto
        ld c,4
        ld a,(colpat+3)
        ld e,a
        call bigc
        ld hl,howto_lines
        ld c,17
.l:     ld a,(hl)
        or a
        jr z,.d
        push hl
        push bc
        ld a,(colpat+2)
        ld e,a
        call textc
        pop bc
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        ld a,c
        add a,7
        ld c,a
        jr .l
.d:     ; demo seesaw & clown art at the sides
        call info_show
        call ensure_music
        ld hl,0
        ld (anim_hook),hl
        ld a,200
        jp info_wait

; ---------------------------------------------------------------------
; POWER-UPS & BALLOONS legend
; ---------------------------------------------------------------------
powerups_screen:
        ld a,0
        ld b,0
        call info_begin
        ld hl,txt_powerups
        ld c,3
        ld a,(colpat+3)
        ld e,a
        call bigc
        ; 7 tokens + names, two columns
        ld hl,BG
        ld (dsbase),hl
        ld iy,legend
.l:     ld a,(iy+0)
        cp $FF
        jr z,.d
        ; sprite into BG at (x,y)
        ld l,(iy+2)
        ld h,(iy+3)
        ld b,(iy+0)
        ld c,(iy+1)
        push bc
        push hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BG
        add hl,de
        ld (dsbase),hl
        pop hl
        call drawspr_b
        pop bc
        ; text at column (x+12)/4, y+1
        ld a,b
        add a,12
        rrca
        rrca
        and $1F
        ld b,a
        inc c
        ld l,(iy+4)
        ld h,(iy+5)
        ld a,(colpat+2)
        ld e,a
        push iy
        call drawtext
        pop iy
        ld de,6
        add iy,de
        jr .l
.d:     call info_show
        call ensure_music
        ld hl,0
        ld (anim_hook),hl
        ld a,200
        jp info_wait

legend:
        db 4,15
        dw TOK_WIDE1,txt_lg_wide
        db 4,24
        dw TOK_SLOW1,txt_lg_slow
        db 4,33
        dw TOK_NET1,txt_lg_net
        db 4,42
        dw TOK_X21,txt_lg_x2
        db 66,15
        dw TOK_UMB1,txt_lg_umb
        db 66,24
        dw TOK_FIRE1,txt_lg_fire
        db 66,33
        dw TOK_1UP1,txt_lg_1up
        db 6,52
        dw BAL_GIFT1,txt_lg_gift
        db 48,52
        dw BAL_BOMB1,txt_lg_bomb
        db 88,52
        dw BAL_STEEL,txt_lg_steel
        db $FF

; ---------------------------------------------------------------------
; HIGH SCORES
; ---------------------------------------------------------------------
init_hiscores:
        ld hl,hs_default
        ld de,hiscores
        ld bc,30
        ldir
        ret

hs_default:
        db "BPM",$01,$50,$00
        db "VZ!",$01,$00,$00
        db "DSE",$00,$75,$00
        db "BOZ",$00,$50,$00
        db "MOE",$00,$25,$00

; append "NAM 012345" for entry HL to DE
hs_fmt:
        ld b,3
.n:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .n
        ld a,' '
        ld (de),a
        inc de
        ld b,3
.s:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .s
        xor a
        ld (de),a
        ret

hiscore_screen:
        ld a,1
        ld b,0
        call info_begin
        ld hl,txt_halloffame
        ld c,4
        ld a,(colpat+3)
        ld e,a
        call bigc
        ld hl,hiscores
        ld c,20
        ld b,0
.l:     push bc
        push hl
        ; "1. NAM 012345"
        ld de,strbuf
        ld a,b
        add a,'1'
        ld (de),a
        inc de
        ld a,'.'
        ld (de),a
        inc de
        ld a,' '
        ld (de),a
        inc de
        call hs_fmt
        ld hl,strbuf
        pop de
        pop bc
        push bc
        push de
        ld a,b
        or a
        ld a,(colpat+3)
        jr z,$+5
        ld a,(colpat+2)
        ld e,a
        call textc
        pop hl
        ld de,6
        add hl,de
        pop bc
        ld a,c
        add a,7
        ld c,a
        inc b
        ld a,b
        cp 5
        jr nz,.l
        ; balloons decoration
        ld hl,BG+21*32
        ld (dsbase),hl
        ld b,8
        ld hl,BAL_R
        call drawspr_b
        ld b,116
        ld hl,BAL_Y
        call drawspr_b
        ld hl,BG+40*32
        ld (dsbase),hl
        ld b,10
        ld hl,BAL_B
        call drawspr_b
        ld b,114
        ld hl,BAL_R
        call drawspr_b
        call info_show
        call ensure_music
        ld hl,0
        ld (anim_hook),hl
        ld a,175
        jp info_wait

; ---------------------------------------------------------------------
; FEATURE PREVIEW ("COMING UP")
; ---------------------------------------------------------------------
preview_screen:
        ld a,0
        ld b,0
        call info_begin
        ld hl,txt_comingup
        ld c,3
        ld a,(colpat+3)
        ld e,a
        call bigc
        ld hl,preview_lines
        ld c,16
.l:     ld a,(hl)
        or a
        jr z,.d
        push hl
        push bc
        ld b,8
        ld a,(colpat+2)
        ld e,a
        call drawtext
        pop bc
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        ld a,c
        add a,10
        ld c,a
        jr .l
.d:     call info_show
        call ensure_music
        ld hl,preview_anim
        ld (anim_hook),hl
        xor a
        ld (t_tick),a
        ld a,200
        call info_wait
        push af
        ld hl,0
        ld (anim_hook),hl
        pop af
        ret

preview_anim:
        ld hl,t_tick
        inc (hl)
        ; hoop flicker at (8,15)
        ld b,8
        ld c,14
        ld d,5
        ld e,6
        call restore_rect6
        ld a,(t_tick)
        and 2
        ld hl,HOOP1
        jr z,$+5
        ld hl,HOOP2
        ld b,8
        ld c,14
        call drawv
        ; monkey swing at (12,24)
        ld b,12
        ld c,24
        call restore_rect8
        ld a,(t_tick)
        and 4
        ld hl,MONKEY1
        jr z,$+5
        ld hl,MONKEY2
        ld b,12
        ld c,24
        call drawv
        ; bomb balloon
        ld b,14
        ld c,35
        call restore_rect8
        ld a,(t_tick)
        and 4
        ld hl,BAL_BOMB1
        jr z,$+5
        ld hl,BAL_BOMB2
        ld b,14
        ld c,35
        call drawv
        ; gold balloon bobbing
        ld b,14
        ld c,44
        call restore_rect8
        ld a,(t_tick)
        and 8
        rrca
        rrca
        rrca
        add a,45
        ld c,a
        ld b,14
        ld hl,BAL_GOLD
        jp drawv

; restore 6-byte-wide x 6 rows / 3-byte x 9 rows from BG to VRAM at B,C
restore_rect6:
        ld a,6
        ld (rr_w),a
        ld a,6
        ld (rr_h),a
        jr rr_go
restore_rect8:
        ld a,3
        ld (rr_w),a
        ld a,9
        ld (rr_h),a
rr_go:  ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,b
        rrca
        rrca
        and $1F
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        push hl
        ld de,VRAM
        add hl,de
        ex de,hl
        pop hl
        ld bc,BG
        add hl,bc
        ld a,(rr_h)
.r:     push af
        push hl
        push de
        ld a,(rr_w)
        ld c,a
        ld b,0
        ldir
        pop hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop hl
        add hl,bc
        pop af
        dec a
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; high score entry
; ---------------------------------------------------------------------
hiscore_check:
        ; find position: first entry with score < our score
        ld hl,hiscores+3
        ld b,0
.f:     push hl
        ld de,score
        ld c,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.lower             ; our digit smaller -> not here
        jr nz,.higher
        inc hl
        inc de
        dec c
        jr nz,.cmp
.lower: pop hl
        ld de,6
        add hl,de
        inc b
        ld a,b
        cp 5
        jr nz,.f
        ret                     ; not in the table
.higher:
        pop hl
        ; B = rank (0..4).  shift entries down
        ld a,b
        ld (hs_rank),a
        ld a,4
        sub b
        jr z,.noshift
        ; bytes to move = (4-b)*6, from end backwards
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *6
        ld b,h
        ld c,l
        ld hl,hiscores+23
        ld de,hiscores+29
        lddr
.noshift:
        ; entry address
        ld a,(hs_rank)
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,hiscores
        add hl,de
        ld (hs_ptr),hl
        ld (hl),'A'
        inc hl
        ld (hl),' '
        inc hl
        ld (hl),' '
        inc hl
        ex de,hl
        ld hl,score
        ld bc,3
        ldir
        ; entry screen
        ld a,1
        ld b,1
        call info_begin
        ld hl,txt_newhigh
        ld c,6
        ld a,(colpat+3)
        ld e,a
        call bigc
        ld hl,txt_entername
        ld c,22
        ld a,(colpat+2)
        ld e,a
        call textc
        ld hl,txt_entryhelp
        ld c,52
        ld a,(colpat+2)
        ld e,a
        call textc
        call info_show
        ld hl,mus_clear0
        ld de,mus_clear1
        xor a
        call play_music
        call wait_release
        xor a
        ld (hs_pos),a
        ld a,(frames)
        ld (nextframe),a
.lp:    call snd_tick
        ld a,2
        call syncframe
        call hs_drawname
        ; typed letter?
        call getkey
        or a
        jr z,.joy
        cp 13
        jr z,.done
        cp 'A'
        jr c,.joy
        call hs_setchar
        call hs_next
        jr nz,.done
        call wait_key_up
        jr .lp
.joy:   call readinput
        ld c,a
        and $0C                 ; up/down cycles letter
        jr z,.nud
        call hs_getchar
        bit 2,c
        jr z,.dn
        cp ' '
        jr nz,.u1
        ld a,'A'
        jr .ok
.u1:    cp 'Z'
        jr nz,.u2
        ld a,' '
        jr .ok
.u2:    inc a
        jr .ok
.dn:    cp ' '
        jr nz,.d1
        ld a,'Z'
        jr .ok
.d1:    cp 'A'
        jr nz,.d2
        ld a,' '
        jr .ok
.d2:    dec a
.ok:    call hs_setchar
        ld a,6
        call waitframes
        jr .lp
.nud:   ld a,c
        and $13                 ; fire or right = next
        jr z,.lp
        call hs_next
        jr nz,.done
        call wait_key_up
        jr .lp
.done:  call stop_music
        call hs_drawname
        ld a,25
        call waitframes
        ret

wait_key_up:
        call rearm
        call anykey
        jr nz,wait_key_up
        call readinput
        or a
        jr nz,wait_key_up
        ret

hs_getchar:
        ld hl,(hs_ptr)
        ld a,(hs_pos)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ret
hs_setchar:
        push af
        call hs_getchar
        pop af
        ld (hl),a
        ret
hs_next:        ; advance position; NZ when finished
        ld a,(hs_pos)
        inc a
        ld (hs_pos),a
        cp 3
        jr nc,.fin
        call hs_getchar
        ld a,'A'
        ld (hl),a
        xor a
        ret
.fin:   or a
        ret

hs_drawname:
        ; draw name big in VRAM at row 32, cursor blink
        ld hl,BG+30*32
        ld de,VRAM+30*32
        ld bc,14*32
        ldir
        ld hl,VRAM
        ld (text_buf),hl
        ld hl,(hs_ptr)
        ld de,strbuf
        ld bc,3
        ldir
        xor a
        ld (de),a
        ld hl,strbuf
        ld b,13
        ld c,32
        ld a,(colpat+3)
        ld e,a
        call drawbig
        ; cursor underline
        ld a,(hs_pos)
        cp 3
        ret nc
        ld a,(frames)
        and 8
        ret z
        ld a,(hs_pos)
        add a,a
        add a,13
        ld l,a
        ld h,0
        ld de,VRAM+43*32
        add hl,de
        ld a,(colpat+2)
        ld (hl),a
        inc hl
        ld (hl),a
        ret

; scan keyboard -> ASCII of a pressed key (0 if none)
getkey:
        ld hl,keytab
        ld b,$FE
.row:   ld a,b
        ld (.rd+1),a
.rd:    ld a,($68FE)
        cpl
        and $3F
        jr nz,.hit
        ld de,6
        add hl,de
        rlc b
        ld a,b
        cp $FE
        jr nz,.row
        xor a
        ret
.hit:   rra
        jr c,.got
        inc hl
        jr .hit
.got:   ld a,(hl)
        ret

keytab:
        db 'T','W',0,'E','Q','R'
        db 'G','S',0,'D','A','F'
        db 'B','X',0,'C','Z','V'
        db '5','2',0,'3','1','4'
        db 'N','.',0,',',' ','M'
        db '6','9','-','8','0','7'
        db 'Y','O',13,'I','P','U'
        db 'H','L',':','K',';','J'
