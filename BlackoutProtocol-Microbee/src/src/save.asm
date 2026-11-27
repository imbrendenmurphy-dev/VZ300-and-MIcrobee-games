; ---------------------------------------------------------------------------
; Save games: SAVES.DAT on the disk, 512 bytes a slot (the record uses the first
; 256).  Slot 0 is the autosave (written when a key comes online), slots 1-3 are
; the player's.  Read and written through CP/M itself (cpm_io below): the game
; parks its own copy of D600-EFFF in a bank, puts back the CP/M it saved at
; start-up, lets the BDOS do the disk work, then swaps back.  CP/M's own disk
; code is what works on every Premium Plus, SD-card disk images included.
; Record: "BPS1", room, door side, clock h m s, wings seen, said hour, keys
; online, shards held, level, then the game_vars block.
; ---------------------------------------------------------------------------
SAVE_BUF equ $4F00              ; 256 bytes in the program's own block (CP/M leaves it
                                ; alone), above the overlays and the room record
SAVE_LEN equ 256
SV_ROOM  equ 4
SV_SIDE  equ 5
SV_CLK   equ 6
SV_WINGS equ 9
SV_HOUR  equ 10
SV_KEYS  equ 11
SV_SHARDS equ 12
SV_SKILL equ 13
SV_VARS  equ 16

; Slot A: read it into SAVE_BUF.  Carry on a disk error.
slot_read:
        ld c,33                 ; BDOS read random
        jp cpm_io

; Slot A: write SAVE_BUF to it.  Carry on a disk error.
slot_write:
        ld c,34                 ; BDOS write random
        jp cpm_io

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
        ld bc,SAVE_LEN-1
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
; Generous by design: Agent leaves a first-time player ~40 deaths to spare (see DESIGN.md).
sk_tab: db  32,        3,       150,      150,   0,            1,  1, 2   ; Story
        db  24,        6,       90,       100,   0,            0,  0, 1   ; Agent
        db  17,        12,      55,       60,    1,            0,  0, 0   ; Ghost

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

; ------------------------------------------------------------- CP/M
; C = BDOS function (33 read / 34 write random), A = slot: the first two 128-byte
; records of the slot <-> SAVE_BUF.  Carry if CP/M reported a problem.
; Runs entirely from the program's own block (0100-4FFF) and FARCODE: CP/M's
; BDOS and BIOS sit at D600-FFFF, and the game's copy of D600-EFFF goes to a bank
; while CP/M is back.  (F000-FFFF is RAM the game never touches: its video window
; covers it.)  A disk error doesn't stop on CP/M's "Err On A:": the BDOS error
; routines are pointed at cpm_err while we're in.
CPM_BASE equ $D600              ; BDOS
CPM_LEN  equ $F000-CPM_BASE
CPM_SAVED equ 28                ; CP/M as it was at start-up (bank.asm)
CPM_PARK  equ 27                ; the game's own D600-EFFF while CP/M is in
PORT_CPM  equ $0C               ; CP/M's map: block 2 low, video off (RAM at F000)
CPM_SP   equ $4EF0              ; a small stack, and our flags, below SAVE_BUF
CPM_ERRF equ $4EF2
CPM_FN   equ $4EF3
CPM_REC  equ $4EF4
cpm_io:
        ld (CPM_SP),sp
        ld sp,CPM_SP            ; (grows down from 4EF0)
        add a,a                 ; slot * 4 records
        add a,a
        ld (CPM_REC),a
        ld a,c
        ld (CPM_FN),a
        di
        ld a,CPM_PARK           ; the game's D600-EFFF -> its bank
        call bank_port
        ld hl,CPM_BASE
        ld de,0
        ld bc,CPM_LEN
        call far_move
        ld a,CPM_SAVED          ; CP/M back in
        call bank_port
        ld hl,0
        ld de,CPM_BASE
        ld bc,CPM_LEN
        call far_move
        ld hl,cpm_err           ; disk errors come to us, not to the console
        ld (CPM_BASE+9),hl
        ld (CPM_BASE+11),hl
        ld (CPM_BASE+13),hl
        ld (CPM_BASE+15),hl
        xor a
        ld (CPM_ERRF),a
        ld a,PORT_CPM
        out ($50),a
        ei
        ld c,13                 ; reset the disk system
        call 5
        ld hl,sv_fcb+12         ; a fresh FCB: extent, records, map, random record
        ld b,24
.z:     ld (hl),0
        inc hl
        djnz .z
        ld de,sv_fcb
        ld c,15                 ; open SAVES.DAT
        call 5
        inc a
        jr z,.bad
        ld hl,SAVE_BUF
        ld a,(CPM_REC)
        call .rec
        ld hl,SAVE_BUF+128
        ld a,(CPM_REC)
        inc a
        call .rec
        ld a,(CPM_FN)
        cp 34
        jr nz,.out
        ld de,sv_fcb
        ld c,16                 ; close: the directory is up to date
        call 5
        inc a
        jr nz,.out
.bad:   ld a,1
        ld (CPM_ERRF),a
.out:   di
        ld a,PORT_GAME
        out ($50),a
        ld a,CPM_SAVED          ; CP/M as it now stands -> its bank (for next time)
        call bank_port
        ld hl,CPM_BASE
        ld de,0
        ld bc,CPM_LEN
        call far_move
        ld a,CPM_PARK           ; and the game back
        call bank_port
        ld hl,0
        ld de,CPM_BASE
        ld bc,CPM_LEN
        call far_move
        ld sp,(CPM_SP)
        ld a,(CPM_ERRF)
        or a
        ret z
        scf
        ret
; HL = buffer, A = record: one random read or write.
.rec:   ld (sv_fcb+33),a
        xor a
        ld (sv_fcb+34),a
        ld (sv_fcb+35),a
        ex de,hl
        ld c,26                 ; DMA
        call 5
        ld de,sv_fcb
        ld a,(CPM_FN)
        ld c,a
        call 5
        or a
        ret z
        ld a,1
        ld (CPM_ERRF),a
        ret
; The BDOS's four error routines (bad sector, select, read-only disk, read-only
; file), while we're in: note it and carry on ("ignore", as RETURN would).
cpm_err:
        ld a,1
        ld (CPM_ERRF),a
        ret
sv_fcb: db 1,"SAVES   DAT"
        ds 24,0

str_nosave: db "SAVE FAILED",0
str_saved:  db "GAME SAVED",0       ; (resident: resume_room reloads the overlay window
;  before these are printed)
        ASSERT SV_VARS+game_vars_end-game_vars <= SAVE_LEN
