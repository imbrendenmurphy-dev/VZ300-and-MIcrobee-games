; ===================================================================
;  DAWN PATROL 2  for the VZ300 + BennVenn SD/128K
;  2026 - ViBED by BPM
; ===================================================================
        device NOSLOT64K
    ifndef DEBUG
DEBUG equ 0
    endif
    macro MARK n
    if DEBUG
        push af
        ld a,n
        out ($FF),a
        pop af
    endif
    endm
        include "defs.asm"

        org $8000
start:
        di
        ld sp,STACKTOP
        ld a,$08
        ld (latchv),a
        ld (LATCH),a
        xor a
        call cls
        ; clear variables
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld a,$08
        ld (latchv),a
        ld hl,$ACE1
        ld (seed),hl
        ld a,$5A
        ld (noise_seed),a
        ; check the BennVenn SRAM banks are present and switch
        call bank_test
        jr nc,.bok
        jp no_sram
.bok:   ; park scenery, music and texts in the second 64K page ($C000 up)
        call to_far
        ; IM2 vector table
        ld hl,IMTAB
        ld de,IMTAB+1
        ld bc,256
        ld (hl),ISRJP/256
        ldir
        ld a,$C3
        ld (ISRJP),a
        ld hl,isr
        ld (ISRJP+1),hl
        ld a,IMTAB/256
        ld i,a
        im 2
        ; joystick present? (idle reads all released)
        call joy_detect
        call preshift_all
        call hs_init
        ld a,1
        ld (difficulty),a
main_loop:
        call title_screen       ; A=0 play, 1 timeout (attract)
        or a
        jr nz,.attract
        call game_new
        jr main_loop
.attract:
        call demo_run
        jr nz,main_loop         ; key pressed during demo
        call hs_screen
        jr main_loop

; ------------------------------------------------------------------
bank_test:
        ; two different SRAM banks in the $4000 window (port values 1 and 3)
        ld a,BANK_W
        out (BANKPORT),a
        ld a,$5A
        ld ($4000),a
        ld a,BANK_P
        out (BANKPORT),a
        ld a,$A5
        ld ($4000),a
        ld a,BANK_W
        out (BANKPORT),a
        ld a,($4000)
        cp $5A
        jr nz,.bad
        ld a,BANK_P
        out (BANKPORT),a
        ld a,($4000)
        cp $A5
        jr nz,.bad
        ; a second page of high RAM (port value 5)
        ld a,BANK_W
        out (BANKPORT),a
        ld a,$C3
        ld ($FFF0),a
        ld a,HIGH1
        out (BANKPORT),a
        ld a,$3C
        ld ($FFF0),a
        ld a,BANK_W
        out (BANKPORT),a
        ld a,($FFF0)
        cp $C3
        jr nz,.bad
        ld a,HIGH1
        out (BANKPORT),a
        ld a,($FFF0)
        ld b,a
        ld a,BANK_W
        out (BANKPORT),a
        ld a,b
        cp $3C
        jr nz,.bad
        or a
        ret
.bad:   ld a,BANK_W
        out (BANKPORT),a
        scf
        ret

; ---- these must stay below $B800: they run while high page 1 is mapped
; copy everything from MOVE_START into page 1 at FARDATA, 8K at a time
; through the $4000 window (both copies share the same addresses)
to_far:
        ld hl,MOVE_START
        ld de,FARDATA
        ld bc,FAR_TOTAL
.lp:    ld a,b
        or c
        ret z
        push bc
        ld a,b
        cp $20
        jr c,.n
        ld bc,$2000
.n:     push bc                 ; chunk size
        push de                 ; far dest
        ld a,BANK_W
        out (BANKPORT),a
        ld de,$4000
        ldir                    ; hl advances through the source
        pop de
        pop bc
        push hl
        push bc
        ld a,HIGH1
        out (BANKPORT),a
        ld hl,$4000
        ldir                    ; de advances through page 1
        ld a,BANK_W
        out (BANKPORT),a
        pop bc                  ; chunk
        pop hl
        ex (sp),hl              ; hl = remaining, stack = src
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        jr .lp

; copy music + long texts from page 1 into the window at ASSETWIN
load_assets:
        ld hl,FAR_ASSETS
        ld de,ASSETWIN
        ld bc,ASSET_SIZE
        jr far_win
; copy the prisoners' voices into the window at SPEECHWIN
load_speech:
        ld hl,FAR_SPEECH
        ld de,SPEECHWIN
        ld bc,SPEECH_SIZE
far_win:
        ld a,HIGH1
        out (BANKPORT),a
        ldir
        ld a,BANK_W
        out (BANKPORT),a
        ret

; unpack the blob at HL (page 1) into the $4000 window (bank W)
unlz_far:
        ld a,HIGH1
        out (BANKPORT),a
        ld de,$4000
        call unlz
        ld a,BANK_W
        out (BANKPORT),a
        ret
LOWCODE_END:

no_sram:
        ld a,$08
        ld (LATCH),a
        xor a
        call cls
        ld a,1
        ld c,0
        call set_txt
        ld b,20
        ld c,2
        call vaddr
        ld de,str_nosram
        call print
        ld b,28
        ld c,2
        call vaddr
        ld de,str_nosram2
        call print
        jr $
str_nosram:  db "NEEDS BENNVENN SD WITH 128K",0
str_nosram2: db "(PORT $37 VALUES 1, 3 AND 5)",0

; ------------------------------------------------------------------
; interrupt: field sync. Copies the finished back buffer to VRAM
; (25 fps lock), plays SFX, then waits for FS to end before EI.
; ------------------------------------------------------------------
isr:
        push af
        push bc
        push de
        push hl
        ld hl,frame_ctr
        inc (hl)
        ld hl,since_copy
        inc (hl)
        ld a,(copy_req)
        or a
        jr z,.nocopy
        ld a,(hl)
        cp 2
        jr c,.nocopy
        call vram_copy
        xor a
        ld (copy_req),a
        ld (since_copy),a
        ld b,90
        jr .snd
.nocopy:
        ; don't burn the field-sync time waiting: return with interrupts
        ; still off; the main loop re-enables them once FS has ended
        ld b,130
        call sfx_isr
        ld a,1
        ld (need_ei),a
        pop hl
        pop de
        pop bc
        pop af
        reti
.snd:   call sfx_isr
.wfs:   ld a,(LATCH)
        rla
        jr nc,.wfs
        pop hl
        pop de
        pop bc
        pop af
        ei
        reti

need_ei db 0
; re-enable interrupts after a quick ISR once field sync is over
check_ei:
        ld a,(need_ei)
        or a
        ret z
        ld a,(LATCH)
        rla
        ret nc
        xor a
        ld (need_ei),a
        ei
        ret

; wait until the pending copy has been done by the ISR
wait_copy:
        call check_ei
        ld a,(copy_req)
        or a
        jr nz,wait_copy
        ret

; ------------------------------------------------------------------
; input: keys Q A M , N SPACE P (as the original) + joystick
; ------------------------------------------------------------------
joy_detect:                     ; joysticks present? (idle reads all released)
        xor a
        ld (joy_ok),a
        ld b,8
.lp:    in a,($2C)              ; joystick 1
        and $1F
        cp $1F
        ret nz
        in a,($29)              ; joystick 2
        and $0C                 ; (its up/down can be flaky, so test left/right)
        cp $0C
        ret nz
        djnz .lp
        ld a,1
        ld (joy_ok),a
        ret

; read both joysticks, either works: A = bits up,down,left,right,fire,arm (1=pressed)
read_joys:
        in a,($2C)              ; J1 directions + fire
        ld c,a
        in a,($2E)              ; J1 fire (standard port)
        and c
        ld c,a
        in a,($29)              ; J2 directions + fire
        and c
        ld c,a
        in a,($2B)              ; J2 fire (standard port)
        and c
        and $1F
        ld c,a
        in a,($2D)              ; J1 arm button
        ld b,a
        in a,($27)              ; J2 arm button
        and b
        and $10
        rrca
        rrca
        rrca
        rrca                    ; -> bit0
        rlca
        rlca
        rlca
        rlca
        rlca                    ; -> bit5
        or c
        or $C0
        cpl
        ret

read_input:
        ld c,0
        ld a,(KR_0)
        bit 4,a                 ; Q
        jr nz,$+4
        set IN_UP,c
        ld a,(KR_1)
        bit 4,a                 ; A
        jr nz,$+4
        set IN_DOWN,c
        ld a,(KR_4)
        bit 5,a                 ; M = right
        jr nz,$+4
        set IN_RIGHT,c
        bit 3,a                 ; , = left
        jr nz,$+4
        set IN_LEFT,c
        bit 0,a                 ; N = rotate
        jr nz,$+4
        set IN_ROT,c
        bit 4,a                 ; SPACE = fire
        jr nz,$+4
        set IN_FIRE,c
        ld a,(KR_6)
        bit 4,a                 ; P = pause
        jr nz,$+4
        set IN_PAUSE,c
        ld a,(joy_ok)
        or a
        jr z,.nojoy
        push bc
        call read_joys          ; bits line up with IN_UP..IN_ROT
        pop bc
        or c
        ld c,a
.nojoy:
        ld a,(in_cur)
        ld (in_prev),a
        cpl
        and c
        ld (in_edge),a
        ld a,c
        ld (in_cur),a
        ret

; any key or fire? -> NZ
any_key:
        ld a,($6800)
        and $3F
        cp $3F
        ret nz
        ld a,(joy_ok)
        or a
        ret z
        call read_joys
        and $10
        ret

wait_release:
        call any_key
        jr nz,wait_release
        ret

; ------------------------------------------------------------------
; maths helpers
; ------------------------------------------------------------------
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
        pop hl
        ret

; A = random 0..B-1 (B>0)
rand_n:
        call rand
.m:     cp b
        ret c
        sub b
        jr .m

; sign-extend A into HL
sext:
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ret

; HL = HL/16 (signed)
div16:
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ret

; aim: DE = dx (px, signed 16), BC = dy (px, signed 16), A = speed (1/16 px)
; -> D = vx, E = vy (signed 8)
aim:
        ld (aim_spd),a
        call clamp_de
        ld a,e
        ld (aim_dx),a
        ld d,b
        ld e,c
        call clamp_de
        ld a,e
        ld (aim_dy),a
        ld a,(aim_dx)
        call abs8
        ld b,a
        ld a,(aim_dy)
        call abs8
        cp b
        jr nc,.m
        ld a,b
.m:     or a
        jr nz,.m2
        inc a
.m2:    ld (aim_m),a
        ld a,(aim_dx)
        call .scale
        push af
        ld a,(aim_dy)
        call .scale
        ld e,a
        pop af
        ld d,a
        ret
.scale: ld c,a
        call abs8
        ld h,a
        ld a,(aim_spd)
        ld e,a
        ld d,0
        ld l,d
        ld b,8
.mu:    add hl,hl
        jr nc,.mn
        add hl,de
.mn:    djnz .mu
        ld a,(aim_m)
        ld e,a
        ld b,16
        xor a
.dv:    add hl,hl
        rla
        cp e
        jr c,.dn
        sub e
        inc l
.dn:    djnz .dv
        ld a,l
        bit 7,c
        ret z
        neg
        ret
aim_spd db 0
aim_dx  db 0
aim_dy  db 0
aim_m   db 0

abs8:   bit 7,a
        ret z
        neg
        ret

clamp_de:
        ld a,d
        or a
        jr z,.pos
        inc a
        jr z,.neg
        bit 7,d
        jr nz,.min
.max:   ld e,127
        ret
.pos:   bit 7,e
        ret z
        jr .max
.neg:   bit 7,e
        ret nz
.min:   ld e,-127
        ret

; BCD add: HL = value (4 BCD digits) added to score
add_score:
        ld a,(demo)
        or a
        ret nz
        ld a,(score+2)
        add a,l
        daa
        ld (score+2),a
        ld a,(score+1)
        adc a,h
        daa
        ld (score+1),a
        ld a,(score)
        adc a,0
        daa
        ld (score),a
        ; extra life?
        ld hl,score
        ld de,next_extra
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.yes
        ret nz
        inc hl
        inc de
        djnz .c
.yes:   ld a,(next_extra)
        add a,2
        daa
        ld (next_extra),a
        ld a,(lives)
        cp 9
        ret nc
        inc a
        ld (lives),a
        ld a,SFX_POWER
        call sfx_play
        ret

        include "gfx.asm"
        include "sound.asm"
        include "game.asm"
        include "render.asm"
        include "screens.asm"
        include "gen.asm"
RESIDENT_END:
        assert LOWCODE_END < $B800
        assert unlz < $B800
        assert RESIDENT_END <= BUF
; ---- everything below is parked in high page 1 at start-up
MOVE_START:
        disp FARDATA
        include "gen_move.asm"
MOVE_SIZE equ $-FARDATA
        ent
ASSET_START:
        disp ASSETWIN
        include "gen_assets.asm"
        include "text_move.asm"
ASSET_SIZE equ $-ASSETWIN
        ent
        assert ASSETWIN+ASSET_SIZE <= SPEECHWIN
SPEECH_START:
        disp SPEECHWIN
        include "gen_speech.asm"
SPEECH_SIZE equ $-SPEECHWIN
        ent
        assert SPEECHWIN+SPEECH_SIZE <= $6800
FAR_END:
FAR_TOTAL   equ FAR_END-MOVE_START
FAR_ASSETS  equ FARDATA+ASSET_START-MOVE_START
FAR_SPEECH  equ FARDATA+SPEECH_START-MOVE_START
        assert FARDATA+FAR_TOTAL <= $10000
code_end:
        savebin "../out/dp2.bin",$8000,code_end-$8000
