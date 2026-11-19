; Stage all artwork into extended RAM while CP/M remains available.
load_pcg:
 ld de,loading_message
 ld c,9
 call 5
 ld hl,store_image
 ld de,$C100
 ld bc,store_image_end-store_image
 ldir
 ld a,4
 ld (asset_block),a
.file:
 ld hl,asset_fcb
 ld de,asset_fcb+1
 ld bc,35
 ld (hl),0
 ldir
 ld hl,asset_name
 ld de,asset_fcb+1
 ld bc,11
 ldir
 ld a,(asset_block)
 ld b,'0'
.tens:
 cp 10
 jr c,.digits
 sub 10
 inc b
 jr .tens
.digits:
 add a,'0'
 ld (asset_fcb+3),a
 ld a,b
 ld (asset_fcb+2),a
 ld de,asset_fcb
 ld c,15
 call 5
 inc a
 jp z,load_error
 ld hl,0
 ld (load_dest),hl
 ld a,0
 ld (load_count),a
.record:
 ld de,$C000
 ld c,26
 call 5
 ld de,asset_fcb
 ld c,20
 call 5
 or a
 jp nz,load_error
 ld a,(asset_block)
 call block_port
 ld hl,$C000
 ld de,(load_dest)
 ld bc,128
 call store_record
 ld (load_dest),de
 ld hl,load_count
 dec (hl)
 jr nz,.record
 ld de,asset_fcb
 ld c,16
 call 5
 ld e,'.'
 ld c,2
 call 5
 ld hl,asset_block
 inc (hl)
 ld a,(hl)
 cp 25
 jp nz,.file
 ret
load_error:
 ld de,load_message
 ld c,9
 call 5
 jp 0
load_message: db 13,10,"Circus artwork missing or damaged.",13,10,"$"
loading_message: db 13,10,"CIRCUS 2 - PREMIUM PLUS",13,10,"Loading 672K of artwork",13,10,"$"
asset_name: db "B04     DAT"
asset_fcb: ds 36,0
asset_block: db 0
load_count: db 0
load_dest: dw 0
store_image:
 DISP $C100
store_record:
 di
 out ($50),a
 ldir
 ld a,12
 out ($50),a
 ei
 ret
 ENT
store_image_end:
