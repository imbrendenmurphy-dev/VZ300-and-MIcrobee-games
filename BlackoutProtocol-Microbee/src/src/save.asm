; ---------------------------------------------------------------------------
; Save games: SAVES.DAT on disk A (CP/M block 2 = data-area logical sectors
; 16..19), one 512-byte sector a slot.  Slot 0 is the autosave (written when a
; key comes online), slots 1-3 are the player's.  Read and written straight
; through the WD2793, in the same way as the packs.
; Record: "BPS1", room, door side, clock h m s, wings seen, said hour, keys
; online, shards held, then the game_vars block.
; ---------------------------------------------------------------------------
SAVE_BUF equ DIRTY_PREV         ; 512 bytes; only used while a page is up
SAVE_LSEC equ 16
SV_ROOM  equ 4
SV_SIDE  equ 5
SV_CLK   equ 6
SV_WINGS equ 9
SV_HOUR  equ 10
SV_KEYS  equ 11
SV_SHARDS equ 12
SV_SKILL equ 13
SV_VARS  equ 16

; Slot A: read its sector into SAVE_BUF.  Carry on a disk error.
slot_read:
        call slot_at
        ld hl,SAVE_BUF
        jp sec_read

; Slot A: write SAVE_BUF to it.  Carry on an error, A = status (bit 6 = protected).
slot_write:
        call slot_at
        ld hl,SAVE_BUF
        jp sec_write

slot_at:
        add a,SAVE_LSEC
        ld l,a
        ld h,0
        ld (pk_lsec),hl
        xor a
        ld (pk_drive),a
        ret

; Z if SAVE_BUF holds a save.
save_valid:
        ld hl,SAVE_BUF
        ld de,save_magic
        ld b,4
.c:     ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .c
        ret                     ; (Z = valid)
save_magic: db "BPS1"

; The game as it stands -> SAVE_BUF.
save_pack:
        ld hl,SAVE_BUF
        ld de,SAVE_BUF+1
        ld bc,511
        ld (hl),0
        ldir
        ld hl,save_magic
        ld de,SAVE_BUF
        ld bc,4
        ldir
        ld a,(cur_room)
        ld (SAVE_BUF+SV_ROOM),a
        ld a,(arr_face)         ; came in facing right = through the left door
        ld (SAVE_BUF+SV_SIDE),a
        ld hl,clk_h
        ld de,SAVE_BUF+SV_CLK
        ld bc,3
        ldir
        ld a,(wings_seen)
        ld (SAVE_BUF+SV_WINGS),a
        ld a,(said_hour)
        ld (SAVE_BUF+SV_HOUR),a
        ld a,(keys_done)        ; for the slot list: keys online, shards held
        call count_bits
        ld (SAVE_BUF+SV_KEYS),a
        ld hl,shards
        ld b,3
        ld c,0
.sh:    ld a,(hl)
        push bc
        call count_bits
        pop bc
        add a,c
        ld c,a
        inc hl
        djnz .sh
        ld a,c
        ld (SAVE_BUF+SV_SHARDS),a
        ld a,(skill)
        ld (SAVE_BUF+SV_SKILL),a
        ld hl,game_vars
        ld de,SAVE_BUF+SV_VARS
        ld bc,game_vars_end-game_vars
        ldir
        ret

; SAVE_BUF -> the game, and into the room it was saved in.  Never returns.
save_restore:
        ld hl,SAVE_BUF+SV_VARS
        ld de,game_vars
        ld bc,game_vars_end-game_vars
        ldir
        ld hl,SAVE_BUF+SV_CLK
        ld de,clk_h
        ld bc,3
        ldir
        ld a,(SAVE_BUF+SV_WINGS)
        ld (wings_seen),a
        ld a,(SAVE_BUF+SV_HOUR)
        ld (said_hour),a
        ld a,(SAVE_BUF+SV_SKILL)
        ld (skill),a
        call skill_apply
        ld hl,0                 ; asleep robots don't stay asleep across a load
        ld (sleep_t),hl
        ld sp,STACKTOP
        ld a,(SAVE_BUF+SV_SIDE)
        ld b,a
        ld a,(SAVE_BUF+SV_ROOM)
        call enter_room
        jp loop

; Autosave into slot 0 (when a key comes online).
autosave:
        call present            ; SAVE_BUF is the last-frame dirty list: two
        call present            ; presents with nothing new leave both lists empty
        call save_pack
        xor a
        call slot_write
        ret nc
        ld hl,str_nosave
        jp msg_show

; ------------------------------------------------------------ difficulty
; skill (0 Story, 1 Agent, 2 Ghost) -> clock speed, death penalty, gun cool-down,
; grace on entry, Ghost's quick patrols, Story's slow hunters.
skill_apply:
        ld a,(skill)
        add a,a
        add a,a
        add a,a                 ; x8
        ld e,a
        ld d,0
        ld hl,sk_tab
        add hl,de
        ld de,sk_vars
        ld bc,8
        ldir
        ld a,(pen_min)          ; "- 10 MINUTES" -> the level's penalty
        ld c,'0'-1
.t:     inc c
        sub 10
        jr nc,.t
        add a,'0'+10
        ld (str_penalty+3),a
        ld a,c
        ld (str_penalty+2),a
        ret
;            fields/s  min off  gun cool  grace  fast patrols  slow hunters
; (then: hunters stand down, robot touch box trimmed each side by n half-pixels)
sk_tab: db  25,        5,       150,      150,   0,            1,  1, 2   ; Story
        db  19,        10,      90,       100,   0,            0,  0, 1   ; Agent
        db  16,        15,      50,       50,    1,            0,  0, 0   ; Ghost

; A = number of bits set.  Preserves HL.
count_bits:
        ld c,0
.b:     or a
        jr z,.d
        srl a
        jr nc,.b
        inc c
        jr .b
.d:     ld a,c
        ret

; ------------------------------------------------------------- sectors
; Logical sector pk_lsec of drive pk_drive <-> HL (fixed RAM).  Carry on error.
sec_read:
        ld a,$80                ; READ SECTOR
        jr sec_io
sec_write:
        ld a,$A0                ; WRITE SECTOR
sec_io: ld (sec_cmd),a
        ld (sec_buf),hl
        call lsec_place         ; cylinder, side, sector ID
        ld b,3
.try:   push bc
        call fdc_seek
        jr c,.err
        ld a,(pk_id)
        out (FDC_SEC),a
        ld a,(sec_cmd)
        out (FDC_CMD),a
        ld hl,(sec_buf)
        cp $80
        jr nz,.wr
.rd:    in a,(FDC_LATCH)        ; bytes in on DRQ until INTRQ
        rla
        jr nc,.rd
        in a,(FDC_CMD)
        bit 1,a
        jr z,.done
        in a,(FDC_DAT)
        ld (hl),a
        inc hl
        jr .rd
.wr:    in a,(FDC_LATCH)        ; bytes out on DRQ until INTRQ
        rla
        jr nc,.wr
        in a,(FDC_CMD)
        bit 1,a
        jr z,.done
        ld a,(hl)
        out (FDC_DAT),a
        inc hl
        jr .wr
.done:  bit 6,a                 ; write protected: no point trying again
        jr nz,.prot
        and $1C
        jr nz,.err
        pop bc
        or a
        ret
.err:   pop bc
        ld a,$FF
        ld (fdc_cyl),a
        djnz .try
        scf
        ret
.prot:  pop bc
        scf
        ret

str_nosave: db "SAVE FAILED",0
str_saved:  db "GAME SAVED",0       ; (resident: resume_room reloads the overlay window
str_noprot: db "DISK A LOCKED",0    ;  before these are printed)
