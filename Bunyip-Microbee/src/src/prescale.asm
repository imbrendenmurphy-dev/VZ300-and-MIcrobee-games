; ==========================================================================
; prescale.asm - shrink every sprite master to its 16 sizes, once, at
;                start-up.  Image n goes to RAM block BLK_SPR + n.
;   VIBED BY BPM 2026
;
; Per size the layout is byte columns, each 64 bytes (masters up to 32
; rows) or 128 bytes: row r is the pair (NOT mask, data) at 2r.  The
; unshifted columns come first, then one more column moved 4 dots right.
; tools/art.py works out each size's width and, for every output dot,
; which source column it comes from (padded to whole bytes), so here it is
; only bit copying.
; ==========================================================================

; ART.BIN directory (block 3)
A_OFF   equ 0           ; master offset (w)
A_NB    equ 2           ; bytes per master row (one plane)
A_H0    equ 3           ; rows
A_XOFF  equ 4           ; column maps (w)
A_CS    equ 6           ; column size shift

prescale_all:
        xor a
        ld (ps_img),a
.img    call ps_one
        call ps_progress
        ld a,(ps_img)
        inc a
        ld (ps_img),a
        cp NIMAGES
        jr nz,.img
        jp tabblk

ps_one:
        ld a,BLK_ART
        call setblk
        ld a,(ps_img)
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0                  ; directory entry
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ps_moff),de
        ld a,(hl)
        ld (ps_nb),a
        inc hl
        ld a,(hl)
        ld (ps_h0),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ps_xoff),de
        ld a,(hl)
        ld (ps_cs),a
        ; height of the master, for the renderer
        ld a,(ps_img)
        ld e,a
        ld d,0
        ld hl,IMGH0
        add hl,de
        ld a,(ps_h0)
        ld (hl),a
        ; the 16 widths
        ld a,(ps_img)
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,80h
        add hl,de
        push de
        ld de,WTAB
        pop bc
        ex de,hl
        add hl,bc
        ex de,hl                ; DE = WTAB + img*16
        ld bc,16
        ldir
        ; the master into MBUF, rows of 16 bytes (mask at +0, data at +8)
        ld hl,(ps_moff)
        ld de,MBUF
        ld a,(ps_h0)
        ld b,a
.mr     push bc
        push de
        ld a,(ps_nb)
        add a,a
        ld c,a
        ld b,0
        ld a,(ps_nb)
        push af
        ld c,a
        ldir                    ; mask bytes
        pop af
        pop de
        push de
        ex de,hl
        ld bc,8
        add hl,bc
        ex de,hl
        ld c,a
        ld b,0
        ldir                    ; data bytes
        pop de
        ex de,hl
        ld bc,16
        add hl,bc
        ex de,hl
        pop bc
        djnz .mr
        ; the column maps of all sizes into XBUF
        ld hl,(ps_xoff)
        ld de,XBUF
        ld bc,XBUFN
        ldir
        ; layout of the sizes in the sprite's block
        ld a,(ps_cs)
        ld b,a
        ld hl,1
.cs     add hl,hl
        djnz .cs
        ld (ps_csz),hl          ; column size in bytes
        ld hl,0
        ld (ps_cur),hl
        ld hl,XBUF
        ld (ps_xp),hl
        xor a
        ld (ps_s),a
.lay    call ps_dirent          ; IX = IMGDIR entry, HL = width table entry
        ld a,(hl)
        add a,7
        srl a
        srl a
        srl a
        ld (ix+D_BW),a
        ld a,(ps_img)
        add a,BLK_SPR
        ld (ix+D_BLK),a
        ld a,(ps_cs)
        ld (ix+D_CS),a
        ; same width as the size before?  share its columns
        ld a,(ps_s)
        or a
        jr z,.fresh
        dec hl
        ld a,(hl)
        inc hl
        cp (hl)
        jr nz,.fresh
        ld e,(ix-8+D_B0)
        ld d,(ix-8+D_B0+1)
        ld (ix+D_B0),e
        ld (ix+D_B0+1),d
        ld e,(ix-8+D_B1)
        ld d,(ix-8+D_B1+1)
        ld (ix+D_B1),e
        ld (ix+D_B1+1),d
        ld (ix+7),1             ; marked: nothing to build
        jr .nexts
.fresh  ld (ix+7),0
        ld hl,(ps_cur)
        ld (ix+D_B0),l
        ld (ix+D_B0+1),h
        ld a,(ix+D_BW)
        call ps_cols            ; HL += A columns
        ld (ix+D_B1),l
        ld (ix+D_B1+1),h
        ld a,(ix+D_BW)
        inc a
        call ps_cols
        ld (ps_cur),hl
.nexts  ld a,(ps_s)
        inc a
        ld (ps_s),a
        cp NSIZES
        jr nz,.lay
        ; build the rows, in the sprite's block
        ld a,(ps_img)
        add a,BLK_SPR
        call setblk
        xor a
        ld (ps_r),a
.row    call ps_expand          ; master row r -> PIX
        ld hl,XBUF
        ld (ps_xp),hl
        xor a
        ld (ps_s),a
.size   call ps_dirent
        push hl
        ld a,(hl)               ; width
        add a,7
        and 0F8h
        ld c,a                  ; dots in the column map
        ld b,0
        ld a,(ix+7)
        or a
        jr nz,.skip             ; shares the size before
        ld de,(ps_xp)
        ld l,(ix+D_B0)
        ld h,(ix+D_B0+1)
        ld a,(ps_r)
        add a,a
        add a,l
        ld l,a                  ; (columns start on 64-byte boundaries)
        push hl
        pop iy                  ; IY = this row in column 0
        ld a,(ix+D_BW)
        ld (ps_j),a
        push bc
        call ps_bytes
        pop bc
.skip   ld hl,(ps_xp)
        add hl,bc
        ld (ps_xp),hl
        pop hl
        ld a,(ps_s)
        inc a
        ld (ps_s),a
        cp NSIZES
        jr nz,.size
        ld a,(ps_r)
        inc a
        ld (ps_r),a
        ld hl,ps_h0
        cp (hl)
        jr nz,.row
        ; the shifted copies
        xor a
        ld (ps_s),a
.sh     call ps_dirent
        ld a,(ix+7)
        or a
        jr nz,.shn
        xor a
        ld (ps_r),a
.shr    call ps_shift
        ld a,(ps_r)
        inc a
        ld (ps_r),a
        ld hl,ps_h0
        cp (hl)
        jr nz,.shr
.shn    ld a,(ps_s)
        inc a
        ld (ps_s),a
        cp NSIZES
        jr nz,.sh
        jp tabblk

; ps_cols: HL += A * column size
ps_cols:
        or a
        ret z
        ld de,(ps_csz)
        ld b,a
.l      add hl,de
        djnz .l
        ret

; ps_dirent: IX = IMGDIR entry of (ps_img, ps_s), HL = its width in WTAB
ps_dirent:
        ld a,(ps_img)
        add a,a
        add a,a
        add a,a
        add a,a
        ld hl,ps_s
        add a,(hl)
        ld l,a
        ld h,high(WTAB)
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,IMGDIR
        add hl,de
        push hl
        pop ix
        pop hl
        ret

; ps_expand: master row (ps_r) -> PIX[x] = mask bit | data bit << 1,
;            PIX[W0] = 0 (the clear pixel the column maps pad with)
ps_expand:
        ld a,(ps_r)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,MBUF
        add hl,de               ; HL = mask bytes, HL+8 = data bytes
        ld de,PIX
        ld a,(ps_nb)
        ld b,a
.byte   push bc
        ld c,(hl)               ; mask
        push hl
        ld bc,8
        add hl,bc
        ld b,(hl)               ; data
        pop hl
        ld a,(hl)
        ld c,a
        push hl
        ld l,8
.bit    xor a
        rl b
        rla
        rl c
        rla                     ; A = data << 1 | mask
        ld (de),a
        inc e
        dec l
        jr nz,.bit
        pop hl
        inc hl
        pop bc
        djnz .byte
        xor a
        ld (de),a               ; PIX[W0] = clear
        ret

; ps_bytes: (ps_j) output bytes of one row of one size
;   DE = column map, IY = destination (column 0, this row)
ps_bytes:
        ld h,high(PIX)
.j      ld b,0
        ld c,0
        rept 8
        ld a,(de)
        inc de
        ld l,a
        ld a,(hl)
        rra
        rl b                    ; mask bits
        rra
        rl c                    ; data bits
        endm
        ld a,b
        cpl
        ld (iy+0),a
        ld (iy+1),c
        push de
        ld de,(ps_csz)
        add iy,de
        pop de
        ld a,(ps_j)
        dec a
        ld (ps_j),a
        jr nz,.j
        ret

; ps_shift: row (ps_r) of size (ps_s): shifted columns from the plain ones
;   out[j] = prev << 4 | cur >> 4, where the plain row is padded with
;   clear (NOT mask FF, data 0) on both ends
ps_shift:
        ld l,(ix+D_B0)
        ld h,(ix+D_B0+1)
        ld a,(ps_r)
        add a,a
        add a,l
        ld l,a
        ld e,(ix+D_B1)
        ld d,(ix+D_B1+1)
        ld a,(ps_r)
        add a,a
        add a,e
        ld e,a
        ld a,(ix+D_BW)
        inc a
        ld (ps_j),a
        ld a,0FFh
        ld (ps_pm),a
        xor a
        ld (ps_pd),a
.j      ld a,(ps_j)
        cp 1
        ld b,0FFh               ; past the end: clear
        ld c,0
        jr z,.e
        ld b,(hl)
        inc hl
        ld c,(hl)
        dec hl
.e      ld a,(ps_pm)            ; NOT mask
        call ps_nib
        ld (de),a
        inc de
        ld a,b
        ld (ps_pm),a
        ld b,c
        ld a,(ps_pd)            ; data
        call ps_nib
        ld (de),a
        dec de
        ld a,b
        ld (ps_pd),a
        push bc
        ld bc,(ps_csz)
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        ld a,(ps_j)
        dec a
        ld (ps_j),a
        jr nz,.j
        ret
; ps_nib: A = previous byte, B = current -> A = prev << 4 | cur >> 4
;         keeps BC, DE, HL
ps_nib: rlca
        rlca
        rlca
        rlca
        and 0F0h
        ld (ps_t),a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        push hl
        ld hl,ps_t
        or (hl)
        pop hl
        ret

; ps_progress: a bar on the loading screen, one block per image
ps_progress:
        ld a,(ps_img)
        add a,12
        ld e,a
        ld d,0
        ld hl,20*40
        add hl,de
        ex de,hl
        ld hl,T_BLOCK
        jp print
T_BLOCK: db "#",0
