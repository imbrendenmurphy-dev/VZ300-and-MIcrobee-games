; =====================================================================
;  SKYLARKIN' front end (an overlay at OVL, loaded from BLK_FRONT):
;  monitor choice, the title with its attract cycle (title, hall of fame,
;  how to play, the demo), pilot select and options, name entry, the
;  ending, and SAVE.DAT.   VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "../build/main.equ"
        INCLUDE "../build/front.inc"
        ORG OVL
        jp f_boot
        jp f_title
        jp f_ending
        jp f_gameend
        ds OVL+32-$

; ---------------------------------------------------------------------
f_boot: call front_glyphs
        ld a,WHITE
        ld (txt_col),a
        call cls
        call page_show0
        ld a,YELLOW
        ld (txt_col),a
        ld hl,s_cm1
        ld e,9
        call print_c
        ld a,WHITE
        ld (txt_col),a
        ld hl,s_cm2
        ld e,12
        call print_c
        ld hl,s_cm3
        ld e,14
        call print_c
.w:     call wait_frame
        ld a,(keysnew)
        and 8
        jr nz,.c
        ld a,(keysnew)
        and 16
        jr z,.w
        ld a,1
        jr .s
.c:     xor a
.s:     ld (monomode),a
        call input_used
        call load_game
        jp f_title
s_cm1:  db "SKYLARKIN'!",0
s_cm2:  db "PRESS  C  FOR A COLOUR MONITOR",0
s_cm3:  db "OR  M  FOR MONOCHROME",0

; ---------------------------------------------------------------------
; the title and the attract cycle
f_title:
        ld sp,STACK
        call stop_music
        xor a
        ld (demo),a
        ld (boss_on),a
        ld (warn_msg),a
        ld (shake_off),a
        call front_glyphs
        call page_show0
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
.cyc:   call title_page
        ld b,0
        call wait_go
        jp c,f_select
        call hof_page
        ld b,200
        call wait_go
        jp c,f_select
        call howto_page
        ld b,0
        call wait_go
        jp c,f_select
        ; the demo: the real game, flown by the autopilot
        ld a,1
        ld (demo),a
        ld hl,0
        ld (demo_t),hl
        call random
        and 3
        ld (pilot),a
        ld a,1
        ld (difficulty),a
        call stop_music
        jp new_game

; wait_go: B frames (0 = 256) unless SPACE / fire / RETURN -> C
wait_go:
.w:     push bc
        call wait_frame
        pop bc
        ld a,(padnew)
        and $10
        jr nz,.go
        ld a,(keysnew)
        and $20
        jr nz,.go
        djnz .w
        or a
        ret
.go:    call input_used
        ld a,SFX_MENU
        call play_sfx
        scf
        ret

title_page:
        ld hl,PIC_TITLE
        call show_pic
        ld a,YELLOW
        ld (txt_col),a
        ld hl,s_t2
        ld e,17
        call print_c
        ld a,WHITE
        ld (txt_col),a
        ld hl,s_t3
        ld e,20
        call print_c
        ld a,GREY
        ld (txt_col),a
        ld hl,s_t4
        ld e,23
        call print_c
        ld a,(unlocked)
        and 2
        ret z
        ld a,YELLOW
        ld (txt_col),a
        ld hl,s_t5
        ld de,0*256+24
        jp print
s_t2:   db "A FAIR DINKUM SHOOT-'EM-UP",0
s_t3:   db "PRESS SPACE OR FIRE",0
s_t4:   db "VIBED BY BPM 2026",0
s_t5:   db "* CLEARED *",0

; the hall of fame
hof_page:
        ld a,WHITE
        ld (txt_col),a
        call cls
        ld a,YELLOW
        ld (txt_col),a
        ld hl,s_h1
        ld e,3
        call print_c
        ld hl,hof
        ld (hp_ptr),hl
        ld a,7
        ld (hp_row),a
        ld a,1
        ld (hp_rank),a
.l:     ld a,(hp_rank)
        add a,'0'
        ld (s_hn),a
        ld a,(hp_rank)
        cp 1
        ld a,WHITE
        jr nz,.c
        ld a,YELLOW
.c:     ld (txt_col),a
        ld hl,s_hn
        ld a,(hp_row)
        ld e,a
        ld d,11
        call print
        ld hl,(hp_ptr)
        ld bc,4
        add hl,bc
        ld de,s_name
        ld bc,3
        ldir
        ld hl,s_name
        ld a,(hp_row)
        ld e,a
        ld d,15
        call print
        ld hl,(hp_ptr)
        ld a,(hp_row)
        ld e,a
        ld d,19
        call print_bcd
        ld hl,(hp_ptr)
        ld bc,7
        add hl,bc
        ld (hp_ptr),hl
        ld hl,hp_row
        inc (hl)
        inc (hl)
        ld hl,hp_rank
        inc (hl)
        ld a,(hl)
        cp 9
        jr c,.l
        ret
hp_ptr: dw 0
hp_row: db 0
hp_rank: db 0
s_h1:   db "HALL OF FAME",0
s_hn:   db "1.",0
s_name: db "AAA",0

; how to play: the bar, the bells
howto_page:
        ld a,WHITE
        ld (txt_col),a
        call cls
        ld hl,howto
        ld e,1
.l:     ld a,(hl)
        or a
        ret z
        ld (txt_col),a
        inc hl
        push hl
        call print_c
        pop hl
.z:     ld a,(hl)
        inc hl
        or a
        jr nz,.z
        inc e
        jr .l
howto:  db YELLOW,"HOW TO PLAY",0
        db GREY," ",0
        db WHITE,"ARROWS OR Q A O P - FLY",0
        db WHITE,"SPACE OR FIRE - SHOOT (HOLD IT)",0
        db WHITE,"X - TAKE THE LIT UPGRADE",0
        db WHITE,"H - PAUSE    S - SOUND",0
        db GREY," ",0
        db BRED,"RED CAPSULES MOVE THE BAR ALONG:",0
        db BCYAN,"SPEED MISSL DOUBL LASER OPTN SHLD OI!",0
        db WHITE,"OI! WIPES THE SCREEN",0
        db GREY," ",0
        db YELLOW,"SHOOT A BELL TO BOUNCE IT.",0
        db YELLOW,"EVERY THIRD HIT IT CHANGES COLOUR:",0
        db YELLOW,"GOLD  - POINTS (MORE IN A ROW)",0
        db BBLUE,"BLUE  - MEGAPHONE: BULLETS TO POINTS",0
        db BGREEN,"GREEN - BIG BIRD: RAM THROUGH THEM",0
        db BRED,"RED   - RAPID FIRE",0
        db WHITE,"WHITE - SLOW-MO",0
        db GREY," ",0
        db BMAGENTA,"JUGGLE A HOT BELL INTO A WAVE",0
        db BMAGENTA,"FOR A BIG MULTIPLIER!",0
        db 0

; ---------------------------------------------------------------------
; pilot select and options
f_select:
        ld hl,PIC_TITLE
        call show_pic
        ld a,BLACK
        ld (txt_col),a
        ld hl,0
        ld (fc_glyph),hl
        ld de,0*256+17
        ld bc,40*256+8
        call fill_cells
        call sel_draw
.w:     call wait_frame
        ld a,(padnew)
        ld c,a
        bit 0,c
        jr z,.nr
        ld a,(pilot)
        inc a
        ld hl,npil
        cp (hl)
        jr c,.p
        xor a
.p:     ld (pilot),a
        jr .chg
.nr:    bit 1,c
        jr z,.nl
        ld a,(pilot)
        dec a
        jp p,.q
        ld a,(npil)
        dec a
.q:     ld (pilot),a
        jr .chg
.nl:    ld a,c
        and 12
        jr z,.nd
        ld a,(difficulty)
        inc a
        cp 3
        jr c,.d
        xor a
.d:     ld (difficulty),a
        jr .chg
.nd:    ld a,(keysnew)
        and 8                   ; C or A: power-ups AUTO / MANUAL
        jr nz,.au
        ld a,c
        and $20                 ; X also toggles it
        jr z,.ng
.au:    ld a,(automode)
        xor 1
        ld (automode),a
        jr .chg
.ng:    ld a,c
        and $10
        jr nz,.go
        ld a,(keysnew)
        and $21
        jr z,.w
        and 1
        jp nz,f_title           ; ESC: back to the title
.go:    call input_used
        call stop_music
        ld a,(difficulty)
        ld (sv_diff),a
        ld hl,hof               ; the hi score on the HUD
        ld de,hiscore
        ld bc,4
        ldir
        xor a
        ld (demo),a
        jp new_game
.chg:   ld a,SFX_MENU
        call play_sfx
        call sel_draw
        jp .w

; how many pilots: LOCKIE once the game has been cleared
npil:   db 4
sel_draw:
        ld a,(unlocked)
        and 1
        ld a,4
        jr z,.n
        inc a
.n:     ld (npil),a
        ld a,(pilot)
        ld hl,npil
        cp (hl)
        jr c,.ok
        xor a
        ld (pilot),a
.ok:    ld a,(npil)
        ld b,a
        ld c,0
.l:     push bc
        ld a,(pilot)
        cp c
        ld a,GREY
        jr nz,.c
        ld a,BLACK+(YELLOW<<4)
.c:     ld (txt_col),a
        ld a,c
        add a,a
        ld l,a
        ld h,0
        ld de,pilot_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        add a,a
        add a,a
        add a,a                 ; *8
        ld d,a
        ld e,17
        call print
        pop bc
        inc c
        djnz .l
        ; the chosen pilot's kit
        ld a,BLACK
        ld (txt_col),a
        ld hl,0
        ld (fc_glyph),hl
        ld de,0*256+18
        ld bc,40*256+4
        call fill_cells
        ld a,WHITE
        ld (txt_col),a
        ld a,(pilot)
        add a,a
        ld l,a
        ld h,0
        ld de,pilot_desc
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,18
.dl:    push hl
        call print_c
        pop hl
.z:     ld a,(hl)
        inc hl
        or a
        jr nz,.z
        inc e
        ld a,(hl)
        or a
        jr nz,.dl
        ; skill and power-ups
        ld a,YELLOW
        ld (txt_col),a
        ld a,(difficulty)
        add a,a
        ld l,a
        ld h,0
        ld de,diff_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,22
        call print_c
        ld a,BCYAN
        ld (txt_col),a
        ld hl,s_man
        ld a,(automode)
        or a
        jr z,.m
        ld hl,s_auto
.m:     ld e,23
        call print_c
        ld a,GREY
        ld (txt_col),a
        ld hl,s_keys
        ld e,24
        jp print_c
s_man:  db " UPGRADES: PRESS X  (C: AUTO)",0
s_auto: db " UPGRADES: AUTOMATIC  (C)    ",0
s_keys: db "LEFT/RIGHT PILOT  UP/DOWN SKILL  SPACE",0

pilot_names:    dw pn0,pn1,pn2,pn3,pn4
pn0:    db " BAZZA ",0
pn1:    db " SHEILA",0
pn2:    db " WALLY ",0
pn3:    db "QUEENIE",0
pn4:    db " LOCKIE",0
pilot_desc:     dw pd0,pd1,pd2,pd3,pd4
pd0:    db "THE BIN CHICKEN - FLYING WHEELIE BIN",0
        db "ROTTEN BANANA, CHICKEN BONE",0
        db "STINK LINE, BABY BINS - 3 HEARTS",0,0
pd1:    db "THE KOALA - FLYING HILLS HOIST",0
        db "PEG DROP, UNDIES FLING",0
        db "SPIN CYCLE, FLYING SOCKS - SLOW",0,0
pd2:    db "THE WOMBAT - FLYING UTE",0
        db "GUMNUT BOMB, SPREAD",0
        db "KABOOMERANG, HARD HATS - 4 HEARTS",0,0
pd3:    db "THE MICROBEE - FLYING KEYBOARD",0
        db "BYTE BUGS, TWIN SHOT",0
        db "DOT MATRIX, FLOPPIES - FAST, 2 HEARTS",0,0
pd4:    db "THE LYREBIRD - MIMICS EVERYONE",0
        db "WALLY'S BOMBS AND SPREAD",0
        db "QUEENIE'S BEAM - FAST, 3 HEARTS",0,0
diff_names:     dw dn0,dn1,dn2
dn0:    db "  SKILL: EASY (5 HEARTS)  ",0
dn1:    db " SKILL: NORMAL (3 HEARTS) ",0
dn2:    db "  SKILL: HARD (ONE HIT)   ",0

; ---------------------------------------------------------------------
; the ending: APPROVED. Unlocks LOCKIE.
f_ending:
        ld sp,STACK
        call stop_music
        ld a,(unlocked)
        or 3
        ld (unlocked),a
        call front_glyphs
        call page_show0
        ld hl,mus_end_0
        ld de,mus_end_1
        call play_music
        ld hl,PIC_END
        call show_pic
        ld hl,endtext
        ld e,18
.l:     ld a,(hl)
        or a
        jr z,.w
        ld (txt_col),a
        inc hl
        push hl
        call print_c
        pop hl
.z:     ld a,(hl)
        inc hl
        or a
        jr nz,.z
        inc e
        jr .l
.w:     ld b,0
        call wait_go
        jr c,.x
        ld b,0
        call wait_go
.x:     jp f_gameend
endtext:
        db WHITE,"THE SKY IS OURS AGAIN!",0
        db GREY,"HEAD OFFICE HAS BEEN... RESTRUCTURED.",0
        db YELLOW,"BAZZA, SHEILA, WALLY AND QUEENIE",0
        db YELLOW,"THREW A PARTY IN THE BOARDROOM.",0
        db BGREEN,"LOCKIE THE LYREBIRD JOINS THE CREW!",0
        db BMAGENTA,"VIBED BY BPM 2026",0
        db 0

; ---------------------------------------------------------------------
; after a game: into the hall of fame?
f_gameend:
        ld sp,STACK
        ld a,(demo)
        or a
        jp nz,f_title
        call stop_music
        call front_glyphs
        call page_show0
        ; find the place: the first entry the score beats
        ld hl,hof
        ld b,8
        ld c,0
.f:     push hl
        push bc
        ld de,score
        ld b,4
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.cd
        inc de
        inc hl
        djnz .cmp
        ; equal: not better
        pop bc
        pop hl
        jr .nx
.cd:    pop bc
        pop hl
        jr nc,.got              ; score > entry
.nx:    ld de,7
        add hl,de
        inc c
        djnz .f
        jp f_title              ; not good enough
.got:   ; move the lower entries down one: entries c..6 -> c+1..7
        ld (ne_ent),hl
        ld a,7
        sub c
        jr z,.ins
        ld b,a                  ; entries to move
        ld a,b
        add a,a
        add a,a
        add a,a
        sub b                   ; *7 bytes
        ld c,a
        ld b,0
        ld hl,hof+7*7-1
        ld de,hof+8*7-1
        lddr
.ins:   ld hl,score
        ld de,(ne_ent)
        ld bc,4
        ldir
        ld a,'A'
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        call name_entry
        call save_game
        call hof_page
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld b,200
        call wait_go
        jp f_title
ne_ent: dw 0

; name entry: three letters into the entry at (ne_ent)+4
name_entry:
        ld a,WHITE
        ld (txt_col),a
        call cls
        ld a,YELLOW
        ld (txt_col),a
        ld hl,s_ne1
        ld e,6
        call print_c
        ld a,WHITE
        ld (txt_col),a
        ld hl,s_ne2
        ld e,9
        call print_c
        ld hl,s_ne3
        ld e,20
        call print_c
        xor a
        ld (ne_pos),a
.draw:  ld hl,(ne_ent)
        ld de,4
        add hl,de
        ld de,s_name
        ld bc,3
        ldir
        ld a,BLACK+(YELLOW<<4)
        ld (txt_col),a
        ld hl,s_name
        ld de,18*256+13
        call print
        ld a,WHITE
        ld (txt_col),a
        ld hl,s_cur
        ld de,17*256+14
        call print
        ld a,(ne_pos)
        add a,18
        ld d,a
        ld e,14
        ld hl,s_up
        call print
.w:     call wait_frame
        ld a,(padnew)
        ld c,a
        ld a,(ne_pos)
        ld hl,(ne_ent)
        add a,4
        ld e,a
        ld d,0
        add hl,de               ; HL -> the letter
        bit 2,c
        jr z,.nu
        call .next
        jr .chg
.nu:    bit 3,c
        jr z,.nd
        call .prev
        jr .chg
.nd:    ld a,c
        and $11                 ; fire or right: the next letter
        jr nz,.adv
        bit 1,c
        jr z,.nb
        ld a,(ne_pos)
        or a
        jr z,.w
        dec a
        ld (ne_pos),a
        jr .chg
.nb:    ld a,(keysnew)
        and $20
        jr z,.w
.adv:   ld a,(ne_pos)
        inc a
        cp 3
        jr nc,.done
        ld (ne_pos),a
.chg:   ld a,SFX_MENU
        call play_sfx
        jp .draw
.done:  call input_used
        ld a,SFX_BELLGET
        jp play_sfx
.next:  ld a,(hl)              ; A..Z, space, full stop, A..
        cp 'Z'
        jr z,.sp
        cp ' '
        jr z,.dot
        cp '.'
        jr z,.aa
        inc a
        jr .s
.prev:  ld a,(hl)
        cp 'A'
        jr z,.dot
        cp '.'
        jr z,.sp
        cp ' '
        jr z,.zz
        dec a
        jr .s
.sp:    ld a,' '
        jr .s
.dot:   ld a,'.'
        jr .s
.aa:    ld a,'A'
        jr .s
.zz:    ld a,'Z'
.s:     ld (hl),a
        ret
ne_pos: db 0
s_ne1:  db "A NEW HIGH SCORE!",0
s_ne2:  db "YOUR INITIALS, PLEASE",0
s_ne3:  db "UP/DOWN LETTER  FIRE/RIGHT NEXT",0
s_cur:  db "     ",0
s_up:   db "^",0

; ---------------------------------------------------------------------
; show_pic: a whole-screen picture from BLK_FRONT at HL onto both pages,
; its glyphs into the PCG from glyph 128
show_pic:
        ld a,BLK_FRONT
        call map_blk
        ld a,LV_SCREEN
        out (P_LV),a
        ld de,VIDEO
        ld bc,1000
        ldir
        push hl
        ld hl,VIDEO
        ld de,VIDEO+$400
        ld bc,1000
        ldir
        pop hl
        ld a,LV_ATTR
        out (P_LV),a
        ld de,VIDEO
        ld bc,1000
        ldir
        push hl
        ld hl,VIDEO
        ld de,VIDEO+$400
        ld bc,1000
        ldir
        pop hl
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld de,COLWIN
        ld bc,1000
        ldir
        push hl
        ld hl,COLWIN
        ld de,COLWIN+$400
        ld bc,1000
        ldir
        pop hl
        xor a
        out (P_COLCTL),a
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(monomode)
        or a
        jr z,.c
        push bc                 ; skip the colour patterns (n x 8)
        ex de,hl
        ld h,b
        ld l,c
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        pop bc
.c:     ld de,128
        jp glyphs_in

; =====================================================================
;  SAVE.DAT on the game's own disk (from MICROBEE AUSTRALIAN OPEN TENNIS).
;  build_disk.py puts SAVE.DAT first: directory entry 0, allocation block
;  1 = track 2, side 0, logical sector 8 (Microbee 3:1 skew: sector ID 26).
;  The directory (logical sector 0 of track 2, ID 22) is checked before
;  every write, so a disk without the file (or with it moved) is never
;  written. The WD2793 is driven directly; every wait is bounded.
; =====================================================================
SVBUF   equ $3800               ; 512 bytes in the RT block
FDC_CMD equ $44
FDC_TRK equ $45
FDC_SEC equ $46
FDC_DAT equ $47
FDC_DRV equ $48
SV_TRACK equ 2
SV_DIRSEC equ 22
SV_DATSEC equ 26

sv_cmd: out (FDC_CMD),a
        ld a,16
.d:     dec a
        jr nz,.d
        ret
sv_wait:
        ld de,0
.w:     in a,(FDC_CMD)
        bit 0,a
        ret z
        dec de
        ld a,d
        or e
        jr nz,.w
        ld a,$D0
        out (FDC_CMD),a
        ld a,$FF
        ret
sv_drq: ld de,0
.w:     in a,(FDC_CMD)
        bit 1,a
        jr nz,.ok
        bit 0,a
        jr z,.err
        dec de
        ld a,d
        or e
        jr nz,.w
.err:   ld (sv_st),a
        ld a,$D0
        out (FDC_CMD),a
        scf
        ret
.ok:    or a
        ret
sv_locate:
        ld a,8
        out (FDC_DRV),a
        ld a,$0B
        call sv_cmd
        call sv_wait
        cp $FF
        ret z
        ld a,SV_TRACK
        out (FDC_DAT),a
        ld a,$1C
        call sv_cmd
        call sv_wait
        cp $FF
        ret z
        and $18
        ret nz
        ld bc,8000
.s:     dec bc
        ld a,b
        or c
        jr nz,.s
        ld a,(sv_sec)
        out (FDC_SEC),a
        xor a
        ret
sv_read:
        call sv_locate
        ret nz
        ld a,$88
        call sv_cmd
        ld hl,SVBUF
        ld bc,512
.b:     call sv_drq
        jr c,sv_fail
        in a,(FDC_DAT)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.b
        call sv_wait
        and $9C
        ret
sv_write:
        call sv_locate
        ret nz
        ld a,$A8
        call sv_cmd
        ld hl,SVBUF
        ld bc,512
.b:     call sv_drq
        jr c,sv_wfail
        ld a,(hl)
        out (FDC_DAT),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.b
        call sv_wait
        bit 6,a
        jr nz,sv_wp
        and $FC
        ret
sv_wp:  ld a,2
        or a
        ret
sv_wfail:
        ld a,(sv_st)
        bit 6,a
        ld a,2
        ret nz
sv_fail:
        ld a,1
        or a
        ret
sv_st:  db 0
sv_sec: db 0
sv_error: db 0
sv_name: db 0,"SAVE    DAT"

sv_dir: ld a,SV_DIRSEC
        ld (sv_sec),a
        call sv_read
        ret nz
        ld hl,SVBUF
        ld de,sv_name
        ld b,12
.n:     ld a,(de)
        cp (hl)
        ret nz
        inc de
        inc hl
        djnz .n
        ld a,(SVBUF+16)
        cp 1
        ret

SV_VER  equ 12
SV_DATA equ 13
SV_LEN  equ sv_end-sv_first
sv_sig: db "SKYLARKSAVE1"
sv_sum: ld hl,SVBUF+SV_VER
        ld b,SV_LEN+1
        xor a
.b:     add a,(hl)
        rlca
        inc hl
        djnz .b
        ret

; at start-up: the hall of fame and the rest (defaults if there's no save)
load_game:
        ld hl,hof_init
        ld de,hof
        ld bc,8*7
        ldir
        ld a,BLK_RT
        call map_blk
        di
        call sv_dir
        jr nz,.x
        ld a,SV_DATSEC
        ld (sv_sec),a
        call sv_read
        jr nz,.x
        ld hl,SVBUF
        ld de,sv_sig
        ld b,12
.s:     ld a,(de)
        cp (hl)
        jr nz,.x
        inc hl
        inc de
        djnz .s
        ld a,(SVBUF+SV_VER)
        cp 1
        jr nz,.x
        call sv_sum
        ld hl,SVBUF+SV_DATA+SV_LEN
        cp (hl)
        jr nz,.x
        ld hl,SVBUF+SV_DATA
        ld de,sv_first
        ld bc,SV_LEN
        ldir
        ld a,(sv_diff)
        cp 3
        jr c,.d
        xor a
.d:     ld (difficulty),a
        ld a,(automode)
        and 1
        ld (automode),a
.x:     ret

; write everything: sv_error 0 ok, 1 disk error / no SAVE.DAT, 2 write protected
save_game:
        ld a,BLK_RT
        call map_blk
        di
        call sv_dir
        jr nz,.bad
        ld hl,SVBUF
        ld b,0
.c:     ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        djnz .c
        ld hl,sv_sig
        ld de,SVBUF
        ld bc,12
        ldir
        ld a,1
        ld (SVBUF+SV_VER),a
        ld hl,sv_first
        ld de,SVBUF+SV_DATA
        ld bc,SV_LEN
        ldir
        call sv_sum
        ld (SVBUF+SV_DATA+SV_LEN),a
        ld a,SV_DATSEC
        ld (sv_sec),a
        call sv_write
        jr nz,.err
        call sv_read
        jr nz,.bad
        call sv_sum
        ld hl,SVBUF+SV_DATA+SV_LEN
        cp (hl)
        jr nz,.bad
        xor a
        jr .x
.err:   cp 2
        jr z,.x
.bad:   ld a,1
.x:     ld (sv_error),a
        ret

hof_init:
        db $00,$05,$00,$00,"BPM"
        db $00,$04,$00,$00,"IBS"
        db $00,$03,$00,$00,"KOA"
        db $00,$02,$50,$00,"WOM"
        db $00,$02,$00,$00,"BEE"
        db $00,$01,$50,$00,"BOS"
        db $00,$01,$00,$00,"CEO"
        db $00,$00,$50,$00,"HR."

ovl_end:
        ASSERT ovl_end <= OVL_END
        SAVEBIN "../build/FRONT.BIN",OVL,ovl_end-OVL
        DISPLAY "front end overlay end: ",ovl_end
