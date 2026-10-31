;=====================================================================
; CHAPTER VIII - REBIRTH   and   CHAPTER IX - SILENCE
;=====================================================================
C8_BAR  equ 130
C8_DUR  equ 2048
C9_BAR  equ 146
C9_DUR  equ 2176
EP_T0   equ 1320            ; face reappears
EP_T1   equ 1620            ; back to the end screen
EP_STARTLE equ 150          ; frames into the epilogue

ch_rebirth:
        xor a
        call setmode
        xor a
        call setfade
        call initstars
        ld a,C8_BAR
        call chbegin
.loop:  call ltime
        ld (T),hl
        ld de,C8_DUR
        or a
        sbc hl,de
        ret nc
        ld hl,(T)
        ld de,640
        or a
        sbc hl,de
        jr nc,.space
        ; ---- burst of luminous colour (cell plasma), dissolving
        call plasma
        ld hl,(T)
        ld de,520
        or a
        sbc hl,de
        ld a,0
        jr c,.pf
        ld a,l
        rrca
        rrca
        rrca
        rrca
        rrca
        and 7
        cp 4
        jr c,.pf
        ld a,4
.pf:    call setfade
        call pcopyf
        jp .loop
.space: ; ---- the new sky: sun, planet curve, stars, transformed entity
        ld (Q),hl               ; q = t-640 (0..1407)
        xor a
        call cclear
        ; star count shrinks in the last part
        ld a,NSTARS
        ld hl,(Q)
        ld de,1000
        or a
        sbc hl,de
        jr c,.ns
        ld a,l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,NSTARS
        sub l
        jr nc,.ns
        xor a
.ns:    ld (NSTV),a
        ld a,1
        ld (SSPD),a
        ld a,32
        ld (SCX),a
        ld a,14
        ld (SCY),a
        ld a,(NSTV)
        or a
        call nz,drawstars2
        ; the sun / nebula: rings pulsing with the music
        call newsun
        ; planet curvature rising at the bottom
        ld hl,(Q)
        ld c,48
        call div16_8
        cp 13
        jr c,.pl
        ld a,13
.pl:    ld b,a
        ld a,84
        sub b
        ld e,a
        ld (PLY),a
        ld d,30
        ld b,47
        ld c,6
        call disc               ; cyan atmosphere rim
        ld a,(PLY)
        ld e,a
        ld d,30
        ld b,46
        ld c,3
        call disc               ; the planet's night side
        ; transformed entity, drifting, finally fading
        call ent8
        ; fade in from the burst, out at the end
        ld hl,(Q)
        ld a,h
        or a
        jr nz,.f1
        ld a,l
        cp 80
        jr nc,.f1
        rrca
        rrca
        rrca
        rrca
        and 7
        ld b,a
        ld a,4
        sub b
        jr nc,.fs
        xor a
.fs:    call setfade
        jr .sh
.f1:    ld hl,(Q)
        ld de,1330
        or a
        sbc hl,de
        ld a,0
        jr c,.fs2
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 15
        cp 4
        jr c,.fs2
        ld a,4
.fs2:   call setfade
.sh:    call present
        jp .loop

; copy with fade: plasma writes cells directly; apply FADE masks on copy
pcopyf: ld hl,CHUNKY
        ld a,(FADEA)
        ld c,a
        ld a,(FADEB)
        ld b,a
        ld d,16
.r:     ld e,32
.c:     ld a,(hl)
        and c
        ld (hl),a
        ld a,c
        ld c,b
        ld b,a
        inc hl
        dec e
        ld a,e
        and 7
        jr nz,.nt
        TICK
.nt:    ld a,e
        or a
        jr nz,.c
        ld a,c
        ld c,b
        ld b,a
        push bc
        ld bc,32
        add hl,bc
        pop bc
        dec d
        jr nz,.r
        jp pcopy

; plasma straight into cells: v = S[x*5+t] + S[y*9-t*2] + S[(x+y)*3+t*3]
plasma: ld a,(T)
        ld (PT1),a
        add a,a
        neg
        ld (PT2),a
        ld a,(T)
        ld b,a
        add a,a
        add a,b
        ld (PT3),a
        ld b,0                  ; y
.row:   ld a,b
        rrca
        rrca
        ld l,a
        and $3F
        add a,CHUNKY>>8
        ld h,a
        ld a,l
        and $C0
        ld l,a
        ld c,0                  ; x
.cell:  push hl
        ld a,c
        add a,a
        add a,a
        add a,c
        ld hl,PT1
        add a,(hl)
        call sin8
        sra a
        ld e,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,b
        ld hl,PT2
        add a,(hl)
        call sin8
        sra a
        add a,e
        ld e,a
        ld a,c
        add a,b
        ld d,a
        add a,a
        add a,d
        ld hl,PT3
        add a,(hl)
        call sin8
        sra a
        add a,e                 ; -190..190 wraps fine
        ld e,a
        rrca
        rrca
        rrca
        rrca
        and 15
        ld hl,PLPAL
        add a,l
        ld l,a
        jr nc,.p1
        inc h
.p1:    ld d,(hl)
        ld a,e
        and 12
        rrca
        rrca
        ld hl,PLPAT
        add a,l
        ld l,a
        jr nc,.p2
        inc h
.p2:    ld a,(hl)
        or d
        pop hl
        ld (hl),a
        inc l
        ld a,c
        and 1
        jr nz,.nt
        TICK
.nt:    inc c
        ld a,c
        cp 32
        jr nz,.cell
        inc b
        ld a,b
        cp 16
        jp nz,.row
        ret

PLPAL:  db $C0,$90,$F0,$B0,$E0,$A0,$D0,$C0,$90,$80,$D0,$E0,$F0,$90,$C0,$D0
PLPAT:  db $0F,$0F,$0E,$0B

; the new sun: concentric discs, breathing with the motif voice
newsun: ld a,(DUTY2)
        rrca
        rrca
        rrca
        rrca
        and 3
        ld (SUNP),a
        ld hl,SUNRING
.l:     ld a,(hl)
        cp $FF
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ld a,(SUNP)
        add a,b
        ld b,a
        ; shrink in the last part
        ld hl,(Q)
        ld de,1100
        or a
        sbc hl,de
        jr c,.n
        ld a,l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,b
        sub l
        jr nc,.ok
        xor a
.ok:    ld b,a
        or a
        jr z,.sk
.n:     ld d,32
        ld e,12
        call disc
.sk:    pop hl
        jr .l
SUNRING: db 13,7, 10,4, 8,8, 5,2, 3,5, $FF

; the entity, transformed: larger glow, slowly ascending, fading at last
ent8:   ld hl,(Q)
        ld de,1250
        or a
        sbc hl,de
        jr c,.v
        ld a,l
        cp 100
        ret nc                  ; gone
        rrca
        rrca
        rrca
        rrca
        rrca
        and 3
        ld b,a
        ld a,3
        sub b
        jr .p
.v:     ld a,3
.p:     ld (E8S),a
        ld a,(Q)
        call sin8
        sra a
        sra a
        sra a
        add a,32
        ld d,a
        ld hl,(Q)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,20
        sub l
        jr nc,.y
        xor a
.y:     ld e,a
        ld a,(E8S)
        call entity
        ; extra halo of colour
        ld a,(E8S)
        cp 3
        ret nz
        ld b,6
.h:     push bc
        call rnd
        and 7
        sub 4
        ld hl,ENTX
        add a,(hl)
        ld d,a
        call rnd
        and 7
        sub 4
        ld hl,ENTY
        add a,(hl)
        ld e,a
        call rnd
        and 7
        inc a
        call pset
        pop bc
        djnz .h
        ret

; starfield with variable count (NSTV)
drawstars2:
        ld a,(NSTV)
        ld b,a
        ld ix,STARS
        jp drawstars.l

;=====================================================================
ch_silence:
        xor a
        call setmode
        ld a,4
        call setfade
        ld a,C9_BAR
        call chbegin
.loop:  call ltime
        ld (T),hl
        ld de,C9_DUR
        or a
        sbc hl,de
        ret nc
        ld hl,(T)
        ld de,EP_T0
        or a
        sbc hl,de
        jr c,.pre
        ld de,EP_T1-EP_T0
        or a
        sbc hl,de
        jp nc,.post
        call ep_face            ; the face returns (runs until EP_T1)
        jp .loop
.post:  ; the end screen again, then a slow fade into darkness
        xor a
        call cclear
        call drawtitle
        ld hl,(T)
        ld de,2020
        or a
        sbc hl,de
        ld a,0
        jr c,.pf
        ld a,h
        or a
        ld a,4
        jr nz,.pf
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 15
        cp 4
        jr c,.pf
        ld a,4
.pf:    call setfade
        call present
        jp .loop
.pre:   xor a
        call cclear
        ld hl,(T)
        ld de,760
        or a
        sbc hl,de
        jr nc,.title
        ; heartbeat: a faint pulse of light in the dark
        xor a
        call setfade
        ld a,(DUTY1)
        or a
        jp z,.show
        cp 60
        ld a,4
        jr c,.dim
        ld a,7
.dim:   ld d,32
        ld e,15
        call pset
        ld a,(DUTY1)
        cp 90
        jr c,.show
        ld a,4
        ld d,31
        call pset
        ld d,33
        call pset
        ld d,32
        dec e
        call pset
        inc e
        inc e
        call pset
        jr .show
.title: ; title and credits fade in and linger
        ld (Q),hl
        call drawtitle
        ; fade level
        ld hl,(Q)
        ld a,h
        or a
        jr nz,.t2
        ld a,l
        cp 160
        jr nc,.t2
        rrca
        rrca
        rrca
        rrca
        rrca
        and 7
        ld b,a
        ld a,4
        sub b
        jr nc,.tf
        xor a
        jr .tf
.t2:    xor a
.tf:    call setfade
.show:  call present
        jp .loop

drawtitle:
        ld hl,TXT1
        ld d,6
        ld e,5
        call text
        ld hl,TXT2
        ld d,10
        ld e,15
        call text
        ld hl,TXT3
        ld d,12
        ld e,22
        jp text

;---------------------------------------------------------------------
; EPILOGUE: the face, resting in the dark as at the beginning, breathing.
; A heartbeat, another - then it wakes with a startle: eyes snap open,
; the head jerks up toward us, the palette flashes, the breath races.
ep_face:
        ; pre-fill the part of VRAM mode(0) doesn't show, so the switch is clean
        ld hl,VRAM+512
        ld c,48
.cl:    ld b,32
.cb:    ld (hl),$AA
        inc hl
        djnz .cb
        TICK
        dec c
        jr nz,.cl
        ld a,$AA
        ld (BGCOL),a
        ld hl,nohook
        ld (HEXTRA),hl
        ld (HPOST),hl
        xor a
        ld (NOFIG),a
        ld (EYES),a
        ld (HEADYAW),a
        ld (BREATH),a
        ld (GHOST),a
        ld a,1
        ld (FEATON),a
        ld a,$08
        ld (PMODE),a            ; switch to mode(1) as the first frame lands
        ld a,(K_LY+9)           ; camera on the head
        ld (CAMTX),a
        ld a,(K_LY+10)
        ld (CAMTY),a
        ld a,(K_LY+11)
        ld (CAMTZ),a
.loop:  call ltime
        ld (T),hl
        ld de,EP_T1
        or a
        sbc hl,de
        jp nc,.done
        add hl,de
        ld de,EP_T0
        or a
        sbc hl,de
        ld (Q),hl               ; frames into the epilogue
        ld hl,K_LY
        ld a,N_LY
        ld de,0
        call animate
        ld hl,(Q)
        ld de,EP_STARTLE
        or a
        sbc hl,de
        jr nc,.awake
        ; ---- asleep: slow breath, a slow drift and push-in
        call breathe
        ld a,(Q)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,248
        ld (YAW),a
        ld a,60
        ld (PITCH),a
        ld hl,(Q)
        ld de,1060
        add hl,de
        ld (ZOOM),hl
        xor a
        ld (EYES),a
        ld (HEADYAW),a
        jp .draw
.awake: ; ---- the startle. k = frames since; d = 32-k (decay, >= 0)
        ld a,h
        or a
        ld a,32
        jr nz,.k2
        ld a,l
        cp 32
        jr c,.k1
        ld a,32
.k1:
.k2:    ld b,a
        ld a,32
        sub b
        ld (EPD),a
        ld a,1
        ld (EYES),a
        ; head jerks up off the ground (and the neck with it)
        ld a,(EPD)
        rrca
        rrca
        rrca
        and 7
        add a,4                 ; lift 4..8
        ld b,a
        ld a,(CURJ+10)
        add a,b
        ld (CURJ+10),a
        srl b
        ld a,(CURJ+7)
        add a,b
        ld (CURJ+7),a
        ; head turns sharply, settling partly back
        ld a,(EPD)
        rrca
        rrca
        and 15
        add a,10
        ld (HEADYAW),a
        ; camera jolt toward the face, with a shake while d > 0
        ld a,(EPD)
        ld e,a
        ld a,6
        call mulu
        ld de,1210
        add hl,de
        ld (ZOOM),hl
        ld a,60
        ld (PITCH),a
        ld a,9
        ld (YAW),a
        ld a,(EPD)
        or a
        jr z,.ns
        call rnd
        and 7
        sub 4
        ld hl,PITCH
        add a,(hl)
        ld (hl),a
        call rnd
        and 3
        sub 2
        ld hl,YAW
        add a,(hl)
        ld (hl),a
.ns:    ; racing breath
        ld a,(T)
        add a,a
        add a,a
        add a,a
        call sin8
        sra a
        sra a
        sra a
        sra a
        ld (BREATH),a
        ; palette flash at the moment of waking
        ld a,(PMODE)
        or a
        jr nz,.draw
        ld a,(EPD)
        cp 20
        ld a,$18
        jr nc,.fm
        ld a,$08
.fm:    ld hl,MODEB
        cp (hl)
        call nz,setmode
.draw:  call featauto
        call hrender
        jp .loop
.done:  ; back to the end screen: black first, then mode(0)
        call waitvb
        xor a
        call setmode
        ld hl,VRAM
        ld c,16
.bl:    ld b,32
.bb:    ld (hl),$80
        inc hl
        djnz .bb
        TICK
        dec c
        jr nz,.bl
        xor a
        call setfade
        ret

; draw string HL at (D,E): bytes = char codes; $01-$08 set colour; 0 ends
text:   ld c,2
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        cp 9
        jr nc,.ch
        ld c,a
        jr .l
.ch:    push hl
        sub 32
        ld l,a
        ld h,0
        ld b,h
        push de
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; *5
        ld de,FONT
        add hl,de
        pop de
        ld b,5
.r:     push bc
        ld a,(hl)
        inc hl
        push hl
        push de
        ld b,3
.px:    bit 2,a
        jr z,.n
        push af
        ld a,c
        call pset
        pop af
.n:     add a,a
        inc d
        djnz .px
        pop de
        pop hl
        inc e
        TICK
        pop bc
        djnz .r
        ld a,e
        sub 5
        ld e,a
        ld a,d
        add a,4
        ld d,a
        pop hl
        TICK
        jr .l

TXT1:   db 2,"TRANS",8,"C",2,"ENDENCE",0
TXT2:   db 6,"BPM / VIBED",0
TXT3:   db 3,"VZ300 ",7,"2026",0
