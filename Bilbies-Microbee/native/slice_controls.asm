; Keyboard-only vertical-slice controls. Calls original skill eligibility and
; inventory routines in simulation block 27. Indexes are into n_entities;
; slice_slots maps those records back to the original 16-byte CRT records.
; LEFT/RIGHT select, 4 blocker, 5 builder, 8 digger, SPACE assign.
; O/P pan, C/M display, H pause. The caller must unmark before rendering and
; mark after rendering so the inverted colour cell never enters the cache.

slice_input:
        ; Shared n_input handles pan, mode and pause. Its benchmark-only
        ; 1/4/D handlers must be disabled in the playable-slice build.
        call n_input
.restart:
        ld a,18 : call n_key
        ld hl,slice_r_down : cp (hl) : jr z,.left
        ld (hl),a : or a : jr z,.left
        xor a : ld (n_paused),a : ld (n_anim),a : ld (slice_half_tick),a
        ld (slice_selected),a : ld (n_patch_count),a
        ld hl,0 : ld (n_camera),hl
        ld a,4 : ld (slice_skill),a
        call slice_init : call n_invalidate : call n_hud
.left:  ld a,$3B : call n_key
        ld hl,slice_left_down : cp (hl) : jr z,.right
        ld (hl),a : or a : jr z,.right
        ld a,(slice_selected) : or a : jr z,.right
        dec a : ld (slice_selected),a
.right: ld a,$3E : call n_key
        ld hl,slice_right_down : cp (hl) : jr z,.block
        ld (hl),a : or a : jr z,.block
        ld a,(n_count) : or a : jr z,.block
        ld b,a : ld a,(slice_selected) : inc a : cp b : jr nc,.block
        ld (slice_selected),a
.block: ld a,$24 : call n_key : jr z,.build
        ld a,3 : ld (slice_skill),a
.build: ld a,$25 : call n_key : jr z,.dig
        ld a,4 : ld (slice_skill),a
.dig:   ld a,$28 : call n_key : jr z,.assign
        ld a,7 : ld (slice_skill),a
.assign:ld a,$37 : call n_key
        ld hl,slice_space_down : cp (hl) : jr z,.done
        ld (hl),a : or a : jr z,.done
        call slice_assign
.done:  jp slice_hud_update

; Return with the original simulation bank selected on exit.
slice_assign:
        ld a,(n_count) : or a : ret z
        ld b,a : ld a,(slice_selected) : cp b : ret nc
        ld l,a : ld h,0 : ld de,slice_slots : add hl,de : ld a,(hl)
        cp 40 : ret nc
        ld l,a : ld h,0 : add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld de,$7B00 : add hl,de : push hl : pop ix
        ld a,27 : call n_bank
        ld a,(slice_skill) : call $0006 : jr nz,.done
        ld a,(slice_skill) : call $0009
.done:  jp n_home

slice_selected: db 0
slice_skill: db 4
slice_left_down: db 0
slice_right_down: db 0
slice_space_down: db 0
slice_r_down: db 0
slice_marker_valid: db 0
slice_marker_addr: dw 0
slice_marker_colour: db 0

 ; The common HUD's second line is:
 ; LEFT/RIGHT SELECT  4 BLOCK  5 BUILD  8 DIG  SPACE ASSIGN   BILBY 00  SKILL 8
slice_hud_update:
        ld a,(n_count) : or a : jr nz,.have_count
        xor a : ld (slice_selected),a : jr .show_zero
.have_count:
        ld b,a : ld a,(slice_selected) : cp b : jr c,.format
        dec b : ld a,b : ld (slice_selected),a
.format:ld a,(slice_selected) : inc a
.show_zero: ld d,'0'
.tens:  cp 10 : jr c,.digits : sub 10 : inc d : jr .tens
.digits:add a,'0' : ld e,a
        ld a,1 : call n_bank
        xor a : out ($08),a : ld a,$80 : out ($1C),a
        ld hl,$F000+1200+65 : ld (hl),d : inc hl : ld (hl),e
        ld a,(slice_skill) : add a,'1' : ld ($F000+1200+75),a
        ld hl,$F000+1120+33 : ld a,(slice_saved) : call slice_number
        inc hl : ld a,(slice_quota) : call slice_number
        ld hl,(slice_seconds) : ld de,100 : ld c,'0'
.hundreds:
        or a : sbc hl,de : jr c,.seconds : inc c : jr .hundreds
.seconds:
        add hl,de : ld a,l : ld hl,$F000+1120+42 : ld (hl),c : inc hl
        call slice_number
        ld a,(slice_goal_end) : or a : jr z,.ongoing
        ld a,(slice_saved) : ld b,a : ld a,(slice_quota) : cp b
        ld hl,.success : jr c,.result : jr z,.result
        ld hl,.failed
.result: ld de,$F000+1120+48 : ld bc,6 : ldir
.ongoing:
        jp n_home
.success: db "SAVED!"
.failed:  db "FAILED"
; A=0..99, HL=screen address; returns HL after the two digits.
slice_number:
        ld b,'0'
.tens:  cp 10 : jr c,.digits : sub 10 : inc b : jr .tens
.digits: ld (hl),b : inc hl : add a,'0' : ld (hl),a : inc hl : ret

; Temporarily invert a selected sprite cell's ink/paper so selection is visible
; in both colour and mono. Must be paired around every n_present call.
slice_unmark:
        ld a,(slice_marker_valid) : or a : ret z
        ld a,1 : call n_bank : ld a,$40 : out ($08),a
        ld hl,(slice_marker_addr) : ld a,(slice_marker_colour) : ld (hl),a
        xor a : out ($08),a : ld (slice_marker_valid),a : jp n_home
slice_mark:
        ld a,(n_count) : or a : ret z
        ld b,a : ld a,(slice_selected) : cp b : ret nc
        ld l,a : ld h,0 : add hl,hl : add hl,hl
        ld de,n_entities : add hl,de
        ld e,(hl) : inc hl : ld d,(hl) : inc hl
        ld a,(hl) : add a,4 : cp 224 : ret nc
        and $F0 : ld c,a : ld b,0
        ; row * 80 = (y & F0h) * 5
        ld h,b : ld l,c : ld d,b : ld e,c
        add hl,hl : add hl,hl : add hl,de : push hl
        ld a,(slice_selected) : ld l,a : ld h,0 : add hl,hl : add hl,hl
        ld de,n_entities : add hl,de : ld e,(hl) : inc hl : ld d,(hl)
        ld hl,(n_camera) : ex de,hl : or a : sbc hl,de
        ld de,5 : add hl,de : bit 7,h : jr nz,.offscreen
        ld de,640 : or a : sbc hl,de : jr nc,.offscreen
        add hl,de : srl h : rr l : srl h : rr l : srl h : rr l
        pop de : add hl,de : ld de,$F800 : add hl,de
        ld (slice_marker_addr),hl
        ld a,1 : call n_bank : ld a,$40 : out ($08),a
        ld hl,(slice_marker_addr) : ld a,(hl) : ld (slice_marker_colour),a
        rlca : rlca : rlca : rlca : ld (hl),a
        xor a : out ($08),a : inc a : ld (slice_marker_valid),a : jp n_home
.offscreen:
        pop de : ret
