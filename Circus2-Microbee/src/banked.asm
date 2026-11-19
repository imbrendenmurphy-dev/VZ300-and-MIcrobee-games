; Premium Plus 1MB asset residency: blocks 4..24 hold 672 KiB.
; Block 2 executes the game, block 0 is the fixed upper 32 KiB.
; All paging instructions execute from fixed upper RAM.
install_resident:
 ld hl,resident_image
 ld de,$E000
 ld bc,resident_image_end-resident_image
 ldir
 ret

load_scene:
 ; A = 0..8 act scenery, 9 illustrated title.
 push af
 ld a,6
 out ($0C),a
 xor a
 out ($0D),a
 pop af
 ld (scene_number),a
 ld c,a
 ld hl,0
 ld de,3000
 or a
 jr z,.offset_done
.offset: add hl,de
 dec a
 jr nz,.offset
.offset_done:
 ld (scene_offset),hl
 ld a,c
 add a,a
 add a,4
 ld c,a
 ld a,(mono_mode)
 add a,c
 call block_port
 call resident_pcg
 ld hl,(scene_offset)
 ld de,$C000
 ld bc,1000
 ld a,24
 call block_port
 call resident_fetch
 ld hl,(scene_offset)
 ld de,1000
 add hl,de
 ld de,$C400
 ld bc,1000
 ld a,24
 call block_port
 call resident_fetch
 ld hl,(scene_offset)
 ld de,2000
 add hl,de
 ld de,$C800
 ld bc,1000
 ld a,24
 call block_port
 call resident_fetch
 ld hl,$C000
 ld de,MAP
 ld bc,1000
 ldir
 ld hl,$C400
 ld de,ATTR
 ld bc,1000
 ldir
 ld hl,$C800
 ld de,COL
 ld bc,1000
 ldir
 ld hl,dirty_rows
 ld de,dirty_rows+1
 ld bc,24
 ld (hl),1
 ldir
 ld a,(mono_mode)
 or a
 ret z
 ld a,$40
 out ($08),a
 ld hl,$F800
 ld de,$F801
 ld bc,999
 ld (hl),$0F
 ldir
 xor a
 out ($08),a
 ret
block_port:
 push hl
 push de
 ld e,a
 ld d,0
 ld hl,block_ports
 add hl,de
 ld a,(hl)
 pop de
 pop hl
 ret
block_ports:
 db $06,$07,$04,$05,$26,$27,$24,$25
 db $46,$47,$44,$45,$66,$67,$64,$65
 db $86,$87,$84,$85,$A6,$A7,$A4,$A5
 db $C6,$C7,$C4,$C5,$E6,$E7,$E4,$E5

resident_image:
 DISP $E000
resident_fetch:
 di
 out ($50),a
 ldir
 ld a,4
 out ($50),a
 ret
resident_pcg:
 di
 out ($50),a
 xor a
 out ($08),a
 ld hl,0
 ld a,$80
.bank:
 push af
 out ($1C),a
 ld de,$F800
 ld bc,2048
 ldir
 pop af
 inc a
 cp $90
 jr nz,.bank
 ld a,4
 out ($50),a
 ld a,$80
 out ($1C),a
 ret
 ENT
resident_image_end:
