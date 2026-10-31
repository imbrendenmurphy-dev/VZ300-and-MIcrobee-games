; ===================================================================
;  DAWN PATROL 2  -  title, briefing, tally, game over, high scores
; ===================================================================

; A = background colour, CSS0
scr_begin:
        push af
        ld a,$08
        ld (latchv),a
        ld (LATCH),a
        pop af
        call colbyte
        jp cls

; centred print: DE = string, B = row
print_c:
        push de
        ld c,0
.len:   ld a,(de)
        or a
        jr z,.d
        inc de
        inc c
        jr .len
.d:     ld a,32
        sub c
        srl a
        ld c,a
        pop de
        call vaddr
        jp print

print_c2:
        push de
        ld c,0
.len:   ld a,(de)
        or a
        jr z,.d
        inc de
        inc c
        inc c
        jr .len
.d:     ld a,32
        sub c
        srl a
        ld c,a
        pop de
        call vaddr
        jp print2

; wait for field sync start (interrupts off)
wait_frame:
.a:     ld a,(LATCH)
        rla
        jr nc,.a
.b:     ld a,(LATCH)
        rla
        jr c,.b
        ret

key_p:  ld a,(KR_6)
        bit 4,a
        ret
key_fire:                       ; Z if SPACE / RETURN / joystick fire
        ld a,(KR_4)
        bit 4,a
        ret z
        ld a,(KR_6)
        bit 2,a
        ret z
        ld a,(joy_ok)
        or a
        jr z,.nj
        call read_joys
        cpl
        bit 4,a
        ret
.nj:    or 1
        ret

; ------------------------------------------------------------------
; TITLE
; ------------------------------------------------------------------
title_screen:
        di
        call wait_release
        ld a,2
        call scr_begin
        ld hl,TITLEPIC
        call unlz_far
        ld hl,$4000
        ld de,VRAM
        ld bc,40*32
        ldir
        ld hl,$4000
        ld de,BUF
        ld bc,40*32
        ldir
        call load_assets
        call title_text
        xor a
        ld (title_res),a
        ld (title_blink),a
        ld hl,0
        ld (title_t),hl
        ld hl,-24
        ld (title_hx),hl
        ld hl,scroll_text
        ld (scroll_p),hl
        ld hl,title_cb
        ld (mus_cb),hl
        ld hl,SONG_TITLE
        call mus_start
        ld a,(title_res)
        cp 2
        ret c
        call instructions
        jr title_screen

title_text:
        ld a,1
        ld c,2
        call set_txt
        ld de,str_press
        ld b,41
        call print_c
        call title_skill
        ld a,1
        ld c,2
        call set_txt
        ld b,53
        ld c,8
        call vaddr
        ld de,str_hi
        call print
        ld de,hs_scores
        ld b,3
        call print_bcd
        ret

title_skill:
        ld a,0
        ld c,2
        call set_txt
        ld b,47
        ld c,4
        call vaddr
        ld de,str_skill
        call print
        ld a,(difficulty)
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,SKILLS
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        jp print

str_press:  db "PRESS P TO PLAY",0
str_hi:     db "HI-SCORE ",0
str_skill:  db "I INFO   D SKILL ",0
SKILLS:     dw .e,.n,.h
.e:         db "EASY  ",0
.n:         db "NORMAL",0
.h:         db "HARD  ",0

title_cb:
        ld hl,(title_t)
        inc hl
        ld (title_t),hl
        ; keys
        call key_p
        jr nz,.np
        xor a
        jr .stop
.np:    call key_fire
        jr nz,.nf
        xor a
        jr .stop
.nf:
    if DEBUG
        ld a,(KR_3)
        bit 4,a                 ; 1
        jr nz,.d1
        xor a
        ld (dbg_lvl),a
.d1:    ld a,(KR_3)
        bit 1,a                 ; 2
        jr nz,.d2
        ld a,1
        ld (dbg_lvl),a
.d2:    ld a,(KR_3)
        bit 3,a                 ; 3
        jr nz,.d3
        ld a,2
        ld (dbg_lvl),a
.d3:    ld a,(KR_3)
        bit 5,a                 ; 4
        jr nz,.d4
        ld a,3
        ld (dbg_lvl),a
.d4:
    endif
        ld a,(KR_6)
        bit 3,a                 ; I
        jr nz,.ni
        ld a,2
        jr .stop
.ni:    ld a,(KR_1)
        bit 3,a                 ; D
        jr nz,.nd
        ld a,(title_dkey)
        or a
        jr nz,.dk
        ld a,1
        ld (title_dkey),a
        ld a,(difficulty)
        inc a
        cp 3
        jr c,.dd
        xor a
.dd:    ld (difficulty),a
        call title_skill
        jr .dk
.nd:    xor a
        ld (title_dkey),a
.dk:    ; timeout -> attract mode
        ld hl,(title_t)
        ld de,3400
        or a
        sbc hl,de
        jr c,.anim
        ld a,1
.stop:  ld (title_res),a
        ld a,1
        ld (mus_stop),a
        ret
.anim:  ld a,(title_t)
        and 1
        call z,title_heli
        ld a,(title_t)
        ld b,9
        call mod_b
        call z,title_scroll
        ld a,(title_t)
        and 31
        ret nz
        ld a,(title_blink)
        xor 1
        ld (title_blink),a
        ld a,1
        jr z,.bl
        ld a,2
.bl:    ld c,2
        call set_txt
        ld de,str_press
        ld b,41
        jp print_c

title_res   db 0
dbg_lvl     db 0
title_blink db 0
title_dkey  db 0
title_t     dw 0
title_hx    dw 0
scroll_p    dw 0

title_scroll:
        ld hl,VRAM+58*32+1
        ld de,VRAM+58*32
        ld a,5
.r:     ld bc,31
        ldir
        inc hl
        inc de
        dec a
        jr nz,.r
        ld a,1
        ld c,3
        call set_txt
        ld hl,(scroll_p)
        ld a,(hl)
        or a
        jr nz,.ok
        ld hl,scroll_text
        ld a,(hl)
.ok:    inc hl
        ld (scroll_p),hl
        ld hl,VRAM+58*32+31
        jp putc

; helicopter flying across the title picture (drawn straight into VRAM)
title_heli:
        ld hl,(title_hx)
        call th_col
        jr c,.nr
        ld e,a
        ld d,0
        ld hl,25*32
        add hl,de
        ld b,12
.rr:    push bc
        push hl
        ld bc,BUF
        add hl,bc
        pop de
        push de
        ex de,hl
        ld bc,VRAM
        add hl,bc
        ex de,hl
        ld bc,6
        ldir
        pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .rr
.nr:    ld hl,(title_hx)
        inc hl
        ld a,h
        or a
        jr nz,.mv
        ld a,l
        cp 190
        jr c,.mv
        ld hl,-24
.mv:    ld (title_hx),hl
        call th_col
        ret c
        ld a,1
        ld (spr_vram),a
        ld hl,(title_hx)
        ld (spr_x),hl
        ld a,(title_t)
        rrca
        rrca
        rrca
        rrca
        and 1
        add a,27
        ld (spr_y),a
        ld (tmp+7),a
        ld a,SPR_HELI_R2
        call draw_spr
        xor a
        ld (spr_vram),a
        ld a,(title_t)
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,ROTLEN
        add hl,de
        ld b,(hl)
        ld a,b
        srl a
        ld c,a
        ld hl,(title_hx)
        ld de,8
        add hl,de
        ld e,c
        ld d,0
        or a
        sbc hl,de
        ld a,(tmp+7)
        dec a
        ld e,a
.rot:   push bc
        push hl
        push de
        ld a,h
        or a
        jr nz,.rs
        ld a,l
        cp 128
        jr nc,.rs
        ld c,l
        ld d,1
        call vplot
.rs:    pop de
        pop hl
        pop bc
        inc hl
        djnz .rot
        ret

th_col: ; HL = x -> A = first byte column, carry if fully off screen
        ld de,20
        add hl,de
        bit 7,h
        scf
        ret nz
        ld de,-20
        add hl,de
        bit 7,h
        jr z,.pos
        xor a
        ret
.pos:   ld a,h
        or a
        scf
        ret nz
        ld a,l
        cp 128
        ccf
        ret c
        srl a
        srl a
        cp 26
        jr c,.ok
        ld a,26
.ok:    or a
        ret

; ------------------------------------------------------------------
; INSTRUCTIONS (two pages, briefing music)
; ------------------------------------------------------------------
instructions:
        ld de,INSTR1
        call instr_page
        ld de,INSTR2
        jp instr_page

instr_page:
        push de
        call load_assets
        call wait_release
        ld a,2
        call scr_begin
        ld a,1
        ld c,2
        call set_txt
        pop de
        ld b,1
.l:     ld a,(de)
        or a
        jr z,.go
        push bc
        ld c,0
        push de
        call vaddr
        pop de
        call print
        inc de
        pop bc
        ld a,b
        add a,6
        ld b,a
        ld a,0
        ld c,2
        push bc
        push de
        call set_txt
        pop de
        pop bc
        jr .l
.go:    ld hl,0
        ld (title_t),hl
        ld hl,wait_cb
        ld (mus_cb),hl
        ld hl,SONG_BRIEF
        jp mus_start

; music callback: stop on key after a short delay, or after (wait_max) ticks
wait_cb:
        ld hl,(title_t)
        inc hl
        ld (title_t),hl
        ld de,(wait_max)
        or a
        sbc hl,de
        jr nc,.stop
        ld hl,(title_t)
        ld a,h
        or a
        jr nz,.k
        ld a,l
        cp 60
        ret c
.k:     call any_key
        ret z
.stop:  ld a,1
        ld (mus_stop),a
        ret
wait_max dw 2800

; ------------------------------------------------------------------
; MISSION BRIEFING
; ------------------------------------------------------------------
level_intro:
        di
        call wait_release
        ld a,(level)
        ld l,a
        ld h,0
        ld de,LV_SIZE
        call mul_hl_de
        ld de,LVTAB
        add hl,de
        push hl
        pop ix
        ld a,(ix+LV_CSS)
        rlca
        rlca
        rlca
        rlca
        or $08
        ld (latchv),a
        ld (LATCH),a
        ld a,(ix+LV_SKY)
        push af
        call colbyte
        call cls
        pop af
        ld c,a
        push bc
        ld a,3
        call set_txt
        ld de,str_mission
        ld b,4
        ld c,6
        call vaddr
        call print2
        ld a,(mission)
        call print2_dec
        pop bc
        push bc
        ld a,(ix+LV_HUDFG)
        call set_txt
        ld l,(ix+LV_OP)
        ld h,(ix+LV_OP+1)
        ex de,hl
        ld b,20
        call print_c
        ld l,(ix+LV_NAME)
        ld h,(ix+LV_NAME+1)
        ex de,hl
        ld b,28
        call print_c
        ; prisoners and quota
        ld a,(ix+LV_CAMPS)
        add a,(ix+LV_CAMPS+1)
        add a,(ix+LV_CAMPS+2)
        add a,(ix+LV_CAMPS+3)
        ld (tmp),a
        ld b,38
        ld c,5
        call vaddr
        ld de,str_pris
        call print
        ld a,(tmp)
        call print_dec2
        pop bc
        push bc
        ld a,3
        call set_txt
        ld de,str_ready
        ld b,52
        call print_c
        pop bc
        ld a,(ix+LV_HUDFG)
        call set_txt
        ld de,str_home
        ld b,44
        call print_c
        ld hl,0
        ld (title_t),hl
        ld hl,320
        ld (wait_max),hl
        ld hl,wait_cb
        ld (mus_cb),hl
        ld hl,SONG_BRIEF
        call mus_start
        ld hl,2800
        ld (wait_max),hl
        ret

; double-size number A (1..99)
print2_dec:
        ld c,'0'-1
.t:     inc c
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,c
        cp '0'
        call nz,putc2
        pop af
        jp putc2

str_mission: db "MISSION ",0
str_pris:    db "PRISONERS TO RESCUE ",0
str_ready:   db "GET READY!",0
str_home:    db "HOME BY 6:00 AM",0

; ------------------------------------------------------------------
; MISSION COMPLETE tally
; ------------------------------------------------------------------
tally_screen:
        di
        ld a,2
        call scr_begin
        ld a,1
        ld c,2
        call set_txt
        ld de,str_mission
        ld b,2
        call print_c2
        ld de,str_complete
        ld b,13
        call print_c2
        ld a,0
        ld c,2
        call set_txt
        ; rescued
        ld b,27
        ld c,4
        call vaddr
        ld de,str_rescued
        call print
        ld a,(rescued)
        call print_dec2
        ld a,'/'
        call putc
        ld a,(total_pris)
        call print_dec2
        ; time bonus = minutes left * 25
        ld a,(clock_min)
        ld b,a
        ld a,120
        sub b
        ld l,a
        ld h,0
        ld de,25
        call mul_hl_de
        push hl
        ld b,34
        ld c,4
        call vaddr
        ld de,str_tbonus
        call print
        pop hl
        call show_add_bonus
        ; fuel bonus = fuel / 4
        ld hl,(fuel)
        srl h
        rr l
        srl h
        rr l
        push hl
        ld b,41
        ld c,4
        call vaddr
        ld de,str_fbonus
        call print
        pop hl
        call show_add_bonus
        ; perfect?
        ld a,(lost)
        or a
        jr nz,.np
        ld a,(rescued)
        ld b,a
        ld a,(total_pris)
        cp b
        jr nz,.np
        ld a,3
        ld c,2
        call set_txt
        ld b,48
        ld c,4
        call vaddr
        ld de,str_perfect
        call print
        ld hl,$5000
        call add_score
.np:    ld a,1
        ld c,2
        call set_txt
        ld b,56
        ld c,8
        call vaddr
        ld de,str_score
        call print
        ld de,score
        ld b,3
        call print_bcd
        ld hl,0
        ld (title_t),hl
        ld hl,wait_cb
        ld (mus_cb),hl
        ld hl,SONG_FANFARE
        call mus_start
        ld hl,0
        ld (title_t),hl
        ld hl,500
        ld (wait_max),hl
        ld hl,SONG_BRIEF
        call mus_start
        ld hl,2800
        ld (wait_max),hl
        ret

; HL = binary bonus -> print 4 digits at current HL... (prints at vram addr in stack)
show_add_bonus:
        push hl
        call bin2bcd            ; de = bcd
        pop hl
        ex de,hl
        push hl
        call add_score
        pop hl
        ld (tmp),hl
        ; print at the position after the label: find via last print position
        ld a,h
        ld (tmp+2),a
        ld a,l
        ld (tmp+3),a
        ld hl,(print_end)
        ld de,tmp+2
        ld b,2
        jp print_bcd

; HL (0..9999) -> DE BCD
bin2bcd:
        ld de,0
        ld bc,-1000
        call .dig
        ld d,a
        sla d
        sla d
        sla d
        sla d
        ld bc,-100
        call .dig
        or d
        ld d,a
        ld bc,-10
        call .dig
        rlca
        rlca
        rlca
        rlca
        ld e,a
        ld a,l
        or e
        ld e,a
        ret
.dig:   xor a
.l:     add hl,bc
        inc a
        jr c,.l
        sbc hl,bc
        dec a
        ret

str_complete: db "COMPLETE",0
str_rescued:  db "RESCUED      ",0
str_tbonus:   db "TIME BONUS   ",0
str_fbonus:   db "FUEL BONUS   ",0
str_perfect:  db "PERFECT!    5000",0
str_score:    db "SCORE ",0

; ------------------------------------------------------------------
; GAME OVER
; ------------------------------------------------------------------
gameover_screen:
        di
        call wait_release
        ld a,$08
        ld (latchv),a
        ld (LATCH),a
        ld hl,GOPIC
        call unlz_far
        ld hl,$4000
        ld de,VRAM
        ld bc,40*32
        ldir
        ld hl,$4000
        ld de,BUF
        ld bc,40*32
        ldir
        ld a,3
        call colbyte
        ld b,40
        ld c,24
        call vfill
        ; reset the show
        ld hl,go_vars
        ld de,go_vars+1
        ld bc,go_vars_end-go_vars-1
        ld (hl),0
        ldir
        ld b,9
        ld hl,go_y
.iy:    ld (hl),-12
        inc hl
        djnz .iy
        ld b,8
        ld hl,go_smoke
.is:    call rand
        and 15
        ld (hl),a               ; staggered lives
        inc hl
        inc hl
        inc hl
        djnz .is
        ld a,1
        ld (go_col),a
        ld hl,go_cb
        ld (mus_cb),hl
        ld hl,SONG_OVER
        call mus_start
.w:     ld a,(go_quit)
        or a
        ret nz
        call wait_frame
        call go_cb
        jr .w

GO_COL  equ 7                   ; first byte column of the big letters
GO_ROW  equ 4                   ; where they land
go_text: db "GAME OVER"

go_cb:
        ld hl,(go_t)
        inc hl
        ld (go_t),hl
        ; leave on a key once the show has played, or after a while
        ld de,1500
        or a
        sbc hl,de
        jr nc,.quit
        ld hl,(go_t)
        ld a,h
        or a
        jr nz,.k
        ld a,l
        cp 200
        jr c,.anim
.k:     call any_key
        jr z,.anim
.quit:  ld a,1
        ld (go_quit),a
        ld (mus_stop),a
        ret
.anim:  ld a,(go_t)
        and 1
        call z,go_letters
        ld a,(go_t)
        ld b,3
        call mod_b
        call z,go_embers
        ld a,(go_t)
        and 3
        call z,go_typer
        ld a,(go_t)
        and 31
        call z,go_pulse
        ret

; ---- big letters drop in one by one and bounce
go_letters:
        ld c,0
.l:     push bc
        ld b,0
        ld hl,go_st
        add hl,bc
        ld a,(hl)
        cp 2
        jr z,.n                 ; landed
        or a
        jr nz,.fall
        ; waiting: start letter c at t >= 30 + 8c
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,30
        ld d,a
        ld a,(go_t+1)
        or a
        jr nz,.go
        ld a,(go_t)
        cp d
        jr c,.n
.go:    ld (hl),1
        ld hl,go_text
        add hl,bc
        ld a,(hl)
        cp ' '
        jr nz,.n
        ld hl,go_st
        add hl,bc
        ld (hl),2               ; the space just "lands"
        jr .n
.fall:  ; erase at old position, move, bounce, redraw
        call go_erase
        ld hl,go_v
        add hl,bc
        inc (hl)                ; gravity
        ld a,(hl)
        ld hl,go_y
        add hl,bc
        add a,(hl)
        cp GO_ROW
        jp m,.st
        jr c,.st
        ; hit the ground
        ld (hl),GO_ROW
        ld hl,go_v
        add hl,bc
        ld a,(hl)
        cp 3
        jr c,.land
        srl a
        neg
        ld (hl),a               ; bounce back up at half speed
        jr .draw
.land:  ld hl,go_st
        add hl,bc
        ld (hl),2
        ld hl,go_landed
        inc (hl)
        jr .draw
.st:    ld (hl),a
.draw:  call go_draw
.n:     pop bc
        inc c
        ld a,c
        cp 9
        jp c,.l
        ret

; restore letter C's column from the clean picture
go_erase:
        push bc
        ld hl,go_y
        add hl,bc
        ld a,(hl)
        ld e,10
        bit 7,a
        jr z,.p
        add a,10
        jr z,.out
        jp m,.out
        ld e,a
        xor a
.p:     ld d,a                  ; first row
        ld a,e
        ld (go_cnt),a
        ld a,c
        add a,a
        add a,GO_COL
        ld c,a
        ld b,d
        call vaddr              ; hl = vram
        push hl
        ld bc,VRAM
        or a
        sbc hl,bc
        ld bc,BUF
        add hl,bc               ; matching clean byte
        pop de
        ex de,hl                ; hl = vram, de = clean
        ld a,(go_cnt)
        ld b,a
.r:     ld a,(de)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        ld (hl),a
        push bc
        ld bc,31
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
.out:   pop bc
        ret

; draw letter C at its row (only once fully on screen)
go_draw:
        push bc
        ld hl,go_y
        add hl,bc
        ld a,(hl)
        bit 7,a
        jr nz,.x
        ld b,a
        ld a,c
        add a,a
        add a,GO_COL
        ld c,a
        call vaddr
        push hl
        ld a,(go_col)
        ld c,2
        call set_txt
        pop hl
        pop bc
        push bc
        ld b,0
        push hl
        ld hl,go_text
        add hl,bc
        ld a,(hl)
        pop hl
        call putc2
.x:     pop bc
        ret

; once all are down, the letters flash yellow / red in time
go_pulse:
        ld a,(go_landed)
        cp 8
        ret c
        ld a,(go_col)
        xor 2                   ; 1 <-> 3
        ld (go_col),a
        ld bc,0
.l:     ld a,c
        cp 4
        jr z,.n
        call go_draw
.n:     inc c
        ld a,c
        cp 9
        jr c,.l
        ret

; ---- embers and flames rising from the wreck
go_embers:
        ld hl,go_smoke
        ld b,8
.l:     push bc
        push hl
        ld a,(hl)               ; life
        or a
        jr z,.spawn
        ; erase old pixel (restore the byte)
        inc hl
        ld c,(hl)               ; x
        inc hl
        ld e,(hl)               ; row
        call go_restore
        pop hl
        push hl
        dec (hl)
        jr z,.n
        inc hl
        call rand
        and 3
        jr nz,.nd
        call rand
        and 2
        dec a
        add a,(hl)
        ld (hl),a               ; drift
.nd:    ld c,(hl)
        inc hl
        dec (hl)                ; rise
        ld e,(hl)
        pop hl
        push hl
        ld a,(hl)
        cp 9
        ld d,1                  ; young: bright flame
        jr nc,.c
        ld d,3                  ; older: glowing ember
.c:     ld a,e
        cp 40
        jr nc,.kill
        cp 3
        jr c,.kill
        call vplot
        jr .n
.kill:  pop hl
        push hl
        ld (hl),0               ; burnt out: respawn next time
.spawn: call rand
        and 15
        add a,14
        ld (hl),a
        inc hl
        call rand
        and 7
        add a,38
        ld (hl),a
        inc hl
        ld (hl),34
.n:     pop hl
        inc hl
        inc hl
        inc hl
        pop bc
        djnz .l
        ; flickering fire on the wreck
        ld b,4
.f:     push bc
        call rand
        and 7
        add a,39
        ld c,a
        call rand
        and 1
        add a,33
        ld e,a
        call rand
        and 2
        inc a
        ld d,a
        call vplot
        pop bc
        djnz .f
        ret

go_restore:                     ; C = x, E = row: copy the clean byte back
        ld a,e
        cp 40
        ret nc
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        srl a
        srl a
        add a,l
        ld l,a
        push hl
        ld de,BUF
        add hl,de
        ld a,(hl)
        pop hl
        ld de,VRAM
        add hl,de
        ld (hl),a
        ret

; ---- typewriter text, then slot-machine score
go_typer:
        ld a,(go_landed)
        cp 8
        ret c
        ld a,(go_phase)
        or a
        jr z,.reason
        dec a
        jp z,.slots
        ret
.reason:
        ld a,1
        ld c,3
        call set_txt
        call go_reason_ptr
        ld a,(go_n)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr nz,.ch
        ld a,1
        ld (go_phase),a
        xor a
        ld (go_n),a
        ret
.ch:    push af
        ; centre the line
        call go_reason_ptr
        ld c,0
.ln:    ld a,(hl)
        or a
        jr z,.lq
        inc hl
        inc c
        jr .ln
.lq:    ld a,32
        sub c
        srl a
        ld c,a
        ld a,(go_n)
        add a,c
        ld c,a
        ld b,44
        call vaddr
        pop af
        call putc
        ld hl,go_n
        inc (hl)
        ret
.slots: ; SCORE ###### with each digit spinning until it locks, left to right
        ld a,0
        ld c,3
        call set_txt
        ld a,(go_n)
        or a
        jr nz,.sp
        ld b,53
        ld c,7
        call vaddr
        ld de,str_score
        call print
.sp:    ld hl,go_n
        inc (hl)
        ld a,(hl)
        cp 60
        jr c,.dg
        ld a,2
        ld (go_phase),a
.dg:    ld b,53
        ld c,13
        call vaddr
        ld c,0                  ; digit index 0..5
.d:     push bc
        push hl
        ld a,(go_n)
        ld b,a
        ld a,c
        inc a
        add a,a
        add a,a
        add a,a                 ; locks at go_n = 8*(i+1)
        cp b
        jr c,.real
        call rand
        and 7
        add a,'1'
        jr .put
.real:  ld a,c
        srl a
        ld e,a
        ld d,0
        ld hl,score
        add hl,de
        ld a,(hl)
        bit 0,c
        jr nz,.lo
        rrca
        rrca
        rrca
        rrca
.lo:    and 15
        add a,'0'
.put:   pop hl
        push hl
        call putc
        pop hl
        inc hl
        pop bc
        inc c
        ld a,c
        cp 6
        jr c,.d
        ret

go_reason_ptr:
        ld a,(end_reason)
        cp 3
        ld hl,str_r3
        ret z
        cp 2
        ld hl,str_r2
        ret z
        ld hl,str_r1
        ret

go_vars:
go_t     dw 0
go_quit  db 0
go_st    ds 9
go_v     ds 9
go_landed db 0
go_phase db 0
go_n     db 0
go_smoke ds 8*3                 ; life, x, row
go_vars_end:
go_y     ds 9
go_col   db 1
go_cnt   db 0

str_game:   db "GAME",0
str_over:   db "OVER",0
str_r3:     db "ALL HELICOPTERS DESTROYED",0
str_r2:     db "6:00 AM - TIME UP",0
str_r1:     db "NO PRISONERS LEFT TO RESCUE",0

; ------------------------------------------------------------------
; HIGH SCORES
; ------------------------------------------------------------------
hs_init:
        ld hl,HS_DEF
        ld de,hs_names
        ld bc,30
        ldir
        ret
HS_DEF: db "BPM","VZ3","DSE","Z80","CPU"
        db $02,$50,$00, $02,$00,$00, $01,$50,$00, $01,$00,$00, $00,$50,$00

hs_check:
        ld b,0
        ld hl,hs_scores
.f:     push hl
        ld de,score
        ld c,3
.c:     ld a,(de)
        cp (hl)
        jr c,.lower
        jr nz,.higher
        inc hl
        inc de
        dec c
        jr nz,.c
.lower: pop hl
        inc hl
        inc hl
        inc hl
        inc b
        ld a,b
        cp 5
        jr c,.f
        ret
.higher:
        pop hl
        ld a,b
        ld (newhs_rank),a
        ld a,4
        sub b
        jr z,.ins
        ld c,a
        add a,a
        add a,c
        ld c,a
        ld b,0
        push bc
        ld hl,hs_names+11
        ld de,hs_names+14
        lddr
        pop bc
        ld hl,hs_scores+11
        ld de,hs_scores+14
        lddr
.ins:   ld a,(newhs_rank)
        call hs_score_ptrs      ; de = name, (hs_sp) = score
        ld (hs_namep),de
        ld hl,score
        ld de,(hs_sp)
        ld bc,3
        ldir
        ld hl,(hs_namep)
        ld (hl),'A'
        inc hl
        ld (hl),'.'
        inc hl
        ld (hl),'.'
        call name_entry
        jp hs_screen

hs_namep dw 0

name_entry:
        call wait_release
        ld a,2
        call scr_begin
        ld a,1
        ld c,2
        call set_txt
        ld de,str_great
        ld b,6
        call print_c
        ld de,str_enter
        ld b,14
        call print_c
        ld a,0
        ld c,2
        call set_txt
        ld de,str_keys
        ld b,52
        call print_c
        xor a
        ld (entry_pos),a
.draw:  ld a,3
        ld c,2
        call set_txt
        ld b,28
        ld c,13
        call vaddr
        ld de,(hs_namep)
        ld b,3
.dn:    ld a,(de)
        inc de
        push bc
        push de
        call putc2
        pop de
        pop bc
        djnz .dn
        ; cursor under current letter
        ld a,2
        call colbyte
        ld b,40
        ld c,1
        call vfill
        ld a,(entry_pos)
        add a,a
        add a,13
        ld c,a
        ld b,40
        call vaddr
        ld a,1
        call colbyte
        ld (hl),a
        inc hl
        ld (hl),a
        ld b,8
.wt:    call wait_frame
        djnz .wt
.key:   call wait_frame
        ld hl,(hs_namep)
        ld a,(entry_pos)
        ld e,a
        ld d,0
        add hl,de
        call read_input
        ld a,(in_cur)
        bit IN_UP,a
        jr z,.nu
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,.s1
        ld a,'.'
        jr .s
.s1:    cp '.'+1
        jr nz,.s
        ld a,'A'
.s:     ld (hl),a
        jr .draw
.nu:    bit IN_DOWN,a
        jr z,.nd
        ld a,(hl)
        dec a
        cp '.'-1
        jr nz,.s2
        ld a,'Z'
        jr .s
.s2:    cp 'A'-1
        jr nz,.s
        ld a,'.'
        jr .s
.nd:    call key_fire
        jr nz,.key
        ld a,(entry_pos)
        inc a
        ld (entry_pos),a
        cp 3
        jr nc,.done
        ld hl,(hs_namep)
        ld e,a
        ld d,0
        add hl,de
        ld (hl),'A'
        call wait_release
        jp .draw
.done:  call wait_release
        ret

str_great: db "A NEW HIGH SCORE!",0
str_enter: db "ENTER YOUR INITIALS",0
str_keys:  db "Q/A CHANGE  SPACE ACCEPT",0

hs_screen:
        di
        call wait_release
        ld a,2
        call scr_begin
        ld a,3
        ld c,2
        call set_txt
        ld de,str_top
        ld b,3
        call print_c2
        xor a
        ld (hs_i),a
.l:     ld a,(hs_i)
        or a
        ld a,1
        jr z,.c0
        xor a
.c0:    ld c,2
        call set_txt
        ld a,(hs_i)
        ld b,a
        add a,a
        add a,b
        add a,a                 ; *6
        add a,18
        ld b,a
        ld c,7
        call vaddr
        ld a,(hs_i)
        add a,'1'
        call putc
        inc hl
        inc hl
        ld a,(hs_i)
        call hs_score_ptrs
        ld b,3
.n:     ld a,(de)
        inc de
        push bc
        push de
        call putc
        pop de
        pop bc
        djnz .n
        inc hl
        inc hl
        inc hl
        ld de,(hs_sp)
        ld b,3
        call print_bcd
        ld hl,hs_i
        inc (hl)
        ld a,(hl)
        cp 5
        jr c,.l
        ld hl,0
        ld (title_t),hl
        ld hl,700
        ld (wait_max),hl
        ld hl,wait_cb
        ld (mus_cb),hl
        ld hl,SONG_BRIEF
        call mus_start
        ld hl,2800
        ld (wait_max),hl
        ret
hs_sp   dw 0
hs_i    db 0
hs_score_ptrs:  ; A = index -> DE = name ptr, (hs_sp) = score ptr
        push hl
        ld l,a
        add a,a
        add a,l
        ld e,a
        ld d,0
        ld hl,hs_scores
        add hl,de
        ld (hs_sp),hl
        ld hl,hs_names
        add hl,de
        ex de,hl
        pop hl
        ret
str_top: db "TOP PILOTS",0

; ------------------------------------------------------------------
; ATTRACT DEMO
; ------------------------------------------------------------------
demo_run:
        ld a,1
        ld (demo),a
        ld a,(demo_lvl)
        ld (level),a
        inc a
        and 3
        ld (demo_lvl),a
        ld hl,800
        ld (demo_t),hl
        ld a,1
        ld (mission),a
        call level_load
        ld a,4
        ld (lives),a
        call game_run
        xor a
        ld (demo),a
        ld hl,(demo_t)
        ld a,h
        or l
        ret
demo_lvl db 0
