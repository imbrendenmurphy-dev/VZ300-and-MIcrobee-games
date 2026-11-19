; =====================================================================
;  loader.asm - (overlay) level loader, pre-shifter, LZ decoder
; =====================================================================
; ---------------------------------------------------------------- player sprites
ovl_load_player:
        ld hl,(lv_player)
        ld de,SCR
        ld bc,NPFRAMES*20
        call blz
        call build_flipt
        ld hl,ptab
        ld (ps_tab),hl
        ld hl,SCR
        ld de,SPRITES
        ld b,NPFRAMES
.f:     push bc
        push hl
        xor a
        ld (ps_flip),a
        ld bc,$0A02
        call preshift
        pop hl
        push hl
        ld a,1
        ld (ps_flip),a
        ld bc,$0A02
        call preshift
        pop hl
        ld bc,20
        add hl,bc
        pop bc
        djnz .f
        ret

; ---------------------------------------------------------------- level loader
; load_level: A = level number. Leaves interrupts disabled.
ovl_load_level:
        di
        ld (levnum),a
        call sd_stage           ; make sure upper bank 0 holds this stage's pack
        ld hl,PACK+PK_REC
        ld de,lvrec
        ld bc,LVSIZE
        call bfetch
        call ovl_load_player    ; (Bix's frames travel in every pack)
        ld hl,(lv_w)
        ld (levw),hl
        ld a,(lv_flags)
        and 1
        ld (bossmode),a
        ; ---- map (row-major, packed) -> SCR, then transpose into MAP
        ld hl,(levw)
        call mul12
        ld b,h
        ld c,l
        ld a,(lv_mapb)
        ld hl,(lv_map)
        ld de,SCR
        call blz
        ld a,(lv_tilb)
        ld hl,(lv_tiles)
        ld de,tiles
        ld bc,NTILES*16
        call blz
        ld a,(lv_attb)
        ld hl,(lv_attrs)
        ld de,ATSCR
        ld bc,NTILES
        call bfetch
        ld a,(lv_songb)
        ld hl,(lv_song)
        ld de,songbuf
        ld bc,(lv_songlen)
        call blz
        ld a,(lv_enb)
        ld hl,(lv_en)
        ld de,ENSCR
        ld bc,NEFRAMES*16
        call blz
        ld a,(lv_bossb)
        ld hl,(lv_bossraw)
        ld de,BSSCR
        ld bc,480
        call blz
        ld hl,(lv_plat)
        ld de,PLSCR
        ld bc,24
        call bfetch
        ; transpose SCR (12 rows of W) -> MAP column-major
        ld hl,SCR
        ld c,0                  ; row
.ty:    push bc
        ld de,MAP
        ld a,c
        add a,e
        ld e,a
        jr nc,.t0
        inc d
.t0:    ld bc,(levw)
.tx:    ld a,(hl)
        ld (de),a
        inc hl
        ld a,12
        add a,e
        ld e,a
        jr nc,.t1
        inc d
.t1:    dec bc
        ld a,b
        or c
        jr nz,.tx
        pop bc
        inc c
        ld a,c
        cp 12
        jr nz,.ty
        ; trailing sky column
        ld hl,(levw)
        call mul12
        ld de,MAP
        add hl,de
        ld b,12
.sk:    ld (hl),T_SKY
        inc hl
        djnz .sk
        ; spawn list
        ld a,(lv_entb)
        ld hl,(lv_ents)
        ld de,SCR
        ld bc,(lv_entslen)
        call bfetch
        ld hl,SCR
        ld de,ENTLIST
        ld bc,(lv_entslen)
        ldir
        ; tile attributes into the home work area
        ld hl,ATSCR
        ld de,tattr
        ld bc,NTILES
        ldir
        ; boss frames into home work area
        ld hl,BSSCR
        ld de,BOSSG
        ld bc,480
        ldir
        ; enemies: 10 mirrored frames, 5 symmetric, + platform
        call build_flipt
        ld hl,etab
        ld (ps_tab),hl
        ld hl,ENSCR
        ld de,SPRITES+NPFRAMES*240
        ld b,NEFRAMES
        ld c,0
.ef:    push bc
        push hl
        xor a
        ld (ps_flip),a
        ld bc,$0802
        call preshift
        pop hl
        pop bc
        push bc
        push hl
        ld a,c
        cp NEFLIP
        jr nc,.nf
        ld a,1
        ld (ps_flip),a
        ld bc,$0802
        call preshift
        jr .nx
.nf:    ; symmetric: dir 1 uses the same four pointers
        push de
        ld hl,(ps_tab)
        ld de,-8
        add hl,de
        ld de,(ps_tab)
        ld bc,8
        ldir
        ld (ps_tab),de
        pop de
.nx:    pop hl
        ld bc,16
        add hl,bc
        pop bc
        inc c
        djnz .ef
        xor a
        ld (ps_flip),a
        ld hl,qtab
        ld (ps_tab),hl
        ld hl,PLSCR
        ld bc,$0406
        call preshift
        ; colour set by world
        ld a,(lv_world)
        and 1                   ; worlds 2 and 4 use colour set 1
        ld a,LATBASE
        jr nz,.cs
        ld a,LATBASE|$10
.cs:    jp set_latch

        db $FF

; ---------------------------------------------------------------- pre-shifter
; preshift: HL = raw sprite (W bytes/row), DE = destination, B = rows, C = W.
; Emits 4 phases of rows x (W+1) bytes, storing each phase's address at (ps_tab).
ps_tab  dw 0
ps_flip db 0
ps_src  dw 0
ps_rows db 0
ps_w    db 0
ps_ph   db 0
ps_rc   db 0
rowb    ds 6
preshift:
        ld (ps_src),hl
        ld a,b
        ld (ps_rows),a
        ld a,c
        ld (ps_w),a
        xor a
.ph:    ld (ps_ph),a
        ld hl,(ps_tab)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (ps_tab),hl
        ld hl,(ps_src)
        ld a,(ps_rows)
        ld (ps_rc),a
.row:   ; load one source row into rowb (mirrored if flipping)
        push de
        ld a,(ps_w)
        ld b,a
        ld de,rowb
        ld a,(ps_flip)
        or a
        jr nz,.fl
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .cp
        jr .ld
.fl:    ; rowb[k] = FLIPT[src[W-1-k]]
        push hl
        ld c,b
        ld b,0
        add hl,bc               ; one past the row
        ld b,c
.f1:    dec hl
        ld a,(hl)
        push hl
        ld l,a
        ld h,high FLIPT
        ld a,(hl)
        pop hl
        ld (de),a
        inc de
        djnz .f1
        pop hl
        ld a,(ps_w)
        ld c,a
        ld b,0
        add hl,bc
.ld:    xor a
        ld (de),a               ; rowb[W] = 0
        pop de
        push hl
        ; emit W+1 bytes
        ld a,(ps_ph)
        or a
        jr nz,.sh
        ld hl,rowb
        ld a,(ps_w)
        inc a
        ld c,a
        ld b,0
        ldir
        jr .nr
.sh:    ; L page = LS1 + 2*(3-ph) ; R page = L page + 1
        ld b,a
        ld a,3
        sub b
        add a,a
        add a,LS1
        ld (.lp+1),a
        inc a
        ld (.rp+1),a
        ld ix,rowb
        ld a,(ps_w)
        inc a
        ld (.cnt),a
        ld c,0                  ; previous byte
.e:     ld b,(ix+0)             ; current byte
        inc ix
.lp:    ld h,0
        ld l,c
        ld a,(hl)               ; prev << (8-2ph)
.rp:    ld h,0
        ld l,b
        or (hl)                 ; | cur >> 2ph
        ld (de),a
        inc de
        ld c,b
        ld a,(.cnt)
        dec a
        ld (.cnt),a
        jr nz,.e
.nr:    pop hl
        ld a,(ps_rc)
        dec a
        ld (ps_rc),a
        jp nz,.row
        ld a,(ps_ph)
        inc a
        cp 4
        jp nz,.ph
        ret
.cnt    db 0

build_flipt:                    ; FLIPT[v] = v with its four 2-bit pixels reversed
        ld hl,FLIPT
.l:     ld a,l
        ld b,4
        ld c,0
.p:     ld d,a
        and 3
        sla c
        sla c
        or c
        ld c,a
        ld a,d
        rrca
        rrca
        djnz .p
        ld (hl),c
        inc l
        jr nz,.l
        ret

