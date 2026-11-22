; ===========================================================================
;  ovl_quit.asm (0.7) - overlay slot 8: leaving VZ-ED (moved out of the main
;  program to make room for undo).  Saves VZED.CFG if a setting changed, then
;  goes back: plug-in mode reloads SHELL.VZ (VZ-DECK), otherwise a restart.
;  Never returns, except when VZED.OVL can't be loaded: then c_quit restarts.
; ===========================================================================
        include "mainsym.inc"
        org OVLA
        dw 0
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
        jp z,ex_rst
        ld hl,s_shellnm     ; plug-in: find SHELL.VZ and reload it like the players do
        call setname
        ld hl,0
        ld e,l
        call dir_find
        jp c,ex_rst
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
        jp ex_rst

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
        call ins_byte
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
        call ins_byte
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

ins_byte:                   ; A = insert mode + 2 * word wrap
        ld a,(wrap)
        add a,a
        ld b,a
        ld a,(insmode)
        or b
        ret

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
