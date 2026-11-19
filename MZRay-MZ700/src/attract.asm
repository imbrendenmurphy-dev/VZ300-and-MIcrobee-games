; ---------------------------------------------------------------- attract sequence
; Title + music, the locals introduce themselves, then a demo of a different area each time round.
; Every part returns with carry set if SPACE was pressed (start the game).

GROW    equ 1                   ; gallery sprite: rows 1-16, columns 12-27
GBACK   equ 0x11                ; on a blue backdrop

attract:
        xor a
        ld (tuneon),a
        call titlescr
        ret c
        call gallery
        ret c
        call demo
        ret c
        jr attract

; wait A fields, keeping the sound going; carry if SPACE
waitf:  ld (wcnt),a
wf0:    ld hl,(fields)
wf1:    call poll
        call sndtick
        push hl
        call getinput
        pop hl
        ld a,(inp)
        bit 6,a
        scf
        ret nz
        ld de,(fields)
        or a
        sbc hl,de
        add hl,de
        jr z,wf1
        ld a,1
        ld (lastf),a
        call sndframe
        ld hl,wcnt
        dec (hl)
        jr nz,wf0
        or a
        ret

; ---- title: the logo is a ready-made colour screen; then the music, then a moment of quiet
titlescr:
        call sndoff
        call cls
        ld hl,TSCR
        ld de,CRAM
        ld bc,TSCRLEN
        ldir
        ld hl,PG_TITLE
        call showpage
        call tmusic
        ret c
        ld a,150
        jp waitf

; three voices on one channel: each field the 8253 plays the next voice that's sounding,
; so chords come out as a fast, buzzy arpeggio
; row: bass, mid, top counts (0 = silent), fields (0 = end)
tmusic: ld hl,TMUS
tm0:    ld de,tmv
        ld bc,6
        ldir
        ld a,(hl)
        inc hl
        or a
        jr z,tm_end
        ld (tmlen),a
        ld (tmptr),hl
tm1:    ld a,(tmvi)
        ld b,3
tm2:    inc a
        cp 3
        jr c,tm3
        xor a
tm3:    ld (tmvi),a
        add a,a
        ld e,a
        ld d,0
        ld hl,tmv
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr nz,tm4
        ld a,(tmvi)
        djnz tm2
        xor a                   ; a rest
        ld (0xE008),a
        jr tm5
tm4:    ex de,hl
        ld a,0x36
        ld (0xE007),a
        call swrite
        ld a,1
        ld (0xE008),a
tm5:    ld a,1
        call waitf
        ret c
        ld hl,tmlen
        dec (hl)
        jr nz,tm1
        ld hl,(tmptr)
        jr tm0
tm_end: xor a
        ld (0xE008),a
        ret

; ---- the gallery. entry: frame 0 page, frame 1 page, text page, fanfare (all words); 0 ends
gallery:
        ld hl,GALT
ga0:    ld (gptr),hl
        ld a,(hl)
        inc hl
        or (hl)
        ret z
        call cls
        ld hl,(gptr)
        ld de,4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call showpage
        xor a
        ld (gframe),a
        call gdrawf
        ld hl,(gptr)
        ld de,6
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call sfx                ; a little ta-da
        ld b,6                  ; then show off for three seconds
gw1:    push bc
        ld a,25
        call waitf
        pop bc
        ret c
        ld a,(gframe)
        xor 1
        ld (gframe),a
        push bc
        call gdrawf
        pop bc
        djnz gw1
        ld hl,(gptr)
        ld de,8
        add hl,de
        jr ga0

gdrawf: ld hl,(gptr)
        ld a,(gframe)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        inc hl
        ld h,(hl)               ; page (sprites are page aligned)
        ld l,0
        ld de,CRAM+GROW*40+12
        ld c,0
gd_r:   ld b,16
        ld l,c
gd_c:   ld a,(hl)
        cp 0xFF
        jr nz,gd1
        ld a,GBACK
gd1:    ld (de),a
        inc de
        ld a,l
        add a,16
        ld l,a
        djnz gd_c
        push hl
        ld hl,24
        add hl,de
        ex de,hl
        pop hl
        inc c
        ld a,c
        cp 16
        jr nz,gd_r
        ret

; ---- the demo: the autopilot plays a different area each time round, everything awake
demo:   ld a,(dcycle)
        ld (dsa),a
        inc a
        cp NAREA
        jr c,de0x
        xor a
de0x:    ld (dcycle),a
        call newgame
        ld a,(dsa)
        ld (area),a
        add a,a
        ld e,a
        ld d,0
        ld hl,DEMOTAB
        add hl,de
        ld a,(hl)
        ld (entrycell),a
        inc hl
        ld a,(hl)
        ld (entryang),a
        call cls
        call hudinit
        call loadarea
        call spawn
        ld hl,OBJ
        ld b,NOBJ
dewx:    ld a,(hl)
        or a
        jr z,dew1x
        cp NENEMY+1
        jr nc,dew1x
        push hl
        ld de,6
        add hl,de
        set 7,(hl)
        pop hl
dew1x:   ld de,8
        add hl,de
        djnz dewx
        ld a,1
        ld (demo_on),a
        ld (tuneon),a
        xor a
        ld (dquit),a
        ld (aturn),a
        ld (awalk),a
        ld hl,MSG_DEMO
        call setmsg
        ld hl,DEMOFLD
        ld (dtime),hl
        ld hl,0
        ld (fields),hl
delx:    call frame
        ld a,(msgt)             ; keep the DEMO banner up
        or a
        jr nz,del1x
        ld hl,MSG_DEMO
        call setmsg
del1x:   ld a,(dquit)
        or a
        jr nz,deqx
        ld a,(hp)
        or a
        jr z,deex
        ld a,(leveldone)
        or a
        jr nz,deex
        ld hl,(dtime)
        ld a,(lastf)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (dtime),hl
        jr z,deex
        jr nc,delx
deex:    call deoffx
        or a
        ret
deqx:    call deoffx
        scf
        ret
deoffx:  xor a
        ld (demo_on),a
        ld (tuneon),a
        ld (leveldone),a
        ld (flasht),a
        ld a,(skycol)
        ld c,0
        call flash
        jp sndoff

; steer for the demo (ported from DROPBEAR): face the nearest creature in view and shoot,
; otherwise wander, walking into doors and ways out. C = input bits.
autopilot:
        ld c,0
        ld a,(aimz)
        or a
        jr z,ap3
        ld a,(aimcol)
        cp 18
        jr nc,ap1
        set 2,c
        jr ap2
ap1:    cp 23
        jr c,ap2
        set 3,c
ap2:    ld hl,(target)
        ld a,h
        or l
        ret z
        set 6,c
        ret
ap3:    ld a,(aturn)
        or a
        jr z,ap4
        xor a
        ld (awalk),a
        ld a,(aturn)
        dec a
        ld (aturn),a
        ld a,(adir)
        ld c,a
        ret
ap4:    ld a,(awalk)            ; tried to walk last time but didn't move? turn away
        ld b,a
        ld hl,(px)
        ld de,(lastpx)
        ld (lastpx),hl
        or a
        sbc hl,de
        ld a,h
        or l
        ld hl,(py)
        ld de,(lastpy)
        ld (lastpy),hl
        jr nz,ap5
        or a
        sbc hl,de
        ld a,h
        or l
        jr nz,ap5
        or b
        jr nz,ap8
ap5:    ld a,(ZB+20)            ; wall close ahead? turn to the open side
        cp 35
        jr c,ap5w
        call ahead              ; unless it's a door or a way out: walk into those
        cp 3
        jr z,ap5w
        cp 4
        jr nz,ap9
ap5w:   set 0,c
        ld a,1
        ld (awalk),a
        call rnd
        and 127
        jr z,ap8                ; now and then, wander off somewhere new
        ld a,(ZB+5)             ; drift towards the more open side
        ld b,a
        ld a,(ZB+34)
        sub b
        jr nc,ap6
        neg
        cp 4
        ret c
        set 3,c
        ret
ap6:    cp 4
        ret c
        set 2,c
        ret
ap8:    call rnd
        and 4
        jr nz,ap7
        ld a,8
        jr ap7
ap9:    ld a,(ZB+5)
        ld b,a
        ld a,(ZB+34)
        cp b
        ld a,8
        jr c,ap7
        ld a,4
ap7:    ld (adir),a
        xor a
        ld (awalk),a
        ld a,(adir)
        ld c,a
        call rnd
        and 7
        add a,6
        ld (aturn),a
        ret

; the map cell about a step and a quarter in front of us -> A
ahead:  push bc
        ld a,(pang)
        ld l,a
        ld h,COS8>>8
        ld a,(hl)
        call x25
        ld hl,(px)
        add hl,de
        ld a,h
        ld (tx),a
        ld a,(pang)
        ld l,a
        ld h,SIN8>>8
        ld a,(hl)
        call x25
        ld hl,(py)
        add hl,de
        ld a,h
        call testcell
        pop bc
        ret
x25:    ld e,a                  ; A signed (x127) -> DE = A*5/2, about 1.25 cells
        add a,a
        sbc a,a
        ld d,a
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        sra h
        rr l
        ex de,hl
        ret
