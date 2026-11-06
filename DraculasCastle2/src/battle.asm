; ===========================================================================
;  battle.asm - turn-based battle screen
;  Scene rows 0..45: area battle backdrop (bank 3 @ BBG) + animated monster
;  (bank 1 @ $4000: frames, each MON_W x MON_H (mask,data) pairs)
;  UI rows 46..63
; ===========================================================================

BBG         equ $5C00           ; battle backdrop in bank 3 (32 x 46 = 1472)
MON_W       equ 16              ; bytes
MON_H       equ 44
MON_X       equ 8               ; byte column
MON_Y       equ 0
MON_FRAME   equ MON_W*MON_H*2   ; 1408
SCENE_H     equ 46
MONB        equ P2BASE          ; monster frames (mask,data) in main RAM

; monster def (16 bytes): dw name ; db hp, atk, def, xp, gold, flags, css, nframes ; dw gfx ; db special, 0,0,0
MF_UNDEAD   equ 1
MF_FLYING   equ 2
MF_SPIRIT   equ 4
MF_BOSS     equ 8

; ---------------------------------------------------------------------------
; battle: A = monster id -> A = 0 won, 1 fled, 2 died
; ---------------------------------------------------------------------------
battle:
            ld a,(bt_loaded)        ; a cutscene may have loaded the monster already
            or a
            ld a,(battle_boss)
            call z,battle_load
            xor a                   ; always consumed here, so the next battle loads afresh
            ld (bt_loaded),a
            jp battle_run

; load monster definition, graphics (bank 1) and backdrop (bank 3)
battle_load:
            ld (bt_mon),a
            dec a
            add a,a
            add a,a
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,monsters
            add hl,de
            ld (bt_def),hl
            push hl
            pop ix
            ld a,(ix+2)
            ld (bt_mhp),a
            ld (bt_mhpmax),a
            xor a
            ld (bt_turn),a
            ld (bt_defend),a
            ld (bt_frame),a
            ld (bt_cursor),a
            ld (bt_charge),a
            ld a,(ix+8)
            ld (bt_css),a
            ; monster frames from SD into main RAM, then build masks
            ld l,(ix+10)
            ld h,(ix+11)
            push hl
            pop ix
            ld de,MONB
            xor a
            call sd_load
            call build_masks
            ; backdrop from SD into SRAM bank 3
            ld a,(AREA_RAM+26)      ; the area's battle backdrop
            add a,a
            ld l,a
            ld h,0
            ld de,bbg_files
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            push hl
            pop ix
            ld de,BBG
            ld a,1
            call sd_load
            ld a,1
            ld (bt_loaded),a
            ret

battle_run:
            ld ix,(bt_def)
            ; music
            ld a,(bt_def)
            ld ix,(bt_def)
            ld a,(ix+7)
            and MF_BOSS
            ld a,MUS_BOSS
            jr nz,.mb
            ld a,MUS_BATTLE
.mb:        call play_music
            ; transition + draw
            call battle_wipe
            ld a,(bt_css)
            call set_css
            call draw_scene
            call draw_battle_ui
            call present_full
            ; "A ... APPEARS!"
            ld de,msgbuf
            ld hl,str_a
            call art_name_de
            ld hl,str_appears
            call strcpy_de
            call bt_message
            call bt_pause

; --- main battle loop ---
.round:     xor a
            ld (bt_defend),a
            call draw_battle_ui
            call present_ui
            call choose_command     ; A = command 0..4
            cp 0
            jp z,.attack
            cp 1
            jp z,.magic
            cp 2
            jp z,.item
            cp 3
            jp z,.defend
            ; run
            ld ix,(bt_def)
            ld a,(ix+7)
            and MF_BOSS
            jr nz,.norun
            ld b,10
            call rand_n
            cp 7
            jr nc,.runfail
            ld hl,sfx_run
            call play_sfx
            ld hl,str_escape
            call bt_msg_hl
            call bt_pause
            ld a,1
            jp battle_exit
.norun:     ld hl,str_noescape
            call bt_msg_hl
            call bt_pause
            jp .mturn
.runfail:   ld hl,str_runfail
            call bt_msg_hl
            call bt_pause
            jp .mturn

.attack:    call fx_slash
            call player_damage      ; A = damage, carry = critical
            push af
            jr nc,.nc
            ld hl,str_critical
            call bt_msg_hl
            call bt_short
.nc:        pop af
            call hurt_monster
            jp .after

.magic:     ld a,(spells)
            and 1
            jr nz,.hasfire
            ld hl,str_nospells
            call bt_msg_hl
            call bt_pause
            jp .round
.hasfire:   ld a,(mp)
            cp 4
            jr nc,.cast
            ld hl,str_nomp
            call bt_msg_hl
            call bt_pause
            jp .round
.cast:      sub 4
            ld (mp),a
            ld hl,str_fire
            call bt_msg_hl
            call fx_fire
            ; damage 14 + lvl*3 + rnd 8 ; spirits take 50% more
            ld a,(lvl)
            ld b,a
            add a,a
            add a,b
            add a,14
            ld c,a
            ld b,8
            call rand_n
            add a,c
            ld c,a
            ld ix,(bt_def)
            ld a,(ix+7)
            and MF_SPIRIT
            ld a,c
            jr z,.fd
            srl a
            add a,c
.fd:        call hurt_monster
            jp .after

.item:      call choose_item        ; A = item id or 0
            or a
            jp z,.round
            cp IT_POTION
            jr nz,.holy
            ld hl,items+IT_POTION
            dec (hl)
            ld a,(hp)
            add a,30
            jr c,.cap
            ld b,a
            ld a,(maxhp)
            cp b
            jr c,.cap2
            ld a,b
.cap2:
.cap:       ld b,a
            ld a,(maxhp)
            cp b
            jr c,.capm
            ld a,b
.capm:      ld (hp),a
            call fx_heal
            ld hl,str_potion
            call bt_msg_hl
            call draw_battle_ui_stats
            call bt_pause
            jp .mturn
.holy:      ld hl,items+IT_HOLY
            dec (hl)
            ld hl,str_holy
            call bt_msg_hl
            call fx_holy
            ld ix,(bt_def)
            ld a,(ix+7)
            and MF_UNDEAD|MF_SPIRIT
            ld a,12
            jr z,.hd
            ld a,28
.hd:        call hurt_monster
            jp .after

.defend:    ld a,1
            ld (bt_defend),a
            ld hl,str_defend
            call bt_msg_hl
            call bt_short

.after:     ld a,(bt_mhp)
            or a
            jp z,battle_won

; --- monster turn ---
.mturn:     call monster_turn
            ld a,(hp)
            or a
            jp z,battle_lost
            ld hl,bt_turn
            inc (hl)
            jp .round

; ---------------------------------------------------------------------------
monster_turn:
            ld ix,(bt_def)
            ; boss special: every third turn telegraph then dive
            ld a,(ix+7)
            and MF_BOSS
            jr z,.normal
            ld a,(bt_charge)
            or a
            jr nz,.dive
            ld a,(bt_turn)
            inc a
            ld b,3
.m3:        sub b
            jr nc,.m3
            add a,b
            jr nz,.normal
            ld a,1
            ld (bt_charge),a
            ld hl,str_wings
            call bt_msg_hl
            call bt_pause
            ret
.dive:      xor a
            ld (bt_charge),a
            ld hl,str_dive
            call bt_msg_hl
            call fx_lunge
            ld ix,(bt_def)
            ld a,(ix+3)
            add a,a                 ; double attack
            jr .dmg
.normal:    ; flying monsters sometimes flutter about instead
            ld a,(ix+7)
            and MF_FLYING
            jr z,.atk
            ld b,5
            call rand_n
            or a
            jr nz,.atk
            ld hl,str_flutter
            call bt_msg_hl
            call bt_pause
            ret
.atk:       call mon_name_msg
            ld hl,str_attacks
            call strcpy_de
            call bt_message
            call fx_lunge
            ld ix,(bt_def)
            ld a,(ix+3)
.dmg:       ; dmg = atk + rnd(atk/3+1) - def ; defend halves ; min 1
            ld c,a
            srl a
            srl a
            inc a
            ld b,a
            call rand_n
            add a,c
            ld c,a
            ld a,(def)
            ld b,a
            ld a,c
            sub b
            jr c,.one
            jr nz,.ok
.one:       ld a,1
.ok:        ld c,a
            ld a,(bt_defend)
            or a
            ld a,c
            jr z,.nd
            srl a
            jr nz,.nd
            inc a
.nd:        ld (bt_dmg),a
            ; apply
            ld b,a
            ld a,(hp)
            sub b
            jr nc,.alive
            xor a
.alive:     ld (hp),a
            call fx_player_hit
            ; message "YOU TAKE nn DAMAGE"
            ld de,msgbuf
            ld hl,str_take
            call strcpy_de
            ld a,(bt_dmg)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_damage
            call strcpy_de
            call bt_message
            call draw_battle_ui_stats
            call present_ui
            jp bt_pause

; ---------------------------------------------------------------------------
; damage to monster: A = amount (shows number, flash, updates HP)
hurt_monster:
            ld (bt_dmg),a
            ld b,a
            ld a,(bt_mhp)
            sub b
            jr nc,.ok
            xor a
.ok:        ld (bt_mhp),a
            ld hl,sfx_hit
            call play_sfx
            call fx_monster_flash
            ld de,msgbuf
            ld hl,str_hit
            call strcpy_de
            ld a,(bt_dmg)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_damage
            call strcpy_de
            call bt_message
            call draw_battle_ui_stats
            call present_ui
            jp bt_pause

; player physical damage -> A, carry = critical
player_damage:
            ld a,(atk)
            ld c,a
            ld a,(weapon)
            or a
            jr z,.w0
            ; silver dagger: +3 / silver sword: +8, both x1.5 vs undead
            cp IT_SWORD
            ld a,3
            jr nz,.wb
            ld a,8
.wb:        add a,c
            ld c,a
            ld ix,(bt_def)
            ld a,(ix+7)
            and MF_UNDEAD
            jr z,.w0
            ld a,c
            srl a
            add a,c
            ld c,a
.w0:        ld a,c
            srl a
            inc a
            ld b,a
            call rand_n
            add a,c
            ld c,a
            ld ix,(bt_def)
            ld b,(ix+4)             ; monster def
            ; spirits: physical damage halved
            ld a,(ix+7)
            and MF_SPIRIT
            ld a,c
            jr z,.ns
            srl a
.ns:        sub b
            jr c,.min
            jr nz,.crit
.min:       ld a,1
.crit:      ld c,a
            ld b,12
            call rand_n
            or a
            ld a,c
            ret nz                  ; carry clear
            add a,a
            scf
            ret

; ---------------------------------------------------------------------------
battle_won:
            call fx_death
            ld a,MUS_VICTORY
            call play_music
            ld hl,kills
            inc (hl)
            ld ix,(bt_def)
            ld a,(ix+5)
            ld l,a
            ld h,0
            ld de,(xp)
            add hl,de
            ld (xp),hl
            ld a,(ix+6)
            ld l,a
            ld h,0
            ld de,(gold)
            add hl,de
            ld (gold),hl
            ; "VICTORY! nn XP, nn GOLD"
            ld de,msgbuf
            ld hl,str_victory
            call strcpy_de
            ld a,(ix+5)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_xp
            call strcpy_de
            ld ix,(bt_def)
            ld a,(ix+6)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_goldw
            call strcpy_de
            call bt_message
            call draw_battle_ui_stats
            call present_ui
            call wait_key
            call check_levelup
            xor a
            jr battle_exit

battle_lost:
            call fx_player_dies
            ld a,MUS_DEATH
            call play_music
            ld hl,str_fallen
            call bt_msg_hl
            call wait_key
            ld a,2
battle_exit:
            push af
            ld a,(bt_mon)
            ld (bt_last),a
            ; restore exploration assets (part 2 lives in bank 1)
            call reload_part2
            ld a,(area_music)
            call play_music
            ld a,8
            ld (steps_safe),a
            pop af
            ret

reload_part2:
            ld a,(cur_area)
            call area_files_ptr
            jp reload_p2_hl

; level-up table: XP needed for levels 2..9
xp_table:   dw 10,25,45,75,110,160,220,300,390,500,630,780,950,1150,1400,9999

check_levelup:
            ld a,(lvl)
            dec a
            add a,a
            ld e,a
            ld d,0
            ld hl,xp_table
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld hl,(xp)
            or a
            sbc hl,de
            ret c
            ld hl,lvl
            inc (hl)
            ld a,(maxhp)
            add a,8
            ld (maxhp),a
            ld (hp),a
            ld a,(maxmp)
            add a,3
            ld (maxmp),a
            ld (mp),a
            ld hl,atk
            inc (hl)
            inc (hl)
            ld hl,def
            inc (hl)
            ld a,MUS_LEVELUP
            call play_music
            call fx_levelup
            ld de,msgbuf
            ld hl,str_levelup
            call strcpy_de
            ld a,(lvl)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_lvbang
            call strcpy_de
            call bt_message
            call draw_battle_ui_stats
            call present_ui
            call wait_key
            jr check_levelup

; ---------------------------------------------------------------------------
; command menu
; ---------------------------------------------------------------------------
cmd_names:  dw cn_attack,cn_magic,cn_item,cn_defend,cn_run
cn_attack:  db "ATTACK",0
cn_magic:   db "MAGIC",0
cn_item:    db "ITEM",0
cn_defend:  db "DEFEND",0
cn_run:     db "RUN",0
cmd_pos:    db 1,47, 8,47, 1,53, 8,53, 1,59    ; x (byte), y

choose_command:
            call draw_commands
            call present_ui
            ld a,20
            ld (bt_anim),a
.l:         call wait_frame
            call read_input
            call tick_time
            call idle_anim
            ld a,(keys_new)
            or a
            jr z,.l
            ld b,a
            ld a,(bt_cursor)
            bit 0,b
            jr z,.n1
            sub 2
            jr nc,.set
            add a,2
            jr .set
.n1:        bit 1,b
            jr z,.n2
            add a,2
            cp 5
            jr c,.set
            sub 2
            jr .set
.n2:        bit 2,b
            jr z,.n3
            and $FE
            jr .set
.n3:        bit 3,b
            jr z,.n4
            or 1
            cp 5
            jr c,.set
            ld a,4
            jr .set
.n4:        bit 4,b
            jr z,.l
            ld hl,sfx_select
            call play_sfx
            ld a,(bt_cursor)
            ret
.set:       ld (bt_cursor),a
            ld hl,sfx_tick
            call play_sfx
            call draw_commands
            call present_ui
            jr .l

draw_commands:
            call clear_ui
            xor a
.c:         ld (bt_tmp),a
            ld b,1
            ld c,2
            ld hl,bt_cursor
            cp (hl)
            jr nz,.ns
            ld c,3
.ns:        call text_colors
            ld a,(bt_tmp)
            add a,a
            ld e,a
            ld d,0
            ld hl,cmd_names
            add hl,de
            ld c,(hl)
            inc hl
            ld b,(hl)
            push bc
            ld hl,cmd_pos
            add hl,de
            ld c,(hl)
            inc hl
            ld d,(hl)
            pop hl
            call print_at
            ld a,(bt_tmp)
            inc a
            cp 5
            jr nz,.c
            jp draw_battle_ui_stats

; choose item: returns A = item id (0 = cancelled)
choose_item:
            ld a,(items+IT_POTION)
            or a
            jr nz,.has
            ld a,(items+IT_HOLY)
            or a
            jr nz,.has
            ld hl,str_noitems
            call bt_msg_hl
            call bt_pause
            xor a
            ret
.has:       call clear_ui
            ld b,1
            ld c,2
            call text_colors
            ld de,msgbuf
            ld hl,str_items1
            call strcpy_de
            ld a,(items+IT_POTION)
            ld l,a
            ld h,0
            call num3_left
            ld hl,msgbuf
            ld c,1
            ld d,47
            call print_at
            ld de,msgbuf
            ld hl,str_items2
            call strcpy_de
            ld a,(items+IT_HOLY)
            ld l,a
            ld h,0
            call num3_left
            ld hl,msgbuf
            ld c,1
            ld d,53
            call print_at
            ld hl,str_items3
            ld c,1
            ld d,59
            call print_at
            call present_ui
.w:         call wait_frame
            call read_input
            call idle_anim
            ld a,($68F7)            ; row 3: 4 1 3 - 2 5 (bit5..bit0)
            cpl
            bit 4,a                 ; 1
            jr nz,.k1
            bit 1,a                 ; 2
            jr nz,.k2
            ld a,(keys_new)
            and K_FIRE|K_LEFT|K_RIGHT|K_UP|K_DOWN
            jr z,.w
            xor a
            ret
.k1:        ld a,(items+IT_POTION)
            or a
            jr z,.w
            ld a,IT_POTION
            ret
.k2:        ld a,(items+IT_HOLY)
            or a
            jr z,.w
            ld a,IT_HOLY
            ret

; ---------------------------------------------------------------------------
; UI drawing
; ---------------------------------------------------------------------------
clear_ui:
            ld c,0
            ld b,32
            ld d,SCENE_H
            ld e,64-SCENE_H
            ld a,$AA
            call fill_rect
            ; red rule
            ld c,0
            ld b,32
            ld d,SCENE_H
            ld e,1
            ld a,$FF
            jp fill_rect

draw_battle_ui:
            call draw_commands
            ret

; player HP/MP on the right of the UI, monster name+bar at top of scene
draw_battle_ui_stats:
            ld c,20
            ld b,12
            ld d,47
            ld e,17
            ld a,$AA
            call fill_rect
            ld b,1
            ld c,2
            call text_colors
            ld de,statbuf
            ld a,'@'
            ld (de),a
            inc de
            ld a,(hp)
            ld l,a
            ld h,0
            call num3_left
            ld a,'/'
            ld (de),a
            inc de
            ld a,(maxhp)
            ld l,a
            ld h,0
            call num3_left
            ld hl,statbuf
            ld c,21
            ld d,47
            call print_at
            ld de,statbuf
            ld a,'%'
            ld (de),a
            inc de
            ld a,(mp)
            ld l,a
            ld h,0
            call num3_left
            ld a,'/'
            ld (de),a
            inc de
            ld a,(maxmp)
            ld l,a
            ld h,0
            call num3_left
            ld hl,statbuf
            ld c,21
            ld d,53
            call print_at
            ld de,statbuf
            ld hl,str_lvshort
            call strcpy_de
            ld a,(lvl)
            ld l,a
            ld h,0
            call num3_left
            ld hl,statbuf
            ld c,21
            ld d,59
            call print_at
            ; monster bar into scene top-left (drawn over backdrop)
            jp draw_mon_bar

draw_mon_bar:
            ld c,0
            ld b,11
            ld d,0
            ld e,8
            ld a,$AA
            call fill_rect
            ld b,1
            ld c,2
            call text_colors
            ld de,statbuf
            call mon_name_de
            ld hl,statbuf
            ld c,0
            ld d,0
            call print_at
            ; bar: 40px * mhp / mhpmax at row 6
            ld a,(bt_mhp)
            ld e,40
            call mul8
            ld a,(bt_mhpmax)
            ld c,a
            call div_hl_c
            ld b,a
            ld d,6
            ld c,0
            push bc
            call back_addr
            pop bc
.f:         ld a,b
            cp 4
            jr c,.p
            ld (hl),$FF
            inc hl
            sub 4
            ld b,a
            jr .f
.p:         or a
            ret z
            ld (hl),$C0
            dec b
            ret z
            ld (hl),$F0
            dec b
            ret z
            ld (hl),$FC
            ret

present_ui:
            ld c,0
            ld b,32
            ld d,SCENE_H
            ld e,64
            call present_rect
            ld c,0
            ld b,11
            ld d,0
            ld e,8
            jp present_rect

; message in the UI area: msgbuf / HL
bt_msg_hl:
            ld de,msgbuf
            call strcpy_de
bt_message:
            call clear_ui
            ld b,1
            ld c,2
            call text_colors
            ld hl,msgbuf
            ld c,1
            ld d,48
            call print_at
            call draw_battle_ui_stats
            jp present_ui

mon_name_msg:
            ld de,msgbuf
            ld hl,str_the
; HL = article: copied unless the monster has a proper name (def byte 14)
art_name_de:
            ld ix,(bt_def)
            bit 0,(ix+14)
            call z,strcpy_de
mon_name_de:
            ld ix,(bt_def)
            ld l,(ix+0)
            ld h,(ix+1)
            jp strcpy_de

; pause ~1 second (animating), any key skips
bt_pause:
            ld b,50
            jr bt_wait
bt_short:
            ld b,20
bt_wait:
            push bc
            call wait_frame
            call read_input
            call idle_anim
            pop bc
            ld a,(keys_new)
            or a
            ret nz
            djnz bt_wait
            ret

; ---------------------------------------------------------------------------
; scene drawing
; ---------------------------------------------------------------------------
; restore backdrop rows into BACK (bank 3)
draw_backdrop:
            call bank3
            ld hl,BBG
            ld de,BACK
            ld bc,32*SCENE_H
            ldir
            ret

draw_scene:
            call draw_backdrop
            call draw_monster
            jp draw_mon_bar

; draw monster frame bt_frame at (MON_X + bt_dx, MON_Y + bt_dy)
draw_monster:
            ld a,(bt_mhp)
            or a
            jr nz,.alive
            ld a,(bt_dying)
            or a
            ret z
.alive:     ld a,(bt_frame)
            ld hl,MONB
            ld de,MON_FRAME
            or a
            jr z,.f0
.fl:        add hl,de
            dec a
            jr nz,.fl
.f0:        ld a,(bt_dy)
            add a,MON_Y
            ld d,a
            ld a,(bt_dx)
            add a,MON_X
            ld c,a
            push hl
            call back_addr
            ex de,hl
            pop hl
            ld a,(bt_flash)
            or a
            jr nz,draw_mon_flash
            ld b,MON_H
.r:         push bc
            push de
            ld b,MON_W
.b:         ld a,(de)
            and (hl)
            inc hl
            or (hl)
            inc hl
            ld (de),a
            inc de
            djnz .b
            pop de
            ex de,hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop bc
            djnz .r
            ret

; flash: opaque pixels become colour 1 (yellow / cyan)
draw_mon_flash:
            ld b,MON_H
.r:         push bc
            push de
            ld b,MON_W
.b:         ld a,(hl)               ; mask
            cpl                     ; opaque bits
            and $55
            ld c,a
            ld a,(de)
            and (hl)
            or c
            inc hl
            inc hl
            ld (de),a
            inc de
            djnz .b
            pop de
            ex de,hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop bc
            djnz .r
            ret

; present the scene rows only
present_scene:
            ld c,0
            ld b,32
            ld d,0
            ld e,SCENE_H
            jp present_rect

present_monster:
            ld c,MON_X-2
            ld b,MON_W+4
            ld d,0
            ld e,SCENE_H
            jp present_rect

; idle animation: toggle frames 0/1 every 18 ticks
idle_anim:
            ld hl,bt_anim
            dec (hl)
            ret nz
            ld (hl),18
            ld a,(bt_mhp)
            or a
            ret z
            ld a,(bt_frame)
            xor 1
            and 1
            ld (bt_frame),a
            ; spirits bob up and down
            ld ix,(bt_def)
            ld a,(ix+7)
            and MF_SPIRIT|MF_FLYING
            jr z,.d
            ld a,(bt_frame)
            ld (bt_dy),a
.d:         call draw_backdrop
            call draw_monster
            call draw_mon_bar
            jp present_monster

; build mask planes: frames were unpacked as data planes with transparent
; colour key = the monster's key colour stored in the def (ix+12)
build_masks:
            ; frames in bank 1 at $4000 stored as data only (MON_W*MON_H each);
            ; expand backwards into (mask,data) pairs in place
            ld ix,(bt_def)
            ld a,(ix+9)             ; frames
            ld b,a
            ld hl,0
            ld de,MON_W*MON_H
.m:         add hl,de
            djnz .m                 ; hl = total data bytes
            ld (bt_tmp),hl
            ; src end = MONB + total - 1 ; dst end = MONB + 2*total - 1
            ld de,MONB-1
            add hl,de
            push hl                 ; src end
            ld hl,(bt_tmp)
            add hl,hl
            ld de,MONB-1
            add hl,de
            ex de,hl                ; de = dst end
            pop hl
            ld bc,(bt_tmp)
            ld a,(ix+12)            ; key colour 0..3
            ld (bt_key),a
.x:         push bc
            ld a,(hl)
            dec hl
            ld (de),a               ; data
            dec de
            ; mask: pixels equal to key -> 11
            ld c,a
            ld b,4
            xor a
            ld (bt_tmp+2),a
.px:        ld a,(bt_tmp+2)
            rrca
            rrca
            ld (bt_tmp+2),a
            ld a,c
            and 3
            push hl
            ld hl,bt_key
            cp (hl)
            pop hl
            jr nz,.op
            ld a,(bt_tmp+2)
            or $C0
            ld (bt_tmp+2),a
.op:        rrc c
            rrc c
            djnz .px
            ld a,(bt_tmp+2)
            ld (de),a
            dec de
            ; clear key pixels in the data byte
            inc de
            inc de
            ld a,(de)
            push af
            ld a,(bt_tmp+2)
            cpl
            ld c,a
            pop af
            and c
            ld (de),a
            dec de
            dec de
            pop bc
            dec bc
            ld a,b
            or c
            jr nz,.x
            ret

; ---------------------------------------------------------------------------
; effects
; ---------------------------------------------------------------------------
; transition from exploration: blinds closing over the screen
battle_wipe:
            ld hl,sfx_encounter
            call play_sfx
            ld b,0
.s:         push bc
            ; fill rows where (row & 7) == b with blue
            ld d,b
.r:         ld a,d
            cp 64
            jr nc,.done
            push de
            ld e,d
            inc e
            ld a,$AA
            call fill_rows
            pop de
            ld a,d
            add a,8
            ld d,a
            jr .r
.done:      call present_full_fast
            pop bc
            inc b
            ld a,b
            cp 8
            jr nz,.s
            ret

present_full_fast:
            jp present_full

; flash monster white-ish twice + shake
fx_monster_flash:
            ld b,3
.l:         push bc
            ld a,1
            ld (bt_flash),a
            ld a,1
            ld (bt_dx),a
            call redraw_mon
            xor a
            ld (bt_flash),a
            ld a,-1
            ld (bt_dx),a
            call redraw_mon
            pop bc
            djnz .l
            xor a
            ld (bt_dx),a
            jp redraw_mon

redraw_mon:
            call draw_backdrop
            call draw_monster
            call draw_fx
            call draw_mon_bar
            jp present_monster

; sword slash: diagonal streak across the monster over 4 steps
fx_slash:
            ld hl,sfx_slash
            call play_sfx
            ld b,0
.s:         push bc
            ld a,b
            ld (fx_step),a
            ld a,1
            ld (fx_kind),a
            call redraw_mon
            pop bc
            inc b
            ld a,b
            cp 5
            jr nz,.s
            xor a
            ld (fx_kind),a
            ret

; fire: fireball rises then bursts
fx_fire:
            ld hl,sfx_fire
            call play_sfx
            ld b,0
.s:         push bc
            ld a,b
            ld (fx_step),a
            ld a,2
            ld (fx_kind),a
            call redraw_mon
            pop bc
            inc b
            ld a,b
            cp 10
            jr nz,.s
            xor a
            ld (fx_kind),a
            ; screen flash via CSS toggle
            ld a,(bt_css)
            xor 1
            call set_css
            ld b,3
            call wait_frames
            ld a,(bt_css)
            call set_css
            ret

fx_holy:
            ld hl,sfx_heal
            call play_sfx
            ld b,0
.s:         push bc
            ld a,b
            ld (fx_step),a
            ld a,3
            ld (fx_kind),a
            call redraw_mon
            pop bc
            inc b
            ld a,b
            cp 8
            jr nz,.s
            xor a
            ld (fx_kind),a
            ret

fx_heal:
            ld hl,sfx_heal
            jp play_sfx

fx_levelup:
            ld b,4
.l:         push bc
            ld a,(bt_css)
            xor 1
            call set_css
            ld b,4
            call wait_frames
            ld a,(bt_css)
            call set_css
            ld b,4
            call wait_frames
            pop bc
            djnz .l
            ret

; monster lunges: grows down 2 rows and uses the attack frame
fx_lunge:
            ld hl,sfx_monatk
            call play_sfx
            ld a,2
            ld (bt_frame),a
            ld a,1
            ld (bt_dy),a
            call redraw_mon
            ld a,2
            ld (bt_dy),a
            call redraw_mon
            ld b,6
            call wait_frames
            xor a
            ld (bt_dy),a
            ld (bt_frame),a
            jp redraw_mon

; player hit: screen shake via CSS flicker + red flash on UI
fx_player_hit:
            ld hl,sfx_hurt
            call play_sfx
            ld a,(bt_css)
            xor 1
            call set_css
            ld b,2
            call wait_frames
            ld a,(bt_css)
            jp set_css

fx_player_dies:
            ld b,6
.l:         push bc
            ld a,(bt_css)
            xor 1
            call set_css
            ld b,5
            call wait_frames
            ld a,(bt_css)
            call set_css
            ld b,5
            call wait_frames
            pop bc
            djnz .l
            ret

; monster death: dissolve with random pixel erasure over 12 steps
fx_death:
            ld hl,sfx_death
            call play_sfx
            ld a,1
            ld (bt_dying),a
            ld b,12
.l:         push bc
            ; erase random bytes of mask (set to FF) in current frame
            ld b,100
.e:         push bc
            call random
            ld l,a
            call random
            and 3
            ld h,a
            add hl,hl               ; even offset (mask byte), range 0..2047
            ld a,(bt_frame)
            or a
            jr z,.f0
            ld de,MON_FRAME
            add hl,de
.f0:        ld de,MONB
            add hl,de
            ld (hl),$FF
            inc hl
            ld (hl),0
            pop bc
            djnz .e
            call redraw_mon
            pop bc
            djnz .l
            xor a
            ld (bt_dying),a
            call draw_backdrop
            call draw_mon_bar
            jp present_monster

; effect overlay drawn after the monster (fx_kind / fx_step)
draw_fx:
            ld a,(fx_kind)
            or a
            ret z
            cp 1
            jr z,fx_draw_slash
            cp 2
            jr z,fx_draw_fire
            jp fx_draw_holy

; slash: a bright diagonal band from top-right to bottom-left, growing
fx_draw_slash:
            ld a,(fx_step)
            inc a
            ld b,a
            add a,a
            add a,a
            add a,a
            add a,b                 ; rows = step*9
            cp SCENE_H-4
            jr c,.ok
            ld a,SCENE_H-4
.ok:        ld b,a
            ld d,4
.r:         push bc
            push de
            ; x byte = 22 - (row-4)/3
            ld a,d
            sub 4
            ld c,0
.dv:        sub 3
            jr c,.dd
            inc c
            jr .dv
.dd:        ld a,22
            sub c
            ld c,a
            call back_addr
            ld (hl),$55             ; bright streak (colour 1)
            inc hl
            ld (hl),$15
            pop de
            inc d
            pop bc
            djnz .r
            ret

; fire: fireball rising from the bottom to the monster, then a burst
fx_draw_fire:
            ld a,(fx_step)
            cp 6
            jr nc,.burst
            ; ball at y = 40 - step*5, x = 15..16
            ld b,a
            add a,a
            add a,a
            add a,b
            ld b,a
            ld a,40
            sub b
            ld d,a
            ld c,15
            call back_addr
            ld (hl),$5D             ; yellow/red core
            inc hl
            ld (hl),$D4
            ld de,31
            add hl,de
            ld (hl),$7F
            inc hl
            ld (hl),$FC
            ld de,31
            add hl,de
            ld (hl),$3F
            inc hl
            ld (hl),$F0
            ret
.burst:     ; ring of sparks around the monster centre
            sub 5
            ld b,a                  ; radius step 1..4
            ld hl,burst_pts
.p:         ld a,(hl)
            cp $80
            ret z
            push hl
            ld c,a
            inc hl
            ld a,(hl)
            ; y = 22 + dy*b, x = 16 + dx*b
            push bc
            ld e,a
            xor a
.m1:        add a,e
            djnz .m1
            pop bc
            add a,22
            ld d,a
            ld e,c
            push bc
            xor a
.m2:        add a,e
            djnz .m2
            pop bc
            add a,16
            ld c,a
            push bc
            call back_addr
            pop bc
            ld a,(fx_step)
            and 1
            ld a,$77
            jr z,.c1
            ld a,$DD
.c1:        ld (hl),a
            pop hl
            inc hl
            inc hl
            jr .p
burst_pts:  db 1,0, -1,0, 0,4, 0,-4, 1,3, -1,3, 1,-3, -1,-3, 2,1, -2,1, 2,-1, -2,-1, $80

; holy water: sparkles falling on the monster
fx_draw_holy:
            ld b,10
.l:         push bc
            call random
            and 15
            add a,MON_X
            ld c,a
            call random
            and 31
            add a,4
            ld d,a
            call back_addr
            ld (hl),$44
            pop bc
            djnz .l
            ret

; ---------------------------------------------------------------------------
str_a:      db "A ",0
str_the:    db "THE ",0
str_appears: db " APPEARS!",0
str_attacks: db 1,"ATTACKS!",0
str_take:   db "YOU TAKE ",0
str_hit:    db "YOU DEAL ",0
str_damage: db " DAMAGE!",0
str_critical: db "A CRITICAL STRIKE!",0
str_escape: db "YOU FLEE INTO",1,"THE DARK!",0
str_noescape: db "THERE IS NO ESCAPE!",0
str_runfail: db "YOU CAN'T GET AWAY!",0
str_nospells: db "YOU KNOW NO",1,"SPELLS... YET.",0
str_nomp:   db "NOT ENOUGH MAGIC!",0
str_fire:   db "YOU CAST FIRE!",0
str_potion: db "A POTION!",1,"+30 HP",0
str_holy:   db "HOLY WATER!",0
str_defend: db "YOU BRACE YOURSELF.",0
str_wings:  db "IT SPREADS ITS",1,"WINGS... DEFEND!",0
str_dive:   db "THE GARGOYLE DIVES!",0
str_flutter: db "IT FLUTTERS ABOUT,",1,"SQUEAKING.",0
str_victory: db "VICTORY!",1,"+",0
str_xp:     db " XP  +",0
str_goldw:  db " GOLD",0
str_levelup: db "LEVEL UP!",1,"NOW LEVEL ",0
str_lvbang: db "!",0
str_fallen: db "YOU HAVE FALLEN...",0
str_noitems: db "NO USEFUL ITEMS.",0
str_items1: db "1: POTION     X",0
str_items2: db "2: HOLY WATER X",0
str_items3: db "1/2 USE SPACE:BACK",0
str_lvshort: db "LEVEL ",0
