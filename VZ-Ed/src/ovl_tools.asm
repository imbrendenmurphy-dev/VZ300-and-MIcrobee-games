; ===========================================================================
;  ovl_tools.asm (0.7) - overlay slot 7: bookmarks, go to line, word count.
;  ovkey (set by c_ovl) says which:
;    K_MK1..K_MK1+8  CTRL+1..9   go to bookmark 1..9
;    K_SETMK         CTRL+0      set a bookmark at the cursor (then 1-9)
;    K_GOTO          menu        go to a line number
;    K_INFO          menu        words, lines and characters (of the block if marked)
;  The bookmarks themselves (marks) are kept up to date by undo.asm.
;  Like every overlay: never moves the gap; C + HL = move the cursor there.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)
zt_go:  ld a,(ovkey)
        cp K_MK1
        jr nc,zt_mark
        cp K_SETMK
        jp z,zt_set
        cp K_INFO
        jp z,zt_info

; ---- go to line
        xor a
        ld (zt_buf),a
        ld hl,zt_ask
        ld de,zt_buf
        call input_line
        jr nc,zg_p
        xor a               ; cancelled: NC, nothing to do
        ret
zg_p:   ld hl,zt_buf
        ld b,(hl)
        inc hl
        ld de,0             ; DE = the number typed
zg_d:   ld a,(hl)
        sub '0'
        cp 10
        jr nc,zg_bad
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl           ; * 10
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        djnz zg_d
        ld hl,(lnbase)      ; (0.8) a part of a big file: lines before it
        ex de,hl
        or a
        sbc hl,de
        ex de,hl
        jr nc,zg_0
        ld de,0
zg_0:   ld a,d              ; line 0 = line 1
        or e
        jr nz,zg_1
        inc de
zg_1:   ld hl,0             ; walk to it (or to the last line)
zg_l:   dec de
        ld a,d
        or e
        jr z,zg_ok
        push de
        push hl
        call next_line      ; DE = next line start, $FFFF = none
        pop hl
        ld a,d
        and e
        inc a
        jr z,zg_last
        ex de,hl
        pop de
        jr zg_l
zg_last: pop de
zg_ok:  scf
        ret
zg_bad: ld hl,zt_mbad
        call zl_msg
        xor a
        ret

; ---- CTRL+1..9: go to a bookmark
zt_mark: sub K_MK1
        ld (zt_n),a
        call zt_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        and h
        inc a
        jr z,zm_no
        push hl             ; past the end (never expected): the end
        call textlen
        pop de
        or a
        sbc hl,de
        jr c,zm_end
        ex de,hl
        scf
        ret
zm_end: add hl,de
        scf
        ret
zm_no:  ld hl,zt_mno        ; "NO MARK n"
        ld de,zt_out
        call puts
        call zt_dig
        jr zt_show

; ---- CTRL+0: set one
zt_set: xor a
        ld (edmode),a
        call clr_title
        ld hl,zt_mask
        ld de,SCR
        call puts
        call flush
zs_k:   call waitkey
        cp K_MK1            ; CTRL+digit works too
        jr c,zs_a
        cp K_MK1+9
        jr nc,zs_no
        sub K_MK1-'1'
zs_a:   sub '1'
        cp 9
        jr nc,zs_no
        ld (zt_n),a
        call zt_ptr
        push hl
        call curpos
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,zt_mset       ; "MARK n SET"
        ld de,zt_out
        call puts
        call zt_dig
        ld hl,zt_mset2
        call puts
zt_show: xor a
        ld (de),a
        ld hl,zt_out
        call zl_msg
        xor a
        ret
zs_no:  xor a               ; any other key: nothing
        ret

zt_ptr: ld a,(zt_n)         ; HL = &marks[zt_n]
        add a,a
        ld e,a
        ld d,0
        ld hl,marks
        add hl,de
        ret
zt_dig: ld a,(zt_n)         ; the bookmark's digit at DE
        add a,'1'
        ld (de),a
        inc de
        ret

; ---- word count
zt_info: ld hl,0
        ld (zt_w),hl
        ld (zt_lf),hl
        xor a
        ld (zt_in),a
        ld a,(selon)
        dec a
        jr nz,zi_all
        call sel_range      ; a marked block: just that (all on one side of the gap)
        jr z,zi_all
        push hl
        ex de,hl
        or a
        sbc hl,de
        ld (zt_ch),hl
        ld b,h
        ld c,l
        pop hl
        call log2phys
        call zi_cnt
        ld hl,zt_mblk
        jr zi_out
zi_all: call textlen
        ld (zt_ch),hl
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        call zi_cnt
        ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        call zi_cnt
        ld hl,zt_mnone
zi_out: ld de,zt_out        ; "[BLOCK ]n WORDS n LINES n CHARS"
        call puts
        ld hl,(zt_w)
        call putdec16
        ld hl,zt_mw
        call puts
        ld hl,(zt_lf)
        inc hl
        call putdec16
        ld hl,zt_ml
        call puts
        ld hl,(zt_ch)
        call putdec16
        ld hl,zt_mc
        call puts
        xor a
        ld (de),a
        ld (edmode),a
        call clr_title      ; on the title bar until a key is pressed
        ld hl,zt_out
        ld de,SCR
        ld b,32
zi_c:   ld a,(hl)
        or a
        jr z,zi_s
        ld (de),a
        inc hl
        inc de
        djnz zi_c
zi_s:   call flush
        call waitkey
        xor a
        ret

zi_cnt:                     ; HL = text, BC = length: count words and LFs
        ld a,b
        or c
        ret z
zc_l:   ld a,(hl)
        inc hl
        cp 10
        jr nz,zc_nlf
        push hl
        ld hl,(zt_lf)
        inc hl
        ld (zt_lf),hl
        pop hl
zc_nlf: cp 33
        jr c,zc_sp
        ld a,(zt_in)
        or a
        jr nz,zc_n
        inc a
        ld (zt_in),a
        push hl
        ld hl,(zt_w)
        inc hl
        ld (zt_w),hl
        pop hl
        jr zc_n
zc_sp:  xor a
        ld (zt_in),a
zc_n:   dec bc
        ld a,b
        or c
        jr nz,zc_l
        ret

zl_msg: ld de,msgbuf         ; message (11 characters at most) via msgbuf:
        ld bc,11            ; the overlay area may be gone before it shows
zl_cp:  ld a,(hl)
        ld (de),a
        or a
        jr z,zl_sh
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,zl_cp
        xor a
        ld (de),a
zl_sh:  ld hl,msgbuf
        jp set_msg

zt_ask: db "GO TO LINE: ",0
zt_mbad: db "LINE NO.?",0
zt_mno: db "NO MARK ",0
zt_mask: db "BOOKMARK: PRESS 1-9 (^Q NO)",0
zt_mset: db "MARK ",0
zt_mset2: db " SET",0
zt_mblk: db "BLOCK ",0
zt_mnone: db 0
zt_mw:  db " WORDS ",0
zt_ml:  db " LINES ",0
zt_mc:  db " CHARS",0

; work RAM (not in the file)
zt_buf  equ $               ; length + 22 characters
zt_out  equ zt_buf+24       ; 48 bytes
zt_n    equ zt_out+48
zt_w    equ zt_n+1
zt_lf   equ zt_w+2
zt_ch   equ zt_lf+2
zt_in   equ zt_ch+2
        assert zt_in+1 <= OVLEND
