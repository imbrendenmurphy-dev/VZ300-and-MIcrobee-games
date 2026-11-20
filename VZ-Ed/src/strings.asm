; ===========================================================================
;  strings.asm - messages and help text (run from the spare RAM below $A000)
; ===========================================================================

; (filling the RAM up to the page-aligned tables)
m_markon: db "MARK ON: ^J COPY ^Y CUT ^K OFF",0
m_trunc: db "FILE ENDED EARLY ON THE CARD",0
m_replq: db "REPLACE? Y/N  A=ALL  ^Q=STOP",0
s_listhdr: db "OPEN  RET=OPEN  CTRL+Q=BACK",0
m_saveerr: db "SAVE FAILED (SEE .BAK/.$$$)",0
m_full: db "MEMORY FULL",0
m_clipbig: db "BLOCK TOO BIG FOR CLIPBOARD",0
m_disp2: db "DISPLAY: GRAPHICS, 4X6 FONT",0
s_namechr: db "$%'-_@~`!(){}^#&",0
m_empty: db "(NO FILES HERE)",0

        include "tables.inc"

m_savechg: db "SAVE CHANGES? Y/N  ^Q=STAY",0
m_nomark: db "MARK A BLOCK FIRST WITH ^K",0
m_nofs: db "CARD FORMAT NOT SUPPORTED",0
s_helphdr: db "VZ-ED 0.2 HELP  ^Q=DONE",0
m_badname: db "BAD NAME - USE NAME.EXT",0
m_toobig: db "FILE TOO BIG FOR VZ-ED",0
m_cardfull: db "CARD FULL - NOT SAVED",0
m_replace: db "REPLACE FILE? Y/N",0
m_copied: db "COPIED",0

helptext:
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
        db "VZ-ED 0.2  VIBED BY BPM 2026",0
        db $FF

