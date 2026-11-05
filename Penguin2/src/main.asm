; =====================================================================
;  PENGUIN 2 - "Ice Age Rampage"
;  for the Dick Smith VZ300 / VZ200 (Mode 1, 128x64, 4 colours)
;  with the BennVenn SD loader + 128K RAM expansion (RAM to $FFFF).
;  Sequel to the VZ200/VZ300 game PENGUIN.
;  ViBED by BPM 2026.  Assemble: sjasmplus main.asm (see build.sh)
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BGBUF   equ $F800
MASKTAB equ $F600
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10
qbuf    equ $7C00               ; 128-byte commit ring (page aligned)
GRID    equ $7C80               ; 8 rows x 16
XOFF    equ 4
YOFF    equ 6

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
        ld a,MODE1|CSS1
        ld (latchbase),a
        ld (latchcur),a
        ld (palbase),a
        ld ($6800),a
        xor a
        call cls_vram           ; start-up only (display content is garbage anyway)
        xor a
        call cls_bg
        ld a,r
        ld l,a
        ld h,$A7
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        ld a,28
        ld (cbudget),a
        ld hl,vb_none
        ld (vbhook),hl
        ld hl,hitab_init
        ld de,hitab
        ld bc,30
        ldir
        call init_sprites
        jp attract

hitab_init:
        db $03,$00,$00,"BPM"
        db $02,$00,$00,"VZ3"
        db $01,$50,$00,"ICE"
        db $01,$00,$00,"PEN"
        db $00,$50,$00,"GUN"

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
; reveal the whole BG buffer in "blinds" order (8 rows per frame)
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
        add a,8
        ld e,a
        cp 64
        jr c,.r
        call do_frame
        pop bc
        inc c
        ld a,c
        cp 8
        jr nz,.p
        call flush_queue
        ld a,28
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
        ld a,(startlevel)
        ld (level),a
        xor a
        ld (startlevel),a
        call stop_music
        ld hl,0
        ld (score),hl
        xor a
        ld (score+2),a
        ld a,4                  ; four lives, as in the original
        ld (lives),a
        ld hl,$0002             ; next extra life at 020000 (BCD, high byte first)
        ld (nextlife),hl
        xor a
        ld (nextlife+2),a
level_start:
        call setup_level
        call stage_intro
        ret nz                  ; demo aborted
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
        jp z,level_clear
        cp 2
        jp z,death
        cp 4
        jp z,quit_game
        jp bonus_over           ; 3: gold rush time up
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

; P = pause (X while paused quits), S = sound mode
keys_ingame:
        ld a,(demo)
        or a
        ret nz
        ld a,(keysnew)
        bit 0,a
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
        ld a,(goldmode)
        or a
        call z,game_music
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
        bit 1,a
        jr z,.pl
        pop af
        ld (soundmode),a
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
level_clear:
        call stop_music
        ld a,(goldmode)
        or a
        jp nz,bonus_over
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld hl,s_clear
        call banner
        ; penguin dances
        ld b,100
.d:     push bc
        call dl_reset
        call update_particles
        call update_popups
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_PDANCE0
        ld ix,peng
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        call dl_add
        call draw_popups
        call do_frame
        pop bc
        djnz .d
        ; time bonus tally: 50 per second left
        ld a,(timesec)
        or a
        jr z,.nob
        ld hl,s_tbonus
        call banner2
.tb:    ld de,$0050
        call add_score
        call hud_score
        ld a,SFX_TICK
        call play_sfx
        ld hl,timesec
        dec (hl)
        call hud_time
        call blank_keep
        call blank_keep
        ld a,(timesec)
        or a
        jr nz,.tb
        ld b,40
.w2:    push bc
        call blank_keep
        pop bc
        djnz .w2
.nob:   jp next_level

; keep current sprites, one frame
blank_keep:
        call do_frame
        ret

next_level:
        call stop_music
        ld a,(level)
        cp 9
        call z,run_dance        ; intermission after world 2's bonus
        ld a,(level)
        inc a
        cp NLEVELS
        jr c,.ok
        call run_ending
        ld hl,lap
        inc (hl)
        xor a
.ok:    ld (level),a
        jp level_start

; gold rush finished (cleared or time up)
bonus_over:
        call stop_music
        ld hl,s_bover
        call banner
        ld a,(result)
        cp 1
        jr nz,.np
        ; all smashed: perfect bonus 5000
        ld de,$5000
        call add_score
        call hud_score
        ld hl,s_perfect
        call banner2
        ld hl,mus_crystal_0
        ld de,mus_crystal_1
        call play_music
.np:    ld b,150
.w:     push bc
        call dl_reset
        call update_particles
        call update_popups
        call draw_popups
        call do_frame
        pop bc
        djnz .w
        jp next_level

death:
        call stop_music
        ld b,30
.f:     push bc
        call build_drawlist
        call do_frame
        pop bc
        djnz .f
        ld hl,mus_death_0
        ld de,mus_death_1
        call play_music
        ld a,8
        ld (flashtim),a
        ld b,0
.an:    push bc
        call dl_reset
        call update_monster_sprites
        pop bc
        push bc
        ld a,b
        srl a
        srl a
        srl a
        srl a
        cp 3
        jr c,.a1
        ld a,2
.a1:    add a,SPR_PDIE0
        ld ix,peng
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        call dl_add
        call update_particles
        pop bc
        push bc
        ld a,b
        cp 20
        jr nz,.nb
        ld ix,peng
        ld a,(ix+A_X)
        add a,4
        ld b,a
        ld a,(ix+A_Y)
        add a,3
        ld c,a
        ld a,2
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
        ld b,160
.w:     push bc
        call dl_reset
        call update_monster_sprites
        call do_frame
        pop bc
        djnz .w
        call stop_music
        call enter_hiscore
        jp attract

s_clear:    db "STAGE CLEAR!",0
s_tbonus:   db "TIME BONUS",0
s_gameover: db "GAME OVER",0
s_bover:    db "GOLD RUSH OVER",0
s_perfect:  db "PERFECT! 5000",0

; =====================================================================
        include "core.asm"
        include "sound.asm"
        include "game.asm"
        include "attract.asm"
        include "data.inc"

code_end:
        savebin "penguin2.bin",start,code_end-start
shtab   equ code_end
SHIFTBUF equ shtab+NSPR*8
        assert SHIFTBUF+SHIFTSIZE <= MASKTAB, "out of memory for shifted sprites"
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
; game
demo:   db 0
demotim: dw 0
result: db 0
level:  db 0
lap:    db 0
lives:  db 0
score:  ds 3
nextlife: ds 3
goldmode: db 0
lvptr:  dw 0
lv_eggs: db 0
lv_max: db 0
lv_roster: db 0
lv_speed: db 0
startx: db 0
starty: db 0
eggs_left: db 0
alive:  db 0
hatchdelay: db 0
timesec: db 0
framesub: db 0
hurry:  db 0
invuln: db 0
pushtim: db 0
facing: db 0
skatetim: db 0
crystal_done: db 0
fishval: db 0
golds:  db 0
itemkind: db 0
itemtim: dw 0
itemcx: db 0
itemcy: db 0
wallside: db 0
walltim: db 0
labeltim: db 0
curlabel: dw 0
ai_cool: db 0
tmpx:   db 0
tmpy:   db 0
tmpd:   db 0
best:   db 0
bestd:  db 0
cnt:    db 0
peng:   ds 16
mons:   ds 16*4
blks:   ds 16*2
breaks: ds 4*8
popups: ds 4*4
particles: ds 6*10
hitab:  ds 30
attr_t: dw 0
attr_v: ds 16
nameb:  ds 4
hiptr:  dw 0
snow:   ds 3*12
burstcol: db 0
burstidx: db 0
bcount: db 0
cand:   ds 4
curblk: dw 0
noq:    db 0
tbuf:   ds 12
infohook: dw 0
savesp: dw 0
startlevel: db 0
; test hooks, only ever set from the emulator (-poke); always 0 on hardware
autoplay: db 0
godmode: db 0
forceclear: db 0
ai_bx:  db 0
ai_by:  db 0
wbuf:   ds 34
lbuf:   ds 12
vars_end:
        assert vars_end < qbuf, "vars overflow"
        display "vars end: ",/A,vars_end
