; ============================================================================
;  RENDER: composing the arena each tick, effects, messages, shadows
;  (always-visible memory: these routines switch the stage bank in and out)
; ============================================================================
; ---------------------------------------------------------------------------
; render_fight: compose the arena for this tick
; ---------------------------------------------------------------------------
render_fight:
        call anim_step
        ; put back the backdrop where things were drawn last tick.  If the
        ; camera moved, the scrolling rows all come straight from the stage
        ; (and BG is rebuilt on the next still tick).
        ld a,(band_top)
        ld (rc_top),a
        ld a,BANDBOT
        ld (rc_bot),a
        ld a,(scrolled)
        or a
        jr z,.still
        ld a,SKYROWS
        ld (rc_bot),a
.still: ld a,(band_l)
        ld (rc_l),a
        ld a,(band_r)
        ld (rc_r),a
        call rect_restore
        ld a,BANDBOT
        ld (copy_bot),a
        ld a,(scrolled)
        or a
        jr z,.ns0
        xor a
        ld (scrolled),a
        inc a
        ld (bg_stale),a
        ld a,(cam)
        ld (src_cam),a
        ld a,SKYROWS
        ld b,64-SKYROWS
        ld de,SB+SKYROWS*32
        call stage_rows
        ld a,64
        ld (copy_bot),a
        ld a,SKYROWS
        ld (band_top),a
        xor a
        ld (band_l),a
        ld a,32
        ld (band_r),a
.ns0:   ld a,BANDBOT
        ld (cur_top),a
        ld a,32
        ld (cur_l),a
        xor a
        ld (cur_r),a
        ld a,ARENATOP
        ld (clip_top),a
        ; shadows first, under everything
        ld ix,p1
        call draw_shadow
        ld ix,p2
        call draw_shadow
        ; the one attacking is drawn last, so the strike is on top
        ld ix,p1
        ld iy,p2
        ld a,(p1+F_ST)
        cp ST_ATK
        jr nz,.o
        ld ix,p2
        ld iy,p1
.o:     push iy
        call draw_one
        pop ix
        call draw_one
        call draw_projs
        ; spark
        ld a,(spark_t)
        or a
        jr z,.ns
        dec a
        ld (spark_t),a
        ld a,1
        call set_colour
        ld a,(spark_x)
        ld l,a
        ld h,0
        ld (pt_x),hl
        ld a,(spark_row)
        ld (pt_row),a
        xor a
        ld (pt_flip),a
        ld hl,fx_hit
        ld a,(spark_blk)
        or a
        jr z,$+5
        ld hl,fx_block
        call draw_points
.ns:
        ; copy range = last tick's area + this tick's
        ld a,(cur_top)
        ld b,a
        ld a,(band_top)
        cp b
        jr c,$+3
        ld a,b
        cp ARENATOP
        jr nc,$+4
        ld a,ARENATOP
        ld (copy_top),a
        ld a,(cur_l)
        ld b,a
        ld a,(band_l)
        cp b
        jr c,$+3
        ld a,b
        ld (copy_l),a
        ld a,(cur_r)
        ld b,a
        ld a,(band_r)
        cp b
        jr nc,$+3
        ld a,b
        ld (copy_r),a
        ; this tick's area is next tick's band
        ld a,(cur_top)
        cp ARENATOP
        jr nc,$+4
        ld a,ARENATOP
        ld (band_top),a
        ld a,(cur_l)
        ld (band_l),a
        ld a,(cur_r)
        ld (band_r),a
        ; HUD
        ld a,(hud_dirty)
        or a
        jr z,.nh
        xor a
        ld (hud_dirty),a
        call hud_bars
.nh:    ld a,(dbg_on)
        or a
        ret z
        ld a,(dbg_dirty)
        or a
        ret z
        xor a
        ld (dbg_dirty),a
        jp dbg_show

; draw_one: IX = fighter -> sprite and its effects
draw_one:
        call draw_fighter
        ld a,(ix+F_ST)
        cp ST_DIZZY
        jp z,draw_dizzy
        cp ST_ATK
        ret nz
        call move_ptr
        ld a,(iy+M_FX)
        and 3
        ret z
        cp 3                    ; a thrown thing has no line to draw
        ret z
        ld (fx_kind),a
        ; hand position from the frame directory
        ld a,(ix+F_FRM)
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b
        ld e,a
        ld d,0
        ld l,(ix+F_DIRL)
        ld h,(ix+F_DIRH)
        add hl,de
        ld de,8
        add hl,de
        ld a,(hl)               ; hand x (signed)
        ld (fx_hx),a
        inc hl
        ld c,(hl)               ; hand y (rows up)
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld a,(ix+F_FACE)
        ld (pt_flip),a
        or a
        jr z,.r
        ld a,e
        cpl
        ld e,a
        ld a,d
        cpl
        ld d,a
        inc de
.r:     push de
        call scr_x
        pop de
        add hl,de
        ld (pt_x),hl
        ld a,GROUND
        sub (ix+F_Y)
        sub c
        ld (pt_row),a
        ld a,1
        call set_colour
        ; which part of the move?
        ld a,(ix+F_T)
        cp (iy+M_SU)
        jr nc,.act
        bit 2,(iy+M_FX)         ; a staff or cane: nothing trails behind
        ret nz
        ld hl,fx_whipback
        jp draw_points
.act:   sub (iy+M_SU)
        cp (iy+M_AC)
        jr nc,.rec
        ; the whip at full stretch: from the hand to the reach
        ld a,(fx_kind)
        cp 2
        jr nz,.hi
        ld a,GROUND-1
        ld (pt_row),a
.hi:    ld a,(fx_hx)
        ld b,a
        ld a,(iy+M_X1)
        sub b
        jr nc,$+3
        xor a
        inc a
        push af
        call hline
        pop af
        ; crack at the tip
        ld e,a
        ld d,0
        ld a,(pt_flip)
        or a
        jr z,.t
        ld a,e
        cpl
        ld e,a
        ld d,$FF
        inc de
.t:     ld hl,(pt_x)
        add hl,de
        ld (pt_x),hl
        ld hl,fx_crack
        jp draw_points
.rec:   bit 2,(iy+M_FX)
        ret nz
        ld hl,fx_slack_hi
        ld a,(fx_kind)
        cp 2
        jr nz,$+5
        ld hl,fx_slack_lo
        jp draw_points

; dbg_show: spare time and slow ticks in place of player 1's name (debug)
dbg_show:
        ld a,$AA
        ld b,0
        ld c,0
        ld d,9
        ld e,5
        call fill_rect
        ; percent = spare count / 40 (spare count * 35 T of 141,260 T)
        ld hl,(spare_show)
        ld de,40
        call div16
        ld a,l
        cp 100
        jr c,$+4
        ld a,99
        call num2
        ld a,'%'
        ld (num_buf+2),a
        xor a
        ld (num_buf+3),a
        ld hl,num_buf
        ld b,0
        ld c,0
        ld a,1
        call text
        ld hl,(slow_ticks)
        ld a,h
        or a
        ld a,l
        jr z,$+4
        ld a,99
        cp 100
        jr c,$+4
        ld a,99
        call num2
        ld a,'S'
        ld (num_buf+2),a
        xor a
        ld (num_buf+3),a
        ld hl,num_buf
        ld b,4
        ld c,0
        ld a,3
        call text
        ld a,1
        ld (copy_hud),a
        ret

; num2: A (0-99) -> two digits in num_buf
num2:
        ld b,'0'
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     add a,'0'
        ld (num_buf+1),a
        ld a,b
        ld (num_buf),a
        ret

; div16: HL = HL / DE
div16:
        ld bc,0
.l:     or a
        sbc hl,de
        jr c,.d
        inc bc
        jr .l
.d:     ld h,b
        ld l,c
        ret

; ---------------------------------------------------------------------------
; messages are drawn once into the backdrop (BG), so they cost nothing per tick
; show_msg: HL = big line (0 = none), DE = small line under it (0 = none),
;           A = row.  The words are copied first: they may live in a bank
;           that is out while the clean view is being drawn on.
show_msg:
        push af
        push de
        ld de,msgbuf1
        call .cp
        pop hl
        ld de,msgbuf2
        call .cp
        call h0_on
        ld a,1
        ld (cam_lock),a
        call bg_fresh_i
        call hide_msg_i
        ld a,1
        ld (cam_lock),a
        ld (msg_on),a
        pop af
        ld (msg_row),a
        ; a dark banner across the arena behind the words
        sub 2
        ld c,a
        ld b,0
        call sb_addr
        ld de,BG-SB
        add hl,de
        ld d,h
        ld e,l
        inc de
        ld (hl),$AA
        ld bc,15*32-1
        ld a,(msgbuf2)
        or a
        jr z,$+5
        ld bc,21*32-1
        ldir
        ld a,BG>>8
        ld (txt_page),a
        ld a,(msgbuf1)
        or a
        jr z,.ns
        ld hl,msgbuf1
        ld a,(msg_row)
        ld c,a
        call big_text
.ns:    ld a,(msgbuf2)
        or a
        jr z,.done
        ld hl,msgbuf2
        ld a,(msg_row)
        add a,13
        ld c,a
        ld a,1
        call text_c
.done:  ld a,SB>>8
        ld (txt_page),a
        call h0_off
        jp band_full
.cp:    ld a,h
        or l
        jr nz,.c1
        ld (de),a
        ret
.c1:    ld b,33
.c2:    ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        djnz .c2
        xor a
        ld (de),a
        ret

; hide_msg: put the stage back where the message was; free the camera
hide_msg:
        call h0_on
        call hide_msg_i
        jp h0_off
hide_msg_i:
        xor a
        ld (cam_lock),a
        ld a,(msg_on)
        or a
        ret z
        xor a
        ld (msg_on),a
        ld a,(bg_cam)
        ld (src_cam),a
        ld a,(msg_row)
        sub 2
        ld c,a
        ld b,0
        call sb_addr
        ld de,BG-SB
        add hl,de
        ex de,hl
        ld a,(msg_row)
        sub 2
        ld b,21
        call stage_rows_i
        jp band_full

; bg_fresh: make the clean view match the camera (after it has been scrolling)
bg_fresh:
        call h0_on
        call bg_fresh_i
        jp h0_off
bg_fresh_i:
        ld a,(bg_stale)
        or a
        ret z
        xor a
        ld (bg_stale),a
        ld a,(cam)
        ld (src_cam),a
        ld (bg_cam),a
        ld a,SKYROWS
        ld b,64-SKYROWS
        ld de,BG+SKYROWS*32
        jp stage_rows_i

; band_full: next tick restores and copies the whole arena
band_full:
        ld a,ARENATOP
        ld (band_top),a
        xor a
        ld (band_l),a
        ld a,32
        ld (band_r),a
        ret

; draw_shadow: IX = fighter.  A small green ellipse on the street, narrower
; the higher the fighter is off the ground.  Drawn as spans: whole bytes in
; the middle, masked bytes at the ends.
draw_shadow:
        ld a,(ix+F_HIDE)
        or a
        ret nz
        ld a,(ix+F_Y)
        srl a
        srl a
        cp 6
        jr c,$+4
        ld a,6
        neg
        add a,9
        ld (sh_w),a             ; half width
        call scr_x
        ld (sh_x),hl
        ld a,GROUND+1
        ld c,2
        call .row
        ld a,GROUND+2
        ld c,0
        call .row
        ld a,GROUND+3
        ld c,3
.row:   ld (pt_row),a
        ld a,(sh_w)
        sub c
        ret c
        ret z
        ld c,a                  ; half width for this row
        ld hl,(sh_x)
        ld e,c
        ld d,0
        or a
        sbc hl,de               ; left end
        bit 7,h
        jr z,$+5
        ld hl,0
        ld a,h
        or a
        ret nz
        ld a,l
        cp 128
        ret nc
        ld b,a                  ; x0
        ld a,c
        add a,a
        add a,b                 ; x1 = x0 + 2w
        jr c,.cl
        cp 128
        jr c,.ok
.cl:    ld a,127
.ok:    ld c,a                  ; x1 (inclusive)
        ; widen this tick's area
        ld a,(pt_row)
        ld hl,cur_top
        cp (hl)
        jr nc,$+3
        ld (hl),a
        ld a,b
        rrca
        rrca
        and $1F
        ld hl,cur_l
        cp (hl)
        jr nc,$+3
        ld (hl),a
        ld a,c
        rrca
        rrca
        and $1F
        inc a
        inc hl
        cp (hl)
        jr c,$+3
        ld (hl),a
        ; first and last bytes
        push bc
        ld a,b
        rrca
        rrca
        and $1F
        ld b,a
        ld a,(pt_row)
        ld c,a
        call sb_addr            ; HL = first byte
        pop bc
        ld a,b
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,sh_lmask
        add hl,de
        ld e,(hl)               ; keep-mask for the first byte
        pop hl
        ld a,b
        rrca
        rrca
        and $1F
        ld d,a                  ; first column
        ld a,c
        rrca
        rrca
        and $1F
        sub d                   ; columns after the first
        jr nz,.multi
        ; one byte: both masks together
        ld a,c
        and 3
        push hl
        ld hl,sh_rmask
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        or e
        pop hl
        jr sh_put
.multi: ld d,a
        ld a,e
        call sh_put
        inc hl
        dec d
        jr z,.last
.mid:   ld a,(sh_pat)
        ld (hl),a
        inc hl
        dec d
        jr nz,.mid
.last:  ld a,c
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,sh_rmask
        add hl,de
        ld a,(hl)
        pop hl
; sh_put: A = keep-mask, HL = byte: the rest of the byte becomes shadow
sh_put: push de
        ld e,a
        cpl
        ld d,a
        ld a,(sh_pat)
        and d
        ld d,a
        ld a,(hl)
        and e
        or d
        ld (hl),a
        pop de
        ret

; keep-masks: first byte starting at pixel 0-3, last byte ending at pixel 0-3
sh_lmask: db $00,$C0,$F0,$FC
sh_rmask: db $3F,$0F,$03,$00

; rect_restore: put the clean picture back in SB over rows rc_top..rc_bot-1,
; byte columns rc_l..rc_r-1.  The still sky (and everything, while a message
; is up and the camera is locked) comes from BG; the scrolling rows come
; straight from the stage, so a moving camera never needs BG rebuilt.
rect_restore:
        call h0_on
        call rect_restore_i
        jp h0_off
rect_restore_i:
        ld a,(cam_lock)
        or a
        jr z,.split
        ld hl,BG
        ld de,SB
        jp rect_copy
.split: ld a,(rc_top)
        cp SKYROWS
        jr nc,.stage
        ; still rows from BG
        ld a,(rc_bot)
        push af
        cp SKYROWS
        jr c,$+4
        ld a,SKYROWS
        ld (rc_bot),a
        ld a,(rc_l)
        push af
        ld a,(rc_r)
        push af
        ld hl,BG
        ld de,SB
        call rect_copy
        pop af
        ld (rc_r),a
        pop af
        ld (rc_l),a
        pop af
        ld (rc_bot),a
        ld a,SKYROWS
        ld (rc_top),a
.stage: ld a,(rc_bot)
        ld b,a
        ld a,(rc_top)
        ld c,a
        ld a,b
        sub c
        ret z
        ret c
        ld (rr_rows),a
        ld a,(rc_r)
        ld b,a
        ld a,(rc_l)
        ld c,a
        ld a,b
        sub c
        ret z
        ret c
        add a,a
        ld e,a
        ld d,0
        ld hl,ldirow_end
        or a
        sbc hl,de
        ld (.call+1),hl
        ; source: the stage at the camera, plus the left column
        ld a,(rc_top)
        ld c,a
        ld a,(cam)
        ld b,a
        call stage_src
        ld a,(rc_l)
        ld e,a
        ld d,0
        add hl,de
        push hl
        ld a,(rc_l)
        ld b,a
        ld a,(rc_top)
        ld c,a
        call sb_addr
        ex de,hl                ; DE = SB destination
        pop hl
        ld a,(rr_rows)
        ld b,a
.row:   push hl
        push de
        push bc
.call:  call ldirow_end
        pop bc
        pop de
        pop hl
        push bc
        ld bc,STAGEW
        add hl,bc
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        djnz .row
        ret


; draw_dizzy: IX = a dizzy fighter: stars circling the head
draw_dizzy:
        call scr_x
        ld (pt_x),hl
        ld a,D_HURTH
        call def_byte
        add a,5
        ld b,a
        ld a,GROUND
        sub b
        ld (pt_row),a
        xor a
        ld (pt_flip),a
        inc a
        call set_colour
        ld hl,fx_dizzy1
        bit 2,(ix+F_T)
        jr z,$+5
        ld hl,fx_dizzy2
        jp draw_points

; draw_projs: the things in flight (player 1's with a blue rim, player 2's red)
draw_projs:
        ld iy,pr1
        ld a,2
        call .one
        ld iy,pr2
        ld a,3
.one:   ld (fx_kind),a
        ld a,(iy+PR_ON)
        or a
        ret z
        ld l,(iy+PR_XL)
        ld h,(iy+PR_XH)
        srl h
        rr l
        srl h
        rr l
        ld a,(cam)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (pt_x),hl
        ld a,GROUND
        sub (iy+PR_Y)
        ld (pt_row),a
        ld a,(iy+PR_T)          ; it spins: mirrored on alternate pairs of ticks
        rrca
        and 1
        ld (pt_flip),a
        ld a,(iy+PR_KIND)
        and 3
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,proj_shapes
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        push de
        ld a,(fx_kind)
        call set_colour
        pop hl
        call draw_points        ; the rim, in the owner's colour
        ld a,1
        call set_colour
        pop hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp draw_points          ; the bright core
proj_shapes:
        dw fx_p0r,fx_p0c, fx_p1r,fx_p1c, fx_p2r,fx_p2c, fx_p3r,fx_p3c
