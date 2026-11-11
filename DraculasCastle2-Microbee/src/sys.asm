; ===========================================================================
;  sys.asm - core system: frame sync + music sample loop, present, input,
;            decompressor, random, misc helpers
; ===========================================================================

LATCH       equ $6800
KEYS        equ $6800
FSREAD      equ $6FFF          ; keyboard read with no rows selected: bit7 = FS
VRAM        equ $F000
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
            in a,($0C)
            and $20
            ld a,$CA                ; JP NC (loop while FS low)
            jr z,.low
            ld a,$C2                ; JP C (loop while FS high)
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
            cp $CA
            jr z,.done              ; entered vertical blank
            ld a,$CA
            ld (ml_cond),a
            ld (ml_cond2),a
            jp mloop
.done:
            ld (ph1),hl
            exx
            ld (ph2),hl
            exx
            ld (ph3),ix
            xor a                     ; speaker neutral
            out ($02),a
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
            and $40                 ; 7   music voices swing bit 5 only (half volume)
            ld e,a                  ; 4
ml_j3:      jp ml_tone              ; 10
ml_tone:
ml_s3:      ld bc,0                 ; 10
            add ix,bc               ; 15
            ld a,ixh                ; 8
ml_d3:      cp 0                    ; 7
            sbc a,a                 ; 4
ml_m3:      and $40                 ; 7   $21 for SFX (full swing), $20 for music
            or e                    ; 4
ml_x1:      xor $00                 ; 7   latch base (speaker rests with bit0=1, bit5=0)
            out ($02),a            ; 13
            in a,($0C)
            and $20                     ; 4
ml_cond:    jp z,mloop              ; 10
            jp ml_out
            ; total tone path: 211 T per sample (tools/build.py SAMPLE_T)

ml_noise:   ; noise: Galois LFSR (x^16+x^5+x^3+x^2+1) in IX, duty compares low byte
            add ix,ix               ; 15
            sbc a,a                 ; 4
            and $2D                 ; 7
            xor ixl                 ; 8
            ld ixl,a                ; 8
ml_d3n:     cp 0                    ; 7
            sbc a,a                 ; 4
ml_m3n:     and $40                 ; 7
            or e                    ; 4
ml_x2:      xor $00                 ; 7
            out ($02),a            ; 13
            in a,($0C)
            and $20                     ; 4
ml_cond2:   jp z,mloop              ; 10
            jp ml_out

; ---------------------------------------------------------------------------
; set_latch_base: A = base latch value (bit3 mode, bit4 css)
; ---------------------------------------------------------------------------
set_latch:  ld (latch_base),a
            jp native_battle_css

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
            ld d,0
            ld e,64
present_rect:
            jp mb_present

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

cls_back:   call world_reset ; A = fill byte
            ld d,0
            ld e,64
            jr fill_rows

; fill rect in back buffer: C=x byte, B=w, D=y, E=h, A=byte
fill_rect:
            call world_erase
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
            call mb_row_FE
            cpl
            bit 1,a
            jr z,.r0a
            set 0,c
.r0a:       bit 3,a
            jr z,.r1
            set 7,c
.r1:        call mb_row_FD            ; F A D CTRL S G  (bit5..bit0)
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
.r4:        call mb_row_EF            ; M SPACE , - . N  (bit5..bit0)
            cpl
            ; N toggles the music anywhere (except the 1984 maze, where N means north)
            ld b,a
            and $01
            ld hl,n_prev
            cp (hl)
            ld (hl),a
            jr z,.r4n
            or a
            jr z,.r4n
            ld a,(n_lock)
            or a
            jr nz,.r4n
            ld a,(music_on)
            xor 1
            ld (music_on),a
            ld a,1
            ld (n_hit),a
            push bc
            ld hl,sfx_tick
            call play_sfx
            pop bc
.r4n:       ld a,b
            bit 5,a                 ; M
            jr z,.r4b
            set 5,c
.r4b:       bit 4,a                 ; SPACE
            jr z,.r6
            set 4,c
.r6:        call mb_row_BF            ; U P I RET O Y  (bit5..bit0)
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
.r7:        call mb_row_7F            ; J ; K : L H  (bit5..bit0)
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
            call mb_any
            and $3F
            cp $3F
            ld a,0
            jr z,.nk
            inc a
.nk:        ld (any_key),a
            ret

; joystick: AND together all known port variants; returns A = action bits
read_joy:   push bc
            in a,($00)
            cpl
            ld b,a
            and $0F
            cp $0F
            jr z,.none
            bit 7,b
            jr z,.done
            or $10
.done:      pop bc
            ret
.none:      xor a
            pop bc
            ret
detect_joy: ld a,1
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
