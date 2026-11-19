; =====================================================================
;  scroll.asm - horizontal parallax: flat sky, skyline band (half speed)
;  and ground band (full speed), pixel-smooth.
;  Each band keeps 4 pre-shifted ring buffers, 64 bytes per row:
;    ring_s[n] = world pixels 4n+s .. 4n+s+3   (n = column mod 64)
;  A new 4-px tile column costs ~1K T to fold into all four rings; a
;  frame then copies 32 bytes per row out of ring (scroll & 3).
; =====================================================================
SKYBYTE     equ $AA            ; blue

; ---- reset the scroller for a stage (ground map already selected)
scroll_init:
            ld hl,0
            ld (scx),hl
            ld (g_n),hl
            ld (s_n),hl
            xor a
            ld (sm_i),a
            ld (scroll_sub),a
            ld (gm_left),hl         ; (0: the stage feeds the first segment)
            ld hl,(STG_GTILES)
            ld (g_prev),hl
            ld hl,(STG_STILES)
            ld (s_prev),hl
            ; prime both bands with 33 columns
            ld b,34
.pg:        push bc
            call ground_col
            call sky_col
            pop bc
            djnz .pg
            ret

; advance the scroll by one pixel and feed new columns
scroll_step:
            ld hl,(scx)
            inc hl
            ld (scx),hl
            ld a,l
            and 3
            jr nz,.sky
            call ground_col         ; a new ground column every 4 px
            ld a,(tl_hold)          ; the timeline waits while a boss is up
            or a
            jr nz,.sky
            ld hl,(tl_col)
            inc hl
            ld (tl_col),hl
.sky:       ld hl,(scx)
            ld a,l
            and 7
            ret nz
            jp sky_col              ; and a skyline column every 8

; fold the next ground tile into the rings
ground_col:
            ld hl,(gm_left)
            ld a,h
            or l
            call z,STG_SEG
            ld hl,(gm_left)
            dec hl
            ld (gm_left),hl
            ld hl,(gm_p)
            ld a,(hl)
            inc hl
            ld (gm_p),hl
            ; tile address = GTILES + a*18
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl               ; *16
            add hl,de
            add hl,de               ; *18
            ld de,(STG_GTILES)
            add hl,de
            push hl
            ld a,GROWS
            ld (rp_rows),a
            ld hl,GRING
            ld (rp_base),hl
            ld hl,GROWS*64
            ld (rp_stride),hl
            ld a,(g_n)
            ld (rp_n),a
            pop ix
            ld iy,(g_prev)
            ld (g_prev),ix
            call ring_put
            ld hl,(g_n)
            inc hl
            ld (g_n),hl
            ret

sky_col:
            ld a,(sm_i)
            ld e,a
            ld d,0
            inc a
            cp SKY_C
            jr c,.w
            xor a
.w:         ld (sm_i),a
            ld hl,(STG_SMAP)
            add hl,de
            ld a,(hl)
            ld l,a                  ; *12
            ld h,0
            add hl,hl
            add hl,hl
            ld d,h
            ld e,l
            add hl,hl
            add hl,de
            ld de,(STG_STILES)
            add hl,de
            push hl
            ld a,SROWS
            ld (rp_rows),a
            ld hl,SRING
            ld (rp_base),hl
            ld hl,SROWS*64
            ld (rp_stride),hl
            ld a,(s_n)
            ld (rp_n),a
            pop ix
            ld iy,(s_prev)
            ld (s_prev),ix
            call ring_put
            ld hl,(s_n)
            inc hl
            ld (s_n),hl
            ret

; IX = new tile (rows bytes), IY = previous tile, rp_* = ring description
; ring0[n] = new ; ring_s[n-1] = (prev<<2s | new>>(8-2s)) for s = 1..3
ring_put:
            ld a,(rp_n)
            and 63
            ld e,a
            ld d,0
            ld hl,(rp_base)
            add hl,de
            push hl                 ; ring0 + n
            ld a,e
            dec a
            and 63
            ld e,a
            ld hl,(rp_base)
            add hl,de
            ld de,(rp_stride)
            add hl,de
            push hl                 ; ring1 + (n-1)
            ld hl,(rp_stride)
            add hl,hl
            ex de,hl
            ld hl,64
            or a
            sbc hl,de
            ld b,h
            ld c,l                  ; BC = 64 - 2*stride
            ld de,(rp_stride)       ; DE = stride
            pop hl                  ; HL = ring1 ptr
            exx                     ; -> alternate set
            pop hl                  ; main HL = ring0 ptr
            ld a,(rp_rows)
            ld e,a
.row:       ld a,(ix+0)
            ld (hl),a               ; ring0
            ld c,a
            ld b,(iy+0)
            sla c
            rl b
            sla c
            rl b
            ld a,b
            exx
            ld (hl),a               ; ring1
            add hl,de
            exx
            sla c
            rl b
            sla c
            rl b
            ld a,b
            exx
            ld (hl),a               ; ring2
            add hl,de
            exx
            sla c
            rl b
            sla c
            rl b
            ld a,b
            exx
            ld (hl),a               ; ring3
            add hl,bc               ; back to ring1, next row
            exx
            inc ix
            inc iy
            ld bc,64
            add hl,bc
            dec e
            jr nz,.row
            ret

; ---------------------------------------------------------------------
; draw the background into the back buffer: sky fill, clouds, bands
; ---------------------------------------------------------------------
draw_bg:
            ; sky rows PF_TOP..STOP-1 filled with PUSH (end of the area first)
            ld a,(bbh)
            add a,HIGH(STOP*32)
            ld h,a
            ld l,LOW(STOP*32)
            ld de,SKYBYTE*257
            ld b,(STOP-PF_TOP)*2
            di
            ld (bg_sp),sp
            ld sp,hl
.sk:        REPT 8
            push de
            ENDR
            djnz .sk
            ld sp,(bg_sp)
            call re_ei
            ; clouds at quarter speed
            call draw_clouds
            ; skyline band: scroll = scx/2
            ld hl,(scx)
            srl h
            rr l
            ld a,l
            and 3
            ld b,a                  ; shift
            srl h
            rr l
            srl h
            rr l                    ; L = column (mod 256)
            ld c,l
            ld hl,SRING
            ld de,SROWS*64
            call ring_sel
            ld hl,STOP*32
            call bbp
            ex de,hl
            ld a,SROWS
            call band
            ; ground band: scroll = scx
            ld hl,(scx)
            ld a,l
            and 3
            ld b,a
            srl h
            rr l
            srl h
            rr l
            ld c,l
            ld hl,GRING
            ld de,GROWS*64
            call ring_sel
            ld hl,GTOP*32
            call bbp
            ex de,hl
            ld a,GROWS
            jp band

; HL = ring base, DE = stride, B = shift, C = first column -> HL = ring_s
; and the two copy runs set up in band's call targets
ring_sel:
            inc b
.s:         dec b
            jr z,.d
            add hl,de
            jr .s
.d:         ld (bd_base),hl
            ld a,c
            and 63
            ld (bd_i0),a
            ; run 1 = min(32, 64-i0), run 2 = 32 - run1
            ld b,a
            ld a,64
            sub b
            cp 33
            jr c,.r
            ld a,32
.r:         ld c,a                  ; run1
            ld a,32
            sub c                   ; run2
            push af
            ; entry = chain_end - 2*n
            ld a,c
            add a,a
            ld e,a
            ld d,0
            ld hl,ldi_end
            or a
            sbc hl,de
            ld (band.e1+1),hl
            pop af
            add a,a
            ld e,a
            ld d,0
            ld hl,ldi_end
            or a
            sbc hl,de
            ld (band.e2+1),hl
            ret

; copy A rows from the selected ring to DE (back buffer)
band:
            ld (bd_rows),a
            ld hl,(bd_base)
.row:       push hl
            ld a,(bd_i0)
            add a,l
            ld l,a
            jr nc,.nc
            inc h
.nc:        ld bc,$FFFF
.e1:        call ldi_end
            pop hl
            push hl
.e2:        call ldi_end
            pop hl
            ld bc,64
            add hl,bc
            ld a,(bd_rows)
            dec a
            ld (bd_rows),a
            jr nz,.row
            ret
bd_base:    dw 0
bd_i0:      db 0
bd_rows:    db 0

ldi_chain:  REPT 32
            ldi
            ENDR
ldi_end:    ret

; three clouds drifting at quarter speed (x positions in cloud_x)
draw_clouds:
            ld a,(frames)
            and 3
            jr nz,.dr
            ld hl,cloud_x
            ld b,3
.mv:        dec (hl)
            inc hl
            djnz .mv
.dr:        ld a,(cloud_spr)        ; (a stage can swap the clouds or drop them)
            or a
            ret z
            ld a,(cloud_x)
            ld b,a
            ld c,10+YOFF
            ld a,(cloud_spr)
            call blit
            ld a,(cloud_x+1)
            ld b,a
            ld c,16+YOFF
            ld a,(cloud_spr)
            call blit
            ld a,(cloud_x+2)
            ld b,a
            ld c,7+YOFF
            ld a,(cloud_spr)
            jp blit
