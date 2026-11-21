; ===========================================================================
;  ovl_menu.asm - overlay slot 2: the menu bar (CTRL+I, or joystick fire in
;  the editor).  Built by build.py against mainsym.inc; runs at OVLA+2.
;
;  The title row becomes FILE EDIT FIND VIEW HELP; the open menu drops down
;  over the text.  Cursor keys (CTRL or plain M , . SPACE) move, RETURN or
;  fire picks, a letter picks the item with that CTRL key (from any menu),
;  CTRL+Q or CTRL+I closes.  Returns NC with A = the key code of the item,
;  which ovl_run passes to dispatch exactly as if the CTRL key was pressed
;  (A = 0: closed).  The last menu used is remembered in menusel.
;  The rows are made plain while the menu is up, so it looks the same in
;  every display style: the bar is the title bar with the open menu cut out,
;  the drop-down is inverse with the chosen item cut out.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)

zm_go:  ld a,1
        ld (waitrel),a      ; CTRL+I is still held
        ld hl,SCR           ; what is under the menus
        ld de,zBK
        ld bc,512
        ldir
        ld hl,(curcell)     ; (without the cursor)
        ld a,h
        cp $FF
        jr z,zm_0
        ld de,zBK
        add hl,de
        res 7,(hl)
zm_0:   xor a
        call set_rows
        ld hl,$FFFF         ; no cursor while the menu is up
        ld (curcell),hl
        call invalidate
        ld a,(menusel)
        cp 5
        jr c,zm_1
        xor a
        ld (menusel),a
zm_1:   xor a
        ld (zI),a
zm_drw: call zm_draw
        call flush
zm_key: call waitkey
        cp K_LEFT
        jr z,zm_lt
        cp 'm'
        jr z,zm_lt
        cp 'M'
        jr z,zm_lt
        cp K_RIGHT
        jr z,zm_rt
        cp ','
        jr z,zm_rt
        cp K_UP
        jr z,zm_up
        cp '.'
        jr z,zm_up
        cp K_DOWN
        jr z,zm_dn
        cp ' '
        jr z,zm_dn
        cp K_RET
        jr z,zm_pick
        cp K_FIRE
        jr z,zm_pick
        cp K_QUIT
        jr z,zm_cls
        cp K_MENU
        jr z,zm_cls
        and $DF             ; a letter: the item with that CTRL key
        cp 'A'
        jr c,zm_key
        cp 'Z'+1
        jr nc,zm_key
        call zm_hot
        or a
        jr z,zm_key
        jr zm_ret

zm_lt:  ld a,(menusel)
        add a,4
        jr zm_m
zm_rt:  ld a,(menusel)
        inc a
zm_m:   cp 5
        jr c,zm_m1
        sub 5
zm_m1:  ld (menusel),a
        xor a
        ld (zI),a
        jr zm_drw
zm_up:  call zm_list
        ld a,(zI)
        or a
        jr nz,zm_u1
        ld a,(hl)
zm_u1:  dec a
        ld (zI),a
        jr zm_drw
zm_dn:  call zm_list
        ld a,(zI)
        inc a
        cp (hl)
        jr c,zm_d1
        xor a
zm_d1:  ld (zI),a
        jp zm_drw

zm_pick: call zm_list       ; the code of item zI
        inc hl
        ld a,(zI)
        ld b,a
        or a
        jr z,zm_p1
        ld de,14
zm_p0:  add hl,de
        djnz zm_p0
zm_p1:  ld a,(hl)
        jr zm_ret
zm_cls: xor a
zm_ret: push af
        ld hl,zBK           ; the text back as it was (render redraws it all)
        ld de,SCR
        ld bc,512
        ldir
        call invalidate
        pop af
        or a                ; NC, A = the key (or 0)
        ret

; HL = the open menu's list (count, then 14-byte items), zX = its column
zm_list: ld a,(menusel)
        ld l,a
        ld h,0
        ld de,zm_x
        add hl,de
        ld a,(hl)
        ld (zX),a
        ld a,(menusel)
        add a,a
        ld l,a
        ld h,0
        ld de,zm_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; A = a capital letter -> A = the code of the item whose CTRL key it is, or 0
zm_hot: ld c,a
        ld hl,zm_tab
        ld b,5
zh_m:   push bc
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld b,(hl)
        inc hl
zh_i:   push hl
        ld de,13
        add hl,de
        ld a,(hl)
        pop hl
        cp c
        jr z,zh_f
        ld de,14
        add hl,de
        djnz zh_i
        pop hl
        inc hl
        inc hl
        pop bc
        djnz zh_m
        xor a
        ret
zh_f:   ld a,(hl)
        pop hl
        pop bc
        ret

zm_draw: ld hl,zBK          ; the text, the bar, the open menu
        ld de,SCR
        ld bc,512
        ldir
        ld hl,zm_bar
        ld de,SCR
        ld bc,32
        ldir
        ld a,(menusel)      ; its name cut out of the bar
        ld b,a
        add a,a
        add a,b
        add a,a
        ld l,a
        ld h,0
        ld de,SCR
        add hl,de
        ld b,6
zd_h:   set 7,(hl)
        inc hl
        djnz zd_h
        call zm_list
        ld a,(zX)
        ld e,a
        ld d,0
        push hl
        ld hl,SCR+32
        add hl,de
        ex de,hl            ; DE = top left of the drop-down
        pop hl
        ld b,(hl)
        inc hl
        ld c,0
zd_r:   ld a,(zI)           ; inverse, the chosen item plain
        cp c
        ld a,$80
        jr nz,zd_f
        xor a
zd_f:   ld (zF),a
        inc hl              ; (the code)
        ld a,' '
        call zd_put
        push bc
        ld b,13
zd_c:   ld a,(hl)
        inc hl
        call zd_put
        djnz zd_c
        pop bc
        ld a,' '
        call zd_put
        push hl
        ld hl,32-15
        add hl,de
        ex de,hl
        pop hl
        inc c
        djnz zd_r
        ret
zd_put: push bc
        ld b,a
        ld a,(zF)
        or b
        ld (de),a
        inc de
        pop bc
        ret

zm_bar: db " FILE  EDIT  FIND  VIEW  HELP   "
zm_x:   db 0,6,12,17,17
zm_tab: dw zm_l0,zm_l1,zm_l2,zm_l3,zm_l4
zm_l0:  db 5
        db K_NEW,"NEW        ^N"
        db K_OPEN,"OPEN       ^O"
        db K_SAVE,"SAVE       ^S"
        db K_SAVEAS,"SAVE AS    ^A"
        db K_QUIT,"QUIT       ^Q"
zm_l1:  db 6
        db K_MARK,"MARK BLOCK ^K"
        db K_COPY,"COPY       ^J"
        db K_CUT,"CUT        ^Y"
        db K_PASTE,"PASTE      ^P"
        db K_INS,"INS / OVR  ^L"
        db K_CAPS,"CAPS LOCK  ^U"
zm_l2:  db 5
        db K_FIND,"FIND       ^F"
        db K_NEXT,"FIND AGAIN ^G"
        db K_REPL,"REPLACE    ^E"
        db K_TOP,"GO TO TOP  ^T"
        db K_BOT,"GO TO END  ^B"
zm_l3:  db 3
        db K_DISP,"DISPLAY    ^D"
        db K_WRAP,"WORD WRAP  ^W"
        db K_SHEET,"SHEET VIEW ^V"
zm_l4:  db 1
        db K_HELP,"KEYS       ^H"

zm_end:
        assert zm_end <= OVLA+OVLSEC*512
zI      equ zm_end          ; the chosen item
zX      equ zI+1            ; column of the open menu
zF      equ zX+1            ; $80 or 0 while drawing a row
zBK     equ zF+1            ; 512: the screen under the menus
zm_wend equ zBK+512
        assert zm_wend <= OVLEND
