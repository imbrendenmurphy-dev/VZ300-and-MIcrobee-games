; =====================================================================
; THE LANTERN DEEP - engine core (lives in the fixed upper block)
; Everything that switches the lower 32K window must live up here.
; =====================================================================

; ---------------------------------------------------------------------
; Hardware set-up: PIO, 6545 (80 x 24, 8 scan lines), blank video
; ---------------------------------------------------------------------
hw_init:
            ld a,MEM_HOME
            out (P_MEM),a
            ; PIO set-up as used by the earlier Premium conversions
            ld a,$4F : out (P_PIOAC),a
            ld a,$07 : out (P_PIOBC),a
            ld a,$CF : out (P_PIOBC),a
            ld a,$BF : out (P_PIOBC),a      ; port B: bit 6 output (speaker)
            ld a,$07 : out (P_PIOBC),a
            xor a : out (P_PIOB),a
            ld a,$CF : out (P_PIOAC),a      ; port A: all inputs (joystick)
            ld a,$FF : out (P_PIOAC),a
            ld a,$07 : out (P_PIOAC),a
            xor a : out (P_ROMLAT),a
            ; 6545
            ld hl,crtc_tab
            ld c,0
.ci:        ld a,c : out (P_CRTCA),a
            ld a,(hl) : out (P_CRTCD),a
            inc hl : inc c
            ld a,c : cp 16 : jr nz,.ci
            ld a,MEM_HOME_V : out (P_MEM),a
            ; colour RAM: black on black first, so nothing flashes
            ld a,COL_ON : out (P_COLCTL),a
            ld hl,COLWIN : ld bc,$0800 : ld e,0 : call fill
            xor a : out (P_COLCTL),a
            ld a,LV_ATTR : out (P_LV),a
            ld hl,VIDEO : ld bc,$0800 : ld e,FONT_BANK : call fill
            ld a,LV_SCREEN : out (P_LV),a
            ld hl,VIDEO : ld bc,$0800 : ld e,$80 : call fill
            ret

; 80 x 24 characters of 8 scan lines; timing values from the boot ROM's
; own 80-column table (R0-R3, R8), rows/sync for 8-line characters
; (39 x 8 = 312 lines, vsync at row 31 centres the 192-line picture).
crtc_tab:   DB $6B,$50,$58,$37,$26,$00,$18,$1F,$48,$07,$20,$07,$00,$00,$00,$00

; HL = start, BC = count, E = value
fill:       ld (hl),e
            inc hl
            dec bc
            ld a,b : or c
            jr nz,fill
            ret

; ---------------------------------------------------------------------
; Banked memory (Premium Plus: 32 x 32K blocks, lower window only)
; port 50h: b7 b6 b5 = block bits 4..2, b1 b0 = block bits 1..0
; (b1 inverted while b2 = ROMs off), b3 = 1 no video window
; ---------------------------------------------------------------------
; A = block -> A = port value (ROMs off, video window on)
bank_port:  push bc
            ld b,a
            and 3 : xor 2 : ld c,a
            ld a,b : and $1C : rlca : rlca : rlca
            or c : or 4
            pop bc
            ret

; A = block, HL = source (0000-7FFF), DE = destination (upper), BC = length
bank_read:  push af
            call bank_port
            out (P_MEM),a
            ldir
            ld a,MEM_HOME_V
            out (P_MEM),a
            pop af
            ret

; A = block, HL = source, DE = destination anywhere (via bounce), BC = length
bank_to_home:
            ld (bth_blk),a
.chunk:     ld a,b : or c : ret z
            push bc
            ld a,b : or a
            jr z,.go                        ; fewer than 256 left: BC as is
            ld bc,256
.go:        ld (bth_n),bc
            push de
            ld de,BOUNCE
            ld a,(bth_blk) : call bank_port : out (P_MEM),a
            ldir
            ld a,MEM_HOME_V : out (P_MEM),a
            pop de
            push hl
            ld hl,BOUNCE
            ld bc,(bth_n)
            ldir
            pop hl
            pop bc
            push hl
            ld h,b : ld l,c
            ld bc,(bth_n)
            or a : sbc hl,bc
            ld b,h : ld c,l
            pop hl
            jr .chunk
bth_blk:    DB 0
bth_n:      DW 0

; A = block holding the 16K PCG library at 0000 (16 banks x 128 glyphs x
; 8 rows). Copied straight from the lower window into PCG RAM.
pcg_load_all:
            ld b,16
; A = block, B = number of PCG banks to fill (from bank 0)
pcg_load_n: ld c,a
            ld a,b : ld (pl_n),a
            ld a,c
            call bank_port
            out (P_MEM),a
            ld hl,0
            ld c,0
.bank:      ld a,c : or LV_SCREEN : out (P_LV),a
            ld de,PCGWIN
            ld b,128
.glyph:     push bc
            ldi : ldi : ldi : ldi : ldi : ldi : ldi : ldi
            xor a
            ld b,8
.z:         ld (de),a : inc de : djnz .z
            pop bc
            djnz .glyph
            inc c
            ld a,(pl_n) : cp c : jr nz,.bank
            ld a,LV_SCREEN : out (P_LV),a
            ld a,MEM_HOME_V : out (P_MEM),a
            ret
pl_n:       DB 16

; Probe how many distinct 32K blocks exist (writes a signature to address
; $7FF0 of each block, block 1 last). Result in mem_blocks.
mem_probe:
            ld b,31
.wr:        ld a,b : call bank_port : out (P_MEM),a
            ld a,b : ld ($7FF0),a : cpl : ld ($7FF1),a
            dec b
            jr nz,.wr
            ld b,2
.rd:        ld a,b : call bank_port : out (P_MEM),a
            ld a,($7FF0) : cp b : jr nz,.done
            ld a,($7FF1) : cpl : cp b : jr nz,.done
            inc b
            ld a,b : cp 32 : jr nz,.rd
.done:      ld a,b : ld (mem_blocks),a
            ld a,MEM_HOME_V : out (P_MEM),a
            ret
mem_blocks: DB 0

; ---------------------------------------------------------------------
; Vertical blanking
; ---------------------------------------------------------------------
; Counts rising edges of the 6545 vertical blanking status (bit 5).
vb_poll:    push af : push hl
            in a,(P_CRTCA) : and $20
            ld hl,vb_last
            cp (hl) : jr z,.o
            ld (hl),a
            or a : jr z,.o
            ld hl,(frames) : inc hl : ld (frames),hl
            call snd_tick                   ; long work: keep the music going
.o:         pop hl : pop af
            ret
vb_last:    DB 0
frames:     DW 0

; Wait for the next vertical blanking edge while the sound engine plays.
wait_frame: call snd_wait
            ld a,$20 : ld (vb_last),a
            ld hl,(frames) : inc hl : ld (frames),hl
            ret

; ---------------------------------------------------------------------
; Output queues. Full entries change glyph+bank+colour; colour entries
; only colour RAM (most lighting changes).
;   FULLQ: DW screen offset, DB chr, DB bank, DB colour
;   COLQ : DW screen offset, DB colour
; ---------------------------------------------------------------------
FULLQ       EQU OUTQ            ; E400-E6FF
FULLQ_END   EQU OUTQ+150*5
COLQ        EQU OUTQ+$300       ; E700-E9FF (256 entries)

q_reset:    ld hl,FULLQ : ld (fq_ptr),hl
            ld hl,COLQ : ld (cq_ptr),hl
            ret
fq_ptr:     DW FULLQ
cq_ptr:     DW COLQ

flush_outq: ; ---- full entries: port switching per entry
            ld hl,(fq_ptr)
            ld de,FULLQ
            or a : sbc hl,de
            jr z,.col
            ld hl,FULLQ
.full:      ld e,(hl) : inc hl
            ld a,(hl) : or $F0 : ld d,a : inc hl     ; DE = F000 | offset
            ld a,LV_SCREEN : out (P_LV),a
            ld a,(hl) : ld (de),a : inc hl          ; character
            ld a,LV_ATTR : out (P_LV),a
            ld a,(hl) : ld (de),a : inc hl          ; PCG bank
            ld a,d : or $08 : ld d,a
            ld a,COL_ON : out (P_COLCTL),a
            ld a,(hl) : ld (de),a : inc hl          ; colour
            xor a : out (P_COLCTL),a
            ld de,(fq_ptr)
            ld a,l : cp e : jr nz,.full
            ld a,h : cp d : jr nz,.full
            ld a,LV_SCREEN : out (P_LV),a
            ld hl,FULLQ : ld (fq_ptr),hl
.col:       ; ---- colour-only entries: one pass
            ld hl,(cq_ptr)
            ld de,COLQ
            or a : sbc hl,de
            ret z
            ld a,COL_ON : out (P_COLCTL),a
            ld hl,COLQ
            ld bc,(cq_ptr)
.c1:        ld e,(hl) : inc hl
            ld a,(hl) : or $F8 : ld d,a : inc hl
            ld a,(hl) : ld (de),a : inc hl
            ld a,l : cp c : jr nz,.c1
            ld a,h : cp b : jr nz,.c1
            xor a : out (P_COLCTL),a
            ld hl,COLQ : ld (cq_ptr),hl
            ret

; ---------------------------------------------------------------------
; Cell renderer.  HL = FLAGS cell pointer.
; Appearance = f(tile, light level, tint, seen, entity). The light "key"
; (tint*8+level, or a dark/remembered code) is kept per cell in SHKEY:
; a cell whose key is unchanged is skipped at once. Otherwise the glyph
; and colour come from the tile's light ramp and are compared with the
; shadow arrays; differences go to the output queues.
; Register use: D = page of the cell in FLAGS, L/B = its low byte.
; ---------------------------------------------------------------------
KEY_BLACK   EQU $7E
KEY_ENTITY  EQU $7F

render_cell:
            ld a,(hl)
            bit F_EDGE,a : ret nz
            ld b,a                          ; B = flags
            ld d,h
            ld a,h : add a,D_LIGHT : ld h,a
            ld a,(hl) : and 7 : ld c,a      ; C = torch level
            cp 4 : jr nc,.nf                ; flame flicker dims the fringe
            ld a,(flick_on) : or a : jr z,.nf
            ld a,c : srl a : neg : add a,c : ld c,a
.nf:        ld a,d : add a,D_STAT : ld h,a
            ld a,(hl)                       ; static: level | tint<<3 | zone<<5
            bit F_REVEAL,b : jr nz,.rv
            and $38                         ; this zone's lights not shown
.rv:        ld e,a : and 7
            cp c : jr z,.dyn : jr c,.dyn
            ld c,a                          ; static light is brighter
            ld a,e : and $38
            jr .lt
.dyn:       xor a                           ; torch light is warm
.lt:        add a,c : add a,a : ld e,a      ; E = key*2
            ld a,c : or a : jr z,.dark
            ld h,d : set F_SEEN,(hl)
            ld a,d : add a,D_ENT : ld h,a
            ld a,(hl) : or a : jr nz,.entity
            ld a,e
            jr .key
.dark:      ld e,0
            bit F_SEEN,b : ld a,0 : jr nz,.key   ; remembered: key 0
            ld a,KEY_BLACK
.key:       ld c,a
            ld a,d : add a,D_SHKEY : ld h,a
            ld a,(hl) : cp c : ret z        ; nothing changed
            ld (hl),c
            ld (rk_old),a                   ; >= $7E: blank/entity/forced before
            ld a,c : cp KEY_BLACK : jr z,.blank
            ld a,d : add a,D_TILE : ld h,a
            ld c,(hl)                       ; C = tile
            bit F_CYCLE,b
            ld b,l                          ; B = cell low byte from here on
            jr nz,.cyc
            ld l,c : ld h,TD_RL>>8
            ld a,(hl) : add a,e : ld e,a
            inc h : ld h,(hl) : ld l,e      ; HL = ramp entry
.vc:        ld a,(hl) : inc l : ld e,(hl)   ; A = variant, E = colour
            add a,TD_CHR0>>8 : ld h,a : ld l,c
            ld c,(hl)                       ; C = character
            ld h,TD_BANK>>8 : ld a,(hl)     ; A = PCG bank
            jr emit
.cyc:       ld a,e : or a : jr z,.cy0       ; remembered: plain ramp
            ld a,b : and 7 : ld h,a
            ld a,(cyc_phase) : add a,h : and 7 : add a,a
            add a,CYCTAB&$FF : ld l,a : ld h,CYCTAB>>8
            jr .vc
.cy0:       ld l,c : ld h,TD_RL>>8
            ld a,(hl) : ld e,a
            inc h : ld h,(hl) : ld l,e
            jr .vc
.blank:     ld b,l
            ld c,$80 : ld a,FONT_BANK : ld e,0
            jr emit
.entity:    ld b,l                          ; A = entity number
            ld e,c                          ; E = the light on this cell
            add a,a : add a,a : add a,a : add a,a
            add a,EN_GLYPH : ld l,a : ld h,ENTS>>8
            ld a,(mono_on) : or a : jr z,.en
            ld a,e : cp MONO_LIT : jr c,.en ; monochrome, in the gloom: plain
            ld a,(hl) : or $40 : jr .eg     ; in the light: the inverted sprite
.en:        ld a,(hl)
.eg:        ld c,a : inc l : ld a,(hl) : inc l : ld e,(hl)
            ld (em_bank),a
            ld l,b : ld a,d : add a,D_SHKEY : ld h,a
            ld (hl),KEY_ENTITY
            ld a,$FF : ld (rk_old),a        ; always a full update
            ld a,(em_bank)
            ; fall into emit

; D/B = cell, C = character, A = bank, E = colour: compare with the
; shadow arrays and queue what changed. The bank follows from the tile, so
; it only needs writing when the cell held something else before (blank,
; an entity, or a forced redraw: rk_old >= $7E).
emit:       ld l,b
            ld (em_bank),a
            ld a,d : add a,D_SHCHR : ld h,a
            ld a,(rk_old) : cp KEY_BLACK : jr nc,.full
            ld a,(hl) : cp c : jr nz,.full
            ld a,d : add a,D_SHCOL : ld h,a
            ld a,(hl) : cp e : ret z
            ld (hl),e
            ld a,e : ld (em_col),a
            call scr_off
            ex de,hl
            ld hl,(cq_ptr)
            ld (hl),e : inc hl : ld (hl),d : inc hl
            ld a,(em_col) : ld (hl),a : inc hl
            ld (cq_ptr),hl
            ld a,h : cp (COLQ+$300)>>8 : ret c
            jp flush_outq
.full:      ld (hl),c
            ld a,d : add a,D_SHCOL : ld h,a
            ld (hl),e
            ld a,e : ld (em_col),a
            ld a,c : ld (em_chr),a
            call scr_off
            ex de,hl
            ld hl,(fq_ptr)
            ld (hl),e : inc hl : ld (hl),d : inc hl
            ld a,(em_chr) : ld (hl),a : inc hl
            ld a,(em_bank) : ld (hl),a : inc hl
            ld a,(em_col) : ld (hl),a : inc hl
            ld (fq_ptr),hl
            ld de,FULLQ_END : or a : sbc hl,de
            ret c
            jp flush_outq
em_bank:    DB 0
rk_old:     DB 0
em_col:     DB 0
em_chr:     DB 0

; D = FLAGS page, B = low byte of a cell -> HL = screen offset
scr_off:    ld a,b : rla
            ld a,d : rla                    ; A = row' + $80
            sub ((FLAGS>>8)*2)&$FF
            add a,a
            add a,ROWOFS&$FF : ld l,a : ld h,ROWOFS>>8
            ld a,(hl) : inc l : ld h,(hl) : ld l,a
            ld a,b : and $7F
            add a,l : ld l,a : ret nc
            inc h
            ret

; ROWOFS[r'] = (r'-1)*80 - 1  (so offset = ROWOFS[r'] + c')
            ALIGN 64
ROWOFS:
            DW -81
            DW 0*80-1,1*80-1,2*80-1,3*80-1,4*80-1,5*80-1,6*80-1,7*80-1
            DW 8*80-1,9*80-1,10*80-1,11*80-1,12*80-1,13*80-1,14*80-1,15*80-1
            DW 16*80-1,17*80-1,18*80-1,19*80-1,20*80-1,21*80-1,22*80-1

cyc_phase:  DB 0

; ---------------------------------------------------------------------
; Dirty queue: cells that must be redrawn (entities, reveals, cyclers).
; ---------------------------------------------------------------------
DIRTYQ_MAX  EQU 200
; HL = FLAGS cell; preserves HL, DE
mark_dirty: bit F_QUEUED,(hl)
            ret nz
            set F_QUEUED,(hl)
            push de
            ex de,hl
            ld hl,(dq_ptr)
            ld (hl),e : inc hl : ld (hl),d : inc hl
            ld (dq_ptr),hl
            ex de,hl
            pop de
            ret

render_dirty:
            ld hl,DIRTYQ
.lp:        ld de,(dq_ptr)
            ld a,l : cp e : jr nz,.go
            ld a,h : cp d : jr nz,.go
            ld hl,DIRTYQ : ld (dq_ptr),hl
            ret
.go:        ld e,(hl) : inc hl : ld d,(hl) : inc hl
            push hl
            ex de,hl
            res F_QUEUED,(hl)
            ld a,h : add a,D_SHKEY : ld h,a
            ld (hl),$FF                     ; force: forget the last key
            sub D_SHKEY : ld h,a
            call render_cell
            call vb_poll
            pop hl
            jr .lp
dq_ptr:     DW DIRTYQ

; ---------------------------------------------------------------------
; Torch lighting.
; LIGHT holds the torch level 1-7 of every lit cell. The lit cells are
; kept in a list; a relight marks the old ones ($80), casts the ray-tree
; (cells reached for the first time are appended to the new list), then
; redraws only the cells in the old and new lists.
; ---------------------------------------------------------------------
; HL = LIGHT cell, A = $80|level. Appends newly lit cells. Preserves DE.
light_hl:   ld c,(hl)
            cp c : ret c : ret z
            ld (hl),a
            ld a,c : and $7F : ret nz
            ld b,h : ld c,l
            ld hl,(lst_new) : ld (hl),c : inc hl : ld (hl),b : inc hl : ld (lst_new),hl
            ret

; Cast a ray-tree. HL = tree (in the lower window), BC = origin cell,
; IY = new-list pointer. LIGHT: 0 dark, $80 lit last time, $80|n lit now.
; The tree is walked with SP (POP is the fastest way to read it), so no
; calls or pushes in here. Nodes: DW offset, DW skip, DB 0, DB $80|level.
cast:       ld (.sp+1),sp
            ld sp,hl
.loop:      pop hl                          ; offset
            pop de                          ; subtree skip pointer
            add hl,bc                       ; cell
            ld a,(hl) : and 3
            jr nz,.block
            ld a,h : add a,D_LIGHT : ld h,a
            pop af                          ; A = $80 | level
            ld e,(hl)
            cp e : jr c,.loop : jr z,.loop
            ld (hl),a
            ld a,e : and $7F : jr nz,.loop  ; first light this time: list it
            ld (iy+0),l : ld (iy+1),h
            inc iy : inc iy
            jr .loop
.block:     cp 2 : jr nc,.edge
            ; opaque: lit, then its subtree is in shadow
            ld a,(hl) : ld (cst_fl),a
            ld a,h : add a,D_LIGHT : ld h,a
            pop af                          ; (DE holds the skip pointer: keep it)
            ld (cst_lv),a
            cp (hl) : jr c,.face : jr z,.face
            ld a,(hl) : or a
            ld a,(cst_lv) : ld (hl),a
            jr nz,.face
            ld (iy+0),l : ld (iy+1),h
            inc iy : inc iy
.face:      ld a,(cst_fl) : and 1<<F_FACE : jr z,.skip
            ld a,l : add a,$80 : ld l,a     ; the wall face above shares the light
            jr c,.f1
            dec h
.f1:        ld a,(cst_lv)
            cp (hl) : jr c,.skip : jr z,.skip
            ld a,(hl) : and $7F
            ld a,(cst_lv) : ld (hl),a
            jr nz,.skip
            ld (iy+0),l : ld (iy+1),h
            inc iy : inc iy
.skip:      ex de,hl
            ld sp,hl
            jr .loop
.edge:      ; the map edge - or a marker node (offset into the $FF region)
            ld a,h : cp FLAGS>>8 : jr nc,.skip
            ld a,d : or e : jr z,.sp
            in a,(P_CRTCA) : and $20        ; timing checkpoint
            ld hl,vb_last
            cp (hl) : jr z,.skip
            ld (hl),a
            or a : jr z,.skip
            ld hl,(frames) : inc hl : ld (frames),hl
            jr .skip
.sp:        ld sp,0
            ret
cst_fl:     DB 0
cst_lv:     DB 0

; Multi-cell opaque pieces (statue, pillars) take the brightest light of
; any of their cells.
groups:     ld hl,(RI_GROUPS)
.g:         ld a,(hl) : or a : ret z
            ld b,a : inc hl
            push hl
            ld c,0                          ; max level
            push bc
.mx:        ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld a,d : add a,D_LIGHT : ld d,a
            ld a,(de) : and 7
            cp c : jr c,.n1 : ld c,a
.n1:        djnz .mx
            ld a,c
            pop bc
            pop hl
            or a : jr z,.skipg
            ld (grp_lv),a
.st:        ld e,(hl) : inc hl : ld d,(hl) : inc hl
            push hl : push bc
            ex de,hl
            ld a,h : add a,D_LIGHT : ld h,a
            ld a,(grp_lv) : or $80
            call light_hl
            pop bc : pop hl
            djnz .st
            jr .g
.skipg:     add a,b : add a,b : ld e,a : ld d,0 : add hl,de   ; skip 2*n bytes
            jr .g
grp_lv:     DB 0

; Full relight around the player (and lit projectiles).
relight:    ; 1. mark the cells lit last time
            ld hl,(lst_prev)
            ld bc,(lst_prev_end)
.m:         ld a,l : cp c : jr nz,.m1
            ld a,h : cp b : jr z,.m2
.m1:        ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld a,$80 : ld (de),a
            jr .m
.m2:        ; 2. new list in the other buffer
            ld hl,(lst_prev) : ld de,LISTA
            or a : sbc hl,de
            ld hl,LISTA : jr nz,.a
            ld hl,LISTB
.a:         ld (lst_new_start),hl
            ld (lst_new),hl
            call vb_poll
            ; 3. the bearer's own cell, then the torch tree, cast in place
            ;    from the WORLD bank mapped into the lower window
            ld hl,(player_cell)
            ld a,h : add a,D_LIGHT : ld h,a
            ld a,$87 : call light_hl
            ld a,(torch_blk) : call bank_port : out (P_MEM),a
            ld iy,(lst_new)
            ld hl,(torch_tree)
            ld bc,(player_cell)
            call cast
            ; 4. a second source: fire bolt or its burst
            ld hl,(xlight_cell)
            ld a,h : or a : jr z,.nx
            ld b,h : ld c,l
            ld a,h : add a,D_LIGHT : ld h,a
            ld a,$87 : ld e,(hl)
            cp e : jr c,.x1 : jr z,.x1
            ld (hl),a
            ld a,e : and $7F : jr nz,.x1
            ld (iy+0),l : ld (iy+1),h : inc iy : inc iy
.x1:        ld hl,TREE_OMNI
            call cast
.nx:        ld a,MEM_HOME_V : out (P_MEM),a
            ld (lst_new),iy
            call vb_poll
            ; 5. pieces lit as a whole
            call groups
            ld hl,(lst_new) : ld (hl),0 : inc hl : ld (hl),0   ; list end marker
            ; 6. draw every lit cell (each is listed once)
            ld hl,(lst_new_start)
.n:         ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld a,d : or a : jr z,.n2
            ld a,l : and $0F : call z,vb_poll
            ; drawn with this very torch level already? (static light and
            ; entities change the key themselves, so a match means nothing
            ; to do)
            ld a,(de) : and 7 : add a,a : ld b,a
            ld a,d : add a,(D_SHKEY-D_LIGHT)&$FF : ld d,a
            ld a,(de) : cp b : jr z,.n
            push hl
            ld l,e : ld a,d : sub D_SHKEY : ld h,a
            call render_cell
            pop hl
            jr .n
.n2:        ; 7. cells lit last time and not now: dark again
            ld hl,(lst_prev)
.o:         ld de,(lst_prev_end)
            ld a,l : cp e : jr nz,.o1
            ld a,h : cp d : jr z,.o4
.o1:        ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld a,(de) : cp $80 : jr nz,.o
            xor a : ld (de),a
            ld a,l : and $0F : call z,vb_poll
            push hl
            ld l,e : ld a,d : sub D_LIGHT : ld h,a
            call render_cell
            pop hl
            jr .o
.o4:        ld hl,(lst_new_start) : ld (lst_prev),hl
            ld hl,(lst_new) : ld (lst_prev_end),hl
            ret

; Flicker: the torch flame wavers, so cells at the fringe of the light
; (levels 1-3) are redrawn one step dimmer or restored (see render_cell).
flicker_redraw:
            ld hl,(lst_prev)
.f:         ld de,(lst_prev_end)
            ld a,l : cp e : jr nz,.f1
            ld a,h : cp d : ret z
.f1:        ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld a,(de) : and 7
            cp 2 : jr c,.f
            cp 4 : jr nc,.f
            push hl
            ex de,hl
            ld a,h : sub D_LIGHT : ld h,a
            call render_cell
            pop hl
            jr .f
flick_on:   DB 0

torch_tree: DW TREE_RIGHT
torch_blk:  DB BLK_WORLD
player_cell: DW 0              ; (upper: read while the WORLD bank is mapped)
xlight_cell: DW 0
lst_prev:   DW LISTA
lst_prev_end: DW LISTA
lst_new:    DW LISTB
lst_new_start: DW LISTB
lst_cast_end: DW LISTB

; ---------------------------------------------------------------------
; PCG animation: every entry rewrites one glyph (8 rows) from its frame
; list every <period> frames. Runs right after vertical blanking starts.
; ---------------------------------------------------------------------
anim_tick:  ld ix,ANIM_LIST
.e:         ld a,(ix+0)
            cp $FF : jr z,.done
            ld a,(ix+6) : or a
            jr z,.step
            dec (ix+6)
            jr .nx
.step:      ld a,(ix+3) : dec a : ld (ix+6),a      ; reload period
            ld a,(ix+7) : inc a
            cp (ix+2) : jr c,.f1
            xor a
.f1:        ld (ix+7),a
            add a,a : add a,a : add a,a
            ld e,a : ld d,0
            ld l,(ix+4) : ld h,(ix+5)
            add hl,de                                 ; source frame
            ld a,(ix+0) : or LV_SCREEN : out (P_LV),a
            ld a,(ix+1) : and $7F
            ld e,a : ld d,0
            ex de,hl
            add hl,hl : add hl,hl : add hl,hl : add hl,hl
            ld bc,PCGWIN : add hl,bc
            ex de,hl
            ldi : ldi : ldi : ldi : ldi : ldi : ldi : ldi
.nx:        ld de,8 : add ix,de
            jr .e
.done:      ld a,LV_SCREEN : out (P_LV),a
            ret

; ---------------------------------------------------------------------
; Rooms and regions (everything here maps banks, so it lives up here)
; ---------------------------------------------------------------------
; A = region: its 14 banks of PCG tiles and its tile/ramp/animation
; tables (block 16+2n)
region_load:
            ld (cur_region),a
            add a,a : add a,BLK_REGION : ld (rl_blk),a
            ld b,14 : call pcg_load_n
            ld a,(rl_blk) : ld hl,$3800 : ld de,REGTAB : ld bc,REGTAB_LEN
            call bank_read
            ld a,(mono_on) : or a : ret z
            ld a,(rl_blk) : ld hl,MONO_RAMPS : ld de,RAMPTAB : ld bc,$0800
            jp bank_read                    ; monochrome: light by pattern alone
cur_region: DB $FF
mono_on:    DB 0
MONO_LIT    EQU 4                   ; light from which mono sprites go solid
                                    ; (4+: past the flame flicker, so no blinking)

; A = room: TILE and STAT maps unpacked into the home block, the room
; record into ROOMINFO (block 17+2n)
room_load:  ld (cur_room),a
            ld l,a : ld h,0 : add hl,hl : ld de,ROOM_TAB : add hl,de
            ld a,(hl) : add a,a : add a,BLK_REGION+1 : ld (rl_blk),a
            inc hl : ld a,(hl)
            add a,a : add a,a : add a,a : ld l,a : ld h,0
            ld a,(rl_blk) : ld de,rl_dir : ld bc,8 : call bank_read
            ld hl,(rl_dir) : ld de,TILE : call unpack_map
            ld hl,(rl_dir+2) : ld de,STAT : call unpack_map
            ld a,(rl_blk) : ld hl,(rl_dir+4) : ld de,ROOMINFO : ld bc,(rl_dir+6)
            jp bank_read
cur_room:   DB 0
rl_blk:     DB 0
rl_dir:     DS 8

; HL = PackBits data in the room bank, DE = TILE or STAT: 80 x 22 cells
unpack_map: push de
            ld a,(rl_blk) : call bank_port : out (P_MEM),a
            ld de,LISTA
.u:         ld a,(hl) : inc hl
            cp 128 : jr nc,.run
            inc a : ld c,a : ld b,0
            ldir
            jr .chk
.run:       sub 125 : ld b,a
            ld a,(hl) : inc hl
.r1:        ld (de),a : inc de
            djnz .r1
.chk:       ld a,e : cp (LISTA+1760)&$FF : jr nz,.u
            ld a,d : cp (LISTA+1760)>>8 : jr nz,.u
            ld a,MEM_HOME_V : out (P_MEM),a
            pop de
            ld hl,STRIDE+1 : add hl,de : ex de,hl
            ld hl,LISTA
            ld b,22
.row:       push bc
            ld bc,80 : ldir
            ex de,hl : ld bc,STRIDE-80 : add hl,bc : ex de,hl
            pop bc
            djnz .row
            ret

; Explored cells are remembered per room in the STATE block (220 bytes:
; one bit per cell). A = room.
seen_save:  ld (ss_room),a
            ld hl,FLAGS+STRIDE+1 : ld de,BOUNCE
            ld b,22
.r:         push bc
            ld b,10
.by:        push bc
            ld b,8
.bi:        ld a,(hl) : rla : rl c
            inc hl
            djnz .bi
            ld a,c : ld (de),a : inc de
            pop bc
            djnz .by
            push de : ld de,STRIDE-80 : add hl,de : pop de
            pop bc
            djnz .r
            ld a,BLK_STATE : call bank_port : out (P_MEM),a
            ld a,(ss_room) : ld d,a : ld e,0
            ld hl,BOUNCE : ld bc,220 : ldir
            ld a,MEM_HOME_V : out (P_MEM),a
            ret
ss_room:    DB 0

seen_load:  ld h,a : ld l,0
            ld a,BLK_STATE : ld de,BOUNCE : ld bc,220 : call bank_read
            ld hl,FLAGS+STRIDE+1 : ld de,BOUNCE
            ld b,22
.r:         push bc
            ld b,10
.by:        push bc
            ld a,(de) : ld c,a : inc de
            ld b,8
.bi:        rl c : jr nc,.n
            set F_SEEN,(hl)
.n:         inc hl
            djnz .bi
            pop bc
            djnz .by
            push de : ld de,STRIDE-80 : add hl,de : pop de
            pop bc
            djnz .r
            ret

seen_clear: ld a,BLK_STATE : call bank_port : out (P_MEM),a
            ld hl,0 : ld bc,32*256 : ld e,0 : call fill
            ld a,MEM_HOME_V : out (P_MEM),a
            ret

; ---------------------------------------------------------------------
; Keyboard (6545 light-pen scan, as the boot ROM does) and joystick
; ---------------------------------------------------------------------
; A = Microbee key code -> NZ if pressed
keytest:    push bc
            ld b,a
            ld a,$10 : out (P_CRTCA),a : in a,(P_CRTCD)
            ld a,$11 : out (P_CRTCA),a : in a,(P_CRTCD)
            ld a,$12 : out (P_CRTCA),a
            ld a,b : rrca : rrca : rrca : rrca : and $03 : out (P_CRTCD),a
            ld a,$13 : out (P_CRTCA),a
            ld a,b : rlca : rlca : rlca : rlca : and $F0 : out (P_CRTCD),a
            ld a,$1F : out (P_CRTCA),a : out (P_CRTCD),a
            nop
            ld b,0
.w:         in a,(P_CRTCA)
            bit 7,a : jr nz,.d
            djnz .w
.d:         and $40
            pop bc
            ret

; Build the input byte: b0 up b1 down b2 left b3 right b4 attack b5 magic
; b6 menu/escape b7 action-confirm (RETURN)
read_input: ld a,1 : out (P_ROMLAT),a
            ld hl,keymap
            ld c,0
.k:         ld a,(hl) : cp $FF : jr z,.joy
            inc hl
            call keytest
            ld a,(hl) : inc hl
            jr z,.k
            or c : ld c,a
            jr .k
.joy:       xor a : out (P_ROMLAT),a
            in a,(P_PIOA)
            or a : jr nz,.j1
            dec a                           ; reads 00: no joystick fitted
.j1:        cpl
            ld b,a
            and $0F                         ; up down left right
            or c : ld c,a
            bit 7,b : jr z,.nf
            set 4,c
.nf:        ld a,c
            ld (input),a
            jp demo_input
input:      DB 0
keymap:     DB $38,$01, $3A,$02, $3B,$04, $3E,$08      ; cursor keys
            DB 17,$01, 1,$02, 15,$04, 16,$08            ; Q A O P
            DB 23,$01, 19,$02                           ; W S (left hand)
            DB $37,$10, 26,$10                          ; SPACE, Z: strike / use
            DB 6,$20, 24,$20                            ; F, X: fire bolt
            DB $30,$40                                  ; ESC
            DB $34,$80                                  ; RETURN
            DB $FF

; ---------------------------------------------------------------------
; Sampled speech: a 1-bit delta-sigma stream in the AUDIO bank, one
; speaker state every 64 T-states (52.7 kHz). The program stops while a
; line is spoken. HL = offset in the bank, DE = length, A = block.
; ---------------------------------------------------------------------
; One speaker state every 42 T-states (80.4 kHz): the faster the bit
; stream, the further its noise is pushed above the voice, so the speech
; hisses less. Lines are whole 256-byte pages (D = pages); the byte loop
; spreads its own work over the eight bit slots so each stays ~42 T.
speak:      call bank_port : out (P_MEM),a
            ld c,(hl)
            ld b,0
.byte:      rl c : sbc a,a : and $40 : out (P_PIOB),a   ; bit 7
            inc hl : nop                                ; 40
            rl c : sbc a,a : and $40 : out (P_PIOB),a   ; bit 6
            jr $+2                                      ; 42
            rl c : sbc a,a : and $40 : out (P_PIOB),a
            jr $+2
            rl c : sbc a,a : and $40 : out (P_PIOB),a
            jr $+2
            rl c : sbc a,a : and $40 : out (P_PIOB),a
            jr $+2
            rl c : sbc a,a : and $40 : out (P_PIOB),a   ; bit 2
            ld e,(hl) : nop                             ; 41: the next byte
            rl c : sbc a,a : and $40 : out (P_PIOB),a   ; bit 1
            jr $+2
            rl c : sbc a,a : and $40 : out (P_PIOB),a   ; bit 0
            ld c,e
            djnz .byte                                  ; 47
            dec d : jp nz,.byte
            xor a : out (P_PIOB),a
            ld a,MEM_HOME_V : out (P_MEM),a
            ret
