; =====================================================================
;  bank.asm - BennVenn SD loader memory (see MAME sdloader.cpp)
;  Port $37:  bit0 = DOS RAM (1) / ROM (0) at $4000-$67FF
;             bit1 = which 10K RAM bank at $4000-$67FF
;             bit2 = which 18K RAM bank at $B800-$FFFF
;    1 = home  : shift tables, sprites, work area ($6000-$67FF)
;    3 = world : level archive (maps, tiles, songs, sprite sheets) 10K
;    5 = upper : the other $B800-$FFFF bank: packed menus overlay + more
;               archive.  It can only be switched in by resident code below
;               $B800, and data crosses through a small bounce buffer.
; =====================================================================
BANKPORT  equ $37
; Bix 2 keeps the DOS alive so it can load each stage from the SD card:
;   DOSMAP (1, or 0 if the DOS runs from ROM): the DOS's low bank + upper bank 0
;   BK_UPPER = 3: the game's low bank 1 + upper bank 0 (packed menus, the
;                 stage pack, the saved ROM/DOS system area, the DOS stack)
;   BK_HOME  = 7: the game's low bank 1 + upper bank 1 (ring, buffer, map)
; The DOS's low bank and upper bank 0 from $F000 up are left to the DOS.
BK_UPPER  equ 3
BK_HOME   equ 7
SCR       equ $D000         ; scratch in the (idle) ring area
FLIPT     equ $DF00         ; pixel-order reverse table (built on demand)
ENSCR     equ $DE00
PLSCR     equ $E1E0         ; 24 bytes
BSSCR     equ $E000
BOSSG     equ $6500         ; boss frames live in home bank work area
ATSCR     equ $E200
LANDING   equ $E300         ; packed blobs from the upper bank land here (2.2K)
BOUNCE    equ $AF10         ; 128 bytes free between the IM2 table and vector
; ---- upper bank 0
UP_OVL    equ $B800         ; packed overlay (loaded there with the program)
PACK      equ $D200         ; the current stage pack (BIX2Lnn.DAT)
PACK_MAX  equ $E000-PACK
GAMESAVE  equ $E000         ; the game's $7800-$7BFF while the DOS runs
SYSSAVE   equ $E400         ; the ROM/DOS system area $7800-$7BFF
DOS_SP    equ $F800         ; DOS-call stack: 4K, $E800-$F7FF (it needs well over 1K)
SECBUF    equ $F800         ; DOS sector buffer $F800-$F9FF ; DOS RAM $FA00+

        MACRO bank n
        ld a,n
        out (BANKPORT),a
        ENDM

; ---------------------------------------------------------------- far copy
; farcopy: BC bytes, HL = source, DE = destination, A = direction
;   0: main -> upper bank   1: upper bank -> main   2: compare upper with main
; (Z set on return if the compare matched.)  Interrupts must be off.
fc_dir  db 0
fc_bad  db 0
farcopy:
        ld (fc_dir),a
        xor a
        ld (fc_bad),a
.l:     ld a,b
        or c
        jr z,.done
        push bc
        ld a,b                  ; n = min(128, BC)
        or a
        jr nz,.big
        ld a,c
        cp 129
        jr c,.n
.big:   ld a,128
.n:     ld c,a
        ld b,0
        push bc                 ; n
        ld a,(fc_dir)
        or a
        jr nz,.up2main
        ; main -> bounce -> upper
        push de
        ld de,BOUNCE
        ldir                    ; HL advanced
        pop de
        pop bc
        push bc
        push hl
        bank BK_UPPER
        ld hl,BOUNCE
        ldir                    ; DE advanced
        bank BK_HOME
        pop hl
        jr .next
.up2main:
        push de
        bank BK_UPPER
        ld de,BOUNCE
        ldir
        bank BK_HOME
        pop de
        pop bc
        push bc
        push hl
        ld hl,BOUNCE
        ld a,(fc_dir)
        cp 2
        jr z,.cmp
        ldir
        pop hl
        jr .next
.cmp:   ld a,(de)
        cp (hl)
        jr z,.ce
        ld a,1
        ld (fc_bad),a
.ce:    inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.cmp
        pop hl
.next:  pop bc                  ; n
        ex (sp),hl              ; HL = remaining, stack = src
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        jr .l
.done:  ld a,(fc_bad)
        or a
        ret

; bfetch: raw copy BC bytes from the stage pack (upper bank 0), HL, to DE
bfetch: ld a,1
        jp farcopy

; blz: unpack BC bytes from the stage pack (upper bank 0), HL, to DE
blz:    push bc
        push de
        ; bring up to 2.2K of the packed stream down to LANDING
        ld bc,2200
        ld de,LANDING
        ld a,1
        call farcopy
        pop de
        pop bc
        ld hl,LANDING
        jp lz_dec

; ---------------------------------------------------------------- overlay
load_overlay:
        di
        ld hl,UP_OVL
        ld de,OVLPACK
        ld bc,OVL_LZ
        ld a,1
        call farcopy
        ld hl,OVLPACK
        ld de,OVL_ORG
        ld bc,OVL_SIZE
        jp lz_dec

; ---------------------------------------------------------------- latch / colour set
set_latch:                      ; A = latch base (mode + colour set)
        ld (latchv),a
        ld (LATCH),a
        or $20
        ld (draw_bg.tk1x+1),a
        ld (isr.tk2x+1),a
        ret

; ---------------------------------------------------------------- loader stubs
; The level loader, pre-shifter and LZ decoder live in the overlay (they only
; run between levels); these stubs bring the overlay in first.
load_level:
        push af
        call load_overlay
        pop af
        jp OVL_LOADLV

; ---------------------------------------------------------------- BIX-LZ decoder
; HL = packed source, DE = destination, BC = unpacked length
;   0nnnnnnn : n+1 literals      1nnnnnnn oooooooo : copy n+3 from dest-o-1
lz_dec:
.l:     ld a,b
        or c
        ret z
        ld a,(hl)
        inc hl
        cp $80
        jr nc,.cp
        inc a
.lt:    push af
        ldi
        pop af
        dec a
        jr nz,.lt
        jr .l
.cp:    and $7F
        add a,3
        ex af,af'
        ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,0
        inc hl                  ; o+1
        push de
        ex de,hl                ; hl = dest, de = o+1
        or a
        sbc hl,de               ; hl = dest-o-1
        pop de
        ex af,af'
.cl:    push af
        ldi
        pop af
        dec a
        jr nz,.cl
        pop hl
        jr .l
