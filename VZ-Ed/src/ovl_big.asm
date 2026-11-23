; ===========================================================================
;  ovl_big.asm (0.8) - overlay slot 9: text files too big for the text buffer
;  (up to 65,535 bytes) are edited in parts of about 6K.
;
;  State (vars): bigmode 1 while editing a part; bsrc / bsz = the file on the
;  card the parts come from (first cluster, size); bws / bwl = where the part
;  in the buffer starts in that file and how many bytes of it (as on the card,
;  with CRs) it replaced; bwlf = its line ends; lnbase = lines before it (the
;  title bar adds it to the line number).
;  bigop: 0 open (from ovl_vzopen via K_BIG: ldcl / ldsz), 1 the next part,
;         2 the part before, 3 save (from save_doc: the whole file is written
;         again as VZEDTEMP.$$$ = the file before the part + the part + the file
;         after it, then save_doc's .BAK and rename steps).
;  The source is read with its own sector buffer (zRB), never SECBUF, because
;  saving writes through SECBUF at the same time.  The cluster chain is read
;  into zSL first (at most 128 clusters).
;  Loading a part replaces the text: a parked small clipboard (ovl.asm) is
;  moved to BUFS first and stays at gs, where ov_unstash looks for it.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)

MAXW    equ 6144            ; bytes of the file in one part (at most)

zb_go:  ld a,1
        ld (waitrel),a
        ld a,(bigop)
        cp 3
        jp z,zs_save
        or a
        jr nz,zb_np
        ld hl,(ldcl)        ; open: the file from the list
        ld (bsrc),hl
        ld a,(ldcl+2)
        ld (bsrc+2),a
        ld hl,(ldsz)
        ld (bsz),hl
        ld hl,0
        ld (bws),hl
        ld (bwl),hl
        ld (bwlf),hl
        ld (lnbase),hl
        xor a
        ld (crlf),a
zb_np:  call zr_list
        jp c,zb_bad
        ld a,(bigop)
        ld (zOp),a
        ld hl,(bwlf)        ; lines of the old part (as on the card)
        ld (zOld),hl
        ; ---- where the new part starts, and how much to read
        cp 2
        jr z,zb_prev
        ld hl,(bws)         ; open / next: right after the old part
        ld de,(bwl)
        add hl,de
        ld (zS),hl
        ex de,hl
        ld hl,(bsz)
        or a
        sbc hl,de           ; bytes left in the file
        ld de,MAXW
        call zmin
        ld (zN),hl
        jr zb_ld
zb_prev: ld hl,(bws)        ; before: up to MAXW bytes ending at the old part
        ld de,MAXW
        call zmin
        ld (zN),hl
        ex de,hl
        ld hl,(bws)
        or a
        sbc hl,de
        ld (zS),hl
zb_ld:  call zl_park        ; (the old text is given up from here on)
        call zl_read
        ; ---- cut the part
        ld a,(zOp)
        cp 2
        jr nz,zb_cutend
        ld hl,(zS)          ; before: start after the first line end (unless at 0)
        ld a,h
        or l
        jr z,zb_all
        ld hl,(zFR)
        ld a,h
        or l
        jr z,zb_all         ; (a line longer than a part: take it all)
        ld de,(zS)
        add hl,de
        ld (zS),hl
        ld hl,(zFD)
        ld (zT0),hl
        ld hl,(zLF)
        dec hl
        ld (zLF),hl
        jr zb_len
zb_cutend: ld hl,(zS)       ; open / next: end after the last line end, unless
        ld de,(zR)          ; this is the end of the file
        add hl,de
        ld de,(bsz)
        or a
        sbc hl,de
        jr nc,zb_all
        ld hl,(zLR)
        ld a,h
        or l
        jr z,zb_nolf
        ld (zR),hl
        ld hl,(zLD)
        ld (zD),hl
        jr zb_all
zb_nolf: ld a,(zCRl)        ; no line end at all: don't split a CR LF
        or a
        jr z,zb_all
        ld hl,(zR)
        dec hl
        ld (zR),hl
zb_all:
zb_len: ld a,(zOp)          ; bwl = the bytes of the file this part covers
        cp 2
        jr nz,zb_l1
        ld hl,(bws)         ; before: from zS up to the old part
        ld de,(zS)
        or a
        sbc hl,de
        jr zb_l2
zb_l1:  ld hl,(zR)
zb_l2:  ld (bwl),hl
        ld hl,(zS)
        ld (bws),hl
        ld hl,(zLF)
        ld (bwlf),hl
        ; ---- line numbers
        ld a,(zOp)
        or a
        jr z,zb_ln          ; open: 0
        ld hl,(lnbase)
        cp 2
        jr z,zb_lp
        ld de,(zOld)        ; next: + the old part's lines
        add hl,de
        jr zb_lns
zb_lp:  ld de,(zLF)         ; before: - this part's lines
        or a
        sbc hl,de
        jr nc,zb_lns
zb_ln:  ld hl,0
zb_lns: ld (lnbase),hl
        ; ---- the part to the top of the buffer (cursor at the start)
        ld hl,(zD)
        ld de,(zT0)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,BUFE
        ld a,b
        or c
        jr z,zb_mv0
        ld hl,(zD)
        dec hl
        ld de,BUFE-1
        lddr
        inc de
        ex de,hl
zb_mv0: ld (ge),hl
        ld hl,BUFS
        ld (gs),hl
        ld a,(zOp)          ; crlf: from the first part (as load_file does)
        or a
        jr nz,zb_st
        ld a,(zCR)
        or a
        jr nz,zb_cr1
        ld hl,(zLF)
        ld a,h
        or l
        jr z,zb_cr1
        xor a               ; line ends but no CR: LF only
        jr zb_cr0
zb_cr1: ld a,1
zb_cr0: ld (crlf),a
zb_st:  ld hl,1
        ld (curln),hl
        ld hl,0
        ld (top),hl
        ld (hs),hl
        xor a
        ld (modified),a
        ld (selon),a
        ld (trunc),a
        ld (basmode),a
        call un_clr         ; no undo history / bookmarks from the old part
        ld a,1
        ld (bigmode),a
        ld (ovok),a
        ld a,(zOp)          ; a word on the title bar
        ld hl,zm_big
        or a
        jr z,zb_msg
        ld hl,zm_part
        cp 1
        jr z,zb_msg
        ld hl,zm_prev
zb_msg: call zl_msg
        ld a,(zOp)
        cp 2
        ld hl,0
        jr nz,zb_ret
        call textlen        ; before: the cursor at its end (where it came from)
zb_ret: scf                 ; C: ovl_run moves the cursor to HL
        ret
zb_bad: ld hl,m_trunc       ; the chain doesn't cover the file
        call set_msg
        xor a
        ret

zmin:   push hl             ; HL = min(HL, DE)
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; ---- the source's clusters -> zSL (3 bytes each).  C = the chain is short.
zr_list: ld hl,(bsz)
        ld e,0
        ld c,0
zrl_n:  ld a,h              ; clusters needed (as write_new counts them)
        or l
        or e
        jr z,zrl_c
        inc c
        push bc
        ld bc,bpc
        call subm24
        pop bc
        jr nc,zrl_n
zrl_c:  ld a,c
        ld (zNC),a
        cp 129
        ccf
        ret c
        ld hl,bsrc
        call ld24
        ld ix,zSL
        ld a,(zNC)
        or a
        ret z
        ld b,a
zrl_l:  push bc
        call clvalid
        pop bc
        jr c,zrl_x
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+2),e
        inc ix
        inc ix
        inc ix
        dec b
        jr z,zrl_ok
        push bc
        call fat_get
        pop bc
        or a
        jr z,zrl_l
zrl_x:  call fat_sync
        scf
        ret
zrl_ok: call fat_sync
        or a
        ret

; ---- reading the source: zr_seek HL = offset, then zr_get A = next byte
zr_seek: ld a,l             ; byte in the sector
        ld (zBp),a
        ld a,h
        and 1
        ld (zBp+1),a
        ld a,h              ; sector number in the file = offset >> 9
        srl a
        ld c,a
        ld a,(spc)
        dec a
        and c
        ld (zSs),a          ; sector in its cluster
        ld a,(sh)
        or a
        jr z,zsk_c
        ld b,a
zsk_l:  srl c
        djnz zsk_l
zsk_c:  ld a,c
        ld (zCi),a          ; cluster index
        ld hl,(zBp)
        ld de,zRB
        add hl,de
        ld (zBp),hl
        ld a,1
        ld (zNeed),a
        ret

zr_get: ld a,(zNeed)        ; A = the next byte of the source (BC DE HL kept)
        or a
        call nz,zr_read
        push hl
        ld hl,(zBp)
        ld a,(hl)
        inc hl
        ld (zBp),hl
        push af
        ld a,h
        cp (zRB+512)/256
        jr nz,zg_x
        ld hl,zRB
        ld (zBp),hl
        ld a,1
        ld (zNeed),a
        ld a,(zSs)
        inc a
        ld hl,spc
        cp (hl)
        jr nz,zg_s
        ld hl,zCi
        inc (hl)
        xor a
zg_s:   ld (zSs),a
zg_x:   pop af
        pop hl
        ret

zr_read: push bc
        push de
        push hl
        xor a
        ld (zNeed),a
        ld a,(zCi)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,zSL
        add hl,de
        call ld24
        ld a,(zSs)
        call clus_lba
        call dos_nocache
        ld bc,zRB
        ld ($FB80),bc
        ld d,0
        call DOS_RDSEC
        di
        ld hl,SECBUF
        ld ($FB80),hl
        pop hl
        pop de
        pop bc
        ret

; ---- park: the small clipboard (if it was parked at gs) to BUFS
zl_park: ld hl,BUFS
        ld (zT0),hl
        ld a,(ovst)
        cp 1
        ret nz
        ld bc,(cliplen)
        ld hl,(gs)
        ld de,BUFS
        ld a,b
        or c
        jr z,zp_e
        ldir
zp_e:   ld (zT0),de
        ret

; ---- read zN bytes from zS into the buffer at zT0, leaving out CRs.
; zR raw bytes read, zD end; zLR/zLD raw/dest after the last LF, zFR/zFD after
; the first LF (0 = none), zLF line ends, zCR any CR seen, zCRl the last byte was CR.
zl_read: ld hl,(zS)
        call zr_seek
        ld hl,(zT0)
        ld (zD),hl
        ld hl,0
        ld (zR),hl
        ld (zLR),hl
        ld (zFR),hl
        ld (zLF),hl
        xor a
        ld (zCR),a
zr_l:   ld hl,(zR)
        ld de,(zN)
        or a
        sbc hl,de
        ret z
        call zr_get
        ld hl,(zR)
        inc hl
        ld (zR),hl
        ld b,a
        xor a
        ld (zCRl),a
        ld a,b
        cp 13
        jr nz,zr_s
        ld a,1
        ld (zCR),a
        ld (zCRl),a
        jr zr_l
zr_s:   ld hl,(zD)
        ld (hl),a
        inc hl
        ld (zD),hl
        cp 10
        jr nz,zr_l
        ld (zLD),hl
        ld de,(zR)
        ld (zLR),de
        ld hl,(zLF)
        inc hl
        ld (zLF),hl
        ld hl,(zFR)
        ld a,h
        or l
        jr nz,zr_l
        ld (zFR),de
        ld hl,(zD)
        ld (zFD),hl
        jr zr_l

; ---- save: the file again as VZEDTEMP.$$$ with this part in it, then .BAK / rename
zs_save: ld hl,m_saving
        call show_status
        ld hl,s_tmpname     ; an old temp file goes (unless it is our source)
        call cwd_find
        jr c,zs_1
        ld hl,(dwptr)
        ld bc,26
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(bsrc)
        or a
        sbc hl,de
        jr nz,zs_del
        ld hl,(dwptr)
        ld bc,20
        add hl,bc
        ld a,(bsrc+2)
        cp (hl)
        jr nz,zs_del
        ld hl,zm_tmp        ; editing VZEDTEMP.$$$ itself: save it as something else
        call zl_msg
        jp zs_x
zs_del: call del_entry
zs_1:   call zr_list
        ld hl,m_trunc
        jp c,zs_fail
        ld hl,(gs)          ; the part as it will be on the card
        ld de,BUFS
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,BUFS
        call count_lf
        push de
        ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        call count_lf
        pop hl
        add hl,de
        ld (zLF),hl         ; its line ends
        ld a,(crlf)
        or a
        jr nz,zs_2
        ld hl,0
zs_2:   push hl
        call textlen
        pop de
        add hl,de
        ld (zR),hl          ; its bytes
        ld de,(bsz)         ; the new size: bsz - bwl + zR (at most 65,535)
        add hl,de
        ld a,0
        adc a,a
        ld de,(bwl)
        or a
        sbc hl,de
        sbc a,0
        ld (outlen),hl
        ld hl,m_toobig
        jp nz,zs_fail
        ld hl,(outlen)      ; clusters (write_new's count)
        ld e,0
        ld c,0
zs_cl:  ld a,h
        or l
        or e
        jr z,zs_cd
        inc c
        push bc
        ld bc,bpc
        call subm24
        pop bc
        jr nc,zs_cl
zs_cd:  ld a,c
        ld (wncl),a
        cp 129
        ld hl,m_cardfull
        jp nc,zs_fail
        call alloc_chain
        ld hl,m_cardfull
        jp c,zs_fail
        xor a
        ld (wci),a
        ld (wsec),a
        ld hl,SECBUF
        ld (wpos),hl
        ld hl,0             ; the file before the part
        ld de,(bws)
        call zs_copy
        ld hl,BUFS          ; the part
        ld de,(gs)
        ex de,hl
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        ld a,(crlf)
        ld (wcrlf),a
        call wseg
        ld hl,BUFE
        ld de,(ge)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ex de,hl
        call wseg
        ld hl,(bws)         ; the file after it
        ld de,(bwl)
        add hl,de
        push hl
        ex de,hl
        ld hl,(bsz)
        or a
        sbc hl,de
        ex de,hl
        pop hl
        call zs_copy
        ld hl,cwd           ; the directory entry (the end of write_new)
        call ld24
        ld bc,wdir
        call st24
        ld hl,s_tmpname
        call setname
        call zs_end
        ld hl,m_cardfull
        jr c,zs_fail
        ld hl,(wfirst)      ; this file is the source from now on
        ld (zNs),hl
        ld a,(wfirst+2)
        ld (zNs+2),a
        ld hl,(outlen)
        ld (zNz),hl
        call sv_3           ; save_doc: NAME -> NAME.BAK, temp -> NAME
        jr c,zs_x           ; (its message is up)
        ld hl,(zNs)
        ld (bsrc),hl
        ld a,(zNs+2)
        ld (bsrc+2),a
        ld hl,(zNz)
        ld (bsz),hl
        ld hl,(zR)
        ld (bwl),hl
        ld hl,(zLF)
        ld (bwlf),hl
        ld a,1
        ld (ovok),a
        xor a
        ret
zs_fail: call set_msg       ; (messages of the main program: they stay)
zs_x:   xor a               ; NC, nothing for ovl_run to do
        ld (ovok),a
        ret

zs_end: ld hl,(wpos)        ; as write_new ends: pad the last sector, the entry
        ld a,l
        or a
        jp nz,wn_z
        ld a,h
        cp SECBUF/256
        jp nz,wn_z
        jp wn_ent

zs_copy: ld (zCnt),de       ; HL = offset, DE = count: source -> the new file
        call zr_seek
zc_l:   ld hl,(zCnt)
        ld a,h
        or l
        ret z
        dec hl
        ld (zCnt),hl
        call zr_get
        call wputb
        jr zc_l

zl_msg: ld de,msgbuf        ; message via msgbuf (11 characters at most): the
        ld bc,11            ; overlay area may be gone before it shows
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

zm_big: db "IN 6K PARTS",0
zm_part: db "NEXT PART",0
zm_prev: db "PART BEFORE",0
zm_tmp: db "USE SAVE AS",0

; work RAM (not in the file)
zOp     equ $
zOld    equ zOp+1
zS      equ zOld+2
zN      equ zS+2
zR      equ zN+2
zD      equ zR+2
zT0     equ zD+2
zLR     equ zT0+2
zLD     equ zLR+2
zFR     equ zLD+2
zFD     equ zFR+2
zLF     equ zFD+2
zCR     equ zLF+2
zCRl    equ zCR+1
zNC     equ zCRl+1
zBp     equ zNC+1
zSs     equ zBp+2
zCi     equ zSs+1
zNeed   equ zCi+1
zCnt    equ zNeed+1
zNs     equ zCnt+2
zNz     equ zNs+3
zEND    equ zNz+2
zSL     equ $9200           ; 128 clusters x 3
zRB     equ $9400           ; source sector buffer (page aligned)
        assert zEND <= zSL
        assert zSL+384 <= zRB
        assert zRB+512 <= OVLEND
