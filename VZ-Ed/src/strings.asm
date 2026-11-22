; ===========================================================================
;  strings.asm - messages and help text (run from the spare RAM below $A000)
; ===========================================================================

; (filling the RAM up to the page-aligned tables)
m_markon: db "MARK ON: ^J COPY ^Y CUT ^K OFF",0
m_trunc: db "FILE ENDED EARLY ON THE CARD",0
s_listhdr: db "OPEN  RET=OPEN  CTRL+Q=BACK",0
m_saveerr: db "SAVE FAILED (SEE .BAK/.$$$)",0
m_full: db "MEMORY FULL",0

        include "tables.inc"
m_disp2: db "DISPLAY: GRAPHICS, 4X6 FONT",0
s_namechr: db "$%'-_@~`!(){}^#&.",0
m_empty: db "(NO FILES HERE)",0
m_clipbig: db "BLOCK TOO BIG FOR CLIPBOARD",0

m_replq: db "REPLACE? Y/N  A=ALL  ^Q=STOP",0

m_savechg: db "SAVE CHANGES? Y/N  ^Q=STAY",0
m_nomark: db "MARK A BLOCK FIRST WITH ^K",0
m_nofs: db "CARD FORMAT NOT SUPPORTED",0
m_badname: db "BAD NAME - USE NAME.EXT",0
m_toobig: db "FILE TOO BIG FOR VZ-ED",0
m_cardfull: db "CARD FULL - NOT SAVED",0
m_replace: db "REPLACE FILE? Y/N",0
m_copied: db "COPIED",0


m_noovl: db "VZED.OVL MISSING OR OLD",0
m_clipgone: db "SMALL CLIPBOARD EMPTIED",0
s_ovlname: db "VZED    OVL"
