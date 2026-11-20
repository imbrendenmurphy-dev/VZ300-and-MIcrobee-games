; ===========================================================================
;  strmain.asm - the messages that stay with the code (the spare RAM is full)
; ===========================================================================

m_disp0: db "DISPLAY: TEXT, CAPITALS INVERSE",0
m_disp1: db "DISPLAY: TEXT, LOWER INVERSE",0
m_wrapoff: db "WORD WRAP OFF",0
m_wrapon: db "WORD WRAP ON",0
s_tmpname: db "VZEDTEMP$$$"
s_cfgname: db "VZED    CFG"
s_shellnm: db "SHELL   VZ "
m_saving: db "SAVING...",0
s_repl: db "REPLACE: ",0
m_notfound: db "NOT FOUND",0
s_replaced: db " REPLACED",0
s_saveas: db "SAVE AS: ",0
s_untitled: db "UNTITLED",0
m_new:  db "NEW FILE",0
m_markoff: db "MARK OFF",0
s_find: db "FIND: ",0
s_dir:  db "<DIR>",0
m_saved: db "SAVED",0
s_mark: db "BLOCK",0
s_big:  db ">16M",0
s_ovr:  db "OVR",0
m_cut:  db "CUT",0
s_txt:  db "TXT"
s_bak:  db "BAK"
s_ins:  db "INS",0
m_clipempty: db "CLIPBOARD EMPTY",0
