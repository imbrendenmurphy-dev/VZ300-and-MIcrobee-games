; =====================================================================
;  KAMIKAZE INVADERS 2 - gameplay
;  Mothership (BG blit, smooth 1-px moves), columns (BG), flyers, divers,
;  ground blasts (BG), centre bomb, capsules, shots, HUD, demo AI, bonus round.
; =====================================================================
MS_OFF     equ 0
MS_WARPIN  equ 1
MS_CRUISE  equ 2
MS_BREACH  equ 3
MS_EXPLODE equ 4
MS_ESCAPE  equ 5
MS_XMIN    equ 4
MS_XMAX    equ 99

T_GRUNT equ 1
T_ARMOR equ 2
T_CRACK equ 3
T_ZIG   equ 4
T_SPARK equ 5

BONUS_N equ 30
SHIP_XMAX equ 121
LANE_X  equ 61                  ; bomb x (7 wide, centred in the lane 55..73)

; flyer / diver / shot / blast field offsets
F_T equ 0
F_X equ 1
F_Y equ 2
F_C equ 3
F_D equ 4
F_F equ 5
D_T equ 0
D_X equ 1
D_Y equ 2
D_F equ 3
D_P equ 4
D_BX equ 5
D_HP equ 6
B_T equ 0
B_CX equ 1
B_R equ 2
B_RM equ 3
B_K equ 4

popstr: dw 0                    ; (render's text entries are unused here)
typespr: db SPR_GRUNT0,SPR_GRUNT0,SPR_ARMOR0,SPR_CRACK0,SPR_ZIG0,SPR_SPARK0
mix_s0a: db 1,1,1,1,1,1,1,1
mix_s0:  db 1,1,1,1,1,1,2,2
mix_s1:  db 1,1,1,2,4,4,4,1
mix_s2:  db 1,2,4,4,5,5,1,2
mix_s3:  db 1,2,2,4,4,5,5,4
mixtab:  dw mix_s0,mix_s1,mix_s2,mix_s3
captab:  db 1,1,2,2,3,3,4,1             ; T T R R S S N T

; =====================================================================
;  low-level drawing helpers
; =====================================================================
; pset: B = x, C = y, E = colour, A = buffer page (BGBUF/256 or CLEANBUF/256)
pset_b: ld a,BGBUF/256
pset:   push de
        push hl
        ld d,a
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,b
        srl a
        srl a
        or l
        ld l,a
        ld a,h
        add a,d
        ld h,a
        ld a,e
        add a,a
        add a,a
        ld e,a
        ld a,b
        and 3
        or e
        add a,a
        push hl
        ld l,a
        ld h,0
        ld de,pixtab
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        pop hl
        and (hl)
        or e
        ld (hl),a
        pop hl
        pop de
        ret

; restore_rect: D = byte col, E = row, B = width, C = height: CLEAN -> BG
restore_rect:
        push bc
        call scraddr
        pop bc
.r:     push bc
        push hl
        ld a,h
        or $88
        ld d,a
        ld e,l
        ld a,h
        add a,$78
        ld h,a
        ld c,b
        ld b,0
        ldir
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        dec c
        jr nz,.r
        ret
; restore and queue
restore_q:
        push de
        push bc
        call restore_rect
        pop bc
        pop de
        jp queue_rect

; bg_sprite: A = sprite id, B = x, C = y: masked draw into BGBUF (no queue)
bg_sprite:
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,shtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (pw_),a
        inc hl
        ld a,(hl)
        ld (rowcnt),a
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = bytes per shift
        ex de,hl                ; HL = base
        pop de                  ; D = x, E = y
        push de
        ld a,d
        and 3
        jr z,.s0
.s1:    add hl,bc
        dec a
        jr nz,.s1
.s0:    pop de
        push hl
        ld a,d
        srl a
        srl a
        ld d,a
        call scraddr
        ld a,h
        or $88
        ld h,a
        pop de                  ; DE = (mask,data) pairs
.row:   push hl
        ld a,(pw_)
        ld b,a
.b:     ld a,(de)
        and (hl)
        ld (hl),a
        inc de
        ld a,(de)
        or (hl)
        ld (hl),a
        inc de
        inc l
        djnz .b
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,(rowcnt)
        dec a
        ld (rowcnt),a
        jr nz,.row
        ret

; =====================================================================
;  SECTOR / WAVE SETUP
; =====================================================================
setup_sector:
        ld a,(sector)
        ld l,a
        ld h,0
        ld de,sec_css
        add hl,de
        ld a,(hl)
        or MODE1
        ld (palbase),a
        ld hl,colcnt
        ld de,colcnt+1
        ld bc,10+40+10+10+10-1
        ld (hl),0
        ldir
        call clear_objects_quiet
        xor a
        ld (ms_state),a
        ld (ms_done),a
        ld (shield),a
        ld hl,0
        ld (twin_tim),hl
        ld (rapid_tim),hl
        ld (curlabel),hl
        ld a,60
        ld (shipx),a
        call build_clean
        ; show it with a blinds wipe
        ld hl,CLEANBUF
        ld de,BGBUF
        ld bc,2048
        ldir
        call hud_full
        call wipe_show
        ret

; build the empty playfield for this sector into CLEANBUF
build_clean:
        ld hl,CLEANBUF
        ld de,CLEANBUF+1
        ld bc,2047
        ld (hl),$AA
        ldir
        ld a,(sector)
        ld l,a
        ld h,0
        ld de,sec_rail
        add hl,de
        ld a,(hl)
        ld (tmpd),a             ; rail colour
        ld a,(sector)
        ld l,a
        ld h,0
        ld de,sec_style
        add hl,de
        ld a,(hl)
        ld (tmpy),a             ; style 0..3
        ; stars in the open sky (fixed pattern per sector)
        ld hl,(seed)
        push hl
        ld a,(sector)
        add a,$31
        ld h,a
        ld l,$7A
        ld (seed),hl
        ld a,22
        ld (cnt),a
.st:    ld b,128
        call rand_n
        ld (tmpx),a
        ld b,14
        call rand_n
        add a,OPEN_Y
        ld c,a
        call random
        and 3
        ld e,1
        jr nz,.sc
        ld e,0
.sc:    ld a,(tmpx)
        ld b,a
        ld a,CLEANBUF/256
        call pset
        ld hl,cnt
        dec (hl)
        jr nz,.st
        pop hl
        ld (seed),hl
        ; rails
        ld hl,railx
        ld b,12
.rl:    push bc
        push hl
        ld a,(hl)
        ld (tmpx),a
        ld c,RAIL_Y0
.ry:    push bc
        ld a,(tmpy)
        ld e,a
        ld a,c
        sub RAIL_Y0
        ld d,a                  ; row within the rail
        ld a,e
        or a
        jr z,.solid
        dec a
        jr z,.dash
        dec a
        jr z,.dot
        ; style 3: solid with green rivets every 5 rows
        ld a,(tmpd)
        ld e,a
        ld a,d
.m5:    sub 5
        jr nc,.m5
        add a,5
        cp 2
        jr nz,.put
        ld e,0
        jr .put
.dash:  ld a,d
        and 3
        cp 3
        jr z,.skip
        jr .solid
.dot:   ld a,d
        and 1
        jr nz,.skip
.solid: ld a,(tmpd)
        ld e,a
.put:   ld a,(tmpx)
        ld b,a
        ld a,CLEANBUF/256
        call pset
.skip:  pop bc
        inc c
        ld a,c
        cp RAIL_Y1+1
        jr nz,.ry
        ; caps: a little T at the top and a foot at the bottom
        ld a,(tmpd)
        ld e,a
        ld a,(tmpx)
        or a
        jr z,.nc1
        dec a
        ld b,a
        ld c,RAIL_Y0
        ld a,CLEANBUF/256
        call pset
        ld c,RAIL_Y1
        ld a,CLEANBUF/256
        call pset
.nc1:   ld a,(tmpx)
        inc a
        cp 128
        jr nc,.nc2
        ld b,a
        ld c,RAIL_Y0
        ld a,CLEANBUF/256
        call pset
        ld c,RAIL_Y1
        ld a,CLEANBUF/256
        call pset
.nc2:   pop hl
        pop bc
        inc hl
        dec b
        jp nz,.rl
        ; the bomb chute: faint dots down the centre lane
        ld c,RAIL_Y0+2
.ch:    ld b,64
        ld e,0
        ld a,CLEANBUF/256
        call pset
        ld a,c
        add a,4
        ld c,a
        cp RAIL_Y1
        jr c,.ch
        ; ground: a rail-coloured edge and a two-row pattern
        ld a,(tmpd)
        ld l,a
        ld h,0
        ld de,colbyte
        add hl,de
        ld a,(hl)
        ld hl,CLEANBUF+GROUND_Y*32
        ld b,32
.g1:    ld (hl),a
        inc hl
        djnz .g1
        ld a,(tmpy)
        add a,a
        ld l,a
        ld h,0
        ld de,groundpat
        add hl,de
        ld a,(hl)
        inc hl
        ld c,(hl)
        ld hl,CLEANBUF+(GROUND_Y+1)*32
        ld b,32
.g2:    ld (hl),a
        inc hl
        djnz .g2
        ld b,32
.g3:    ld (hl),c
        inc hl
        djnz .g3
        ret
groundpat: db $DD,$77, $44,$11, $CC,$33, $D5,$57

setup_wave:
        ld a,(sector)
        add a,a
        add a,a
        ld b,a
        ld a,(wave)
        add a,b
        ld (wi),a
        ; cargo = 20 + 2*wi + 6*lap (max 60)
        ld a,(wi)
        add a,a
        add a,30
        ld b,a
        ld a,(lap)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,b
        cp 71
        jr c,.c1
        ld a,70
.c1:    ld (ms_cargo),a
        ; bomb released once cargo falls to 2/3 (and again at 1/4 if 2 bombs)
        ld b,a
        srl a
        ld c,a
        srl c
        add a,c
        ld (bm_trig),a
        ; release interval = 64 - 3*wi - 8*lap (min 20)
        ld a,(wi)
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld a,(lap)
        add a,a
        add a,a
        add a,a
        add a,b
        ld b,a
        ld a,52
        sub b
        jr c,.r0
        cp 16
        jr nc,.r1
.r0:    ld a,16
.r1:    ld (d_relint),a
        ; flyer speed $0100 + wi*$0C + lap*$40 (max $0300)
        ld a,(wi)
        ld b,a
        ld hl,$0140
        ld de,$0010
        call .madd
        ld a,(lap)
        ld b,a
        ld de,$0040
        call .madd
        ld de,$0300
        call .cap
        ld (d_flyspd),hl
        ; diver speed $0070 + wi*$06 + lap*$18 (max $0140)
        ld a,(wi)
        ld b,a
        ld hl,$0078
        ld de,$0007
        call .madd
        ld a,(lap)
        ld b,a
        ld de,$0018
        call .madd
        ld de,$0140
        call .cap
        ld (d_divespd),hl
        ; bomb speed $0050 + sector*$0C + lap*$10
        ld a,(sector)
        ld b,a
        ld hl,$0050
        ld de,$000C
        call .madd
        ld a,(lap)
        ld b,a
        ld de,$0010
        call .madd
        ld (d_bombspd),hl
        ; flyers at once: 2, 3 from wave index 6 or on lap 2
        ld a,(lap)
        ld b,a
        ld a,(wi)
        cp 3
        ld a,2
        jr c,.f1
        inc a
.f1:    inc b
        dec b
        jr z,.f2
        ld a,3
.f2:    ld (d_flymax),a
        ; spontaneous drops from wave index 2: 600 - wi*25 - lap*60 frames (min 150)
        ld hl,0
        ld a,(wi)
        cp 1
        jr c,.d2
        ld b,a
        ld hl,460
        ld de,-22
        call .madd
        ld a,(lap)
        ld b,a
        ld de,-60
        call .madd
        bit 7,h
        jr nz,.d1
        ld de,120
        or a
        sbc hl,de
        add hl,de
        jr nc,.d2
.d1:    ld hl,120
.d2:    ld (d_dropint),hl
        ld (drop_tim),hl
        xor a
        ld (drop_wait),a
        ; bombs: 2 in the last sector; 2 hits from sector 3
        ld a,(sector)
        cp 3
        ld a,1
        jr c,.b1
        inc a
.b1:    ld (bm_left),a
        ld a,(sector)
        cp 2
        ld a,1
        jr c,.b2
        inc a
.b2:    ld (d_bombhp),a
        ; core hits 4 + lap (max 8)
        ld a,(lap)
        add a,4
        cp 9
        jr c,.h1
        ld a,8
.h1:    ld (d_coreh),a
        ; kamikaze mix
        ld a,(sector)
        or a
        jr nz,.mx
        ld a,(wave)
        cp 2
        ld hl,mix_s0a
        jr c,.mx2
        ld hl,mix_s0
        jr .mx2
.mx:    add a,a
        ld l,a
        ld h,0
        ld de,mixtab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.mx2:   ld (d_mix),hl
        ; mothership
        ld a,52
        ld (ms_x),a
        ld (ms_drawn),a
        call random
        and 1
        add a,a
        dec a
        ld (ms_dir),a
        ld hl,ms_hull
        ld (ms_img),hl
        ld a,MS_WARPIN
        ld (ms_state),a
        ld hl,60
        ld (ms_tim),hl
        xor a
        ld (ms_done),a
        ld (ms_sub),a
        ld a,70
        ld (rel_tim),a
        call hud_wave
        ret
.madd:  inc b
.ml:    dec b
        ret z
        add hl,de
        jr .ml
.cap:   push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; =====================================================================
;  INTROS
; =====================================================================
; run B frames of the "waiting" world (mothership warp, particles, blasts)
; NZ if the demo was aborted
wait_world:
        push bc
        call dl_reset
        call ms_update
        call update_particles
        call update_popups
        call update_blasts
        call ship_sprite
        call do_frame
        pop bc
        ld a,(demo)
        or a
        jr z,.n
        call check_start
        ret nz
.n:     djnz wait_world
        xor a
        ret

sector_intro:
        ld hl,mus_start_0
        ld de,mus_start_1
        call play_music
        ld hl,s_sector
        ld de,tbuf
        call strcpy
        ld a,(sector)
        add a,'1'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld hl,tbuf
        call banner
        ld a,(sector)
        add a,a
        ld l,a
        ld h,0
        ld de,sec_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call banner2
        ld b,120
        call wait_world
        push af
        call banner_clear
        pop af
        ret
s_sector: db "SECTOR ",0

; HL -> DE copy, DE left on the terminator
strcpy: ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr strcpy

wave_intro:
        ld hl,s_mship
        ld de,tbuf
        call strcpy
        ld a,(wave)
        add a,'1'
        ld (de),a
        inc de
        ld a,'/'
        ld (de),a
        inc de
        ld a,'4'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld hl,tbuf
        call banner
        ld a,SFX_WARP
        call play_sfx
        ld b,70
        call wait_world
        push af
        call banner_clear
        pop af
        ret
s_mship: db "MOTHERSHIP ",0

ready_sequence:
        call respawn
        ld hl,s_ready
        call banner2
        ld b,50
.l:     push bc
        call dl_reset
        ld a,(ms_state)
        cp MS_WARPIN
        call z,ms_update
        call update_blasts
        call update_particles
        pop bc
        push bc
        bit 3,b
        call z,ship_sprite_raw
        call do_frame
        pop bc
        ld a,(demo)
        or a
        jr z,.n
        call check_start
        ret nz
.n:     djnz .l
        call banner_clear
        call game_music
        xor a
        ld (result),a
        ret
s_ready: db "GET READY!",0

respawn:
        ld a,60
        ld (shipx),a
        ld a,90
        ld (invuln),a
        xor a
        ld (result),a
        ld (reload),a
        ld (streak),a
        ld hl,shots
        ld b,8
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; remove every moving thing (after a death / at sector change)
clear_objects:
        ; repaint blast band and the open sky (popups)
        ld de,SHIP_Y
        ld bc,$2005
        call restore_q
clear_objects_quiet:
        ld hl,flyers
        ld de,flyers+1
        ld bc,8*FLY_N+8*DIV_N+8+6*BLAST_N-1
        ld (hl),0
        ldir
        xor a
        ld (bm_on),a
        ld (cp_type),a
        ld hl,particles
        ld b,6*12
.p:     ld (hl),0
        inc hl
        djnz .p
        ld hl,popups
        ld b,4*3
.q:     ld (hl),0
        inc hl
        djnz .q
        ld hl,colwarn
        ld b,10
.w:     ld a,(hl)
        or a
        jr z,.wn
        ld (hl),0
        push hl
        ld de,coldirty-colwarn
        add hl,de
        ld (hl),1
        pop hl
.wn:    inc hl
        djnz .w
        xor a
        ld (drop_wait),a
        ret

; =====================================================================
;  BANNERS / HUD
; =====================================================================
BAN_Y1 equ 43
BAN_Y2 equ 49
banner:
        push hl
        ld de,BAN_Y1
        ld bc,$2005
        call restore_rect
        ld a,1
        ld b,2
        call set_ink
        pop hl
        ld e,BAN_Y1
        jp print_c
banner2:
        push hl
        ld de,BAN_Y2
        ld bc,$2005
        call restore_rect
        ld a,0
        ld b,2
        call set_ink
        pop hl
        ld e,BAN_Y2
        jp print_c
banner_clear:
        ld de,BAN_Y1
        ld bc,$2006
        call restore_q
        ld de,BAN_Y2
        ld bc,$2006
        jp restore_q

hud_full:
        ld de,0
        ld bc,$2005
        call restore_q
        call hud_score
        call hud_wave
        call hud_lives
        call hud_powers
        jp hud_label_restore
hud_score:
        ld a,1
        ld b,2
        call set_ink
        ld hl,score
        ld b,3
        ld de,$0000
        jp print_bcd
hud_wave:
        ld a,0
        ld b,2
        call set_ink
        ld hl,tbuf
        ld a,(sector)
        add a,'1'
        ld (hl),a
        inc hl
        ld (hl),'-'
        inc hl
        ld a,(wave)
        add a,'1'
        ld (hl),a
        inc hl
        ld (hl),0
        ld a,(bonusmode)
        or a
        jr z,.n
        ld hl,tbuf
        ld (hl),'B'
        inc hl
        ld (hl),'O'
        inc hl
        ld (hl),'N'
.n:     ld hl,tbuf
        ld de,$0700
        jp print
hud_lives:
        ld a,1
        ld b,2
        call set_ink
        ld hl,tbuf
        ld (hl),'['
        inc hl
        ld a,(lives)
        add a,'0'
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,tbuf
        ld de,$1E00
        jp print
hud_powers:
        ld a,3
        ld b,2
        call set_ink
        ld hl,tbuf
        ld de,(twin_tim)
        ld a,d
        or e
        ld a,' '
        jr z,.t
        ld a,'T'
.t:     ld (hl),a
        inc hl
        ld de,(rapid_tim)
        ld a,d
        or e
        ld a,' '
        jr z,.r
        ld a,'R'
.r:     ld (hl),a
        inc hl
        ld a,(shield)
        or a
        ld a,' '
        jr z,.s
        ld a,'S'
.s:     ld (hl),a
        inc hl
        ld (hl),0
        ld hl,tbuf
        ld de,$1A00
        jp print

hud_label:
        ld (curlabel),hl
        xor a
        ld (labeltim),a
        jr hud_label_print
; temporary label for ~1.5 s
hud_label_tmp:
        ld a,80
        ld (labeltim),a
        jr hud_label_print
hud_label_restore:
        xor a
        ld (labeltim),a
        ld hl,(curlabel)
        ld a,h
        or l
        jr nz,hud_label_print
        ld hl,s_blank
hud_label_print:
        push hl
        ld de,lbuf
        ld b,13
        ld a,' '
.f:     ld (de),a
        inc de
        djnz .f
        xor a
        ld (de),a
        ; centre within 13 chars
        pop hl
        push hl
        ld b,0
.ln:    ld a,(hl)
        or a
        jr z,.ld
        inc b
        inc hl
        jr .ln
.ld:    ld a,13
        sub b
        jr nc,.ok
        xor a
        ld b,13
.ok:    srl a
        ld e,a
        ld d,0
        ld hl,lbuf
        add hl,de
        ex de,hl
        pop hl
.c:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        djnz .c
.e:     ld a,3
        ld b,2
        call set_ink
        ld hl,lbuf
        ld de,$0C00
        jp print
s_blank: db 0
update_label:
        ld a,(labeltim)
        or a
        ret z
        dec a
        ld (labeltim),a
        ret nz
        jr hud_label_restore

add_score:
        ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        jr nc,.nov
        ld a,$99
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
.nov:   ld a,(demo)
        or a
        jr nz,.done
        ; extra ship?
        ld hl,score
        ld de,nextlife
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.ge                ; next < score
        jr nz,.done             ; next > score
        inc hl
        inc de
        djnz .c
.ge:    ld a,(nextlife)
        add a,$02
        daa
        ld (nextlife),a
        ld a,(lives)
        cp 9
        jr nc,.done
        inc a
        ld (lives),a
        call hud_lives
        ld hl,s_xlife
        call hud_label_tmp
        ld a,SFX_GET
        call play_sfx
.done:  jp hud_score
s_xlife: db "EXTRA SHIP!",0

; =====================================================================
;  POPUPS (text in the open sky, erased from CLEANBUF)
;  entry: tim, col, row, len
; =====================================================================
; popup_add: HL = string, B = x (pixel), C = y (pixel)
popup_add:
        ld a,(demo)
        or a
        ret nz
        push hl
        ld a,c
        cp OPEN_Y
        jr nc,.y1
        ld a,OPEN_Y
.y1:    cp 51
        jr c,.y2
        ld a,50
.y2:    ld c,a
        ; length
        ld e,0
.l:     ld a,(hl)
        or a
        jr z,.ld
        inc e
        inc hl
        jr .l
.ld:    ; col = x/4 - len/2, clamped to 0..32-len
        ld a,e
        srl a
        ld d,a
        ld a,b
        srl a
        srl a
        sub d
        jr nc,.x1
        xor a
.x1:    ld b,a
        add a,e
        cp 33
        jr c,.x2
        ld a,32
        sub e
        ld b,a
.x2:    ; find a free slot
        ld hl,popups
        ld d,3
.f:     ld a,(hl)
        or a
        jr z,.got
        inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        pop hl
        ret
.got:   ld (hl),40
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),e
        ld a,3
        push bc
        ld b,2
        call set_ink
        pop bc
        ld d,b
        ld e,c
        pop hl
        jp print
update_popups:
        ld hl,popups
        ld b,3
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        jr nz,.n
        push hl
        push bc
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld b,(hl)
        ld c,5
        call restore_q
        pop bc
        pop hl
.n:     inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        ret

; burst: A = colour, B = x, C = y : spawn 4 particles
burst:
        ld (burstcol),a
        ld a,4
        ld (bcount),a
        ld hl,particles
        ld e,12
.f:     ld a,(hl)
        or a
        jr nz,.n
        push de
        push hl
        ld (hl),10
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ex de,hl
        ld a,(burstidx)
        inc a
        and 7
        ld (burstidx),a
        add a,a
        ld l,a
        ld h,0
        push bc
        ld bc,burstdir
        add hl,bc
        pop bc
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        ld a,(burstcol)
        ld (de),a
        pop hl
        pop de
        ld a,(bcount)
        dec a
        ld (bcount),a
        ret z
.n:     ld a,l
        add a,6
        ld l,a
        jr nc,.nc
        inc h
.nc:    dec e
        jr nz,.f
        ret
burstdir: db 2,0, -2,0, 1,-1, -1,1, 1,1, -1,-1, 0,-2, 0,2

update_particles:
        ld hl,particles
        ld d,12
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        jr z,.n
        push hl
        push de
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        add a,b
        ld b,a
        inc hl
        ld a,(hl)
        add a,c
        ld c,a
        inc hl
        ld e,(hl)
        dec hl
        dec hl
        dec hl
        ld (hl),c
        dec hl
        ld (hl),b
        ld a,b
        cp 128
        jr nc,.kill
        ld a,c
        cp 6
        jr c,.kill
        cp 63
        jr nc,.kill
        call dl_pixel
        jr .d
.kill:  dec hl
        ld (hl),0
.d:     pop de
        pop hl
.n:     ld a,l
        add a,6
        ld l,a
        jr nc,.nc
        inc h
.nc:    dec d
        jr nz,.l
        ret

; =====================================================================
;  MOTHERSHIP
; =====================================================================
; ms_draw: blit the current image at ms_x into BG rows 6..12, digits, queue
ms_draw:
        ld a,(ms_x)
        ld (ms_drawn),a
        ld c,a
        and 3
        ld b,a
        ld hl,(ms_img)
        ld de,63
        inc b
.s:     dec b
        jr z,.sd
        add hl,de
        jr .s
.sd:    push hl
        ld a,c
        srl a
        srl a
        dec a
        ld d,a
        ld e,MS_Y
        push de
        call scraddr
        ld a,h
        or $88
        ld h,a
        ex de,hl
        pop bc
        pop hl
        push bc
        ld a,7
.r:     ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ex de,hl
        ld bc,23
        add hl,bc
        ex de,hl
        dec a
        jr nz,.r
        ; cargo digits on the closed hull
        ld hl,(ms_img)
        ld de,ms_hull
        or a
        sbc hl,de
        jr nz,.nod
        ld a,(ms_cargo)
        ld b,0
.t:     cp 10
        jr c,.td
        sub 10
        inc b
        jr .t
.td:    push af
        ld a,b
        ld b,9
        call ms_digit
        pop af
        ld b,13
        call ms_digit
.nod:   pop de
        ld bc,$0907
        jp queue_rect
; A = digit, B = offset from ms_x
ms_digit:
        add a,'0'-32
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,font3
        add hl,de
        ld a,(ms_x)
        add a,b
        ld b,a
        ld c,MS_Y+1
        ld d,5
.r:     ld a,(hl)
        push hl
        push bc
        ld l,a
        ld h,3
.p:     bit 2,l
        jr z,.n
        push de
        ld e,3
        call pset_b
        pop de
.n:     sla l
        inc b
        dec h
        jr nz,.p
        pop bc
        pop hl
        inc hl
        inc c
        dec d
        jr nz,.r
        ret
ms_erase:
        ld a,(ms_drawn)
        srl a
        srl a
        dec a
        ld d,a
        ld e,MS_Y
        ld bc,$0907
        jp restore_q

; idle mothership during death/game over: nothing moves
ms_tick_idle:
        ret

ms_update:
        ld a,(ms_state)
        or a
        ret z
        cp MS_WARPIN
        jp z,ms_warpin
        cp MS_CRUISE
        jp z,ms_cruise
        cp MS_BREACH
        jp z,ms_breach
        cp MS_EXPLODE
        jp z,ms_explode
        jp ms_escape

ms_warpin:
        ld hl,(ms_tim)
        dec hl
        ld (ms_tim),hl
        ld a,h
        or l
        jr z,.go
        ld a,l
        and 3
        ret nz
        bit 2,l
        jp z,ms_erase
        jp ms_draw
.go:    ld a,MS_CRUISE
        ld (ms_state),a
        jp ms_draw

ms_cruise:
        ; move: 1 px every 2 frames (every frame from sector 3 / lap 2)
        ld a,(ms_sub)
        inc a
        ld (ms_sub),a
        ld b,a
        ld a,(lap)
        ld c,a
        ld a,(sector)
        or c
        cp 2
        jr nc,.mv
        bit 0,b
        jr nz,.nomove
.mv:    ; occasional random turn
        call random
        cp 3
        jr nc,.nt
        ld a,(ms_dir)
        neg
        ld (ms_dir),a
.nt:    ld a,(ms_dir)
        ld b,a
        ld a,(ms_x)
        add a,b
        cp MS_XMIN
        jr c,.bounce
        cp MS_XMAX+1
        jr nc,.bounce
        ld (ms_x),a
        ld a,1
        ld (ms_dirty),a
        jr .nomove
.bounce: ld a,b
        neg
        ld (ms_dir),a
.nomove:
        call ms_release
        call ms_bomb
        ; empty and nothing in flight -> BREACH
        ld a,(ms_cargo)
        or a
        jr nz,.nb
        call flyers_active
        jr nz,.nb
        ld a,(bm_on)
        or a
        jr nz,.nb
        ld a,MS_BREACH
        ld (ms_state),a
        ld hl,360
        ld (ms_tim),hl
        ld a,(d_coreh)
        ld (ms_hp),a
        ld hl,ms_core0
        ld (ms_img),hl
        ld a,1
        ld (ms_dirty),a
        ld hl,s_breach
        call hud_label_tmp
        call game_music
.nb:    ld a,(ms_dirty)
        or a
        ret z
        xor a
        ld (ms_dirty),a
        jp ms_draw
s_breach: db "BREACH! FIRE!",0

ms_breach:
        ld hl,(ms_tim)
        dec hl
        ld (ms_tim),hl
        ld a,h
        or l
        jr nz,.go
        ; it got away
        ld a,MS_ESCAPE
        ld (ms_state),a
        ld hl,50
        ld (ms_tim),hl
        ld a,SFX_WARP
        call play_sfx
        ld hl,s_escaped
        call hud_label_tmp
        call stop_music
        ret
.go:    ld a,l
        and 7
        jr nz,.nd
        ld hl,ms_core0
        ld a,(ms_tim)
        bit 3,a
        jr z,.c0
        ld hl,ms_core1
.c0:    ld (ms_img),hl
        ld a,1
        ld (ms_dirty),a
.nd:    ld a,(ms_dirty)
        or a
        ret z
        xor a
        ld (ms_dirty),a
        jp ms_draw
s_escaped: db "IT ESCAPED!",0

ms_core_hit:
        ld a,SFX_CORE
        call play_sfx
        ld a,2
        ld (flashtim),a
        ld de,$0050
        call add_score
        ld hl,ms_hp
        dec (hl)
        ret nz
        ; destroyed!
        ld a,MS_EXPLODE
        ld (ms_state),a
        ld hl,80
        ld (ms_tim),hl
        call stop_music
        ld hl,mus_boom_0
        ld de,mus_boom_1
        call play_music
        ld a,SFX_BOOM
        call play_sfx
        ld a,16
        ld (flashtim),a
        ld de,$2000
        call add_score
        ld a,(lap)
        or a
        jr z,.nl
        ld de,$1000
        call add_score
.nl:    ld hl,s_2000
        ld a,(ms_x)
        add a,12
        ld b,a
        ld c,OPEN_Y
        call popup_add
        ret
s_2000: db "2000",0

ms_explode:
        ld hl,(ms_tim)
        dec hl
        ld (ms_tim),hl
        ld a,h
        or l
        jr z,.done
        ld a,l
        and 3
        ret nz
        ; bursts across the hull
        ld b,24
        call rand_n
        ld b,a
        ld a,(ms_x)
        add a,b
        ld b,a
        ld a,(ms_tim)
        and 4
        ld c,MS_Y+2
        jr z,.c
        ld c,MS_Y+5
.c:     call random
        and 1
        add a,a
        inc a
        call burst
        ld a,(ms_tim)
        cp 40
        ret nc
        ; second half: the hull flickers away
        bit 2,a
        jp z,ms_erase
        jp ms_draw
.done:  call ms_erase
        jr ms_gone

ms_escape:
        ld hl,(ms_tim)
        dec hl
        ld (ms_tim),hl
        ld a,h
        or l
        jr z,.done
        ld a,l
        and 3
        ret nz
        bit 2,l
        jp z,ms_erase
        jp ms_draw
.done:  call ms_erase
ms_gone:
        xor a
        ld (ms_state),a
        ld a,1
        ld (ms_done),a
        ret

; release kamikazes into the lane
ms_release:
        ld hl,rel_tim
        dec (hl)
        ret nz
        ld b,16
        call rand_n
        ld b,a
        ld a,(d_relint)
        add a,b
        ld (rel_tim),a
        ld a,(ms_cargo)
        or a
        ret z
        ; room for another flyer?
        call flyers_active
        ld a,(d_flymax)
        cp b
        jr z,.busy
        jr c,.busy
        ld ix,flyers
        ld b,FLY_N
.f:     ld a,(ix+F_T)
        or a
        jr z,.got
        ld de,8
        add ix,de
        djnz .f
.busy:  ld a,10
        ld (rel_tim),a
        ret
.got:   ; type from the wave mix
        call random
        and 7
        ld l,a
        ld h,0
        ld de,(d_mix)
        add hl,de
        ld a,(hl)
        ld (ix+F_T),a
        ld b,10
        call rand_n
        ld (ix+F_C),a
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld c,(hl)               ; target x
        ld a,(ms_x)
        add a,9
        ld (ix+F_X),a
        ld (ix+F_Y),LANE_Y
        ld (ix+F_F),0
        ld b,1
        cp c
        jr c,.dr
        ld b,-1
.dr:    ld (ix+F_D),b
        ld hl,ms_cargo
        dec (hl)
        ld a,1
        ld (ms_dirty),a
        ; a full column is about to spit one out: warn
        ld a,(ix+F_C)
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        cp 4
        jr nz,.nw
        ld de,colwarn-colcnt
        add hl,de
        ld (hl),1
.nw:    ld a,SFX_RELEASE
        jp play_sfx

; -> B = active flyers, Z if none
flyers_active:
        ld hl,flyers
        ld de,8
        ld bc,FLY_N*256
.l:     ld a,(hl)
        or a
        jr z,.n
        inc c
.n:     add hl,de
        djnz .l
        ld b,c
        ld a,c
        or a
        ret

ms_bomb:
        ld a,(bm_left)
        or a
        ret z
        ld a,(bm_on)
        or a
        ret nz
        ld a,(bm_trig)
        ld b,a
        ld a,(ms_cargo)
        cp b
        jr z,.t
        ret nc
.t:     ld a,(ms_x)
        add a,9
        cp LANE_X
        ret nz
        ld a,1
        ld (bm_on),a
        ld a,LANE_Y
        ld (bm_y+1),a
        xor a
        ld (bm_y),a
        ld a,(d_bombhp)
        ld (bm_hp),a
        ld hl,bm_left
        dec (hl)
        ld a,(bm_trig)
        srl a
        srl a
        ld (bm_trig),a
        ld hl,s_bomb
        call hud_label_tmp
        ld a,SFX_BOMBDROP
        jp play_sfx
s_bomb: db "BOMB! SHOOT!",0

; =====================================================================
;  COLUMNS
; =====================================================================
; col_draw: A = column
col_draw:
        ld (tmpd),a
        ld l,a
        ld h,0
        ld de,coldirty
        add hl,de
        ld (hl),0
        ld a,(tmpd)
        add a,a
        ld l,a
        ld h,0
        ld de,colb
        add hl,de
        ld d,(hl)
        inc hl
        ld b,(hl)
        ld e,COL_Y
        ld c,20
        push de
        push bc
        call restore_rect
        ; kamikazes, top to bottom
        ld a,(tmpd)
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        or a
        jr z,.done
        ld (cnt),a
        ld de,colwarn-colcnt
        add hl,de
        ld a,(hl)
        ld (tmpx),a             ; warn flag
        ld de,colph-colwarn
        add hl,de
        ld a,(hl)
        ld (tmpy),a             ; leg frame
        ld a,(tmpd)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,colslot
        add hl,de
        ld c,COL_Y
.s:     push hl
        push bc
        ld a,(hl)
        ld l,a
        ld h,0
        ld de,typespr
        add hl,de
        ld a,(tmpy)
        add a,(hl)
        ld b,a
        ; bottom one flashes if a warning is up
        ld a,(cnt)
        dec a
        jr nz,.nw
        ld a,(tmpx)
        or a
        jr z,.nw
        ld a,(framecount)
        and 8
        jr z,.nw
        ld b,SPR_WARN
.nw:    ld a,(tmpd)
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld a,b
        ld b,(hl)
        pop de                  ; E = y
        push de
        ld c,e
        call bg_sprite
        pop bc
        pop hl
        inc hl
        ld a,c
        add a,5
        ld c,a
        ld a,(cnt)
        dec a
        ld (cnt),a
        jr nz,.s
.done:  pop bc
        pop de
        jp queue_rect

; col_push: A = column, C = type (a kamikaze arrives at the top)
col_push:
        push ix
        call .go
        pop ix
        ret
.go:    ld (tmpd),a
        ld b,c
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        push hl
        ld a,(tmpd)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld ix,colslot
        add ix,de
        pop hl
        ld a,(hl)
        cp 4
        jr c,.room
        ; full: the bottom one is pushed out and dives
        push bc
        push hl
        ld c,(ix+3)
        ld a,(tmpd)
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld b,(hl)
        ld a,c
        ld c,COL_Y+15
        push ix
        call diver_spawn
        pop ix
        pop hl
        pop bc
        jr .sh
.room:  inc (hl)
.sh:    ld a,(ix+2)
        ld (ix+3),a
        ld a,(ix+1)
        ld (ix+2),a
        ld a,(ix+0)
        ld (ix+1),a
        ld (ix+0),b
        ld de,colwarn-colcnt
        add hl,de
        ld (hl),0
        ld de,coldirty-colwarn
        add hl,de
        ld (hl),1
        ld a,SFX_PUSH
        jp play_sfx

; col_drop: A = column: its bottom kamikaze falls out
col_drop:
        ld (tmpd),a
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        or a
        ret z
        dec a
        ld (hl),a
        ld c,a                  ; index of the bottom one
        ld de,colwarn-colcnt
        add hl,de
        ld (hl),0
        ld de,coldirty-colwarn
        add hl,de
        ld (hl),1
        ld a,(tmpd)
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,0
        ld de,colslot
        add hl,de
        ld a,(hl)
        ld (hl),0
        push af
        ld a,c
        add a,a
        add a,a
        add a,c
        add a,COL_Y
        ld c,a
        ld a,(tmpd)
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld b,(hl)
        pop af
        jp diver_spawn

; col_hit: A = column (shot reached its bottom kamikaze)
col_hit:
        ld (tmpd),a
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        dec a
        ld c,a
        push hl
        ld a,(tmpd)
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,0
        ld de,colslot
        add hl,de
        ld a,(hl)
        cp T_ARMOR
        jr nz,.kill
        ld (hl),T_CRACK
        pop hl
        ld de,coldirty-colcnt
        add hl,de
        ld (hl),1
        ld a,SFX_CLANK
        jp play_sfx
.kill:  ld (hl),0
        pop hl
        dec (hl)
        ld de,colwarn-colcnt
        add hl,de
        ld (hl),0
        ld de,coldirty-colwarn
        add hl,de
        ld (hl),1
        ; pop!
        ld a,c
        add a,a
        add a,a
        add a,c
        add a,COL_Y+2
        ld c,a
        ld a,(tmpd)
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld a,(hl)
        add a,3
        ld b,a
        ld a,1
        call burst
        ld a,SFX_POP
        call play_sfx
        ld de,$0010
        jp add_score

; column animation, warnings and spontaneous drops (one frame)
update_columns:
        ld hl,animtim
        dec (hl)
        jr nz,.na
        ld (hl),6
        ld a,(animcol)
        inc a
        cp 10
        jr c,.a1
        xor a
.a1:    ld (animcol),a
        ld l,a
        ld h,0
        ld de,colph
        add hl,de
        ld a,(hl)
        xor 1
        ld (hl),a
        ld de,coldirty-colph
        add hl,de
        ld a,(hl)
        or a
        jr nz,.na
        push hl
        ld de,colcnt-coldirty
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr z,.na
        ld (hl),1
.na:    ; warning flashes repaint every 8 frames
        ld a,(framecount)
        and 7
        jr nz,.nw
        ld hl,colwarn
        ld b,10
.w:     ld a,(hl)
        or a
        jr z,.wn
        push hl
        ld de,coldirty-colwarn
        add hl,de
        ld (hl),1
        pop hl
.wn:    inc hl
        djnz .w
.nw:    ; spontaneous drops
        ld a,(bonusmode)
        or a
        jr nz,.nd
        ld a,(ms_state)
        cp MS_CRUISE
        jr c,.nd
        ld a,(drop_wait)
        or a
        jr z,.dt
        dec a
        ld (drop_wait),a
        jr nz,.nd
        ld a,(drop_col)
        call col_drop
        jr .nd
.dt:    ld hl,(d_dropint)
        ld a,h
        or l
        jr z,.nd
        ld hl,(drop_tim)
        dec hl
        ld (drop_tim),hl
        ld a,h
        or l
        jr nz,.nd
        ld hl,(d_dropint)
        ld (drop_tim),hl
        ; pick a column with 3 or more, starting at a random one
        ld b,10
        call rand_n
        ld c,a
        ld b,10
.pc:    ld a,c
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        cp 3
        jr nc,.pk
        ld a,c
        inc a
        cp 10
        jr c,.pc2
        xor a
.pc2:   ld c,a
        djnz .pc
        jr .nd
.pk:    ld a,c
        ld (drop_col),a
        ld de,colwarn-colcnt
        add hl,de
        ld (hl),1
        ld a,45
        ld (drop_wait),a
.nd:    ; repaint up to 2 dirty columns
        ld a,2
        ld (dcnt),a
        ld hl,coldirty
        ld b,0
.dl:    ld a,(hl)
        or a
        jr z,.dn
        push hl
        push bc
        ld a,b
        call col_draw
        pop bc
        pop hl
        ld a,(dcnt)
        dec a
        ld (dcnt),a
        ret z
.dn:    inc hl
        inc b
        ld a,b
        cp 10
        jr nz,.dl
        ret

; repaint every column now (no limit)
draw_all_columns:
        ld b,0
.l:     push bc
        ld a,b
        call col_draw
        pop bc
        inc b
        ld a,b
        cp 10
        jr nz,.l
        ret

; column x centre -> burst (visual for "empty column" counting)
col_flash:
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld a,(hl)
        add a,3
        ld b,a
        ld c,28
        ld a,1
        call burst
        ld a,(tmpx)
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld a,(hl)
        add a,3
        ld b,a
        ld c,34
        ld a,0
        jp burst

; end of sector: every remaining kamikaze pops (no points)
clear_columns_boom:
        xor a
        ld (tmpx),a
.c:     ld a,(tmpx)
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        or a
        jr z,.n
.k:     ld a,(tmpx)
        call col_drop_silent
        ld a,(tmpx)
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        or a
        jr nz,.k
        ld a,SFX_POP
        call play_sfx
        ld b,4
.w:     push bc
        call update_columns
        call idle_frame
        pop bc
        djnz .w
.n:     ld hl,tmpx
        inc (hl)
        ld a,(hl)
        cp 10
        jr nz,.c
        ret
; remove the bottom kamikaze of column A with a pop (no diver)
col_drop_silent:
        ld (tmpd),a
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        or a
        ret z
        dec a
        ld (hl),a
        ld c,a
        ld de,coldirty-colcnt
        add hl,de
        ld (hl),1
        ld a,(tmpd)
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,0
        ld de,colslot
        add hl,de
        ld (hl),0
        ld a,c
        add a,a
        add a,a
        add a,c
        add a,COL_Y+2
        ld c,a
        ld a,(tmpd)
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld a,(hl)
        add a,3
        ld b,a
        ld a,3
        jp burst

; =====================================================================
;  FLYERS (lane, from the mothership to a column)
; =====================================================================
update_flyers:
        ld ix,flyers
        ld b,FLY_N
.l:     push bc
        ld a,(ix+F_T)
        or a
        call nz,fly_one
        ld de,8
        add ix,de
        pop bc
        djnz .l
        ret
fly_one:
        ; steps this frame from the 8.8 speed
        ld de,(d_flyspd)
        ld a,(ix+F_F)
        add a,e
        ld (ix+F_F),a
        ld a,d
        adc a,0
        ld b,a
        or a
        ret z
        ; target x
        ld a,(ix+F_C)
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld c,(hl)
.st:    ld a,(ix+F_X)
        cp c
        jr z,.arrive
        add a,(ix+F_D)
        ld (ix+F_X),a
        djnz .st
        ret
.arrive:
        ld a,(ix+F_C)
        ld c,(ix+F_T)
        ld (ix+F_T),0
        jp col_push

; =====================================================================
;  DIVERS
; =====================================================================
; diver_spawn: A = type, B = x, C = y
diver_spawn:
        ld (tmpy),a
        ld ix,divers
        ld e,DIV_N
.f:     ld a,(ix+D_T)
        or a
        jr z,.got
        push de
        ld de,8
        add ix,de
        pop de
        dec e
        jr nz,.f
        ret                     ; no room: it slips away
.got:   ld a,(tmpy)
        ld (ix+D_T),a
        ld (ix+D_X),b
        ld (ix+D_BX),b
        ld (ix+D_Y),c
        ld (ix+D_F),0
        ld (ix+D_P),0
        cp T_ARMOR
        ld a,1
        jr nz,.h
        inc a
.h:     ld (ix+D_HP),a
        ld a,SFX_DIVE
        jp play_sfx

update_divers:
        ld ix,divers
        ld b,DIV_N
.l:     push bc
        ld a,(ix+D_T)
        or a
        call nz,dive_one
        ld de,8
        add ix,de
        pop bc
        djnz .l
        ret
dive_one:
        ld de,(d_divespd)
        ld a,(bonusmode)
        or a
        jr z,.ns
        ld de,$0110
.ns:    ld a,(ix+D_F)
        add a,e
        ld (ix+D_F),a
        ld a,(ix+D_Y)
        adc a,d
        ld (ix+D_Y),a
        ; zig-zag
        ld a,(ix+D_T)
        cp T_ZIG
        jr nz,.nz
        inc (ix+D_P)
        ld a,(ix+D_P)
        srl a
        and 31
        ld l,a
        ld h,0
        ld de,zigtab
        add hl,de
        ld a,(ix+D_BX)
        add a,(hl)
        bit 7,a
        jr z,.z1
        xor a
.z1:    cp SHIP_XMAX+1
        jr c,.z2
        ld a,SHIP_XMAX
.z2:    ld (ix+D_X),a
.nz:    ld a,(ix+D_Y)
        cp SHIP_Y
        ret c
        ; hits the ground: blast
        ld a,(ix+D_X)
        add a,3
        ld b,a
        ld c,16
        ld e,0
        ld a,(ix+D_T)
        cp T_SPARK
        jr nz,.nsp
        ld c,30
.nsp:   ld a,(bonusmode)
        or a
        jr z,.nb
        ld c,6
        ld e,2                  ; harmless fizzle in the bonus round
.nb:    ld (ix+D_T),0
        jp blast_spawn

; =====================================================================
;  GROUND BLASTS (drawn in BG rows 56..60)
; =====================================================================
; blast_spawn: B = centre x, C = max radius, E = kind (0 normal, 1 bomb, 2 harmless)
blast_spawn:
        ld iy,blasts
        ld d,BLAST_N
.f:     ld a,(iy+B_T)
        or a
        jr z,.got
        push de
        ld de,6
        add iy,de
        pop de
        dec d
        jr nz,.f
        ld iy,blasts            ; all busy: reuse the first
.got:   ld (iy+B_T),36
        ld (iy+B_CX),b
        ld (iy+B_R),2
        ld (iy+B_RM),c
        ld (iy+B_K),e
        ld a,e
        cp 2
        ld a,SFX_BLAST
        jr nz,.s
        ld a,SFX_POP
.s:     call play_sfx
        ld a,(iy+B_K)
        cp 2
        ret z
        ld a,4
        ld (flashtim),a
        ret

update_blasts:
        ld iy,blasts
        ld b,BLAST_N
.l:     push bc
        ld a,(iy+B_T)
        or a
        call nz,blast_one
        ld de,6
        add iy,de
        pop bc
        djnz .l
        ret
blast_one:
        ld a,(iy+B_R)
        cp (iy+B_RM)
        jr nc,.g
        add a,2
        ld (iy+B_R),a
.g:     dec (iy+B_T)
        ; byte range
        ld a,(iy+B_CX)
        sub (iy+B_R)
        jr nc,.l0
        xor a
.l0:    srl a
        srl a
        ld d,a
        ld a,(iy+B_CX)
        add a,(iy+B_R)
        jr c,.r1
        cp 128
        jr c,.r0
.r1:    ld a,127
.r0:    srl a
        srl a
        sub d
        inc a
        ld b,a                  ; width
        ld e,SHIP_Y
        ld c,5
        ld a,(iy+B_T)
        or a
        jp z,restore_q          ; finished: repaint the band
        ; draw the bolts
        push de
        push bc
        call scraddr
        ld a,h
        or $88
        ld h,a
        ld a,(framecount)
        add a,(iy+B_CX)
        and 7
        ld c,a
        add a,a
        add a,a
        add a,c
        ld e,a
        ld d,0
        push hl
        ld hl,bolttab
        add hl,de
        ex de,hl
        pop hl
        pop bc
        push bc
        ld c,5
.row:   push hl
        push bc
        ld a,(de)
.b:     ld (hl),a
        inc l
        rlca
        rlca
        djnz .b
        pop bc
        pop hl
        inc de
        ld a,l
        add a,32
        ld l,a
        jr nc,.nc
        inc h
.nc:    dec c
        jr nz,.row
        pop bc
        pop de
        call queue_rect
        ; hits the ship?
        ld a,(iy+B_K)
        cp 2
        ret z
        ld a,(iy+B_T)
        cp 5
        ret c
        ld a,(result)
        or a
        ret nz
        ld a,(invuln)
        or a
        ret nz
        ld a,(iy+B_CX)
        sub (iy+B_R)
        jr nc,.a0
        xor a
.a0:    ld b,a                  ; left edge
        ld a,(shipx)
        add a,6
        cp b
        ret c                   ; ship right edge < blast left
        ld a,(iy+B_CX)
        add a,(iy+B_R)
        jr nc,.a1
        ld a,255
.a1:    ld b,a
        ld a,(shipx)
        cp b
        jr z,.hit
        ret nc
.hit:   ld a,(iy+B_K)
        or a
        jp nz,ship_hit          ; the bomb's blast goes through shields
        ld a,(shield)
        or a
        jp z,ship_hit
        xor a
        ld (shield),a
        ld a,60
        ld (invuln),a
        call hud_powers
        ld hl,s_shieldgone
        call hud_label_tmp
        ld a,SFX_SHIELD
        jp play_sfx
s_shieldgone: db "SHIELD GONE",0

ship_hit:
        ld a,(godmode)
        or a
        ret nz
        ld a,2
        ld (result),a
        ret

; =====================================================================
;  BOMB
; =====================================================================
update_bomb:
        ld a,(bm_on)
        or a
        ret z
        ld hl,(bm_y)
        ld de,(d_bombspd)
        add hl,de
        ld (bm_y),hl
        ld a,h
        cp SHIP_Y-1
        ret c
        ; it reached the ground: the whole floor goes up
        xor a
        ld (bm_on),a
        ld b,64
        ld c,80
        ld e,1
        call blast_spawn
        ld a,12
        ld (flashtim),a
        ld a,SFX_BOOM
        jp play_sfx

bomb_hit:
        ld hl,bm_hp
        dec (hl)
        jr z,.dead
        ld a,SFX_CLANK
        jp play_sfx
.dead:  xor a
        ld (bm_on),a
        ld a,SFX_BOMBHIT
        call play_sfx
        ld a,6
        ld (flashtim),a
        ld a,(bm_y+1)
        add a,3
        ld c,a
        ld b,LANE_X+3
        push bc
        ld a,3
        call burst
        pop bc
        push bc
        ld a,1
        call burst
        pop bc
        ld hl,s_500
        call popup_add
        ld de,$0500
        jp add_score
s_500:  db "500",0

; =====================================================================
;  CAPSULES
; =====================================================================
; capsule_drop: B = x, C = y
capsule_drop:
        ld a,(cp_type)
        or a
        ret nz
        ld a,(bonusmode)
        or a
        ret nz
        call random
        and 7
        ld l,a
        ld h,0
        ld de,captab
        add hl,de
        ld a,(hl)
        ld (cp_type),a
        ld a,b
        ld (cp_x),a
        ld a,c
        ld (cp_y+1),a
        xor a
        ld (cp_y),a
        ret
update_capsule:
        ld a,(cp_type)
        or a
        ret z
        ld hl,(cp_y)
        ld de,$0070
        add hl,de
        ld (cp_y),hl
        ld a,h
        cp SHIP_Y+2
        jr c,.c
        xor a
        ld (cp_type),a
        ret
.c:     cp SHIP_Y-4
        ret c
        ld a,(result)
        or a
        ret nz
        ; caught?
        ld a,(cp_x)
        ld b,a
        ld a,(shipx)
        sub b
        jr nc,.p
        neg
.p:     cp 7
        ret nc
        ld a,(cp_type)
        push af
        xor a
        ld (cp_type),a
        ld a,SFX_GET
        call play_sfx
        ld de,$0100
        call add_score
        pop af
        dec a
        jr z,.twin
        dec a
        jr z,.rapid
        dec a
        jr z,.shield
        ; NOVA: every kamikaze on screen goes pop
        jp nova
.twin:  ld hl,900
        ld (twin_tim),hl
        ld hl,s_twin
        jr .lab
.rapid: ld hl,900
        ld (rapid_tim),hl
        ld hl,s_rapid
        jr .lab
.shield: ld a,1
        ld (shield),a
        ld hl,s_shield
.lab:   call hud_label_tmp
        jp hud_powers
s_twin:   db "TWIN SHOT!",0
s_rapid:  db "RAPID FIRE!",0
s_shield: db "SHIELD UP!",0
s_nova:   db "N O V A !",0

nova:
        ld hl,s_nova
        call hud_label_tmp
        ld a,SFX_NOVA
        call play_sfx
        ld a,20
        ld (flashtim),a
        ; columns
        xor a
        ld (tmpx),a
.c:     ld a,(tmpx)
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        or a
        jr z,.n
        ld a,(tmpx)
        call col_drop_silent
        ld de,$0010
        call add_score
        jr .c
.n:     ld hl,tmpx
        inc (hl)
        ld a,(hl)
        cp 10
        jr nz,.c
        ; flyers and divers
        ld ix,flyers
        ld b,FLY_N
.f:     ld a,(ix+F_T)
        or a
        jr z,.fn
        ld (ix+F_T),0
        push bc
        ld b,(ix+F_X)
        ld c,LANE_Y+2
        ld a,3
        call burst
        ld de,$0020
        call add_score
        pop bc
.fn:    ld de,8
        add ix,de
        djnz .f
        ld ix,divers
        ld b,DIV_N
.d:     ld a,(ix+D_T)
        or a
        jr z,.dn
        ld (ix+D_T),0
        push bc
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        ld a,3
        call burst
        ld de,$0030
        call add_score
        pop bc
.dn:    ld de,8
        add ix,de
        djnz .d
        ret

; =====================================================================
;  PLAYER + SHOTS
; =====================================================================
update_player:
        ld a,(invuln)
        or a
        jr z,.ni
        dec a
        ld (invuln),a
.ni:    ld a,(reload)
        or a
        jr z,.nr
        dec a
        ld (reload),a
.nr:    ; power timers
        ld hl,(twin_tim)
        ld a,h
        or l
        jr z,.t1
        dec hl
        ld (twin_tim),hl
        ld a,h
        or l
        call z,hud_powers
.t1:    ld hl,(rapid_tim)
        ld a,h
        or l
        jr z,.t2
        dec hl
        ld (rapid_tim),hl
        ld a,h
        or l
        call z,hud_powers
.t2:    ; move: 1 and 2 px on alternate frames
        ld a,(shipsub)
        xor 1
        ld (shipsub),a
        inc a
        ld c,a
        ld a,(inp)
        bit 1,a
        jr z,.nl
        ld a,(shipx)
        sub c
        jr nc,.l1
        xor a
.l1:    ld (shipx),a
        jr .nm
.nl:    bit 0,a
        jr z,.nm
        ld a,(shipx)
        add a,c
        cp SHIP_XMAX+1
        jr c,.r1
        ld a,SHIP_XMAX
.r1:    ld (shipx),a
.nm:    ; fire
        ld a,(inp)
        and $10
        ret z
        ld a,(reload)
        or a
        ret nz
        ld hl,(twin_tim)
        ld a,h
        or l
        jr z,.single
        ; twin: both barrels at once
        ld a,(shots)
        ld b,a
        ld a,(shots+4)
        or b
        ret nz
        ld a,(shipx)
        inc a
        ld hl,shots
        call .put
        ld a,(shipx)
        add a,5
        ld hl,shots+4
        call .put
        ld a,8
        jr .fired
.single:
        ld hl,shots
        ld a,(hl)
        or a
        jr z,.ok
        ld hl,(rapid_tim)
        ld a,h
        or l
        ret z                   ; normal gun: one shot at a time (as the original)
        ld hl,shots+4
        ld a,(hl)
        or a
        ret nz
.ok:    ld a,(shipx)
        add a,3
        call .put
        ld a,5
.fired: ld (reload),a
        ld a,SFX_FIRE
        jp play_sfx
.put:   ld (hl),1
        inc hl
        ld (hl),a
        inc hl
        ld (hl),SHIP_Y-3
        ret

update_shots:
        ld ix,shots
        call shot_one
        ld ix,shots+4
shot_one:
        ld a,(ix+0)
        or a
        ret z
        ld a,(ix+2)
        ld (tmpy),a             ; old y
        ld b,3
        ld hl,(rapid_tim)
        ld a,h
        or l
        jr z,.sp
        ld b,4
.sp:    ld a,(ix+2)
        sub b
        jp c,.miss
        cp MS_Y-1
        jp c,.miss
        ld (ix+2),a
        ; swept range [y, oldy+3]
        ld a,(ix+1)
        ld (tmpx),a
        ; --- bomb
        ld a,(bm_on)
        or a
        jr z,.nbomb
        ld a,(tmpx)
        sub LANE_X
        cp 7
        jr nc,.nbomb
        ld a,(bm_y+1)
        ld c,6
        call .yhit
        jr nc,.nbomb
        ld (ix+0),0
        call bomb_hit
        jp .scored
.nbomb: ; --- divers
        ld iy,divers
        ld b,DIV_N
.dv:    ld a,(iy+D_T)
        or a
        jr z,.dvn
        ld a,(tmpx)
        sub (iy+D_X)
        cp 7
        jr nc,.dvn
        ld a,(iy+D_Y)
        ld c,5
        call .yhit
        jr nc,.dvn
        ld (ix+0),0
        jp diver_hit
.dvn:   ld de,8
        add iy,de
        djnz .dv
        ; --- flyers in the lane
        ld a,(ix+2)
        cp LANE_Y+5
        jr nc,.nfly
        ld iy,flyers
        ld b,FLY_N
.fl:    ld a,(iy+F_T)
        or a
        jr z,.fln
        ld a,(tmpx)
        sub (iy+F_X)
        cp 7
        jr nc,.fln
        ld (ix+0),0
        jp flyer_hit
.fln:   ld de,8
        add iy,de
        djnz .fl
.nfly:  ; --- mothership
        ld a,(ix+2)
        cp MS_Y+7
        jr nc,.nms
        ld a,(ms_state)
        cp MS_CRUISE
        jr c,.nms
        cp MS_EXPLODE
        jr nc,.nms
        ld b,a
        ld a,(ms_x)
        ld c,a
        ld a,(tmpx)
        sub c
        cp 24
        jr nc,.nms
        ld (ix+0),0
        ld c,a
        ld a,b
        cp MS_BREACH
        jr nz,.armour
        ld a,c
        sub 8
        cp 9
        jr nc,.armour
        call ms_core_hit
        jp .scored
.armour: ld a,SFX_CLANK
        call play_sfx
        jp .missed
.nms:   ; --- columns
        ld a,(ix+2)
        cp RAIL_Y1
        jr nc,.done
        ld hl,colx
        ld b,0
.cl:    ld a,(tmpx)
        sub (hl)
        cp 7
        jr c,.cfound
        inc hl
        inc b
        ld a,b
        cp 10
        jr nz,.cl
        jr .done
.cfound: ld hl,colcnt
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr z,.done
        ; bottom edge of the bottom kamikaze = COL_Y + 5*cnt - 1
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,COL_Y-1
        cp (ix+2)
        jr c,.done
        ld (ix+0),0
        ld a,b
        call col_hit
        jr .scored
.done:  ret
.miss:  ld (ix+0),0
.missed: xor a
        ld (streak),a
        ret
.scored:
        ; hit streak: every 10 in a row is worth 500
        ld hl,streak
        inc (hl)
        ld a,(hl)
        cp 10
        ret c
        ld (hl),0
        ld de,$0500
        call add_score
        ld hl,s_streak
        jp hud_label_tmp
; carry if object rows [A, A+C-1] overlap the swept shot rows [y, oldy+2]
.yhit:  ld d,a
        ld a,(tmpy)
        add a,2
        cp d
        jr c,.yn                ; shot bottom above the object
        ld a,d
        add a,c
        dec a
        cp (ix+2)
        jr c,.yn                ; object bottom above the shot
        scf
        ret
.yn:    or a
        ret
s_streak: db "STREAK 500",0

diver_hit:
        dec (iy+D_HP)
        jr z,.kill
        ld (iy+D_T),T_CRACK
        ld a,SFX_CLANK
        call play_sfx
        jp shot_one.scored
.kill:  ld a,(iy+D_X)
        add a,3
        ld b,a
        ld a,(iy+D_Y)
        add a,2
        ld c,a
        ld (iy+D_T),0
        push bc
        ld a,3
        call burst
        pop bc
        ld a,SFX_POP
        call play_sfx
        ld a,(bonusmode)
        or a
        jr z,.n
        ld hl,bhits
        inc (hl)
        ld de,$0100
        call add_score
        jp shot_one.scored
.n:     ld de,$0030
        call add_score
        jp shot_one.scored

flyer_hit:
        ld b,(iy+F_X)
        ld c,LANE_Y
        ld (iy+F_T),0
        push bc
        ld a,b
        add a,3
        ld b,a
        ld a,c
        add a,2
        ld c,a
        ld a,1
        call burst
        pop bc
        ; one in four drops a capsule
        call random
        and 3
        call z,capsule_drop
        ld a,SFX_POP
        call play_sfx
        ld de,$0020
        call add_score
        jp shot_one.scored

; =====================================================================
;  FRAME LOGIC
; =====================================================================
game_logic:
        ld a,(forceclear)
        or a
        call nz,force_clear
        ld a,(demo)
        ld b,a
        ld a,(autoplay)
        or b
        call nz,ai_think
        call update_player
        call update_shots
        ld a,(bonusmode)
        or a
        call z,ms_update
        call update_flyers
        call update_divers
        call update_bomb
        call update_capsule
        call update_blasts
        call update_columns
        call update_popups
        call update_label
        ld a,(bonusmode)
        or a
        jp nz,bonus_logic
        ; wave over?
        ld a,(result)
        or a
        ret nz
        ld a,(ms_done)
        or a
        ret z
        call anything_moving
        ret nz
        ld a,1
        ld (result),a
        ret

; NZ while divers, flyers, blasts or the bomb are still active
anything_moving:
        ld a,(bm_on)
        or a
        ret nz
        ld hl,flyers
        ld de,8
        ld b,FLY_N+DIV_N
.l:     ld a,(hl)
        or a
        ret nz
        add hl,de
        djnz .l
        ld hl,blasts
        ld de,6
        ld b,BLAST_N
.b:     ld a,(hl)
        or a
        ret nz
        add hl,de
        djnz .b
        xor a
        ret

; test hook: finish the current mothership / bonus round at once
force_clear:
        xor a
        ld (forceclear),a
        ld a,(bonusmode)
        or a
        jr z,.w
        ld a,BONUS_N
        ld (bspawned),a
        ret
.w:     ld a,(ms_state)
        or a
        ret z
        call ms_erase
        xor a
        ld (ms_cargo),a
        jp ms_gone

; ---------------------------------------------------------------------
build_drawlist:
        call dl_reset
        call ship_sprite
        ; shots
        ld hl,shots
        ld b,2
.s:     ld a,(hl)
        or a
        jr z,.sn
        push hl
        push bc
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld a,SPR_SHOT
        call dl_add
        pop bc
        pop hl
.sn:    ld de,4
        add hl,de
        djnz .s
        ; flyers
        ld ix,flyers
        ld b,FLY_N
.f:     ld a,(ix+F_T)
        or a
        jr z,.fn
        push bc
        call kami_spr
        ld b,(ix+F_X)
        ld c,(ix+F_Y)
        call dl_add
        pop bc
.fn:    ld de,8
        add ix,de
        djnz .f
        ; divers
        ld ix,divers
        ld b,DIV_N
.d:     ld a,(ix+D_T)
        or a
        jr z,.dn
        push bc
        call kami_spr
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        call dl_add
        pop bc
.dn:    ld de,8
        add ix,de
        djnz .d
        ; bomb
        ld a,(bm_on)
        or a
        jr z,.nb
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_BOMB0
        ld b,LANE_X
        ld hl,(bm_y)
        ld c,h
        call dl_add
.nb:    ; capsule
        ld a,(cp_type)
        or a
        jr z,.nc
        ld a,(cp_x)
        ld b,a
        ld hl,(cp_y)
        ld c,h
        ld a,(cp_type)
        add a,SPR_CAPT-1
        call dl_add
.nc:    jp update_particles
; A = kamikaze sprite (frame from type at IX+0)
kami_spr:
        ld a,(ix+0)
        ld l,a
        ld h,0
        ld de,typespr
        add hl,de
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,(hl)
        ret

ship_sprite:
        ld a,(result)
        cp 2
        ret z
        ld a,(invuln)
        bit 2,a
        ret nz
ship_sprite_raw:
        ld a,(shield)
        or a
        ld a,SPR_SHIP
        jr z,.n
        ld a,(framecount)
        and 4
        ld a,SPR_SHIP
        jr z,.n
        ld a,SPR_SHIPG
.n:     ld hl,shipx
        ld b,(hl)
        ld c,SHIP_Y
        jp dl_add

; =====================================================================
;  BONUS ROUND: KAMIKAZE RAIN
; =====================================================================
bonus_round_setup:
        ld a,1
        ld (bonusmode),a
        xor a
        ld (bspawned),a
        ld (bhits),a
        ld (ms_state),a
        ld a,40
        ld (btim),a
        call clear_objects_quiet
        call respawn
        ld a,(sector)
        ld l,a
        ld h,0
        ld de,sec_css
        add hl,de
        ld a,(hl)
        xor CSS1                ; the other palette for the bonus round
        or MODE1
        ld (palbase),a
        call hud_wave
        ret
bonus_intro:
        ld hl,s_rain
        call banner
        ld hl,s_rain2
        call banner2
        ld hl,mus_start_0
        ld de,mus_start_1
        call play_music
        ld b,110
        call wait_world
        call banner_clear
        call game_music
        xor a
        ld (result),a
        ret
s_rain:  db "BONUS: KAMIKAZE RAIN",0
s_rain2: db "100 EACH - 30 FOR 10000",0

bonus_logic:
        ld a,(bspawned)
        cp BONUS_N
        jr nc,.end
        ld hl,btim
        dec (hl)
        ret nz
        ld a,(lap)
        add a,a
        ld b,a
        ld a,20
        sub b
        ld (hl),a
        ld hl,bspawned
        inc (hl)
        ld b,116
        call rand_n
        add a,4
        ld b,a
        ld c,LANE_Y
        call random
        and 3
        ld a,T_GRUNT
        jr nz,.t
        ld a,T_ZIG
.t:     jp diver_spawn
.end:   call anything_moving
        ret nz
        ld a,(result)
        or a
        ret nz
        ld a,3
        ld (result),a
        ret

; =====================================================================
;  DEMO / AUTOPLAY AI
; =====================================================================
ai_think:
        xor a
        ld (inp),a
        ld a,$FF
        ld (ai_tx),a
        ; 1: the bomb
        ld a,(bm_on)
        or a
        jr z,.nb
        ld a,LANE_X
        ld (ai_tx),a
        jp .go
.nb:    ; 2: the lowest diver
        ld ix,divers
        ld b,DIV_N
        ld c,0
.d:     ld a,(ix+D_T)
        or a
        jr z,.dn
        ld a,(ix+D_Y)
        cp c
        jr c,.dn
        ld c,a
        ld a,(ix+D_X)
        ld (ai_tx),a
.dn:    ld de,8
        add ix,de
        djnz .d
        ld a,(ai_tx)
        cp $FF
        jr nz,.go
        ; 3: a capsule
        ld a,(cp_type)
        or a
        jr z,.nc
        ld a,(cp_x)
        ld (ai_tx),a
        jr .go
.nc:    ; 4: the core
        ld a,(ms_state)
        cp MS_BREACH
        jr nz,.ncore
        ld a,(ms_x)
        add a,9
        ld (ai_tx),a
        jr .go
.ncore: ; 5: the fullest column
        ld hl,colcnt
        ld b,0
        ld c,0
        ld e,$FF
.cl:    ld a,(hl)
        or a
        jr z,.cln
        cp c
        jr c,.cln
        jr z,.cln
        ld c,a
        ld e,b
.cln:   inc hl
        inc b
        ld a,b
        cp 10
        jr nz,.cl
        ld a,e
        cp $FF
        jr z,.go
        ld l,a
        ld h,0
        ld de,colx
        add hl,de
        ld a,(hl)
        ld (ai_tx),a
.go:    ; dodge blasts that are close
        ld iy,blasts
        ld b,BLAST_N
.bl:    ld a,(iy+B_T)
        or a
        jr z,.bln
        ld a,(iy+B_K)
        cp 2
        jr z,.bln
        ld a,(shipx)
        add a,3
        sub (iy+B_CX)
        ld c,0                  ; 0: ship right of centre
        jr nc,.ab
        neg
        inc c
.ab:    ld d,a
        ld a,(iy+B_RM)
        add a,8
        cp d
        jr c,.bln
        ld a,c
        or a
        ld a,1                  ; move right
        jr z,.mv
        ld a,2                  ; move left
.mv:    ld (inp),a
        ret
.bln:   ld de,6
        add iy,de
        djnz .bl
        ld a,(ai_tx)
        cp $FF
        ret z
        ld b,a
        ld a,(shipx)
        cp b
        jr z,.fire
        jr c,.right
        sub b
        cp 3
        jr c,.fire
        ld a,2
        ld (inp),a
        ret
.right: ld c,a
        ld a,b
        sub c
        cp 3
        jr c,.fire
        ld a,1
        ld (inp),a
        ret
.fire:  ld a,$10
        ld (inp),a
        ret
