; =====================================================================
;  GHOST HUNTER 3-D  -  for the Dick Smith VZ300 (Mode 1, 128x64)
;  BennVenn SD loader + 128K: big scrolling mazes in SRAM bank A
;  Sequel to "VZ Ghost Hunter" by Dubois & McNamara and Ghost Hunter 2
;  ViBED by BPM 2026
;  Assemble: sjasmplus main.asm  (see BUILD.md)
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BGBUF   equ $6000           ; full-screen background (bank B: title/attract/intermissions)
MAXH    equ 36              ; tallest maze (cells)
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10

        org $8000
start:
        di
        ld sp,STACKTOP
        ; the attract overlay goes to SRAM bank B at $4000
        call bank_b
        ld hl,ovl_src
        ld de,$4000
        ld bc,ovl_len
        ldir
        ; clear variables
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld a,MODE1
        ld (latchbase),a
        ld ($6800),a
        ld a,$AA
        call cls_vram
        ld a,r
        ld l,a
        ld h,$5A
        ld (seed),hl
        ld a,1
        ld (soundon),a
        ; default hiscore table
        ld hl,hitab_init
        ld de,hitab
        ld bc,30
        ldir
        ld hl,hitab
        ld de,hiscore
        ld bc,3
        ldir
        call init_sprites
        jp attract

; ---------------------------------------------------------------------
; DEMO (real engine, AI player) - in main RAM because the game maps bank A
run_demo:
        call wipe_out
        call stop_music
        ld a,1
        ld (demo),a
        call random
        and 7
        cp 6
        jr c,.dm
        sub 4
.dm:    ld (demomaze),a
        and 3
        inc a
        ld (level),a
        ld a,1
        ld (lives),a
        ld hl,score
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld hl,1500
        ld (demotim),hl
        call level_start
        push af
        call leave_game_mode
        xor a
        ld (demo),a
        ld (sirenmode),a
        ld (palbase),a
        ld (frighttim),a
        ld (supertim),a
        call stop_music
        pop af
        ret

hitab_init:
        db $01,$00,$00,"BPM"
        db $00,$80,$00,"DUB"
        db $00,$60,$00,"MAC"
        db $00,$40,$00,"VZ "
        db $00,$20,$00,"BOO"

; ---------------------------------------------------------------------
; do_frame: palette, sound, wait vblank, render sprites, read input
; ---------------------------------------------------------------------
do_frame:
        ld a,(palbase)
        ld b,a
        ld a,(flashtim)
        or a
        jr z,.nf
        dec a
        ld (flashtim),a
        ld a,b
        xor CSS1
        ld b,a
.nf:    ld a,b
        or MODE1
        ld (latchbase),a
        call sound_tick
        call frame_wait
        ld a,(gmode)
        or a
        jr z,.att
        call render_game
        jp read_input
.att:   call render
        jp read_input

; empty frame (no sprites)
blank_frame:
        call dl_reset
        jp do_frame

; wait B frames (keeps sprites as in list); returns NZ if start pressed
wait_frames:
        push bc
        call do_frame
        call check_start
        pop bc
        ret nz
        djnz wait_frames
        xor a
        ret

; blinds wipe to blue
wipe_out:
        call dl_reset
        call do_frame
        ld c,0
.p:     push bc
        ld hl,VRAM
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a                  ; row c
        ld b,8
.r:     push bc
        ld b,32
.b:     ld (hl),$AA
        inc hl
        djnz .b
        ld de,32*7
        add hl,de
        pop bc
        djnz .r
        call do_frame
        pop bc
        inc c
        ld a,c
        cp 8
        jr nz,.p
        ret
; blinds reveal BG buffer
wipe_in:
        call dl_reset
        ld c,0
.p:     push bc
        ld hl,BGBUF
        ld de,VRAM
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld e,a
        ld b,8
.r:     push bc
        ld bc,32
        ldir
        ld bc,32*7
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        call do_frame
        pop bc
        inc c
        ld a,c
        cp 8
        jr nz,.p
        ret

; restore a VRAM rect from BG: D col, E row, B width, C height
restore_rect:
        call scraddr
.r:     push bc
        push hl
.b:     ld a,h
        and $EF
        ld d,a
        ld e,l
        ld a,(de)
        ld (hl),a
        inc l
        djnz .b
        pop hl
        ld de,32
        add hl,de
        pop bc
        dec c
        jr nz,.r
        ret

; clear eraselist (after full redraws)
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
        call stop_music
        call wipe_out
        ld hl,score
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld a,3
        ld (lives),a
        xor a
        ld (extragiven),a
        ld a,(startlevel)       ; (test harness: start on a later round)
        or a
        jr nz,.sl
        inc a
.sl:    ld (level),a
level_start:
        xor a
        ld (spawned),a
        ld (sirenmode),a
        ld (gmode),a
        call setup_round
        call clear_erase
        call reset_actors
        call enter_game_mode
        call reveal_maze
        ld a,1
        ld (firstlife),a
        call round_banner
life_start:
        call ready_sequence
        ret nz                  ; demo aborted by start -> handled by caller
        ; main play loop
play_loop:
        call game_logic
        ld (result),a
        call build_drawlist
        call hud_power
        call update_hud
        call keys_ingame
        ld a,(swoopreq)
        or a
        jr z,.nsw
        xor a
        ld (swoopreq),a
        call cam_swoop
.nsw:   call update_camera
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
        cp 1
        jp z,level_clear
        cp 2
        jp z,death
        jp time_up
.demo_end:
        xor a
        ret
.demo_start:
        ld a,1
        or a
        ret

; P = pause, S = sound toggle
keys_ingame:
        ld a,(demo)
        or a
        ret nz
        ld a,(keysnew)
        bit 0,a
        jr z,.ns
        ld a,(soundon)
        xor 1
        ld (soundon),a
.ns:    ld a,(keysnew)
        bit 1,a
        ret z
        ; pause
        ld a,1
        ld (pause),a
        ld hl,s_paused
        ld a,3
        call hud_label
        ld a,(soundon)
        push af
        xor a
        ld (soundon),a
.pl:    call do_frame
        ld a,(keysnew)
        bit 1,a
        jr z,.pl
        pop af
        ld (soundon),a
        xor a
        ld (pause),a
        ld hl,0
        ld (lastlabel),hl
        ret
s_paused: db "PAUSED",0

; banner before a round (bonus rounds explain themselves)
round_banner:
        ld a,(demo)
        or a
        ret nz
        ld a,(roundtype)
        or a
        ret z
        ld hl,s_buffet
        ld (roundtype_lbl),hl
        ld hl,1500
        ld (roundtim),hl
        ld hl,s_bb1
        ld de,s_bb2
        ld a,(roundtype)
        cp 1
        jr z,.b
        ld hl,s_panic
        ld (roundtype_lbl),hl
        ld hl,2500
        ld (roundtim),hl
        ld hl,s_pb1
        ld de,s_pb2
.b:     push de
        push hl
        ld a,3
        ld (hud_dirty),a
        call update_hud
        xor a
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld d,4
        ld e,8
        ld b,24
        ld c,22
        ld a,$AA
        call fill_rect
        ld hl,s_bonus
        ld e,10
        call print_c
        ld a,1
        ld b,2
        call set_ink
        pop hl
        ld e,18
        call print_c
        ld a,0
        ld b,2
        call set_ink
        pop hl
        ld e,26
        call print_c
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        call play_music
        ld b,150
.w:     push bc
        call blank_frame
        pop bc
        djnz .w
        call stop_music
        ld a,1
        ld (panflag),a
        call clear_erase
        ld a,3
        ld (hud_dirty),a
        ret
s_bonus: db "* BONUS ROUND *",0
s_bb1: db "GHOST BUFFET!",0
s_bb2: db "30 SECONDS. EAT ALL YOU CAN",0
s_pb1: db "PELLET PANIC!",0
s_pb2: db "CLEAR IT IN 50 SEC",0

; READY! with sprites shown; first life of a level plays the jingle
ready_sequence:
        xor a
        ld (frighttim),a
        ld (palbase),a
        ld (pvisible),a
        ld a,3
        ld (hud_dirty),a
        call update_hud
        ld hl,0
        ld (lastlabel),hl
        ld a,(demo)
        or a
        jr z,.nd
        ld hl,s_demo
        ld a,3
        call hud_label
.nd:    xor a
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        call ready_row
        ld hl,s_ready
        call print_c
        ld b,60
        ld a,(firstlife)
        or a
        jr z,.short
        ; first life: the maze's name too
        xor a
        ld b,2
        call set_ink
        call name_row
        ld hl,(mazename)
        call print_c
        ld b,60
        ld a,(demo)
        or a
        jr nz,.short
        ld hl,mus_start_0
        ld de,mus_start_1
        call play_music
        ld b,130
.short: xor a
        ld (firstlife),a
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
        call stop_music
        call ready_row
        ld d,13
        ld bc,$0605
        call restore_rect_game
        call name_row
        ld d,0
        ld bc,$2005
        call restore_rect_game
        ld a,1
        ld (pvisible),a
        ld a,(PLAYER+A_X)
        add a,4
        ld b,a
        ld a,(PLAYER+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,1
        call burst
        xor a
        ret
s_ready: db "READY!",0
; E = screen row for the maze name (under READY!, or above it near the bottom)
name_row:
        call ready_row
        ld a,e
        add a,6
        cp 59
        jr c,.n
        sub 12
.n:     ld e,a
        ret
; E = screen row for a message under the hero (kept inside the view)
ready_row:
        ld a,(camy)
        ld e,a
        ld a,(PLAYER+A_Y)
        sub e
        add a,VPTOP+7
        cp 58
        jr c,.r
        sub 14
.r:     ld e,a
        ret

level_clear:
        ld a,(demo)
        or a
        jr z,.real
        xor a
        ret
.real:
        xor a
        ld (sirenmode),a
        ld (frighttim),a
        ld (supertim),a
        ld (palbase),a
        ; pellet panic bonus
        ld a,(roundtype)
        cp 2
        jr nz,.np
        ld de,$5000
        call add_score
        ld a,P_5000
        call popup_at_player
.np:    ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ; ghosts vanish, maze flashes
        ld b,100
.f:     push bc
        call dl_reset
        ld ix,PLAYER
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        ld a,SPR_HERO_R2
        call dl_add_map
        call update_particles
        pop bc
        push bc
        ld a,b
        and 8
        jr z,.p0
        ld a,CSS1
.p0:    ld (palbase),a
        ld a,b
        and 15
        jr nz,.nb
        ld a,(PLAYER+A_X)
        add a,4
        ld b,a
        ld a,(PLAYER+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,1
        call burst
.nb:    call update_hud
        call do_frame
        pop bc
        djnz .f
        xor a
        ld (palbase),a
        call stop_music
        ld a,(intermission)
        or a
        jr z,.noint
        call leave_game_mode
        ld a,(intermission)
        call run_intermission
.noint:
        ld hl,level
        inc (hl)
        call wipe_out
        jp level_start

time_up:
        xor a
        ld (sirenmode),a
        ld (frighttim),a
        ld (palbase),a
        xor a
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_timeup
        ld e,32
        call print_c
        ld b,100
.w:     push bc
        call dl_reset
        call update_particles
        call do_frame
        pop bc
        djnz .w
        ld hl,level
        inc (hl)
        call wipe_out
        jp level_start
s_timeup: db "TIME UP!",0

death:
        ld a,(demo)
        or a
        jr z,.nd
        ; demo: short death then end
.nd:    xor a
        ld (sirenmode),a
        call stop_music
        ; freeze moment
        ld b,40
.f:     push bc
        call build_drawlist
        call do_frame
        pop bc
        djnz .f
        ; ghosts vanish; death animation
        ld hl,mus_death_0
        ld de,mus_death_1
        call play_music
        xor a
        ld (supertim),a
        ld (frighttim),a
        ld (palbase),a
        ld a,6
        ld (flashtim),a
        ld b,0
.an:    push bc
        call dl_reset
        pop bc
        push bc
        ld a,b
        srl a
        srl a
        srl a
        cp 5
        jr c,.a1
        ld a,4
.a1:    add a,SPR_HDIE_0
        ld e,a
        ld a,(PLAYER+A_X)
        ld b,a
        ld a,(PLAYER+A_Y)
        ld c,a
        ld a,e
        call dl_add_map
        call update_particles
        pop bc
        push bc
        ld a,b
        cp 40
        jr nz,.nb
        ld a,(PLAYER+A_X)
        add a,4
        ld b,a
        ld a,(PLAYER+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,3
        call burst
        ld a,(PLAYER+A_X)
        add a,4
        ld b,a
        ld a,(PLAYER+A_Y)
        add a,YOFF+2
        ld c,a
        ld a,1
        call burst
.nb:    call do_frame
        pop bc
        inc b
        ld a,b
        cp 90
        jr nz,.an
        call stop_music
        ld a,(demo)
        or a
        jr z,.real
        xor a                   ; demo over
        ret
.real:  ld hl,lives
        dec (hl)
        jr z,game_over
        call reset_actors
        xor a
        ld (pvisible),a
        call cam_swoop          ; the camera glides back to the start
        jp life_start

game_over:
        ld a,3
        ld (hud_dirty),a
        call update_hud
        xor a
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_gameover
        ld e,32
        call print_c
        ld hl,mus_over_0
        ld de,mus_over_1
        call play_music
        ; ghosts dance (wobble) around for a while
        ld b,180
.w:     push bc
        call dl_reset
        ld ix,GHOST1
        ld b,4
.g:     push bc
        ld a,(framecount)
        add a,b
        add a,b
        and 15
        cp 8
        jr c,.g1
        cpl
        add a,16
.g1:    srl a
        ld c,a
        ld a,(ix+A_X)
        add a,c
        ld b,a
        ld a,(ix+A_Y)
        ld c,a
        push bc
        call ghost_sprite
        pop bc
        cp $FF
        call nz,dl_add_map
        ld de,16
        add ix,de
        pop bc
        djnz .g
        call do_frame
        pop bc
        djnz .w
        call stop_music
        call leave_game_mode
        call enter_hiscore
        jp attract

; switch the frame renderer to the scrolling view (SRAM bank A)
enter_game_mode:
        call bank_a
        call gen_copycode
        ld hl,dirtylist
        ld (dirtyp),hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld a,1
        ld (gmode),a
        ret
; back to the full-screen renderer (title, intermissions) in bank B
leave_game_mode:
        xor a
        ld (gmode),a
        ld (panflag),a
        jp bank_b
s_gameover: db "GAME OVER",0

; =====================================================================
        include "core.asm"
        include "view.asm"
        include "sound.asm"
        include "game.asm"
        include "data.inc"

; ---- the attract overlay: assembled for $4000 (SRAM bank B), copied there at boot
ovl_src:
        DISP $4000
ovl_start:
        include "attract.asm"
        include "data_ovl.inc"
ovl_end:
        ENT
ovl_len equ ovl_end-ovl_start
code_end:
        savebin "gh3.bin",start,code_end-start
; ---- runtime areas in main RAM (over the overlay's copy, free after boot)
shtab   equ ovl_src
SHIFTBUF equ shtab+NSPR*8
COPYA   equ SHIFTBUF+SHIFTSIZE  ; generated copy code, viewport rows 0..28
COPYB   equ COPYA+1576          ; rows 29..57
srctab  equ COPYB+1576          ; 58 x 4 source pointers
GRIDTOP equ srctab+4*58         ; guard row, the grid (28 x MAXH), guard row
GRID    equ GRIDTOP+28
RAMTOP  equ GRIDTOP+28*(MAXH+2)
TPAGE   equ $F900                ; 5 tile pages
MASKTAB equ $FE00                ; sprite mask / clean tables (2 pages)
; ---- bank B
BIGSHIFT equ ovl_end
        display "code+data end: ",/A,code_end," overlay: ",/A,ovl_len," runtime top: ",/A,RAMTOP
        display "bank B used to: ",/A,BIGSHIFT+SHIFTBIG," (BGBUF at $6000)"
        assert RAMTOP <= TPAGE, "out of main RAM"
        assert BIGSHIFT+SHIFTBIG <= BGBUF, "bank B overflow"
        assert code_end <= $F9F0, ".VZ too long for the loader"


; =====================================================================
;  variables (zeroed at start) - internal RAM $7800..
; =====================================================================
        org $7800
vars_start:
latchbase: db 0
palbase: db 0
flashtim: db 0
framecount: dw 0
seed:   dw 0
acc1:   dw 0
acc2:   dw 0
step1:  dw 0
step2:  dw 0
soundon: db 0
inp:    db 0
inpnew: db 0
keys:   db 0
keysnew: db 0
ink_fg: db 0
ink_bg: db 0
inktab: ds 8
textdest: db 0
; music channel blocks (ptr, base, left, step, fin)
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
sirenmode: db 0
sirenspd: db 0
sirenpos: db 0
; sprite engine
sw_:    db 0
pw_:    db 0
h_:     db 0
w_:     db 0
col_:   db 0
skip_:  db 0
rowcnt: db 0
tmp_:   db 0
shiftn: db 0
srcptr: dw 0
shiftend: dw 0
rowd:   ds 6
rowm:   ds 6
dlptr:  dw 0
elptr:  dw 0
drawlist: ds 4*48+1
eraselist: ds 4*48+2
; game
demo:   db 0
demomaze: db 0
demotim: dw 0
godmode: db 0
autoplay: db 0          ; (test harness: the AI plays a real game)
startlevel: db 0
result: db 0
level:  db 0
lives:  db 0
score:  ds 3
hiscore: ds 3
extragiven: db 0
hud_dirty: db 0
lastbar: db 0
lastbarc: db 0
lastlabel: dw 0
pause:  db 0
firstlife: db 0
mazeidx: db 0
mstyle: db 0
wox:    db 0
woy:    db 0
wflag:  db 0
wi0:    db 0
wi1:    db 0
wj0:    db 0
wj1:    db 0
wdx:    db 0
wcx:    db 0
wcy:    db 0
wdy:    db 0
roundtype: db 0
roundtype_lbl: dw 0
roundtim: dw 0
intermission: db 0
pellets: dw 0
pellets_total: dw 0
eaten:  dw 0
spawned: db 0
pspeed: db 0
gspeed: db 0
fspeed: db 0
frighttime: db 0
dizzy_chance: db 0
frighttim: db 0
frightmax: db 0
freezetim: db 0
speedtim: db 0
x2tim:  db 0
shieldtim: db 0
supertim: db 0
decoytim: db 0
decoyx: db 0
decoyy: db 0
decoycx: db 0
decoycy: db 0
pumax:  db 0
pukind: db 0
itemtim: db 0
itemspr: db 0
chasemode: db 0
modephase: db 0
modetim: dw 0
hitstop: db 0
chain:  db 0
streak: db 0
streaktim: db 0
elroy:  db 0
wakaflip: db 0
energvis: db 0
pvisible: db 0
best:   db 0
bestd:  db 0
bestdir: db 0
pdir_:  db 0
aidir:  db 0
aiscore: db 0
aitx:   db 0
aity:   db 0
npx:    db 0
npy:    db 0
npd:    db 0
burstcol: db 0
telep:  dw 0
energp: dw 0
tele_list: ds 8
energ_list: ds 16
popups: ds 12
particles: ds 12*8
actors: ds 16*5
; ---- GH3 view / level
gmode:  db 0
panflag: db 0
rpass:  db 0
camx:   db 0
camy:   db 0
maph:   db 0
maphpx: db 0
maxcamy: db 0
savesp: dw 0
bs_slot: db 0
er_col: db 0
grow_dst: dw 0
grow_pg: db 0
rc_cx:  db 0
rc_r:   db 0
rc_grid: dw 0
rc_j:   db 0
rc_cnt: db 0
gc_src: dw 0
gc_dst: dw 0
swx:    db 0
swy:    db 0
swoopreq: db 0
styleids: dw 0
styletiles: dw 0
mazename: dw 0
decalsrc: dw 0
halfbuf: ds 14
nener:  db 0
ntele:  db 0
nspots: db 0
spots:  ds 16
startcx: db 0
startcy: db 0
doorcy: db 0
exitcy: db 0
exity:  db 0
housey: db 0
itemx:  db 0
itemy:  db 0
pitry:  db 0
spawnstep: dw 0
hudcache: ds 12
npy0:   db 0
npy1:   db 0
npsweep: db 0
tunrow: ds MAXH+1
ndecals: db 0
decalidx: db 0
D_X     equ 0
D_Y     equ 1
D_KIND  equ 2
D_BASE  equ 3
D_FRAME equ 4
D_TIM   equ 5
D_FLG   equ 6
DSIZE   equ 8
decals: ds 16*DSIZE
NDIRTY  equ 20
dirtyp: dw 0
dirtylist: ds 4*NDIRTY+2
rr_tmp: ds 6
hitab:  ds 30
attr_t: dw 0
attr_v: ds 16
nameb:  ds 4
hiptr:  dw 0
vars_end:
        assert vars_end < $7F00, "vars overflow into stack"
        display "vars end: ",/A,vars_end
