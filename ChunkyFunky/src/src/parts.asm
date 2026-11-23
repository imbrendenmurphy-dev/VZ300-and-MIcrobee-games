; =====================================================================
;  parts.asm - the seven parts. Each has an init (called once, any time)
;  and a frame routine (called at the start of field sync, then the music
;  plays in whatever time is left of the 70,630 T field).
; =====================================================================

; ===================================================================== 1 TITLE
; The CHUNKY / FUNKY logo dissolves in, colour-cycles, and dissolves out.
VIS         equ WORK                    ; 256 bytes: the logo cells shown now

t_init:
            xor a
            call set_latch
            ld a,$80
            call cls0
            ld hl,VIS
            ld de,VIS+1
            ld bc,255
            ld (hl),0
            ldir
            ld a,1
            ld (lfsr),a
            ld hl,0
            ld (tw_ptr),hl
            ret

t_frame:
            ld hl,(ptime)
            ld a,h
            or a
            jr nz,.notin
            ld a,l
            sub 24
            jr c,.notin
            cp 64
            jr nc,.notin
            or a
            jr nz,.in4
            ld a,(logo)                 ; cell 0 (the sequence never gives 0)
            ld (VIS),a
.in4:       ld b,4
.inl:       call lfsr_next
            ld l,a
            ld h,HIGH(logo)
            ld a,(hl)
            ld h,HIGH(VIS)
            ld (hl),a
            djnz .inl
            jr .draw
.notin:     ld de,672                   ; dissolve out in bars 8
            or a
            sbc hl,de
            jr c,.draw
            ld a,h
            or a
            jr nz,.draw
            ld a,l
            cp 64
            jr nc,.wipe
            ld b,4
.outl:      call lfsr_next
            ld l,a
            ld h,HIGH(VIS)
            ld (hl),0
            djnz .outl
            jr .draw
.wipe:      cp 64                       ; then the words go
            jr nz,.draw
            xor a
            ld (VIS),a
            ld hl,VRAM+11*32
            ld de,VRAM+11*32+1
            ld bc,5*32-1
            ld (hl),$80
            ldir
.draw:
            ld hl,(ptime)               ; the words start typing at field 100
            ld de,100
            or a
            sbc hl,de
            ld a,h
            or l
            jr nz,.notw
            ld hl,tw_title
            call tw_start
.notw:      call tw_step
            ld a,(ptime)
            rrca
            rrca
            and $3F
            ld c,a                      ; colour phase
            ld de,VIS
            ld hl,VRAM+2*32
            ld b,8
.row:       push bc
            push hl
            ld a,c
            add a,b
            and 7
            ld hl,rainbow
            add a,l
            ld l,a
            jr nc,.nc
            inc h
.nc:        ld c,(hl)
            pop hl
            REPT 32
            ld a,(de)
            or c
            ld (hl),a
            inc e
            inc hl
            ENDR
            pop bc
            dec b
            jp nz,.row
            ret

; ===================================================================== 2 PLASMA
; 32x15 cells of semigraphic plasma (8 colours + half-tones) and a text crawl.
; CX: column terms, 8 copies of 32 (page aligned, in the variables)

pl_init:
            xor a
            ld (st_ready),a
            call set_latch
            ld a,$80
            call cls0
            ld hl,pl_text
            ld (scr_ptr),hl
            ld a,1
            ld (scr_cnt),a
            ret

pl_frame:
            ld a,(ptime)
            ld b,a
            add a,a
            ld e,a                      ; e = 2t
            add a,b
            ld d,a                      ; d = 3t
            ld hl,CX
            ld b,32
.cx:        push hl
            ld h,HIGH(sintab)
            ld l,e
            ld a,(hl)
            sra a
            sra a
            sra a
            ld c,a
            ld l,d
            ld a,(hl)
            sra a
            sra a
            sra a
            add a,c
            pop hl
            ld (hl),a
            inc l
            ld a,e
            add a,5
            ld e,a
            ld a,d
            add a,9
            ld d,a
            djnz .cx
            ld hl,CX
            ld de,CX+32
            ld bc,224
            ldir
            ld a,(ptime)
            ld (pl_b1),a
            add a,a
            neg
            ld (pl_b2),a
            ld hl,VRAM
            ld b,15
.row:       push bc
            push hl
            ld h,HIGH(sintab)
            ld a,(pl_b1)
            ld l,a
            add a,11
            ld (pl_b1),a
            ld c,(hl)
            sra c
            sra c
            sra c
            ld a,(pl_b2)
            ld l,a
            add a,14
            ld (pl_b2),a
            ld a,(hl)
            sra a
            sra a
            sra a
            add a,c
            ld c,a
            ld a,(ptime)
            add a,c
            ld ixl,a
            pop hl
            ld d,HIGH(CX)
            ld b,HIGH(pl_ctab)
            REPT 32
            ld e,l
            ld a,(de)
            add a,ixl
            ld c,a
            ld a,(bc)
            ld (hl),a
            inc l
            ENDR
            ld a,l
            or a
            jr nz,.nw
            inc h
.nw:        pop bc
            dec b
            jp nz,.row
            ld hl,(ptime)               ; last 40 fields: make the star table
            ld de,768-40
            or a
            sbc hl,de
            call nc,st_genrow
; the text crawl on the bottom row
crawl:
            ld hl,scr_cnt
            dec (hl)
            ret nz
            ld (hl),6
            ld hl,VRAM+15*32+1
            ld de,VRAM+15*32
            ld bc,31
            ldir
            ld hl,(scr_ptr)
            ld a,(hl)
            cp $FF
            jr nz,.c
            ld hl,pl_text
            ld a,(hl)
.c:         inc hl
            ld (scr_ptr),hl
            ld (VRAM+15*32+31),a
            ret

; ===================================================================== 3 STARS
; 3D starfield on mode 1, colour by depth, speeding up to warp.
NSTAR       equ 56
star_proj   equ WORK                    ; built by st_init
SBG         equ $AA                     ; blue

st_init:
            ld a,$08
            call set_latch
            ld a,SBG
            call cls1
            ld ix,stars
            ld b,NSTAR
.l:         call st_new
            call rnd
            or 8
            ld (ix+2),a
            ld de,6
            add ix,de
            djnz .l
            ld hl,st_label
            ld de,VRAM+56*32+2
            call draw_str1
            ld a,(st_ready)             ; the table is normally made during the plasma
            cp 31
            ret z
st_genall:  call st_genrow
            ld a,(st_ready)
            cp 31
            jr nz,st_genall
            ret

; st_genrow: one row of star_proj (in WORK): depth st_ready+1, 64 values of v*8/depth
; (v = -32..31), $80 = off screen. 31 rows in all; st_ready counts them.
st_genrow:
            ld a,(st_ready)
            cp 31
            ret z
            inc a
            ld (st_ready),a
            ld c,a
            dec a
            ld l,a                      ; row address = WORK + 32 + (depth-1)*64
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,WORK+32
            add hl,de
            ld (st_row),hl
            ld hl,2048
            call div_hl_c               ; 8/depth in 8.8
            ld (st_step),hl
            ld ix,(st_row)
            ld iy,(st_row)
            ld hl,128                   ; rounding
            ld b,0
.v:         ld a,h
            cp 64
            ld a,h
            jr c,.ok
            ld a,$80
.ok:        ld (ix+0),a                 ; +v
            cp $80
            jr z,.neg
            neg
.neg:       ld (iy+0),a                 ; -v
            inc ix
            dec iy
            ld de,(st_step)
            add hl,de
            jr nc,.nc
            ld h,$FF                    ; stays off screen
.nc:        inc b
            ld a,b
            cp 33
            jr nz,.v
            ret

; div_hl_c: HL = HL / C (C < 128)
div_hl_c:
            xor a
            ld b,16
.l:         add hl,hl
            rla
            cp c
            jr c,.n
            sub c
            inc l
.n:         djnz .l
            ret

st_new:                                 ; a star at the far end
            call rnd
            and 63
            ld (ix+0),a
            call rnd
            and 31
            add a,16
            ld (ix+1),a
            ld (ix+2),255
            ld (ix+5),0
            ret

st_frame:
            ld hl,(ptime)
            add hl,hl
            ld a,h                      ; t / 128
            add a,2
            cp 8
            jr c,.s
            ld a,7
.s:         ld (st_speed),a
            ld ix,stars
            ld b,NSTAR
.l:         push bc
            ld a,(ix+5)                 ; rub out the old dot
            or a
            jr z,.ne
            ld c,a
            ld l,(ix+3)
            ld h,(ix+4)
            ld a,(hl)
            xor SBG
            and c
            xor (hl)
            ld (hl),a
            ld (ix+5),0
.ne:        ld a,(ix+2)
            ld hl,st_speed
            sub (hl)
            jr c,.respawn
            cp 8
            jr nc,.ok
.respawn:   call st_new
            jp .next
.ok:        ld (ix+2),a
            and $F8                     ; z index * 8
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl                   ; z index * 64
            ld de,star_proj-64
            add hl,de
            push hl
            ld e,(ix+0)
            ld d,0
            add hl,de
            ld a,(hl)
            pop hl
            cp $80
            jr z,.respawn
            add a,64
            ld c,a                      ; screen x
            ld e,(ix+1)
            add hl,de
            ld a,(hl)
            add a,32
            cp 56                       ; keep off the label rows
            jr nc,.respawn
            call row1
            ld a,c
            rrca
            rrca
            and 31
            or l
            ld l,a
            ld (ix+3),l
            ld (ix+4),h
            ld a,c
            and 3
            ld e,a
            ld d,0
            push hl
            ld hl,pmask
            add hl,de
            ld c,(hl)
            pop hl
            ld (ix+5),c
            ld a,(ix+2)
            ld e,$55                    ; near: yellow
            cp 80
            jr c,.col
            ld e,$00                    ; middle: green
            cp 160
            jr c,.col
            ld e,$FF                    ; far: red
.col:       ld a,(hl)
            xor e
            and c
            xor (hl)
            ld (hl),a
.next:      ld de,6
            add ix,de
            pop bc
            dec b
            jp nz,.l
            ret

; ===================================================================== 4 CUBE
; A wireframe cube with perspective, mode 1 colour set 1.
CU_S        equ 18                      ; half size
CU_CY       equ 27                      ; screen centre row
CBG         equ $AA                     ; magenta

cu_init:
            ld a,$18
            call set_latch
            ld a,CBG
            call cls1
            ld hl,WORK                  ; the back buffer
            ld a,CBG
            call fill2k
            ld hl,cu_label
            ld de,VRAM+56*32+1
            call draw_str1
            call cu_compute
            call cu_bbox
            ld hl,cu_nx0
            ld de,cu_ox0
            ld bc,4
            ldir
            ret

; Two fields a picture (25 Hz), drawn off screen in WORK:
;  even: copy the changed box to the screen (in the sync gap, ahead of the beam),
;        clear the box in WORK, work out the next corners
;  odd:  draw the edges into WORK
cu_frame:
            ld a,(ptime)
            rrca
            jp c,cu_edges
            call cu_copy
            ld hl,cu_nx0
            ld de,cu_ox0
            ld bc,4
            ldir
            call cu_clear
            call cu_compute
            jp cu_bbox

; cu_copy: WORK -> screen over the union of the old and new boxes
cu_copy:
            ld hl,cu_ox0
            ld de,cu_nx0
            ld a,(de)                   ; x0 = min
            cp (hl)
            jr c,.x0
            ld a,(hl)
.x0:        ld (cu_ux0),a
            inc hl
            inc de
            ld a,(de)                   ; x1 = max
            cp (hl)
            jr nc,.x1
            ld a,(hl)
.x1:        ld (cu_ux1),a
            inc hl
            inc de
            ld a,(de)                   ; y0 = min
            cp (hl)
            jr c,.y0
            ld a,(hl)
.y0:        ld (cu_uy0),a
            inc hl
            inc de
            ld a,(de)                   ; y1 = max
            cp (hl)
            jr nc,.y1
            ld a,(hl)
.y1:        ld hl,cu_uy0
            sub (hl)
            inc a
            ld (cu_rows),a
            ld a,(cu_ux0)
            ld b,a
            ld a,(cu_ux1)
            sub b
            inc a
            add a,a
            ld e,a
            ld d,0
            ld hl,ldi_end
            or a
            sbc hl,de
            ld (.jp+1),hl
            ld a,(cu_uy0)
            call row1
            ld a,(cu_ux0)
            or l
            ld l,a
            ld d,h
            ld e,l                      ; DE = screen
            ld a,h
            add a,HIGH(WORK)-HIGH(VRAM)
            ld h,a                      ; HL = WORK
.r:         push hl
            push de
.jp:        call 0
            pop hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop hl
            add hl,bc
            ld a,(cu_rows)
            dec a
            ld (cu_rows),a
            jr nz,.r
            ret
ldi_chain:
            REPT 32
            ldi
            ENDR
ldi_end:    ret

; cu_clear: the new box in WORK back to the background
cu_clear:
            ld a,(cu_nx1)
            ld hl,cu_nx0
            sub (hl)
            inc a
            add a,a
            ld e,a
            ld d,0
            ld hl,fill_end
            or a
            sbc hl,de
            ld (.jp+1),hl
            ld a,(cu_ny1)
            ld hl,cu_ny0
            sub (hl)
            inc a
            ld b,a
            ld a,(hl)
            call row1
            ld a,(cu_nx0)
            or l
            ld l,a
            ld a,h
            add a,HIGH(WORK)-HIGH(VRAM)
            ld h,a
            ld de,32
.r:         push hl
            ld a,CBG
.jp:        call 0
            pop hl
            add hl,de
            djnz .r
            ret
fill_chain:
            REPT 32
            ld (hl),a
            inc l
            ENDR
fill_end:   ret

cu_bbox:
            ld hl,cu_sx
            call .mm
            ld a,c
            rrca
            rrca
            and 31
            ld (cu_nx0),a
            ld a,d
            rrca
            rrca
            and 31
            ld (cu_nx1),a
            call .mm
            ld a,c
            ld (cu_ny0),a
            ld a,d
            ld (cu_ny1),a
            ret
.mm:        ld b,8
            ld c,255
            ld d,0
.l:         ld a,(hl)
            cp c
            jr nc,.n1
            ld c,a
.n1:        cp d
            jr c,.n2
            ld d,a
.n2:        inc hl
            djnz .l
            ret

cu_edges:
            ld hl,cu_edge_list
            ld b,12
.l:         push bc
            ld a,(hl)
            inc hl
            push hl
            ld e,a
            ld d,0
            ld hl,cu_sx
            add hl,de
            ld b,(hl)
            ld de,8
            add hl,de
            ld c,(hl)
            pop hl
            ld a,(hl)
            inc hl
            push hl
            push bc
            ld e,a
            ld d,0
            ld hl,cu_sx
            add hl,de
            ld a,(hl)
            ld de,8
            add hl,de
            ld e,(hl)
            ld d,a
            pop bc
            call line
            pop hl
            pop bc
            djnz .l
            ret

cu_edge_list:
            db 0,1, 2,3, 4,5, 6,7, 0,2, 1,3, 4,6, 5,7, 0,4, 1,5, 2,6, 3,7

cu_compute:
            ld a,(cu_a)
            add a,3
            ld (cu_a),a
            ld l,a
            ld h,HIGH(sintab)
            ld a,(hl)
            ld (cu_sa),a
            ld a,l
            add a,64
            ld l,a
            ld a,(hl)
            ld (cu_ca),a
            ld a,(cu_b)
            add a,5
            ld (cu_b),a
            ld l,a
            ld a,(hl)
            ld (cu_sb),a
            ld a,l
            add a,64
            ld l,a
            ld a,(hl)
            ld (cu_cb),a
            ld e,CU_S
            ld a,(cu_sa)
            call mul7
            ld (cu_saS),a
            ld e,CU_S
            ld a,(cu_ca)
            call mul7
            ld (cu_caS),a
            ld e,CU_S
            ld a,(cu_sb)
            call mul7
            ld (cu_cols+5),a            ; C1z = sbS
            ld e,CU_S
            ld a,(cu_cb)
            call mul7
            ld (cu_cols+4),a            ; C1y = cbS
            xor a
            ld (cu_cols+3),a            ; C1x = 0
            ld a,(cu_caS)
            ld (cu_cols+0),a            ; C0x = caS
            ld a,(cu_saS)
            ld (cu_cols+6),a            ; C2x = saS
            ld a,(cu_sb)
            ld e,a
            ld a,(cu_saS)
            call mul7
            ld (cu_cols+1),a            ; C0y = saS*sb
            ld a,(cu_cb)
            ld e,a
            ld a,(cu_saS)
            call mul7
            neg
            ld (cu_cols+2),a            ; C0z = -saS*cb
            ld a,(cu_sb)
            ld e,a
            ld a,(cu_caS)
            call mul7
            neg
            ld (cu_cols+7),a            ; C2y = -caS*sb
            ld a,(cu_cb)
            ld e,a
            ld a,(cu_caS)
            call mul7
            ld (cu_cols+8),a            ; C2z = caS*cb
; the 8 corners = +-C0 +-C1 +-C2
            ld hl,cu_vx
            ld ix,cu_cols
            ld c,3
.comp:      ld b,0
.v:         xor a
            ld e,(ix+0)
            bit 0,b
            jr z,.n0
            add a,e
            jr .d0
.n0:        sub e
.d0:        ld e,(ix+3)
            bit 1,b
            jr z,.n1
            add a,e
            jr .d1
.n1:        sub e
.d1:        ld e,(ix+6)
            bit 2,b
            jr z,.n2
            add a,e
            jr .d2
.n2:        sub e
.d2:        ld (hl),a
            inc hl
            inc b
            ld a,b
            cp 8
            jr nz,.v
            inc ix
            dec c
            jr nz,.comp
; perspective
            ld ix,cu_vx
            ld iy,cu_sx
            ld b,8
.p:         push bc
            ld a,(ix+16)                ; Z
            add a,66
            ld e,a
            ld d,0
            ld hl,cu_rx
            add hl,de
            push hl
            ld e,(hl)
            ld a,(ix+0)                 ; X
            call mul_ss
            add hl,hl
            add hl,hl
            ld a,h
            add a,64
            ld (iy+0),a
            pop hl
            ld de,128
            add hl,de
            ld e,(hl)
            ld a,(ix+8)                 ; Y
            call mul_ss
            add hl,hl
            add hl,hl
            ld a,h
            add a,CU_CY
            ld (iy+8),a
            inc ix
            inc iy
            pop bc
            djnz .p
            ret

; line: from (B,C) to (D,E) in the WORK back buffer, ORed in colour 3
line:
            ld a,d
            sub b
            jr nc,ln_noswap
            ld a,b
            ld b,d
            ld d,a
            ld a,c
            ld c,e
            ld e,a
            ld a,d
            sub b
ln_noswap:    ld (ln_dx),a
            ld a,e
            sub c
            ld h,$C6                    ; add a,n
            ld l,$24                    ; inc h
            jr nc,ln_down
            neg
            ld h,$D6                    ; sub n
            ld l,$25                    ; dec h
ln_down:      ld (ln_dy),a
            ld a,h
            ld (lx_yop),a
            ld (ly_yop),a
            ld a,l
            ld (lx_hop),a
            ld (ly_hop),a
            ld a,c
            call row1
            ld a,h
            add a,HIGH(WORK)-HIGH(VRAM)
            ld h,a
            ld a,b
            rrca
            rrca
            and 31
            or l
            ld l,a
            ld a,b
            and 3
            ld c,$C0
            jr z,ln_mk
ln_ms:        rrc c
            rrc c
            dec a
            jr nz,ln_ms
ln_mk:        ld a,(ln_dx)
            ld e,a
            ld a,(ln_dy)
            ld d,a
            cp e
            jr nc,ln_ymaj
            ld a,e                      ; x major
            ld (lx_dx+1),a
            ld a,d
            ld (lx_dy+1),a
            ld b,e
            inc b
            ld a,e
            srl a
            ld d,a
ln_xl:      ld a,(hl)
            or c                        ; orange (11) over magenta (10)
            ld (hl),a
            ld a,d
lx_dy:      sub 0
            jr nc,ln_xn
lx_dx:      add a,0
            ld d,a
            ld a,l
lx_yop:     add a,32
            ld l,a
            jr nc,ln_xs
lx_hop:     inc h
            jr ln_xs
ln_xn:        ld d,a
ln_xs:        rrc c
            rrc c
            jr nc,ln_xw
            inc l
ln_xw:        djnz ln_xl
            ret
ln_ymaj:      ld a,e                      ; y major
            ld (ly_dx+1),a
            ld a,d
            ld (ly_dy+1),a
            ld b,d
            inc b
            ld a,d
            srl a
            ld d,a
ln_yl:      ld a,(hl)
            or c                        ; orange (11) over magenta (10)
            ld (hl),a
            ld a,l
ly_yop:     add a,32
            ld l,a
            jr nc,ln_yh
ly_hop:     inc h
ln_yh:        ld a,d
ly_dx:      sub 0
            jr nc,ln_yn
ly_dy:      add a,0
            rrc c
            rrc c
            jr nc,ln_yn
            inc l
ln_yn:        ld d,a
            djnz ln_yl
            ret

; ===================================================================== 5 SCROLLER
; Sine-wave scroller over three bouncing colour bars, mode 1 colour set 0.
NBAR        equ 3
BBG         equ $AA                     ; blue

sc_init:
            ld a,$08
            call set_latch
            ld a,BBG
            call cls1
            ld hl,0
            ld (sc_pos),hl
            ld hl,sc_old                ; old columns: somewhere harmless
            ld b,32
.o:         ld (hl),LOW(VRAM)
            inc hl
            ld (hl),HIGH(VRAM)
            inc hl
            djnz .o
            ld hl,sc_obar
            ld (hl),0
            inc hl
            ld (hl),0
            inc hl
            ld (hl),0
            ret

sc_frame:
; 1. rub out the old bars and the old letters
            ld hl,sc_obar
            ld b,NBAR
.ob:        push bc
            push hl
            ld a,(hl)
            call row1
            ld c,6
.obr:       push hl
            ld a,BBG
            call fill_row
            pop hl
            ld de,32
            add hl,de
            dec c
            jr nz,.obr
            pop hl
            inc hl
            pop bc
            djnz .ob
            ld ix,sc_old
            ld b,32
.oc:        ld l,(ix+0)
            ld h,(ix+1)
            ld de,32
            ld a,BBG
            REPT 8
            ld (hl),a
            add hl,de
            ENDR
            inc ix
            inc ix
            djnz .oc
; 2. the bars
            ld hl,sc_obar
            ld ix,bar_pats
            ld c,0                      ; bar number * 85
            ld b,NBAR
.bar:       push bc
            push hl
            ld a,(ptime)
            add a,a
            add a,c
            ld l,a
            ld h,HIGH(sintab)
            ld a,(hl)
            sra a
            sra a
            sra a
            ld e,a
            ld a,(ptime)
            ld d,a
            add a,a
            add a,d
            add a,c
            add a,c
            ld l,a
            ld a,(hl)
            sra a
            sra a
            sra a
            sra a
            add a,e
            add a,29
            pop hl
            ld (hl),a
            push hl
            call row1
            ld c,6
.br:        push hl
            ld a,(ix+0)
            call fill_row
            pop hl
            ld de,32
            add hl,de
            inc ix
            dec c
            jr nz,.br
            pop hl
            inc hl
            pop bc
            ld a,c
            add a,85
            ld c,a
            djnz .bar
; 3. the letters
            ld hl,(sc_pos)
            ld a,l
            and 1
            ld (sc_half),a
            srl h
            rr l
            ld de,sc_text
            add hl,de
            ld (sc_p),hl
            ld a,(ptime)
            ld b,a
            add a,a
            add a,b
            ld (sc_ph),a
            ld ix,sc_old
            xor a
            ld (sc_col),a
.col:       ld hl,(sc_p)                ; glyph column address
            ld l,(hl)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(sc_half)
            or a
            jr z,.h0
            ld de,8
            add hl,de
.h0:        ld de,font1
            add hl,de
            ex de,hl
            ld a,(sc_half)              ; next column
            xor 1
            ld (sc_half),a
            jr nz,.sameh
            ld hl,(sc_p)
            inc hl
            ld (sc_p),hl
.sameh:     ld a,(sc_ph)                ; the wave
            ld l,a
            add a,3
            ld (sc_ph),a
            ld h,HIGH(sintab)
            ld a,(hl)
            sra a
            sra a
            sra a
            add a,26
            call row1
            ld a,(sc_col)
            or l
            ld l,a
            ld (ix+0),l
            ld (ix+1),h
            ld b,HIGH(tmask)
            REPT 8
            ld a,(de)
            ld c,a
            ld a,(bc)
            and (hl)
            or c
            ld (hl),a
            inc e
            ld a,l
            add a,32
            ld l,a
            jr nc,$+3
            inc h
            ENDR
            inc ix
            inc ix
            ld a,(sc_col)
            inc a
            ld (sc_col),a
            cp 32
            jp nz,.col
; 4. move along every other field
            ld a,(ptime)
            and 1
            ret nz
            ld hl,(sc_pos)
            inc hl
            ld de,2*(SC_LEN-16)
            or a
            sbc hl,de
            add hl,de
            jr c,.st
            ld hl,0
.st:        ld (sc_pos),hl
            ret

bar_pats:   db $FF,$DD,$55,$55,$DD,$FF  ; red / yellow
            db $00,$11,$55,$55,$11,$00  ; green / yellow
            db $FF,$CC,$00,$00,$CC,$FF  ; red / green

; ===================================================================== 6 TUNNEL
; A spiral tunnel from a lookup table, the view swaying around inside it.
tu_init:
            xor a
            call set_latch
            ld a,$80
            jp cls0

tu_frame:
            ld a,(ptime)
            and $FC
            add a,a
            add a,a                     ; ring = t/4
            ld c,a
            ld a,(ptime)
            rrca
            rrca
            rrca
            and 15                      ; spin = t/8
            add a,c
            ld ixl,a                    ; texture offset: rings rush in, slow spin
            ld h,HIGH(sintab)
            ld a,(ptime)
            add a,a
            ld l,a
            ld a,(hl)
            sra a
            sra a
            sra a
            sra a
            sra a
            add a,4
            ld (tu_ox),a                ; 0..7
            ld a,(ptime)
            ld c,a
            add a,a
            add a,c
            ld l,a
            ld a,(hl)
            sra a
            sra a
            sra a
            sra a
            sra a
            sra a
            add a,2
            ld (tu_oy),a                ; 0..3
            ld l,a                      ; DE = table + oy*40 + ox
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,de
            ld a,(tu_ox)
            ld e,a
            ld d,0
            add hl,de
            ld de,tun_tab
            add hl,de
            ex de,hl
            ld bc,VRAM
            ld a,16
.row:       ld (tu_rows),a
            push de
            ld h,HIGH(tun_tex)
            REPT 32
            ld a,(de)
            add a,ixl
            ld l,a
            ld a,(hl)
            ld (bc),a
            inc de
            inc c
            ENDR
            ld a,c
            or a
            jr nz,.nb
            inc b
.nb:        pop hl
            ld de,TUN_W
            add hl,de
            ex de,hl
            ld a,(tu_rows)
            dec a
            jp nz,.row
; black out the far end
            ld a,(tu_oy)
            neg
            add a,9
            call row1                   ; 32 bytes a row, as in mode 1
            ld a,(tu_ox)
            neg
            add a,19
            ld c,a
            ld b,0
            add hl,bc
            ld ix,tun_dark
            ld b,TUN_DARK_N
.d:         ld e,(ix+0)
            ld d,(ix+1)
            push hl
            add hl,de
            ld (hl),$80
            pop hl
            inc ix
            inc ix
            djnz .d
            ret

; ===================================================================== 7 CREDITS
; Orange text rolling up between colour-cycling pillars.
cr_init:
            ld a,$10
            call set_latch
            ld a,$80
            call cls0
            ld hl,cr_text
            ld (cr_ptr),hl
            ld a,1
            ld (cr_cnt),a
            ret

cr_frame:
            ld a,(ptime)                ; the pillars
            rrca
            rrca
            and 7
            ld c,a
            ld hl,VRAM
            ld de,31
            ld b,16
.p:         push hl
            ld a,c
            add a,b
            and 7
            ld hl,rainbow
            add a,l
            ld l,a
            jr nc,.nc
            inc h
.nc:        ld a,(hl)
            or $0F
            pop hl
            ld (hl),a
            add hl,de
            ld (hl),a
            inc hl
            djnz .p
            ld hl,cr_cnt
            dec (hl)
            ret nz
            ld (hl),12
            ld hl,VRAM+32+1             ; roll up one row
            ld de,VRAM+1
            ld b,15
.r:         push bc
            ld bc,30
            ldir
            ld bc,2
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            pop bc
            djnz .r
            ld hl,VRAM+15*32+1          ; empty the new bottom row
            ld de,VRAM+15*32+2
            ld bc,29
            ld (hl),$80
            ldir
            ld hl,(cr_ptr)              ; the next line: length, codes
            ld a,(hl)
            cp $FF
            ret z
            inc hl
            ld c,a
            ld b,0
            ld a,28
            sub c
            srl a
            add a,LOW(VRAM+15*32+2)
            ld e,a
            ld d,HIGH(VRAM+15*32)
            ld a,c
            or a
            jr z,.done
            ldir
.done:      ld (cr_ptr),hl
            ret
