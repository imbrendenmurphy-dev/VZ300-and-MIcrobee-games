; ===========================================================================
;  ovl.asm - overlays (0.3).  Help and the sheet view are not in VZED.VZ: they
;  are 3K slots in VZED.OVL (root folder of the card, next to VZED.CFG), loaded
;  into OVLA when used.  OVLA is the fallback clipboard's RAM: if that holds a
;  block it is parked in the gap (free part of the text buffer) meanwhile, and
;  the overlay must not move the gap.  An overlay returns NC, or C with HL = a
;  logical position to move the cursor to (it may set top and hs itself).
;  Slot layout: dw build id (must equal ovl_id), then the code at OVLA+2.
;  This code is in the tail (copied below $A000 at start-up).
; ===========================================================================
OVLA    equ $8900
OVLSEC  equ 6               ; sectors per slot (3072 bytes)
OVLEND  equ $9700           ; overlays may use RAM up to here (DPTR is free too)

ovl_id: dw 0                ; filled in by build.py (a checksum of the code)

ovl_run:                    ; A = slot
        ld (ovslot),a
        xor a
        ld (edmode),a
        ld (ovst),a
        ld a,(fs_ok)
        or a
        jp z,ov_bad
        ld hl,s_ovlname
        call setname
        ld hl,0
        ld e,l
        call dir_find       ; root folder
        jp c,ov_bad
        ld hl,(dwptr)       ; first cluster
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
        ld bc,ldcur
        call st24
        call ov_stash
        ld a,(ovslot)       ; skip slot*6 sectors, then read 6
        ld b,a
        add a,a
        add a,b
        add a,a
        ld (ovskip),a
        ld a,OVLSEC
        ld (ovcnt),a
        ld hl,OVLA
        ld (lddst),hl
        xor a
        ld (lsec),a
ov_sec: ld hl,ldcur
        call ld24
        call clvalid
        jp c,ov_bad2        ; the file is too short
        call fat_sync
        ld hl,ldcur
        call ld24
        ld a,(lsec)
        call clus_lba
        call rd_sec
        ld hl,ovskip
        ld a,(hl)
        or a
        jr z,ov_cp
        dec (hl)
        jr ov_nx
ov_cp:  ld hl,SECBUF
        ld de,(lddst)
        ld bc,512
        ldir
        ld (lddst),de
        ld hl,ovcnt
        dec (hl)
        jr z,ov_go
ov_nx:  ld a,(lsec)
        inc a
        ld (lsec),a
        ld b,a
        ld a,(spc)
        cp b
        jr nz,ov_sec
        xor a
        ld (lsec),a
        ld hl,ldcur
        call ld24
        call fat_get
        or a
        jp nz,ov_bad2
        ld bc,ldcur
        call st24
        jr ov_sec
ov_go:  call fat_sync
        ld hl,(OVLA)        ; built with this VZ-ED?
        ld de,(ovl_id)
        or a
        sbc hl,de
        jp nz,ov_bad2
        call OVLA+2
        push af
        push hl
        call ov_unstash
        pop hl
        pop af
        ld a,1
        ld (waitrel),a
        ret nc
        call gap_to
        jp reset_goal
ov_bad2: call ov_unstash
ov_bad: call fat_sync
        ld hl,m_noovl
        jp set_msg

ov_stash:                   ; park the fallback clipboard in the gap
        ld a,(clipbank)
        or a
        ret nz
        ld bc,(cliplen)
        ld a,b
        or c
        ret z
        ld hl,(ge)
        ld de,(gs)
        or a
        sbc hl,de
        sbc hl,bc           ; (no borrow from the line above)
        jr c,ovs_x
        ld hl,(clipbase)
        ldir
        ld a,1
        ld (ovst),a
        ret
ovs_x:  ld hl,0             ; no room: it is lost (and the editor says so)
        ld (cliplen),hl
        ld a,2
        ld (ovst),a
        ret

ov_unstash:
        ld a,(ovst)
        or a
        ret z
        dec a
        jr nz,ovu_m
        ld hl,(gs)
        ld de,(clipbase)
        ld bc,(cliplen)
        ldir
        ret
ovu_m:  ld hl,m_clipgone
        jp set_msg
