;=====================================================================
; TRANSCENDENCE SD loader (TRANSCND.VZ) - follows the 13 Ghosts method
; Loads TRANSCN1.DAT -> $8000 (engine, music, scenes)
;       TRANSCN2.DAT -> SRAM bank 3 at $4000 (3D keyframes, sprites)
; then maps bank 3 and starts the demo. All SD access happens here, in
; the opening darkness, so the music never stalls on sector reads.
;=====================================================================
        org $F000
ldr:    di
        ld sp,$F3F0
        ld hl,$5FFF             ; probe which mapping the DOS runs in
        ld b,(hl)
        ld a,b
        cpl
        ld (hl),a
        ld a,(hl)
        xor b
        ld (hl),b
        and 1
        ld (LMAP),a
        ld hl,FTAB
        ld (LPTR),hl
lnext:  ld hl,(LPTR)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,lgo
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (LDST),de
        ld (LLEN),bc
        ld (LBANK),a
        push hl
        ld de,10
        add hl,de
        ld (LPTR),hl
        ld hl,$F800
        ld ($FB80),hl
        pop hl                  ; HL -> "NAME"
        ld a,1
        call $5F00              ; open DAT
        ld a,($FB03)
        cp 1
        jr nz,lerr
        ld a,($FB05)
        cp 1
        jr z,lerr
        ld a,1
        call $5F03              ; first sector -> $F800
        ld a,1
        ld (LFIRST),a
lchunk: call lgetsec
        ld de,(LDST)
        ld bc,(LLEN)
        ld a,b
        cp 2
        jr c,lsm
        ld bc,$0200
lsm:    push bc
        ld a,(LBANK)
        or a
        jr z,lnb
        ld a,3
        out ($37),a
        ldir
        ld a,(LMAP)
        out ($37),a
        jr lcd
lnb:    ldir
lcd:    pop bc
        ld (LDST),de
        ld hl,(LLEN)
        or a
        sbc hl,bc
        ld (LLEN),hl
        ld a,h
        or l
        jr nz,lchunk
        jp lnext
lgo:    di
        ld a,3
        out ($37),a
        jp start
lerr:   ld hl,EMSG
        call $28A7
lhang:  jr lhang
lgetsec:
        ld a,(LFIRST)
        or a
        jr z,lgs2
        xor a
        ld (LFIRST),a
        ld hl,$F800
        ret
lgs2:   ld hl,$F400
        ld ($FB80),hl
        call $5F09              ; next sector
        ld hl,$F400
        ret
EMSG:   db "TRANSCENDENCE: CAN'T OPEN DATA FILE",13,0
LFIRST: db 0
LMAP:   db 0
LBANK:  db 0
LPTR:   dw 0
LDST:   dw 0
LLEN:   dw 0
FTAB:   dw $8000, codeend-$8000
        db 0
        db '"TRANSCN1"'
        dw $4000, assetend-$4000
        db 1
        db '"TRANSCN2"'
        dw 0
ldrend:
        assert ldrend < $F3C0
