; ===================================================================
;  DAWN PATROL 2  -  frame rendering, HUD, minimap, demo pilot
; ===================================================================

render:
        call render_scenery     ; leaves bank W selected (sprites)
        MARK 5
        call check_ei
        call draw_stars
        ; the sun rises with the clock: 4:00 low behind the hills, 6:00 high
        ld a,(clock_min)
        ld b,6
        call div_b
        ld b,a
        ld a,26
        sub b
        ld c,32
        call draw_sun
        MARK 6
        call draw_campers
        call draw_objs
        call check_ei
        call draw_runners
        MARK 7
        call draw_heli
        call draw_pbul
        call draw_ebul
        call draw_parts
        call draw_arrows
        ld a,(demo)
        or a
        ret z
        ld a,(frame_ctr)
        and 16
        ret z
        ld hl,56
        ld a,2
        ld de,str_demo
        jp buf_print
str_demo: db "DEMO",0

div_b:  ; A = A / B
        ld c,0
.l:     cp b
        jr c,.d
        sub b
        inc c
        jr .l
.d:     ld a,c
        ret

; sprite A at world px HL, py E
spr_world:
        push af
        ld bc,(rcx)
        or a
        sbc hl,bc
        ld (spr_x),hl
        ld a,e
        ld (spr_y),a
        pop af
        jp draw_spr

STARS:  db 12,1, 40,4, 77,2, 101,7, 140,3, 166,0, 190,5, 222,2, 250,8, 30,8, 120,5, 205,1

draw_stars:
        ld a,(clock_min)
        cp 60
        ret nc
        ld b,a
        ld a,60
        sub b
        ld b,5
        call div_b
        or a
        ret z
        ld b,a
        ld hl,(rcx)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        ld (tmp),a
        ld hl,STARS
.l:     push bc
        push hl
        ld a,(frame_ctr)
        add a,b
        add a,b
        add a,b
        and 15
        jr z,.skip
        ld a,(tmp)
        ld c,a
        ld a,(hl)
        sub c
        and 127
        ld c,a
        inc hl
        ld e,(hl)
        ld a,(starbyte)
        ld d,a
        ld a,e
        call plot_nc
.skip:  pop hl
        inc hl
        inc hl
        pop bc
        djnz .l
        ret

; prisoners waving at the hut windows when you fly by
draw_campers:
        ld a,(hstate)
        cp HS_LANDED
        ret z
        ld hl,(heli_x)
        call div16
        ld (tmp+2),hl
        ld b,0
.l:     push bc
        ld hl,camp_cnt
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr z,.n
        ld hl,CAMPXTAB
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld de,(tmp+2)
        or a
        sbc hl,de
        ld de,90
        add hl,de
        ld a,h
        or a
        pop hl
        jr nz,.n
        ld a,l
        push hl
        ld hl,(tmp+2)
        pop hl
        ; inside 180px window?
        push hl
        ld de,(tmp+2)
        or a
        sbc hl,de
        ld de,90
        add hl,de
        ld a,l
        cp 180
        pop hl
        jr nc,.n
        push hl
        ld de,-15
        add hl,de
        ld a,(frame_ctr)
        and 8
        ld a,SPR_P_WAVE1
        jr z,.w1
        ld a,SPR_P_WAVE2
.w1:    ld e,GROUNDY-4
        call spr_world
        pop hl
        ld de,12
        add hl,de
        ld a,(frame_ctr)
        and 8
        ld a,SPR_P_WAVE2
        jr z,.w2
        ld a,SPR_P_WAVE1
.w2:    ld e,GROUNDY-4
        call spr_world
.n:     pop bc
        inc b
        ld a,b
        cp 4
        jr c,.l
        ret

; ------------------------------------------------------------------
draw_objs:
        ld ix,objs
        ld b,NOBJ
.l:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        ld a,(ix+O_FLASH)
        or a
        jr z,.nf
        ld a,1
.nf:    ld (draw_flash),a
        ; px position
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        call div16
        ld (tmp+2),hl
        ld de,(rcx)
        or a
        sbc hl,de
        ld de,24
        add hl,de
        ld a,h
        or a
        jr nz,.n
        ld a,l
        cp 160
        jr nc,.n
        ld l,(ix+O_YL)
        ld h,(ix+O_YH)
        call div16
        ld a,l
        ld (tmp+4),a
        ld a,(ix+O_TYPE)
        add a,a
        ld l,a
        ld h,0
        ld de,OBJDRAW-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
.n:     xor a
        ld (draw_flash),a
        ld de,OBJSZ
        add ix,de
        pop bc
        djnz .l
        ret

OBJDRAW: dw d_tank,d_jet,d_trans,d_plane,d_aa,d_sam,d_missile,d_gun
         dw d_balloon,d_crate,d_explo,d_flak,d_popup

; draw sprite A at (tmp+2),(tmp+4)
d_here:
        ld hl,(tmp+2)
        push af
        ld a,(tmp+4)
        ld e,a
        pop af
        jp spr_world

d_tank:
        ld a,(ix+O_ANIM)
        rrca
        rrca
        and 1
        ld b,a
        ld a,(ix+O_DIR)
        add a,a
        add a,b
        add a,SPR_TANK_L1
        jr d_here
d_jet:  ld a,(ix+O_DIR)
        add a,SPR_JET_L
        jr d_here
d_trans:
        ld a,(ix+O_DIR)
        add a,SPR_TRN_L
        jr d_here
d_plane:
        ld a,(ix+O_STATE)
        ld b,a
        ld a,(ix+O_DIR)
        or a
        ld a,b
        jr z,.t
        ld a,2
        sub b
.t:     add a,SPR_PLANE_S
        ld b,a
        ; centre: shift left by half width (3,5,7)
        sub SPR_PLANE_S
        add a,a
        add a,3
        ld e,a
        ld d,0
        ld hl,(tmp+2)
        or a
        sbc hl,de
        ld (tmp+2),hl
        ld a,b
        jr d_here
d_aa:   ld a,(ix+O_STATE)
        or a
        ld a,SPR_AAGUN
        jr z,d_here
        ld a,SPR_AAWRECK
        jr d_here
d_sam:  ld a,(ix+O_STATE)
        or a
        ld a,SPR_SAM
        jr z,d_here
        ld a,SPR_AAWRECK
        jr d_here
d_missile:
        ld a,(ix+O_DIR)
        add a,SPR_MIS_L
        jr d_here
d_gun:  ld a,(ix+O_DIR)
        add a,SPR_GUN_L
        call d_here
        ; rotor
        ld a,(ix+O_ANIM)
        and 3
        ld e,a
        ld d,0
        ld hl,ROTLEN
        add hl,de
        ld a,(hl)
        ld (tmp+5),a
        srl a
        ld e,a
        ld hl,(tmp+2)
        ld bc,6
        add hl,bc
        or a
        sbc hl,de
        ld bc,(rcx)
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        ld a,(tmp+4)
        dec a
        ld e,a
        ld a,(tmp+5)
        ld l,a
        ld a,3
        jp hline
d_balloon:
        ld a,SPR_BALLOON
        jp d_here
d_crate:
        ld a,(ix+O_STATE)
        or a
        jr z,.d
        ld a,(ix+O_TIMER)
        cp 60
        jr nc,.d
        ld a,(frame_ctr)
        and 2
        ret nz
.d:     ld a,SPR_CRATE
        jp d_here
d_explo:
        ld a,(ix+O_TIMER)
        ld b,3
        call div_b
        cp 4
        ret nc
        add a,SPR_EXP0
        jp d_here
d_flak: ld a,(ix+O_TIMER)
        and 1
        ret nz
        ld a,SPR_FLAK
        jp d_here
d_popup:
        ld a,(ix+O_AUX)
        add a,a
        ld e,a
        ld d,0
        ld hl,PUSTR
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(tmp+2)
        ld bc,(rcx)
        or a
        sbc hl,bc
        ld a,(tmp+4)
        jp buf_print

ROTLEN: db 15,11,5,11

; ------------------------------------------------------------------
draw_runners:
        ld ix,runners
        ld b,NRUN
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+1)
        ld h,(ix+2)
        call div16
        dec hl
        ld (tmp+2),hl
        ld a,GROUNDY-4
        ld (tmp+4),a
        ld a,(ix+0)
        cp R_WAIT
        jr z,.wave
        cp R_DEAD
        jr z,.dead
        ; running: frames 1 2 3 2
        ld a,(ix+4)
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,RUNSEQ
        add hl,de
        ld a,(hl)
        ld b,a
        ld a,(ix+5)
        or a
        ld a,b
        jr nz,.r
        add a,1                 ; L frames follow R frames
.r:     call d_here
        jr .n
.wave:  ld a,(ix+4)
        and 8
        ld a,SPR_P_WAVE1
        jr z,.w
        ld a,SPR_P_WAVE2
.w:     call d_here
        jr .n
.dead:  ld a,SPR_P_DEAD
        call d_here
.n:     ld de,RSZ
        add ix,de
        pop bc
        djnz .l
        ret
RUNSEQ: db SPR_P_R1,SPR_P_R2,SPR_P_R3,SPR_P_R2

; ------------------------------------------------------------------
draw_heli:
        ld a,(hstate)
        cp HS_DEAD
        ret z
        cp HS_DYING
        jr z,.vis
        ld a,(hinv)
        or a
        jr z,.vis
        ld a,(frame_ctr)
        and 2
        ret nz
.vis:   ld a,(hit_flash)
        and 2
        ld (draw_flash),a
        ; choose frame (index from SPR_HELI_L0)
        ld a,(hstate)
        cp HS_DYING
        jr nz,.nd
        ld a,(htimer)           ; spinning out of control
        and 4
        ld a,2
        jr z,.fr
        ld a,6
        jr .fr
.nd:    ld a,(hturn)
        or a
        jr z,.sl
        cp 4
        jr z,.sr
        add a,7                 ; 1->8 LQ, 2->9 F, 3->10 RQ
        jr .fr
.sl:    ld a,(htilt)
        jr .fr
.sr:    ld a,(htilt)
        add a,4
.fr:    ld (hf_frame),a
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl               ; *6
        ld de,HELI_META
        add hl,de
        ld (hf_meta),hl
        ; sprite position
        ld e,(hl)
        ld d,0
        ld hl,(heli_x)
        call div16
        or a
        sbc hl,de
        ld (hf_x),hl
        ld hl,(heli_y)
        call div16
        ld a,l
        sub 6
        ld (hf_y),a
        ld e,a
        ld a,(hf_frame)
        add a,SPR_HELI_L0
        ld hl,(hf_x)
        call spr_world
        xor a
        ld (draw_flash),a
        ld a,(hstate)
        cp HS_DYING
        ret z
        ; windscreen glint
        ld a,(glint_t)
        or a
        jr z,.ng
        ld ix,(hf_meta)
        ld hl,(hf_x)
        ld e,(ix+3)
        ld d,0
        add hl,de
        ld de,(rcx)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,(hf_y)
        add a,(ix+4)
        ld e,a
        ld a,(glint_col)
        call plot
.ng:    ; rotor: tilted with the body, tips drooping
        ld ix,(hf_meta)
        ld a,(ix+5)
        ld (hf_slope),a
        ld hl,(hf_x)
        ld e,(ix+1)
        ld d,0
        add hl,de
        ld de,(rcx)
        or a
        sbc hl,de
        ld (hf_hub),hl
        ld a,(hf_y)
        add a,(ix+2)
        dec a
        ld (hf_ry),a
        ld a,(hrotor)
        and 3
        ld e,a
        ld d,0
        ld hl,ROTLEN
        add hl,de
        ld a,(hl)
        ld (hf_len),a
        srl a
        ld (hf_half),a
        neg
        ld (hf_d),a
        ld a,(hrotor)
        and 1
        ld a,(pb_col)
        jr z,.rc
        ld a,(rot_col2)
.rc:    ld (hf_col),a
        ld a,(hf_len)
        ld b,a
.rl:    push bc
        ; dy = (d * slope) / 8, plus a droop at the tips of long blades
        ld a,(hf_slope)
        ld c,a
        ld a,(hf_d)
        ld e,a
        xor a
        bit 7,c
        jr z,.mp
        ld b,a
        sub c
        ld c,a
        ld a,b
.ml:    sub e
        dec c
        jr nz,.ml
        jr .md
.mp:    inc c
        dec c
        jr z,.md
.ma:    add a,e
        dec c
        jr nz,.ma
.md:    sra a
        sra a
        sra a
        ld c,a
        ld a,(hf_len)
        cp 11
        jr c,.nodr
        ld a,(hf_d)
        call abs8
        ld b,a
        ld a,(hf_half)
        cp b
        jr nz,.nodr
        inc c
.nodr:  ld a,(hf_ry)
        add a,c
        ld e,a
        ld a,(hf_d)
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld bc,(hf_hub)
        add hl,bc
        ld b,h
        ld c,l
        ld a,(hf_col)
        call plot
        ld hl,hf_d
        inc (hl)
        pop bc
        djnz .rl
        ret

hf_frame db 0
hf_meta  dw 0
hf_x     dw 0
hf_y     db 0
hf_hub   dw 0
hf_ry    db 0
hf_len   db 0
hf_half  db 0
hf_d     db 0
hf_slope db 0
hf_col   db 0
glint_col db 1

; ------------------------------------------------------------------
draw_pbul:
        ld ix,pbul
        ld b,NPB
.l:     ld a,(ix+0)
        or a
        jr z,.n
        push bc
        call bul_screen
        ld a,(pb_col)
        push bc
        push de
        call plot
        pop de
        pop bc
        ld a,(ix+7)
        or a
        jr z,.side
        dec e
        jr .p
.side:  bit 7,(ix+5)
        jr z,.l2
        inc bc
        jr .p
.l2:    dec bc
.p:     ld a,(pb_col)
        call plot
        pop bc
.n:     ld de,BSZ
        add ix,de
        djnz .l
        ret

; bullet IX -> BC screen x, E py
bul_screen:
        ld l,(ix+1)
        ld h,(ix+2)
        call div16
        ld de,(rcx)
        or a
        sbc hl,de
        push hl
        ld l,(ix+3)
        ld h,(ix+4)
        call div16
        ld e,l
        pop bc
        ret

draw_ebul:
        ld ix,ebul
        ld b,NEB
.l:     ld a,(ix+0)
        or a
        jr z,.n
        push bc
        call bul_screen
        ld a,(eb_col)
        push bc
        push de
        call plot
        pop de
        pop bc
        ld a,(ix+7)
        cp 2
        jr z,.bomb
        inc bc
        jr .p
.bomb:  dec e
.p:     ld a,(eb_col)
        call plot
        pop bc
.n:     ld de,BSZ
        add ix,de
        djnz .l
        ret

draw_parts:
        ld ix,parts
        ld b,NPART
.l:     ld a,(ix+0)
        or a
        jr z,.n
        push bc
        call bul_screen
        ld a,(ix+7)
        and 3
        call plot
        pop bc
.n:     ld de,PSZ
        add ix,de
        djnz .l
        ret

; warning markers for aircraft approaching from off-screen
draw_arrows:
        ld a,(frame_ctr)
        and 4
        ret z
        ld ix,objs
        ld b,NOBJ
.l:     push bc
        ld a,(ix+O_TYPE)
        cp OT_JET
        jr z,.chk
        cp OT_TRANS
        jr z,.chk
        cp OT_GUNSHIP
        jr z,.chk
        cp OT_MISSILE
        jr nz,.n
.chk:   call obj_sx
        ld de,(rcx)
        ld bc,(camx)
        add hl,bc
        or a
        sbc hl,de               ; relative to render cam
        bit 7,h
        jr z,.right
        ld de,100
        add hl,de
        bit 7,h
        jr nz,.n
        ld hl,1
        jr .draw
.right: ld de,128
        or a
        sbc hl,de
        jr c,.n
        ld de,100
        sbc hl,de
        jr nc,.n
        ld hl,124
.draw:  ld (spr_x),hl
        ld l,(ix+O_YL)
        ld h,(ix+O_YH)
        call div16
        ld a,l
        ld (spr_y),a
        ld a,SPR_ARROW_L
        call draw_spr
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .l
        ret

; ------------------------------------------------------------------
; text into the back buffer (transparent). HL = screen x, A = py, DE = string
; ------------------------------------------------------------------
buf_print:
        ld (tmp+5),a
        ld bc,32
        add hl,bc
        bit 7,h
        ret nz
        ld a,h
        or a
        ret nz
        ld a,l
        srl a
        srl a
        ld (tmp+6),a            ; column
.c:     ld a,(de)
        or a
        ret z
        inc de
        push de
        ld c,a
        ld a,(tmp+6)
        cp 44
        jr nc,.skip
        ld a,(tmp+5)
        add a,BTOP
        cp 59
        jr nc,.skip
        add a,a
        ld l,a
        ld h,BROW/256
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,(tmp+6)
        add a,e
        ld e,a
        jr nc,.nc
        inc d
.nc:    ld a,c
        sub 32
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        ld bc,FONT
        add hl,bc               ; glyph
        ld b,3
.g:     ld a,(hl)
        inc hl
        push af
        rrca
        rrca
        rrca
        rrca
        call .wr
        pop af
        dec b
        jr z,.skip
        call .wr
        jr .g
.skip:  pop de
        ld hl,tmp+6
        inc (hl)
        jr .c
.wr:    push hl
        and 15
        ld l,a
        ld h,0
        push bc
        ld bc,N2M
        add hl,bc
        pop bc
        ld a,(hl)
        ld c,a
        cpl
        ex de,hl
        and (hl)
        ld (hl),a
        ld a,(pop_pat)
        and c
        or (hl)
        ld (hl),a
        ld a,l
        add a,BSTR
        ld l,a
        jr nc,.n2
        inc h
.n2:    ex de,hl
        pop hl
        ret

pb_col  db 1
rot_col2 db 3
eb_col  db 3

; ------------------------------------------------------------------
; HUD (rows 0..6 of VRAM, drawn directly)
; ------------------------------------------------------------------
hud_init:
        ld a,3
        call colbyte
        ld b,0
        ld c,6
        call vfill
        ld a,(skycol)
        ld b,a
        ld a,1
        cp b
        ld a,1
        jr nz,.pc
        ld a,3
.pc:    ld (pb_col),a
        ld a,(skycol)
        cp 1
        ld a,3
        jr nz,.ec
        ld a,2
.ec:    ld (eb_col),a
        ld a,(skycol)
        cp 1
        ld a,3
        jr nz,.r2
        xor a
.r2:    ld (rot_col2),a

        ld a,(pb_col)
        call colbyte
        ld (pop_pat),a
        ld (draw_spr.fpat+1),a
        ld a,1
        ld c,3
        call set_txt
        ld b,6
        ld c,1
        ld a,(skybyte)
        call vfill
        ld b,1
        ld c,7
        call vaddr
        ld a,'%'
        call putc
        ld b,1
        ld c,17
        call vaddr
        ld a,'@'
        call putc
        ld b,1
        ld c,25
        call vaddr
        ld a,'^'
        call putc
        ld b,1
        ld c,29
        call vaddr
        ld a,':'
        call putc
        xor a
        ld (hud_step_n),a
        ld a,1
        ld (hud_force),a
        ld b,6
.all:   push bc
        call hud_step
        pop bc
        djnz .all
        xor a
        ld (hud_force),a
        call minimap
        ret

hud_step:
        ld a,(hud_step_n)
        inc a
        cp 6
        jr c,.s
        xor a
.s:     ld (hud_step_n),a
        ; skip fields that have not changed
        ld e,a
        ld d,0
        ld hl,hud_last
        add hl,de
        push hl
        call hud_value
        pop hl
        cp (hl)
        jr nz,.chg
        ld a,(hud_force)
        or a
        ret z
.chg:   ld (hl),a
        ld a,1
        ld c,3
        call set_txt
        ld a,(hud_step_n)
        or a
        jr z,.score
        dec a
        jr z,.fuel
        dec a
        jr z,.aboard
        dec a
        jp z,.armour
        dec a
        jp z,.lives
        ; time  H:MM
        ld b,1
        ld c,28
        call vaddr
        ld a,(clock_min)
        ld c,4
.h:     cp 60
        jr c,.hd
        sub 60
        inc c
        jr .h
.hd:    push af
        ld a,c
        add a,'0'
        call putc
        inc hl
        pop af
        jp print_dec2
.score: ld b,1
        ld c,0
        call vaddr
        ld de,score
        ld b,3
        jp print_bcd
.aboard:
        ld b,1
        ld c,18
        call vaddr
        ld a,(aboard)
        cp CAPACITY
        jr nz,.ab
        ld a,(frame_ctr)
        and 8
        jr z,.ab2
        ld a,0
        ld c,3
        push hl
        call set_txt
        pop hl
.ab2:   ld a,(aboard)
.ab:    jp print_dec2
.fuel:  ; bar in columns 8..15 (32 px) rows 2..4
        ld hl,(fuel)
        ld de,250
        ld c,0
.fd:    or a
        sbc hl,de
        jr c,.fe
        inc c
        jr .fd
.fe:    ld a,c                  ; 0..32 px
        ld (tmp),a
        ; colour: green, or flashing yellow/red when low
        ld b,0
        cp 7
        jr nc,.fc
        ld a,(frame_ctr)
        and 4
        ld b,1
        jr z,.fc
        ld b,2
.fc:    ld a,b
        call colbyte
        ld (tmp+1),a
        ld a,3
        call colbyte
        ld (tmp+2),a
        ld b,2
        ld c,8
        call vaddr
        ld b,8
.fb:    push bc
        ld a,(tmp)
        cp 4
        jr c,.part
        sub 4
        ld (tmp),a
        ld a,4
        jr .px
.part:  ld c,a
        xor a
        ld (tmp),a
        ld a,c
.px:    push hl
        ld e,a
        ld d,0
        ld hl,FILLM
        add hl,de
        ld c,(hl)
        pop hl
        ld a,(tmp+1)
        and c
        ld d,a
        ld a,c
        cpl
        ld e,a
        ld a,(tmp+2)
        and e
        or d
        or $00
        ; three rows
        ld (hl),a
        ld de,32
        add hl,de
        ld (hl),a
        add hl,de
        ld (hl),a
        ld de,-63
        add hl,de
        pop bc
        djnz .fb
        ret
.armour:
        ld b,1
        ld c,21
        call vaddr
        ld b,3
        ld c,0
.ar:    push bc
        push hl
        ld a,(armour)
        cp b
        ld a,1
        jr nc,.ac
        ld a,2
.ac:    ld c,3
        call set_txt
        pop hl
        ld a,'&'
        call putc
        pop bc
        djnz .ar
        ret
.lives: ld b,1
        ld c,26
        call vaddr
        ld a,(lives)
        add a,'0'
        jp putc

FILLM:  db $00,$C0,$F0,$FC,$FF

hud_last  ds 6
hud_force db 1
; A = signature of HUD field E (changes when the field needs redrawing)
hud_value:
        ld a,e
        or a
        jr nz,.v1
        ld a,(score+2)
        ld hl,score+1
        add a,(hl)
        ret
.v1:    dec a
        jr nz,.v2
        ld hl,(fuel)
        ld a,h
        cp 1+(MAXFUEL/5)/256
        ret nc
        ld a,(frame_ctr)        ; flashing when low
        and 4
        or h
        ret
.v2:    dec a
        jr nz,.v3
        ld a,(aboard)
        cp CAPACITY
        ret nz
        ld a,(frame_ctr)
        and 8
        or CAPACITY
        ret
.v3:    dec a
        jr nz,.v4
        ld a,(armour)
        ret
.v4:    dec a
        jr nz,.v5
        ld a,(lives)
        ret
.v5:    ld a,(clock_min)
        ret

hud_pause:
        ld hl,48
        ld a,24
        ld de,str_paused
        jp buf_print
str_paused: db "PAUSED",0

; ------------------------------------------------------------------
; minimap: rows 61..63
; ------------------------------------------------------------------
minimap:
        ld a,(mapbg)
        call colbyte
        ld b,61
        ld c,3
        call vfill
        ; base
        ld hl,PADX0+12
        ld e,62
        ld d,1
        call vplot_w
        ld hl,PADX0+14
        ld e,63
        ld d,1
        call vplot_w
        ld hl,HANGARX
        ld e,63
        ld d,1
        call vplot_w
        ; camps
        ld b,0
.c:     push bc
        ld e,b
        ld d,0
        ld hl,camp_cnt
        add hl,de
        ld a,(hl)
        or a
        jr z,.cn
        ld hl,camp_lock
        add hl,de
        ld a,(hl)
        or a
        ld d,3
        jr z,.cc
        ld a,(frame_ctr)
        and 8
        jr z,.cn
.cc:    ld hl,CAMPXTAB
        ld e,b
        ld a,d
        ld d,0
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld d,a
        push hl
        ld e,62
        call vplot_w
        pop hl
        push hl
        ld e,63
        ld d,3
        call vplot_w
        pop hl
        inc hl
        inc hl
        inc hl
        ld e,63
        ld d,3
        call vplot_w
.cn:    pop bc
        inc b
        ld a,b
        cp 4
        jr c,.c
        ; enemies
        ld ix,objs
        ld b,NOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.on
        cp OT_EXPLO
        jr nc,.on
        cp OT_PLANE3D
        jr z,.on
        ld e,61
        cp OT_TANK
        jr nz,.oe
        ld e,63
.oe:    ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        call div16
        ld d,2
        ld a,(mapbg)
        cp 2
        jr nz,.od
        ld d,3
.od:    call vplot_w
.on:    ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ; heli
        ld a,(frame_ctr)
        and 4
        ret z
        ld hl,(heli_x)
        call div16
        ld e,61
        ld d,1
        call vplot_w
        ld hl,(heli_x)
        call div16
        ld e,62
        ld d,1
        jp vplot_w

; plot world px HL on minimap row E colour D  (x*21/128)
vplot_w:
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        push hl                 ; 4x
        add hl,hl
        add hl,hl               ; 16x
        add hl,de
        pop de
        add hl,de               ; 21x
        add hl,hl               ; /128 -> h
        ld c,h
        pop de
        ld a,c
        cp 128
        ret nc
; VRAM plot: C = x, E = row, D = colour
vplot:
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        rrca
        rrca
        and $3F
        add a,l
        ld l,a
        ld a,h
        adc a,VRAM/256
        ld h,a
        ld a,c
        and 3
        ld c,a
        push hl
        ld a,d
        add a,a
        add a,a
        add a,c
        ld e,a
        ld d,0
        ld hl,PIXT
        add hl,de
        ld d,(hl)
        ld e,c
        ld a,d
        ld d,0
        ld hl,PIXT+16
        add hl,de
        ld e,a
        ld a,(hl)
        pop hl
        and (hl)
        or e
        ld (hl),a
        ret

; ------------------------------------------------------------------
; attract-mode pilot. Returns NZ to abort the demo.
; ------------------------------------------------------------------
demo_input:
        ld a,(in_cur)
        or a
        ret nz                  ; a real key ends the demo
        call any_key
        ret nz
        ld hl,(demo_t)
        dec hl
        ld (demo_t),hl
        ld a,h
        or l
        jr nz,.go
        inc a
        ret
.go:    ; choose a target
        ld a,(aboard)
        cp 8
        jr nc,.base
        ld hl,(fuel)
        ld de,MAXFUEL/4
        or a
        sbc hl,de
        jr c,.base
        ; nearest camp with prisoners (scan from base outward)
        ld b,4
        ld hl,camp_cnt+3
        ld de,CAMPXTAB+6
.fc:    ld a,(hl)
        or a
        jr nz,.gotc
        dec hl
        dec de
        dec de
        djnz .fc
        ld a,(aboard)
        or a
        jr nz,.base
        ld hl,PADX0+12
        jr .tgt
.gotc:  ex de,hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .tgt
.base:  ld hl,PADX0+12
.tgt:   ld (tmp+6),hl
        ld c,0
        ; landed?
        ld a,(hstate)
        cp HS_LANDED
        jr nz,.fly
        ; wait while prisoners board / unload
        ld a,(heading)
        or a
        jr nz,.out
        ld a,(land_t)
        cp 50
        jr c,.out
        call .dx
        ld a,h
        or a
        jr nz,.up
        ld a,l
        cp 20
        jr c,.out
.up:    set IN_UP,c
        jr .out
.fly:   call .dx
        ld a,h
        or a
        jr nz,.far
        ld a,l
        cp 6
        jr nc,.far
        set IN_DOWN,c
        jr .fire
.far:   ; cruise altitude 20
        push hl
        ld hl,(heli_y)
        call div16
        ld a,l
        pop hl
        cp 24
        jr c,.alt
        set IN_UP,c
.alt:   ld a,(tmp+5)
        or a
        jr z,.r
        set IN_LEFT,c
        jr .fire
.r:     set IN_RIGHT,c
.fire:  ; shoot now and then, face the way we fly
        ld a,(frame_ctr)
        and 7
        jr nz,.face
        set IN_FIRE,c
.face:  ld a,(hface)
        cp 1
        jr z,.rot
        ld b,a
        ld a,(tmp+5)
        or a
        ld a,0
        jr nz,.fw
        ld a,2
.fw:    cp b
        jr z,.out
.rot:   ld a,(frame_ctr)
        and 3
        jr nz,.out
        set IN_ROT,c
.out:   ld a,(in_prev)
        cpl
        and c
        ld (in_edge),a
        ld a,c
        ld (in_cur),a
        xor a
        ret
.dx:    ; |target - heli| -> HL, (tmp+5) = 1 if target left
        ld hl,(heli_x)
        call div16
        ex de,hl
        ld hl,(tmp+6)
        or a
        sbc hl,de
        ld a,0
        jr nc,.dp
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        ld a,1
.dp:    ld (tmp+5),a
        ret
