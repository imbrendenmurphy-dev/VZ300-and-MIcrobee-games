; ==========================================================================
; hw.asm - Microbee Premium Plus hardware layer for BUNYIP
;          40 x 25 cells of 8 x 10 (320 x 250), 1MB RAM in 32K blocks
; VIBED BY BPM 2026
; ==========================================================================

PORT_PIOB   equ 02h         ; bit 6 = speaker
PORT_08     equ 08h         ; bit 6 = colour RAM at F800
PORT_09     equ 09h         ; IN with A = 1: 40-column clock, A = 0: 80-column
PORT_0B     equ 0Bh         ; ROM latch: 1 while scanning the keyboard
CRTC_A      equ 0Ch         ; 6545 address / status
CRTC_D      equ 0Dh         ; 6545 data
PORT_1C     equ 1Ch         ; b7 ext gfx, b4 attr RAM at F000, b3-0 PCG bank
PORT_50     equ 50h         ; memory map

VRAM        equ 0F000h      ; screen / attribute RAM window (2K)
PCGWIN      equ 0F800h      ; PCG bank / colour RAM window (2K)

X1C         equ 80h         ; extended graphics on, screen RAM at F000
X1C_ATTR    equ 90h         ; extended graphics on, attribute RAM at F000

; RAM blocks in the lower window (0000-7FFF).  Block 0 is the upper 32K.
BLK_TAB     equ 1           ; engine tables, the zone map (normally mapped)
BLK_ZONES   equ 2           ; the four zones (ZONES.BIN)
BLK_ART     equ 3           ; sprite masters (ART.BIN)
BLK_PCG     equ 4           ; PCG glyph data (PCG.BIN), also the tileset
BLK_SPR     equ 6           ; sprites, one block per image: 6..21

; key codes (Microbee matrix, code = row*8+bit)
K_A equ 1
K_B equ 2
K_C equ 3
K_D equ 4
K_E equ 5
K_F equ 6
K_M equ 13
K_N equ 14
K_P equ 16
K_Q equ 17
K_R equ 18
K_S equ 19
K_W equ 23
K_Y equ 25
K_CTRL equ 3Fh
K_ESC equ 30h
K_RET equ 34h
K_SPACE equ 37h
K_UP equ 38h
K_DOWN equ 3Ah
K_LEFT equ 3Bh
K_RIGHT equ 3Eh

; --------------------------------------------------------------------------
; setblk: A = block -> map it in the lower window (video window at F000h)
;         keeps BC, DE, HL
; --------------------------------------------------------------------------
setblk: ld (curblk),a
        push bc
        ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and 1Ch
        rlca
        rlca
        rlca
        or c
        or 4                    ; ROMs off, video window at F000h
        out (PORT_50),a
        pop bc
        ret
curblk: db BLK_TAB

tabblk: ld a,BLK_TAB
        jr setblk

; --------------------------------------------------------------------------
; init_video: 40-column clock, 6545 for 40 x 25 cells of 8 x 10.
;   R0-R3 are the values proven on BPM's Premium Plus (MODES40, STARHIVE);
;   31 rows of 10 lines + 2 = 312 lines (proven by BEECAST V2).
; --------------------------------------------------------------------------
init_video:
        ld a,1
        in a,(PORT_09)          ; 40-column dot clock (the value goes out in A)
        ld hl,crtc_tab
        ld c,0
.r      ld a,c
        out (CRTC_A),a
        ld a,(hl)
        out (CRTC_D),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.r
        xor a
        out (PORT_08),a
        out (PORT_0B),a
        ret

;               R0  R1  R2  R3  R4  R5  R6  R7  R8  R9  R10 R11 R12 R13 R14 R15
crtc_tab:
        db 35h,28h,2Ch,34h,1Eh,02h,19h,1Ch,48h,09h,20h,09h,00h,00h,00h,00h

; --------------------------------------------------------------------------
; upload_pcg: copy PCG banks B (first) .. C-1 from the PCG data block
;   (128 glyphs x 10 bytes a bank) into PCG RAM (16-byte slots)
; --------------------------------------------------------------------------
upload_pcg:
        ld a,BLK_PCG
        call setblk
.bank   push bc
        ld a,b                  ; HL = bank * 1280
        ld h,a
        add a,a
        add a,a
        add a,h
        ld h,a
        ld l,0
        ld a,b
        or X1C
        out (PORT_1C),a
        ld de,PCGWIN
        ld b,128
.ch     push bc
        ld bc,CELLH
        ldir
        ld a,e
        add a,16-CELLH
        ld e,a
        jr nc,.n
        inc d
.n      pop bc
        djnz .ch
        pop bc
        inc b
        ld a,b
        cp c
        jr nz,.bank
        ld a,X1C
        out (PORT_1C),a
        jp tabblk

; --------------------------------------------------------------------------
; keytest: A = key code -> NZ if pressed.  Light-pen keyboard via R18/R19/R31
;          (the ROM latch, port 0Bh, must be on: see readkeys)
; --------------------------------------------------------------------------
keytest:
        ld c,a
        ld a,18
        out (CRTC_A),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 03h
        out (CRTC_D),a
        ld a,19
        out (CRTC_A),a
        ld a,c
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        out (CRTC_D),a
        ld a,16
        out (CRTC_A),a
        in a,(CRTC_D)           ; reading R16 clears the light pen flag
        ld a,31
        out (CRTC_A),a
        out (CRTC_D),a          ; dummy access to R31 starts the update cycle
        nop
        ld b,0
.w      in a,(CRTC_A)
        rla
        jr c,.ok
        djnz .w
.ok     in a,(CRTC_A)
        and 40h
        ret

; anykey: NZ if any of the keys that start or continue things is down
anykey: ld a,1
        out (PORT_0B),a
        ld a,K_SPACE
        call keytest
        jr nz,.y
        ld a,K_RET
        call keytest
        jr nz,.y
        ld a,K_CTRL
        call keytest
.y      push af
        xor a
        out (PORT_0B),a
        pop af
        ret

; onekey: A = key -> NZ if down (does the ROM latch itself)
onekey: push af
        ld a,1
        out (PORT_0B),a
        pop af
        call keytest
        push af
        xor a
        out (PORT_0B),a
        pop af
        ret

; --------------------------------------------------------------------------
; vbpoll: cheap check for the start of vertical blank; counts 50Hz fields.
;         call at least every ~10,000 T-states while rendering.
;         keeps BC, DE
; --------------------------------------------------------------------------
vbpoll:
P_vb:
        in a,(CRTC_A)
        and 20h
        ld hl,vb_last
        cp (hl)
        ret z
        ld (hl),a
        or a
        ret z                   ; falling edge: ignore
        ld hl,(fields)
        inc hl
        ld (fields),hl
        ret
vb_last: db 0
fields: dw 0

; wait_vb: wait for the start of the next vertical blank, as counted by
;          vbpoll (so the field counter and the wait can never disagree)
wait_vb:
        ld hl,(fields)
        ld (.f0),hl
.l      call vbpoll
        ld hl,(fields)
        ld de,(.f0)
        or a
        sbc hl,de
        jr z,.l
        ret
.f0     dw 0

; waitf: wait A fields
waitf:  ld b,a
.l      push bc
        call wait_vb
        pop bc
        djnz .l
        ret
