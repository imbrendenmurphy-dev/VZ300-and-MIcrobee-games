; =====================================================================
;  FRONT: start-up and the title (the title picture and the rogue mob
;  take turns). SPACE, RETURN, joystick fire or a fire key starts.
; =====================================================================
start:
        ld a,r
        ld l,a
        ld h,$A7
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        call apply_sound
        ld a,$01
        ld (hiscore),a          ; 010000 to beat
        ld a,64
        ld (blade_spd),a
        call load_pcg
        ld a,(boot_test)
        or a
        jp nz,game_new
title:
        ld sp,STACK
        xor a
        ld (tpic),a
        ld (paused),a
        ld hl,mus_title_0
        ld de,mus_title_1
        call song
.pic:   ld a,(tpic)
        call show_pic
        ld hl,s_hiscore
        ld de,23*40+11
        ld c,GREY
        call text_both
        ld hl,hiscore
        ld de,23*40+23
        ld c,BCYAN
        call bcd_both
        ld hl,s_start
        ld de,24*40+6
        ld c,WHITE
        call text_both
        ld hl,300
        ld (ttimer),hl
.w:     call read_input
        ld a,(keysnew)
        ld b,a
        ld a,(padnew)
        ld c,a
        call input_used
        bit 3,b
        jp nz,game_new
        bit 4,c
        jp nz,game_new
        ld a,(firepad)
        or a
        jp nz,game_new
        bit 2,b
        call nz,toggle_sound
        call sound_tick
        ld a,2
        call frame_wait
        ld hl,(ttimer)
        dec hl
        ld (ttimer),hl
        ld a,h
        or l
        jr nz,.w
        ld a,(tpic)
        xor 1
        ld (tpic),a
        jr .pic

s_hiscore: db "HIGH SCORE",0
s_start: db "SPACE OR A FIRE KEY TO START",0
boot_test: db 0
