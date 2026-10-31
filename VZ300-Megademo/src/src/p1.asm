; =====================================================================
;  PART 1 : boot screen (live diagnostics) -> glitch storm -> speech ->
;           FLD-dropped colour-cycling VZ300 logo with jelly wobble
;  music orders 0..5
; =====================================================================
        INCLUDE "ovl.inc"

P1_END_ORDER EQU 6

SU_FA2  MACRO
        SU_HLDE src_ptr, VRAM
        ENDM
SU_FB2  MACRO
        SU_SP fld_ptr
        ENDM
SU_FB3  MACRO
        SU_HLDE src_ptr, VRAM+64
        ENDM

part_entry:
        ld hl,0
        ld (pf),hl
        ; screen buffer = spaces
        ld hl,scrbuf
        ld de,scrbuf+1
        ld bc,511
        ld (hl),$20
        ldir
        ld hl,fld_tab+2*200     ; normal entries
        ld (rt_ptr),hl
        ld (rt_norm),hl
        ld hl,scrbuf
        ld (src_ptr),hl
        ld a,(kernel_pairs)
        sub 12+44+1
        ld (ca3),a
        ld a,(kernel_pairs)
        sub 57
        ld (cb2),a
        xor a
        call show_line
        call music_tick
        call music_apply

; ---------------------------------------------------------------------
; frame type A: full-screen copy of scrbuf (or ROM garbage), glitch rasters
; ---------------------------------------------------------------------
fa_frame:
        FRAME_START rt_ptr
        SEG fa1, fa1x, RAST, 105, SU_NONE, W_IDLE, W_IDLE, ca1
        SEG fa2, fa2x, RAST, 105, SU_FA2, W_COPY, W_COPY, ca2
        SEG fa3, fa3x, RAST, 105, SU_NONE, W_IDLE, W_IDLE, ca3
        FRAME_END
        call logic_a
        call music_apply
        ld a,(mode)
        or a
        jp z,fa_frame
        cp 2
        ret z                   ; part finished
        jp fb_frame

; ---------------------------------------------------------------------
; frame type B: logo screen - FLD / jelly during display (RASTHL holds),
; logo frame copied into rows 4..11 after the display
; ---------------------------------------------------------------------
fb_frame:
        FRAME_START rt_norm
        SEG fb1, fb1x, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, cb1
        SEG fb2, fb2x, RASTHL, 103, SU_FB2, W_IDLEH, W_IDLEH, cb2
        SEG fb3, fb3x, RAST, 105, SU_FB3, W_COPY, W_COPY, cb3
        SEG fb4, fb4x, RAST, 105, SU_NONE, W_IDLE, W_IDLE, cb4
        FRAME_END
        call logic_b
        call music_apply
        ld a,(mode)
        cp 2
        ret z
        jp fb_frame

ca1:    db 11
ca2:    db 43
ca3:    db 0
cb1:    db 30
cb2:    db 0
cb3:    db 22
cb4:    db 1

pf:     dw 0            ; frame counter
mode:   db 0            ; 0 = boot/glitch (A), 1 = logo (B), 2 = done
rt_ptr: dw 0
rt_norm: dw 0
src_ptr: dw 0
fld_ptr: dw 0
glitch_level: db 0
p1_said: db 0
fldp:   dw 0            ; FLD push in lines (8.8 fixed)
fldv:   dw 0            ; velocity
logo_landed: db 0
melt:   db 0
traj_i: db 0

; ---------------------------------------------------------------------
logic_a:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ; --- boot text lines appear ---
        ld a,h
        or a
        jr nz,.nolines
        ld a,l
        and 7
        jr nz,.nolines
        ld a,l
        rrca
        rrca
        rrca
        and 31                  ; line index = pf/8
        cp 6
        jr c,.showline
        ; lines 6..13 every 24 frames: pf = 48 + 24*(i-6)
        ld a,l
        sub 48
        jr c,.nolines
        ld c,0
.d24:   sub 24
        jr c,.r24
        inc c
        jr .d24
.r24:   add a,24
        cp 0
        jr nz,.nolines
        ld a,c
        add a,6
        cp 14
        jr nc,.nolines
.showline:
        call show_line
.nolines:
        ; --- cursor blink after the last boot line ---
        ld hl,(pf)
        ld a,h
        or a
        jr nz,.curok
        ld a,l
        cp 232
        jr c,.nocur
.curok: ld a,l
        and 16
        ld a,$20
        jr z,.cur
        ld a,$60                ; inverse space = cursor
.cur:   ld (scrbuf+32*14),a
.nocur:
        ; --- glitch phases ---
        ld a,(m_ordnum)
        or a
        jr nz,.o1
        ld hl,(pf)
        ld de,250
        or a
        sbc hl,de
        jr c,.calm
        ; level rises 0..133 over the rest of order 0
        ld a,l
        jr .glitch
.calm:  ld hl,(rt_norm)
        ld (rt_ptr),hl
        ld hl,scrbuf
        ld (src_ptr),hl
        ret
.o1:    ; order 1: 50 frames of heavy glitch then speech
        ld a,(p1_said)
        or a
        jr nz,.tologo
        ld hl,(pf)
        ld de,(.o1start)
        ld a,d
        or e
        jr nz,.o1s
        ld (.o1start),hl
        ex de,hl
.o1s:   or a
        sbc hl,de
        ld a,l
        cp 50
        jr nc,.say
        ld a,200
        jr .glitch
.say:   jp do_speech
.tologo:
        ret
.o1start: dw 0

.glitch: ; A = level 0..255 : probability of a glitched frame
        ld b,a
        call rnd16
        cp b
        jr nc,.calm
        ; glitch frame: random raster table offset
        call rnd16
        ld a,h
        and 7
        ld h,a
        ld a,l
        and $FE
        ld l,a                  ; 0..2046 even
        ld de,glitch_tab
        add hl,de
        ld (rt_ptr),hl
        ; sometimes show ROM garbage
        call rnd16
        and 3
        jr nz,.scr
        ld a,h
        and $3F
        ld h,a
        ld (src_ptr),hl
        jr .corrupt
.scr:   ld hl,scrbuf
        ld (src_ptr),hl
.corrupt: ; poke a random char into the screen buffer
        call rnd16
        ld a,h
        and 1
        ld h,a
        ld de,scrbuf
        add hl,de
        push hl
        call rnd16
        pop hl
        ld (hl),a
        ret

; show boot line A (0..13) into scrbuf row A (+diagnostic values)
show_line:
        push af
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *32
        push hl
        ld de,bootlines
        add hl,de
        ex de,hl                ; DE = source
        pop hl
        ld bc,scrbuf
        add hl,bc               ; HL = dest
        ex de,hl
        ld bc,32
        ldir
        pop af
        cp 7
        jr nz,.n8
        ; scanlines per field
        ld de,scrbuf+7*32+21
        ld hl,(lines_per_frame)
        jp put_dec16
.n8:    cp 8
        jr nz,.n9
        ld de,scrbuf+8*32+21
        ld a,(sram_ok)
        or a
        ld hl,txt_ok
        jr nz,.cp3
        ld hl,txt_fail
.cp3:   ld bc,4
        ldir
        ret
.n9:    cp 9
        ret nz
        ld de,scrbuf+9*32+21
        ld hl,txt_ok
        ld bc,4
        ldir
        ret
txt_ok:   db 15,11,32,32        ; "OK  "
txt_fail: db 6,1,9,12           ; "FAIL"

; HL (0..999) -> 3 digits at DE
put_dec16:
        ld bc,-100
        call .dig
        ld bc,-10
        call .dig
        ld a,l
        add a,'0'
        ld (de),a
        ret
.dig:   ld a,'0'-1
.l:     inc a
        add hl,bc
        jr c,.l
        sbc hl,bc
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------------
do_speech:
        ld a,1
        ld (p1_said),a
        ; black screen + static logo while speaking
        ld a,$80
        call cls
        ld hl,logo_frames
        ld de,VRAM+64
        ld bc,256
        ldir
        ld hl,speech1
        ld de,speech1_len
        ld c,M0
        call speech_play
        ; switch to logo frames, FLD drop from the top
        ld a,$80
        call cls
        xor a
        ld (traj_i),a
        ld a,200
        ld (fldp+1),a
        ld a,1
        ld (mode),a
        ld hl,logo_frames
        ld (src_ptr),hl
        call fld_set
        ret

; ---------------------------------------------------------------------
logic_b:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ; logo colour cycle: frame = (pf/3) & 7
        ld a,(.cyc)
        inc a
        cp 3
        jr c,.c3
        xor a
        ld hl,.fr
        inc (hl)
.c3:    ld (.cyc),a
        ld a,(.fr)
        and 7
        add a,a
        ld l,a
        ld h,0
        ld de,logo_ptrs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (src_ptr),hl
        ; end of part?
        ld a,(m_ordnum)
        cp P1_END_ORDER
        jr c,.notend
        ld a,2
        ld (mode),a
        ret
.notend:
        ; melt during the last 2 bars of order 5
        cp P1_END_ORDER-1
        jr nz,.physics
        ld a,(m_row)
        cp 32
        jr c,.physics
        ; push down: p += 4 lines per frame
        ld hl,(fldp)
        ld de,4*256
        add hl,de
        ld a,h
        cp 200
        jr c,.mok
        ld h,200
.mok:   ld (fldp),hl
        jp fld_set
.physics:
        ld a,(logo_landed)
        or a
        jr nz,.jelly
        ld a,(traj_i)
        ld l,a
        ld h,0
        ld de,traj
        add hl,de
        ld a,(hl)
        cp $FF
        jr z,.land
        ld (fldp+1),a
        ld hl,traj_i
        inc (hl)
        jp fld_set
.land:  ld a,1
        ld (logo_landed),a
        xor a
        ld (fldp+1),a
.jelly: ; jelly wobble from order 2; subtitle stripes from order 3
        ld a,(m_ordnum)
        cp 3
        jr c,.nosub
        ld a,(.subon)
        or a
        jr nz,.nosub
        inc a
        ld (.subon),a
        ld hl,sub_text
        ld de,VRAM+11*32
        ld bc,96
        ldir
.nosub: ld a,(m_ordnum)
        cp 2
        jp c,fld_set
        ld hl,(pf)
        ld a,l
        and 14                  ; phase advances every 2 frames (x2 for word table)
        ld l,a
        ld h,0
        ld de,jelly_ptrs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (fld_ptr),hl
        ret
.cyc:   db 0
.fr:    db 0
.subon: db 0

; fld_ptr = fld_tab + 2*(200 - p)
fld_set:
        ld a,(fldp+1)
        ld b,a
        ld a,200
        sub b
        ld l,a
        ld h,0
        add hl,hl
        ld de,fld_tab
        add hl,de
        ld (fld_ptr),hl
        ret

logo_ptrs:
        DUP 8, ii
        dw logo_frames + ii*264
        EDUP
jelly_ptrs:
        DUP 8, ii
        dw jelly_tab + ii*480
        EDUP
; HL = HL * DE (16 bit)
mul16:  ld b,h
        ld c,l
        ld hl,0
        ld a,16
.l:     add hl,hl
        sla e
        rl d
        jr nc,.n
        add hl,bc
.n:     dec a
        jr nz,.l
        ret

; ---------------------------------------------------------------------
bootlines:  INCBIN "../build/p1/bootlines.bin"
sub_text:   INCBIN "../build/p1/sub.bin"
glitch_tab: INCBIN "../build/p1/glitch.bin"
fld_tab:    INCBIN "../build/p1/fld.bin"
jelly_tab:  INCBIN "../build/p1/jelly.bin"
traj:       INCBIN "../build/p1/traj.bin"
logo_frames: INCBIN "../build/p1/logo.bin"
speech1:    INCBIN "../build/p1/speech1.bin"
speech1_len EQU $-speech1
scrbuf:     ds 512
p1_end:
        DISPLAY "p1 end: ", p1_end
        ASSERT p1_end <= $FA00
        SAVEBIN "../build/p1.bin", OVL, p1_end - OVL
