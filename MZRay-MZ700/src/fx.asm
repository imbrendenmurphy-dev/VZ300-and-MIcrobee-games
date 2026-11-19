; ---------------------------------------------------------------- sound, pieces and flashes
; Sound: one 8253 square-wave channel (counter 0 at E004, control E007, gate E008).
; An effect is a chain of parts: base count (2), count change per field (2), noise mask, fields, next part (2).
; The count sweeps once per field; the noise (a random amount added to the count) is redone at every
; drawn column, so the 8253 sounds gritty rather than beepy. With no effect playing, the slow in-game
; tune plays short "dinks".

GRAV    equ 3                   ; pieces fall 3/32 row per field per field
FLOORR  equ VIEWH-1

; HL -> effect. Takes over from the tune or any effect already playing.
sfx:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (scount),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sdelta),de
        ld a,(hl)
        inc hl
        ld (smask),a
        ld a,(hl)
        inc hl
        ld (sfld),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (snext),de
        ld a,0x36               ; counter 0, low then high byte, square wave
        ld (0xE007),a
        ld hl,(scount)
        call swrite
        ld a,1
        ld (sact),a
        ld (0xE008),a
        ret

swrite: ld a,l
        ld (0xE004),a
        ld a,h
        ld (0xE004),a
        ret

; every drawn column: fresh noise on the playing effect
sndtick:
        ld a,(smask)
        or a
        ret z
        ld b,a
        call rnd
        and b
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(scount)
        add hl,de
        jr swrite

; once a frame, from timers: run the effect for lastf fields, or the tune when nothing else is playing
sndframe:
        ld a,(sact)
        or a
        jr z,tune
        ld hl,lastf
        ld a,(sfld)
        sub (hl)
        jr z,sf_next
        jr c,sf_next
        ld (sfld),a
        ld b,(hl)
        ld hl,(scount)
        ld de,(sdelta)
sf1:    add hl,de
        djnz sf1
        ld (scount),hl
        jr swrite
sf_next:
        ld hl,(snext)
        ld a,h
        or l
        jr nz,sfx
sndoff: xor a
        ld (sact),a
        ld (smask),a
        ld (mdink),a
        ld (0xE008),a
        ret

tune:   ld a,(tuneon)           ; only during play (and the demo)
        or a
        ret z
        ld a,(mdink)            ; end of a dink
        or a
        jr z,tu1
        ld hl,lastf
        sub (hl)
        jr nc,tu0
        xor a
tu0:    ld (mdink),a
        jr nz,tu1
        ld (0xE008),a
tu1:    ld hl,lastf
        ld a,(musict)
        add a,(hl)
        ld (musict),a
        cp MUSP
        ret c
        sub MUSP
        ld (musict),a
tu2:    ld hl,(gtptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (gtptr),hl
        ld a,d
        cp 0xFF
        jr nz,tu3
        ld hl,GTUNE
        ld (gtptr),hl
        jr tu2
tu3:    or e
        ret z                   ; a rest
        ex de,hl
        ld a,0x36
        ld (0xE007),a
        call swrite
        ld a,1
        ld (0xE008),a
        ld a,3
        ld (mdink),a
        ret

; play an effect to the end with nothing else going on (jingles on the death and win pages)
sndwait:
        call sfx
sw1:    ld a,1
        ld (lastf),a
        ld hl,(fields)
sw2:    call poll
        call sndtick
        ld de,(fields)
        or a
        sbc hl,de
        add hl,de
        jr z,sw2
        call sndframe
        ld a,(sact)
        or a
        jr nz,sw1
        ret

rnd:    push bc
        ld a,(seed)
        ld b,a
        add a,a
        add a,a
        add a,b
        inc a
        ld (seed),a
        rrca
        rrca
        rrca
        xor b
        pop bc
        ret

; ---- screen flashes: A = sky colour, C = frames
flash:  ld (d1_cl+1),a
        ld (d2_cl+1),a
        ld (d2_cl+4),a
        ld a,c
        ld (flasht),a
        ret
flashend:
        ld a,(flasht)
        or a
        ret z
        dec a
        ld (flasht),a
        ret nz
        ld a,(skycol)
        ld c,0
        jr flash

; ---- exploding pieces: 32 of them, each one colour cell, in screen space
; piece (8 bytes): x (8.8 columns), y (8.8 rows), vx, vy (signed, 1/32 cell per field), colour, life (fields)

; B pieces from (pcx, pcy), spread (pspr) wide, colours from the four at (pcolp)
spawnp: ld a,(pnext)
        inc a
        and 31
        ld (pnext),a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,PART>>8
        push hl
        pop ix
        call rnd
        ld (ix+0),a
        ld a,(pcx)
        ld (ix+1),a
        call rnd
        ld (ix+2),a
        call rnd                ; start somewhere in the middle half of the body
        and 3
        ld c,a
        ld a,(pcy)
        add a,c
        sub 2
        ld (ix+3),a
        call rnd                ; sideways: -spread/2 .. +spread/2
        ld c,a
        ld a,(pspr)
        and c
        ld c,a
        ld a,(pspr)
        srl a
        neg
        add a,c
        ld (ix+4),a
        call rnd                ; upwards
        and 15
        add a,8
        neg
        ld (ix+5),a
        call rnd
        and 3
        ld e,a
        ld d,0
        ld hl,(pcolp)
        add hl,de
        ld a,(hl)
        ld (ix+6),a
        call rnd
        and 15
        add a,30
        ld (ix+7),a
        djnz spawnp
        ret

; move every piece by lastf fields and file it under the ray that draws its column
parts:  ld hl,PHEAD
        ld de,PHEAD+1
        ld bc,39
        ld (hl),0
        ldir
        ld ix,PART
        ld c,0
pt_l:   ld a,(ix+7)
        or a
        jp z,pt_n
        ld a,(lastf)
        ld b,a
pt_f:   ld a,(ix+4)             ; x += vx*8
        call sext8
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        ld a,(ix+5)             ; y += vy*8
        call sext8
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld a,(ix+5)             ; gravity
        add a,GRAV
        jp pe,pt_g              ; (overflow: keep it)
        ld (ix+5),a
pt_g:   ld a,h                  ; hit the floor going down? bounce, losing half
        bit 7,a
        jr nz,pt_b
        cp FLOORR
        jr c,pt_b
        ld a,(ix+5)
        bit 7,a
        jr nz,pt_b
        sra a
        neg
        ld (ix+5),a
        ld a,(ix+4)
        sra a
        ld (ix+4),a
        ld (ix+2),0
        ld (ix+3),FLOORR
pt_b:   dec (ix+7)
        jr z,pt_n
        djnz pt_f
        ld a,(ix+1)             ; off the sides: gone
        cp 40
        jr c,pt_k
        ld (ix+7),0
        jr pt_n
pt_k:   ld a,(ix+3)             ; above the top: not drawn this frame
        cp VIEWH
        jr nc,pt_n
        ld a,(m_colstep)
        cp 2
        ld a,(ix+1)
        jr nz,pt_k1
        srl a
pt_k1:  ld e,a
        ld d,0
        ld hl,PHEAD
        add hl,de
        ld a,(hl)
        inc c
        ld (hl),c
        ld e,c
        dec c
        ld hl,PNEXT-1
        add hl,de
        ld (hl),a
pt_n:   ld de,8
        add ix,de
        inc c
        ld a,c
        cp 32
        jp nz,pt_l
        ret

sext8:  ld e,a                  ; A signed -> DE = A*8
        add a,a
        sbc a,a
        ld d,a
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ret

; per column, after the sprites: the pieces filed under this ray
partcol:
        ld a,(ray)
        ld e,a
        ld d,0
        ld hl,PHEAD
        add hl,de
        ld a,(hl)
        or a
        ret z
pc_l:   dec a
        ld (pidx),a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,PART>>8
        inc l
        ld c,(hl)               ; column
        inc l
        inc l
        ld a,(hl)               ; row
        inc l
        inc l
        inc l
        ld b,(hl)               ; colour
        add a,a
        ld e,a
        ld d,0
        ld hl,ROW40
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(destp)
        add hl,de
        ld a,(scol)
        ld e,a
        ld a,c
        sub e
        ld e,a
        ld d,0
        add hl,de
        ld (hl),b
        ld a,(pidx)
        ld e,a
        ld hl,PNEXT
        add hl,de
        ld a,(hl)
        or a
        jr nz,pc_l
        ret

; burst for the creature in (target): where it is on screen, how big, and its colours
burst:  ld a,(tsz)              ; spread grows with how big it looks
        ld c,15
        cp 8
        jr c,bu1
        ld c,31
        cp 16
        jr c,bu1
        ld c,63
bu1:    ld a,c
        ld (pspr),a
        ld a,(tcen)
        ld (pcx),a
        ld a,(trow)
        ld (pcy),a
        ld a,(otype)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,TYPET+11
        add hl,de
        ld (pcolp),hl
        ld de,4
        add hl,de
        ld b,(hl)
        jp spawnp
