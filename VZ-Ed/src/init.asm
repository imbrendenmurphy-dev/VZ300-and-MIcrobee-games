; ===========================================================================
;  (0.7) start-up code.  Stored in the file after the tail, so it is loaded
;  into the (still empty) text buffer and run there once from start; the text
;  buffer overwrites it later.  Nothing here may be called after start-up.
;  clip_init's 10K copy of $4000-$67FF goes to CIBUF, above this code.
; ===========================================================================
init:
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
        ret z
        call verify_ho      ; really opened from VZ-DECK with a file?
        ret c
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
        ret

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
        ld de,CIBUF
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
        jp z,clip_off       ; looks the same: no separate bank
        ld hl,$4040
        ld e,(hl)           ; the bank's byte
        ld a,e
        cpl
        ld (hl),a
        ld b,(hl)           ; read back
        call clip_off
        ld a,(CIBUF+$40)     ; the home byte, as it was
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
        ld de,CIBUF
        ld bc,$2800
cc_l:   ld a,(de)
        cpi
        jr nz,cc_x
        inc de
        jp pe,cc_l
cc_x:   ld a,(wk)
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
        ld a,(SECBUF+7)     ; bit 0 insert mode, bit 1 word wrap (0.2)
        and 3
        ld (cfg_ins),a
        ld b,a
        and 1
        ld (insmode),a
        ld a,b
        rrca
        and 1
        ld (wrap),a
        ret

