; BLACKOUT PROTOCOL - Microbee Premium Plus
; Milestone 3: Wren's full movement (run, vault, fall, search, lift pads).
        DEVICE NOSLOT64K
        org $0100
COLS     equ 42
ROWS     equ 24
ROOM_ROWS equ 22
CELLS    equ COLS*ROWS          ; 1008 per page
BACK     equ $5000              ; clean scene, 16 bytes per cell
NATIVE   equ $9000              ; what is on screen, 16 bytes per cell
DIRTY_CUR equ $D000
DIRTY_PREV equ $D800
STACKTOP equ $EF00
KEY_A    equ 1
KEY_O    equ 15
KEY_P    equ 16
KEY_Q    equ 17
KEY_SPACE equ 55
WREN_FG  equ $0F
ROOM_WY  equ 21*12-24           ; standing on the bottom floor

start:
        call load_assets        ; BLACKOUT.DAT into the banks, through CP/M
        di
        ld sp,STACKTOP
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        call hw_init
        call far_init
        ld a,(ld_packs)         ; disks B-D already read through CP/M at start-up
        ld (packs_in),a
        ld a,1                  ; Agent until a level is chosen (and for the test hooks)
        ld (skill),a
        call skill_apply
        ld a,$FF
        ld (fb_frame),a
        ld hl,BACK              ; clear BACK + NATIVE (flags must start at 0)
        ld de,BACK+1
        ld bc,NATIVE+CELLS*16-BACK-1
        ld (hl),0
        ldir
        jp title

loop:
        call esc_check          ; ESC: quit to the title?
        ld a,(gmode)
        or a
        jr nz,.sh
        ld a,(vb_count)         ; rooms: one logic tick per field gone, so the
        ld b,a                  ; game keeps time when a busy room draws at 25
        xor a
        ld (vb_count),a
        ld a,b
        or a
        jr nz,$+3
        inc a
        cp 4
        jr c,$+4
        ld a,3
        ld (ticks),a
.tk:    call room_update
        ld a,(gmode)
        or a
        jr nz,.w                ; went into a shaft
        ld a,(ticks)
        dec a
        jr z,.w
        ld (ticks),a
        call clock_tick
        jr .tk
.sh:    xor a
        ld (vb_count),a
        call shaft_update
.w:     ld a,(gmode)
        or a
        jr nz,.shw
        call pads_moving        ; a moving pad redraws everything near it
        call objs_frame
        jr .still
.shw:   ld a,(lift_dir)
        or a
        jr nz,.still
        call wren_erase
        call wren_rect
        call wren_draw
.still: call clock_tick
        call present
        jr loop

; ESC in a room or a shaft pauses: "PAUSED. Y=QUIT" on the bar.  Y goes back to the title
; (where L loads a saved game); N or ESC again carries on.
KEY_ESC equ 48
KEY_Y   equ 25
KEY_N   equ 14
esc_check:
        ld a,KEY_ESC
        call scan_key
        ret z
        ld a,(demo_on)          ; (in the demo any key just ends it)
        or a
        jp nz,demo_quit
        call wait_up
        ld hl,str_quitq
        call msg_show
        call present
        call present
.k:     ld a,KEY_Y
        call scan_key
        jr nz,.yes
        ld a,KEY_N
        call scan_key
        jr nz,.no
        ld a,KEY_ESC
        call scan_key
        jr z,.k
.no:    call wait_up
        ld hl,str_blank
        call msg_show
        xor a
        ld (vb_count),a         ; (the clock stood still while asking)
        ret
.yes:   call wait_up
        ld sp,STACKTOP
        jp title
str_quitq: db "PAUSED. Y=QUIT",0

; ---------------------------------------------------------------- rooms
; A = room, B = arrival: 0 through the left door, 1 through the right
enter_room:
        ld (cur_room),a
        push bc
        ld b,a                  ; first visit?
        call visited_bit
        ld a,1
        jr z,.fv
        xor a
.fv:    ld (first_visit),a
        ld a,(cur_room)         ; visited
        ld hl,visited
        call flag_bit
        or (hl)
        ld (hl),a
        ld a,(cur_room)
        ld l,a                  ; the room's record from the banks -> STAGE
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,room_far
        add hl,de
        ld de,STAGE
        call far_load
        ld a,(cur_room)         ; its doors
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *6
        ld de,room_door
        add hl,de
        ld de,doors
        ld bc,6
        ldir
        ld hl,(STAGE+6)         ; its runs
        ld de,STAGE
        add hl,de
        push hl
        call draw_rle
        pop hl
        call room_maps
        call pads_init
        call robots_init
        ld a,(cur_room)         ; the observatory wing floats
        ld hl,room_wing
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        cp 4
        ld a,0
        jr nz,.lg
        inc a
.lg:    ld (lowgrav),a
        xor a
        ld (slide),a
        ld a,(grace_n)          ; a moment's grace on the way in
        ld (grace),a
        call marks_apply
        ld hl,(STAGE+0)         ; its name
        ld de,STAGE
        add hl,de
        call hud_draw
        call room_signs_draw
        call full_redraw
        call show_all
        pop bc
        ld a,b
        or a
        jr nz,.r
        ld a,(doors+2)          ; in through the left door
        ld c,6
        ld d,0
        jr .at
.r:     ld a,(doors+5)          ; in through the right door
        ld c,146
        ld d,1
.at:    ld l,a                  ; standing on that door's floor
        add a,a
        add a,l
        add a,a
        add a,a
        sub 24
        ld (wy),a
        ld (arr_y),a
        ld a,c
        ld (wx),a
        ld (arr_x),a
        ld a,d
        ld (wface),a
        ld (arr_face),a
        xor a
        ld (gmode),a
        ld (srch_lock),a
        ld (wstate),a
        ld a,F_STAND
        ld (wframe),a
        call room_bounds
        call objs_reset
        ld a,(cur_room)         ; first time in this wing: its sting
        ld hl,room_wing
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld b,(hl)
        ld a,1
        inc b
.wb:    dec b
        jr z,.wt
        add a,a
        jr .wb
.wt:    ld b,a
        ld a,(wings_seen)
        and b
        jr nz,.ws
        ld a,(wings_seen)
        or b
        ld (wings_seen),a
        ld hl,mus_dock
        bit 1,b
        jr z,.w1
        ld hl,mus_habitat
.w1:    bit 2,b
        jr z,.w2
        ld hl,mus_core
.w2:    xor a
        call mus_play
.ws:    call shard_hint         ; (Story / Agent: "SHARD SIGNAL")
        ld a,(first_visit)      ; first time in a guarded room: MERIDIAN notices
        or a
        ret z
        ld a,(nrob)
        or a
        ret z
        ld a,SPK_INTRUDER
        jp say

; Walls: the door gaps only count on their own floor.
room_bounds:
        ld a,(wy)
        add a,24
        ld l,a
        ld h,0
        ld de,ycell
        add hl,de
        ld b,(hl)               ; the row Wren's feet are in
        ld a,(doors+2)
        cp b
        ld a,5
        jr nz,.l
        xor a
.l:     ld (wxmin),a
        ld a,(doors+5)
        cp b
        ld a,150
        jr nz,.r
        ld a,WX_EXIT_R
.r:     ld (wxmax),a
        ret

room_update:
        call room_bounds
        call wren_update
        ld a,(gmode)            ; (a page or a shaft may have taken over)
        or a
        ret nz
        call pads_update
        call robots_update
        call robots_hit
        ld a,(wstate)
        cp WS_GROUND
        ret nz
        ld a,(wx)
        or a
        jr nz,.notl
        ld a,(doors+0)          ; out of the left door
        cp $FF
        ret z
        ld (cur_shaft),a
        ld a,(doors+1)
        ld b,1                  ; into the shaft from its right tunnel
        jp enter_shaft
.notl:  cp WX_EXIT_R
        ret c
        ld a,(doors+3)
        cp $FF
        ret z
        ld (cur_shaft),a
        ld a,(doors+4)
        ld b,0
        jp enter_shaft

; Second pass over the room's runs: tile numbers to ROOM_MAP, colours to ROOM_COL.
room_maps:
        ld de,ROOM_MAP
        ld ix,ROOM_COL
.run:   ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
.c:     ld (de),a
        inc de
        ld (ix+0),c
        inc ix
        djnz .c
        jr .run

; Paint the room's wall signs (row, col, ink, text, 0 ... $FF).
room_signs_draw:
        ld hl,(STAGE+4)
        ld de,STAGE
        add hl,de
.s:     ld a,(hl)
        cp $FF
        ret z
        ld c,a
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld a,b
        call print_at
        inc hl
        jr .s

; HUD: bar on row 22, name (HL) and clock on row 23.
hud_draw:
        push hl
        ld a,T_BZ_T             ; a bevel line, then a blue strip
        ld c,22
        ld e,$0E
        call fill_row
        ld a,T_EMPTY
        ld c,23
        ld e,$40
        call fill_row
        pop hl
        ld a,1
        ld c,23
        ld e,$4E
        call print_at
        jp show_clock

; ---------------------------------------------------------------- clock
CLOCK_FRAMES equ 17             ; fields per game second: the clock runs ~3x real time,
clock_tick:                     ; so the eight hours are about 2 h 40 min of play
        ld hl,clk_fr
        inc (hl)
        ld a,(hl)
        ld hl,clk_frames        ; (per difficulty level)
        cp (hl)
        ld hl,clk_fr
        ret c
        ld (hl),0
        ld hl,clk_s
        dec (hl)
        jp p,show_clock
        ld (hl),59
        ld hl,clk_m
        dec (hl)
        jp p,show_clock
        ld (hl),59
        ld hl,clk_h
        dec (hl)
        jp m,game_over
        jr nz,show_clock
        ld a,(said_hour)        ; the last hour
        or a
        jr nz,show_clock
        inc a
        ld (said_hour),a
        call show_clock
        ld a,SPK_HOUR
        jp say
show_clock:
        ld a,33
        ld (pr_col),a
        ld a,$4B
        ld (pr_ink),a
        ld c,23
        ld a,(clk_h)
        call put2
        ld a,':'
        call put_c1
        ld a,(clk_m)
        call put2
        ld a,':'
        call put_c1
        ld a,(clk_s)
put2:   ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,b
        call put_c1
        pop af
put_c1: push bc
        call put_char
        pop bc
        ld hl,pr_col
        inc (hl)
        ret

str_shaft: db "LIFT SHAFT A",0
str_sealed: db "CORE SEALED",0
str_level: db "FLOOR ",0

        include "video.asm"
        include "shaft.asm"
        include "wren.asm"
        include "sprite.asm"
        include "robots.asm"
        include "items.asm"
        include "screens.asm"
        include "objects.asm"
        include "ui.asm"
        include "save.asm"
        include "demo.asm"
        include "fdc.asm"
        include "sound.asm"
        include "bank.asm"
        include "keys.asm"
        include "assets.inc"
code_end:
        ASSERT code_end < DATA_WIN
        ASSERT vars_end < ROOM_MAP
        SAVEBIN "../build/BLACKOUT.COM",start,code_end-start

; The overlay: assembled to run at DATA_WIN, saved as BLACKOUT.OVL, loaded at
; start-up into block OVL_BLOCK and copied in when a screen needs it.
OVL_BLOCK equ 31
ovl_image:
        DISP DATA_WIN
        include "overlay.asm"
ovl_run_end:
        ENT
ovl_image_end:
OVL_LEN equ ovl_image_end-ovl_image
        ASSERT ovl_run_end <= BACK
        SAVEBIN "../build/BLACKOUT.OVL",ovl_image,OVL_LEN
; the second overlay: save and load pages (block OVL2_BLOCK)
OVL2_BLOCK equ 30
ovl2_image:
        DISP DATA_WIN
        include "overlay2.asm"
ovl2_run_end:
        ENT
ovl2_image_end:
OVL2_LEN equ ovl2_image_end-ovl2_image
        ASSERT ovl2_run_end <= BACK
        ASSERT ovl_run_end <= CPM_SP-$70   ; the overlays stay clear of the save stack
        ASSERT ovl2_run_end <= CPM_SP-$70  ; and record (save.asm)
        SAVEBIN "../build/BLACKOUT.OV2",ovl2_image,OVL2_LEN
; the third overlay: the splice terminal and the tone lock (block OVL3_BLOCK)
OVL3_BLOCK equ 29
ovl3_image:
        DISP DATA_WIN
        include "overlay3.asm"
ovl3_run_end:
        ENT
ovl3_image_end:
OVL3_LEN equ ovl3_image_end-ovl3_image
        ASSERT ovl3_run_end <= CPM_SP-$70
        SAVEBIN "../build/BLACKOUT.OV3",ovl3_image,OVL3_LEN

        org $E000
vars_start:
page_vars: ds 4                 ; per page: band mapped (2), combo y (2)
pagebase: dw 0
pageoff: db 0
cur_end: dw 0
own_end: dw 0
prev_end: dw 0
fbank:  db 0
frames: dw 0
pr_col: db 0
pr_ink: db 0
rcx:    db 0
rcy0:   db 0
rcy1:   db 0
wx:     db 0
wy:     db 0
wxmin:  db 0
wxmax:  db 0
wface:  db 0
wframe: db 0
wmove:  db 0
wstate: db 0
wtim:   db 0
wy0:    db 0
vy:     db 0
turnt:  db 0
runfr:  db 0
runsub: db 0
sprog:  db 0
srch_lock: db 0
kbits:  db 0
knew:   db 0
arr_x:  db 0
arr_face: db 0
sptr:   dw 0
dptr:   dw 0
tpage:  db 0
cur_line: db 0
t6:     ds 6
t8:     ds 8
npads:  db 0
pads:   ds 2*12
ride_ix: dw 0
ix_c:   db 0
doors:  ds 6
arr_y:  db 0
cur_shaft: db 0
d_vt:   dw 0
vb_count: db 0
vb_last: db 0
ticks:  db 0
pend_msg: dw 0
cmb_list: ds 129                ; this shaft's combos: count, then their numbers
title_n: db 0
demo_on: db 0
demo_dir: db 0
demo_t: dw 0
demo_lastx: db 0
demo_stuck: db 0
demo_cool: db 0
skill:  db 0                    ; 0 Story, 1 Agent, 2 Ghost
sk_vars:                        ; skill_apply copies a row of sk_tab here
clk_frames: db 0
pen_min: db 0
gun_cool: db 0
grace_n: db 0
fast_pat: db 0
slow_hunt: db 0
hunt_off: db 0
hb_trim: db 0
sec_cmd: db 0
sec_buf: dw 0
mus_key2: db 0
pn_col: db 0
pn_r1:  dw 0
packs_in: db 0
speech_ok: db 0
mus_key: db 0
mus_p1: db 0
mus_p2: db 0
mus_lkey: db 0
mus_lptr: dw 0
wings_seen: db 0
said_hour: db 0
first_visit: db 0
end_say: db 0
end_tune: dw 0
pk_num: db 0
pk_drive: db 0
pk_lsec: dw 0
pk_left: dw 0
pk_block: db 0
pk_dest: dw 0
pk_id:  db 0
pk_cyl: db 0
pk_side: db 0
fdc_cyl: db 0
fdc_drv: db 0
grace:  db 0
slide:  db 0
lowgrav: db 0
cur_colcol: dw 0
objs:   ds 9*24
of_force: db 0
of_pass: db 0
d_port: db 0
d_x:    db 0
d_y:    db 0
d_h:    db 0
d_face: db 0
d_ink:  db 0
d_rcx:  db 0
d_rcy0: db 0
d_rcy1: db 0
er_c:   db 0
er_r1:  db 0
nrob:   db 0
robots: ds MAXROB*RB_SIZE
seen_row: db 0
sees:   db 0
asleep: db 0
hx0:    db 0
hx1:    db 0
hy0:    db 0
hy1:    db 0
srch_row: db 0
srch_col: db 0
srch_c0: db 0
srch_d: db 0
tmp_k:  db 0
tmp_x:  db 0
msgbuf: ds 16
spk:    db 0
wk_key: db 0
sp_key: db 0
sp_tgt: ds 3
sp_cur: ds 3
sp_down: ds 3
sd_mask: db 0
sd_ink: db 0
sd_col: db 0
sd_row: db 0
game_vars:
shards: ds 3
keys_done: db 0
n_sleep: db 0
n_reset: db 0
srch_bits: ds NROOMS*4
visited: ds (NROOMS+7)/8
searches: db 0
deaths: db 0
tones_done: db 0                ; tone locks opened (bit = wing)
sleep_t: dw 0
game_vars_end:
fb_frame: db 0
fc_port: db 0
ix_n:   db 0
prow1:  db 0
ppat:   dw 0
py:     db 0
pline:  db 0
pbyte:  db 0
clk_h:  db 0
clk_m:  db 0
clk_s:  db 0
clk_fr: db 0
gmode:  db 0                    ; 0 room, 1 shaft
cur_room: db 0
room_level: db 0
room_side: db 0
cur_level: db 0
lvl_left: db 0
lvl_right: db 0
tgt_level: db 0
tgt_y:  db 0
lift_dir: db 0                  ; 0 stopped, 1 up, 2 down
shy:    db 0                    ; coarse view row in the shaft
sho:    db 0                    ; fine offset 0..11
hpage:  db 0
tmp_bank: db 0
cnta:   db 0
cntb:   db 0
blanked: db 0
tmp_row: db 0
tmp_oldy: db 0
tmp_scr: dw 0
tmp_old: dw 0
vars_end:
