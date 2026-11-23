; =====================================================================
;  OCTOCHROME                                         VIBED BY BPM 2026
;  All 8 colours at once in the VZ300's 128x64 mode: the colour set (CSS)
;  is switched in the middle of every scanline. Real FLD (6847 line holds)
;  bounces a scroller. Three-voice music mixed into the raster kernel.
;  Standard VZ300 (16K), no expansion. Keys , and . set the fine phase.
;
;  Frame plan (312 lines of 228 T):
;   line 0     field sync: IM2 interrupt wakes the HALT (0-3 T jitter)
;   0-54       27 kernel units (music only, nothing shown)
;   ~55-58     fine-sync unit: samples the end of field sync, trims the
;              jitter to 1 T
;   58-117     30 units of top border
;   118-273    78 picture units: logo with rolling colour-set bands, FLD
;              hold, the split scroller, FLD hold, split colour bars
;   274-311    the bottom of the picture shows the title while the CPU
;              does the frame's work (music tick, bounce, splits, scroll),
;              then EI / HALT.
;  A kernel unit is two scanlines (456 T), entered by RET from a table on
;  the stack: each unit pops the next unit's latch bases, then RETs on.
; =====================================================================
LATCH       equ $6800
FSREAD      equ $6FFF                   ; bit 7 = FS (0 = in field sync)
KEYROW      equ $68EF                   ; bit 4 SPACE, bit 3 ',', bit 2 '.'
VRAM        equ $7000
IM2TAB      equ $B500                   ; 257 bytes of $B6
IM2VEC      equ $B6B6                   ; JP irq
STACK       equ $B500

N_TOP       equ 27                      ; units before the fine sync
N_BORDER    equ 30                      ; units after it, before the picture
N_LOGO      equ 24
N_HOLD      equ 17                      ; hold1 + hold2 units
N_SCR       equ 14
N_BAR       equ 10                      ; each band
PIC_FIRST   equ N_TOP+1+N_BORDER        ; unit index of the first picture unit
MID_FIRST   equ PIC_FIRST+N_LOGO        ; first hold unit
N_UNITS     equ MID_FIRST+N_HOLD+N_SCR+2*N_BAR
D_PLAIN     equ $0909                   ; data: E = W1 base, D = W2 base (bit 0 = speaker, bit 3 = AG, bit 4 = CSS)
D_HOLD      equ $0109                   ; W2 base with AG off = the flick
D_SPLIT     equ $1909                   ; CSS0 left, CSS1 right
D_SPLITR    equ $0919                   ; CSS1 left, CSS0 right
X_DEFAULT   equ 14                      ; fine phase

            org $8000
start:
            di
            ld sp,STACK
            ld hl,vars_start
            ld de,vars_start+1
            ld bc,vars_end-vars_start-1
            ld (hl),0
            ldir
            ld hl,screen_img
            ld de,VRAM
            ld bc,2048
            ldir
            ld a,$09
            ld (LATCH),a
            ld hl,IM2TAB                ; IM2: any vector byte -> $B6B6
            ld de,IM2TAB+1
            ld bc,256
            ld (hl),HIGH(IM2VEC)
            ldir
            ld a,$C3
            ld (IM2VEC),a
            ld hl,irq
            ld (IM2VEC+1),hl
            ld a,HIGH(IM2TAB)
            ld i,a
            im 2
            call m_start
            ld hl,1
            ld (m_ph3),hl
            ld a,X_DEFAULT
            ld (phase),a
            call set_phase
            ld a,8                      ; the regions are built with W2 in slot 0
            ld hl,u_scr_ra
            ld de,sl_scr
            call set_split
            ld a,8
            ld hl,u_bara_ra
            ld de,sl_bara
            call set_split
            ld a,8
            ld hl,u_barb_ra
            ld de,sl_barb
            call set_split
            call build_ktab
            ld hl,scr_text
            ld (sc_ptr),hl
            call sc_glyph
            ld a,9
            ld (fld_u),a
            call build_mid
            call m_tick
            ei
            halt

; ---------------------------------------------------------------------
; the interrupt: 10 (JP at the vector) + 111 T, then the first unit
irq:
            ld sp,ktab                  ; 10
            ld ix,(m_ph1)               ; 20
            ld iy,(m_ph2)               ; 20
            exx                         ; 4
            ld hl,(m_ph3)               ; 16
            ld e,$1D                    ; 7   noise taps
            exx                         ; 4
            ld hl,LATCH                 ; 10
            ld bc,$0909                 ; 10
            ret                         ; 10

; the last unit returns here, at picture line 156
kend:
            ld a,$19                    ; the bottom: colour set 1, set in the blanking
            ld (hl),a
            ld (m_ph1),ix
            ld (m_ph2),iy
            exx
            ld (m_ph3),hl
            exx
            ld sp,STACK
            call work
            ei
            halt                        ; -> irq at the next field sync

; ---------------------------------------------------------------------
; the frame's work (about 8K T before the next field sync)
work:
            ld hl,(frame)
            inc hl
            ld (frame),hl
            call m_tick
; FLD: hold1 = 9 + 8 sin (1..16 units), hold2 = 17 - hold1
            ld a,(frame)
            ld b,a
            add a,a
            add a,b
            ld l,a
            ld h,HIGH(sintab)
            ld a,(hl)
            sra a
            sra a
            sra a
            sra a
            add a,9
            ld (fld_u),a
            call build_mid
; the three splits
            ld a,(frame)
            add a,a
            ld l,a
            ld h,HIGH(sintab)
            ld a,(hl)
            sra a
            sra a
            sra a
            sra a
            add a,8                     ; 0..15
            ld hl,u_scr_ra
            ld de,sl_scr
            call set_split
            ld a,(frame)
            ld b,a
            add a,a
            add a,b
            add a,64
            ld l,a
            ld h,HIGH(sintab)
            ld a,(hl)
            sra a
            sra a
            sra a
            sra a
            push af
            add a,8
            ld hl,u_bara_ra
            ld de,sl_bara
            call set_split
            pop af
            neg
            add a,8
            ld hl,u_barb_ra
            ld de,sl_barb
            call set_split
            call keys
            ld a,(frame)
            rra
            jp nc,scroll                ; even fields: move the scroller
            jp logo_bands               ; odd fields: roll the logo's colour bands

m_tick:
            ld ix,m_chan1
            call m_ch
            ld ix,m_chan2
            call m_ch
            ld ix,m_chan3
            call m_ch
            jp m_patch
m_mute:     ret

; set_split: HL = a copy's region A, DE = its slot variable, A = new slot (0..16).
; Region B is RB_OFF bytes after region A in every copy.
RB_OFF      equ u_plain_rb-u_plain_ra
set_split:
            ld c,a
            ld a,(de)
            cp c
            ret z
            push bc
            push hl
            ld c,a                      ; old slot: back to NOP in both lines
            ld b,0
            add hl,bc
            ld (hl),0
            ld bc,RB_OFF
            add hl,bc
            ld (hl),0
            pop hl
            pop bc
            ld a,c
            ld (de),a
            ld b,0
            add hl,bc
            ld (hl),$71                 ; LD (HL),C: the mid-line latch write
            ld bc,RB_OFF
            add hl,bc
            ld (hl),$71
            ret

; ---------------------------------------------------------------------
; the stack table for the kernel: [addr of unit 0] then [data][addr] per unit
build_ktab:
            ld hl,ktab
            ld de,u_plain
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld b,N_TOP-1
            ld de,u_plain
            ld ix,D_PLAIN
            call .put
            ld de,fsu
            ld b,1
            call .put
            ld de,u_plain
            ld b,N_BORDER
            call .put
            ld b,N_LOGO
            call .put
            ld b,N_HOLD+N_SCR           ; rebuilt every field by build_mid
            call .put
            ld de,u_bara
            ld ix,D_SPLIT
            ld b,N_BAR
            call .put
            ld de,u_barb
            ld ix,D_SPLITR
            ld b,N_BAR
            call .put
            ld de,kend
            ld ix,0
            ld b,1
.put:       push bc
            push ix
            pop bc
            ld (hl),c
            inc hl
            ld (hl),b
            inc hl
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            pop bc
            djnz .put
            ret

; build_mid: hold1 (fld_u units), scroller (14), hold2 (17 - fld_u), written by PUSH from the end
ENTRY_MID   equ ktab+2+(MID_FIRST-1)*4
ENTRY_BARS  equ ENTRY_MID+(N_HOLD+N_SCR)*4
build_mid:
            ld (sp_save),sp
            ld sp,ENTRY_BARS
            ld a,(fld_u)
            ld c,a
            ld a,N_HOLD
            sub c
            ld b,a
            ld de,u_plain
            ld hl,D_HOLD
.h2:        push de
            push hl
            djnz .h2
            ld b,N_SCR
            ld de,u_scr
            ld hl,D_SPLIT
.s:         push de
            push hl
            djnz .s
            ld b,c
            ld de,u_plain
            ld hl,D_HOLD
.h1:        push de
            push hl
            djnz .h1
            ld sp,(sp_save)
            ret

; logo_bands: the logo's 24 units alternate colour sets in bands of 8 that roll down
ENTRY_LOGO  equ ktab+2+(PIC_FIRST-1)*4
logo_bands:
            ld hl,ENTRY_LOGO
            ld a,(frame)
            rra
            rra
            cpl
            ld c,a
            ld b,N_LOGO
.l:         ld a,c
            and 8
            ld a,$09
            jr z,.c
            ld a,$19
.c:         ld (hl),a
            inc hl
            ld (hl),a
            inc hl
            inc hl
            inc hl
            inc c
            djnz .l
            ret

; ---------------------------------------------------------------------
; the scroller: rows 17-24, one byte (4 pixels) left every other field
SROW        equ VRAM+17*32
scroll:
            ld hl,SROW+1
            ld de,SROW
            ld ix,(sc_gp)
            ld a,8
.r:         ld (sc_cnt),a
            REPT 31
            ldi
            ENDR
            ld a,(ix+0)
            ld (de),a
            inc ix
            inc hl
            inc de
            ld a,(sc_cnt)
            dec a
            jr nz,.r
            ld a,(sc_colx)              ; the next byte-column of the letter
            inc a
            and 3
            ld (sc_colx),a
            jr nz,sc_glyph
            ld hl,(sc_ptr)
            inc hl
            ld a,(hl)
            cp $FF
            jr nz,.n
            ld hl,scr_text
.n:         ld (sc_ptr),hl
sc_glyph:                               ; sc_gp = font2 + char*32 + column*8
            ld hl,(sc_ptr)
            ld l,(hl)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(sc_colx)
            add a,a
            add a,a
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld de,font2
            add hl,de
            ld (sc_gp),hl
            ret

; ---------------------------------------------------------------------
; keys , and . : fine phase (where the fine-sync samples). Shown for a few seconds.
keys:
            ld a,(KEYROW)
            cpl
            and $0C
            ld hl,key_prev
            ld b,(hl)
            ld (hl),a
            ld c,a
            ld a,b
            cpl
            and c                       ; newly pressed
            ld b,a
            ld a,(phase)
            bit 3,b
            jr z,.n1
            dec a
.n1:        bit 2,b
            jr z,.n2
            inc a
.n2:        and 15
            ld hl,phase
            cp (hl)
            jr z,.same
            ld (hl),a
            call set_phase
            ld a,150
            ld (show_t),a
            jp show_phase
.same:      ld a,(show_t)
            or a
            ret z
            dec a
            ld (show_t),a
            ret nz
            ld hl,VRAM+43*32+28         ; time's up: clear the number
            ld b,8
.cl:        ld (hl),0
            inc hl
            ld (hl),0
            inc hl
            ld (hl),0
            inc hl
            ld (hl),0
            ld de,29
            add hl,de
            djnz .cl
            ret

set_phase:                              ; fs_prep = fs_pre_<x>, fs_postp = fs_post_<15-x>
            ld a,(phase)
            add a,a
            ld e,a
            ld d,0
            ld hl,pre_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld (fs_prep),hl
            ld a,(phase)
            cpl
            and 15
            add a,a
            ld e,a
            ld hl,post_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld (fs_postp),hl
            ret

show_phase:                             ; two digits at the bottom right, rows 43-50
            ld a,(phase)
            ld b,0
.t:         cp 10
            jr c,.u
            sub 10
            inc b
            jr .t
.u:         push af
            ld a,b
            ld de,VRAM+43*32+28
            call digit
            pop af
            ld de,VRAM+43*32+30
digit:                                  ; A = 0-9, DE = screen: 2 bytes x 8 rows, background colour 0
            ld l,a
            ld h,0
            ld bc,digits1
            add hl,bc
            ld l,(hl)
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld bc,font1
            add hl,bc
            ld b,8
.r:         push bc
            ld a,(hl)
            ld (de),a
            push hl
            ld bc,8
            add hl,bc
            ld a,(hl)
            inc de
            ld (de),a
            dec de
            pop hl
            inc hl
            ld a,e
            add a,32
            ld e,a
            jr nc,.nc
            inc d
.nc:        pop bc
            djnz .r
            ret

pre_tab:    dw fs_pre_0,fs_pre_1,fs_pre_2,fs_pre_3,fs_pre_4,fs_pre_5,fs_pre_6,fs_pre_7
            dw fs_pre_8,fs_pre_9,fs_pre_10,fs_pre_11,fs_pre_12,fs_pre_13,fs_pre_14,fs_pre_15
post_tab:   dw fs_post_0,fs_post_1,fs_post_2,fs_post_3,fs_post_4,fs_post_5,fs_post_6,fs_post_7
            dw fs_post_8,fs_post_9,fs_post_10,fs_post_11,fs_post_12,fs_post_13,fs_post_14,fs_post_15

            include "msys.asm"
            include "gen/kernel.inc"
            ALIGN 256
            include "gen/data.inc"
            include "gen/song.inc"
code_end:

; ---------------------------------------------------------------------
            NOEMIT
vars_start:
m_chan1:    ds CH_SIZE
m_chan2:    ds CH_SIZE
m_chan3:    ds CH_SIZE
m_ph1:      ds 2
m_ph2:      ds 2
m_ph3:      ds 2
frame:      ds 2
sp_save:    ds 2
fld_u:      ds 1
sl_scr:     ds 1
sl_bara:    ds 1
sl_barb:    ds 1
phase:      ds 1
fs_prep:    ds 2
fs_postp:   ds 2
key_prev:   ds 1
show_t:     ds 1
sc_ptr:     ds 2
sc_gp:      ds 2
sc_colx:    ds 1
sc_cnt:     ds 1
ktab:       ds 2+N_UNITS*4
vars_end:
            EMIT
