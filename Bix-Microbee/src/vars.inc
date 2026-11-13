; =====================================================================
;  the engine's variables (9800-98FF)
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
entptr:     ds 2
nflip:      ds 2
sprstart:   ds 2
ncq:        ds 1            ; flip-list entries that are background cells
nslots:     ds 1
nold:       ds 1
poolbank:   ds 1
savesp:     ds 2
; the scroll
org:        ds 2            ; ring offset of world column 0, screen row 0
camcell:    ds 2            ; the world column at the left of the screen
oldphase:   ds 1
phase:      ds 1            ; 0..3: the shift, in pairs of pixels
sstart:     ds 2            ; the 6545 start address
sdirty:     ds 1            ; the picture has moved: blast the attributes
hud_dirty:  ds 1
hud_col:    ds 1
pcol_h:     ds 1            ; high byte of the ink table in use
nmapq:      ds 1
ndraw:      ds 1
bl_lo:      ds 2
bl_hi:      ds 2
bl_save:    ds 3
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
; the camera, in VZ pixels (the game's unit): set by the game
camx:       ds 2
m_x:        ds 2            ; map block scratch
m_r:        ds 1
m_n:        ds 1
m_ptr:      ds 2
m_ring:     ds 2
m_mask:     ds 4
        ALIGN 8
scratch:    ds 8
perf_late:  ds 1
vars_end:
        ASSERT vars_end <= ROWTAB
