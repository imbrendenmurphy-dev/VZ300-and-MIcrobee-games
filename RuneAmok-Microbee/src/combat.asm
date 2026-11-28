; =====================================================================
;  COMBAT: monsters, their turn, fighting, spells, potions, the
;  trader, levelling up, death and victory
;
;  MONS: 16 bytes a monster: type (FF = gone), hp, square offset (2),
;  awake, move timer
; =====================================================================
M_TYPE      EQU 0
M_HP        EQU 1
M_POS       EQU 2
M_AWAKE     EQU 4
M_TIMER     EQU 5
MT_KING     EQU 8
MT_TRADER   EQU 9

; per type: hp, attack, defence, xp, speed (turns a step), name
mon_tab:
        db 6,2,0,3,1
        dw n_rat
        db 14,4,1,8,2
        dw n_skel
        db 16,5,1,10,1
        dw n_spider
        db 26,6,2,13,2
        dw n_fungoid
        db 30,7,3,18,1
        dw n_ghoul
        db 22,8,5,20,1
        dw n_wisp
        db 32,9,3,24,1
        dw n_imp
        db 40,11,3,28,1
        dw n_hound
        db 100,11,4,0,1
        dw n_king
        db 99,0,99,0,99
        dw n_trader
n_rat:      db "Rat",0
n_skel:     db "Skeleton",0
n_spider:   db "Cave Spider",0
n_fungoid:  db "Fungoid",0
n_ghoul:    db "Drowned Ghoul",0
n_wisp:     db "Grave Wisp",0
n_imp:      db "Ember Imp",0
n_hound:    db "Ash Hound",0
n_king:     db "Hollow King",0
n_trader:   db "Trader",0

; A = type -> HL = its stats
mon_stats:
        ld l,a
        add a,a
        add a,a
        add a,a
        sub l                   ; *7
        ld l,a
        ld h,0
        ld de,mon_tab
        add hl,de
        ret

; A = monster number + 1 -> IX = its record
mon_rec:
        dec a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,MONS
        add hl,de
        push hl
        pop ix
        ret

; view: A = monster + 1 -> A = sprite id (sp_flash set)
mon_sprite:
        push af
        call mon_rec
        pop af
        ld b,a
        xor a
        ld (sp_flash),a
        ld a,(flash_mon)
        cp b
        jr nz,.nf
        ld a,BRED
        ld (sp_flash),a
.nf:    ld a,(ix+M_TYPE)
        cp $FF
        jr nz,.al
        xor a
        ret
.al:    ld hl,mon_spr
        call add_a_hl
        ld c,(hl)
        ld a,(atk_mon)
        cp b
        jr nz,.id
        ld a,(sp_dz)
        cp 1
        jr nz,.id
        inc c                   ; the attack frame, close up
.id:    ld a,c
        ret

; view: A = item -> A = sprite id
item_sprite:
        ld b,a
        xor a
        ld (sp_flash),a
        ld a,b
        add a,SP_ITEM1-1
        ret

; ---------------------------------------------------------------------
;  message builder: mb_str (HL), mb_num (HL), mb_chr (A), then mb_go
; ---------------------------------------------------------------------
mb_reset:
        ld hl,msgbuf
        ld (mb_ptr),hl
        ret
mb_str: push de
        ld de,(mb_ptr)
.l:     ld a,e
        cp low(msgbuf+120)
        jr z,.d
        ld a,(hl)
        or a
        jr z,.d
        ld (de),a
        inc hl
        inc de
        jr .l
.d:     ld (mb_ptr),de
        pop de
        ret
mb_chr: push hl
        ld hl,(mb_ptr)
        ld (hl),a
        inc hl
        ld (mb_ptr),hl
        pop hl
        ret
mb_num: ld de,num_buf+5
        xor a
        ld (de),a
.d:     dec de
        push de
        ld de,10
        call div16
        pop de
        add a,'0'
        ld (de),a
        ld a,h
        or l
        jr nz,.d
        ex de,hl
        jp mb_str
; A = colour: log the built message
mb_go:  push af
        xor a
        call mb_chr
        pop af
        ld hl,msgbuf
        jp log_msgc
mb_ptr:     dw 0

; HL = number, BC = template ('#' = the number) -> log it
fmt_num_msg:
        push hl
        call mb_reset
        pop hl
        push hl
.l:     ld a,(bc)
        inc bc
        or a
        jr z,.d
        cp '#'
        jr z,.n
        call mb_chr
        jr .l
.n:     pop hl
        push hl
        push bc
        call mb_num
        pop bc
        jr .l
.d:     pop hl
        ld a,YELLOW
        jp mb_go

; "The <name>" of monster IX
mb_name:
        ld hl,t_the
        call mb_str
        ld a,(ix+M_TYPE)
        call mon_stats
        ld de,5
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp mb_str

; ---------------------------------------------------------------------
;  the player attacks the monster in front: A = monster + 1
; ---------------------------------------------------------------------
attack: ld (cur_mon),a
        call mon_rec
        ld a,(ix+M_TYPE)
        ld (cur_type),a
        cp MT_TRADER
        jp z,shop
        ld (ix+M_AWAKE),1
        ld hl,sfx_swing
        call sfx
        call rnd
        cp 34
        jr nc,.hit
        call mb_reset
        ld hl,t_youmiss
        call mb_str
        call mb_name
        ld a,'.'
        call mb_chr
        ld a,GREY
        call mb_go
        xor a
        call show_blow          ; the blade swings, nothing bleeds
        jp end_turn
.hit:   ; damage = atk + rnd(atk/2 + 1) - defence, at least 1
        ld a,(atk)
        srl a
        inc a
        call rndn
        ld hl,atk
        add a,(hl)
        ld b,a
        ld a,(ix+M_TYPE)
        call mon_stats
        inc hl
        inc hl
        ld a,b
        sub (hl)
        jr z,.one
        jr nc,.dmg
.one:   ld a,1
.dmg:   jp damage_mon

; A = damage to the current monster (IX), then the turn ends
damage_mon:
        ld (cur_dmg),a
        ld b,a
        ld a,(ix+M_HP)
        sub b
        jr c,.dead
        jr z,.dead
        ld (ix+M_HP),a
        ld hl,sfx_hit
        call sfx
        call mb_reset
        ld hl,t_youhit
        call mb_str
        call mb_name
        ld hl,t_for
        call mb_str
        ld a,(cur_dmg)
        ld l,a
        ld h,0
        call mb_num
        ld a,'.'
        call mb_chr
        ld a,WHITE
        call mb_go
        call flash_monster
        jp end_turn
.dead:  call flash_monster      ; the killing blow shows too
        call kill_mon
        jp end_turn

; the current monster (cur_mon / IX) is struck: the blade's slash across
; it and the creature flashing red, held long enough to see
flash_monster:
        ld a,1
show_blow:                      ; A = 0: a miss (the slash alone)
        or a
        jr z,.nf
        ld a,(cur_mon)
.nf:    ld (flash_mon),a
        ld a,(blow_spr)
        ld (fx_sprite),a
        cp SP_X_SLASH
        jr nz,.kd               ; a spell stays where it struck
        ld a,1
        ld (fx_dz),a            ; the blade: on the foe in front
.kd:    ld a,SP_X_SLASH
        ld (blow_spr),a         ; (a spell sets its own for one blow)
        push ix
        call view_refresh       ; returns once the view is on screen
        ld a,12
        call frames
        xor a
        ld (flash_mon),a
        ld (fx_sprite),a
        call view_refresh
        pop ix
        ret

blow_spr:   db SP_X_SLASH

kill_mon:
        ld hl,sfx_kill
        call sfx
        ld (ix+M_TYPE),$FF
        ld l,(ix+M_POS)
        ld h,(ix+M_POS+1)
        push hl
        ld de,MONMAP
        add hl,de
        ld (hl),0
        call mb_reset
        call mb_name_dead
        ld hl,t_dies
        call mb_str
        ld a,(dead_type)
        call mon_stats
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        ld d,0
        ld hl,(xp)
        add hl,de
        ld (xp),hl
        ld hl,(kills)
        inc hl
        ld (kills),hl
        ld a,e
        or a
        jr z,.nx
        ld hl,t_plus
        call mb_str
        ld l,e
        ld h,0
        call mb_num
        ld hl,t_xp
        call mb_str
.nx:    ld a,BGREEN
        call mb_go
        pop hl
        ; maybe some gold where it fell
        ld de,ITEMMAP
        add hl,de
        ld a,(hl)
        or a
        jr nz,.ng
        call rnd
        cp 110
        jr nc,.ng
        ld (hl),1
.ng:    ld a,(dead_type)
        cp MT_KING
        jr nz,.nk
        ld a,1
        ld (won),a
.nk:    call view_refresh
        jp level_check

mb_name_dead:
        ld a,(ix+M_TYPE)
        cp $FF
        jr nz,.n
        ld a,(cur_type)
.n:     ld (dead_type),a
        ld hl,t_the
        call mb_str
        ld a,(dead_type)
        call mon_stats
        ld de,5
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp mb_str

cur_mon:    db 0
cur_dmg:    db 0
cur_type:   db 0
dead_type:  db 0

; enough XP for the next level?
level_check:
        ld a,(lvl)
        cp 9
        ret nc
        call xp_need
        ex de,hl
        ld hl,(xp)
        or a
        sbc hl,de
        ret c
        ld hl,lvl
        inc (hl)
        ld a,(hpmax)
        add a,6
        ld (hpmax),a
        ld (hp),a
        ld a,(mpmax)
        add a,2
        ld (mpmax),a
        ld (mp),a
        ld hl,atk
        inc (hl)
        ld a,(lvl)
        and 1
        jr nz,.d
        ld hl,def
        inc (hl)
.d:     ld hl,sfx_levelup
        call sfx
        call mb_reset
        ld hl,t_levelup
        call mb_str
        ld a,(lvl)
        ld l,a
        ld h,0
        call mb_num
        ld a,'!'
        call mb_chr
        ld a,YELLOW
        call mb_go
        call ui_stats
        jr level_check

; ---------------------------------------------------------------------
;  the monsters' turn
; ---------------------------------------------------------------------
monsters_turn:
        xor a
        ld (mt_moved),a
        ld a,(nmons)
        or a
        ret z
        ld b,a
        ld ix,MONS
        ld c,1
.m:     push bc
        ld a,c
        ld (cur_mon),a
        ld a,(ix+M_TYPE)
        cp $FF
        jr z,.n
        cp MT_TRADER
        jr z,.n
        ld (cur_type),a
        cp MT_KING
        call z,king_rage
        call mon_act
        ld a,(dead)
        or a
        jr nz,.stop
.n:     ld de,16
        add ix,de
        pop bc
        inc c
        djnz .m
        ld a,(mt_moved)
        or a
        ret z
        jp view_refresh
.stop:  pop bc
        ret

mt_moved:   db 0

; IX = a monster: wake, strike or step
mon_act:
        ; dx, dy to the player
        ld hl,(ppos)
        ld de,MAP
        or a
        sbc hl,de
        call off_xy             ; D = x, E = y (player)
        ld (pl_xy),de
        ld l,(ix+M_POS)
        ld h,(ix+M_POS+1)
        call off_xy
        ld a,(pl_xy+1)
        sub d
        ld (m_dx),a             ; player x - monster x
        ld a,(pl_xy)
        sub e
        ld (m_dy),a
        call iabs
        ld b,a
        ld a,(m_dx)
        call iabs
        add a,b
        ld (m_dist),a
        ld a,(ix+M_AWAKE)
        or a
        jr nz,.awake
        ld a,(m_dist)
        cp 5
        ret nc
        ld (ix+M_AWAKE),1
        ret
.awake: ld a,(m_dist)
        cp 1
        jp z,mon_strike
        cp 12
        ret nc                  ; lost the trail
        ld a,(ix+M_TYPE)
        call mon_stats
        ld de,4
        add hl,de
        ld a,(ix+M_TIMER)
        inc a
        cp (hl)
        jr nc,.go
        ld (ix+M_TIMER),a
        ret
.go:    ld (ix+M_TIMER),0
        ; step along the longer axis first
        ld a,(m_dx)
        call iabs
        ld b,a
        ld a,(m_dy)
        call iabs
        cp b
        jr nc,.ydir
        call .tryx
        ret z
        jp .tryy
.ydir:  call .tryy
        ret z
.tryx:  ld a,(m_dx)
        or a
        jr z,.no
        ld de,1
        jp p,.mv
        ld de,-1
        jr .mv
.tryy:  ld a,(m_dy)
        or a
        jr z,.no
        ld de,32
        jp p,.mv
        ld de,-32
.mv:    ; DE = step: free square?
        ld l,(ix+M_POS)
        ld h,(ix+M_POS+1)
        add hl,de
        push hl
        ld de,MAP
        add hl,de
        ld a,(hl)
        cp T_ILLUS
        jr z,.blk
        cp T_PIT
        jr z,.blk
        cp T_TELE
        jr z,.blk
        push hl
        ld hl,passtab
        call add_a_hl
        ld a,(hl)
        pop hl
        or a
        jr z,.blk
        ld de,MONMAP-MAP
        add hl,de
        ld a,(hl)
        or a
        jr nz,.blk
        ; go
        ld (hl),c               ; (C = this monster + 1 is not kept: use cur_mon)
        ld a,(cur_mon)
        ld (hl),a
        ld l,(ix+M_POS)
        ld h,(ix+M_POS+1)
        ld de,MONMAP
        add hl,de
        ld (hl),0
        pop hl
        ld (ix+M_POS),l
        ld (ix+M_POS+1),h
        ld a,1
        ld (mt_moved),a
        xor a                   ; Z: moved
        ret
.blk:   pop hl
.no:    or 1                    ; NZ: could not
        ret

; HL = MAP offset -> D = x, E = y
off_xy: ld a,l
        and 31
        ld d,a
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,h
        ret

iabs:   or a
        ret p
        neg
        ret

pl_xy:      dw 0
m_dx:       db 0
m_dy:       db 0
m_dist:     db 0

; the monster IX strikes the player
mon_strike:
        ; in front of us? show it lunging
        call ahead
        ld de,MAP
        or a
        sbc hl,de
        ld a,(ix+M_POS)
        cp l
        jr nz,.side
        ld a,(ix+M_POS+1)
        cp h
        jr nz,.side
        ld a,(cur_mon)
        ld (atk_mon),a
        call view_refresh
        ld a,1
        jr .roll
.side:  xor a
.roll:  ld (m_front),a
        call rnd
        cp 64
        jr nc,.hit
        call mb_reset
        call mb_name
        ld hl,t_misses
        call mb_str
        ld a,GREY
        call mb_go
        ld hl,sfx_swing
        call sfx
        jr .done
.hit:   ld a,(ix+M_TYPE)
        call mon_stats
        inc hl
        ld a,(hl)               ; attack
        ld b,a
        srl a
        inc a
        call rndn
        add a,b
        ld hl,def
        sub (hl)
        jr z,.one
        jr nc,.d
.one:   ld a,1
.d:     ld (cur_dmg),a
        call mb_reset
        call mb_name
        ld hl,t_strikes
        call mb_str
        ld a,(m_front)
        or a
        jr nz,.f
        ld hl,t_fromside
        call mb_str
.f:     ld a,'('
        call mb_chr
        ld a,(cur_dmg)
        ld l,a
        ld h,0
        call mb_num
        ld a,')'
        call mb_chr
        ld a,BRED
        call mb_go
        ld a,(cur_dmg)
        call hurt_player
.done:  ld a,(atk_mon)
        or a
        ret z
        ld a,14
        call frames
        xor a
        ld (atk_mon),a
        jp view_refresh

m_front:    db 0

; A = damage to the player
hurt_player:
        ld b,a
        ld a,(hp)
        sub b
        jr nc,.ok
        xor a
.ok:    ld (hp),a
        push af
        ld hl,sfx_hurt
        call sfx
        ld a,24
        ld (hurtflash),a        ; the view's frame flashes red (vb_hurt)
        call ui_stats
        pop af
        or a
        ret nz
        ld a,1
        ld (dead),a
        ret

; ---------------------------------------------------------------------
;  commands: spells, potion, sound, quit, help
; ---------------------------------------------------------------------
handle_cmd:
        ld a,(cmd)
        or a
        ret z
        ld b,a
        xor a
        ld (cmd),a
        ld a,b
        cp '1'
        jp z,cast_fire
        cp '2'
        jp z,cast_mend
        cp '3'
        jp z,quaff
        cp 'P'
        jp z,quaff
        cp 'T'
        jp z,snd_toggle
        cp 'H'
        jp z,help
        cp 27
        jp z,ask_quit
        ret

help:   ld hl,t_help
        ld a,BCYAN
        jp log_msgc

ask_quit:
        ld hl,t_quit
        ld a,YELLOW
        call log_msgc
        call ask_yn
        jr nz,.stay
        ld sp,STACK             ; out of the game: back to the title
        jp restart
.stay:  ld hl,t_onward
        jp log_msg

; wait for Y or N (or ESC = N) -> Z = yes
ask_yn: xor a
        ld (cmd),a
.w:     call frame
        ld a,(cmd)
        or a
        jr z,.w
        cp 'Y'
        ret z
        cp 'N'
        jr z,.n
        cp 27
        jr nz,.w
.n:     or 1
        ret

quaff:  ld a,(potions)
        or a
        ld hl,t_nopotion
        jp z,log_msg
        dec a
        ld (potions),a
        ld a,25
        call heal
        ld hl,t_quaff
        ld a,BMAGENTA
        call log_msgc
        jp end_turn

; A = hit points back
heal:   ld b,a
        ld a,(hp)
        add a,b
        ld hl,hpmax
        cp (hl)
        jr c,.ok
        ld a,(hl)
.ok:    ld (hp),a
        ld hl,sfx_heal
        call sfx
        jp ui_stats

cast_mend:
        ld a,(spells)
        and 2
        ld hl,t_nospell
        jp z,log_msg
        ld a,(mp)
        cp 4
        ld hl,t_nomp
        jp c,log_msg
        sub 4
        ld (mp),a
        ld a,(lvl)
        ld b,a
        add a,a
        add a,b
        add a,10
        call heal
        ld hl,t_mended
        ld a,BGREEN
        call log_msgc
        jp end_turn

cast_fire:
        ld a,(spells)
        and 1
        ld hl,t_nospell
        jp z,log_msg
        ld a,(mp)
        cp 3
        ld hl,t_nomp
        jp c,log_msg
        sub 3
        ld (mp),a
        call ui_stats
        ld hl,sfx_fire
        call sfx
        ; fly down the corridor: up to 3 squares, to the first monster
        ld hl,(ppos)
        ld (fb_pos),hl
        ld b,1
.fly:   push bc
        ld a,b
        ld (fx_dz),a
        ld a,(facing)
        add a,a
        ld hl,fwdtab
        call add_a_hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(fb_pos)
        add hl,de
        ld (fb_pos),hl
        ld a,(hl)
        cp T_ILLUS
        jr z,.stop
        push hl
        ld hl,passtab
        call add_a_hl
        ld a,(hl)
        pop hl
        or a
        jr z,.stop
        ld de,MONMAP-MAP
        add hl,de
        ld a,(hl)
        or a
        jr nz,.burn
        ld a,SP_X_FIREBALL
        ld (fx_sprite),a
        call view_refresh
        ld a,2
        call frames
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.fly
        jr .gone
.stop:  pop bc
.gone:  xor a
        ld (fx_sprite),a
        ld hl,t_fizzle
        call log_msg
        call view_refresh
        jp end_turn
.burn:  ld (cur_mon),a
        ld a,SP_X_FIREBALL
        ld (fx_sprite),a
        call view_refresh
        ld a,4
        call frames
        pop bc
        xor a
        ld (fx_sprite),a
        ld a,(cur_mon)
        call mon_rec
        ld a,(ix+M_TYPE)
        ld (cur_type),a
        cp MT_TRADER
        jr nz,.hurt
        ld hl,t_trader_no
        call log_msg
        call view_refresh
        jp end_turn
.hurt:  ld (ix+M_AWAKE),1
        ld a,(lvl)
        add a,a
        add a,8
        ld b,a
        ld a,4
        call rndn
        add a,b
        push af
        ld a,SP_X_FIREBALL
        ld (blow_spr),a         ; the fire, not a blade, lands
        pop af
        jp damage_mon

; ---------------------------------------------------------------------
;  the trader
; ---------------------------------------------------------------------
shop:   ld hl,t_shop1
        ld a,YELLOW
        call log_msgc
        ld hl,t_shop2
        ld a,YELLOW
        call log_msgc
        xor a
        ld (cmd),a
.w:     call frame
        ld a,(pressed)
        and 64
        jr nz,.leave
        ld a,(cmd)
        or a
        jr z,.w
        cp '1'
        jr z,.potion
        cp '2'
        jr z,.blade
        cp '3'
        jr z,.mail
.leave: xor a
        ld (pressed),a
        ld (cmd),a
        ld hl,t_shop_bye
        jp log_msg
.potion:
        ld de,20
        call pay
        jr c,.poor
        ld hl,potions
        inc (hl)
        jr .sold
.blade: ld de,(price_b)
        call pay
        jr c,.poor
        ld hl,(price_b)
        ld de,30
        add hl,de
        ld (price_b),hl
        ld hl,atk
        inc (hl)
        jr .sold
.mail:  ld de,(price_m)
        call pay
        jr c,.poor
        ld hl,(price_m)
        ld de,30
        add hl,de
        ld (price_m),hl
        ld hl,def
        inc (hl)
.sold:  ld hl,sfx_coin
        call sfx
        ld hl,t_shop_sold
        call log_msg
        call ui_stats
        jr .again
.poor:  ld hl,t_shop_poor
        call log_msg
.again: xor a
        ld (cmd),a
        jp .w

; DE = price: pay it (C = not enough gold)
pay:    ld hl,(gold)
        or a
        sbc hl,de
        ret c
        ld (gold),hl
        ret

fb_pos:     dw 0
price_b:    dw 50
price_m:    dw 50

; spawn a monster: DE = square address, A = type
; DE = square address, A = type: a new, awake monster there (if the
; square is free floor and a record is free)
spawn_mon:
        push ix
        call .go
        pop ix
        ret
.go:    ld (spn_type),a
        ld (spn_sq),de
        xor a
        ld (spn_ok),a
        ld hl,(ppos)
        or a
        sbc hl,de
        ret z                   ; not on the player
        ld a,(de)
        ld hl,passtab
        call add_a_hl
        ld a,(hl)
        or a
        ret z
        ld hl,MONMAP-MAP
        add hl,de
        ld a,(hl)
        or a
        ret nz                  ; taken
        ; a slot: a dead monster's, or a new one
        ld ix,MONS
        ld c,1
        ld a,(nmons)
        or a
        jr z,.new
        ld b,a
.f:     ld a,(ix+M_TYPE)
        cp $FF
        jr z,.use
        ld de,16
        add ix,de
        inc c
        djnz .f
.new:   ld a,(nmons)
        cp 16
        ret nc
        inc a
        ld (nmons),a
.use:   ld a,(spn_type)
        ld (ix+M_TYPE),a
        call mon_stats
        ld a,(hl)
        ld (ix+M_HP),a
        ld hl,(spn_sq)
        ld de,MAP
        or a
        sbc hl,de
        ld (ix+M_POS),l
        ld (ix+M_POS+1),h
        ld (ix+M_AWAKE),1
        ld (ix+M_TIMER),0
        ld de,MONMAP
        add hl,de
        ld (hl),c
        ld a,1
        ld (mt_moved),a
        ld (spn_ok),a
        ret

spn_ok:     db 0
spn_type:   db 0
spn_sq:     dw 0

; the Hollow King, badly hurt, calls his hounds (once): IX = the King
king_rage:
        ld a,(king_phase)
        or a
        ret nz
        ld a,(ix+M_HP)
        cp 50
        ret nc
        ld a,1
        ld (king_phase),a
        ld hl,sfx_gate
        call sfx
        ld hl,t_king_rage
        ld a,BMAGENTA
        call log_msgc
        ld l,(ix+M_POS)
        ld h,(ix+M_POS+1)
        ld de,MAP
        add hl,de
        ld (kr_sq),hl
        ld bc,$0208             ; two hounds, eight places to try
        ld hl,kr_dirs
.d:     ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl
        push bc
        ld hl,(kr_sq)
        add hl,de
        ex de,hl
        ld a,7                  ; an ash hound
        call spawn_mon
        pop bc
        pop hl
        ld a,(spn_ok)
        or a
        jr z,.n
        dec b
        ret z
.n:     dec c
        jr nz,.d
        ret

kr_sq:      dw 0
king_phase: db 0
; (hi, lo) of the squares around the King
kr_dirs:    db $FF,$E0, $00,$20, $FF,$FF, $00,$01, $FF,$DF, $FF,$E1, $00,$1F, $00,$21

; ---------------------------------------------------------------------
;  death and victory
; ---------------------------------------------------------------------
; -> C = end the game, NC = rise again
death:  call snd_quiet
        ld hl,mus_dirge
        call play_tune
        ld hl,t_dead1
        ld a,BRED
        call log_msgc
        ld hl,t_dead2
        ld a,YELLOW
        call log_msgc
        call ask_yn
        jr z,.rise
        ld hl,es_lose
        ld de,mus_dirge
        call end_screen
        scf
        ret
.rise:  xor a
        ld (dead),a
        ld a,(hpmax)
        ld (hp),a
        ld a,(mpmax)
        ld (mp),a
        ld hl,(gold)
        srl h
        rr l
        ld (gold),hl
        call state_save
        ld a,255                ; level 1: the start
        ld (arrive),a
        ld a,(level)
        or a
        jr z,.l1
        xor a                   ; deeper: the up stairs
        ld (arrive),a
.l1:    call enter_level
        ld hl,t_rise
        ld a,BGREEN
        call log_msgc
        or a
        ret

victory:
        ld hl,es_win
        ld de,mus_victory
        jp end_screen
