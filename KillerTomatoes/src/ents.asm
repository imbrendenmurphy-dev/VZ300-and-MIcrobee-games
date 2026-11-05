; =====================================================================
;  ents.asm - tomatoes, shots, seeds, bosses, sprite selection, demo bot
; =====================================================================

; type info: speed, whacks, points BCD hi, lo, catch time
type_tab:
        db $70,2,$01,$00,200    ; cherry
        db $94,3,$02,$00,150    ; roma
        db $50,4,$03,$00,250    ; beefsteak
        db $68,2,$02,$50,200    ; unripe
        db $A8,1,$20,$00,200    ; golden
        db $80,2,$03,$00,180    ; hopper
        db $58,3,$02,$50,220    ; rotten
        db $B4,2,$03,$50,180    ; cannonball
type_info:                      ; A = type -> HL
        sub T_CHERRY
        ld l,a
        add a,a
        add a,a
        add a,l
        ld hl,type_tab
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; =====================================================================
update_enemies:
        ld ix,ents+ESIZE
        ld b,11
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        ld a,(ix+E_FLASH)
        or a
        jr z,$+5
        dec (ix+E_FLASH)
        inc (ix+E_ANIM)
        ld a,(ix+E_TYPE)
        cp T_SHOT
        jr z,.sh
        cp T_SEED
        jr z,.sd
        cp T_BOSS
        jr z,.bs
        call tomato_update
        jr .n
.sh:    call shot_update
        jr .n
.sd:    call seed_update
        jr .n
.bs:    call boss_update
.n:     ld de,ESIZE
        add ix,de
        pop bc
        djnz .l
        ; stink cloud timer
        ld a,(stink_t)
        or a
        ret z
        dec a
        ld (stink_t),a
        ret nz
        ld a,(stink_cell)
        jp clear_tile

; ---------------------------------------------------------------------
tomato_update:
        ld a,(ix+E_STATE)
        cp S_SPAWN
        jr nz,.n1
        dec (ix+E_TIMER)
        ret nz
        ld (ix+E_STATE),S_WALK
        ret
.n1:    cp S_SQUASH
        jr nz,.n2
        dec (ix+E_TIMER)
        ret nz
        ld (ix+E_TYPE),T_NONE
        ret
.n2:    cp S_CAUGHT
        jr nz,.n3
        dec (ix+E_TIMER)
        ret nz
        ; escaped!
        ld (ix+E_STATE),S_WALK
        call ent_cell
        push af
        call clear_tile
        pop af
        ld hl,traps
        dec (hl)
        ld hl,sfx_trample
        jp play_sfx
.n3:    cp S_STUN
        jr nz,.walk
        dec (ix+E_TIMER)
        ret nz
        ld (ix+E_STATE),S_WALK
        ret
.walk:  ; bonus-round sleepers wake when player near
        ld a,(ix+E_AUX2)
        or a
        jr z,.awake
        call ent_cell
        call dist_player
        cp 4
        jp nc,.coll
        ld (ix+E_AUX2),0
.awake: ; per-type timers
        ld a,(frame_cnt)
        and 31
        jr nz,.nt
        inc (ix+E_AUX)
        ld a,(ix+E_TYPE)
        cp T_UNRIPE
        jr nz,.ng
        ld a,(ix+E_AUX)
        cp 24
        jr c,.nt
        call ripen
        jr .nt
.ng:    cp T_GOLD
        jr nz,.nt
        ld a,(ix+E_AUX)
        cp 40
        jr c,.nt
        ; golden tomato leaves
        ld (ix+E_STATE),S_SQUASH
        ld (ix+E_TIMER),8
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        ld d,6
        ld e,1
        push ix
        call spawn_burst
        pop ix
        ret
.nt:    ; speed
        ld a,(ix+E_TYPE)
        call type_info
        ld a,(hl)
        ld c,a
        ld a,(hurry)
        or a
        jr z,$+6
        ld a,c
        add a,$20
        ld c,a
        ld a,(lap)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        jr nc,$+4
        ld a,$F0
        ld c,a
        ld a,(diff)
        or a
        jr nz,.d1
        ld a,c
        sub $18
        ld c,a
        jr .d2
.d1:    cp 2
        jr nz,.d2
        ld a,c
        add a,$14
        jr nc,$+4
        ld a,$F8
        ld c,a
.d2:    call is_scared
        jr nc,.ns
        srl c
        ld a,c
        add a,$18
        ld c,a
.ns:    ld a,c
        call conv_adjust
        add a,(ix+E_ACC)
        ld (ix+E_ACC),a
        jr nc,.coll
        ; step
        ld a,(ix+E_PROG)
        or a
        jr nz,.go
        call tom_think
        ld a,(ix+E_DIR)
        cp $FF
        jr z,.coll
.go:    call ent_advance
        call c,tom_arrive
.coll:  ; collision with player
        ld a,(ix+E_STATE)
        or a
        ret nz
        ld a,(dying)
        or a
        ret nz
        call touch_player
        ret nc
        call is_scared
        jr c,.eat
        ld a,(ix+E_TYPE)
        cp T_GOLD
        jr z,.eat
        jp kill_player
.eat:   call squash_ent
        ret

; is_scared: carry if this tomato is fleeing (record / bonus)
is_scared:
        ld a,(kind)
        cp 2
        jr z,.y
        ld a,(pw_record)
        or a
        ret z
.y:     scf
        ret

; touch_player: carry if IX overlaps player (lenient box)
touch_player:
        ld a,(ents+E_X)
        sub (ix+E_X)
        jr nc,$+4
        neg
        cp 6
        ret nc
        ld a,(ents+E_Y)
        sub (ix+E_Y)
        jr nc,$+4
        neg
        cp 4
        ret

ripen:
        ld (ix+E_TYPE),T_CHERRY
        ld (ix+E_FLASH),10
        ld a,(tick_t)
        or a
        ret nz
        ld a,M_RIPE
        jp ticker

; ---------------------------------------------------------------------
;  choose direction at a cell centre
; ---------------------------------------------------------------------
tom_think:
        ld a,(ix+E_TYPE)
        cp T_BALL
        jr nz,.nb
        ; cannonball: keep rolling until blocked
        ld a,(ix+E_DIR)
        cp $FF
        jr z,.nb
        ld b,a
        call ent_cell
        call open_dir
        ret z
.nb:    ; mode: 0 random, 1 chase, 2 flee
        ld c,0
        call is_scared
        jr nc,.m1
        ld c,2
        jr .md
.m1:    ld a,(ix+E_TYPE)
        cp T_GOLD
        jr nz,.m2
        ld c,2
        jr .md
.m2:    ld a,(pw_disg)
        or a
        jr nz,.md
        ld a,(ix+E_TYPE)
        cp T_ROMA
        jr z,.ch
        ld a,(hurry)
        or a
        jr nz,.ch50
        ld a,(ix+E_TYPE)
        cp T_BEEF
        jr z,.md
        call rand
        cp 80
        jr nc,.md
        jr .ch
.ch50:  call rand
        rla
        jr nc,.md
.ch:    ld c,1
        call rand
        cp 30
        jr nc,.md
        ld c,0                  ; occasional randomness so they don't lock up
.md:    ld a,c
        cp 2
        jr z,.md2
        call bait_near          ; armed trap within 2 cells? -> mode 3 (seek it)
        jr nc,.md2
        ld c,3
.md2:   ld a,c
        ld (tmp+1),a
        ; evaluate the 4 directions starting at a random one
        ld a,$FF
        ld (best),a
        ld a,c
        cp 2
        ld a,0
        jr z,$+4
        ld a,$FF
        ld (bestd),a            ; flee: maximise (start 0); chase/random: minimise (start 255)
        ld a,4
        call rand_n
        ld (tmp+2),a
        ld b,4
.dl:    push bc
        ld a,(tmp+2)
        inc a
        and 3
        ld (tmp+2),a
        ld b,a
        ; don't reverse
        ld a,(ix+E_DIR)
        xor 1
        cp b
        jr z,.skip
        call ent_cell
        ld (tmp+3),a
        push bc
        call open_dir
        pop bc
        jr nz,.skip
        ld c,a                  ; candidate cell
        ; hopper avoids armed traps (75%, and never once the tomatoes are enraged)
        ld a,(ix+E_TYPE)
        cp T_HOP
        jr nz,.nh
        ld a,(hurry)
        or a
        jr nz,.nh
        call rand
        cp 64
        jr c,.nh
        ld a,c
        call tile_get
        cp TL_TRAP3
        jr z,.skip
.nh:    ld a,(tmp+1)
        or a
        jr nz,.sc
        call rand
        and $3F
        jr .cmp
.sc:    cp 3
        jr z,.bt
        ld a,c
        call dist_player
        jr .cmp
.bt:    ld a,(bait_cell)
        call cell_dist
.cmp:   ld e,a
        ld a,(tmp+1)
        cp 2
        ld a,(bestd)
        jr z,.fl
        cp e
        jr c,.skip
        jr z,.skip
        jr .take
.fl:    cp e
        jr nc,.skip
.take:  ld a,e
        ld (bestd),a
        ld a,b
        ld (best),a
.skip:  pop bc
        djnz .dl
        ld a,(best)
        cp $FF
        jr nz,.set
        ; dead end: reverse if possible
        ld a,(ix+E_DIR)
        cp $FF
        jr z,.set
        xor 1
        ld b,a
        push af
        call ent_cell
        call open_dir
        pop bc
        ld a,b
        jr z,.set
        ld a,$FF
.set:   ld (ix+E_DIR),a
        ret

; bait_near: carry if an armed trap is within 2 cells (sets bait_cell)
bait_near:
        ld a,(ix+E_TYPE)
        cp T_HOP
        jr z,.no
        cp T_UNRIPE
        jr z,.no
        ld a,(narmed)
        or a
        jr z,.no
        ld b,a
        call rand
        cp 150
        jr nc,.no
        call ent_cell
        ld c,a
        ld hl,armed
.l:     ld a,(hl)
        inc hl
        push hl
        push af
        call cell_dist
        pop hl                  ; H = trap cell
        cp 3
        ld a,h
        pop hl
        jr nc,.n
        ld (bait_cell),a
        scf
        ret
.n:     djnz .l
.no:    or a
        ret

; scan_armed: incremental scan of 22 cells per frame; list published every 8 frames
scan_armed:
        ld a,(scan_pos)
        or a
        jr nz,.go
        xor a
        ld (scan_n),a
.go:    ld a,(scan_pos)
        ld c,a
        ld hl,tilemap
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld b,22
.l:     ld a,(hl)
        bit 7,a
        jr nz,.n
        and $3F
        cp TL_TRAP3
        jr nz,.n
        ld a,(scan_n)
        cp 8
        jr nc,.n
        push hl
        ld e,a
        inc a
        ld (scan_n),a
        ld d,0
        ld hl,scan_tmp
        add hl,de
        ld (hl),c
        pop hl
.n:     inc hl
        inc c
        djnz .l
        ld a,c
        cp 176
        jr c,.sv
        ; publish
        ld hl,scan_tmp
        ld de,armed
        ld bc,8
        ldir
        ld a,(scan_n)
        ld (narmed),a
        xor a
.sv:    ld (scan_pos),a
        ret

; arrival at a new cell
tom_arrive:
        call ent_cell
        ld (tmp),a
        call tile_get
        cp TL_TRAP3
        jr z,.trap
        cp TL_TRAP1
        ret c
        cp TL_TRAP3
        ret nc
        ; trample half-built trap
.tr:    ld a,(tmp)
        call clear_tile
        ld hl,traps
        dec (hl)
        ld hl,sfx_trample
        jp play_sfx
.trap:  ld a,(ix+E_TYPE)
        cp T_UNRIPE
        jr z,.tr
        call is_scared
        ret c
        ld (ix+E_STATE),S_CAUGHT
        ld a,(ix+E_TYPE)
        call type_info
        ld de,4
        add hl,de
        ld a,(hl)
        ld (ix+E_TIMER),a
        ld a,(tmp)
        ld c,TL_TRAPC
        call tile_set
        ld hl,sfx_snap
        call play_sfx
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        ld hl,txt_snap
        jp popup

; ---------------------------------------------------------------------
;  squash (IX). points with combo
; ---------------------------------------------------------------------
squash_ent:
        ld a,(ix+E_STATE)
        cp S_SQUASH
        ret z
        ld (ix+E_STATE),S_SQUASH
        ld (ix+E_TIMER),16
        ld (ix+E_FLASH),0
        call ent_near
        ld (tmp),a
        call tile_get
        cp TL_TRAPC
        jr nz,.nt
        ld hl,traps
        dec (hl)
        jr .stain
.nt:    or a
        jr z,.stain
        cp TL_SHADOW
        jr nz,.nost
.stain: ld a,(tmp)
        ld c,TL_STAIN
        call tile_set
.nost:  ; combo
        ld a,(combo_t)
        or a
        ld a,(combo)
        jr z,.c0
        cp 3
        jr nc,.c1
        inc a
        jr .c1
.c0:    xor a
.c1:    ld (combo),a
        ld a,75
        ld (combo_t),a
        ld a,(combo)
        cp 2
        jr nz,.nc
        ld a,(tick_t)
        or a
        jr nz,.nc
        ld a,M_COMBO
        call ticker
.nc:    ; points = base * (combo+1)
        ld a,(ix+E_TYPE)
        call type_info
        inc hl
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld a,(combo)
        or a
        jr z,.pt
        ld b,a
        ld h,d
        ld l,e
.cm:    ld a,e
        add a,l
        daa
        ld e,a
        ld a,d
        adc a,h
        daa
        ld d,a
        djnz .cm
.pt:    push de
        call add_score
        pop de
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        push ix
        call popup_pts
        pop ix
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        inc b
        inc b
        ld d,10
        ld a,(cmap+3)
        ld e,a
        push ix
        call spawn_burst
        pop ix
        ld hl,sfx_splat
        call play_sfx
        ld a,(ix+E_TYPE)
        cp T_GOLD
        jr z,.ng
        ld a,(kind)
        cp 1
        jr z,.ng                ; boss minions don't count
        ld hl,tleft
        dec (hl)
        ld hl,hud_dirty
        set 4,(hl)
        ld a,(tleft)
        cp 1
        jr nz,.ng
        ld a,(kind)
        or a
        jr nz,.ng
        ld a,(tick_t)
        or a
        jr nz,.ng
        ld a,M_LAST
        call ticker
.ng:    ld a,(ix+E_TYPE)
        cp T_ROT
        jr nz,.nr
        ; stink cloud
        ld a,(stink_t)
        or a
        jr z,.sk
        ld a,(stink_cell)
        call clear_tile
.sk:    ld a,(tmp)
        ld (stink_cell),a
        ld c,TL_STINK
        call tile_set
        ld a,180
        ld (stink_t),a
.nr:    ld a,(ix+E_TYPE)
        cp T_BEEF
        ret nz
        ld a,(kind)
        or a
        ret nz
        ; beefsteak splits into two cherries
        ld a,(tmp)
        ld (tmp+1),a
        ld b,2
.sp:    push bc
        push ix
        call free_slot
        jr c,.nf
        ld (ix+E_TYPE),T_CHERRY
        ld a,(tmp+1)
        call ent_place
        ld (ix+E_STATE),S_SPAWN
        ld (ix+E_TIMER),20
        ld (ix+E_DIR),$FF
        ld (ix+E_SPD),$70
        ld (ix+E_HP),2
        ld (ix+E_AUX),0
        ld (ix+E_AUX2),0
        ld hl,tleft
        inc (hl)
.nf:    pop ix
        pop bc
        djnz .sp
        ret

; ---------------------------------------------------------------------
;  ketchup shot
; ---------------------------------------------------------------------
shot_update:
        dec (ix+E_TIMER)
        jr z,.kill
        ld b,2
.st:    push bc
        ld a,(ix+E_PROG)
        or a
        jr nz,.mv
        ld b,(ix+E_DIR)
        call ent_cell
        call open_dir
        jr nz,.wall
.mv:    call ent_advance
        call shot_hit
        pop bc
        ld a,(ix+E_TYPE)
        or a
        ret z
        djnz .st
        ret
.wall:  pop bc
.kill:  ld b,(ix+E_X)
        ld c,(ix+E_Y)
        ld d,4
        ld a,(cmap+3)
        ld e,a
        push ix
        call spawn_burst
        pop ix
        ld (ix+E_TYPE),T_NONE
        ret
; shot_hit: test against enemies
shot_hit:
        push ix
        pop iy
        ld ix,ents+ESIZE
        ld b,10
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        cp T_SHOT
        jr z,.n
        ld a,(iy+E_X)
        sub (ix+E_X)
        jr nc,$+4
        neg
        cp 6
        jr nc,.n
        ld a,(iy+E_Y)
        sub (ix+E_Y)
        jr nc,$+4
        neg
        cp 4
        jr nc,.n
        ld a,(ix+E_TYPE)
        cp T_SEED
        jr z,.seed
        cp T_BOSS
        jr z,.boss
        ld a,(ix+E_STATE)
        or a
        jr nz,.n
        ; hit a tomato
        ld a,(ix+E_TYPE)
        cp T_UNRIPE
        call z,ripen
        ld a,(gun_lvl)
        cp 3
        jr c,.stun
        call squash_ent
        jr .used
.stun:  ld (ix+E_STATE),S_STUN
        ld (ix+E_TIMER),110
        ld (ix+E_FLASH),6
        ld hl,sfx_bonk
        call play_sfx
.used:  ld a,(gun_lvl)
        cp 2
        jr nc,.n                ; piercing
        ld (iy+E_TYPE),T_NONE
        pop bc
        push iy
        pop ix
        ret
.seed:  ld (ix+E_TYPE),T_NONE
        jr .used
.boss:  ld (iy+E_TYPE),T_NONE
        ld (ix+E_FLASH),4
        pop bc
        push iy
        pop ix
        ret
.n:     ld de,ESIZE
        add ix,de
        pop bc
        dec b
        jp nz,.l
        push iy
        pop ix
        ret

; ---------------------------------------------------------------------
;  seeds (final boss projectiles)
; ---------------------------------------------------------------------
seed_update:
        ld a,$B0
        add a,(ix+E_ACC)
        ld (ix+E_ACC),a
        jr nc,.c
        ld a,(ix+E_PROG)
        or a
        jr nz,.mv
        ld b,(ix+E_DIR)
        call ent_cell
        call open_dir
        jr z,.mv
        ld (ix+E_TYPE),T_NONE
        ret
.mv:    call ent_advance
.c:     ld a,(dying)
        or a
        ret nz
        call touch_player
        ret nc
        ld (ix+E_TYPE),T_NONE
        jp kill_player

; =====================================================================
;  bosses
; =====================================================================
boss_setup:
        ld ix,ents+ESIZE
        ld (ix+E_TYPE),T_BOSS
        ld a,(bossid)
        cp 3
        jr z,.b3
        ld a,4
        ld (bossw),a
        ld a,10
        ld (bossrows),a
        ld a,7                  ; row 0, col 7
        call ent_place
        ld a,(bossid)
        cp 1
        ld a,12
        jr z,$+4
        ld a,16
        jr .hp
.b3:    ld a,6
        ld (bossw),a
        ld a,15
        ld (bossrows),a
        ld a,6
        call ent_place
        ld (ix+E_DIR),3
        ld a,24
.hp:    ld (ix+E_HP),a
        ld (ix+E_STATE),S_WALK
        ld (ix+E_DIR),$FF
        ld a,(bossid)
        cp 3
        jr nz,$+6
        ld (ix+E_DIR),3
        ld a,1
        ld (tleft),a
        ld a,100
        ld (boss_spawn_t),a
        ld a,60
        ld (seed_t),a
        ld a,1
        ret
boss_fp:                        ; footprint size in cells
        ld a,(bossid)
        cp 3
        ld a,2
        ret nz
        inc a
        ret

boss_vulnerable:                ; IX = boss -> carry if whackable
        ld a,(ix+E_STATE)
        cp S_CAUGHT
        jr z,.y
        cp S_STUN
        jr z,.y
        or a
        ret
.y:     scf
        ret
; boss_covers: A = cell -> carry if inside boss footprint (IX = boss)
boss_covers:
        ld c,a
        and $0F
        sub (ix+E_CX)
        jr c,.no
        ld b,a
        call boss_fp
        ld e,a
        ld a,b
        cp e
        jr nc,.no
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $0F
        sub (ix+E_CY)
        jr c,.no
        cp e
        ret                     ; carry if < fp
.no:    or a
        ret

; boss_open: B = dir -> Z if the whole leading edge is passable (IX = boss)
boss_open:
        ld (tmp+2),a
        ld a,b
        ld (tmp+3),a
        call boss_fp
        ld d,a                  ; fp
        ld e,a                  ; counter
        ; first leading cell
        ld a,b
        or a
        jr nz,.d
        ld a,(ix+E_CY)
        or a
        jr z,.no
        dec a
        ld h,a
        ld l,(ix+E_CX)
        ld c,1                  ; step along x
        jr .scan
.d:     dec a
        jr nz,.lt
        ld a,(ix+E_CY)
        add a,d
        cp 11
        jr nc,.no
        ld h,a
        ld l,(ix+E_CX)
        ld c,1
        jr .scan
.lt:    dec a
        jr nz,.rt
        ld a,(ix+E_CX)
        or a
        jr z,.no
        dec a
        ld l,a
        ld h,(ix+E_CY)
        ld c,16
        jr .scan
.rt:    ld a,(ix+E_CX)
        add a,d
        cp 16
        jr nc,.no
        ld l,a
        ld h,(ix+E_CY)
        ld c,16
.scan:  ld a,h
        add a,a
        add a,a
        add a,a
        add a,a
        add a,l
.sl:    push af
        call tile_get
        bit 7,a
        jr nz,.nop
        pop af
        add a,c
        dec e
        jr nz,.sl
        xor a
        ret
.nop:   pop af
.no:    or 1
        ret

boss_update:
        ld a,(ix+E_STATE)
        cp S_SQUASH
        jp z,boss_dying
        ; minion spawns
        ld hl,boss_spawn_t
        dec (hl)
        call z,boss_minion
        ld a,(ix+E_STATE)
        cp S_CAUGHT
        jr z,.held
        cp S_STUN
        jr nz,.walk
.held:  dec (ix+E_TIMER)
        jr nz,.coll
        ; break free
        ld (ix+E_STATE),S_WALK
        call boss_clear_traps
        jr .coll
.walk:  ld a,(bossid)
        cp 3
        jp z,great_walk
        ; speed
        ld a,(bossid)
        cp 1
        ld c,$48
        jr z,$+4
        ld c,$5C
        ld a,(ix+E_AUX)         ; charging?
        or a
        jr z,$+4
        ld c,$F0
        ld a,(ix+E_HP)
        cp 5
        jr nc,$+6
        ld a,c
        add a,$18
        ld c,a
        ld a,c
        add a,(ix+E_ACC)
        ld (ix+E_ACC),a
        jr nc,.coll
        ld a,(ix+E_PROG)
        or a
        jr nz,.go
        call boss_think
        ld a,(ix+E_DIR)
        cp $FF
        jr z,.coll
.go:    call ent_advance
        jr nc,.coll
        call boss_trapcheck
.coll:  ; contact with player
        ld a,(ix+E_STATE)
        or a
        ret nz
        ld a,(dying)
        or a
        ret nz
        ld a,(bossw)
        add a,a
        add a,a
        ld c,a
        ld a,(ents+E_X)
        add a,5
        sub (ix+E_X)
        ret c
        cp c
        ret nc
        ld a,(bossrows)
        ld c,a
        ld a,(ents+E_Y)
        add a,3
        sub (ix+E_Y)
        ret c
        inc c
        cp c
        ret nc
        jp kill_player

; boss_think: chase; Baron charges when lined up
boss_think:
        ld a,(ix+E_AUX)
        or a
        jr z,.nc
        ; charging: continue until blocked -> dizzy
        ld b,(ix+E_DIR)
        call boss_open
        ret z
        ld (ix+E_AUX),0
        ld (ix+E_STATE),S_STUN
        ld (ix+E_TIMER),130
        ld (ix+E_DIR),$FF
        ld a,4
        ld (flash_scr),a
        ld hl,sfx_bosshit
        call play_sfx
        ld a,M_BOSSHURT
        jp ticker
.nc:    ld a,(bossid)
        cp 2
        jr nz,.chase
        ; lined up? player column within boss columns or row within rows
        ld a,(ents+E_CX)
        sub (ix+E_CX)
        cp 2
        jr nc,.row
        ld a,(ents+E_CY)
        cp (ix+E_CY)
        ld b,0
        jr c,.charge
        ld b,1
        jr .charge
.row:   ld a,(ents+E_CY)
        sub (ix+E_CY)
        cp 2
        jr nc,.chase
        ld a,(ents+E_CX)
        cp (ix+E_CX)
        ld b,2
        jr c,.charge
        ld b,3
.charge: push bc
        call boss_open
        pop bc
        jr nz,.chase
        ld (ix+E_DIR),b
        ld (ix+E_AUX),1
        ld hl,sfx_charge
        jp play_sfx
.chase: ; greedy towards player
        ld a,$FF
        ld (best),a
        ld (bestd),a
        ld b,4
.dl:    push bc
        dec b
        ld a,(ix+E_DIR)
        xor 1
        cp b
        jr z,.sk
        push bc
        call boss_open
        pop bc
        jr nz,.sk
        ; distance after move
        ld a,(ix+E_CX)
        inc a
        ld c,a
        ld a,b
        cp 2
        jr nz,$+3
        dec c
        cp 3
        jr nz,$+3
        inc c
        ld a,(ents+E_CX)
        sub c
        jr nc,$+4
        neg
        ld e,a
        ld a,(ix+E_CY)
        ld c,a
        ld a,b
        or a
        jr nz,$+3
        dec c
        cp 1
        jr nz,$+3
        inc c
        ld a,(ents+E_CY)
        sub c
        jr nc,$+4
        neg
        add a,e
        ld e,a
        call rand
        and 1
        add a,e
        ld e,a
        ld a,(bestd)
        cp e
        jr c,.sk
        ld a,e
        ld (bestd),a
        ld a,b
        ld (best),a
.sk:    pop bc
        djnz .dl
        ld a,(best)
        ld (ix+E_DIR),a
        ret

boss_trapcheck:                 ; caught if any footprint cell holds an armed trap
        call boss_fp
        ld d,a
        ld e,a
        ld a,(ix+E_CY)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,(ix+E_CX)
        ld c,a
.ry:    ld b,d
        ld a,c
.rx:    push af
        push bc
        call tile_get
        cp TL_TRAP3
        jr z,.caught
        pop bc
        pop af
        inc a
        djnz .rx
        ld a,c
        add a,16
        ld c,a
        dec e
        jr nz,.ry
        ret
.caught: pop bc
        pop af
        ld c,TL_TRAPC
        call tile_set
        ld (ix+E_STATE),S_CAUGHT
        ld (ix+E_TIMER),170
        ld (ix+E_AUX),0
        ld (ix+E_DIR),$FF
        ld hl,sfx_snap
        call play_sfx
        ld a,2
        ld (flash_scr),a
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        ld hl,txt_snap
        jp popup

boss_clear_traps:               ; remove sprung traps under the boss
        call boss_fp
        ld d,a
        ld e,a
        ld a,(ix+E_CY)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,(ix+E_CX)
        ld c,a
.ry:    ld b,d
        ld a,c
.rx:    push af
        push bc
        push de
        ld (tmp+3),a
        call tile_get
        cp TL_TRAPC
        jr nz,.n
        ld a,(tmp+3)
        call clear_tile
        ld hl,traps
        dec (hl)
.n:     pop de
        pop bc
        pop af
        inc a
        djnz .rx
        ld a,c
        add a,16
        ld c,a
        dec e
        jr nz,.ry
        ret

boss_minion:
        ld (hl),180
        ; count live tomatoes
        call minions_alive
        cp 3
        ret nc
        push ix
        call rand
        rla
        ld a,T_CHERRY
        jr nc,$+4
        ld a,T_ROMA
        ld b,0
        call spawn_enemy
        pop ix
        ret
minions_alive:                  ; -> A count of tomatoes alive (slots 2..10)
        push ix
        ld ix,ents+2*ESIZE
        ld b,9
        ld c,0
.l:     ld a,(ix+E_TYPE)
        or a
        jr z,.n
        cp T_SHOT
        jr nc,.n
        inc c
.n:     ld de,ESIZE
        add ix,de
        djnz .l
        ld a,c
        pop ix
        ret

; final boss: patrols the top, spits seeds
great_walk:
        ld a,$1C
        add a,(ix+E_ACC)
        ld (ix+E_ACC),a
        jr nc,.spit
        ld a,(ix+E_PROG)
        or a
        jr nz,.go
        ; at centre: maybe turn towards player
        call rand
        cp 60
        jr nc,.keep
        ld a,(ents+E_CX)
        dec a
        cp (ix+E_CX)
        ld a,2
        jr c,$+4
        ld a,3
        ld (ix+E_DIR),a
.keep:  ld b,(ix+E_DIR)
        call boss_open
        jr z,.go
        ld a,(ix+E_DIR)
        xor 1
        ld (ix+E_DIR),a
        ret
.go:    call ent_advance        ; two half-steps: always byte aligned (cheap to draw)
        jr c,.spit
        call ent_advance
.spit:  ld hl,seed_t
        dec (hl)
        jp nz,boss_update.coll
        ld a,(ix+E_HP)
        add a,30
        ld (hl),a
        push ix
        call free_slot
        jr c,.nf
        ld (ix+E_TYPE),T_SEED
        ld a,(ents+ESIZE+E_CY)
        add a,3
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(ents+ESIZE+E_CX)
        inc a
        add a,b
        call ent_place
        ld (ix+E_DIR),1
        ld (ix+E_STATE),S_WALK
        ld hl,sfx_shot
        call play_sfx
.nf:    pop ix
        jp boss_update.coll

boss_daze:                      ; the song hurts the Great Tomato
        push ix
        ld ix,ents+ESIZE
        ld a,(ix+E_TYPE)
        cp T_BOSS
        jr nz,.n
        ld (ix+E_STATE),S_STUN
        ld (ix+E_TIMER),220
        ld a,M_SING
        call ticker
.n:     pop ix
        ret

; boss_hit: IX = boss (from whack_ent)
boss_hit:
        ld hl,sfx_bosshit
        call play_sfx
        ld a,2
        ld (flash_scr),a
        ld de,$0100
        call add_score
        dec (ix+E_HP)
        jr z,.dead
        ; Mama breaks out every 4 whacks
        ld a,(bossid)
        cp 3
        jr z,.x
        ld a,(ix+E_HP)
        and 3
        jr nz,.x
        ld (ix+E_TIMER),1
.x:     ld ix,ents
        ret
.dead:  ld (ix+E_STATE),S_SQUASH
        ld (ix+E_TIMER),120
        call boss_clear_traps
        call stop_music
        ld ix,ents
        ret

boss_dying:
        ld a,(ix+E_TIMER)
        and 7
        jr nz,.n
        ; explosions around the boss
        ld a,(bossw)
        add a,a
        add a,a
        call rand_n
        add a,(ix+E_X)
        ld b,a
        ld a,(bossrows)
        call rand_n
        add a,(ix+E_Y)
        ld c,a
        ld d,6
        call rand
        and 1
        add a,a
        inc a
        ld e,a
        push ix
        call spawn_burst
        pop ix
        ld hl,sfx_splat
        call play_sfx
        ld a,2
        ld (flash_scr),a
.n:     dec (ix+E_TIMER)
        ret nz
        ld (ix+E_TYPE),T_NONE
        ; kill remaining minions
        push ix
        ld ix,ents+2*ESIZE
        ld b,9
.k:     ld a,(ix+E_TYPE)
        or a
        jr z,.kn
        cp T_SHOT
        jr z,.kn
        push bc
        call squash_ent
        pop bc
.kn:    ld de,ESIZE
        add ix,de
        djnz .k
        pop ix
        ld a,(bossid)
        ld de,$1000
        cp 1
        jr z,.s
        ld de,$2000
        cp 2
        jr z,.s
        ld de,$5000
.s:     call add_score
        ld bc,$3818
        ld hl,txt_yum
        call popup
        xor a
        ld (tleft),a
        ret

; =====================================================================
;  sprite selection: IX -> HL sprite, A flags (bit0 flash, bit1 hide, bit2 big)
; =====================================================================
ent_sprite:
        ld a,(ix+E_TYPE)
        cp T_PLAYER
        jp z,.player
        cp T_SHOT
        jr nz,.ns
        ld hl,spr_SHOT
        ld a,(gun_lvl)
        cp 3
        jr c,$+5
        ld hl,spr_SHOT3
        xor a
        ret
.ns:    cp T_SEED
        jr nz,.nse
        ld hl,spr_SEED
        xor a
        ret
.nse:   cp T_BOSS
        jp z,.boss
        ; tomatoes
        ld a,(ix+E_STATE)
        cp S_SPAWN
        jr nz,.n1
        ld hl,spr_POP1
        ld a,(ix+E_TIMER)
        cp 15
        jr nc,$+5
        ld hl,spr_POP2
        xor a
        ret
.n1:    cp S_SQUASH
        jr nz,.n2
        ld hl,spr_FLAT1
        ld a,(ix+E_TIMER)
        cp 9
        jr nc,$+5
        ld hl,spr_FLAT2
        xor a
        ret
.n2:    cp S_CAUGHT
        jr nz,.n3
        ld hl,spr_CAUGHT
        ld a,(frame_cnt)
        and 8
        jr z,$+5
        ld hl,spr_CAUGHTM
        ld a,(ix+E_TIMER)
        cp 45
        jr nc,.fl
        ld a,(frame_cnt)
        and 4
        jr z,.fl
        ld a,1
        ret
.n3:    cp S_STUN
        jr nz,.n4
        ld hl,spr_DIZZY1
        ld a,(frame_cnt)
        and 8
        jr z,.fl
        ld hl,spr_DIZZY2
        jr .fl
.n4:    call is_scared
        jr nc,.n5
        ld hl,spr_SCARED1
        ld a,(ix+E_AUX2)
        or a
        jr nz,.fl
        ld a,(frame_cnt)
        and 4
        jr z,.fl
        ld hl,spr_SCARED2
        ld a,(pw_record)
        cp 4
        jr nc,.fl
        ld a,(frame_cnt)        ; record running out: blink back to red
        and 8
        jr z,.fl
        ld a,(ix+E_TYPE)
        jr .walkspr
.n5:    ld a,(ix+E_TYPE)
.walkspr:
        sub T_CHERRY
        add a,a
        add a,a
        ld hl,walk_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(ix+E_X)
        add a,(ix+E_Y)
        and 4
        jr z,$+4
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.fl:    ld a,(ix+E_FLASH)
        or a
        ret z
        ld a,1
        ret
.player:
        ld a,(dying)
        or a
        jr z,.alive
        ld hl,spr_PDIE1
        cp 50
        jr nc,$+5
        ld hl,spr_PDIE2
        xor a
        ret
.alive: ld a,(clear_t)
        or a
        jr z,.nw
        ld hl,spr_PWIN
        xor a
        ret
.nw:    ld a,(invuln)
        or a
        jr z,.vis
        ld a,(frame_cnt)
        and 2
        ld a,2
        ret nz
.vis:   ld a,(pw_disg)
        or a
        jr z,.nd
        ld hl,spr_DISGUISE
        ld a,(pw_disg)
        cp 4
        ld a,0
        ret nc
        ld a,(frame_cnt)
        and 4
        ret z
        ld a,1
        ret
.nd:    ld a,(face)
        add a,a
        add a,a
        ld hl,pl_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(ix+E_X)
        add a,(ix+E_Y)
        and 4
        jr z,$+4
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(shield)
        or a
        ret z
        ld a,(frame_cnt)
        and 16
        ret z
        ld a,(frame_cnt)
        and 3
        ld a,0
        ret nz
        ld a,1
        ret
.boss:  ld a,(bossid)
        dec a
        add a,a
        add a,a
        ld hl,boss_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(frame_cnt)
        and 8
        jr z,$+4
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ix+E_STATE)
        cp S_STUN
        jr nz,.bn
        ld a,(bossid)
        cp 3
        jr nz,.bn
        ld hl,spr_GREATD
.bn:    ld a,(ix+E_FLASH)
        or a
        ld a,4
        ret z
        ld a,5
        ret
walk_tab:
        dw spr_CH1,spr_CH2, spr_RO1,spr_RO2, spr_BF1,spr_BF2, spr_UN1,spr_UN2
        dw spr_GO1,spr_GO2, spr_HOP1,spr_HOP2, spr_ROT1,spr_ROT2, spr_BALL1,spr_BALL2
pl_tab: dw spr_PU1,spr_PU2, spr_PD1,spr_PD2, spr_PL1,spr_PL2, spr_PR1,spr_PR2
boss_tab: dw spr_MAMA1,spr_MAMA2, spr_BARON1,spr_BARON2, spr_GREAT1,spr_GREAT2

; =====================================================================
;  demo bot: produces inp / inp_new for the attract-mode demo
; =====================================================================
bot_input:
        ld a,(inp)
        ld (inp_prev),a
        ld ix,ents
        call nearest_tom        ; A = dist, C = cell
        ld (bot_d),a
        ld a,c
        ld (bot_t),a
        ld a,(bot_hold)
        or a
        jr z,.think
        dec a
        ld (bot_hold),a
        ; abort building if a tomato gets too close (unless it's caught)
        ld a,(bot_d)
        cp 2
        jr nc,.keep
        xor a
        ld (bot_hold),a
        jr .think
.keep:  ld a,(inp)
        jp .set
.think: ld a,(ix+E_PROG)
        or a
        jr z,.ctr
        ld a,(inp)
        and $0F
        jp .set                 ; mid-cell: keep going
.ctr:
        ; 1. adjacent whackable -> whack it
        ld b,4
.wl:    push bc
        dec b
        ld a,b
        ld (face),a
        call ent_cell
        call neighbour
        jr c,.wn
        ld (target_cell),a
        call find_whackable
        jr nc,.wn
        pop bc
        ld a,(face)
        call dirbit
        or 1<<I_FIRE
        ld b,a
        ld a,8
        ld (bot_hold),a
        ld a,b
        jp .set
.wn:    pop bc
        djnz .wl
        ; 1b. ketchup: shoot a tomato lined up within 5 cells
        ld a,(gun_ammo)
        or a
        jr z,.nogun
        ld a,(ents+11*ESIZE+E_TYPE)
        or a
        jr nz,.nogun
        ld a,(bot_d)
        cp 6
        jr nc,.nogun
        ld a,(bot_t)
        ld c,a
        and $0F
        ld b,a                  ; tomato cx
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld c,a                  ; tomato cy
        ld a,(ix+E_CY)
        cp c
        jr nz,.col
        ld a,(ix+E_CX)
        cp b
        ld a,2
        jr nc,.shoot
        ld a,3
        jr .shoot
.col:   ld a,(ix+E_CX)
        cp b
        jr nz,.nogun
        ld a,(ix+E_CY)
        cp c
        ld a,0
        jr nc,.shoot
        ld a,1
.shoot: ld (face),a
        call dirbit
        or 1<<I_SHOOT
        jp .set
.nogun: ; 2. danger -> flee (maximise distance)
        ld a,(bot_d)
        cp 2
        jr nc,.nodanger
        ld a,2
        jr .pick
.nodanger:
        ; 3. build a trap towards the tomato when it's 2..5 away
        cp 6
        jr nc,.hunt
        ld a,(traps)
        cp MAXTRAPS
        jr nc,.hunt
        ld a,1
        call bot_best           ; best open floor dir towards tomato -> A (or $FF)
        cp $FF
        jr z,.hunt
        ld b,a
        call ent_cell
        call neighbour
        call tile_get
        or a
        jr z,.bld
        cp TL_SHADOW
        jr z,.bld
        cp TL_TRAP1
        jr c,.hunt
        cp TL_TRAP3
        jr nc,.hunt
.bld:   ld a,(bot_best_dir)
        call dirbit
        or 1<<I_FIRE
        ld b,a
        ld a,30
        ld (bot_hold),a
        ld a,b
        jr .set
.hunt:  ; 4. go for a pickup, a dazed boss, or the nearest tomato
        ld a,(pk_life)
        or a
        jr z,.nopk
        ld a,(pk_cell)
        ld (bot_t),a
        jr .h1
.nopk:  ld a,(ents+ESIZE+E_TYPE)
        cp T_BOSS
        jr nz,.h1
        ld a,(ents+ESIZE+E_STATE)
        cp S_STUN
        jr z,.bv
        cp S_CAUGHT
        jr nz,.h1
.bv:    ld a,(ents+ESIZE+E_CY)
        ld b,a
        call boss_fp
        add a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(ents+ESIZE+E_CX)
        inc a
        add a,b
        ld (bot_t),a
.h1:    ld a,1
.pick:  call bot_best
        cp $FF
        jr nz,.go
        ld a,(bot_dir)
        xor 1
.go:    ld (bot_dir),a
        call dirbit
.set:   ld (inp),a
        ld b,a
        ld a,(inp_prev)
        cpl
        and b
        ld (inp_new),a
        ret

; bot_best: A = mode (0 random, 1 towards tomato, 2 away) -> A = dir ($FF none)
bot_best:
        ld (tmp+1),a
        ld a,$FF
        ld (bot_best_dir),a
        ld a,(tmp+1)
        cp 2
        ld a,0
        jr z,$+4
        ld a,$FF
        ld (bestd),a
        ld a,4
        call rand_n
        ld (tmp+2),a
        ld b,4
.l:     push bc
        ld a,(tmp+2)
        inc a
        and 3
        ld (tmp+2),a
        ld b,a
        call ent_cell
        call open_dir
        jr nz,.n
        ld c,a
        ld a,(tmp+1)
        or a
        jr nz,.d
        call rand
        and 15
        ld e,a
        ld a,(bot_dir)
        cp b
        jr nz,.cmp
        ld a,e
        sub 6                   ; prefer to keep going
        jr nc,$+3
        xor a
        ld e,a
        jr .cmp
.d:     ; distance from candidate cell to the tomato's cell
        ld a,(bot_t)
        call cell_dist          ; A = |c - t|
        ld e,a
.cmp:   ld a,(tmp+1)
        cp 2
        ld a,(bestd)
        jr z,.fl
        cp e
        jr c,.n
        jr z,.n
        jr .tk
.fl:    cp e
        jr nc,.n
.tk:    ld a,e
        ld (bestd),a
        ld a,b
        ld (bot_best_dir),a
.n:     pop bc
        djnz .l
        ld a,(bot_best_dir)
        ret
; cell_dist: A = cell t, C = cell c -> A = manhattan distance
cell_dist:
        push bc
        ld b,a
        and $0F
        ld e,a
        ld a,c
        and $0F
        sub e
        jr nc,$+4
        neg
        ld e,a
        ld a,b
        and $F0
        ld b,a
        ld a,c
        and $F0
        sub b
        jr nc,$+4
        neg
        rrca
        rrca
        rrca
        rrca
        add a,e
        pop bc
        ret
dirbit: ld b,a
        inc b
        ld a,1
.l:     dec b
        ret z
        add a,a
        jr .l
nearest_tom:
        ld a,255
        ld (bestd),a
        push ix
        ld ix,ents+ESIZE
        ld b,10
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        cp T_SHOT
        jr nc,.n
        ld a,(ix+E_STATE)
        or a
        jr nz,.n
        call ent_cell
        ld c,a
        call dist_player
        ld hl,bestd
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld a,c
        ld (best),a
.n:     ld de,ESIZE
        add ix,de
        pop bc
        djnz .l
        pop ix
        ld a,(best)
        ld c,a
        ld a,(bestd)
        ret
