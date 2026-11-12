; =====================================================================
;  BOSS: drawn straight into the page from a bitmap pre-shifted 4 ways,
;  one glyph per cell in the page's boss bank (12 or 13), colours from
;  boss_pal (logical colours, so lights flash by changing the palette).
;  Stage 1: the COPYTRON 9000.
; =====================================================================
BS_ENTER    equ 0
BS_SPIT     equ 1
BS_SHOOT    equ 2
BS_WARN     equ 3
BS_FIRE     equ 4
BS_JAM      equ 5
BS_DIE      equ 6
BC_WARN     equ 4

boss_start:
        ld a,1
        ld (boss_on),a
        ld a,GS_BOSS
        ld (gstate),a
        ld hl,336
        ld (boss_x),hl
        ld a,32+70
        ld (boss_y),a
        xor a
        ld (boss_var),a
        ld (boss_st),a
        ld (boss_jam),a
        ld (boss_n),a
        ld (boss_flash),a
        ld hl,0
        ld (boss_t),hl
        ld a,(difficulty)
        ld e,a
        ld d,0
        ld hl,boss_hps
        add hl,de
        ld a,(hl)
        ld l,a
        ld h,0
        ld (boss_hp),hl
        ld (boss_hpmax),hl
        ld a,1
        ld (hud_dirty),a
        call stop_music
        ld hl,mus_boss_0
        ld de,mus_boss_1
        call play_music
        ld a,SFX_ALARM
        jp play_sfx
boss_hps:   db 36,48,64

; ---------------------------------------------------------------------
boss_update:
        ld a,(boss_on)
        or a
        ret z
        ld hl,(boss_t)
        inc hl
        ld (boss_t),hl
        ld a,(boss_flash)
        or a
        jr z,.f
        dec a
        ld (boss_flash),a
.f:     ld a,(boss_st)
        add a,a
        ld l,a
        ld h,0
        ld de,.jt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.jt:    dw cb_enter,cb_spit,cb_shoot,cb_warn,cb_fire,cb_jam,cb_die

cb_next:                        ; A = the next state
        ld (boss_st),a
        ld hl,0
        ld (boss_t),hl
        ret

cb_enter:
        ld hl,(boss_x)
        dec hl
        dec hl
        ld (boss_x),hl
        ld de,232
        or a
        sbc hl,de
        ret nz
        ld a,BS_SPIT
        jr cb_next

; follow the pilot up and down (slowly)
cb_bob: ld a,(py)
        sub 30
        cp 32
        jr nc,.a
        ld a,32
.a:     cp 32+104
        jr c,.b
        ld a,32+104
.b:     ld hl,boss_y
        cp (hl)
        ret z
        jr c,.u
        inc (hl)
        ret
.u:     dec (hl)
        ret

cb_spit:
        ld a,1
        ld (boss_var),a
        ld a,(boss_t)
        and 1
        call z,cb_bob
        ld a,(boss_t)
        and 7
        jr nz,.t
        ld a,SFX_SPIT
        call play_sfx
        ld hl,(boss_x)
        ld de,-4
        add hl,de
        ld a,(boss_y)
        add a,28
        ld c,a
        ld a,E_SWARM
        call en_new
        jr c,.t
        ld (ix+E_DXL),$60
        ld (ix+E_DXH),$FD       ; -2.6
.t:     ld a,(boss_t)
        cp 64
        ret c
        ld a,BS_SHOOT
        jr cb_next

cb_shoot:
        xor a
        ld (boss_var),a
        ld a,(boss_t)
        and 1
        call z,cb_bob
        ld a,(boss_t)
        and 15
        cp 8
        jr nz,.t
        ; both eyes fire
        ld hl,(boss_x)
        ld de,24
        add hl,de
        ld a,(boss_y)
        add a,26
        ld c,a
        call bullet_aimed
        ld a,(difficulty)
        or a
        jr z,.t
        ld hl,(boss_x)
        ld de,40
        add hl,de
        ld a,(boss_y)
        add a,26
        ld c,a
        call bullet_aimed
.t:     ld a,(boss_t)
        cp 48
        ret c
        ld a,(boss_jam)
        cp 3
        jr nc,.jam
        ld a,(boss_n)
        cp 3
        jr nc,.jam
        ld a,BS_WARN
        jp cb_next
.jam:   ld a,SFX_JAM
        call play_sfx
        ld a,BS_JAM
        jp cb_next

cb_warn:
        ld a,2
        ld (boss_var),a
        ld a,(boss_t)
        cp 24
        call c,cb_aim
        ld a,(boss_t)
        and 4
        ld a,RED
        jr z,.c
        ld a,YELLOW
.c:     ld (boss_pal+BC_WARN),a
        ld a,(boss_t)
        and 7
        ld a,SFX_ALARM
        call z,play_sfx
        ld a,1
        ld (warn_msg),a
        ld a,(boss_t)
        cp 40
        ret c
        ld a,RED
        ld (boss_pal+BC_WARN),a
        ld a,SFX_BEAM
        call play_sfx
        ld a,BS_FIRE
        jp cb_next
; line the mouth up with the pilot
cb_aim: ld a,(py)
        sub 34
        jp cb_bob.a

cb_fire:
        ld a,(boss_t)
        and 7
        ld a,SFX_BEAM
        call z,play_sfx
        ; the beam: mouth row, the whole way left
        ld a,(pdead)
        or a
        jr nz,.t
        ld a,(boss_y)
        add a,37
        ld b,a                  ; beam top
        ld a,(py)
        add a,9
        cp b
        jr c,.t
        ld a,b
        add a,6
        ld c,a
        ld a,(py)
        add a,4
        cp c
        jr nc,.t
        call hit_player
.t:     ld a,(boss_t)
        cp 30
        ret c
        xor a
        ld (warn_msg),a
        ld a,1
        ld (hud_dirty),a
        ld hl,boss_n
        inc (hl)
        ld a,BS_SPIT
        jp cb_next

cb_jam:
        ld a,3
        ld (boss_var),a
        ; it shakes and smokes
        ld a,(boss_t)
        and 1
        ld hl,(boss_x)
        jr z,.l
        inc hl
        inc hl
        jr .s
.l:     dec hl
        dec hl
.s:     ld (boss_x),hl
        ld a,(boss_t)
        and 15
        jr nz,.t
        ld hl,(boss_x)
        ld de,30
        add hl,de
        ld a,(boss_y)
        sub 8
        ld c,a
        call fx_boom
.t:     ld a,(boss_t)
        cp 80
        ret c
        ld hl,232
        ld (boss_x),hl
        xor a
        ld (boss_jam),a
        ld (boss_n),a
        ld a,BS_SPIT
        jp cb_next

cb_die: ld a,(boss_t)
        and 3
        jr nz,.t
        call random
        and 63
        ld e,a
        ld d,0
        ld hl,(boss_x)
        add hl,de
        push hl
        call random
        and 63
        ld c,a
        ld a,(boss_y)
        add a,c
        sub 8
        ld c,a
        pop hl
        call fx_boom
        ld a,SFX_BOOM
        call play_sfx
        ld a,(boss_t)
        and 8
        ld a,1
        jr z,.k
        xor a
.k:     ld (shake_off),a
.t:     ld a,(boss_t)
        cp 75
        ret c
        xor a
        ld (boss_on),a
        ld (shake_off),a
        ld a,GS_CLEAR
        ld (gstate),a
        ret

; ---------------------------------------------------------------------
; boss_hurt: E = damage
boss_hurt:
        ld a,(boss_st)
        cp BS_DIE
        ret z
        cp BS_ENTER
        ret z
        ld hl,(boss_hp)
        ld d,0
        or a
        sbc hl,de
        jr z,.dead
        jr c,.dead
        ld (boss_hp),hl
        ld a,3
        ld (boss_flash),a
        ld a,1
        ld (hud_dirty),a
        ld a,SFX_BOSSHIT
        jp play_sfx
.dead:  ld hl,0
        ld (boss_hp),hl
        ld a,1
        ld (hud_dirty),a
        ld de,$2000
        call add_score
        xor a
        ld (warn_msg),a
        ld a,BS_DIE
        jp cb_next

; the body: x+16..x+80, y+10..y+64 (half x biased by 8 like the shots)
; the jam: x+0..x+36, y+42..y+58 (only while jammed)
shot_boss:
        ld a,(boss_on)
        or a
        ret z
        ld hl,(boss_x)
        ld de,16+16
        add hl,de
        call .hx
        ld c,a                  ; body x0
        ld a,(sx1)
        cp c
        jr c,.jam
        ld a,(boss_y)
        add a,10
        ld c,a
        ld a,(sy1)
        cp c
        jr c,.jam
        add a,0
        ld a,(boss_y)
        add a,64
        ld c,a
        ld a,(sy0)
        cp c
        jr nc,.jam
        ; the body: shots are swallowed (beams go on)
        call .weak
        ret c
        ld a,(ix+0)
        cp ST_BEAM
        ret z
        ld (ix+0),0
        ld a,SFX_TINK
        jp play_sfx
.jam:   call .weak
        ret
; a hit on the jam? -> C (and the damage done)
.weak:  ld a,(boss_st)
        cp BS_JAM
        jr nz,.no
        ld hl,(boss_x)
        ld de,16
        add hl,de
        call .hx
        ld c,a
        ld a,(sx1)
        cp c
        jr c,.no
        ld a,c
        add a,18
        ld c,a
        ld a,(sx0)
        cp c
        jr nc,.no
        ld a,(boss_y)
        add a,42
        ld c,a
        ld a,(sy1)
        cp c
        jr c,.no
        ld a,c
        add a,16
        ld c,a
        ld a,(sy0)
        cp c
        jr nc,.no
        ld a,(ix+0)
        cp ST_BEAM
        jr nz,.nb
        ld a,(ix+6)
        and 3
        jr nz,.y                ; beams: every fourth frame
.nb:    cp ST_BOMB
        jr nz,.nbo
        call bomb_burst
        scf
        ret
.nbo:   ld a,(ix+0)
        cp ST_BEAM
        jr z,.d
        cp ST_RING
        jr z,.d
        ld (ix+0),0
.d:     ld e,(ix+7)
        call boss_hurt
.y:     scf
        ret
.no:    or a
        ret
.hx:    ld a,h
        or a
        ld a,255
        ret nz
        srl h
        rr l
        ld a,l
        ret

; boss_area: E = damage from a blast or a shout (half while not jammed)
boss_area:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_JAM
        jr z,.f
        srl e
        ret z
.f:     jp boss_hurt

; the pilot against the body
boss_touch:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_DIE
        ret z
        ld hl,(boss_x)
        ld de,16+16
        add hl,de
        call shot_boss.hx
        ld c,a
        ld a,(hx1)
        cp c
        ret c
        ld a,(boss_y)
        add a,12
        ld c,a
        ld a,(hy1)
        cp c
        ret c
        ld a,(boss_y)
        add a,62
        ld c,a
        ld a,(hy0)
        cp c
        ret nc
        jp hit_player

; ---------------------------------------------------------------------
; boss_draw: into the page being drawn (after the strips, before sprites)
; ---------------------------------------------------------------------
boss_draw:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_hdr)
        ld (bd_nc),a
        ld a,(boss_hdr+1)
        ld (bd_nr),a
        ld a,(boss_hdr+2)
        add a,16
        ld (bd_h),a
        ; the variant and shift
        ld hl,(boss_x)
        ld a,l
        and 6
        add a,a                 ; shift * 4
        ld c,a
        ld a,(boss_var)
        add a,a
        add a,a
        add a,a
        add a,a                 ; var * 16
        add a,c
        ld e,a
        ld d,0
        ld hl,boss_data
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (bd_ptr),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (bd_cm),de
        ; screen position
        ld hl,(boss_x)
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (bd_c),a             ; first column
        ld a,(boss_y)
        sub 24
        ld b,a
        and 7
        ld (bd_dy),a
        ld a,b
        rrca
        rrca
        rrca
        and $1F
        ld (bd_r),a             ; first row
        xor a
        ld (bd_k),a
        ld (bd_cnt),a
        ld a,(stg_hdr+H_BOSSB)
        call map_blk
        ld a,(rpage)
        add a,BK_BOSS+LV_SCREEN
        out (P_LV),a
        ; ---- each column, each row
        xor a
        ld (bd_ci),a
        ld hl,0
        ld (bd_coff),hl
        ld (bd_colc),hl
.col:   ld a,(bd_ci)
        ld hl,bd_c
        add a,(hl)
        cp 40
        jp nc,.ncol
        ld (tmp),a              ; screen column
        xor a
        ld (bd_ri),a
.row:   ld a,(bd_ri)
        ld hl,bd_r
        add a,(hl)
        cp PF_TOP
        jp c,.nrow
        cp PF_TOP+PF_ROWS
        jp nc,.nrow
        ld (tmp+1),a            ; screen row
        ; the colour: band r (dy <= 4) or r-1; else the other one
        ld a,(bd_dy)
        cp 5
        ld a,(bd_ri)
        jr c,.b0
        dec a
.b0:    call .ink
        jr nz,.has
        ld a,(bd_dy)
        or a
        jr z,.nrow
        cp 5
        ld a,(bd_ri)
        jr nc,.b1
        dec a
.b1:    call .ink
        jr z,.nrow
.has:   ld (tmp+2),a
        ld a,(bd_k)
        cp 120
        jr nc,.nrow
        ; the source: column c, line 8 + r*8 - dy
        ld a,(bd_ri)
        add a,a
        add a,a
        add a,a
        add a,8
        ld hl,bd_dy
        sub (hl)
        ld e,a
        ld d,0
        ld hl,(bd_ptr)
        add hl,de
        ld de,(bd_coff)
        add hl,de
        ; destination: glyph k of the boss bank
        ld a,(bd_k)
        or $80
        ld e,a
        ld d,$0F
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        REPT 8
        ldi
        ENDR
        ; the list: cell, k, colour
        ld a,(tmp+1)
        ld e,a
        ld a,(tmp)
        ld d,a
        call cell_of
        ex de,hl
        ld a,(bd_cnt)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld bc,SCRATCH
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(bd_k)
        ld (hl),a
        inc hl
        ld a,(tmp+2)
        ld (hl),a
        ld hl,bd_k
        inc (hl)
        ld hl,bd_cnt
        inc (hl)
.nrow:  ld hl,bd_ri
        inc (hl)
        ld a,(bd_nr)
        inc a
        cp (hl)
        jp nz,.row
.ncol:  ld hl,(bd_coff)
        ld a,(bd_h)
        ld e,a
        ld d,0
        add hl,de
        ld (bd_coff),hl
        ld hl,(bd_colc)
        ld a,(bd_nr)
        ld e,a
        add hl,de
        ld (bd_colc),hl
        ld hl,bd_ci
        inc (hl)
        ld a,(bd_nc)
        cp (hl)
        jp nz,.col
        ld a,LV_SCREEN
        out (P_LV),a
        jp boss_commit
; .ink: A = band -> A = logical colour of (column c, band), Z if none
.ink:   cp 128
        jr nc,.z
        ld hl,bd_nr
        cp (hl)
        jr nc,.z
        ld e,a
        ld d,0
        ld hl,(bd_cm)
        add hl,de
        ld de,(bd_colc)
        add hl,de
        ld a,(hl)
        or a
        ret
.z:     xor a
        ret

; write the listed boss cells into the page, list them for restoring
boss_commit:
        ld a,(bd_cnt)
        or a
        ret z
        ld a,(vpg)
        ld c,a
        ; codes
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(bd_cnt)
        ld b,a
        ld hl,SCRATCH
.c1:    ld e,(hl)
        inc hl
        ld a,(hl)
        add a,c
        ld d,a
        inc hl
        ld a,(hl)
        or $80
        ld (de),a
        inc hl
        inc hl
        djnz .c1
        ; banks
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(bd_cnt)
        ld b,a
        ld hl,SCRATCH
        ld a,(rpage)
        add a,BK_BOSS
        ld (tmp+5),a
.c2:    ld e,(hl)
        inc hl
        ld a,(hl)
        add a,c
        ld d,a
        inc hl
        inc hl
        inc hl
        ld a,(tmp+5)
        ld (de),a
        djnz .c2
        ; colours
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(bd_cnt)
        ld b,a
        ld hl,SCRATCH
.c3:    ld e,(hl)
        inc hl
        ld a,(hl)
        add a,c
        add a,8
        ld d,a
        inc hl
        inc hl
        ld a,(boss_flash)
        or a
        ld a,WHITE
        jr nz,.w
        push hl
        ld a,(hl)
        ld hl,boss_pal
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
.w:     ex af,af'
        ld a,(de)
        and $F0
        ld (tmp+6),a
        ex af,af'
        push hl
        ld hl,tmp+6
        or (hl)
        pop hl
        ld (de),a
        inc hl
        djnz .c3
        xor a
        out (P_COLCTL),a
        ; restore list
        ld a,(rpage)
        or a
        ld de,BL0
        jr z,.p0
        ld de,BL1
.p0:    ld a,(bd_cnt)
        ld b,a
        ld (blcnt_tmp),a
        ld hl,SCRATCH
.c4:    ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        add a,c
        ld (de),a
        inc de
        inc hl
        inc hl
        inc hl
        djnz .c4
        ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,blcnt
        add hl,de
        ld a,(blcnt_tmp)
        ld (hl),a
        ret
blcnt_tmp:  db 0
bd_colc:    dw 0
bd_coff:    dw 0
bd_ci:      db 0
bd_ri:      db 0

; the toner beam (drawn with the small objects)
draw_boss_objs:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_FIRE
        ret nz
        ld a,(boss_y)
        add a,37-24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(ticks)
        and 2
        ld a,BMAGENTA
        jr z,.c
        ld a,WHITE
.c:     ld (spr_ink),a
        ld hl,(boss_x)
        ld de,16
        add hl,de
        ld a,l
        and $F8
        ld l,a
.l:     ld (spr_x),hl
        push hl
        ld a,K_TONER
        call obj_draw
        pop hl
        ld de,-8
        add hl,de
        bit 7,h
        jr z,.l
        ret
