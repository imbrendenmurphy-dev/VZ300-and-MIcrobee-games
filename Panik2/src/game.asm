; =====================================================================
;  PANIK 2 - gameplay
;  Five floors (girder tops at rows 17,28,39,50,61), 16 slots of 8 px.
;  Dig a hole in front of you (SPACE), an alien walks in and is trapped,
;  bash it (SPACE again) and it drops through.  GRUBs die from a 1-floor
;  drop, BRUTEs need 2 floors, KINGs 3: line up holes for long drops.
; =====================================================================
; alien record (16 bytes)
AL_ST   equ 0
AL_TYPE equ 1                   ; 0 grub 1 brute 2 king
AL_X    equ 2
AL_Y    equ 3
AL_FL   equ 4                   ; floor (climbing: destination floor)
AL_DIR  equ 5                   ; walking: 0 right 1 left ; climbing: 0 down 1 up
AL_ACC  equ 6
AL_TIM  equ 7
AL_HP   equ 8
AL_DROP equ 9
AL_ANG  equ 10
AL_SLOT equ 11
AL_COOL equ 12
AL_ANIM equ 13
AS_FREE equ 0
AS_SPARK equ 1
AS_WALK equ 2
AS_CLIMB equ 3
AS_TRAP equ 4
AS_FALL equ 5
AS_STUN equ 6
AS_DIE  equ 7
NAL     equ 6
PS_WALK equ 0
PS_CLIMB equ 1
PS_DIG  equ 2
O2MAX   equ 96
; items
IT_O2   equ 1
IT_BOOT equ 2
IT_DRILL equ 3
IT_FREEZE equ 4
IT_GEM  equ 5
; popup strings
P_100 equ 0
P_200 equ 1
P_400 equ 2
P_800 equ 3
P_300 equ 4
P_600 equ 5
P_1200 equ 6
P_2400 equ 7
P_1600 equ 8
P_3200 equ 9
P_6400 equ 10
P_1000 equ 11
P_500 equ 12
P_2000 equ 13
P_5000 equ 14
P_1UP equ 15
P_O2  equ 16

flytab:  db 9,20,31,42,53       ; sprite y for a character standing on floor k
gtoptab: db 17,28,39,50,61      ; girder top row of floor k

; ---------------------------------------------------------------------
; setup_level: read the stage, compose the playfield, reset everybody
; ---------------------------------------------------------------------
setup_level:
        ld a,(level)
        ld c,0
.w:     cp 5
        jr c,.wd
        sub 5
        inc c
        jr .w
.wd:    ld a,c
        cp 4
        jr c,.w4
        ld a,3
.w4:    ld (world),a
        ld a,(level)
        add a,a
        ld l,a
        ld h,0
        ld de,stagetab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (lvptr),hl
        inc hl
        inc hl
        ld de,lv_ng
        ld bc,8
        ldir
        push hl
        ld a,(lv_max)           ; at most 5 aliens on screen (vblank budget)
        cp 6
        jr c,.mx
        ld a,5
        ld (lv_max),a
.mx:
        ; lap 2+: faster aliens, keener chasing, shorter traps
        ld a,(lap)
        ld b,a
        ld a,(lv_speed)
        inc b
.lp:    dec b
        jr z,.lpd
        add a,24
        jr nc,.lp
        ld a,240
        jr .lp
.lpd:   cp 241
        jr c,.sp
        ld a,240
.sp:    ld (lv_speed),a
        ld a,(world)
        ld b,a
        add a,a
        add a,b                 ; *3
        ld b,a
        add a,a
        add a,a
        add a,a                 ; *24
        add a,b                 ; *27
        add a,90
        ld b,a
        ld a,(lap)
        or a
        ld a,b
        jr z,.ch
        add a,40
        jr nc,.ch
        ld a,230
.ch:    ld (lv_chase),a
        ld a,(world)
        add a,a
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b                 ; *20
        ld b,a
        ld a,230
        sub b
        ld b,a
        ld a,(lap)
        or a
        ld a,b
        jr z,.tr
        sub 30
.tr:    ld (lv_trap),a
        pop hl
        ; floors and ladders
        ld de,FLT
        ld bc,64
        ldir
        ld de,LAD
        ld bc,64
        ldir
        ld hl,HOLES
        ld de,HOLES+1
        ld bc,127
        ld (hl),0
        ldir
        ; spawn order: grubs, brutes, kings, then shuffled (first stays a grub)
        ld hl,SPAWN
        ld a,(lv_ng)
        ld c,0
        call setup_fill
        ld a,(lv_nb)
        ld c,1
        call setup_fill
        ld a,(lv_nk)
        ld c,2
        call setup_fill
        ld a,(lv_ng)
        ld b,a
        ld a,(lv_nb)
        add a,b
        ld b,a
        ld a,(lv_nk)
        add a,b
        ld (total),a
        cp 3
        jr c,.nos
        ld (cnt),a
        ld c,1
.sh:    push bc
        ld a,(cnt)
        dec a
        ld b,a
        call rand_n
        inc a                   ; 1..total-1
        pop bc
        ld l,a
        ld h,SPAWN/256
        ld e,c
        ld d,h
        ld a,(de)
        ld b,(hl)
        ld (hl),a
        ld a,b
        ld (de),a
        inc c
        ld a,(cnt)
        cp c
        jr nz,.sh
.nos:   ; gems to find (gem dig)
        ld hl,FLT
        ld bc,$4000
.gc:    ld a,(hl)
        cp 2
        jr nz,.gn
        inc c
.gn:    inc hl
        djnz .gc
        ld a,c
        ld (gems_left),a
        xor a
        ld (spawned),a
        ld (killed),a
        ld (alive),a
        ld (gemval),a
        ld a,50
        ld (spawncool),a
        ; palette
        call world_ptr
        ld de,16
        add hl,de
        ld a,(hl)
        or a
        ld a,MODE1
        jr z,.pc
        ld a,MODE1|CSS1
.pc:    ld (palbase),a
        ; compose the playfield in CLEAN
        call dl_reset
        call do_frame
        ld a,(world)
        add a,a
        ld l,a
        ld h,0
        ld de,backdrops
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,CLEAN
        call unpack
        ld a,1
        ld (noq),a
        ld b,0
.gf:    ld c,0
.gs:    push bc
        call draw_slot
        pop bc
        inc c
        ld a,c
        cp 16
        jr nz,.gs
        inc b
        ld a,b
        cp 5
        jr nz,.gf
        ld b,0
.lf:    ld c,0
.ls:    push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        add a,LAD&255
        ld l,a
        ld h,LAD/256
        ld a,(hl)
        or a
        call nz,draw_ladder
        pop bc
        inc c
        ld a,c
        cp 16
        jr nz,.ls
        inc b
        ld a,b
        cp 4
        jr nz,.lf
        xor a
        ld (noq),a
        ld hl,CLEAN
        ld de,BGBUF
        ld bc,2048
        ldir
        xor a
        ld (result),a
        ld (combo),a
        ld (labeltim),a
        ld (labelheld),a
        ld hl,500
        ld (itemcool),hl
        call reset_player
        call init_popups
        call hud_full
        ld a,(demo)
        or a
        ret z
        ld hl,s_demo
        jp hud_label_hold
s_demo: db "    DEMO",0
setup_fill:
        or a
        ret z
        ld b,a
.f1:    ld (hl),c
        inc hl
        djnz .f1
        ret

; HL = this world's tile table entry (18 bytes)
world_ptr:
        ld a,(world)
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl               ; *16
        add hl,de               ; *18
        ld de,worldtab
        add hl,de
        ret

; reset_player: at the bottom, full oxygen, no aliens on screen
reset_player:
        ld hl,53*256+56
        ld (px),hl
        ld a,4
        ld (pfl),a
        xor a
        ld (pst),a
        ld (pdir),a
        ld (pdig),a
        ld (freeze),a
        ld (hurry),a
        ld (itemk),a
        ld (aiclimb),a
        ld hl,0
        ld (boots),hl
        ld (drill),hl
        ld a,O2MAX
        ld (o2),a
        ld a,(lv_o2)
        ld (o2cnt),a
        ld hl,aliens
        ld de,aliens+1
        ld bc,16*NAL-1
        ld (hl),0
        ldir
        ld a,(killed)
        ld (spawned),a
        xor a
        ld (alive),a
        ld a,60
        ld (spawncool),a
        ret

respawn:
        ; trapped aliens leave their holes
        ld hl,HOLES
        ld b,64
.h:     ld a,(hl)
        and $7F
        ld (hl),a
        inc hl
        djnz .h
        call reset_player
        xor a
        ld (result),a           ; the death is dealt with: play on
        ld (pdig),a
        ld (prep),a
        ld a,100
        ld (invuln),a
        call hud_o2
        jp hud_count

; ---------------------------------------------------------------------
; draw_slot: B = floor, C = slot -> CLEAN + BG (+ queue unless noq)
; ---------------------------------------------------------------------
draw_slot:
        push bc
        call world_ptr          ; HL = girder tile
        ex de,hl
        pop bc
        xor a
        ld (tmpd),a             ; gem flag
        ld (tmpx),a             ; hole state
        ld a,b
        cp 4
        jr nc,.ok
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,HOLES/256
        ld a,(hl)
        and $7F
        ld (tmpx),a
        ld a,l
        add a,FLT&255
        ld l,a
        ld a,(hl)
        cp 1
        jr nz,.ng
        ld hl,6
        add hl,de
        ex de,hl                ; steel tile
        jr .ok
.ng:    cp 2
        jr nz,.ok
        ld (tmpd),a
.ok:    ld a,b    ; HL = CLEAN address of the slot's girder top
        push bc
        ld hl,gtoptab
        add a,l
        ld l,a
        jr nc,.g1
        inc h
.g1:    ld a,(hl)
        ld (tmpy),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        add a,a
        add a,l
        ld l,a
        ld a,h
        add a,CLEAN/256
        ld h,a
        ; mask table for the hole state
        ld a,(tmpx)
        add a,a
        ld b,a
        add a,a
        add a,b                 ; *6
        push hl
        ld hl,holemask
        add a,l
        ld l,a
        jr nc,.m1
        inc h
.m1:    ld b,h
        ld c,l                  ; BC = masks
        pop hl
        ld a,3
        ld (cnt),a
.row:   ld a,(bc)
        push bc
        ld b,a
        ld a,(de)
        and b
        ld (hl),a
        pop bc
        inc bc
        inc de
        inc hl
        ld a,(bc)
        push bc
        ld b,a
        ld a,(de)
        and b
        ld (hl),a
        pop bc
        inc bc
        inc de
        dec hl
        ; gem sparkle in the middle row (only while still buried)
        ld a,(cnt)
        cp 2
        jr nz,.nogem
        ld a,(tmpd)
        or a
        jr z,.nogem
        ld a,(tmpx)
        or a
        jr nz,.nogem
        ld a,(hl)
        and $FC
        or $03
        ld (hl),a
        inc hl
        ld a,(hl)
        and $3F
        or $C0
        ld (hl),a
        dec hl
.nogem: push de
        ld de,32
        add hl,de
        pop de
        ld a,(cnt)
        dec a
        ld (cnt),a
        jr nz,.row
        pop bc
        ; copy CLEAN -> BG and queue
        ld a,c
        add a,a
        ld d,a
        ld a,(tmpy)
        ld e,a
        ld bc,$0203
        jp restore_rect
holemask:
        db $FF,$FF,$FF,$FF,$FF,$FF
        db $F0,$0F,$FF,$FF,$FF,$FF
        db $C0,$03,$C0,$03,$FF,$FF
        db $00,$00,$00,$00,$00,$00

; draw_ladder: B = k (between floor k and k+1), C = slot (CLEAN only)
draw_ladder:
        push bc
        call world_ptr
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; rails
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; rungs
        ld (wbuf),de
        ld (wbuf+2),hl
        pop bc
        ld a,b
        ld hl,gtoptab
        add a,l
        ld l,a
        jr nc,.g
        inc h
.g:     ld a,(hl)
        ld (tmpy),a             ; top girder row
        inc hl
        ld a,(hl)
        ld (tmpx),a             ; next girder row
        ld a,(tmpy)
        sub 3
        ld e,a                  ; current row
        ld d,0                  ; phase
.r:     ld a,(tmpy)
        cp e
        jr z,.skip
        inc a
        cp e
        jr z,.skip
        inc a
        cp e
        jr z,.skip
        push de
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        add a,a
        add a,l
        ld l,a
        ld a,h
        add a,CLEAN/256
        ld h,a
        ld a,d
        cp 1
        ld de,(wbuf)
        jr nz,.rl
        ld de,(wbuf+2)
.rl:    ld a,e                  ; merge over the backdrop (MASKTAB keeps
        call lad_merge          ; the pixels the ladder leaves empty)
        inc hl
        ld a,d
        call lad_merge
        pop de
.skip:  inc d
        ld a,d
        cp 3
        jr nz,.ph
        ld d,0
.ph:    inc e
        ld a,(tmpx)
        cp e
        jr nz,.r
        ret

lad_merge:
        push de
        ld e,a
        ld d,MASKTAB/256
        ld a,(de)
        and (hl)
        or e
        ld (hl),a
        pop de
        ret

; restore_rect: D = byte col, E = row, B = width, C = height
; copies CLEAN -> BG, queues the rect (unless noq)
restore_rect:
        push bc
        push de
        ld a,(noq)
        or a
        call z,queue_rect
        pop de
        pop bc
        call scraddr
        ld a,h
        add a,CLEAN/256-VRAM/256
        ld h,a                  ; HL = CLEAN
.r:     push bc
        push hl
        ld d,h
        ld e,l
        ld a,d
        add a,BGBUF/256-CLEAN/256
        ld d,a
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

; ---------------------------------------------------------------------
stage_intro:
        call wipe_show
        ld a,(lv_kind)
        or a
        jr z,.n
        ld hl,s_gemdig
        call banner
        ld hl,s_gemdig2
        call banner2
        ld a,(demo)
        or a
        jr nz,.w
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        call play_music
        jr .w
.n:     ld hl,s_stage
        ld de,tbuf
        ld bc,6
        ldir
        call stage_text
        ld hl,tbuf
        call banner
        ld hl,(lvptr)
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call banner2
        ld a,(demo)
        or a
        jr nz,.w
        ld hl,mus_start_0
        ld de,mus_start_1
        call play_music
.w:     ld b,110
        ld a,(demo)
        or a
        jr z,.lp
        ld b,50
.lp:    push bc
        call build_drawlist
        call do_frame
        pop bc
        ld a,(demo)
        or a
        jr z,.nc
        call check_start
        ret nz
.nc:    djnz .lp
        call banner_clear
        xor a
        ret
s_stage: db "STAGE "
s_gemdig: db "* GEM DIG! *",0
s_gemdig2: db "DIG UP THE GEMS",0
; stage_text: "W-S" at tbuf+6 (S = 1..4, gem digs show '$')
stage_text:
        ld a,(level)
        ld b,0
.d:     cp 5
        jr c,.dd
        sub 5
        inc b
        jr .d
.dd:    add a,'1'
        cp '5'
        jr nz,.n5
        ld a,'$'
.n5:    ld c,a
        ld a,b
        add a,'1'
        ld hl,tbuf+6
        ld (hl),a
        inc hl
        ld (hl),'-'
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        ret

; READY! (after the intro and after every death).  NZ = demo aborted
ready_sequence:
        ld hl,s_ready
        call banner
        ld hl,(lvptr)
        ld a,(world)
        add a,a
        ld l,a
        ld h,0
        ld de,worldnames
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call banner2
        ld b,50
.w:     push bc
        call build_drawlist
        call do_frame
        pop bc
        ld a,(demo)
        or a
        jr z,.nc
        call check_start
        ret nz
.nc:    djnz .w
        call banner_clear
        call stop_music
        ld a,(lv_kind)
        or a
        jr z,.g
        ld a,(demo)
        or a
        jr nz,.g2
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        call play_music
.g2:    xor a
        ret
.g:     ld a,(demo)
        or a
        call z,game_music
        xor a
        ret
s_ready: db "READY!",0

; banner box in the middle of the playfield (cols 6-25, rows 25-39)
banner:
        push hl
        ld a,1
        ld (noq),a
        ld de,$0619
        ld bc,$140F
        ld a,$AA
        call fill_rect
        ld a,1
        ld b,2
        call set_ink
        pop hl
        ld e,28
        call print_c
        xor a
        ld (noq),a
        ld de,$0619
        ld bc,$1405
        call queue_rect
        ld de,$061E
        ld bc,$1405
        call queue_rect
        ld de,$0623
        ld bc,$1405
        jp queue_rect
banner2:
        push hl
        xor a
        ld b,2
        call set_ink
        pop hl
        ld e,34
        jp print_c
banner_clear:
        ld de,$0619
        ld bc,$1405
        call restore_rect
        ld de,$061E
        ld bc,$1405
        call restore_rect
        ld de,$0623
        ld bc,$1405
        jp restore_rect

; ---------------------------------------------------------------------
; HUD (rows 0-4): score | O2 bar | lives | aliens left | stage
; ---------------------------------------------------------------------
hud_full:
        ld de,$0000
        ld bc,$2006
        xor a
        call fill_rect
        call hud_score
        call hud_o2
        call hud_lives
        call hud_count
hud_stage:
        ld a,1
        ld b,0
        call set_ink
        call stage_text
        ld hl,tbuf+6
        ld de,$1D00
        jp print
hud_score:
        ld a,3
        ld b,0
        call set_ink
        ld hl,score
        ld b,3
        ld de,$0000
        jp print_bcd
hud_lives:
        ld a,1
        ld b,0
        call set_ink
        ld a,(lives)
        add a,'0'
        ld (tbuf+1),a
        ld a,'['
        ld (tbuf),a
        xor a
        ld (tbuf+2),a
        ld hl,tbuf
        ld de,$1500
        jp print
hud_count:
        ld a,2
        ld b,0
        call set_ink
        ld a,(lv_kind)
        or a
        ld a,']'
        jr z,.e
        ld a,'$'
.e:     ld (tbuf),a
        xor a
        ld (tbuf+1),a
        ld hl,tbuf
        ld de,$1800
        call print
        ld a,1
        ld b,0
        call set_ink
        ld a,(lv_kind)
        or a
        jr nz,.g
        ld a,(killed)
        ld b,a
        ld a,(total)
        sub b
        jr .p
.g:     ld a,(gems_left)
.p:     ld de,$1900
        jp print_dec2
; O2 bubble + bar (cols 7..19), unless a label is showing there
hud_o2:
        ld a,(labeltim)
        ld b,a
        ld a,(labelheld)
        or b
        ret nz
        ld a,(o2small)
        or a
        jr nz,.noi
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_o2icon
        ld de,$0700
        call print
.noi:   ld a,(o2)
        srl a                   ; filled pixels 0..48
        ld (tmpx),a
        ld a,(o2)
        cp 24
        ld c,1
        jr nc,.c
        ld c,3
.c:     ld hl,BGBUF+32+8        ; row 1, col 8
        ld b,12
.b:     push bc
        ld a,(tmpx)
        ld e,a                  ; pixels still to fill
        ld d,4
        xor a
.px:    add a,a
        add a,a
        ld b,a
        ld a,e
        or a
        jr z,.empty
        dec e
        ld a,b
        or c
        jr .nx
.empty: ld a,b
        or 2
.nx:    dec d
        jr nz,.px
        ld (hl),a
        ld de,32
        add hl,de
        ld (hl),a
        add hl,de
        ld (hl),a
        ld de,-63
        add hl,de
        ld a,(tmpx)
        sub 4
        jr nc,.s
        xor a
.s:     ld (tmpx),a
        pop bc
        djnz .b
        ld a,(o2small)
        or a
        jr nz,.small
        ld de,$0801
        ld bc,$0C03
        jp queue_rect
.small: xor a                   ; one unit used: only one byte changed
        ld (o2small),a
        ld a,(o2)
        rrca
        rrca
        rrca
        and 31
        cp 12
        jr c,.sm
        ld a,11
.sm:    add a,8
        ld d,a
        ld e,1
        ld bc,$0103
        jp queue_rect
s_o2icon: db "@",0

; labels over the O2 bar: tmp (~1.5 s) or held (until restore)
hud_label_tmp:
        ld a,80
        ld (labeltim),a
        jr hud_label_print
hud_label_hold:
        ld a,1
        ld (labelheld),a
hud_label_print:
        ld de,lbuf
        ld b,13
.c:     ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .c
        jr .e
.pad:   ld a,' '
.p:     ld (de),a
        inc de
        djnz .p
.e:     xor a
        ld (de),a
        ld a,3
        ld b,0
        call set_ink
        ld hl,lbuf
        ld de,$0700
        jp print
hud_label_restore:
        xor a
        ld (labeltim),a
        ld (labelheld),a
        ld de,$0700
        ld bc,$0D05
        xor a
        call fill_rect
        jp hud_o2
update_label:
        ld a,(labeltim)
        or a
        ret z
        dec a
        ld (labeltim),a
        ret nz
        ld a,(labelheld)
        or a
        ret nz
        jp hud_label_restore

; ---------------------------------------------------------------------
; score: DE = 4-digit BCD points
; ---------------------------------------------------------------------
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
.nov:   ld hl,score
        ld de,nextlife
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.ge
        jr nz,.done
        inc hl
        inc de
        djnz .c
.ge:    ld a,(nextlife)
        add a,$04
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
        ld hl,mus_oneup_0
        ld de,mus_oneup_1
        ld a,(soundmode)
        or a
        call nz,jingle
.done:  jp hud_score
s_xlife: db "EXTRA DIGGER!",0
; short jingle over the game: play it, the game music resumes from clear/ready
jingle:
        jp play_music

; ---------------------------------------------------------------------
; MAIN LOGIC (one frame)
; ---------------------------------------------------------------------
game_logic:
        ld a,(autoplay)
        ld b,a
        ld a,(demo)
        or b
        call nz,ai_think
        call update_player
        call update_aliens
        call spawn_logic
        call update_holes
        call update_item
        call update_o2
        call check_hits
        call update_label
        call check_clear
        ; timers
        ld hl,(boots)
        ld a,h
        or l
        jr z,.nb
        dec hl
        ld (boots),hl
.nb:    ld hl,(drill)
        ld a,h
        or l
        jr z,.nd
        dec hl
        ld (drill),hl
.nd:    ld a,(freeze)
        or a
        jr z,.nf
        dec a
        ld (freeze),a
.nf:    ld a,(invuln)
        or a
        ret z
        dec a
        ld (invuln),a
        ret

check_clear:
        ld a,(forceclear)
        or a
        jr z,.n
        xor a
        ld (forceclear),a
        jr .clr
.n:     ld a,(lv_kind)
        or a
        jr nz,.gem
        ld a,(killed)
        ld b,a
        ld a,(total)
        cp b
        ret nz
        ld a,(alive)
        or a
        ret nz                  ; let the last splat finish
.clr:   ld a,(result)
        or a
        ret nz
        ld a,1
        ld (result),a
        ret
.gem:   ld a,(gems_left)
        or a
        ret nz
        jr .clr

; ---------------------------------------------------------------------
; PLAYER
; inp: bit0 R, 1 L, 2 U, 3 D, 4 FIRE
; ---------------------------------------------------------------------
update_player:
        ld a,(result)
        or a
        ret nz
        ld a,(pst)
        cp PS_DIG
        jr nz,.nd
        ld a,(pdig)
        dec a
        ld (pdig),a
        ret nz
        xor a
        ld (pst),a
        ret
.nd:    ld hl,(boots)
        ld a,h
        or l
        jr z,player_step
        call player_step
        ld a,(pst)
        cp PS_DIG
        ret z
player_step:
        ld a,(pst)
        cp PS_CLIMB
        jp z,.climb
        ld a,(inp)
        ld c,a
        ; up a ladder?
        bit 2,c
        jr z,.nu
        ld a,(pfl)
        or a
        jr z,.nu
        dec a
        ld e,a
        call near_ladder
        jr nc,.nu
        ld a,(pfl)
        dec a
        jr .goclimb
.nu:    bit 3,c
        jr z,.ndn
        ld a,(pfl)
        cp 4
        jr nc,.ndn
        ld e,a
        call near_ladder
        jr nc,.ndn
        ld a,(pfl)
.goclimb:
        ld (pladk),a
        ld a,b
        add a,a
        add a,a
        add a,a
        ld (px),a
        ld a,PS_CLIMB
        ld (pst),a
        ret
.ndn:   ; dig / bash
        ld a,(inpnew)
        bit 4,a
        jr nz,.dig
        ld a,(inp)
        bit 4,a
        jr z,.nrep
        ld a,(prep)
        inc a
        ld (prep),a
        cp 14
        jr c,.mv
.dig:   xor a
        ld (prep),a
        jp dig_action
.nrep:  xor a
        ld (prep),a
.mv:    ld a,(inp)
        ld c,a
        bit 0,c
        jr z,.nr
        xor a
        ld (pdir),a
        ld a,(px)
        cp 120
        ret nc
        inc a
        ld (px),a
        jr .anim
.nr:    bit 1,c
        ret z
        ld a,1
        ld (pdir),a
        ld a,(px)
        or a
        ret z
        dec a
        ld (px),a
.anim:  ld hl,panim
        inc (hl)
        ret
.climb: ld a,(inp)
        bit 2,a
        jr z,.cd
        ld a,(py)
        dec a
        ld (py),a
        ld hl,panim
        inc (hl)
        ld b,a
        ld a,(pladk)
        call fly
        cp b
        ret nz
        ld a,(pladk)
        jr .arrive
.cd:    bit 3,a
        ret z
        ld a,(py)
        inc a
        ld (py),a
        ld hl,panim
        inc (hl)
        ld b,a
        ld a,(pladk)
        inc a
        push af
        call fly
        pop de
        cp b
        ret nz
        ld a,d
.arrive:
        ld (pfl),a
        xor a
        ld (pst),a
        ret

; fly: A = floor -> A = sprite y
fly:
        push hl
        ld hl,flytab
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        pop hl
        ret

; near_ladder: E = ladder row k -> carry + B = slot if a ladder is in reach
near_ladder:
        ld a,(px)
        add a,4
        rrca
        rrca
        rrca
        and 15
        ld b,a
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,LAD&255
        ld l,a
        ld h,LAD/256
        ld a,(hl)
        or a
        ret z                   ; (carry clear)
        scf
        ret

; slot in front of the digger -> A (or $FF if off the edge)
front_slot:
        ld a,(px)
        add a,4
        rrca
        rrca
        rrca
        and 15
        ld b,a
        ld a,(pdir)
        or a
        ld a,b
        jr nz,.l
        inc a
        cp 16
        ret c
        ld a,$FF
        ret
.l:     dec a
        ret

dig_action:
        ld a,PS_DIG
        ld (pst),a
        ld a,10
        ld (pdig),a
        ld a,(pfl)
        cp 4
        jp nc,.clunk
        call front_slot
        cp $FF
        jp z,.clunk
        ld c,a
        ld a,(pfl)
        ld b,a
        push bc
        call find_trapped
        pop bc
        jp z,bash
        ; diggable?
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld (tmpd),a             ; idx
        add a,FLT&255
        ld l,a
        ld h,FLT/256
        ld a,(hl)
        cp 1
        jr z,.clunk             ; steel
        ld a,(tmpd)
        add a,LAD&255
        ld l,a
        ld a,(hl)
        or a
        jr nz,.clunk            ; ladder goes down from here
        ld a,b
        or a
        jr z,.nl
        ld a,l
        sub 16
        ld l,a
        ld a,(hl)
        or a
        jr nz,.clunk            ; ladder comes up here
.nl:    ld a,(tmpd)
        ld l,a                  ; HOLES page = $F0, low = idx
        ld a,(hl)
        cp 3
        jr nc,.clunk            ; already open (or occupied)
        inc a
        push hl
        ld hl,(drill)
        ld e,a
        ld a,h
        or l
        ld a,e
        jr z,.nd
        ld a,3
.nd:    pop hl
        ld (hl),a
        push af
        push bc
        ld a,l
        add a,HTIM&255
        ld l,a
        ld a,(lv_trap)          ; open holes last a while, then fill in
        srl a
        add a,40
        ld (hl),a
        pop bc
        pop af
        cp 3
        jr nz,.dug
        ; opened: a buried gem?
        ld a,(tmpd)
        add a,FLT&255
        ld l,a
        ld a,(hl)
        cp 2
        jr nz,.dug3
        ld (hl),0
        push bc
        call gem_found
        pop bc
.dug3:  push bc
        call draw_slot
        pop bc
        ld a,SFX_OPEN
        jp play_sfx
.dug:   push bc
        call draw_slot
        pop bc
        ld a,SFX_DIG
        jp play_sfx
.clunk: ld a,SFX_CLUNK
        jp play_sfx

gem_found:
        ld hl,gems_left
        ld a,(hl)
        or a
        jr z,.z
        dec (hl)
.z:     call hud_count
        ld a,c
        add a,a
        add a,a
        add a,a
        ld (tmpx),a
        ld de,$0300
        call add_score
        ld a,(tmpx)
        add a,4
        ld b,a
        ld a,(pfl)
        call fly
        add a,4
        ld c,a
        ld a,3
        call burst
        ld a,(tmpx)
        rrca
        rrca
        and 63
        ld b,a
        ld a,(pfl)
        call fly
        ld c,a
        ld e,P_300
        call popup_add
        ld a,SFX_GET
        jp play_sfx

; find_trapped: B = floor, C = slot -> Z and IX = alien trapped there
find_trapped:
        ld ix,aliens
        ld h,NAL
.l:     ld a,(ix+AL_ST)
        cp AS_TRAP
        jr nz,.n
        ld a,(ix+AL_FL)
        cp b
        jr nz,.n
        ld a,(ix+AL_SLOT)
        cp c
        ret z
.n:     ld de,16
        add ix,de
        dec h
        jr nz,.l
        or 1
        ret

; bash the trapped alien at IX: hits needed = type+1, then it drops through
bash:
        ld a,(ix+AL_X)
        add a,4
        ld b,a
        ld a,(ix+AL_Y)
        add a,2
        ld c,a
        ld a,1
        call burst
        dec (ix+AL_HP)
        jr z,.drop
        ld a,SFX_BASH
        jp play_sfx
.drop:  ld (ix+AL_ST),AS_FALL
        ld (ix+AL_DROP),0
        ld (ix+AL_ACC),0
        ; the hole stays open (no longer occupied), its timer starts again
        call al_idx
        ld l,a
        ld h,HOLES/256
        ld (hl),3
        add a,HTIM&255
        ld l,a
        ld (hl),60
        xor a
        ld (combo),a
        ld a,SFX_DROP
        jp play_sfx

; al_idx: IX alien -> A = floor*16 + slot
al_idx:
        ld a,(ix+AL_FL)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,(ix+AL_SLOT)
        ret

; ---------------------------------------------------------------------
; HOLES: open holes fill in again by themselves (every 4th frame)
; ---------------------------------------------------------------------
update_holes:
        ld hl,htick
        inc (hl)
        ld a,(hl)
        and 3
        ret nz
        ld hl,HOLES
        ld b,64
.l:     ld a,(hl)
        or a
        jr z,.n
        bit 7,a
        jr nz,.n                ; occupied: frozen
        ld a,l
        add a,HTIM&255
        ld e,a
        ld d,h
        ld a,(de)
        or a
        jr z,.n
        dec a
        ld (de),a
        jr nz,.n
        dec (hl)
        jr z,.d
        ld a,15
        ld (de),a
.d:     push hl
        push bc
        ld a,l
        and 15
        ld c,a
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 3
        ld b,a
        call draw_slot
        ld a,SFX_FILL
        call play_sfx
        pop bc
        pop hl
.n:     inc l
        djnz .l
        ret

; ---------------------------------------------------------------------
; OXYGEN
; ---------------------------------------------------------------------
update_o2:
        ld a,(result)
        or a
        ret nz
        ld hl,o2cnt
        dec (hl)
        ret nz
        ld a,(lv_o2)
        ld (hl),a
        ld hl,o2
        ld a,(hl)
        or a
        jr z,.out
        dec (hl)
        ld a,(hl)
        cp 23
        jr z,.full              ; colour change: whole bar
        ld a,1
        ld (o2small),a
.full:  call hud_o2
        xor a
        ld (o2small),a
        ld a,(o2)
        cp 24
        jr nz,.nw
        ld a,1
        ld (hurry),a
        ld a,(lv_kind)
        or a
        jr nz,.nm
        call game_music
.nm:    ld hl,s_lowair
        call hud_label_tmp
.nw:    ld a,(o2)
        cp 24
        jr nc,.nb
        ld a,SFX_BEEP
        call play_sfx
.nb:    ld a,(o2)
        or a
        ret nz
.out:   ld a,(lv_kind)
        or a
        ld a,3
        jr nz,.r                ; gem dig: time up
        ld a,(godmode)
        or a
        ret nz
        ld a,2
.r:     ld (result),a
        ret
s_lowair: db "LOW OXYGEN!",0

; ---------------------------------------------------------------------
; ALIENS
; ---------------------------------------------------------------------
spawn_logic:
        ld a,(result)
        or a
        ret nz
        ld hl,spawncool
        ld a,(hl)
        or a
        jr z,.go
        dec (hl)
        ret
.go:    ld a,(spawned)
        ld b,a
        ld a,(total)
        cp b
        ret z
        ret c
        ld a,(lv_max)
        ld b,a
        ld a,(alive)
        cp b
        ret nc
        ; free record
        ld ix,aliens
        ld b,NAL
.f:     ld a,(ix+AL_ST)
        or a
        jr z,.got
        ld de,16
        add ix,de
        djnz .f
        ret
.got:   ld a,90
        ld (spawncool),a
        ld hl,alive
        inc (hl)
        ld a,(spawned)
        ld l,a
        inc a
        ld (spawned),a
        ld h,SPAWN/256
        ld a,(hl)
        ld (ix+AL_TYPE),a
        inc a
        ld (ix+AL_HP),a
        ; pick a top-floor slot away from the digger
.again: ld b,16
        call rand_n
        ld c,a
        ld a,(pfl)
        or a
        jr nz,.ok
        ld a,c
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(px)
        sub b
        jr nc,.p
        neg
.p:     cp 32
        jr c,.again
.ok:    ld a,c
        add a,a
        add a,a
        add a,a
        ld (ix+AL_X),a
        ld (ix+AL_Y),9
        ld (ix+AL_FL),0
        ld (ix+AL_ST),AS_SPARK
        ld (ix+AL_TIM),40
        ld (ix+AL_ANG),0
        ld (ix+AL_COOL),0
        ld (ix+AL_ACC),0
        call random
        and 1
        ld (ix+AL_DIR),a
        ld a,SFX_BEAM
        jp play_sfx

update_aliens:
        ld ix,aliens
        ld b,NAL
.l:     push bc
        ld a,(ix+AL_ST)
        or a
        call nz,alien_one
        pop bc
        ld de,16
        add ix,de
        djnz .l
        ret

alien_one:
        inc (ix+AL_ANIM)
        ld a,(ix+AL_ANG)
        or a
        jr z,.na
        ld a,(framecount)
        and 3
        jr nz,.na
        dec (ix+AL_ANG)
.na:    ld a,(ix+AL_ST)
        cp AS_SPARK
        jr z,a_spark
        cp AS_FALL
        jp z,a_fall
        cp AS_DIE
        jr z,a_die
        cp AS_STUN
        jr z,a_stun
        ld b,a
        ld a,(freeze)
        or a
        ret nz
        ld a,b
        cp AS_TRAP
        jp z,a_trap
        ; walking / climbing: speed
        ld a,(lv_speed)
        ld b,(ix+AL_TYPE)
        inc b
.t:     dec b
        jr z,.td
        add a,14
        jr nc,.t
        ld a,255
.td:    ld b,a
        ld a,(ix+AL_ANG)
        or a
        ld a,b
        jr z,.sp
        add a,56
        jr nc,.sp
        ld a,255
.sp:    add a,(ix+AL_ACC)
        ld (ix+AL_ACC),a
        ret nc
        ld a,(ix+AL_ST)
        cp AS_CLIMB
        jp z,a_climb
        jp a_walk

a_spark:
        dec (ix+AL_TIM)
        ret nz
        ld (ix+AL_ST),AS_WALK
        ret
a_die:
        dec (ix+AL_TIM)
        ret nz
        ld (ix+AL_ST),AS_FREE
        ld hl,alive
        dec (hl)
        ret
a_stun:
        dec (ix+AL_TIM)
        ret nz
        ld (ix+AL_ST),AS_WALK
        ld (ix+AL_ANG),60
        ret

a_trap:
        dec (ix+AL_TIM)
        ret nz
        ; climbs out: the hole is wrecked, and the alien is angry
        call al_idx
        ld l,a
        ld h,HOLES/256
        ld (hl),0
        ld b,(ix+AL_FL)
        ld c,(ix+AL_SLOT)
        call draw_slot
        ld a,(ix+AL_FL)
        call fly
        ld (ix+AL_Y),a
        ld (ix+AL_ST),AS_WALK
        ld (ix+AL_ANG),120
        ld (ix+AL_COOL),2
        ld a,SFX_ESCAPE
        jp play_sfx

a_walk:
        ld a,(ix+AL_DIR)
        or a
        ld a,(ix+AL_X)
        jr nz,.left
        cp 120
        jr c,.r
        ld (ix+AL_DIR),1
        ret
.r:     inc a
        jr .mv
.left:  or a
        jr nz,.l
        ld (ix+AL_DIR),0
        ret
.l:     dec a
.mv:    ld (ix+AL_X),a
        and 7
        ret nz
        ; on a slot boundary
        ld a,(ix+AL_X)
        rrca
        rrca
        rrca
        and 15
        ld (ix+AL_SLOT),a
        ld c,a
        ld a,(ix+AL_FL)
        ld b,a
        cp 4
        jr nc,.nohole
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,HOLES/256
        ld a,(hl)
        cp 3
        jr nz,.nohole
        ; falls in!
        set 7,(hl)
        ld (ix+AL_ST),AS_TRAP
        ld a,(ix+AL_Y)
        add a,4
        ld (ix+AL_Y),a
        ld a,(lv_trap)
        ld (ix+AL_TIM),a
        ld a,(ix+AL_TYPE)
        inc a
        ld (ix+AL_HP),a
        ld a,SFX_TRAP
        jp play_sfx
.nohole:
        ld a,(ix+AL_COOL)
        or a
        jr z,.cl
        dec (ix+AL_COOL)
        jp .face
.cl:    ; ladders here?  (B = floor, C = slot)
        xor a
        ld (tmpx),a             ; bit0 up, bit1 down
        ld a,b
        or a
        jr z,.nup
        dec a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        add a,LAD&255
        ld l,a
        ld h,LAD/256
        ld a,(hl)
        or a
        jr z,.nup
        ld a,1
        ld (tmpx),a
.nup:   ld a,b
        cp 4
        jr nc,.ndn
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        add a,LAD&255
        ld l,a
        ld h,LAD/256
        ld a,(hl)
        or a
        jr z,.ndn
        ld a,(tmpx)
        or 2
        ld (tmpx),a
.ndn:   ld a,(tmpx)
        or a
        jr z,.face
        ; chase: towards the digger's floor
        call target_floor
        ld (tmpy),a
        call random
        ld e,a
        ld a,(ix+AL_ANG)
        or a
        ld a,(lv_chase)
        jr z,.cc
        ld a,230
.cc:    cp e
        jr c,.rnd
        ld a,(tmpy)
        cp (ix+AL_FL)
        jr z,.face
        jr c,.wantup
        ld a,(tmpx)
        bit 1,a
        jr nz,.down
        jr .face
.wantup:
        ld a,(tmpx)
        bit 0,a
        jr nz,.up
        jr .face
.rnd:   ld a,e
        and 3
        jr nz,.face
        ld a,(tmpx)
        bit 0,a
        jr z,.down
        bit 1,a
        jr z,.up
        ld a,e
        and 4
        jr z,.down
.up:    ld (ix+AL_ST),AS_CLIMB
        ld (ix+AL_DIR),1
        dec (ix+AL_FL)
        ret
.down:  ld (ix+AL_ST),AS_CLIMB
        ld (ix+AL_DIR),0
        inc (ix+AL_FL)
        ret
.face:  ; on the digger's floor: sometimes turn towards him
        ld a,(pst)
        cp PS_CLIMB
        ret z
        ld a,(pfl)
        cp (ix+AL_FL)
        ret nz
        call random
        ld e,a
        ld a,(lv_chase)
        cp e
        ret c
        ld a,(px)
        cp (ix+AL_X)
        ld a,0
        jr nc,.fr
        inc a
.fr:    ld (ix+AL_DIR),a
        ret

; target_floor: the floor the aliens hunt (the digger's, or the ladder's lower floor)
target_floor:
        ld a,(pst)
        cp PS_CLIMB
        ld a,(pfl)
        ret nz
        ld a,(pladk)
        ret

a_climb:
        ld a,(ix+AL_DIR)
        or a
        ld a,(ix+AL_Y)
        jr z,.d
        dec a
        jr .s
.d:     inc a
.s:     ld (ix+AL_Y),a
        ld b,a
        ld a,(ix+AL_FL)
        call fly
        cp b
        ret nz
        ld (ix+AL_ST),AS_WALK
        ld (ix+AL_COOL),2
        ; pick a direction, towards the digger if he's here
        call random
        and 1
        ld (ix+AL_DIR),a
        ld a,(pfl)
        cp (ix+AL_FL)
        ret nz
        ld a,(px)
        cp (ix+AL_X)
        ld a,0
        jr nc,.fr
        inc a
.fr:    ld (ix+AL_DIR),a
        ret

; falling through holes.  Lands when there's no open hole below.
a_fall:
        ld a,(ix+AL_Y)
        add a,2
        ld (ix+AL_Y),a
        ld b,a
        ld a,(ix+AL_FL)
        inc a
        call fly
        cp b
        jr z,.arr
        ret nc
.arr:   ld (ix+AL_Y),a
        ; reached the next floor down
        inc (ix+AL_FL)
        inc (ix+AL_DROP)
        ld a,(ix+AL_FL)
        cp 4
        jr nc,.land
        call al_idx
        ld l,a
        ld h,HOLES/256
        ld a,(hl)
        and $7F
        cp 3
        jr nz,.land
        ; an open hole below: keep falling, squashing anyone inside
        bit 7,(hl)
        ret z
        res 7,(hl)
        ld b,(ix+AL_FL)
        ld c,(ix+AL_SLOT)
        push ix
        call find_trapped
        call z,squash
        pop ix
        ret
.land:  ; squash walkers where it lands
        push ix
        ld a,(ix+AL_X)
        ld (tmpx),a
        ld a,(ix+AL_FL)
        ld (tmpy),a
        push ix
        pop hl
        ld (wbuf+4),hl
        ld ix,aliens
        ld b,NAL
.sq:    push bc
        push ix
        pop hl
        ld de,(wbuf+4)
        or a
        sbc hl,de
        jr z,.sn
        ld a,(ix+AL_ST)
        cp AS_WALK
        jr z,.sc
        cp AS_STUN
        jr z,.sc
        cp AS_SPARK
        jr nz,.sn
.sc:    ld a,(ix+AL_FL)
        ld hl,tmpy
        cp (hl)
        jr nz,.sn
        ld a,(ix+AL_X)
        ld hl,tmpx
        sub (hl)
        jr nc,.ab
        neg
.ab:    cp 8
        jr nc,.sn
        call squash
.sn:    ld de,16
        add ix,de
        pop bc
        djnz .sq
        pop ix
        ; a long enough drop?
        ld a,(ix+AL_TYPE)
        cp (ix+AL_DROP)
        jr c,kill_drop
        ; survived: dizzy for a while, then angry
        ld (ix+AL_ST),AS_STUN
        ld (ix+AL_TIM),90
        ld a,(ix+AL_FL)
        call fly
        ld (ix+AL_Y),a
        ld a,SFX_THUD
        jp play_sfx

; kill_drop: IX died from a fall of AL_DROP floors
kill_drop:
        ld a,(ix+AL_DROP)
        sub (ix+AL_TYPE)        ; 1.. -> 0..
        dec a
        cp 4
        jr c,.k
        ld a,3
.k:     ld b,a
        ld a,(ix+AL_TYPE)
        add a,a
        add a,a
        add a,b                 ; type*4 + k
        ld b,a
        add a,a
        add a,b                 ; *3
        ld l,a
        ld h,0
        ld de,ptstab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        push af
        call add_score
        pop af
        ld e,a
        call kill_fx
        ld a,SFX_SPLAT
        jp play_sfx
; points per type and how far past the minimum drop it fell
ptstab:
        dw $0100 : db P_100
        dw $0200 : db P_200
        dw $0400 : db P_400
        dw $0800 : db P_800
        dw $0300 : db P_300
        dw $0600 : db P_600
        dw $1200 : db P_1200
        dw $2400 : db P_2400
        dw $0800 : db P_800
        dw $1600 : db P_1600
        dw $3200 : db P_3200
        dw $6400 : db P_6400

; squash: IX is crushed by a falling alien: 1000
squash:
        ld de,$1000
        call add_score
        ld e,P_1000
        call kill_fx
        ld a,SFX_SQUASH
        jp play_sfx

; kill_fx: IX dies (splat), E = popup
kill_fx:
        push de
        ld (ix+AL_ST),AS_DIE
        ld (ix+AL_TIM),30
        ld a,(ix+AL_FL)
        cp 5
        jr c,.f
        ld a,4
.f:     call fly
        ld (ix+AL_Y),a
        ld hl,killed
        inc (hl)
        call hud_count
        ld a,(ix+AL_X)
        add a,4
        ld b,a
        ld a,(ix+AL_Y)
        add a,4
        ld c,a
        ld a,(ix+AL_TYPE)
        inc a
        call burst
        ld a,6
        ld (flashtim),a
        pop de
        ld a,(ix+AL_X)
        rrca
        rrca
        and 63
        ld b,a
        ld a,(ix+AL_Y)
        sub 6
        ld c,a
        jp popup_add

; ---------------------------------------------------------------------
; collisions: digger vs aliens and the pickup
; ---------------------------------------------------------------------
check_hits:
        ld a,(result)
        or a
        ret nz
        call item_hit
        ld a,(invuln)
        ld b,a
        ld a,(godmode)
        or b
        ret nz
        ld a,(freeze)
        or a
        ret nz
        ld ix,aliens
        ld b,NAL
.l:     ld a,(ix+AL_ST)
        cp AS_WALK
        jr z,.c
        cp AS_CLIMB
        jr nz,.n
.c:     ld a,(px)
        sub (ix+AL_X)
        jr nc,.a1
        neg
.a1:    cp 6
        jr nc,.n
        ld a,(py)
        sub (ix+AL_Y)
        jr nc,.a2
        neg
.a2:    cp 7
        jr nc,.n
        ld a,2
        ld (result),a
        ret
.n:     ld de,16
        add ix,de
        djnz .l
        ret

; ---------------------------------------------------------------------
; PICKUPS
; ---------------------------------------------------------------------
update_item:
        ld a,(lv_kind)
        or a
        ret nz
        ld a,(itemk)
        or a
        jr nz,.live
        ld hl,(itemcool)
        dec hl
        ld (itemcool),hl
        ld a,h
        or l
        ret nz
        ; spawn: random floor and slot, not at a ladder or a hole
        ld b,5
        call rand_n
        ld (itemfl),a
        ld b,16
        call rand_n
        ld (itemsl),a
        ld c,a
        ld a,(itemfl)
        ld b,a
        call slot_clear
        jr nz,.retry
        call random
        and 15
        ld e,IT_O2
        cp 5
        jr c,.k
        ld e,IT_GEM
        cp 10
        jr c,.k
        ld e,IT_BOOT
        cp 12
        jr c,.k
        ld e,IT_DRILL
        cp 14
        jr c,.k
        ld e,IT_FREEZE
.k:     ld a,e
        ld (itemk),a
        ld hl,450
        ld (itemtim),hl
        ld a,SFX_ITEM
        jp play_sfx
.retry: ld hl,20
        ld (itemcool),hl
        ret
.live:  ld hl,(itemtim)
        dec hl
        ld (itemtim),hl
        ld a,h
        or l
        ret nz
        xor a
        ld (itemk),a
        call random
        ld l,a
        ld h,1
        ld (itemcool),hl
        ret

; slot_clear: B floor, C slot -> Z if no ladder end and no hole there
slot_clear:
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,HOLES/256
        ld a,b
        cp 4
        jr nc,.nh
        ld a,(hl)
        or a
        ret nz
.nh:    ld a,l
        add a,LAD&255
        ld l,a
        ld a,b
        cp 4
        jr nc,.nd
        ld a,(hl)
        or a
        ret nz
.nd:    ld a,b
        or a
        ret z
        ld a,l
        sub 16
        ld l,a
        ld a,(hl)
        or a
        ret

item_hit:
        ld a,(itemk)
        or a
        ret z
        ld a,(pst)
        cp PS_CLIMB
        ret z
        ld a,(pfl)
        ld b,a
        ld a,(itemfl)
        cp b
        ret nz
        ld a,(itemsl)
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(px)
        sub b
        jr nc,.a
        neg
.a:     cp 6
        ret nc
        ; collected
        ld a,(itemk)
        push af
        xor a
        ld (itemk),a
        call random
        ld l,a
        ld h,2
        ld (itemcool),hl
        ld a,SFX_GET
        call play_sfx
        ld a,(px)
        add a,4
        ld b,a
        ld a,(py)
        add a,3
        ld c,a
        ld a,1
        call burst
        pop af
        cp IT_O2
        jr nz,.n1
        ld a,(o2)
        add a,32
        cp O2MAX
        jr c,.o
        ld a,O2MAX
.o:     ld (o2),a
        cp 24
        jr c,.o2
        ld a,(hurry)
        or a
        jr z,.o2
        xor a
        ld (hurry),a
        call game_music
.o2:    call hud_o2
        ld e,P_O2
        jr .pop
.n1:    cp IT_BOOT
        jr nz,.n2
        ld hl,500
        ld (boots),hl
        ld hl,s_boots
        jp hud_label_tmp
.n2:    cp IT_DRILL
        jr nz,.n3
        ld hl,500
        ld (drill),hl
        ld hl,s_drill
        jp hud_label_tmp
.n3:    cp IT_FREEZE
        jr nz,.n4
        ld a,250
        ld (freeze),a
        ld a,SFX_FREEZE
        call play_sfx
        ld hl,s_freeze
        jp hud_label_tmp
.n4:    ; gem: 500, 1000, 2000
        ld a,(gemval)
        ld b,a
        inc a
        cp 3
        jr c,.g
        ld a,2
.g:     ld (gemval),a
        ld a,b
        ld de,$0500
        ld c,P_500
        or a
        jr z,.gp
        ld de,$1000
        ld c,P_1000
        dec a
        jr z,.gp
        ld de,$2000
        ld c,P_2000
.gp:    push bc
        call add_score
        pop bc
        ld e,c
.pop:   ld a,(px)
        rrca
        rrca
        and 63
        ld b,a
        ld a,(py)
        sub 6
        ld c,a
        jp popup_add
s_boots:  db "SPEED BOOTS!",0
s_drill:  db "POWER DRILL!",0
s_freeze: db "FREEZE!",0

; ---------------------------------------------------------------------
; DRAWING
; ---------------------------------------------------------------------
build_drawlist:
        call dl_reset
        ; pickup (blinks before it goes)
        ld a,(itemk)
        or a
        jr z,.ni
        ld hl,(itemtim)
        ld a,h
        or a
        jr nz,.iv
        ld a,l
        cp 100
        jr nc,.iv
        ld a,(framecount)
        and 4
        jr nz,.ni
.iv:    ld a,(itemsl)
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(itemfl)
        call fly
        ld c,a
        ld a,(itemk)
        add a,SPR_ITO2-1
        call dl_add
.ni:    call alien_sprites
        ; digger
        ld a,(invuln)
        or a
        jr z,.vis
        ld a,(framecount)
        and 4
        jr nz,.np
.vis:   call digger_sprite
        ld hl,(px)
        ld b,l
        ld c,h
        call dl_add
.np:    call update_particles
        jp update_popups

digger_sprite:
        ld a,(pst)
        cp PS_CLIMB
        jr nz,.nc
        ld a,(py)
        rrca
        rrca
        and 1
        add a,SPR_DC0
        ret
.nc:    cp PS_DIG
        jr nz,.w
        ld a,(pdig)
        cp 6
        ld a,0
        jr nc,.d0
        inc a
.d0:    ld b,a
        ld a,(pdir)
        add a,a
        add a,b
        add a,SPR_DG0
        ret
.w:     ld a,(pdir)
        add a,a
        ld b,a
        ld a,(panim)
        rrca
        rrca
        and 1
        add a,b
        add a,SPR_DR0
        ret

alien_sprites:
        ld ix,aliens
        ld b,NAL
.l:     push bc
        ld a,(ix+AL_ST)
        or a
        call nz,alien_sprite
        ld de,16
        add ix,de
        pop bc
        djnz .l
        ret
alien_sprite:
        ld b,(ix+AL_X)
        ld c,(ix+AL_Y)
        cp AS_SPARK
        jr nz,.ns
        ld a,(ix+AL_ANIM)
        rrca
        rrca
        and 1
        add a,SPR_SPARK0
        jp dl_add
.ns:    cp AS_DIE
        jr nz,.nd
        ld a,SPR_SPLAT
        jp dl_add
.nd:    ld e,a
        ; frame: walking anim, trapped wriggle, frozen still
        ld a,(ix+AL_ANIM)
        rrca
        rrca
        rrca
        ld d,a
        ld a,e
        cp AS_TRAP
        jr nz,.nt
        ld a,(ix+AL_ANIM)
        rrca
        ld d,a
        ld a,(ix+AL_TIM)
        cp 40
        jr nc,.nt
        ld a,(ix+AL_ANIM)
        and 2
        jr z,.nt
        inc b                   ; about to climb out: shakes
.nt:    ld a,e
        cp AS_STUN
        jr nz,.nz
        ld a,(framecount)
        and 4
        ret nz                  ; dizzy: flickers
.nz:    ld a,(freeze)
        or a
        jr z,.nf
        ld d,0
.nf:    ld a,(ix+AL_ANG)
        or a
        ld a,(ix+AL_TYPE)
        jr z,.na
        add a,3
.na:    add a,a
        ld e,a
        ld a,d
        and 1
        add a,e
        add a,SPR_GRUB0
        jp dl_add

; ---------------------------------------------------------------------
; popups (score text in the BG, erased from CLEAN) and particles
; ---------------------------------------------------------------------
; popup_add: B = col, C = row, E = string index
popup_add:
        ld a,c
        cp 6
        jr nc,.r
        ld c,6
.r:     cp 57
        jr c,.r2
        ld c,56
.r2:    ld a,b
        cp 27
        jr c,.cc
        ld b,26
.cc:    ld hl,popups
        ld d,4
.f:     ld a,(hl)
        cp $FF
        jr z,.got
        inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        ret
.got:   push hl
        ld a,e
        add a,a
        ld e,a
        ld d,0
        ld hl,popstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld e,0
.ln:    ld a,(hl)
        or a
        jr z,.lnd
        inc e
        inc hl
        jr .ln
.lnd:   pop hl
        ex (sp),hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),45
        inc hl
        ld (hl),e
        push bc
        ld a,3
        ld b,0
        call set_ink
        pop de
        pop hl
        jp print
init_popups:
        ld hl,popups
        ld b,4
.l:     ld (hl),$FF
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        ld hl,particles
        ld b,10
.p:     ld (hl),0
        ld de,6
        add hl,de
        djnz .p
        ret
update_popups:
        ld hl,popups
        ld d,4
.l:     ld a,(hl)
        cp $FF
        jr z,.n
        push hl
        inc hl
        inc hl
        dec (hl)
        pop hl
        jr nz,.n
        push hl
        push de
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        inc hl
        ld b,(hl)
        ld c,5
        call restore_rect
        pop de
        pop hl
        ld (hl),$FF
.n:     inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.l
        ret

; burst: A = colour, B = x, C = y : spawn 4 particles
burst:
        ld (burstcol),a
        ld a,4
        ld (bcount),a
        ld hl,particles
        ld e,10
.f:     ld a,(hl)
        or a
        jr nz,.n
        push de
        push hl
        ld (hl),12
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
burstdir: db 2,0, -2,0, 0,-1, 0,1, 1,-1, -1,-1, 1,1, -1,1

update_particles:
        ld hl,particles
        ld d,10
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
        ; only while the frame has room (vblank budget): skip, keep alive
        push hl
        ld hl,(dlptr)
        ld a,l
        sub drawlist&255
        pop hl
        cp 5*10
        jr nc,.d
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

popstr: dw ps0,ps1,ps2,ps3,ps4,ps5,ps6,ps7,ps8,ps9,ps10,ps11,ps12,ps13,ps14,ps15,ps16
ps0:    db "100",0
ps1:    db "200",0
ps2:    db "400",0
ps3:    db "800",0
ps4:    db "300",0
ps5:    db "600",0
ps6:    db "1200",0
ps7:    db "2400",0
ps8:    db "1600",0
ps9:    db "3200",0
ps10:   db "6400",0
ps11:   db "1000",0
ps12:   db "500",0
ps13:   db "2000",0
ps14:   db "5000",0
ps15:   db "1UP",0
ps16:   db "+O2",0
