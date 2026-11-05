; =====================================================================
;  ATTACK OF THE KILLER TOMATOES - RE-SAUCED
;  VZ300 (stock 16K) remake, inspired by Apolon Ivankovic's 1984 original
;  Assemble: sjasmplus main.asm  -> build/game.bin (loads at $7B00)
; =====================================================================
        DEVICE NONE

VRAM    equ $7000
LATCH   equ $6800
MASKP   equ $78
COLP    equ $79
FLASHP  equ $7A
MAZEY   equ 9
STACKTOP equ $F800
LOADADR equ $8000

; latch bits
GFX     equ $08
CSS     equ $10

; input bits
I_UP    equ 0
I_DN    equ 1
I_LT    equ 2
I_RT    equ 3
I_FIRE  equ 4
I_SHOOT equ 5
I_PAUSE equ 6

; entity struct
E_TYPE  equ 0
E_STATE equ 1
E_CX    equ 2
E_CY    equ 3
E_DIR   equ 4
E_PROG  equ 5
E_X     equ 6
E_Y     equ 7
E_ANIM  equ 8
E_TIMER equ 9
E_HP    equ 10
E_ACC   equ 11
E_SPD   equ 12
E_FLASH equ 13
E_AUX   equ 14
E_AUX2  equ 15
ESIZE   equ 16
NENTS   equ 12              ; 0 player, 1..10 enemies, 11 shot

; entity types
T_NONE  equ 0
T_PLAYER equ 1
T_CHERRY equ 2
T_ROMA  equ 3
T_BEEF  equ 4
T_UNRIPE equ 5
T_GOLD  equ 6
T_HOP   equ 7
T_ROT   equ 8
T_BALL  equ 9
T_SHOT  equ 10
T_SEED  equ 11
T_BOSS  equ 12

; entity states
S_WALK  equ 0
S_CAUGHT equ 1
S_STUN  equ 2
S_SQUASH equ 3
S_SPAWN equ 4
S_DEAD  equ 5

; tile codes
TL_FLOOR equ $00
TL_STAIN equ $01
TL_TRAP1 equ $02
TL_TRAP2 equ $03
TL_TRAP3 equ $04
TL_TRAPC equ $05
TL_GUN  equ $08
TL_SNEAK equ $09
TL_RECORD equ $0A
TL_X2   equ $0B
TL_COLAND equ $0C
TL_DISG equ $0D
TL_CAN  equ $0E
TL_LET  equ $10             ; $10..$14 letters S A U C E
TL_CONV equ $18             ; $18..$1B U D L R
TL_HAZ  equ $1C             ; $1C off $1D warn $1E on
TL_HOLE equ $1F
TL_STINK equ $07
TL_WALL equ $80
TL_DIRTY equ $40

        OUTPUT "build/game.bin"
        ORG LOADADR

start:
        di
        ld sp,STACKTOP
        ; clear BSS
        ld hl,bss_start
        ld de,bss_start+1
        ld bc,bss_end-bss_start-1
        ld (hl),0
        ldir
        ld a,GFX|$01
        ld (latch_val),a
        ld (LATCH),a
        ld a,1
        ld (music_ok),a
        ld (diff),a
        IFDEF AUTOPLAY
        IFNDEF NOTRAIN
        ld (trainer),a
        ENDIF
        ld a,STARTST
        ld (startst),a
        call game_main
        ENDIF
        ld hl,$ACE1
        ld (seed),hl
        call joy_detect
        call init_hiscores
        xor a
        call cls
attract:
        call title_screen
        jr z,new_game
        call story
        jr z,new_game
        call cast_screens
        jr z,new_game
        call demo_play
        jr z,new_game
        call hiscore_screen
        jr z,new_game
        jr attract

new_game:
        call game_main
        jr attract

; ---------------------------------------------------------------------
;  input
; ---------------------------------------------------------------------
joy_detect:                     ; 0 none, 1 = J1 only, 2 = both (idle lines read high)
        ld b,0
        in a,($2C)
        and $1F
        cp $1F
        jr nz,.ok
        inc b
        in a,($29)
        and $1F
        cp $1F
        jr nz,.ok
        inc b
.ok:    ld a,b
        ld (joy_on),a
        ret

read_input:
        ld c,0
        ld a,($68FE)            ; row0: Q bit4
        bit 4,a
        jr nz,$+4
        set I_UP,c
        ld a,($68FD)            ; row1: A bit4
        bit 4,a
        jr nz,$+4
        set I_DN,c
        ld a,($68BF)            ; row6: O bit1, P bit4, RETURN bit2
        bit 1,a
        jr nz,$+4
        set I_LT,c
        bit 4,a
        jr nz,$+4
        set I_RT,c
        bit 2,a
        jr nz,$+4
        set I_PAUSE,c
        ld a,($68EF)            ; row4: M bit5 (left), ',' bit3 (right), SPACE bit4
        bit 5,a
        jr nz,$+4
        set I_LT,c
        bit 3,a
        jr nz,$+4
        set I_RT,c
        bit 4,a
        jr nz,$+4
        set I_FIRE,c
        ld a,($68FB)            ; row2: X bit1, C bit3 (fire) Z bit4 (shoot)
        bit 1,a
        jr nz,$+4
        set I_FIRE,c
        bit 3,a
        jr nz,$+4
        set I_FIRE,c
        bit 4,a
        jr nz,$+4
        set I_SHOOT,c
        ld a,(joy_on)
        or a
        jr z,.nj
        in a,($2C)              ; joystick 1 directions
        cpl
        and $0F
        or c
        ld c,a
        in a,($2E)              ; J1 fire
        bit 4,a
        jr nz,$+4
        set I_FIRE,c
        in a,($2D)              ; J1 arm
        bit 4,a
        jr nz,$+4
        set I_SHOOT,c
        ld a,(joy_on)
        cp 2
        jr nz,.nj
        in a,($29)              ; joystick 2 directions
        cpl
        and $0F
        or c
        ld c,a
        in a,($2B)              ; J2 fire
        bit 4,a
        jr nz,$+4
        set I_FIRE,c
        in a,($27)              ; J2 arm
        bit 4,a
        jr nz,$+4
        set I_SHOOT,c
.nj:    ld a,($68FD)            ; S = music on/off (row1 bit1)
        cpl
        and 2
        ld b,a
        ld a,(s_prev)
        cpl
        and b
        ld a,b
        ld (s_prev),a
        jr z,.nm
        ld a,(music_ok)
        xor 1
        ld (music_ok),a
.nm:    ld a,(inp)
        ld (inp_prev),a
        ld a,c
        ld (inp),a
        ld a,(inp_prev)
        cpl
        and c
        ld (inp_new),a
        ret

; any key or fire? -> NZ if pressed (keyboard any row)
any_key:
        ld a,($6800)
        and $3F
        cp $3F
        ret nz
        ld a,(joy_on)
        or a
        ret z
        in a,($2C)
        and $10
        xor $10
        ret

; wait_frames: B = frames; returns Z early if fire pressed (new press)
wait_frames:
        push bc
        call sound_tick
        call frame_sync
        call read_input
        pop bc
        ld a,(inp_new)
        and 1<<I_FIRE
        jr nz,.fire
        djnz wait_frames
        or 1
        ret
.fire:  xor a
        ret

; ---------------------------------------------------------------------
;  random: xorshift16 -> A (and HL)
; ---------------------------------------------------------------------
rand:
        push hl
        ld hl,(seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (seed),hl
        pop hl
        ret

; rand_n: A = n -> A = random 0..n-1
rand_n:
        push bc
        ld c,a
        call rand
.m:     cp c
        jr c,.ok
        sub c
        jr .m
.ok:    pop bc
        ret

        include "gfx.asm"
        include "snd.asm"
        include "game.asm"
        include "ents.asm"
        include "front.asm"
        include "gen_data.inc"
        include "gen_title.inc"

code_end:
        OUTEND
        DISPLAY "code end: ",/H,code_end, " size: ",/D,code_end-LOADADR

; ---------------------------------------------------------------------
;  BSS (not saved in file)
; ---------------------------------------------------------------------
        ORG code_end
bss_start:
sp_save: ds 2
fr_pat: ds 1
bt_v:   ds 1
bt_m:   ds 1
bt_c:   ds 1
bt_f:   ds 1
flashc: ds 1
cmap:   ds 4
bw:     ds 1
bstep:  ds 1
txt_fg: ds 1
txt_bg: ds 1
txt_mode: ds 1
txt_x:  ds 1
txt_x0: ds 1
txt_y:  ds 1
str_delay: ds 1
lg_fg:  ds 1
lg_sh:  ds 1
latch_val: ds 1
snd_period: ds 1
snd_noise: ds 1
frame_cnt: ds 1
mus_ptr: ds 2
mus_start: ds 2
mus_timer: ds 1
mus_per: ds 1
mus_gate: ds 1
mus_on: ds 1
sfx_ptr: ds 2
sfx_timer: ds 1
sfx_per: ds 1
sfx_flags: ds 1
music_ok: ds 1
joy_on: ds 1
inp:    ds 1
inp_prev: ds 1
inp_new: ds 1
seed:   ds 2
; game
score:  ds 3
lives:  ds 1
stage:  ds 1
lap:    ds 1
world:  ds 1
kind:   ds 1
bossid: ds 1
letters: ds 1
letter_shown: ds 1
demo:   ds 1
demo_timer: ds 2
hiscores: ds 8*6
hi_rank: ds 1
; stage
tilemap: ds 176
dbk:    ds 11*16
dbn:    ds 11
erow:   ds NENTS
rcnt:   ds 11
rpos:   ds 11
ord:    ds NENTS
ord_p:  ds 2
cur_row: ds 1
tile_cache: ds 32*10
ents:   ds NENTS*ESIZE
NPART   equ 12
PSIZE   equ 12
parts:  ds NPART*PSIZE
NPOP    equ 4
POPSZ   equ 30
pops:   ds NPOP*POPSZ
stage_ptr: ds 2
maze_ptr: ds 2
spawn1: ds 1
spawn2: ds 1
pstart: ds 1
wave_ptr: ds 2
stime:  ds 2                ; stage time in frames/25 (half-seconds)
stime_sub: ds 1
hurry:  ds 1
hurry_t: ds 1
tleft:  ds 1                ; tomatoes remaining (incl. pending waves)
traps:  ds 1
pk_timer: ds 1
pk_period: ds 1
pk_cell: ds 1
pk_life: ds 1
pw_sneak: ds 1
pw_record: ds 1
pw_x2:  ds 1
pw_disg: ds 1
shield: ds 1
gun_ammo: ds 1
gun_lvl: ds 1
invuln: ds 1
combo:  ds 1
combo_t: ds 1
tick_t: ds 1
tick_msg: ds 1
hud_dirty: ds 1
haz_t:  ds 1
haz_ph: ds 1
conv_t: ds 1
conv_f: ds 1
nhaz:   ds 1
hazcells: ds 8
nconv:  ds 1
convcells: ds 16
holes:  ds 2
nholes: ds 1
build_t: ds 1
whack_t: ds 1
face:   ds 1
want:   ds 1
dying:  ds 1
damaged: ds 1
clear_t: ds 1
boss_ptr: ds 2
boss_spawn_t: ds 1
seed_t: ds 1
news_t: ds 1
gold_done: ds 1
bonus_cnt: ds 1
shake:  ds 1
target_cell: ds 1
paused: ds 1
quit:   ds 1
result: ds 1
tmp:    ds 4
hz_look: ds 1
flash_scr: ds 1
cont_ok: ds 1
kl_new: ds 1
kl_last: ds 1
jprev:  ds 1
tick_ptr: ds 2
tick_col: ds 1
tick_clr: ds 1
scan_pos: ds 1
scan_n: ds 1
scan_tmp: ds 8
narmed: ds 1
armed:  ds 8
bait_cell: ds 1
bot_d:  ds 1
bot_t:  ds 1
bot_best_dir: ds 1
txt_center: ds 1
fe_bg:  ds 1
fe_anim: ds 2
opt_show: ds 1
opt_prev: ds 1
drip_t: ds 1
dripy:  ds 8
look_t: ds 1
look:   ds 1
march_x: ds 1
cast_ptr: ds 2
demo_key: ds 1
hi_ptr: ds 2
name_pos: ds 1
name_buf: ds 4
fe_world: ds 1
fe_kind: ds 1
menu_ptr: ds 2
menu_x: ds 1
seen_types: ds 1
s_prev: ds 1
stars:  ds 32
stink_cell: ds 1
stink_t: ds 1
pw_daze: ds 1
bot_hold: ds 1
bot_dir: ds 1
best: ds 1
bestd: ds 1
minions: ds 1
pk_code: ds 1
cur_ent: ds 2
dflags: ds 1
bossw:  ds 1
bossrows: ds 1
wptr:   ds 2
wallbuf: ds 10
last_1up: ds 1
stage_in_world: ds 1
snd_hi: ds 1
trainer: ds 1
diff:   ds 1
startst: ds 1
mus_kind: ds 1
mus2_ptr: ds 2
mus2_start: ds 2
mus2_timer: ds 1
mus2_per: ds 1
mus_env: ds 1
cheat_buf: ds 8
bss_end:
        ASSERT bss_end < STACKTOP-256
        DISPLAY "bss end: ",/H,bss_end
