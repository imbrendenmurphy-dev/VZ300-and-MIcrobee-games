; ---------------------------------------------------------------------------
; The second overlay: the save and load pages (BLACKOUT.OV2, block 30).
; ---------------------------------------------------------------------------
        jp save_page_open
        jp load_page_open
        jp level_page_open

; Before a new game: Story, Agent or Ghost.
level_page_open:
        call page_begin
        ld hl,level_page
        call page_run
        call page_show
.k:     ld a,KEY_X
        call scan_key
        jp nz,title
        ld b,0
.s:     ld a,b
        add a,KEY_1
        call scan_key
        jr nz,.go
        inc b
        ld a,b
        cp 3
        jr nz,.s
        jr .k
.go:    ld a,b
        ld (skill),a
        call skill_apply
        call sfx_found
        call wait_up
        jp new_game

save_page_open:
        call page_begin
        ld hl,save_page
        call page_run
        call slots_list
        call page_show
.k:     ld a,KEY_X
        call scan_key
        jr nz,.back
        ld b,1
.s:     ld a,b
        add a,KEY_0
        call scan_key
        jr nz,.save
        inc b
        ld a,b
        cp 4
        jr nz,.s
        jr .k
.save:  push bc
        call save_pack
        pop bc
        ld a,b
        call slot_write
        ld hl,str_saved
        jr nc,.m
        ld hl,str_noprot
        bit 6,a
        jr nz,.m
        ld hl,str_nosave
.m:     ld (pend_msg),hl
        call sfx_found
.back:  call wait_up
        jp resume_room

load_page_open:
        call page_begin
        ld hl,load_page
        call page_run
        call slots_list
        call page_show
.k:     ld a,KEY_X
        call scan_key
        jp nz,title
        ld b,0
.s:     ld a,b
        add a,KEY_0
        call scan_key
        jr nz,.load
        inc b
        ld a,b
        cp 4
        jr nz,.s
        jr .k
.load:  ld a,b
        call slot_read
        jr c,.k
        call save_valid
        jr nz,.k
        call sfx_found
        jp save_restore

; The four slots, rows 7, 9, 11, 13: wing, keys, shards, time left.
slots_list:
        ld b,0
.sl:    push bc
        ld a,b
        add a,a
        add a,7
        ld (tmp_x),a
        ld a,b
        call slot_read
        jp c,.empty
        call save_valid
        jp nz,.empty
        ld a,(SAVE_BUF+SV_ROOM) ; its wing's name
        ld hl,room_wing
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        add a,a
        ld l,a
        ld h,0
        ld de,wing_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(SAVE_BUF+SV_SKILL) ; the name in its level's colour
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,sk_ink
        add hl,de
        ld e,(hl)
        pop hl
        ld a,(tmp_x)
        ld c,a
        ld a,10
        call print_at
        ld a,(tmp_x)            ; keys k/6, shards nn, time hh:mm
        ld c,a
        ld a,24
        ld (pr_col),a
        ld a,$0A
        ld (pr_ink),a
        ld a,'K'
        call put_c1
        ld a,(SAVE_BUF+SV_KEYS)
        call put_digit
        ld a,'/'
        call put_c1
        ld a,'6'
        call put_c1
        ld a,29
        ld (pr_col),a
        ld a,$0E
        ld (pr_ink),a
        ld a,'S'
        call put_c1
        ld a,(SAVE_BUF+SV_SHARDS)
        call put2
        ld a,33
        ld (pr_col),a
        ld a,$0B
        ld (pr_ink),a
        ld a,(SAVE_BUF+SV_CLK)
        call put2
        ld a,':'
        call put_c1
        ld a,(SAVE_BUF+SV_CLK+1)
        call put2
        jr .nx
.empty: ld hl,str_empty
        ld a,(tmp_x)
        ld c,a
        ld a,10
        ld e,$08
        call print_at
.nx:    pop bc
        inc b
        ld a,b
        cp 4
        jp nz,.sl
        ret

sk_ink: db $0A,$0F,$09,$0F     ; Story green, Agent white, Ghost red
wing_names: dw wn0, wn1, wn2, wn3, wn4, wn5
wn0:    db "DOCKING",0
wn1:    db "HYDROPONICS",0
wn2:    db "CRYO LABS",0
wn3:    db "REACTOR DECK",0
wn4:    db "OBSERVATORY",0
wn5:    db "MERIDIAN CORE",0
str_empty:  db "- EMPTY -",0

level_page:
        db PG_PANEL,4,3,17,38,$0E
        db PG_HEAD,4,5,$0B,"CLEARANCE",0
        db PG_KEY,6,5," 1 ",0
        db PG_TEXT,6,9,$0A,"STORY",0
        db PG_TEXT,7,9,$08,"SLOWER CLOCK, SLOWER HUNTERS",0
        db PG_KEY,9,5," 2 ",0
        db PG_TEXT,9,9,$0F,"AGENT",0
        db PG_TEXT,10,9,$08,"THE MISSION AS DESIGNED",0
        db PG_KEY,12,5," 3 ",0
        db PG_TEXT,12,9,$09,"GHOST",0
        db PG_TEXT,13,9,$08,"FAST CLOCK, QUICK GUNS",0
        db PG_SEP,15,5,36
        db PG_TEXT,16,5,$0F,"A DEATH COSTS 5 / 10 / 15 MIN",0
        db PG_KEY,19,5," 1 ",0
        db PG_TEXT,19,9,$0F,"-",0
        db PG_KEY,19,11," 3 ",0
        db PG_TEXT,19,15,$0F,"CHOOSE AND BEGIN",0
        db PG_KEY,21,5," X ",0
        db PG_TEXT,21,9,$0F,"BACK TO THE TITLE",0
        db PG_END
save_page:
        db PG_PANEL,4,3,17,38,$0E
        db PG_HEAD,4,5,$0B,"SAVE GAME",0
        db PG_TEXT,7,5,$08,"AUTO",0
        db PG_KEY,9,5," 1 ",0
        db PG_KEY,11,5," 2 ",0
        db PG_KEY,13,5," 3 ",0
        db PG_SEP,15,5,36
        db PG_TEXT,16,5,$0F,"SAVES TO DISK A",0
        db PG_KEY,19,5," 1 ",0
        db PG_TEXT,19,9,$0F,"-",0
        db PG_KEY,19,11," 3 ",0
        db PG_TEXT,19,15,$0F,"SAVE INTO A SLOT",0
        db PG_KEY,21,5," X ",0
        db PG_TEXT,21,9,$0F,"BACK TO THE MISSION",0
        db PG_END
load_page:
        db PG_PANEL,4,3,17,38,$0E
        db PG_HEAD,4,5,$0A,"LOAD GAME",0
        db PG_KEY,7,5," 0 ",0
        db PG_KEY,9,5," 1 ",0
        db PG_KEY,11,5," 2 ",0
        db PG_KEY,13,5," 3 ",0
        db PG_SEP,15,5,36
        db PG_TEXT,16,5,$0F,"0 IS THE AUTOSAVE",0
        db PG_KEY,19,5," 0 ",0
        db PG_TEXT,19,9,$0F,"-",0
        db PG_KEY,19,11," 3 ",0
        db PG_TEXT,19,15,$0F,"PICK UP WHERE YOU LEFT",0
        db PG_KEY,21,5," X ",0
        db PG_TEXT,21,9,$0F,"BACK TO THE TITLE",0
        db PG_END
