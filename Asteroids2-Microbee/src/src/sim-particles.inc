; particle mover (the VZ version also erased/plotted pixels; the Microbee
; renderer draws particles from the exported list instead).
; Record: +0 life, +1 class, +2/3 X, +4/5 Y, +6/7 VX, +8/9 VY
update_parts:
        ld hl,PARTS : ld b,N_PART
.loop:  ld a,(hl) : or a : jr z,.next
        dec (hl) : jr z,.next
        push hl : push bc
        ld e,l : ld d,h : inc hl : inc hl       ; HL -> position
        ex de,hl : ld bc,6 : add hl,bc : ex de,hl   ; DE -> velocity
        ld a,(de) : add a,(hl) : ld (hl),a : inc hl : inc de
        ld a,(de) : adc a,(hl) : and 127 : ld (hl),a : inc hl : inc de
        ld a,(de) : add a,(hl) : ld (hl),a : inc hl : inc de
        ld a,(de) : adc a,(hl) : and 63 : ld (hl),a
        pop bc : pop hl
.next:  ld a,b : and 7 : call z,fs_poll
        ld de,PARTSZ : add hl,de : djnz .loop : ret
