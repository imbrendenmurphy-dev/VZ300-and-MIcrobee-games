; ===========================================================================
;  ovl_pdf.asm - overlay slot 3: save the document as NAME.PDF (FILE menu).
;  Built by build.py against mainsym.inc; runs at OVLA+2.
;
;  A plain PDF 1.4: Courier 10 pt on A4, 64 lines of 80 characters a page
;  (out_lay.inc).  Objects: 1 catalog, 2 page tree (written last), 3 font,
;  then for page p: 4+2p the page, 5+2p its contents.  The whole file is made
;  twice: once only counting bytes (the card code needs the length first, and
;  each page's stream length, written as 5 digits so both runs match), then
;  for real through wputb, like write_new.  Safe order as in save_doc: the PDF
;  is written as VZEDTEMP.$$$, then an old NAME.PDF (after asking) goes, then
;  the temp file is renamed.  The text is only read.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)

MAXPG   equ 200             ; (12,288 empty lines = 192 pages)

zp_go:  ld a,1
        ld (waitrel),a
        ld a,(fs_ok)
        or a
        jr nz,zp_1
        ld hl,m_nofs
        call set_msg
        xor a
        ret
zp_1:   ld a,(named)        ; NEWNAME = NAME + PDF (UNTITLED if no name yet)
        or a
        ld hl,fname
        jr nz,zp_2
        ld hl,s_untitled
zp_2:   ld de,NEWNAME
        ld bc,8
        ldir
        ld hl,zs_pdf
        ld bc,3
        ldir
        ld a,(named)        ; the document is a .PDF itself: don't replace it
        or a
        jr z,zp_3
        ld hl,fname+8
        ld de,zs_pdf
        ld b,3
zp_cm:  ld a,(de)
        cp (hl)
        jr nz,zp_3
        inc hl
        inc de
        djnz zp_cm
        ld hl,zs_ispdf
        jp zl_msg
zp_3:   ld hl,NEWNAME       ; already there: ask
        call cwd_find
        jr c,zp_4
        ld hl,zs_repl
        call ask_yn
        cp 'Y'
        jr z,zp_4
        xor a
        ret
zp_4:   ld hl,zs_making
        call show_status
        xor a               ; 1. count
        ld (zPass),a
        call zp_pass
        ld a,(zOvf)
        or a
        jp nz,zp_big
        ld hl,(zCnt)        ; clusters needed (as write_new)
        ld (outlen),hl
        ld e,0
        ld c,0
zp_cl:  ld a,h
        or l
        or e
        jr z,zp_cd
        inc c
        push bc
        ld bc,bpc
        call subm24
        pop bc
        jr nc,zp_cl
zp_cd:  ld a,c
        ld (wncl),a
        cp 129
        jp nc,zp_big
        ld hl,s_tmpname     ; 2. clear away an old temp file
        call cwd_find
        call nc,del_entry
        ld hl,cwd
        call ld24
        ld bc,wdir
        call st24
        ld a,(wncl)
        call alloc_chain
        jr c,zp_full
        xor a
        ld (wci),a
        ld (wsec),a
        ld hl,SECBUF
        ld (wpos),hl
        ld a,1              ; 3. write it
        ld (zPass),a
        call zp_pass
        ld hl,s_tmpname
        call setname
        call zp_fin
        jr c,zp_full
        ld hl,NEWNAME       ; 4. the old PDF goes, the temp file takes its name
        call cwd_find
        call nc,del_entry
        ld hl,s_tmpname
        call cwd_find
        jr c,zp_err
        call rename_entry
        ld hl,zs_saved
        jp zl_msg
zp_full: ld hl,m_cardfull
        call set_msg
        xor a
        ret
zp_err: ld hl,m_saveerr
        call set_msg
        xor a
        ret
zp_big: ld hl,zs_big
        jp zl_msg
zp_fin: ld hl,(wpos)        ; the end of write_new: pad the last sector, the entry
        ld a,l
        or a
        jp nz,wn_z
        ld a,h
        cp SECBUF/256
        jp z,wn_ent
        jp wn_z

; ---- one run over the whole file (zPass 0 = count only, 1 = write)
zp_pass: ld hl,0
        ld (zCnt),hl
        xor a
        ld (zOvf),a
        ld hl,zs_hdr
        call zp_str
        ld hl,1
        call zp_rec
        ld hl,zs_o1
        call zp_str
        ld hl,3
        call zp_rec
        ld hl,zs_o3
        call zp_str
        call zl_start
        ld hl,0
        ld (zPg),hl
zg_l:   ld hl,(zPg)         ; page object 4+2p
        add hl,hl
        ld de,4
        add hl,de
        ld (zN),hl
        call zp_rec
        ld hl,(zN)
        call zp_num
        ld hl,zs_pg1
        call zp_str
        ld hl,(zN)
        inc hl
        call zp_num
        ld hl,zs_pg2
        call zp_str
        ld hl,(zN)          ; its contents 5+2p
        inc hl
        push hl
        call zp_rec
        pop hl
        call zp_num
        ld hl,zs_st1
        call zp_str
        call zp_lenp
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call zp_num5
        ld hl,zs_st2
        call zp_str
        ld hl,(zCnt)
        ld (zSS),hl
        ld hl,zs_bt
        call zp_str
        ld a,64
        ld (zLn),a
zg_ln:  call zl_next
        jr c,zg_le
        ld a,'('
        call zp_out
        ld hl,zLB
        ld a,b
        or a
        jr z,zg_lc
zg_ch:  ld a,(hl)
        inc hl
        cp ' '
        jr nc,zg_c1
        ld a,' '            ; (control characters: a space)
zg_c1:  cp '('
        jr z,zg_esc
        cp ')'
        jr z,zg_esc
        cp 92               ; backslash
        jr nz,zg_c2
zg_esc: push af
        ld a,92
        call zp_out
        pop af
zg_c2:  call zp_out
        djnz zg_ch
zg_lc:  ld hl,zs_tq
        call zp_str
        ld hl,zLn
        dec (hl)
        jr nz,zg_ln
zg_le:  ld hl,zs_et
        call zp_str
        ld hl,(zCnt)        ; this page's stream length
        ld de,(zSS)
        or a
        sbc hl,de
        push hl
        call zp_lenp
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,zs_es
        call zp_str
        ld hl,(zPg)
        inc hl
        ld (zPg),hl
        call textlen        ; more text: another page
        ld de,(zLP)
        or a
        sbc hl,de
        jr z,zg_tree
        ld hl,(zPg)
        ld de,MAXPG
        or a
        sbc hl,de
        jp c,zg_l
        ld a,1
        ld (zOvf),a
zg_tree: ld hl,2            ; the page tree
        call zp_rec
        ld hl,zs_p1
        call zp_str
        ld hl,(zPg)
        call zp_num
        ld hl,zs_p2
        call zp_str
        ld hl,4
        ld (zN),hl
        ld bc,(zPg)
zg_k:   push bc
        ld hl,(zN)
        call zp_num
        ld hl,zs_r
        call zp_str
        ld hl,(zN)
        inc hl
        inc hl
        ld (zN),hl
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,zg_k
        ld hl,zs_p3
        call zp_str
        ld hl,(zCnt)        ; cross-reference table
        ld (zXR),hl
        ld hl,zs_x1
        call zp_str
        ld hl,(zN)          ; (zN = 4+2P = the number of objects)
        call zp_num
        ld hl,zs_x2
        call zp_str
        ld hl,1
zg_x:   push hl
        ld de,(zN)
        or a
        sbc hl,de
        pop hl
        jr nc,zg_tr
        push hl
        ld hl,zs_z5
        call zp_str
        pop hl
        push hl
        add hl,hl
        ld de,zOFF
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call zp_num5
        ld hl,zs_x3
        call zp_str
        pop hl
        inc hl
        jr zg_x
zg_tr:  ld hl,zs_t1
        call zp_str
        ld hl,(zN)
        call zp_num
        ld hl,zs_t2
        call zp_str
        ld hl,(zXR)
        call zp_num
        ld hl,zs_t3
        jp zp_str

zp_lenp: ld hl,(zPg)        ; HL = &zLEN[page]
        add hl,hl
        ld de,zLEN
        add hl,de
        ret

zp_rec: add hl,hl           ; object HL starts here
        ld de,zOFF
        add hl,de
        ld de,(zCnt)
        ld (hl),e
        inc hl
        ld (hl),d
        ret

zp_str: ld a,(hl)           ; HL = zero-terminated string
        or a
        ret z
        call zp_out
        inc hl
        jr zp_str

zp_num: xor a               ; HL in decimal (zp_num5: always 5 digits)
        jr zn_0
zp_num5: ld a,1
zn_0:   ld (zPad),a
        ld de,zs_pow
zn_p:   ld a,(de)
        ld c,a
        inc de
        ld a,(de)
        ld b,a
        inc de
        or c
        jr z,zn_last
        push de
        ld d,b
        ld e,c
        ld b,'0'-1
zn_s:   inc b
        or a
        sbc hl,de
        jr nc,zn_s
        add hl,de
        pop de
        ld a,b
        cp '0'
        jr nz,zn_e
        ld a,(zPad)
        or a
        jr z,zn_p
zn_e:   ld a,1
        ld (zPad),a
        ld a,b
        call zp_out
        jr zn_p
zn_last: ld a,l
        add a,'0'
        jp zp_out

zp_out: push hl             ; one byte of the file (A kept)
        push af
        ld hl,(zCnt)
        inc hl
        ld (zCnt),hl
        ld a,h
        or l
        jr nz,zo_1
        ld a,1              ; 64K or more: too big for the card code
        ld (zOvf),a
zo_1:   ld a,(zPass)
        or a
        jr z,zo_2
        pop af
        push af
        call wputb
zo_2:   pop af
        pop hl
        ret

        include "out_lay.inc"

zs_pow: dw 10000,1000,100,10,0
zs_pdf: db "PDF"
zs_ispdf: db "FILE IS PDF",0
zs_repl: db "REPLACE THE .PDF? Y/N",0
zs_making: db "MAKING PDF...",0
zs_saved: db "PDF SAVED",0
zs_big: db "PDF TOO BIG",0
zs_hdr: db "%PDF-1.4",10,0
zs_o1:  db "1 0 obj",10,"<</Type/Catalog/Pages 2 0 R>>",10,"endobj",10,0
zs_o3:  db "3 0 obj",10,"<</Type/Font/Subtype/Type1/BaseFont/Courier>>",10,"endobj",10,0
zs_pg1: db " 0 obj",10,"<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]"
        db "/Resources<</Font<</F1 3 0 R>>>>/Contents ",0
zs_pg2: db " 0 R>>",10,"endobj",10,0
zs_st1: db " 0 obj",10,"<</Length ",0
zs_st2: db ">>",10,"stream",10,0
zs_bt:  db "BT /F1 10 Tf 12 TL 50 812 Td",10,0
zs_tq:  db ")'",10,0
zs_et:  db "ET",0
zs_es:  db 10,"endstream",10,"endobj",10,0
zs_p1:  db "2 0 obj",10,"<</Type/Pages/Count ",0
zs_p2:  db "/Kids[",0
zs_r:   db " 0 R ",0
zs_p3:  db "]>>",10,"endobj",10,0
zs_x1:  db "xref",10,"0 ",0
zs_x2:  db 10,"0000000000 65535 f",13,10,0
zs_z5:  db "00000",0
zs_x3:  db " 00000 n",13,10,0
zs_t1:  db "trailer",10,"<</Size ",0
zs_t2:  db "/Root 1 0 R>>",10,"startxref",10,0
zs_t3:  db 10,"%%EOF",10,0

zp_end:
        assert zp_end <= OVLA+OVLSEC*512
zPass   equ zp_end
zOvf    equ zPass+1
zPad    equ zOvf+1
zLn     equ zPad+1
zCnt    equ zLn+1
zSS     equ zCnt+2
zXR     equ zSS+2
zPg     equ zXR+2
zN      equ zPg+2
zLP     equ zN+2
zLB     equ zLP+2           ; 81
zOFF    equ zLB+81          ; object offsets, 4+2*MAXPG
zLEN    equ zOFF+(4+2*MAXPG)*2
zp_wend equ zLEN+MAXPG*2
        assert zp_wend <= OVLEND
