; =====================================================================
;  bank.asm - BennVenn memory, reused from BIX THE BILBY (bank.asm):
;  same port $37 switch model, same bounce-buffer far copy, adapted to
;  keep the DOS alive: home = MAP_FE (bank 3 low + upper 0), the other
;  upper bank (racing data) = MAP_RACE.  Interrupts must be off.
; =====================================================================

; farcopy: BC bytes, HL = source, DE = destination, A = direction
;   0: main/upper0 -> upper1   1: upper1 -> main/upper0   2: compare
; (Z set on return if the compare matched.)
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
        cp BOUNCEN+1
        jr c,.n
.big:   ld a,BOUNCEN
.n:     ld c,a
        ld b,0
        push bc                 ; n
        ld a,(fc_dir)
        or a
        jr nz,.up2main
        push de
        ld de,BOUNCE
        ldir
        pop de
        pop bc
        push bc
        push hl
        bank MAP_RACE
        ld hl,BOUNCE
        ldir
        bank MAP_FE
        pop hl
        jr .next
.up2main:
        push de
        bank MAP_RACE
        ld de,BOUNCE
        ldir
        bank MAP_FE
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

memcmp: ; Z if equal
.l:     ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret
