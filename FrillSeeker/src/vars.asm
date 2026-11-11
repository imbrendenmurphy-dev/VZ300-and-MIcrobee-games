; =====================================================================
;  variables (EE00-EE7F), entities (EE80-EEFF), the tile map (ED00, 20 x 11)
; =====================================================================
TMAP        EQU $ED00
scratch     EQU $EDF0
ENTS        EQU $EE80

        ORG VARS
cur_blk:    ds 1
room:       ds 1
roomblk0:   ds 1
roombase_h: ds 1
rm_npat:    ds 2
nb_left:    ds 1
nb_right:   ds 1
mono:       ds 1
pl_bank:    ds 1
vlast:      ds 1
fields:     ds 1
lastfields: ds 1
bl_edge:    ds 1
curlist:    ds 2
oldlist:    ds 2
listptr:    ds 2
entptr:     ds 2
nslots:     ds 1
nold:       ds 1
poolbank:   ds 1
nflip:      ds 2
savesp:     ds 2
killq:      ds 1
nanim:      ds 1
an_next:    ds 1
an_video:   ds 1
aa_ids:     ds 2
aa_n:       ds 1
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
ds_h:       ds 1
pad:        ds 1
padnew:     ds 1
rseed:      ds 2
gtick:      ds 1
newroom:    ds 1
want_start: ds 1
hud_dirty:  ds 1
hearts:     ds 1
bugs:       ds 1
collected:  ds 8
hudname:    ds 17
; Bluff
hx:         ds 2
hxf:        ds 1
hy:         ds 2
hyf:        ds 1
hvx:        ds 2
hvy:        ds 2
oldy:       ds 2
rs_x:       ds 2
rs_y:       ds 2
h_face:     ds 1
h_on:       ds 1
h_was:      ds 1
h_coy:      ds 1
h_jbuf:     ds 1
h_jump:     ds 1
h_drop:     ds 1
h_flare:    ds 1
h_glide:    ds 1
h_hurt:     ds 1
h_inv:      ds 1
h_run:      ds 1
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
vars_end:
        ASSERT vars_end <= ENTS
