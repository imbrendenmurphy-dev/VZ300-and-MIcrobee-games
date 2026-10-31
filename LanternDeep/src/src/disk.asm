; =====================================================================
; THE LANTERN DEEP - saving the journey to disk
;
; CP/M is gone once the game owns the machine, so the game drives the
; WD2793 itself, with the same commands, ports and timing as the Microbee
; CP/M BIOS on this disk: port 48h = drive | side<<2 | 08h (double
; density), 44h-47h command/status, track, sector, data; port 48h bit 7
; = DRQ or INTRQ. Read sector 88h, write sector A8h, seek 1Ch, restore 0Bh.
;
; The journey is kept in SAVE.DAT, which is always the first file on the
; disk (blocks 1-2); its sectors are listed in gen/savemap.asm. Before
; anything is written, the file's first sector is read and must begin
; with its signature, so nothing else on the disk can be touched.
;   sector 0 : signature, valid flag, checksum, the journey (see sv_vars)
;   1-10     : the explored-cell bits of every room (STATE block 0-13FFh)
; =====================================================================
FBUF        EQU OUTQ            ; 512-byte sector buffer (the output queues)

fd_drive:   DB 0
fd_idx:     DB 0
fd_sec:     DB 0

; settle time after a seek (the BIOS's own delay loop)
fd_settle:  push hl
.o:         ld hl,$007A
.i:         dec hl : ld a,h : or l : jr nz,.i
            djnz .o
            pop hl
            ret

; A = command: issue it, then wait while the controller is busy (with a
; limit, so a missing drive cannot hang the game). -> A = status
fd_cmd:     out ($44),a
            ld a,$10
.d:         dec a : jr nz,.d
            ret
fd_cmdw:    call fd_cmd
fd_wait:    push bc
            ld bc,0
.w:         in a,($44) : bit 0,a : jr z,.ok
            dec bc : ld a,b : or c : jr nz,.w
            ld a,$D0 : out ($44),a          ; give up: force interrupt
            ld a,$FF
.ok:        pop bc
            ret

; select the drive (side 0) and find track 0
fd_restore: ld a,(fd_drive) : or $08 : out ($48),a
            ld a,$D0 : call fd_cmd
            ld a,$0B : call fd_cmdw
            ld b,$1E : jp fd_settle

; A = save sector 0..10: select the side, seek its track, set the sector
fd_locate:  ld l,a : ld h,0 : ld e,l : ld d,h
            add hl,hl : add hl,de : ld de,SAVE_SECT : add hl,de
            ld d,(hl) : inc hl                          ; track
            ld a,(hl) : inc hl : add a,a : add a,a      ; side -> bit 2
            ld e,a
            ld a,(fd_drive) : or e : or $08 : out ($48),a
            ld a,(hl) : ld (fd_sec),a
            in a,($45) : cp d : jr z,.ok
            ld a,d : out ($47),a
            ld a,$1C : call fd_cmdw
            ld b,$1E : call fd_settle
.ok:        ld a,(fd_sec) : out ($46),a
            ret

; A = save sector: read it into FBUF. -> Z if good
fd_read:    ld (fd_idx),a
            ld b,10                                     ; tries
.try:       push bc
            ld a,(fd_idx) : call fd_locate
            ld hl,FBUF : ld bc,$0048                    ; 256 x 2 bytes, C = 48h
            ld a,$88 : call fd_cmd
.r1:        in a,(c) : jp p,.r1
            in a,($47) : ld (hl),a : inc hl
.r2:        in a,(c) : jp p,.r2
            in a,($47) : ld (hl),a : inc hl
            djnz .r1
            call fd_wait : and $9C
            pop bc
            ret z
            push bc : call fd_restore : pop bc
            djnz .try
            or 1
            ret

; A = save sector: write FBUF to it. -> Z if good
fd_write:   ld (fd_idx),a
            ld b,10
.try:       push bc
            ld a,(fd_idx) : call fd_locate
            ld hl,FBUF : ld bc,$0048
            ld a,$A8 : call fd_cmd
.w1:        ld a,(hl)
.p1:        in d,(c) : jp p,.p1
            out ($47),a : inc hl
            ld a,(hl)
.p2:        in d,(c) : jp p,.p2
            out ($47),a : inc hl
            djnz .w1
            call fd_wait : and $FC
            pop bc
            ret z
            bit 6,a : jr nz,.wp                         ; write protected: no point
            push bc : call fd_restore : pop bc
            djnz .try
.wp:        or 1
            ret

; which drive holds this game's disk? -> Z and fd_drive set if found
fd_find:    xor a
            call .one : ret z
            ld a,1
.one:       ld (fd_drive),a
            call fd_restore
            xor a : call fd_read : ret nz
            ld hl,FBUF : ld de,sv_sig : ld b,16
.c:         ld a,(de) : cp (hl) : ret nz
            inc hl : inc de
            djnz .c
            ret
sv_sig:     DB "LANTERN-DEEP-SAV"

; the journey's state (all in the home block), in save order
sv_vars:    DW items : DB 1
            DW hp_max : DB 1
            DW gold : DB 2
            DW ck_room : DB 1
            DW ck_xy : DB 2
            DW ck_dir : DB 1
            DW lives : DB 1
            DW room_bits : DB 5*N_ROOMS        ; room states and visited flags
            DW 0
SV_STATE    EQU 18                          ; where they start in sector 0

; -> A = 0 saved, 1 game disk not found, 2 disk error / write protected
save_game:  call flush_outq
            ld a,(in_room) : or a : jr z,.ns
            ld a,(cur_room) : call seen_save    ; this room's explored cells too
.ns:        call fd_find
            ld a,1 : jr nz,.out
            ; the explored cells: STATE block 0000-13FF, sectors 1-10
            ld b,10
.s:         push bc
            ld a,10 : sub b                     ; 0..9
            push af
            add a,a : ld h,a : ld l,0           ; offset A*512
            ld a,BLK_STATE : ld de,FBUF : ld bc,512 : call bank_read
            pop af : inc a
            call fd_write
            pop bc
            ld a,2 : jr nz,.out
            djnz .s
            ; then the header with the journey (written last)
            ld hl,FBUF : ld bc,512 : ld e,0 : call fill
            ld hl,sv_sig : ld de,FBUF : ld bc,16 : ldir
            ld a,1 : ld (FBUF+16),a
            ld de,FBUF+SV_STATE
            ld hl,sv_vars
.v:         ld c,(hl) : inc hl : ld b,(hl) : inc hl
            ld a,b : or c : jr z,.vd
            ld a,(hl) : inc hl
            push hl
            ld h,b : ld l,c : ld c,a : ld b,0
            ldir
            pop hl
            jr .v
.vd:        call sv_sum : ld (FBUF+17),a
            xor a : call fd_write
            ld a,2 : jr nz,.out
            xor a
.out:       push af
            call q_reset
            ld a,(fd_drive) : or $08 : out ($48),a  ; (leave drive A selected)
            pop af
            ret

; checksum of FBUF+18 .. FBUF+511 -> A
sv_sum:     ld hl,FBUF+SV_STATE : ld bc,512-SV_STATE
            xor a
.s:         add a,(hl) : rlca : inc hl
            dec bc : ld e,a : ld a,b : or c : ld a,e : jr nz,.s
            ret

; -> Z if a saved journey was found and restored (ck_valid set)
load_game:  call fd_find : ret nz
            ld a,(FBUF+16) : cp 1 : ret nz
            call sv_sum : ld hl,FBUF+17 : cp (hl) : ret nz
            ld hl,FBUF+SV_STATE
            ld de,sv_vars
.v:         ld a,(de) : ld c,a : inc de : ld a,(de) : ld b,a : inc de
            or c : jr z,.vd
            ld a,(de) : inc de
            push de
            ld d,b : ld e,c : ld c,a : ld b,0
            ldir
            pop de
            jr .v
.vd:        ; the explored cells back into the STATE block
            ld b,10
.s:         push bc
            ld a,11 : sub b                     ; sectors 1..10
            push af
            call fd_read
            pop de
            pop bc
            ret nz
            ld a,d : dec a : add a,a : ld d,a : ld e,0
            push bc
            ld a,BLK_STATE : ld hl,FBUF : ld bc,512 : call bank_read
            pop bc
            djnz .s
            ld a,1 : ld (ck_valid),a
            xor a
            ret

; ---------------------------------------------------------------------
; The journal offers S to save; the title's CONTINUE looks on the disk
; when there is no journey in memory.
; ---------------------------------------------------------------------
j_hint:     ld hl,17*80 : ld de,t_savehint : ld c,C_DGR : jp print_centre

; in the journal's wait: S saves (then waits for S to be let go)
j_savekey:  ld a,1 : out (P_ROMLAT),a
            ld a,19 : call keytest : ld b,a
            xor a : out (P_ROMLAT),a
            ld a,b : or a : ret z
            ld hl,17*80 : call clear_row
            ld de,t_saving : ld c,C_BYEL : call print_centre
            call save_game
            add a,a : ld e,a : ld d,0
            ld hl,sv_msgs : add hl,de
            ld e,(hl) : inc hl : ld d,(hl)
            push de
            ld hl,17*80 : call clear_row
            pop de
            ld c,C_BYEL : call print_centre
.w:         call j_frame
            ld a,1 : out (P_ROMLAT),a
            ld a,19 : call keytest : ld b,a
            xor a : out (P_ROMLAT),a
            ld a,b : or a : jr nz,.w
            xor a : ld (input),a
            ret

; title: CONTINUE with nothing in memory -> look on the disk. Z if found.
title_load: ld hl,23*80 : call clear_row
            ld de,t_looking : ld c,C_GRY : call print_centre
            call load_game
            ret z
            ld hl,23*80 : call clear_row
            or 1
            ret

t_savehint: DB "S  SAVE YOUR JOURNEY TO DISK",0
t_saving:   DB "SAVING...",0
t_looking:  DB "LOOKING FOR A SAVED JOURNEY...",0
sv_msgs:    DW t_saved,t_nodisk,t_derror
t_saved:    DB "YOUR JOURNEY IS SAVED. CONTINUE FROM THE TITLE TO RETURN HERE.",0
t_nodisk:   DB "THE LANTERN DEEP DISK WAS NOT FOUND IN DRIVE A OR B.",0
t_derror:   DB "THE DISK COULD NOT BE WRITTEN. IS IT WRITE-PROTECTED?",0
