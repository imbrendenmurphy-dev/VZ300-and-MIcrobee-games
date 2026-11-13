; =====================================================================
;  RACE.ASM - VZ300 3D racer, Stage 3: first moving track
;  VIBED BY BPM 2026
;  Loads at $8000-$F7FF; maps BennVenn SRAM bank B at $4000 (port $37 = 3).
;  IM2 field interrupt (table $DC00, vector $DDDD) copies the finished
;  frame to video RAM during field sync, ahead of the beam (tear-free).
; =====================================================================
{EQUATES}

        ORG $8000
start:  di
        ld sp,STACKTOP
        ld a,$08
        ld (LATCH),a
        ld (LATCHV),a
        call setup_banks
        call init_vars
{STARTUP}

; =====================================================================
;  main loop
; =====================================================================
main:   CHKEI
        ; elapsed fields since the last frame (1..6)
        ld hl,(FIELDS)
        ld de,(LASTF)
        ld (LASTF),hl
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.cap
        ld a,l
        or a
        jr nz,.e1
        inc a
.e1:    cp 7
        jr c,.e2
.cap:   ld a,6
.e2:    ld (ELAPSED),a
        call state_frame
        call input
        ld a,(ELAPSED)
        ld b,a
.ph:    push bc
        call field_tick
        pop bc
        djnz .ph
        call rv_prep
        call obj_prep
        call dyn_prep
        call mark_build
        call render
        call rv_project
        ; wait until the interrupt has shown the previous frame
.wr:    CHKEI
        ld a,(READY)
        or a
        jr nz,.wr
        call compose
        call draw_hud
        call draw_gates
        call draw_rivals
        call draw_craft
        call draw_banner
        ld a,(SPLAIN)           ; rows TOPROW..CLEAN-1 are plain sky in this frame
        ld b,a
        ld a,(DMIN)
        cp b
        jr nc,.c1
        ld b,a
.c1:    ld a,(CLEAN)            ; copy from the first row that may differ from the screen
        ld c,a
        ld a,b
        ld (CLEAN),a
        cp c
        jr c,.c2
        ld a,c
.c2:    cp TOPROW
        jr nc,.c3
        ld a,TOPROW
.c3:    and $FE
        ld c,a
        ld a,(SPLITMODE)        ; the HUD split needs a fixed copy length
        or a
        jr z,.c4
        ld c,TOPROW
.c4:    ld a,c
        ld (CPYROW),a
        ld a,255
        ld (DMIN),a
        ld a,(SPLITMODE)        ; HUD-strip split: switch back at the top of the 3D view
        cp 2
        ld a,TOPROW
        jr z,.fs
        ld a,(SPLIT)
.fs:    ld (FSPLIT),a
        ld a,1
        ld (READY),a
        ld hl,(FRAMES)
        inc hl
        ld (FRAMES),hl
        jp main

; =====================================================================
;  field interrupt: copy the frame, palette split, count fields
; =====================================================================
isr:    push af
        push bc
        push de
        push hl
        exx
        ex af,af'
        push af
        push bc
        push de
        push hl
        push ix
        push iy
        ld hl,(FIELDS)
        inc hl
        ld (FIELDS),hl
        xor a
        ld (COPIED),a
        ld a,(READY)
        or a
        jr z,.nc
        ld a,(TOPCHG)
        or a
        jr z,.part
        call copy_buffer        ; whole screen
        ld a,1
        jr .cd
.part:  call copy_buffer16      ; sky rows unchanged: copy rows 16..63 only
        ld a,2
.cd:    ld (COPIED),a
        xor a
        ld (TOPCHG),a
        ld (READY),a
        ld a,(FSPLIT)
        ld (DSPLIT),a
.nc:    ld a,(SPLITMODE)
        or a
        jr z,.css0
        ld a,$18                ; sky in colour set 1
        ld (LATCH),a
        ld a,(DSPLIT)           ; delay = base + split*26 loop passes (26 T each)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        add hl,hl
        pop bc
        add hl,bc               ; *24
        add hl,de
        add hl,de               ; *26
        ld a,(COPIED)
        or a
        jr nz,.cp
.wf:    ld a,(LATCH)            ; no copy: wait for the end of field sync first
        rla
        jr nc,.wf
        ld de,DLY_NOCOPY
        jr .dl0
.cp:    ld de,DLY_COPY
        dec a
        jr z,.dl0
        ld de,DLY_COPYP
.dl0:   add hl,de
        ld b,h
        ld c,l
.dl:    dec bc
        ld a,b
        or c
        jr nz,.dl
.css0:  ld a,(LATBASE)          ; colour set 0 (day) or 1 (dusk races)
        ld (LATCH),a
        call sfx_isr
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        ex af,af'
        exx
        ld a,(LATCH)            ; re-enable only once field sync has ended
        rla
        jr nc,.noei
        pop hl
        pop de
        pop bc
        pop af
        ei
        reti
.noei:  pop hl
        pop de
        pop bc
        pop af
        reti

; =====================================================================
;  input: keyboard (, . SPACE N, M toggles palette split) and joystick 1
; =====================================================================
input:  xor a
        ld (STEER),a
        ld (THROT),a
        ld (BRAKE),a
        ld a,(KEYROW)           ; $68EF: bit5 M, bit4 SPACE, bit3 ',', bit1 '.', bit0 N
        cpl
        and $3B
        ld c,a
        in a,($2C)              ; joystick 1 directions (bit0 up, 1 down, 2 left, 3 right)
        cpl
        and $0F
        ld b,a
        in a,($2E)              ; joystick 1 fire (bit4)
        cpl
        and $10
        or b
        ld b,a
        ld a,c
        or b
        ; fire the weapon: M or joystick fire (fresh press, racing only)
        ld a,c
        and $20
        ld d,a
        ld a,b
        and $10
        or d
        ld hl,MPREV
        cp (hl)
        ld (hl),a
        jr z,.nm
        or a
        jr z,.nm
        ld a,(GSTATE)
        cp GS_RACE
        jr nz,.nm
        ld a,(AUTO)
        or a
        jr nz,.nm
        push bc
        call fire
        pop bc
.nm:    ld a,(KEYH)             ; H toggles half-rate rows (edge)
        cpl
        and 1
        ld hl,HPREV
        cp (hl)
        ld (hl),a
        jr z,.nh
        or a
        jr z,.nh
        ld a,(HALFON)
        xor 1
        ld (HALFON),a
.nh:    call mode_upd
        ld a,(AUTO)
        or a
        jr nz,autopilot
        ; steering
        bit 3,c
        jr nz,.l
        bit 2,b
        jr z,.nl
.l:     ld a,-1
        ld (STEER),a
.nl:    bit 1,c
        jr nz,.r
        bit 3,b
        jr z,.nr
.r:     ld a,(STEER)
        inc a
        ld (STEER),a
.nr:    ld a,c                  ; throttle: SPACE or joystick up
        and $10
        ld d,a
        ld a,b
        and $01
        or d
        jr z,.nt
        ld a,1
        ld (THROT),a
.nt:    ld a,c                  ; brake: N or joystick down
        and $01
        ld d,a
        ld a,b
        and $02
        or d
        jr z,.nb
        ld a,1
        ld (BRAKE),a
.nb:    ld a,(AIRT)             ; no steering in the air
        or a
        ret z
        xor a
        ld (STEER),a
        ret

autopilot:
        ld a,1
        ld (THROT),a
        ; target lateral = -(curvature ahead) * 3
        ld hl,(CAM_I)
        ld de,4
        add hl,de
        ld a,h
        and 1
        ld h,a
        ld de,TRK_H
        add hl,de
        ld b,(hl)
        ld hl,(CAM_I)
        ld de,TRK_H
        add hl,de
        ld a,b
        sub (hl)                ; curvature over 4 sections (signed): aim for the inside
        ld b,a
        add a,a
        add a,b                 ; *3
        call sext
        ld de,(CAM_LAT)
        or a
        sbc hl,de               ; target - lat
        ld a,h
        bit 7,a
        jr nz,.left
        or a
        jr nz,.right
        ld a,l
        cp 6
        ret c
.right: ld a,1
        ld (STEER),a
        ret
.left:  inc a
        jr nz,.lft
        ld a,l
        cp -6
        ret nc
.lft:   ld a,-1
        ld (STEER),a
        ret

; =====================================================================
;  physics, one field: forgiving hover handling, no falling off
; =====================================================================
physics:
        ld a,(AIRT)             ; airborne: speed holds
        or a
        jr z,.gnd
        ld a,(SPEED)
        ld b,a
        jp .sp3
.gnd:   call vcap
        ld c,a                  ; C = speed limit (normal, boost, stalled)
        ld a,(SPEED)
        ld b,a
        ld a,(THROT)
        or a
        jr z,.coast
        ld a,b
        cp c
        jr nc,.sp
        inc b
        ld a,(BOOSTT)
        or a
        jr z,.sp
        inc b
        jr .sp
.coast: ld a,(FIELDS)
        and 1
        jr nz,.sp
        ld a,b
        or a
        jr z,.sp
        dec b
.sp:    ld a,(BRAKE)
        or a
        jr z,.sp2
        ld a,b
        sub 3
        jr nc,.sp1
        xor a
.sp1:   ld b,a
.sp2:   ld a,c                  ; above the limit: ease down
        cp b
        jr nc,.sp3
        dec b
.sp3:   ld a,b
        ld (SPEED),a
        ; advance along the track
        ld a,(CAM_F)
        add a,b
        ld (CAM_F),a
        jr nc,.nadv
        ld hl,(CAM_I)
        inc hl
        ld a,h
        and 1
        ld h,a
        ld (CAM_I),hl
        call new_section
.nadv:  ; lateral velocity: steering
        ld a,(STEER)
        ld b,a
        add a,a
        add a,b                 ; *3
        ld b,a
        ld a,(LATV)
        add a,b
        ld (LATV),a
        ; centrifugal push: -(curv * speed) >> 7
        ld hl,(CAM_I)
        inc hl
        inc hl
        ld a,h
        and 1
        ld h,a
        ld de,TRK_H
        add hl,de
        ld b,(hl)
        ld hl,(CAM_I)
        ld de,TRK_H
        add hl,de
        ld a,b
        sub (hl)
        ld b,a
        ld a,(SPEED)
        srl a
        ld c,a
        call mul8
        add hl,hl
        ld a,h                  ; (curv*speed/2) >> 7
        neg
        ld b,a
        ld a,(LATV)
        add a,b
        ld (LATV),a
        ; friction when not steering
        ld a,(STEER)
        or a
        jr nz,.nf
        ld a,(LATV)
        sra a
        sra a
        ld b,a
        ld a,(LATV)
        sub b
        ld (LATV),a
.nf:    ld a,(LATV)             ; clamp to +-12
        bit 7,a
        jr nz,.cn
        cp 13
        jr c,.cok
        ld a,12
        jr .cok
.cn:    cp -12
        jr nc,.cok
        ld a,-12
.cok:   ld (LATV),a
        call sext
        ld de,(CAM_LAT)
        add hl,de
        ld (CAM_LAT),hl
        ; track edges: bounce back, scrub speed (never fall off)
        ld a,h
        bit 7,a
        jr nz,.neg
        or a
        jr nz,.hit
        ld a,l
        cp 61
        jr c,.ok
.hit:   ld hl,60
        jr .bounce
.neg:   inc a
        jr nz,.hitn
        ld a,l
        cp -60
        jr nc,.ok
.hitn:  ld hl,-60
.bounce:
        ld (CAM_LAT),hl
        ld a,(AIRT)             ; scraping the barrier costs a little shield
        ld b,a
        ld a,(BUMPT)
        or b
        jr nz,.nbh
        ld a,12
        ld (BUMPT),a
        ld a,SFX_BUMP
        call sfx
        ld a,2
        call hurt
.nbh:
        ld a,(LATV)
        sra a
        neg
        ld (LATV),a
        ld a,(SPEED)
        srl a
        srl a
        srl a
        ld b,a
        ld a,(SPEED)
        sub b
        ld (SPEED),a
.ok:    ; camera yaw follows the slide a little
        ld a,(LATV)
        sra a
        ld (CAM_TH),a
        ret

; =====================================================================
;  craft sprite (pre-shifted, masked) and HUD
; =====================================================================
draw_craft:
        ; view 0..6 from steering and sideways slide (3 = straight)
        ld a,(LATV)
        sra a
        sra a
        ld b,a
        ld a,(STEER)
        add a,a
        add a,b
        bit 7,a
        jr nz,.fn
        cp 4
        jr c,.fok
        ld a,3
        jr .fok
.fn:    cp -3
        jr nc,.fok
        ld a,-3
.fok:   add a,3
        ld c,a
        cp 2                    ; near-straight: nose up / down on climbs and dips
        jr c,.np
        cp 5
        jr nc,.np
        ld hl,(CAM_I)
        inc hl
        ld a,h
        and 1
        ld h,a
        ld de,TRK_DY
        add hl,de
        ld a,(hl)
        bit 7,a
        jr nz,.dn
        cp 9
        jr c,.np
        ld c,7
        jr .np
.dn:    cp -8
        jr nc,.np
        ld c,8
.np:    ld a,(STEER)            ; x = 50 + steer*2
        add a,a
        add a,50
        ld (CRF),a
        ld hl,SPR_P0            ; frame c: 448 bytes per frame, 112 per pixel shift
        ld de,448
        inc c
        jr .f2
.f1:    add hl,de
.f2:    dec c
        jr nz,.f1
        and 3
        jr z,.s1
        ld de,112
        ld b,a
.s0:    add hl,de
        djnz .s0
.s1:    ex de,hl                ; DE = source
        ld a,(AIRT)             ; jump: rise and fall over the shadow
        or a
        jr z,.gb
        ld b,a
        ld a,(AIRTOT)
        sub b
        cp b
        jr c,.g1
        ld a,b
.g1:    srl a
        cp 11
        jr c,.g2
        ld a,10
.g2:    ld b,a
        jr .g3
.gb:    ld a,(FIELDS)           ; gentle hover bob
        rrca
        rrca
        rrca
        and 1
        ld b,a
.g3:    ld a,CRAFTY+1
        sub b
        call .dest
        ld bc,8*256+7
        call blit
        ld a,(CRF)              ; shadow under it
        and 3
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        sbc hl,de               ; *28
        ld de,SPR_SH
        add hl,de
        ex de,hl
        ld a,CRAFTY+9
        call .dest
        ld bc,2*256+7
        jp blit
.dest:  ld l,a                  ; HL = BUFFER + A*32 + (CRF)/4
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(CRF)
        rrca
        rrca
        and $1F
        ld c,a
        ld b,0
        add hl,bc
        ld bc,BUFFER
        add hl,bc
        ret

; masked sprite: HL = BUFFER address, DE -> (mask, data) pairs, B = rows, C = bytes per row
blit:   push bc
        push hl
        ld b,c
.by:    ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        inc de
        ld (hl),a
        inc hl
        djnz .by
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz blit
        ret

draw_hud:
        ld hl,FCNT              ; 16-frame field count for the F average
        ld a,(ELAPSED)
        ld c,a
        ld a,(FACC)
        add a,c
        jr nc,.fa
        ld a,255
.fa:    ld (FACC),a
        dec (hl)
        jr nz,.fk
        ld (hl),16
        ld (FAVG),a
        xor a
        ld (FACC),a
.fk:    ld a,(HUDFORCE)         ; refresh the text every 4th frame (or after a sky restore)
        or a
        jr nz,.go
        ld a,(hl)
        and 3
        ret nz
.go:    ld hl,HUDBUF            ; two 31-character lines
        ld b,64
.sp:    ld (hl),' '
        inc hl
        djnz .sp
        xor a
        ld (HUDBUF+31),a
        ld (HUDBUF+63),a
        ; line 1: "SPEED nnn  LAP n/3  POS n  n.nF"
        ld hl,s_hud1
        ld de,HUDBUF
        ld bc,24
        ldir
        ld de,HUDBUF+6
        ld a,(SPEED)
        ld l,a
        ld h,0
        ld bc,100
        call .dig
        ld bc,10
        call .dig
        ld a,l
        add a,'0'
        ld (de),a
        ld a,(LAPN)
        cp NLAPS-1
        jr c,.lp
        ld a,NLAPS-1
.lp:    add a,'1'
        ld (HUDBUF+15),a
        ld a,(POS)
        add a,'0'
        ld (HUDBUF+24),a
        ld a,(FAVG)             ; average fields per frame: tenths = sum*10/16
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld de,HUDBUF+27
        ld bc,10
        call .dig
        ld a,'.'
        ld (de),a
        inc de
        ld a,l
        add a,'0'
        ld (de),a
        inc de
        ld a,'F'
        ld (de),a
        ; line 2: "TIME m:ss  ########  MISSILE" or the demo prompt
        ld a,(GSTATE)
        or a
        jr nz,.race
        ld hl,s_demo
        ld de,HUDBUF+32
        ld bc,18
        ldir
        jr .nhh
.race:  ld hl,s_time
        ld de,HUDBUF+32
        ld bc,5
        ldir
        ld hl,(RTIME)
        call fmt_time
        dec de                  ; whole seconds only here (fewer redraws)
        ld a,' '
        ld (de),a
        dec de
        ld (de),a
        ld a,(SHIELD)           ; shield bar: one block per 8
        rrca
        rrca
        rrca
        and 15
        ld b,a
        ld hl,HUDBUF+32+11
        ld c,8
.bar:   ld a,b
        or a
        ld a,'-'
        jr z,.be
        dec b
        ld a,'#'
.be:    ld (hl),a
        inc hl
        dec c
        jr nz,.bar
        ld a,(WEAPON)           ; weapon in hand
        or a
        jr z,.nhh
        ld hl,s_msl
        ld bc,7
        dec a
        jr z,.wp
        ld hl,s_mine
        ld bc,4
.wp:    ld de,HUDBUF+32+21
        ldir
.nhh:   ld a,(HUDFORCE)         ; redraw each line only when its text changed
        ld (.frc+1),a
        xor a
        ld (HUDFORCE),a
        ld hl,HUDBUF
        ld de,HUDPREV
        ld a,1
        call .line
        ld hl,HUDBUF+32
        ld de,HUDPREV+32
        ld a,8
.line:  push af                 ; A = first row, HL = text, DE = previous text
        push hl
        push de
.frc:   ld a,0
        or a
        jr nz,.ch
        ld b,32
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.ch
        inc hl
        inc de
        djnz .cmp
        pop de
        pop hl
        pop af
        ret
.ch:    pop de
        pop hl
        push hl
        ld bc,32                ; remember it
        ldir
        pop hl
        pop af
        push hl
        ld l,a                  ; clear the line's 5 rows back to sky
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        ld de,SKYIMG
        add hl,de
        ex (sp),hl
        ld de,BUFFER
        add hl,de
        ex de,hl
        pop hl
        push de
        ld bc,5*32
        ldir
        pop de
        inc de                  ; text starts one column in
        pop hl
        ld a,1
        ld (TOPCHG),a
        jp text_t
.dig:   ld a,'0'
.d1:    or a
        sbc hl,bc
        jr c,.d2
        inc a
        jr .d1
.d2:    add hl,bc
        ld (de),a
        inc de
        ret

text:   ; HL -> zero-terminated text, DE -> buffer address (one byte per glyph column)
.ch:    ld a,(hl)
        or a
        ret z
        push hl
        push de
        sub 32
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,FONT
        add hl,bc
        ld b,5
.gr:    ld a,(hl)
        push hl
        add a,GLYPHT & 255
        ld l,a
        ld h,GLYPHT/256
        ld a,(hl)
        ld (de),a
        pop hl
        inc hl
        ex de,hl
        ld a,l
        add a,32
        ld l,a
        jr nc,.nc
        inc h
.nc:    ex de,hl
        djnz .gr
        pop de
        pop hl
        inc de
        inc hl
        jr .ch

s_hud1: DB "SPEED 000  LAP 1/3  POS 1"
s_speed: DB "SPEED "

text_t: ; transparent text: only the glyph pixels are drawn, in HUDFG colour
.ch:    ld a,(hl)
        or a
        ret z
        cp ' '
        jr nz,.gl
        inc hl
        inc de
        jr .ch
.gl:
        push hl
        push de
        sub 32
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,FONT
        add hl,bc
        ld b,5
.gr:    ld a,(hl)
        push hl
        add a,GLYPHM & 255
        ld l,a
        ld h,GLYPHM/256
        ld c,(hl)               ; mask of lit pixels
        ld a,(HUDFG)
        and c
        ld h,a
        ld a,c
        cpl
        ex de,hl
        and (hl)
        ex de,hl
        or h
        ld (de),a
        pop hl
        inc hl
        ex de,hl
        ld a,l
        add a,32
        ld l,a
        jr nc,.nc
        inc h
.nc:    ex de,hl
        djnz .gr
        pop de
        pop hl
        inc de
        inc hl
        jr .ch

; display mode: 0 game (open sky, skyline), 1 attract (sunset sky in colour
; set 1, split at the horizon), 2 game with the HUD strip in colour set 1
mode_upd:
        ld a,(AUTO)
        or a
        ld a,ATTRACT_MODE
        jr nz,.m
        ld a,(MSPLIT)
        add a,a
.m:     ld hl,CURMODE
        cp (hl)
        ret z
        ld (hl),a
        ld (SPLITMODE),a
        or a
        jr z,.m0
        dec a
        jr z,.m1
        ld hl,SKYH
        ld a,1
        ld b,$FF
        jr .set
.m1:    ld hl,SKY1
        xor a
        ld b,$FF
        jr .set
.m0:    ld hl,SKYA
        ld a,1
        ld b,$55
.set:   ld (SKYTAB),hl
        ld (SKYLN),a
        ld a,b
        ld (HUDFG),a
        ld a,1
        ld (HUDFORCE),a
        jp make_sky_top

; title card with the colour-set split (title block in set 1); ~3 s, interrupts off
title_card:                     ; HL = routine that draws the lower half
        di
        ld (LOWERFN),hl
        call cls_buf
        ld de,BUFFER            ; sunset gradient behind the title (shown in colour set 1)
        ld c,0
.g:     ld hl,.bands
.gb:    ld a,c
        cp (hl)
        inc hl
        jr nc,.gn
        ld a,(hl)
        bit 0,c
        jr z,.ge
        add a,16
.ge:    add a,PATTAB & 255
        ld l,a
        ld h,PATTAB/256
        ld a,(hl)
        ld b,32
.gf:    ld (de),a
        inc de
        djnz .gf
        inc c
        ld a,c
        cp 34
        jr nz,.g
        jr .tt
.gn:    inc hl
        jr .gb
.bands: DB 23,1, 26,9, 31,2, 33,10, 34,3
.tt:    ld a,(HUDFG)
        push af
        xor a                   ; buff text
        ld (HUDFG),a
        call draw_logo
        ld hl,s_credit
        ld de,BUFFER+32*27+7
        call text_t
        pop af
        ld (HUDFG),a
        ld hl,(LOWERFN)
        call jp_hl
        ld hl,BUFFER
        ld de,VRAM
        ld bc,2048
        ldir
        ld b,150
.w:     ld a,(LATCH)            ; field sync: title block in colour set 1
        rla
        jr c,.w
        ld a,$18
        ld (LATCH),a
.w2:    ld a,(LATCH)            ; end of sync, then count down to row 34
        rla
        jr nc,.w2
        ld de,TDLY
.t:     dec de
        ld a,d
        or e
        jr nz,.t
        ld a,$08
        ld (LATCH),a
        djnz .w
        xor a                   ; the game screen must be rebuilt in full
        ld (CLEAN),a
        ld a,1
        ld (SKYDIRTY),a
        ld (TOPCHG),a
        ld hl,(FIELDS)
        ld (LASTF),hl
        ret

{GAME}

; map SRAM bank B, build the sprites there and move the track tables in
setup_banks:
        call expand_sprites
        ld hl,STG_TRK
        ld de,TRK_H
        ld bc,2048
        ldir
        ret

jp_hl:  jp (hl)

init_vars:
        ld hl,VARS              ; clear variables
        ld b,0
.c:     ld (hl),0
        inc hl
        djnz .c
        ld a,1
        ld (AUTO),a
        ld hl,GVARS             ; clear game variables and rivals
        ld b,160
.g:     ld (hl),0
        inc hl
        djnz .g
        ld a,HALF_INIT
        ld (HALFON),a
        ld a,16
        ld (FCNT),a
        ld (TOPCHG),a
        ld a,255
        ld (CURMODE),a
        call make_skyline
        call mode_upd
        ld hl,4
        ld (CAM_I),hl
        ret

; clear the screen buffer to blue and show it
cls_buf:
        ld hl,BUFFER
        ld de,BUFFER+1
        ld bc,2047
        ld (hl),$AA
        ldir
        ret

{ENGINE}

{COPY}
@code_end_real:

        ALIGN 256
FILL2:
{FILL}
        jp (iy)

; DRAW_LOGO: unpack the MAX Q logo (run-length coded) into BUFFER rows LOGO_TOP..
; byte = code<<6 | (run-1); code 0 cream, 1 orange, 2 magenta, 3 leave as is
draw_logo:
        ld hl,LOGO
        ld de,BUFFER+LOGO_TOP*32
        ld c,0                  ; pixel within the byte
.lb:    ld a,(hl)
        inc hl
        push hl
        ld b,a
        and $3F
        inc a
        ld ixl,a                ; run length
        ld a,b
        rlca
        rlca
        and 3
        cp 3
        jr z,.skp
        cp 1
        jr nz,.cm
        ld a,3
.cm:    ld h,a                  ; colour
.pl:    ld a,h
        rrca
        rrca
        ld l,$3F
        ld b,c
        inc b
.sh:    dec b
        jr z,.pw
        rrca
        rrca
        rrc l
        rrc l
        jr .sh
.pw:    ld b,a
        ld a,(de)
        and l
        or b
        ld (de),a
        call .adv
        dec ixl
        jr nz,.pl
        jr .nb
.skp:   call .adv
        dec ixl
        jr nz,.skp
.nb:    pop hl
        ld a,l
        cp (LOGO+LOGO_N)&255
        jr nz,.lb
        ld a,h
        cp (LOGO+LOGO_N)/256
        jr nz,.lb
        ret
.adv:   inc c
        bit 2,c
        ret z
        ld c,0
        inc de
        ret
@logo_end:

{DATA}
