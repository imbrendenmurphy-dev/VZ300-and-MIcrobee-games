; =====================================================================
;  the engine's variables (VARS, 256 bytes)
; =====================================================================
        ORG VARS
cur_blk:    ds 1
mono:       ds 1
pl_bank:    ds 1
vlast:      ds 1
fields:     ds 1
bl_edge:    ds 1
lateblast:  ds 1
curlist:    ds 2
oldlist:    ds 2
listptr:    ds 2
entptr:     ds 2            ; the flip list's next entry
nflip:      ds 2
centptr:    ds 2            ; the colour-flip list's next entry
ncflip:     ds 1
sprstart:   ds 2
nslots:     ds 1
nold:       ds 1
poolbank:   ds 1
savesp:     ds 2
; the scroll
org:        ds 2            ; ring offset of world cell (0, 0)
camcell:    ds 2            ; the world column at the left of the screen
camrow:     ds 1            ; the world row at the top of the playfield
oldphase:   ds 1
phase:      ds 1            ; 0..11: shift (0..3) + 4 x vertical step (0..2)
sstart:     ds 2            ; the 6545 start address
sdirty:     ds 1            ; the phase changed: every playfield cell's bank
hud_dirty:  ds 1            ; 1: the status line's codes and colours; 2: all of it
nmapq:      ds 1
ndraw:      ds 1
nload:      ds 1            ; slots waiting for the PCG
fq_head:    ds 1
fq_tail:    ds 1
ovf_count:  ds 1            ; times no slot was free
miss_count: ds 1
; sprites
sd_frame:   ds 1
sd_face:    ds 1
sd_x:       ds 2
sd_y:       ds 2
ds_col:     ds 1
ds_sh:      ds 1
ds_cx:      ds 1
ds_cy:      ds 1
ds_ry:      ds 1
ds_cyc:     ds 1
ds_n:       ds 1
; input
pad:        ds 1
padnew:     ds 1
rseed:      ds 2
; sound
snd_per:    ds 1
spk:        ds 1
sfx_on:     ds 1
sfx_left:   ds 1
sfx_ptr:    ds 2
mus_on:     ds 1
mus_left:   ds 1
mus_gate:   ds 1
mus_note:   ds 1
mus_ptr:    ds 2
tw_ptr:     ds 2
tw_start:   ds 2
tw_len:     ds 1
tw_cnt:     ds 1
; the camera, set by the game: across in VZ pixels, down in lines
camx:       ds 2
camy:       ds 2            ; the line of the level at the top of the playfield
colstep:    ds 1
stg_blk:    ds 1
stg_ofs:    ds 2
fc_src:     ds 1
fc_dst:     ds 1
fc_w:       ds 2
hud_col:    ds 1
; the map block's scratch
m_x:        ds 2
m_r:        ds 1
m_n:        ds 1
m_ring:     ds 2
m_ent:      ds 2
m_cnt:      ds 1
m_force:    ds 1
m_slot:     ds 1
sb_k:       ds 4
sb_dst:     ds 2
sb_vi:      ds 1
sb_y:       ds 1
fl_save:    ds 2
fl_end:     ds 2
rl_src:     ds 2
rl_left:    ds 2
rl_dst:     ds 2
q_id:       ds 2
qd_tmp:     ds 14           ; a loaded quad's inks and flags
rb_ink:     ds 1
        ALIGN 8
scratch:    ds 10
perf_late:  ds 1
vars_end:
        ASSERT vars_end <= ROWTAB
