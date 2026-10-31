; =====================================================================
;  level.asm : chapters and passwords
;
;  Memory (the way BIX uses the BennVenn card; the DOS is never called):
;    port $37 = 1  home 10K bank at $4000-$67FF: the chapter archive
;                  (all three chapter blocks; this overwrites the DOS)
;    port $37 = 3  other 10K bank at $4000-$67FF: common data at $4000,
;                  the current chapter block at LSLOT ($5A00)
;  Both banks are unpacked from the .VZ at power-on and checksummed.
;  Switching chapter copies a block home bank -> map area -> bank 3.
; =====================================================================
lv_slot:  db 0              ; chapter currently held in LSLOT (0 = none)
lv_num:   db 1

; ---------------------------------------------------------------------
; level_load: A = chapter -> make sure its block is in LSLOT (NC)
; ---------------------------------------------------------------------
level_load:
        ld hl,lv_slot
        cp (hl)
        ret z
        ld (hl),a
        dec a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,ARCH
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = address in the home bank
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = length
        push bc
        call bank0
        ex de,hl
        ld de,MAP
        ldir                    ; home bank -> map area (free here)
        pop bc
        call bank1
        ld hl,MAP
        ld de,LSLOT
        ldir                    ; map area -> bank 3
        call bank0
        or a
        ret

; ---------------------------------------------------------------------
; level_begin: chapter (lv_num) must be in LSLOT. Copies its hot part,
; unpacks the map, places the player at the start.
; ---------------------------------------------------------------------
level_begin:
        ld hl,LISTA             ; forget any light-change list (the SD DOS may
        ld (light_old),hl       ; have run the ROM interrupt over $7800)
        ld (light_oend),hl
        call bank1
        ld hl,(LB_HOTSRC)
        ld bc,(LB_HOTLEN)
        ld de,LVBUF
        ldir
        ld hl,(LB_MAP)
        ld de,MAP
        call dzx0
        call bank0
        ld a,(p_sun)
        or a
        call nz,reveal_hidden
        ld a,(LVBUF+LV_SX)
        ld (p_x),a
        ld a,(LVBUF+LV_SY)
        ld (p_y),a
        ld a,(LVBUF+LV_SDIR)
        ld (p_dir),a
        ld a,$FF
        ld (mus_track),a
        ret

; ---------------------------------------------------------------------
; chapter title card with the password (mode 0), waits for fire/space
; ---------------------------------------------------------------------
chapter_card:
        ld a,M0O
        ld (lbase),a
        ld (LATCH),a
        call bank1
        ld hl,PAGE_CHAP
        call show_page
        call bank0
        ld hl,LVBUF+LV_TITLE
        ld de,VRAM+5*32
        ld bc,32
        ldir
        call pw_encode
        ld hl,pw_buf
        ld de,VRAM+11*32+13
        ld bc,6
        ldir
        ld hl,SFX_CHAPTER
        call sfx
.w:     call wait_frame
        call sound_tick
        call read_input
        ld a,(in_new)
        and (1<<IN_FIRE)
        jr z,.w
        ret

; ---------------------------------------------------------------------
; passwords: 24 bits of state + 6 check bits -> 6 symbols of 5 bits
;  b0 = chapter-1 (2) | items<<2 (staff boots sun ring blade)
;  b1 = hpmax (4) | mpmax<<4        b2 = level-1 (3) | gems<<3 (5)
;  b3 = check (6)
; ---------------------------------------------------------------------
PWALPHA: db "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
PWKEY:   db 19,7,28,2,13,24
pw_buf:  ds 6               ; screen codes (encode) / ascii (entry)
pw_bits: ds 4

pw_state:                   ; player state -> pw_bits (b0..b2)
        ld c,0
        ld a,(p_blade)
        call .b
        ld a,(p_ring)
        call .b
        ld a,(p_sun)
        call .b
        ld a,(p_boots)
        call .b
        ld a,(p_staff)
        call .b
        ld a,c
        add a,a
        add a,a
        ld c,a
        ld a,(lv_num)
        dec a
        and 3
        or c
        ld (pw_bits),a
        ld a,(p_mpmax)
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(p_hpmax)
        and 15
        or b
        ld (pw_bits+1),a
        ld a,(p_gems)
        cp 32
        jr c,$+4
        ld a,31
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(p_lvl)
        dec a
        and 7
        or b
        ld (pw_bits+2),a
        call pw_check
        ld (pw_bits+3),a
        ret
.b:     or a
        jr z,$+4
        ld a,1
        sla c
        or c
        ld c,a
        ret

pw_check:
        ld a,(pw_bits+1)
        ld c,a
        add a,a
        add a,c
        ld b,a
        ld a,(pw_bits)
        add a,b
        ld b,a
        ld a,(pw_bits+2)
        ld c,a
        add a,a
        add a,a
        add a,a
        sub c
        add a,b
        add a,$2B
        and 63
        ret

pw_encode:
        call pw_state
        ld de,pw_buf
        ld ix,PWKEY
        ld c,0
        ld b,6
.s:     push bc
        ld e,0
        ld b,5
.t:     ld hl,pw_bits+3
        srl (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        rr e
        djnz .t
        ld a,e
        rrca
        rrca
        rrca
        and 31
        pop bc
        push de
        add a,c
        add a,(ix+0)
        and 31
        ld c,a
        ld hl,PWALPHA
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        call ascii2vz
        pop de
        ; DE was clobbered by the bit loop's E: recompute destination
        push af
        ld a,6
        sub b
        ld e,a
        ld d,0
        ld hl,pw_buf
        add hl,de
        pop af
        ld (hl),a
        inc ix
        djnz .s
        ret

; pw_buf holds 6 ascii chars -> on success sets the player state and lv_num, NC
pw_decode:
        xor a
        ld (pw_bits),a
        ld (pw_bits+1),a
        ld (pw_bits+2),a
        ld (pw_bits+3),a
        ld ix,PWKEY
        ld iy,pw_buf
        ld c,0                  ; previous scrambled symbol
        ld b,6
.s:     push bc
        ld a,(iy+0)
        ; ascii -> symbol index
        ld hl,PWALPHA
        ld e,0
.f:     cp (hl)
        jr z,.fd
        inc hl
        inc e
        bit 5,e
        jr z,.f
        pop bc
        scf
        ret
.fd:    ld a,e                  ; scrambled symbol
        pop bc
        push af
        sub c
        sub (ix+0)
        and 31                  ; plain symbol
        ld e,a
        pop af
        ld c,a
        push bc
        ld b,5
.u:     rr e
        ld hl,pw_bits+3
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        djnz .u
        pop bc
        inc ix
        inc iy
        djnz .s
        ; 30 bits in the top: shift right 2 more
        ld b,2
.a:     ld hl,pw_bits+3
        srl (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        djnz .a
        call pw_check
        ld hl,pw_bits+3
        cp (hl)
        scf
        ret nz
        ; unpack
        ld a,(pw_bits)
        and 3
        cp 3
        ccf
        ret c
        inc a
        ld (lv_num),a
        ld a,(pw_bits)
        rrca
        rrca
        ld c,a
        and 1
        ld (p_staff),a
        ld a,c
        rrca
        ld c,a
        and 1
        ld (p_boots),a
        ld a,c
        rrca
        ld c,a
        and 1
        ld (p_sun),a
        ld a,c
        rrca
        ld c,a
        and 1
        ld (p_ring),a
        ld a,c
        rrca
        and 1
        ld (p_blade),a
        ld a,(pw_bits+1)
        and 15
        cp 4
        ret c
        ld (p_hpmax),a
        ld (p_hp),a
        ld a,(pw_bits+1)
        rrca
        rrca
        rrca
        rrca
        and 15
        ld (p_mpmax),a
        ld (p_mp),a
        ld a,(pw_bits+2)
        and 7
        inc a
        ld (p_lvl),a
        ld e,a
        ld d,0
        ld hl,XPLEV-2
        add hl,de
        ld a,(hl)
        dec e
        jr nz,$+3
        xor a
        ld (p_xp),a
        ld a,(pw_bits+2)
        rrca
        rrca
        rrca
        and 31
        ld (p_gems),a
        or a
        ret

ascii2vz:
        cp 64
        ret c
        sub 64
        ret
