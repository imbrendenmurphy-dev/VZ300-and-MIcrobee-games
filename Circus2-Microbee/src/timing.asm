; PAL edge polling. The Microbee does not share the VZ interrupt circuit.
rearm:
 push bc
 push hl
 in a,($0C)
 and $20
 ld b,a
 ld a,(last_blank)
 cp b
 jr z,.done
 ld a,b
 ld (last_blank),a
 or a
 jr z,.done
 ld hl,frames
 inc (hl)
.done: pop hl
 pop bc
 ret
syncframe:
 ld (.step+1),a
 call snd_idle
 ld a,(frames)
.step: add a,2
 ld (nextframe),a
 ret
waitframes:
 ld b,a
 ld a,(frames)
 add a,b
 ld (nextframe),a
 jp snd_idle
snd_idle:
        ld a,(snd_on)
        or a
        jp z,.quiet
        ld a,(v0per)
        cp $FF
        jp z,noise_idle
        ld d,a
        or a
        ld a,$40
        jr nz,$+3
        xor a
        ld (.x0+1),a
        ld a,(v1per)
        ld e,a
        or a
        ld a,$40
        jr nz,$+3
        xor a
        ld (.x1+1),a
        xor a
        ld h,a
        ld c,d
        ld b,e
.chk:   ld l,64
.tl:    dec c
        jr nz,.a
        ld c,d
        ld a,h
.x0:    xor $40
        ld h,a
        out (2),a
.a:     dec b
        jr nz,.b
        ld b,e
        ld a,h
.x1:    xor $40
        ld h,a
        out (2),a
.b:     dec l
        jr nz,.tl
        call rearm
        ld a,(nextframe)
        ld l,a
        ld a,(frames)
        sub l
        jp m,.chk
        xor a
        out (2),a
        ret
.quiet: call rearm
        ld a,(nextframe)
        ld l,a
        ld a,(frames)
        sub l
        jp m,.quiet
        ret

; voice 0 noise (period v1per = density), voice 1 silent
noise_idle:
        ld a,(v1per)
        or a
        jr nz,$+4
        ld a,4
        ld d,a
        ld c,a
        xor a
        ld h,a
.chk:   ld l,64
.tl:    dec c
        jr nz,.a
        ld c,d
        push hl
        ld hl,(nseed)
        add hl,hl
        jr nc,.n1
        ld a,l
        xor $2D
        ld l,a
.n1:    ld (nseed),hl
        ld a,l
        pop hl
        and $40
        xor h
        ld h,a
        out (2),a
.a:     dec l
        jr nz,.tl
        call rearm
        ld a,(nextframe)
        ld l,a
        ld a,(frames)
        sub l
        jp m,.chk
        xor a
        out (2),a
        ret

