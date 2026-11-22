; ===========================================================================
;  ui.asm - file list, prompts, help, open / save / new / quit
; ===========================================================================

; ---- "save changes?" before throwing the text away.  NC = go ahead.
check_modified:
        ld a,(modified)
        or a
        ret z
        ld hl,m_savechg
        call ask_yn
        or a
        scf
        ret z               ; cancelled
        cp 'N'
        ret z               ; (NC) discard
        jp c_save           ; NC if it saved

c_save: ld a,(named)
        or a
        jp nz,save_doc
c_saveas:
        call prefill
        call input_name
        ret c
        ld hl,PNAME
        call cwd_find
        jr c,csa_new        ; no such file yet
        ld a,(named)
        or a
        jr z,csa_ask
        ld hl,PNAME         ; the same file we are editing: just save
        ld de,fname
        ld b,11
csa_c:  ld a,(de)
        cp (hl)
        jr nz,csa_ask
        inc hl
        inc de
        djnz csa_c
        jr csa_new
csa_ask: ld hl,m_replace
        call ask_yn
        cp 'Y'
        scf
        ret nz
csa_new: ld hl,PNAME
        ld de,fname
        ld bc,11
        ldir
        ld a,1
        ld (named),a
        jp save_doc

prefill:                    ; INBUF = current name (or empty)
        xor a
        ld (inlen),a
        ld a,(named)
        or a
        ret z
        ld hl,fname
        ld de,INBUF
        call put83
        ld a,e
        sub INBUF&255
        ld (inlen),a
        ret

c_new:  call check_modified
        ret c
        call buf_clear
        xor a
        ld (named),a
        inc a
        ld (crlf),a
        ld hl,m_new
        jp set_msg

c_open: call check_modified
        ret c
        xor a
        ld (selon),a
        ld (rbuf),a         ; so do the replacement text
        ld a,(clipbank)     ; the fallback clipboard shares RAM with the file list
        or a
        jr nz,co_1
        ld h,a
        ld l,a
        ld (cliplen),hl
co_1:   call filelist
        ld a,1
        ld (waitrel),a
        ret

c_quit: call check_modified
        ret c
        call cfg_save
exit:   xor a               ; back to text mode, clear the screen
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,511
        ld (hl),$20
        ldir
        ld a,(plugmode)
        or a
        jr z,ex_rst
        ld hl,s_shellnm     ; plug-in: find SHELL.VZ and reload it like the players do
        call setname
        ld hl,0
        ld e,l
        call dir_find
        jr c,ex_rst
        ld hl,(dwptr)
        ld de,26
        add hl,de
        ld a,(hl)
        ld (HO+22),a
        inc hl
        ld a,(hl)
        ld (HO+23),a
        ld hl,(dwptr)
        ld de,20
        add hl,de
        ld a,(hl)
        ld (HO+24),a
        xor a
        ld (HO+25),a
        ld hl,(dwptr)
        ld de,28
        add hl,de
        ld a,(hl)
        ld (HO+26),a
        inc hl
        ld a,(hl)
        ld (HO+27),a
        call fat_sync
        call dos_nocache
        ld hl,rl_src
        ld de,$7600
        ld bc,rl_end-rl_src
        ldir
        jp $7600
ex_rst: xor a               ; restart: VZ-DECK comes back up
        out ($37),a
        jp 0
rl_src: ld hl,$4456         ; "VD": tells VZ-DECK it is coming back
        ld (HO),hl
        ld hl,HO+22
        ld de,$FA12
        ld bc,4
        ldir
        ld hl,$7FE8
        ld ($FB80),hl
        ld hl,(HO+26)
        ld de,511
        add hl,de
        ld a,h
        srl a
        ld (HO+28),a
        call D_C2S
        call D_READ
        di
rl_l:   ld hl,HO+28
        dec (hl)
        jr z,rl_x
        ld hl,($FB80)
        ld de,512
        add hl,de
        ld ($FB80),hl
        call D_NEXT
        di
        jr rl_l
rl_x:   ld hl,$F800
        ld ($FB80),hl
        jp $8000
rl_end:

; ---- the file list.  NC = a file was opened.
filelist:
        xor a
        ld (edmode),a
        ld (lcur),a
        ld (ltop),a
        call read_dir
fl_draw: call list_draw
        call flush
fl_key: call waitkey
        cp K_UP
        jr z,fl_up
        cp '.'
        jr z,fl_up
        cp K_DOWN
        jr z,fl_dn
        cp ' '
        jr z,fl_dn
        cp K_PGUP
        jr z,fl_pu
        cp K_PGDN
        jr z,fl_pd
        cp K_RET
        jr z,fl_sel
        cp K_FIRE
        jr z,fl_sel
        cp K_QUIT
        jr z,fl_esc
        cp 'q'
        jr z,fl_esc
        cp 'Q'
        jr z,fl_esc
        jr fl_key
fl_esc: scf
        ret
fl_up:  ld a,(lcur)
        or a
        jr z,fl_key
        dec a
        ld (lcur),a
        jr fl_fix
fl_dn:  ld a,(lcur)
        inc a
        ld hl,dcount
        cp (hl)
        jr nc,fl_key
        ld (lcur),a
        jr fl_fix
fl_pu:  ld a,(docrows)
        dec a
        ld b,a
        ld a,(lcur)
        sub b
        jr nc,fl_pu1
        xor a
fl_pu1: ld (lcur),a
        jr fl_fix
fl_pd:  ld a,(docrows)
        dec a
        ld b,a
        ld a,(lcur)
        add a,b
        ld hl,dcount
        cp (hl)
        jr c,fl_pd1
        ld a,(hl)
        dec a
fl_pd1: ld (lcur),a
fl_fix: ld a,(dcount)       ; keep the cursor in view
        or a
        jp z,fl_draw
        ld a,(lcur)
        ld hl,ltop
        cp (hl)
        jr nc,fl_f1
        ld (hl),a
        jp fl_draw
fl_f1:  ld b,a
        ld a,(docrows)
        add a,(hl)
        dec a               ; last visible index
        cp b
        jp nc,fl_draw
        ld a,(docrows)
        ld c,a
        ld a,b
        sub c
        inc a
        ld (hl),a
        jp fl_draw
fl_sel: ld a,(dcount)
        or a
        jp z,fl_key
        call cur_rec        ; HL = record
        ld a,(hl)
        cp 2
        jr z,fl_file
        ld bc,12            ; a folder (or ..): go into it
        add hl,bc
        call ld24
        ld bc,cwd
        call st24
        xor a
        ld (lcur),a
        ld (ltop),a
        call read_dir
        jp fl_draw
fl_file: push hl
        ld bc,12
        add hl,bc
        call ld24
        ld (ldcl),hl
        ld a,e
        ld (ldcl+2),a
        pop hl
        push hl
        ld bc,15
        add hl,bc
        ld a,(hl)
        ld (ldsz),a
        inc hl
        ld a,(hl)
        ld (ldsz+1),a
        inc hl
        ld a,(hl)
        ld (ldsz+2),a
        inc hl
        ld a,(hl)           ; over 16MB: certainly too big
        or a
        jr z,fl_f2
        ld a,$FF
        ld (ldsz+2),a
fl_f2:  pop hl               ; (0.6: .VZ files and big files go to an overlay)
        push hl
        call open_file
        pop hl
        ret c
        inc hl
        ld de,fname
        ld bc,11
        ldir
        ld a,1
        ld (named),a
        or a
        ret

cur_rec: ld a,(lcur)        ; HL = record under the cursor
idx_rec: ld l,a             ; A = index -> HL = record
        ld h,0
        add hl,hl
        ld de,DPTR
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

list_draw:
        call cls_scr
        xor a
        call set_rows
        ld hl,s_listhdr
        ld de,SCR
        call puts
        ld a,(fs_ok)
        or a
        jr nz,ld_1
        ld hl,m_nofs
        ld de,SCR+64+1
        jp puts
ld_1:   ld a,(dcount)
        or a
        jr nz,ld_2
        ld hl,m_empty
        ld de,SCR+64+1
        jp puts
ld_2:   ld a,(ltop)
        ld (lidx),a
        ld hl,SCR+32
        ld (lrow),hl
        ld a,(docrows)
        ld b,a
ld_row: push bc
        ld a,(lidx)
        ld hl,dcount
        cp (hl)
        jp nc,ld_done
        call idx_rec
        ld de,(lrow)
        inc de
        ld a,(hl)
        or a
        jr nz,ld_nf
        ld a,'.'            ; ..
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld a,'/'
        ld (de),a
        jr ld_sel
ld_nf:  push hl
        inc hl
        call put83
        pop hl
        ld a,(hl)
        cp 1
        jr nz,ld_fsz
        ld a,'/'
        ld (de),a
        ld hl,s_dir
        ld de,(lrow)
        ld bc,26
        ex de,hl
        add hl,bc
        ex de,hl
        call puts
        jr ld_sel
ld_fsz: ld bc,18            ; size: 4th byte set = huge
        add hl,bc
        ld a,(hl)
        dec hl
        dec hl
        dec hl
        or a
        jr z,ld_s1
        ld hl,s_big
        ld de,(lrow)
        ld bc,28
        ex de,hl
        add hl,bc
        ex de,hl
        call puts
        jr ld_sel
ld_s1:  ld de,n24
        ld bc,3
        ldir
        call putdec24       ; B = digits
        ld hl,(lrow)        ; right align, ending at column 30
        ld de,31
        add hl,de
        ld a,l
        sub b
        ld l,a
        jr nc,ld_s2
        dec h
ld_s2:  ex de,hl
        ld hl,NUMTMP
        ld c,b
        ld b,0
        ldir
ld_sel: ld a,(lidx)         ; highlight the cursor row
        ld hl,lcur
        cp (hl)
        jr nz,ld_nx
        ld hl,(lrow)
        ld b,32
ld_h:   set 7,(hl)
        inc hl
        djnz ld_h
ld_nx:  ld hl,(lrow)
        ld de,32
        add hl,de
        ld (lrow),hl
        ld hl,lidx
        inc (hl)
        pop bc
        dec b
        jp nz,ld_row
        ret
ld_done: pop bc
        ret

; ---- yes / no question on the title bar.  A = 'Y', 'N' or 0 (cancelled)
ask_yn: push hl
        ld a,(edmode)
        ld (askmode),a
        xor a
        ld (edmode),a
        pop hl
        call show_status
ay_k:   call waitkey
        cp 'a'
        jr c,ay_u
        sub 32
ay_u:   cp 'Y'
        jr z,ay_r
        cp 'N'
        jr z,ay_r
        cp 'A'              ; 'A' (all) only where asked for
        jr nz,ay_q
        ld b,a
        ld a,(askall)
        or a
        ld a,b
        jr nz,ay_r
ay_q:   cp K_QUIT
        jr z,ay_c
        cp 'C'
        jr nz,ay_k
ay_c:   xor a
ay_r:   push af
        xor a
        ld (msgflag),a
        ld a,(askmode)
        ld (edmode),a
        ld a,1
        ld (waitrel),a
        pop af
        ret

; ---- type a file name.  NC = PNAME holds a valid 8.3 name
input_name:
        xor a
        ld (edmode),a
in_drw: call clr_title
        ld hl,s_saveas
        ld de,SCR
        call puts
        ld hl,INBUF
        ld a,(inlen)
        or a
        jr z,in_cur
        ld c,a
        ld b,0
        ldir
in_cur: ld a,' '+128
        ld (de),a
        call flush
in_k:   call waitkey
        cp K_QUIT
        jr z,in_esc
        cp K_RET
        jr z,in_ok
        cp K_BS
        jr z,in_bs
        cp 32
        jr c,in_k
        cp 127
        jr nc,in_k
        cp 'a'
        jr c,in_u
        cp 'z'+1
        jr nc,in_u
        sub 32
in_u:   call validch
        jr c,in_k
        ld c,a
        ld a,(inlen)
        cp 12
        jr nc,in_k
        ld e,a
        ld d,0
        ld hl,INBUF
        add hl,de
        ld (hl),c
        inc a
        ld (inlen),a
        jr in_drw
in_bs:  ld a,(inlen)
        or a
        jr z,in_k
        dec a
        ld (inlen),a
        jr in_drw
in_esc: ld a,1
        ld (waitrel),a
        scf
        ret
in_ok:  ld a,1
        ld (waitrel),a
        call parse_name
        ret nc
        ld hl,m_badname
        call set_msg
        scf
        ret

validch:                    ; NC if A can go in a file name
        cp 'A'
        jr c,vc_1
        cp 'Z'+1
        ccf
        ret nc
vc_1:   cp '0'
        jr c,vc_2
        cp '9'+1
        ccf
        ret nc
vc_2:   ld hl,s_namechr
        ld b,a
vc_l:   ld a,(hl)
        or a
        jr z,vc_no
        cp b
        ld a,b
        ret z
        inc hl
        jr vc_l
vc_no:  ld a,b
        scf
        ret

parse_name:                 ; INBUF -> PNAME (no extension = .TXT); C = bad
        ld hl,PNAME
        ld de,PNAME+1
        ld bc,10
        ld (hl),' '
        ldir
        ld a,(inlen)
        ld c,a
        or a
        jr z,pn_bad
        ld hl,INBUF
        ld de,PNAME
        ld b,0
pn_n:   ld a,c
        or a
        jr z,pn_noext
        ld a,(hl)
        inc hl
        dec c
        cp '.'
        jr z,pn_dot
        ld (de),a
        inc de
        inc b
        ld a,b
        cp 9
        jr nc,pn_bad
        jr pn_n
pn_dot: ld a,b
        or a
        jr z,pn_bad
        ld de,PNAME+8
        ld b,0
pn_e:   ld a,c
        or a
        jr z,pn_ende
        ld a,(hl)
        inc hl
        dec c
        cp '.'
        jr z,pn_bad
        ld (de),a
        inc de
        inc b
        ld a,b
        cp 4
        jr nc,pn_bad
        jr pn_e
pn_ende: ld a,b
        or a
        jr nz,pn_ok
        jr pn_def
pn_noext: ld a,b
        or a
        jr z,pn_bad
pn_def: ld hl,s_txt
        ld de,PNAME+8
        ld bc,3
        ldir
pn_ok:  or a
        ret
pn_bad: scf
        ret


