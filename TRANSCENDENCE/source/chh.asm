;=====================================================================
; CHAPTERS III-V: THE ENCOUNTER / AWAKENING / SEPARATION
;=====================================================================
C3_BAR  equ 44
C3_DUR  equ 2048
C4_BAR  equ 60
C4_DUR  equ 3072
C5_BAR  equ 84
C5_DUR  equ 1280

;---------------------------------------------------------------------
; camtrack: HL = track, DE = local time. Entries (13 bytes):
;   t(2) rate(2) tx ty tz yaw(2) pitch zoom(2)
; rate = 65536/(t_next - t); s = smoothstep(((t-t0)*rate)>>16 * 256)
camtrack:
        ld (CTT),de
.find:  push hl
        ld bc,13
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)               ; next t
        pop hl
        ; last entry? rate == 0
        push hl
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        or (hl)
        pop hl
        jr z,.hold
        ; t < next.t ?
        push hl
        ld hl,(CTT)
        or a
        sbc hl,bc
        pop hl
        jr c,.seg
        ld bc,13
        add hl,bc
        jr .find
.hold:  xor a
        ld (CTS),a
        jr .apply0
.seg:   ; s = ((t - t0) * rate) >> 8   (8-bit result)
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; rate
        ld hl,(CTT)
        or a
        sbc hl,de               ; dt
        ; dt * rate >> 16 *256  ==  (dt*rate)>>8 high byte... compute via 8x16 parts
        ; s = (dt * rate) >> 16 in 0..255 (scaled: rate = 16777216/len -> use >>16)
        ex de,hl                ; DE = dt
        call m16x16h            ; A = (DE*BC) >> 16
        ld l,a
        ld h,SMOOTH>>8
        ld a,(hl)
        ld (CTS),a
        pop hl
.apply0:
        ; HL -> entry ; next entry at +13
        push hl
        ld bc,4
        add hl,bc
        ld (CTP),hl             ; current params
        ld bc,13
        add hl,bc
        ld (CTQ),hl             ; next params
        pop hl
        ld a,(CTS)
        ld (HTMP+9),a
        TICK
        ; tx, ty, tz (signed bytes)
        ld b,0
.xyz:   push bc
        call ct8s
        pop bc
        ld hl,CAMTX
        ld e,b
        ld d,0
        add hl,de
        ld (hl),a
        inc b
        ld a,b
        cp 3
        jr nz,.xyz
        ; yaw 16-bit at +3
        ld c,3
        call ct16
        ld a,l
        ld (YAW),a
        TICK
        ; pitch at +5 (unsigned byte)
        ld hl,(CTP)
        ld bc,5
        add hl,bc
        ld a,(hl)
        ld l,a
        ld h,0
        push hl
        ld hl,(CTQ)
        add hl,bc
        ld e,(hl)
        ld d,0
        pop hl
        call lerp16
        ld a,l
        ld (PITCH),a
        ; zoom 16-bit at +6
        ld c,6
        call ct16
        ld (ZOOM),hl
        ret

; signed byte param at offset B -> A
ct8s:   ld hl,(CTP)
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        ld hl,(CTQ)
        add hl,de
        ld e,(hl)
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld a,e
        rla
        sbc a,a
        ld d,a
        call lerp16
        ld a,l
        ret
; 16-bit param at offset C -> HL
ct16:   ld b,0
        ld hl,(CTP)
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld hl,(CTQ)
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        jp lerp16

; A = (DE * BC) >> 16  (DE < 4096 ensures result fits)
m16x16h:
        ld hl,0
        ld a,0
        push ix
        ld ixl,16
        ld ixh,0                ; carry byte accumulator in A:H:L (24-bit)
        ; shift-add from MSB of DE
.l:     add hl,hl
        rla
        ex de,hl
        add hl,hl
        ex de,hl
        jr nc,.n
        add hl,bc
        adc a,0
.n:     dec ixl
        jr nz,.l
        pop ix
        ret

;---------------------------------------------------------------------
; common frame setup for a human chapter
hstart: ld hl,VRAM
        ld c,64
.cl:    ld b,32
.cb:    ld (hl),$AA
        inc hl
        djnz .cb
        TICK
        dec c
        jr nz,.cl
        ld a,$08
        call setmode
        ld a,$AA
        ld (BGCOL),a
        ld hl,nohook
        ld (HEXTRA),hl
        ld (HPOST),hl
        xor a
        ld (PMODE),a
        ld (NOFIG),a
        ld (FEATON),a
        ld (EYES),a
        ld (HEADYAW),a
        ld (BREATH),a
        ld (GHOST),a
        ret

; breathing from time (slow sine)
breathe:
        ld a,(T)
        add a,a
        call sin8
        sra a
        sra a
        sra a
        sra a
        ld (BREATH),a
        ret

; feature switch: FEATON = (ZOOM >= 600)
featauto:
        ld hl,(ZOOM)
        ld de,600
        or a
        sbc hl,de
        ld a,0
        jr c,.f
        inc a
.f:     ld (FEATON),a
        ret

;=====================================================================
ch_encounter:
        call hstart
        ld a,C3_BAR
        call chbegin
.loop:  call ltime
        ld (T),hl
        ld de,C3_DUR
        or a
        sbc hl,de
        ret nc
        ld hl,K_LY
        ld a,N_LY
        ld de,(T)
        call animate
        call breathe
        ld hl,CAM3
        ld de,(T)
        call camtrack
        call featauto
        ; head slowly turns toward the arriving light near the end
        ld hl,(T)
        ld de,1700
        or a
        sbc hl,de
        jr c,.nh
        ld a,l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        cp 22
        jr c,.hy
        ld a,22
.hy:    ld (HEADYAW),a
.nh:    ld hl,ent3
        ld (HEXTRA),hl
        ld hl,spark3
        ld (HPOST),hl
        call hrender
        jp .loop

; the entity hovers in (world units) during the last part of III
ent3:   ld hl,(T)
        ld de,1450
        or a
        sbc hl,de
        ret c
        ; descend from high above toward the head: y from 30 -> -18
        ld c,l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        cp 48
        jr c,.y
        ld a,48
.y:     ld b,a
        ld a,30
        sub b
        ld (EWY),a
        ld a,(T)
        call sin8
        sra a
        sra a
        sra a
        sra a
        add a,14
        ld (EWX),a
        ld a,(T)
        add a,a
        call cos8
        sra a
        sra a
        sra a
        sra a
        sub 40
        ld (EWZ),a
entsph: ld a,(EWX)
        ld b,a
        ld a,(EWY)
        ld c,a
        ld a,(EWZ)
        ld d,a
        ld a,(DUTY2)
        rrca
        rrca
        rrca
        and $0F
        add a,22
        ld e,a
        ld a,2
        jp addworld

; electrical sparks around the entity sphere (BB 2bpp)
spark3: ld hl,(T)
        ld de,1450
        or a
        sbc hl,de
        ret c
sparks: ld a,(NSPH)
        or a
        ret z
        ; entity is the last sphere added: find it (kind 2 with largest index)
        dec a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPL
        add hl,de
        ld a,(hl)
        ld (SPX),a
        inc hl
        ld a,(hl)
        ld (SPY),a
        ld b,10
.l:     push bc
        call rnd
        and 15
        sub 8
        ld hl,SPX
        add a,(hl)
        ld d,a
        call rnd
        and 7
        sub 4
        ld hl,SPY
        add a,(hl)
        ld e,a
        call rnd
        and 1
        ld c,a                  ; green or yellow
        call bplot
        ld a,b
        and 1
        call z,snd
        pop bc
        djnz .l
        TICK
        ret

;=====================================================================
ch_awaken:
        call hstart
        ld a,C4_BAR
        call chbegin
        ld hl,ent4
        ld (HEXTRA),hl
        ld hl,post4
        ld (HPOST),hl
.loop:  call ltime
        ld (T),hl
        ld de,C4_DUR
        or a
        sbc hl,de
        ret nc
        ; animation segment by time
        ld hl,(T)
        ld de,380
        or a
        sbc hl,de
        jr nc,.r
        ld hl,K_LY
        ld a,N_LY
        ld de,0
        call animate
        call breathe
        jr .cam
.r:     ld de,640-380
        or a
        sbc hl,de
        jr nc,.tc
        add hl,de               ; t-380
        ex de,hl
        ld hl,K_RI
        ld a,N_RI
        call animate
        xor a
        ld (BREATH),a
        jr .cam
.tc:    ex de,hl                ; t-640
        ld hl,K_TC
        ld a,N_TC
        call animate
        xor a
        ld (BREATH),a
.cam:   ld hl,CAM4
        ld de,(T)
        call camtrack
        call featauto
        ; eyes open after the entity has entered
        ld hl,(T)
        ld de,410
        or a
        sbc hl,de
        ld a,0
        jr c,.e
        inc a
.e:     ld (EYES),a
        ; head turns back to centre as it wakes
        ld a,22
        ld hl,(T)
        ld de,300
        or a
        sbc hl,de
        jr c,.hy
        xor a
.hy:    ld (HEADYAW),a
        ; the moment of entry: palette flash (CSS) for a few fields
        ld hl,(T)
        ld de,366
        or a
        sbc hl,de
        jr c,.nf
        ld a,h
        or a
        jr nz,.nf
        ld a,l
        cp 10
        jr nc,.nf
        and 2
        ld a,$08
        jr z,.fl
        ld a,$18
.fl:    call setmode
        jr .rend
.nf:    ld a,(MODEB)
        cp $08
        ld a,$08
        call nz,setmode
.rend:  call hrender
        jp .loop

; entity: descends to the forehead (t 0..360), then is gone
ent4:   ld hl,(T)
        ld de,362
        or a
        sbc hl,de
        ret nc
        ; k = t*256/362 ~ t*181>>8 (0..255)
        ld a,(T)
        ld e,a
        ld a,(T+1)
        ld d,a
        ex de,hl
        ld a,181
        call mulhl8             ; HL = t*181
        ld a,h                  ; k
        ld (HTMP+9),a
        ; x: 14 -> 0 ; y: 2 -> -25 ; z: -40 -> -34
        ld hl,14
        ld de,0
        call lerp16
        ld a,l
        ld (EWX),a
        ld hl,2
        ld de,-25
        call lerp16
        ld a,l
        ld (EWY),a
        ld hl,-40
        ld de,-34
        call lerp16
        ld a,l
        ld (EWZ),a
        jp entsph

; HL * A (unsigned) -> HL (low 16 bits of HL*A>>0, HL<512)
mulhl8: ld b,8
        ex de,hl
        ld hl,0
.l:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; filaments from the entity to the face, then sparks
post4:  ld hl,(T)
        ld de,362
        or a
        sbc hl,de
        ret nc
        call sparks
        ld hl,(T)
        ld de,170
        or a
        sbc hl,de
        ret c
        ; 3 jagged filaments from entity toward random points near the head
        ld b,3
.f:     push bc
        ld a,(SPX)
        ld (FLX),a
        ld a,(SPY)
        ld (FLY),a
        ld hl,PJ+24
        ld a,(hl)
        ld (FTX),a
        inc hl
        inc hl
        ld a,(hl)
        ld (FTY),a
        call rnd
        and 31
        sub 16
        ld hl,FTX
        add a,(hl)
        ld (hl),a
        call rnd
        and 15
        sub 8
        ld hl,FTY
        add a,(hl)
        ld (hl),a
        ld b,24
.s:     push bc
        ; step toward target with jitter
        ld a,(FTX)
        ld hl,FLX
        sub (hl)
        call sgn
        ld c,a
        call rnd
        and 3
        jr nz,.nj
        call rnd
        and 2
        dec a
        ld c,a
.nj:    ld a,(FLX)
        add a,c
        ld (FLX),a
        ld d,a
        ld a,(FTY)
        ld hl,FLY
        sub (hl)
        call sgn
        ld c,a
        call rnd
        and 3
        jr nz,.nk
        call rnd
        and 2
        dec a
        ld c,a
.nk:    ld a,(FLY)
        add a,c
        ld (FLY),a
        ld e,a
        ld c,1
        call bplot
        inc d
        ld c,1
        call bplot
        TICK
        pop bc
        djnz .s
        TICK
        pop bc
        dec b
        jp nz,.f
        ret

; A -> sign (-1,0,1)
sgn:    or a
        ret z
        ld a,1
        ret p
        ld a,-1
        ret

;=====================================================================
ch_separate:
        call hstart
        ld a,1
        ld (EYES),a
        ld a,C5_BAR
        call chbegin
        ld hl,ent5
        ld (HEXTRA),hl
        ld hl,post5
        ld (HPOST),hl
.loop:  call ltime
        ld (T),hl
        ld de,C5_DUR
        or a
        sbc hl,de
        ret nc
        ld hl,K_SE
        ld a,N_SE
        ld de,(T)
        call animate
        ld hl,CAM5
        ld de,(T)
        call camtrack
        xor a
        ld (FEATON),a
        ; fade to darkness at the end (blue -> fills to blue)
        call hrender
        jp .loop

; ghost: body spheres converge on the rising consciousness, which then
; continues upward alone (world space; the camera follows it)
ent5:   ld hl,(T)
        ld de,380
        or a
        sbc hl,de
        ret c
        push hl
        srl h
        rr l
        ld a,h
        or a
        ld a,255
        jr nz,.s1
        ld a,l
.s1:    ld (GHSHR),a
        pop hl
        ; rise (units) = (t-380)/10, max 120
        ld c,10
        call div16_8
        cp 120
        jr c,.r1
        ld a,120
.r1:    ld (GHRISE),a
        ; entity world position: chest + (0, rise, 0)
        ld a,(CURJ+3)
        ld b,a
        ld a,(GHRISE)
        ld c,a
        ld a,(CURJ+4)
        add a,c
        jp po,.ny
        ld a,127
.ny:    ld c,a
        ld a,(CURJ+5)
        ld d,a
        ld a,(CAMTX)
        ld e,a
        ld a,b
        sub e
        ld b,a
        ld a,(CAMTY)
        ld e,a
        ld a,c
        sub e
        ld c,a
        ld a,(CAMTZ)
        ld e,a
        ld a,d
        sub e
        ld d,a
        call rot3
        ld ix,HTMP+10
        call proj
        ld hl,HTMP+10
        ld de,EPROJ
        ld bc,7
        ldir
        ld a,(EPROJ)
        ld (FTX),a
        ld a,(EPROJ+2)
        ld (FTY),a
        ld a,(GHSHR)
        cp 255
        jp z,.ent
        ld a,(NSPH)
        ld b,a
        ld c,0
.g:     push bc
        ld a,c
        and 1
        jp nz,.gn
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPL
        add hl,de
        push hl
        pop ix
        ld a,(GHSHR)
        ld (HTMP+9),a
        ld l,(ix+0)
        ld h,0
        ld de,(EPROJ)
        call lerp16
        ld (HTMP+10),hl
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,(EPROJ+2)
        call lerp16
        ld (HTMP+12),hl
        ld a,127
        ld (HTMP+14),a
        ld a,(GHSHR)
        cpl
        ld e,(ix+4)
        call mulu
        ld a,h
        or a
        jr nz,.rk
        inc a
.rk:    inc a
        ld e,a
        ld hl,4080
        ld (HTMP+15),hl
        ld a,5
        push bc
        call addsph
        pop bc
        TICK
.gn:    pop bc
        inc c
        dec b
        jp nz,.g
.ent:   ld hl,EPROJ
        ld de,HTMP+10
        ld bc,7
        ldir
        ld a,127
        ld (HTMP+14),a
        ld a,(DUTY2)
        rrca
        rrca
        rrca
        and 15
        add a,30
        ld e,a
        ld a,2
        jp addsph

; expanding rings + sparks after the convergence
post5:  ld a,(GHSHR)
        cp 255
        ret nz
        call sparks
        ld a,(FTX)
        ld (SPX),a
        ld a,(FTY)
        ld (SPY),a
        ; ring radius from time
        ld hl,(T)
        ld a,l
        and 63
        ld b,a                  ; radius 0..63 cycling
        ld a,(SPX)
        ld (FLX),a
        ld a,(SPY)
        ld (FLY),a
        ld c,0
.p:     push bc
        ld a,c
        call cos8
        ld e,b
        push bc
        call muls
        ld a,h
        ld d,a
        sra d
        add a,d                 ; *1.5
        ld hl,FLX
        add a,(hl)
        ld d,a
        pop bc
        push de
        ld a,c
        call sin8
        ld e,b
        push bc
        call muls
        pop bc
        ld a,h
        ld hl,FLY
        add a,(hl)
        pop de
        ld e,a
        ld a,b
        cp 40
        ld c,1
        jr c,.cy
        ld c,0
.cy:    call bplot
        TICK
        pop bc
        ld a,c
        add a,8
        ld c,a
        jr nz,.p
        TICK
        ret
