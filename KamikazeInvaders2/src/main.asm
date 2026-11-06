; =====================================================================
;  KAMIKAZE INVADERS 2 - "The Mothership Strikes Back"
;  for the Dick Smith VZ300 / VZ200 (Mode 1, 128x64, 4 colours)
;  with the BennVenn SD loader + 128K RAM expansion (RAM to $FFFF).
;  Sequel to the VZ200 game KAMIKAZE INVADERS.
;  ViBED by BPM 2026.  Assemble: sjasmplus main.asm (see build.sh)
;  Engine (frame sync, beeper, sprites, commit queue) from PENGUIN 2.
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BGBUF   equ $F800               ; what should be on screen (sprites aside)
MASKTAB equ $F600
CLEANBUF equ $E800              ; the empty playfield (stars, rails, ground)
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10
qbuf    equ $7C00               ; 128-byte commit ring (page aligned)

; playfield layout (pixel rows)
MS_Y    equ 6                   ; mothership band rows 6..12
LANE_Y  equ 13                  ; flight lane rows 13..17
RAIL_Y0 equ 18
RAIL_Y1 equ 39
COL_Y   equ 19                  ; slot s at COL_Y + 5*s
OPEN_Y  equ 41                  ; open sky rows 41..55 (banners, popups)
SHIP_Y  equ 56                  ; ship rows 56..60, blasts too
GROUND_Y equ 61

        org $8000
start:
        di
        ld sp,STACKTOP
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,qbuf
        ld de,qbuf+1
        ld bc,255
        ld (hl),0
        ldir
        ld a,MODE1
        ld (latchbase),a
        ld (latchcur),a
        ld (palbase),a
        ld ($6800),a
        ld a,$AA
        call cls_vram           ; start-up only
        ld a,$AA
        call cls_bg
        ld a,r
        ld l,a
        ld h,$5C
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        ld a,CBUDGET
        ld (cbudget),a
        ld hl,vb_none
        ld (vbhook),hl
        ld hl,hitab_init
        ld de,hitab
        ld bc,HIENT*10
        ldir
        call init_sprites
        jp attract

CBUDGET equ 34
HIENT   equ 8                   ; bytes per hi-score entry: 3 BCD + 5 name
hitab_init:
        db $02,$00,$00,"BPM  "
        db $01,$75,$00,"VIBED"
        db $01,$50,$00,"VZ300"
        db $01,$25,$00,"SWARM"
        db $01,$00,$00,"ZAPPO"
        db $00,$80,$00,"KAMI "
        db $00,$60,$00,"HIVE "
        db $00,$40,$00,"RAILS"
        db $00,$20,$00,"NOVA "
        db $00,$10,$00,"BLAST"

vb_none:
        ret
special_vblank:
        ld hl,(vbhook)
        jp (hl)

; ---------------------------------------------------------------------
; do_frame: palette, sound, wait for vblank, render, input
; ---------------------------------------------------------------------
do_frame:
        ld a,(palbase)
        ld b,a
        ld a,(flashtim)
        or a
        jr z,.nf
        dec a
        ld (flashtim),a
        bit 1,a
        jr z,.nf
        ld a,b
        xor CSS1
        ld b,a
.nf:    ld a,b
        or MODE1
        ld (latchbase),a
        call sound_tick
        call frame_wait
        call render
        jp read_input

blank_frame:
        call dl_reset
        jp do_frame

; wait B frames; NZ if start pressed
wait_frames:
        push bc
        call do_frame
        call check_start
        pop bc
        ret nz
        djnz wait_frames
        xor a
        ret

; wipe to a blank screen: BG filled with A, revealed in blinds order
wipe_to:
        push af
        call dl_reset
        call do_frame
        pop af
        call cls_bg
; reveal the whole BG buffer in "blinds" order (4 rows per frame)
wipe_show:
        call dl_reset
        call clear_erase
        xor a
        ld (q_head),a
        ld (q_tail),a
        ld a,120
        ld (cbudget),a
        ld c,0
.p:     push bc
        ld e,c
.r:     push de
        ld d,0
        ld bc,$2001
        call queue_rect
        pop de
        ld a,e
        add a,16
        ld e,a
        cp 64
        jr c,.r
        call do_frame
        pop bc
        inc c
        ld a,c
        cp 16
        jr nz,.p
        call flush_queue
        ld a,CBUDGET
        ld (cbudget),a
        ret

clear_erase:
        xor a
        ld (eraselist),a
        ld (eraselist+1),a
        ret

; =====================================================================
;  GAME FLOW
; =====================================================================
start_game:
        xor a
        ld (demo),a
        ld (lap),a
        ld a,(startsector)
        ld (sector),a
        xor a
        ld (startsector),a
        call stop_music
        ld hl,0
        ld (score),hl
        xor a
        ld (score+2),a
        ld a,3                  ; three ships, as in the original
        ld (lives),a
        ld hl,$0001             ; first extra ship at 010000 (BCD, high byte first)
        ld (nextlife),hl
        xor a
        ld (nextlife+2),a
sector_start:
        xor a
        ld (wave),a
        ld (bonusmode),a
        call setup_sector
sector_start_d2:
        call sector_intro
        ret nz                  ; demo aborted
wave_start:
        call setup_wave
        call wave_intro
        ret nz
life_start:
        call ready_sequence
        ret nz
play_loop:
        call game_logic
        call build_drawlist
        call keys_ingame
        ld a,(demo)
        or a
        jr z,.nd
        ld hl,(demotim)
        dec hl
        ld (demotim),hl
        ld a,h
        or l
        jr z,.demo_end
        call check_start
        jr nz,.demo_start
.nd:    call do_frame
        ld a,(result)
        or a
        jr z,play_loop
        ld a,(demo)
        or a
        jr nz,.demo_end
        ld a,(result)
        cp 1
        jp z,wave_clear
        cp 2
        jp z,death
        cp 4
        jp z,quit_game
        jp bonus_over           ; 3: bonus round over
.demo_end:
        xor a
        ret
.demo_start:
        ld a,1
        or a
        ret

quit_game:
        call stop_music
        jp attract

; P = pause (X while paused quits), S = sound mode, CTRL+BREAK quits
keys_ingame:
        ld a,(demo)
        or a
        ret nz
        ld a,(keysnew)
        bit 5,a
        jr z,.nb
        ld a,4
        ld (result),a
        ret
.nb:    bit 0,a
        jr z,.ns
        ld a,(soundmode)
        or a
        jr nz,.s1
        ld a,3
.s1:    dec a
        ld (soundmode),a
        ld hl,s_snd0
        or a
        jr z,.s2
        ld hl,s_snd1
        dec a
        jr z,.s2
        ld hl,s_snd2
.s2:    push hl
        call game_music
        ld a,(soundmode)
        or a
        call z,stop_music
        pop hl
        call hud_label_tmp
.ns:    ld a,(keysnew)
        bit 1,a
        ret z
        ; pause
        ld hl,s_paused
        call hud_label
        ld a,(soundmode)
        push af
        xor a
        ld (soundmode),a
.pl:    call do_frame
        ld a,(keysnew)
        bit 3,a
        jr nz,.quit
        bit 5,a
        jr nz,.quit
        bit 1,a
        jr z,.pl
        pop af
        ld (soundmode),a
        ld hl,0
        ld (curlabel),hl
        call hud_label_restore
        ret
.quit:  pop af
        ld (soundmode),a
        ld a,4
        ld (result),a
        ret
s_paused: db "PAUSED X:QUIT",0
s_snd0: db "SOUND OFF",0
s_snd1: db "SFX ONLY",0
s_snd2: db "MUSIC+SFX",0

; ---------------------------------------------------------------------
; a mothership has been dealt with (destroyed or escaped)
wave_clear:
        call stop_music
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld hl,s_wclear
        call banner
        ld b,110
.w:     push bc
        call idle_frame
        pop bc
        djnz .w
        call banner_clear
        ld hl,wave
        inc (hl)
        ld a,(hl)
        cp 4
        jp c,wave_start
        jp sector_clear

; one frame of "everything holds still but particles/popups/ship"
idle_frame:
        call dl_reset
        call update_particles
        call update_popups
        call update_blasts
        call ship_sprite
        jp do_frame

sector_clear:
        call stop_music
        ld hl,mus_sector_0
        ld de,mus_sector_1
        call play_music
        ld hl,s_sclear
        call banner
        ld b,60
.w1:    push bc
        call idle_frame
        pop bc
        djnz .w1
        ; 500 for every empty column, counted up
        ld hl,s_empty
        call banner2
        xor a
        ld (tmpx),a
.c:     ld a,(tmpx)
        ld l,a
        ld h,0
        ld de,colcnt
        add hl,de
        ld a,(hl)
        or a
        jr nz,.cn
        ld de,$0500
        call add_score
        ld a,SFX_TICK
        call play_sfx
        ld a,(tmpx)
        call col_flash
.cn:    ld b,8
.cw:    push bc
        call idle_frame
        pop bc
        djnz .cw
        ld hl,tmpx
        inc (hl)
        ld a,(hl)
        cp 10
        jr nz,.c
        ; the survivors in the columns are blown away
        call clear_columns_boom
        ld b,60
.w2:    push bc
        call idle_frame
        pop bc
        djnz .w2
        call banner_clear
        ; bonus round
        call bonus_round_setup
        call bonus_intro
        jp play_loop

; bonus round finished
bonus_over:
        call stop_music
        call banner_clear
        ld hl,s_bover
        call banner
        ; hits tally
        ld hl,s_hits
        call banner2
        ld a,0
        ld b,2
        call set_ink
        ld a,(bhits)
        ld de,$0F31
        call print_dec2
        ld a,(bhits)
        cp BONUS_N
        jr nz,.np
        ld de,$5000
        call add_score
        ld de,$5000
        call add_score
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call play_music
        ld hl,s_perfect
        call hud_label_tmp
.np:    ld b,150
.w:     push bc
        call idle_frame
        pop bc
        djnz .w
        call banner_clear
        xor a
        ld (bonusmode),a
        ld hl,sector
        inc (hl)
        ld a,(hl)
        cp 4
        jp c,sector_start
        call run_ending
        ld hl,lap
        inc (hl)
        xor a
        ld (sector),a
        jp sector_start

death:
        call stop_music
        ld hl,mus_death_0
        ld de,mus_death_1
        call play_music
        ld a,8
        ld (flashtim),a
        ld a,SFX_BOOM
        call play_sfx
        ld a,(shipx)
        add a,3
        ld b,a
        ld c,SHIP_Y+2
        ld a,1
        call burst
        ld a,(shipx)
        add a,3
        ld b,a
        ld c,SHIP_Y+1
        ld a,3
        call burst
        ld b,0
.an:    push bc
        call dl_reset
        call update_particles
        call update_popups
        call update_blasts
        call ms_tick_idle
        pop bc
        push bc
        ld a,b
        srl a
        srl a
        srl a
        srl a
        cp 3
        jr c,.a1
        ld a,99                 ; gone
.a1:    cp 99
        jr z,.nos
        add a,SPR_SHIPX0
        ld hl,shipx
        ld b,(hl)
        ld c,SHIP_Y
        call dl_add
.nos:   call do_frame
        pop bc
        inc b
        ld a,b
        cp 100
        jr nz,.an
        call stop_music
        call clear_objects
        ld a,(demo)
        or a
        jr z,.real
        xor a
        ret
.real:  ld hl,lives
        dec (hl)
        jr z,game_over
        call hud_lives
        call respawn
        jp life_start

game_over:
        call hud_lives
        ld hl,s_gameover
        call banner
        ld hl,mus_over_0
        ld de,mus_over_1
        call play_music
        ld b,170
.w:     push bc
        call dl_reset
        call update_particles
        call update_blasts
        call ms_tick_idle
        call do_frame
        pop bc
        djnz .w
        call stop_music
        call enter_hiscore
        jp attract

s_wclear:   db "MOTHERSHIP DONE",0
s_sclear:   db "SECTOR CLEAR!",0
s_empty:    db "EMPTY COLUMNS 500",0
s_gameover: db "GAME OVER",0
s_bover:    db "KAMIKAZE RAIN OVER",0
s_hits:     db "HITS    /30",0
s_perfect:  db "PERFECT 10000",0

; =====================================================================
        include "core.asm"
        include "sound.asm"
        include "game.asm"
        include "attract.asm"
        include "data.inc"

code_end:
        savebin "kami2.bin",start,code_end-start
shtab   equ code_end
SHIFTBUF equ shtab+NSPR*8
        assert SHIFTBUF+SHIFTSIZE <= CLEANBUF, "out of memory for shifted sprites"
        display "code+data end: ",/A,code_end, "  shift end: ",/A,SHIFTBUF+SHIFTSIZE

; =====================================================================
;  variables (zeroed at start) at $7800 (free once BASIC isn't running)
; =====================================================================
        org $7800
vars_start:
latchbase: db 0
latchcur: db 0
palbase: db 0
flashtim: db 0
framecount: dw 0
seed:   dw 0
acc1:   dw 0
acc2:   dw 0
step1:  dw 0
step2:  dw 0
soundmode: db 0
inp:    db 0
inpnew: db 0
keys:   db 0
keysnew: db 0
joyseen: db 0
ink_fg: db 0
ink_bg: db 0
inktab: ds 8
textdirect: db 0
popcol: db 0
cbudget: db 0
budget_: db 0
cfirst: db 0
q_head: db 0
q_tail: db 0
vbhook: dw 0
mptr0:  dw 0
mbase0: dw 0
mleft0: db 0
mstep0: dw 0
mfin0:  db 0
mptr1:  dw 0
mbase1: dw 0
mleft1: db 0
mstep1: dw 0
mfin1:  db 0
mplaying: db 0
sfxstep: dw 0
sfxdelta: dw 0
sfxleft: db 0
sfxmode: db 0
sfxprio: db 0
; sprite engine
sw_:    db 0
pw_:    db 0
h_:     db 0
w_:     db 0
col_:   db 0
skip_:  db 0
rowcnt: db 0
shiftn: db 0
srcptr: dw 0
shiftend: dw 0
rowd:   ds 6
dlptr:  dw 0
elptr:  dw 0
drawlist: ds 4*40+1
eraselist: ds 4*40+2
noq:    db 0
savesp: dw 0
; game state
demo:   db 0
demotim: dw 0
result: db 0
sector: db 0
wave:   db 0
wi:     db 0                    ; wave index 0..15 (sector*4+wave)
lap:    db 0
lives:  db 0
score:  ds 3
nextlife: ds 3
bonusmode: db 0
startsector: db 0
; difficulty for this wave
d_relint: db 0
d_flyspd: dw 0
d_divespd: dw 0
d_bombspd: dw 0
d_flymax: db 0
d_dropint: dw 0
d_mix:  dw 0
d_bombhp: db 0
d_coreh: db 0
; mothership
ms_state: db 0
ms_x:   db 0
ms_dir: db 0
ms_sub: db 0
ms_cargo: db 0
ms_tim: dw 0
ms_hp:  db 0
ms_img: dw 0
ms_drawn: db 0
ms_dirty: db 0
ms_done: db 0
rel_tim: db 0
; player
shipx:  db 0
shipsub: db 0
invuln: db 0
shield: db 0
twin_tim: dw 0
rapid_tim: dw 0
reload: db 0
streak: db 0
; objects
FLY_N   equ 3
DIV_N   equ 4
BLAST_N equ 3
flyers: ds 8*FLY_N
divers: ds 8*DIV_N
shots:  ds 4*2
blasts: ds 6*BLAST_N
bm_on:  db 0
bm_y:   dw 0
bm_hp:  db 0
bm_left: db 0
bm_trig: db 0
cp_type: db 0
cp_x:   db 0
cp_y:   dw 0
; columns
colcnt: ds 10
colslot: ds 40
coldirty: ds 10
colwarn: ds 10
colph:  ds 10
animcol: db 0
animtim: db 0
drop_tim: dw 0
drop_col: db 0
drop_wait: db 0
; bonus round
bspawned: db 0
bhits:  db 0
btim:   db 0
; misc
popups: ds 4*3
particles: ds 6*12
burstcol: db 0
burstidx: db 0
bcount: db 0
labeltim: db 0
curlabel: dw 0
tmpx:   db 0
tmpy:   db 0
tmpd:   db 0
cnt:    db 0
lbuf:   ds 16
tbuf:   ds 12
hitab:  ds HIENT*10
nameb:  ds 6
hirank: db 0
hiptr:  dw 0
dcnt:   db 0
attr_t: dw 0
attr_v: ds 16
gridsel: db 0
ai_tx:  db 0
ai_cool: db 0
ai_dodge: db 0
; test hooks, only ever set from the emulator (-poke); always 0 on hardware
autoplay: db 0
godmode: db 0
forceclear: db 0
vars_end:
        assert vars_end < qbuf, "vars overflow"
        display "vars end: ",/A,vars_end
