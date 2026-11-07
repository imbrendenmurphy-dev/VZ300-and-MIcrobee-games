; ============================================================================
;  SYSTEM: init, interrupt, frame pacing, audio engine, music, input, misc
; ============================================================================

init:
        di
        ld (BOOT_SP),sp         ; what the loader left: the DOS calls use these
        ld (BOOT_IX),ix
        ld (BOOT_IY),iy
        ld sp,STACKTOP
        ; boot progress: one yellow band per step, top to bottom. They are
        ; wiped when the title appears; if start-up ever stops, the last
        ; band shows how far it got (a red band marks a failed check).
        ld a,$28
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$AA
        ldir
        ld a,0
        call boot_band
        call dos_probe          ; as the 13 Ghosts loader does
        ld a,1
        call boot_band
        xor a
        ld (DOSBUSY),a
        ld a,SRAM_GAME
        out ($37),a
        ; move the SRAM blobs up from the load image
        ld hl,BLOB1_SRC
        ld de,$5500
        ld bc,BLOB1_END-$5500
        ldir
        ld hl,BLOB2_SRC
        ld de,$6100
        ld bc,BLOB2_END-$6100
        ldir
        ; check the SRAM really holds what was copied
        ld hl,BLOB1_SRC
        ld de,$5500
        ld bc,BLOB1_END-$5500
.ck:    ld a,(de)
        cp (hl)
        jr nz,.bad
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.ck
        ld a,2
        call boot_band
        jr .ok
.bad:   ld a,2
        call boot_fail
.stop:  jr .stop
.ok:
        ; clear variables
        ld hl,VARS
        ld de,VARS+1
        ld bc,VARS_END-VARS-1
        ld (hl),0
        ldir
        call build_tables
        ; IM2 vector table
        ld hl,IM2TAB
        ld de,IM2TAB+1
        ld bc,256
        ld (hl),ISRJP>>8
        ldir
        ld a,$C3
        ld (ISRJP),a
        ld hl,isr
        ld (ISRJP+1),hl
        ld a,IM2TAB>>8
        ld i,a
        im 2
        ld a,$28                ; mode 1, CSS 0, speaker bit5 set (silent)
        ld (latch),a
        ld (latch_next),a
        ld (LATCH),a
        ld a,3
        call boot_band
        call cls_fb
        ; the first interrupt
        ei
        halt
        ld a,4
        call boot_band
        halt
        halt
        di
        ld a,1
        ld (opt_sound),a
        ld (opt_diff),a
        ld (opt_music),a
        ld hl,$ACE1
        ld (seed),hl
        call load_hiscores
        ld a,1
        ld (booting),a
        ei
        ld a,5
        call boot_band
        call ensure_front       ; first SD read: bands 6, 7, then 8 when done
        ld a,8
        call boot_band
        xor a
        ld (booting),a
        jp front_main

; boot_band: A = step (0-7): paint rows 4A..4A+3 yellow, plus a marker
boot_band:
        ld c,$55
        jr boot_paint
boot_fail:
        ld c,$FF
boot_paint:
        push hl
        push de
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *128
        ld de,VRAM
        add hl,de
        ld (hl),c
        ld d,h
        ld e,l
        inc de
        ld bc,127
        ldir
        pop bc
        pop de
        pop hl
        ret

; ---------------------------------------------------------------- tables
build_tables:
        ; FLIP: reverse the 4 two-bit pixels of a byte
        ld hl,FLIPT
.fl:    ld a,l
        ld b,4
        ld c,0
.fl2:   rrca
        rl c
        rrca
        rl c
        ; c accumulates pixel pairs in reversed order but bit order inside pair flipped
        djnz .fl2
        ; fix bit order inside each pixel: swap bits of each pair
        ld a,c
        and $AA
        rrca
        ld b,a
        ld a,c
        and $55
        rlca
        or b
        ld (hl),a
        inc l
        jr nz,.fl
        ; FB row address table (72 rows)
        ld hl,FB
        ld de,FBW
        ld ix,YTAB
        ld b,FBROWS
.yt:    ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        add hl,de
        djnz .yt
        ret

; ---------------------------------------------------------------- ISR
isr:
        push af
        ld a,(DOSBUSY)
        or a
        jr z,.go
        call fs_wait
        pop af
        ei
        reti
.go:    push bc
        push de
        push hl
        exx
        ex af,af'
        push af
        push bc
        push de
        push hl
        push ix
        push iy
        ld a,(frame_ready)
        or a
        jr z,.noblit
        ld a,(top_dirty)
        or a
        jr z,.pf
        xor a
        ld (top_dirty),a
        ld a,(hud_mode)
        or a
        jr z,.tt
        call BLIT_HUD
        jr .noblit
.tt:    call BLIT_TOP
        jr .noblit
.pf:    call BLIT_PF
        ld a,(latch_next)
        ld (latch),a
        ld (LATCH),a
        xor a
        ld (frame_ready),a
.noblit:
        ld hl,fieldcnt
        inc (hl)
        ld hl,(ticks)
        inc hl
        ld (ticks),hl
        ld a,1
        ld (irqflag),a
        call music_tick
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        exx
        ex af,af'
        pop hl
        pop de
        pop bc
        call fs_wait
        pop af
        ei
        reti

; The VZ's interrupt is level-triggered: the line stays low for the whole
; field sync (56 lines), so interrupts may only be re-enabled after it ends
; (bit 7 of the latch reads 1 once field sync is over)
fs_wait:
        ld a,(LATCH)
        rla
        jr nc,fs_wait
        ret

; ---------------------------------------------------------------- frame sync
; mark the frame buffer complete; play audio until it has been shown and at
; least FRAME_FIELDS fields have passed since the previous frame.
frame_end:
        ld a,1
        ld (frame_ready),a
.w:     call audio_run
        ld a,(frame_ready)
        or a
        jr nz,.w
        ld a,(fieldcnt)
        cp 2
        jr c,.w
        xor a
        ld (fieldcnt),a
        ret

; wait N fields (B) while playing audio, no blit
wait_fields:
        push bc
        call audio_run
        pop bc
        djnz wait_fields
        ret

; ---------------------------------------------------------------- audio
; Two pulse channels mixed by time-multiplexing on the 1-bit speaker.
; Runs until the next interrupt.  129 T-states per sample (27.5 kHz).
; Pulse width (duty) doubles as volume: narrow pulses are quiet and blippy.
audio_run:
        xor a
        ld (irqflag),a
        ld a,(latch)
        or $20
        and $FE
        ld c,a
        ld a,(out1_duty)
        ld b,a
        ld hl,(acc1)
        ld de,(out1_step)
        exx
        ld a,(latch)
        or $20
        and $FE
        ld c,a
        ld a,(out2_duty)
        ld b,a
        ld hl,(acc2)
        ld de,(out2_step)
        exx
.lp:    add hl,de
        ld a,h
        add a,b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        exx
        add hl,de
        ld a,h
        add a,b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        exx
        ld a,(irqflag)
        or a
        jp z,.lp
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ld a,c                  ; leave speaker in the 'off' state
        ld (LATCH),a
        ret

; ---------------------------------------------------------------- music
; channel struct (MCH1/MCH2): +0 ptr  +2 start  +4 dur  +5 active  +6 step
;                             +8 duty  +9 attack  +10 floor
MC_PTR equ 0
MC_START equ 2
MC_DUR equ 4
MC_ACT equ 5
MC_STEP equ 6
MC_DUTY equ 8
MC_ATT equ 9
MC_FLOOR equ 10
MCSIZE equ 12

; HL = song record (dw channel A, dw channel B)
play_song:
        push ix                 ; callers may be walking the object table
        di
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld ix,MCH1
        ld (ix+MC_ATT),64
        ld (ix+MC_FLOOR),12
        call .start
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld ix,MCH2
        ld (ix+MC_ATT),80
        ld (ix+MC_FLOOR),18
        call .start
        ei
        pop ix
        ret
.start: ld (ix+MC_PTR),e
        ld (ix+MC_PTR+1),d
        ld (ix+MC_START),e
        ld (ix+MC_START+1),d
        ld (ix+MC_DUR),1
        ld (ix+MC_ACT),1
        ld (ix+MC_DUTY),0
        ret

stop_music:
        xor a
        ld (MCH1+MC_ACT),a
        ld (MCH2+MC_ACT),a
        ld (MCH1+MC_DUTY),a
        ld (MCH2+MC_DUTY),a
        ret

; A = sfx id
play_sfx:
        add a,a
        ld e,a
        ld d,0
        ld hl,SFXTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (sfx_ptr),hl
        ret

; music_tick: called from the ISR every field
music_tick:
        ld ix,MCH1
        call .chan
        ld ix,MCH2
        call .chan
        ; outputs
        ld a,(opt_sound)
        or a
        jr z,.mute
        ld hl,(MCH1+MC_STEP)
        ld (out1_step),hl
        ld a,(opt_music)
        or a
        jr z,$+5
        ld a,(MCH1+MC_DUTY)
        ld (out1_duty),a
        ld hl,(sfx_ptr)
        ld a,h
        or l
        jr z,.nosfx
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.sfxend
        ld (out2_step),de
        ld a,(hl)
        inc hl
        ld (out2_duty),a
        ld (sfx_ptr),hl
        ret
.sfxend:
        ld hl,0
        ld (sfx_ptr),hl
.nosfx: ld hl,(MCH2+MC_STEP)
        ld (out2_step),hl
        ld a,(opt_music)
        or a
        jr z,$+5
        ld a,(MCH2+MC_DUTY)
        ld (out2_duty),a
        ret
.mute:  xor a
        ld (out1_duty),a
        ld (out2_duty),a
        ret

.chan:  ld a,(ix+MC_ACT)
        or a
        ret z
        dec (ix+MC_DUR)
        jr z,.next
        ; envelope: decay toward floor; silence on the last tick (detached notes)
        ld a,(ix+MC_DUR)
        cp 1
        jr z,.gap
        ld a,(ix+MC_DUTY)
        or a
        ret z
        sub 5
        cp (ix+MC_FLOOR)
        jr nc,.d1
        ld a,(ix+MC_FLOOR)
.d1:    ld (ix+MC_DUTY),a
        ret
.gap:   ld (ix+MC_DUTY),0
        ret
.next:  ld l,(ix+MC_PTR)
        ld h,(ix+MC_PTR+1)
.rd:    ld a,(hl)
        cp $FF
        jr nz,.n1
        ld l,(ix+MC_START)
        ld h,(ix+MC_START+1)
        jr .rd
.n1:    cp $FE
        jr nz,.n2
        ld (ix+MC_ACT),0
        ld (ix+MC_DUTY),0
        ld a,1
        ld (song_done),a
        ret
.n2:    inc hl
        ld b,(hl)
        inc hl
        ld (ix+MC_PTR),l
        ld (ix+MC_PTR+1),h
        ld (ix+MC_DUR),b
        or a
        jr z,.rest
        add a,a
        ld e,a
        ld d,0
        ld hl,NOTE_STEP
        add hl,de
        ld a,(hl)
        ld (ix+MC_STEP),a
        inc hl
        ld a,(hl)
        ld (ix+MC_STEP+1),a
        ld a,(ix+MC_ATT)
        ld (ix+MC_DUTY),a
        ret
.rest:  ld (ix+MC_DUTY),0
        ret

; ---------------------------------------------------------------- input
; keys bits: 0 left 1 right 2 up/jump 3 down 4 fire 5 switch 6 magic 7 pause
K_LEFT  equ 0
K_RIGHT equ 1
K_UP    equ 2
K_DOWN  equ 3
K_FIRE  equ 4
K_SWAP  equ 5
K_MAGIC equ 6
K_PAUSE equ 7

read_input:
        ld a,(demo_mode)
        or a
        jp nz,demo_input
        ld c,0
        ; keyboard (active low)
        ; Each row reads its keys as bits 5..0 in the order usually listed
        ; (checked on real hardware: $68EF gives M SPACE , - . N = bits 5..0)
        ld a,($68BF)            ; row A6: U P I RET O Y
        bit 1,a                 ; O
        jr nz,$+4
        set K_LEFT,c
        bit 4,a                 ; P
        jr nz,$+4
        set K_RIGHT,c
        bit 2,a                 ; RETURN
        jr nz,$+4
        set K_SWAP,c
        ld a,($68FE)            ; row A0: R Q E - W T
        bit 4,a                 ; Q
        jr nz,$+4
        set K_UP,c
        bit 1,a                 ; W
        jr nz,$+4
        set K_SWAP,c
        ld a,($68FD)            ; row A1: F A D CTRL S G
        bit 4,a                 ; A
        jr nz,$+4
        set K_DOWN,c
        ld a,($68EF)            ; row A4: M SPACE , - . N
        bit 4,a                 ; SPACE
        jr nz,$+4
        set K_FIRE,c
        bit 5,a                 ; M
        jr nz,$+4
        set K_MAGIC,c
        ld a,($687F)            ; row A7: J ; K : L H
        bit 0,a                 ; H
        jr nz,$+4
        set K_PAUSE,c
        ; joysticks (either joystick works)
        in a,($2C)              ; joystick 1 directions
        ld b,a
        in a,($29)              ; joystick 2 directions
        and b
        cpl
        ld b,a
        and $0F                 ; up down left right in bits 0..3
        ld e,a
        bit 0,e
        jr z,$+4
        set K_UP,c
        bit 1,e
        jr z,$+4
        set K_DOWN,c
        bit 2,e
        jr z,$+4
        set K_LEFT,c
        bit 3,e
        jr z,$+4
        set K_RIGHT,c
        in a,($2E)              ; fire buttons
        ld b,a
        in a,($2B)
        and b
        bit 4,a
        jr nz,$+4
        set K_FIRE,c
        in a,($2D)              ; arm buttons -> weapon swap
        ld b,a
        in a,($27)
        and b
        bit 4,a
        jr nz,$+4
        set K_SWAP,c
store_keys:
        ld a,(keys)
        ld (keys_old),a
        cpl
        and c
        ld (keys_new),a
        ld a,c
        ld (keys),a
        ; any keypress resets the idle timer
        or a
        ret z
        ld hl,0
        ld (idle),hl
        ret

; any key or fire in the keyboard matrix? (used by menus) -> NZ if pressed
any_key:
        ld a,($6800)
        and $3F
        cp $3F
        ret nz
        in a,($2E)
        bit 4,a
        jr z,.y
        in a,($2B)
        bit 4,a
        jr z,.y
        xor a
        ret
.y:     or 1
        ret

; ---------------------------------------------------------------- misc
; 16-bit xorshift random -> A (HL preserved)
rand:
        push hl
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
        ld a,l
        pop hl
        ret

; HL = HL * 8
mul8:   add hl,hl
        add hl,hl
        add hl,hl
        ret

; copy BC bytes HL -> DE
memcpy: ldir
        ret

cls_fb:
        ld hl,FB
        ld de,FB+1
        ld bc,FBROWS*FBW-1
        ld a,(col_sky)
        ld (hl),a
        ldir
        ret

; colour constants
COLOURS:
col_sky:   db $AA          ; blue
col_yel:   db $55
col_red:   db $FF
col_grn:   db $00
col_hud:   db $AA
col_dim:   db $88          ; blue/green dither
COLOURS_END:

; ---------------------------------------------------------------- hi scores
; (kept in RAM for this session; SD save planned once the DOS file API is wired in)
load_hiscores:
        ld hl,HISCORE_INIT
        ld de,hiscores
        ld bc,HISCORE_INIT_END-HISCORE_INIT
        ldir
        ret
