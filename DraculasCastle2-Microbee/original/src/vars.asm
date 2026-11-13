; ===========================================================================
;  vars.asm - RAM layout (not part of the .VZ image)
; ===========================================================================
            noemit
            org $EE00
ttab:       ds 8            ; text expansion table (8-aligned)
frame_count: ds 2
rng:        ds 2
latch_base: ds 1
keys_now:   ds 1
keys_new:   ds 1
any_key:    ds 1
joy_ok:     ds 1
music_on:   ds 1
cur_song:   ds 2
ph1:        ds 2
ph2:        ds 2
ph3:        ds 2
chan1:      ds 16
chan2:      ds 16
chan3:      ds 16
chsfx:      ds 16
pr_x:       ds 1
pr_w:       ds 1
pr_y:       ds 1
pr_y1:      ds 1
pr_left:    ds 1
pr_src:     ds 2
pr_dst:     ds 2
pr_skip:    ds 2
pr_entry:   ds 2
pr_rpf:     ds 1
fr_val:     ds 1
fr_cnt:     ds 1
fr_w:       ds 1
fr_h:       ds 1
txt_fg:     ds 1
txt_bg:     ds 1
txt_x0:     ds 1
dc_src:     ds 2
dc_cnt:     ds 1
cur_bank:   ds 1
; view
px:         ds 1
py:         ds 1
pdir:       ds 1
fdx:        ds 1
fdy:        ds 1
rdx:        ds 1
rdy:        ds 1
cx0:        ds 1
cy0:        ds 1
cxl:        ds 1
cyl:        ds 1
view_cells: ds 20
map_page:   ds 1
area_door_decor: ds 1
area_door_kind: ds 1
area_exits: ds 2
rv_d:       ds 1
rv_l:       ds 1
rv_cell:    ds 1
rv_kind:    ds 1
rv_decor:   ds 1
rv_slot:    ds 1
fw_wb:      ds 1
fw_y0:      ds 1
fw_rows:    ds 1
fw_x:       ds 1
fw_sx:      ds 1
fw_soff:    ds 1
fw_cw:      ds 1
blit_dx:    ds 1
bm_h:       ds 1
bm_w:       ds 1
bm_c:       ds 1
; SD loader
dos_map:    ds 1
sd_bank:    ds 1
sd_dst:     ds 2
sd_left:    ds 2
sd_try:     ds 1
n_prev:     ds 1
n_lock:     ds 1
n_hit:      ds 1
vars_game:
            include "gvars.asm"
vars_end:
            assert vars_end <= $F000
SAVE_LEN    equ gstate_end-vars_game

BACK_ADDR   equ $F000       ; 2K back buffer $F000-$F7FF (DOS owns $FA00-$FFFF)
FLIP        equ $7B00       ; flip table (system area $7800-$7AE7 left for ROM/DOS)
STACK_TOP   equ $EE00       ; stack $EA00-$EDFF (1K)
AREA_RAM    equ $E400       ; current area pack (map, events, exits, texts, song) $E400-$E9FF
AREA_MAX    equ $0600
AREA_TEXTS  equ AREA_RAM+20 ; dw local text table
AREA_SONG   equ AREA_RAM+22 ; dw song header
SECBUF      equ $F800       ; 512-byte SD sector buffer $F800-$F9FF (as 13 Ghosts uses)
P2BASE      equ $C800       ; area part 2 / monster frames ($C800-$E3FF)
VCACHE      equ $D900       ; cutscene viewport cache (1040 bytes)
MAPBUF      equ $7C00       ; current area's map (256)
OPENED      equ $7D00       ; per area 32 bytes: doors/secrets opened (8 areas)
EXPLORED    equ $7E00       ; per area 32 bytes: seen-bits (8 areas)
FLAGS       equ $7F00       ; event flags (bytes, 256)
PSTATE      equ $7D00       ; persistent per-area state saved with the game: $7D00-$7FFF
            emit
