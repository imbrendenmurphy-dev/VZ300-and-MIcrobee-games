; ==========================================================================
; prescale.asm - shrink every sprite master to its 16 sizes, once, at
;                start-up, into RAM blocks 6 on (several images a block).
;   VIBED BY BPM 2026
;
; Per size the layout is byte columns, each 64 bytes (masters up to 32
; rows) or 128 bytes: row r is the pair (NOT mask, data) at 2r.  The
; unshifted columns come first, then one more column moved 4 dots right.
; tools/art.py works out each size's width and where it goes (the sprite
; directory in block 4); here each output dot's source column is found by
; stepping, then it is only bit copying.
; ==========================================================================

; ART.BIN directory (block 3)
A_OFF   equ 0           ; master offset (w)
A_NB    equ 2           ; bytes per master row (one plane)
A_H0    equ 3           ; rows
A_CS    equ 6           ; column size shift

prescale_all:                   ; at start-up: the things every zone has
        xor a
        ld (ps_img),a
        ld (ps_cnt),a
.img    call ps_mark
        call ps_one
        call ps_progress
        ld a,(ps_img)
        inc a
        ld (ps_img),a
        cp NCOMMON
        jr nz,.img
        jp tabblk

; prescale_zone: the zone's creatures and scenery not made yet (Z_NEED)
prescale_zone:
        xor a
        ld (ps_img),a
        ld (ps_cnt),a
.img    ld a,(ps_img)
        ld e,a
        ld d,0
        ld hl,PSBUILT
        add hl,de
        ld a,(hl)
        or a
        jr nz,.n                ; made for an earlier zone
        ld a,(ps_img)
        ld b,a
        srl a
        srl a
        srl a
        ld e,a
        ld hl,ZH+(Z_NEED-400h)
        add hl,de
        ld a,b
        and 7
        ld b,a
        ld a,(hl)
        inc b
.sh     rrca
        djnz .sh                ; bit img & 7 -> carry
        jr nc,.n
        call ps_mark
        call ps_one
        call ps_progress
.n      ld a,(ps_img)
        inc a
        ld (ps_img),a
        cp NIMAGES
        jr nz,.img
        jp tabblk

; ps_mark: this image is made (or about to be)
ps_mark:
        ld a,(ps_img)
        ld e,a
        ld d,0
        ld hl,PSBUILT
        add hl,de
        ld (hl),1
        ret

ps_one:
        ld a,BLK_ART
        call setblk
        ld a,(ps_img)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; ART directory entry (ARTDIR = 0)
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
        inc hl
        inc hl
        ld a,(hl)
        ld (ps_cs),a
        ld b,a
        ld hl,1
.cs     add hl,hl
        djnz .cs
        ld (ps_csz),hl          ; column size in bytes
        ; height of the master, for the renderer
        ld a,(ps_img)
        ld e,a
        ld d,0
        ld hl,IMGH0
        add hl,de
        ld a,(ps_h0)
        ld (hl),a
        ; the 16 widths -> WTAB + img * 16
        call ps_w16             ; HL = img * 16
        push hl
        ld de,ARTW
        add hl,de
        pop de
        push hl
        ld hl,WTAB
        add hl,de
        ex de,hl
        pop hl
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
        ld c,a
        ld b,0
        push af
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
        call ps_xmaps
        ; build the rows, in the image's block (from the directory)
        xor a
        ld (ps_s),a
        call ps_dirent
        ld a,(ix+D_BLK)
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
        ld l,a                  ; (columns start on column-size boundaries)
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

; ps_w16: HL = ps_img * 16
ps_w16: ld a,(ps_img)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ret

; ps_xmaps: for every size, which source column each output dot comes
;   from: floor(x * W0 / w) for x < w, then W0 (a clear pixel) up to a
;   whole byte.  Into XBUF, the sizes one after another.
ps_xmaps:
        ld a,(ps_nb)
        add a,a
        add a,a
        add a,a
        ld (ps_t),a             ; W0
        call ps_w16
        ld de,WTAB
        add hl,de               ; HL -> the 16 widths
        ld de,XBUF
        ld b,NSIZES
.s      push bc
        ld a,(hl)
        inc hl
        push hl
        ld b,a                  ; w
        ld c,a                  ; dots of picture
        ld hl,0                 ; H = source column, L = remainder
.x      ld a,h
        ld (de),a
        inc de
        ld a,(ps_t)
        add a,l
.q      cp b
        jr c,.qd
        sub b
        inc h
        jr .q
.qd     ld l,a
        dec c
        jr nz,.x
        ld a,b                  ; pad to a whole byte with W0
        neg
        and 7
        jr z,.nx
        ld c,a
        ld a,(ps_t)
.pl     ld (de),a
        inc de
        dec c
        jr nz,.pl
.nx     pop hl
        pop bc
        djnz .s
        ret

; ps_dirent: IX = a copy of the sprite directory entry of (ps_img, ps_s)
;            (block 4, SPRDIR), HL = its width in WTAB
ps_dirent:
        call ps_w16
        ld a,(ps_s)
        or l
        ld l,a                  ; HL = img * 16 + s
        push hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPRDIR
        add hl,de
        ld a,(curblk)
        push af
        ld a,BLK_PCG
        call setblk
        ld de,PSDIR
        ld bc,8
        ldir
        pop af
        call setblk
        ld ix,PSDIR
        pop hl
        ld de,WTAB
        add hl,de
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

;  ps_shift: row (ps_r) of size (ps_s): the shifted columns, 4 dots right of
;   the plain ones (clear - NOT mask F, data 0 - comes in from the left, and
;   there is one more column at the end).  Plain loads, ANDs and rotates
;   only: the RRD this used to be done with is the one instruction in the
;   game that had never run on the real machine.
ps_shift:
        ld a,0Fh                ; the NOT mask bytes
        ld (ps_pd),a
        xor a
        call .pass
        xor a                   ; the data bytes
        ld (ps_pd),a
        inc a
.pass   ld c,a                  ; C = 0 mask, 1 data
        ld a,(ps_r)
        add a,a
        add a,c
        ld c,a
        ld a,(ix+D_B0)
        add a,c
        ld l,a
        ld h,(ix+D_B0+1)        ; HL = the plain row
        ld a,(ix+D_B1)
        add a,c
        ld e,a
        ld d,(ix+D_B1+1)        ; DE = the shifted row
        ld a,(ix+D_BW)
        ld (ps_j),a
        ld a,(ps_pd)            ; what comes in from the left, as a high nibble
        rlca
        rlca
        rlca
        rlca
        ld (ps_pm),a
        ld bc,(ps_csz)
.c      ld a,(hl)
        and 0F0h
        rrca
        rrca
        rrca
        rrca
        push hl
        ld hl,ps_pm
        or (hl)
        pop hl
        ld (de),a
        ld a,(hl)
        and 0Fh
        rlca
        rlca
        rlca
        rlca
        ld (ps_pm),a
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        ld a,(ps_j)
        dec a
        ld (ps_j),a
        jr nz,.c
        ld hl,ps_pd             ; the extra column: the last nibble, then clear
        ld a,(ps_pm)
        or (hl)
        ld (de),a
        ret

; ps_progress: a bar on the loading screen, one block per image
ps_progress:
        ld hl,ps_cnt
        inc (hl)
        ld a,(hl)
        add a,1
        ld e,a
        ld d,0
        ld hl,22*40
        add hl,de
        ex de,hl
        ld hl,T_BLOCK
        jp print
T_BLOCK: db "#",0
