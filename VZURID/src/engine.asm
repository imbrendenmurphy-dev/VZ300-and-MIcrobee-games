; =====================================================================
;  VZURID - Uridium-style shoot-'em-up for the VZ300  (Phase 1 engine)
;  Scrolling + animated 180-degree flip + enemies + firing.
;  VIBED BY BPM 2026
;
;  Rendering: the whole 128x56 playfield is redrawn every frame by an
;  unrolled LDI chain from pre-shifted hull data held in a ring buffer
;  (4 pixel phases x 48 byte-columns x 56 rows).  Sprites are drawn over
;  the fresh background band by band, always ahead of the TV beam.
; =====================================================================
LATCH       equ $6800
PORTFS      equ $68FF
VRAM        equ $7000
RING        equ $C000
RAWA        equ $F000
RAWB        equ $F040
V           equ $F100

; ---- variables ----
posFrac     equ V+0
posX        equ V+1
speed       equ V+3
curB        equ V+5
curP        equ V+7
curSlot     equ V+8
ringRc      equ V+9
ringLc      equ V+10
oldB        equ V+11
inbits      equ V+13
flipF       equ V+14
flipTgt     equ V+15
flipTick    equ V+16
shipY       equ V+17
shipXs      equ V+18
bankst      equ V+19
fireCool    equ V+20
frameCnt    equ V+21
lateCnt     equ V+23
minSlack    equ V+25
score       equ V+27
rng         equ V+29
bandIdx     equ V+31
sprCount    equ V+32
sprNext     equ V+33
srcPtr      equ V+35
joyok       equ V+37
gc_slot     equ V+38
rc_b        equ V+39
rc_tab      equ V+40
as_y        equ V+42
as_frm      equ V+43
as_wb       equ V+45
as_h        equ V+46
as_rowlen   equ V+47
as_phsz     equ V+48
as_ph       equ V+49
as_sl       equ V+50
as_vis      equ V+51
as_dcol     equ V+52
col_bx      equ V+53
col_ew      equ V+55
col_eh      equ V+56
pc_row      equ V+57
jobSt       equ V+58
jobDir      equ V+59
jobW        equ V+60
jobSlot     equ V+62
ENM         equ V+$40               ; 6 x 10 bytes (4 mobile + 2 turret slots)
BUL         equ V+$80               ; 3 x 4 player bullets
EBUL        equ V+$8C               ; 3 x 4 enemy bullets
lives       equ V+$A0
energy      equ V+$A1
invuln      equ V+$A2
pstate      equ V+$A3               ; 0 play, 1 dying, 2 game over
ptimer      equ V+$A4
waveTimer   equ V+$A5
waveNo      equ V+$A6
hc_row      equ V+$A9
fa_x        equ V+$AA
fa_y        equ V+$AB
tcursor     equ V+$AC
wv_dir      equ V+$AD
wv_base     equ V+$AE
TURALIVE    equ $F380
SPT         equ $F200
BHEAD       equ $F300
NENM        equ 6
MAXE        equ 5
hudmsg      equ V+$B0
lastSlack   equ V+$BC               ; spare time of the previous frame (35 T units)
shSc        equ V+$B1
shEn        equ V+$B3
shSl        equ V+$B4
shLt        equ V+$B6
shLv        equ V+$B8
shWv        equ V+$B9

; ---- tuning ----
ACCEL       equ 16
FRIC        equ 8
MAXSPD      equ 384
FLIPDIV     equ 2
FIRECD      equ 7
BSPD        equ 5
YMIN        equ 16
YMAX        equ 57
SHIPX_R     equ 36
SHIPX_L     equ 76

            org $8000
start:
            di
            ld sp,$FFF0
            ld a,$08
            ld (LATCH),a            ; MODE(1), colour set 0, speaker off
            call clear_vars
            call init_state
            call splash_draw
            call ring_init          ; hull generation runs behind the splash
            call splash_wait
            call status_static
            ld hl,0
            ld (frameCnt),hl
            jp mainloop

mainloop:
            call frame_wait
frame_sync_ret:
            call status_update      ; HUD first: the beam has not reached it yet
            call render
            call logic
            jp mainloop

; ---------------------------------------------------------------------
clear_vars:
            ld hl,V
            ld de,V+1
            ld bc,$FF
            ld (hl),0
            ldir
            ret

init_state:
            ld a,28
            ld (shipY),a
            ld a,SHIPX_R
            ld (shipXs),a
            ld hl,$ACE1
            ld (rng),hl
            ld hl,$FFFF
            ld (minSlack),hl
            call game_reset
            ret

; ---------------------------------------------------------------------
;  frame synchronisation: wait for the falling edge of field sync
;  (= the instant the picture area ends).  Counts spare time (35 T
;  per count) and late frames.
; ---------------------------------------------------------------------
frame_wait:
            ld a,(PORTFS)
            rla
            jr nc,.late             ; already inside field sync: we are late
            ld hl,0
.w1:        inc hl
            ld a,(PORTFS)
            rla
            jr c,.w1                ; 35 T per loop
            ld (lastSlack),hl
            ; record minimum spare time
            ld de,(minSlack)
            ld a,h
            cp d
            jr c,.new
            ret nz
            ld a,l
            cp e
            ret nc
.new:       ld (minSlack),hl
            ret
.late:      ld hl,0
            ld (lastSlack),hl
            ld hl,(lateCnt)
            inc hl
            ld (lateCnt),hl
.l2:        ld a,(PORTFS)
            rla
            jr nc,.l2               ; wait for field sync to end
.l3:        ld a,(PORTFS)
            rla
            jr c,.l3                ; wait for it to start again
            ret

; ---------------------------------------------------------------------
;  render: background copy + sprites, band by band (8 rows per band)
; ---------------------------------------------------------------------
render:
            ; source = RING + phase*48 + slot
            ld a,(curP)
            ld c,a
            add a,a
            add a,c                 ; 3*phase
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl               ; *16 -> phase*48
            ld a,(curSlot)
            ld e,a
            ld d,0
            add hl,de
            ld de,RING
            add hl,de
            ld (srcPtr),hl
            ld a,(curSlot)
            cp 17
            jr c,.nosplit
            ; split: entryA = CHAIN + 2*(slot-16), entryB = CHAIN + 2*(48-slot)
            sub 16
            add a,a
            ld l,a
            ld h,0
            ld de,CHAIN
            add hl,de
            ld (thunkA+1),hl
            ld a,(curSlot)
            ld c,a
            ld a,48
            sub c
            add a,a
            ld l,a
            ld h,0
            ld de,CHAIN
            add hl,de
            ld (thunkB+1),hl
            ld hl,copy_split
            jr .setcall
.nosplit:   ld hl,copy_nosplit
.setcall:   ld (.rbcall+1),hl
            ld hl,(srcPtr)
            ld de,VRAM+16*32
            xor a
            ld (bandIdx),a
.band:
            ; (patched at run time)
.rbcall:    call 0
            push hl
            push de
            call band_sprites
            pop de
            pop hl
            ld a,(bandIdx)
            inc a
            ld (bandIdx),a
            cp 6
            jr nz,.band
            ret

; draw every sprite whose bottom row lies in the current band (linked list)
band_sprites:
            ld a,(bandIdx)
            add a,a
            ld e,a
            ld d,0
            ld hl,BHEAD
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld a,d
            or e
            ret z
.lp:        push de
            pop ix
            call drawspr
            ld e,(ix+8)
            ld d,(ix+9)
            ld a,d
            or e
            jr nz,.lp
            ret

; draw one sprite record (IX): masked blit, mask/data byte pairs.
; fast path: unrolled byte chain (no source adjustment needed)
drawspr:
            ld a,(ix+6)
            or a
            jp nz,drawspr_slow
            ld l,(ix+0)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,VRAM
            add hl,de
            ld e,(ix+3)
            ld d,0
            add hl,de
            ex de,hl                ; DE = destination
            ld a,5
            sub (ix+2)              ; 5 - vis
            ld c,a
            add a,a
            add a,a
            add a,a
            sub c                   ; *7
            ld l,a
            ld h,0
            ld bc,SBCHAIN
            add hl,bc
            ld (.rcall+1),hl
            ld l,(ix+4)
            ld h,(ix+5)             ; HL = source
            ld c,(ix+7)             ; destination row adjust
            ld b,(ix+1)             ; rows
.row:
.rcall:     call 0
            ld a,c
            add a,e
            ld e,a
            jr nc,.nc
            inc d
.nc:        djnz .row
            ret

drawspr_slow:
            ld l,(ix+0)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,VRAM
            add hl,de
            ld e,(ix+3)
            ld d,0
            add hl,de
            ex de,hl                ; DE = destination
            ld l,(ix+4)
            ld h,(ix+5)             ; HL = source
            ld c,(ix+1)             ; rows
.row:       ld b,(ix+2)
.byte:      ld a,(de)
            and (hl)
            inc hl
            or (hl)
            inc hl
            ld (de),a
            inc de
            djnz .byte
            ld a,(ix+6)
            add a,l
            ld l,a
            jr nc,.n1
            inc h
.n1:        ld a,(ix+7)
            add a,e
            ld e,a
            jr nc,.n2
            inc d
.n2:        dec c
            jr nz,.row
            ret

; ---------------------------------------------------------------------
;  game logic
; ---------------------------------------------------------------------
logic:
            call readinput
            call player_update
            call ring_update
            call wave_update
            call turret_spawn
            call enemies_update
            call bullets_update
            call ebul_update
            call player_hits
            call collisions
            call build_sprites
            ld hl,(frameCnt)
            inc hl
            ld (frameCnt),hl
            ret

; ---- input: bit0 left, bit1 right, bit2 up, bit3 down, bit4 fire ----
readinput:
            ld c,0
            ld a,($68EF)            ; row X4: M bit5, SPACE bit4, comma bit3, full stop bit1
            bit 5,a
            jr nz,.a1
            set 0,c
.a1:        bit 3,a
            jr nz,.a2
            set 1,c
.a2:        bit 1,a
            jr nz,.a3
            set 4,c
.a3:        bit 4,a
            jr nz,.a4
            set 4,c
.a4:        ld a,($68FE)            ; Q = up
            bit 4,a
            jr nz,.a5
            set 2,c
.a5:        ld a,($68FD)            ; A = down
            bit 4,a
            jr nz,.a6
            set 3,c
.a6:        ld a,(joyok)
            or a
            jr nz,.j1
            ; joystick is only trusted after it has once read "idle"
            in a,($2C)
            and $0F
            cp $0F
            jr nz,.done
            in a,($2E)
            and $10
            jr z,.done
            ld a,1
            ld (joyok),a
            jr .done
.j1:        in a,($2C)
            cpl
            ld b,a
            bit 2,b
            jr z,.j2
            set 0,c
.j2:        bit 3,b
            jr z,.j3
            set 1,c
.j3:        bit 0,b
            jr z,.j4
            set 2,c
.j4:        bit 1,b
            jr z,.j5
            set 3,c
.j5:        in a,($2E)
            bit 4,a
            jr nz,.done
            set 4,c
.done:      ld a,c
            ld (inbits),a
            ret

; ---- flight model: momentum, flip state machine, ship position ----
flight:
            ld a,(inbits)
            and 3
            cp 1
            jr z,.left
            cp 2
            jr z,.right
            jp .coast
.left:      ld a,8
            ld (flipTgt),a
            ld hl,(speed)
            ld de,-ACCEL
            add hl,de
            ld de,MAXSPD
            add hl,de
            bit 7,h
            jr z,.lok
            ld hl,-MAXSPD
            jr .store
.lok:       or a
            sbc hl,de
            jr .store
.right:     xor a
            ld (flipTgt),a
            ld hl,(speed)
            ld de,ACCEL
            add hl,de
            ld de,MAXSPD
            or a
            sbc hl,de
            bit 7,h
            jr z,.rclamp
            add hl,de
            jr .store
.rclamp:    ld hl,MAXSPD
            jr .store
.coast:     ld hl,(speed)
            ld a,h
            or l
            jr z,.store
            ld de,FRIC
            bit 7,h
            jr nz,.negf
            or a
            sbc hl,de
            jr nc,.store
            ld hl,0
            jr .store
.negf:      add hl,de
            jr nc,.store
            ld hl,0
.store:     ld (speed),hl
            ; position += speed (8.8 fixed, 24 bit)
            ld a,(posFrac)
            add a,l
            ld (posFrac),a
            ld a,(posX)
            adc a,h
            ld (posX),a
            ld a,(posX+1)
            ld e,0
            bit 7,h
            jr z,.sp
            ld e,$FF
.sp:        adc a,e
            ld (posX+1),a
            ; wrap to 0..1535
            ld hl,(posX)
            bit 7,h
            jr nz,.wneg
            ld de,1536
            or a
            sbc hl,de
            jr nc,.wst
            add hl,de
            jr .wst
.wneg:      ld de,1536
            add hl,de
.wst:       ld (posX),hl

            ; ---- flip state machine ----
            ld a,(flipF)
            ld b,a
            ld a,(flipTgt)
            cp b
            jr z,.noflip
            ld a,(flipTick)
            inc a
            cp FLIPDIV
            jr c,.ftstore
            xor a
            ld (flipTick),a
            ld a,(flipTgt)
            cp b
            jr c,.fdec
            inc b
            jr .fset
.fdec:      dec b
.fset:      ld a,b
            ld (flipF),a
            jr .fdone
.ftstore:   ld (flipTick),a
            jr .fdone
.noflip:    xor a
            ld (flipTick),a
.fdone:
            ; ---- vertical movement + banking ----
            ld a,(frameCnt)
            and 1
            inc a
            ld c,a                  ; step 1 or 2
            ld a,(inbits)
            ld b,a
            ld a,(shipY)
            ld e,0                  ; bank state
            bit 2,b
            jr z,.nup
            ld d,a
            sub YMIN
            cp c
            jr c,.cu
            ld a,d
            sub c
            jr .upd
.cu:        ld a,YMIN
.upd:       ld e,1
            jr .vdone
.nup:       bit 3,b
            jr z,.vdone
            ld d,a
            ld a,YMAX
            sub d
            cp c
            jr c,.cd
            ld a,d
            add a,c
            jr .dnd
.cd:        ld a,YMAX
.dnd:       ld e,2
.vdone:     ld (shipY),a
            ld a,e
            ld (bankst),a
            ; ---- screen x drift ----
            ld a,(flipF)
            cp 4
            ld c,SHIPX_R
            jr c,.tx
            ld c,SHIPX_L
.tx:        ld a,(shipXs)
            cp c
            jr z,.xd
            jr c,.xinc
            dec a
            jr .xs
.xinc:      inc a
.xs:        ld (shipXs),a
.xd:        ret

; ---------------------------------------------------------------------
;  ring buffer management
; ---------------------------------------------------------------------
ring_init:
.r:         ld a,(ringRc)
            cp 38
            jr nc,.l
            call gen_right
            jr .r
.l:         ld a,(ringLc)
            cp 10
            ret nc
            call gen_left
            jr .l

ring_update:
            ld hl,(posX)
            ld a,l
            and 3
            ld (curP),a
            srl h
            rr l
            srl h
            rr l                    ; hl = B
            ld de,(oldB)
            ld (oldB),hl
            ld (curB),hl
            or a
            sbc hl,de               ; hl = B - oldB (mod 384, small)
            ld a,h
            or a
            jr z,.dpos
            cp $FF
            jr z,.dneg
            ; wrapped: H = 1 or $FE : delta = L - 128
            ld a,l
            sub 128
            jr .dgot
.dpos:      ld a,l
            jr .dgot
.dneg:      ld a,l
.dgot:      ld c,a                  ; c = signed delta
            ; Rc -= delta ; Lc += delta
            ld a,(ringRc)
            sub c
            ld (ringRc),a
            ld a,(ringLc)
            add a,c
            ld (ringLc),a
            ; slot = B mod 48
            ld hl,(curB)
            ld de,48
.m:         or a
            sbc hl,de
            jr nc,.m
            add hl,de
            ld a,l
            ld (curSlot),a
            ; staged column generation.  Stages per frame adapt to the load:
            ; 1 when many sprites are on screen, 2 otherwise, +1/+2 when the
            ; ring is running low (urgent)
            ld hl,(lastSlack)
            ld b,3
            ld a,h
            or a
            jr nz,.chk
            ld a,l
            ld b,1
            cp 100
            jr c,.chk
            inc b
            cp 200
            jr c,.chk
            inc b
.chk:       ld a,(ringRc)
            cp 35
            jr nc,.chl
            inc b
            cp 34
            jr nc,.chl
            inc b
            inc b
.chl:       ld a,(ringLc)
            cp 4
            jr nc,.g
            inc b
            inc b
.g:         push bc
            call job_step
            pop bc
            djnz .g
            ret

setup_right:
            ld a,(ringRc)
            ld c,a
            ld b,0
            ld hl,(curB)
            add hl,bc
            call wrap384
            ld a,(curSlot)
            add a,c
            cp 48
            jr c,.s
            sub 48
.s:         ret
fin_right:
            ld a,(ringRc)
            inc a
            ld (ringRc),a
            ld c,a
            ld a,(ringLc)
            add a,c
            cp 49
            ret c
            ld a,(ringLc)
            dec a
            ld (ringLc),a
            ret

setup_left:
            ld a,(ringLc)
            ld c,a
            ld b,0
            ld hl,(curB)
            or a
            sbc hl,bc
            dec hl
            bit 7,h
            jr z,.pos
            ld de,384
            add hl,de
.pos:       ld a,(curSlot)
            add a,47
            sub c
            cp 48
            jr c,.s
            sub 48
.s:         ret
fin_left:
            ld a,(ringLc)
            inc a
            ld (ringLc),a
            ld c,a
            ld a,(ringRc)
            add a,c
            cp 49
            ret c
            ld a,(ringRc)
            dec a
            ld (ringRc),a
            ret

gen_right:
            call setup_right
            call gen_column
            jp fin_right
gen_left:
            call setup_left
            call gen_column
            jp fin_left

; staged background job: 1 raw columns, 2/3 pixel phases for rows 0-27 / 28-55
job_step:
            ld a,(jobSt)
            or a
            jr nz,.run
            ld a,(ringRc)
            cp 38
            jr nc,.tl
            call setup_right
            ld (jobW),hl
            ld (jobSlot),a
            xor a
            ld (jobDir),a
            jr .st
.tl:        ld a,(ringLc)
            cp 10
            ret nc
            call setup_left
            ld (jobW),hl
            ld (jobSlot),a
            ld a,1
            ld (jobDir),a
.st:        ld a,1
            ld (jobSt),a
.run:       ld a,(jobSt)
            cp 1
            jr nz,.gp
            ld hl,(jobW)
            ld de,RAWA
            call rawcol
            ld hl,(jobW)
            inc hl
            ld a,h
            cp 1
            jr nz,.ok
            ld a,l
            cp $80
            jr nz,.ok
            ld hl,0
.ok:        ld de,RAWB
            call rawcol
            ld a,2
            ld (jobSt),a
            ret
.gp:        sub 2                   ; chunk k = 0..5 (8 rows each)
            ld c,a
            add a,a
            add a,c
            add a,a                 ; 6k
            ld h,a
            ld l,0                  ; 1536*k = 8 rows * 192
            ld a,(jobSlot)
            ld e,a
            ld d,0
            add hl,de
            ld de,RING+72
            add hl,de
            push hl
            pop ix
            ld a,c
            add a,a
            add a,a
            add a,a
            ld e,a
            ld d,$F0                ; RAWA = $F000
            ld b,8
            call gp_rows
            ld a,(jobSt)
            inc a
            cp 8
            jr c,.keep
            xor a
            ld (jobSt),a
            ld a,(jobDir)
            or a
            jp z,fin_right
            jp fin_left
.keep:      ld (jobSt),a
            ret

wrap384:
            ld de,384
            or a
            sbc hl,de
            ret nc
            add hl,de
            ret

wrap1536:
            bit 7,h
            jr z,.pos
            ld de,1536
            add hl,de
            ret
.pos:       ld de,1536
            or a
            sbc hl,de
            ret nc
            add hl,de
            ret

; build raw byte columns W and W+1 then write all four pixel phases
; in: HL = W (0..383), A = ring slot
gen_column:
            ld (gc_slot),a
            push hl
            ld de,RAWA
            call rawcol
            pop hl
            inc hl
            ld a,h
            cp 1
            jr nz,.ok
            ld a,l
            cp $80
            jr nz,.ok
            ld hl,0
.ok:        ld de,RAWB
            call rawcol
            ld a,(gc_slot)
            ; fall through to gen_phases

gen_phases:
            ld l,a
            ld h,0
            ld de,RING+72
            add hl,de
            push hl
            pop ix
            ld de,RAWA
            ld b,48
gp_rows:
.row:       ld a,(de)
            ld h,a
            ld (ix-72),a            ; phase 0
            set 6,e
            ld a,(de)
            ld l,a
            res 6,e
            inc e
            add hl,hl
            add hl,hl
            ld (ix-24),h            ; phase 1
            add hl,hl
            add hl,hl
            ld (ix+24),h            ; phase 2
            add hl,hl
            add hl,hl
            ld (ix+72),h            ; phase 3
            ld a,ixl
            add a,192
            ld ixl,a
            jr nc,.nx
            inc ixh
.nx:        djnz .row
            ret

; raw column of the hull map: HL = W (0..383), DE = 48-byte destination
rawcol:
            ld a,l
            and 1
            ld (rc_b),a
            srl h
            rr l                    ; hl = tile column
            ld b,h
            ld c,l
            add hl,hl
            add hl,bc
            add hl,hl               ; hl = 6 * tile column
            ld bc,HULLMAP
            add hl,bc
            ld a,(rc_b)
            or a
            ld bc,TILE0
            jr z,.b0
            ld bc,TILE1
.b0:        ld (rc_tab),bc
            ld b,6
.tr:        push bc
            ld a,(hl)
            inc hl
            push hl
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld bc,(rc_tab)
            add hl,bc
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            pop hl
            pop bc
            djnz .tr
            ret

; ---------------------------------------------------------------------
;  random numbers (xorshift16)
; ---------------------------------------------------------------------
rnd:
            ld hl,(rng)
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
            ld (rng),hl
            ret

; screen x of enemy (IX) -> (ix+6/7), $7FFF when off screen
enemy_sx:
            ld l,(ix+1)
            ld h,(ix+2)
            ld de,(posX)
            or a
            sbc hl,de
            jr nc,.p
            ld de,1536
            add hl,de
.p:         ld de,128
            or a
            sbc hl,de
            jr c,.vis
            ld de,1520-128
            or a
            sbc hl,de
            jr nc,.neg
            ld hl,$7FFF
            jr .st
.neg:       ld de,-16
            add hl,de
            jr .st
.vis:       ld de,128
            add hl,de
.st:        ld (ix+6),l
            ld (ix+7),h
            ret

; ---------------------------------------------------------------------
;  bullets (4 bytes: active, x+16, y, dx)
; ---------------------------------------------------------------------
bullets_update:
            ld a,(fireCool)
            or a
            jr z,.nocd
            dec a
            ld (fireCool),a
.nocd:      ld a,(inbits)
            bit 4,a
            jr z,.nospawn
            ld a,(fireCool)
            or a
            jr nz,.nospawn
            ld ix,BUL
            ld b,3
            ld de,4
.f:         ld a,(ix+0)
            or a
            jr z,.found
            add ix,de
            djnz .f
            jr .nospawn
.found:     ld (ix+0),1
            ld a,(shipY)
            add a,3
            ld (ix+2),a
            ld a,(flipF)
            cp 4
            jr nc,.fl
            ld a,(shipXs)
            add a,32
            ld (ix+1),a
            ld (ix+3),BSPD
            jr .fired
.fl:        ld a,(shipXs)
            add a,10
            ld (ix+1),a
            ld (ix+3),-BSPD
.fired:     ld a,FIRECD
            ld (fireCool),a
.nospawn:   ld ix,BUL
            ld b,3
            ld de,4
.m:         ld a,(ix+0)
            or a
            jr z,.nx
            ld a,(ix+1)
            add a,(ix+3)
            ld (ix+1),a
            cp 2
            jr c,.kill
            cp 144
            jr c,.nx
.kill:      ld (ix+0),0
.nx:        add ix,de
            djnz .m
            ret

; bullet vs enemy hits
collisions:
            ld iy,BUL
            ld b,3
.bl:        push bc
            ld a,(iy+0)
            or a
            jp z,.nb
            ld a,(iy+1)
            ld l,a
            ld h,0
            ld de,-16
            add hl,de
            ld (col_bx),hl
            ld ix,ENM
            ld c,NENM
.el:        ld a,(ix+0)
            cp 1
            jr nz,.ne
            ld a,(iy+2)             ; coarse y rejection first
            sub (ix+3)
            inc a
            cp 8
            jr nc,.ne
            ld a,(ix+8)
            or a
            ld a,17
            ld l,8
            jr z,.t1
            ld a,13
            ld l,7
.t1:        ld (col_ew),a
            ld a,l
            ld (col_eh),a
            ld hl,(col_bx)
            ld e,(ix+6)
            ld d,(ix+7)
            or a
            sbc hl,de
            ld de,5
            add hl,de
            ld a,h
            or a
            jr nz,.ne
            ld a,l
            ld hl,col_ew
            cp (hl)
            jr nc,.ne
            ld a,(iy+2)
            sub (ix+3)
            inc a
            ld hl,col_eh
            cp (hl)
            jr nc,.ne
            ld (iy+0),0
            ld a,(ix+8)
            cp 2
            jr nz,.kill
            ld a,(ix+4)             ; turrets have armour (hits left in +4)
            or a
            jr z,.kill
            dec a
            ld (ix+4),a
            jr .nb
.kill:      ld (ix+0),2
            call add_score
            jr .nb
.ne:        ld de,10
            add ix,de
            dec c
            jr nz,.el
.nb:        ld de,4
            add iy,de
            pop bc
            dec b
            jp nz,.bl
            ret

; ---------------------------------------------------------------------
;  sprite table construction
; ---------------------------------------------------------------------
frame_addr:                         ; HL = table, A = index -> HL = frame address
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ret

build_sprites:
            xor a
            ld (sprCount),a
            ld hl,SPT
            ld (sprNext),hl
            ld hl,BHEAD
            ld de,BHEAD+1
            ld bc,13
            ld (hl),0
            ldir
            ; --- player ship (added first so it is drawn last, on top) ---
            ld a,(pstate)
            or a
            jr z,.shipalive
            cp 1
            jp nz,.noship
            ld a,(ptimer)
            srl a
            srl a
            srl a
            srl a
            ld c,a
            ld a,2
            sub c
            ld hl,EXPFR_TAB
            call frame_addr
            ld a,(shipXs)
            add a,2
            ld e,a
            ld d,0
            ld a,(shipY)
            ld b,a
            ld c,4
            call addspr
            jp .noship
.shipalive: ld a,(invuln)
            or a
            jr z,.drawship
            ld a,(frameCnt)
            and 4
            jp z,.noship
.drawship:  ld a,(flipF)
            ld c,a
            or a
            jr z,.rest
            cp 8
            jr nz,.mid
.rest:      ld a,(bankst)
            or a
            jr z,.mid
            dec a
            add a,9
            ld b,a
            ld a,c
            or a
            ld a,b
            jr z,.bf
            add a,2
.bf:        ld c,a
.mid:       ld a,c
            ld hl,SHIPFR_TAB
            call frame_addr
            ld a,(shipXs)
            ld e,a
            ld d,0
            ld a,(shipY)
            ld b,a
            ld c,0
            call addspr
.noship:
            ; --- bullets ---
            ld ix,BUL
            ld b,3
.bl:        push bc
            ld a,(ix+0)
            or a
            jr z,.bn
            ld a,(ix+1)
            ld e,a
            ld d,0
            ld hl,-16
            add hl,de
            ex de,hl                ; DE = x - 16 (signed)
            ld b,(ix+2)
            ld c,3
            ld hl,BULFR_0
            call addspr
.bn:        ld de,4
            add ix,de
            pop bc
            dec b
            jp nz,.bl
            ; --- enemy bullets ---
            ld ix,EBUL
            ld b,3
.ebl:       push bc
            ld a,(ix+0)
            or a
            jr z,.ebn
            ld a,(ix+1)
            ld e,a
            ld d,0
            ld hl,-16
            add hl,de
            ex de,hl
            ld b,(ix+2)
            ld c,6
            ld hl,EBLFR_0
            call addspr
.ebn:       ld de,4
            add ix,de
            pop bc
            dec b
            jp nz,.ebl
            ; --- enemies ---
            ld ix,ENM
            ld b,NENM
.el:        push bc
            ld a,(ix+0)
            or a
            jr z,.en
            ld a,(ix+7)
            cp $7F
            jr z,.en                ; off screen: nothing to draw
            ld a,(ix+0)
            cp 1
            jr nz,.explode
            ld a,(ix+8)
            or a
            jr z,.typeA
            cp 2
            jr z,.typeT
            jr .typeB
.typeA:     ld a,(frameCnt)
            rrca
            rrca
            rrca
            and 1
            ld hl,ENAFR_TAB
            call frame_addr
            ld c,1
            jr .add
.typeT:     ld a,(ix+5)
            cp 12
            ld a,0
            jr nc,.tf
            inc a
.tf:        ld hl,TURFR_TAB
            call frame_addr
            ld c,5
            jr .add
.typeB:     ld hl,ENBFR_TAB
            xor a
            call frame_addr
            ld c,2
            jr .add
.explode:   sub 2
            rrca
            rrca
            and 3
            ld hl,EXPFR_TAB
            call frame_addr
            ld c,4
.add:       ld e,(ix+6)
            ld d,(ix+7)
            ld b,(ix+3)
            call addspr
.en:        ld de,10
            add ix,de
            pop bc
            djnz .el
            ret

; add a sprite record.  HL = frame data, DE = x (signed px), B = y, C = class
addspr:
            ld a,(sprCount)
            cp 14
            ret nc
            ld (as_frm),hl
            ld a,b
            ld (as_y),a
            ld a,c
            add a,a
            add a,a
            ld l,a
            ld h,0
            ld bc,CLSTAB
            add hl,bc
            ld a,(hl)
            ld (as_wb),a
            inc hl
            ld a,(hl)
            ld (as_h),a
            inc hl
            ld a,(hl)
            ld (as_rowlen),a
            inc hl
            ld a,(hl)
            ld (as_phsz),a
            ld a,e
            and 3
            ld (as_ph),a
            sra d
            rr e
            sra d
            rr e                    ; DE = byte column (signed)
            ld a,d
            or a
            jr z,.pos
            inc a
            ret nz                  ; far off screen
            ld a,e
            neg
            ld c,a                  ; bytes clipped on the left
            ld a,(as_wb)
            cp c
            ret c
            ret z
            sub c
            ld (as_vis),a
            ld a,c
            ld (as_sl),a
            xor a
            ld (as_dcol),a
            jr .common
.pos:       ld a,e
            cp 32
            ret nc
            ld (as_dcol),a
            ld c,a
            ld a,(as_wb)
            add a,c
            sub 32
            jr c,.nover
            jr z,.nover
            ld c,a
            ld a,(as_wb)
            sub c
            jr .setv
.nover:     ld a,(as_wb)
.setv:      ld (as_vis),a
            xor a
            ld (as_sl),a
.common:    ld hl,(as_frm)
            ld a,(as_ph)
            or a
            jr z,.nph
            ld b,a
            ld a,(as_phsz)
            ld e,a
            ld d,0
.mp:        add hl,de
            djnz .mp
.nph:       ld a,(as_sl)
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ex de,hl                ; DE = source pointer
            ld hl,(sprNext)
            push hl                 ; record start
            ld a,(as_y)
            ld (hl),a
            inc hl
            ld a,(as_h)
            ld (hl),a
            inc hl
            ld a,(as_vis)
            ld (hl),a
            inc hl
            ld a,(as_dcol)
            ld (hl),a
            inc hl
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld a,(as_vis)
            add a,a
            ld c,a
            ld a,(as_rowlen)
            sub c
            ld (hl),a
            inc hl
            ld a,(as_vis)
            ld c,a
            ld a,32
            sub c
            ld (hl),a
            ; link into the list of the band containing the bottom row
            ld a,(as_y)
            ld c,a
            ld a,(as_h)
            add a,c
            sub 17
            rrca
            rrca
            rrca
            and 7
            add a,a
            ld c,a
            ld b,0
            ld hl,BHEAD
            add hl,bc
            pop de                  ; DE = record start
            ld c,(hl)
            inc hl
            ld b,(hl)               ; BC = old head
            ld (hl),d
            dec hl
            ld (hl),e               ; head = this record
            ex de,hl
            ld de,8
            add hl,de
            ld (hl),c
            inc hl
            ld (hl),b               ; record.next = old head
            ld hl,(sprNext)
            ld de,10
            add hl,de
            ld (sprNext),hl
            ld hl,sprCount
            inc (hl)
            ret

; ---------------------------------------------------------------------
;  status bar (rows 0..7), 3x5 font
; ---------------------------------------------------------------------
putchar:                            ; A = glyph, C = column ; preserves BC DE HL
            push hl
            push de
            push bc
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,hl
            add hl,de
            ld de,GLYPHS
            add hl,de
            push hl
            ld hl,(pc_row)
            ld a,c
            add a,l
            ld e,a
            ld a,h
            adc a,0
            ld d,a
            pop hl
            ld b,5
.r:         ld a,(hl)
            ld (de),a
            inc hl
            ld a,e
            add a,32
            ld e,a
            jr nc,.nc
            inc d
.nc:        djnz .r
            pop bc
            pop de
            pop hl
            ret

putstr:                             ; HL = string (255 terminated), C = column
            ld a,(hl)
            cp 255
            ret z
            inc hl
            call putchar
            inc c
            jr putstr

putdec4:                            ; HL = value, C = column (advances)
            ld de,1000
            call pd1
            ld de,100
            call pd1
            ld de,10
            call pd1
            ld a,l
            inc a
            call putchar
            inc c
            ret
pd1:        ld b,0
.l:         or a
            sbc hl,de
            jr c,.d
            inc b
            jr .l
.d:         add hl,de
            ld a,b
            inc a
            call putchar
            inc c
            ret

splash_draw:
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,2047
            ld (hl),$AA
            ldir
            ld hl,VRAM+22*32
            ld (pc_row),hl
            ld hl,TXT_TITLE
            ld c,9
            call putstr
            ld hl,VRAM+32*32
            ld (pc_row),hl
            ld hl,TXT_VIBED
            ld c,7
            call putstr
            ret

splash_wait:
            ld b,150
.w:         push bc
            call frame_wait
            pop bc
            djnz .w
            ret

            include "combat.asm"
            include "../build/gen_blocks.asm"
            include "../build/assets.asm"
prog_end:
