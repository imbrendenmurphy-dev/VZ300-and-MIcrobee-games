; =====================================================================
;  fesys.asm - front-end system (upper bank 0, interrupts off):
;  three-voice music (the Dracula's Castle II player), frame wait,
;  the front-end screen buffer with dirty-row presents, drawing helpers
; =====================================================================
FEBB        equ $E800          ; 64 rows x 32 bytes

; ---------------------------------------------------------------------
; music engine. Stream: $00 rest, $01-$5F note (C1 = 1), $60-$7F length,
; $80-$8F instrument, $90 lo hi slide, $91 n length, $FE lo hi jump, $FF stop
CH_PTR      equ 0
CH_WAIT     equ 2
CH_LEN      equ 3
CH_STEP     equ 4
CH_DUTY     equ 6
CH_DECAY    equ 7
CH_DMIN     equ 8
CH_DSTART   equ 9
CH_FLAGS    equ 12
CH_SLIDE    equ 13
CH_SIZE     equ 16

; m_play: A = song number
m_play:
            push ix
            add a,a
            ld l,a
            ld h,0
            ld de,song_table
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            jr m_song
; m_playhl: HL = a song header (three channel pointers), e.g. the intro's
m_playhl:
            push ix
m_song:     ld ix,m_chan1
            ld b,3
.l:         ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (ix+CH_PTR),e
            ld (ix+CH_PTR+1),d
            ld (ix+CH_WAIT),1
            ld (ix+CH_LEN),6
            ld (ix+CH_DUTY),0
            ld (ix+CH_SLIDE),0
            ld (ix+CH_SLIDE+1),0
            ld (ix+CH_FLAGS),0
            ld de,CH_SIZE
            add ix,de
            djnz .l
            pop ix
            ret

m_stop:
            xor a
            ld (m_chan1+CH_PTR+1),a
            ld (m_chan2+CH_PTR+1),a
            ld (m_chan3+CH_PTR+1),a
            ld (m_chan1+CH_DUTY),a
            ld (m_chan2+CH_DUTY),a
            ld (m_chan3+CH_DUTY),a
            ret

; is a song still playing? NZ if so
m_busy:
            ld a,(m_chan1+CH_PTR+1)
            ld hl,m_chan2+CH_PTR+1
            or (hl)
            ld hl,m_chan3+CH_PTR+1
            or (hl)
            ret

; m_sfx: HL = effect stream (channel 3, full volume)
m_sfx:
            push ix
            ld ix,m_chsfx
            ld (ix+CH_PTR),l
            ld (ix+CH_PTR+1),h
            ld (ix+CH_WAIT),1
            ld (ix+CH_LEN),1
            ld (ix+CH_SLIDE),0
            ld (ix+CH_SLIDE+1),0
            ld (ix+CH_FLAGS),0
            ld (ix+CH_DUTY),0
            pop ix
            ret

m_tick:
            ld ix,m_chan1
            call m_ch
            ld ix,m_chan2
            call m_ch
            ld ix,m_chan3
            call m_ch
            ld ix,m_chsfx
            call m_ch
            ld hl,(m_chan1+CH_STEP)
            ld (ml_s1+1),hl
            ld a,(m_chan1+CH_DUTY)
            call m_mute
            ld (ml_d1+1),a
            ld hl,(m_chan2+CH_STEP)
            ld (ml_s2+1),hl
            ld a,(m_chan2+CH_DUTY)
            call m_mute
            ld (ml_d2+1),a
            ld a,(m_chsfx+CH_PTR+1)
            or a
            jr nz,.sfx
            ld a,(m_chsfx+CH_DUTY)
            or a
            jr nz,.sfx
            ld ix,m_chan3
            ld a,$20
            ld (ml_m3+1),a
            ld (ml_m3n+1),a
            ld a,(ix+CH_DUTY)
            call m_mute
            jr .ch3
.sfx:       ld a,$21
            ld (ml_m3+1),a
            ld (ml_m3n+1),a
            ld ix,m_chsfx
            ld a,(ix+CH_DUTY)
.ch3:       ld (ml_d3+1),a
            ld (ml_d3n+1),a
            ld l,(ix+CH_STEP)
            ld h,(ix+CH_STEP+1)
            ld (ml_s3+1),hl
            ld hl,ml_tone
            bit 0,(ix+CH_FLAGS)
            jr z,.t
            ld hl,ml_noise
.t:         ld (ml_j3+1),hl
            ret

m_mute:     push af
            ld a,(music_on)
            or a
            jr z,.off
            pop af
            ret
.off:       pop af
            xor a
            ret

; IX = channel
m_ch:
            ld a,(ix+CH_PTR+1)
            or a
            jr nz,.active
            ld (ix+CH_DUTY),0
            ret
.active:    bit 7,(ix+CH_FLAGS)
            jr z,.snd
            ld (ix+CH_DUTY),0
            jr .dok2
.snd:       ld a,(ix+CH_DUTY)
            sub (ix+CH_DECAY)
            jr c,.dmin
            cp (ix+CH_DMIN)
            jr nc,.dok
.dmin:      ld a,(ix+CH_DMIN)
.dok:       ld (ix+CH_DUTY),a
.dok2:      ld a,(ix+CH_SLIDE)
            or (ix+CH_SLIDE+1)
            jr z,.ns
            ld l,(ix+CH_STEP)
            ld h,(ix+CH_STEP+1)
            ld e,(ix+CH_SLIDE)
            ld d,(ix+CH_SLIDE+1)
            add hl,de
            ld (ix+CH_STEP),l
            ld (ix+CH_STEP+1),h
.ns:        dec (ix+CH_WAIT)
            ret nz
            ld l,(ix+CH_PTR)
            ld h,(ix+CH_PTR+1)
.next:      ld a,(hl)
            inc hl
            cp $60
            jr c,.note
            cp $80
            jr c,.len
            cp $90
            jr c,.inst
            jr z,.slide
            cp $91
            jr z,.llen
            cp $FE
            jr z,.jump
            ld (ix+CH_PTR+1),0
            ld (ix+CH_DUTY),0
            ret
.len:       sub $5F
            ld (ix+CH_LEN),a
            jr .next
.llen:      ld a,(hl)
            inc hl
            ld (ix+CH_LEN),a
            jr .next
.inst:      and $0F
            push hl
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,instruments
            add hl,de
            ld a,(hl)
            ld (ix+CH_DSTART),a
            inc hl
            ld a,(hl)
            ld (ix+CH_DECAY),a
            inc hl
            ld a,(hl)
            ld (ix+CH_DMIN),a
            inc hl
            ld a,(hl)
            ld (ix+CH_FLAGS),a
            pop hl
            jr .next
.slide:     ld a,(hl)
            ld (ix+CH_SLIDE),a
            inc hl
            ld a,(hl)
            ld (ix+CH_SLIDE+1),a
            inc hl
            jr .next
.jump:      ld e,(hl)
            inc hl
            ld d,(hl)
            ex de,hl
            jr .next
.note:      ld (ix+CH_PTR),l
            ld (ix+CH_PTR+1),h
            ld b,a
            ld a,(ix+CH_LEN)
            ld (ix+CH_WAIT),a
            ld a,b
            or a
            jr z,.rest
            add a,a
            ld e,a
            ld d,0
            ld hl,note_steps-2
            add hl,de
            ld a,(hl)
            ld (ix+CH_STEP),a
            inc hl
            ld a,(hl)
            ld (ix+CH_STEP+1),a
            ld a,(ix+CH_DSTART)
            ld (ix+CH_DUTY),a
            res 7,(ix+CH_FLAGS)
            ret
.rest:      ld (ix+CH_DUTY),0
            set 7,(ix+CH_FLAGS)
            ret

; ---------------------------------------------------------------------
; fe_wait: music tick, then play samples until the next field sync
; starts (FS falling). Returns at the very start of the sync gap.
fe_wait:
            push ix
            call m_tick
            ld hl,(fe_frames)
            inc hl
            ld (fe_frames),hl
            ld a,(FSREAD)
            rla
            ld a,$D2                ; JP NC: loop while FS low
            jr nc,.low
            ld a,$DA                ; JP C: loop while FS high
.low:       ld (ml_cond),a
            ld (ml_cond2),a
            ld hl,(m_ph1)
            exx
            ld hl,(m_ph2)
            exx
            ld ix,(m_ph3)
            jp mloop
ml_out:     ld a,(ml_cond)
            cp $DA
            jr z,.done
            ld a,$DA
            ld (ml_cond),a
            ld (ml_cond2),a
            jp mloop
.done:      ld (m_ph1),hl
            exx
            ld (m_ph2),hl
            exx
            ld (m_ph3),ix
            ld a,(fe_latch)
            ld (LATCH),a
            pop ix
            ret

mloop:
ml_s1:      ld bc,0                 ; 10
            add hl,bc               ; 11
            ld a,h                  ; 4
ml_d1:      cp 0                    ; 7
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
            and $20                 ; 7
            ld e,a                  ; 4
ml_j3:      jp ml_tone              ; 10
ml_tone:
ml_s3:      ld bc,0                 ; 10
            add ix,bc               ; 15
            ld a,ixh                ; 8
ml_d3:      cp 0                    ; 7
            sbc a,a                 ; 4
ml_m3:      and $20                 ; 7
            or e                    ; 4
ml_x1:      xor $09                 ; 7
            ld (LATCH),a            ; 13
            ld a,(FSREAD)           ; 13
            rla                     ; 4
ml_cond:    jp c,mloop              ; 10
            jp ml_out               ; total 211 T a sample
ml_noise:   add ix,ix               ; 15
            sbc a,a                 ; 4
            and $2D                 ; 7
            xor ixl                 ; 8
            ld ixl,a                ; 8
ml_d3n:     cp 0                    ; 7
            sbc a,a                 ; 4
ml_m3n:     and $20                 ; 7
            or e                    ; 4
ml_x2:      xor $09                 ; 7
            ld (LATCH),a            ; 13
            ld a,(FSREAD)           ; 13
            rla                     ; 4
ml_cond2:   jp c,mloop              ; 10
            jp ml_out

; fe_setlatch: A = mode/colour-set bits ($08 CSS0, $18 CSS1)
fe_setlatch:
            or $01
            ld (fe_latch),a
            ld (LATCH),a
            ld (ml_x1+1),a
            ld (ml_x2+1),a
            ret

; ---------------------------------------------------------------------
; the front-end buffer: text and sprites draw here, fe_present copies the
; rows marked dirty to video RAM at the start of the sync gap
fe_txt:
            ld hl,FEBB
            ld (txt_base),hl
            ld a,32
            ld (txt_stride),a
            ret

; fe_frame: one 50 Hz step: music until sync, then the dirty rows
fe_frame:
            call fe_wait
; copy dirty rows (LDI, ~540 T a row)
fe_present:
            ld a,22                 ; at most 22 rows a gap (~12K T): the rest
            ld (fp_n),a             ; wait for the next one, so no snow.
            ld a,(fp_next)          ; Round robin: start where the last gap
            ld c,a                  ; stopped, so no row is ever starved
            ld b,64
.r:         ld a,c
            and 63
            ld c,a
            ld hl,fe_dirty
            add a,l
            ld l,a
            jr nc,.h
            inc h
.h:         ld a,(hl)
            or a
            jr z,.n
            ld a,(fp_n)
            dec a
            jp m,.out
            ld (fp_n),a
            ld (hl),0
            push bc
            ld l,c
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            push hl
            ld de,VRAM
            add hl,de
            ex de,hl                ; DE = video row
            pop hl
            ld bc,FEBB
            add hl,bc               ; HL = buffer row
            REPT 32
            ldi
            ENDR
            pop bc
.n:         inc c
            djnz .r
.out:       ld a,c
            and 63
            ld (fp_next),a
            ret

; mark rows dirty: A = first row, B = count
fe_mark:
            push hl
            push de
            ld e,a
            ld d,0
            ld hl,fe_dirty
            add hl,de
.l:         ld (hl),1
            inc hl
            djnz .l
            pop de
            pop hl
            ret

fe_markall:
            xor a
            ld b,64
            jr fe_mark

; fill rows: A = first row, B = count, C = byte
fe_rows:
            push bc
            push af
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,FEBB
            add hl,de
            ld a,b
            ld b,c
.r:         ld c,32
.c:         ld (hl),b
            inc hl
            dec c
            jr nz,.c
            dec a
            jr nz,.r
            pop af
            pop bc
            jr fe_mark

fe_cls:     ld c,a
            xor a
            ld b,64
            jr fe_rows

; text at (D col, E row) with colours set by txt_colour; marks the rows
fe_str:
            push hl
            push de
            call fe_txt
            pop de
            pop hl
            push de
            call draw_str
            pop de
            ld a,e
            ld b,5
            jr fe_mark
fe_strc:
            push hl
            push de
            call fe_txt
            pop de
            pop hl
            push de
            call draw_strc
            pop de
            ld a,e
            ld b,5
            jr fe_mark
fe_str2c:
            push hl
            push de
            call fe_txt
            pop de
            pop hl
            push de
            call draw_str2c
            pop de
            ld a,e
            ld b,10
            jp fe_mark
fe_str2:
            push hl
            push de
            call fe_txt
            pop de
            pop hl
            push de
            call draw_str2
            pop de
            ld a,e
            ld b,10
            jp fe_mark

; ---------------------------------------------------------------------
; fe_spr: HL = sprite block (cache slot), B = x pixel (0-112), C = y row
; (0-56), drawn into FEBB (no clipping)
fe_spr:
            ld a,b
            and 3
            rrca
            rrca
            add a,l
            ld l,a                  ; + phase * 64
            ld (fs_srcp),hl
            ld a,c
            push bc
            ld b,8
            call fe_mark
            pop bc
            ld l,c
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,b
            srl a
            srl a
            add a,l
            ld l,a
            ld de,FEBB
            add hl,de
            ld (fs_sp),sp
            ld sp,(fs_srcp)
            ld e,8
.r:         REPT 4
            pop bc
            ld a,(hl)
            and c
            or b
            ld (hl),a
            inc hl
            ENDR
            ld bc,28
            add hl,bc
            dec e
            jr nz,.r
            ld sp,(fs_sp)
            ret

; unpack a run-length packed 2K picture (HL) into FEBB, all rows dirty
; (n < $80: n+1 literal bytes; n >= $80: the next byte n-$7D times)
fe_pic:
            ld de,FEBB
.l:         ld a,d
            cp HIGH(FEBB+2048)
            jp z,fe_markall
            ld a,(hl)
            inc hl
            cp $80
            jr nc,.run
            inc a
            ld c,a
            ld b,0
            ldir
            jr .l
.run:       sub $7D
            ld b,a
            ld a,(hl)
            inc hl
.r:         ld (de),a
            inc de
            djnz .r
            jr .l

; a byte-aligned box: D = col, E = row, B = width (bytes), C = height, A = byte
fe_box:
            push af
            ld a,e
            push bc
            ld b,c
            call fe_mark
            pop bc
            ld l,e
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,l
            add a,d
            ld l,a
            ld de,FEBB
            add hl,de
            pop af
.r:         push hl
            push bc
.c:         ld (hl),a
            inc hl
            djnz .c
            pop bc
            pop hl
            ld de,32
            add hl,de
            dec c
            jr nz,.r
            ret

; set one pixel in FEBB: B = x, C = y, A = colour 0-3
fe_px:
            ld (fp_c),a
            ld l,c
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,b
            srl a
            srl a
            add a,l
            ld l,a
            ld de,FEBB
            add hl,de
            push hl
            ld a,(fp_c)
            ld hl,cfill
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            ld (pd_c),a
            pop hl
            ld a,b
            and 3
            call set_px
            ld a,c
            ld b,1
            jp fe_mark

; wait N fields of music (A); returns NZ early on fire / any key
fe_delay:
            ld (fe_dn),a
.l:         call fe_frame
            call read_input
            ld a,(in_new)
            and K_FIRE|K_ANY
            ret nz
            ld hl,fe_dn
            dec (hl)
            jr nz,.l
            xor a
            ret

; play a front-end effect by number (A = 0 move, 1 select ...)
fe_sfx:
            add a,a
            ld l,a
            ld h,0
            ld de,fsfx_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            jp m_sfx
fsfx_tab:   dw fsfx_move,fsfx_select,fsfx_fire,fsfx_pulse,fsfx_zap,fsfx_tick,fsfx_type,fsfx_lift,fsfx_beep,fsfx_alarm
FX_ALARM    equ 9
FX_MOVE     equ 0
FX_SELECT   equ 1
FX_FIRE     equ 2
FX_PULSE    equ 3
FX_ZAP      equ 4
FX_TICK     equ 5
FX_TYPE     equ 6
FX_LIFT     equ 7
FX_BEEP     equ 8

; ---- front-end variables
m_chan1:    ds CH_SIZE
m_chan2:    ds CH_SIZE
m_chan3:    ds CH_SIZE
m_chsfx:    ds CH_SIZE
m_ph1:      ds 2
m_ph2:      ds 2
m_ph3:      ds 2
fe_frames:  ds 2
fe_latch:   db $09
fe_dirty:   ds 64
fe_dn:      ds 1
fs_srcp:    ds 2
fs_sp:      ds 2
fp_c:       ds 1
fp_n:       ds 1
fp_next:    db 0
