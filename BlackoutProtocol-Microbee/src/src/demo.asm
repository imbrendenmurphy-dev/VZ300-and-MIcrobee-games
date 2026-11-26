; ---------------------------------------------------------------------------
; The attract demo: when the title tune has played through untouched, Wren plays
; by herself for ~45 s (Agent level) and the title comes back.  Any key, or ESC,
; ends it at once.
;
; Her "AI" replaces the keyboard in read_keys (one decision per logic tick):
;   - finishing a search, a vault or a fall: carry on
;   - a robot on her floor coming up ahead: vault it
;   - an unsearched fitting at her feet (not too often): search it
;   - otherwise run; if she's stopped by a wall, turn round
; so she wanders the rooms, out through the doors and on along the lift shafts.
; ---------------------------------------------------------------------------
DEMO_ROOM  equ 0                ; Cargo Bay 7: conveyors, a guard, lots to search
DEMO_TICKS equ 2250             ; ~45 s of logic ticks
DEMO_SEE   equ 26               ; vault when a robot is this close ahead (half-pixels)

demo_start:
        ld sp,STACKTOP
        ld a,1                  ; Agent
        ld (skill),a
        call skill_apply
        call game_init
        ld a,1
        ld (demo_on),a
        ld hl,DEMO_TICKS
        ld (demo_t),hl
        xor a
        ld (demo_dir),a
        ld (demo_stuck),a
        ld (demo_cool),a
        ld b,0                  ; in through the left door
        ld a,DEMO_ROOM
        call enter_room
        ld hl,str_demo
        call msg_show
        jp loop
str_demo: db "DEMO - ANY KEY",0

demo_quit:
        xor a
        ld (demo_on),a
        ld (kbits),a
        ld sp,STACKTOP
        jp title

; In: C = keys really held.  Out: C = the keys Wren "presses".
demo_keys:
        ld a,c                  ; a real key: back to the title
        or a
        jr nz,demo_quit
        ld hl,(demo_t)
        dec hl
        ld (demo_t),hl
        ld a,h
        or l
        jr z,demo_quit
        ld a,(demo_cool)
        or a
        jr z,.c0
        dec a
        ld (demo_cool),a
.c0:    ld a,(wstate)
        cp WS_SEARCH
        jr nz,.ns
        ld c,1<<K_UP            ; searching: hold on till it's done
        ret
.ns:    ld a,(gmode)
        or a
        jp nz,.run              ; in a shaft: on across
        ld a,(wstate)
        or a
        jp nz,.run              ; mid-vault or falling: keep going
        ld a,(wx)               ; stuck against a wall? turn round
        ld hl,demo_lastx
        cp (hl)
        ld (hl),a
        ld a,0
        jr nz,.st
        ld a,(demo_stuck)
        inc a
        cp 8
        jr c,.st
        ld a,(demo_dir)
        xor 1
        ld (demo_dir),a
        xor a
.st:    ld (demo_stuck),a
        call wren_floor_row     ; a robot on this floor, coming up ahead?
        cp $FF
        jr z,.srch
        ld e,a
        ld a,(nrob)
        or a
        jr z,.srch
        ld b,a
        ld ix,robots
.r:     ld a,(ix+RB_KIND)
        cp 4
        jr nc,.nx               ; (vents and lasers: not robots)
        ld a,(ix+RB_FLOOR)
        cp e
        jr nz,.nx
        ld a,(demo_dir)
        or a
        ld hl,wx
        jr nz,.lt
        ld a,(ix+RB_X)          ; running right: robot x - Wren x
        sub (hl)
        jr .d
.lt:    ld a,(hl)               ; running left: Wren x - robot x
        sub (ix+RB_X)
.d:     jr c,.nx                ; behind her
        cp DEMO_SEE
        jr c,.vault
.nx:    push de
        ld de,RB_SIZE
        add ix,de
        pop de
        djnz .r
.srch:  ld a,(demo_cool)        ; search what she passes, now and then
        or a
        jr nz,.run
        call term_under         ; (never at a terminal: that opens a page)
        and $0C
        jr nz,.run
        call searchable
        jr nc,.run
        ld a,150
        ld (demo_cool),a
        ld c,1<<K_UP
        ret
.vault: ld a,(demo_dir)
        or a
        ld c,(1<<K_RIGHT)|(1<<K_FIRE)
        ret z
        ld c,(1<<K_LEFT)|(1<<K_FIRE)
        ret
.run:   ld a,(demo_dir)
        or a
        ld c,1<<K_RIGHT
        ret z
        ld c,1<<K_LEFT
        ret
