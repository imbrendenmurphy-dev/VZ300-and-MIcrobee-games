; =====================================================================
;  RACE.ASM - VZ300 3D racer, Stage 3: first moving track
;  VIBED BY BPM 2026
;  Loads at $8000, no ROM or DOS calls, no mapper writes.
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
        ld a,(AUTO)             ; attract mode: title card every ~200 frames
        or a
        ld hl,0
        jr z,.at0
        ld hl,(ATIMER)
        inc hl
        ld a,l
        cp 200
        jr c,.at0
        call title_card
        ei
        ld hl,0
.at0:   ld (ATIMER),hl
        call input
        ld a,(ELAPSED)
        ld b,a
.ph:    push bc
        call physics
        pop bc
        djnz .ph
        call render
        ; wait until the interrupt has shown the previous frame
.wr:    CHKEI
        ld a,(READY)
        or a
        jr nz,.wr
        call compose
        call draw_hud
        call draw_gates
        call draw_craft
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
.css0:  ld a,$08                ; track in colour set 0
        ld (LATCH),a
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
        jr z,.idle
        xor a
        ld (IDLE),a
        ld (IDLE+1),a
        ld (AUTO),a
.idle:  ; split toggle on M (edge)
        ld a,c
        and $20
        ld hl,MPREV
        cp (hl)
        ld (hl),a
        jr z,.nm
        or a
        jr z,.nm
        ld a,(MSPLIT)           ; M: colour-set split on the HUD strip
        xor 1
        ld (MSPLIT),a
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
.nr:    ld a,c                  ; throttle: SPACE, joystick up or fire
        and $10
        ld d,a
        ld a,b
        and $11
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
.nb:    ld hl,(IDLE)            ; back to the autopilot after ~5 s idle
        inc hl
        ld (IDLE),hl
        ld de,90
        or a
        sbc hl,de
        ret c
        ld a,1
        ld (AUTO),a
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
        ld a,(SPEED)
        ld b,a
        ld a,(THROT)
        or a
        jr z,.coast
        ld a,b
        cp VMAX
        jr nc,.sp
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
.sp2:   ld a,b
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
        ; viewing angle: steering plus sideways slide, clamped to -2..2
        ld a,(LATV)
        sra a
        sra a
        ld b,a
        ld a,(STEER)
        add a,b
        bit 7,a
        jr nz,.fn
        cp 3
        jr c,.fok
        ld a,2
        jr .fok
.fn:    cp -2
        jr nc,.fok
        ld a,-2
.fok:   add a,2                 ; frame 0..4
        add a,a
        add a,a
        ld (CRF),a              ; frame*4
        ld a,(STEER)            ; x = 50 + steer*2
        add a,a
        add a,50
        ld c,a
        and 3
        ld b,a
        ld a,(CRF)
        add a,b                 ; set index = frame*4 + shift
        add a,a
        ld l,a
        ld h,0
        ld de,SPRTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE -> mask/data pairs (10 rows x 7 bytes)
        ld a,c
        rrca
        rrca
        and $1F
        ld c,a
        ld b,0
        ld hl,BUFFER+CRAFTY*32
        add hl,bc
        ld b,10
.row:   push bc
        push hl
        ld b,7
.byte:  ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        inc de
        ld (hl),a
        inc hl
        djnz .byte
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz .row
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
.go:    ld hl,HUDBUF            ; line 1: "SPEED nnn" ... "n.nF H"
        ld b,28
.sp:    ld (hl),' '
        inc hl
        djnz .sp
        ld (hl),0
        inc hl
        ld a,(AUTO)
        ld (hl),a               ; byte 29: autopilot flag (line 2)
        ld hl,s_speed
        ld de,HUDBUF
        ld bc,6
        ldir
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
        ld a,(FAVG)             ; tenths = sum*10/16 = sum*5/8
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
        ld de,HUDBUF+22
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
        inc de
        ld a,(HALFON)
        or a
        jr z,.nhh
        inc de
        ld a,'H'
        ld (de),a
.nhh:   ld a,(HUDFORCE)         ; sky freshly restored: just draw
        or a
        jr nz,.dr
        ld hl,HUDBUF            ; unchanged text: nothing to do
        ld de,HUDPREV
        ld b,30
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.chg
        inc hl
        inc de
        djnz .cmp
        ret
.chg:   ld hl,SKYIMG+1*32       ; clear the HUD rows back to sky
        ld de,BUFFER+1*32
        ld bc,12*32
        ldir
.dr:    xor a
        ld (HUDFORCE),a
        inc a
        ld (TOPCHG),a
        ld hl,HUDBUF
        ld de,HUDPREV
        ld bc,30
        ldir
        ld hl,HUDBUF
        ld de,BUFFER+1*32+1
        call text_t
        ld a,(AUTO)
        or a
        ret z
        ld hl,s_auto
        ld de,BUFFER+8*32+1
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

s_auto: DB "AUTOPILOT",0
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
title_card:
        di
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
.bands: DB 8,1, 14,9, 22,2, 28,10, 34,3
.tt:    ld a,(HUDFG)
        push af
        xor a                   ; buff text
        ld (HUDFG),a
        ld hl,s_title
        ld de,BUFFER+32*18+9
        call text_t
        ld hl,s_credit
        ld de,BUFFER+32*26+7
        call text_t
        pop af
        ld (HUDFG),a
        ld hl,s_keys1
        ld de,BUFFER+32*40+2
        call text
        ld hl,s_keys2
        ld de,BUFFER+32*48+2
        call text
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
        ld a,1                  ; the game screen must be rebuilt in full
        ld (SKYDIRTY),a
        ld (TOPCHG),a
        ld hl,(FIELDS)
        ld (LASTF),hl
        ret

init_vars:
        ld hl,VARS              ; clear variables
        ld b,0
.c:     ld (hl),0
        inc hl
        djnz .c
        ld a,1
        ld (AUTO),a
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

        ALIGN 256
FILL2:
{FILL}
        jp (iy)

{DATA}
