; ============================================================================
;  SYSTEM: start-up, banked frame install, tables, interrupt, controls,
;  sound, frame pacing, quit
; ============================================================================

init:
        di
        ld sp,STACKTOP
        ld a,$28                ; mode 1, CSS 0, speaker idle
        ld (LATCH),a
        ld hl,VARS              ; clear the variables
        ld de,VARS+1
        ld bc,VARSEND-VARS-1
        ld (hl),0
        ldir
        ld a,SB>>8
        ld (txt_page),a
        ld hl,VRAM              ; blue screen while starting up
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$AA
        ldir
        ; the SRAM must be there: write and read back in both banks
        ld a,BANK_FLICK
        call sram_check
        jp nz,no_sram
        ld a,BANK_DUSTY
        call sram_check
        jp nz,no_sram
        ; and the two banks must be separate
        ld a,BANK_FLICK
        out ($37),a
        ld a,$A5
        ld ($4000),a
        ld a,BANK_DUSTY
        out ($37),a
        ld a,$5A
        ld ($4000),a
        ld a,BANK_FLICK
        out ($37),a
        ld a,($4000)
        cp $A5
        jp nz,no_sram
        call build_tables
        ; frames into the banks: Flick first (his masters are then free for
        ; Dusty's overflow), Dusty second
        ld hl,$4000
        ld (bank_ptr),hl
        ld hl,flick_data
        ld (ovf_ptr),hl
        ld hl,flick_hdr
        ld ix,dir_flick
        ld a,BANK_FLICK
        call install
        ld hl,$4000
        ld (bank_ptr),hl
        ld hl,dusty_hdr
        ld ix,dir_dusty
        ld a,BANK_DUSTY
        call install
        ld hl,(ovf_ptr)
        ld de,flick_end
        or a
        sbc hl,de
        jp nc,no_sram           ; (can't happen: the build checks the sizes)
        ; the stage shifted 2 pixels, for odd camera steps
        call build_stage2
        ld a,32
        ld (cam),a
        ld (src_cam),a
        call bg_build
        ; IM2 vector table
        ld hl,IM2TAB
        ld de,IM2TAB+1
        ld bc,256
        ld (hl),ISRJP>>8
        ldir
        ld a,$C3
        ld (ISRJP),a
        ld hl,isr
        ld (ISRJP+1),hl
        ld a,IM2TAB>>8
        ld i,a
        im 2
        ld a,$28
        ld (latch),a
        ld hl,$ACE1
        ld (seed),hl
        ld a,1
        ld (opt_diff),a
        ld a,2
        ld (tick_len),a
        ei
        jp front_main

; sram_check: A = mapper value; Z if $4000 holds what is written
sram_check:
        out ($37),a
        ld hl,$4000
        ld (hl),$A5
        ld a,(hl)
        cp $A5
        ret nz
        ld (hl),$5A
        ld a,(hl)
        cp $5A
        ret

no_sram:
        ld a,BANK_FLICK
        out ($37),a
        ld hl,s_nosram
        ld de,VRAM+24*32+3
.l:     ld a,(hl)
        or a
        jr z,.h
        ; crude: show the message as solid bars on the blue screen
        ld a,$FF
        ld (de),a
        inc de
        inc hl
        jr .l
.h:     jr .h
s_nosram: db "NEEDS 128K SRAM",0

; ---------------------------------------------------------------------------
; install: copy one fighter's 22 frames into a bank, building the shifted
; (2 pixels right) copy of each.  HL = master header, IX = runtime directory,
; A = mapper value.  Frames that don't fit go to main RAM at ovf_ptr.
;   directory entry (10 bytes): dw plain, dw shifted, db width, height,
;   anchor_x, rows_below, hand_x, hand_y
; ---------------------------------------------------------------------------
install:
        out ($37),a
        ld (inst_hdr),hl
        ld a,NFRAMES
        ld (inst_n),a
.frame: ld hl,(inst_hdr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (inst_src),de
        ld a,(hl)
        ld (inst_wb),a
        ld (ix+4),a
        inc hl
        ld a,(hl)
        ld (inst_h),a
        ld (ix+5),a
        inc hl
        ld a,(hl)
        ld (ix+6),a
        inc hl
        ld a,(hl)
        ld (ix+7),a
        inc hl
        ld a,(hl)
        ld (ix+8),a
        inc hl
        ld a,(hl)
        ld (ix+9),a
        inc hl
        ld (inst_hdr),hl
        ; size0 = wb*h ; need = (2wb+1)*h
        ld a,(inst_wb)
        ld e,a
        ld d,0
        ld a,(inst_h)
        call mul8           ; HL = wb*h
        ld (inst_s0),hl
        ld a,(inst_wb)
        add a,a
        inc a
        ld e,a
        ld d,0
        ld a,(inst_h)
        call mul8           ; HL = need
        ld b,h
        ld c,l
        ; does it fit in the bank?
        ld hl,(bank_ptr)
        push hl
        add hl,bc
        ld de,$6801
        or a
        sbc hl,de
        pop hl
        jr nc,.ovf
        ld (inst_dst),hl
        add hl,bc
        ld (bank_ptr),hl
        jr .go
.ovf:   ld hl,(ovf_ptr)
        ld (inst_dst),hl
        add hl,bc
        ld (ovf_ptr),hl
.go:    ld hl,(inst_dst)
        ld (ix+0),l
        ld (ix+1),h
        ld de,(inst_s0)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ; plain copy
        ld hl,(inst_src)
        ld de,(inst_dst)
        ld bc,(inst_s0)
        ldir
        ; shifted copy: DE continues right after the plain copy
        ld hl,(inst_src)
        ld a,(inst_h)
        ld b,a
.row:   push bc
        ld a,(inst_wb)
        ld b,a
        ld c,0              ; previous byte, nibbles swapped
.byte:  ld a,(hl)
        inc hl
        rrca
        rrca
        rrca
        rrca                ; A = swapped
        push af
        and $0F
        ld (inst_t),a
        ld a,c
        and $F0
        push hl
        ld hl,inst_t
        or (hl)
        pop hl
        ld (de),a
        inc de
        pop af
        ld c,a
        djnz .byte
        ld a,c
        and $F0
        ld (de),a
        inc de
        pop bc
        djnz .row
        ld bc,10
        add ix,bc
        ld a,(inst_n)
        dec a
        ld (inst_n),a
        jp nz,.frame
        ret

; mul8: HL = DE * A (A <= 255, small values)
mul8:
        ld hl,0
        or a
        ret z
        ld b,a
.l:     add hl,de
        djnz .l
        ret

; ---------------------------------------------------------------------------
; draw tables: at each transform page T: T = byte transform, T+1 = mask
; ---------------------------------------------------------------------------
build_tables:
        ld hl,XF_ID*256
.id:    ld (hl),l
        inc l
        jr nz,.id
        ld hl,XF_FLIP*256
.fl:    ld a,l
        call flip4
        ld (hl),a
        inc l
        jr nz,.fl
        ld hl,XF_RED*256
.rd:    ld a,l
        call red4
        ld (hl),a
        inc l
        jr nz,.rd
        ld hl,XF_FRED*256
.fr:    ld a,l
        call flip4
        call red4
        ld (hl),a
        inc l
        jr nz,.fr
        ; mask pages
        ld hl,(XF_ID+1)*256
.mk:    ld a,l
        call mask4
        ld (hl),a
        inc l
        jr nz,.mk
        ld hl,(XF_ID+1)*256
        ld de,(XF_FLIP+1)*256
        ld bc,256
        ldir
        ld hl,(XF_ID+1)*256
        ld de,(XF_RED+1)*256
        ld bc,256
        ldir
        ld hl,(XF_ID+1)*256
        ld de,(XF_FRED+1)*256
        ld bc,256
        ldir
        ret

flip4:  ; A = byte with its 4 pixels in reverse order
        ld c,a
        ld b,4
        ld e,0
.l:     ld a,c
        and 3
        sla e
        sla e
        or e
        ld e,a
        srl c
        srl c
        djnz .l
        ld a,e
        ret

red4:   ; pixel colour 2 -> 3:  A | ((A & $AA) >> 1)
        ld c,a
        and $AA
        rrca
        or c
        ret

mask4:  ; 11 for every 00 pixel
        ld c,a
        ld e,0
        ld b,4
.l:     sla e
        sla e
        ld a,c
        and $C0
        jr nz,.n
        ld a,e
        or 3
        ld e,a
.n:     sla c
        sla c
        djnz .l
        ld a,e
        ret

; ---------------------------------------------------------------------------
; INTERRUPT (once per field).  The VZ's interrupt line stays low for the
; whole 56-line field sync, so interrupts may only be re-enabled after it.
; If a frame is ready, it is copied from SB to video RAM here: the copy starts
; at the top of field sync, well ahead of the beam, so it never tears.
; ---------------------------------------------------------------------------
isr:
        push af
        push bc
        push de
        push hl
        ld a,(frame_ready)
        or a
        jr z,.nocopy
        call copy_out
        xor a
        ld (frame_ready),a
.nocopy:
        call read_inputs
        call sfx_tick
        ld hl,fieldcnt
        inc (hl)
        ld hl,(fields)
        inc hl
        ld (fields),hl
        ld a,1
        ld (irqflag),a
        ; keep the sound going until field sync ends
        ld a,(sfx_mode)
        or a
        call nz,isr_audio
.fs:    ld a,(LATCH)
        rla
        jr nc,.fs
        pop hl
        pop de
        pop bc
        pop af
        ei
        reti

; copy_out: SB -> VRAM for the HUD rows (if flagged) and rows copy_top..copy_bot-1
copy_out:
        ld a,(copy_full)
        or a
        jr z,.part
        xor a
        ld (copy_full),a
        ld (copy_hud),a
        ld hl,SB
        ld de,VRAM
        ld b,64
.fl:    call ldi32
        djnz .fl
        ret
.part:  ld a,(copy_hud)
        or a
        jr z,.nohud
        xor a
        ld (copy_hud),a
        ld hl,SB
        ld de,VRAM
        ld b,HUDROWS
.hl:    call ldi32
        djnz .hl
.nohud: ld a,(copy_low)
        or a
        jr z,.nolow
        xor a
        ld (copy_low),a
        ld hl,SB+56*32
        ld de,VRAM+56*32
        ld b,8
.lw:    call ldi32
        djnz .lw
.nolow: ld a,(copy_top)
        ld (rc_top),a
        ld a,(copy_bot)
        ld (rc_bot),a
        ld a,(copy_l)
        ld (rc_l),a
        ld a,(copy_r)
        ld (rc_r),a
        ld hl,SB
        ld de,VRAM
        jp rect_copy

; rect_copy: copy the rectangle rows rc_top..rc_bot-1, byte columns
; rc_l..rc_r-1 from the screen-sized area at HL to the one at DE (both
; page aligned).  Wide rectangles copy whole rows in one run.
rect_copy:
        ld a,(rc_bot)
        ld b,a
        ld a,(rc_top)
        ld c,a
        ld a,b
        sub c
        ret z
        ret c
        ld b,a                  ; rows
        ld a,(rc_r)
        ld c,a
        ld a,(rc_l)
        cp c
        ret nc                  ; empty
        ld a,c
        ld c,a
        ld a,(rc_l)
        neg
        add a,c                 ; width
        cp 24
        jr c,.narrow
        ; whole rows
        xor a
        ld (rc_l),a
        call .addr
.full:  call ldi32
        djnz .full
        ret
.narrow:
        add a,a
        ld c,a
        push hl
        push bc
        ld b,0
        ld hl,ldirow_end
        or a
        sbc hl,bc
        ld (.call+1),hl
        pop bc
        pop hl
        call .addr
.row:   push hl
        push de
        push bc
.call:  call ldirow_end
        pop bc
        pop de
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr nc,$+3
        inc h
        ld a,e
        add a,32
        ld e,a
        jr nc,$+3
        inc d
        djnz .row
        ret
.addr:  ; HL, DE += rc_top*32 + rc_l
        ld a,(rc_top)
        push af
        and 7
        rrca
        rrca
        rrca
        ld c,a
        ld a,(rc_l)
        add a,c
        ld l,a
        ld e,a
        pop af
        rrca
        rrca
        rrca
        and $1F
        ld c,a
        ld a,h
        add a,c
        ld h,a
        ld a,d
        add a,c
        ld d,a
        ret

; 32 x LDI, entered part-way for shorter rows
ldirow:
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
ldirow_end:
        ret

; 32 x LDI (B is kept: LDI only counts BC down, and C wraps harmlessly)
ldi32:
        push bc
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop bc
        ret

; ---------------------------------------------------------------------------
; CONTROLS, read every field.
;  pad bits: 0 up, 1 down, 2 left, 3 right, 4 button A, 5 button B
;  joystick 1: directions $2C, A = fire $2E, B = arm $2D
;  joystick 2: directions $29 and $23 together, A = fire $2B, B = arm $27
;  keys 1: W A S D + F (A) G (B)      keys 2: I J K L + ; (A) : (B)
;  system keys (skey): bit0 RETURN, bit1 SPACE, bit2 Q, bit3 T
; ---------------------------------------------------------------------------
read_inputs:
        ; ---- joystick 1
        in a,($2C)
        ld (raw_2c),a
        cpl
        and $0F
        cp $0F
        jr nz,.j1ok
        xor a                   ; all four at once = no interface / noise
.j1ok:  ld c,a
        in a,($2E)
        ld (raw_2e),a
        bit 4,a
        jr nz,.j1a
        set 4,c
.j1a:   in a,($2D)
        ld (raw_2d),a
        bit 4,a
        jr nz,.j1b
        set 5,c
.j1b:   ld a,c
        ld (pad_j1),a
        ; ---- joystick 2
        in a,($29)
        ld (raw_29),a
        ld b,a
        in a,($23)
        ld (raw_23),a
        and b
        cpl
        and $0F
        cp $0F
        jr nz,.j2ok
        xor a
.j2ok:  ld c,a
        in a,($2B)
        ld (raw_2b),a
        bit 4,a
        jr nz,.j2a
        set 4,c
.j2a:   in a,($27)
        ld (raw_27),a
        bit 4,a
        jr nz,.j2b
        set 5,c
.j2b:   ld a,c
        ld (pad_j2),a
        ; ---- keyboard rows
        ld a,($68FE)            ; row 0: R Q E . W T
        ld (kr0),a
        ld a,($68FD)            ; row 1: F A D CTRL S G
        ld (kr1),a
        ld a,($68BF)            ; row 6: U P I RETURN O Y
        ld (kr6),a
        ld a,($687F)            ; row 7: J ; K : L H
        ld (kr7),a
        ld a,($68EF)            ; row 4: M SPACE , - . N
        ld (kr4),a
        ; keys 1
        ld c,0
        ld a,(kr0)
        bit 1,a
        jr nz,$+4
        set 0,c                 ; W up
        ld a,(kr1)
        bit 1,a
        jr nz,$+4
        set 1,c                 ; S down
        bit 4,a
        jr nz,$+4
        set 2,c                 ; A left
        bit 3,a
        jr nz,$+4
        set 3,c                 ; D right
        bit 5,a
        jr nz,$+4
        set 4,c                 ; F = A
        bit 0,a
        jr nz,$+4
        set 5,c                 ; G = B
        ld a,c
        ld (pad_k1),a
        ; keys 2
        ld c,0
        ld a,(kr6)
        bit 3,a
        jr nz,$+4
        set 0,c                 ; I up
        ld a,(kr7)
        bit 3,a
        jr nz,$+4
        set 1,c                 ; K down
        bit 5,a
        jr nz,$+4
        set 2,c                 ; J left
        bit 1,a
        jr nz,$+4
        set 3,c                 ; L right
        bit 4,a
        jr nz,$+4
        set 4,c                 ; ; = A
        bit 2,a
        jr nz,$+4
        set 5,c                 ; : = B
        ld a,c
        ld (pad_k2),a
        ; system keys
        ld c,0
        ld a,(kr6)
        bit 2,a
        jr nz,$+4
        set 0,c                 ; RETURN
        ld a,(kr4)
        bit 4,a
        jr nz,$+4
        set 1,c                 ; SPACE
        ld a,(kr0)
        bit 4,a
        jr nz,$+4
        set 2,c                 ; Q
        bit 0,a
        jr nz,$+4
        set 3,c                 ; T
        ld a,(skey)
        cpl
        and c
        ld hl,skey_new
        or (hl)
        ld (hl),a
        ld a,c
        ld (skey),a
        ; ---- players
        ld a,(pad_j1)
        ld hl,pad_k1
        or (hl)
        ld b,a                  ; P1 in 2-player mode
        ld a,(pad_j2)
        ld hl,pad_k2
        or (hl)
        ld c,a                  ; P2 in 2-player mode
        ld a,(two_player)
        or a
        jr nz,.two
        ld a,b
        or c
        ld b,a                  ; one player: every controller drives P1
        ld c,0
.two:   ld a,b
        ld (p1_cur),a
        ld hl,p1_prev
        ld a,(hl)
        cpl
        and b
        ld (hl),b
        ld hl,p1_new
        or (hl)
        ld (hl),a
        ld a,c
        ld (p2_cur),a
        ld hl,p2_prev
        ld a,(hl)
        cpl
        and c
        ld (hl),c
        ld hl,p2_new
        or (hl)
        ld (hl),a
        ; menu input: everything together
        ld a,(pad_j1)
        ld hl,pad_j2
        or (hl)
        ld hl,pad_k1
        or (hl)
        ld hl,pad_k2
        or (hl)
        ld b,a
        ld hl,m_prev
        ld a,(hl)
        cpl
        and b
        ld (hl),b
        ld hl,m_new
        or (hl)
        ld (hl),a
        ; control test extras
        ld a,(ct_on)
        or a
        ret z
        jp ct_field

; take_input: copy one player's latched presses for this tick.
;   HL = p1_new or p2_new -> A = presses (cleared)
take_new:
        di
        ld a,(hl)
        ld (hl),0
        ei
        ret

; menu_keys: A = new menu presses (pad bits), B = new system keys; both cleared
menu_keys:
        di
        ld a,(skey_new)
        ld b,a
        xor a
        ld (skey_new),a
        ld a,(m_new)
        ld c,a
        xor a
        ld (m_new),a
        ld a,c
        ei
        ret

clear_keys:
        di
        xor a
        ld (skey_new),a
        ld (m_new),a
        ld (p1_new),a
        ld (p2_new),a
        ei
        ret

; ---------------------------------------------------------------------------
; FRAME PACING
; frame_end: SB is complete.  Wait until the interrupt has copied it and at
; least tick_len fields have passed since the last frame, playing sound (or
; halting) meanwhile.  Counts slow ticks and, in debug mode, spare time.
; ---------------------------------------------------------------------------
frame_end:
        ld a,1
        ld (frame_ready),a
        ld hl,0
        ld (spare),hl
frame_w:
        call idle_wait
        ld a,(frame_ready)
        or a
        jr nz,frame_w
        ld a,(tick_len)
        ld b,a
        ld a,(fieldcnt)
        cp b
        jr c,frame_w
        jr z,frame_ok
        ld a,(tick_len)
        cp 2
        jr nz,frame_ok
slow_hit:
        ld hl,(slow_ticks)
        inc hl
        ld (slow_ticks),hl
frame_ok:
        xor a
        ld (fieldcnt),a
        ; spare time this tick (debug): keep the smallest over 25 ticks
        ld a,(dbg_on)
        or a
        ret z
        ld hl,(spare)
        ld de,(spare_min)
        or a
        sbc hl,de
        jr nc,frame_nm
        ld hl,(spare)
        ld (spare_min),hl
frame_nm:
        ld hl,dbg_cnt
        inc (hl)
        ld a,(hl)
        cp 25
        ret c
        ld (hl),0
        ld hl,(spare_min)
        ld (spare_show),hl
        ld hl,$FFFF
        ld (spare_min),hl
        ld a,1
        ld (dbg_dirty),a
        ret

; idle_wait: returns after the next interrupt
idle_wait:
        xor a
        ld (irqflag),a
        ld a,(dbg_on)
        or a
        jr nz,.count
        ld a,(sfx_mode)
        or a
        jr z,.h
        push ix
        call main_audio
        pop ix
        ret
.h:     ei
        halt
        ret
.count: ; 35 T per loop: spare T = count * 35
        ld hl,(spare)
.cl:    inc hl
        ld a,(irqflag)
        or a
        jr z,.cl
        ld (spare),hl
        ret

; wait_fields: B fields, with sound
wait_fields:
        push bc
        call idle_wait
        pop bc
        djnz wait_fields
        ret

; ---------------------------------------------------------------------------
; SOUND.  One voice on the 1-bit speaker, square tone or noise, driven by
; step lists: db fields, mode (0 rest, 1 tone, 2 noise), dw pitch step;
; fields = 0 ends.  The voice runs in the idle time between ticks and
; through field sync inside the interrupt.
; ---------------------------------------------------------------------------
; play_sfx: HL = step list (replaces whatever is playing)
play_sfx:
        di
        ld (sfx_ptr),hl
        xor a
        ld (sfx_dur),a
        call sfx_next
        ei
        ret

sfx_tick:
        ld a,(sfx_dur)
        or a
        ret z
        dec a
        ld (sfx_dur),a
        ret nz
sfx_next:
        ld hl,(sfx_ptr)
        ld a,(hl)
        or a
        jr z,.end
        ld (sfx_dur),a
        inc hl
        ld a,(hl)
        ld (sfx_mode),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sfx_step),de
        ld (sfx_ptr),hl
        ret
.end:   xor a
        ld (sfx_mode),a
        ld (sfx_dur),a
        ld a,(sfx_loop)
        or a
        ret z
        ld hl,(sfx_loopp)
        ld (sfx_ptr),hl
        jr sfx_next

; main_audio: play until the interrupt flag is set
main_audio:
        ld a,(latch)
        and $DE
        or $20
        ld ixl,a                ; speaker idle state
        ld de,(sfx_step)
        ld hl,(sfx_acc)
        ld b,rndtab>>8
        ld a,(sfx_mode)
        cp 2
        jr z,.noise
        cp 1
        jr z,.tone
        ei
        halt
        ret
.tone:  ei
.tl:    add hl,de
        ld a,h
        rla
        sbc a,a
        and $21
        xor ixl
        ld (LATCH),a
        ld a,(irqflag)
        or a
        jp z,.tl
        ld (sfx_acc),hl
        ld a,ixl
        ld (LATCH),a
        ret
.noise: ei
.nl:    add hl,de
        ld c,h
        ld a,(bc)
        xor ixl
        ld (LATCH),a
        ld a,(irqflag)
        or a
        jp z,.nl
        ld (sfx_acc),hl
        ld a,ixl
        ld (LATCH),a
        ret

; isr_audio: same voice, until field sync ends (called inside the interrupt)
isr_audio:
        push ix
        ld a,(latch)
        and $DE
        or $20
        ld ixl,a
        ld de,(sfx_step)
        ld hl,(sfx_acc)
        ld b,rndtab>>8
        ld a,(sfx_mode)
        cp 2
        jr z,.noise
.tl:    add hl,de
        ld a,h
        rla
        sbc a,a
        and $21
        xor ixl
        ld (LATCH),a
        ld a,(LATCH)            ; bit 7 = 1 once field sync is over
        rla
        jr nc,.tl
        jr .done
.noise: add hl,de
        ld c,h
        ld a,(bc)
        xor ixl
        ld (LATCH),a
        ld a,(LATCH)
        rla
        jr nc,.noise
.done:  ld (sfx_acc),hl
        ld a,ixl
        ld (LATCH),a
        pop ix
        ret

stop_sfx:
        di
        xor a
        ld (sfx_mode),a
        ld (sfx_dur),a
        ld (sfx_loop),a
        ei
        ret

; random: A = next pseudo-random byte (16-bit LFSR)
random:
        ld hl,(seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (seed),hl
        ret

; quit to the SD card menu: map the loader's EPROM back and restart
quit_to_sd:
        di
        xor a
        out ($37),a
        jp 0

; ---------------------------------------------------------------------------
; THE SCROLLING STAGE: 192 pixels (48 bytes) wide, rows 10-63.  Rows below
; SKYROWS (the starry sky) never scroll; they always come from camera 32.
; ---------------------------------------------------------------------------
; build_stage2: STAGE2 = stage0 shifted left by 2 pixels
build_stage2:
        ld hl,stage0
        ld bc,STAGE2
        ld a,54
.r:     push af
        ld d,STAGEW-1
.b:     ld a,(hl)
        inc hl
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        or e
        ld (bc),a
        inc bc
        dec d
        jr nz,.b
        ld a,(hl)
        inc hl
        add a,a
        add a,a
        add a,a
        add a,a
        ld (bc),a
        inc bc
        pop af
        dec a
        jr nz,.r
        ret

; stage_src: C = row (10-63), B = camera (even, 0-64) -> HL = first byte
stage_src:
        ld a,c
        sub 10
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; row * 16
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; row * 48
        ld a,b
        rrca
        rrca
        and $3F
        ld e,a
        ld d,0
        add hl,de
        ld de,stage0
        bit 1,b
        jr z,.s0
        ld de,STAGE2
.s0:    add hl,de
        ret

; stage_rows: A = first row, B = rows, DE = where they go (a 32-byte-wide
; buffer, already at that row).  Rows below SKYROWS use camera 32, the rest
; camera (src_cam).
stage_rows:
        cp SKYROWS
        jr nc,.scroll
        ; the still rows first (camera 32)
        push af
        push bc
        push de
        ld c,a
        ld b,32
        call stage_src
        pop de
        pop bc
        pop af
.s1:    push bc
        call ldirow
        ld bc,STAGEW-32
        add hl,bc
        pop bc
        inc a
        dec b
        ret z
        cp SKYROWS
        jr c,.s1
.scroll:
        push af
        push bc
        push de
        ld c,a
        ld a,(src_cam)
        ld b,a
        call stage_src
        pop de
        pop bc
        pop af
.s2:    push bc
        call ldirow
        ld bc,STAGEW-32
        add hl,bc
        pop bc
        djnz .s2
        ret

; bg_build: BG = the HUD band and the stage seen from camera (src_cam)
bg_build:
        ld hl,BG
        ld de,BG+1
        ld bc,HUDROWS*32-1
        ld (hl),$AA
        ldir
        ld a,10
        ld b,54
        ld de,BG+10*32
        call stage_rows
        ld a,(src_cam)
        ld (bg_cam),a
        ret
