; ==========================================================================
; vidmap.asm - assembled separately (org 0E000h) and copied there by
;              map_video (hw.asm).  ViBED by BPM 2026
;
; Under the Premium's CP/M the video window may be at F000h, at 8000h or
; switched off (it depends on the CP/M version/BIOS).  These programs need
; it at F000h.  Method (from the proven BILBIES!/uB-TYPE loaders):
;   1. probe F000h for video RAM (attribute vs screen RAM test) -> done.
;   2. otherwise find CP/M's lower 32K block by looking for our own
;      program signature in each block, then set port 50h to that block,
;      ROMs off, video window at F000h.
; Runs from the upper 32K so the lower window can be switched freely.
; Interrupts must be off.
; ==========================================================================
        org 0E000h

SIGCOPY equ 0E200h      ; 32 bytes of the program at 0100h, copied by map_video

stub:
        ld hl,0F000h
        call probe
        ret nz                  ; video already at F000h
        ld c,0                  ; scan blocks 0..31
.scan:  ld a,c
        call blkport
        or 08h                  ; video window off while scanning
        out (50h),a
        ld hl,0100h
        ld de,SIGCOPY
        ld b,32
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.next
        inc hl
        inc de
        djnz .cmp
        ld a,c                  ; found: this block, ROMs off, video at F000h
        call blkport
        out (50h),a
        ret
.next:  inc c
        ld a,c
        cp 32
        jr c,.scan
        ld a,2                  ; not found (should not happen): CP/M's usual block
        call blkport
        out (50h),a
        ret

; A = block -> port 50h value: b7..b5 = block bits 4..2,
; b1 b0 = (block bits 1..0) xor 2, b2 = 1 (ROMs off), b3 = 0 (video at F000h)
blkport:
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
        or 4
        pop bc
        ret

; probe: NZ if video RAM appears at HL (attribute RAM differs from screen RAM)
probe:
        ld a,90h                ; attribute RAM at F000h, writes enabled
        out (1Ch),a
        ld a,(hl)
        ld (psave),a
        ld (hl),0AAh
        ld a,80h                ; screen RAM
        out (1Ch),a
        ld b,(hl)
        ld a,90h
        out (1Ch),a
        ld (hl),55h
        ld a,80h
        out (1Ch),a
        ld a,(hl)
        cp b
        ld a,0
        jr nz,.n
        inc a
.n:     ld (pres),a
        ld a,90h
        out (1Ch),a
        ld a,(psave)
        ld (hl),a
        ld a,80h
        out (1Ch),a
        ld a,(pres)
        or a
        ret
psave:  db 0
pres:   db 0
