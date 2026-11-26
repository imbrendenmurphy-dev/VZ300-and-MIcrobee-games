; ---------------------------------------------------------------------------
; Packs on drives B-D, read straight from the WD2793 (CP/M is long gone by
; then).  Ports: 44 command/status, 45 track, 46 sector, 47 data, 48 drive /
; side / density latch (read: bit 7 = INTRQ or DRQ).  A pack is a CP/M file
; that starts at logical sector 8 of its disk's data area; logical sector L
; is on track-side 4 + L/10, at physical slot skew[L mod 10], sector ID 21+slot.
; Each pack is read once, into its blocks, the first time it's needed.
; ---------------------------------------------------------------------------
FDC_CMD  equ $44
FDC_TRK  equ $45
FDC_SEC  equ $46
FDC_DAT  equ $47
FDC_LATCH equ $48

; A = pack (0 = the core, always there).  Loads it if it isn't in RAM yet.
str_loadpk: db "LOADING...",0
pack_need:
        call pack_try
        ret nc
.again: call pack_load
        jr nc,pack_mark
        ld hl,str_insert        ; wrong or missing disk: ask, wait, try again
        ld a,(pk_drive)
        add a,'A'
        ld (str_insert+12),a
        call msg_show
        call present
        ld a,KEY_SPACE
        call wait_key
        jr .again

; Like pack_need, but doesn't ask for the disk: carry if it couldn't load.
pack_try:
        or a
        ret z
        ld (pk_num),a
        ld b,a
        ld a,(packs_in)
.bit:   rrca
        djnz .bit
        ccf
        ret nc                  ; already loaded
        ld hl,str_loadpk        ; the disk is being read
        call msg_show
        call present
        call present
        call pack_load
        ret c
pack_mark:
        ld a,(pk_num)           ; mark it loaded
        ld b,a
        ld a,1
.sh:    dec b
        jr z,.set
        add a,a
        jr .sh
.set:   ld hl,packs_in
        or (hl)
        ld (hl),a
        ld hl,str_blank
        call msg_show
        call present
        or a
        ret

; Read pack (pk_num) into its blocks.  Carry set on failure.
pack_load:
        ld a,(pk_num)           ; its record: drive, start sector, count, first block
        dec a
        ld l,a
        add a,a
        add a,l
        add a,a                 ; * PACK_REC (6)
        ld hl,pack_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (pk_drive),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (pk_lsec),de
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (pk_left),de
        inc hl
        ld a,(hl)
        ld (pk_block),a
        ld hl,str_reading
        ld a,(pk_drive)
        add a,'A'
        ld (str_reading+13),a
        call msg_show
        call present            ; show it before the drive starts
        ld hl,0
        ld (pk_dest),hl
.sec:   ld hl,(pk_left)
        ld a,h
        or l
        jr z,.check
        call read_lsec          ; one sector into the bank
        ret c
        ld hl,(pk_lsec)
        inc hl
        ld (pk_lsec),hl
        ld hl,(pk_left)
        dec hl
        ld (pk_left),hl
        ld hl,(pk_dest)
        ld de,512
        add hl,de
        ld a,h
        cp $80
        jr c,.nb
        ld hl,pk_block          ; this block is full
        inc (hl)
        ld hl,0
.nb:    ld (pk_dest),hl
        jr .sec
.check: ld a,(pk_num)           ; the signature: "BLACKOUT PACK n"
        dec a
        ld l,a
        add a,a
        add a,l
        add a,a
        add a,5
        ld hl,pack_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)               ; first block
        ld hl,0
        ld de,BOUNCE+256-16     ; (far_copy bounces through BOUNCE itself)
        ld bc,16
        push de
        call far_copy
        pop hl
        ld de,str_sig
        ld b,14
.cmp:   ld a,(de)
        cp (hl)
        scf
        ret nz
        inc hl
        inc de
        djnz .cmp
        ld a,(pk_num)
        add a,'0'
        cp (hl)
        scf
        ret nz
        or a
        ret

; Logical sector pk_lsec of drive pk_drive -> pk_block:pk_dest.  Carry on error.
read_lsec:
        call lsec_place
        jr rl_go

; pk_lsec -> pk_cyl, pk_side, pk_id (CP/M data area, 3:1 skew).
lsec_place:
        ld hl,(pk_lsec)         ; L / 10, L mod 10
        ld c,0
        ld de,-10
.dv:    add hl,de
        jr nc,.dn
        inc c
        jr .dv
.dn:    ld de,10
        add hl,de               ; L = (track-side - 4) * 10 + s, C = track-side - 4
        ld a,l
        ld hl,skew
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        add a,21
        ld (pk_id),a
        ld a,c
        add a,4                 ; track-side
        ld c,a
        srl a
        ld (pk_cyl),a
        ld a,c
        and 1
        ld (pk_side),a
        ret
rl_go:  ld b,3                  ; three tries
.try:   push bc
        call fdc_seek
        jr c,.err
        ld a,(pk_id)
        out (FDC_SEC),a
        ld a,$80                ; read sector
        out (FDC_CMD),a
        ld a,(pk_block)
        call bank_port
        ld hl,(pk_dest)
        call fdc_rd             ; (in upper RAM: the bank is switched in)
        and $1C                 ; record not found, CRC, lost data
        jr nz,.err
        pop bc
        ret
.err:   pop bc
        ld a,$FF                ; forget where the head is, re-home next time
        ld (fdc_cyl),a
        djnz .try
        scf
        ret

; Select pk_drive / pk_side and step to pk_cyl.  Carry if no disk.
fdc_seek:
        ld a,(pk_side)
        add a,a
        add a,a
        ld b,a
        ld a,(pk_drive)
        or b
        or 8                    ; double density
        out (FDC_LATCH),a
        ld a,(pk_drive)         ; the track register belongs to the last drive used
        ld hl,fdc_drv
        cp (hl)
        jr z,.same
        ld (hl),a
        ld a,$FF
        ld (fdc_cyl),a
.same:  ld a,(fdc_cyl)
        cp $FF
        jr nz,.known
        ld a,$00                ; restore (home)
        out (FDC_CMD),a
        call fdc_wait
        bit 7,a
        scf
        ret nz                  ; not ready: no disk
        xor a
        ld (fdc_cyl),a
.known: ld a,(pk_cyl)
        ld hl,fdc_cyl
        cp (hl)
        ret z                   ; (carry clear)
        ld (hl),a
        out (FDC_DAT),a
        ld a,$10                ; seek
        out (FDC_CMD),a
        call fdc_wait
        bit 7,a
        scf
        ret nz
        or a
        ret

; Wait for the command to finish; A = status.
fdc_wait:
        ld b,0                  ; (a little settle before polling)
        djnz $
        ld bc,0                 ; ~3 s, then give up (status FF: "not ready")
        ld d,4
.w:     in a,(FDC_LATCH)
        rla
        jr c,.ok
        djnz .w
        dec c
        jr nz,.w
        dec d
        jr nz,.w
        ld a,$D0                ; force interrupt
        out (FDC_CMD),a
        ld a,$FF
        ret
.ok:    in a,(FDC_CMD)
        ret

skew:   db 1,4,7,0,3,6,9,2,5,8  ; logical slot -> physical slot (3:1)
str_reading: db "READING DISK  ",0
str_insert:  db "INSERT DISK  ",0
str_sig:     db "BLACKOUT PACK "
