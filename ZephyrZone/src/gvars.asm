; ---- game variables (included from vars.asm)
NOBJ        equ 36
objs:       ds NOBJ*40
px8:        ds 2            ; hero x, 1/8 units (signed)
py8:        ds 2            ; hero height, 1/8 units
pvx:        ds 2            ; velocities, 1/8 units per field
pvy:        ds 2
px:         ds 2            ; hero x, units
py:         ds 1            ; hero height, units
hsx:        ds 2            ; hero screen position
hsy:        ds 2
hpose:      ds 1
hfire:      ds 1            ; muzzle flash timer
hrun:       ds 1            ; run cycle
dt:         ds 1            ; fields since the last frame (1-4)
speed:      ds 1            ; forward units per field
travel:     ds 2            ; distance travelled (units/16)
next_spawn: ds 2
anim:       ds 1            ; animation clock (fields)
clock:      ds 2            ; stage clock (fields)
ev_ptr:     ds 2            ; next stage event
score:      ds 3            ; BCD, 6 digits
hiscore:    ds 3
lives:      ds 1
health:     ds 1
maxhealth:  ds 1
inv:        ds 1            ; invulnerable fields left
wlevel:     ds 1            ; weapon 0 single, 1 twin, 2 triple
shield:     ds 1            ; shield fields left
fire_cd:    ds 1            ; fields until the next shot
nbolts:     ds 1
diff:       ds 1            ; 0 casual 1 arcade 2 expert
autofire:   ds 1
hud_dirty:  ds 1
dead:       ds 1            ; >0: dying / respawn countdown
fcount:     ds 8            ; formation sizes
fkill:      ds 8            ; formation kills
fnext:      ds 1
scen_gap:   ds 1            ; scenery spacing (units/4)
scen_mix:   ds 1
boss_on:    ds 1
boss_hp:    ds 1
boss_t:     ds 1
bhist:      ds 128          ; boss head history: x/4, y, z/8 (+1) x 32
bhist_p:    ds 1
msg_id:     ds 1            ; big message on screen
msg_t:      ds 1
stage_done: ds 1
paused:     ds 1
sfx_p:      ds 2
sfx_n:      ds 1
mus_p:      ds 2
mus_t:      ds 1
mus_on:     ds 1
mus_base:   ds 2
blip:       ds 1
kills:      ds 2
frozen:     ds 1
fall_v:     ds 1            ; the world stands still (the hero is down)
boss_max:   ds 1
world:      ds 1            ; world being played (1..)
world_ld:   ds 1            ; world file in memory
wname_buf:  ds 17
bname_buf:  ds 17
stg_buf:    ds 8
demo:       ds 1
round:      ds 1
force_pose: ds 1
mus_off:    ds 1
title_t:    ds 2
akey:       ds 1
tsel_t:     ds 1            ; title: a just-changed menu line stays up
tsel_m:     ds 1
maxw:       ds 1            ; furthest stage reached this session (trainer)
startw:     ds 1            ; stage a new game starts at
from_buf:   ds 13           ; "FROM STAGE n"
attract_n:  ds 1            ; title cycles (storyboard every third)
gal_w:      ds 1            ; world the storyboard shows next
gal_s:      ds 2            ; storyboard scroll
gal_c:      ds 1            ; storyboard caption shown
gal_y:      ds 1            ; picture title: logo column
tl_n:       ds 1
sr_free:    ds 1
sh_t:       ds 1            ; flight time of the orb being aimed
sfx_cur:    ds 1
sd_map:     ds 1            ; mapping to restore after an SD load
cphase:     ds 1            ; split copy: second half pending
dat_id:     ds 2            ; build id written by each .DAT as it loads
gstate_end:
