; =====================================================================
;  LIVING BACKGROUND: glyphs 768-1023 (PCG banks 6 and 7) are rewritten
;  while a room is on show. A room's record lists small sets of them
;  with their frames (worked out when the room is built): drifting
;  water, swaying grass, twinkling stars - and the bugs, which are not
;  sprites at all but a few cells of background that flutter, and cost
;  nothing in a frame unless they change. One set is rewritten in each
;  vertical blanking, after the sprite cells.
;
;  record: type, glyphs n, frames, period, length (word), n glyph ids
;  (words), frames x n x 8 pattern bytes; a bug then has: object index,
;  x (word), y, cells, and for each cell: index (word), the screen code, bank
;  and colours to put back when the bug is eaten
; =====================================================================
A_TYPE      EQU 0           ; 1 scenery, 2 bug, 3 gone; b7 = a new frame is waiting
A_TIMER     EQU 1
A_FRAME     EQU 2
A_PTR       EQU 3
A_PERIOD    EQU 5
A_NF        EQU 6
A_N         EQU 7
A_SIZE      EQU 8
NANIM       EQU 32

anim_init:
        ld hl,ANIMS
        ld de,ANIMS+1
        ld bc,NANIM*A_SIZE-1
        ld (hl),0
        ldir
        xor a
        ld (killq),a
        ld (an_next),a
        ld hl,R_ANIM
        call room_ptr
        ld ix,ANIMS
        ld b,0
        xor a
        ld (nanim),a
.l:     ld a,(hl)
        or a
        ret z
        ld (ix+A_TYPE),a
        ld (ix+A_PTR),l
        ld (ix+A_PTR+1),h
        push hl
        inc hl
        ld a,(hl)
        ld (ix+A_N),a
        inc hl
        ld a,(hl)
        ld (ix+A_NF),a
        inc hl
        ld c,(hl)
        ld (ix+A_PERIOD),c
        ld a,b                  ; stagger the sets
        add a,a
        add a,b
.m:     cp c
        jr c,.md
        sub c
        jr .m
.md:    inc a
        ld (ix+A_TIMER),a
        ld (ix+A_FRAME),0
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        push bc
        call anim_apply
        pop bc
        pop de
        pop hl
        add hl,de
        ld de,A_SIZE
        add ix,de
        inc b
        ld a,b
        ld (nanim),a
        cp NANIM
        jr c,.l
        ret

; IX = set -> HL = its frame data for frame 0, BC = bytes a frame
anim_data:
        ld l,(ix+A_PTR)
        ld h,(ix+A_PTR+1)
        ld de,6
        add hl,de
        ld (aa_ids),hl
        ld e,(ix+A_N)
        ld d,0
        add hl,de
        add hl,de
        ex de,hl                ; DE = data
        ld h,0
        ld l,(ix+A_N)
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l                  ; 8n
        ex de,hl
        ret

; IX = set: write its current frame to TILEPAT and the PCG
anim_apply:
        call anim_data
        ld a,(ix+A_FRAME)
        or a
        jr z,.f0
.fm:    add hl,bc
        dec a
        jr nz,.fm
.f0:    ld a,(ix+A_N)
        ld (aa_n),a
        xor a
        out (P_COLCTL),a
.g:     push hl
        ld hl,(aa_ids)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (aa_ids),hl
        ld a,e
        rlca
        ld a,d
        rla
        or LV_SCREEN
        out (P_LV),a
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,TILEPAT
        add hl,bc
        push hl
        ld a,e
        and $7F
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        or PCGWIN >> 8
        ld h,a
        pop de                  ; TILEPAT
        ex (sp),hl              ; HL = source
        pop bc                  ; PCG
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(hl)
        ld (de),a
        ld (bc),a
        inc hl
        ld a,(aa_n)
        dec a
        ld (aa_n),a
        jr nz,.g
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; each tick: step the sets whose time has come
anim_tick:
        ld a,(nanim)
        or a
        ret z
        ld b,a
        ld ix,ANIMS
        ld de,A_SIZE
.l:     ld a,(ix+A_TYPE)
        and $7F
        jr z,.n
        cp 3
        jr nc,.n
        dec (ix+A_TIMER)
        jr nz,.n
        ld a,(ix+A_PERIOD)
        ld (ix+A_TIMER),a
        ld a,(ix+A_FRAME)
        inc a
        cp (ix+A_NF)
        jr c,.s
        xor a
.s:     ld (ix+A_FRAME),a
        set 7,(ix+A_TYPE)
.n:     add ix,de
        djnz .l
        ret

; in the vertical blanking: an eaten bug's cells, then one waiting set
anim_service:
        call room_map
        ld a,(killq)
        or a
        jr z,.nk
        ld b,a
        ld a,1
        ld (an_video),a
        ld a,b
        call anim_kill
.nk:    ld a,(an_next)
        ld c,NANIM
.s:     and NANIM-1
        ld b,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,ANIMS >> 8
        bit 7,(hl)
        jr nz,.found
        ld a,b
        inc a
        dec c
        jr nz,.s
        ret
.found: res 7,(hl)
        push hl
        pop ix
        ld a,b
        inc a
        ld (an_next),a
        jp anim_apply

; IX = a bug's set -> HL = its tail (object index, x, y, cells ...)
anim_tail:
        call anim_data
        ld a,(ix+A_NF)
.f:     add hl,bc
        dec a
        jr nz,.f
        ret

; A = set number + 1: the bug is gone; its cells go back to the scenery
; (an_video = 0: shadows only, the room is not on show yet)
anim_kill:
        dec a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,ANIMS >> 8
        push hl
        pop ix
        ld (ix+A_TYPE),3
        xor a
        ld (killq),a
        call anim_tail
        inc hl
        inc hl
        inc hl
        inc hl
        ld b,(hl)
        inc hl
.c:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push bc
        ld a,d
        add a,SCRSH >> 8
        ld d,a
        ld a,(hl)
        ld (de),a
        ld b,a
        inc hl
        ld a,d
        add a,4
        ld d,a
        ld a,(hl)
        ld (de),a
        ld c,a
        inc hl
        ld a,d
        sub 8
        ld d,a
        ld a,(hl)
        ld (de),a
        inc hl
        push af
        ld a,d
        add a,(CELLMAP >> 8) - (COLSH >> 8)
        ld d,a
        ld a,(de)               ; under a sprite just now? the next frame mends it
        or a
        jr nz,.skip
        ld a,(an_video)
        or a
        jr z,.skip
        ld a,d
        add a,(VIDEO >> 8) - (CELLMAP >> 8)
        ld d,a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,b
        ld (de),a
        ld a,LV_ATTR
        out (P_LV),a
        ld a,c
        and 15
        ld (de),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,d
        pop af
        ld (de),a
        xor a
        out (P_COLCTL),a
        jr .next
.skip:  pop af
.next:  pop bc
        djnz .c
        ret
