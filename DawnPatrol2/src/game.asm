; ===================================================================
;  DAWN PATROL 2  -  gameplay
; ===================================================================

MAXFUEL     equ 8000
HMAXVX      equ 40
HMAXVY      equ 26
PADX0       equ BASEX+26
PADX1       equ BASEX+50
HANGARX     equ BASEX+74
CAPACITY    equ 16

; object definition table: w, h, flags, hp, score lo, score hi, -, -
OF_SHOOT    equ 1
OF_HARM     equ 2
OF_COLLECT  equ 4
OBJDEF:
        db 0,0,0,0,0,0,0,0
        db 12,6,OF_SHOOT|OF_HARM,3,$50,$02,0,0      ; tank
        db 16,5,OF_SHOOT|OF_HARM,1,$00,$03,0,0      ; jet
        db 16,6,OF_HARM,99,0,0,0,0                  ; transport (cannot be shot!)
        db 0,0,0,0,0,0,0,0                          ; plane 3d
        db 8,5,OF_SHOOT,4,$00,$02,0,0               ; AA gun
        db 8,5,OF_SHOOT,4,$00,$04,0,0               ; SAM site
        db 5,3,OF_SHOOT|OF_HARM,1,$00,$01,0,0       ; missile
        db 12,6,OF_SHOOT|OF_HARM,3,$00,$05,0,0      ; gunship
        db 5,7,OF_SHOOT|OF_HARM,1,$50,$00,0,0       ; balloon
        db 7,7,OF_SHOOT|OF_COLLECT,1,0,0,0,0        ; crate
        db 0,0,0,0,0,0,0,0                          ; explosion
        db 0,0,0,0,0,0,0,0                          ; flak
        db 0,0,0,0,0,0,0,0                          ; popup

; objdef: A = type -> HL = entry
objdef:
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,OBJDEF
        add hl,de
        ret

; ------------------------------------------------------------------
; new game
; ------------------------------------------------------------------
game_new:
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (level),a
        ld (loopn),a
        ld (next_extra+1),a
        ld (next_extra+2),a
        ld (demo),a
        ld a,2
        ld (next_extra),a
        ld a,4
        ld (lives),a
        ld a,1
        ld (mission),a
    if DEBUG
        ld a,(dbg_lvl)
        ld (level),a
    endif
.lvl:
        call level_intro
        call level_load
        call game_run
        ld a,(end_reason)
        cp 3
        jr z,.over
        ld a,(rescued)
        ld b,a
        ld a,(quota)
        cp b
        jr z,.ok
        jr nc,.over
.ok:    call tally_screen
        ld hl,mission
        inc (hl)
        ld a,(level)
        inc a
        cp 4
        jr c,.nl
        ld hl,loopn
        inc (hl)
        xor a
.nl:    ld (level),a
        jr .lvl
.over:
        call gameover_screen
        call hs_check
        ret

; ------------------------------------------------------------------
; level load: unpack scenery for current level, reset state
; ------------------------------------------------------------------
level_load:
        di
        xor a
        ld (in_game_flag),a
        ld a,(level)
        ld l,a
        ld h,0
        ld de,LV_SIZE
        call mul_hl_de
        ld de,LVTAB
        add hl,de
        ld (lvlptr),hl
        push hl
        pop ix
        ld a,(ix+LV_CSS)
        rlca
        rlca
        rlca
        rlca
        or $08
        ld (latchv),a
        ld (LATCH),a
        ld a,(ix+LV_CSS)
        call spr_recolour
        ; helicopter colours to suit the level:
        ; desert = green, highlands = orange with white skids
        ld a,(level)
        cp 1
        ld a,1
        jr z,.hg
        ld a,(level)
        cp 2
        ld a,2
        jr z,.hg
        xor a
.hg:    call heli_recolour
        ld a,(level)
        ld e,a
        ld d,0
        ld hl,GLINTCOL
        add hl,de
        ld a,(hl)
        ld (glint_col),a
        ld ix,(lvlptr)
        ld a,(ix+LV_SKY)
        ld (skycol),a
        call colbyte
        ld (skybyte),a
        ld a,(ix+LV_STAR)
        ld (starbyte),a
        ld a,(ix+LV_HUDBG)
        ld (hudbg),a
        ld a,(ix+LV_HUDFG)
        ld (hudfg),a
        ld a,(ix+LV_MAPBG)
        ld (mapbg),a
        ld l,(ix+LV_SUN)
        ld h,(ix+LV_SUN+1)
        ld (sun_ptr),hl
        call build_skym
        ; blank screen while unpacking
        ld a,(skybyte)
        call cls
        ; bands
        ld l,(ix+LV_BANDS)
        ld h,(ix+LV_BANDS+1)
        call unlz_far
        ld hl,$4000
        ld de,BUF
        ld bc,1488
        ldir
        ld a,BANK_P
        out (BANKPORT),a
        ld hl,BUF
        ld de,CL_BASE
        ld b,CL_ROWS
        ld c,CL_P
        ld a,32
        call band_expand
        ld hl,BUF+640
        ld de,MT_BASE
        ld b,MT_ROWS
        ld c,MT_P
        xor a
        call band_expand
        ld hl,BUF+960
        ld de,HL_BASE
        ld b,HL_ROWS
        ld c,HL_P
        ld a,32
        call band_expand
        ld hl,BUF+1344
        ld de,GR_BASE
        ld b,GR_ROWS
        ld c,GR_P
        xor a
        call band_expand
        ld hl,BUF+1392
        ld de,FG_BASE
        ld b,FG_ROWS
        ld c,FG_P
        xor a
        call band_expand
        ; world
        ld ix,(lvlptr)
        ld l,(ix+LV_WORLD)
        ld h,(ix+LV_WORLD+1)
        call unlz_far
        ld hl,$4000
        ld de,BUF
        ld bc,WD_SH
        ldir
        ld a,BANK_W
        out (BANKPORT),a
        ld hl,BUF
        call world_expand
        call load_speech
        ; clear lists
        ld hl,objs
        ld de,objs+1
        ld bc,NOBJ*OBJSZ+NPB*BSZ+NEB*BSZ+NPART*PSZ+NRUN*RSZ-1
        ld (hl),0
        ldir
        ; camps
        ld ix,(lvlptr)
        xor a
        ld b,4
        ld hl,camp_cnt
        ld de,camp_lock
        push ix
.cp:    ld a,(ix+LV_CAMPS)
        ld (hl),a
        ld a,(ix+LV_LOCKS)
        or a
        jr z,.cl
        ld a,4                  ; hits to break the door
.cl:    ld (de),a
        inc hl
        inc de
        inc ix
        djnz .cp
        pop ix
        ld a,(camp_cnt)
        ld hl,camp_cnt+1
        add a,(hl)
        inc hl
        add a,(hl)
        inc hl
        add a,(hl)
        ld (total_pris),a
        ld b,a
        ld a,(difficulty)
        or a
        ld a,b
        jr nz,.q1
        srl a                   ; easy: a third
        srl a
        add a,2
        jr .q2
.q1:    srl a                   ; normal/hard: half
.q2:    ld (quota),a
        ; statics
        ld l,(ix+LV_STAT)
        ld h,(ix+LV_STAT+1)
.st:    ld a,(hl)
        or a
        jr z,.std
        ld (tmp+7),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        push de
        call obj_alloc
        pop de
        jr c,.stn
        ld a,(tmp+7)
        ld (ix+O_TYPE),a
        ex de,hl
        call mul16
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld hl,42*16
        ld (ix+O_YL),l
        ld (ix+O_YH),h
        call obj_init_hp
        call rand
        and 63
        add a,40
        ld (ix+O_TIMER),a
.stn:   pop hl
        jr .st
.std:
        ; player
        xor a
        ld (aboard),a
        ld (aboard_c),a
        ld (aboard_c+1),a
        ld (aboard_c+2),a
        ld (aboard_c+3),a
        ld (heading),a
        ld (rescued),a
        ld (lost),a
        ld (clock_min),a
        ld (clock_sub),a
        ld (end_reason),a
        ld (shake),a
        ld (paused),a
        ld (camp_rel),a
        ld hl,0
        ld (cloud_drift),hl
        ld (upd_ctr),hl
        call heli_spawn
        ; snap camera
        ld hl,(heli_x)
        call div16
        ld de,-64
        add hl,de
        call clamp_cam
        ld (camx),hl
        call mul16
        ld (camx16),hl
        ; director timers
        ld b,8
        ld hl,dir_t
.dt:    call rand
        and 127
        add a,100
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        djnz .dt
        ld hl,700
        ld (crate_t),hl
        ; screen furniture
        call hud_init
        ret

; CSS1 levels: swap colours 0<->1 in opaque sprite pixels so the
; yellow helicopter becomes white against the cyan sky (and back)
spr_recolour:
        ld hl,spr_css
        cp (hl)
        ret z
        ld (hl),a
        ld hl,SPRMEM
        ld bc,SPR_END/2-SPRMEM/2
.l:     ld a,(hl)
        cpl
        ld e,a                  ; opaque bits
        inc hl
        ld a,(hl)
        cpl
        rrca
        and e
        and $55
        xor (hl)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret
spr_css db 0

; recolour the helicopter sprites only. A = scheme:
; 0 normal, 1 swap colours 0<->1 (yellow -> green), 2 invert (0<->3, 1<->2)
; each swap is its own inverse, so undo the old scheme then apply the new
heli_recolour:
        ld hl,heli_green
        cp (hl)
        ret z
        ld c,(hl)
        ld (hl),a
        push af
        ld a,c
        call .apply             ; undo old
        pop af
.apply: or a
        ret z
        ld (.mode),a
        ld b,SPR_HELI_RQ-SPR_HELI_L0+1
        ld hl,SPRTAB+SPR_HELI_L0*6
.s:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ex de,hl
        sla c
        rl b
.l:     ld a,(hl)
        cpl
        ld e,a                  ; opaque bits
        inc hl
        ld a,(.mode)
        cp 1
        ld a,(hl)
        jr nz,.m2
        cpl                     ; 0<->1: flip low bit where high bit is 0
        rrca
        and e
        and $55
        jr .fx
.m2:    ld a,e                  ; invert every opaque pixel (0<->3, 1<->2)
.fx:    xor (hl)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        pop hl
        pop bc
        djnz .s
        ret
.mode   db 0
heli_green db 0
said_hi    db 0
said_bye   db 0
GLINTCOL db 1,2,0,1             ; glint colour per level (contrasts the glass)

heli_spawn:
        ld hl,(PADX0+12)*16
        ld (heli_x),hl
        ld hl,GROUNDY*16
        ld (heli_y),hl
        xor a
        ld (hvx),a
        ld (hvy),a
        ld (hface),a
        ld (hlast),a
        ld (hturn),a
        inc a
        ld (htilt),a
        dec a
        ld (fire_cd),a
        ld a,HS_LANDED
        ld (hstate),a
        ld a,60
        ld (hinv),a
        ld a,3
        ld (armour),a
        ld hl,MAXFUEL
        ld (fuel),hl
        ret

; HL = HL*16
mul16:
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ret

; HL = HL*DE (16-bit)
mul_hl_de:
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
.l:     add hl,hl
        sla c
        rl b
        jr nc,.n
        add hl,de
.n:     dec a
        jr nz,.l
        ret

clamp_cam:      ; HL signed px -> 0..CAMMAX
        bit 7,h
        jr z,.p
        ld hl,0
        ret
.p:     push de
        ld de,CAMMAX
        or a
        sbc hl,de
        add hl,de
        pop de
        ret c
        ld hl,CAMMAX
        ret

; ------------------------------------------------------------------
; the game loop
; ------------------------------------------------------------------
game_run:
        ld a,$FF
        ld (in_cur),a           ; no stale key edges on the first frame
        ld a,1
        ld (in_game_flag),a
        ld a,4
        ld (rotor_rate),a
        xor a
        ld (copy_req),a
        ld (sfx_cur),a
        ld (end_t),a
        call render
        ld a,1
        ld (copy_req),a
        ei
.loop:
        call read_input
        ld a,(demo)
        or a
        jr z,.nd
        call demo_input
        jr nz,.quit
.nd:    ld a,(in_edge)
        bit IN_PAUSE,a
        jr z,.np
        ld a,(paused)
        xor 1
        ld (paused),a
        ld a,SFX_BLIP
        call sfx_play
.np:    ld a,(paused)
        or a
        jr z,.run
        call hud_pause
        call wait_copy
        ld a,1
        ld (copy_req),a
        jr .loop
.run:
    if DEBUG
        ld a,(KR_7)
        bit 1,a                 ; L = debug: finish level
        jr nz,.dl
        ld a,(total_pris)
        ld (rescued),a
        ld a,1
        ld (end_reason),a
.dl:    ld a,(KR_7)
        bit 3,a                 ; K = debug: kill heli
        jr nz,.dk
        ld a,(hstate)
        cp HS_DYING
        call c,heli_die
.dk:
    endif
        MARK 1
        call update_all
        MARK 2
        call wait_copy
        MARK 3
        call render
        MARK 4
        ld a,1
        ld (copy_req),a
        ld a,(end_reason)
        or a
        jp z,.loop
        ld hl,end_t
        inc (hl)
        ld a,(hl)
        cp 60
        jp c,.loop
.quit:  call wait_copy
.w2:    call check_ei
        ld a,(since_copy)       ; let last frame through
        cp 2
        jr c,.w2
        di
        xor a
        ld (need_ei),a
        xor a
        ld (in_game_flag),a
        ld (rotor_rate),a
        ld (sfx_cur),a
        ld a,(latchv)
        ld (LATCH),a
        ret

update_all:
        ld hl,(upd_ctr)
        inc hl
        ld (upd_ctr),hl
        ld hl,(cloud_drift)
        inc hl
        ld (cloud_drift),hl
        call check_ei
        call upd_heli
        call build_hitlist
        call upd_pbul
        call check_ei
        call upd_ebul
        call upd_objs
        call check_ei
        call upd_runners
        call upd_parts
        call upd_camps
        ld a,(end_reason)
        or a
        call z,director
        call upd_clock
        call upd_camera
        call hud_step
        ld hl,map_t
        inc (hl)
        ld a,(hl)
        and 3
        call z,minimap
        ld a,(hit_flash)
        or a
        ret z
        dec a
        ld (hit_flash),a
        ret

; ------------------------------------------------------------------
; helicopter
; ------------------------------------------------------------------
upd_heli:
        ld a,(hinv)
        or a
        jr z,.ni
        dec a
        ld (hinv),a
.ni:    ld hl,hrotor
        inc (hl)
        ld a,(fire_cd)
        or a
        jr z,.nf
        dec a
        ld (fire_cd),a
.nf:    ld a,(hstate)
        cp HS_DYING
        jp z,heli_dying
        cp HS_DEAD
        jp z,heli_dead
        call heli_turn_anim
        ; rotate (N)
        ld a,(in_edge)
        bit IN_ROT,a
        call nz,heli_rotate
        ; fire
        ld a,(in_cur)
        bit IN_FIRE,a
        call nz,heli_fire
        ld a,(hstate)
        cp HS_LANDED
        jp z,.landed
        ; --- horizontal
        ld c,0
        ld a,(in_cur)
        bit IN_LEFT,a
        jr z,.nl
        ld c,-HMAXVX
.nl:    bit IN_RIGHT,a
        jr z,.nr
        ld c,HMAXVX
.nr:    ld a,(hvx)
        ld b,2
        call approach
        ld (hvx),a
        ; --- vertical
        ld c,0
        ld a,(in_cur)
        bit IN_UP,a
        jr z,.nu
        ld c,-HMAXVY
.nu:    bit IN_DOWN,a
        jr z,.ndn
        ld c,HMAXVY
.ndn:   ld a,(hvy)
        ld b,3
        call approach
        ld (hvy),a
        ; move
        ld a,(hvx)
        call sext
        ld de,(heli_x)
        add hl,de
        ; clamp 8..760 px
        ld de,8*16
        or a
        sbc hl,de
        add hl,de
        jr nc,.c1
        ld hl,8*16
        xor a
        ld (hvx),a
.c1:    ld de,(WORLDPX-8)*16
        or a
        sbc hl,de
        add hl,de
        jr c,.c2
        ld hl,(WORLDPX-9)*16
        xor a
        ld (hvx),a
.c2:    ld (heli_x),hl
        ld a,(hvy)
        call sext
        ld de,(heli_y)
        add hl,de
        ld de,9*16
        or a
        sbc hl,de
        add hl,de
        jr nc,.c3
        ld hl,9*16
        xor a
        ld (hvy),a
.c3:    ld de,GROUNDY*16
        or a
        sbc hl,de
        add hl,de
        jr c,.c4
        ; touchdown
        ld hl,GROUNDY*16
        ld (heli_y),hl
        xor a
        ld (hvx),a
        ld (hvy),a
        ld a,HS_LANDED
        ld (hstate),a
        ld a,SFX_LAND
        call sfx_play
        xor a
        ld (land_t),a
        jr .fuel
.c4:    ld (heli_y),hl
        call heli_tilt
.dust:  ; rotor wash: kick up dust near the ground
        ld hl,(heli_y)
        ld de,(GROUNDY-7)*16
        or a
        sbc hl,de
        jr c,.fuel
        ld a,(hrotor)
        and 1
        jr nz,.fuel
        call dust_puff
        jr .fuel
.landed:
        ld c,1
        call tilt_toward
        ld hl,land_t
        inc (hl)
        ld a,(in_cur)
        bit IN_UP,a
        jr z,.fuel
        xor a
        ld (said_hi),a
        ld (said_bye),a
        ld a,HS_FLY
        ld (hstate),a
        ld a,-10
        ld (hvy),a
.fuel:  ; fuel burn: flying 2 + aboard/4, landed away from base 1
        ld a,(hstate)
        cp HS_LANDED
        ld a,1
        jr z,.fb
        ld a,(aboard)
        srl a
        srl a
        add a,2
        ld b,a
        ld a,(difficulty)
        cp 2
        ld a,b
        jr nz,.fb
        inc a
.fb:    ld e,a
        ld d,0
        ld hl,(fuel)
        or a
        sbc hl,de
        jr nc,.fok
        ld hl,0
.fok:   ld (fuel),hl
        ld a,h
        or l
        jr nz,.nofx
        ; out of fuel -> going down
        jp heli_die
.nofx:  ; low fuel warning
        ld de,MAXFUEL/5
        or a
        sbc hl,de
        ret nc
        ld hl,low_fuel_t
        inc (hl)
        ld a,(hl)
        and 31
        ret nz
        ld a,SFX_ALARM
        jp sfx_play

; A = value, C = target, B = step -> A moved toward C (signed)
approach:
        ld d,a
        ld a,c
        xor $80
        ld e,a
        ld a,d
        xor $80
        cp e
        ld a,d
        ret z
        jr c,.up
        sub b
        ld d,a
        xor $80
        cp e
        ld a,d
        ret nc
        ld a,c
        ret
.up:    add a,b
        ld d,a
        xor $80
        cp e
        ld a,d
        ret c
        ret z
        ld a,c
        ret

; chop rate of the rotor sound: fast climbing, slow on the ground
heli_turn_anim:
        ld a,(hstate)
        cp HS_LANDED
        ld b,8
        jr z,.rr
        ld a,(hvy)
        ld b,3
        bit 7,a
        jr nz,.rr               ; climbing
        ld b,6
        cp 9
        jr nc,.rr               ; descending
        ld b,4
.rr:    ld a,b
        ld (rotor_rate),a
        ; turning: hturn walks towards hface*2, one step per two updates
        ld a,(glint_t)
        or a
        jr z,.g0
        dec a
        ld (glint_t),a
.g0:    ld a,(upd_ctr)
        and 127
        jr nz,.g1
        ld a,4
        ld (glint_t),a          ; the odd glint of sun on the glass
.g1:    ld a,(upd_ctr)
        and 1
        ret nz
        ld a,(hface)
        add a,a
        ld c,a
        ld a,(hturn)
        cp c
        ret z
        jr c,.up
        dec a
        jr .st
.up:    inc a
.st:    ld (hturn),a
        ld a,6
        ld (glint_t),a
        ret

; tilt from forward speed: dive when racing ahead, flare when braking
heli_tilt:
        ld a,(hturn)
        or a
        jr z,.l
        cp 4
        jr z,.r
        ld c,1
        jr tilt_toward
.l:     ld a,(hvx)
        neg
        ld b,a
        ld a,(in_cur)
        and 1<<IN_LEFT
        jr .calc
.r:     ld a,(hvx)
        ld b,a
        ld a,(in_cur)
        and 1<<IN_RIGHT
.calc:  ld d,a
        ld a,b
        add a,$80
        ld e,a
        ld c,1
        cp 128-10
        jr nc,.n1
        ld c,0                  ; drifting backwards: nose up
        jr tilt_toward
.n1:    cp 128+10
        jr c,tilt_toward
        ld a,d
        or a
        jr nz,.fwd
        ld c,0                  ; braking: flare
        jr tilt_toward
.fwd:   ld c,2
        ld a,e
        cp 128+28
        jr c,tilt_toward
        ld c,3
tilt_toward:                    ; C = wanted tilt, eased every other update
        ld a,(upd_ctr)
        and 1
        ret nz
        ld a,(htilt)
        cp c
        ret z
        jr c,.inc
        dec a
        ld (htilt),a
        ret
.inc:   inc a
        ld (htilt),a
        ret

; firing direction from the current turn position: 0 left 1 down 2 right
fire_dir:
        ld a,(hturn)
        cp 2
        jr z,.d
        jr c,.l
        ld a,2
        ret
.l:     xor a
        ret
.d:     ld a,1
        ret

heli_rotate:
        ld a,(hface)
        cp 1
        jr z,.fromf
        ld (hlast),a
        ld a,1
        ld (hface),a
        ret
.fromf: ld a,(hlast)
        xor 2
        ld (hface),a
        ret

heli_fire:
        ld a,(fire_cd)
        or a
        ret nz
        ld a,(hstate)
        cp HS_LANDED
        jr nz,.ok
        call fire_dir
        cp 1
        ret z                   ; can't shoot the ground while sitting on it
.ok:    ld ix,pbul
        ld b,NPB
        ld de,BSZ
.f:     ld a,(ix+0)
        or a
        jr z,.got
        add ix,de
        djnz .f
        ret
.got:   ld a,5
        ld (fire_cd),a
        call fire_dir
        ld (tmp+7),a
        cp 1
        jr z,.down
        ld hl,(heli_x)
        ld de,-8*16
        or a
        jr z,.l
        ld de,8*16
.l:     add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld hl,(heli_y)
        ld de,-3*16
        add hl,de
        ld (ix+3),l
        ld (ix+4),h
        ld a,(hvx)
        sra a
        ld b,a
        ld a,(tmp+7)
        or a
        ld a,-88
        jr z,.l2
        ld a,88
.l2:    add a,b
        ld (ix+5),a
        ld a,(htilt)
        ld e,a
        ld d,0
        ld hl,FIREDY
        add hl,de
        ld a,(hl)
        ld (ix+6),a
        ld (ix+7),0
        jr .done
.down:  ld hl,(heli_x)
        ld (ix+1),l
        ld (ix+2),h
        ld hl,(heli_y)
        ld (ix+3),l
        ld (ix+4),h
        ld a,(hvx)
        sra a
        ld (ix+5),a
        ld (ix+6),64
        ld (ix+7),1
.done:  ld (ix+0),22
        ld a,SFX_SHOT
        jp sfx_play

; heli takes damage A (armour points)
FIREDY: db -6,3,10,16           ; shot drop per tilt pose

heli_hit:
        ld b,a
        ld a,(hinv)
        or a
        ret nz
        ld a,(hstate)
        cp HS_DYING
        ret nc
        ld a,(demo)
        or a
        jr z,.nd
        ld b,0                  ; demo pilot is invincible
.nd:    ld a,(armour)
        sub b
        jr nc,.ok
        xor a
.ok:    ld (armour),a
        ld a,8
        ld (shake),a
        ld (hit_flash),a
        ld a,30
        ld (hinv),a
        ld a,SFX_HIT
        call sfx_play
        ld a,(armour)
        or a
        ret nz
heli_die:
        ld a,HS_DYING
        ld (hstate),a
        xor a
        ld (htimer),a
        ld (hvx),a
        ld a,4
        ld (hvy),a
        ld a,SFX_BIGEXPL
        call sfx_play
        ld a,10
        ld (shake),a
        ret

heli_dying:
        ; spin down trailing smoke, explode on the ground
        ld hl,htimer
        inc (hl)
        ld a,(hrotor)
        and 1
        jr nz,.ns
        ld hl,(heli_x)
        ld de,(heli_y)
        ld a,e
        sub 6*16
        ld e,a
        jr nc,.s1
        dec d
.s1:    call smoke_at
.ns:    ld a,(hvy)
        cp 40
        jr nc,.f
        add a,3
        ld (hvy),a
.f:     ld a,(hvy)
        call sext
        ld de,(heli_y)
        add hl,de
        ld de,GROUNDY*16
        or a
        sbc hl,de
        add hl,de
        jr nc,.boom
        ld (heli_y),hl
        ret
.boom:  ld hl,GROUNDY*16
        ld (heli_y),hl
        ld hl,(heli_x)
        ld de,(heli_y)
        ld a,e
        sub 4*16
        ld e,a
        jr nc,.s2
        dec d
.s2:    call big_explosion
        ; prisoners aboard are lost
        ld a,(aboard)
        ld b,a
        ld a,(lost)
        add a,b
        ld (lost),a
        xor a
        ld (aboard),a
        ld (aboard_c),a
        ld (aboard_c+1),a
        ld (aboard_c+2),a
        ld (aboard_c+3),a
        ; kill runners nearby
        ld hl,(heli_x)
        call div16
        ld c,12
        call kill_runners_near
        ld a,(demo)
        or a
        jr nz,.nd
        ld hl,lives
        dec (hl)
.nd:    ld a,HS_DEAD
        ld (hstate),a
        xor a
        ld (htimer),a
        ret

heli_dead:
        ld hl,htimer
        inc (hl)
        ld a,(hl)
        cp 70
        ret c
        ld a,(lives)
        or a
        jr nz,.re
        ld a,(end_reason)
        or a
        ret nz
        ld a,3
        ld (end_reason),a
        ret
.re:    call heli_spawn
        ld a,SFX_POWER
        jp sfx_play

; ------------------------------------------------------------------
; player bullets
; ------------------------------------------------------------------
upd_pbul:
        ld ix,pbul
        ld b,NPB
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        dec (ix+0)
        jr z,.n
        call bul_move
        ; hit the ground?
        ld a,(ix+4)
        ld h,a
        ld l,(ix+3)
        ld de,48*16
        or a
        sbc hl,de
        jr c,.air
        ld (ix+0),0
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,47*16
        call dirt_puff
        ; prisoners hit by our own fire!
        ld l,(ix+1)
        ld h,(ix+2)
        call div16
        ld c,3
        call kill_runners_near
        jr .n
.air:   call pbul_hits
.n:     ld de,BSZ
        add ix,de
        pop bc
        djnz .l
        ret

bul_move:
        ld a,(ix+5)
        call sext
        ld e,(ix+1)
        ld d,(ix+2)
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld a,(ix+6)
        call sext
        ld e,(ix+3)
        ld d,(ix+4)
        add hl,de
        ld (ix+3),l
        ld (ix+4),h
        ret

; bullet IX against objects / locked huts
pbul_hits:
        ld l,(ix+1)
        ld h,(ix+2)
        call div16
        ld (tmp),hl             ; bullet px x
        ld l,(ix+3)
        ld h,(ix+4)
        call div16
        ld a,l
        ld (tmp+2),a            ; bullet py
        ; huts
        cp 38
        jr c,.objs
        ld iy,CAMPXTAB
        ld b,4
        ld c,0
.hut:   ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(tmp)
        or a
        sbc hl,de
        ld de,8
        add hl,de
        ld a,h
        or a
        jr nz,.nh
        ld a,l
        cp 16
        jr nc,.nh
        ; hit hut c
        ld hl,camp_lock
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr z,.nh
        dec (hl)
        ld (ix+0),0
        ld hl,camp_flash
        add hl,de
        ld (hl),4
        ld a,(camp_lock)
        ld hl,camp_lock
        add hl,de
        ld a,(hl)
        or a
        ld a,SFX_TINK
        jp nz,sfx_play
        ; door blown open
        push bc
        ld l,(iy+0)
        ld h,(iy+1)
        call mul16
        ld de,42*16
        call explosion_at
        ld hl,$0100
        call add_score
        ld a,SFX_HUT
        call sfx_play
        pop bc
        ret
.nh:    inc iy
        inc iy
        inc c
        djnz .hut
.objs:  ; test against the per-update hit list (x lo, x hi, y, w, h, flags, ptr)
        ld iy,hitlist
.o:     ld a,(iy+3)
        or a
        ret z
        ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(tmp)
        or a
        sbc hl,de               ; bx - ox
        ld a,h
        or a
        jr nz,.on
        ld a,l
        cp (iy+3)
        jr nc,.on
        ld a,(tmp+2)
        sub (iy+2)
        jr c,.on
        cp (iy+4)
        jr nc,.on
        ; hit
        ld (ix+0),0
        ld a,(iy+5)
        ld l,(iy+6)
        ld h,(iy+7)
        push hl
        pop iy
        and OF_SHOOT
        jp nz,obj_damage
        ld a,SFX_TINK
        jp sfx_play
.on:    ld de,8
        add iy,de
        jr .o

; list live collidable objects with pixel boxes for the bullet tests
build_hitlist:
        ld hl,hitlist
        ld ix,objs
        ld b,NOBJ
.l:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp OT_AA
        jr z,.st
        cp OT_SAM
        jr nz,.t
.st:    ld a,(ix+O_STATE)
        or a
        jr nz,.n
        ld a,(ix+O_TYPE)
.t:     push hl
        call objdef
        ld a,(hl)
        or a
        jr z,.np
        ld c,a                  ; w
        inc hl
        ld b,(hl)               ; h
        inc hl
        ld a,(hl)               ; flags
        pop hl
        and OF_SHOOT|OF_HARM
        jr z,.n
        ld e,a
        push hl
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        call div16
        ex de,hl                ; de = x px, l = flags
        ld a,l
        ld (tmp+7),a
        ld l,(ix+O_YL)
        ld h,(ix+O_YH)
        call div16
        ld a,l
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld a,(tmp+7)
        ld (hl),a
        inc hl
        push ix
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        jr .n
.np:    pop hl
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .l
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0               ; w = 0 terminates
        ret

hitlist: ds (NOBJ+1)*8

CAMPXTAB: dw CAMP0X,CAMP1X,CAMP2X,CAMP3X

objdef_iy:
        ld a,(iy+O_TYPE)
        push de
        call objdef
        pop de
        ret

; object IY takes a hit
obj_damage:
        ld (iy+O_FLASH),3
        dec (iy+O_HP)
        jr z,.kill
        ld a,SFX_TINK
        jp sfx_play
.kill:  call objdef_iy
        inc hl
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        push hl
        call add_score
        pop de
        ; popup with value
        ld a,(iy+O_TYPE)
        cp OT_CRATE
        jr z,.crate
        ld b,a
        push bc
        call obj_centre
        call explosion_at
        pop bc
        ld a,b
        call score_popup_type
        ld a,(iy+O_TYPE)
        cp OT_AA
        jr z,.wreck
        cp OT_SAM
        jr z,.wreck
        ld (iy+O_TYPE),0
        ret
.wreck: ld (iy+O_STATE),1
        ld (iy+O_HP),0
        ret
.crate: call obj_centre
        call explosion_at
        ld (iy+O_TYPE),0
        ret

; HL = centre x (1/16), DE = centre y (1/16) of object IY
obj_centre:
        call objdef_iy
        ld a,(hl)
        rlca
        rlca
        rlca                    ; w/2*16 = w*8
        ld c,a
        inc hl
        ld a,(hl)
        rlca
        rlca
        rlca
        ld b,a
        ld l,(iy+O_XL)
        ld h,(iy+O_XH)
        ld e,c
        ld d,0
        add hl,de
        push hl
        ld l,(iy+O_YL)
        ld h,(iy+O_YH)
        ld e,b
        add hl,de
        ex de,hl
        pop hl
        ret

; ------------------------------------------------------------------
; enemy bullets  (type 0 bullet, 1 flak shell, 2 bomb)
; ------------------------------------------------------------------
upd_ebul:
        ld ix,ebul
        ld b,NEB
.l:     push bc
        ld a,(ix+0)
        or a
        jp z,.n
        call bul_move
        ld a,(ix+7)
        cp 2
        jr nz,.nb
        ld a,(ix+6)             ; bombs accelerate
        cp 60
        jr nc,.nb
        add a,3
        ld (ix+6),a
.nb:    dec (ix+0)
        jr nz,.alive
        ld a,(ix+7)
        cp 1
        jr nz,.n
        ; flak shell bursts
        call ebul_pos
        call flak_at
        jr .n
.alive: ; ground?
        ld l,(ix+3)
        ld h,(ix+4)
        ld de,48*16
        or a
        sbc hl,de
        jr c,.air
        ld (ix+0),0
        call ebul_pos
        ld a,(ix+7)
        cp 2
        jr nz,.small
        push hl
        call explosion_at
        pop hl
        call div16
        ld c,7
        call kill_runners_near
        jr .n
.small: call dirt_puff
        jr .n
.air:   ; hits heli?
        call ebul_pos
        call div16
        ex de,hl
        call div16
        ex de,hl                ; hl = x px, e = y px
        call point_in_heli
        jr nc,.n
        ld (ix+0),0
        ld a,1
        call heli_hit
.n:     ld de,BSZ
        add ix,de
        pop bc
        dec b
        jp nz,.l
        ret

ebul_pos:
        ld l,(ix+1)
        ld h,(ix+2)
        ld e,(ix+3)
        ld d,(ix+4)
        ret

; HL = x px, E = y px -> carry if inside heli body
point_in_heli:
        ld a,(hstate)
        cp HS_DYING
        jr nc,.no
        push de
        ex de,hl
        ld hl,(heli_x)
        call div16
        ld bc,-7
        add hl,bc
        ex de,hl
        or a
        sbc hl,de
        pop de
        ld a,h
        or a
        jr nz,.no
        ld a,l
        cp 14
        jr nc,.no
        ld hl,(heli_y)
        call div16
        ld a,l
        sub e
        jr c,.no
        cp 7
        ret
.no:    or a
        ret

; spawn enemy bullet: HL = x (1/16), DE = y (1/16), B = vx, C = vy, A = type, life in (tmp+7)
ebul_spawn:
        push ix
        push af
        ld ix,ebul
        push bc
        ld b,NEB
.f:     ld a,(ix+0)
        or a
        jr z,.got
        push de
        ld de,BSZ
        add ix,de
        pop de
        djnz .f
        pop bc
        pop af
        pop ix
        ret
.got:   pop bc
        pop af
        ld (ix+7),a
        ld (ix+1),l
        ld (ix+2),h
        ld (ix+3),e
        ld (ix+4),d
        ld (ix+5),b
        ld (ix+6),c
        ld a,(tmp+7)
        ld (ix+0),a
        pop ix
        ret

; fire an aimed shot from HL,DE (1/16) at the heli. A = speed, (tmp+7)=life, type in (tmp+6)
fire_at_heli:
        push hl
        ld hl,(heli_x)
        ld (fa_tx),hl
        pop hl
fire_at_point:
        ld (fa_spd),a
        ld (fa_x),hl
        ld (fa_y),de
        call div16
        ex de,hl
        ld hl,(fa_tx)
        call div16
        or a
        sbc hl,de
        push hl
        ld hl,(fa_y)
        call div16
        ex de,hl
        ld hl,(heli_y)
        call div16
        ld bc,-4
        add hl,bc
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop de
        ld a,(fa_spd)
        call aim
        ld b,d
        ld c,e
        ld hl,(fa_x)
        ld de,(fa_y)
        ld a,(tmp+6)
        jp ebul_spawn

fa_spd  db 0
fa_x    dw 0
fa_y    dw 0
fa_tx   dw 0                    ; target x (normally the heli)

; ------------------------------------------------------------------
; objects
; ------------------------------------------------------------------
obj_alloc:      ; -> IX free slot, carry if none
        ld ix,objs
        ld b,NOBJ
        ld de,OBJSZ
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.got
        add ix,de
        djnz .l
        scf
        ret
.got:   push ix
        pop hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,OBJSZ-1
        ldir
        or a
        ret

obj_init_hp:
        ld a,(ix+O_TYPE)
        call objdef
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (ix+O_HP),a
        ret

count_type:     ; A = type -> A = count
        ld c,a
        ld hl,objs
        ld de,OBJSZ
        ld b,NOBJ
        xor a
.l:     push af
        ld a,(hl)
        cp c
        jr nz,.n
        pop af
        inc a
        push af
.n:     pop af
        add hl,de
        djnz .l
        ret

upd_objs:
        ld ix,objs
        ld b,NOBJ
.l:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        ld a,(ix+O_FLASH)
        or a
        jr z,.nf
        dec (ix+O_FLASH)
.nf:    ld a,(ix+O_TYPE)
        add a,a
        ld l,a
        ld h,0
        ld de,OBJUPD-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .l
        ret

OBJUPD: dw u_tank,u_jet,u_trans,u_plane3d,u_aa,u_sam,u_missile,u_gunship
        dw u_balloon,u_crate,u_explo,u_flak,u_popup

obj_move:
        ld a,(ix+O_VX)
        call sext
        ld e,(ix+O_XL)
        ld d,(ix+O_XH)
        add hl,de
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld a,(ix+O_VY)
        call sext
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        add hl,de
        ld (ix+O_YL),l
        ld (ix+O_YH),h
        ret

; object px x minus camera -> HL (signed)
obj_sx:
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        call div16
        ld de,(camx)
        or a
        sbc hl,de
        ret

; kill if more than ~180px from screen centre
obj_cull:
        call obj_sx
        ld de,-64
        add hl,de
        bit 7,h
        jr z,.p
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
.p:     ld de,190
        or a
        sbc hl,de
        ret c
        ld (ix+O_TYPE),0
        ret

; touching the heli? (object box vs heli box) -> carry
obj_touch_heli:
        ld a,(hstate)
        cp HS_DYING
        jr nc,.no
        ld a,(ix+O_TYPE)
        call objdef
        ld c,(hl)               ; w
        inc hl
        ld b,(hl)               ; h
        ld hl,(heli_x)
        call div16
        ld de,-7
        add hl,de
        ex de,hl
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        call div16
        or a
        sbc hl,de               ; ox - left
        ld e,c
        ld d,0
        add hl,de
        ld a,h
        or a
        jr nz,.no
        ld a,l
        or a
        jr z,.no
        ld d,a
        ld a,c
        add a,14
        cp d
        jr c,.no
        jr z,.no
        ld hl,(heli_y)
        call div16
        ld de,-7
        add hl,de
        ex de,hl
        ld l,(ix+O_YL)
        ld h,(ix+O_YH)
        call div16
        or a
        sbc hl,de               ; oy - top
        ld e,b
        ld d,0
        add hl,de
        ld a,h
        or a
        jr nz,.no
        ld a,l
        or a
        jr z,.no
        ld d,a
        ld a,b
        add a,8
        cp d
        jr c,.no
        jr z,.no
        scf
        ret
.no:    or a
        ret

; --- TANK -----------------------------------------------------------
u_tank:
        ld a,(upd_ctr)
        and 1
        jr nz,.nm
        call obj_move
.nm:    inc (ix+O_ANIM)
        ; turn at bounds or randomly
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        call div16
        ld de,16
        or a
        sbc hl,de
        jr c,.right
        ld de,BASEX-40-16
        or a
        sbc hl,de
        jr nc,.left
        dec (ix+O_AUX)
        jr nz,.fire
        call rand
        and 127
        add a,60
        ld (ix+O_AUX),a
        ld a,(ix+O_VX)
        neg
        ld (ix+O_VX),a
        jr .fire
.right: ld (ix+O_VX),12
        jr .fire
.left:  ld (ix+O_VX),-12
.fire:  ld a,(ix+O_VX)
        rlca
        and 1
        xor 1
        ld (ix+O_DIR),a         ; 0 left, 1 right
        dec (ix+O_TIMER)
        ret nz
        call fire_interval
        ld (ix+O_TIMER),a
        ; heli in range and airborne?
        ld a,(hstate)
        or a
        ret nz
        call heli_dx
        cp 70
        ret nc
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld de,6*16
        add hl,de
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        ld a,30
        ld (tmp+7),a
        xor a
        ld (tmp+6),a
        ld a,30
        call fire_at_heli
        ld a,SFX_ESHOT
        jp sfx_play

fire_interval:  ; A = random fire delay scaled by difficulty
        call rand
        and 63
        ld b,a
        ld a,(difficulty)
        or a
        ld a,b
        jr nz,.n
        add a,50
.n:     add a,45
        ld b,a
        ld a,(difficulty)
        cp 2
        ld a,b
        ret nz
        sub 20
        ret

; |heli px - object px| clamped to 255 -> A
heli_dx:
        ld hl,(heli_x)
        call div16
        push hl
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        call div16
        pop de
        or a
        sbc hl,de
        bit 7,h
        jr z,.p
        ld a,l
        neg
        ld l,a
        ld a,h
        cpl
        adc a,0
        ld h,a
.p:     ld a,h
        or a
        ld a,255
        ret nz
        ld a,l
        ret

; --- JET -------------------------------------------------------------
u_jet:
        call obj_move
        call obj_cull
        ld a,(ix+O_TYPE)
        or a
        ret z
        call radar_check
        call obj_touch_heli
        jr nc,.nt
        ld a,2
        call heli_hit
        push ix
        pop iy
        jp obj_damage_force
.nt:    ; shoot once when the heli is ahead and close
        ld a,(ix+O_AUX)
        or a
        jr nz,.bomb
        call heli_dx
        cp 72
        jr nc,.bomb
        ; is heli in front?
        ld hl,(heli_x)
        ld e,(ix+O_XL)
        ld d,(ix+O_XH)
        or a
        sbc hl,de
        ld a,h
        xor (ix+O_VX)
        and $80
        jr nz,.bomb
        ld (ix+O_AUX),1
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld de,8*16
        add hl,de
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        ld a,40
        ld (tmp+7),a
        xor a
        ld (tmp+6),a
        ld a,44
        call fire_at_heli
        ld a,SFX_ESHOT
        jp sfx_play
.bomb:  call rand
        and 63
        ret nz
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld de,8*16
        add hl,de
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        ld a,e
        add a,5*16
        ld e,a
        jr nc,.b1
        inc d
.b1:    ld a,(ix+O_VX)
        sra a
        ld b,a
        ld c,8
        ld a,60
        ld (tmp+7),a
        ld a,2
        jp ebul_spawn

obj_damage_force:       ; destroy IY outright
        ld (iy+O_HP),1
        jp obj_damage

; --- TRANSPORT (can't be shot: as in the original) --------------------
u_trans:
        call obj_move
        call obj_cull
        ld a,(ix+O_TYPE)
        or a
        ret z
        call whoosh_check
        call obj_touch_heli
        ret nc
        ld a,2
        jp heli_hit

; radar beep-beep once, as an enemy aircraft closes in from off screen
radar_check:
        ld a,(ix+O_AUX2)
        or a
        ret nz
        call obj_sx
        bit 7,h
        jr z,.r
        ld de,100
        add hl,de
        bit 7,h
        ret nz
        jr .beep
.r:     ld de,-128
        add hl,de
        bit 7,h
        ret nz
        ld a,h
        or a
        ret nz
        ld a,l
        cp 100
        ret nc
.beep:  ld (ix+O_AUX2),1
        ld a,SFX_RADAR
        jp sfx_play

; whoosh as a freight plane roars into view
whoosh_check:
        ld a,(ix+O_AUX2)
        or a
        ret nz
        call obj_sx
        ld a,h
        or a
        ret nz
        ld a,l
        cp 128
        ret nc
        ld (ix+O_AUX2),1
        ld a,SFX_WHOOSH
        jp sfx_play

; --- PLANE 3D: flying towards or away from you (harmless) -------------
u_plane3d:
        dec (ix+O_TIMER)
        ret nz
        ld (ix+O_TIMER),10
        inc (ix+O_STATE)
        ld a,(ix+O_STATE)
        cp 3
        jr c,.ok
        ld (ix+O_TYPE),0
        ret
.ok:    ld a,(ix+O_DIR)
        or a
        ld a,(ix+O_YL)
        jr nz,.away
        sub 24                  ; coming closer: rises over you
        jr nc,.s
        dec (ix+O_YH)
        jr .s
.away:  add a,10
        jr nc,.s
        inc (ix+O_YH)
.s:     ld (ix+O_YL),a
        ld a,(ix+O_STATE)
        cp 2
        ret nz
        ld a,SFX_WHOOSH
        jp sfx_play

; --- AA GUN -------------------------------------------------------------
u_aa:
        ld a,(ix+O_STATE)
        or a
        ret nz
        dec (ix+O_TIMER)
        ret nz
        call fire_interval
        add a,20
        ld (ix+O_TIMER),a
        ld a,(hstate)
        or a
        ret nz
        call heli_dx
        cp 80
        ret nc
        ld hl,(heli_y)
        ld de,40*16
        or a
        sbc hl,de
        ret nc
        ; flak shell aimed at where the heli will be
        ld a,(hvx)
        call sext
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(heli_x)
        add hl,de
        ld (fa_tx),hl
        ld hl,(heli_y)
        call div16
        ld a,42
        sub l
        srl a
        add a,2
        ld (tmp+7),a
        ld a,1
        ld (tmp+6),a
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld de,4*16
        add hl,de
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        ld a,32
        call fire_at_point
        ld a,SFX_FLAK
        jp sfx_play

; --- SAM SITE -------------------------------------------------------------
u_sam:
        ld a,(ix+O_STATE)
        or a
        ret nz
        dec (ix+O_TIMER)
        ret nz
        call rand
        and 63
        add a,120
        ld (ix+O_TIMER),a
        ld a,(hstate)
        or a
        ret nz
        call heli_dx
        cp 96
        ret nc
        push ix
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        push hl
        push de
        call obj_alloc
        pop de
        pop hl
        jr c,.no
        ld (ix+O_TYPE),OT_MISSILE
        ld bc,2*16
        add hl,bc
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld a,e
        sub 3*16
        ld e,a
        jr nc,.m1
        dec d
.m1:    ld (ix+O_YL),e
        ld (ix+O_YH),d
        ld (ix+O_VY),-30
        ld (ix+O_TIMER),110
        call obj_init_hp
        ld a,SFX_MISSILE
        call sfx_play
.no:    pop ix
        ret

; --- MISSILE (homing) --------------------------------------------------
u_missile:
        dec (ix+O_TIMER)
        jr nz,.fly
        ld (ix+O_TYPE),0
        call obj_centre_ix
        jp explosion_at
.fly:   ; steer
        ld hl,(heli_x)
        ld e,(ix+O_XL)
        ld d,(ix+O_XH)
        or a
        sbc hl,de
        ld a,(ix+O_VX)
        ld c,36
        bit 7,h
        jr z,.r
        ld c,-36
.r:     ld b,2
        call approach
        ld (ix+O_VX),a
        ld hl,(heli_y)
        ld de,-4*16
        add hl,de
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        or a
        sbc hl,de
        ld a,(ix+O_VY)
        ld c,30
        bit 7,h
        jr z,.d
        ld c,-30
.d:     ld b,2
        call approach
        ld (ix+O_VY),a
        call obj_move
        ld a,(ix+O_TIMER)
        and 1
        jr nz,.ns
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        call smoke_at
.ns:    ld a,(ix+O_VX)
        rlca
        and 1
        xor 1
        ld (ix+O_DIR),a
        call obj_touch_heli
        ret nc
        ld a,1
        call heli_hit
        ld (ix+O_TYPE),0
        call obj_centre_ix
        jp explosion_at

obj_centre_ix:
        push ix
        pop iy
        jp obj_centre

; --- GUNSHIP -------------------------------------------------------------
u_gunship:
        call radar_check
        inc (ix+O_ANIM)
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld de,(heli_x)
        or a
        sbc hl,de               ; gun - heli
        ld bc,44*16
        bit 7,h
        jr z,.side
        ld bc,-44*16
.side:  ld h,d
        ld l,e
        add hl,bc               ; target x
        ld e,(ix+O_XL)
        ld d,(ix+O_XH)
        or a
        sbc hl,de               ; target - gun
        ld c,0
        ld de,4*16
        add hl,de
        ld a,h
        or a
        jr nz,.far
        ld a,l
        cp 8*16
        jr c,.tr
.far:   ld c,22
        bit 7,h
        jr z,.tr
        ld c,-22
.tr:    ld a,(ix+O_VX)
        ld b,1
        call approach
        ld (ix+O_VX),a
        ld hl,(heli_y)
        ld de,-6*16
        add hl,de
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        or a
        sbc hl,de
        ld a,(ix+O_VY)
        ld c,12
        bit 7,h
        jr z,.tv
        ld c,-12
.tv:    ld b,1
        call approach
        ld (ix+O_VY),a
        call obj_move
        ; face the heli
        ld hl,(heli_x)
        ld e,(ix+O_XL)
        ld d,(ix+O_XH)
        or a
        sbc hl,de
        ld a,h
        rlca
        and 1
        xor 1
        ld (ix+O_DIR),a
        call obj_touch_heli
        jr nc,.nt
        ld a,1
        call heli_hit
.nt:    dec (ix+O_TIMER)
        ret nz
        call fire_interval
        sub 10
        ld (ix+O_TIMER),a
        ld a,(hstate)
        cp HS_DYING
        ret nc
        call heli_dx
        cp 90
        ret nc
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld de,6*16
        add hl,de
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        ld a,e
        add a,3*16
        ld e,a
        jr nc,.g1
        inc d
.g1:    ld a,40
        ld (tmp+7),a
        xor a
        ld (tmp+6),a
        ld a,40
        call fire_at_heli
        ld a,SFX_ESHOT
        jp sfx_play

; --- BALLOON MINE ----------------------------------------------------------
u_balloon:
        inc (ix+O_ANIM)
        ld a,(ix+O_ANIM)
        and 31
        cp 16
        ld a,3
        jr c,.u
        ld a,-3
.u:     ld (ix+O_VY),a
        call obj_move
        call obj_cull
        ld a,(ix+O_TYPE)
        or a
        ret z
        call obj_touch_heli
        ret nc
        ld a,1
        call heli_hit
        push ix
        pop iy
        jp obj_damage_force

; --- SUPPLY CRATE ----------------------------------------------------------
u_crate:
        ld a,(ix+O_STATE)
        or a
        jr nz,.ground
        call obj_move
        ld l,(ix+O_YL)
        ld h,(ix+O_YH)
        ld de,(GROUNDY-6)*16
        or a
        sbc hl,de
        jr c,.coll
        ld (ix+O_STATE),1
        ld (ix+O_TIMER),250
        ld (ix+O_YL),(GROUNDY-6)*16 & 255
        ld (ix+O_YH),(GROUNDY-6)*16 / 256
        jr .coll
.ground:
        dec (ix+O_TIMER)
        jr nz,.coll
        ld (ix+O_TYPE),0
        ret
.coll:  call obj_touch_heli
        ret nc
        ld (ix+O_TYPE),0
        ld a,SFX_POWER
        call sfx_play
        ld a,(ix+O_AUX)
        or a
        jr nz,.c1
        ld hl,(fuel)
        ld de,MAXFUEL/2
        add hl,de
        ld de,MAXFUEL
        or a
        sbc hl,de
        add hl,de
        jr c,.f
        ex de,hl
.f:     ld (fuel),hl
        ld a,PU_FUEL
        jr .pop
.c1:    dec a
        jr nz,.c2
        ld a,3
        ld (armour),a
        ld a,PU_ARMOR
        jr .pop
.c2:    dec a
        jr nz,.c3
        ld a,(lives)
        cp 9
        jr nc,.c3
        inc a
        ld (lives),a
        ld a,PU_1UP
        jr .pop
.c3:    ld hl,$1000
        call add_score
        ld a,PU_1000
.pop:   push af
        call obj_centre_ix
        pop af
        jp popup_at

; --- EXPLOSION -----------------------------------------------------------
u_explo:
        inc (ix+O_TIMER)
        ld a,(ix+O_TIMER)
        cp 12
        ret c
        ld (ix+O_TYPE),0
        ret

; --- FLAK burst -----------------------------------------------------------
u_flak:
        inc (ix+O_TIMER)
        ld a,(ix+O_TIMER)
        cp 8
        jr c,.a
        ld (ix+O_TYPE),0
        ret
.a:     cp 5
        ret nc
        ; within 7px of burst centre?
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld de,2*16
        add hl,de
        call div16
        ld e,(ix+O_YL)
        ld d,(ix+O_YH)
        ex de,hl
        call div16
        ld a,l
        add a,2
        ld e,a
        ex de,hl
        ; point test with slack: test 3 points
        push hl
        push de
        call point_in_heli
        pop de
        pop hl
        jr c,.hit
        ld bc,4
        add hl,bc
        push hl
        push de
        call point_in_heli
        pop de
        pop hl
        jr c,.hit
        ld bc,-8
        add hl,bc
        call point_in_heli
        ret nc
.hit:   ld a,1
        jp heli_hit

; --- score / message popup --------------------------------------------------
u_popup:
        dec (ix+O_TIMER)
        jr nz,.m
        ld (ix+O_TYPE),0
        ret
.m:     ld a,(ix+O_YL)
        sub 6
        ld (ix+O_YL),a
        ret nc
        dec (ix+O_YH)
        ret

; popup A = message index at HL (x 1/16), DE (y 1/16)
popup_at:
        push af
        push hl
        push de
        call obj_alloc
        pop de
        pop hl
        jr c,.no
        pop af
        ld (ix+O_TYPE),OT_POPUP
        ld (ix+O_AUX),a
        ld bc,-6*16
        add hl,bc
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld (ix+O_YL),e
        ld (ix+O_YH),d
        ld (ix+O_TIMER),30
        ret
.no:    pop af
        ret

; score popup for object type A at IY centre
score_popup_type:
        ld e,a
        ld d,0
        ld hl,TYPE_PU
        add hl,de
        ld a,(hl)
        or a
        ret z
        push af
        call obj_centre
        pop af
        push ix
        call popup_at
        pop ix
        ret

TYPE_PU: db 0,PU_250,PU_300,0,0,PU_200,PU_400,PU_100,PU_500,PU_50,0,0,0,0

PU_50   equ 1
PU_100  equ 2
PU_200  equ 3
PU_250  equ 4
PU_300  equ 5
PU_400  equ 6
PU_500  equ 7
PU_1500 equ 8
PU_FUEL equ 9
PU_ARMOR equ 10
PU_1UP  equ 11
PU_1000 equ 12
PU_OPEN equ 13
PU_FULL equ 14
PUSTR:  dw 0,.s50,.s100,.s200,.s250,.s300,.s400,.s500,.s1500,.sf,.sa,.s1,.s1000,.so,.sfu
.s50:   db "50",0
.s100:  db "100",0
.s200:  db "200",0
.s250:  db "250",0
.s300:  db "300",0
.s400:  db "400",0
.s500:  db "500",0
.s1500: db "1500",0
.sf:    db "FUEL",0
.sa:    db "ARMOR",0
.s1:    db "1UP",0
.s1000: db "1000",0
.so:    db "OPEN",0
.sfu:   db "FULL",0

; ------------------------------------------------------------------
; effects: explosions, particles
; ------------------------------------------------------------------
; HL = x, DE = y (1/16, centre)
explosion_at:
        push hl
        push de
        push ix
        push hl
        push de
        call obj_alloc
        pop de
        pop hl
        jr c,.np
        ld (ix+O_TYPE),OT_EXPLO
        ld bc,-4*16
        add hl,bc
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ex de,hl
        ld bc,-3*16
        add hl,bc
        ld (ix+O_YL),l
        ld (ix+O_YH),h
.np:    pop ix
        pop de
        pop hl
        ld b,6
        call debris
        ld a,4
        ld (shake),a
        ld a,SFX_EXPL
        jp sfx_play

big_explosion:
        push hl
        push de
        call explosion_at
        pop de
        pop hl
        ld b,12
        call debris
        ld a,12
        ld (shake),a
        ld a,SFX_BIGEXPL
        jp sfx_play

; flak burst object at HL,DE
flak_at:
        push ix
        push hl
        push de
        call obj_alloc
        pop de
        pop hl
        jr c,.n
        ld (ix+O_TYPE),OT_FLAK
        ld bc,-2*16
        add hl,bc
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ex de,hl
        add hl,bc
        ld (ix+O_YL),l
        ld (ix+O_YH),h
        ld a,SFX_FLAK
        call sfx_play
.n:     pop ix
        ret

; particle spawn: HL x, DE y, B vx, C vy, A colour (bit7 = gravity), life in (tmp+5)
part_spawn:
        push ix
        push af
        push bc
        push de
        ld ix,parts
        ld b,NPART
        ld de,PSZ
.f:     ld a,(ix+0)
        or a
        jr z,.g
        add ix,de
        djnz .f
        pop de
        pop bc
        pop af
        pop ix
        ret
.g:     pop de
        pop bc
        pop af
        ld (ix+7),a
        ld (ix+1),l
        ld (ix+2),h
        ld (ix+3),e
        ld (ix+4),d
        ld (ix+5),b
        ld (ix+6),c
        ld a,(tmp+5)
        ld (ix+0),a
        pop ix
        ret

; B particles of debris at HL,DE
debris:
.l:     push bc
        push hl
        push de
        call rand
        and 63
        sub 32
        ld b,a
        call rand
        and 31
        add a,40
        neg
        ld c,a
        call rand
        and 15
        add a,14
        ld (tmp+5),a
        call rand
        and 1
        add a,1
        bit 0,a
        jr z,.c
        ld a,3
.c:     or $80
        pop de
        pop hl
        push hl
        push de
        call part_spawn
        pop de
        pop hl
        pop bc
        djnz .l
        ret

smoke_at:       ; HL, DE (1/16)
        push bc
        call rand
        and 7
        sub 4
        ld b,a
        ld c,-6
        ld a,12
        ld (tmp+5),a
        ld a,(skycol)
        xor 2                   ; a colour that differs from the sky
        and 3
        call part_spawn
        pop bc
        ret

dirt_puff:      ; HL x, DE y
        ld b,3
.l:     push bc
        push hl
        push de
        call rand
        and 31
        sub 16
        ld b,a
        call rand
        and 15
        add a,10
        neg
        ld c,a
        ld a,8
        ld (tmp+5),a
        ld a,$83
        call part_spawn
        pop de
        pop hl
        pop bc
        djnz .l
        ret

dust_puff:
        ld hl,(heli_x)
        call rand
        and 1
        ld b,40
        jr z,.r
        ld b,-40
.r:     ld de,GROUNDY*16
        ld c,-4
        ld a,6
        ld (tmp+5),a
        ld a,1
        jp part_spawn

upd_parts:
        ld ix,parts
        ld b,NPART
.l:     ld a,(ix+0)
        or a
        jr z,.n
        dec (ix+0)
        push bc
        call bul_move
        pop bc
        bit 7,(ix+7)
        jr z,.n
        ld a,(ix+6)
        add a,4
        ld (ix+6),a
.n:     ld de,PSZ
        add ix,de
        djnz .l
        ret

; ------------------------------------------------------------------
; prisoners on the ground
; ------------------------------------------------------------------
R_RUN   equ 1
R_WAIT  equ 2
R_HOME  equ 3
R_DEAD  equ 4

runner_alloc:   ; -> IY, carry if none
        ld iy,runners
        ld b,NRUN
        ld de,RSZ
.l:     ld a,(iy+0)
        or a
        ret z
        add iy,de
        djnz .l
        scf
        ret

upd_runners:
        ld ix,runners
        ld b,NRUN
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        inc (ix+4)
        cp R_RUN
        jr z,.run
        cp R_WAIT
        jp z,.wait
        cp R_HOME
        jp z,.home
        ; dead
        dec (ix+6)
        jr nz,.n
        ld (ix+0),0
.n:     ld de,RSZ
        add ix,de
        pop bc
        djnz .l
        ret
.run:   ld a,(hstate)
        cp HS_LANDED
        jr z,.r1
        ld (ix+0),R_WAIT
        ld hl,heading
        dec (hl)
        jr .n
.r1:    ld hl,(heli_x)
        ld e,(ix+1)
        ld d,(ix+2)
        or a
        sbc hl,de
        ; close enough?
        push hl
        bit 7,h
        jr z,.p
        ld a,l
        neg
        ld l,a
        ld a,h
        cpl
        adc a,0
        ld h,a
.p:     ld de,3*16
        or a
        sbc hl,de
        pop hl
        jr c,.board
        ld a,16
        ld (ix+5),1
        bit 7,h
        jr z,.mv
        ld a,-16
        ld (ix+5),0
.mv:    call sext
        ld e,(ix+1)
        ld d,(ix+2)
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        jr .n
.board: ld (ix+0),0
        ld hl,heading
        dec (hl)
        ld hl,aboard
        inc (hl)
        ld e,(ix+3)
        ld d,0
        ld hl,aboard_c
        add hl,de
        inc (hl)
        ld a,SFX_PICKUP
        call sfx_play
        ld a,(said_hi)
        or a
        jr nz,.hi
        inc a
        ld (said_hi),a
        push ix
        ld hl,SPEECH_HI
        call speak
        pop ix
.hi:    ld a,(aboard)
        cp CAPACITY
        jp nz,.n
        ld hl,(heli_x)
        ld de,(GROUNDY-10)*16
        ld a,PU_FULL
        push ix
        call popup_at
        pop ix
        jp .n
.wait:  ld a,(hstate)
        cp HS_LANDED
        jp nz,.n
        ld a,(aboard)
        ld hl,heading
        add a,(hl)
        cp CAPACITY
        jp nc,.n
        ld hl,(heli_x)
        call div16
        push hl
        ld l,(ix+1)
        ld h,(ix+2)
        call div16
        pop de
        or a
        sbc hl,de
        ld a,l
        add a,48
        ld l,a
        ld a,h
        adc a,0
        jp nz,.n
        ld a,l
        cp 96
        jp nc,.n
        ld (ix+0),R_RUN
        ld hl,heading
        inc (hl)
        jp .n
.home:  ld l,(ix+1)
        ld h,(ix+2)
        ld de,16
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld (ix+5),1
        call div16
        ld de,HANGARX
        or a
        sbc hl,de
        jp c,.n
        ; safe!
        ld (ix+0),0
        ld hl,rescued
        inc (hl)
        ld a,(ix+3)
        add a,a
        ld e,a
        ld d,0
        ld hl,CAMPVAL
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push ix
        call add_score
        pop ix
        ld a,SFX_UNLOAD
        call sfx_play
        ld e,(ix+3)
        ld d,0
        ld hl,CAMPPU
        add hl,de
        ld a,(hl)
        ld hl,HANGARX*16
        ld de,(GROUNDY-9)*16
        push ix
        call popup_at
        pop ix
        jp .n

CAMPVAL: dw $1500,$0500,$0200,$0100     ; far camp pays most (as the original)
CAMPPU:  db PU_1500,PU_500,PU_200,PU_100

; kill runners within C px of HL (px)
kill_runners_near:
        push ix
        ld ix,runners
        ld b,NRUN
.l:     ld a,(ix+0)
        or a
        jr z,.n
        cp R_DEAD
        jr z,.n
        push hl
        push bc
        ld e,(ix+1)
        ld d,(ix+2)
        ex de,hl
        call div16
        or a
        sbc hl,de               ; runner - x
        ld a,l
        add a,c
        ld e,a
        ld a,h
        adc a,0
        pop bc
        jr nz,.np
        ld a,c
        add a,a
        cp e
        jr c,.np
        ; dead
        ld a,(ix+0)
        cp R_RUN
        jr nz,.nr
        ld hl,heading
        dec (hl)
.nr:    ld (ix+0),R_DEAD
        ld (ix+6),60
        ld hl,lost
        inc (hl)
.np:    pop hl
.n:     ld de,RSZ
        add ix,de
        djnz .l
        pop ix
        ret

; ------------------------------------------------------------------
; camps and base
; ------------------------------------------------------------------
upd_camps:
        ld b,4
        ld hl,camp_flash
.cf:    ld a,(hl)
        or a
        jr z,.cf1
        dec (hl)
.cf1:   inc hl
        djnz .cf
        ld a,(hstate)
        cp HS_LANDED
        jp nz,.endchk
        ld hl,(heli_x)
        call div16
        ld (tmp),hl
        ; at the base pad?
        ld de,PADX0
        or a
        sbc hl,de
        jp c,.camps
        ld de,PADX1-PADX0
        or a
        sbc hl,de
        jp nc,.camps
        ; refuel
        ld hl,(fuel)
        ld de,48
        add hl,de
        ld de,MAXFUEL
        or a
        sbc hl,de
        add hl,de
        jr c,.rf
        ex de,hl
.rf:    ld (fuel),hl
        ld hl,pad_t
        inc (hl)
        ld a,(hl)
        and 31
        jr nz,.unl
        ld a,(armour)
        cp 3
        jr nc,.unl
        inc a
        ld (armour),a
        ld a,SFX_BLIP
        call sfx_play
.unl:   ; unload one every 6 updates
        ld a,(pad_t)
        ld b,6
        call mod_b
        jp nz,.endchk
        ld a,(aboard)
        or a
        jp z,.endchk
        call runner_alloc
        jp c,.endchk
        ld hl,aboard_c
        ld c,0
.fc:    ld a,(hl)
        or a
        jr nz,.gc
        inc hl
        inc c
        jr .fc
.gc:    dec (hl)
        ld hl,aboard
        dec (hl)
        ld a,(said_bye)
        or a
        jr nz,.by
        inc a
        ld (said_bye),a
        push bc
        push iy
        ld hl,SPEECH_BYE
        call speak
        pop iy
        pop bc
.by:
        ld (iy+0),R_HOME
        ld (iy+3),c
        ld hl,(heli_x)
        ld (iy+1),l
        ld (iy+2),h
        ld (iy+4),0
        jp .endchk
.camps: ; in a camp enclosure?
        ld iy,CAMPXTAB
        ld c,0
.cl:    ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(tmp)
        or a
        sbc hl,de
        ld de,30
        add hl,de
        ld a,h
        or a
        jr nz,.cn
        ld a,l
        cp 60
        jr c,.incamp
.cn:    inc iy
        inc iy
        inc c
        ld a,c
        cp 4
        jr c,.cl
        jp .endchk
.incamp:
        ld b,0
        ld hl,camp_lock
        add hl,bc
        ld a,(hl)
        or a
        jp nz,.endchk           ; door still locked: shoot it open!
        ld hl,camp_cnt
        add hl,bc
        ld a,(hl)
        or a
        jp z,.endchk
        ld a,(aboard)
        ld d,a
        ld a,(heading)
        add a,d
        cp CAPACITY
        jp nc,.endchk
        ld a,(camp_rel)
        inc a
        ld (camp_rel),a
        and 7
        jp nz,.endchk
        push hl
        push bc
        call runner_alloc
        pop bc
        pop hl
        jp c,.endchk
        dec (hl)
        ld hl,heading
        inc (hl)
        ld (iy+0),R_RUN
        ld (iy+3),c
        ld (iy+4),0
        ld e,c
        ld d,0
        ld hl,CAMPXTAB
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call mul16
        ld (iy+1),l
        ld (iy+2),h
.endchk:
        ; level over? nobody left anywhere
        ld a,(end_reason)
        or a
        ret nz
        ld hl,camp_cnt
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        ld hl,aboard
        or (hl)
        ret nz
        ld hl,runners
        ld b,NRUN
        ld de,RSZ
.rl:    ld a,(hl)
        or a
        jr z,.rn
        cp R_DEAD
        ret nz
.rn:    add hl,de
        djnz .rl
        ld a,1
        ld (end_reason),a
        ret

mod_b:  ; A mod B, Z if zero
.l:     cp b
        jr c,.d
        sub b
        jr .l
.d:     or a
        ret

; ------------------------------------------------------------------
; enemy director
; ------------------------------------------------------------------
director:
        ld a,(demo)
        or a
        jr z,.go
        ld a,(upd_ctr)
        and 1
        ret nz
.go:    ; heat: more aggressive with prisoners aboard
        ld a,(aboard)
        srl a
        srl a
        inc a
        ld (tmp+1),a
        ld c,0
.cls:   push bc
        ld a,c
        add a,a
        ld e,a
        ld d,0
        ld ix,(lvlptr)
        add ix,de
        ld l,(ix+LV_INT)
        ld h,(ix+LV_INT+1)
        ld a,h
        or l
        jr z,.next
        ld (tmp+2),hl           ; interval
        ld hl,dir_t
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; de = timer
        ld a,(tmp+1)
        ld c,a
        ld a,e
        sub c
        ld e,a
        ld a,d
        sbc a,0
        ld d,a
        jr c,.fire
        or e
        jr z,.fire
        ld (hl),d
        dec hl
        ld (hl),e
        jr .next
.fire:  ; timer = 3/4 interval + rand(0..63)
        push hl
        ld hl,(tmp+2)
        srl h
        rr l
        ld d,h
        ld e,l
        srl d
        rr e
        add hl,de
        call rand
        and 63
        call sext_add
        ex de,hl
        pop hl
        ld (hl),d
        dec hl
        ld (hl),e
        pop bc
        push bc
        ld a,c
        call spawn_class
.next:  pop bc
        inc c
        ld a,c
        cp 6
        jr c,.cls
        ; supply crates
        ld hl,(crate_t)
        dec hl
        ld (crate_t),hl
        ld a,h
        or l
        ret nz
        ld hl,900
        ld (crate_t),hl
        jp spawn_crate

spawn_class:
        or a
        jp z,spawn_tank
        dec a
        jp z,spawn_jet
        dec a
        jp z,spawn_trans
        dec a
        jp z,spawn_gunship
        dec a
        jp z,spawn_balloon
        jp spawn_plane3d

; edge position: A = 0 left / 1 right -> HL = world x (1/16) just offscreen
edge_x:
        ld hl,(camx)
        or a
        jr nz,.r
        ld de,-24
        jr .s
.r:     ld de,140
.s:     add hl,de
        jp mul16

spawn_tank:
        ld a,OT_TANK
        call count_type
        ld ix,(lvlptr)
        cp (ix+LV_TMAX)
        ret nc
        call obj_alloc
        ret c
        call rand
        and 1
        push af
        call edge_x
        pop af
        ; don't spawn in the base
        push hl
        call div16
        ld de,BASEX-48
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ld hl,(BASEX-100)*16
        xor a
.ok:    ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld (ix+O_TYPE),OT_TANK
        or a
        ld a,12
        jr z,.v
        ld a,-12
.v:     ld (ix+O_VX),a
        ld hl,(GROUNDY-5)*16
        ld (ix+O_YL),l
        ld (ix+O_YH),h
        ld (ix+O_AUX),90
        ld (ix+O_TIMER),70
        jp obj_init_hp

spawn_air:      ; common: type A, speed B -> IX object, from a random edge, altitude 4..30
        ld (sa_type),a
        ld a,b
        ld (sa_spd),a
        call obj_alloc
        ret c
        ld a,(sa_type)
        ld (ix+O_TYPE),a
        call rand
        and 1
        ld (sa_side),a
        call edge_x
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld a,(sa_side)
        or a
        ld a,(sa_spd)
        jr z,.v
        neg
.v:     ld (ix+O_VX),a
        rlca
        and 1
        xor 1
        ld (ix+O_DIR),a
        ld b,26
        call rand_n
        add a,4
        ld l,a
        ld h,0
        call mul16
        ld (ix+O_YL),l
        ld (ix+O_YH),h
        call obj_init_hp
        or a
        ret
sa_type db 0
sa_spd  db 0
sa_side db 0

spawn_jet:
        ld a,OT_JET
        ld b,54
        jp spawn_air

spawn_trans:
        ld a,OT_TRANS
        call count_type
        or a
        ret nz
        ld a,OT_TRANS
        ld b,26
        call spawn_air
        ret c
        ld a,SFX_WARN
        jp sfx_play

spawn_gunship:
        ld a,OT_GUNSHIP
        call count_type
        cp 2
        ret nc
        ld a,OT_GUNSHIP
        ld b,20
        call spawn_air
        ret c
        ld (ix+O_TIMER),60
        ret

spawn_balloon:
        ld a,OT_BALLOON
        call count_type
        cp 4
        ret nc
        call obj_alloc
        ret c
        ld (ix+O_TYPE),OT_BALLOON
        ; ahead of the heli
        ld a,(hvx)
        rlca
        and 1
        xor 1
        call edge_x
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld b,20
        call rand_n
        add a,8
        ld l,a
        ld h,0
        call mul16
        ld (ix+O_YL),l
        ld (ix+O_YH),h
        ld a,(hvx)
        bit 7,a
        ld a,-4
        jr z,.v
        ld a,4
.v:     ld (ix+O_VX),a
        jp obj_init_hp

spawn_plane3d:
        ld a,OT_PLANE3D
        call count_type
        or a
        ret nz
        call obj_alloc
        ret c
        ld (ix+O_TYPE),OT_PLANE3D
        ld b,90
        call rand_n
        add a,12
        ld l,a
        ld h,0
        ld de,(camx)
        add hl,de
        call mul16
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        call rand
        and 1
        ld (ix+O_DIR),a
        ld hl,14*16
        jr z,.t
        ld hl,6*16
.t:     ld (ix+O_YL),l
        ld (ix+O_YH),h
        ld (ix+O_TIMER),12
        ret

spawn_crate:
        call obj_alloc
        ret c
        ld (ix+O_TYPE),OT_CRATE
        ld hl,(heli_x)
        call div16
        ld a,(hvx)
        sra a
        call sext_add
        ld de,-3
        add hl,de
        call clamp_x
        call mul16
        ld (ix+O_XL),l
        ld (ix+O_XH),h
        ld hl,-8*16
        ld (ix+O_YL),l
        ld (ix+O_YH),h
        ld (ix+O_VY),6
        ; contents: mostly fuel, sometimes armour, rarely an extra heli
        call rand
        and 15
        ld b,0
        cp 7
        jr c,.k
        inc b
        cp 12
        jr c,.k
        inc b
        cp 14
        jr c,.k
        inc b
.k:     ld (ix+O_AUX),b
        jp obj_init_hp

sext_add:       ; HL += sign-extended A
        push de
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        add hl,de
        pop de
        ret

clamp_x:        ; HL px -> 16..WORLDPX-24
        bit 7,h
        jr nz,.lo
        ld de,16
        or a
        sbc hl,de
        add hl,de
        jr c,.lo
        ld de,WORLDPX-24
        or a
        sbc hl,de
        add hl,de
        ret c
        ld hl,WORLDPX-24
        ret
.lo:    ld hl,16
        ret

; ------------------------------------------------------------------
; clock: 4:00 -> 6:00 AM
; ------------------------------------------------------------------
upd_clock:
        ld a,(end_reason)
        or a
        ret nz
        ld hl,clock_sub
        inc (hl)
        ld a,(hl)
        cp 62
        ret c
        ld (hl),0
        ld hl,clock_min
        inc (hl)
        ld a,(hl)
        cp 120
        ret c
        ld a,2
        ld (end_reason),a
        ret

; ------------------------------------------------------------------
; camera with look-ahead and shake
; ------------------------------------------------------------------
upd_camera:
        ld a,(hvx)
        call sext
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(heli_x)
        add hl,de
        ld de,-64*16
        add hl,de               ; target (1/16)
        ld de,(camx16)
        or a
        sbc hl,de
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        add hl,de
        ; clamp
        bit 7,h
        jr z,.p
        ld hl,0
.p:     ld de,CAMMAX*16
        or a
        sbc hl,de
        add hl,de
        jr c,.q
        ex de,hl
.q:     ld (camx16),hl
        call div16
        ld (camx),hl
        ld a,(shake)
        or a
        jr z,.ns
        dec a
        ld (shake),a
        and 1
        ld a,(shake)
        jr z,.sp
        srl a
        neg
        jr .sa
.sp:    srl a
.sa:    and $FF
        call sext_add
        call clamp_cam
.ns:    ld (rcx),hl
        ret
