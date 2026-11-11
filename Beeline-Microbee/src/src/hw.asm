; ==========================================================================
; hw.asm - Microbee Premium / Premium Plus hardware layer
; ViBED by BPM 2026
; ==========================================================================

PORT_PIOB   equ 02h         ; bit 6 = speaker
PORT_08     equ 08h         ; bit 6 = colour RAM at F800
CRTC_A      equ 0Ch         ; 6545 address / status
CRTC_D      equ 0Dh         ; 6545 data
PORT_1C     equ 1Ch         ; b7 ext gfx, b4 attr RAM at F000, b3-0 PCG bank

VRAM        equ 0F000h      ; screen / attribute RAM window (2K)
PCGWIN      equ 0F800h      ; PCG bank / colour RAM window (2K)

X1C         equ 80h         ; extended graphics on, screen RAM at F000
X1C_ATTR    equ 90h         ; extended graphics on, attribute RAM at F000

; key codes (Microbee matrix, code = row*8+bit)
K_A equ 1
K_M equ 13
K_N equ 14
K_O equ 15
K_P equ 16
K_X equ 24
K_Z equ 26
K_COMMA equ 2Ch
K_DOT equ 2Eh
K_ESC equ 30h
K_SPACE equ 37h
K_UP equ 38h
K_DOWN equ 3Ah
K_LEFT equ 3Bh
K_RIGHT equ 3Eh

; --------------------------------------------------------------------------
; map_video: make sure the video window is at F000h (see vidmap.asm).
;            Call first, with interrupts off and SP in the upper 32K.
; --------------------------------------------------------------------------
map_video:
        ld hl,VIDSTUB
        ld de,0E000h
        ld bc,VIDSTUB_END-VIDSTUB
        ldir
        ld hl,0100h
        ld de,0E200h
        ld bc,32
        ldir
        jp 0E000h               ; returns to our caller
VIDSTUB:
        incbin "../build/vidmap.bin"
VIDSTUB_END:

; --------------------------------------------------------------------------
; init_video: 64x16 cells of 8x16, cursor off, extended graphics on,
;             clears screen/attr/colour RAM, uploads PCG data.
; --------------------------------------------------------------------------
init_video:
        ld hl,crtc_tab
        ld b,16
        ld c,0
.r      ld a,c
        out (CRTC_A),a
        ld a,(hl)
        out (CRTC_D),a
        inc hl
        inc c
        djnz .r
        xor a
        out (PORT_08),a
        ld a,X1C
        out (PORT_1C),a
        ; screen RAM -> spaces
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),20h
        ldir
        ; attribute RAM -> 0
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),0
        ldir
        ld a,X1C
        out (PORT_1C),a
        ; colour RAM -> black on black
        ld a,40h
        out (PORT_08),a
        ld hl,PCGWIN
        ld de,PCGWIN+1
        ld bc,2047
        ld (hl),0
        ldir
        xor a
        out (PORT_08),a
        ; upload PCG data: PCG_BANKS whole banks of 2K
        ld hl,PCGDATA
        ld b,PCG_BANKS
        ld c,0
.bank   push bc
        ld a,c
        or X1C
        out (PORT_1C),a
        ld de,PCGWIN
        ld bc,2048
        ldir
        pop bc
        inc c
        djnz .bank
        ld a,X1C
        out (PORT_1C),a
        ret

crtc_tab:
        db 6Bh,40h,51h,37h,12h,09h,10h,12h,48h,0Fh,20h,0Fh,00h,00h,00h,00h

; --------------------------------------------------------------------------
; keytest: A = key code -> NZ if pressed.  Light-pen keyboard via R18/R19/R31
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
        ld b,0
.w      in a,(CRTC_A)
        rla
        jr c,.ok
        djnz .w
.ok     in a,(CRTC_A)
        and 40h
        ret

; --------------------------------------------------------------------------
; vbpoll: cheap check for the start of vertical blank; counts 50Hz fields.
;         call at least every ~10,000 T-states while rendering.
; --------------------------------------------------------------------------
vbpoll:
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

; wait_vb: wait for the start of the next vertical blank (counted)
wait_vb:
        ld de,0
.a      push de
        call vbpoll
        pop de
        in a,(CRTC_A)
        and 20h
        jr z,.b                 ; not in vblank: wait for it
        dec de                  ; in vblank already: wait for it to end (timeout)
        ld a,d
        or e
        jr nz,.a
.b      ld de,0
.c      push de
        call vbpoll
        pop de
        in a,(CRTC_A)
        and 20h
        ret nz
        dec de
        ld a,d
        or e
        jr nz,.c
        ret
