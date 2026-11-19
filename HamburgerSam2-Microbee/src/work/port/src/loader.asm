; CP/M loader: ten colour/mono scene banks, read before taking over hardware.
load_assets:
        ld hl,store_image
        ld de,$8100
        ld bc,store_end-store_record
        ldir
        ld de,asset_fcb
        ld c,15
        call 5
        inc a
        jp z,load_error
        ld a,4
        ld (asset_bank),a
.bank:  ld hl,0
        ld (asset_dest),hl
        xor a
        ld (asset_count),a
.record:ld de,$8000
        ld c,26
        call 5
        ld de,asset_fcb
        ld c,20
        call 5
        or a
        jp nz,load_error
        ld a,(asset_bank)
        call block_port
        ld hl,$8000
        ld de,(asset_dest)
        ld bc,128
        call store_record
        ld (asset_dest),de
        ld hl,asset_count
        dec (hl)
        jr nz,.record
        ld hl,asset_bank
        inc (hl)
        ld a,(hl)
        cp 19                   ; blocks 4-18: 11 scenes + 4 sprite-cache blocks
        jr nz,.bank
        ld de,asset_fcb
        ld c,16
        call 5
        ret
load_error:
        ld de,asset_error
        ld c,9
        call 5
        jp 0
asset_error: db 13,10,"HAMSAM2.DAT missing or incomplete.",13,10,"$"
asset_fcb: db 0,"HAMSAM2 DAT"
        ds 25,0
asset_bank: db 0
asset_count: db 0
asset_dest: dw 0
store_image:
        DISP $8100
store_record:
        di
        out ($50),a
        ldir
        ld a,12
        out ($50),a
        ei
        ret
store_end:
        ENT
block_port:
        push hl
        ld hl,block_ports
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ret
block_ports:
        db $06,$07,$04,$05,$26,$27,$24,$25
        db $46,$47,$44,$45,$66,$67,$64,$65
        db $86,$87,$84,$85,$A6,$A7,$A4,$A5
        db $C6,$C7,$C4,$C5,$E6,$E7,$E4,$E5
