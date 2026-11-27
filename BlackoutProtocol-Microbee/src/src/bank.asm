; ---------------------------------------------------------------------------
; The 1 MB.  Port 50 picks which 32K block appears at 0000-7FFF; 8000-FFFF is
; always block 0.  Block 2 is this program's lower half; BLACKOUT.DAT is
; loaded at start-up into blocks DAT_FIRST.. (see tools/gen.py).
; Code that runs while another block is switched in lives in upper RAM.
; ---------------------------------------------------------------------------
BOUNCE   equ $8F00              ; 256-byte bounce buffer (just above BACK)
FARCODE  equ $CF00              ; far_chunk + spr_blit, copied here at start
DATA_WIN equ $4400              ; 3K window in the program's own block:
STAGE    equ DATA_WIN           ;   a room record while it's being built,
SHAFT_PM equ DATA_WIN           ;   or the current shaft's pair map
DAT_FIRST equ 4
PORT_GAME equ $04               ; ROMs out, video at F000, block 2 low

; A = block 0..31 -> A = the port 50 value that maps it at 0000 (video on).
bank_port:
        push bc
        ld b,a
        and 3
        xor 2
        or 4
        ld c,a
        ld a,b
        and $1C
        rlca
        rlca
        rlca
        or c
        pop bc
        ret

; ------------------------------------------------------------- start-up load
; Read BLACKOUT.DAT through CP/M, 128 bytes at a time, into the blocks.
load_assets:
        ld hl,store_image       ; the store routine must sit in upper RAM
        ld de,$8100
        ld bc,store_end-store_record
        ldir
        ld de,str_loading
        ld c,9
        call 5
        ld de,ovl_fcb           ; the screens overlays into their blocks
        ld a,OVL_BLOCK
        call load_file
        ld de,ovl2_fcb
        ld a,OVL2_BLOCK
        call load_file
        ld de,dat_fcb
        ld a,DAT_FIRST
        call load_file
; The wings, MERIDIAN's voice and the music: each WINGn.DAT straight into its pack's
; blocks.  Everything is on the one disk, so all of it is in RAM from here on.
        ld de,wing2_fcb
        ld a,PACK1_BASE
        call load_file
        ld de,wing3_fcb
        ld a,PACK2_BASE
        call load_file
        ld de,wing4_fcb
        ld a,PACK3_BASE
        call load_file
        ld a,7
        ld (ld_packs),a
; The BIOS answers a write to a write-protected disk with "DISKETTE A IS WRITE
; PROTECTED - PRESS RETURN TO TRY AGAIN" and waits, again and again.  Mid-game that
; would hang a save, so (only if these are exactly the expected bytes) the branch
; that leads to it becomes "return the error": the save then just says SAVE FAILED.
        di
        ld a,12                 ; CP/M's map with the video off: the BIOS's RAM at F000
        out ($50),a
        ld hl,$F077
        ld de,wp_code
        ld b,8
.wp:    ld a,(de)
        cp (hl)
        jr nz,.nowp
        inc hl
        inc de
        djnz .wp
        ld a,$18                ; JR Z,+20 -> JR +20
        ld ($F07D),a
.nowp:  ei
; Last, CP/M itself (BDOS + BIOS, D600-EFFF) into a bank: the game will overwrite it,
; and puts it back for a moment whenever it saves or loads (save.asm, cpm_io).
        ld a,CPM_SAVED
        call bank_port
        ld hl,CPM_BASE
        ld de,0
        ld bc,CPM_LEN
        jp $8100

; DE = FCB, A = first block: read the whole file into the banks.
load_file:
        ld (ld_block),a
        ld (ld_fcb),de
        ld c,15                 ; open
        call 5
        inc a
        jp z,load_error
        ld hl,0
        ld (ld_dest),hl
.rec:   ld de,$8000
        ld c,26                 ; DMA
        call 5
        ld de,(ld_fcb)
        ld c,20                 ; read sequential
        call 5
        or a
        jr nz,.eof
        ld a,(ld_block)
        call bank_port
        ld hl,$8000
        ld de,(ld_dest)
        ld bc,128
        call $8100
        ld (ld_dest),de
        ld a,d                  ; a dot every 4 KB read
        and $0F
        or e
        jr nz,.nd
        push de
        ld e,'.'
        ld c,2
        call 5
        pop de
.nd:    ld a,d
        cp $80
        jp c,.rec
        ld hl,0                 ; this block is full: on to the next
        ld (ld_dest),hl
        ld hl,ld_block
        inc (hl)
        jr .rec
.eof:   ld de,(ld_fcb)
        ld c,16                 ; close
        jp 5
load_error:
        ld de,str_nodat
        ld c,9
        call 5
        jp 0
str_loading: db 13,10,"BLACKOUT PROTOCOL - loading the station...",13,10,"$"
str_nodat:   db 13,10,"A game file is missing or unreadable: please copy the disk again.",13,10,"$"
ld_block: db 0                  ; (here, not at E000: CP/M is still up there while loading)
ld_dest: dw 0
ld_fcb: dw 0
dat_fcb: db 0,"BLACKOUTDAT"
        ds 25,0
wing2_fcb: db 0,"WING2   DAT"
        ds 25,0
wing3_fcb: db 0,"WING3   DAT"
        ds 25,0
wing4_fcb: db 0,"WING4   DAT"
        ds 25,0
ld_packs: db 0                  ; packs read at start-up (bit 0 = pack 1 ...)

ovl_fcb: db 0,"BLACKOUTOVL"
        ds 25,0
ovl2_fcb: db 0,"BLACKOUTOV2"
        ds 25,0
wp_code: db $DB,$44,$CB,$77,$3E,$01,$28,$14   ; IN A,(44h) / BIT 6,A / LD A,1 / JR Z,..
store_image:
        DISP $8100
store_record:
        di
        out ($50),a
        ldir
        ld a,12                 ; back to CP/M's own map
        out ($50),a
        ei
        ret
store_end:
        ENT

; ------------------------------------------------------------- far copies
far_init:
        ld hl,farcode_image
        ld de,FARCODE
        ld bc,farcode_end-far_chunk
        ldir
        ld hl,upcode2_image
        ld de,UPCODE2
        ld bc,upcode2_end-sp_play
        ldir
        ret

UPCODE2 equ $EC00               ; more code that runs with a data block switched in
upcode2_image:
        DISP UPCODE2
; A = port, HL = samples (1 bit each, MSB first) in that block, BC = bytes.
sp_play:
        out ($50),a
.by:    ld d,(hl)
        inc hl
        ld e,8
.bi:    rl d
        sbc a,a
        and $40
        out ($02),a
        ld a,SP_DELAY
.w:     dec a
        jr nz,.w
        dec e
        jr nz,.bi
        dec bc
        ld a,b
        or c
        jr nz,.by
        ld a,PORT_GAME
        out ($50),a
        ret
upcode2_end:
        ENT
        ASSERT upcode2_end-sp_play <= 256
farcode_image:
        DISP FARCODE
; A = port value, HL = source in that block, BC = 1..256 bytes -> BOUNCE.
far_chunk:
        out ($50),a
        ld de,BOUNCE
        ldir
        ld a,PORT_GAME
        out ($50),a
        ret
; A = port, HL = pre-shifted rows (inverted mask, pixels) x 4 in that block,
; DE = NATIVE destination (line-adjusted), B = rows, C = line within the cell.
spr_blit:
        out ($50),a
.row:   push de
        push hl                 ; count fields while drawing (see vb_poll)
        in a,($0C)
        and $20
        ld hl,vb_last
        cp (hl)
        jr z,.nv
        ld (hl),a
        or a
        jr z,.nv
        ld hl,vb_count
        inc (hl)
.nv:    pop hl
        REPT 3
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        ld a,e
        add a,16
        ld e,a
        jr nc,1F
        inc d
1:
        ENDR
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        pop de
        inc c
        ld a,c
        cp 12
        jr z,.wrap
        inc de
        djnz .row
        jr .done
.wrap:  ld c,0
        ex de,hl
        push bc
        ld bc,COLS*16-11
        add hl,bc
        pop bc
        ex de,hl
        djnz .row
.done:  ld a,PORT_GAME
        out ($50),a
        ret
far_move:                       ; A = port (a block low), HL -> DE, BC bytes
        out ($50),a             ; (copies between a bank and upper RAM either way)
        ldir
        ld a,PORT_GAME
        out ($50),a
        ret
farcode_end:
        ENT
        ASSERT farcode_end-far_chunk <= 256

; A = block, HL = source address (0000-7FFF), DE = destination (not BOUNCE),
; BC = length.  Interrupts are off throughout the game.
far_copy:
        call bank_port
        ld (fc_port),a
.next:  ld a,b
        or c
        ret z
        push bc
        ld a,b                  ; this chunk: up to 256
        or a
        jr z,.small
        ld bc,256
.small: push bc
        push de
        ld a,(fc_port)
        call far_chunk
        pop de
        pop bc                  ; chunk length
        push hl
        ld hl,BOUNCE
        push bc
        ldir
        pop bc
        pop hl
        ex (sp),hl              ; HL = total left
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        jr .next

; HL = far descriptor (block, offset, length), DE = destination.
far_load:
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        pop hl
        jp far_copy

