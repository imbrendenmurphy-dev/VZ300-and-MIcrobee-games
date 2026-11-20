; ===========================================================================
;  edit2.asm - VZ-ED 0.2: screen wrap, blocks + clipboard, find / replace
;
;  Positions here are LOGICAL offsets (0 = start of the text, ignoring the gap)
;  unless a routine says "physical".  The cursor is at logical position
;  c = gs - BUFS.
; ===========================================================================

LIN     equ $8600           ; wrap: the text on screen laid out straight (WIN + end mark)
WIN     equ 480             ; 15 rows of at most 32 positions
RING    equ $8800           ; wrap: last 16 row starts of a line (logical)
WRS     equ $8820           ; wrap: start of each screen row in LIN (16+1 words)
SRS     equ $8850           ; selection: logical position of column 0 of each row
SRP     equ $8870           ; selection: positions on each row (bytes)
FFOLD   equ $8880           ; the find string in lower case
CLIPF   equ $8900           ; clipboard if there is no spare SRAM bank (lost on CTRL+O)
; scratch variables, rebuilt every time they are used (never across the file list)
rbuf    equ $88D8           ; replacement text (23 bytes; emptied by CTRL+O)
wls     equ $88A0           ; start of the cursor's line
wlim    equ $88A2
wcrs    equ $88A4           ; start of the cursor's screen row
wnext   equ $88A6
wtmp    equ $88A8
lincur  equ $88AA
linend  equ $88AC
wscr    equ $88AE
wsp     equ $88B0
srsp    equ $88B2
ss0     equ $88B4
ss1     equ $88B6
nl_s    equ $88B8
fsave   equ $88BA
rcount  equ $88BC
ilp     equ $88BE
ilb     equ $88C0
wlast   equ $88C2
wlf     equ $88C3
ridx    equ $88C4
rcnt    equ $88C5
wk      equ $88C6
wneed   equ $88C7
sa_n    equ $88C8
sa_hi   equ $88C9
rall    equ $88CA
ilemp   equ $88CB
msgbuf  equ $88CC           ; 12 bytes: "n REPLACED"
        assert rbuf+23 <= CLIPF
CLIPB   equ $4000           ; clipboard in the spare 10K SRAM bank (OUT ($37),3)
; (LIN .. CLIPF+ are inside DIRBUF: only the file list uses that, and it
;  rebuilds everything here before the editor draws again)

        assert LIN+WIN < RING
        assert (BUFE&255) == 0

; ---------------------------------------------------------------- helpers
curpos: push de             ; HL = cursor (logical)
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        pop de
        ret

textlen: push de            ; HL = length of the text
        ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        ex de,hl
        call curpos
        add hl,de
        pop de
        ret

log2phys:                   ; HL = logical position -> physical pointer
        push de             ; (at or after the cursor -> after the gap)
        push hl
        call curpos
        ex de,hl
        pop hl
        or a
        sbc hl,de
        jr nc,l2p_a
        add hl,de
        ld de,BUFS
        add hl,de
        pop de
        ret
l2p_a:  ld de,(ge)
        add hl,de
        pop de
        ret

phys2log:                   ; HL = physical pointer -> logical position
        push de
        ld de,(ge)
        or a
        sbc hl,de
        jr c,p2l_b
        ex de,hl
        call curpos
        add hl,de
        pop de
        ret
p2l_b:  add hl,de
        ld de,BUFS
        or a
        sbc hl,de
        pop de
        ret

ls_of:                      ; HL = logical position (<= cursor) -> start of its line
        ld a,h
        or l
        ret z
        ld b,h
        ld c,l
        ld de,BUFS
        add hl,de
        dec hl
        ld a,10
        cpdr
        jr nz,lo_0
        inc hl
        inc hl
        or a
        sbc hl,de
        ret
lo_0:   ld hl,0
        ret

prevls: dec hl              ; HL = start of a line (> 0, <= cursor) -> start of the line above
        jp ls_of

gap_to:                     ; HL = logical position: move the cursor there (block moves)
        push hl
        call curpos
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ret z
        jr c,gto_l
        ld b,h
        ld c,l
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
        ld (ge),hl
        ret
gto_l:  ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld b,h
        ld c,l
        push bc
        ld hl,(gs)
        or a
        sbc hl,bc
        call count_lf
        ld hl,(curln)
        or a
        sbc hl,de
        ld (curln),hl
        pop bc
        ld hl,(gs)
        dec hl
        ld de,(ge)
        dec de
        lddr
        inc hl
        inc de
        ld (gs),hl
        ld (ge),de
        ret

next_line:                  ; HL = start of a line -> HL = its length,
        ld (nl_s),hl        ; DE = start of the next line ($FFFF = none)
        call log2phys
        ld de,(gs)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,nl_aft
        push hl
        ex de,hl
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        ld a,10
        cpir
        jr z,nl_fnd
        ld hl,(ge)
nl_aft: ex de,hl
        ld hl,BUFE
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        ld a,b
        or c
        jr z,nl_end
        ld a,10
        cpir
        jr z,nl_fnd
nl_end: call textlen
        ld de,(nl_s)
        or a
        sbc hl,de
        ld de,$FFFF
        ret
nl_fnd: call phys2log
        ex de,hl
        ld h,d
        ld l,e
        dec hl
        push de
        ld de,(nl_s)
        or a
        sbc hl,de
        pop de
        ret

; ===========================================================================
;  screen wrap.  A screen row holds at most 32 positions: up to 31 characters
;  and the line end, or 32 characters broken after the last space in them (or
;  straight after the 32nd if there is no space).  The file keeps one line per
;  paragraph.  wrow (gap-aware, for moving around) and wlay (fast, on the LIN
;  copy) must follow exactly the same rule.
; ===========================================================================

; HL = physical start of a row.  Out: HL = physical start of the next row,
; A = 1 if the row ended with a line feed, 0 if it wrapped; C = this was the
; last row of the text (HL = BUFE).
wrow:   ld de,(gs)          ; fast way first: 32 characters all on one side
        or a                ; of the gap: CPIR for a line feed, CPDR for a space
        sbc hl,de
        add hl,de
        jr c,wf_b           ; before the gap: the limit is gs
        ld de,(ge)
        or a
        sbc hl,de
        add hl,de
        jr c,wrow_s         ; at the cursor: the careful way
        ld de,BUFE          ; after the gap: the limit is the end
wf_b:   push hl
        ld bc,32
        add hl,bc
        ex de,hl
        or a
        sbc hl,de           ; limit - (start + 32)
        pop hl
        jr c,wrow_s         ; too near the gap or the end
        ld a,10
        cpir
        jr z,wr_lf          ; line feed in the first 32: HL is after it
        push hl
        dec hl
        ld c,32
        ld a,' '
        cpdr
        pop de              ; DE = start + 32
        jr nz,wf_h
        inc hl              ; after the last space
        inc hl
        xor a
        ret
wf_h:   ex de,hl
        xor a
        ret
wrow_s: ld a,(gs)           ; careful way: one character at a time
        ld c,a
        ld b,32
        ld de,0
wr_l:   ld a,l
        cp c
        jr z,wr_g
wr_c:   ld a,l
        or a
        jr z,wr_e
wr_r:   ld a,(hl)
        inc hl
        cp 10
        jr z,wr_lf
        cp ' '
        jr nz,wr_n
        ld d,h
        ld e,l
wr_n:   djnz wr_l
        ld a,d
        or e
        jr z,wr_w
        ex de,hl
wr_w:   xor a
        ret
wr_lf:  ld a,1
        or a
        ret
wr_g:   ld a,(gs+1)
        cp h
        jr nz,wr_c
        ld hl,(ge)
        jr wr_c
wr_e:   ld a,h
        cp BUFE/256
        jr nz,wr_r
        scf
        ret

; row starts are kept in a ring of 16 (RING, ridx, rcnt)
rpush:  ex de,hl            ; HL = position to remember
        ld a,(ridx)
        ld l,a
        inc a
        and 15
        ld (ridx),a
        ld h,0
        add hl,hl
        ld bc,RING
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(rcnt)
        cp 16
        ret z
        inc a
        ld (rcnt),a
        ret

rget:   ld b,a              ; A = k (0 = the last one pushed) -> HL
        ld a,(ridx)
        dec a
        sub b
        and 15
        ld l,a
        ld h,0
        add hl,hl
        ld bc,RING
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; walk the rows of the line starting at HL, remembering their starts, until
; the row holding position (wlim) or the end of the line.  wnext = start of
; the row after the last one walked (text length + 1 at the very end), wlast
; = 1 if that row is the last row of the text.
wline:  xor a
        ld (ridx),a
        ld (rcnt),a
        ld (wlast),a
wl_row: push hl
        call rpush
        pop hl
        call log2phys
        call wrow
        jr c,wl_end
        ld (wlf),a
        call phys2log
        ld (wnext),hl
        ld a,(wlf)
        or a
        ret nz
        ex de,hl
        ld hl,(wlim)
        or a
        sbc hl,de
        ex de,hl
        ret c
        jr wl_row
wl_end: call textlen
        inc hl
        ld (wnext),hl
        ld a,1
        ld (wlast),a
        ret

wcur:   call line_start     ; the rows of the cursor's line, up to its row
        ld de,BUFS
        or a
        sbc hl,de
        ld (wls),hl
        call curpos
        ld (wlim),hl
        ld hl,(wls)
        call wline
        xor a
        call rget
        ld (wcrs),hl
        ret

; HL = start of a row, DE = start of the row after it -> HL = the goal
; column on that row (or its last position)
wtarget: push hl
        ex de,hl
        or a
        sbc hl,de
        dec hl
        ld de,(goal)
        or a
        sbc hl,de
        jr nc,wt_g
        add hl,de
        ex de,hl
wt_g:   pop hl
        add hl,de
        ret

wmv_up: call wcur           ; C if on the first row
        ld hl,(wcrs)
        ld a,h
        or l
        scf
        ret z
        ld a,(rcnt)
        cp 2
        jr c,wu_prev
        ld a,1
        call rget
        ld de,(wcrs)
        jr wu_go
wu_prev: ld hl,(wls)
        call prevls
        ld de,$FFFF
        ld (wlim),de
        call wline
        xor a
        call rget
        ld de,(wls)
wu_go:  call wtarget
gto_nc: call gap_to
        or a
        ret

wmv_down: call wcur         ; C if on the last row
        ld a,(wlast)
        or a
        scf
        ret nz
        ld hl,(wnext)
        push hl
        call log2phys
        call wrow
        jr c,wd_end
        call phys2log
        ex de,hl
        jr wd_go
wd_end: call textlen
        inc hl
        ex de,hl
wd_go:  pop hl
        call wtarget
        jr gto_nc

; ---- drawing in wrap mode
render_wrap:
        ld hl,0
        ld (hs),hl
        call wvis
        call wlin
        call wlay
        ld hl,(curcell)
        ld a,h
        and l
        inc a
        ret nz
        call wback          ; the cursor is below: make its row the bottom row
        call wlin
        jp wlay

wvis:   call wcur           ; keep top a real row start, and not below the cursor
        ld hl,(top)
        ld de,(wcrs)
        or a
        sbc hl,de
        ret z
        jr c,wv_blw
        ld (top),de         ; the cursor is above the screen
        ret
wv_blw: ld hl,(top)
        ld de,(wls)
        or a
        sbc hl,de
        ret c               ; top is in an earlier line: still a row start
        ld a,(rcnt)         ; top is in the cursor's line: snap it to a row
        ld b,a
        ld c,0
wv_s:   ld a,c
        push bc
        call rget
        pop bc
        ex de,hl
        ld hl,(top)
        or a
        sbc hl,de
        jr nc,wv_set
        inc c
        djnz wv_s
wv_set: ld (top),de
        ret

wlin:   call curpos         ; copy the text from top into LIN, straight
        ld de,(top)
        or a
        sbc hl,de
        ld (lincur),hl      ; the cursor's place in LIN
        ld bc,WIN
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,wln_1
        ld h,b
        ld l,c
wln_1:   ld b,h
        ld c,l
        ld hl,(top)
        ld de,BUFS
        add hl,de
        ld de,LIN
        ld a,b
        or c
        jr z,wln_2
        ldir
wln_2:   ld hl,LIN+WIN
        or a
        sbc hl,de
        ld b,h
        ld c,l
        push de
        ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        or a
        sbc hl,bc
        jr nc,wln_3
        add hl,bc
        ld b,h
        ld c,l
wln_3:   pop de
        ld hl,(ge)
        ld a,b
        or c
        jr z,wln_4
        ldir
wln_4:   ld (linend),de
        ld a,10
        ld (de),a
        ret

wlay:   ld hl,$FFFF         ; lay LIN out on the screen rows
        ld (curcell),hl
        ld ix,WRS
        ld hl,LIN
        ld de,SCR+32
        ld a,(docrows)
        ld (rrows),a
wy_row: ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        ld (wscr),de
        ld bc,0
        ld (wsp),bc
        ld b,32
wy_c:   ld a,(hl)
        cp 10
        jr z,wy_lf
        ld (de),a
        inc hl
        inc de
        cp ' '
        jr nz,wy_n
        ld (wsp),hl
wy_n:   djnz wy_c
        ld bc,(wsp)         ; 32 characters, no line end
        ld a,b
        or c
        jr z,wy_nx          ; no space: the next row starts here
        or a
        sbc hl,bc
        ld a,l              ; characters after the last space
        ld h,b
        ld l,c
        or a
        jr z,wy_nx
        ld b,a
        push hl
        ex de,hl
wy_bl:  dec hl
        ld (hl),' '
        djnz wy_bl
        pop hl
wy_nx:  ld de,(wscr)
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        ld a,(rrows)
        dec a
        ld (rrows),a
        jr nz,wy_row
        ld (ix+0),l
        ld (ix+1),h
        jr wy_cur
wy_lf:  ld a,' '            ; line end: blank the rest of the row
wy_lp:  ld (de),a
        inc de
        djnz wy_lp
        push hl
        ld bc,(linend)
        or a
        sbc hl,bc
        pop hl
        inc hl
        jr nz,wy_nx
        ld a,(rrows)        ; end of the text: later rows are empty
        ld b,a
wy_e1:  ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        djnz wy_e1
        ld a,(rrows)
        dec a
        jr z,wy_cur
        ld b,a
        ld hl,(wscr)
        ld de,32
        add hl,de
wy_e2:  ld c,32
wy_e3:  ld (hl),' '
        inc hl
        dec c
        jr nz,wy_e3
        djnz wy_e2
wy_cur: ld hl,(lincur)      ; which row is the cursor on?
        ld de,LIN
        add hl,de
        ld ix,WRS
        ld a,(docrows)
        ld b,a
        ld c,0
wy_f:   ld e,(ix+2)
        ld d,(ix+3)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,wy_got
        inc ix
        inc ix
        inc c
        djnz wy_f
        ret
wy_got: ld e,(ix+0)
        ld d,(ix+1)
        or a
        sbc hl,de
        ld e,l
        ld d,0
        ld l,c
        inc l
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld (curcell),hl
        ret

wback:  ld a,(docrows)      ; top = the row docrows-1 rows above the cursor's
        dec a
        ld (wneed),a
        ld hl,(wcrs)
        ld (top),hl
        ld hl,(wls)
        ld (wtmp),hl
        ld a,1
        ld (wk),a
wb_tk:  ld a,(wk)
        ld hl,rcnt
        cp (hl)
        jr nc,wb_prv
        call rget
        ld (top),hl
        ld hl,wk
        inc (hl)
        ld hl,wneed
        dec (hl)
        ret z
        jr wb_tk
wb_prv: ld hl,(wtmp)
        ld a,h
        or l
        ret z
        call prevls
        ld (wtmp),hl
        ld de,$FFFF
        ld (wlim),de
        call wline
        xor a
        ld (wk),a
        jr wb_tk

c_wrap: ld a,(wrap)         ; CTRL+W
        xor 1
        ld (wrap),a
        ld hl,(top)
        call ls_of
        ld (top),hl
        ld hl,0
        ld (hs),hl
        ld a,(wrap)
        or a
        ld hl,m_wrapoff
        jr z,cw_1
        ld hl,m_wrapon
cw_1:   jp set_msg

; ===========================================================================
;  blocks.  CTRL+K starts marking at the cursor (anchor); moving the cursor
;  extends the block.  selon: 0 none, 1 marking, 2 a find match shown until
;  the next key.
; ===========================================================================
sel_range:                  ; HL = start, DE = end of the block; Z if empty
        call curpos
        ld de,(anchor)
        or a
        sbc hl,de
        ret z
        jr c,sr_1
        add hl,de
        ex de,hl
        ret
sr_1:   add hl,de
        ret

c_mark: ld a,(selon)        ; CTRL+K
        or a
        jr z,cm_on
        xor a
        ld (selon),a
        ld hl,m_markoff
        jp set_msg
cm_on:  call curpos
        ld (anchor),hl
        ld a,1
        ld (selon),a
        ld hl,m_markon
        jp set_msg

c_copy: call blk_get        ; CTRL+J
        ret c
        xor a
        ld (selon),a
        ld hl,m_copied
        jp set_msg

c_cut:  call blk_get        ; CTRL+Y
        ret c
        call blk_rm
        ld hl,m_cut
        jp set_msg

blk_del: call sel_range     ; delete key with a block marked
        call nz,blk_rm
        xor a
        ld (selon),a
        ret

blk_rm: call sel_range      ; remove the block from the text
        push hl
        ex de,hl
        push hl
        call gap_to         ; cursor to the end of the block
        pop hl
        pop de
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(gs)
        or a
        sbc hl,bc
        push hl
        call count_lf
        ld hl,(curln)
        or a
        sbc hl,de
        ld (curln),hl
        pop hl
        ld (gs),hl
        xor a
        ld (selon),a
        inc a
        ld (modified),a
        jp reset_goal

blk_get: ld a,(selon)       ; copy the block to the clipboard; C = not done
        dec a
        jr nz,bg_no
        call sel_range
        jr z,bg_no
        push hl
        push de
        ex de,hl
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(clipmax)
        or a
        sbc hl,bc
        pop de
        pop hl
        jr c,bg_big
        push bc
        push hl
        call curpos
        pop de
        or a
        sbc hl,de
        ld hl,(ge)          ; cursor at the start: the block is after the gap
        jr z,bg_src
        ld hl,BUFS          ; cursor at the end: before the gap
        add hl,de
bg_src: pop bc
        ld (cliplen),bc
        ld de,(clipbase)
        call clip_on
        ldir
        call clip_off
        or a
        ret
bg_big: ld hl,m_clipbig
        jr bg_m
bg_no:  ld hl,m_nomark
bg_m:   call set_msg
        scf
        ret

c_paste: xor a              ; CTRL+P
        ld (selon),a
        ld bc,(cliplen)
        ld a,b
        or c
        ld hl,m_clipempty
        jp z,set_msg
        ld hl,(ge)
        ld de,(gs)
        or a
        sbc hl,de
        or a
        sbc hl,bc
        ld hl,m_full
        jp c,set_msg
        ld hl,(clipbase)
        ld de,(gs)
        push de
        push bc
        call clip_on
        ldir
        call clip_off
        ld (gs),de
        pop bc
        pop hl
        call count_lf
        ld hl,(curln)
        add hl,de
        ld (curln),hl
        ld a,1
        ld (modified),a
        jp reset_goal

clip_on: ld a,(clipbank)
        or a
        ret z
        ld a,3
        out ($37),a
        ret
clip_off: ld a,(clhome)       ; back to what the DOS uses
        out ($37),a
        ret

; The spare 10K SRAM bank (port $37 = 3) holds the clipboard if it is really
; separate from what the DOS uses.  Port $37 can't be read back, so first find
; out what is mapped at $4000-$67FF now (copy it to the empty text buffer and
; see whether setting 1 or 0 shows exactly the same) and always go back to that
; ("clhome").  The bank is used only if it reads differently, and the one test
; write is checked against the home view and put back at once.  Otherwise: the
; 3.3K fallback clipboard in DIRBUF.
clip_init:
        xor a               ; (start-up) no find / replace text yet
        ld (fbuf),a
        ld (rbuf),a
        ld hl,CLIPF
        ld (clipbase),hl
        ld hl,$9600-CLIPF
        ld (clipmax),hl
        ld hl,$4000
        ld de,BUFS
        ld bc,$2800
        ldir
        ld a,1
        call ci_cmp
        jr z,ci_home
        xor a
        call ci_cmp
        jr z,ci_home
        inc a               ; neither (not expected): the loader's usual 1, no bank
ci_home: ld (clhome),a
        ld a,3
        call ci_cmp
        jr z,clip_off       ; looks the same: no separate bank
        ld hl,$4040
        ld e,(hl)           ; the bank's byte
        ld a,e
        cpl
        ld (hl),a
        ld b,(hl)           ; read back
        call clip_off
        ld a,(BUFS+$40)     ; the home byte, as it was
        cp (hl)
        jr nz,ci_bad
        ld a,3
        out ($37),a
        ld (hl),e
        call clip_off
        ld a,e
        cpl
        cp b
        ret nz              ; the bank doesn't keep what is written
        ld a,1
        ld (clipbank),a
        ld hl,CLIPB
        ld (clipbase),hl
        ld hl,$2800
        ld (clipmax),hl
        ret
ci_bad: ld (hl),a           ; the write reached the home view: put it back
        ret
ci_cmp: ld (wk),a            ; A = setting to try.  Z if $4000-$67FF then
        out ($37),a         ; matches the copy.  Returns with A = that setting.
        ld hl,$4000
        ld de,BUFS
        ld bc,$2800
cc_l:   ld a,(de)
        cpi
        jr nz,cc_x
        inc de
        jp pe,cc_l
cc_x:   ld a,(wk)
        ret

; ---- show the block (or find match) on the screen: bit 7 of SCR
sel_show:
        ld a,(selon)
        or a
        ret z
        call sel_range
        ret z
        ld (ss0),hl
        ld (ss1),de
        ld a,(wrap)
        or a
        jr nz,ss_w
        call srows_nw
        jr ss_go
ss_w:   call srows_w
ss_go:  ld hl,SRS
        ld ix,SRP
        ld de,SCR+32
        ld a,(docrows)
        ld b,a
sa_l:   push bc
        push de
        ld a,(ix+0)
        inc ix
        or a
        jr z,sa_n0
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld (sa_n),a
        ld hl,(ss1)
        or a
        sbc hl,bc
        jr c,sa_skp
        jr z,sa_skp
        ld a,h
        or a
        jr nz,sa_hn
        ld a,(sa_n)
        cp l
        jr c,sa_hn
        ld a,l
        jr sa_h
sa_hn:  ld a,(sa_n)
sa_h:   ld (sa_hi),a
        ld hl,(ss0)
        or a
        sbc hl,bc
        ld a,0
        jr c,sa_l0
        ld a,h
        or a
        jr nz,sa_skp
        ld a,l
sa_l0:  ld c,a
        ld a,(sa_hi)
        sub c
        jr c,sa_skp
        jr z,sa_skp
        ld b,a
        ld h,d
        ld l,e
        ld a,c
        add a,l
        ld l,a
        jr nc,sa_s
        inc h
sa_s:   set 7,(hl)
        inc hl
        djnz sa_s
sa_skp: pop hl
        jr sa_nx
sa_n0:  inc hl
        inc hl
sa_nx:  pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        djnz sa_l
        ret

srows_w:                    ; rows from the wrap layout
        ld a,(docrows)
        ld b,a
        ld hl,WRS
        ld de,SRS
        ld ix,SRP
srw_l:  push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or a
        sbc hl,bc
        ld (ix+0),l
        inc ix
        ld hl,(top)
        add hl,bc
        ld bc,$10000-LIN
        add hl,bc
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex de,hl
        pop hl
        pop bc
        djnz srw_l
        ret

srows_nw:                   ; rows = whole lines from top, scrolled by hs
        ld hl,(top)
        ld (wtmp),hl
        ld hl,SRS
        ld (srsp),hl
        ld ix,SRP
        ld a,(docrows)
srn_l:  push af
        ld hl,(wtmp)
        ld a,h
        and l
        inc a
        jr z,srn_0
        push hl
        ld de,(hs)
        add hl,de
        ex de,hl
        ld hl,(srsp)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (srsp),hl
        pop hl
        call next_line
        ld (wtmp),de
        inc hl
        ld de,(hs)
        or a
        sbc hl,de
        jr c,srn_z
        jr z,srn_z
        ld a,h
        or a
        jr nz,srn_32
        ld a,l
        cp 33
        jr c,srn_p
srn_32: ld a,32
        jr srn_p
srn_0:  ld hl,(srsp)
        inc hl
        inc hl
        ld (srsp),hl
srn_z:  xor a
srn_p:  ld (ix+0),a
        inc ix
        pop af
        dec a
        jr nz,srn_l
        ret

; ===========================================================================
;  find / replace (letters match either case)
; ===========================================================================
input_line:                 ; HL = prompt, DE = buffer (length + 22 chars),
        ld (ilp),hl         ; A = 1 if it may be left empty.  C = cancelled.
        ld (ilb),de
        ld (ilemp),a
        xor a
        ld (edmode),a
il_drw: call clr_title
        ld hl,(ilp)
        ld de,SCR
        call puts
        ld hl,(ilb)
        ld a,(hl)
        inc hl
        or a
        jr z,il_cur
        ld c,a
        ld b,0
        ldir
il_cur: ld a,' '+128
        ld (de),a
        call flush
il_k:   call waitkey
        cp K_QUIT
        jr z,il_esc
        cp K_RET
        jr z,il_ok
        cp K_BS
        jr z,il_bs
        cp 32
        jr c,il_k
        cp 127
        jr nc,il_k
        ld c,a
        ld hl,(ilb)
        ld a,(hl)
        cp 22
        jr nc,il_k
        inc (hl)
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld (hl),c
        jr il_drw
il_bs:  ld hl,(ilb)
        ld a,(hl)
        or a
        jr z,il_k
        dec (hl)
        jr il_drw
il_esc: ld a,1
        ld (waitrel),a
        scf
        ret
il_ok:  ld a,1
        ld (waitrel),a
        ld hl,(ilb)
        ld a,(hl)
        or a
        ret nz
        ld a,(ilemp)
        or a
        ret nz
        scf
        ret

ask_find:
        ld hl,s_find
        ld de,fbuf
        xor a
        jp input_line

fold:   cp 'A'              ; A to lower case
        ret c
        cp 'Z'+1
        ret nc
        or $20
        ret

fold_pat:
        ld hl,fbuf
        ld b,(hl)
        inc hl
        ld de,FFOLD
fp_l:   ld a,(hl)
        call fold
        ld (de),a
        inc hl
        inc de
        djnz fp_l
        ret

search:                     ; HL = from, DE = end (physical, no gap between).
        ld a,(fbuf)         ; NC: HL = the match.  C: not found.
        ld c,a
        ld b,0
        ex de,hl
        or a
        sbc hl,bc
        ex de,hl            ; DE = last place a match can start
se_l:   ld a,d
        cp h
        jr c,se_no
        jr nz,se_c
        ld a,e
        cp l
        jr c,se_no
se_c:   ld a,(hl)
        cp 'A'
        jr c,se_f
        cp 'Z'+1
        jr nc,se_f
        or $20
se_f:   ld b,a
        ld a,(FFOLD)
        cp b
        jr z,se_m
se_n:   inc hl
        jr se_l
se_m:   push hl
        push de
        ld de,FFOLD
        ld b,c
se_mc:  ld a,(hl)
        call fold
        ex de,hl
        cp (hl)
        ex de,hl
        jr nz,se_mx
        inc hl
        inc de
        djnz se_mc
        pop de
        pop hl
        or a
        ret
se_mx:  pop de
        pop hl
        jr se_n
se_no:  scf
        ret

c_find: call ask_find        ; CTRL+F
        ret c
        ld hl,0
        jr do_find
c_next: ld a,(fbuf)         ; CTRL+G: the next one
        or a
        jr z,c_find
        ld hl,1
do_find:
        push hl
        call fold_pat
        pop bc
        ld hl,(ge)
        add hl,bc
        ld de,BUFE
        call search
        jr nc,df_got
        call curpos         ; not after the cursor: try from the top
        ld (fsave),hl
        call gap_to_end
        ld hl,BUFS
        ld de,(gs)
        call search
        jr nc,df_g2
        ld hl,(fsave)
        call gap_to
        ld hl,m_notfound
        jp set_msg
df_g2:  ld de,BUFS
        or a
        sbc hl,de
        jr df_go
df_got: call phys2log
df_go:  push hl
        call gap_to
        pop hl
        ld a,(fbuf)
        ld e,a
        ld d,0
        add hl,de
        ld (anchor),hl      ; show the match until the next key
        ld a,2
        ld (selon),a
        jp reset_goal

c_repl: call ask_find        ; CTRL+E: replace, from the cursor to the end
        ret c
        ld hl,s_repl
        ld de,rbuf
        ld a,1
        call input_line
        ret c
        call fold_pat
        ld hl,0
        ld (rcount),hl
        xor a
        ld (rall),a
        ld (selon),a
rp_l:   ld hl,(ge)
        ld de,BUFE
        call search
        jp c,rp_done
        call phys2log
        push hl
        call gap_to
        pop hl
        ld a,(rall)
        or a
        jr nz,rp_do
        ld a,(fbuf)
        ld e,a
        ld d,0
        add hl,de
        ld (anchor),hl
        ld a,2
        ld (selon),a
        call reset_goal
        call render
        ld a,1
        ld (askall),a
        ld hl,m_replq
        call ask_yn
        ld b,a
        xor a
        ld (askall),a
        ld (selon),a
        ld a,b
        or a
        jr z,rp_done
        cp 'N'
        jr z,rp_skip
        cp 'A'
        jr nz,rp_do
        ld a,1
        ld (rall),a
rp_do:  ld a,(fbuf)         ; the match goes, the new text comes in
        ld c,a
        ld b,0
        ld hl,(ge)
        add hl,bc
        ld (ge),hl
        ld de,(gs)
        or a
        sbc hl,de
        ld a,(rbuf)
        ld c,a
        or a
        sbc hl,bc
        jr c,rp_full
        ld hl,rbuf+1
        ld de,(gs)
        ld a,c
        or a
        jr z,rp_d1
        ldir
rp_d1:  ld (gs),de
        ld a,1
        ld (modified),a
        ld hl,(rcount)
        inc hl
        ld (rcount),hl
        jp rp_l
rp_skip: ld bc,1
        call gap_right
        jp rp_l
rp_full: ld hl,m_full
        jp set_msg
rp_done: call reset_goal
        ld hl,(rcount)
        ld de,msgbuf
        call putdec16
        ld hl,s_replaced
        call puts
        xor a
        ld (de),a
        ld hl,msgbuf
        jp set_msg
