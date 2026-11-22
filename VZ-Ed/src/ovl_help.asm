; ===========================================================================
;  ovl_help.asm - overlay slot 0: the help pages (CTRL+H).  Built by build.py
;  against the main program's symbols (mainsym.inc); runs at OVLA+2.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)
zh_go:  xor a
        ld (edmode),a
        ld hl,zh_text
        ld (hptr),hl
zh_pg:  call cls_scr
        xor a
        call set_rows
        ld hl,zh_hdr
        ld de,SCR
        call puts
        ld a,(docrows)
        ld b,a
        ld de,SCR+32
        ld hl,(hptr)
zh_ln:  ld a,(hl)
        cp $FF
        jr z,zh_end
        push de
        call puts
        pop de
        inc hl
        ex de,hl
        ld a,b
        ld bc,32
        add hl,bc
        ld b,a
        ex de,hl
        djnz zh_ln
zh_end: ld (hptr),hl
        call flush
        call waitkey
        cp K_QUIT
        jr z,zh_x
        ld hl,(hptr)
        ld a,(hl)
        cp $FF
        jr nz,zh_pg
zh_x:   ld a,1
        ld (waitrel),a
        xor a               ; NC, no key: the cursor stays
        ret

zh_hdr: db "VZ-ED 0.6 HELP  ^Q=DONE",0
zh_text:
        db "CTRL + KEY:",0
        db " M , . SPC  CURSOR",0
        db "   (LEFT RIGHT UP DOWN)",0
        db " R C   PAGE UP / DOWN",0
        db " T B   TOP / END OF FILE",0
        db " Z X   START / END OF LINE",0
        db " :     DELETE LEFT",0
        db " ;     DELETE RIGHT",0
        db " L     INSERT / OVERTYPE",0
        db " U     CAPS LOCK",0
        db " O     OPEN FILE",0
        db " S     SAVE",0
        db " A     SAVE AS",0
        db " N     NEW FILE",0
        db " D     DISPLAY STYLE",0
        db " H     HELP   Q  QUIT",0
        db " V     SHEET VIEW (WHOLE PAGE)",0
        db " I     MENUS (OR JOYSTICK FIRE)",0
        db "FILE MENU: SAVE AS PDF, PRINT",0
        db " ",0
        db "BASIC .VZ FILES OPEN AS TEXT:",0
        db " ONE LINE NUMBER A LINE. SAVE",0
        db " AS .VZ MAKES THE PROGRAM",0
        db " AGAIN (^S), .TXT KEEPS TEXT",0
        db "OTHER .VZ AND BIG FILES OPEN",0
        db " IN A HEX VIEW (READ ONLY)",0
        db " W     WORD WRAP ON / OFF",0
        db " K     MARK A BLOCK (AGAIN=OFF)",0
        db " J Y   COPY / CUT THE BLOCK",0
        db " P     PASTE",0
        db " : ;   (BLOCK MARKED) DELETE IT",0
        db " F G   FIND / FIND AGAIN",0
        db " E     REPLACE (CURSOR TO END)",0
        db "TYPING:",0
        db " LETTERS ARE LOWER CASE,",0
        db " SHIFT+LETTER = CAPITAL",0
        db " SHIFT: 1! 2",34," 3# 4$ 5% 6&",0
        db "   7' 8( 9) 0@ -= ;+ :* ,< .>",0
        db " CTRL+SHIFT: L? K/ O[ P]",0
        db "   I{ U} M\ N^ J| H~ -_ 7`",0
        db "JOYSTICK MOVES THE CURSOR",0
        db "SAVING KEEPS THE OLD FILE",0
        db "AS NAME.BAK",0
        db " ",0
        db "WRAP: Z X = START/END OF THE",0
        db " WHOLE LINE (PARAGRAPH)",0
        db "FIND IGNORES CAPITALS",0
        db " ",0
        db "SHEET VIEW: A DOT FOR EACH",0
        db " LETTER; THE YELLOW BOX IS",0
        db " THE SCREEN. MOVE IT WITH THE",0
        db " CURSOR KEYS, R C T B, THEN",0
        db " RETURN = GO THERE, Q = BACK",0
        db "HELP AND SHEET VIEW NEED",0
        db " VZED.OVL IN THE ROOT FOLDER",0
        db " ",0
        db "MENUS (^I): CURSOR KEYS PICK,",0
        db " RETURN DOES IT, A LETTER DOES",0
        db " ITS ^ KEY, ^Q OR ^I CLOSES",0
        db " ",0
        db "VZ-ED 0.6  VIBED BY BPM 2026",0
        db $FF
zh_last:
        assert zh_last <= OVLA+OVLSEC*512
