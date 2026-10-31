; =====================================================================
;  PART 6 : GRAND FINALE                          music orders 38..45
;  Rapid music-synced cuts: tunnel / plasma / rotozoom / kefrens,
;  plasma + credits scroller, speech "YOU THOUGHT THIS WAS IMPOSSIBLE?",
;  closing logo with FLD drop and copper credits.  Never returns.
; =====================================================================
        INCLUDE "ovl.inc"
        INCLUDE "../build/p6/p6const.inc"

RC0     MACRO
        RASTC M0
        ENDM
LUTOP   MACRO lab
        ld a,(hl)
lab = $+1
        add a,0
        ld c,a
        ld a,(bc)
        ld (de),a
        inc hl
        inc e
        ENDM
WA_E    MACRO
        LUTOP pa1
        LUTOP pa2
        WAIT 21
        ENDM
WA_O    MACRO
        LUTOP pa3
        LUTOP pa4
        WAIT 21
        ENDM
WB_E    MACRO
        LUTOP pb1
        LUTOP pb2
        WAIT 21
        ENDM
WB_O    MACRO
        LUTOP pb3
        LUTOP pb4
        WAIT 21
        ENDM
WC_E    MACRO
        LUTOP pc1
        LUTOP pc2
        WAIT 21
        ENDM
WC_O    MACRO
        LUTOP pc3
        LUTOP pc4
        WAIT 21
        ENDM
WD_E    MACRO
        LUTOP pd1
        LUTOP pd2
        WAIT 21
        ENDM
WD_O    MACRO
        LUTOP pd3
        LUTOP pd4
        WAIT 21
        ENDM
SU_PL1  MACRO
        ld hl,(fptr)
        ld de,VRAM
        ld a,(lutp)
        ld b,a
        WAIT 72
        ENDM
SU_PL2  MACRO
        inc d
        WAIT 111
        ENDM
SU_AN   MACRO
        SU_HLDE asrc, VRAM
        ENDM
SU_SC0  MACRO
        SU_HLDE sp0, VRAM+12*32
        ENDM
SU_SC1  MACRO
        SU_HLDE sp1, VRAM+13*32
        ENDM
SU_SC2  MACRO
        SU_HLDE sp2, VRAM+14*32
        ENDM
SU_SC3  MACRO
        SU_HLDE sp3, VRAM+15*32
        ENDM
KEF     MACRO                   ; 103T
        ld a,(bc)
        inc c
        ld l,a
        ld h,HIGH VRAM
        ld (hl),$BD
        inc l
        ld (hl),$55
        inc l
        ld (hl),$7E
        WAIT 43
        ENDM
SU_K    MACRO
        ld bc,(kptr)
        WAIT 93
        ENDM
SU_FLD  MACRO
        SU_SP fld_ptr
        ENDM
SU_LG   MACRO
        SU_HLDE lsrc, VRAM+64
        ENDM

part_entry:
        ld a,(kernel_pairs)
        sub 44+1
        ld (an2),a
        ld a,(kernel_pairs)
        sub 65+65+1
        ld (pl3),a
        ld a,(kernel_pairs)
        sub 65+33+31+16+1
        ld (ps8),a
        ld a,(kernel_pairs)
        sub 25+1
        ld (kf2),a
        ld a,(kernel_pairs)
        sub 57
        ld (lg2),a
        ld hl,tunnel
        ld (asrc),hl
        ld a,HIGH luts
        ld (lutp),a
        ld a,(sram_ok)
        or a
        jr z,.nb
        ld a,3
        out ($37),a             ; rotozoom + speech live in SRAM bank 1
.nb:
dispatch:
        call logic
        call music_apply
        ld a,(effect)
        cp 1
        jp z,f_plasma
        cp 2
        jp z,f_anim
        cp 3
        jp z,f_kef
        cp 4
        jp z,f_pscroll
        cp 5
        jp z,f_logo
        ; 0: tunnel (anim)
f_anim:
        FRAME_START dummy
        SEG an, anx, RC0, 105, SU_AN, W_COPY, W_COPY, an1
        SEG ao, aox, RC0, 105, SU_NONE, W_IDLE, W_IDLE, an2
        FRAME_END
        jp dispatch

f_plasma:
        FRAME_START dummy
        SEG pa, pax, RC0, 105, SU_PL1, WA_E, WA_O, pl1
        SEG pb, pbx, RC0, 105, SU_PL2, WB_E, WB_O, pl1
        SEG pc, pcx, RC0, 105, SU_NONE, W_IDLE, W_IDLE, pl3
        FRAME_END
        jp dispatch

f_kef:
        FRAME_START ktabp
        SEG ka, kax, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, kf1
        SEG kb, kbx, RASTHL, 103, SU_K, KEF, KEF, kf2
        FRAME_END
        ; clear the bar row for the next frame
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,31
        ld (hl),0
        ldir
        jp dispatch

f_pscroll:
        FRAME_START dummy
        SEG qa, qax, RC0, 105, SU_PL1, WC_E, WC_O, pl1
        SEG qb, qbx, RC0, 105, SU_PL2, WD_E, WD_O, ps2
        SEG qc, qcx, RC0, 105, SU_NONE, W_IDLE, W_IDLE, ps3
        SEG qd, qdx, RC0, 105, SU_SC0, W_COPY, W_COPY, ps4
        SEG qe, qex, RC0, 105, SU_SC1, W_COPY, W_COPY, ps4
        SEG qf, qfx, RC0, 105, SU_SC2, W_COPY, W_COPY, ps4
        SEG qg, qgx, RC0, 105, SU_SC3, W_COPY, W_COPY, ps4
        SEG qh, qhx, RC0, 105, SU_NONE, W_IDLE, W_IDLE, ps8
        FRAME_END
        jp dispatch

f_logo:
        FRAME_START etabp
        SEG la, lax, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, lg1
        SEG lb, lbx, RASTHL, 103, SU_FLD, W_IDLEH, W_IDLEH, lg2
        SEG lc, lcx, RAST, 105, SU_LG, W_COPY, W_COPY, lg3
        SEG ld_, ldx, RAST, 105, SU_NONE, W_IDLE, W_IDLE, lg4
        FRAME_END
        jp dispatch

an1:    db 43
an2:    db 0
pl1:    db 64
pl3:    db 0
ps2:    db 32
ps3:    db 30
ps4:    db 3
ps8:    db 0
kf1:    db 24
kf2:    db 0
lg1:    db 30
lg2:    db 0
lg3:    db 22
lg4:    db 1
dummy:  dw 0
ktabp:  dw ktab
etabp:  dw etab
effect: db 0
asrc:   dw 0
fptr:   dw field
lutp:   db 0
tcol:   db 0
oph:    db 0
kptr:   dw 0
kt:     db 0
anim:   db 0
scpos:  dw 0
sp0:    dw 0
sp1:    dw 0
sp2:    dw 0
sp3:    dw 0
pf:     dw 0
said:   db 0
fld_ptr: dw 0
lsrc:   dw logo
traj_i: db 0
landed: db 0
lfr:    db 0

; ---------------------------------------------------------------------
logic:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ; ---- choose effect from song position ----
        ld a,(m_ordnum)
        cp 44
        jp nc,.logo
        cp 42
        jr nc,.ps
        ld b,a
        ld a,(m_row)
        ld c,a
        ld a,b
        cp 40
        jr nc,.fast
        ld a,c                  ; orders 38,39: cut every bar
        rrca
        rrca
        rrca
        rrca
        jr .sel
.fast:  ld a,b
        cp 41
        ld a,c
        jr nz,.f1
        cp 48
        jr c,.f1
        rrca                    ; last bar: strobe every 2 rows
        jr .sel
.f1:    rrca
        rrca
        rrca                    ; every half bar
.sel:   and 3
        ; roto needs bank 1
        cp 2
        jr nz,.s2
        ld b,a
        ld a,(sram_ok)
        or a
        ld a,b
        jr nz,.s2
        xor a
.s2:    ld (effect),a
        jr .anims
.ps:    ld a,4
        ld (effect),a
.anims: ld a,(effect)
        cp 1
        jr z,.dop
        cp 4
        jr nz,.nop
        call scroll_step
.dop:   call plasma_step
.nop:
        ; tunnel / roto frame pointers
        ld a,(anim)
        inc a
        cp 12
        jr c,.a1
        xor a
.a1:    ld (anim),a
        add a,a
        ld h,a
        ld l,0
        ld a,(effect)
        cp 2
        ld de,tunnel
        jr nz,.a2
        ld de,$4000
.a2:    add hl,de
        ld (asrc),hl
        ; kefrens path
        ld a,(kt)
        add a,3
        ld (kt),a
        ld c,a
        ld b,HIGH ksine
        ld (kptr),bc
        ret
.logo:  ; ---- order 44: speech once, then the closing logo ----
        ld a,(said)
        or a
        jr nz,.lg
        inc a
        ld (said),a
        ld a,$80
        call cls
        ld hl,logo
        ld de,VRAM+64
        ld bc,256
        ldir
        ld a,(sram_ok)
        or a
        jr z,.nosp
        ld hl,SPEECH3
        ld de,SPEECH3_LEN
        ld c,M0
        call speech_play
.nosp:  ld hl,credits
        ld de,VRAM+11*32
        ld bc,96
        ldir
        ld a,5
        ld (effect),a
        ld a,200
        call fld_at
.lg:    ; colour cycle the logo
        ld a,(pf)
        and 3
        jr nz,.nc
        ld a,(lfr)
        inc a
        and 3
        ld (lfr),a
.nc:    ld a,(lfr)
        ld l,a
        ld h,0
        ld de,264
        call mul16
        ld de,logo
        add hl,de
        ld (lsrc),hl
        ; drop trajectory, then copper stripes
        ld a,(landed)
        or a
        jr nz,.cop
        ld a,(traj_i)
        ld l,a
        ld h,0
        ld de,traj
        add hl,de
        ld a,(hl)
        cp $FF
        jr z,.land
        ld hl,traj_i
        inc (hl)
        jp fld_at
.land:  ld a,1
        ld (landed),a
.cop:   ld a,(pf)
        rrca
        and 3
        add a,a
        ld l,a
        ld h,0
        ld de,etab+2*62
        add hl,de
        ld (fld_ptr),hl
        ret

fld_at: ; fld_ptr = fld + 2*(200-A)
        ld b,a
        ld a,200
        sub b
        ld l,a
        ld h,0
        add hl,hl
        ld de,fld
        add hl,de
        ld (fld_ptr),hl
        ret

plasma_step:
        ld a,(tcol)
        add a,3
        ld (tcol),a
        ld (pa1),a
        ld (pa2),a
        ld (pa3),a
        ld (pa4),a
        ld (pb1),a
        ld (pb2),a
        ld (pb3),a
        ld (pb4),a
        ld (pc1),a
        ld (pc2),a
        ld (pc3),a
        ld (pc4),a
        ld (pd1),a
        ld (pd2),a
        ld (pd3),a
        ld (pd4),a
        ld a,(m_row)
        and 16
        ld a,HIGH luts
        jr z,.l
        inc a
.l:     ld (lutp),a
        ld a,(oph)
        inc a
        ld (oph),a
        ld l,a
        ld h,HIGH sine64
        ld a,(hl)
        and $3E                 ; keep it inside the 64-row field for 16 visible rows
        srl a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,field
        add hl,de
        ld (fptr),hl
        ret

scroll_step:
        ld a,(pf)
        rrca
        jr nc,.n
        ld hl,(scpos)
        inc hl
        ld de,SCR_CELLS
        or a
        sbc hl,de
        add hl,de
        jr c,.ok
        ld hl,0
.ok:    ld (scpos),hl
.n:     ld hl,(scpos)
        ld a,l
        and 1
        srl h
        rr l
        ld de,scroll
        add hl,de
        or a
        jr z,.p0
        ld de,4*SCR_LEN
        add hl,de
.p0:    ld (sp0),hl
        ld de,SCR_LEN
        add hl,de
        ld (sp1),hl
        add hl,de
        ld (sp2),hl
        add hl,de
        ld (sp3),hl
        ret

lptrs:  dw logo, logo+264, logo+528, logo+792
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

        ALIGN 256
luts:   INCBIN "../build/p6/luts.bin"
sine64: INCBIN "../build/p6/sine64.bin"
ksine:  INCBIN "../build/p6/ksine.bin"
field:  INCBIN "../build/p6/field.bin"
ktab:   INCBIN "../build/p6/ktab.bin"
etab:   INCBIN "../build/p6/etab.bin"
fld:    INCBIN "../build/p6/fld.bin"
traj:   INCBIN "../build/p6/traj.bin"
credits: INCBIN "../build/p6/credits.bin"
logo:   INCBIN "../build/p6/logo.bin"
scroll: INCBIN "../build/p6/scroll.bin"
tunnel: INCBIN "../build/p6/tunnel.bin"
        ds 4,$80
p6_end:
        DISPLAY "p6 end: ", p6_end
        ASSERT p6_end <= $FA00
        SAVEBIN "../build/p6.bin", OVL, p6_end - OVL
