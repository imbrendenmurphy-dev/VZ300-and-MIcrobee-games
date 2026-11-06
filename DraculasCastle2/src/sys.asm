; ===========================================================================
;  sys.asm - core system: frame sync + music sample loop, present, input,
;            decompressor, random, misc helpers
; ===========================================================================

LATCH       equ $6800
KEYS        equ $6800
FSREAD      equ $6FFF          ; keyboard read with no rows selected: bit7 = FS
VRAM        equ $7000
BACK        equ BACK_ADDR       ; back buffer (32 bytes/row)

; ---------------------------------------------------------------------------
; wait_frame: runs music + SFX tick, then plays samples until the start of the
; next vertical sync (FS falling). Returns at the very start of vblank.
; Preserves nothing. Interrupts are always off.
; ---------------------------------------------------------------------------
wait_frame:
            push ix
            call wf_inner
            pop ix
            ret
wf_inner:
            call snd_tick
            ld hl,frame_count
            inc (hl)
            jr nz,.nc
            inc hl
            inc (hl)
.nc:
            ; set up loop condition depending on current FS state
            ld a,(FSREAD)
            rla
            ld a,$D2                ; JP NC (loop while FS low)
            jr nc,.low
            ld a,$DA                ; JP C (loop while FS high)
.low:       ld (ml_cond),a
            ld (ml_cond2),a
            ld hl,(ph1)
            exx
            ld hl,(ph2)
            exx
            ld ix,(ph3)
            jp mloop

ml_out:     ; reached when FS changed state
            ld a,(ml_cond)
            cp $DA
            jr z,.done              ; was waiting for FS high->low: done
            ld a,$DA
            ld (ml_cond),a
            ld (ml_cond2),a
            jp mloop
.done:
            ld (ph1),hl
            exx
            ld (ph2),hl
            exx
            ld (ph3),ix
            ld a,(latch_base)       ; leave speaker in neutral state
            ld (LATCH),a
            ret

; --- the sample loop (self-modifying) ---------------------------------------
mloop:
ml_s1:      ld bc,0                 ; 10  ch1 step
            add hl,bc               ; 11
            ld a,h                  ; 4
ml_d1:      cp 0                    ; 7   ch1 duty
            sbc a,a                 ; 4
            ld e,a                  ; 4
            exx                     ; 4
ml_s2:      ld bc,0                 ; 10
            add hl,bc               ; 11
            ld a,h                  ; 4
ml_d2:      cp 0                    ; 7
            exx                     ; 4
            sbc a,a                 ; 4
            or e                    ; 4
            ld e,a                  ; 4
ml_j3:      jp ml_tone              ; 10
ml_tone:
ml_s3:      ld bc,0                 ; 10
            add ix,bc               ; 15
            ld a,ixh                ; 8
ml_d3:      cp 0                    ; 7
            sbc a,a                 ; 4
            or e                    ; 4
            and $21                 ; 7
ml_x1:      xor $09                 ; 7   latch base ^ 1
            ld (LATCH),a            ; 13
            ld a,(FSREAD)           ; 13
            rla                     ; 4
ml_cond:    jp c,mloop              ; 10
            jp ml_out
            ; total tone path: 214 T per sample

ml_noise:   ; noise: Galois LFSR (x^16+x^5+x^3+x^2+1) in IX, duty compares low byte
            add ix,ix               ; 15
            sbc a,a                 ; 4
            and $2D                 ; 7
            xor ixl                 ; 8
            ld ixl,a                ; 8
ml_d3n:     cp 0                    ; 7
            sbc a,a                 ; 4
            or e                    ; 4
            and $21                 ; 7
ml_x2:      xor $09                 ; 7
            ld (LATCH),a            ; 13
            ld a,(FSREAD)           ; 13
            rla                     ; 4
ml_cond2:   jp c,mloop              ; 10
            jp ml_out

; ---------------------------------------------------------------------------
; set_latch_base: A = base latch value (bit3 mode, bit4 css)
; ---------------------------------------------------------------------------
set_latch:
            ld (latch_base),a
            ld (LATCH),a
            xor $01
            ld (ml_x1+1),a
            ld (ml_x2+1),a
            ret

; set CSS (A=0/1) keeping mode 1
set_css:
            or a
            ld a,$08
            jr z,set_latch
            ld a,$18
            jr set_latch

; ---------------------------------------------------------------------------
; wait_frames: B = number of frames
; ---------------------------------------------------------------------------
wait_frames:
            push bc
            call wait_frame
            pop bc
            djnz wait_frames
            ret

; ---------------------------------------------------------------------------
; Present: copy a rectangle of the back buffer to VRAM during vblank(s).
;   present_rect: C = x byte, B = width bytes, D = y0, E = y1 (exclusive)
;   Blocks (waiting frames, music keeps playing) until done. Each frame copies
;   as many rows as fit in ~11500 T (the 56-line field-sync period is ~12700 T).
; ---------------------------------------------------------------------------
PRESENT_T   equ 11400

present_full:
            ld c,0
            ld b,32
            ld d,0
            ld e,64
present_rect:
            push ix
            call pr_inner
            pop ix
            ret
pr_inner:
            ld a,e
            sub d
            ret z
            ret c
            ld (pr_left),a
            push bc
            call back_addr          ; hl = BACK + y*32 + x
            ld (pr_src),hl
            ld bc,(VRAM-BACK) & $FFFF
            add hl,bc
            ld (pr_dst),hl
            pop bc
            ld a,32
            sub b
            ld (pr_skip),a
            xor a
            ld (pr_skip+1),a
            ; chain entry = .ldiend - 2*w
            ld l,b
            ld h,0
            add hl,hl
            ex de,hl
            ld hl,.ldiend
            or a
            sbc hl,de
            ld (pr_entry),hl
            ; rows per frame = PRESENT_T / (16*w + 77)
            ld l,b
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,77
            add hl,de
            ex de,hl
            ld hl,PRESENT_T
            ld b,0
.div:       or a
            sbc hl,de
            jr c,.dd
            inc b
            jr .div
.dd:        ld a,b
            ld (pr_rpf),a
.frame:
            call wait_frame
            ld a,(pr_left)
            ld b,a
            ld a,(pr_rpf)
            cp b
            jr c,.some
            ld a,b
.some:      ld c,a                  ; rows now
            ld a,b
            sub c
            ld (pr_left),a
            ld a,c
            ex af,af'
            ld hl,(pr_src)
            ld de,(pr_dst)
            ld ix,(pr_entry)
            jp (ix)
.ldichain:
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
.ldiend:
            ld bc,(pr_skip)
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ex af,af'
            dec a
            jr z,.fdone
            ex af,af'
            jp (ix)
.fdone:     ld (pr_src),hl
            ld (pr_dst),de
            ld a,(pr_left)
            or a
            jr nz,.frame
            ret

; quick present of the exploration viewport (80x52)
present_view:
            ld c,0
            ld b,20
            ld d,0
            ld e,52
            jp present_rect

; ---------------------------------------------------------------------------
; Back buffer helpers
; ---------------------------------------------------------------------------
; clear back buffer rows D..E-1 with byte A (full width)
fill_rows:
            push af
            ld l,d
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld bc,BACK
            add hl,bc
            ld a,e
            sub d
            ld b,a
            pop af
.r:         push bc
            ld b,32
.c:         ld (hl),a
            inc hl
            djnz .c
            pop bc
            djnz .r
            ret

cls_back:   ; A = fill byte
            ld d,0
            ld e,64
            jr fill_rows

; fill rect in back buffer: C=x byte, B=w, D=y, E=h, A=byte
fill_rect:
            ld (fr_val),a
            ld a,e
            ld (fr_cnt),a
            ld a,b
            ld (fr_w),a
            call back_addr
.r:         push hl
            ld a,(fr_w)
            ld b,a
            ld a,(fr_val)
.c:         ld (hl),a
            inc hl
            djnz .c
            pop hl
            ld de,32
            add hl,de
            ld a,(fr_cnt)
            dec a
            ld (fr_cnt),a
            jr nz,.r
            ret

; hl = BACK + D*32 + C
back_addr:
            ld l,d
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld b,BACK/256
            add hl,bc               ; c = x, b = $40 -> + $4000 + x
            ret

; ---------------------------------------------------------------------------
; LZ2 decompressor  HL = src, DE = dst
;   t < $80 : literal run t+1 ; t = 1LLLOOOO lo : match len LLL+3 (7 -> +ext),
;   offset OOOO:lo + 1 ; ext = $FF ends the stream
; ---------------------------------------------------------------------------
lz_unpack:
            ld a,(hl)
            inc hl
            bit 7,a
            jr nz,.match
            ld c,a
            ld b,0
            inc bc
            ldir
            jr lz_unpack
.match:     ld b,a
            ld a,(hl)
            inc hl
            push hl
            cpl
            ld l,a
            ld a,b
            and $0F
            cpl
            ld h,a                  ; hl = -(offset)
            add hl,de               ; hl = copy source
            ld a,b
            rrca
            rrca
            rrca
            rrca
            and 7
            add a,3
            ld c,a
            ld b,0
            cp 10
            jr nz,.copy
            ex (sp),hl
            ld a,(hl)
            inc hl
            ex (sp),hl
            cp $FF
            jr z,.end
            add a,10
            ld c,a
            ld a,0
            adc a,0
            ld b,a
.copy:      ldir
            pop hl
            jr lz_unpack
.end:       pop hl
            ret

; ---------------------------------------------------------------------------
; random: returns A (xorshift 16)
; ---------------------------------------------------------------------------
random:
            push hl
            ld hl,(rng)
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
            ld (rng),hl
            pop hl
            ret

; rand_n: A = random 0..B-1 (B>0)
rand_n:
            push bc
            call random
            ld c,a
            ld a,b
            ; a = (rand * n) >> 8
            ld h,0
            ld l,0
            ld d,0
            ld e,c
.m:         add hl,de
            djnz .m
            ld a,h
            pop bc
            ret

; ---------------------------------------------------------------------------
; Input
;   keys_now: bitfield of game actions this frame, keys_new: newly pressed
; ---------------------------------------------------------------------------
K_UP        equ 1
K_DOWN      equ 2
K_LEFT      equ 4
K_RIGHT     equ 8
K_FIRE      equ 16
K_MAP       equ 32
K_MENU      equ 64
K_ITEM      equ 128

; read raw keyboard rows -> action bits
read_input:
            ld c,0
            ; VZ matrix: bit5..bit0 per row, e.g. $68FE = R Q E - W T  (T = bit0)
            ld a,($68FE)
            cpl
            bit 1,a
            jr z,.r0a
            set 0,c
.r0a:       bit 3,a
            jr z,.r1
            set 7,c
.r1:        ld a,($68FD)            ; F A D CTRL S G  (bit5..bit0)
            cpl
            bit 4,a                 ; A
            jr z,.r1b
            set 2,c
.r1b:       bit 3,a                 ; D
            jr z,.r1c
            set 3,c
.r1c:       bit 1,a                 ; S
            jr z,.r4
            set 1,c
.r4:        ld a,($68EF)            ; M SPACE , - . N  (bit5..bit0)
            cpl
            bit 5,a                 ; M
            jr z,.r4b
            set 5,c
.r4b:       bit 4,a                 ; SPACE
            jr z,.r6
            set 4,c
.r6:        ld a,($68BF)            ; U P I RET O Y  (bit5..bit0)
            cpl
            bit 2,a                 ; RETURN
            jr z,.r6b
            set 4,c
.r6b:       bit 3,a                 ; I = up
            jr z,.r6c
            set 0,c
.r6c:       bit 4,a                 ; P = menu
            jr z,.r7
            set 6,c
.r7:        ld a,($687F)            ; J ; K : L H  (bit5..bit0)
            cpl
            bit 5,a                 ; J = left
            jr z,.r7b
            set 2,c
.r7b:       bit 3,a                 ; K = down
            jr z,.r7c
            set 1,c
.r7c:       bit 1,a                 ; L = right
            jr z,.joy
            set 3,c
.joy:       ld a,(joy_ok)
            or a
            jr z,.done
            call read_joy
            or c
            ld c,a
.done:      ld a,(keys_now)
            cpl
            and c
            ld (keys_new),a
            ld a,c
            ld (keys_now),a
            ; any key at all (for "press any key")
            ld a,($6800)
            and $3F
            cp $3F
            ld a,0
            jr z,.nk
            inc a
.nk:        ld (any_key),a
            ret

; joystick: AND together all known port variants; returns A = action bits
read_joy:
            push bc
            in a,($2E)
            ld b,a
            in a,($2D)
            and b
            ld b,a
            in a,($2B)
            and b
            ld b,a
            in a,($27)
            and b
            ld b,a
            in a,($2C)
            and b
            ld b,a
            in a,($29)
            and b
            cpl
            and $1F                 ; bit0 up 1 down 2 left 3 right 4 fire -> same layout as K_*
            pop bc
            ret

detect_joy:
            ld b,16
            ld c,$FF
.l:         push bc
            call read_joy
            pop bc
            or a
            jr nz,.no
            djnz .l
            ld a,1
            ld (joy_ok),a
            ret
.no:        xor a
            ld (joy_ok),a
            ret

; wait for all keys released then a new press; returns keys_new in A
wait_key:
.rel:       call wait_frame
            call read_input
            ld a,(keys_now)
            ld b,a
            ld a,(any_key)
            or b
            jr nz,.rel
.prs:       call wait_frame
            call read_input
            ld a,(keys_new)
            or a
            ret nz
            ld a,(any_key)
            or a
            jr z,.prs
            ld a,K_FIRE
            ret

; ---------------------------------------------------------------------------
; misc
; ---------------------------------------------------------------------------
; multiply: HL = A * E
mul8:
            ld hl,0
            ld d,0
            ld b,8
.l:         add hl,hl
            rla
            jr nc,.n
            add hl,de
.n:         djnz .l
            ret

; divide HL by 10 -> HL quotient, A remainder
div10:
            ld b,16
            xor a
.l:         add hl,hl
            rla
            cp 10
            jr c,.n
            sub 10
            inc l
.n:         djnz .l
            ret

; number to decimal string: HL = value (0..999), DE = dest (3 chars, leading spaces)
num3:
            push de
            call div10
            ld c,a                  ; units
            push bc
            call div10
            ld b,a                  ; tens
            push bc
            call div10              ; a = hundreds
            pop bc                  ; b = tens
            pop de                  ; e(c) = units  (c of pushed bc)
            ld d,b
            pop hl                  ; dest
            ; a=hund, d=tens, e=units
            add a,'0'
            ld (hl),a
            inc hl
            ld a,d
            add a,'0'
            ld (hl),a
            inc hl
            ld a,e
            add a,'0'
            ld (hl),a
            dec hl
            dec hl
            ld a,(hl)
            cp '0'
            ret nz
            ld (hl),' '
            inc hl
            ld a,(hl)
            cp '0'
            ret nz
            ld (hl),' '
            ret
