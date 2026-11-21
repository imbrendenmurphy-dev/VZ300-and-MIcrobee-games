; =====================================================================
;  vars.asm - RAM layout (not part of the saved binary)
; =====================================================================

; droid record (slot 0 = the player)
D_TYPE          equ 0               ; roster index, FFh = empty
D_X             equ 1
D_Y             equ 2
D_EN            equ 3               ; energy
D_ST            equ 4               ; spare state
D_NODE          equ 5               ; waypoint heading for
D_PREV          equ 6               ; waypoint came from
D_ACC           equ 7               ; movement accumulator (1/16 cell)
D_DX            equ 8               ; facing
D_DY            equ 9
D_RELD          equ 10              ; reload timer
D_FLASH         equ 11              ; hit flash timer
D_ANIM          equ 12
D_THINK         equ 13
D_CB            equ 14              ; display code base of the body colour
D_WAIT          equ 15              ; blocked: frames to wait
DSZ             equ 16
NDROIDS         equ 15

; shot record
S_LIFE          equ 0
S_X             equ 1
S_Y             equ 2
S_DX            equ 3
S_DY            equ 4
S_OWN           equ 5               ; 0 = player, 1 = enemy
S_DMG           equ 6
S_KIND          equ 7               ; 0 -, 1 |, 2 /, 3 \
SHOTSZ          equ 8
NSHOTS          equ 10

; explosion record
E_T             equ 0               ; frames left (0 = free)
E_F             equ 1               ; frame shown
E_X             equ 2
E_Y             equ 3
E_HURT          equ 4               ; 1 = still to deal blast damage
EXPLSZ          equ 6
NEXPL           equ 6

; door record
DR_X            equ 0
DR_Y            equ 1
DR_KIND         equ 2               ; 0 horizontal (3 wide), 1 vertical (2 tall)
DR_ST           equ 3               ; 0 closed .. 2 open
DR_ADDR         equ 4
DRSZ            equ 6
MAXDOORS        equ 24

MAXNODES        equ 80

; per-deck saved state (per ship)
DS_CLEARED      equ 0
DS_N            equ 1
DS_REC          equ 2               ; records: type, x, y, energy, node, prev
DSRECSZ         equ 6
DSSZ            equ 96

        org VARBASE
vars_start:
seed            ds 2
fieldcnt        ds 1
lastframe       ds 1
drops           ds 1
noise_on        ds 1
noise_band      ds 1
noise_div       ds 1
nseed           ds 1
cur_div         ds 2
snd_mute        ds 1
sfxptr          ds 2
sfxpri          ds 1
mus_on          ds 1
mus_song        ds 2
mus_ord         ds 2
mus_row         ds 2
mus_tick        ds 1
mus_speed       ds 1
mus_fx          ds 1
mus_arp         ds 1
lead_note       ds 1
lead_age        ds 1
bass_note       ds 1
bass_age        ds 1
drum_kind       ds 1
drum_age        ds 1

key_pause       ds 1
key_quit        ds 1
fe_prev         ds 1
fe_rep          ds 1
keys            ds 1
keys_prev       ds 1

demo            ds 1
joy_on          ds 1                ; MZ-1X03 joystick switched on
joy_x           ds 1
joy_y           ds 1
joy_cx          ds 1                ; calibrated centre counts
joy_cy          ds 1
joy_dirs        ds 1
joy_fraw        ds 1
joy_fidle       ds 1
joy_jprev       ds 1
demo_abort      ds 1
demo_time       ds 2

; game
score           ds 3
hiscore_rank    ds 1
ship            ds 1
ship_hdr        ds 2
ndecks          ds 1
deck            ds 1
deck_hdr        ds 2
dimmed          ds 1                ; 0 lit, 1 dim
camx            ds 1
camy            ds 1
frame           ds 1
event           ds 1
event_arg       ds 1
pl_dead         ds 1
dead_time       ds 1
xmode           ds 1                ; transfer mode timer (0 = off)
fire_hold       ds 1
bump_cool       ds 1
burn_time       ds 1
ener_time       ds 1
invuln          ds 1
alarm_time      ds 1
enemies_left    ds 1
lift_x          ds 1
lift_y          ds 1
lift_shaft      ds 1

hud_dirty       ds 1
hud_deck        ds 1
hud_halves      ds 1
msg_time        ds 1
msg_text        ds 2

ovlptr          ds 2
rleptr          ds 2
rlecnt          ds 1
rlecode         ds 1
shot_kind       ds 1
shot_dir        ds 2
shot_pos        ds 2
shot_own        ds 1
shot_dmg        ds 1
shot_life       ds 1
check_clear     ds 1
clear_delay     ds 1
dec_y3          ds 1
db_cnt          ds 1
tmp_en          ds 1
tmp_node        ds 1

ndoors          ds 1
nlifts          ds 1
neners          ds 1
ncons           ds 1
nnodes          ds 1

; demo AI
ai_node         ds 1
ai_target       ds 1
ai_tnode        ds 1
ai_stuck        ds 1
ai_lastx        ds 1
ai_lasty        ds 1
ai_think        ds 1
ai_keys         ds 1
ai_want_xfer    ds 1
nn_best         ds 1
ai_pref         ds 1
nn_node         ds 1
nn_tmp          ds 1
bfs_head        ds 2
bfs_tail        ds 2

; transfer game
tr_enemy        ds 1                ; droid slot
tr_result       ds 1                ; 1 win, 2 lose
tr_time         ds 1
tr_sub          ds 1
tr_sel          ds 1
tr_shots        ds 2                ; player, enemy pulses left
tr_class        ds 2
tr_ai_time      ds 1
tr_phase        ds 1
tr_etype        ds 1
tr_lasttime     ds 1
tr_portcol      ds 1
tr_aiside       ds 1
tr_best         ds 1
tr_bestv        ds 1
fd_cb           ds 1

; front end
tmp_attr        ds 1
page_fx         ds 2
scroll_ptr      ds 2
scroll_tick     ds 1
parade_x        ds 1
logo_phase      ds 1
pd_col          ds 1
pd_row          ds 1
ge_type         ds 1
ge_col          ds 1
ge_row          ds 1
hs_ptr          ds 2
hs_pos          ds 1
hs_i            ds 1
hs_ent          ds 2
ls_n            ds 1
ls_ptr          ds 2
ls_shaft        ds 1
ls_col          ds 1
ls_deck         ds 1
ls_save         ds 1
lift_sel        ds 1
lift_ai_t       ds 1
ld_deck         ds 1
ld_attr         ds 1
ld_count        ds 1
cm_w            ds 1
cm_h            ds 1
cm_x0           ds 1
PBUF            ds 80
STARPOS         ds 32

        align 256
OVLBUF          ds 768
DROIDS          ds DSZ*NDROIDS
SHOTS           ds SHOTSZ*NSHOTS
EXPLS           ds EXPLSZ*NEXPL
DOORS           ds DRSZ*MAXDOORS
LIFTS           ds 3*4
ENERS           ds 2*4
CONS            ds 2*4
NODES           ds 2*MAXNODES
ADJ             ds 8*MAXNODES
DIST            ds MAXNODES
BFSQ            ds MAXNODES+2
DSTATE          ds DSSZ*8
HISCORES        ds 8*8              ; name[3], score[3] BCD (lo first), ship, deck
TRBUF           ds 256              ; transfer game state
vars_end:
        ASSERT vars_end <= MAP
