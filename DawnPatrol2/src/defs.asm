; ===================================================================
;  DAWN PATROL 2  -  definitions, memory map and RAM variables
; ===================================================================

LATCH       equ $6800
VRAM        equ $7000
BUF         equ $D400          ; back buffer, 48 bytes x 64 rows
BSTR        equ 48             ; back buffer stride
BTOP        equ 5              ; buffer row of playfield py=0
VTOP        equ 7              ; VRAM row of playfield py=0
PFH         equ 54             ; playfield height
SPRMEM      equ $E000          ; pre-shifted sprites (main RAM, $E000-$FFFF)
SPRMEM2     equ $6400          ; pre-shifted sprites (bank W leftover)
SPRMEM2END  equ $6800
STACKTOP    equ $7E00
IMTAB       equ $7E00          ; IM2 vector table $7E00-$7F00
ISRJP       equ $7F7F
BANKPORT    equ $37
BANK_W      equ 1              ; SRAM bank 0 : world band + sprites
BANK_P      equ 3              ; SRAM bank 1 : parallax bands
HIGH1       equ 5              ; window bank 0 + expansion RAM page 1 at $B800-$FFFF
FARDATA     equ $C000          ; compressed scenery lives here in page 1
ASSETWIN    equ $5000          ; music + texts copied into bank W window for menus
SPEECHWIN   equ $6400          ; voices live in the free end of bank W during play

; bank P layout (shift-major per band)
CL_ROWS     equ 10
CL_P        equ 64
CL_STR      equ CL_P+32
CL_SH       equ CL_ROWS*CL_STR
CL_BASE     equ $4000
MT_ROWS     equ 10
MT_P        equ 32
MT_STR      equ MT_P+32
MT_SH       equ MT_ROWS*MT_STR
MT_BASE     equ CL_BASE+4*CL_SH
HL_ROWS     equ 6
HL_P        equ 64
HL_STR      equ HL_P+32
HL_SH       equ HL_ROWS*HL_STR
HL_BASE     equ MT_BASE+4*MT_SH
GR_ROWS     equ 3
GR_P        equ 16
GR_STR      equ GR_P+32
GR_SH       equ GR_ROWS*GR_STR
GR_BASE     equ HL_BASE+4*HL_SH
FG_ROWS     equ 3
FG_P        equ 32
FG_STR      equ FG_P+32
FG_SH       equ FG_ROWS*FG_STR
FG_BASE     equ GR_BASE+4*GR_SH
PEND        equ FG_BASE+4*FG_SH
    assert PEND <= $6800

; world band in bank W
WD_ROWS     equ 12
WD_W        equ 192            ; bytes (768 px)
WD_SH       equ WD_ROWS*WD_W
WD_BASE     equ $4000
    assert WD_BASE+4*WD_SH <= SPRMEM2

WORLDPX     equ 768
CAMMAX      equ WORLDPX-128
GROUNDY     equ 47             ; py of skids / feet when on ground

; playfield band rows
PY_CLOUD    equ 10
PY_MOUNT    equ 20
PY_HILL     equ 30
PY_WORLD    equ 36
PY_GROUND   equ 48
PY_FG       equ 51

; keyboard rows (address for LD A,(nn)) ; bit numbers
KR_0        equ $68FE   ; R Q E - W T   (5..0)
KR_1        equ $68FD   ; F A D CTRL S G
KR_2        equ $68FB   ; V Z C SHIFT X B
KR_3        equ $68F7   ; 4 1 3 - 2 5
KR_4        equ $68EF   ; M SPC , - . N
KR_5        equ $68DF   ; 7 0 8 - 9 6
KR_6        equ $68BF   ; U P I RET O Y
KR_7        equ $687F   ; J ; K : L H

; input bits
IN_UP       equ 0
IN_DOWN     equ 1
IN_LEFT     equ 2
IN_RIGHT    equ 3
IN_FIRE     equ 4
IN_ROT      equ 5
IN_PAUSE    equ 6

; object types
OT_TANK     equ 1
OT_JET      equ 2
OT_TRANS    equ 3
OT_PLANE3D  equ 4
OT_AA       equ 5
OT_SAM      equ 6
OT_MISSILE  equ 7
OT_GUNSHIP  equ 8
OT_BALLOON  equ 9
OT_CRATE    equ 10
OT_EXPLO    equ 11
OT_FLAK     equ 12
OT_POPUP    equ 13

; object record offsets (IX)
O_TYPE      equ 0
O_STATE     equ 1
O_XL        equ 2
O_XH        equ 3
O_YL        equ 4
O_YH        equ 5
O_VX        equ 6
O_VY        equ 7
O_TIMER     equ 8
O_HP        equ 9
O_ANIM      equ 10
O_DIR       equ 11
O_AUX       equ 12
O_AUX2      equ 13
O_FLASH     equ 14
O_SPR       equ 15
OBJSZ       equ 16
NOBJ        equ 20

NPB         equ 6              ; player bullets (as the original!)
NEB         equ 16             ; enemy bullets
BSZ         equ 8
NPART       equ 24
PSZ         equ 8
NRUN        equ 16
RSZ         equ 8

; heli states
HS_FLY      equ 0
HS_LANDED   equ 1
HS_DYING    equ 2
HS_DEAD     equ 3

; ------------------------------------------------------------------ RAM
    org $7800
vars_start:
frame_ctr   ds 1
since_copy  ds 1
copy_req    ds 1
sfx_cur     ds 1
sfx_t       ds 1
sfx_pitch   ds 2
sfx_dp      ds 2
sfx_len     ds 1
sfx_type    ds 1
sfx_prio    ds 1
rotor_tick  ds 1
rotor_rate  ds 1
latchv      ds 1               ; current latch value (mode/css, speaker low)
seed        ds 2
noise_seed  ds 2

level       ds 1               ; 0..3 theme index
mission     ds 1               ; 1.. mission number
loopn       ds 1               ; how many times the 4 levels were completed
difficulty  ds 1               ; 0 easy 1 normal 2 hard
lvlptr      ds 2               ; pointer to level table
skycol      ds 1
skybyte     ds 1
starbyte    ds 1
hudbg       ds 1
hudfg       ds 1
mapbg       ds 1
demo        ds 1               ; attract mode flag
demo_t      ds 2

score       ds 3               ; BCD, high byte first
next_extra  ds 3
hiscore     ds 3
lives       ds 1
armour      ds 1
fuel        ds 2
aboard      ds 1
aboard_c    ds 4
heading     ds 1               ; runners heading to the heli
rescued     ds 1
lost        ds 1
total_pris  ds 1
quota       ds 1
clock_min   ds 1
clock_sub   ds 1
end_reason  ds 1               ; 0 none 1 complete 2 time 3 all dead
end_t       ds 1

heli_x      ds 2               ; 1/16 px, centre
heli_y      ds 2               ; 1/16 px, skid bottom
hvx         ds 1
hvy         ds 1
hface       ds 1               ; 0 L 1 F 2 R
hlast       ds 1               ; last side facing
hstate      ds 1
hinv        ds 1
htimer      ds 1
hrotor      ds 1
htilt       ds 1               ; 0 flare 1 level 2 cruise 3 dive
hturn       ds 1               ; 0 L, 1 L3/4, 2 front, 3 R3/4, 4 R
glint_t     ds 1
fire_cd     ds 1
in_cur      ds 1
in_prev     ds 1
in_edge     ds 1
joy_ok      ds 1
paused      ds 1
low_fuel_t  ds 1
land_t      ds 1
pad_t       ds 1
hit_flash   ds 1

camx16      ds 2               ; camera in 1/16 px
camx        ds 2               ; integer camera px
rcx         ds 2               ; render camera (with shake)
shake       ds 1
cloud_drift ds 2

camp_cnt    ds 4               ; prisoners still in each hut
camp_lock   ds 4               ; hut locked hp (0 = open)
camp_rel    ds 1               ; release timer
camp_flash  ds 4

dir_t       ds 16              ; director timers per enemy class
crate_t     ds 2
hud_step_n  ds 1
map_t       ds 1
upd_ctr     ds 2

; lists
objs        ds NOBJ*OBJSZ
pbul        ds NPB*BSZ
ebul        ds NEB*BSZ
parts       ds NPART*PSZ
runners     ds NRUN*RSZ

; scratch
tmp         ds 8
spr_x       ds 2
spr_y       ds 1
draw_flash  ds 1
bd_stride   ds 2
bd_pmask    ds 2
bd_shsize   ds 2
bd_rows     ds 1
bd_x        ds 2
hs_names    ds 5*3
hs_scores   ds 5*3
entry_pos   ds 1
newhs_rank  ds 1
vars_end:
    assert vars_end <= $7C00
skym        equ $7C00          ; sky-colour pixel mask table (page aligned)
NIBM        equ $7B00          ; (unused)
