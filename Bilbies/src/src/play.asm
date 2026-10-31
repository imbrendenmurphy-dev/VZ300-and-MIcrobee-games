; ---------------------------------------------------------------------------
; Playing a level: controls, cursor, scrolling, skills, the demo/test player
; ---------------------------------------------------------------------------

; reset the game state for a freshly built level
game_init:
        ld hl,CRT
        ld de,CRT+1
        ld bc,NCRT*CSZ+NPART*PSZ-1
        ld (hl),0
        ldir
        xor a
        ld (v_released),a
        ld (v_saved),a
        ld (v_lost),a
        ld (v_reltimer),a
        ld (v_hatch),a
        ld (v_paused),a
        ld (v_nuke),a
        ld (v_nukeidx),a
        ld (v_end),a
        ld (v_hcount),a
        ld (v_secfr),a
        ld (v_loop),a
        ld (v_spawnfl),a
        ld hl,0
        ld (v_gtick),hl
        ld a,(v_min)
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; x15
        add hl,hl
        add hl,hl               ; x60
        ld (v_tleft),hl
        ld a,2+SK_DIG           ; start with the first skill that's available
        ld (v_sel),a
        ld hl,v_skill
        ld b,8
        ld c,2
.fs:    ld a,(hl)
        or a
        jr nz,.got
        inc hl
        inc c
        djnz .fs
        jr .sc
.got:   ld a,c
        ld (v_sel),a
.sc:    ; start the window on the hatch
        ld hl,(v_hx)
        ld de,-56
        add hl,de
        jr c,.s1
        ld hl,0
.s1:    srl h
        rr l
        srl h
        rr l
        ld a,l
        call set_scroll
        ld a,(v_hy)
        sub 8
        jr nc,.s3
        xor a
.s3:    call set_scry
        ld a,64
        ld (v_cx),a
        ld a,22
        ld (v_cy),a
        ret

; ---- play the level in v_lvl (built). Returns when it ends. ------------------
play_level:
        ld a,BROW>>8
        ld (ds_rows),a
        di
        call snd_init
        ei
        call cls_blue
        call panel_init
        call render_play
        xor a
        ld (v_kold),a
        ld (v_ctlold),a
        ld a,$FF
        ld (v_psb),a
        ld a,(v_tick)
        ld (v_last),a
.loop:  ld a,2
        call frame_sync
        call controls
        ld a,(v_quit)
        or a
        ret nz
        ; logic every other loop (12.5 a second)
        ld a,(v_loop)
        inc a
        ld (v_loop),a
        rra
        jr c,.nt
        call game_tick
        call demo_tick
        call clock
        call hover
        call render_play
        jr .pu
.nt:    call clock
        call hover
        ld a,(v_scrb)
        ld hl,v_lastscr
        cp (hl)
        jr nz,.rp
        ld a,(v_scry)
        ld hl,v_lastsy
        cp (hl)
        jr z,.lt
.rp:    call render_play
        jr .pu
.lt:    call render_light
.pu:
        call panel_update
        call sfx_tick
        ld a,(v_end)
        or a
        jr z,.loop
        ; let the last sounds and sparks finish
        ld b,25
.w:     push bc
        ld a,2
        call frame_sync
        call part_tick
        call render_play
        call sfx_tick
        pop bc
        djnz .w
        ret

cls_blue:
        ld a,BG
        jp cls

; ---- the clock ---------------------------------------------------------------------
clock:
        ld a,(v_paused)
        or a
        ret nz
        ld a,(v_secfr)
        add a,2
        cp 50
        jr c,.s
        ld hl,(v_tleft)
        ld a,h
        or l
        jr z,.z
        dec hl
        ld (v_tleft),hl
.z:     xor a
.s:     ld (v_secfr),a
        ret

; ---- what's under the cursor --------------------------------------------------------
; v_hcount = how many, v_hst = state of the first, v_hptr = the one to give the
; selected skill to (0 = none can take it)
hover:
        xor a
        ld (v_hcount),a
        ld hl,0
        ld (v_hptr),hl
        ld a,(v_cy)
        cp PFH
        ret nc
        call scroll_px
        ld a,(v_cx)
        ld e,a
        ld d,0
        add hl,de
        ld (v_hx2),hl           ; cursor level x
        ld a,(v_scry)
        ld e,a
        ld a,(v_cy)
        add a,e
        ld (v_hy2),a            ; cursor level y
        ld ix,CRT
        ld b,NCRT
.l:     push bc
        ld a,(ix+C_ST)
        or a
        jr z,.n
        cp ST_SPLAT
        jr nc,.n
        ld hl,(v_hx2)
        ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        or a
        sbc hl,de
        inc hl
        inc hl
        ld a,h
        or a
        jr nz,.n
        ld a,l
        cp 5
        jr nc,.n
        ld a,(v_hy2)
        sub (ix+C_Y)
        add a,5
        cp 7
        jr nc,.n
        ld hl,v_hcount
        ld a,(hl)
        inc (hl)
        or a
        jr nz,.nf
        ld a,(ix+C_ST)
        ld (v_hst),a
        bit 0,(ix+C_FL)
        jr z,.nf
        ld a,ST_CLIMB
        ld (v_hst),a
.nf:    ld hl,(v_hptr)
        ld a,h
        or l
        jr nz,.n
        ld a,(v_sel)
        sub 2
        cp 8
        jr nc,.n
        call can_take
        jr nz,.n
        ld (v_hptr),ix
.n:     ld de,CSZ
        add ix,de
        pop bc
        djnz .l
        ret

; Z if creature IX can take skill A (0..7)
can_take:
        ld c,a
        add a,a
        ld l,a
        ld h,0
        ld de,SKMASK
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = states allowed
        ld a,(ix+C_ST)
        or a
        jr z,.no
.sh:    srl d
        rr e
        dec a
        jr nz,.sh
        jr nc,.no
        ld a,c
        cp 3
        jr nc,.yes
        ; climber / floater / bomber: not twice
        inc a
        ld b,a
        ld a,(ix+C_FL)
.fb:    rrca
        djnz .fb
        jr c,.no
.yes:   xor a
        ret
.no:    or 1
        ret
; bit s = state s allowed (bit 0 = state 1 after the shift above)
SKMASK:
        ; states:      1W 2F 3Fl 4C 5H 6Bl 7Bu 8Sh 9Ba 10Mi 11Di
        dw %11111111111 ; climber: anything still on the go
        dw %11111111111 ; floater
        dw %11111111111 ; bomber
        dw %11111000001 ; blocker: walker, builder, shrugger, basher, miner, digger
        dw %11110000001 ; builder: walker, shrugger, basher, miner, digger
        dw %11011000001 ; basher
        dw %10111000001 ; miner
        dw %01111000001 ; digger

; give skill A to creature IX (it can take it); uses one up
apply_skill:
        ld c,a
        ld e,a
        ld d,0
        ld hl,v_skill
        add hl,de
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ld a,1
        ld (v_pdirty),a
        ld a,c
        or a
        jr nz,.a1
        set 0,(ix+C_FL)
        jr .snd
.a1:    dec a
        jr nz,.a2
        set 1,(ix+C_FL)
        jr .snd
.a2:    dec a
        jr nz,.a3
        set 2,(ix+C_FL)
        ld (ix+C_BT),BOMBTICKS
        jr .snd
.a3:    ld hl,SKST-3
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        ld (ix+C_ST),a
        ld (ix+C_AN),0
        ld (ix+C_CNT),0
.snd:   ld a,SFX_ASSIGN
        jp sfx_play
SKST:   db ST_BLOCK,ST_BUILD,ST_BASH,ST_MINE,ST_DIG

; ---- controls ---------------------------------------------------------------------
; keys read once a loop: KB bits 0 Z, 1 X, 2 comma, 3 full stop, 4 H, 5 N, 6 ARM
controls:
        ld a,(v_demo)
        or a
        jp nz,demo_controls
        call read_controls
        ld c,a
        ; extra keys into B
        ld b,0
        ld a,(KR2)
        bit 4,a
        jr nz,.k1
        set 0,b                 ; Z
.k1:    bit 1,a
        jr nz,.k2
        set 1,b                 ; X
.k2:    ld a,(KR4)
        bit 3,a
        jr nz,.k3
        set 2,b                 ; ,
.k3:    bit 1,a
        jr nz,.k4
        set 3,b                 ; .
.k4:    bit 0,a
        jr nz,.k5
        set 5,b                 ; N
.k5:    ld a,(KR7)
        bit 0,a
        jr nz,.k6
        set 4,b                 ; H
.k6:    bit 5,c
        jr z,.k7
        set 6,b                 ; ARM
.k7:    ; quit: CTRL + Q
        ld a,(KR1)
        bit 2,a
        jr nz,.nq
        ld a,(KR0)
        bit 4,a
        jr nz,.nq
        ld a,1
        ld (v_quit),a
        ret
.nq:    ; new presses
        ld a,(v_kold)
        cpl
        and b
        ld e,a                  ; E = newly pressed
        ld a,b
        ld (v_kold),a
        ld a,(v_ctlold)
        cpl
        and c
        ld d,a                  ; D = new controls
        ld a,c
        ld (v_ctlold),a
        push bc
        push de
        ; skill keys 1-8
        call skill_keys
        pop de
        push de
        bit 0,e
        call nz,sel_prev
        pop de
        push de
        ld a,e
        and $42
        call nz,sel_next
        pop de
        push de
        bit 4,e
        call nz,toggle_pause
        pop de
        push de
        bit 5,e
        call nz,nuke_press
        pop de
        pop bc
        push de
        ; rate keys (repeat while held, every 2 loops)
        ld a,(v_loop)
        and 1
        jr nz,.nr
        bit 2,b
        call nz,rate_down
        bit 3,b
        call nz,rate_up
.nr:    pop de
        ; cursor
        push de
        ld a,c
        call move_cursor
        pop de
        ; fire
        bit 4,d
        jr nz,click
        ; held fire on the rate buttons repeats
        bit 4,c
        ret z
        ld a,(v_loop)
        and 1
        ret nz
        ld a,(v_cy)
        cp BROW0
        ret c
        ld a,(v_cx)
        cp 16
        ret nc
        cp 8
        jp c,rate_down
        jp rate_up

; fire pressed
click:
        ld a,(v_cy)
        cp PFH
        jr nc,.panel
        ld ix,(v_hptr)
        ld a,ixh
        or ixl
        ret z
        ld a,(v_sel)
        sub 2
        cp 8
        ret nc
        jp apply_skill
.panel: cp BROW0
        ret c
        ld a,(v_cx)
        cp 96
        jr nc,.mm
        rrca
        rrca
        rrca
        and 15                  ; button
        cp 2
        jr c,.rate
        cp 10
        jr c,.skill
        jr z,toggle_pause
        jp nuke_press
.rate:  or a
        jp z,rate_down
        jp rate_up
.skill: ld (v_sel),a
        ld a,SFX_CLICK
        jp sfx_play
.mm:    ; minimap: centre the window there (a minimap pixel is 16 x 8)
        sub 97
        jr nc,.m0
        xor a
.m0:    sub 4
        jr nc,.m1
        xor a
.m1:    add a,a
        add a,a                 ; 4 bytes a minimap pixel
        call set_scroll
        ld a,(v_cy)
        sub MMROW
        jr nc,.m2
        xor a
.m2:    add a,a
        add a,a
        add a,a                 ; 8 rows a minimap pixel
        sub 20
        jr nc,.m3
        xor a
.m3:    jp set_scry

skill_keys:
        ld hl,SKEYS
        ld c,2
.l:     ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        call keyt
        jr nz,.n
        ld a,c
        ld (v_sel),a
        ret
.n:     inc c
        ld a,c
        cp 10
        jr nz,.l
        ret
; row address low byte, bit: keys 1..8
SKEYS:  db $F7,$10, $F7,$02, $F7,$08, $F7,$20, $F7,$01, $DF,$01, $DF,$20, $DF,$08

sel_prev:
        ld a,(v_sel)
        dec a
        cp 2
        jr nc,.s
        ld a,9
.s:     ld (v_sel),a
        ret
sel_next:
        ld a,(v_sel)
        inc a
        cp 10
        jr c,.s
        ld a,2
.s:     ld (v_sel),a
        ret
toggle_pause:
        ld a,(v_paused)
        xor 1
        ld (v_paused),a
        ld a,SFX_CLICK
        jp sfx_play
; nuke needs two presses within a second
nuke_press:
        ld a,(v_nuke)
        or a
        ret nz
        ld hl,(v_gtick)
        ld de,(v_nukeask)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.first
        ld a,l
        cp 13
        jr nc,.first
        ld a,1
        ld (v_nuke),a
        ld a,SFX_OHNO
        jp sfx_play
.first: ld hl,(v_gtick)
        ld (v_nukeask),hl
        ld a,SFX_CLICK
        jp sfx_play

rate_down:
        ld a,(v_minrate)
        ld c,a
        ld a,(v_rate)
        cp c
        ret z
        ret c
        dec a
        jr rate_set
rate_up:
        ld a,(v_rate)
        cp 99
        ret nc
        inc a
rate_set:
        ld (v_rate),a
        ld a,1
        ld (v_pdirty),a
        ret

; ---- cursor ---------------------------------------------------------------------------
; A = controls. Speed builds up while a direction is held.
move_cursor:
        ld c,a
        and $0F
        jr nz,.held
        xor a
        ld (v_cheld),a
        ret
.held:  ld a,(v_cheld)
        inc a
        jr z,.h
        ld (v_cheld),a
.h:     ld b,1
        cp 6
        jr c,.sp
        inc b
        cp 14
        jr c,.sp
        inc b
.sp:    ; left
        bit 0,c
        jr z,.nl
        ld a,(v_cx)
        sub b
        jr nc,.l1
        call scroll_left
        xor a
.l1:    ld (v_cx),a
.nl:    bit 1,c
        jr z,.nr
        ld a,(v_cx)
        add a,b
        cp 128
        jr c,.r1
        call scroll_right
        ld a,127
.r1:    ld (v_cx),a
.nr:    bit 3,c
        jr z,.nu
        ld a,(v_cy)
        sub b
        jr nc,.u0
        call scroll_up
        xor a
.u0:    cp PFH-1                ; leaving the panel: back to the field's foot
        jr nc,.u1
        ld e,a
        ld a,(v_cy)
        cp PFH
        ld a,e
        jr c,.u1
        ld a,PFH-1
.u1:    ld (v_cy),a
.nu:    bit 2,c
        ret z
        ld a,(v_cy)
        cp PFH-1
        jr nz,.dn
        call scroll_down        ; at the foot of the field: scroll first
        ret nz
        ld a,(v_cy)
.dn:    add a,b
        cp 63
        jr c,.d1
        ld a,63
.d1:    ld (v_cy),a
        ret

scroll_up:
        ld a,(v_scry)
        or a
        ret z
        dec a
        jr z,.s
        dec a
.s:     ld (v_scry),a
        ret
; NZ if it scrolled
scroll_down:
        ld a,(v_lh)
        sub PFH
        ld c,a
        ld a,(v_scry)
        cp c
        jr nc,.no
        inc a
        cp c
        jr nc,.s
        inc a
.s:     ld (v_scry),a
        or 1
        ret
.no:    xor a
        ret
; A = wanted top row -> clamped
set_scry:
        ld c,a
        ld a,(v_lh)
        sub PFH
        jr nc,.p
        xor a
.p:     cp c
        jr nc,.ok
        ld c,a
.ok:    ld a,c
        ld (v_scry),a
        ret

scroll_left:
        ld a,(v_scrb)
        or a
        ret z
        dec a
        ld (v_scrb),a
        ret
scroll_right:
        ld a,(v_lwb)
        sub 32
        ld c,a
        ld a,(v_scrb)
        cp c
        ret nc
        inc a
        ld (v_scrb),a
        ret
; A = wanted scroll byte -> clamped
set_scroll:
        ld c,a
        ld a,(v_lwb)
        sub 32
        cp c
        jr nc,.ok
        ld c,a
.ok:    ld a,c
        ld (v_scrb),a
        ret

; ===========================================================================
; demo / test player: scripted skills (tick.w, creature, skill) ... $FF
; ===========================================================================
demo_start:                     ; HL = script
        ld (v_dptr),hl
        ld hl,v_dfired
        ld b,8
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; every event not done yet: (tick.w, creature, skill, x from, x to)
demo_tick:
        ld a,(v_demo)
        or a
        ret z
        ld hl,(v_dptr)
        ld c,0                  ; event number
.ev:    ld a,(hl)
        cp $FF
        ret z
        push hl
        push bc
        call .one
        pop bc
        pop hl
        ld de,8
        add hl,de
        inc c
        jr .ev
; HL = event, C = its number
.one:   push hl
        call .bit               ; fired already?
        pop hl
        ret nz
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(v_gtick)
        or a
        sbc hl,de
        pop hl
        ret c                   ; not yet
        ld a,(hl)               ; creature
        inc hl
        ld b,(hl)               ; skill
        inc hl
        push bc
        ld e,(hl)
        inc hl
        ld d,(hl)               ; x from
        inc hl
        ld (v_ev0),de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; x to
        ld (v_ev1),de
        cp $FF
        jr z,.any               ; every bilby that comes by
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,CRT
        add hl,de
        push hl
        pop ix
        pop bc
        ld a,b
        cp 8                    ; nuke
        jr nz,.sk
        ld a,1
        ld (v_nuke),a
        jr .fire
.any:   pop bc
        ld ix,CRT
        ld a,NCRT
.al:    push af
        push bc
        ld a,(ix+C_ST)
        or a
        call nz,.try
        pop bc
        ld de,CSZ
        add ix,de
        pop af
        dec a
        jr nz,.al
        ret
.try:   ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        ld hl,(v_ev0)
        or a
        sbc hl,de
        jr z,.t0
        ret nc
.t0:    ld hl,(v_ev1)
        or a
        sbc hl,de
        ret c
        push bc
        ld a,b
        call can_take
        pop bc
        ret nz
        ld a,b
        add a,2
        ld (v_sel),a
        ld a,b
        jp apply_skill
.sk:    ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        ld hl,(v_ev0)
        or a
        sbc hl,de
        jr z,.x0
        ret nc                  ; x < from
.x0:    ld hl,(v_ev1)
        or a
        sbc hl,de
        ret c                   ; x > to
        push bc
        ld a,b
        call can_take
        pop bc
        ret nz
        ld a,b
        add a,2
        ld (v_sel),a
        push bc
        ld a,b
        call apply_skill
        pop bc
.fire:  call .bit
        or (hl)
        ld (hl),a
        ret
; event C -> HL = its byte in v_dfired, A = its bit; NZ if set
.bit:   push bc
        ld a,c
        rrca
        rrca
        rrca
        and 7
        ld hl,v_dfired
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,c
        and 7
        ld b,a
        ld a,1
        jr z,.b1
.b0:    add a,a
        djnz .b0
.b1:    ld c,a
        and (hl)
        ld a,c
        pop bc
        ret

; the demo cursor follows the next creature to get a skill; a key ends it
demo_controls:
        ld a,(v_test)
        or a
        jr nz,.nk
        call anykey
        jr z,.nk
        ld a,1
        ld (v_quit),a
        ret
.nk:    ld hl,(v_dptr)
        ld c,0
.f:     ld a,(hl)
        cp $FF
        jr z,.last
        push hl
        push bc
        call demo_tick.bit
        pop bc
        pop hl
        jr nz,.nx
        inc hl
        inc hl
        ld a,(hl)               ; the camera skips 'everyone' events
        dec hl
        dec hl
        inc a
        jr nz,.got
.nx:    ld de,8
        add hl,de
        inc c
        jr .f
.last:  ld a,(v_dlast)
        jr .fol
.got:   inc hl
        inc hl
        ld a,(hl)
        ld (v_dlast),a
.fol:   ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,CRT
        add hl,de
        push hl
        pop ix
        ld a,(ix+C_ST)
        dec a
        cp ST_EXIT-1
        jr c,.ok
        ; that one's done: follow the first still on the go
        ld ix,CRT
        ld b,NCRT
        ld de,CSZ
.any:   ld a,(ix+C_ST)
        dec a
        cp ST_EXIT-1
        jr c,.ok
        add ix,de
        djnz .any
        ret
.ok:    ; keep it in the window: across
        call scroll_px
        ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        call view_x
        jr c,.far
        cp 28
        jr c,.sl
        cp 100
        jr c,.vert
        call scroll_right
        jr .vert
.sl:    call scroll_left
        jr .vert
.far:   ; well away: jump straight there
        ex de,hl
        ld de,-64
        add hl,de
        jr c,.f1
        ld hl,0
.f1:    srl h
        rr l
        srl h
        rr l
        ld a,l
        call set_scroll
.vert:  ; and down
        ld a,(v_scry)
        ld c,a
        ld a,(ix+C_Y)
        sub c
        jr c,.vu
        cp 10
        jr c,.vu
        cp 36
        jr c,.cur
        call scroll_down
        jr .cur
.vu:    call scroll_up
.cur:   call scroll_px
        ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        call view_x
        jr nc,.c1
        ld a,64
.c1:    ld b,a                  ; target x
        ld a,(v_scry)
        ld c,a
        ld a,(ix+C_Y)
        sub c
        sub 2
        jr nc,.c2
        xor a
.c2:    cp PFH
        jr c,.c3
        ld a,PFH-1
.c3:    ld c,a                  ; target y
        ld a,(v_cx)
        call .step
        ld (v_cx),a
        ld b,c
        ld a,(v_cy)
        call .step
        ld (v_cy),a
        ret
.step:  cp b
        ret z
        jr c,.up
        dec a
        cp b
        ret z
        dec a
        ret
.up:    inc a
        cp b
        ret z
        inc a
        ret
