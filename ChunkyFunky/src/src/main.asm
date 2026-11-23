; =====================================================================
;  CHUNKY FUNKY                                       VIBED BY BPM 2026
;  A demo for the Dick Smith VZ300 (standard 16K, no expansion needed).
;  Seven parts, mode 0 semigraphics and mode 1 128x64x4, three-voice
;  beeper funk. Parts change on the tune's bar lines.
; =====================================================================
LATCH       equ $6800
FSREAD      equ $6FFF          ; bit 7 = FS (0 = in field sync)
KEYSPACE    equ $68EF          ; keyboard row with SPACE in bit 4
VRAM        equ $7000
WORK        equ $7800          ; 2K scratch for the running part (BASIC's area: we never return)
STACK_TOP   equ $B800

            org $8000
start:
            di
            ld sp,STACK_TOP
            ld hl,vars_start            ; clear the variables
            ld de,vars_start+1
            ld bc,vars_end-vars_start-1
            ld (hl),0
            ldir
            ld hl,$ACE1
            ld (seed),hl
            ld a,$80
            call cls0
            xor a
            call set_latch
demo_restart:
            call m_start
            ld hl,parts
            ld (part_ptr),hl
next_part:
            ld hl,(part_ptr)
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld a,d
            or e
            jr z,demo_restart
            ld c,(hl)
            inc hl
            ld b,(hl)
            inc hl
            ld (pf_call+1),bc
            ld c,(hl)
            inc hl
            ld b,(hl)
            inc hl
            ld (part_left),bc
            ld (part_ptr),hl
            ld hl,0
            ld (ptime),hl
            ex de,hl
            call jp_hl                  ; the part's init
part_loop:
            call fe_wait                ; music until field sync starts
            ld hl,(part_left)
            dec hl
            ld (part_left),hl
            ld a,h
            or l
            jr z,next_part
            call key_skip
            jr c,next_part
pf_call:    call 0                      ; the part's frame
            ld hl,(ptime)
            inc hl
            ld (ptime),hl
            jr part_loop
jp_hl:      jp (hl)

; key_skip: C when SPACE has just been pressed
key_skip:
            ld a,(KEYSPACE)
            cpl
            and $10
            ld hl,key_prev
            ld b,(hl)
            ld (hl),a
            or a
            ret z
            ld a,b
            or a
            ret nz
            scf
            ret

; parts: init, frame, length in fields (one bar = 96)
parts:
            dw t_init, t_frame, 8*96
            dw pl_init, pl_frame, 8*96
            dw st_init, st_frame, 8*96
            dw cu_init, cu_frame, 8*96
            dw sc_init, sc_frame, 12*96
            dw tu_init, tu_frame, 8*96
            dw cr_init, cr_frame, 12*96
            dw 0

; ---------------------------------------------------------------------
; helpers
cls0:                                   ; text screen = A
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,511
            ld (hl),a
            ldir
            ret
cls1:                                   ; mode 1 screen = A
            ld hl,VRAM
            jp fill2k

; rnd: A = a pseudo-random byte (xorshift), uses HL
rnd:
            ld hl,(seed)
            ld a,h
            rra
            ld a,l
            rra
            xor h
            ld h,a
            ld a,l
            rra
            ld a,h
            rra
            xor l
            ld l,a
            xor h
            ld h,a
            ld (seed),hl
            ret

; lfsr_next: A = next of an 8-bit maximal sequence (1..255)
lfsr_next:
            ld a,(lfsr)
            srl a
            jr nc,.n
            xor $B8
.n:         ld (lfsr),a
            ret

; print0: HL = 6847 codes ($FF ends), DE = screen address
print0:
            ld a,(hl)
            cp $FF
            ret z
            ld (de),a
            inc hl
            inc de
            jr print0

; typewriter: tw_start HL = text ($FE lo hi = move to an address, $FF = end)
tw_start:
            ld (tw_ptr),hl
            ld a,1
            ld (tw_cnt),a
            ret
tw_step:
            ld hl,(tw_ptr)
            ld a,h
            or a
            ret z
            ld a,(tw_cnt)
            dec a
            ld (tw_cnt),a
            ret nz
            ld a,3
            ld (tw_cnt),a
.again:     ld a,(hl)
            inc hl
            cp $FF
            jr z,.end
            cp $FE
            jr nz,.ch
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (tw_dst),de
            jr .again
.ch:        ld de,(tw_dst)
            ld (de),a
            inc de
            ld (tw_dst),de
            ld (tw_ptr),hl
            ret
.end:       ld hl,0
            ld (tw_ptr),hl
            ret

; mul_ss: HL = A * E (both signed). Uses A, B, D, E.
mul_ss:
            ld d,a
            xor e
            push af                     ; result sign in bit 7
            ld a,d
            or a
            jp p,.p1
            neg
.p1:        ld d,a
            ld a,e
            or a
            jp p,.p2
            neg
.p2:        ld e,a
            ld hl,0
            ld a,d
            ld d,0
            ld b,8
.ml:        add hl,hl
            rla
            jr nc,.s
            add hl,de
.s:         djnz .ml
            pop af
            ret p
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
            ret

; mul7: A = (A * E) >> 7, signed
mul7:
            call mul_ss
            add hl,hl
            ld a,h
            ret

; row1: HL = VRAM + A*32 (mode 1 row address)
row1:
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,h
            add a,HIGH(VRAM)
            ld h,a
            ret

; fill_row: HL = start of a mode 1 row, A = byte. 32 bytes by PUSH.
fill_row:
            ld (sp_save),sp
            ld de,32
            add hl,de
            ld sp,hl
            ld d,a
            ld e,a
            REPT 16
            push de
            ENDR
            ld sp,(sp_save)
            ret
; fill2k: HL = start of 2K, A = byte (by PUSH, ~12K T)
fill2k:
            ld (sp_save),sp
            ld de,2048
            add hl,de
            ld sp,hl
            ld d,a
            ld e,a
            ld b,64
.l:         REPT 16
            push de
            ENDR
            djnz .l
            ld sp,(sp_save)
            ret
fill_end_sp:

; draw_str1: mode 1 text, HL = font indices ($FF ends), DE = screen address.
; Transparent: colour 0 in the font leaves the screen as it is.
draw_str1:
            ld a,(hl)
            cp $FF
            ret z
            push hl
            push de
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld bc,font1
            add hl,bc
            call draw_col1
            pop de
            push de
            inc de
            call draw_col1
            pop de
            inc de
            inc de
            pop hl
            inc hl
            jr draw_str1
draw_col1:                              ; HL = 8 glyph bytes, DE = screen
            ld b,8
.l:         push bc
            ld a,(hl)
            ld c,a
            ld b,HIGH(tmask)
            ld a,(bc)
            ex de,hl
            and (hl)
            or c
            ld (hl),a
            ld bc,32
            add hl,bc
            ex de,hl
            inc hl
            pop bc
            djnz .l
            ret

            include "music.asm"
            include "parts.asm"
            include "../gen/data.inc"
            include "../gen/songs.inc"
code_end:

; ---------------------------------------------------------------------
; variables (not in the file; cleared at start)
            NOEMIT
            ALIGN 256
CX:         ds 256                      ; plasma column terms
vars_start:
m_chan1:    ds CH_SIZE
m_chan2:    ds CH_SIZE
m_chan3:    ds CH_SIZE
m_ph1:      ds 2
m_ph2:      ds 2
m_ph3:      ds 2
fe_latch:   ds 1
seed:       ds 2
lfsr:       ds 1
part_ptr:   ds 2
part_left:  ds 2
ptime:      ds 2
key_prev:   ds 1
sp_save:    ds 2
tw_ptr:     ds 2
tw_dst:     ds 2
tw_cnt:     ds 1
scr_ptr:    ds 2
scr_cnt:    ds 1
            include "partvars.asm"
vars_end:
            EMIT
; (build.py checks that the variables end below $B700)
