; =====================================================================
;  variables (upper RAM, cleared at start)
; =====================================================================
        ORG VARS
hero:       ds F_SIZE
foe:        ds F_SIZE
pad:        db 0
padnew:     db 0
lastnew:    db 0
wt:         db 0
fields:     db 0
vlast:      db 0
ticks:      db 0
vispage:    db 0
hidpage:    db 0
flip_ask:   db 0
drawpage:   dw 0
pl_bank:    db 0
picblk:     db 0
picbase:    dw 0
rseed:      dw 0
stage:      db 0
msg_t:      db 0
hud_dirty:  db 0
counter_flash: db 0
blocked_flag: db 0
gap:        db 0
seen:       db 0
punished:   db 0
guard_t:    db 0
brainp:     dw 0
scriptp:    dw 0
scr_pc:     db 0
scr_t:      db 0
rangep:     dw 0
; render
rng_a:      dw 0
rng_b:      dw 0
rng_n:      db 0
rng:        ds 4
r_fn:       dw 0
r_wbase:    dw 0
r_vofs:     dw 0
r_c0:       db 0
r_c1:       db 0
r_n:        db 0
r_top:      db 0
r_have:     dw 0
r_vid:      dw 0
poolused:   db 0
d_w:        db 0
d_h:        db 0
d_x0:       db 0
d_row:      dw 0
c_want:     dw 0
c_ink:      db 0
c_code:     db 0
c_top:      ds 16
c_bot:      ds 8
; sound
sound_on:   db 0
sfx_p:      dw 0
mus_p:      dw 0
mus_base:   dw 0
mus_t:      db 0
mus_on:     db 0
mus_note:   db 0
mus_tail:   db 0
saved_tune: dw 0
spk:        db 0
hudbuf:     ds 41
vars_end:
