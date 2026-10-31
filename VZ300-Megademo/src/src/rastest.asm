; =====================================================================
;  RASTEST.VZ - VZ300 MEGADEMO hardware investigation / calibration
;  1. RESULTS : field timing, SRAM bank tests, SD stream speed
;  2. CALIBRATE: orange marker line (Q/A) + write-phase dashes (W/S)
;  3. SPLIT + HOLD: mid-frame mode(0)/mode(1) switch with line hold
;  4. FLD: bouncing text via line holds
;  RETURN = next screen
; =====================================================================
        DEVICE NOSLOT64K
NO_KCOPY EQU 1
        INCLUDE "engine.inc"
OVL     EQU $C000
        org $8000
start:
        di
        ld sp,STACKTOP
        im 1
        ld a,M0
        ld (LATCH),a
        call snd_silence
        ld a,$20
        call cls
        call calibrate
        call test_sram
        call test_sd
        jp screen_results

        INCLUDE "core.asm"
snd_silence_dummy:
silence: ds 256,0
music_apply:
music_tick:
music_save:
        ret

; ---------------------------------------------------------------------
; keyboard (keys verified on VZ/Laser hardware by 2018 A.D.)
; ---------------------------------------------------------------------
KEY_Q   EQU 1           ; bit masks into our key byte
KEY_A   EQU 2
KEY_W   EQU 4
KEY_S   EQU 8
KEY_RET EQU 16
readkeys:               ; -> A = pressed keys (1 = pressed)
        ld c,0
        ld a,($68FE)
        bit 4,a
        jr nz,.q
        set 0,c
.q:     bit 1,a
        jr nz,.w
        set 2,c
.w:     ld a,($68FD)
        bit 4,a
        jr nz,.a
        set 1,c
.a:     bit 1,a
        jr nz,.s
        set 3,c
.s:     ld a,($68BF)
        bit 2,a
        jr nz,.r
        set 4,c
.r:     ld a,c
        ret
lastkeys: db 0
newkeys:                ; edge-triggered keys
        call readkeys
        ld b,a
        ld a,(lastkeys)
        cpl
        and b
        ld c,a
        ld a,b
        ld (lastkeys),a
        ld a,c
        ret

; ---------------------------------------------------------------------
; text output: HL = zero-terminated ASCII, DE = screen address
; ---------------------------------------------------------------------
print:  ld a,(hl)
        or a
        ret z
        cp 64
        jr c,.n
        cp 96
        jr nc,.n
        sub 64
.n:     ld (de),a
        inc hl
        inc de
        jr print
; HL = value 0..999 -> 3 digits at DE
pdec:   ld bc,-100
        call .d
        ld bc,-10
        call .d
        ld a,l
        add a,'0'
        ld (de),a
        inc de
        ret
.d:     ld a,'0'-1
.l:     inc a
        add hl,bc
        jr c,.l
        sbc hl,bc
        ld (de),a
        inc de
        ret
at      MACRO row, col
        ld de,VRAM + row*32 + col
        ENDM

; ---------------------------------------------------------------------
; SRAM tests
; ---------------------------------------------------------------------
r_low:  db 0            ; 1 = bank 1 at $4000 works, DOS intact
r_high: db 0            ; 0 = no effect, 1 = bank switch works, 2 = odd
r_hval: db 0
tsbuf:  ds 16
test_sram:
        ; ---- low bank: port $37 = 3 (read-only distinctness check first) ----
        ld hl,$5F00
        ld de,tsbuf
        ld bc,16
        ldir
        ld a,3
        out ($37),a
        ld hl,$5F00
        ld de,tsbuf
        ld b,16
        ld c,0
.cmp:   ld a,(de)
        cp (hl)
        jr z,.sm
        inc c
.sm:    inc hl
        inc de
        djnz .cmp
        ld a,1
        out ($37),a
        ld a,c
        or a
        jr z,.lowfail
        ld a,3
        out ($37),a
        ld hl,$6700
        ld (hl),$A5
        ld a,1
        out ($37),a
        ld a,($5F00)
        ld hl,tsbuf
        cp (hl)
        jr nz,.lowfail
        ld a,3
        out ($37),a
        ld a,($6700)
        cp $A5
        ld a,1
        out ($37),a
        jr nz,.lowfail
        ld a,1
        ld (r_low),a
.lowfail:
        ; ---- high bank: port $37 bit 2 (value 5), test at $C000 ----
        ; run from low RAM ($7D00) in case the switch also affects $8000+
        ld hl,hb_code
        ld de,$7D00
        ld bc,hb_end-hb_code
        ldir
        call $7D00
        ld (r_high),a
        ret

hb_code:                        ; position independent (no absolute jumps/data)
        ld hl,$C000
        ld (hl),$11
        ld a,5
        out ($37),a
        ld c,(hl)               ; value seen with bit 2 set
        ld (hl),$22
        ld a,1
        out ($37),a
        ld a,(hl)               ; bank 0 again: should still be $11
        cp $11
        jr nz,.hodd
        ld a,c
        cp $11
        jr z,.hnone             ; same memory: bit 2 has no effect
        ld a,5
        out ($37),a
        ld b,(hl)
        ld a,1
        out ($37),a
        ld a,b
        cp $22
        jr nz,.hodd
        ld a,1                  ; switches cleanly
        ret
.hnone: xor a
        ret
.hodd:  ld a,1
        out ($37),a
        ld a,2
        ret
hb_end:

; ---------------------------------------------------------------------
; SD speed: read 32 sectors of VZMEGA.DAT, count fields with IM2
; ---------------------------------------------------------------------
r_sdok: db 0
r_sdframes: dw 0
IM2TAB  EQU $BE00       ; 257 bytes of $BF -> vector $BFBF
test_sd:
        call sd_open
        ret c
        ld a,1
        ld (r_sdok),a
        ; IM2 setup
        ld hl,IM2TAB
        ld b,0
.f:     ld (hl),$BF
        inc hl
        djnz .f
        ld (hl),$BF
        ld a,$C3
        ld ($BFBF),a
        ld hl,isr
        ld ($BFC0),hl
        ld a,HIGH IM2TAB
        ld i,a
        im 2
        ld hl,0
        ld (r_sdframes),hl
        ld a,1
        ld (sd_quiet),a
        ei
        ld b,32
        ld hl,$C000
.r:     push bc
        push hl
        ld b,1
        ei
        call sd_read
        ei
        pop hl
        pop bc
        djnz .r
        di
        im 1
        xor a
        ld i,a
        ld (sd_quiet),a
        ret
isr:    push af
        push hl
        ld hl,(r_sdframes)
        inc hl
        ld (r_sdframes),hl
        ld hl,LATCH
.w:     bit 7,(hl)
        jr z,.w                 ; wait for the end of field sync (level INT)
        pop hl
        pop af
        ei
        reti

; ---------------------------------------------------------------------
; screen 1: results
; ---------------------------------------------------------------------
screen_results:
        di
        ld a,M0
        ld (LATCH),a
        ld a,$20
        call cls
        ld hl,t_title
        at 0,0
        call print
        ld hl,t_lines
        at 2,0
        call print
        ld hl,(lines_per_frame)
        at 2,22
        call pdec
        ld hl,t_fs
        at 3,0
        call print
        ; fs low lines = count*30/228 ~ count*2/15
        ld hl,(fs_low_count)
        add hl,hl
        ld de,0
.d15:   ld bc,15
        or a
        sbc hl,bc
        jr c,.dd
        inc de
        jr .d15
.dd:    ex de,hl
        at 3,22
        call pdec
        ld hl,t_low
        at 5,0
        call print
        ld a,(r_low)
        or a
        ld hl,t_ok
        jr nz,.l1
        ld hl,t_fail
.l1:    at 5,22
        call print
        ld hl,t_high
        at 6,0
        call print
        ld a,(r_high)
        ld hl,t_none
        or a
        jr z,.h1
        ld hl,t_works
        dec a
        jr z,.h1
        ld hl,t_odd
.h1:    at 6,22
        call print
        ld hl,t_sd
        at 8,0
        call print
        ld a,(r_sdok)
        or a
        jr nz,.sd1
        ld hl,t_nofile
        at 9,2
        call print
        jr .sd2
.sd1:   ld hl,t_sd2
        at 9,0
        call print
        ld hl,(r_sdframes)
        at 9,22
        call pdec
.sd2:   ld hl,t_help
        at 12,0
        call print
        ld hl,t_help2
        at 13,0
        call print
        ld hl,t_help3
        at 15,0
        call print
.wait:  call newkeys
        and KEY_RET
        jr z,.wait
        jp screen_cal

t_title: db "VZ300 MEGADEMO HARDWARE TEST 1.1",0
t_lines: db "SCANLINES PER FIELD",0
t_fs:    db "FIELD SYNC LOW LINES",0
t_low:   db "SRAM LOW BANK 1",0
t_high:  db "SRAM HIGH BANK",0
t_ok:    db "OK",0
t_fail:  db "FAIL",0
t_none:  db "NO EFFECT",0
t_works: db "SWITCHES",0
t_odd:   db "ODD",0
t_sd:    db "SD STREAM: 32 SECTORS OF DAT",0
t_sd2:   db "  FIELDS TAKEN",0
t_nofile: db "VZMEGA.DAT NOT FOUND",0
t_help:  db "PLEASE NOTE THESE VALUES.",0
t_help2: db "RETURN = CALIBRATION SCREEN",0
t_help3: db "(Q/A W/S RETURN ON NEXT SCREENS)",0

; ---------------------------------------------------------------------
; screen 2: calibration - marker line + write phase dashes
; ---------------------------------------------------------------------
cal_d:  db 64
cal_tab: ds 640
cal_c1: db 99
cal_c2: db 0
cal_build:
        ; all normal text lines
        ld hl,cal_tab
        ld b,0
.f:     ld (hl),M0
        inc hl
        ld (hl),M0
        inc hl
        djnz .f
        ld b,64
.f2:    ld (hl),M0
        inc hl
        ld (hl),M0
        inc hl
        djnz .f2
        ; marker line D: one mode(1) line (white border + colour pixels)
        ld a,(cal_d)
        ld l,a
        ld h,0
        add hl,hl
        ld de,cal_tab
        add hl,de
        ld (hl),M1W
        inc hl
        ld (hl),M1W
        ; RASTHL dashes (3T toggles to graphics) on lines D+100..D+109
        ld a,(cal_d)
        add a,100
        ld l,a
        ld h,0
        add hl,hl
        ld de,cal_tab
        add hl,de
        ld b,10
.d1:    ld (hl),M1G
        inc hl
        ld (hl),M0
        inc hl
        djnz .d1
        ; RAST dashes (21T toggles) on lines D+160..D+169 (second segment)
        ld a,(cal_d)
        ld l,a
        ld h,0
        ld de,160
        add hl,de
        add hl,hl
        ld de,cal_tab
        add hl,de
        ld b,10
.d2:    ld (hl),M1G
        inc hl
        ld (hl),M0
        inc hl
        djnz .d2
        ret

screen_cal:
        ld a,$20
        call cls
        ; ruler: row numbers down the left, text everywhere
        ld de,VRAM
        ld b,16
        ld c,'0'
.rr:    push bc
        ld a,c
        ld (de),a
        inc de
        ld hl,t_ruler
        ld bc,31
        ldir
        pop bc
        inc c
        ld a,c
        cp '9'+1
        jr nz,.rn
        ld c,'A'
.rn:    djnz .rr
        ld a,(kernel_pairs)
        sub 100+1
        ld (cal_c2),a
        call cal_build
        call snd_silence
cal_frame:
        ld (sp_save),sp
        call frame_sync
        ld sp,cal_tab
        xor a
        SEG ca, cax, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, cal_c1
        SEG cb, cbx, RAST, 105, SU_NONE, W_IDLE, W_IDLE, cal_c2
        ld sp,(sp_save)
        ; show values on the bottom row
        ld hl,t_vals
        at 15,0
        call print
        ld a,(cal_d)
        ld l,a
        ld h,0
        at 15,7
        call pdec
        ld a,(hphase)
        ld l,a
        ld h,0
        at 15,20
        call pdec
        call newkeys
        ld b,a
        and KEY_RET
        jp nz,screen_split
        ld a,b
        and KEY_Q
        jr z,.ck1
        ld hl,cal_d
        dec (hl)
        call cal_build
.ck1:    ld a,b
        and KEY_A
        jr z,.ck2
        ld hl,cal_d
        inc (hl)
        call cal_build
.ck2:    ld a,b
        and KEY_W
        jr z,.ck3
        ld a,(hphase)
        inc a
        and 31
        ld (hphase),a
.ck3:    ld a,b
        and KEY_S
        jr z,.ck4
        ld a,(hphase)
        dec a
        and 31
        ld (hphase),a
.ck4:    call snd_silence
        jp cal_frame
t_ruler: db 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,"01234"
t_vals:  db "D LINE=     HPHASE=    (Q/A W/S)",0

; ---------------------------------------------------------------------
; screen 3: mid-frame split + line hold
;   rows 0-3 text, then 60 lines of mode(1) holding VRAM row 4,
;   then text again (rows 4.. as text)
; ---------------------------------------------------------------------
sp_tab: ds 640
screen_split:
        ld a,$20
        call cls
        ld hl,t_s1
        at 0,0
        call print
        ld hl,t_s2
        at 1,0
        call print
        ld hl,t_s3
        at 2,0
        call print
        ; VRAM row 4: colour bars in mode(1) terms
        ld hl,VRAM+4*32
        ld b,8
.cb:    ld (hl),$00
        inc hl
        ld (hl),$55
        inc hl
        ld (hl),$AA
        inc hl
        ld (hl),$FF
        inc hl
        djnz .cb
        ld hl,t_s4
        at 5,0
        call print
        ld hl,t_s5
        at 6,0
        call print
        ld hl,t_s6
        at 7,0
        call print
        ; table: normal, then hold lines (A then G), then normal
        ld hl,sp_tab
        ld b,0
.n:     ld (hl),M0
        inc hl
        ld (hl),M0
        inc hl
        djnz .n
        ld b,64
.n2:    ld (hl),M0
        inc hl
        ld (hl),M0
        inc hl
        djnz .n2
        ld a,(cal_d)
        add a,48
        ld l,a
        ld h,0
        add hl,hl
        ld de,sp_tab
        add hl,de
        ld b,60
.h:     ld (hl),M0
        inc hl
        ld (hl),M1W
        inc hl
        djnz .h
        ld a,(kernel_pairs)
        dec a
        ld (sp_c1),a
split_frame:
        ld (sp_save),sp
        call frame_sync
        ld sp,sp_tab
        xor a
        SEG sa, sax, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, sp_c1
        ld sp,(sp_save)
        call newkeys
        and KEY_RET
        jp nz,screen_fld
        call snd_silence
        jp split_frame
sp_c1:  db 0
t_s1:   db "SPLIT TEST: BELOW SHOULD BE A",0
t_s2:   db "BLOCK OF CYAN/MAGENTA/ORANGE",0
t_s3:   db "VERTICAL STRIPES, THEN TEXT.",0
t_s4:   db "IF THIS TEXT IS READABLE, MID-",0
t_s5:   db "FRAME MODE SWITCH + LINE HOLD",0
t_s6:   db "WORK ON YOUR VZ300.  RETURN=NEXT",0

; ---------------------------------------------------------------------
; screen 4: FLD bounce of the whole text screen
; ---------------------------------------------------------------------
SU_FL   MACRO
        SU_SP fl_ptr
        ENDM
fl_tab: ds 2*(120+320)
fl_ptr: dw 0
fl_ph:  db 0
screen_fld:
        ld a,$20
        call cls
        ld hl,t_f1
        at 0,0
        call print
        ld hl,t_f2
        at 1,0
        call print
        ld hl,t_f3
        at 3,0
        call print
        ld hl,fl_tab
        ld b,120
.h:     ld (hl),M1G
        inc hl
        ld (hl),M0
        inc hl
        djnz .h
        ld b,0
.n:     ld (hl),M0
        inc hl
        ld (hl),M0
        inc hl
        djnz .n
        ld b,64
.n2:    ld (hl),M0
        inc hl
        ld (hl),M0
        inc hl
        djnz .n2
        ld a,(kernel_pairs)
        sub 25+1
        ld (fl_c2),a
fld_frame:
        ; bounce height = |sine| 0..96
        ld a,(fl_ph)
        add a,2
        ld (fl_ph),a
        ld l,a
        ld h,HIGH bsin
        ld a,(hl)
        ld b,a
        ld a,120
        sub b
        ld l,a
        ld h,0
        add hl,hl
        ld de,fl_tab
        add hl,de
        ld (fl_ptr),hl
        ld (sp_save),sp
        call frame_sync
        ld sp,fl_tab+240
        xor a
        SEG fa, fax, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, fl_c1
        SEG fb, fbx, RASTHL, 103, SU_FL, W_IDLEH, W_IDLEH, fl_c2
        ld sp,(sp_save)
        call newkeys
        and KEY_RET
        jp nz,screen_results
        call snd_silence
        jp fld_frame
fl_c1:  db 24
fl_c2:  db 0
t_f1:   db "FLD TEST: THIS SCREEN SHOULD",0
t_f2:   db "BOUNCE UP AND DOWN SMOOTHLY.",0
t_f3:   db "RETURN = BACK TO RESULTS",0
        ALIGN 256
bsin:
        LUA ALLPASS
        for i=0,255 do
          local v = math.floor(math.abs(math.sin(i*math.pi/128))*96 + 0.5)
          sj.add_byte(v)
        end
        ENDLUA
rastest_end:
        SAVEBIN "../build/rastest.bin", start, rastest_end - start
