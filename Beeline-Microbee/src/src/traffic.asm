; ==========================================================================
; traffic.asm - rival cars                                 ViBED by BPM 2026
;
;  World : NT cars, each with a track position in the same 16-bit ring units
;          as camPos (256 per segment), a lane offset (lx, +-128 = road
;          edge), speed and target speed.  Cars further than ~30 segments
;          are dropped; new ones are spawned out of sight ahead (or behind,
;          when the player dawdles).  RIVALS counts the cars ahead of the
;          player in the whole field, so overtaking really moves you up.
;  Screen: traffic_prep projects each visible car between two projected
;          road points and builds an instance (rows, columns, sprite strip
;          pointer).  traffic_row composites the car cells of the road row
;          just written: each cell gets a fresh PCG slot of the row's bank,
;          built from the ground under it (slot records) and the sprite's
;          (notmask, ink) strip by cellcomp.  Rows hidden behind a crest are
;          clipped with the point's occlusion line.
; ==========================================================================

NT      equ 6                   ; car slots
CARSZ   equ 10                  ; act, pos(2), spd(2), tspd(2), lx, tlx, ahead
PLAYZ   equ 280                 ; player car: world units ahead of the camera
MINDZ   equ 300                 ; nearest drawn car
MAXDZ   equ 17*256              ; furthest drawn car (last projected point = 18)
FIELD   equ 19                  ; rivals in the race

; --------------------------------------------------------------------------
; traffic_reset: starting grid - five rivals lined up ahead, the rest of the
;                field further up the road
; --------------------------------------------------------------------------
traffic_reset:
        ld hl,TCARS
        ld b,NT*CARSZ
.z      ld (hl),0
        inc hl
        djnz .z
        ld a,FIELD
        ld (rivals),a
        call set_pace
        ld hl,30*256
        ld (gapnext),hl
        xor a
        ld (spawnt),a
        ld (bumpt),a
        ld (tevents),a
        ld ix,TCARS
        ld hl,GRID
        ld b,5
.g      ld (ix+0),1
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+1),e
        ld (ix+2),d
        ld (ix+3),0
        ld (ix+4),0
        ld a,(hl)
        inc hl
        ld (ix+7),a
        ld (ix+8),a
        ld (ix+9),1
        push hl
        call rival_speed
        ld (ix+5),l
        ld (ix+6),h
        pop hl
        ld de,CARSZ
        add ix,de
        djnz .g
        ret
GRID:   dw 520
        db -40
        dw 900
        db 40
        dw 1280
        db -40
        dw 1660
        db 40
        dw 2100
        db 0

; set_pace: (rspd) = the rivals' average pace on this leg
set_pace:
        ld a,(leg)
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b
        add a,a                 ; leg*14
        ld e,a
        ld d,0
        ld hl,290+24
        add hl,de
        ld (rspd),hl
        ret

; rival_speed: HL = target speed for a new rival: pace -24 .. +23
rival_speed:
        call rnd
        and 47
        ld e,a
        ld d,0
        ld hl,(rspd)
        add hl,de
        ld de,-24
        add hl,de
        ret

; rnd: 16-bit xorshift -> A (uses HL only)
rnd:    ld hl,(rseed)
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
        ld (rseed),hl
        ret

; --------------------------------------------------------------------------
; traffic_move: once per frame, (dt) fields of rival motion
; --------------------------------------------------------------------------
traffic_move:
        ld a,(gstate)           ; rivals wait on the grid for the start
        cp GS_COUNT
        ret z
        ld ix,TCARS
        ld b,NT
.c      ld a,(ix+0)
        or a
        jr z,.nx
        push bc
        ld a,(dt)
        ld b,a
        ld l,(ix+3)             ; speed towards target, 3 per field
        ld h,(ix+4)
        ld e,(ix+5)
        ld d,(ix+6)
.sl     push hl
        or a
        sbc hl,de
        pop hl
        jr z,.sp
        jr nc,.dn
        inc hl
        inc hl
        inc hl
        jr .s1
.dn     dec hl
        dec hl
        dec hl
.s1     djnz .sl
.sp     ld (ix+3),l
        ld (ix+4),h
        srl h                   ; pos += dt * speed/4
        rr l
        srl h
        rr l
        ex de,hl
        ld l,(ix+1)
        ld h,(ix+2)
        ld a,(dt)
        ld b,a
.pa     add hl,de
        djnz .pa
        ld (ix+1),l
        ld (ix+2),h
        ld a,(dt)               ; lane drift, 1 per field
        ld b,a
.ld     ld a,(ix+8)
        sub (ix+7)
        jr z,.ldd
        ld a,(ix+7)
        jp m,.lm
        inc a
        jr .ls
.lm     dec a
.ls     ld (ix+7),a
        djnz .ld
.ldd    pop bc
.nx     ld de,CARSZ
        add ix,de
        djnz .c
        ret

; --------------------------------------------------------------------------
; traffic_update: once per frame - overtakes, collisions, despawn, spawn
;   events (tevents): bit0 overtook a rival, bit1 got overtaken, bit2 crash,
;   bit3 slipstream boost
; --------------------------------------------------------------------------
traffic_update:
        ld a,(bumpt)
        or a
        jr z,.b0
        dec a
        ld (bumpt),a
.b0     xor a
        ld (nahead),a
        ld ix,TCARS
        ld b,NT
.c      push bc
        ld a,(ix+0)
        or a
        jp z,.nx
        ld l,(ix+1)             ; d = pos - camPos
        ld h,(ix+2)
        ld de,(camPos)
        or a
        sbc hl,de
        ld (.d),hl
        ld de,-1024             ; well behind: gone
        call cmp_signed
        jr nc,.nb
        xor a
        ld (ix+0),a
        jp .nx
.nb     ld de,32*256            ; far ahead: gone (still counted ahead)
        call cmp_signed
        jr c,.nf
        xor a
        ld (ix+0),a
        jp .nx
.nf     ld de,PLAYZ             ; ahead of the player car?
        call cmp_signed
        ld a,0
        jr c,.ah
        inc a
.ah     cp (ix+9)
        jr z,.same
        ld (ix+9),a
        ld c,a
        ld a,(ix+0)             ; ordinary traffic does not count
        cp 2
        jr z,.same
        ld a,c
        or a
        ld hl,rivals
        jr nz,.passedme
        ld a,(hl)               ; we overtook it
        or a
        jr z,.same
        dec (hl)
        ld hl,tevents
        set 0,(hl)
        jr .same
.passedme
        ld a,(hl)
        cp FIELD
        jr nc,.same
        inc (hl)
        ld hl,tevents
        set 1,(hl)
.same   ld a,(ix+0)
        cp 1
        jr nz,.col
        ld a,(ix+9)
        or a
        jr z,.col
        ld hl,nahead
        inc (hl)
.col    ; slipstream: right behind it (PLAYZ+60 .. +640) and in line
        ld hl,(.d)
        ld de,PLAYZ+60
        call cmp_signed
        jr c,.coll
        ld de,PLAYZ+640
        call cmp_signed
        jr nc,.coll
        ld a,(ix+7)
        call lx_world
        ld de,(camX)
        or a
        sbc hl,de
        bit 7,h
        call nz,neghl
        ld de,44
        or a
        sbc hl,de
        jr nc,.coll
        ld a,1
        ld (slipc),a
.coll   ; collision: |d - PLAYZ| < 150 and |x - camX| < 64
        ld a,(bumpt)
        or a
        jp nz,.nx
        ld hl,(.d)
        ld de,PLAYZ
        or a
        sbc hl,de
        bit 7,h
        call nz,neghl
        ld de,150
        or a
        sbc hl,de
        jp nc,.nx
        ld a,(ix+7)             ; world x = lx * 25/16
        call lx_world
        ld (.x),hl
        ld de,(camX)
        or a
        sbc hl,de
        bit 7,h
        call nz,neghl
        ld de,64
        or a
        sbc hl,de
        jp nc,.nx
        ; crash!  lose speed, nudge apart
        ld hl,tevents
        set 2,(hl)
        ld a,10
        ld (bumpt),a
        ld hl,(.d)              ; rival ahead: we run into its back
        ld de,PLAYZ
        call cmp_signed
        jr c,.behind
        ld l,(ix+3)
        ld h,(ix+4)
        ld de,-60
        add hl,de
        bit 7,h
        jr z,.s1
        ld hl,0
.s1     ex de,hl
        ld hl,(speed)
        call cmp_signed
        jr c,.s2
        ld (speed),de
.s2     ld l,(ix+1)             ; and shove it on a little
        ld h,(ix+2)
        ld de,96
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        jr .side
.behind ld l,(ix+3)             ; it ran into us: it loses speed
        ld h,(ix+4)
        ld de,-80
        add hl,de
        ld (ix+3),l
        ld (ix+4),h
.side   ld hl,(camX)            ; push the player sideways, away from it
        ld de,(.x)
        call cmp_signed
        ld de,28
        jr nc,.sr
        ld de,-28
.sr     add hl,de
        ld (camX),hl
.nx     ld de,CARSZ
        add ix,de
        pop bc
        dec b
        jp nz,.c
        ; slipstream: 0.9 s in a rival's wake at speed -> a boost
        ld a,(slipc)
        or a
        jr z,.ns
        xor a
        ld (slipc),a
        ld hl,(speed)
        ld de,260
        call cmp_signed
        jr c,.ns
        ld a,(boostt)
        or a
        jr nz,.ns
        ld a,(dt)
        ld b,a
        ld a,(slipt)
        add a,b
        ld (slipt),a
        cp 45
        jr c,.sd
        ld a,100
        ld (boostt),a
        ld hl,tevents
        set 3,(hl)
.ns     xor a
        ld (slipt),a
.sd
        ; occasional lane change
        call rnd
        and 31
        jr nz,.sp
        call rnd
        and 7
        cp NT
        jr nc,.sp
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; *10
        ld de,TCARS
        add hl,de
        push hl
        call rnd
        and 3
        ld e,a
        ld d,0
        ld hl,LANES
        add hl,de
        ld a,(hl)
        pop hl
        ld de,8
        add hl,de
        ld (hl),a
.sp     ; spawning.  gapnext = distance to the next rival ahead that is not
        ; on the road yet; it closes at (our speed - the rivals' pace)
        ld hl,(speed)
        ld de,(rspd)
        or a
        sbc hl,de
        sra h
        rr l
        sra h
        rr l                    ; (speed - pace)/4 per field
        ld a,(dt)
        ld b,a
        ex de,hl
        ld hl,(gapnext)
.gp     or a
        sbc hl,de
        djnz .gp
        bit 7,h
        jr z,.g0
        ld hl,0
.g0     ld de,60*256
        call cmp_signed
        jr c,.g1
        ex de,hl
.g1     ld (gapnext),hl
        ld a,(spawnt)
        or a
        jr z,.sp1
        dec a
        ld (spawnt),a
        ret
.sp1    ld a,(nahead)           ; rivals ahead that are not on the road yet?
        ld b,a
        ld a,(rivals)
        cp b
        jp z,.spb
        jp c,.spb
        ld hl,(gapnext)         ; close enough to come into view?
        ld de,27*256
        call cmp_signed
        jr nc,.civ
        call free_car
        ret nc
        ld de,(camPos)          ; just out of sight ahead
        ld hl,27*256
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        call rival_speed
        ld (ix+3),l
        ld (ix+4),h
        ld (ix+5),l
        ld (ix+6),h
        ld (ix+9),1
        call rnd                ; the next one: 6..29 segments further on
        and 15
        ld b,a
        call rnd
        and 7
        add a,b
        add a,6+27
        ld h,a
        ld l,0
        ld (gapnext),hl
        ld a,1
        jp .lane
.civ    call rnd                ; ordinary traffic now and then
        and 7
        jr nz,.spn
        call free_car
        ret nc
        ld de,(camPos)
        ld hl,27*256
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        call rnd
        and 63
        ld l,a
        ld h,0
        ld de,190
        add hl,de
        ld (ix+3),l
        ld (ix+4),h
        ld (ix+5),l
        ld (ix+6),h
        ld (ix+9),1
        ld a,2
        jr .lane
.spn    ld a,6
        ld (spawnt),a
        ret
.spb    ld a,(rivals)           ; dawdling: someone from behind comes past
        cp FIELD
        jr nc,.civ
        ld hl,(rspd)
        ld de,-70
        add hl,de
        ex de,hl
        ld hl,(speed)
        call cmp_signed
        jr nc,.civ
        call free_car
        ret nc
        ld de,(camPos)
        ld hl,-700
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld hl,(rspd)
        ld de,30
        add hl,de
        ld (ix+3),l
        ld (ix+4),h
        ld (ix+5),l
        ld (ix+6),h
        ld (ix+9),0
        ld a,1
.lane   ld (ix+0),a
        call rnd
        and 3
        ld e,a
        ld d,0
        ld hl,LANES
        add hl,de
        ld a,(hl)
        ld (ix+7),a
        ld (ix+8),a
        call rnd
        and 15
        add a,20
        ld (spawnt),a
        ret
.d      dw 0
.x      dw 0
LANES:  db -84,-28,28,84

; free_car: IX -> a free car slot, carry set; NC if none
free_car:
        ld ix,TCARS
        ld b,NT
        ld de,CARSZ
.f      ld a,(ix+0)
        or a
        scf
        ret z
        add ix,de
        djnz .f
        or a
        ret

; lx_world: A = lane offset -> HL = world x = lx * 25/16
lx_world:
        ld l,a
        rlca
        sbc a,a
        ld h,a
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl
        add hl,hl               ; *24
        add hl,de               ; *25
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ret

; --------------------------------------------------------------------------
; traffic_prep: after project - instances of the visible cars, far first
; --------------------------------------------------------------------------
traffic_prep:
        call vbpoll
        ld hl,RECROW            ; car rows always keep slot records
        ld b,16
        xor a
.cl     ld (hl),a
        inc hl
        djnz .cl
        ld a,1
        ld (RECROW+13),a
        ld (RECROW+14),a
        ld (RECROW+15),a
        xor a
        ld (ninst),a
        ; visible cars -> VIS (d, car index), then far first
        ld ix,TCARS
        ld iy,VIS
        ld bc,NT*256            ; B = cars, C = visible count
.k      ld a,(ix+0)
        or a
        jr z,.kn
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,(camPos)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.kn
        ld de,MINDZ
        or a
        sbc hl,de
        jr c,.kn
        ld de,MAXDZ-MINDZ
        sbc hl,de
        jr nc,.kn
        ld de,MAXDZ
        add hl,de               ; d again
        ld (iy+0),l
        ld (iy+1),h
        ld a,NT
        sub b
        ld (iy+2),a
        inc iy
        inc iy
        inc iy
        inc c
.kn     ld de,CARSZ
        add ix,de
        djnz .k
        ld a,c
        or a
        ret z
        ld (.nv),a
        ; selection: each pass takes the furthest remaining entry
.pick   ld iy,VIS
        ld hl,0
        ld (.best),hl
        ld a,(.nv)
        ld b,a
.pl     ld l,(iy+0)
        ld h,(iy+1)
        ld de,(.best)
        or a
        sbc hl,de
        jr c,.pn
        jr z,.pn
        add hl,de
        ld (.best),hl
        ld (.bp),iy
.pn     inc iy
        inc iy
        inc iy
        djnz .pl
        ld hl,(.best)
        ld a,h
        or l
        ret z
        ld iy,(.bp)
        ld a,(iy+2)
        ld (iy+0),0
        ld (iy+1),0
        ld l,a                  ; IX -> car
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld de,TCARS
        add hl,de
        push hl
        pop ix
        call vbpoll
        ld hl,(.best)
        call car_inst
        jp .pick
.best   dw 0
.bp     dw 0
.nv     db 0

; car_inst: HL = d (MINDZ..MAXDZ), IX -> car  -> appends an instance
car_inst:
        ld (ci_d),hl
        ; bracket the car between projected points p and p+1:
        ; point p lies at 256*PK[p] - 8*fq, PK = 1..4 then 6, 8 .. 18
        ld a,(camPos)
        and 0F8h
        ld e,a
        ld d,0
        add hl,de               ; d' = d + 8*fq: segment k = d'>>8
        ld a,h
        cp 4
        jr nc,.far
        ld b,a                  ; p = k, t = d' & 255
        jr .t1
.far    sub 4                   ; p = 4 + (k-4)/2, t = ((k-4)&1 : d'&255) / 2
        srl a
        rr l                    ; carry = (k-4)&1 -> top bit of t
        add a,4
        ld b,a
.t1     ld a,b
        or a
        ret z                   ; nearer than point 1
        inc a
        ld c,a
        ld a,(kmax)
        cp c
        ret c                   ; beyond the last projected point: hidden
        ld a,l
        ld (ci_t),a
        ld l,b                  ; IY -> record p (record p+1 at +8)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PTS
        add hl,de
        push hl
        pop iy
        ld a,(iy+15)            ; occlusion line in front of the car
        ld (ci_clip),a
        or a
        ret z
        ; sy, sw, sx by linear interpolation
        ld l,(iy+0)
        ld h,(iy+1)
        ld e,(iy+8)
        ld d,(iy+9)
        ld a,(ci_t)
        call lerpf
        ld (ci_sy),hl
        ld l,(iy+4)
        ld h,(iy+5)
        ld e,(iy+12)
        ld d,(iy+13)
        ld a,(ci_t)
        call lerpf
        ld a,h
        or a
        ld a,l
        jr nz,.swmax
        cp 128
        jr c,.swok
.swmax  ld a,127
.swok   ld (ci_sw),a
        ld l,(iy+2)
        ld h,(iy+3)
        ld e,(iy+10)
        ld d,(iy+11)
        ld a,(ci_t)
        call lerpf
        ld (ci_sx),hl
        ; size
        ld a,(ci_sw)
        ld e,a
        ld d,0
        ld hl,SWSCALE
        add hl,de
        ld a,(hl)
        cp 0FFh
        ret z
        rrca
        rrca
        rrca                    ; *32
        ld e,a
        ld hl,SCALETAB
        add hl,de
        push hl
        pop iy                  ; IY -> SCALETAB entry
        ; centre x (logical) = sx + lx*sw/128
        ld a,(ix+7)
        ld (.lx),a
        bit 7,a
        jr z,.lp
        neg
.lp     ld e,a
        ld a,(ci_sw)
        call mul8q
        add hl,hl
        ld l,h
        ld h,0
        ld a,(.lx)
        bit 7,a
        call nz,neghl
        ld de,(ci_sx)
        add hl,de
        ; left screen px = 2*cx - W/2
        add hl,hl
        ld a,(iy+0)
        srl a
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld a,l
        and 7
        srl a
        ld (ci_shift),a
        sra h                   ; column = left >> 3
        rr l
        sra h
        rr l
        sra h
        rr l
        ld de,-12               ; well off screen?
        call cmp_signed
        ret c
        ld de,64
        call cmp_signed
        ret nc
        ld a,l
        ld (ci_col),a
        ; columns: cfirst = max(0, -col), clast = min(NC-1, 63-col)
        xor a
        ld c,a
        ld a,l
        bit 7,a
        jr z,.c0
        neg
        ld c,a
.c0     ld a,c
        ld (ci_cf),a
        ld a,63
        sub l
        ld b,a
        ld a,(iy+2)
        dec a
        cp b
        jr c,.c1
        ld a,b
.c1     sub c
        ret c
        inc a
        ld (ci_n),a
        ; vertical: Ytop = 2*sy + 2 - H (screen lines)
        ld hl,(ci_sy)
        add hl,hl
        inc hl
        ld (.yb),hl             ; bottom screen line
        inc hl
        ld e,(iy+1)
        ld d,0
        or a
        sbc hl,de
        ld (ci_ytop),hl
        ; rmin = max(Ytop>>4, LTOP>>3, 1)
        ld a,h
        bit 7,a
        ld a,0
        jr nz,.r0
        ld a,h
        or a
        ret nz
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 0Fh
.r0     ld b,a
        ld a,(LTOP)
        rrca
        rrca
        rrca
        and 1Fh
        cp b
        jr c,.r1
        ld b,a
.r1     ld a,b
        or a
        jr nz,.r2
        inc b
.r2     ld a,b
        ld (ci_r0),a
        ; rmax = min(bottom row, row of (2*clip - 1), 15)
        ld hl,(.yb)
        bit 7,h
        ret nz
        ld a,h
        or a
        ld a,15
        jr nz,.r3
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 0Fh
.r3     ld c,a
        ld a,(ci_clip)
        add a,a
        dec a
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        cp c
        jr nc,.r4
        ld c,a
.r4     ld a,c
        ld (ci_r1),a
        ld a,(ci_r0)
        cp c
        jr z,.ok
        ret nc
.ok     ; strip pointer: base[shift] + 32 + cfirst*stride + 2*(16*r0 - Ytop)
        ld a,(ci_shift)
        add a,a
        add a,6
        ld e,a
        ld d,0
        push iy
        pop hl
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,32
        add hl,de
        ld e,(iy+4)
        ld d,(iy+5)
        ld (.stride),de
        ld a,(ci_cf)
        or a
        jr z,.m1
        ld b,a
.m0     add hl,de
        djnz .m0
.m1     push hl
        ld a,(ci_r0)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(ci_ytop)
        or a
        sbc hl,de
        add hl,hl
        pop de
        add hl,de
        ld (.ptr),hl
        ; light row
        ld a,(iy+3)
        or a
        ld a,0FFh
        jr z,.l0
        ld hl,(ci_ytop)
        ld e,(iy+3)
        ld d,0
        add hl,de
        ld a,h
        or a
        ld a,0FFh
        jr nz,.l0
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 0Fh
.l0     ld (.light),a
        ; append the instance
        ld a,(ninst)
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,INST
        add hl,de
        ld a,(ci_r0)
        ld (hl),a
        inc hl
        ld a,(ci_r1)
        ld (hl),a
        inc hl
        ld a,(ci_col)
        ld b,a
        ld a,(ci_cf)
        add a,b
        ld (hl),a
        inc hl
        ld a,(ci_n)
        ld (hl),a
        inc hl
        ld de,(.ptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(.stride)
        ld (hl),a
        inc hl
        ld a,(.light)
        ld (hl),a
        inc hl
        push hl                 ; light column mask >> cfirst
        ld a,(ci_shift)
        add a,a
        add a,14
        ld e,a
        ld d,0
        push iy
        pop hl
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(ci_cf)
        or a
        jr z,.lm1
        ld b,a
.lm0    srl d
        rr e
        djnz .lm0
.lm1    pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(ci_r0)            ; j0 = 16*r0 - Ytop
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(ci_ytop)
        neg
        add a,b
        ld (hl),a
        ld hl,ninst
        inc (hl)
        ld a,(ci_r0)            ; these rows need slot records
        ld e,a
        ld d,0
        ld hl,RECROW
        add hl,de
        ld a,(ci_r1)
        sub e
        inc a
        ld b,a
.rr     ld a,(hl)
        or 3
        ld (hl),a
        inc hl
        djnz .rr
        ret
.lx     db 0
.yb     dw 0
.stride dw 0
.ptr    dw 0
.light  db 0

; --------------------------------------------------------------------------
; traffic_row: composite the car cells of road row (crow), just written by
;   write_row (slot allocator state sdest/scode/sleft still live)
; --------------------------------------------------------------------------
traffic_row:
        ld a,(crow)
        ld e,a
        ld d,0
        ld hl,RECROW
        add hl,de
        bit 1,(hl)
        ret z
        ld a,(rbank)
        or X1C
        out (PORT_1C),a
        call patch_comp
        ld a,0FFh
        ld (make_grd.done),a
        ld ix,INST
        ld a,(ninst)
        ld b,a
.i      push bc
        ld a,(crow)             ; row within this instance?
        cp (ix+0)
        jp c,.in
        ld c,a
        ld a,(ix+1)
        cp c
        jp c,.in
        ld a,c                  ; k = row - r0
        sub (ix+0)
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,(ix+10)           ; j = j0 + 16k: first strip line of this row
        ld (.j),a
        add a,16                ; offset of the column's (o0,o1): -2*(j+16)
        ld l,a
        rlca
        sbc a,a
        ld h,a
        add hl,hl
        call neghl
        ld (.oo),hl
        ld l,c                  ; strip pointer for this row: ptr + 32k
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,(ix+4)
        ld d,(ix+5)
        add hl,de
        ld (.sp),hl
        ld hl,(raddr)
        ld e,(ix+2)
        ld d,0
        add hl,de
        ld (.scr),hl
        call make_grd
        ld hl,1
        ld (.lbit),hl
        dec l
        ld (.lok),hl
        push iy
        ld iy,(.scr)
        ld b,(ix+3)
.cell   ld a,(sleft)
        or a
        jp z,.full
        dec a
        ld (sleft),a
        push bc
        ld a,(scode)            ; next slot code replaces the ground's code
        ld c,a
        inc a
        ld (scode),a
        ld e,(iy+0)
        ld (iy+0),c
        inc iy
        ld d,high(SLOTMASK)     ; the new slot inherits the ground's records
        ld b,d
        ld a,(de)
        ld (bc),a
        ld l,a                  ; L = mask
        inc d
        inc b
        ld a,(de)
        ld (bc),a
        ld h,a                  ; H = RES page
        ld (.mp),hl
        ld hl,(.sp)             ; ground lines in this cell: gap above + below
        push hl                 ; the column's solid run [o0, o1)
        ld de,(.oo)
        add hl,de
        ld a,(hl)
        cp 255
        jr z,.np                ; no solid lines at all
        add a,16
        ld c,a                  ; O0 = o0+16
        inc hl
        ld a,(hl)
        add a,16
        ld b,a                  ; O1 = o1+16
        ld a,(.j)
        add a,16
        ld e,a                  ; J = j+16 (>= 1)
        ld a,c
        sub e
        jr nc,.g1
        xor a
.g1     ld d,a
        ld a,e
        add a,16
        sub b
        jr nc,.g2
        xor a
.g2     add a,d
        cp 1                    ; all car: may carry the light colour
        jr nc,.np
        ld d,a
        ld hl,(.lbit)
        ld a,(.lok)
        or l
        ld (.lok),a
        ld a,(.lok+1)
        or h
        ld (.lok+1),a
        ld a,d
        or a
        jr z,.opq
.np     pop hl
        ld de,(sdest)
        ld bc,(.mp)
        ld a,b
        cp high(RESPAGES)+2     ; plain road under it?
        jr nz,.gen
        ld a,c
        or a
        jr nz,.gen
        ld bc,GRD
        call tcomp
        jr .made
.gen    push ix
        push hl
        pop ix
        ld h,b
        ld b,high(MASKLIB)
        call cellcomp
        pop ix
        jr .made
.opq    pop hl
        ld de,(sdest)
        call topq
.made   inc de
        ld (sdest),de
        ld hl,(.lbit)
        add hl,hl
        ld (.lbit),hl
        call vbpoll
        ld hl,(.sp)
        ld e,(ix+6)
        ld d,0
        add hl,de
        ld (.sp),hl
        pop bc
        dec b
        jp nz,.cell
        pop iy
        jr .lights
.full   pop iy
.lights ld a,(crow)             ; tail lights: light colour on solid light cells
        cp (ix+7)
        jr nz,.in
        ld a,(.lok)             ; solid light columns that came out mostly car
        and (ix+8)
        ld e,a
        ld a,(.lok+1)
        and (ix+9)
        ld d,a
        or e
        jr z,.in
        ld hl,(raddr)
        ld c,(ix+2)
        ld b,0
        add hl,bc
        ld bc,800h
        add hl,bc
        ld b,(ix+3)
        ld a,40h
        out (PORT_08),a
.lc     srl d
        rr e
        jr nc,.ln
        ld a,(LIGHTCOL)
        ld (hl),a
        push hl                 ; remember it: restored when this page is redrawn
        push de
        ex de,hl
        ld hl,(litp)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(crow)
        push hl
        ld e,a
        ld d,0
        ld hl,ROWCOL
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        inc hl
        ld (litp),hl
        pop de
        pop hl
.ln     inc hl
        djnz .lc
        xor a
        out (PORT_08),a
.in     ld de,16
        add ix,de
        pop bc
        dec b
        jp nz,.i
        ld a,X1C
        out (PORT_1C),a
        ret
.sp     dw 0
.scr    dw 0
.oo     dw 0
.j      db 0
.mp     dw 0
.lbit   dw 0
.lok    dw 0

; make_grd: GRD[2l+s] = plain road pattern of line l, scanline s of this row
make_grd:
        ld a,(.done)
        ld hl,crow
        cp (hl)
        ret z                   ; already built for this row
        ld a,(hl)
        ld (.done),a
        ld hl,PHOFF
        ld de,GRD
.l      ld a,(hl)               ; 0 / 10 / 20 -> 0 / 2 / 4
        inc l
        push hl
        ld c,a
        ld b,0
        ld hl,DIV5
        add hl,bc
        ld c,(hl)
        ld hl,ROADPAT
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc e
        inc hl
        ld a,(hl)
        ld (de),a
        inc e
        pop hl
        ld a,e
        and 15
        jr nz,.l
        ret
.done   db 0FFh

; lit_restore: put back the ground colour of the cells lit last time this
;   page was drawn; litp -> this page's list for the new lights
lit_restore:
        ld a,(page)
        or a
        ld hl,LIT0
        jr z,.p
        ld hl,LIT1
.p      push hl
        ld e,(hl)               ; list end
        inc hl
        ld d,(hl)
        inc hl
        ld a,40h
        out (PORT_08),a
.l      ld a,l                  ; while HL < end
        cp e
        jr nz,.r
        ld a,h
        cp d
        jr z,.done
.r      ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (bc),a
        jr .l
.done   xor a
        out (PORT_08),a
        pop hl
        inc hl
        inc hl
        ld (litp),hl
        ret

; lit_close: store the end of this page's list
lit_close:
        ld a,(page)
        or a
        ld hl,LIT0
        jr z,.p
        ld hl,LIT1
.p      ld de,(litp)
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; lerpf: lerp, with a fast path when both ends are 0..255
lerpf:  ld c,a
        ld a,h
        or d
        ld a,c
        jp nz,lerp
        ld a,e
        sub l
        jr c,.neg
        ld e,a
        ld a,c
        push hl
        call mul8q
        ld e,h
        pop hl
        ld d,0
        add hl,de
        ret
.neg    neg
        ld e,a
        ld a,c
        push hl
        call mul8q
        ld e,h
        pop hl
        ld d,0
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------- variables
rseed:  dw 0ACE1h
rspd:   dw 0
gapnext: dw 0
rivals: db 0                    ; rivals ahead of the player (position - 1)
nahead: db 0
spawnt: db 0
bumpt:  db 0
tevents: db 0
slipc:  db 0
slipt:  db 0
ninst:  db 0
kmax:   db 0
leg:    db 0
ci_d:   dw 0
ci_t:   db 0
ci_clip: db 0
ci_sy:  dw 0
ci_sx:  dw 0
ci_sw:  db 0
ci_shift: db 0
ci_col: db 0
ci_cf:  db 0
ci_n:   db 0
ci_ytop: dw 0
ci_r0:  db 0
ci_r1:  db 0
TCARS:  ds NT*CARSZ
VIS:    ds NT*3
INST:   ds NT*16                ; r0, r1, col0, ncols, strip ptr, stride, light row,
                                ; light column mask, j0 (first strip line of row r0)
RECROW: ds 16                   ; per row: bit0 slot records needed, bit1 traffic
litp:   dw 0
        align 16
GRD:    ds 16
LIT0:   dw LIT0+2               ; lit cells per page: end pointer, (addr, colour) x n
        ds NT*10*3
LIT1:   dw LIT1+2
        ds NT*10*3

        include "../build/tcomp.inc"
