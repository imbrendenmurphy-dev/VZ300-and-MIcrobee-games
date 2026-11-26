; =====================================================================
;  xfer.asm - the link duel
;  Twelve lanes a side run from the edges to a column of twelve nodes.
;  Fire a pulse down a lane: when it arrives it takes its node(s) for
;  your side and locks them for a while. Lanes can be plain, BROKEN,
;  FORKED (feeds two nodes), BOOSTED (locks for longer) or REVERSED
;  (hands the node to the other side). Hold more nodes than the other
;  side when the time runs out and the droid is yours.
;  In: xf_mine, xf_enemy (types). Out: A = 1 won, 0 lost, 2 deadlock.
; =====================================================================
G_WIRE      equ 0
G_BREAK     equ 1
G_FORK      equ 2
G_BOOST     equ 3
G_REV       equ 4
G_FORKED    equ 5              ; the lane under a fork (no entry of its own)
LANES       equ 12
XF_TIME     equ 250            ; frames (two fields each) = 10 seconds
LOCKT       equ 45

xfer_main:
            ld a,$08
            call fe_setlatch
            ld a,MUS_LINK
            call m_play
            ; sprites: slot 0 = our host (built already), slot 7 = the enemy
            ld a,(xf_enemy)
            ld d,7
            ld b,0
            call build_type
            ; charges: you 5 + class, them 4 + class
            ld a,(xf_mine)
            ld c,T_CLASS
            call type_stat
            ld (xc_mycls),a
            add a,5
            ld (xc_mych),a
            ld a,(xf_enemy)
            ld c,T_CLASS
            call type_stat
            ld (xc_ecls),a
            add a,4
            ld (xc_ench),a
            call xb_make
            ; nodes start alternating
            ld hl,xn_own
            ld b,LANES
            ld a,1
.n:         ld (hl),a
            xor 3
            inc hl
            djnz .n
            ld hl,xn_lock
            ld b,LANES
.z:         ld (hl),0
            inc hl
            djnz .z
            ld hl,xp_l
            ld b,LANES*2
.z2:        ld (hl),0
            inc hl
            djnz .z2
            ld a,5
            ld (xc_cur),a
            ld (xc_ecur),a
            xor a
            ld (xc_side),a          ; 0 = you on the left
            call xd_all
            ; ---- choose a side
            ld a,1
            ld (xc_choose),a
            ld a,70
            ld (xc_t),a
.ch:        call xd_side
            call fe_frame
            call fe_frame
            call read_input
            ld a,(demo)
            or a
            jr nz,.cauto
            ld a,(in_new)
            and K_LEFT
            jr z,.c1
            xor a
            ld (xc_side),a
            ld a,FX_MOVE
            call fe_sfx
.c1:        ld a,(in_new)
            and K_RIGHT
            jr z,.c2
            ld a,1
            ld (xc_side),a
            ld a,FX_MOVE
            call fe_sfx
.c2:        ld a,(in_new)
            and K_FIRE
            jr nz,.cgo
            jr .ct
.cauto:     ; the demo picks the side with more working lanes
            ld a,(xc_t)
            cp 40
            jr nz,.ct
            call xai_side
.ct:        ld hl,xc_t
            dec (hl)
            jr nz,.ch
.cgo:       xor a
            ld (xc_choose),a
            ld a,FX_SELECT
            call fe_sfx
            call xd_all
            ; ---- the duel
            ld hl,XF_TIME
            ld (xc_time),hl
            xor a
            ld (xc_ait),a
            ld (xc_pait),a
.f:         call fe_frame
            call xd_pulses          ; animate on the odd field too
            call fe_frame
            call read_input
            ld a,(demo)
            or a
            jr nz,.pai
            ; your cursor and fire
            ld a,(in_new)
            and K_UP
            jr z,.u
            ld a,(xc_cur)
            or a
            jr z,.u
            dec a
            ld (xc_cur),a
            ld a,FX_MOVE
            call fe_sfx
.u:         ld a,(in_new)
            and K_DOWN
            jr z,.d
            ld a,(xc_cur)
            cp LANES-1
            jr z,.d
            inc a
            ld (xc_cur),a
            ld a,FX_MOVE
            call fe_sfx
.d:         ld a,(in_new)
            and K_FIRE
            jr z,.ai
            ld a,(xc_cur)
            ld c,a
            ld a,(xc_side)
            call x_fire
            jr .ai
.pai:       ; demo: the autopilot plays your side
            ld hl,xc_pait
            dec (hl)
            jp p,.ai
            ld (hl),8
            ld a,(xc_side)
            ld b,a
            ld a,(xc_mych)
            call xai_pick
            jr c,.ai
            ld (xc_cur),a
            ld c,a
            ld a,(xc_side)
            call x_fire
.ai:        ; the droid's side
            ld hl,xc_ait
            dec (hl)
            jp p,.step
            ld a,(xc_ecls)
            add a,a
            ld b,a
            ld a,22
            sub b
            ld (hl),a               ; thinks faster the higher its class
            ld a,(xc_side)
            xor 1
            ld b,a
            ld a,(xc_ench)
            call xai_pick
            jr c,.step
            ld (xc_ecur),a
            ld c,a
            ld a,(xc_side)
            xor 1
            call x_fire
.step:      call x_step
            call xd_header
            call xd_meter
            ld hl,(xc_time)
            dec hl
            ld (xc_time),hl
            ld a,h
            or l
            jp nz,.f
            ; ---- count
            call m_stop
            ld b,LANES
            ld hl,xn_own
            ld de,0                 ; D = left, E = right
.cnt:       ld a,(hl)
            cp 1
            jr nz,.r
            inc d
.r:         cp 2
            jr nz,.nx
            inc e
.nx:        inc hl
            djnz .cnt
            ld a,(xc_side)
            or a
            jr z,.lft
            ld a,d
            ld d,e
            ld e,a                  ; D = yours, E = theirs
.lft:       ld a,d
            cp e
            ld a,2
            jr z,.res
            ld a,1
            jr nc,.res
            xor a
.res:       ld (xc_res),a
            ; the verdict
            ld hl,res_txt
            call str_index
            ld a,(xc_res)           ; won: gold; lost: alert; deadlock: system
            ld c,BF_GOLD
            cp 1
            jr z,.rc
            ld c,BF_ALERT
            or a
            jr z,.rc
            ld c,BF_SYSTEM
.rc:        ld a,c
            ld e,31
            call fe_header
            ld a,(xc_res)
            or a
            ld a,MUS_LOSE
            jr z,.j
            dec a
            ld a,MUS_WIN
            jr z,.j
            ld a,MUS_LOSE
.j:         call m_play
            ld a,120
            call fe_delay
            call m_stop
            ld a,(xc_res)
            ret
res_txt:    db "LINK FAILED",0,"TAKEN OVER!",0,"DEADLOCK",0

; ---------------------------------------------------------------------
; the board: random gates for each side (xb_gate: 12 left then 12 right)
xb_make:
            ld hl,xb_gate
            ld b,LANES*2
.c:         ld (hl),G_WIRE
            inc hl
            djnz .c
            ld ix,xb_gate
            call .side
            ld ix,xb_gate+LANES
.side:      ld c,0                  ; lane
.l:         call random
            and 15
            cp 4
            jr c,.br                ; 0-3 broken
            cp 6
            jr c,.fk                ; 4-5 fork
            cp 7
            jr c,.bo                ; 6 boost
            cp 9
            jr c,.rv                ; 7-8 reverse
            jr .nx
.br:        ld (ix+0),G_BREAK
            jr .nx
.bo:        ld (ix+0),G_BOOST
            jr .nx
.rv:        ld (ix+0),G_REV
            jr .nx
.fk:        ld a,c
            cp LANES-1
            jr z,.nx
            ld (ix+0),G_FORK
            ld (ix+1),G_FORKED
            inc ix
            inc c
.nx:        inc ix
            inc c
            ld a,c
            cp LANES
            jr c,.l
            ret

; A = side (0/1), C = lane -> HL = its gate
xb_ptr:
            ld hl,xb_gate
            or a
            jr z,.l
            ld hl,xb_gate+LANES
.l:         ld a,l
            add a,c
            ld l,a
            ret nc
            inc h
            ret

; ---------------------------------------------------------------------
; fire: A = side, C = lane (needs a charge and a free lane)
x_fire:
            ld (xf_s),a
            ld b,a
            ld a,(xc_side)
            cp b
            ld hl,xc_mych
            jr z,.m
            ld hl,xc_ench
.m:         ld a,(hl)
            or a
            ret z
            push hl
            ld a,(xf_s)
            call xb_ptr
            ld a,(hl)
            pop hl
            cp G_FORKED
            ret z                   ; no entry here
            push hl
            ld a,(xf_s)
            call xp_ptr
            ld a,(de)
            pop hl
            or a
            ret nz                  ; a pulse is already on its way
            dec (hl)
            ld a,1
            ld (de),a               ; pulse at position 1 of 16
            ld a,FX_PULSE
            call fe_sfx
            jp xd_header

; A = side, C = lane -> DE = its pulse position (0 = none)
xp_ptr:
            ld de,xp_l
            or a
            jr z,.l
            ld de,xp_r
.l:         ld a,e
            add a,c
            ld e,a
            ret nc
            inc d
            ret

; move the pulses; apply the ones that arrive; count the locks down
x_step:
            ld hl,xn_lock
            ld b,LANES
.lk:        ld a,(hl)
            or a
            jr z,.lz
            dec (hl)
            jr nz,.lz
            ld a,LANES
            sub b
            push hl
            push bc
            call xd_node            ; lock over: redraw unlocked
            pop bc
            pop hl
.lz:        inc hl
            djnz .lk
            xor a
            ld (xs_side),a
.sd:        ld c,0
.ln:        ld a,(xs_side)
            call xp_ptr
            ld a,(de)
            or a
            jr z,.nl
            inc a
            ld (de),a
            cp 17
            jr c,.nl
            xor a
            ld (de),a
            call x_arrive
.nl:        inc c
            ld a,c
            cp LANES
            jr nz,.ln
            ld a,(xs_side)
            inc a
            ld (xs_side),a
            cp 2
            jr nz,.sd
            ret

; a pulse from side xs_side reached the end of lane C
x_arrive:
            push bc
            ld a,(xs_side)
            call xb_ptr
            ld a,(hl)
            ld b,a
            ld a,(xs_side)
            inc a
            ld (xa_own),a           ; owner code 1 left, 2 right
            ld a,LOCKT
            ld (xa_lock),a
            ld a,b
            cp G_BREAK
            jr z,.out
            cp G_REV
            jr nz,.nr
            ld a,(xa_own)
            xor 3
            ld (xa_own),a
            jr .one
.nr:        cp G_BOOST
            jr nz,.nb
            ld a,LOCKT*2
            ld (xa_lock),a
            jr .one
.nb:        cp G_FORK
            jr nz,.one
            push bc
            inc c
            call x_take
            pop bc
.one:       call x_take
.out:       pop bc
            ret

; node C goes to xa_own (unless the other side has it locked)
x_take:
            ld hl,xn_lock
            ld a,l
            add a,c
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            or a
            jr z,.free
            ; locked: by whom?
            push hl
            ld hl,xn_own
            ld a,l
            add a,c
            ld l,a
            jr nc,.n2
            inc h
.n2:        ld a,(xa_own)
            cp (hl)
            pop hl
            ret nz                  ; theirs and locked: the pulse bounces
.free:      ld a,(xa_lock)
            ld (hl),a
            ld hl,xn_own
            ld a,l
            add a,c
            ld l,a
            jr nc,.n3
            inc h
.n3:        ld a,(xa_own)
            ld (hl),a
            ld a,FX_ZAP
            call fe_sfx
            ld a,c
            jp xd_node

; ---------------------------------------------------------------------
; AI: B = side, A = its charges -> A = lane to fire (NC), or C = hold
xai_pick:
            or a
            scf
            ret z
            ld (xa_ch),a
            ld a,b
            ld (xa_side),a
            inc a
            ld (xa_me),a            ; my owner code
            ; save a charge for the last two seconds unless rich
            ld a,(xa_ch)
            cp 2
            jr nc,.go
            ld hl,(xc_time)
            ld a,h
            or a
            jr nz,.hold
            ld a,l
            cp 50
            jr nc,.hold
.go:        ld a,$80
            ld (xa_best),a          ; best score so far (signed, $80 = none)
            ld a,$FF
            ld (xa_lane),a
            ld c,0
.l:         call xai_score
            ld b,a
            ld a,(xa_best)
            xor $80
            ld e,a
            ld a,b
            xor $80
            cp e
            jr c,.nb
            jr z,.nb
            ld a,b
            ld (xa_best),a
            ld a,c
            ld (xa_lane),a
.nb:        inc c
            ld a,c
            cp LANES
            jr nz,.l
            ld a,(xa_best)
            bit 7,a
            jr nz,.hold             ; nothing worth it
            or a
            jr z,.hold
            ; low classes fumble now and then
            call random
            and 7
            ld b,a
            ld a,(xc_ecls)
            cp b
            jr nc,.ok
            call random
            and 15
            cp LANES
            jr nc,.ok
            ld (xa_lane),a
.ok:        ld a,(xa_lane)
            or a                    ; NC
            ret
.hold:      scf
            ret

; score of lane C for side xa_side: +2 a node won, -2 a node given away,
; very low if the lane is busy or has no entry
xai_score:
            push bc
            ld a,(xa_side)
            call xp_ptr
            ld a,(de)
            or a
            jr nz,.no
            ld a,(xa_side)
            call xb_ptr
            ld a,(hl)
            cp G_BREAK
            jr z,.no
            cp G_FORKED
            jr z,.no
            ld b,a
            ld a,(xa_me)
            ld (xa_who),a
            ld a,b
            cp G_REV
            jr nz,.nr
            ld a,(xa_me)
            xor 3
            ld (xa_who),a
.nr:        push bc
            call xai_node
            pop bc
            ld d,a
            ld a,b
            cp G_FORK
            ld a,d
            jr nz,.done
            inc c
            push de
            call xai_node
            pop de
            add a,d
.done:      pop bc
            ret
.no:        pop bc
            ld a,$81
            ret

; node C taken by xa_who: A = value for xa_me
xai_node:
            ld hl,xn_lock
            ld a,l
            add a,c
            ld l,a
            jr nc,.n
            inc h
.n:         ld b,(hl)
            ld hl,xn_own
            ld a,l
            add a,c
            ld l,a
            jr nc,.n2
            inc h
.n2:        ld a,(hl)               ; current owner
            ld e,a
            ld a,b
            or a
            jr z,.free
            ld a,(xa_who)
            cp e
            jr z,.free
            xor a                   ; locked by the other: no effect
            ret
.free:      ld a,(xa_who)
            cp e
            jr nz,.chg
            ; already that owner: just refreshes the lock (worth 1 if ours
            ; and about to expire)
            ld a,b
            cp 12
            ld a,0
            ret nc
            ld a,(xa_me)
            cp e
            ld a,1
            ret z
            xor a
            ret
.chg:       ld a,(xa_me)
            ld d,a
            ld a,(xa_who)
            cp d
            ld a,2
            ret z                   ; we gain it
            ld a,e
            cp d
            ld a,-3
            ret z                   ; we would lose ours
            xor a
            ret

; demo: choose the side with more working lanes
xai_side:
            ld b,0
            ld d,0
            ld e,0
            ld hl,xb_gate
            ld c,LANES
.l:         ld a,(hl)
            cp G_BREAK
            jr z,.n
            cp G_FORKED
            jr z,.n
            inc d
.n:         push hl
            ld a,l
            add a,LANES
            ld l,a
            jr nc,.h
            inc h
.h:         ld a,(hl)
            pop hl
            cp G_BREAK
            jr z,.m
            cp G_FORKED
            jr z,.m
            inc e
.m:         inc hl
            dec c
            jr nz,.l
            ld a,d
            cp e
            ld a,0
            jr nc,.s
            inc a
.s:         ld (xc_side),a
            ret

; ---------------------------------------------------------------------
; drawing. Lane i: wire row 13+4i; nodes at columns 15-16, rows 12+4i..+2
LANE_Y0     equ 13

xd_all:
            ld a,$AA
            call fe_cls
            ld de,$0000             ; the header panel, rows 0-10
            ld bc,$200B
            ld a,3
            call fe_panel
            ; the two droids
            ld a,(xc_side)
            or a
            ld b,3
            jr z,.y
            ld b,112
.y:         ld c,2
            ld hl,SPRC
            call fe_spr
            ld a,(xc_side)
            or a
            ld b,112
            jr z,.e
            ld b,3
.e:         ld c,2
            ld hl,SPRC+$700
            call fe_spr
            ; the core: a red frame round the node column
            ld a,$FF
            ld (bf_cb),a
            ld c,11
.cv:        ld b,57
            call bf_plot
            ld b,70
            call bf_plot
            inc c
            ld a,c
            cp 60
            jr nz,.cv
            ld b,57
.ch:        ld c,11
            call bf_plot
            ld c,59
            call bf_plot
            inc b
            ld a,b
            cp 71
            jr nz,.ch
            call xd_header
            ld c,0
.l:         xor a
            call xd_lane
            ld a,1
            call xd_lane
            ld a,c
            push bc
            call xd_node
            pop bc
            inc c
            ld a,c
            cp LANES
            jr nz,.l
            ld a,(xc_choose)
            or a
            ret nz
            jp xd_meter

; the header's live part (between the droids): charges, seconds, the
; timer bar, YOU
xd_header:
            ld de,$0501
            ld bc,$1609
            ld a,$AA
            call fe_box
            ; charges
            ld a,(xc_side)
            or a
            ld d,5
            jr z,.c1
            ld d,21
.c1:        ld a,(xc_mych)
            ld b,1
            call xd_charges
            ld a,(xc_side)
            or a
            ld d,21
            jr z,.c2
            ld d,5
.c2:        ld a,(xc_ench)
            ld b,3
            call xd_charges
            ; time left: seconds, and a bar that runs down (red at the end)
            ld a,(xc_choose)
            or a
            jr nz,.choose
            ld hl,(xc_time)
            ld c,25
            call div_hl_c
            ld a,l
            ld de,t_buf
            call num3
            ld de,$0102
            call txt_colour
            ld hl,t_buf+1
            ld de,$0F02
            call fe_str
            ld hl,(xc_time)
            ld c,13
            call div_hl_c
            ld a,l
            or a
            jr z,.choose
            ld b,a
            ld a,(xc_time)
            cp 75
            ld a,$00
            jr nc,.bc
            ld a,$FF
.bc:        ld de,$0607
            ld c,2
            call fe_box
.choose:    ld de,$0002             ; "YOU" beside the time, on your side
            call txt_colour
            ld a,(xc_side)
            or a
            ld d,11
            jr z,.yu
            ld d,18
.yu:        ld e,2
            ld hl,you_txt
            jp fe_str
you_txt:    db "YOU",0

; the tug-of-war meter along the bottom (rows 60-62): yellow from the
; left for the left side's nodes, red from the right for the right's
xd_meter:
            ld b,LANES
            ld hl,xn_own
            ld de,0
.cn:        ld a,(hl)
            cp 1
            jr nz,.r
            inc d
.r:         cp 2
            jr nz,.n
            inc e
.n:         inc hl
            djnz .cn
            push de
            ld de,$043C
            ld bc,$1803
            ld a,$00
            call fe_box
            pop de
            push de
            ld a,d
            add a,a
            jr z,.nl
            ld b,a
            ld de,$043C
            ld c,3
            ld a,$55
            call fe_box
.nl:        pop de
            ld a,e
            add a,a
            ret z
            ld b,a
            ld a,28
            sub b
            ld d,a
            ld e,60
            ld c,3
            ld a,$FF
            jp fe_box

; A = charges, B = colour, D = column: a pip per charge (max 7)
xd_charges:
            cp 7
            jr c,.k
            ld a,6
.k:         or a
            ret z
            ld e,a
            ld hl,cfill
            ld a,l
            add a,b
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            and $3C                 ; two middle pixels
            ld c,a
            ld a,$AA
            and $C3
            or c
            ld c,a
            ld b,e
.p:         push bc
            push de
            ld e,3
            ld b,1
            ld a,c
            ld c,3
            call fe_box
            pop de
            pop bc
            inc d
            djnz .p
            ret

; choose-side prompt, along the bottom
xd_side:
            ld a,59
            ld b,5
            ld c,$AA
            call fe_rows
            ld de,$0102
            call txt_colour
            ld a,(xc_side)
            or a
            ld hl,side_l
            jr z,.s
            ld hl,side_r
.s:         ld e,59
            call fe_strc
            jp xd_header
side_l:     db "< YOUR SIDE: LEFT >",0
side_r:     db "< YOUR SIDE: RIGHT >",0

; draw lane C of side A (wire, gate, entry)
xd_lane:
            ld (xl_s),a
            push bc
            call xb_ptr
            ld a,(hl)
            ld (xl_g),a
            ; wire row
            ld a,c
            add a,a
            add a,a
            add a,LANE_Y0
            ld (xl_y),a
            ; side colour: left yellow, right red
            ld a,(xl_s)
            or a
            ld a,$55
            jr z,.c
            ld a,$FF
.c:         ld (xl_col),a
            ld a,(xl_s)             ; clear the whole lane row first (sparks
            or a                    ; cross the gap of a broken lane)
            ld d,1
            jr z,.cl
            ld d,17
.cl:        ld a,(xl_y)
            ld e,a
            ld bc,$0E01
            ld a,$AA
            call fe_box
            ld a,(xl_g)
            cp G_FORKED
            jp z,.forked
            ; the wire: columns 1-14 (left) or 17-30 (right)
            ld a,(xl_s)
            or a
            ld d,1
            jr z,.w
            ld d,17
.w:         ld b,14
            ld a,(xl_g)
            cp G_BREAK
            jr nz,.full
            ld b,7                  ; broken: half way, the outer half
            ld a,(xl_s)
            or a
            jr z,.full
            ld d,24
.full:      ld a,(xl_y)
            ld e,a
            ld c,1
            ld a,(xl_col)
            call fe_box
            ; the gate mark at columns 7 / 24
            ld a,(xl_s)
            or a
            ld d,7
            jr z,.g
            ld d,24
.g:         ld a,(xl_g)
            cp G_BREAK
            jr z,.brk
            cp G_BOOST
            jr z,.boost
            cp G_REV
            jr z,.rev
            cp G_FORK
            jr z,.fork
            jr .done
.brk:       ; an end cap where the wire stops
            ld a,(xl_s)
            or a
            ld d,8
            jr z,.b2
            ld d,23
.b2:        ld a,(xl_y)
            dec a
            ld e,a
            ld b,1
            ld c,3
            ld a,$99                ; blue/yellow end cap
            call fe_box
            jr .done
.boost:     ld hl,ic_boost          ; an amplifier: a yellow diamond
            jr .icon
.rev:       ld hl,ic_rev            ; a reverser: a green X
.icon:      ld a,(xl_y)
            dec a
            ld e,a
            ld b,3
.ir:        push bc
            push de
            push hl
            ld a,(hl)
            ld b,1
            ld c,1
            call fe_box
            pop hl
            pop de
            pop bc
            inc hl
            inc e
            djnz .ir
            jr .done
.fork:      ; a riser down to the next lane's wire
            ld a,(xl_y)
            ld e,a
            ld b,1
            ld c,5
            ld a,(xl_col)
            call fe_box
.done:      pop bc
            ret
.forked:    ; the inner half of the wire only
            ld a,(xl_s)
            or a
            ld d,7
            jr z,.f2
            ld d,17
.f2:        ld a,(xl_y)
            ld e,a
            ld b,8
            ld c,1
            ld a,(xl_col)
            call fe_box
            pop bc
            ret

ic_boost:   db $96,$55,$96
ic_rev:     db $28,$82,$28

; node A: its owner's colour (locked: solid; free: striped)
xd_node:
            ld c,a
            ld hl,xn_own
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            ld b,$00                ; neutral green
            cp 1
            jr nz,.r
            ld b,$55
.r:         cp 2
            jr nz,.k
            ld b,$FF
.k:         ld hl,xn_lock
            ld a,l
            add a,c
            ld l,a
            jr nc,.n2
            inc h
.n2:        ld a,(hl)
            or a
            ld a,b
            jr nz,.solid
            and $3C                 ; free: a band in the middle, blue sides
            or $82
.solid:     push af
            ld a,c
            add a,a
            add a,a
            add a,LANE_Y0-1
            ld e,a
            ld d,15
            ld b,2
            ld c,3
            pop af
            jp fe_box

; animate the pulses: a bright dash on each live lane
xd_pulses:
            xor a
            ld (xs_side),a
.sd:        ld c,0
.ln:        push bc
            ld a,(xs_side)
            call xp_ptr
            ld a,(de)
            or a
            jr z,.nl
            ; redraw the lane then the dash
            ld a,(xs_side)
            call xd_lane
            pop bc
            push bc
            ld a,(xs_side)
            call xp_ptr
            ld a,(de)               ; 1..16
            dec a
            srl a                   ; 0..7
            ld b,a
            ld a,(xs_side)
            or a
            jr z,.l
            ld a,29                 ; right side runs from column 29 inwards
            sub b
            sub b
            jr .p
.l:         ld a,b
            add a,a
            inc a                   ; column 1, 3 .. 15
.p:         ld d,a
            ld a,c
            add a,a
            add a,a
            add a,LANE_Y0
            ld e,a
            ld b,1
            ld c,1
            ld a,$00                ; a green spark on the wire
            call fe_box
.nl:        pop bc
            inc c
            ld a,c
            cp LANES
            jr nz,.ln
            ld a,(xs_side)
            inc a
            ld (xs_side),a
            cp 2
            jr nz,.sd
            ; your cursor: an arrow at the mouth of the lane
            ld a,(xc_side)
            or a
            ld d,0
            jr z,.cs
            ld d,31
.cs:        ld e,11
            ld b,1
            ld c,48
            ld a,$AA
            call fe_box
            ld a,(fe_frames)
            and 4
            ld a,$55
            jr z,.cc
            ld a,$00
.cc:        ld (bf_cb),a
            ld a,(xc_cur)
            add a,a
            add a,a
            add a,LANE_Y0
            ld c,a                  ; the wire row
            ld a,(xc_side)
            or a
            ld b,0
            ld d,1                  ; left: points right
            jr z,.ar
            ld b,127
            ld d,-1                 ; right: points left
.ar:        dec c
            call bf_plot
            inc c
            call bf_plot
            inc c
            call bf_plot
            dec c
            ld a,b
            add a,d
            ld b,a
            call bf_plot
            ld a,b
            add a,d
            ld b,a
            jp bf_plot

; ---- variables
xc_mycls:   ds 1
xc_ecls:    ds 1
xc_mych:    ds 1
xc_ench:    ds 1
xc_cur:     ds 1
xc_ecur:    ds 1
xc_side:    ds 1
xc_choose:  ds 1
xc_t:       ds 1
xc_time:    ds 2
xc_ait:     ds 1
xc_pait:    ds 1
xc_res:     ds 1
xf_s:       ds 1
xs_side:    ds 1
xa_own:     ds 1
xa_lock:    ds 1
xa_ch:      ds 1
xa_side:    ds 1
xa_me:      ds 1
xa_who:     ds 1
xa_best:    ds 1
xa_lane:    ds 1
xl_s:       ds 1
xl_g:       ds 1
xl_y:       ds 1
xl_col:     ds 1
xb_gate:    ds LANES*2
xn_own:     ds LANES
xn_lock:    ds LANES
xp_l:       ds LANES
xp_r:       ds LANES
