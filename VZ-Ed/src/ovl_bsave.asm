; ===========================================================================
;  ovl_bsave.asm - overlay slot 6 (0.6): save a BASIC program as .VZ (from
;  save_doc through bas_save when basmode = 1 and the name ends in .VZ).
;
;  Each text line "NUMBER text" is tokenised the way the ROM does it
;  (tools/basic.py is the model, checked against the real ROM): one space after
;  the number dropped; the first keyword in table order at each place, in
;  either case; other letters made capitals; ? = PRINT; ':' before ELSE, ':REM'
;  for '; REM / ' keep the rest, DATA up to ':'; quotes kept.  Blank lines are
;  skipped.  Line numbers must go up (1-65529).  Errors: message, the cursor
;  goes to the line (C + HL for ovl_run), nothing is written.
;  File: "VZF0" + name (bashdr) + $F0 + load address, then the program with
;  its links for that address, then 0 0.  Made twice (count, then write via
;  wputb, as the PDF), as VZEDTEMP.$$$, then save_doc's own steps 3-4 (sv_3:
;  the old file becomes .BAK, the temp file takes the name).
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0                ; build id (build.py)

zb_go:  ld a,1
        ld (waitrel),a
        ld a,(fs_ok)
        or a
        jr nz,zb_1
        ld hl,m_nofs
        call set_msg
        xor a
        ret
zb_1:   ld hl,m_saving
        call show_status
        call zi_init
        xor a               ; 1. count (and check every line)
        ld (zPass),a
        call zb_pass
        jp c,zb_err
        ld hl,(zCnt)
        ld (outlen),hl
        ld e,0
        ld c,0
zb_cl:  ld a,h
        or l
        or e
        jr z,zb_cd
        inc c
        push bc
        ld bc,bpc
        call subm24
        pop bc
        jr nc,zb_cl
zb_cd:  ld a,c
        ld (wncl),a
        cp 129
        jr nc,zb_full
        ld hl,s_tmpname     ; 2. the temp file
        call cwd_find
        call nc,del_entry
        ld hl,cwd
        call ld24
        ld bc,wdir
        call st24
        ld a,(wncl)
        call alloc_chain
        jr c,zb_full
        xor a
        ld (wci),a
        ld (wsec),a
        ld hl,SECBUF
        ld (wpos),hl
        ld a,1
        ld (zPass),a
        call zb_pass
        ld hl,s_tmpname
        call setname
        call zb_fin
        jr c,zb_full
        call sv_3           ; 3-4. NAME.BAK, the temp file takes the name
        ld a,0
        jr c,zb_r
        inc a
zb_r:   ld (ovok),a
        xor a
        ret
zb_full: ld hl,m_cardfull
        call set_msg
        xor a
        ret
zb_err: ld hl,(zErr)        ; the message, and the cursor to that line
        ld de,msgbuf
        ld bc,12
        ldir
        ld hl,msgbuf
        call set_msg
        ld hl,(zLS)
        scf
        ret
zb_fin: ld hl,(wpos)        ; the end of write_new: pad the last sector, the entry
        ld a,l
        or a
        jp nz,wn_z
        ld a,h
        cp SECBUF/256
        jp z,wn_ent
        jp wn_z

; ---- keyword index: zFirst[c-32] = first token starting with c, zNext[k] =
; the next token with the same first character (table order), zEnt[k] = entry
zi_init: ld hl,zFirst        ; zFirst and zLast
        ld b,128
zi_f:   ld (hl),$FF
        inc hl
        djnz zi_f
        ld hl,zNext
        ld b,124
zi_n:   ld (hl),$FF
        inc hl
        djnz zi_n
        ld de,bas_kw
        ld c,0              ; k
zi_l:   ld a,(de)
        cp $80
        ret z
        ld l,c              ; zEnt[k] = DE
        ld h,0
        add hl,hl
        push de
        ld de,zEnt
        add hl,de
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(de)
        cp $FF
        jr z,zi_nx
        cp $A7              ; (' is done by hand)
        jr z,zi_nx
        and $7F
        sub 32
        cp 64
        jr nc,zi_nx
        ld l,a
        ld h,0
        push de
        ld de,zLast
        add hl,de
        ld a,(hl)
        ld (hl),c           ; zLast[ch] = k
        cp $FF
        jr nz,zi_ch
        ld de,zFirst-zLast  ; the first one: zFirst[ch] = k
        add hl,de
        ld (hl),c
        jr zi_d
zi_ch:  ld l,a              ; zNext[previous] = k
        ld h,0
        ld de,zNext
        add hl,de
        ld (hl),c
zi_d:   pop de
zi_nx:  inc de              ; on to the next entry
        ld a,(de)
        bit 7,a
        jr z,zi_nx
        inc c
        jr zi_l

; ---- one run over the text.  C = a bad line (zErr, zLS).
zb_pass: ld hl,0
        ld (zCnt),hl
        ld (zOff),hl
        ld (zTL),hl
        ld (zLastN),hl
        xor a
        ld (zHave),a
        ld hl,zs_vzf
        ld b,4
        call zo_n
        ld hl,bashdr        ; name (17), type, load address
        ld b,17
        call zo_n
        ld a,$F0
        call zo
        ld hl,bashdr+17
        ld b,2
        call zo_n
        ld hl,0
        call log2phys
        ld (zTP),hl
zb_ln:  ld hl,(zTL)         ; a line into zLin
        ld (zLS),hl
        ld de,zLin
        ld c,0
zb_rd:  call zt_get
        jr c,zb_eot
        cp 10
        jr z,zb_got
        ld (de),a
        inc de
        inc c
        jr nz,zb_rd
        ld hl,zs_long       ; over 255 characters
        jp zb_bad
zb_eot: ld a,c              ; the end of the text
        or a
        jr z,zb_end
        call zb_line
        ret c
zb_end: xor a               ; the end of the program
        call zo
        xor a
        call zo
        or a
        ret
zb_got: call zb_line
        ret c
        jr zb_ln

; zLin, C = its length -> tokenised and sent; C = bad
zb_line: ld hl,zLin
        ld b,c
zl_sp:  ld a,b              ; blank line: nothing
        or a
        ret z
        ld a,(hl)
        cp ' '
        jr nz,zl_n
        inc hl
        dec b
        jr zl_sp
zl_n:   ld de,0             ; the line number
        ld c,0              ; digits
zl_d:   ld a,b
        or a
        jr z,zl_dn
        ld a,(hl)
        sub '0'
        cp 10
        jr nc,zl_dn
        push hl
        ld h,d              ; DE = DE*10 + A
        ld l,e
        add hl,hl
        jr c,zl_bign
        add hl,hl
        jr c,zl_bign
        add hl,de
        jr c,zl_bign
        add hl,hl
        jr c,zl_bign
        ld e,a
        ld d,0
        add hl,de
        jr c,zl_bign
        ex de,hl
        pop hl
        inc hl
        dec b
        inc c
        jr zl_d
zl_bign: pop hl
        jr zl_nono
zl_dn:  ld a,c
        or a
        jr z,zl_nono
        push hl             ; 1 .. 65529, above the last one
        ld hl,65529
        or a
        sbc hl,de
        pop hl
        jr c,zl_nono
        ld a,d
        or e
        jr z,zl_nono
        ld a,(zHave)
        or a
        jr z,zl_ok
        push hl
        ld hl,(zLastN)
        or a
        sbc hl,de
        pop hl
        jr nc,zl_order
zl_ok:  ld (zLastN),de
        ld a,1
        ld (zHave),a
        ld a,b              ; one space after the number is dropped
        or a
        jr z,zl_cr
        ld a,(hl)
        cp ' '
        jr nz,zl_cr
        inc hl
        dec b
zl_cr:  call zc_crunch      ; -> zTB, zTn
        ret c
        ld hl,(zOff)        ; link = load address + offset of the next line
        ld de,4+1
        add hl,de
        ld a,(zTn)
        ld e,a
        ld d,0
        add hl,de
        ld (zOff),hl
        ld de,(bashdr+17)
        add hl,de
        ld a,l
        call zo
        ld a,h
        call zo
        ld a,(zLastN)
        call zo
        ld a,(zLastN+1)
        call zo
        ld hl,zTB
        ld a,(zTn)
        ld b,a
        or a
        call nz,zo_n
        xor a
        call zo
        or a
        ret
zl_nono: ld hl,zs_nono
        jr zb_bad
zl_order: ld hl,zs_order
zb_bad: ld (zErr),hl
        scf
        ret

; ---- CRUNCH: HL = text, B = its length -> zTB, zTn.  C = too long.
zc_crunch: ld de,zTB
        xor a
        ld (zTn),a
        ld (zM),a           ; 0 plain, 1 quote, 2 the rest kept, 3 DATA to ':'
zc_l:   ld a,b
        or a
        ret z               ; (NC)
        ld a,(zM)
        cp 2
        jp z,zc_cp
        cp 1
        jr nz,zc_1
        ld a,(hl)           ; in quotes
        cp '"'
        jp nz,zc_cp
        xor a
        ld (zM),a
        jp zc_cp
zc_1:   ld a,(hl)
        cp '"'
        jr nz,zc_2
        ld a,1
        ld (zM),a
        jr zc_cp
zc_2:   ld a,(zM)
        cp 3
        jr nz,zc_3
        ld a,(hl)           ; DATA
        cp ':'
        jr nz,zc_cp
        xor a
        ld (zM),a
        jr zc_cp
zc_3:   ld a,(hl)
        cp '?'
        jr nz,zc_4
        ld a,$B2            ; ? = PRINT
        jr zc_one
zc_4:   cp 39
        jr nz,zc_5
        ld a,':'            ; ' = :REM'
        call zc_out
        ret c
        ld a,$93
        call zc_out
        ret c
        ld a,$FB
        call zc_out
        ret c
        ld a,2
        ld (zM),a
        inc hl
        dec b
        jr zc_l
zc_5:   call zc_match
        jr nc,zc_ch
        cp $95              ; ELSE: a ':' first
        jr nz,zc_6
        push af
        ld a,':'
        call zc_out
        pop bc              ; (B back below)
        ld a,b
        ret c
        ld a,(zRem)
        ld b,a
        ld a,$95
zc_6:   call zc_out
        ret c
        cp $93
        jr nz,zc_7
        ld a,2
        ld (zM),a
zc_7:   cp $88
        jr nz,zc_8
        ld a,3
        ld (zM),a
zc_8:   ld a,(zML)          ; past the keyword
        ld c,a
zc_sk:  inc hl
        dec b
        dec c
        jr nz,zc_sk
        jp zc_l
zc_ch:  ld a,(hl)           ; any other character: capitals outside quotes
        call zc_up
        jr zc_one
zc_cp:  ld a,(hl)
zc_one: call zc_out
        ret c
        inc hl
        dec b
        jp zc_l

zc_out: push hl             ; A -> zTB (A kept); C = over 250 bytes
        ld hl,zTn
        ld c,a
        ld a,(hl)
        cp 250
        jr nc,zo_long
        inc (hl)
        ld a,c
        ld (de),a
        inc de
        pop hl
        or a
        ret
zo_long: pop hl
        ld hl,zs_long
        ld (zErr),hl
        scf
        ret

zc_up:  cp 'a'              ; A: a lower case letter -> capital
        ret c
        cp 'z'+1
        ret nc
        sub 32
        ret

; HL = text, B = left: the first keyword (table order) that starts here.
; C = found: A = token, zML = its length.  (HL, B, DE kept)
zc_match: ld a,(hl)
        call zc_up
        sub 32
        cp 64
        ret nc              ; (NC: no keyword starts with that)
        push de
        push hl
        ld (zSrc),hl
        ld l,a
        ld a,b
        ld (zRem),a
        ld h,0
        ld de,zFirst
        add hl,de
        ld a,(hl)           ; k
zm_k:   cp $FF
        jr z,zm_no
        ld (zK),a
        ld l,a              ; DE = the entry
        ld h,0
        add hl,hl
        ld de,zEnt
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(zSrc)
        ld a,(zRem)
        ld c,a
        ld a,(de)
        and $7F
zm_c:   ld (zEc),a          ; compare the keyword with the text
        ld a,c
        or a
        jr z,zm_nx
        ld a,(hl)
        call zc_up
        push hl
        ld hl,zEc
        cp (hl)
        pop hl
        jr nz,zm_nx
        inc hl
        dec c
        inc de
        ld a,(de)
        bit 7,a
        jr z,zm_c
        ld de,(zSrc)        ; found
        or a
        sbc hl,de
        ld a,l
        ld (zML),a
        ld a,(zK)
        add a,$80
        pop hl
        pop de
        scf
        ret
zm_nx:  ld a,(zK)           ; the next keyword with that first character
        ld l,a
        ld h,0
        ld de,zNext
        add hl,de
        ld a,(hl)
        jr zm_k
zm_no:  pop hl
        pop de
        ld a,(zRem)
        ld b,a
        or a
        ret

; the next text character (around the gap): A; C = the end.  zTL counts.
zt_get: push hl
        ld hl,(zTP)
        ld a,(gs)
        cp l
        jr nz,zt_1
        ld a,(gs+1)
        cp h
        jr nz,zt_1
        ld hl,(ge)
zt_1:   ld a,h
        cp BUFE/256
        jr nz,zt_2
        ld a,l
        cp BUFE&255
        jr nz,zt_2
        pop hl
        scf
        ret
zt_2:   ld a,(hl)
        inc hl
        ld (zTP),hl
        ld hl,(zTL)
        inc hl
        ld (zTL),hl
        pop hl
        or a
        ret

zo_n:   ld a,(hl)           ; B bytes from HL to the file
        call zo
        inc hl
        djnz zo_n
        ret
zo:     push hl             ; one byte of the file (count, or write)
        push af
        ld hl,(zCnt)
        inc hl
        ld (zCnt),hl
        ld a,(zPass)
        or a
        jr z,zo_2
        pop af
        push af
        call wputb
zo_2:   pop af
        pop hl
        ret

zs_vzf: db "VZF0"
zs_nono: db "NO LINE NO.",0
zs_order: db "LINE ORDER",0,0
zs_long: db "LONG LINE",0,0,0

        include "basic_kw.inc"

zb_end2:
        assert zb_end2 <= OVLA+OVLSEC*512
zPass   equ zb_end2
zCnt    equ zPass+1
zOff    equ zCnt+2
zTP     equ zOff+2          ; text: physical pointer, logical count
zTL     equ zTP+2
zLS     equ zTL+2           ; start of the line being done
zLastN  equ zLS+2
zHave   equ zLastN+2
zErr    equ zHave+1
zTn     equ zErr+2
zM      equ zTn+1
zML     equ zM+1
zSrc    equ zML+1
zRem    equ zSrc+2
zK      equ zRem+1
zEc     equ zK+1
zFirst  equ zEc+1           ; 64
zLast   equ zFirst+64       ; 64
zNext   equ zLast+64        ; 124
zEnt    equ zNext+124       ; 124 x 2
zLin    equ zEnt+248        ; 256
zTB     equ zLin+256        ; 251
zb_wend equ zTB+251
        assert zb_wend <= OVLEND
