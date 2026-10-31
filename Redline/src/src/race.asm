; =====================================================================
;  race.asm - one stage: set-up, the frame loop, the player's car,
;  tunnels, and streaming the next track section from the SD card
; =====================================================================

; A = leg (0..4).  Section 0 of the leg must already be loaded.
; returns A = 0 out of time, 1 stage cleared
race:
        ld (leg),a
        xor a
        ld (section),a
        call section_start
        ld hl,0
        ld (pos_s),hl
        ld (camx),hl
        ld (speed),hl
        ld (dist),hl
        xor a
        ld (pos_f),a
        ld (pos_ff),a
        ld (msg_t),a
        ld (gstate),a
        ld (want_load),a
        ld (pframe_spin),a
        ld a,(leg_time)
        ld (tleft),a
        xor a
        ld (tsub),a
        ; clear traffic
        ld hl,cars
        ld b,NCARS*C_LEN
.ct:    ld (hl),0
        inc hl
        djnz .ct
        ld a,MAP_RACE
        ld (race_map),a
        out (BANKPORT),a
        call hud_init
        ld a,ST_COUNT
        ld (gstate),a
        ld a,4
        ld (cnt_n),a
        ld a,1
        ld (cnt_t),a
        ld a,MSG_READY
        call show_msg
        ld a,(fieldctr)
        ld (lastfr),a
        ld a,FPS_FIELDS
        ld (dtf),a
        xor a
        ld (facc),a
.frame: ; physics in 3-field steps: a slow frame runs extra steps, so
        ; the game keeps real-time speed whatever the frame rate
        ld a,(dtf)
        ld hl,facc
        add a,(hl)
.ps:    cp FPS_FIELDS
        jr c,.pd
        sub FPS_FIELDS
        ld (hl),a
        push hl
        call game_update
        pop hl
        ld a,(hl)
        jr .ps
.pd:    ld (hl),a
        call detail_ctl
        call upd_camera
        call upd_score
        call upd_sound
        call render
        call hud_update
        call present
        ld a,(want_load)
        or a
        call nz,next_section
        ld a,(gstate)
        cp ST_DONE
        jr z,.end
        cp ST_OVER
        jr nz,.frame
.end:   ld a,(end_t)
        or a
        jr nz,.frame
        ld a,(gstate)
        cp ST_DONE
        ld a,1
        ret z
        xor a
        ret

; adaptive detail: a frame that needed a 4th field trims the scenery
; draw distance; a run of on-time frames restores it
detail_ctl:
        ld a,(dtf)
        cp FPS_FIELDS+1
        jr c,.ok
        xor a
        ld (det_ok),a
        ld a,(det_k)
        cp 13
        ret c
        sub 4
        ld (det_k),a
        ret
.ok:    ld hl,det_ok
        inc (hl)
        ld a,(hl)
        cp 25
        ret c
        ld (hl),0
        ld a,(det_k)
        cp 22
        ret nc
        inc a
        ld (det_k),a
        ret
facc:   db 0
det_ok: db 0
det_k:  db 22

; ---------------------------------------------------------------- render
render:
        ld a,MAP_RACE
        out (BANKPORT),a
        call draw_road          ; (the road first: the panorama only fills
        call cur_flags          ;  the rows above the highest road line)
        and 1
        jr nz,.tun
        call draw_pano
        jr .rd
.tun:   ld a,(clip)
        sub PANOTOP
        jr z,.rd
        jr c,.rd
        cp HZ-PANOTOP+2
        jr c,.t0
        ld a,HZ-PANOTOP+1
.t0:    ld b,a
        ld a,(tun_col)          ; inside a tunnel the sky is the roof
        ld hl,BB
.tr:    push bc
        push hl
        push af
        call fill_row
        pop af
        pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .tr
.rd:    call draw_roof
        call build_dl
        call draw_dl
        call draw_player
        call draw_msg
        ret

cur_flags:
        ld hl,(pos_s)
        inc hl
        ld de,TRK_FLAG
        add hl,de
        ld a,(hl)
        ret

; ---------------------------------------------------------------- tunnel roof
; the roof mirrors the road about the horizon: band k spans the mirror of
; road boundaries k..k+1, coloured by the stripe, while the segment is in
; the tunnel.  Beyond the tunnel's end the panorama shows through (the
; light at the end).  Approaching a tunnel, its mouth is cut into a rock
; face (draw list entry K_PORTAL).
draw_roof:
        ld hl,(pos_s)
        ld (roofs),hl
        ld a,PANOTOP
        ld (roofy),a
        ld b,0                  ; k
.k:     push bc
        ld hl,(roofs)
        ld e,b
        ld d,0
        add hl,de
        ld de,TRK_FLAG
        add hl,de
        ld a,(hl)
        and 1
        jr z,.out               ; not tunnel: stop
        ld e,b
        ld d,0
        ld hl,prj_y+1
        add hl,de
        ld a,(hl)
        cp 255
        jr z,.fill_rest
        ld c,a
        ld a,HZ*2
        sub c                   ; mirrored row
        jr nc,.m1
        xor a
.m1:    cp HZ+1
        jr c,.m2
        ld a,HZ+1
.m2:    ld c,a                  ; band bottom (exclusive)
        ld a,(roofy)
        cp c
        jr nc,.nx
        ; colour by stripe of segment pos_s+k
        ld hl,(roofs)
        ld e,b
        ld d,0
        add hl,de
        ld a,l
        and 2
        ld a,(tun_col2)
        jr z,.c1
        ld a,(tun_col)
.c1:    ld (roofc),a
.fl:    ld a,(roofy)
        cp c
        jr nc,.nx
        push bc
        call roof_row
        pop bc
        ld hl,roofy
        inc (hl)
        jr .fl
.nx:    pop bc
        inc b
        ld a,b
        cp 30
        jr c,.k
        ret
.fill_rest:                     ; tunnel beyond the draw distance: dark
        ld a,(tun_col)
        ld (roofc),a
.fr:    ld a,(roofy)
        cp HZ+1
        jr nc,.out
        call roof_row
        ld hl,roofy
        inc (hl)
        jr .fr
.out:   pop bc
        ret

roof_row:                       ; fill row (roofy) with (roofc)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BBR0
        add hl,de
        ld a,(roofc)
        jp fill_row

; ---------------------------------------------------------------- the player's car
; frames: 5 steering angles x 2 wheel phases (+ spin frames); brake
; lights and dust are overlays.  Fixed byte-aligned position.
draw_player:
        ld a,(gstate)
        cp ST_CRASH
        jr nz,.n
        ld a,(pframe_spin)
        add a,10                ; spin frames 10..17
        jr .fr
.n:     ; steering angle: held direction builds up to the hard frames
        ld a,(steerdir)
        or a
        jr z,.c
        ld b,a
        ld a,(steerhold)
        cp 4
        jr nc,.h
        inc a
        ld (steerhold),a
.h:     ld c,1                  ; mild
        cp 3
        jr c,.m
        ld c,2                  ; hard
.m:     ld a,b
        rla
        ld a,2                  ; centre index
        jr c,.lft
        add a,c
        jr .ang
.lft:   sub c
        jr .ang
.c:     xor a
        ld (steerhold),a
        ld a,2
.ang:   ; wheel phase: speed-driven counter
        add a,a                 ; *2
        ld c,a
        ld hl,(speed)
        ld a,(wheelacc)
        add a,h
        ld (wheelacc),a
        rla
        rla
        and 1
        add a,c
.fr:    ld l,a
        ld h,0
        add hl,hl
        ld de,PCAR_TAB
        add hl,de
        ld a,MAP_FE
        out (BANKPORT),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (spr_map),a
        ld a,1
        ld (spr_masked),a
        ; bounce on rough ground / rumble strips
        ld a,61
        ld b,a
        ld a,(offroad)
        or a
        jr z,.nb
        ld a,(frames)
        and 1
        jr z,.nb
        dec b
.nb:    ld a,b
        ld (de_y),a
        ld a,64
        ld (de_clip),a
        push hl
        ld hl,64
        ld (de_x),hl
        pop hl
        call draw_frame_c
        ; brake lights / dust
        ld a,(gstate)
        or a
        ret nz
        ld a,(keys)
        and K_BRK
        jr z,.nbr
        ld hl,PCAR_TAB+40       ; brake-light overlay frame
        call ovl_frame
.nbr:   ld a,(offroad)
        or a
        ret z
        ld a,(frames)
        and 3
        add a,21                ; dust puffs 21..24
        add a,a
        ld l,a
        ld h,0
        ld de,PCAR_TAB
        add hl,de
        jp ovl_frame

; overlay frame from table entry HL (upper bank 0), drawn at the car position
ovl_frame:
        ld a,MAP_FE
        out (BANKPORT),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,h
        or l
        ret z
        ld a,MAP_FE
        ld (spr_map),a
        ld a,1
        ld (spr_masked),a
        ld hl,64
        ld (de_x),hl
        ex de,hl
        ld hl,64
        ld (de_x),hl
        ex de,hl
        jp draw_frame_c

; ---------------------------------------------------------------- sections

section_start:
        ; the section's gantry list and object list pointers, traffic, time
        ld a,MAP_RACE
        out (BANKPORT),a
        ld hl,SECHDR
        ld a,(hl)               ; start time (leg start only)
        ld (leg_time),a
        inc hl
        ld a,(hl)
        ld (traffic),a
        inc hl
        ld a,(hl)
        ld (tun_col),a
        inc hl
        ld a,(hl)
        ld (tun_col2),a
        inc hl
        ld de,solid_tab
        ld bc,16
        ldir
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sec_base_next),de
        ld a,(hl)               ; colour set
        inc hl
        ld (latchv),a
        or L_SPK0
        ld (spkoff),a
        ld (LATCH),a
        ld de,hud_fg
        ld bc,9                 ; hud_fg,hud_bg,big_fg,big_bg,msg_col,msg_shadow,gan_col1-3
        ldir
        ld de,pal_a
        ld bc,12
        ldir
        ld de,pal_t
        ld bc,12
        ldir
        ld hl,GANLIST
        ld (gan_ptr),hl
        call next_gantry
        ld hl,OBJLIST
        ld (obj_ptr),hl
        jp build_strips

; at a section gantry: show the banner, load the next section, re-base
next_section:
        xor a
        ld (want_load),a
        call load_banner
        ld a,(section)
        inc a
        ld (section),a
        call sec_name
        ld hl,fname
        call load_dat
        jr c,.miss
        ; re-base: the new section starts at the gantry segment
        ld hl,(pos_s)
        ld de,(sec_base_next)
        or a
        sbc hl,de
        ld (pos_s),hl
        ; cars keep their places relative to the camera
        ld ix,cars
        ld b,NCARS
.c:     ld l,(ix+C_SL)
        ld h,(ix+C_SH)
        or a
        sbc hl,de
        ld (ix+C_SL),l
        ld (ix+C_SH),h
        push de
        ld de,C_LEN
        add ix,de
        pop de
        djnz .c
        call section_start
        call hud_init
        ret
.miss:  ; no more sections (or missing file): treat as the finish
        ld a,ST_DONE
        ld (gstate),a
        ld a,40
        ld (end_t),a
        ret

; file name for (leg),(section): "RL" leg-digit section-letter
sec_name:
        ld a,(leg)
        add a,'1'
        ld (fname+3),a
        ld a,(section)
        add a,'A'
        ld (fname+4),a
        ret
fname:  db '"RL1A"',0
