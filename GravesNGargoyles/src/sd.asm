; ============================================================================
;  SD CARD LOADING (BennVenn DOS, as used by the 13 Ghosts loader)
;   ($FB80)   = sector buffer address
;   $5F00     A=1, HL -> "NAME"   open; OK if ($FB03)=1 and ($FB05)<>1
;   $5F03     A=1                 read first sector into ($FB80)
;   $5F09                         read next sector into ($FB80)
;  The DOS runs from SRAM bank A (port $37 = DOS mapping) and keeps its own
;  RAM at $FA00 and up, which this program never touches.
; ============================================================================

; at start-up, before touching port $37: is the DOS bank writable RAM?
dos_probe:
        ld hl,$5FFF
        ld b,(hl)
        ld a,b
        cpl
        ld (hl),a
        ld a,(hl)
        xor b
        ld (hl),b
        and 1
        ld (DOSMAP),a
        ret

; load_pack: HL = pack directory entry -> carry set on failure
load_pack:
        di
        ld a,1
        ld (DOSBUSY),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ld_dest),de
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (ld_left),bc
        ld (ld_name),hl
        call stop_music
        ld a,(DOSMAP)
        out ($37),a
        ld hl,FB
        ld ($FB80),hl
        ld hl,(ld_name)
        ld a,1
        call $5F00
        ld a,($FB03)
        cp 1
        jr nz,.err
        ld a,($FB05)
        cp 1
        jr z,.err
        ld hl,FB
        ld ($FB80),hl
        ld a,1
        call $5F03
.lp:    ld bc,(ld_left)
        ld a,b
        cp 2
        jr c,.part
        ld bc,$200
.part:  push bc
        ld hl,FB
        ld de,(ld_dest)
        ldir
        ld (ld_dest),de
        pop bc
        ld hl,(ld_left)
        or a
        sbc hl,bc
        ld (ld_left),hl
        ld a,h
        or l
        jr z,.ok
        ld hl,FB
        ld ($FB80),hl
        call $5F09
        jr .lp
.ok:    or a
        jr .out
.err:   scf
.out:   push af
        ld a,SRAM_GAME
        out ($37),a
        xor a
        ld (DOSBUSY),a
        xor a
        ld (frame_ready),a
        ld (fieldcnt),a
        pop af
        ei
        ret

; make sure a pack is in memory: HL = directory entry, A = magic byte
ensure_pack:
        ld b,a
        ld a,(PACK_AREA)
        cp b
        jr nz,.load
        ld a,(pack_ok)
        or a
        ret nz
.load:  push hl
        push bc
        call load_pack
        pop bc
        pop hl
        jr c,.fail
        ld a,(PACK_AREA)
        cp b
        jr nz,.fail
        ld a,1
        ld (pack_ok),a
        ret
.fail:  xor a
        ld (pack_ok),a
        push hl
        push bc
        call sd_error
        pop bc
        pop hl
        jr .load

ensure_front:
        ld hl,PK_FRONT
        ld a,'F'
        jp ensure_pack

; make sure the pack for cur_stage (1-7) is in memory
ensure_stage:
        ld a,(PACK_AREA)
        cp 'S'
        jr nz,.load
        ld a,(STG_NUM)
        ld b,a
        ld a,(cur_stage)
        cp b
        jr z,.have
.load:  xor a
        ld (PACK_AREA),a        ; force a reload
.have:  ld a,(cur_stage)
        dec a
        ld l,a
        add a,a                 ; *2
        add a,l                 ; *3
        add a,a                 ; *6
        add a,l                 ; *7
        add a,a                 ; *14
        ld e,a
        ld d,0
        ld hl,PK_STAGES
        add hl,de
        ld a,'S'
        jp ensure_pack

; error screen: HL = directory entry (name at +4).  Waits for fire, then retry.
sd_error:
        ld de,4
        add hl,de
        inc hl                  ; skip the opening quote
        ld de,text_buf
        ld bc,8
        ldir
        ld hl,STR_DAT
        ld bc,5
        ldir
        call cls_fb
        ld hl,STR_SDERR
        ld c,20
        ld a,(col_red)
        call text_fbc
        ld hl,text_buf
        ld c,30
        ld a,(col_yel)
        call text_fbc
        ld hl,STR_RETRY
        ld c,44
        ld a,(col_grn)
        call text_fbc
        call show_full
.w:     call show_full
        call read_input
        ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_SWAP)
        jr z,.w
        ret
STR_DAT:   db ".DAT",0
STR_SDERR: db "CAN'T READ FROM SD CARD:",0
STR_RETRY: db "PRESS FIRE TO TRY AGAIN",0
