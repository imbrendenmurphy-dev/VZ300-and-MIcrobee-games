; ===========================================================================
;  VZ-ED 0.2 - full-screen text editor for the VZ300 / VZ200
;  BennVenn SD loader + 128K.  VIBED BY BPM 2026
;
;  One binary, two names on the card:
;    VZED.VZ     run it from VZ-DECK (or the DOS) - starts with a new file
;    PLAYTXT.VZ  VZ-DECK plug-in: RETURN on any .TXT opens it in VZ-ED and
;                quitting goes back to the same place in VZ-DECK
;  The byte at $A003 tells them apart (patched by build.py).
;
;  Memory:  $A000-...  code + tables       BUFS-$F5FF  text (gap buffer)
;           $8000-$9FFF screen shadow, folder list, variables
;           $F600-$F7FF stack       $F800-$F9FF DOS sector buffer
;           $FA00-$FFFF the DOS's own RAM (never touched)
;           $7C00-$7FFF VZ-DECK's variables (never touched)
; ===========================================================================

LATCH   equ $6800
VRAM    equ $7000
HO      equ $7FC0           ; VZ-DECK hand-over block
SCR     equ $8000           ; 16 x 32 shadow screen (what we want shown)
OLD     equ $8200           ; what is on the display now
ROWATTR equ $8400           ; per row: bit0 document row, bit1 title bar
CLIST   equ $8410           ; clusters for a file being written (128 x 3)
INBUF   equ $8590           ; name typed at a prompt
PNAME   equ $85A0           ; parsed 8.3 name
CFGBUF  equ $85B0
NAMEBUF equ $85C0           ; name to search for
NEWNAME equ $85D0           ; name to rename to
fbuf    equ $85DB           ; find text: length + 22 characters (kept)
        assert fbuf+23 <= $8600
DIRBUF  equ $8600           ; folder list records, 20 bytes each
DPTR    equ $95A0           ; pointers to the records (sorted), right after DIRBUF
SECBUF  equ $F800           ; DOS sector buffer (all card I/O goes through here)
STACKTOP equ $F800
BUFE    equ $F600           ; end of the text buffer

DOS_RDSEC equ $575D         ; read sector E:HL into (FB80)
DOS_WRSEC equ $568C         ; write SECBUF to sector E:HL
D_C2S   equ $480D
D_READ  equ $578E
D_NEXT  equ $48BF

MAXENT  equ 200
        assert CLIST+128*3 <= INBUF
        assert DIRBUF+MAXENT*20 <= DPTR
REP1    equ 18              ; frames before a held key repeats
REP2    equ 3               ; frames between repeats

FDATE   equ ((2026-1980)<<9)|(11<<5)|20     ; 20 Nov 2026 (no clock on the VZ)
FTIME   equ (12<<11)

; key events (printable ASCII 32-126 types itself)
K_LEFT  equ 1
K_RIGHT equ 2
K_UP    equ 3
K_DOWN  equ 4
K_PGUP  equ 5
K_PGDN  equ 6
K_TOP   equ 7
K_BOT   equ 8
K_HOME  equ 9
K_END   equ 10
K_BS    equ 11
K_DEL   equ 12
K_RET   equ 13
K_INS   equ 14
K_CAPS  equ 15
K_OPEN  equ 16
K_SAVE  equ 17
K_SAVEAS equ 18
K_NEW   equ 19
K_QUIT  equ 20
K_DISP  equ 21
K_HELP  equ 22
K_FIRE  equ 23
K_MARK  equ 24
K_COPY  equ 25
K_CUT   equ 26
K_PASTE equ 27
K_FIND  equ 28
K_NEXT  equ 29
K_REPL  equ 30
K_WRAP  equ 31
K_LAST  equ 31
K_SHEET equ 127             ; (0.3, CTRL+V: above the printable range)
K_MENU  equ 128             ; (0.4, CTRL+I; joystick fire in the editor too)

        include "vars.inc"

        org $A000
entry:  jp start
plugin: db 0                ; 1 = PLAYTXT.VZ (VZ-DECK plug-in), 0 = VZED.VZ
        db "VZ-ED 0.4 VIBED BY BPM 2026",0

; ===========================================================================
start:  di
        ld sp,STACKTOP
        ld hl,code_end      ; messages and help text: to the spare RAM below $A000
        ld de,tail
        ld bc,tail_end-tail
        ldir
        xor a
        ld (LATCH),a
        ld hl,VARS
        ld de,VARS+1
        ld bc,VARS_END-VARS-1
        ld (hl),0
        ldir
        ld hl,SECBUF
        ld ($FB80),hl
        ld a,$FF
        ld (fatcache),a
        ld (fatcache+1),a
        ld (fatcache+2),a
        ld (lastidx),a
        ld hl,$FFFF
        ld (goal),hl
        ld (curcell),hl
        ld a,1
        ld (insmode),a
        ld (crlf),a
        ld (waitrel),a
        ld (cfg_ins),a
        call clip_init
        ld hl,($FB45)       ; the folder VZ-DECK / the DOS is in
        ld (cwd),hl
        ld a,($FB47)
        ld (cwd+2),a
        call fs_init
        call cfg_load
        call joy_detect
        call set_display
        call buf_clear
        ld a,(plugin)
        or a
        jr z,st_go
        call verify_ho      ; really opened from VZ-DECK with a file?
        jr c,st_go
        ld a,1
        ld (plugmode),a
        ld hl,(HO+3)
        ld (ldcl),hl
        ld a,(HO+5)
        ld (ldcl+2),a
        ld hl,(HO+7)
        ld (ldsz),hl
        ld a,(HO+9)
        ld (ldsz+2),a
        call load_file
        jr c,st_go
        ld hl,HO+11
        ld de,fname
        ld bc,11
        ldir
        ld a,1
        ld (named),a
st_go:  jp edit

; VZ-DECK hand-over: HO+3 cluster, HO+7 size, HO+11 name.  Only trusted if
; that name is in this folder with that cluster and size (C = not trusted).
verify_ho:
        ld hl,(HO)
        ld a,h
        or l
        scf
        ret nz
        ld a,(HO+6)
        or a
        scf
        ret nz
        ld a,(fs_ok)
        or a
        scf
        ret z
        ld hl,HO+11
        call cwd_find
        ret c
        ld hl,(dwptr)
        ld de,26
        add hl,de
        ld de,(HO+3)
        ld a,(hl)
        cp e
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp d
        scf
        ret nz
        ld hl,(dwptr)
        ld de,20
        add hl,de
        ld a,(HO+5)
        cp (hl)
        scf
        ret nz
        ld hl,(dwptr)
        ld de,28
        add hl,de
        ld de,HO+7
        ld b,3
vh_s:   ld a,(de)
        cp (hl)
        scf
        ret nz
        inc hl
        inc de
        djnz vh_s
        or a
        ret

joy_detect:
        in a,($2C)
        and $0F
        cp $0F
        ret nz
        in a,($2E)
        bit 4,a
        ret z
        ld a,1
        ld (joyon),a
        ret

; ===========================================================================
;  editor main loop
; ===========================================================================
edit:   ld a,1
        ld (edmode),a
        call render
ed_lp:  call frame
        call getkey
        or a
        jr z,ed_lp
        push af
        xor a
        ld (msgflag),a
        ld (blinkc),a
        inc a
        ld (blinkon),a
        pop af
        call dispatch
        ld a,1
        ld (edmode),a
        call render
        jr ed_lp

dispatch:
        ld b,a
        ld a,(selon)        ; a find match is only shown until the next key
        cp 2
        jr nz,ds_0
        xor a
        ld (selon),a
ds_0:   ld a,b
        cp 32
        jr c,ds_cmd
        cp K_MENU
        jr z,c_menu
        cp K_SHEET
        jr z,c_sheet
        ret nc
        jp type_char
ds_cmd: cp K_RET
        jp z,type_newline
        or a
        ret z
        cp K_LAST+1
        ret nc
        add a,a
        ld l,a
        ld h,0
        ld de,cmdtab-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
cmdtab: dw c_left,c_right,c_up,c_down,c_pgup,c_pgdn,c_top,c_bot,c_home,c_end
        dw c_bs,c_del,c_none,c_ins,c_caps,c_open,c_save,c_saveas,c_new,c_quit
        dw c_disp,c_help,c_menu,c_mark,c_copy,c_cut,c_paste,c_find,c_next,c_repl
        dw c_wrap
c_none: ret
c_help: xor a               ; help and the sheet view are overlays (ovl.asm)
        jp ovl_run
c_sheet: ld a,1
        jp ovl_run
c_menu: ld a,2
        jp ovl_run

c_left: call mv_left
        jp reset_goal
c_right: call mv_right
        jp reset_goal
c_up:   call setgoal
        jp mv_up
c_down: call setgoal
        jp mv_down
c_pgup: call setgoal
        ld a,(docrows)
        dec a
        ld b,a
cpu_l:  push bc
        call mv_up
        call nc,top_up1
        pop bc
        djnz cpu_l
        ret
c_pgdn: call setgoal
        ld a,(docrows)
        dec a
        ld b,a
cpd_l:  push bc
        call mv_down
        call nc,top_down1
        pop bc
        djnz cpd_l
        ret
c_top:  call gap_to_start
        ld hl,0
        ld (top),hl
        ld (hs),hl
        jp reset_goal
c_bot:  call gap_to_end
        jp reset_goal
c_home: call goto_ls
        jp reset_goal
c_end:  call goto_le
        jp reset_goal
c_bs:   ld a,(selon)
        or a
        jp nz,blk_del
        call del_left
        jp reset_goal
c_del:  ld a,(selon)
        or a
        jp nz,blk_del
        call del_right
        jp reset_goal
c_ins:  ld a,(insmode)
        xor 1
        ld (insmode),a
        ret
c_caps: ld a,(caps)
        xor 1
        ld (caps),a
        ret
c_disp: ld a,(dstyle)
        inc a
        cp 3
        jr c,cd_1
        xor a
cd_1:   ld (dstyle),a
        call set_display
        ld a,(dstyle)
        ld hl,m_disp0
        or a
        jr z,cd_2
        ld hl,m_disp1
        dec a
        jr z,cd_2
        ld hl,m_disp2
cd_2:   jp set_msg

; ---- typing
type_char:
        ld b,a
        xor a               ; typing ends marking (the block stays in the text)
        ld (selon),a
        ld a,(insmode)
        or a
        jr nz,tc_ins
        push bc
        call peek_r
        pop bc
        jr c,tc_ins
        cp 10
        jr z,tc_ins
        push bc
        call del_right
        pop bc
tc_ins: ld a,b
        call ins_char
        jp reset_goal
type_newline:
        xor a
        ld (selon),a
        ld a,10
        call ins_char
        jp reset_goal

reset_goal:
        ld hl,$FFFF
        ld (goal),hl
        ret
setgoal: ld hl,(goal)
        ld a,h
        and l
        inc a
        ret nz
        ld a,(wrap)
        or a
        jr z,sg_n
        call wcur           ; wrap: the column on the screen row
        call curpos
        ld de,(wcrs)
        or a
        sbc hl,de
        ld (goal),hl
        ret
sg_n:   call curcol
        ld (goal),hl
        ret

; ===========================================================================
;  gap buffer.  text = [BUFS,gs) + [ge,BUFE).  The cursor sits at the gap.
; ===========================================================================
buf_clear:
        ld hl,BUFS
        ld (gs),hl
        ld hl,BUFE
        ld (ge),hl
        ld hl,1
        ld (curln),hl
        ld hl,0
        ld (top),hl
        ld (hs),hl
        xor a
        ld (modified),a
        ld (selon),a
        jp reset_goal

ins_char:                   ; A = char
        ld c,a
        ld hl,(gs)
        ld de,(ge)
        or a
        sbc hl,de
        jr z,ic_full
        ld hl,(gs)
        ld (hl),c
        inc hl
        ld (gs),hl
        ld a,1
        ld (modified),a
        ld a,c
        cp 10
        ret nz
        ld hl,(curln)
        inc hl
        ld (curln),hl
        ret
ic_full: ld hl,m_full
        jp set_msg

del_left:
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        ret z
        ld hl,(gs)
        dec hl
        ld (gs),hl
        ld a,1
        ld (modified),a
        ld a,(hl)
        cp 10
        ret nz
        ld hl,(curln)
        dec hl
        ld (curln),hl
        ret

del_right:
        ld hl,(ge)
        ld de,BUFE
        or a
        sbc hl,de
        ret z
        ld hl,(ge)
        inc hl
        ld (ge),hl
        ld a,1
        ld (modified),a
        ret

peek_r:                     ; A = char after the cursor, C if at the end
        ld hl,(ge)
        ld de,BUFE
        or a
        sbc hl,de
        scf
        ret z
        ld hl,(ge)
        ld a,(hl)
        and a
        ret

mv_left:                    ; C if already at the start
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        scf
        ret z
        ld bc,1
        call gap_left
        or a
        ret

mv_right:                   ; C if already at the end
        ld hl,(ge)
        ld de,BUFE
        or a
        sbc hl,de
        scf
        ret z
        ld bc,1
        call gap_right
        or a
        ret

gap_left:                   ; move the gap BC chars towards the start
        ld a,b
        or c
        ret z
        ld hl,(gs)
        ld de,(ge)
gl_l:   dec hl
        dec de
        ld a,(hl)
        ld (de),a
        cp 10
        jr nz,gl_n
        push hl
        ld hl,(curln)
        dec hl
        ld (curln),hl
        pop hl
gl_n:   dec bc
        ld a,b
        or c
        jr nz,gl_l
        ld (gs),hl
        ld (ge),de
        ret

gap_right:                  ; move the gap BC chars towards the end
        ld a,b
        or c
        ret z
        ld hl,(ge)
        ld de,(gs)
gr_l:   ld a,(hl)
        ld (de),a
        inc hl
        inc de
        cp 10
        jr nz,gr_n
        push hl
        ld hl,(curln)
        inc hl
        ld (curln),hl
        pop hl
gr_n:   dec bc
        ld a,b
        or c
        jr nz,gr_l
        ld (ge),hl
        ld (gs),de
        ret

gap_to_start:               ; block move: whole text after the cursor
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        ret z
        ld hl,(gs)
        dec hl
        ld de,(ge)
        dec de
        lddr
        inc de
        ld (ge),de
        ld hl,BUFS
        ld (gs),hl
        ld hl,1
        ld (curln),hl
        ret

gap_to_end:
        ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        ret z
        push bc
        ld hl,(ge)
        call count_lf
        ld hl,(curln)
        add hl,de
        ld (curln),hl
        pop bc
        ld hl,(ge)
        ld de,(gs)
        ldir
        ld (gs),de
        ld hl,BUFE
        ld (ge),hl
        ret

line_start:                 ; HL = start of the cursor's line (before the gap)
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(gs)
        ld a,b
        or c
        ret z
        dec hl
        ld a,10
        cpdr
        jr nz,ls_none
        inc hl
        inc hl
        ret
ls_none: ld hl,BUFS
        ret

curcol: call line_start     ; HL = cursor column (0 based)
        ex de,hl
        ld hl,(gs)
        or a
        sbc hl,de
        ret

dist_to_le:                 ; BC = chars from the cursor to the end of its line
        ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        ret z
        ld hl,(ge)
        ld a,10
        cpir
        jr nz,dl_all
        dec hl
        ld de,(ge)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ret
dl_all: ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ret

goto_ls: call curcol
        ld b,h
        ld c,l
        jp gap_left

goto_le: call dist_to_le
        jp gap_right

goto_col:                   ; HL = column wanted, move right up to it on this line
        push hl
        call dist_to_le
        pop hl
        or a
        sbc hl,bc
        jr nc,gc_bc
        add hl,bc
        ld b,h
        ld c,l
gc_bc:  jp gap_right

mv_up:  ld a,(wrap)         ; C if on the first line
        or a
        jp nz,wmv_up
        call line_start
        ld de,BUFS
        or a
        sbc hl,de
        scf
        ret z
        call goto_ls
        ld bc,1
        call gap_left
        call goto_ls
        ld hl,(goal)
        call goto_col
        or a
        ret

mv_down:                    ; C if on the last line
        ld a,(wrap)
        or a
        jp nz,wmv_down
        call dist_to_le
        ld hl,(ge)
        add hl,bc
        ld de,BUFE
        or a
        sbc hl,de
        scf
        ret z
        inc bc
        call gap_right
        ld hl,(goal)
        call goto_col
        or a
        ret

top_up1:                    ; scroll the view up a line
        ld a,(wrap)
        or a
        ret nz
        ld hl,(top)
        ld a,h
        or l
        ret z
        ld de,BUFS
        add hl,de
        dec hl              ; HL -> LF ending the line above
        push hl
        ld de,BUFS
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        ld a,b
        or c
        jr z,tu_zero
        dec hl
        ld a,10
        cpdr
        jr nz,tu_zero
        inc hl
        inc hl
        ld de,BUFS
        or a
        sbc hl,de
        ld (top),hl
        ret
tu_zero: ld hl,0
        ld (top),hl
        ret

top_down1:                  ; scroll the view down a line (never past the cursor)
        ld a,(wrap)
        or a
        ret nz
        ld hl,(top)
        ld de,BUFS
        add hl,de
        push hl
        ex de,hl
        ld hl,(gs)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        ld a,b
        or c
        ret z
        ld a,10
        cpir
        ret nz
        ld de,BUFS
        or a
        sbc hl,de
        ld (top),hl
        ret

count_lf:                   ; HL = start, BC = length -> DE = number of LFs
        ld de,0
        ld a,b
        or c
        ret z
        ld a,10
cl_l:   cpir
        ret nz
        inc de
        jp pe,cl_l
        ret

ensure_vis:                 ; scroll so the cursor is on screen
        call line_start
        push hl
        ld de,BUFS
        or a
        sbc hl,de           ; line start (logical)
        ld de,(top)
        or a
        sbc hl,de
        jr nc,ev_below
        add hl,de           ; above the top line: it becomes the top line
        ld (top),hl
        jr ev_hs
ev_below:                   ; walk back up to a screen of lines from the cursor line
        pop hl
        push hl
        ld a,(docrows)
        dec a
        ld (evn),a
ev_back: ex de,hl           ; DE = line start being looked at
        ld hl,(top)
        ld bc,BUFS
        add hl,bc
        or a
        sbc hl,de
        jr z,ev_hs          ; reached the top line: no scrolling needed
        ld hl,evn
        ld a,(hl)
        or a
        jr z,ev_set
        dec (hl)
        ex de,hl            ; HL = line start; find the line above
        dec hl              ; the LF before it
        push hl
        ld bc,BUFS
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        ld a,b
        or c
        jr z,ev_set0
        dec hl
        ld a,10
        cpdr
        jr nz,ev_set0
        inc hl
        inc hl
        jr ev_back
ev_set0: ld hl,BUFS
        ex de,hl
ev_set: ex de,hl            ; HL = new top line start
        ld de,BUFS
        or a
        sbc hl,de
        ld (top),hl
ev_hs:  pop de              ; line start
        ld hl,(gs)
        or a
        sbc hl,de           ; column
        ld de,(hs)
        or a
        sbc hl,de
        jr nc,ev_r
        add hl,de
        ld de,8
        or a
        sbc hl,de
        jr nc,ev_s
        ld hl,0
ev_s:   ld (hs),hl
        ret
ev_r:   ld de,32
        or a
        sbc hl,de
        ret c
        add hl,de
        ld de,(hs)
        add hl,de
        ld de,24
        or a
        sbc hl,de
        ld (hs),hl
        ret

; ===========================================================================
;  drawing the editor
; ===========================================================================
render: ld a,2
        call set_rows
        call render_doc
        call sel_show
        call build_status
        ld hl,(curcell)
        ld a,h
        cp $FF
        jr z,rn_f
        ld a,(blinkon)
        or a
        jr z,rn_f
        ld de,SCR
        add hl,de
        set 7,(hl)
rn_f:   jp flush

set_rows:                   ; row 0 title bar, other rows = A>>1 (1 doc / 0 plain)
        srl a
        ld hl,ROWATTR
        ld (hl),2
        inc hl
        ld b,15
sr_l:   ld (hl),a
        inc hl
        djnz sr_l
        ret

cls_scr: ld hl,SCR
        ld de,SCR+1
        ld bc,511
        ld (hl),' '
        ldir
        ret

render_doc:
        ld a,(wrap)
        or a
        jp nz,render_wrap
        call ensure_vis
        ld hl,$FFFF
        ld (curcell),hl
        ld hl,(gs)          ; boundary: first the gap (= cursor), then the end
        ld (bnd),hl
        xor a
        ld (bphase),a
        ld hl,(top)
        ld de,BUFS
        add hl,de           ; HL = text pointer (top line)
        ld de,SCR+32        ; DE = screen row 1
        ld a,(docrows)
        ld (rrows),a
rd_row: ld a,(bnd)
        ld c,a              ; C = low byte of the boundary
        push de             ; skip the columns scrolled off the left
        ld de,(hs)
rd_sk:  ld a,d
        or e
        jr z,rd_skd
        ld a,l
        cp c
        jr nz,rd_skg        ; (0.2 fix: the carry from "cp c" used to reach the jr c
        call rd_bnd         ;  below and blank the screen when scrolled sideways)
        jr c,rd_skeot
rd_skg: ld a,(hl)
        inc hl
        cp 10
        jr z,rd_skeol
        dec de
        jr rd_sk
rd_skeol: pop de
        jr rd_eol
rd_skeot: pop de
        jr rd_eot
rd_skd: pop de
        ld b,32
rd_vl:  ld a,l              ; visible part of the line
        cp c
        jr z,rd_vb
rd_vg:  ld a,(hl)
        inc hl
        cp 10
        jr z,rd_eolp
        ld (de),a
        inc de
        djnz rd_vl
rd_rest: ld a,l             ; rest of a long line is off screen
        cp c
        jr z,rd_rb
rd_rg:  ld a,(hl)
        inc hl
        cp 10
        jr nz,rd_rest
        jr rd_next
rd_rb:  call rd_bnd
        jr c,rd_eot0
        jr rd_rg
rd_vb:  ld a,(bnd+1)
        cp h
        jr nz,rd_vg
        ld a,(bphase)
        or a
        jr nz,rd_eotp
        push hl             ; the cursor is here
        ld hl,-SCR
        add hl,de
        ld (curcell),hl
        pop hl
        call rd_bnd
        jr c,rd_eotp
        jr rd_vg
rd_eol: ld b,32             ; line ended inside the skipped part
rd_eolp: ld a,' '
rd_p1:  ld (de),a
        inc de
        djnz rd_p1
rd_next: ld a,(rrows)
        dec a
        ld (rrows),a
        jr nz,rd_row
        ret
rd_eot: ld b,32
rd_eotp: ld a,' '           ; end of text: blank the rest
rd_p2:  ld (de),a
        inc de
        djnz rd_p2
rd_eot0: ld a,(rrows)
        dec a
        ret z
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld h,d
        ld l,e
        ld (hl),' '
        dec bc
        ld a,b
        or c
        ret z
        inc de
        ldir
        ret

; reached a possible boundary (L = C).  NC = carry on reading at HL,
; C = end of the text.  Jumps the gap the first time.
rd_bnd: ld a,(bnd+1)
        cp h
        ret nz              ; (NC) not really
        ld a,(bphase)
        or a
        scf
        ret nz              ; the end
        inc a
        ld (bphase),a
        ld hl,BUFE
        ld (bnd),hl
        ld c,l
        ld hl,(ge)          ; over the gap
        ld a,l
        cp c
        jr nz,rb_ok
        ld a,h
        cp BUFE/256
        scf
        ret z               ; gap runs to the end: end of text
rb_ok:  or a
        ret

build_status:
        call clr_title
        ld a,(msgflag)
        or a
        jr z,bs_n
        ld hl,(msgp)
        ld de,SCR
        jp puts
bs_n:   ld de,SCR
        ld a,(selon)
        dec a
        jr nz,bs_nm
        ld hl,s_mark
        call puts
        jr bs_1
bs_nm:  call put_fname
        ld a,(modified)
        or a
        jr z,bs_1
        ld a,'*'
        ld (de),a
bs_1:   ld de,SCR+14
        ld a,'L'
        ld (de),a
        inc de
        ld hl,(curln)
        call putdec16
        call curcol
        inc hl
        ld de,SCR+21
        ld a,'C'
        ld (de),a
        inc de
        call putdec16
        ld de,SCR+27
        ld hl,s_ins
        ld a,(insmode)
        or a
        jr nz,bs_2
        ld hl,s_ovr
bs_2:   call puts
        ld a,(wrap)
        or a
        jr z,bs_3
        ld a,'W'
        ld (SCR+30),a
bs_3:   ld a,(caps)
        or a
        ret z
        ld a,'^'
        ld (SCR+31),a
        ret

clr_title:                  ; blank the title bar row of SCR
        ld hl,SCR
        ld de,SCR+1
        ld bc,31
        ld (hl),' '
        ldir
        ret

put_fname:                  ; name.ext (or UNTITLED) at DE
        ld a,(named)
        or a
        jr nz,pf_1
        ld hl,s_untitled
        jp puts
pf_1:   ld hl,fname
put83:  ld b,8              ; HL = 11 byte name -> "NAME.EXT" at DE
pf_n:   ld a,(hl)
        cp ' '
        jr z,pf_ns
        ld (de),a
        inc de
pf_ns:  inc hl
        djnz pf_n
        ld a,(hl)
        cp ' '
        ret z
        ld a,'.'
        ld (de),a
        inc de
        ld b,3
pf_e:   ld a,(hl)
        cp ' '
        jr z,pf_es
        ld (de),a
        inc de
pf_es:  inc hl
        djnz pf_e
        ret

puts:   ld a,(hl)           ; zero terminated HL -> DE
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr puts

putdec16:                   ; HL -> decimal at DE, no leading zeros
        xor a
        ld (lz),a
        ld bc,10000
        call pd_dig
        ld bc,1000
        call pd_dig
        ld bc,100
        call pd_dig
        ld bc,10
        call pd_dig
        ld a,l
        add a,'0'
        ld (de),a
        inc de
        ret
pd_dig: ld a,'0'-1
pd_l:   inc a
        or a
        sbc hl,bc
        jr nc,pd_l
        add hl,bc
        cp '0'
        jr nz,pd_put
        ld c,a
        ld a,(lz)
        or a
        ld a,c
        ret z
pd_put: ld (de),a
        inc de
        ld a,1
        ld (lz),a
        ret

putdec24:                   ; (n24) -> decimal into NUMTMP, B = length
        xor a
        ld (lz),a
        ld de,NUMTMP
        ld hl,pow24
        ld b,7
p24_l:  ld c,'0'-1
p24_s:  inc c
        ld a,(n24)
        sub (hl)
        ld (n24),a
        inc hl
        ld a,(n24+1)
        sbc a,(hl)
        ld (n24+1),a
        inc hl
        ld a,(n24+2)
        sbc a,(hl)
        ld (n24+2),a
        dec hl
        dec hl
        jr nc,p24_s
        ld a,(n24)
        add a,(hl)
        ld (n24),a
        inc hl
        ld a,(n24+1)
        adc a,(hl)
        ld (n24+1),a
        inc hl
        ld a,(n24+2)
        adc a,(hl)
        ld (n24+2),a
        inc hl
        ld a,c
        cp '0'
        jr nz,p24_put
        ld a,b
        cp 1
        jr z,p24_put
        ld a,(lz)
        or a
        jr z,p24_skip
p24_put: ld a,c
        ld (de),a
        inc de
        ld a,1
        ld (lz),a
p24_skip: djnz p24_l
        ld a,e
        sub NUMTMP&255
        ld b,a
        ret
pow24:  db 1000000&255,(1000000>>8)&255,1000000>>16
        db 100000&255,(100000>>8)&255,100000>>16
        db 10000&255,10000>>8,0
        db 1000&255,1000>>8,0
        db 100,0,0
        db 10,0,0
        db 1,0,0

set_msg: ld (msgp),hl
        ld a,1
        ld (msgflag),a
        ret

show_status:                ; put a message up straight away (before slow work)
        call set_msg
        call build_status
        jp flush

; ===========================================================================
;  display: three styles.  0/1 = 32x16 text (capitals or lower case shown
;  inverse), 2 = 128x64 4-colour graphics with a 4x6 font (32x10).
; ===========================================================================
set_display:
        ld a,(dstyle)
        cp 2
        jr z,sd_g
        ld a,16
        ld (nrows),a
        ld hl,0*256+2       ; B=0 (256 cells), C=2 passes
        ld (ncells),hl
        ld a,(dstyle)
        or a
        ld a,$40
        jr z,sd_t
        ld a,$80
sd_t:   ld (tinvm),a
        xor a
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,511
        ld (hl),$20
        ldir
        jr sd_c
sd_g:   ld a,10
        ld (nrows),a
        ld hl,64*256+2      ; 64 then 256 = 320 cells
        ld (ncells),hl
        ld a,$08
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),0
        ldir
sd_c:   ld a,(nrows)
        dec a
        ld (docrows),a
        ld a,1
        ld (waitrel),a
invalidate:
        ld hl,OLD
        ld de,OLD+1
        ld bc,511
        ld (hl),$FE
        ldir
        ret

flush:                      ; draw every cell that changed
        ld hl,SCR
        ld de,OLD
        ld bc,(ncells)      ; B = first pass count, C = passes
fl_l:   ld a,(de)
        cp (hl)
        jr nz,fl_d
fl_n:   inc hl
        inc de
        djnz fl_l
        dec c
        jr nz,fl_l
        ret
fl_d:   ld a,(hl)
        ld (de),a
        push hl
        push de
        push bc
        ld b,h
        res 7,b             ; index = HL - $8000
        ld c,l
        call draw_cell
        pop bc
        pop de
        pop hl
        jr fl_n

draw_cell:                  ; BC = cell index, A = shadow byte
        ld e,a
        xor a
        ld (dsel),a
        bit 7,e
        jr z,dc_go
        ld hl,(curcell)
        or a
        sbc hl,bc
        jr z,dc_go
        ld a,1              ; highlighted but not the cursor: selected text
        ld (dsel),a
dc_go:  ld a,c
        rlca
        rlca
        rlca
        and 7
        ld d,a
        ld a,b
        add a,a
        add a,a
        add a,a
        or d                ; A = row
        ld (crow),a
        ld hl,ROWATTR
        add a,l
        ld l,a
        ld d,(hl)           ; D = row flags
        ld a,(dstyle)
        cp 2
        jr z,gcell
        ; ---- text mode
        ld hl,VRAM
        add hl,bc
        push hl
        ld a,e
        and $7F
        ld l,a
        ld h,TTAB/256
        ld c,(hl)           ; C = 6847 code + case flags
        pop hl
        ld a,c
        and $3F
        bit 7,e
        jr z,tc_nh
        ld b,a
        ld a,(dsel)
        or a
        ld a,b
        jr z,tc_hl
        bit 0,d
        jr z,tc_hl
        ld a,(tinvm)        ; selected text: the opposite of how it normally shows
        and c
        ld a,b
        jr nz,tc_st
        jr tc_inv
tc_hl:  bit 1,d             ; on the title bar: a hole (prompt cursor)
        jr nz,tc_st
        bit 0,d
        jr z,tc_inv
        ld a,(insmode)      ; cursor in the text: a coloured block
        or a
        ld a,$AF
        jr nz,tc_st
        ld a,$BF
        jr tc_st
tc_nh:  bit 1,d
        jr nz,tc_inv
        bit 0,d
        jr z,tc_st
        ld b,a
        ld a,(tinvm)
        and c
        ld a,b
        jr z,tc_st
tc_inv: or $40
tc_st:  ld (hl),a
        ret
gcell:  ; ---- graphics mode: colour pair (CTAB sits in the upper half of TTAB's page)
        bit 7,e
        jr z,gc_nh
        ld a,$A0
        bit 0,d
        jr z,gc_p
        ld a,(dsel)
        or a
        ld a,$C0            ; selected text
        jr nz,gc_p
        ld a,(insmode)
        or a
        ld a,$A0
        jr nz,gc_p
        ld a,$B0
        jr gc_p
gc_nh:  ld a,$80
        bit 1,d
        jr z,gc_p
        ld a,$90
gc_p:   ld (gpair),a
        ld a,c
        and 31
        ld (ccol),a
        ld a,e
        and $7F
        sub 32
        jr c,gc_blk
        cp 95
        jr c,gc_ok
gc_blk: ld a,95
gc_ok:  ld l,a               ; 3 bytes per glyph (two rows per byte)
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,FONT
        add hl,de
        ex de,hl            ; DE = glyph
        ld a,(crow)
        add a,a
        ld l,a
        ld h,0
        ld bc,ROWBASE
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ccol)
        add a,l
        ld l,a
        jr nc,gc_a
        inc h
gc_a:   ld b,3
        ld a,(gpair)
        ld c,a
gc_l:   ld a,(de)
        rrca
        rrca
        rrca
        rrca
        call gc_row
        ld a,(de)
        inc de
        call gc_row
        djnz gc_l
        ret
gc_row: and $0F             ; one pixel row: nibble + colour pair -> 2bpp byte
        or c
        push hl
        ld l,a
        ld h,CTAB/256
        ld a,(hl)
        pop hl
        ld (hl),a
        ld a,l
        add a,32
        ld l,a
        ret nc
        inc h
        ret
ROWBASE: dw VRAM,VRAM+192,VRAM+384,VRAM+576,VRAM+768
        dw VRAM+960,VRAM+1152,VRAM+1344,VRAM+1536,VRAM+1728

; ===========================================================================
;  keyboard + joystick, with auto-repeat
; ===========================================================================
vsync:  ld a,(LATCH)        ; wait for the start of field sync
        rla
        jr nc,vsync
vs_w:   ld a,(LATCH)
        rla
        jr c,vs_w
        ret

frame:  call vsync          ; one frame; blinks the cursor in the editor
        ld a,(edmode)
        or a
        ret z
        ld a,(blinkc)
        inc a
        and 15
        ld (blinkc),a
        ret nz
        ld a,(blinkon)
        xor 1
        ld (blinkon),a
        ld hl,(curcell)
        ld a,h
        cp $FF
        ret z
        ld de,SCR
        add hl,de
        ld a,(hl)
        xor $80
        ld (hl),a
        jp flush

kscan:                      ; B = key index (row*8+bit) or $FF, C = 1 shift, 2 ctrl
        ld c,0
        ld a,($68FB)
        bit 2,a
        jr nz,ks_1
        set 0,c
ks_1:   ld a,($68FD)
        bit 2,a
        jr nz,ks_2
        set 1,c
ks_2:   ld hl,$68FE
        ld b,0
ks_row: ld a,(hl)
        cpl
        and $3F
        ld e,a
        ld a,l
        cp $FD
        jr z,ks_m
        cp $FB
        jr nz,ks_nm
ks_m:   ld a,e
        and $3B             ; not SHIFT/CTRL themselves
        ld e,a
ks_nm:  ld a,e
        or a
        jr nz,ks_bit
        ld a,b
        add a,8
        ld b,a
        ld a,l
        rlca
        ld l,a
        cp $FE
        jr nz,ks_row
        ld a,(joyon)
        or a
        jr z,ks_none
        in a,($2C)
        cpl
        and $0F
        jr z,ks_fire
        ld b,64
ks_jb:  rrca
        ret c
        inc b
        jr ks_jb
ks_fire: in a,($2E)
        bit 4,a
        jr nz,ks_none
        ld b,68
        ret
ks_none: ld b,$FF
        ret
ks_bit: rrca
        ret c
        inc b
        jr ks_bit

getkey:                     ; A = event or 0
        call kscan
        ld a,b
        cp $FF
        jr nz,gk_k
        ld (lastidx),a
        xor a
        ld (waitrel),a
        ret
gk_k:   ld a,(waitrel)      ; ignore keys held over from before
        or a
        jr z,gk_k2
        ld a,b
        ld (lastidx),a
        xor a
        ret
gk_k2:  ld a,(lastidx)
        cp b
        jr nz,gk_new
        ld a,(lastmod)
        cp c
        jr nz,gk_new
        ld a,(rpt)
        dec a
        ld (rpt),a
        jr z,gk_rep
        xor a
        ret
gk_rep: ld a,REP2
        ld (rpt),a
        jr gk_ev
gk_new: ld a,b
        ld (lastidx),a
        ld a,c
        ld (lastmod),a
        ld a,REP1
        ld (rpt),a
gk_ev:  ld a,b
        cp 64
        jr nc,gk_joy
        ld a,c
        rrca
        rrca
        or b
        ld l,a
        ld h,KTAB/256
        ld a,(hl)
        ld c,a
        ld a,(caps)
        or a
        ld a,c
        ret z
        cp 'a'
        jr c,gk_cu
        cp 'z'+1
        jr c,gk_flip
gk_cu:  cp 'A'
        ret c
        cp 'Z'+1
        ret nc
gk_flip: xor $20
        ret
gk_joy: sub 64
        ld l,a
        ld h,0
        ld de,JTAB
        add hl,de
        ld a,(hl)
        ret
JTAB:   db K_UP,K_DOWN,K_LEFT,K_RIGHT,K_FIRE

waitkey:                    ; A = next event (no blink)
        call frame
        call getkey
        or a
        jr z,waitkey
        ret

        include "edit2.asm"
        include "files.asm"
        include "ui.asm"

code_end:
BUFS    equ (code_end+255)&$FF00
        assert BUFS+12000 <= BUFE

; tables, font, messages and help text: stored after the code in the file and
; copied at start-up to the free RAM between the variables and $A000 (VZ-DECK's
; plug-in header at $9FE8 is only needed while loading), so they don't take
; room from the text buffer
        org VARS_END
tail:

        include "strings.asm"
        include "strmain.asm"
        include "ovl.asm"
tail_end:
        assert tail_end <= $A000
