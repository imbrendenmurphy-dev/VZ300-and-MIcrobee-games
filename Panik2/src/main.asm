; =====================================================================
;  PANIK 2 - "DIG DEEPER!"
;  for the Dick Smith VZ300 / VZ200 (Mode 1, 128x64, 4 colours)
;  with the BennVenn SD loader + 128K RAM expansion.
;  Sequel to the VZ game PANIK (VZ-PANIC).
;  ViBED by BPM 2026.  Assemble: sjasmplus main.asm (see build.sh)
;
;  Memory map
;   $4000-$67FF  BennVenn SRAM as the SD DOS leaves it (mapping 1):
;                pre-shifted, pre-masked sprites (built at start-up)
;   $7000-$77FF  video RAM
;   $7800-$7BFF  variables      $7C00-$7C7F commit queue    $7FFE stack
;   $8000-$E7FF  code + data (the .VZ file)
;   $E800-$EFFF  CLEAN: the playfield without text/popups (restore source)
;   $F000-$F1FF  stage tables (holes, timers, floor types, ladders, spawns)
;   $F600-$F7FF  sprite mask tables
;   $F800-$FFFF  BG: background buffer, copied to video RAM in vblank
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BGBUF   equ $F800
CLEAN   equ $E800
MASKTAB equ $F600
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10
qbuf    equ $7C00               ; 128-byte commit ring (page aligned)
HOLES   equ $F000               ; 64: hole state per floor*16+slot (0-3, bit7 = alien inside)
HTIM    equ $F040               ; 64: refill timers
FLT     equ $F080               ; 64: floor type (0 girder 1 steel 2 gem)
LAD     equ $F0C0               ; 64: ladder between floor k and k+1 at slot
SPAWN   equ $F100               ; 16: alien types in arrival order
shtab   equ $4000               ; sprite shift table, then the shifted sprites
SHIFTBUF equ shtab+NSPR*8

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
        xor a
        call cls_vram           ; start-up only (display content is garbage anyway)
        xor a
        call cls_bg
        call sram_check         ; the 10K SRAM window must be there
        ld a,r
        ld l,a
        ld h,$B5
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        ld a,22
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
        db $01,$50,$00,"DIG"
        db $01,$00,$00,"PAN"
        db $00,$50,$00,"IIK"

; ---------------------------------------------------------------------
; SRAM check: the sprites live in the BennVenn SRAM at $4000-$67FF, which
; the SD DOS leaves mapped and writable (mapping 1).  If it doesn't hold a
; test pattern, try selecting mapping 1 once; if that fails too, say so.
sram_check:
        call .test
        ret z
        ld a,1
        out ($37),a
        call .test
        ret z
        ld a,MODE1
        ld ($6800),a
        ld a,$AA
        call cls_vram
        ld a,1
        ld b,2
        call set_ink
        ld a,1
        ld (textdirect),a
        ld hl,s_noram1
        ld e,24
        call print_c
        ld hl,s_noram2
        ld e,32
        call print_c
.halt:  jr .halt
.test:  ld hl,$4000
.t1:    ld a,l
        xor h
        xor $5A
        ld (hl),a
        inc hl
        ld a,h
        cp $68
        jr nz,.t1
        ld hl,$4000
.t2:    ld a,l
        xor h
        xor $5A
        cp (hl)
        ret nz
        cpl
        ld (hl),a
        cp (hl)
        ret nz
        inc hl
        ld a,h
        cp $68
        jr nz,.t2
        xor a
        ret
s_noram1: db "PANIK 2 NEEDS THE BENNVENN",0
s_noram2: db "SD LOADER WITH 128K RAM",0

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
        ld a,22
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
        ld a,3                  ; three diggers, as in the original
        ld (lives),a
        ld hl,$0002             ; extra life at 020000, then every 40000
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
        jp bonus_over           ; 3: gem dig time up
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
        ld a,(lv_kind)
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
        call hud_label_hold
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
        jp hud_label_restore
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
        ld a,(lv_kind)
        or a
        jp nz,bonus_over
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld hl,s_clear
        call banner
        ; the digger celebrates
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
        add a,SPR_DWIN0
        ld hl,(px)
        ld b,l
        ld c,h
        call dl_add
        call do_frame
        pop bc
        djnz .d
        ; oxygen bonus: 10 per unit left
        ld a,(o2)
        or a
        jr z,.nob
        ld hl,s_o2bonus
        call banner2
.tb:    ld de,$0020
        call add_score
        ld a,SFX_TICK
        call play_sfx
        ld hl,o2
        dec (hl)
        jr z,.tz
        dec (hl)
.tz:    call hud_o2
        call blank_keep
        ld a,(o2)
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
        jp do_frame

next_level:
        call stop_music
        ld a,(level)
        cp 9
        call z,run_inter        ; coffee break after world 2's gem dig
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

; gem dig finished (all found, or time up)
bonus_over:
        call stop_music
        ld hl,s_bover
        call banner
        ld a,(result)
        cp 1
        jr nz,.np
        ld de,$5000
        call add_score
        ld hl,s_perfect
        call banner2
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
.np:    ld b,150
.w:     push bc
        call dl_reset
        call update_particles
        call update_popups
        call do_frame
        pop bc
        djnz .w
        jp next_level

death:
        call stop_music
        ld b,25
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
        ld a,(o2)
        or a
        jr nz,.nm
        ld hl,s_noair
        call hud_label_hold
.nm:    ld b,0
.an:    push bc
        call dl_reset
        call alien_sprites
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
.a1:    add a,SPR_DDIE0
        ld hl,(px)
        ld b,l
        ld c,h
        call dl_add
        call update_particles
        pop bc
        push bc
        ld a,b
        cp 20
        jr nz,.nb
        ld a,(px)
        add a,4
        ld b,a
        ld a,(py)
        add a,3
        ld c,a
        ld a,3
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
        call alien_sprites
        call do_frame
        pop bc
        djnz .w
        call stop_music
        call enter_hiscore
        jp attract

s_clear:    db "STAGE CLEAR!",0
s_o2bonus:  db "OXYGEN BONUS",0
s_gameover: db "GAME OVER",0
s_bover:    db "GEM DIG OVER",0
s_perfect:  db "ALL GEMS! 5000",0
s_noair:    db "OUT OF AIR!",0

; =====================================================================
        include "core.asm"
        include "sound.asm"
        include "game.asm"
        include "ai.asm"
        include "attract.asm"
        include "data.inc"

code_end:
        savebin "panik2.bin",start,code_end-start
        assert code_end <= CLEAN, "code+data overlaps the CLEAN buffer"
        assert SHIFTBUF+SHIFTSIZE <= $6800, "shifted sprites don't fit the SRAM window"
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
drawlist: ds 5*24+1
eraselist: ds 4*24+2
dl_xy:  dw 0
dl_src: dw 0
; game flow
demo:   db 0
demotim: dw 0
result: db 0
level:  db 0
lap:    db 0
lives:  db 0
score:  ds 3
nextlife: ds 3
world:  db 0
lvptr:  dw 0
lv_ng:  db 0
lv_nb:  db 0
lv_nk:  db 0
lv_max: db 0
lv_speed: db 0
lv_o2:  db 0
lv_kind: db 0
lv_spdh: db 0
lv_chase: db 0
lv_trap: db 0
total:  db 0
spawned: db 0
killed: db 0
alive:  db 0
spawncool: db 0
gems_left: db 0
gemval: db 0
; player (px,py adjacent: loaded as a word)
px:     db 0
py:     db 0
pfl:    db 0
pst:    db 0
pdir:   db 0
panim:  db 0
pladk:  db 0
pdig:   db 0
prep:   db 0
boots:  dw 0
drill:  dw 0
freeze: db 0
invuln: db 0
o2:     db 0
o2cnt:  db 0
o2small: db 0
hurry:  db 0
htick:  db 0
combo:  db 0
itemk:  db 0
itemfl: db 0
itemsl: db 0
itemtim: dw 0
itemcool: dw 0
aliens: ds 16*6
popups: ds 4*4
particles: ds 6*10
labeltim: db 0
labelheld: db 0
curlabel: dw 0
hitab:  ds 30
attr_t: dw 0
attr_v: ds 16
nameb:  ds 4
hiptr:  dw 0
burstcol: db 0
burstidx: db 0
bcount: db 0
noq:    db 0
tbuf:   ds 12
infohook: dw 0
savesp: dw 0
startlevel: db 0
tmpx:   db 0
tmpy:   db 0
tmpd:   db 0
cnt:    db 0
; demo AI
aiprev: db 0
aitx:   db 0
aiwait: db 0
aiclimb: db 0
; test hooks, only ever set from the emulator (-poke); always 0 on hardware
autoplay: db 0
godmode: db 0
forceclear: db 0
wbuf:   ds 34
lbuf:   ds 16
vars_end:
        assert vars_end < qbuf, "vars overflow"
        display "vars end: ",/A,vars_end
