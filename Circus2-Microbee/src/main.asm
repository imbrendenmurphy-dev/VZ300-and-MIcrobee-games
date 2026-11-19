 DEVICE NOSLOT64K
 ORG $100
start:
 ld sp,$CF00
 call load_pcg
 di
 ld sp,$EF00
 ld a,4
 out ($50),a
 xor a
 out ($0B),a
 out ($08),a
 ld a,$CF
 out (1),a
 ld a,$FF
 out (1),a
 ld a,7
 out (1),a
 ld a,$CF
 out (3),a
 ld a,$BF
 out (3),a
 ld a,7
 out (3),a
 ld hl,crtc_table
 ld c,0
.crtc: ld a,c
 out ($0C),a
 ld a,(hl)
 out ($0D),a
 inc hl
 inc c
 ld a,c
 cp 16
 jr nz,.crtc
 ld hl,vars_start
 ld de,vars_start+1
 ld bc,vars_end_all-vars_start-1
 ld (hl),0
 ldir
 ld hl,$1F3A
 ld (seed),hl
 ld a,1
 ld (snd_on),a
 ld (difficulty),a
 ld a,11
 ld (colpat+1),a
 ld a,14
 ld (colpat+2),a
 ld a,15
 ld (colpat+3),a
 ld hl,$ACE1
 ld (nseed),hl
 call init_hiscores
 call install_resident
 call init_video
 jp attract
crtc_table: db $35,$28,$2C,$34,$1E,$03,$19,$1C,$48,$09,$20,$09,0,0,0,0
 INCLUDE "loader.asm"
 INCLUDE "video.asm"
 INCLUDE "banked.asm"
 INCLUDE "keyboard.asm"
 INCLUDE "timing.asm"
 INCLUDE "random.asm"
 INCLUDE "sound.asm"
 INCLUDE "game.asm"
 INCLUDE "rowcache.asm"
 INCLUDE "frontend.asm"
 INCLUDE "data.asm"
 INCLUDE "art.inc"
code_end:
 ASSERT code_end < $8000
 SAVEBIN "../build/CIRCUS2.COM",start,code_end-start
 ORG $D000
vars_start:
fullpres: db 0
 INCLUDE "vars.inc"
last_blank: db 0
sprite_ptr: dw 0
sprite_dest: dw 0
sprite_y: db 0
sprite_width: db 0
sprite_height: db 0
sprite_colour: db 0
sprite_first: db 0
sprite_x: db 0
cell_number: dw 0
upload_bank: db 0
text_x: db 0
text_y: db 0
big_y: db 0
hs_rank: db 0
hs_entry_base: dw 0
sim_frame: db 0
title_time: db 0
draw_y: db 0
draw_x: db 0
draw_w: db 0
draw_h: db 0
draw_col: db 0
cache_offset: dw 0
cache_dirty: ds 4
cache_row: db 0
cache_phase: db 0
cache_column: db 0
cache_src: dw 0
cache_dst: dw 0
cache_page: db 0
cache_line: db 0
cache_slot: db 0
dirty_rows: ds 25
old_rows: ds 25
covered_rows: ds 25
restore_game_flag: db 0
mono_mode: db 0
scene_number: db 0
scene_offset: dw 0
vars_end_all:
 ASSERT vars_end_all < $E000
