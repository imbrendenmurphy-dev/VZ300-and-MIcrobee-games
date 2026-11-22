; =====================================================================
;  VARIABLES (EA00h-EEFFh, cleared at start-up)
; =====================================================================
        ORG VARS
; video
vispage:    DS 1
cm_state:   DS 1            ; 0 idle, 1 copying rows, 2 rows done: flip
cm_row:     DS 1
nanim:      DS 1
tick:       DS 1
pl_bank:    DS 1
pr_col:     DS 1
; view composition
zkey:       DS VW
zown:       DS VW
nfill:      DS 1
cp_off:     DS 2
cp_slot:    DS 1
dp_off:     DS 2
dp_side:    DS 1
sp_id:      DS 1
sp_dz:      DS 1
sp_shift:   DS 1
sp_key:     DS 1
sp_slot:    DS 1
sp_sq:      DS 2
sp_flash:   DS 1
flash_mon:  DS 1            ; monster number + 1 drawn flashing
atk_mon:    DS 1            ; monster number + 1 drawn lunging
fx_sprite:  DS 1            ; a spell effect sprite drawn in the view (0 none)
fx_dz:      DS 1
; input
held:       DS 1
pressed:    DS 1
cmd:        DS 1
cmdheld:    DS 1
repcnt:     DS 1
; level
level:      DS 1            ; 0..3
lvl_mpa:    DS 1            ; port 50h values of the level's blocks
lvl_mpb:    DS 1
ndecor:     DS 1
ppos:       DS 2            ; the player's square (address in MAP)
facing:     DS 1            ; 0 N 1 E 2 S 3 W
nmons:      DS 1
runestep:   DS 1
visited:    DS 1            ; bit n: level n has been entered (its state saved)
; hero
hp:         DS 1
hpmax:      DS 1
mp:         DS 1
mpmax:      DS 1
lvl:        DS 1
xp:         DS 2
atk:        DS 1
def:        DS 1
gold:       DS 2
potions:    DS 1
keys:       DS 3
sigils:     DS 1
spells:     DS 1
weapon:     DS 1
armour:     DS 1
turns:      DS 2
kills:      DS 2
dead:       DS 1
won:        DS 1
; ui
ui_dirty:   DS 1            ; b0 stats, b1 log, b2 minimap, b3 compass
log_new:    DS 1
mini_dirty: DS 8            ; one bit per minimap cell (64)
hurtflash:  DS 1
msgbuf:     DS 128
; sound
snd_mode:   DS 1            ; 0 off, 1 effects, 2 music and effects
mus_on:     DS 1
mus_hdr:    DS 2
mus_p1:     DS 8
mus_p2:     DS 8
mus_p3:     DS 8
mus_gate:   DS 1
sfx_on:     DS 1
sfx_ptr:    DS 2
sfx_pri:    DS 1
sa_m:       DS 2
sa_b:       DS 2
sa_f:       DS 2
lfsr:       DS 1
rseed:      DS 2
vars_end:
        ASSERT vars_end <= $EF00
