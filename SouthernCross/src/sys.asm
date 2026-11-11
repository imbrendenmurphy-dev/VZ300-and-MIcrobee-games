; ============================================================================
;  SYSTEM: start-up, interrupt + blit, frame pacing, audio, music, input
; ============================================================================

init:
        di
        ld sp,STACKTOP
        ld a,$28                ; mode 1, colour set 0, speaker bit 5 set
        ld (LATCH),a
        ; SRAM bank B at $4000-$67FF (as Graves 'n' Gargoyles does), holding
        ; the background strip; check it really is RAM
        ld a,3
        out ($37),a
        ld hl,STRIP
        ld de,SRAMSTRIP
        ld bc,STRIP_END-STRIP
        ldir
        ld hl,STRIP
        ld de,SRAMSTRIP
        ld bc,STRIP_END-STRIP
.ck:    ld a,(de)
        cp (hl)
        jp nz,no_sram
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.ck
        ; clear variables
        ld hl,VARS
        ld de,VARS+1
        ld bc,VARS_END-VARS-1
        ld (hl),0
        ldir
        ld a,$28
        ld (latch),a
        ld (latch_next),a
        ; frame buffer row table
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
        call build_code
        ; HUD shadow, then the whole screen once (start-up only)
        ld hl,HUD_INIT
        ld de,HUDBUF
        ld bc,512
        ldir
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$AA
        ldir
        call BLIT_HUD
        ; IM2 vectors
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
        ld a,1
        ld (opt_sound),a
        ld (opt_music),a
        ld hl,$ACE1
        ld (seed),hl
        ld hl,$FFFF
        ld (spare_min),hl
        ld a,$00
        ld (hiscore+1),a
        ld a,$50                ; HI 00005000
        ld (hiscore+2),a
        ei
        jp title

; no SRAM: a red screen with a blue bar, and stop
no_sram:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$FF
        ldir
        ld hl,VRAM+30*32
        ld de,VRAM+30*32+1
        ld bc,4*32-1
        ld (hl),$AA
        ldir
.st:    jr .st

; ---------------------------------------------------------------- code builder
; The unrolled copy routines are generated here rather than stored in the
; load image (they're 6.6K of very regular code).
build_code:
        ; LDI chain: 1536 x LDI, then RET
        ld hl,LDICHAIN
        ld bc,64*FBW
.ld:    ld (hl),$ED
        inc hl
        ld (hl),$A0
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.ld
        ld (hl),$C9
        ; BLIT_PF: 64 rows of stack copy, then JP blit_done
        ld hl,BLIT_PF
        ld de,FBVIS             ; source row
        ld ix,VRAM+4            ; destination row
        ld b,64
.bp:    push bc
        ld (hl),$31             ; ld sp,src
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        call .pops
        ld (hl),$D9             ; exx
        inc hl
        ld (hl),$08             ; ex af,af'
        inc hl
        call .pops
        push de
        push ix
        pop de
        ld a,16
        call .ldsp              ; ld sp,dst+16
        call .push
        ld (hl),$D9
        inc hl
        ld (hl),$08
        inc hl
        call .push
        pop de
        push de
        ld a,e
        add a,16
        ld e,a
        jr nc,$+3
        inc d
        xor a
        call .ldsp              ; ld sp,src+16
        call .pops
        push ix
        pop de
        ld a,24
        call .ldsp              ; ld sp,dst+24
        call .push
        pop de
        ld a,e                  ; next source row (+24)
        add a,FBW
        ld e,a
        jr nc,$+3
        inc d
        ld bc,32                ; next destination row
        add ix,bc
        pop bc
        djnz .bp
        ld (hl),$C3             ; jp blit_done
        inc hl
        ld de,blit_done
        ld (hl),e
        inc hl
        ld (hl),d
        ; BLIT_HUD: ld hl,HUDBUF / 64 x (ld de,row: 4 LDI / ld de,row+28: 4 LDI) / ret
        ld hl,BLIT_HUD
        ld (hl),$21
        inc hl
        ld (hl),HUDBUF&255
        inc hl
        ld (hl),HUDBUF>>8
        inc hl
        ld de,VRAM
        ld b,64
.bh:    xor a
        call .ldde
        ld a,28
        call .ldde
        push hl
        ld hl,32
        add hl,de
        ex de,hl
        pop hl
        djnz .bh
        ld (hl),$C9
        ret
; emit ld de,(DE+A) followed by 4 x LDI
.ldde:  push de
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld (hl),$11
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop de
        ld c,4
.l4:    ld (hl),$ED
        inc hl
        ld (hl),$A0
        inc hl
        dec c
        jr nz,.l4
        ret
; emit ld sp,DE+A
.ldsp:  push de
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld (hl),$31
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop de
        ret
; emit pop af/bc/de/hl
.pops:  ld (hl),$F1
        inc hl
        ld (hl),$C1
        inc hl
        ld (hl),$D1
        inc hl
        ld (hl),$E1
        inc hl
        ret
; emit push hl/de/bc/af
.push:  ld (hl),$E5
        inc hl
        ld (hl),$D5
        inc hl
        ld (hl),$C5
        inc hl
        ld (hl),$F5
        inc hl
        ret

; ---------------------------------------------------------------- ISR
; The interrupt line is held low for the 56 lines of field sync.  Video RAM
; may only be touched before the display starts (94 lines after the
; interrupt), so the frame is copied first, with the least possible set-up.
isr:
        push af
        push bc
        push de
        push hl
        exx
        ex af,af'
        push af
        push bc
        push de
        push hl
        ld a,(frame_ready)
        or a
        jr z,isr_nob
        ld (isr_sp),sp
        jp BLIT_PF              ; 64 rows x 24 bytes, 19,712 T
blit_done:
        ld sp,(isr_sp)
        xor a
        ld (frame_ready),a
        ld a,(latch_next)
        ld (latch),a
        ld (LATCH),a
        jr isr_common
isr_nob:
        ld a,(hud_dirty)
        or a
        jr z,isr_common
        xor a
        ld (hud_dirty),a
        call BLIT_HUD           ; 64 x 8 bytes, ~10,100 T
isr_common:
        push ix
        push iy
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
        call fs_audio           ; keep the sound going until field sync ends
        pop af
        ei
        reti

; ---------------------------------------------------------------- frame sync
; Mark the frame buffer complete.  Play audio (counting idle passes in IY)
; until it has been shown and two fields have passed since the last frame.
frame_end:
        ld iy,0
        ld a,(fieldcnt)
        cp 2
        jr c,.ok
        ld hl,(late_frames)
        inc hl
        ld (late_frames),hl
.ok:    ld a,1
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
        ld (spare_last),iy
        ld hl,(frames)
        inc hl
        ld (frames),hl
        ; test build: last 128 spare readings (passes/4) at $7D80 for the emulator
        ld a,l
        and $7F
        or $80
        ld l,a
        ld h,$7D
        push iy
        pop de
        srl d
        rr e
        srl d
        rr e
        ld (hl),e
        ; minimum spare (ignore the first frames of each mode)
        ld a,(mode_tm+1)
        or a
        jr nz,.mn
        ld a,(mode_tm)
        cp 20
        ret c
.mn:    push iy
        pop de
        ld hl,(spare_min)
        or a
        sbc hl,de
        ret c
        ld (spare_min),de
        ret

; ---------------------------------------------------------------- audio
; Two pulse channels time-multiplexed on the speaker, 139 T per pass
; (25.5 kHz).  Pulse width is the volume.  INC IY counts idle passes.
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
        inc iy
        ld a,(irqflag)
        or a
        jp z,.lp
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ld a,c
        ld (LATCH),a
        ret

; the same loop inside the ISR until field sync ends (same 139 T pass)
fs_audio:
        push bc
        push de
        push hl
        ld a,(latch)
        or $20
        and $FE
        ld c,a
        ld a,(out1_duty)
        ld b,a
        ld hl,(acc1)
        ld de,(out1_step)
        exx
        push bc
        push de
        push hl
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
        jp .j1                  ; 10 T, matches INC IY
.j1:    ld a,(LATCH)            ; bit 7 = 1 once field sync is over
        rla
        jp nc,.lp
        ld (acc1),hl
        exx
        ld (acc2),hl
        pop hl
        pop de
        pop bc
        exx
        ld a,c
        ld (LATCH),a
        pop hl
        pop de
        pop bc
        ret

; ---------------------------------------------------------------- music
; Each note is a short blip (BLIP fields) then silence: "dink, dink-dink".
; channel: +0 ptr +2 start +4 dur +5 active +6 step +8 duty +9 attack
;          +10 decay +11 blip countdown +12 blip length
MC_PTR   equ 0
MC_START equ 2
MC_DUR   equ 4
MC_ACT   equ 5
MC_STEP  equ 6
MC_DUTY  equ 8
MC_ATT   equ 9
MC_DEC   equ 10
MC_BLIP  equ 11
MC_BLEN  equ 12
MCSIZE   equ 13

; HL = song record (dw channel A, dw channel B)
play_song:
        push ix
        di
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld ix,MCH1
        ld (ix+MC_ATT),84
        ld (ix+MC_DEC),18
        ld (ix+MC_BLEN),3
        call .start
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld ix,MCH2
        ld (ix+MC_ATT),64
        ld (ix+MC_DEC),10
        ld (ix+MC_BLEN),4
        call .start
        xor a
        ld (song_done),a
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
        ld (ix+MC_BLIP),0
        ret

stop_music:
        xor a
        ld (MCH1+MC_ACT),a
        ld (MCH2+MC_ACT),a
        ld (MCH1+MC_DUTY),a
        ld (MCH2+MC_DUTY),a
        ret

; A = effect number.  A lower-numbered effect never cuts off a louder one
; that is still playing (priority = table order, higher wins)
play_sfx:
        push hl
        push de
        ld e,a
        ld hl,(sfx_ptr)
        ld a,h
        or l
        jr z,.go
        ld a,(sfx_prio)
        cp e
        jr z,.go
        jr nc,.no
.go:    ld a,e
        ld (sfx_prio),a
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
.no:    pop de
        pop hl
        ret

; called from the ISR every field
music_tick:
        ld ix,MCH1
        call .chan
        ld ix,MCH2
        call .chan
        ld a,(opt_sound)
        or a
        jr z,.mute
        ld hl,(MCH1+MC_STEP)
        ld (out1_step),hl
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
        ld a,(ix+MC_BLIP)       ; blip running: decay, then silence
        or a
        jr z,.nob
        dec (ix+MC_BLIP)
        jr nz,.dec
        ld (ix+MC_DUTY),0
        jr .nob
.dec:   ld a,(ix+MC_DUTY)
        sub (ix+MC_DEC)
        jr nc,.d1
        xor a
.d1:    ld (ix+MC_DUTY),a
.nob:   dec (ix+MC_DUR)
        ret nz
        ld l,(ix+MC_PTR)
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
        ld e,a
        ld a,(opt_music)
        or a
        ret z
        ld a,e
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
        ld a,(ix+MC_BLEN)
        ld (ix+MC_BLIP),a
        ret
.rest:  ld (ix+MC_DUTY),0
        ld (ix+MC_BLIP),0
        ret

; ---------------------------------------------------------------- input
K_LEFT  equ 0
K_RIGHT equ 1
K_UP    equ 2
K_DOWN  equ 3
K_FIRE  equ 4
K_BURST equ 5
K_SPEED equ 6
K_PAUSE equ 7

; Keyboard rows read their keys as bits 5..0 in the order usually listed
; (checked on a real VZ300: $68EF gives M SPACE , - . N).
read_input:
        ld c,0
        ld a,($68BF)            ; U P I RET O Y
        bit 1,a                 ; O
        jr nz,$+4
        set K_LEFT,c
        bit 4,a                 ; P
        jr nz,$+4
        set K_RIGHT,c
        ld a,($68FE)            ; R Q E - W T
        bit 4,a                 ; Q
        jr nz,$+4
        set K_UP,c
        ld a,($68FD)            ; F A D CTRL S G
        bit 4,a                 ; A
        jr nz,$+4
        set K_DOWN,c
        bit 1,a                 ; S
        jr nz,$+4
        set K_SPEED,c
        ld a,($68EF)            ; M SPACE , - . N
        bit 4,a                 ; SPACE
        jr nz,$+4
        set K_FIRE,c
        bit 5,a                 ; M
        jr nz,$+4
        set K_BURST,c
        ld a,($687F)            ; J ; K : L H
        bit 0,a                 ; H
        jr nz,$+4
        set K_PAUSE,c
        ; joysticks: either one
        in a,($2C)              ; joystick 1 directions
        ld b,a
        in a,($29)              ; joystick 2 left/right
        and b
        cpl
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
        in a,($2E)              ; FIRE buttons
        ld b,a
        in a,($2B)
        and b
        bit 4,a
        jr nz,$+4
        set K_FIRE,c
        in a,($2D)              ; ARM buttons -> Cross Burst
        ld b,a
        in a,($27)
        and b
        bit 4,a
        jr nz,$+4
        set K_BURST,c
        ld a,(keys)
        ld (keys_old),a
        cpl
        and c
        ld (keys_new),a
        ld a,c
        ld (keys),a
        ret

; ---------------------------------------------------------------- misc
; 16-bit xorshift -> A (HL preserved)
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
