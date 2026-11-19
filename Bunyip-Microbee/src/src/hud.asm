; ==========================================================================
; hud.asm - text, the status lines, messages, the map, beeper sound
;   VIBED BY BPM 2026
; ==========================================================================

ROW_TOP equ 0
ROW_ST  equ 23
ROW_MSG equ 24

; --------------------------------------------------------------------------
; print: zero-terminated text at HL -> screen offset DE, ink B, both pages
; --------------------------------------------------------------------------
print:  ld b,CWHITE
printc: ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        call putch
        pop hl
        inc de
        jr printc

; putch: character A at offset DE, ink B, both pages (keeps BC, DE)
putch:  sub 32
        ld l,a
        ld h,0
        push bc
        ld bc,FMAP
        add hl,bc
        pop bc
        ld a,(hl)
; putcode: font code A at offset DE, ink B, both pages (keeps BC, DE)
putcode:
        ld hl,VRAM
        add hl,de
        ld (hl),a
        set 2,h                 ; + 400h: page 1
        ld (hl),a
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld (hl),FONT_BANK
        res 2,h
        ld (hl),FONT_BANK
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        set 3,h                 ; colour RAM at F800
        ld (hl),b
        set 2,h
        ld (hl),b
        xor a
        out (PORT_08),a
        ret

; spaces: B = count of blanks from offset DE (both pages)
spaces: push bc
        ld a,' '
        ld b,CWHITE
        call putch
        inc de
        pop bc
        djnz spaces
        ret

; prnum: HL = number -> 5 digits (A = 5) or 2 digits (A = 2) at DE, ink B
prnum:  push bc
        ld ix,NUMBUF
        cp 2
        jr z,.two
        ld bc,-10000
        call .d
        ld bc,-1000
        call .d
        ld bc,-100
        call .d
.two    ld bc,-10
        call .d
        ld a,l
        add a,'0'
        ld (ix+0),a
        ld (ix+1),0
        pop bc
        ld hl,NUMBUF
        jp printc
.d      ld a,'0'-1
.dl     inc a
        add hl,bc
        jr c,.dl
        sbc hl,bc
        ld (ix+0),a
        inc ix
        ret

; addscore: score += DE
addscore:
        ld hl,(score)
        add hl,de
        jr nc,.s
        ld hl,65535
.s      ld (score),hl
        ld a,1
        ld (hud_dirty),a
        ret

; div16: BC = HL / DE (unsigned)
div16:  ld a,h
        ld c,l
        ld hl,0
        ld b,16
.l      sla c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,.ok
        add hl,de
        jr .n
.ok     inc c
.n      djnz .l
        ld b,a
        ret

; cls: every cell of both pages blank, ink B
cls:    ld a,b
        ld (clsink),a
        ld hl,VRAM
        ld bc,2047
        ld a,128
        call fillv
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,VRAM
        ld bc,2047
        ld a,FONT_BANK
        call fillv
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        ld hl,PCGWIN
        ld bc,2047
        ld a,(clsink)
        call fillv
        xor a
        out (PORT_08),a
        ret

; --------------------------------------------------------------------------
; HUD
; --------------------------------------------------------------------------
hud_all:
        ld de,ROW_TOP*40
        ld b,40
        call spaces
        ld hl,T_ZONE
        ld de,ROW_TOP*40
        ld b,CYELLOW
        call printc
        ld a,(zone)
        add a,'1'
        call putch
        ld de,ROW_TOP*40+7
        ld hl,ZH+(Z_NAME-400h)
        ld b,CYELLOW
        call printc
        ld de,ROW_ST*40
        ld b,80
        call spaces
        call hud_status
        jp msg_clear

; hud_status: health, charges, keys, opals, score
hud_status:
        xor a
        ld (hud_dirty),a
        ld de,ROW_ST*40
        ld a,'>'
        ld b,CBRED
        call putch
        inc de
        ; the health bar: 10 cells of 10
        ld a,(health)
        ld c,a
        ld b,CBGREEN
        cp 51
        jr nc,.ink
        ld b,CYELLOW
        cp 26
        jr nc,.ink
        ld b,CBRED
.ink    ld a,(hurtt)
        or a
        jr z,.i2
        ld b,CWHITE
.i2     ld a,10
.bar    push af
        ld a,c
        sub 10
        jr c,.part
        ld c,a
        ld a,'#'
        jr .put
.part   add a,10
        ld c,0
        cp 5
        ld a,'%'
        jr nc,.put
        ld a,'_'
.put    call putch
        inc de
        pop af
        dec a
        jr nz,.bar
        ; charges
        ld de,ROW_ST*40+13
        ld a,'|'
        ld b,CBCYAN
        call putch
        inc de
        ld a,(charges)
        ld l,a
        ld h,0
        ld a,(pwrt+1)           ; yellow while the Southern Cross lasts
        ld b,a
        ld a,(pwrt)
        or b
        ld b,CWHITE
        jr z,.pw
        ld b,CYELLOW
.pw     ld a,2
        call prnum
        ; keys
        ld de,ROW_ST*40+18
        ld hl,KINKS
        ld a,(keys)
        ld c,a
        ld a,3
.k      push af
        ld b,CDGREY
        srl c
        jr nc,.kn
        ld b,(hl)
.kn     inc hl
        push hl
        push bc
        ld a,'<'
        call putch
        pop bc
        pop hl
        inc de
        pop af
        dec a
        jr nz,.k
        ; opals
        ld de,ROW_ST*40+23
        ld a,'@'
        ld b,CBMAG
        call putch
        inc de
        ld a,(opals)
        ld l,a
        ld h,0
        ld a,2
        ld b,CWHITE
        call prnum
        ; score
        ld de,ROW_ST*40+29
        ld hl,T_SCORE
        ld b,CGREY
        call printc
        ld hl,(score)
        ld de,ROW_ST*40+35
        ld a,5
        ld b,CWHITE
        jp prnum
KINKS:  db CYELLOW,CBBLUE,CBRED

; message: A = message number -> row 24 for a few seconds
message:
        ld (msgid),a
        ld a,150
        ld (msgt),a
        ld de,ROW_MSG*40
        ld b,40
        call spaces
        ld a,(msgid)
        cp MSG_HINT
        ld hl,ZH+(Z_HINT-400h)
        jr z,.p
        add a,a
        ld l,a
        ld h,0
        ld de,MSGS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.p      ld de,ROW_MSG*40
        ld b,CWHITE
        jp printc

; hud_tick: every frame: the status line if it changed, the message timer,
;           the guardian's health while it fights
hud_tick:
        ld a,(hurtt)
        or a
        jr z,.h
        ld hl,nstep
        sub (hl)
        jr nc,.h0
        xor a
.h0     ld (hurtt),a
        jr nz,.h1
        inc a
        ld (hud_dirty),a        ; back to its own colour
        jr .h
.h1     ld a,1
        ld (hud_dirty),a
.h      ld a,(hud_dirty)
        or a
        call nz,hud_status
        ld a,(msgt)
        or a
        jr z,boss_bar
        ld hl,nstep
        sub (hl)
        jr nc,.m
        xor a
.m      ld (msgt),a
        ret nz
msg_clear:
        xor a
        ld (msgt),a
        ld (bossbar),a
        ld de,ROW_MSG*40
        ld b,40
        jp spaces
; boss_bar: the guardian's health while it is fighting you
boss_bar:
        call find_boss
        ret nz
        ld a,(ix+E_ST)
        cp ST_CHASE
        jr z,.b
        cp ST_PAIN
        ret nz
.b      ld a,(ix+E_HP)
        ld hl,bossbar
        cp (hl)
        ret z
        ld (hl),a
        ld de,ROW_MSG*40
        ld hl,T_GUARD
        ld b,CBRED
        call printc
        ; 20 cells: hp * 20 / hp0
        ld a,(bossbar)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; * 20
        ld a,(bosshp0)
        ld e,a
        ld d,0
        call div16
        ld a,c
        or a
        jr nz,.nz
        inc c                   ; a sliver while it lives
.nz     ld de,ROW_MSG*40+12
        ld b,20
.bb     push bc
        ld a,c
        or a
        ld a,'_'
        ld b,CDGREY
        jr z,.bp
        ld a,'#'
        ld b,CBRED
.bp     call putch
        inc de
        pop bc
        ld a,c
        or a
        jr z,.be
        dec c
.be     djnz .bb
        ret

; find_boss: IX = the living guardian, Z if found
find_boss:
        ld ix,ENT
        ld b,NENT
        ld de,ESIZE
.l      ld a,(ix+E_TYPE)
        cp T_BOSS
        ret z
        add ix,de
        djnz .l
        or 1
        ret

T_ZONE:  db "ZONE ",0
T_SCORE: db "SCORE",0
T_GUARD: db "GUARDIAN",0

MSG_NEEDG equ 0
MSG_NEEDB equ 1
MSG_NEEDR equ 2
MSG_GATE equ 3
MSG_BGATE equ 4
MSG_SECRET equ 5
MSG_SEALED equ 6
MSG_LEVER equ 7
MSG_FLAT equ 8
MSG_GKEY equ 9
MSG_BKEY equ 10
MSG_RKEY equ 11
MSG_PIE equ 12
MSG_CHG equ 13
MSG_OPAL equ 14
MSG_BOSS equ 15
MSG_DEAD equ 16
MSG_PAUSE equ 17
MSG_OUCH equ 18
MSG_POWER equ 19
MSG_SHARP equ 20
MSG_FAST equ 21
MSG_HINT equ 0FFh
MSGS:   dw .m0,.m1,.m2,.m3,.m4,.m5,.m6,.m7,.m8,.m9,.m10,.m11,.m12,.m13,.m14,.m15,.m16,.m17,.m18,.m19,.m20,.m21
.m0     db "LOCKED. THE GOLD KEY WOULD HELP.",0
.m1     db "LOCKED. IT WANTS THE BLUE KEY.",0
.m2     db "LOCKED. RED KEY. YOU KNOW THE DRILL.",0
.m3     db "A GATE. GLARING WON'T OPEN IT. LEVER.",0
.m4     db "THE GUARDIAN'S GATE. IT ISN'T IN.",0
.m5     db "A SECRET PASSAGE! +500. WELL DONE, YOU.",0
.m6     db "SEALED. SORT THE GUARDIAN OUT FIRST.",0
.m7     db "CLUNK! SOMEWHERE A GATE SWINGS.",0
.m8     db "ZAPPER FLAT. TRY HARSH LANGUAGE.",0
.m9     db "THE GOLD KEY! DON'T LOSE IT.",0
.m10    db "THE BLUE KEY! GOING WELL, FOR YOU.",0
.m11    db "THE RED KEY! THAT'S THE SET.",0
.m12    db "A MEAT PIE! STILL WARM. +25 HEALTH",0
.m13    db "ZAPPER CHARGES +15",0
.m14    db "AN OPAL! +250. FINDERS KEEPERS.",0
.m15    db "THE GUARDIAN FALLS! NOBODY SAW HOW.",0
.m16    db "YOU CARKED IT. UP YOU GET, CHAMP.",0
.m17    db "PAUSED. PUT THE KETTLE ON. (P)",0
.m18    db "OUCH! THAT WAS YOUR OWN FAULT.",0
.m19    db "THE SOUTHERN CROSS! DOUBLE ZAPS.",0
.m20    db "SHARP WALLS (R: FAST WALLS)",0
.m21    db "FAST WALLS (R: SHARP WALLS)",0

; --------------------------------------------------------------------------
; automap: every wall you have seen, two map rows to a text row
; --------------------------------------------------------------------------
automap:
        call showpage0
        ld de,40
        ld c,22
.cl     ld b,40
        call spaces
        dec c
        jr nz,.cl
        ld hl,T_MAPHDR
        ld de,1*40+4
        ld b,CYELLOW
        call printc
        ld de,2*40+4            ; screen
        ld hl,SEEN              ; map rows y, y+1
        ld c,16
.r      push bc
        push de
        ld b,32
.x      push bc
        push hl
        ld a,(hl)               ; top
        ld bc,32
        add hl,bc
        ld c,(hl)               ; bottom
        or a
        jr z,.t0
        ld a,c
        or a
        ld a,'#'
        jr nz,.g
        ld a,'^'
        jr .g
.t0     ld a,c
        or a
        ld a,' '
        jr z,.g
        ld a,'`'
.g      push af                 ; ink: the seen wall's colour
        ld a,(hl)
        or a
        jr nz,.ik
        ld bc,-32
        add hl,bc
        ld a,(hl)
.ik     push de
        call mapink
        pop de
        ld b,a
        pop af
        call putch
        inc de
        pop hl
        inc hl
        pop bc
        djnz .x
        ld bc,32                ; the next pair of map rows
        add hl,bc
        pop de
        ex de,hl
        ld bc,40
        add hl,bc
        ex de,hl
        pop bc
        dec c
        jr nz,.r
        ; you are here
        ld a,(py+2)
        srl a
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        add hl,hl               ; * 40
        ld de,2*40+4
        add hl,de
        ld a,(px+2)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld a,'~'
        ld b,CBRED
        call putch
        ld hl,T_MAPFTR
        ld de,20*40+4
        ld b,CGREY
        call printc
        ; wait for M, ESC or SPACE
.w      call wait_vb
        call readkeys
        ld a,KY_M
        call edge
        jr nz,.out
        ld a,KY_ESC
        call edge
        jr nz,.out
        ld a,KY_FIRE
        call edge
        jr z,.w
.out    jp view_reset

; mapink: A = map cell type -> A = its ink (zone colours)
mapink: or a
        ret z
        add a,a
        ld e,a
        ld d,0
        ld hl,ZINKS
        add hl,de
        ld a,(mono)
        or a
        ld a,CWHITE
        ret nz
        ld a,(hl)
        ret

T_MAPHDR: db "MAP OF WHAT YOU HAVE SEEN",0
T_MAPFTR: db "M: BACK      ~ YOU ARE HERE",0

; --------------------------------------------------------------------------
; Sound effects: each is a few 'grains', one played per frame just before
; the page flip (so the game gets on with it in between).  A grain is a
; burst of speaker toggles: db period, sweep (added to the period after
; every toggle), noise (mask of a random amount added to each period),
; toggles.  A period unit is about 63 T; keep period sum * 63 under 40000.
; An effect ends with 0.
; --------------------------------------------------------------------------
; snd_play: A = effect (a new one replaces the old)
snd_play:
        add a,a
        ld e,a
        ld d,0
        ld hl,SNDTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (sndp),hl
        ret

; snd_wait: play the effect's next grain, if there is one, then wait for
;           the next vertical blank
snd_wait:
        ld hl,(sndp)
        ld a,h
        or l
        jp z,wait_vb
        ld a,(hl)
        or a
        jr nz,.g
        ld hl,0
        ld (sndp),hl
        jp wait_vb
.g      ld c,a                  ; C = period
        inc hl
        ld e,(hl)               ; E = sweep
        inc hl
        ld d,(hl)               ; D = noise mask
        inc hl
        ld b,(hl)               ; B = toggles
        inc hl
        ld (sndp),hl
.t      ld a,(spk)
        xor 40h
        ld (spk),a
        out (PORT_PIOB),a
        call vbpoll             ; (never miss a vertical blank)
        ld a,d
        or a
        ld a,c
        jr z,.nn
        call rnd
        and d
        add a,c
.nn     ld h,a
.d      ld l,3
.d2     dec l
        jr nz,.d2
        dec h
        jr nz,.d
        ld a,c
        add a,e
        cp 2
        jr nc,.ok
        ld a,2
.ok     ld c,a
        djnz .t
        jp wait_vb

SND_ZAP equ 0
SND_HIT equ 1
SND_DIE equ 2
SND_HURT equ 3
SND_PICK equ 4
SND_KEY equ 5
SND_DOOR equ 6
SND_LEVER equ 7
SND_THROW equ 8
SND_BOSS equ 9
SND_BOOM equ 10
SND_URN equ 11
SND_POWER equ 12
SNDTAB: dw .zap,.hit,.die,.hurt,.pick,.key,.door,.lever,.throw,.boss,.boom,.urn,.power
.zap    db 5,1,0,28, 24,2,3,12, 44,0,7,6, 0             ; pew, with a gritty tail
.hit    db 30,-2,15,10, 14,3,31,10, 0                   ; squelch
.die    db 36,-2,7,12, 12,4,15,12, 50,3,31,6, 70,0,63,5, 0   ; wucka-splat
.hurt   db 60,-6,31,7, 24,8,31,6, 0                     ; oof
.pick   db 7,0,0,60, 5,0,0,70, 4,0,1,60, 0              ; chink, chinkle
.key    db 10,0,0,40, 8,0,0,50, 6,0,0,60, 5,0,0,90, 0   ; four bright steps up
.door   db 70,-1,15,6, 64,-1,15,6, 58,-1,15,6, 52,0,15,6, 0   ; a grinding slide
.lever  db 80,0,7,4, 40,12,3,5, 0                       ; clunk
.throw  db 20,1,31,14, 0                                ; whoosh
.boss   db 90,-4,63,4, 70,5,63,4, 50,-3,31,6, 80,2,63,4, 100,0,63,3, 60,10,31,4, 110,0,63,3, 0
.boom   db 20,10,63,6, 80,4,63,4, 100,0,63,3, 110,0,63,3, 0   ; crump
.urn    db 6,1,7,22, 5,0,3,50, 4,0,1,60, 0              ; smash and tinkle
.power  db 16,-1,0,14, 12,0,0,30, 8,0,0,40, 6,0,0,60, 4,0,0,90, 0   ; a sparkle

; rnd: A = pseudo-random byte (keeps BC, DE)
rnd:    ld hl,(seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (seed),hl
        ret
