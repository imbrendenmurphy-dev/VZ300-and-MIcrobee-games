; ===========================================================================
;  ovl_vzopen.asm - overlay slot 5 (0.6): opening a .VZ file, or a file too
;  big for the text buffer (from open_file in ovl.asm; ldcl / ldsz are set).
;
;  * A BASIC program (.VZ, type $F0) that fits is read raw to the top of the
;    text buffer and listed into the bottom of it, the way the ROM's LIST
;    shows it (tools/basic.py is the model): line number, a space, keywords
;    for tokens; a ':' just before ELSE or REM' isn't shown; REM, ' and quotes
;    are kept as they are, DATA up to the next ':'.  The header (name, load
;    address) goes to bashdr and basmode = 1, so saving as .VZ tokenises again.
;  * Anything else (machine code, BASIC with code after the program, files
;    over 12K) is shown in a read-only hex viewer straight from the card.
;  ovok = 1 when a program was loaded; 0 leaves the old document (unless it
;  was already overwritten: then the editor is left empty and untitled).
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)

zv_go:  ld a,1
        ld (waitrel),a
        ld a,(fs_ok)
        or a
        jr nz,zv_1
        ld hl,m_nofs
        call set_msg
        xor a
        ret
zv_1:   call zv_big         ; (0.8) a big text file: edited in parts (slot 9)
        ret nc
        ld a,(ldsz+2)       ; a BASIC program that fits?
        or a
        jp nz,zx_go
        ld hl,(ldsz)
        ld de,BUFE-BUFS+1
        or a
        sbc hl,de
        jp nc,zx_go
        ld hl,(ldsz)
        ld de,26
        or a
        sbc hl,de
        jp c,zx_go
        ld hl,ldcl          ; its header
        call ld24
        call clvalid
        jp c,zx_go
        call fat_sync
        ld hl,ldcl
        call ld24
        xor a
        call clus_lba
        call rd_sec
        ld a,(SECBUF)
        cp 'V'
        jp nz,zx_go
        ld a,(SECBUF+1)
        cp 'Z'
        jp nz,zx_go
        ld a,(SECBUF+2)
        cp 'F'
        jp nz,zx_go
        ld a,(SECBUF+21)
        cp $F0
        jp nz,zx_go
        call zv_load        ; (from here on the old text is gone)
        jp c,zv_bad
        ld hl,(zD)          ; name and load address -> bashdr
        ld bc,4
        add hl,bc
        ld de,bashdr
        ld bc,17
        ldir
        inc hl
        ld bc,2
        ldir
        call zd_detok
        jp c,zv_bad         ; code after the program, or not a program
        ld a,(zOv)
        or a
        jp nz,zv_bg2
        ld hl,(zWP)         ; the listing to the end of the buffer
        ld de,BUFS
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        ld hl,BUFE
        jr z,zv_e
        ld hl,(zWP)
        dec hl
        ld de,BUFE-1
        lddr
        inc de
        ex de,hl
zv_e:   ld (ge),hl
        ld hl,BUFS
        ld (gs),hl
        ld hl,1
        ld (curln),hl
        ld hl,0
        ld (top),hl
        ld (hs),hl
        xor a
        ld (modified),a
        ld (selon),a
        ld (trunc),a
        inc a
        ld (crlf),a         ; (saved as .TXT it gets CR LF)
        ld (basmode),a
        ld (ovok),a
        ld (caps),a         ; capitals, as on the VZ (CTRL+U turns it off)
        call reset_goal
        call un_clr         ; (0.7) no undo history / bookmarks from the old text
        xor a
        ld (bigmode),a      ; (0.8)
        ld h,a
        ld l,a
        ld (lnbase),hl
        xor a
        ret
zv_bgx: scf
        ret
zv_big: ld a,(ldsz+2)       ; (0.8) NC + A = K_BIG if it is a big text file:
        or a                ; under 64K, too big for the buffer, not a .VZ
        jr nz,zv_bgx        ; (no "VZF" header) and no 0 byte in its first sector
        ld hl,(ldsz)
        ld de,BUFE-BUFS+1
        or a
        sbc hl,de
        jr c,zv_bgx
        ld hl,ldcl
        call ld24
        call clvalid
        ret c
        call fat_sync
        ld hl,ldcl
        call ld24
        xor a
        call clus_lba
        call rd_sec
        ld hl,(SECBUF)
        ld de,'V'+256*'Z'
        or a
        sbc hl,de
        jr nz,zb_t
        ld a,(SECBUF+2)
        cp 'F'
        jr z,zv_bgx
zb_t:   ld hl,SECBUF
        ld bc,512
        xor a
        cpir
        jr z,zv_bgx         ; a 0 byte: not text
        ld (bigop),a
        ld a,K_BIG
        ret
zv_bg2: call zv_clr
        ld hl,m_toobig
        call set_msg
        xor a
        ret
zv_bad: call zv_clr         ; not editable: look at it in hex
        jp zx_go
zv_clr: call buf_clear      ; the old text was overwritten: an empty, new one
        xor a
        ld (named),a
        ret

; ---- the whole file to BUFE-size (zD), raw.  C = the file ended early.
zv_load: ld hl,BUFE
        ld de,(ldsz)
        or a
        sbc hl,de
        ld (lddst),hl
        ld (zD),hl
        ld hl,(ldsz)
        ld (ldrem),hl
        ld hl,(ldcl)
        ld (ldcur),hl
        ld a,(ldcl+2)
        ld (ldcur+2),a
zl_cl:  ld hl,ldcur
        call ld24
        call clvalid
        ret c
        xor a
        ld (lsec),a
zl_sec: call fat_sync
        ld hl,ldcur
        call ld24
        ld a,(lsec)
        call clus_lba
        call rd_sec
        ld hl,(ldrem)
        ld bc,512
        or a
        sbc hl,bc
        jr nc,zl_st
        add hl,bc
        ld b,h
        ld c,l
        ld hl,0
zl_st:  ld (ldrem),hl
        ld hl,SECBUF
        ld de,(lddst)
        ldir
        ld (lddst),de
        ld hl,(ldrem)
        ld a,h
        or l
        jr z,zl_done
        ld a,(lsec)
        inc a
        ld (lsec),a
        ld b,a
        ld a,(spc)
        cp b
        jr nz,zl_sec
        ld hl,ldcur
        call ld24
        call fat_get
        or a
        jr nz,zl_short
        ld bc,ldcur
        call st24
        jr zl_cl
zl_done: call fat_sync
        or a
        ret
zl_short: call fat_sync
        scf
        ret

; ---- LIST: program at zD+24 .. BUFE -> text from BUFS (zWP).
; C = not a program, or bytes after its end; zOv = 1: the text didn't fit.
zd_detok: ld hl,(zD)
        ld bc,24
        add hl,bc
        ld (zRP),hl
        ld hl,BUFS
        ld (zWP),hl
        xor a
        ld (zOv),a
zd_line: call zd_rd         ; link (0 = the end)
        ret c
        ld c,a
        call zd_rd
        ret c
        or c
        jp z,zd_end
        call zd_rd          ; line number
        ret c
        ld c,a              ; (zd_rd uses HL)
        call zd_rd
        ret c
        ld h,a
        ld l,c
        ld de,zNB
        call putdec16
        ld hl,zNB
zd_ln:  ld a,l              ; (DE = after the digits)
        cp e
        jr z,zd_ln2
        ld a,(hl)
        call zd_wr
        inc hl
        jr zd_ln
zd_ln2: ld a,' '
        call zd_wr
        xor a
        ld (zMode),a        ; 0 plain, 1 quote, 2 REM to the end, 3 DATA to ':'
zd_b:   call zd_rd
        ret c
        or a
        jp z,zd_eol
        ld b,a
        ld a,(zMode)
        cp 2
        jp z,zd_raw
        cp 1
        jr nz,zd_n1
        ld a,b              ; in quotes
        call zd_wr
        cp '"'
        jr nz,zd_b
zd_m0:  xor a
        ld (zMode),a
        jr zd_b
zd_n1:  ld a,b
        cp '"'
        jr nz,zd_n2
        call zd_wr
        ld a,1
        ld (zMode),a
        jr zd_b
zd_n2:  ld a,(zMode)
        cp 3
        jr nz,zd_n3
        ld a,b              ; DATA
        call zd_wr
        cp ':'
        jr nz,zd_b
        jr zd_m0
zd_n3:  ld a,b
        cp ':'
        jr nz,zd_n4
        call zd_pk          ; ':' just before ELSE or REM': not shown
        jr c,zd_raw
        cp $95
        jr z,zd_b
        cp $93
        jr nz,zd_raw
        call zd_pk2
        jr c,zd_raw
        cp $FB
        jr z,zd_b
        jr zd_raw
zd_n4:  cp $80
        jr c,zd_raw
        cp $93
        jr nz,zd_k
        call zd_pk
        jr c,zd_k
        cp $FB
        jr nz,zd_k
        call zd_rd          ; REM' = '
        ld a,39             ; '
        call zd_wr
        ld a,2
        ld (zMode),a
        jr zd_b
zd_k:   ld a,b
        ld (zTok),a
        call zd_kw
        jr c,zd_rawt
        ld a,(zTok)
        cp $93
        jr nz,zd_k1
        ld a,2
        ld (zMode),a
        jp zd_b
zd_k1:  cp $88
        jp nz,zd_b
        ld a,3
        ld (zMode),a
        jp zd_b
zd_raw: ld a,b
zd_r2:  call zd_wr
        jp zd_b
zd_rawt: ld a,(zTok)        ; (zd_kw used B)
        jr zd_r2
zd_eol: ld a,10
        call zd_wr
        jp zd_line
zd_end: ld hl,(zRP)         ; nothing may follow the end
        ld de,BUFE
        or a
        sbc hl,de
        ret z
        scf
        ret

zd_rd:  ld hl,(zRP)         ; A = the next program byte; C = none left
        ld a,h
        cp BUFE/256
        jr nz,zr_1
        ld a,l
        cp BUFE&255
        scf
        ret z
zr_1:   ld a,(hl)
        inc hl
        ld (zRP),hl
        or a
        ret
zd_pk:  ld hl,(zRP)         ; A = the next byte, not taken; C = none
        jr zp_k
zd_pk2: ld hl,(zRP)         ; the one after that
        inc hl
zp_k:   ld a,h
        cp BUFE/256
        jr nz,zp_1
        ld a,l
        cp BUFE&255
        scf
        ret z
zp_1:   ld a,(hl)
        or a
        ret

zd_wr:  push hl             ; A -> the text (A kept); no room: zOv = 1
        push de
        push af
        ld hl,(zWP)
        ld de,(zRP)
        or a
        sbc hl,de
        jr c,zw_ok
        ld a,1
        ld (zOv),a
        pop af
        jr zw_x
zw_ok:  add hl,de
        pop af
        ld (hl),a
        inc hl
        ld (zWP),hl
zw_x:   pop de
        pop hl
        ret

zd_kw:  sub $80             ; A = a token -> its keyword; C = not one the VZ has
        cp 124
        ccf
        ret c
        ld b,a
        ld hl,bas_kw
        or a
        jr z,zk_f
zk_s:   inc hl
        bit 7,(hl)
        jr z,zk_s
        djnz zk_s
zk_f:   ld a,(hl)
        cp $FF
        scf
        ret z
        and $7F
zk_w:   call zd_wr
        inc hl
        ld a,(hl)
        bit 7,a
        jr z,zk_w
        or a
        ret

; ===========================================================================
;  the hex viewer: 8 bytes a row, "OOOOOO HHHHHHHHHHHHHHHH CCCCCCCC", read
;  from the card a sector at a time (any size of file).  Cursor keys / R C
;  move, T B top / end, Q, CTRL+Q or RETURN back.
; ===========================================================================
zx_go:  ld a,1
        ld (waitrel),a
        xor a
        ld (zOff),a
        ld (zOff+1),a
        ld (zOff+2),a
        ld (zCi),a
        ld (zCi+1),a
        ld hl,$FFFF
        ld (zSec),hl
        ld hl,(ldcl)
        ld (zCl),hl
        ld a,(ldcl+2)
        ld (zCl+2),a
        ld a,(docrows)      ; bytes a screen
        add a,a
        add a,a
        add a,a
        ld (zPg),a
        xor a
        ld (zPg+1),a
        ld (zPg+2),a
zx_drw: call cls_scr
        xor a
        call set_rows
        ld hl,zs_hex
        ld de,SCR
        call puts
        ld hl,zOff
        call ld24
        ld bc,zRo
        call st24
        ld hl,SCR+32
        ld (zSc),hl
        ld a,(docrows)
        ld b,a
zx_row: push bc
        call zx_line
        ld hl,(zSc)
        ld bc,32
        add hl,bc
        ld (zSc),hl
        pop bc
        djnz zx_row
        call flush
zx_key: call waitkey
        cp K_DOWN
        jr z,zx_dn
        cp K_UP
        jr z,zx_up
        cp K_PGDN
        jr z,zx_pd
        cp K_PGUP
        jr z,zx_pu
        cp K_TOP
        jr z,zx_top
        cp K_BOT
        jr z,zx_bot
        cp K_QUIT
        jr z,zx_x
        cp K_RET
        jr z,zx_x
        or $20
        cp 'q'
        jr nz,zx_key
zx_x:   ld a,1
        ld (waitrel),a
        xor a
        ret
zx_dn:  ld bc,zK8
zx_fw:  ld hl,zOff          ; forward, if that is still in the file
        call ld24
        call addm24
        ld bc,ldsz
        call cmpm24
        jr nc,zx_key
zx_set: ld bc,zOff
        call st24
        jp zx_drw
zx_pd:  ld bc,zPg
        jr zx_fw
zx_up:  ld bc,zK8
zx_bk:  ld hl,zOff          ; back, not before the start
        call ld24
        call subm24
        jr nc,zx_set
zx_top: ld hl,0
        ld e,l
        jr zx_set
zx_pu:  ld bc,zPg
        jr zx_bk
zx_bot: ld hl,ldsz          ; the last screenful
        call ld24
        ld a,h
        or l
        or e
        jr z,zx_top
        ld bc,zK1
        call subm24
        ld a,l
        and $F8
        ld l,a
        ld bc,zPg
        call subm24
        jr c,zx_top
        ld bc,zK8
        call addm24
        jr zx_set

; one row at zSc for offset zRo (zRo moves on by up to 8)
zx_line: ld hl,zRo
        call ld24
        ld bc,ldsz
        call cmpm24
        ret nc              ; past the end: a blank row
        ld de,(zSc)         ; offset in hex
        ld a,(zRo+2)
        call zx_hx
        ld a,(zRo+1)
        call zx_hx
        ld a,(zRo)
        call zx_hx
        inc de
        ld (zP),de          ; where the hex goes
        ld hl,17
        add hl,de
        ld (zA),hl          ; where the characters go
        ld b,8
zx_by:  push bc
        ld hl,zRo
        call ld24
        ld bc,ldsz
        call cmpm24
        jr nc,zx_b3         ; the end of the file
        call zx_byte
        ld de,(zP)
        push af
        call zx_hx
        ld (zP),de
        pop af
        cp ' '
        jr c,zx_dot
        cp 127
        jr c,zx_ch
zx_dot: ld a,'.'
zx_ch:  ld hl,(zA)
        ld (hl),a
        inc hl
        ld (zA),hl
        ld hl,zRo
        call ld24
        ld bc,zK1
        call addm24
        ld bc,zRo
        call st24
        pop bc
        djnz zx_by
        ret
zx_b3:  pop bc
        ret

zx_hx:  push af             ; A -> two hex digits at DE
        rrca
        rrca
        rrca
        rrca
        call zx_nb
        pop af
zx_nb:  and 15
        add a,'0'
        cp '9'+1
        jr c,zx_n1
        add a,7
zx_n1:  ld (de),a
        inc de
        ret

; A = the byte at offset E:HL of the file (cached by sector)
zx_byte: ld a,l
        ld (zBo),a
        ld a,h
        and 1
        ld (zBo+1),a
        srl e               ; sector in the file = offset / 512
        rr h
        ld l,h
        ld h,e
        ld de,(zSec)
        or a
        sbc hl,de
        add hl,de
        jr z,zb_hit
        ld (zSec),hl
        ld a,(spc)          ; cluster index = sector / spc, sector in it = sector % spc
        dec a
        and l
        ld (zSi),a
        ld a,(spc)
zb_sh:  srl a
        jr z,zb_s1
        srl h
        rr l
        jr zb_sh
zb_s1:  ld de,(zCi)         ; walk the chain (from the start if going back)
        or a
        sbc hl,de
        add hl,de
        jr nc,zb_w
        ld de,0
        ld (zCi),de
        ld de,(ldcl)
        ld (zCl),de
        ld a,(ldcl+2)
        ld (zCl+2),a
zb_w:   ld de,(zCi)
        or a
        sbc hl,de
        add hl,de
        jr z,zb_rd
        push hl
        ld hl,zCl
        call ld24
        call fat_get
        ld bc,zCl
        call st24
        ld hl,(zCi)
        inc hl
        ld (zCi),hl
        pop hl
        jr zb_w
zb_rd:  call fat_sync
        ld hl,zCl
        call ld24
        ld a,(zSi)
        call clus_lba
        call rd_sec
zb_hit: ld hl,(zBo)
        ld de,SECBUF
        add hl,de
        ld a,(hl)
        ret

zs_hex: db "HEX VIEW (READ ONLY)  ^Q=BACK",0
zK1:    db 1,0,0
zK8:    db 8,0,0

        include "basic_kw.inc"

zv_end:
        assert zv_end <= OVLA+OVLSEC*512
zD      equ zv_end          ; where the raw file is
zRP     equ zD+2            ; LIST: read / write
zWP     equ zRP+2
zOv     equ zWP+2
zMode   equ zOv+1
zTok    equ zMode+1
zNB     equ zTok+1          ; 6: a line number
zOff    equ zNB+6           ; hex: offset of the top row (24 bit)
zPg     equ zOff+3          ; bytes a screen (24 bit)
zSec    equ zPg+3           ; sector of the file in SECBUF ($FFFF = none)
zCi     equ zSec+2          ; cluster index / cluster of the last walk
zCl     equ zCi+2
zSi     equ zCl+3
zBo     equ zSi+1
zP      equ zBo+2
zA      equ zP+2
zRo     equ zA+2            ; offset of the row being drawn (24 bit)
zSc     equ zRo+3           ; and where it goes on the screen
zv_wend equ zSc+2
        assert zv_wend <= OVLEND
