; ---------------------------------------------------------------------------
; Everything that moves in a room, drawn only when it has to be.
; Slot 0 is Wren, 1..4 robots, 5..8 their sparks.  Each frame: fill in what
; each wants to look like; an object that hasn't changed (frame, place,
; facing) and isn't touched by one that has is left alone - no erase, no
; draw, no video traffic.  The video RAM waits make this matter.
; ---------------------------------------------------------------------------
NOBJ    equ 9
OB_ON   equ 0
OB_VT   equ 1                   ; 2 bytes
OB_X    equ 3
OB_Y    equ 4
OB_H    equ 5
OB_FACE equ 6
OB_INK  equ 7
OB_DRAWN equ 8
OB_LVT  equ 9                   ; 2 bytes: as last drawn
OB_LX   equ 11
OB_LY   equ 12
OB_LFACE equ 13
OB_CH   equ 14
OB_RCX  equ 15                  ; rectangle as drawn
OB_RCY0 equ 16
OB_RCY1 equ 17
OB_NCX  equ 18                  ; rectangle wanted now
OB_NCY0 equ 19
OB_NCY1 equ 20
OB_SIZE equ 24

; Forget what's on screen (after a full redraw).
objs_reset:
        ld hl,objs
        ld de,objs+1
        ld bc,NOBJ*OB_SIZE-1
        ld (hl),0
        ldir
        ret

; Fill in every object's wanted look.
objs_gather:
        ld ix,objs              ; Wren
        ld a,(wstate)
        cp WS_DEAD
        ld a,1
        jr nz,.won
        ld a,(wtim)
        and 4
        ld a,0
        jr nz,.won
        inc a
.won:   ld (ix+OB_ON),a
        ld a,(wframe)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,wren_vt
        add hl,de
        ld (ix+OB_VT),l
        ld (ix+OB_VT+1),h
        ld a,(wx)
        ld (ix+OB_X),a
        ld a,(wy)
        ld (ix+OB_Y),a
        ld (ix+OB_H),24
        ld a,(wface)
        ld (ix+OB_FACE),a
        ld (ix+OB_INK),WREN_FG
        ld iy,robots            ; robots and sparks
        ld b,0
.r:     push bc
        ld a,b                  ; IX = robot slot 1+b
        inc a
        call obj_ptr
        ld a,(nrob)
        cp b
        ld a,0
        jr z,.roff
        jr c,.roff
        inc a
.roff:  ld (ix+OB_ON),a
        or a
        jp z,.spk
        ld a,(iy+RB_KIND)
        cp 4
        jp nc,.haz
        ld a,(iy+RB_X)
        ld (ix+OB_X),a
        ld a,(iy+RB_FLOOR)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        sub 20
        ld (ix+OB_Y),a
        ld (ix+OB_H),20
        ld a,(iy+RB_DIR)
        ld (ix+OB_FACE),a
        ld a,(iy+RB_KIND)       ; this kind's ten frames: kind * 10 + n
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a
        ld e,a
        ld hl,(sleep_t)
        ld a,h
        or l
        ld a,9                  ; asleep
        ld c,$0C
        jr nz,.fr
        ld a,(iy+RB_KIND)       ; its colour
        ld hl,rb_inks
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)
        ld a,(iy+SP_ON)         ; just fired: its firing pose
        or a
        jr z,.mv
        ld a,(iy+SP_LIFE)
        cp ZAP_LIFE-3
        ld a,8
        jr nc,.fr
.mv:    ld a,(iy+RB_KIND)       ; drones hover and turrets sweep even standing still
        cp 2
        ld a,(iy+RB_ANIM)
        jr c,.an
        ld a,(frames)
        rrca
.an:    rrca
        and 7
.fr:    add a,e
        ld (ix+OB_INK),c
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,robot_vt
        add hl,de
        ld (ix+OB_VT),l
        ld (ix+OB_VT+1),h
        jr .spk
.haz:   ld a,(iy+RB_DIR)        ; a hazard: seen only while it fires
        ld (ix+OB_ON),a
        or a
        jr z,.spk
        ld a,(iy+RB_X)
        ld (ix+OB_X),a
        ld a,(iy+RB_FLOOR)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        sub 24
        ld (ix+OB_Y),a
        ld (ix+OB_H),24
        ld (ix+OB_FACE),0
        ld a,(iy+RB_KIND)       ; frame: (kind-4)*2 + flicker
        sub 4
        ld c,$0F                ; steam white, laser bright red
        jr z,.hk
        ld c,$09
.hk:    ld (ix+OB_INK),c
        add a,a
        ld c,a
        ld a,(frames)
        rrca
        rrca
        and 1
        add a,c
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,hazard_vt
        add hl,de
        ld (ix+OB_VT),l
        ld (ix+OB_VT+1),h
.spk:   pop bc
        push bc
        ld a,b                  ; IX = spark slot 5+b
        add a,5
        call obj_ptr
        ld a,(nrob)
        cp b
        ld a,0
        jr z,.soff
        jr c,.soff
        ld a,(iy+SP_ON)
.soff:  ld (ix+OB_ON),a
        or a
        jr z,.n
        ld a,(iy+SP_X)
        ld (ix+OB_X),a
        ld a,(iy+SP_Y)
        ld (ix+OB_Y),a
        ld (ix+OB_H),6
        ld a,(iy+SP_DIR)
        ld (ix+OB_FACE),a
        ld (ix+OB_INK),$0B
        ld a,(frames)
        and 1
        ld hl,spark_vt
        jr z,.sg
        ld hl,spark_vt+3
.sg:    ld (ix+OB_VT),l
        ld (ix+OB_VT+1),h
.n:     ld de,RB_SIZE
        add iy,de
        pop bc
        inc b
        ld a,b
        cp MAXROB
        jp nz,.r
        ret

; IX = object A.
obj_ptr:
        push de
        ld ix,objs
        or a
        jr z,.d
        ld de,OB_SIZE
.a:     add ix,de
        dec a
        jr nz,.a
.d:     pop de
        ret

; Decide, erase, draw.  Call after the logic, before present.
; force (A <> 0): everything is redrawn (a pad moved, or a fresh screen).
objs_frame:
        ld (of_force),a
        call objs_gather
        ld ix,objs              ; 1: what changed, and where it wants to be
        ld b,NOBJ
.c:     push bc
        ld (ix+OB_CH),0
        ld a,(ix+OB_ON)
        or a
        jr z,.off
        ld a,(ix+OB_X)          ; new rectangle
        ld (d_x),a
        ld a,(ix+OB_Y)
        ld (d_y),a
        ld a,(ix+OB_H)
        ld (d_h),a
        call spr_rect
        ld a,(d_rcx)
        ld (ix+OB_NCX),a
        ld a,(d_rcy0)
        ld (ix+OB_NCY0),a
        ld a,(d_rcy1)
        ld (ix+OB_NCY1),a
        ld a,(of_force)
        or a
        jr nz,.ch
        ld a,(ix+OB_DRAWN)
        or a
        jr z,.ch
        ld a,(ix+OB_VT)
        cp (ix+OB_LVT)
        jr nz,.ch
        ld a,(ix+OB_VT+1)
        cp (ix+OB_LVT+1)
        jr nz,.ch
        ld a,(ix+OB_X)
        cp (ix+OB_LX)
        jr nz,.ch
        ld a,(ix+OB_Y)
        cp (ix+OB_LY)
        jr nz,.ch
        ld a,(ix+OB_FACE)
        cp (ix+OB_LFACE)
        jr nz,.ch
        jr .nx
.off:   ld a,(ix+OB_DRAWN)      ; going away: that's a change
        or a
        jr z,.nx
.ch:    ld (ix+OB_CH),1
.nx:    ld de,OB_SIZE
        add ix,de
        pop bc
        djnz .c
        ld a,2                  ; 2: anything touching a change changes too
        ld (of_pass),a
.pass:  ld ix,objs
        ld b,NOBJ
.p:     push bc
        ld a,(ix+OB_CH)
        or a
        jr nz,.pn
        ld a,(ix+OB_DRAWN)
        or a
        jr z,.pn
        call touches_change
        jr nc,.pn
        ld (ix+OB_CH),1
.pn:    ld de,OB_SIZE
        add ix,de
        pop bc
        djnz .p
        ld hl,of_pass
        dec (hl)
        jr nz,.pass
        ld ix,objs              ; 3: erase the old places of what changed
        ld b,NOBJ
.e:     push bc
        ld a,(ix+OB_CH)
        or a
        jr z,.en
        ld a,(ix+OB_DRAWN)
        or a
        jr z,.en
        ld (ix+OB_DRAWN),0
        ld b,(ix+OB_RCY0)
        ld c,(ix+OB_RCY1)
        ld a,(ix+OB_RCX)
        call erase_rect
.en:    ld de,OB_SIZE
        add ix,de
        pop bc
        djnz .e
        call pads_draw
        ld ix,objs+OB_SIZE      ; 4: draw robots and sparks, then Wren on top
        ld b,NOBJ-1
.d:     push bc
        call obj_draw
        ld de,OB_SIZE
        add ix,de
        pop bc
        djnz .d
        ld ix,objs
        jp obj_draw

obj_draw:
        ld a,(ix+OB_CH)
        or a
        ret z
        ld a,(ix+OB_ON)
        or a
        ret z
        ld a,(ix+OB_X)
        ld (d_x),a
        ld (ix+OB_LX),a
        ld a,(ix+OB_Y)
        ld (d_y),a
        ld (ix+OB_LY),a
        ld a,(ix+OB_H)
        ld (d_h),a
        ld a,(ix+OB_FACE)
        ld (d_face),a
        ld (ix+OB_LFACE),a
        ld a,(ix+OB_INK)
        ld (d_ink),a
        ld l,(ix+OB_VT)
        ld h,(ix+OB_VT+1)
        ld (d_vt),hl
        ld (ix+OB_LVT),l
        ld (ix+OB_LVT+1),h
        ld a,(ix+OB_NCX)
        ld (d_rcx),a
        ld (ix+OB_RCX),a
        ld a,(ix+OB_NCY0)
        ld (d_rcy0),a
        ld (ix+OB_RCY0),a
        ld a,(ix+OB_NCY1)
        ld (d_rcy1),a
        ld (ix+OB_RCY1),a
        ld (ix+OB_DRAWN),1
        jp spr_draw

; Carry if object IX's drawn rectangle meets the old or new rectangle of
; any changed object.
touches_change:
        ld iy,objs
        ld b,NOBJ
.o:     push bc
        ld a,(iy+OB_CH)
        or a
        jr z,.n
        ld a,(iy+OB_DRAWN)      ; its old place
        or a
        jr z,.new
        ld d,(iy+OB_RCX)
        ld e,(iy+OB_RCY0)
        ld c,(iy+OB_RCY1)
        call rect_meet
        jr c,.yes
.new:   ld a,(iy+OB_ON)
        or a
        jr z,.n
        ld d,(iy+OB_NCX)
        ld e,(iy+OB_NCY0)
        ld c,(iy+OB_NCY1)
        call rect_meet
        jr c,.yes
.n:     ld de,OB_SIZE
        add iy,de
        pop bc
        djnz .o
        or a
        ret
.yes:   pop bc
        scf
        ret

; Carry if (column D, rows E..C) meets IX's drawn rectangle (4 columns wide).
rect_meet:
        ld a,(ix+OB_RCX)        ; columns: |D - rcx| < 4
        sub d
        jr nc,.p
        neg
.p:     cp 4
        ret nc
        ld a,c                  ; rows: E <= rcy1 and rcy0 <= C
        cp (ix+OB_RCY0)
        jr c,.no
        ld a,(ix+OB_RCY1)
        cp e
        jr c,.no
        scf
        ret
.no:    or a
        ret
rb_inks: db $09,$0B,$0D,$0E       ; patrol red, zapper yellow, hunter magenta, sentry cyan
