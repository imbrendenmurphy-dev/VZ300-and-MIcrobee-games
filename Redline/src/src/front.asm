; =====================================================================
;  front.asm - title, menus, stage screens, results (upper bank 0)
; =====================================================================
TITLE_ART equ $CC00           ; 2K mode(1) picture (from RLCOM.DAT)
NLEGS     equ 5
FE_MAIN:
        ld sp,stack_top
        ld a,MAP_FE
        out (BANKPORT),a
        ei
fe_title:
        di
        call show_title
        ld hl,song_title
        call seq_start
        ld hl,title_hook
        ld (vz_mhook),hl
        ld hl,MITERS-8
        ld (vz_miters),hl
        ld hl,0
        ld (vz_idle),hl
.t:     ld b,0
        call vz_mplay_t         ; until a key, or ~25 s
        jr nz,.key
        ; attract: a demo run of stage 1
        call vz_mstop
        ld a,1
        ld (demo),a
        ld a,(demo_leg)         ; the attract demo tours the stages in turn
        inc a
        cp NLEGS
        jr c,.dl
        xor a
.dl:    ld (demo_leg),a
        call run_leg
        xor a
        ld (demo),a
        jr fe_title
.key:   call vz_mstop
        call wait_release
        call menu
        jr fe_title

; music until a key; Z after ~1200 steps with no key
vz_mplay_t:
        ld b,200
        call vz_mplay
        ret nz
        ld hl,(vz_idle)
        ld de,1250
        or a
        sbc hl,de
        jr c,vz_mplay_t
        xor a
        ret

; ---------------------------------------------------------------- screens
show_title:
        ld a,L_MODE
        ld (latchv),a
        ld a,L_MODE|L_SPK0
        ld (spkoff),a
        ld (LATCH),a
        ld hl,TITLE_ART
        ld de,VRAM
        ld bc,2048
        ldir
        ret

; title animation: blink PRESS FIRE, road stripes rolling
title_hook:
        ld hl,tt_cnt
        inc (hl)
        ld a,(hl)
        and 31
        ret nz
        ld a,(hl)
        and 32
        ld hl,t_press
        jr z,.on
        ld hl,t_blank
.on:    ld a,$55
        ld (hud_fg),a
        ld a,$AA
        ld (hud_bg),a
        push hl
        call hud_colours
        pop hl
        ld bc,$3A0B
        jp hud_text
tt_cnt: db 0
t_press: db "PRESS FIRE",0
t_blank: db "          ",0

; plain screen for menus/info: sky colour, a road, text rows
info_screen:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),$AA
        ldir
        ; bands: horizon stripes and a red base
        ld hl,VRAM+50*32
        ld de,VRAM+50*32+1
        ld bc,14*32-1
        ld (hl),$FF
        ldir
        ld hl,VRAM+48*32
        ld de,VRAM+48*32+1
        ld bc,63
        ld (hl),$55
        ldir
        ld a,$55
        ld (hud_fg),a
        ld a,$AA
        ld (hud_bg),a
        jp hud_colours

; HL -> list of (row, col, text 0) ... row $FF ends; colours from hud_fg/bg
text_list:
        ld a,(hl)
        cp $FF
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        call hud_text
        inc hl
        jr text_list

wait_release:
        call vz_anykey
        jr nz,wait_release
        ret

; keys for menus: A = bits 0 left 1 right 2 fire (edge), waits ~20 ms
menu_keys:
        ld b,0
.d:     djnz .d
        call read_input
        ld a,(keys)
        ld c,a
        ld a,($68EF)            ; SPACE also
        bit 4,a
        jr nz,.n
        set 2,c
.n:     ld a,c
        ld hl,mk_old
        ld b,(hl)
        ld (hl),a
        ld a,b
        cpl
        and c
        ret
mk_old: db $FF

; ---------------------------------------------------------------- menu
menu:
        call info_screen
        ld hl,menu_text
        call text_list
        xor a
        ld (msel),a
        ld (pleg),a
        ld a,$FF
        ld (mk_old),a
.draw:  call menu_marks
.k:     call menu_keys
        bit 2,a
        jr nz,.go
        bit 0,a
        jr nz,.up
        bit 1,a
        jr nz,.dn
        ld hl,(vz_idle)
        inc hl
        ld (vz_idle),hl
        ld a,h
        cp 40
        ret nc                  ; idle: back to the title
        jr .k
.up:    ld a,(msel)
        or a
        jr z,.lg
        xor a
        ld (msel),a
        jr .draw
.lg:    ; on practice row left/right change the stage
        jr .draw
.dn:    ld a,(msel)
        or a
        jr nz,.st
        inc a
        ld (msel),a
        jr .draw
.st:    ld a,(pleg)
        inc a
        cp NLEGS
        jr c,.s1
        xor a
.s1:    ld (pleg),a
        jr .draw
.go:    ld hl,0
        ld (vz_idle),hl
        ld a,(msel)
        or a
        jp z,grand_tour
        ; practice one stage
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld a,(pleg)
        call run_leg
        ret

menu_marks:
        ld a,(msel)
        or a
        ld a,'>'
        ld b,' '
        jr z,.m
        ld a,' '
        ld b,'>'
.m:     push bc
        ld bc,$1806
        call hud_char
        pop af
        ld bc,$2006
        call hud_char
        ld a,(pleg)
        add a,'1'
        ld bc,$2018
        call hud_char
        ld a,(pleg)
        add a,a
        ld l,a
        ld h,0
        ld de,leg_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld bc,$2808
        jp hud_text

menu_text:
        db 2,8,"REDLINE",0
        db 8,6,"COAST TO COAST",0
        db 24,7,"GRAND TOUR",0
        db 32,7,"PRACTICE STAGE",0
        db 52,1,"FIRE START  LEFT/RIGHT CHOOSE",0
        db 58,4,"2026 VIBED BY BPM",0
        db $FF
msel:   db 0
pleg:   db 0

; ---------------------------------------------------------------- grand tour
grand_tour:
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (tour_leg),a
.l:     ld a,(tour_leg)
        call run_leg
        or a
        jr z,.over
        ld a,(tour_leg)
        inc a
        ld (tour_leg),a
        cp NLEGS
        jr c,.l
        call ending
        jr .hs
.over:  call game_over
.hs:    call check_hiscore
        ret
tour_leg: db 0
demo_leg: db NLEGS-1

; A = leg: intro screen, load, race, result screen.  A = 1 cleared
run_leg:
        ld (pleg),a
        ld a,(demo)
        or a
        jr nz,.ld
        call stage_intro
.ld:    ld a,(pleg)
        ld (leg),a
        xor a
        ld (section),a
        call sec_name
        ld hl,fname
        call fe_load
        jr c,.miss
        ld a,(pleg)
        call fe_race
        push af
        ld a,(demo)
        or a
        jr nz,.d
        pop af
        push af
        or a
        call nz,stage_clear
.d:     pop af
        ret
.miss:  call info_screen
        ld hl,t_miss
        call text_list
        ld b,150
        call vz_mplay
        xor a
        ret
t_miss: db 20,2,"STAGE FILE MISSING",0
        db 28,2,"COPY ALL RL*.DAT FILES",0
        db 34,2,"TO THE SD CARD",0,$FF

stage_intro:
        ; the stage's picture, streamed from the SD card (RLnP.DAT) straight
        ; into video RAM; text goes in the band along the bottom
        ld a,(pleg)
        ld (leg),a
        call sec_name
        ld a,'P'
        ld (fname+4),a
        ld hl,fname
        call fe_load
        jr c,.nopic
        ld a,(PICVAR)
        ld (LATCH),a
        and L_CSS
        ld a,$55                ; text: yellow (set 0) / buff (set 1)
        jr z,.c0
        xor a
.c0:    ld (hud_fg),a
        ld a,$FF                ; on the red / orange band
        ld (hud_bg),a
        call hud_colours
        jr .txt
.nopic: call info_screen
.txt:   ; "STAGE n  NAME" centred in the band along the bottom
        ld a,(pleg)
        add a,'1'
        ld (t_stg+6),a
        ld a,(pleg)
        add a,a
        ld l,a
        ld h,0
        ld de,leg_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ex de,hl
        call strlen
        ld a,32-9
        sub b
        srl a
        ld c,a
        push bc
        ld hl,t_stg
        ld b,58
        call hud_text           ; leaves C after the text
        pop bc
        ld a,c
        add a,9
        ld c,a
        ld b,58
        pop hl
        call hud_text
        ld hl,song_start
        call seq_start
        ld hl,vz_nohook
        ld (vz_mhook),hl
        ld hl,MITERS
        ld (vz_miters),hl
.p:     ld b,10
        call vz_mplay
        ld a,(seq_done)
        or a
        jr z,.p
        ld b,60                 ; a moment to take in the picture
        call vz_mplay
        call vz_mstop
        ld a,L_MODE|L_SPK0
        ld (LATCH),a
        ei
        ret
PICVAR  equ $CBFF
t_stg:  db "STAGE 1",0

strlen: ld b,0
.l:     ld a,(hl)
        or a
        ret z
        inc hl
        inc b
        jr .l

stage_clear:
        call info_screen
        ld hl,t_clear
        call text_list
        ; time bonus: seconds left x 1000 (BCD 100s in score units of 10)
        ld a,(tleft)
        ld (bonus_t),a
        ld hl,song_clear
        call seq_start
        ld hl,clear_hook
        ld (vz_mhook),hl
.p:     ld b,10
        call vz_mplay
        ld a,(seq_done)
        or a
        jr z,.p
        call vz_mstop
        ld b,100
        call vz_mplay
        call vz_mstop
        ei
        ret
t_clear: db 12,10,"STAGE CLEAR",0
         db 24,6,"TIME BONUS",0
         db $FF
bonus_t: db 0
clear_hook:                     ; count the bonus into the score
        ld a,(bonus_t)
        or a
        jr z,.show
        dec a
        ld (bonus_t),a
        ld hl,score+1
        ld a,(hl)
        add a,$01               ; +100 pts (x10 = 1000)
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
.show:  ld hl,score
        ld de,numbuf
        call bcd6
        ld hl,numbuf
        ld bc,$1E0C
        jp hud_text

game_over:
        call info_screen
        ld hl,t_over
        call text_list
        ld hl,song_over
        call seq_start
        ld hl,vz_nohook
        ld (vz_mhook),hl
.p:     ld b,10
        call vz_mplay
        ld a,(seq_done)
        or a
        jr z,.p
        call vz_mstop
        ld b,100
        call vz_mplay
        call vz_mstop
        ei
        ret
t_over: db 16,11,"GAME OVER",0
        db 26,6,"OUT OF TIME",0
        db $FF

ending:
        call info_screen
        ld hl,t_end
        call text_list
        ld hl,song_title
        call seq_start
        ld b,250
        call vz_mplay
        ld b,250
        call vz_mplay
        call vz_mstop
        ei
        ret
t_end:  db 6,5,"COAST TO COAST!",0
        db 16,2,"YOU CROSSED THE CONTINENT",0
        db 24,4,"FROM THE INDIAN OCEAN",0
        db 30,4,"TO THE PACIFIC SHORE",0
        db 40,7,"CONGRATULATIONS",0
        db $FF

check_hiscore:
        ld hl,score
        ld de,hiscore
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.new
        ret nz
        inc hl
        inc de
        djnz .c
        ret
.new:   ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        call info_screen
        ld hl,t_hs
        call text_list
        ld hl,score
        ld de,numbuf
        call bcd6
        ld hl,numbuf
        ld bc,$1E0C
        call hud_text
        ld hl,song_clear
        call seq_start
        ld b,200
        call vz_mplay
        call vz_mstop
        ei
        ret
t_hs:   db 14,6,"NEW HIGH SCORE",0,$FF

; ---------------------------------------------------------------- stage names
leg_names: dw ln1,ln2,ln3,ln4,ln5
ln1:    db "SUNSET COAST",0
ln2:    db "RED CENTRE",0
ln3:    db "RAINFOREST RIDGE",0
ln4:    db "SNOWY RANGE",0
ln5:    db "HARBOUR LIGHTS",0
        include "music.asm"
        include "../build/songs.asm"
