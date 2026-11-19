; =====================================================================
; UBTYPE.COM - CP/M loader for uB-TYPE (Microbee Premium Plus)
;
; Adapted from the loader of The Lantern Deep. Runs under the Premium's
; own CP/M: loads the game's files into expanded RAM blocks through the
; lower 32K window, one 128-byte record at a time while CP/M stays alive,
; then takes over the machine: a final stage at F000h copies the staged
; files into their home blocks (and the program to 8000h of block 0) and
; starts the game.
;
; CP/M's own lower block is found by a signature scan and its video
; window by a probe, so port 50h can always be restored for BDOS calls.
; =====================================================================
            DEVICE NOSLOT64K
BDOS        EQU $0005
P_MEM       EQU $50
P_LV        EQU $1C

; blocks (must match src/hw.inc). Files that live in blocks CP/M could be
; using are staged high and moved by the final stage.
BLK_FRONT   EQU 1
BLK_WORK    EQU 2
BLK_LEVEL   EQU 3
BLK_STAGES  EQU 8           ; (levels, later)
STG_WORK    EQU 24
STG_LEVEL   EQU 25
STG_PROG    EQU 27
N_BLOCKS    EQU 28          ; blocks used while loading (0..27)

DMA         EQU $A800       ; record buffer (upper TPA)
PROG_LEN    EQU $5000       ; the program: 8000h onwards

            ORG $0100
start:      ld sp,$A7F0
            ld de,m_title
            ld c,9
            call BDOS
            ld a,(BDOS+2)
            cp $B0   ; TPA must reach past B000h
            jr nc,.tpa
            ld de,m_tpa
            ld c,9
            jp BDOS
.tpa:       ld hl,reloc
            ld de,$A000
            ld bc,reloc_end-reloc_start
            ldir
            ld hl,sig
            ld de,sig_copy
            ld bc,16
            ldir
            jp main

m_title:    DB 13,10,"STARHIVE - SOFTWARE SCROLL TEST - Microbee Premium Plus",13,10
            DB "VIBED BY BPM 2026",13,10,"$"
m_tpa:      DB "Needs a CP/M with a TPA above B000h.",13,10,"$"

reloc:
            DISP $A000
reloc_start:
; ---------------------------------------------------------------------
main:       di
            call find_cpm
            jp c,fail_bank
            call ram_check
            jp c,fail_ram
            ei
            ld de,m_load
            ld c,9
            call BDOS
            ld hl,files
.f:         ld a,(hl)
            or a
            jr z,.done
            ld (cur_blk),a
            inc hl
            ld (cur_name),hl
            push hl
            call load_file
            pop hl
            jp c,fail_file
            ld de,11
            add hl,de
            jr .f
.done:      ld de,m_go
            ld c,9
            call BDOS
            di
            ; final stage runs at F000h in block 0 with no video window
            ld a,(cpm_port)
            or 8
            out (P_MEM),a
            ld hl,final_src
            ld de,$F000
            ld bc,final_end-final_start
            ldir
            jp $F000

files:      INCLUDE "../build/soft_files.inc"
            DB STG_PROG,  "SOFTSCRLBIN"
            DB 0

fail_bank:  ei
            ld de,m_bank
            jr fail
fail_ram:   ei
            ld de,m_ram
            jr fail
fail_file:  ld de,m_file
fail:       ld c,9
            call BDOS
            rst 0
m_load:     DB "Loading$"
m_go:       DB 13,10,"$"
m_bank:     DB 13,10,"Cannot find the CP/M memory bank.",13,10,"$"
m_ram:      DB 13,10,"STARHIVE needs a Microbee Premium Plus with 1MB RAM.",13,10,"$"
m_file:     DB 13,10,"A game file is missing from this disk.",13,10,"$"

; A = block -> A = port 50h value: ROMs off, no video window
blk_port:   push bc
            ld b,a
            and 3
            xor 2
            ld c,a
            ld a,b
            and $1C
            rlca
            rlca
            rlca
            or c
            or $0C
            pop bc
            ret

; ---------------------------------------------------------------------
; Which block is CP/M's lower 32K? The loader's own bytes at 0700h are
; looked for in every block. Also: where is CP/M's video window?
; ---------------------------------------------------------------------
find_cpm:   in a,(P_LV)
            ld (lv_save),a
            ld hl,$8000
            call vid_probe
            or a
            ld a,$10
            jr nz,.v
            ld hl,$F000
            call vid_probe
            or a
            ld a,$00
            jr nz,.v
            ld a,$08
.v:         ld (vid_bits),a
            ld c,0
.scan:      ld a,c
            call blk_port
            out (P_MEM),a
            ld hl,$0700
            ld de,sig_copy
            ld b,16
.cmp:       ld a,(de)
            cp (hl)
            jr nz,.next
            inc hl
            inc de
            djnz .cmp
            ; found: CP/M's port value = its block | its video window
            ld a,c
            call blk_port
            and $F7
            ld b,a
            ld a,(vid_bits)
            or b
            ld (cpm_port),a
            out (P_MEM),a
            ld a,c
            cp BLK_STAGES
            jr c,.ok                        ; 0..7: fine (filled last)
            cp N_BLOCKS
            jr c,.bad                       ; 8..27: ours
.ok:        or a
            ret
.bad:       scf
            ret
.next:      inc c
            ld a,c
            cp 32
            jr nz,.scan
            scf
            ret

; HL = address: is it video RAM (attribute vs screen RAM differ)?
vid_probe:  ld a,$90
            out (P_LV),a
            ld a,(hl)
            ld (pb_save),a
            ld a,$AA
            ld (hl),a
            ld a,$80
            out (P_LV),a
            ld b,(hl)
            ld a,$90
            out (P_LV),a
            ld a,$55
            ld (hl),a
            ld a,$80
            out (P_LV),a
            ld a,(hl)
            cp b
            ld a,0
            jr nz,.n
            inc a
.n:         ld (pb_res),a
            ld a,$90
            out (P_LV),a
            ld a,(pb_save)
            ld (hl),a
            ld a,(lv_save)
            out (P_LV),a
            ld a,(pb_res)
            ret

; ---------------------------------------------------------------------
; Do blocks 0..29 all exist, apart from each other? (1MB Premium Plus)
; Writes a test byte at offset 1F00h of each, then reads them all back.
; ---------------------------------------------------------------------
ram_check:  ld c,0
.w:         ld a,c
            call blk_port
            out (P_MEM),a
            ld a,($1F00)
            ld hl,saved
            ld e,c
            ld d,0
            add hl,de
            ld (hl),a
            ld a,c
            xor $A5
            ld ($1F00),a
            inc c
            ld a,c
            cp N_BLOCKS
            jr nz,.w
            ld c,0
            ld b,0
.r:         ld a,c
            call blk_port
            out (P_MEM),a
            ld a,c
            xor $A5
            ld hl,$1F00
            cp (hl)
            jr z,.ok
            inc b
.ok:        inc c
            ld a,c
            cp N_BLOCKS
            jr nz,.r
            ld c,N_BLOCKS-1
.rs:        ld a,c
            call blk_port
            out (P_MEM),a
            ld hl,saved
            ld e,c
            ld d,0
            add hl,de
            ld a,(hl)
            ld ($1F00),a
            dec c
            jp p,.rs
            ld a,(cpm_port)
            out (P_MEM),a
            ld a,b
            or a
            ret z
            scf
            ret

; ---------------------------------------------------------------------
; Load the file named at (cur_name) into block (cur_blk) from 0000h.
; ---------------------------------------------------------------------
load_file:  ld hl,fcb
            ld (hl),0
            inc hl
            ex de,hl
            ld hl,(cur_name)
            ld bc,11
            ldir
            ld hl,fcb+12
            ld b,24
.z:         ld (hl),0
            inc hl
            djnz .z
            ld de,fcb
            ld c,15
            call BDOS
            inc a
            scf
            ret z
            ld hl,0
            ld (dest),hl
.rec:       ld de,DMA
            ld c,26
            call BDOS
            ld de,fcb
            ld c,20
            call BDOS
            or a
            jr nz,.eof
            di
            ld a,(cur_blk)
            call blk_port
            out (P_MEM),a
            ld hl,DMA
            ld de,(dest)
            ld bc,128
            ldir
            ld (dest),de
            ld a,(cpm_port)
            out (P_MEM),a
            ei
            ld a,(dest)
            or a
            jr nz,.rec
            ld a,(dest+1)
            and $0F
            jr nz,.rec
            ld e,'.'
            ld c,2
            call BDOS   ; a dot per 4K
            jr .rec
.eof:       or a
            ret

cur_blk:    DB 0
cur_name:   DW 0
dest:       DW 0
cpm_port:   DB 0
vid_bits:   DB 0
lv_save:    DB 0
pb_save:    DB 0
pb_res:     DB 0
sig_copy:   DS 16
saved:      DS 32
fcb:        DS 36

reloc_end:
            ASSERT reloc_end <= DMA
            ENT

; ---------------------------------------------------------------------
; Final stage: copied to F000h, runs with CP/M gone.
; ---------------------------------------------------------------------
final_src:
            DISP $F000
final_start:
            ld sp,$FFF0
            ; program: staging block -> 8000h of block 0
            ld a,STG_PROG
            call blk_port_f
            out (P_MEM),a
            ld hl,0
            ld de,$8000
            ld bc,PROG_LEN
            ldir
            ; staged banks -> their home blocks
            ld hl,moves
.mv:        ld a,(hl)
            or a
            jr z,.go
            ld (from),a
            inc hl
            ld a,(hl)
            ld (to),a
            inc hl
            push hl
            ld hl,0
.lp:        push hl
            ld a,(from)
            call blk_port_f
            out (P_MEM),a
            ld de,$F800
            ld bc,256
            ldir
            ld a,(to)
            call blk_port_f
            out (P_MEM),a
            pop de
            push hl
            ld hl,$F800
            ld bc,256
            ldir
            pop hl
            ld a,h
            cp $80
            jr nz,.lp
            pop hl
            jr .mv
.go:        ; lower window = WORK block, still no video window (this code
            ; is at F000h, where the video RAM appears): the game's start-up
            ; switches the video window on
            ld a,BLK_WORK
            call blk_port_f
            out (P_MEM),a
            jp $8000
moves:      DB 0
from:       DB 0
to:         DB 0
blk_port_f: ld b,a
            and 3
            xor 2
            ld c,a
            ld a,b
            and $1C
            rlca
            rlca
            rlca
            or c
            or $0C
            ret
final_end:
            ASSERT final_end <= $F800
            ENT

            ASSERT $ <= $0700
            ORG $0700
sig:        DB "STARHIVE-LOADSIG"               ; CP/M bank signature
            DB $1A

            SAVEBIN "../build/SOFTSCRL.COM",$0100,$0611
