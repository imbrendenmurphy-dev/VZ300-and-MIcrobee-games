; =====================================================================
; LANTERN.COM - CP/M loader for THE LANTERN DEEP (Microbee Premium Plus)
;
; Runs under the Premium's own CP/M. Loads the asset banks straight into
; the expanded RAM blocks (through the lower 32K window, one 128-byte
; record at a time while CP/M stays alive), loads the program halves into
; two staging blocks, then takes over the machine: copies the program to
; its final home (lower window = block 1, upper 32K = block 0) and starts
; it at 0600h.
;
; Bank handling follows the method of the earlier Premium conversions:
; CP/M's own lower block is found by a signature scan and its video
; window by a probe, so port 50h can always be restored for BDOS calls.
; =====================================================================
            DEVICE NOSLOT64K
BDOS        EQU $0005
P_MEM       EQU $50
P_LV        EQU $1C

; blocks used (must match src/layout.inc)
BLK_HOME    EQU 1
BLK_GFX     EQU 8
BLK_WORLD   EQU 9
BLK_TITLE   EQU 10
BLK_AUDIO   EQU 11
BLK_WORLD2  EQU 12
BLK_REGION  EQU 16
N_BLOCKS    EQU 30          ; blocks the game uses (0..29)
BLK_STAGE_LO EQU 14
BLK_STAGE_HI EQU 15

DMA         EQU $A800       ; record buffer (upper TPA)
LO_LEN      EQU $3400       ; program lower part 0000-33FF
HI_LEN      EQU $1A00       ; program upper part 8000-99FF

            ORG $0100
start:      ld sp,$A7F0
            ld de,m_title : ld c,9 : call BDOS
            ld a,(BDOS+2) : cp $B0          ; TPA must reach past B000h
            jr nc,.tpa
            ld de,m_tpa : ld c,9 : jp BDOS
.tpa:       ld hl,reloc : ld de,$A000 : ld bc,reloc_end-reloc_start : ldir
            ld hl,sig : ld de,sig_copy : ld bc,16 : ldir
            jp main

m_title:    DB 13,10,"THE LANTERN DEEP",13,10
            DB "Vibed by BPM ",'-'," 2026",13,10,"$"
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
            ld de,m_load : ld c,9 : call BDOS
            ld hl,files
.f:         ld a,(hl) : or a : jr z,.done
            ld (cur_blk),a
            inc hl
            ld (cur_name),hl
            push hl
            call load_file
            pop hl
            jp c,fail_file
            ld de,11 : add hl,de
            jr .f
.done:      ld de,m_go : ld c,9 : call BDOS
            di
            ; final stage runs at F000h in block 0 with no video window
            ld a,(cpm_port) : or 8 : out (P_MEM),a
            ld hl,final_src : ld de,$F000 : ld bc,final_end-final_start : ldir
            jp $F000

files:      DB BLK_GFX,   "GFX     BNK"
            DB BLK_WORLD, "WORLD   BNK"
            DB BLK_TITLE, "TITLE   BNK"
            DB BLK_AUDIO, "AUDIO   BNK"
            DB BLK_WORLD2, "WORLD2  BNK"
            DB 26, "AUDIO2  BNK"
            DB 27, "AUDIO3  BNK"
            DB 28, "AUDIO4  BNK"
            DB 29, "AUDIO5  BNK"
            DB BLK_REGION+0, "REGION0 BNK"
            DB BLK_REGION+1, "ROOMS0  BNK"
            DB BLK_REGION+2, "REGION1 BNK"
            DB BLK_REGION+3, "ROOMS1  BNK"
            DB BLK_REGION+4, "REGION2 BNK"
            DB BLK_REGION+5, "ROOMS2  BNK"
            DB BLK_REGION+6, "REGION3 BNK"
            DB BLK_REGION+7, "ROOMS3  BNK"
            DB BLK_REGION+8, "REGION4 BNK"
            DB BLK_REGION+9, "ROOMS4  BNK"
            DB BLK_STAGE_LO, "LANTERN LO "
            DB BLK_STAGE_HI, "LANTERN HI "
            DB 0

fail_bank:  ei
            ld de,m_bank : jr fail
fail_ram:   ei
            ld de,m_ram : jr fail
fail_file:  ld de,m_file
fail:       ld c,9 : call BDOS
            rst 0
m_load:     DB "Loading$"
m_go:       DB 13,10,"$"
m_bank:     DB 13,10,"Cannot find the CP/M memory bank.",13,10,"$"
m_ram:      DB 13,10,"The Lantern Deep needs a Microbee Premium Plus with 1MB RAM.",13,10,"$"
m_file:     DB 13,10,"A game file is missing from this disk.",13,10,"$"

; A = block -> A = port 50h value: ROMs off, no video window
blk_port:   push bc
            ld b,a
            and 3 : xor 2 : ld c,a
            ld a,b : and $1C : rlca : rlca : rlca
            or c : or $0C
            pop bc
            ret

; ---------------------------------------------------------------------
; Which block is CP/M's lower 32K? The loader's own bytes at 0700h are
; looked for in every block. Also: where is CP/M's video window?
; ---------------------------------------------------------------------
find_cpm:   in a,(P_LV) : ld (lv_save),a
            ld hl,$8000 : call vid_probe
            or a : ld a,$10 : jr nz,.v
            ld hl,$F000 : call vid_probe
            or a : ld a,$00 : jr nz,.v
            ld a,$08
.v:         ld (vid_bits),a
            ld c,0
.scan:      ld a,c : call blk_port : out (P_MEM),a
            ld hl,$0700 : ld de,sig_copy : ld b,16
.cmp:       ld a,(de) : cp (hl) : jr nz,.next
            inc hl : inc de : djnz .cmp
            ; found: CP/M's port value = its block | its video window
            ld a,c : call blk_port : and $F7
            ld b,a : ld a,(vid_bits) : or b
            ld (cpm_port),a : out (P_MEM),a
            ld a,c
            cp BLK_HOME : jr z,.bad
            cp BLK_GFX : jr nc,.bad2
            or a                            ; not block 0/1, not >= 8
            ret nz
.bad:       scf
            ret
.bad2:      cp N_BLOCKS : ret c             ; 8..29 are ours: refuse
            or a
            ret
.next:      inc c
            ld a,c : cp 32 : jr nz,.scan
            scf
            ret

; HL = address: is it video RAM (attribute vs screen RAM differ)?
vid_probe:  ld a,$90 : out (P_LV),a
            ld a,(hl) : ld (pb_save),a
            ld a,$AA : ld (hl),a
            ld a,$80 : out (P_LV),a
            ld b,(hl)
            ld a,$90 : out (P_LV),a
            ld a,$55 : ld (hl),a
            ld a,$80 : out (P_LV),a
            ld a,(hl) : cp b
            ld a,0 : jr nz,.n
            inc a
.n:         ld (pb_res),a
            ld a,$90 : out (P_LV),a
            ld a,(pb_save) : ld (hl),a
            ld a,(lv_save) : out (P_LV),a
            ld a,(pb_res)
            ret

; ---------------------------------------------------------------------
; Do blocks 0..29 all exist, apart from each other? (1MB Premium Plus)
; Writes a test byte at offset 1F00h of each, then reads them all back.
; ---------------------------------------------------------------------
ram_check:  ld c,0
.w:         ld a,c : call blk_port : out (P_MEM),a
            ld a,($1F00) : ld hl,saved : ld e,c : ld d,0 : add hl,de : ld (hl),a
            ld a,c : xor $A5 : ld ($1F00),a
            inc c : ld a,c : cp N_BLOCKS : jr nz,.w
            ld c,0 : ld b,0
.r:         ld a,c : call blk_port : out (P_MEM),a
            ld a,c : xor $A5 : ld hl,$1F00 : cp (hl)
            jr z,.ok
            inc b
.ok:        inc c : ld a,c : cp N_BLOCKS : jr nz,.r
            ld c,N_BLOCKS-1
.rs:        ld a,c : call blk_port : out (P_MEM),a
            ld hl,saved : ld e,c : ld d,0 : add hl,de : ld a,(hl) : ld ($1F00),a
            dec c : jp p,.rs
            ld a,(cpm_port) : out (P_MEM),a
            ld a,b : or a : ret z
            scf
            ret

; ---------------------------------------------------------------------
; Load the file named at (cur_name) into block (cur_blk) from 0000h.
; ---------------------------------------------------------------------
load_file:  ld hl,fcb : ld (hl),0 : inc hl
            ex de,hl
            ld hl,(cur_name) : ld bc,11 : ldir
            ld hl,fcb+12 : ld b,24
.z:         ld (hl),0 : inc hl : djnz .z
            ld de,fcb : ld c,15 : call BDOS
            inc a : scf : ret z
            ld hl,0 : ld (dest),hl
.rec:       ld de,DMA : ld c,26 : call BDOS
            ld de,fcb : ld c,20 : call BDOS
            or a : jr nz,.eof
            di
            ld a,(cur_blk) : call blk_port : out (P_MEM),a
            ld hl,DMA : ld de,(dest) : ld bc,128 : ldir
            ld (dest),de
            ld a,(cpm_port) : out (P_MEM),a
            ei
            ld a,(dest) : or a : jr nz,.rec
            ld a,(dest+1) : and $0F : jr nz,.rec
            ld e,'.' : ld c,2 : call BDOS   ; a dot per 4K
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
            ENT

; ---------------------------------------------------------------------
; Final stage: copied to F000h, runs with CP/M gone.
; ---------------------------------------------------------------------
final_src:
            DISP $F000
final_start:
            ld sp,$FFF0
            ; upper part: staging block -> 8000h
            ld a,BLK_STAGE_HI : call blk_port_f : out (P_MEM),a
            ld hl,0 : ld de,$8000 : ld bc,HI_LEN : ldir
            ; lower part: staging block -> block 1, via a bounce buffer
            ld hl,0
.lp:        push hl
            ld a,BLK_STAGE_LO : call blk_port_f : out (P_MEM),a
            ld de,$F800 : ld bc,256 : ldir
            ld a,BLK_HOME : call blk_port_f : out (P_MEM),a
            pop de
            push hl
            ld hl,$F800 : ld bc,256 : ldir
            pop hl
            ld a,h : cp LO_LEN>>8 : jr nz,.lp
            ; lower window = block 1, no video window; start the game
            ld a,$0F : out (P_MEM),a
            jp $0600
blk_port_f: ld b,a
            and 3 : xor 2 : ld c,a
            ld a,b : and $1C : rlca : rlca : rlca
            or c : or $0C
            ret
final_end:
            ENT

            ORG $0700
sig:        DB "LANTERN-DEEP-SIG"               ; CP/M bank signature
            DB $1A

            SAVEBIN "../build/LANTERN.COM",$0100,$0611
