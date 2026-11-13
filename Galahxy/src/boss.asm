; =====================================================================
;  boss.asm - shared stage machinery (GLXCOM.DAT, upper bank 1):
;  the ground-segment sequencer, the scripted midboss / boss engine,
;  and a few extra enemy behaviours every stage can use.
; =====================================================================

; ---------------------------------------------------------------------
; ground segments. STG_SEGTAB -> entries of 7 bytes:
;   dw map, dw columns, dw timeline column to sync to ($FFFF none), db flag
; ---------------------------------------------------------------------
SG_NEXT     equ 0               ; play once, move on
SG_MID      equ 1               ; repeat until the midboss is gone
SG_LOOP     equ 2               ; repeat for ever (under the boss)
SG_ROUTE    equ 3               ; high = this entry, low = the next one
seg_next:
            ld hl,(seg_p)
.again:     push hl
            pop iy
            ld a,(iy+6)
            cp SG_MID
            jr nz,.n1
            ld a,(mid_done)
            or a
            jr z,.use               ; (stay on this entry)
            ld de,7
            add hl,de
            jr .again
.n1:        cp SG_LOOP
            jr z,.use
            cp SG_ROUTE
            jr nz,.n3
            ld a,(p_y)              ; the fork: high = route 0, low = route 1
            cp 30+YOFF
            ld a,0
            jr c,.r0
            inc a
            ld de,7
            add hl,de
            push hl
            pop iy
.r0:        ld (route),a
            push hl
            ld a,SFX_SECRET
            call sfx
            pop hl
            ld a,(route)
            or a
            ld de,14
            jr z,.adv
            ld de,7
            jr .adv
.n3:        ld de,7
.adv:       add hl,de
            ld (seg_p),hl
.use:       ld l,(iy+0)
            ld h,(iy+1)
            ld (gm_p),hl
            ld l,(iy+2)
            ld h,(iy+3)
            ld (gm_left),hl
            ld l,(iy+4)
            ld h,(iy+5)
            ld a,h
            and l
            inc a
            ret z                   ; ($FFFF: leave the timeline alone)
            ld (tl_col),hl
            ret

; common stage set-up: A = latch (palette), HL = timeline, DE = tune
stg_setup:
            ld (latchv),a
            ld (tl_p),hl
            ld (stage_tune),de
            ld hl,(STG_SEGTAB)
            ld (seg_p),hl
            xor a
            ld (mid_done),a
            ld (route),a
            ld (stg_cnt),a
            ld a,SPR_CLOUD
            ld (cloud_spr),a
            ex de,hl
            jp music

; HL = message (db column, text, 0), A = frames
stg_msg:
            ld (msg_p),hl
            ld (msg_t),a
            ret

; spawn type A at B,C keeping IX; the new object comes back in IY (C = none)
spawn_keep:
            push ix
            call spawn_obj
            push ix
            pop iy
            pop ix
            ret

; A coins scattered around B,C
coin_burst:
            push ix
.l:         push af
            push bc
            call random
            and 15
            add a,b
            ld b,a
            call random
            and 7
            sub 4
            add a,c
            ld c,a
            ld a,T_COIN
            call spawn_obj
            pop bc
            pop af
            dec a
            jr nz,.l
            pop ix
            ret

; ---------------------------------------------------------------------
; the scripted boss. A definition (STG_MIDDEF / STG_BOSSDEF) is:
; ---------------------------------------------------------------------
BD_TYPE     equ 0               ; object type
BD_HP       equ 1
BD_X0       equ 2               ; where it appears (stored coordinates)
BD_Y0       equ 3
BD_XH       equ 4               ; where it settles
BD_YH       equ 5
BD_ENTRY    equ 6               ; 0 stomps in from the right, 1 drops in, 2 glides in
BD_MDX      equ 7               ; the mouth (shots come from here)
BD_MDY      equ 8
BD_YMIN     equ 9               ; limits when it follows the player
BD_YMAX     equ 10
BD_ANIM     equ 11              ; 0, or a frame mask: two-frame idle animation
BD_HELLO    equ 12              ; dw greeting (0 none): frame 1 while it speaks
BD_WARN     equ 14              ; dw warning message
BD_DEAD     equ 16              ; dw message when beaten
BD_TUNE     equ 18              ; dw fight tune
BD_SCORE    equ 20              ; BCD thousands
BD_COINS    equ 21
BD_THR1     equ 22              ; below this many hit points: phase 2
BD_THR2     equ 23              ; below this: phase 3
BD_PH       equ 24              ; dw phase 1, 2, 3
; a phase: db movement, db cycle length, then events (db time, action, args) ... db $FF
BM_BOB1     equ 1               ; gentle bob
BM_BOB2     equ 2               ; wide bob
BM_BOB3     equ 3               ; very wide bob
BM_FAST     equ 4               ; twice the bob speed
A_FRAME     equ 1               ; db frame
A_SFX       equ 2               ; db effect
A_TELL      equ 3               ; db frames of flashing (the tell)
A_LOB       equ 4               ; db type, vx, vy (1/16 px a frame): lobbed from the mouth
A_FAN       equ 5               ; db count (1 or 3), spread: aimed shots
A_ARM       equ 6               ; db type: an arm shoots out
A_RAIN      equ 7               ; db type: something falls from the top of the screen
A_SPAWN     equ 8               ; db type, dy: a helper appears beside it
A_TRACK     equ 9               ; db frames spent lining up with the player
A_CALL      equ 10              ; dw routine (IX = the boss)
bs_argn:    db 0, 1, 1, 1, 3, 2, 1, 1, 2, 1, 2

mid_start:  xor a
            ld hl,(STG_MIDDEF)
            jr bs_start
boss_start: ld a,1
            ld hl,(STG_BOSSDEF)
bs_start:   ld (bs_kind),a
            ld (bs_def),hl
            inc a
            ld (stg_phase),a        ; PH_MID / PH_BOSS
            push hl
            ld hl,0
            call music
            pop iy
            ld a,(iy+BD_MDX)
            ld (bs_mdx),a
            ld a,(iy+BD_MDY)
            ld (bs_mdy),a
            xor a
            ld (bs_armt),a
            ld b,(iy+BD_X0)
            ld c,(iy+BD_Y0)
            ld a,(iy+BD_TYPE)
            push af
            push bc
            call spawn_obj
            pop bc
            jr nc,.ok
            pop af
            push af
            xor a                   ; no room: the oldest object makes way
            ld (objs+O_T),a
            pop af
            push af
            call spawn_obj
.ok:        pop af
            ld a,(ix+O_SPR)
            ld (bs_spr),a
            ld (ix+O_P),0
            ld a,SFX_CREAK
            jp sfx

; IX took C damage
boss_hit:
            ld a,(ix+O_P)
            or a
            jr z,arm_hit
            ld a,(boss_hp)
            sub c
            jr nc,.ok
            xor a
.ok:        ld (boss_hp),a
            ld a,1
            ld (bbar_dirty),a
            ld a,(boss_hp)
            or a
            ld a,SFX_KNOCK
            jp nz,sfx
            ld (ix+O_P),0
            ld (ix+O_ST),9
            ld (ix+O_TM),0
            ld hl,0
            call music
            ld a,SFX_BIG
            jp sfx
arm_hit:    res F_FLASH,(ix+O_FL)   ; clink: can't be hurt
            ld a,SFX_KNOCK
            jp sfx

boss_bar_on:
            ld (boss_hp),a
            ld (boss_max),a
            xor a
            ld (boss_hp+1),a
            ld (boss_max+1),a
            inc a
            ld (boss_bar),a
            ld (hud_dirty),a
            ret

; B,C = the mouth
bs_mouth:   ld a,(bs_mdx)
            add a,(ix+O_X)
            ld b,a
            ld a,(bs_mdy)
            add a,(ix+O_Y)
            ld c,a
            ret

beh_boss:
            ld iy,(bs_def)
            ld a,(ix+O_ST)
            cp 9
            jp z,bs_die
            inc (ix+O_TM)
            or a
            jp nz,.here
            ; ---- the entrance
            ld a,(iy+BD_ENTRY)
            or a
            jr nz,.e1
            ld a,(ix+O_TM)          ; stomping in: 4 px every 8 frames
            and 7
            ret nz
            ld a,SFX_KNOCK
            call sfx
            ld a,(ix+O_X)
            sub 4
            ld (ix+O_X),a
            ld a,(ix+O_Y)
            xor 1
            ld (ix+O_Y),a
            ld a,(iy+BD_XH)
            cp (ix+O_X)
            ret c
            jr .arrive
.e1:        dec a
            jr nz,.e2
            bit 0,(ix+O_TM)         ; dropping in
            ret nz
            inc (ix+O_Y)
            ld a,(ix+O_Y)
            cp (iy+BD_YH)
            ret c
            jr .arrive
.e2:        dec (ix+O_X)            ; gliding in
            ld a,(iy+BD_XH)
            cp (ix+O_X)
            ret c
.arrive:    ld (ix+O_ST),1
            ld (ix+O_TM),0
            ld a,(iy+BD_YH)
            ld (ix+O_Y),a
            ld (boss_base),a
            ld a,(iy+BD_HELLO)
            or (iy+BD_HELLO+1)
            ret z
            inc (ix+O_SPR)
            ld a,SFX_HONK
            call sfx
            ld l,(iy+BD_HELLO)
            ld h,(iy+BD_HELLO+1)
            ld a,60
            jp stg_msg
.here:      dec a
            jp nz,.fight
            ; ---- "hello", then the warning, then the fight
            ld a,(iy+BD_HELLO)
            or (iy+BD_HELLO+1)
            ld a,(ix+O_TM)
            jr nz,.polite
            add a,62                ; no greeting: straight to the warning
.polite:    cp 30
            jr nz,.h1
            ld a,(bs_spr)
            ld (ix+O_SPR),a
            ret
.h1:        cp 64
            jr nz,.h2
            ld a,(iy+BD_HELLO)
            or (iy+BD_HELLO+1)
            jr z,.nw
            ld a,(bs_spr)
            add a,2
            ld (ix+O_SPR),a
.nw:        ld a,SFX_WARN
            call sfx
            ld l,(iy+BD_WARN)
            ld h,(iy+BD_WARN+1)
            ld a,70
            jp stg_msg
.h2:        cp 120
            ret c
            ld (ix+O_ST),2
            ld (ix+O_P),1
            ld (ix+O_TM),0
            ld a,(bs_spr)
            ld (ix+O_SPR),a
            ld a,$FF
            ld (bs_phase),a
            ld a,(iy+BD_HP)
            call boss_bar_on
            ld l,(iy+BD_TUNE)
            ld h,(iy+BD_TUNE+1)
            jp music
.fight:     ; ---- which phase?
            ld a,(boss_hp)
            ld c,0
            cp (iy+BD_THR1)
            jr nc,.p
            inc c
            cp (iy+BD_THR2)
            jr nc,.p
            inc c
.p:         ld a,(bs_phase)
            cp c
            jr z,.same
            ld a,c
            ld (bs_phase),a
            add a,a
            add a,BD_PH
            ld e,a
            ld d,0
            push iy
            pop hl
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld (bs_php),hl
            xor a
            ld (ix+O_TM),a
            ld (bs_track),a
            ld a,20
            ld (bs_tell),a
            ld a,(bs_spr)
            ld (ix+O_SPR),a
            ld a,c
            or a
            ld a,SFX_CREAK
            call nz,sfx
.same:      ld hl,(bs_php)
            ld c,(hl)               ; movement
            inc hl
            ld a,(ix+O_TM)
            cp (hl)
            jr c,.cy
            ld (ix+O_TM),0
.cy:        inc hl
            push hl                 ; -> events
            ; idle animation
            ld a,(iy+BD_ANIM)
            or a
            jr z,.na
            ld b,a
            and (ix+O_TM)
            jr nz,.na
            ld a,(ix+O_TM)
            inc b
            and b
            ld a,(bs_spr)
            jr z,.a0
            inc a
.a0:        ld (ix+O_SPR),a
.na:        ; the tell: flash
            ld a,(bs_tell)
            or a
            jr z,.nt
            dec a
            ld (bs_tell),a
            bit 1,a
            jr z,.nt
            set F_FLASH,(ix+O_FL)
.nt:        ; lining up with the player, or bobbing
            ld a,(bs_track)
            or a
            jr z,.bob
            dec a
            ld (bs_track),a
            rra
            jr c,.sety
            ld a,(p_y)
            sub (iy+BD_MDY)
            jr nc,.t0
            xor a
.t0:        cp (iy+BD_YMIN)
            jr nc,.t1
            ld a,(iy+BD_YMIN)
.t1:        cp (iy+BD_YMAX)
            jr c,.t2
            ld a,(iy+BD_YMAX)
.t2:        ld hl,boss_base
            cp (hl)
            jr z,.sety
            jr c,.tu
            inc (hl)
            jr .sety
.tu:        dec (hl)
.sety:      ld a,(boss_base)
            ld (ix+O_Y),a
            jr .events
.bob:       ld a,c
            and 3
            jr z,.events
            ld b,a
            ld a,(ix+O_TM)
            bit 2,c
            jr z,.b1
            add a,a
.b1:        and 63
            ld e,a
            ld d,0
            ld hl,sine16
            add hl,de
            ld a,(hl)               ; -16..16
            ld e,a
            ld a,b
            cp 3
            ld a,e
            jr z,.b3
            sra a
            dec b
            dec b
            jr z,.b3
            sra a
.b3:        ld hl,boss_base
            add a,(hl)
            ld (ix+O_Y),a
.events:    pop de
.ev:        ld a,(de)
            cp $FF
            ret z
            inc de
            ld c,a                  ; time
            ld a,(de)               ; action
            inc de
            ld l,a
            ld h,0
            push hl
            ld a,c
            cp (ix+O_TM)
            jr nz,.skip
            push de
            ld a,l
            ex de,hl                ; HL -> arguments
            call bs_act
            pop de
.skip:      pop hl
            ld bc,bs_argn
            add hl,bc
            ld a,(hl)
            add a,e
            ld e,a
            jr nc,.ev
            inc d
            jr .ev

; action A, HL -> arguments, IX = the boss
bs_act:
            dec a
            jr nz,.a2
            ld a,(bs_spr)           ; FRAME
            add a,(hl)
            ld (ix+O_SPR),a
            ret
.a2:        dec a
            jr nz,.a3
            ld a,(hl)               ; SFX
            jp sfx
.a3:        dec a
            jr nz,.a4
            ld a,(hl)               ; TELL
            ld (bs_tell),a
            ret
.a4:        dec a
            jr nz,.a5
            push hl                 ; LOB
            call bs_mouth
            pop hl
            ld a,(hl)
            push hl
            call spawn_keep
            pop hl
            ret c
            inc hl
            ld a,(hl)
            call .v16
            ld (iy+O_VX),e
            ld (iy+O_VX+1),d
            inc hl
            ld a,(hl)
            call .v16
            ld (iy+O_VY),e
            ld (iy+O_VY+1),d
            ld (iy+O_ST),1          ; (velocity already set)
            ret
.v16:       ld e,a                  ; signed A * 16 -> DE (8.8)
            rla
            sbc a,a
            ld d,a
            ex de,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ex de,hl
            ret
.a5:        dec a
            jr nz,.a6
            ld a,(hl)               ; FAN
            inc hl
            ld e,(hl)
            push af
            push de
            call bs_mouth
            push bc
            call fire_at
            pop bc
            pop de
            pop af
            cp 3
            ret c
            push bc
            push de
            ld a,c
            sub e
            ld c,a
            call fire_at
            pop de
            pop bc
            ld a,c
            add a,e
            ld c,a
            jp fire_at
.a6:        dec a
            jr nz,.a7
            ld a,(hl)               ; ARM
            ld (bs_armt),a
            push af
            call bs_mouth
            ld a,b
            sub 10
            ld b,a
            pop af
            jp spawn_keep
.a7:        dec a
            jr nz,.a8
            push hl                 ; RAIN
            call random
            and 63
            add a,20+XOFF
            ld b,a
            ld c,PF_TOP+YOFF
            pop hl
            ld a,(hl)
            call spawn_keep
            ret c
            ld (iy+O_VX),-$30
            ld (iy+O_VX+1),$FF
            ld (iy+O_ST),1
            ret
.a8:        dec a
            jr nz,.a9
            ld a,(ix+O_X)           ; SPAWN
            sub 6
            ld b,a
            inc hl
            ld a,(hl)
            dec hl
            add a,(ix+O_Y)
            ld c,a
            ld a,(hl)
            jp spawn_keep
.a9:        dec a
            jr nz,.a10
            ld a,(hl)               ; TRACK
            ld (bs_track),a
            ret
.a10:       ld a,(hl)               ; CALL
            inc hl
            ld h,(hl)
            ld l,a
            jp (hl)

; blowing up: explosions for a while, then the pay-out
bs_die:
            inc (ix+O_TM)
            ld a,(ix+O_TM)
            and 3
            jr nz,.nb
            call random
            and 15
            add a,(ix+O_X)
            add a,2
            ld b,a
            call random
            and 7
            add a,(ix+O_Y)
            ld c,a
            ld a,T_BOOM
            call spawn_keep
            ld a,(ix+O_TM)
            and 15
            ld a,SFX_KILL
            call z,sfx
.nb:        bit 2,(ix+O_TM)
            jr z,.nf
            set F_FLASH,(ix+O_FL)
.nf:        ld a,(bs_kind)
            or a
            ld a,60
            jr z,.t
            ld a,90
.t:         cp (ix+O_TM)
            ret nc
            ld iy,(bs_def)
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld (ix+O_T),0
            ld a,(iy+BD_COINS)
            call coin_burst
            ld d,(iy+BD_SCORE)
            ld e,0
            push iy
            call add_score
            pop iy
            ; any arms go with it
            ld a,(bs_armt)
            or a
            jr z,.na
            ld c,a
            ld hl,objs
            ld de,OSZ
            ld b,NOBJ
.ar:        ld a,(hl)
            cp c
            jr nz,.an
            ld (hl),0
.an:        add hl,de
            djnz .ar
.na:        xor a
            ld (boss_bar),a
            inc a
            ld (hud_dirty),a
            ld l,(iy+BD_DEAD)
            ld h,(iy+BD_DEAD+1)
            ld a,100
            call stg_msg
            ld a,(bs_kind)
            or a
            jr nz,.boss
            ld (tl_hold),a
            ld (stg_phase),a
            inc a
            ld (mid_done),a
            ld hl,(stage_tune)
            jp music
.boss:      ld a,PH_CLEAR
            ld (stg_phase),a
            ld a,150
            ld (clear_t),a
            call clear_ebul
            ld hl,tune_clear
            jp music

; ---------------------------------------------------------------------
; extra behaviours
; ---------------------------------------------------------------------
; an arm: param 0 shoots out to the left and snaps back;
; param 1 comes down from the top over the player (slowly at first: the tell)
beh_arm:
            ld a,(ix+O_TM)
            inc (ix+O_TM)
            or a
            jr nz,.go
            ld a,(ix+O_X)
            ld (ix+O_VX),a          ; remember where it started
            ld a,(ix+O_P)
            or a
            ret z
            ld a,(p_x)
            ld (ix+O_X),a
            ld (ix+O_Y),PF_TOP+YOFF-10
            ret
.go:        ld a,(ix+O_P)
            or a
            jr nz,.down
            ld a,(ix+O_ST)
            or a
            jr nz,.back
            ld a,(ix+O_X)
            sub 3
            ld (ix+O_X),a
            cp 8+XOFF
            ret nc
            ld (ix+O_ST),1
            ld a,SFX_KNOCK
            jp sfx
.back:      ld a,(ix+O_X)
            add a,4
            ld (ix+O_X),a
            cp (ix+O_VX)
            ret c
            ld (ix+O_T),0
            ret
.down:      ld a,(ix+O_ST)
            or a
            jr nz,.up
            ld a,(ix+O_TM)
            cp 18
            ld a,1
            jr c,.d1
            ld a,4
.d1:        add a,(ix+O_Y)
            ld (ix+O_Y),a
            cp 36+YOFF
            ret c
            ld (ix+O_ST),1
            ld a,SFX_KNOCK
            jp sfx
.up:        ld a,(ix+O_Y)
            sub 3
            ld (ix+O_Y),a
            cp PF_TOP+YOFF-8
            ret nc
            ld (ix+O_T),0
            ret

; floats upward, drifting left (bubbles, steam, jellyfish): param = speed
beh_rise:
            ld a,(ix+O_ST)
            or a
            jr nz,.mv
            inc (ix+O_ST)
            ld a,(ix+O_P)
            neg
            ld l,a
            ld h,$FF
            add hl,hl
            add hl,hl
            add hl,hl
            ld (ix+O_VY),l
            ld (ix+O_VY+1),h
            ld (ix+O_VX),-$50
            ld (ix+O_VX+1),$FF
.mv:        jp obj_move

; walks left along the ground, a little faster than the scroll
beh_walk:
            ld a,(frames)
            and 1
            ret nz
            dec (ix+O_X)
            ret

; a ground gun that aims at the player: param = frames between shots
beh_turret:
            inc (ix+O_TM)
            ld a,(ix+O_TM)
            cp (ix+O_P)
            ret c
            ld (ix+O_TM),0
            ld a,(ix+O_X)
            cp 126+XOFF
            ret nc
            cp 24+XOFF
            ret c
            ld b,a
            ld c,(ix+O_Y)
            dec c
            jp fire_at

; HL = string: the bottom bar (VRAM rows 56-63) in red with it centred
bar_msg:
            push hl
            ld hl,VRAM+BAR_ROW*32
            ld de,VRAM+BAR_ROW*32+1
            ld bc,255
            ld (hl),$FF
            ldir
            ld a,1
            ld c,3
            call text_col
            pop hl
            call strlen
            ld b,a
            ld a,32
            sub b
            srl a
            ld e,a
            ld d,0
            push hl
            ld hl,VRAM+(BAR_ROW+2)*32
            add hl,de
            ex de,hl
            pop hl
            jp print
