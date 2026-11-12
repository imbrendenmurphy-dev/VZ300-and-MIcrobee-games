; =====================================================================
;  STAGE: load a stage from its blocks (A: glyph store + enemy sprites,
;  B: header, packed strips, mono store, base colours, heights, waves,
;  sprite table, the boss). See tools/build.py build_stage().
; =====================================================================
H_NR        equ 0
H_SEND      equ 1
H_RL        equ 3
H_STAB      equ 5
H_ROWS      equ 7
H_NUNP      equ 9
H_UNP       equ 10
H_BASE      equ 26
H_MONOB     equ 28
H_MONOA     equ 29
H_CEIL      equ 31
H_FLOOR     equ 33
H_WAVES     equ 35
H_BOSSB     equ 37
H_BOSSA     equ 38
H_SPRT      equ 40
H_BPAL      equ 42

; load_stage: A = stage (1..5)
load_stage:
        ld (stage),a
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,stage_blk
        add hl,de
        ld a,(hl)
        ld (stg_a),a
        inc hl
        ld a,(hl)
        ld (stg_b),a
        call map_blk
        ld hl,0
        ld de,stg_hdr
        ld bc,64
        ldir
        ld a,(stg_hdr+H_NR)
        ld (nstrip),a
        ; strip table: NR x 36 bytes
        ld b,a
        ld hl,0
        ld de,36
.m:     add hl,de
        djnz .m
        ld b,h
        ld c,l
        ld hl,(stg_hdr+H_STAB)
        ld de,strip_tab
        ldir
        ld a,(nstrip)
        ld b,a
        add a,a
        add a,b
        ld c,a
        ld b,0
        ld hl,(stg_hdr+H_ROWS)
        ld de,row_dst
        ldir
        ld hl,(stg_hdr+H_SEND)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (scroll_end),hl
        ld hl,(stg_hdr+H_WAVES)
        ld (wave_ptr),hl
        ld hl,stg_hdr+H_BPAL
        ld de,boss_pal
        ld bc,16
        ldir
        ; stage sprite frames (ids 192..255)
        ld hl,(stg_hdr+H_SPRT)
        ld de,spr_tab+192*3
        ld bc,64*3
        ldir
        ; the boss header and its variant table
        ld a,(stg_hdr+H_BOSSB)
        call map_blk
        ld hl,(stg_hdr+H_BOSSA)
        ld de,boss_hdr
        ld bc,4+64
        ldir
        ; base picture: the playfield rows blank in their colours
        ld a,(stg_b)
        call map_blk
        ld hl,(stg_hdr+H_BASE)
        ld de,BOUNCE
        ld bc,920
        ldir
        ld a,BLK_RT
        call map_blk
        ld hl,BOUNCE
        ld de,RT_CURCOL+40
        ld bc,920
        ldir
        ld hl,RT_CURLO+40
        ld de,RT_CURLO+41
        ld bc,919
        ld (hl),$80
        ldir
        ld hl,RT_CURHI+40
        ld de,RT_CURHI+41
        ld bc,919
        ld (hl),0
        ldir
        ; unpack the strips
        ld a,(stg_hdr+H_NUNP)
        ld b,a
        ld ix,stg_hdr+H_UNP
.u:     push bc
        ld a,(ix+0)
        ld (uz_sblk),a
        ld l,(ix+1)
        ld h,(ix+2)
        ld (uz_src),hl
        ld a,(ix+3)
        ld (uz_dblk),a
        call slz_unpack
        ld bc,4
        add ix,bc
        pop bc
        djnz .u
        ; the glyph store: mono over colour if wanted, then into the sprite block
        ld a,(monomode)
        or a
        jr z,.col
        ld a,(stg_a)
        ld (cb_dst),a
        ld de,0
        ld hl,(stg_hdr+H_MONOA)
        ld bc,$3000
        ld a,(stg_hdr+H_MONOB)
        call blk_copy
.col:   ld a,BLK_SPR
        ld (cb_dst),a
        ld hl,0
        ld de,0
        ld bc,$3000
        ld a,(stg_a)
        call blk_copy
        ; the PCG: glyphs 0..1535 from the store
        ld a,(stg_a)
        call map_blk
        ld hl,0
        ld de,0
        ld bc,STORE_TOP*128
        call glyphs_in
        ret

; ---------------------------------------------------------------------
; slz_unpack: (uz_src) in block (uz_sblk) -> block (uz_dblk) from 0000h
; ---------------------------------------------------------------------
slz_unpack:
        ld de,0
        call uz_fill
.t:     call uz_gb
        or a
        jp m,.m
        inc a
        ld b,a
.l:     call uz_gb
        ld (de),a
        inc de
        djnz .l
        jr .t
.m:     and $7F
        add a,3
        ld c,a
        call uz_gb
        ld (uz_off),a
        call uz_gb
        ld (uz_off+1),a
        push hl
        ld hl,(uz_off)
        ld a,h
        or l
        jr z,.end
        push de
        ex de,hl
        or a
        sbc hl,de
        pop de
        ld b,0
        ldir
        pop hl
        jr .t
.end:   pop hl
        ret
uz_gb:  ld a,(hl)
        inc l
        ret nz
        push af
        call uz_fill
        pop af
        ret
uz_fill:
        push de
        push bc
        ld a,(uz_sblk)
        call map_blk
        ld hl,(uz_src)
        ld de,BOUNCE
        ld bc,256
        ldir
        ld (uz_src),hl
        ld a,(uz_dblk)
        call map_blk
        ld hl,BOUNCE
        pop bc
        pop de
        ret
uz_src:     dw 0
uz_sblk:    db 0
uz_dblk:    db 0
uz_off:     dw 0

; ---------------------------------------------------------------------
; scroll_set: from (scrollx): the strip positions of the near and far rows
; ---------------------------------------------------------------------
scroll_set:
        ld hl,(scrollx)
        ld a,l
        rrca
        and 3
        ld (scr_p),a
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld (scr_m),hl
        ld hl,(scrollx)
        srl h
        rr l
        ld a,l
        rrca
        and 3
        ld (far_p),a
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld (far_m),hl
        ret

; floor_at: A = screen x (0..255 /2: x in 2-px units) -> A = floor y (playfield px)
; ceil_at likewise. The B block must be mapped.
floor_at:
        ld hl,(stg_hdr+H_FLOOR)
        jr hgt_at
ceil_at:
        ld hl,(stg_hdr+H_CEIL)
hgt_at: push de
        rrca
        rrca
        and $3F                 ; x/8
        ld e,a
        ld d,0
        add hl,de
        ld de,(scr_m)
        add hl,de
        ld a,(hl)
        pop de
        ret
