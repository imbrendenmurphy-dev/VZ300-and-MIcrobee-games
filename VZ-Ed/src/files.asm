; ===========================================================================
;  files.asm - FAT32 reading and safe saving on the BennVenn SD card
;
;  Only two DOS routines are used: read a sector ($575D) and write a sector
;  ($568C), both through the DOS buffer at $F800.  Everything else (FAT
;  chains, folders, free clusters) is done here, by the FAT32 rules:
;    - FAT sectors are found from the partition start (the DOS's own chain
;      code leaves that out, which only works on unpartitioned cards)
;    - every FAT change is written to both copies of the FAT
;    - a save writes a new file first, then renames; the old file is kept as
;      NAME.BAK, so a crash or power cut never leaves you with nothing
;  Numbers are 24 bit (E:HL), which covers every sector the DOS can reach.
; ===========================================================================

; ---- 24 bit helpers
ld24:   ld e,(hl)           ; (HL) -> E:HL
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ex de,hl
        ld e,a
        ret
st24:   ld a,l              ; E:HL -> (BC)
        ld (bc),a
        inc bc
        ld a,h
        ld (bc),a
        inc bc
        ld a,e
        ld (bc),a
        ret
addm24: ld a,(bc)           ; E:HL += (BC)
        add a,l
        ld l,a
        inc bc
        ld a,(bc)
        adc a,h
        ld h,a
        inc bc
        ld a,(bc)
        adc a,e
        ld e,a
        ret
subm24: ld a,(bc)           ; E:HL -= (BC), C = borrow (uses D)
        ld d,a
        ld a,l
        sub d
        ld l,a
        inc bc
        ld a,(bc)
        ld d,a
        ld a,h
        sbc a,d
        ld h,a
        inc bc
        ld a,(bc)
        ld d,a
        ld a,e
        sbc a,d
        ld e,a
        ret
cmpm24: push hl             ; C if E:HL < (BC)
        push de
        call subm24
        pop de
        pop hl
        ret
inc24:  ld bc,1
        add hl,bc
        ld a,e
        adc a,0
        ld e,a
        ret
clvalid:                    ; NC if 2 <= E:HL < clend
        ld a,e
        or h
        jr nz,cv_1
        ld a,l
        cp 2
        ret c
cv_1:   ld bc,clend
        call cmpm24
        ccf
        ret

; ---- sector I/O through the DOS
rd_sec: push bc             ; sector E:HL -> SECBUF
        push de
        push hl
        call dos_nocache
        ld bc,SECBUF
        ld ($FB80),bc
        ld d,0
        call DOS_RDSEC
        di
        pop hl
        pop de
        pop bc
        ret
wr_sec: push bc             ; SECBUF -> sector E:HL
        push de
        push hl
        ld d,0
        call DOS_WRSEC
        di
        call dos_nocache
        pop hl
        pop de
        pop bc
        ret
dos_nocache:                ; the DOS remembers the last sector read; forget it
        ld a,$FF
        ld ($FB06),a
        ld ($FB07),a
        ld ($FB08),a
        ld ($FB09),a
        ret

; ---- card geometry, checked against the DOS.  fs_ok = 0 means hands off.
fs_init:
        xor a
        ld (fs_ok),a
        ld a,($FB0D)
        or a
        ret nz
        ld hl,($FB0A)
        ld a,($FB0C)
        ld (part),hl
        ld (part+2),a
        ld e,a
        call rd_sec
        ld hl,(SECBUF+11)   ; 512 bytes a sector
        ld de,512
        or a
        sbc hl,de
        ret nz
        ld hl,(SECBUF+$16)  ; FAT16 sizes are zero on FAT32
        ld a,h
        or l
        ret nz
        ld a,(SECBUF+$27)
        or a
        ret nz
        ld a,(SECBUF+$2F)
        or a
        ret nz
        ld a,(SECBUF+$10)
        ld (nfats),a
        dec a
        cp 2
        ret nc
        ld a,(SECBUF+13)
        ld (spc),a
        or a
        ret z
        ld c,a
        ld b,0
fi_sh:  srl c
        jr c,fi_shd
        inc b
        jr fi_sh
fi_shd: ld a,c
        or a
        ret nz              ; not a power of two
        ld a,b
        ld (sh),a
        ld hl,512           ; bytes per cluster
        ld e,0
        or a
        jr z,fi_b
fi_bl:  add hl,hl
        rl e
        djnz fi_bl
fi_b:   ld bc,bpc
        call st24
        ld hl,(part)
        ld a,(part+2)
        ld e,a
        ld bc,(SECBUF+14)   ; reserved sectors
        add hl,bc
        ld a,e
        adc a,0
        ld e,a
        ld bc,fat1
        call st24
        ld hl,(SECBUF+$24)
        ld a,(SECBUF+$26)
        ld (fatsz),hl
        ld (fatsz+2),a
        ld hl,fat1
        call ld24
        ld a,(nfats)
        ld b,a
fi_df:  push bc
        ld bc,fatsz
        call addm24
        pop bc
        djnz fi_df
        ld bc,data
        call st24
        ld a,($FA0D)        ; must agree with where the DOS reads files
        or a
        ret nz
        ld a,($FA0A)
        cp l
        ret nz
        ld a,($FA0B)
        cp h
        ret nz
        ld a,($FA0C)
        cp e
        ret nz
        ld hl,(SECBUF+$2C)
        ld a,(SECBUF+$2E)
        ld (rootcl),hl
        ld (rootcl+2),a
        ld hl,(part)
        ld a,(part+2)
        ld e,a
        ld bc,(SECBUF+$30)
        add hl,bc
        ld a,e
        adc a,0
        ld e,a
        ld bc,fsinfo
        call st24
        ; last cluster: end of the volume, capped at the DOS's 24 bit reach
        ld hl,(SECBUF+$20)
        ld a,(SECBUF+$22)
        ld e,a
        ld a,(SECBUF+$23)
        or a
        jr z,fi_t1
        ld hl,$FFFF
        ld e,h
fi_t1:  ld bc,part
        call addm24
        jr nc,fi_t2
        ld hl,$FFFF
        ld e,h
fi_t2:  ld bc,data
        call subm24
        ret c
        ld a,(sh)
        or a
        jr z,fi_t3
        ld b,a
fi_sr:  srl e
        rr h
        rr l
        djnz fi_sr
fi_t3:  ld bc,2
        add hl,bc
        ld a,e
        adc a,0
        ld e,a
        ld bc,clend
        call st24
        ld a,(fatsz+2)      ; and never past the end of the FAT
        cp 2
        jr nc,fi_nc
        ld hl,fatsz
        call ld24
        ld b,7
fi_c7:  add hl,hl
        rl e
        djnz fi_c7
        ld bc,clend
        call cmpm24
        jr nc,fi_nc
        ld bc,clend
        call st24
fi_nc:  ld hl,2             ; where to start looking for free space
        ld (hint),hl
        xor a
        ld (hint+2),a
        ld hl,fsinfo
        call ld24
        call rd_sec
        ld hl,(SECBUF)
        ld de,$5252
        or a
        sbc hl,de
        jr nz,fi_ok
        ld hl,(SECBUF+2)
        ld de,$4161
        or a
        sbc hl,de
        jr nz,fi_ok
        ld a,(SECBUF+$1EF)
        or a
        jr nz,fi_ok
        ld hl,(SECBUF+$1EC)
        ld a,(SECBUF+$1EE)
        ld e,a
        call clvalid
        jr c,fi_ok
        ld bc,hint
        call st24
fi_ok:  ld a,1
        ld (fs_ok),a
        ret

; ---- FAT access.  One FAT sector is cached in SECBUF while fatcache is set.
fat_load:                   ; E:HL = FAT sector number (from the FAT start)
        ld bc,fat1
        call addm24
        ld a,(fatcache)
        cp l
        jr nz,fa_rd
        ld a,(fatcache+1)
        cp h
        jr nz,fa_rd
        ld a,(fatcache+2)
        cp e
        ret z
fa_rd:  call fat_flush
        call rd_sec
        ld bc,fatcache
        jp st24
fat_flush:
        ld a,(fatdirty)
        or a
        ret z
        xor a
        ld (fatdirty),a
        push hl
        push de
        ld hl,fatcache
        call ld24
        call wr_sec
        ld a,(nfats)
        cp 2
        jr c,ff_1
        ld bc,fatsz
        call addm24
        call wr_sec
ff_1:   pop de
        pop hl
        ret
fat_sync:                   ; write out the FAT sector and give SECBUF back
        call fat_flush
        ld a,$FF
        ld (fatcache),a
        ld (fatcache+1),a
        ld (fatcache+2),a
        ret
fat_entry:                  ; cluster E:HL -> HL = its FAT entry in SECBUF
        ld a,l
        and $7F
        push af
        ld b,7
fe_s:   srl e
        rr h
        rr l
        djnz fe_s
        call fat_load
        pop af
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld bc,SECBUF
        add hl,bc
        ret
fat_get:                    ; cluster E:HL -> next E:HL, A <> 0 at end of chain
        call fat_entry
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        and $0F
        ld h,b
        ld l,c
        ret
fat_set:                    ; cluster E:HL = setv / setv3 (top nibble kept)
        call fat_entry
        ld a,(setv)
        ld (hl),a
        inc hl
        ld a,(setv+1)
        ld (hl),a
        inc hl
        ld a,(setv+2)
        ld (hl),a
        inc hl
        ld a,(hl)
        and $F0
        ld b,a
        ld a,(setv3)
        or b
        ld (hl),a
        ld a,1
        ld (fatdirty),a
        ret
set_free:
        xor a
        ld (setv),a
        ld (setv+1),a
        ld (setv+2),a
        ld (setv3),a
        ret
set_eoc:
        ld a,$FF
        ld (setv),a
        ld (setv+1),a
        ld (setv+2),a
        ld a,$0F
        ld (setv3),a
        ret

clus_lba:                   ; cluster E:HL, sector A -> sector number E:HL
        push af
        ld bc,2
        or a
        sbc hl,bc
        ld a,e
        sbc a,0
        ld e,a
        ld a,(sh)
        or a
        jr z,cb_1
        ld b,a
cb_s:   add hl,hl
        rl e
        djnz cb_s
cb_1:   ld bc,data
        call addm24
        pop af
        ld c,a
        ld b,0
        add hl,bc
        ld a,e
        adc a,0
        ld e,a
        ret

; ---- find A free clusters and chain them (CLIST).  C = card full.
alloc_chain:
        ld (anum),a
        or a
        ret z
        xor a
        ld (afound),a
        ld hl,hint
        call ld24
        call clvalid
        jr nc,ac_h
        ld hl,2
        ld e,0
ac_h:   ld bc,acur
        call st24
        ld hl,clend         ; look at each cluster exactly once
        call ld24
        ld bc,2
        or a
        sbc hl,bc
        ld a,e
        sbc a,0
        ld e,a
        ld bc,aleft
        call st24
ac_lp:  ld hl,acur
        call ld24
        call fat_get
        or a
        jr nz,ac_used
        ld a,l
        or h
        or e
        jr nz,ac_used
        ld a,(afound)       ; free: note it
        ld c,a
        add a,a
        add a,c
        ld c,a
        ld b,0
        ld hl,CLIST
        add hl,bc
        push hl
        ld hl,acur
        call ld24
        pop bc
        call st24
        ld a,(afound)
        inc a
        ld (afound),a
        ld b,a
        ld a,(anum)
        cp b
        jr z,ac_link
ac_used: ld hl,acur
        call ld24
        call inc24
        ld bc,clend
        call cmpm24
        jr c,ac_nw
        ld hl,2
        ld e,0
ac_nw:  ld bc,acur
        call st24
        ld hl,aleft
        call ld24
        ld a,l
        sub 1
        ld l,a
        ld a,h
        sbc a,0
        ld h,a
        ld a,e
        sbc a,0
        ld e,a
        ld bc,aleft
        call st24
        ld a,l
        or h
        or e
        jp nz,ac_lp
ac_full: call fat_sync
        scf
        ret
ac_link: ld a,(anum)
        ld b,a
        ld hl,CLIST
ac_lk:  push bc
        push hl
        ld a,b
        cp 1
        jr z,ac_eoc
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (setv),a
        inc hl
        ld a,(hl)
        ld (setv+1),a
        inc hl
        ld a,(hl)
        ld (setv+2),a
        xor a
        ld (setv3),a
        jr ac_st
ac_eoc: call set_eoc
ac_st:  pop hl
        push hl
        call ld24
        call fat_set
        pop hl
        inc hl
        inc hl
        inc hl
        pop bc
        djnz ac_lk
        call fat_sync
        ld hl,acur
        call ld24
        call inc24
        ld bc,hint
        call st24
        or a
        ret

free_chain:                 ; free the chain starting at E:HL
        ld (fccl),hl
        ld a,e
        ld (fccl+2),a
fc_lp:  ld hl,fccl
        call ld24
        call clvalid
        jr c,fc_done
        call fat_get
        ld (fcflag),a
        ld (fcnext),hl
        ld a,e
        ld (fcnext+2),a
        call set_free
        ld hl,fccl
        call ld24
        call fat_set
        ld a,(fcflag)
        or a
        jr nz,fc_done
        ld hl,(fcnext)
        ld (fccl),hl
        ld a,(fcnext+2)
        ld (fccl+2),a
        jr fc_lp
fc_done: jp fat_sync

; ---- walking a folder: dwptr -> current 32 byte entry in SECBUF
dw_start:                   ; E:HL = folder cluster (0 = root)
        ld a,e
        or h
        or l
        jr nz,dws_1
        ld hl,rootcl
        call ld24
dws_1:  ld bc,dwcl
        call st24
        xor a
        ld (dwsec),a
dw_load: call fat_sync
        ld hl,dwcl
        call ld24
        ld a,(dwsec)
        call clus_lba
        ld bc,dwlba
        call st24
        call rd_sec
        ld hl,SECBUF
        ld (dwptr),hl
        or a
        ret
dw_next:                    ; next entry; C at the end of the folder
        ld hl,(dwptr)
        ld de,32
        add hl,de
        ld (dwptr),hl
        ld a,h
        cp (SECBUF+512)/256
        jr z,dwn_s
        or a
        ret
dwn_s:  ld a,(dwsec)
        inc a
        ld (dwsec),a
        ld b,a
        ld a,(spc)
        cp b
        jr nz,dw_load
        ld hl,dwcl
        call ld24
        call fat_get
        or a
        scf
        ret nz
        call clvalid
        ret c
        ld bc,dwcl
        call st24
        xor a
        ld (dwsec),a
        jr dw_load
dir_write:                  ; write the folder sector back
        ld hl,dwlba
        call ld24
        jp wr_sec

dir_find:                   ; NAMEBUF in folder E:HL -> NC found (dwptr)
        call dw_start
df_lp:  ld hl,(dwptr)
        ld a,(hl)
        or a
        scf
        ret z
        cp $E5
        jr z,df_n
        push hl
        ld de,11
        add hl,de
        ld a,(hl)
        pop hl
        cp $0F
        jr z,df_n
        bit 3,a
        jr nz,df_n
        ld de,NAMEBUF
        ld b,11
df_c:   ld a,(de)
        cp (hl)
        jr nz,df_n
        inc hl
        inc de
        djnz df_c
        or a
        ret
df_n:   call dw_next
        ret c
        jr df_lp

dir_slot:                   ; a free entry in folder E:HL -> NC (dwptr)
        call dw_start
dsl_lp: ld hl,(dwptr)
        ld a,(hl)
        or a
        ret z
        cp $E5
        ret z
        call dw_next
        jr nc,dsl_lp
        ; folder is full: give it another (empty) cluster
        ld a,1
        call alloc_chain
        ret c
        ld hl,(CLIST)
        ld (setv),hl
        ld a,(CLIST+2)
        ld (setv+2),a
        xor a
        ld (setv3),a
        ld hl,dwcl
        call ld24
        call fat_set
        call fat_sync
        ld hl,CLIST
        call ld24
        ld bc,dwcl
        call st24
        ld hl,SECBUF
        ld de,SECBUF+1
        ld bc,511
        ld (hl),0
        ldir
        xor a
        ld (dwsec),a
dsl_z:  ld hl,dwcl
        call ld24
        ld a,(dwsec)
        call clus_lba
        call wr_sec
        ld a,(dwsec)
        inc a
        ld (dwsec),a
        ld b,a
        ld a,(spc)
        cp b
        jr nz,dsl_z
        xor a
        ld (dwsec),a
        ld hl,dwcl
        call ld24
        xor a
        call clus_lba
        ld bc,dwlba
        call st24
        ld hl,SECBUF
        ld (dwptr),hl
        or a
        ret

del_entry:                  ; delete the entry dir_find found, free its clusters
        ld hl,(dwptr)
        push hl
        ld de,26
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push hl
        ld bc,20
        add hl,bc
        ld a,(hl)
        pop hl
        ld (fccl),de
        ld (fccl+2),a
        ld (hl),$E5
        call dir_write
        ld hl,fccl
        call ld24
        jp free_chain

rename_entry:               ; the entry dir_find found gets NEWNAME
        ld de,(dwptr)
        ld hl,NEWNAME
        ld bc,11
        ldir
        jp dir_write

setname:                    ; HL -> NAMEBUF (11)
        ld de,NAMEBUF
        ld bc,11
        ldir
        ret
cwd_find:                   ; HL = name -> dir_find in the current folder
        call setname
        ld hl,cwd
        call ld24
        jp dir_find

; ---- write a new file NAMEBUF in folder wdir from seg1/seg2.  C = failed.
write_new:
        ld hl,(seg1p)
        ld bc,(seg1l)
        call count_lf
        push de
        ld hl,(seg2p)
        ld bc,(seg2l)
        call count_lf
        pop hl
        add hl,de
        ld a,(wcrlf)
        or a
        jr nz,wn_1
        ld hl,0
wn_1:   ld de,(seg1l)
        add hl,de
        ld de,(seg2l)
        add hl,de
        ld (outlen),hl
        ld e,0              ; clusters needed
        ld c,0
wn_cl:  ld a,h
        or l
        or e
        jr z,wn_cd
        inc c
        push bc
        ld bc,bpc
        call subm24
        pop bc
        jr nc,wn_cl
wn_cd:  ld a,c
        ld (wncl),a
        cp 129
        ccf
        ret c
        call alloc_chain
        ret c
        xor a
        ld (wci),a
        ld (wsec),a
        ld hl,SECBUF
        ld (wpos),hl
        ld hl,(seg1p)
        ld bc,(seg1l)
        call wseg
        ld hl,(seg2p)
        ld bc,(seg2l)
        call wseg
        ld hl,(wpos)
        ld a,l
        or a
        jr nz,wn_z
        ld a,h
        cp SECBUF/256
        jr z,wn_ent
wn_z:   ld hl,(wpos)        ; pad the last sector with zeros
        ld a,h
        cp (SECBUF+512)/256
        jr z,wn_zf
        ld (hl),0
        inc hl
        ld (wpos),hl
        jr wn_z
wn_zf:  call wflush
wn_ent: ld a,(wncl)
        or a
        ld hl,0
        ld e,l
        jr z,wn_f
        ld hl,CLIST
        call ld24
wn_f:   ld (wfirst),hl
        ld a,e
        ld (wfirst+2),a
        ld hl,wdir
        call ld24
        call dir_slot
        jr nc,wn_fill
        ld hl,wfirst        ; no room for the name: give the space back
        call ld24
        call free_chain
        scf
        ret
wn_fill: ld hl,(dwptr)
        push hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,31
        ldir
        pop hl
        push hl
        ex de,hl
        ld hl,NAMEBUF
        ld bc,11
        ldir
        ex de,hl
        ld (hl),$20         ; attribute: archive
        pop hl
        push hl
        ld bc,14
        add hl,bc
        ld de,FTIME
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,FDATE
        ld (hl),e           ; created
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e           ; accessed
        inc hl
        ld (hl),d
        inc hl
        ld a,(wfirst+2)     ; +20 cluster (high)
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        ld de,FTIME         ; +22 written
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,FDATE
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(wfirst)      ; +26 cluster (low)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(outlen)      ; +28 size
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        call dir_write
        or a
        ret

wseg:   ld a,b              ; HL = text, BC = length -> file (LF -> CR LF)
        or c
        ret z
ws_l:   ld a,(hl)
        inc hl
        cp 10
        jr nz,ws_p
        ld d,a
        ld a,(wcrlf)
        or a
        ld a,d
        jr z,ws_p
        ld a,13
        call wputb
        ld a,10
ws_p:   call wputb
        dec bc
        ld a,b
        or c
        jr nz,ws_l
        ret
wputb:  push hl
        ld hl,(wpos)
        ld (hl),a
        inc hl
        ld (wpos),hl
        ld a,h
        cp (SECBUF+512)/256
        call z,wflush
        pop hl
        ret
wflush: push bc
        push de
        push hl
        ld a,(wci)
        ld c,a
        add a,a
        add a,c
        ld c,a
        ld b,0
        ld hl,CLIST
        add hl,bc
        call ld24
        ld a,(wsec)
        call clus_lba
        call wr_sec
        ld a,(wsec)
        inc a
        ld (wsec),a
        ld b,a
        ld a,(spc)
        cp b
        jr nz,wf_1
        xor a
        ld (wsec),a
        ld a,(wci)
        inc a
        ld (wci),a
wf_1:   ld hl,SECBUF
        ld (wpos),hl
        pop hl
        pop de
        pop bc
        ret

; ---- save the document as fname in the current folder.  C = not saved.
save_doc:
        ld a,(fs_ok)
        or a
        jr nz,sv_ok
        ld hl,m_nofs
        call set_msg
        scf
        ret
sv_ok:  ld hl,m_saving
        call show_status
        ld hl,s_tmpname     ; 1. clear away an old temp file
        call cwd_find
        call nc,del_entry
        ld hl,BUFS          ; 2. write the text as the temp file
        ld (seg1p),hl
        ld hl,(gs)
        ld de,BUFS
        or a
        sbc hl,de
        ld (seg1l),hl
        ld hl,(ge)
        ld (seg2p),hl
        ex de,hl
        ld hl,BUFE
        or a
        sbc hl,de
        ld (seg2l),hl
        ld a,(crlf)
        ld (wcrlf),a
        ld hl,cwd
        call ld24
        ld bc,wdir
        call st24
        ld hl,s_tmpname
        call setname
        call write_new
        jr nc,sv_3
        ld hl,m_cardfull
        call set_msg
        scf
        ret
sv_3:   ld hl,fname         ; 3. the old version becomes NAME.BAK
        call cwd_find
        jr c,sv_4
        ld a,(fname+8)
        cp 'B'
        jr nz,sv_bk
        ld a,(fname+9)
        cp 'A'
        jr nz,sv_bk
        ld a,(fname+10)
        cp 'K'
        jr nz,sv_bk
        call del_entry      ; editing a .BAK itself: just replace it
        jr sv_4
sv_bk:  ld hl,fname
        ld de,NEWNAME
        ld bc,8
        ldir
        ld hl,s_bak
        ld bc,3
        ldir
        ld hl,NEWNAME
        call cwd_find
        call nc,del_entry
        ld hl,NEWNAME
        ld de,NAMEBUF
        ld bc,11
        ldir                ; keep NEWNAME = NAME.BAK
        ld hl,fname
        call cwd_find
        call nc,rename_entry
sv_4:   ld hl,s_tmpname     ; 4. the temp file takes the real name
        call cwd_find
        jr c,sv_err
        ld hl,fname
        ld de,NEWNAME
        ld bc,11
        ldir
        call rename_entry
        xor a
        ld (modified),a
        ld hl,m_saved
        call set_msg
        or a
        ret
sv_err: ld hl,m_saveerr
        call set_msg
        scf
        ret

; ---- load the file at cluster ldcl, size ldsz.  C = not loaded (message set).
load_file:
        ld a,(fs_ok)
        or a
        jr nz,lf_1
        ld hl,m_nofs
        call set_msg
        scf
        ret
lf_1:   ld a,(ldsz+2)
        or a
        jr nz,lf_big
        ld hl,BUFE-BUFS
        ld de,(ldsz)
        or a
        sbc hl,de
        jr nc,lf_2
lf_big: ld hl,m_toobig
        call set_msg
        scf
        ret
lf_2:   call buf_clear
        ld hl,BUFS
        ld (lddst),hl
        xor a
        ld (crlf),a
        ld (trunc),a
        ld hl,(ldsz)
        ld (ldrem),hl
        ld hl,(ldcl)
        ld (ldcur),hl
        ld a,(ldcl+2)
        ld (ldcur+2),a
lf_cl:  ld hl,(ldrem)
        ld a,h
        or l
        jp z,lf_done
        ld hl,ldcur
        call ld24
        call clvalid
        jr c,lf_trunc
        xor a
        ld (lsec),a
lf_sec: call fat_sync
        ld hl,ldcur
        call ld24
        ld a,(lsec)
        call clus_lba
        call rd_sec
        ld hl,(ldrem)
        ld bc,512
        or a
        sbc hl,bc
        jr nc,lf_st
        add hl,bc
        ld b,h
        ld c,l
        ld hl,0
lf_st:  ld (ldrem),hl
        ld hl,SECBUF
        ld de,(lddst)
lf_cp:  ld a,(hl)
        inc hl
        cp 13
        jr z,lf_cr
        ld (de),a
        inc de
        jr lf_nx
lf_cr:  ld a,1
        ld (crlf),a
lf_nx:  dec bc
        ld a,b
        or c
        jr nz,lf_cp
        ld (lddst),de
        ld hl,(ldrem)
        ld a,h
        or l
        jr z,lf_done
        ld a,(lsec)
        inc a
        ld (lsec),a
        ld b,a
        ld a,(spc)
        cp b
        jr nz,lf_sec
        ld hl,ldcur
        call ld24
        call fat_get
        or a
        jr nz,lf_trunc
        ld bc,ldcur
        call st24
        jp lf_cl
lf_trunc: ld a,1
        ld (trunc),a
lf_done: call fat_sync
        ld hl,(lddst)       ; text to the end of the buffer, cursor at the top
        ld de,BUFS
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        jr z,lf_e
        push bc
        ld hl,(lddst)
        dec hl
        ld de,BUFE-1
        lddr
        inc de
        ld (ge),de
        pop bc
        ld a,(crlf)         ; no CR seen: LF-only file, unless it has no LFs at all
        or a
        jr nz,lf_e
        ld hl,(ge)
        call count_lf
        ld a,d
        or e
        jr nz,lf_e2
        ld a,1
        ld (crlf),a
        jr lf_e2
lf_e:   ld a,(crlf)
        or a
        jr nz,lf_e2
        ld a,b
        or c
        jr nz,lf_e2
        ld a,1
        ld (crlf),a
lf_e2:  ld hl,BUFS
        ld (gs),hl
        ld hl,1
        ld (curln),hl
        ld hl,0
        ld (top),hl
        ld (hs),hl
        xor a
        ld (modified),a
        call reset_goal
        ld a,(trunc)
        or a
        ret z
        ld hl,m_trunc
        call set_msg
        or a
        ret

; ---- read the current folder into DIRBUF/DPTR, sorted (folders first)
; record: type (0 parent, 1 folder, 2 file), name 11, cluster 3, size 4, attr
read_dir:
        xor a
        ld (dcount),a
        ld hl,DIRBUF
        ld (dwr),hl
        ld a,(fs_ok)
        or a
        ret z
        ld hl,cwd
        call ld24
        call dw_start
rdr_l:  ld hl,(dwptr)
        ld a,(hl)
        or a
        jr z,rdr_d
        cp $E5
        jr z,rdr_n
        push hl
        ld de,11
        add hl,de
        ld a,(hl)
        pop hl
        ld c,a
        cp $0F
        jr z,rdr_n
        and $0E             ; hidden, system, volume label
        jr nz,rdr_n
        ld a,(hl)
        cp '.'
        jr nz,rdr_k
        inc hl
        ld a,(hl)
        dec hl
        cp '.'
        jr nz,rdr_n         ; "." itself
        ld b,0
        jr rdr_r
rdr_k:  ld b,2
        bit 4,c
        jr z,rdr_r
        ld b,1
rdr_r:  ld de,(dwr)
        ld a,b
        ld (de),a
        inc de
        push hl
        ld bc,11
        ldir
        pop hl
        push hl
        ld bc,26
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        pop hl
        push hl
        ld bc,20
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc de
        pop hl
        push hl
        ld bc,28
        add hl,bc
        ld bc,4
        ldir
        pop hl
        push hl
        ld bc,11
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc de
        pop hl
        ld (dwr),de
        ld a,(dcount)
        inc a
        ld (dcount),a
        cp MAXENT
        jr z,rdr_d
rdr_n:  call dw_next
        jr nc,rdr_l
rdr_d:  ld a,(dcount)
        or a
        ret z
        ld b,a
        ld hl,DIRBUF
        ld de,DPTR
rdr_p:  ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        push bc
        ld bc,20
        add hl,bc
        pop bc
        djnz rdr_p
        ld a,(dcount)       ; insertion sort by type then name
        cp 2
        ret c
        ld c,1
so_i:   ld a,(dcount)
        cp c
        ret z
        ld l,c
        ld h,0
        add hl,hl
        ld de,DPTR
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (skey),de
        ld b,c
so_j:   ld a,b
        or a
        jr z,so_put
        ld l,b
        dec l
        ld h,0
        add hl,hl
        ld de,DPTR
        add hl,de
        push hl
        push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,(skey)
        call rec_gt
        pop bc
        pop hl
        jr nc,so_put
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        dec b
        jr so_j
so_put: ld l,b
        ld h,0
        add hl,hl
        ld de,DPTR
        add hl,de
        ld de,(skey)
        ld (hl),e
        inc hl
        ld (hl),d
        inc c
        jr so_i
rec_gt: ld b,12             ; C if record HL sorts after record DE
rg_l:   ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz rg_l
        ret

; ---- settings file VZED.CFG in the root folder
cfg_load:
        ld a,(fs_ok)
        or a
        ret z
        ld hl,s_cfgname
        call setname
        ld hl,0
        ld e,l
        call dir_find
        ret c
        ld hl,(dwptr)
        ld bc,26
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(dwptr)
        ld bc,20
        add hl,bc
        ld a,(hl)
        ex de,hl
        ld e,a
        ld bc,cfgcl
        call st24
        ld hl,cfgcl
        call ld24
        call clvalid
        ret c
        xor a
        call clus_lba
        call rd_sec
        ld hl,(SECBUF)
        ld de,'V'+256*'Z'
        or a
        sbc hl,de
        ret nz
        ld hl,(SECBUF+2)
        ld de,'E'+256*'D'
        or a
        sbc hl,de
        ret nz
        ld a,1
        ld (cfghave),a
        ld a,(SECBUF+5)
        cp 3
        jr nc,cl_1
        ld (dstyle),a
        ld (cfg_ds),a
cl_1:   ld a,(SECBUF+6)
        and 1
        ld (caps),a
        ld (cfg_caps),a
        ld a,(SECBUF+7)
        and 1
        ld (insmode),a
        ld (cfg_ins),a
        ret

cfg_save:                   ; only when a setting changed
        ld a,(fs_ok)
        or a
        ret z
        ld a,(dstyle)
        ld hl,cfg_ds
        cp (hl)
        jr nz,cs_1
        ld a,(caps)
        ld hl,cfg_caps
        cp (hl)
        jr nz,cs_1
        ld a,(insmode)
        ld hl,cfg_ins
        cp (hl)
        ret z
cs_1:   ld hl,CFGBUF
        ld (hl),'V'
        inc hl
        ld (hl),'Z'
        inc hl
        ld (hl),'E'
        inc hl
        ld (hl),'D'
        inc hl
        ld (hl),1
        inc hl
        ld a,(dstyle)
        ld (hl),a
        inc hl
        ld a,(caps)
        ld (hl),a
        inc hl
        ld a,(insmode)
        ld (hl),a
        ld a,(cfghave)
        or a
        jr z,cs_new
        ld hl,cfgcl         ; rewrite its one sector in place
        call ld24
        call clvalid
        ret c
        call fat_sync
        xor a
        call clus_lba
        push hl
        push de
        call rd_sec
        ld hl,CFGBUF
        ld de,SECBUF
        ld bc,8
        ldir
        pop de
        pop hl
        jp wr_sec
cs_new: ld hl,CFGBUF
        ld (seg1p),hl
        ld hl,8
        ld (seg1l),hl
        ld hl,0
        ld (seg2l),hl
        ld (seg2p),hl
        xor a
        ld (wcrlf),a
        ld hl,0
        ld (wdir),hl
        ld (wdir+2),a
        ld hl,s_cfgname
        call setname
        jp write_new
