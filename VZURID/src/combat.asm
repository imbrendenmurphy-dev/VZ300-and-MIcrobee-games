; =====================================================================
;  Phase 2: player state, hull damage, waves, turrets, enemy fire, HUD
; =====================================================================

; ---- (re)start a game: all gameplay state -----------------------------
game_reset:
            ld hl,ENM
            ld de,ENM+1
            ld bc,59
            ld (hl),0
            ldir
            ld hl,BUL
            ld de,BUL+1
            ld bc,23
            ld (hl),0
            ldir
            ld hl,0
            ld (score),hl
            ld a,3
            ld (lives),a
            ld a,MAXE
            ld (energy),a
            ld a,90
            ld (invuln),a
            xor a
            ld (pstate),a
            ld (ptimer),a
            ld (waveTimer),a
            ld (waveNo),a
            ld a,32
            ld (shipY),a
            ld hl,TURALIVE
            ld de,TURALIVE+1
            ld bc,NTUR-1
            ld (hl),1
            ldir
            ret

; ---- player state machine (replaces a bare call to flight) -----------
player_update:
            ld a,(pstate)
            or a
            jr z,.play
            cp 1
            jr z,.dying
.over:      ld a,(ptimer)
            cp 90
            jr nc,.chk
            inc a
            ld (ptimer),a
            jr .coast
.chk:       ld a,(inbits)
            bit 4,a
            jr z,.coast
            call game_reset
            ld a,2
            ld (hudmsg),a
            ret
.coast:     xor a
            ld (inbits),a
            jp flight
.dying:     ld a,(ptimer)
            dec a
            ld (ptimer),a
            jr nz,.coast
            ld a,(lives)
            dec a
            ld (lives),a
            jr z,.gameover
            ld a,MAXE
            ld (energy),a
            ld a,120
            ld (invuln),a
            xor a
            ld (pstate),a
            ld a,32
            ld (shipY),a
            ld hl,EBUL
            ld de,EBUL+1
            ld bc,11
            ld (hl),0
            ldir
            jr .coast
.gameover:  ld a,2
            ld (pstate),a
            xor a
            ld (ptimer),a
            ld a,1
            ld (hudmsg),a
            jr .coast
.play:      call flight
            ld a,(invuln)
            or a
            jr z,.nv
            dec a
            ld (invuln),a
.nv:        jp hull_check

hurt_player:
            ld a,(invuln)
            or a
            ret nz
            ld a,(pstate)
            or a
            ret nz
            ld a,(energy)
            dec a
            ld (energy),a
            jr z,.die
            ld a,60
            ld (invuln),a
            ret
.die:       ld a,1
            ld (pstate),a
            ld a,36
            ld (ptimer),a
            ret

; ---- raised hull blocks hurt and throw the ship back ------------------
hull_check:
            ld a,(frameCnt)
            and 1
            ret nz                  ; every other frame is plenty
            ld a,(invuln)
            or a
            ret nz
            ld a,(shipY)
            add a,3-16
            rrca
            rrca
            rrca
            and 7
            ld (hc_row),a
            ld b,3
            ld ix,HCX
.pt:        push bc
            ld hl,(posX)
            ld a,(shipXs)
            add a,(ix+0)
            ld e,a
            ld d,0
            add hl,de
            ld de,1536
            or a
            sbc hl,de
            jr nc,.w
            add hl,de
.w:         srl h
            rr l
            srl h
            rr l
            srl h
            rr l                    ; HL = tile column
            ld d,h
            ld e,l
            add hl,hl
            add hl,de
            add hl,hl               ; *6
            ld a,(hc_row)
            ld e,a
            ld d,0
            add hl,de
            ld de,HULLMAP
            add hl,de
            ld e,(hl)
            ld d,0
            ld hl,SOLID
            add hl,de
            ld a,(hl)
            pop bc
            or a
            jr nz,.hit
            inc ix
            djnz .pt
            ret
.hit:       call hurt_player
            ld a,(flipF)
            cp 4
            ld hl,-384
            jr c,.kb
            ld hl,384
.kb:        ld (speed),hl
            ret
HCX:        db 3,8,13

; ---- enemies / enemy bullets touching the ship ------------------------
player_hits:
            ld a,(invuln)
            or a
            ret nz
            ld a,(pstate)
            or a
            ret nz
            ld ix,ENM
            ld b,4
.el:        ld a,(ix+0)
            cp 1
            jr nz,.ne
            ld a,(ix+7)
            cp $7F
            jr z,.ne
            ld a,(shipXs)
            ld e,a
            ld d,0
            ld l,(ix+6)
            ld h,(ix+7)
            or a
            sbc hl,de               ; dx = sx - shipXs
            ld de,10
            ld c,24
            ld a,(ix+8)
            or a
            jr z,.wa
            ld de,6
            ld c,20
.wa:        add hl,de
            ld a,h
            or a
            jr nz,.ne
            ld a,l
            cp c
            jr nc,.ne
            ld d,6
            ld e,13
            ld a,(ix+8)
            or a
            jr z,.ya
            ld d,5
            ld e,12
.ya:        ld a,(ix+3)
            ld hl,shipY
            sub (hl)
            add a,d
            cp e
            jr nc,.ne
            ld (ix+0),2
            call hurt_player
            ld hl,(score)
            inc hl
            ld (score),hl
            ret
.ne:        ld de,10
            add ix,de
            djnz .el
            ld ix,EBUL
            ld b,3
.bl:        ld a,(ix+0)
            or a
            jr z,.bn
            ld a,(ix+1)
            ld hl,shipXs
            sub (hl)
            sub 14
            cp 17
            jr nc,.bn
            ld a,(ix+2)
            ld hl,shipY
            sub (hl)
            inc a
            cp 7
            jr nc,.bn
            ld (ix+0),0
            jp hurt_player
.bn:        ld de,4
            add ix,de
            djnz .bl
            ret

; ---- enemy bullets (4 bytes: active, x+16, y, packed (vx+2)<<4|(vy+2)) --
ebul_update:
            ld ix,EBUL
            ld b,3
.lp:        ld a,(ix+0)
            or a
            jr z,.nx
            ld c,(ix+3)
            ld a,c
            rrca
            rrca
            rrca
            rrca
            and 15
            sub 2
            add a,(ix+1)
            ld (ix+1),a
            cp 2
            jr c,.kill
            cp 146
            jr nc,.kill
            ld a,c
            and 15
            sub 2
            add a,(ix+2)
            ld (ix+2),a
            cp 16
            jr c,.kill
            cp 62
            jr c,.nx
.kill:      ld (ix+0),0
.nx:        ld de,4
            add ix,de
            djnz .lp
            ret

; aimed shot at the ship.  C = source x (screen px), B = source y
fire_aimed:
            push ix
            call fire_aimed_in
            pop ix
            ret
fire_aimed_in:
            ld a,c
            ld (fa_x),a
            ld a,b
            ld (fa_y),a
            ld ix,EBUL
            ld de,4
            ld b,3
.f:         ld a,(ix+0)
            or a
            jr z,.got
            add ix,de
            djnz .f
            ret
.got:       ld a,(shipXs)
            add a,8
            ld hl,fa_x
            sub (hl)
            ld d,a                  ; dx
            ld a,(shipY)
            add a,3
            ld hl,fa_y
            sub (hl)
            ld e,a                  ; dy
            ld a,d
            ld l,1
            bit 7,a
            jr z,.dxp
            neg
            ld l,$FF
.dxp:       ld h,a                  ; H = |dx|, L = sign
            ld a,e
            ld c,1
            bit 7,a
            jr z,.dyp
            neg
            ld c,$FF
.dyp:       ld b,a                  ; B = |dy|, C = sign
            add a,a                 ; 2|dy|
            cp h
            jr z,.hor
            jr c,.hor
            ld a,h
            add a,a
            cp b
            jr z,.ver
            jr c,.ver
            ld a,l                  ; diagonal
            ld d,a
            ld a,c
            jr .pack
.hor:       ld a,l
            add a,a
            ld d,a
            xor a
            jr .pack
.ver:       ld d,0
            ld a,c
            add a,a
.pack:      add a,2
            ld e,a
            ld a,d
            add a,2
            rlca
            rlca
            rlca
            rlca
            or e
            ld (ix+3),a
            ld a,(fa_x)
            add a,16
            ld (ix+1),a
            ld a,(fa_y)
            ld (ix+2),a
            ld (ix+0),1
            ret

; ---- enemies (10 bytes: state, wx(2), y, vx, vy, sx(2), type, aux) ----
;  slots 0-3 mobile (type 0 drifter, 1 diver), slots 4-5 gun turrets
enemies_update:
            ld ix,ENM
            ld b,NENM
.lp:        push bc
            ld a,(ix+0)
            cp 1
            jr z,.alive
            or a
            jr z,.next
            inc a
            ld (ix+0),a
            cp 14
            jr c,.expsx
            ld (ix+0),0
            ld a,(ix+8)
            cp 2
            jr nz,.next
            ld e,(ix+9)
            ld d,0
            ld hl,TURALIVE
            add hl,de
            ld (hl),0
            jr .next
.expsx:     call enemy_sx
            jr .next
.alive:     ld a,(ix+8)
            cp 2
            jr nz,.mob
            call turret_tick
            jr .next
.mob:       ld e,(ix+4)
            ld d,0
            bit 7,e
            jr z,.vp
            ld d,$FF
.vp:        ld l,(ix+1)
            ld h,(ix+2)
            add hl,de
            call wrap1536
            ld (ix+1),l
            ld (ix+2),h
            ld a,(ix+3)
            add a,(ix+5)
            ld (ix+3),a
            cp 16
            jr c,.flipv
            cp 57
            jr c,.sx
.flipv:     ld a,(ix+5)
            neg
            ld (ix+5),a
            ld a,(ix+3)
            add a,(ix+5)
            add a,(ix+5)
            ld (ix+3),a
.sx:        call enemy_sx
            ld a,(ix+8)
            or a
            call nz,diver_ai
.next:      ld de,10
            add ix,de
            pop bc
            dec b
            jp nz,.lp
            ret

; diver: home in on the ship every 8 frames and fire now and then
diver_ai:
            ld a,(frameCnt)
            and 7
            ret nz
            ld a,(shipY)
            sub (ix+3)
            ld c,0
            jr z,.vy
            ld c,1
            jr nc,.vy
            ld c,$FF
.vy:        ld (ix+5),c
            ld hl,(posX)
            ld a,(shipXs)
            add a,8
            ld e,a
            ld d,0
            add hl,de
            ld e,(ix+1)
            ld d,(ix+2)
            or a
            sbc hl,de
            jr nc,.pos
            ld de,1536
            add hl,de
.pos:       ld de,1536
            or a
            sbc hl,de
            jr nc,.w
            add hl,de
.w:         ld de,768
            or a
            sbc hl,de
            ld c,1
            jr c,.vx
            ld c,$FF
.vx:        ld (ix+4),c
            ld a,(ix+7)
            or a
            ret nz
            ld a,(ix+6)
            cp 8
            ret c
            cp 112
            ret nc
            call rnd
            and 7
            ret nz
            ld a,(ix+6)
            add a,4
            ld c,a
            ld b,(ix+3)
            inc b
            jp fire_aimed

; gun turret (IX): despawn when far away, fire when on screen
turret_tick:
            call enemy_sx
            ld l,(ix+1)
            ld h,(ix+2)
            ld de,(posX)
            or a
            sbc hl,de
            jr nc,.p
            ld de,1536
            add hl,de
.p:         ld de,200
            or a
            sbc hl,de
            jr c,.keep
            ld de,1480-200
            or a
            sbc hl,de
            jr nc,.keep
            ld (ix+0),0             ; far away: free the slot (turret stays alive)
            ret
.keep:      ld a,(ix+5)
            or a
            jr z,.rdy
            dec a
            ld (ix+5),a
            ret
.rdy:       ld a,(ix+7)
            or a
            ret nz
            ld a,(ix+6)
            cp 4
            ret c
            cp 120
            ret nc
            ld a,(pstate)
            or a
            ret nz
.shoot:     call rnd
            and 31
            add a,70
            ld (ix+5),a
            ld a,(ix+6)
            add a,2
            ld c,a
            ld b,(ix+3)
            inc b
            jp fire_aimed

; bring turrets into the two turret slots as they scroll into range
turret_spawn:
            ld ix,ENM+40
            ld a,(ix+0)
            or a
            jr z,.slot
            ld ix,ENM+50
            ld a,(ix+0)
            or a
            ret nz
.slot:      ld a,(tcursor)
            ld c,a
            inc a
            cp NTUR
            jr c,.nw
            xor a
.nw:        ld (tcursor),a
            ld e,c
            ld d,0
            ld hl,TURALIVE
            add hl,de
            ld a,(hl)
            or a
            ret z
            ld a,(ENM+40)
            or a
            jr z,.n1
            ld a,(ENM+49)
            cp c
            ret z
.n1:        ld a,(ENM+50)
            or a
            jr z,.n2
            ld a,(ENM+59)
            cp c
            ret z
.n2:        ld l,c
            ld h,0
            add hl,hl
            add hl,hl
            ld de,TURLIST
            add hl,de
            push hl
            pop iy
            ld e,(iy+0)
            ld d,(iy+1)
            ld hl,(posX)
            ex de,hl
            or a
            sbc hl,de
            jr nc,.q
            ld de,1536
            add hl,de
.q:         ld de,128
            or a
            sbc hl,de
            jr c,.none
            ld de,48
            or a
            sbc hl,de
            jr c,.spawn
            ld de,1480-176
            or a
            sbc hl,de
            jr c,.none
            ld de,48
            or a
            sbc hl,de
            jr nc,.none
.spawn:     ld a,c
            ld (ix+9),a
            ld a,(iy+0)
            ld (ix+1),a
            ld a,(iy+1)
            ld (ix+2),a
            ld a,(iy+2)
            ld (ix+3),a
            ld a,2
            ld (ix+4),a             ; armour: three hits to destroy
            call rnd
            and 31
            add a,30
            ld (ix+5),a
            ld (ix+8),2
            ld (ix+0),1
.none:      ret

; ---- formation waves ---------------------------------------------------
wave_update:
            ld ix,ENM
            ld b,4
            ld de,10
.c:         ld a,(ix+0)
            or a
            ret nz
            add ix,de
            djnz .c
            ld a,(waveTimer)
            inc a
            ld (waveTimer),a
            cp 60
            ret c
            xor a
            ld (waveTimer),a
            ld a,(waveNo)
            and 3
            add a,a
            add a,a
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,FORM
            add hl,de
            push hl
            pop iy
            ld a,(flipF)
            cp 4
            ld a,0
            jr c,.r
            inc a
.r:         ld (wv_dir),a
            ld hl,(posX)
            ld de,144
            or a
            jr z,.fr
            ld de,-36
.fr:        add hl,de
            call wrap1536
            ld (wv_base),hl
            ld ix,ENM
            ld b,4
.m:         push bc
            ld c,(iy+0)
            ld b,0
            ld hl,(wv_base)
            ld a,(wv_dir)
            or a
            jr nz,.l
            add hl,bc
            jr .w
.l:         sbc hl,bc
.w:         call wrap1536
            ld (ix+1),l
            ld (ix+2),h
            ld a,(iy+1)
            ld (ix+3),a
            ld a,(iy+2)
            ld (ix+8),a
            ld a,(iy+3)
            ld (ix+5),a
            ld a,(wv_dir)
            or a
            ld a,$FF
            jr z,.vx
            ld a,1
.vx:        ld (ix+4),a
            ld (ix+0),1
            ld de,10
            add ix,de
            ld bc,4
            add iy,bc
            pop bc
            djnz .m
            ld hl,waveNo
            inc (hl)
            ret

; members: dx, y, type, vy
FORM:       db 0,24,0,1,   24,24,0,1,  48,24,0,1,  72,24,0,1
            db 0,36,0,0,   14,28,0,0,  14,44,0,0,  28,36,0,0
            db 0,20,1,0,   20,30,1,0,  40,40,1,0,  60,30,0,1
            db 0,18,0,1,   10,28,0,-1, 20,38,0,1,  30,48,0,-1
SCTAB:      db 1,2,5

; ---- score for killing the enemy at IX -------------------------------
add_score:
            ld e,(ix+8)
            ld d,0
            ld hl,SCTAB
            add hl,de
            ld e,(hl)
            ld hl,(score)
            add hl,de
            ld (score),hl
            ret

; =====================================================================
;  HUD  (16 rows: score / lives / wave on row A, energy bar + timing on B)
; =====================================================================
status_static:
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,32*15-1
            ld (hl),$AA
            ldir
            ld hl,VRAM+15*32
            ld de,VRAM+15*32+1
            ld bc,31
            ld (hl),$55
            ldir
            ld hl,VRAM+2*32
            ld (pc_row),hl
            ld hl,TXT_SC
            ld c,0
            call putstr
            ld hl,TXT_LV
            ld c,9
            call putstr
            ld hl,TXT_WV
            ld c,14
            call putstr
            ld hl,VRAM+9*32
            ld (pc_row),hl
            ld hl,TXT_EN
            ld c,0
            call putstr
            ld hl,TXT_SL
            ld c,15
            call putstr
            ld hl,TXT_LT
            ld c,22
            call putstr
            jp hud_all

hud_all:
            ld hl,shSc
            ld de,shSc+1
            ld bc,9
            ld (hl),$FF
            ldir
            call hud_sc
            call hud_en
            call hud_sl
            call hud_lt
            jp hud_lvwv

hud_sc:     ld hl,(score)
            ld de,(shSc)
            or a
            sbc hl,de
            ret z
            ld hl,(score)
            ld (shSc),hl
            ld hl,VRAM+2*32
            ld (pc_row),hl
            ld hl,(score)
            ld c,2
            call putdec4
            ld a,1
            jp putchar

hud_lvwv:   ld a,(lives)
            ld hl,shLv
            cp (hl)
            jr z,.wv
            ld (hl),a
            ld hl,VRAM+2*32
            ld (pc_row),hl
            inc a
            ld c,11
            call putchar
.wv:        ld a,(waveNo)
            ld hl,shWv
            cp (hl)
            ret z
            ld (hl),a
            ld hl,VRAM+2*32
            ld (pc_row),hl
            ld l,a
            ld h,0
            ld c,16
            jp putdec4

hud_sl:     ld hl,(minSlack)
            ld a,h
            cp $27
            jr c,.ok
            ld hl,9999
.ok:        ld de,(shSl)
            or a
            sbc hl,de
            ret z
            ld hl,(minSlack)
            ld a,h
            cp $27
            jr c,.ok2
            ld hl,9999
.ok2:       ld (shSl),hl
            ld de,VRAM+9*32
            ld (pc_row),de
            ld c,17
            jp putdec4

hud_lt:     ld hl,(lateCnt)
            ld a,h
            cp $27
            jr c,.ok
            ld hl,9999
.ok:        ld de,(shLt)
            or a
            sbc hl,de
            ret z
            ld hl,(lateCnt)
            ld a,h
            cp $27
            jr c,.ok2
            ld hl,9999
.ok2:       ld (shLt),hl
            ld de,VRAM+9*32
            ld (pc_row),de
            ld c,24
            jp putdec4

hud_msg_over:
            ld hl,VRAM+2*32
            ld (pc_row),hl
            ld hl,TXT_GAMEOVER
            ld c,21
            jp putstr
hud_msg_clear:
            ld hl,VRAM+2*32
            ld (pc_row),hl
            ld hl,TXT_BLANK
            ld c,21
            jp putstr

; energy bar: 5 pips of 2 bytes x 5 rows
hud_en:
            ld a,(energy)
            ld hl,shEn
            cp (hl)
            ret z
            ld (hl),a
            ld e,a
            ld c,$00
            cp 4
            jr nc,.cl
            ld c,$55
            cp 2
            jr nc,.cl
            ld c,$FF
.cl:        ld hl,VRAM+9*32+3
            ld d,0
.pip:       ld a,d
            cp e
            ld a,c
            jr c,.fill
            ld a,$AA
.fill:      ld b,a
            and $FC
            or 2
            push hl
            push de
            ld de,32
            ld (hl),b
            inc hl
            ld (hl),a
            dec hl
            add hl,de
            ld (hl),b
            inc hl
            ld (hl),a
            dec hl
            add hl,de
            ld (hl),b
            inc hl
            ld (hl),a
            dec hl
            add hl,de
            ld (hl),b
            inc hl
            ld (hl),a
            dec hl
            add hl,de
            ld (hl),b
            inc hl
            ld (hl),a
            dec hl
            add hl,de
            pop de
            pop hl
            inc hl
            inc hl
            inc d
            ld a,d
            cp MAXE
            jr nz,.pip
            ret

status_update:
            ld a,(hudmsg)
            or a
            jr z,.nomsg
            ld b,a
            xor a
            ld (hudmsg),a
            ld a,b
            cp 1
            jp z,hud_msg_over
            call hud_msg_clear
            jp hud_all
.nomsg:     ld hl,(frameCnt)
            ld a,l
            cp 12
            jr nz,.nr
            ld a,h
            or a
            jr nz,.nr
            ld hl,$FFFF             ; forget warm-up frames
            ld (minSlack),hl
            ld hl,0
            ld (lateCnt),hl
.nr:        ld a,(frameCnt)
            and 3
            ret nz
            ld a,(frameCnt)
            rrca
            rrca
            and 7
            add a,a
            ld e,a
            ld d,0
            ld hl,HUDJT
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)
            ex de,hl
            jp (hl)
HUDJT:      dw hud_sc,hud_en,hud_sl,hud_en,hud_sc,hud_en,hud_lt,hud_lvwv
