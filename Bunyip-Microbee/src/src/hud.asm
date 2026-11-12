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
MSG_HINT equ 0FFh
MSGS:   dw .m0,.m1,.m2,.m3,.m4,.m5,.m6,.m7,.m8,.m9,.m10,.m11,.m12,.m13,.m14,.m15,.m16,.m17,.m18,.m19
.m0     db "THIS DOOR NEEDS THE GOLD KEY.",0
.m1     db "THIS DOOR NEEDS THE BLUE KEY.",0
.m2     db "THIS DOOR NEEDS THE RED KEY.",0
.m3     db "A GATE BARS THE WAY. FIND A LEVER.",0
.m4     db "THE GUARDIAN'S GATE IS SHUT FAST.",0
.m5     db "A SECRET PASSAGE! +500",0
.m6     db "SEALED. THE GUARDIAN MUST FALL FIRST.",0
.m7     db "CLUNK! SOMEWHERE A GATE SWINGS.",0
.m8     db "ZAPPER FLAT! FIND CHARGES.",0
.m9     db "YOU FOUND THE GOLD KEY!",0
.m10    db "YOU FOUND THE BLUE KEY!",0
.m11    db "YOU FOUND THE RED KEY!",0
.m12    db "A MEAT PIE! +25 HEALTH",0
.m13    db "ZAPPER CHARGES +15",0
.m14    db "AN OPAL! +250",0
.m15    db "THE GUARDIAN FALLS! ITS GATE OPENS.",0
.m16    db "OVERCOME... YOU RISE AGAIN.",0
.m17    db "PAUSED. PRESS P.",0
.m18    db "OUCH! KEEP CLEAR OF THAT.",0
.m19    db "THE SOUTHERN CROSS! DOUBLE ZAPS.",0

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
; Sound: one effect at a time, played on the beeper while the frame waits
;        for vertical blank (so it costs no drawing time)
; --------------------------------------------------------------------------
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
; period (loop passes), sweep (added every 4 toggles), noise, toggles
SNDTAB: db 5, 1, 0, 70           ; zap: a falling chirp
        db 9, 0, 1, 30           ; hit
        db 12, 1, 1, 110         ; creature down
        db 26, 1, 1, 50          ; you are hurt
        db 10, -1, 0, 90         ; pick up: a rising chirp
        db 14, -1, 0, 150        ; key, secret
        db 34, 0, 1, 80          ; door
        db 22, 0, 0, 14          ; lever
        db 18, 1, 1, 40          ; thrown
        db 16, 1, 1, 255         ; guardian falls

; snd_play: A = effect (a new one replaces the old)
snd_play:
        ld (sndfx),a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,SNDTAB
        add hl,de
        ld a,(hl)
        ld (sndper),a
        ld (sndcnt),a
        inc hl
        ld a,(hl)
        ld (snddp),a
        inc hl
        ld a,(hl)
        ld (sndnz),a
        inc hl
        ld a,(hl)
        ld (sndlen),a
        xor a
        ld (sndsw),a
        ret

; snd_wait: wait for the next vertical blank, playing the effect meanwhile
snd_wait:
        ld a,(sndlen)
        or a
        jp z,wait_vb
        ld hl,(fields)
        ld (sw_f0),hl
.l      call vbpoll
        ld hl,(fields)
        ld de,(sw_f0)
        or a
        sbc hl,de
        ret nz
        ld a,(sndlen)
        or a
        jr z,.l
        ld hl,sndcnt
        dec (hl)
        jr nz,.l
        ; toggle the speaker
        ld a,(spk)
        xor 40h
        ld (spk),a
        out (PORT_PIOB),a
        ld a,(sndper)
        ld b,a
        ld a,(sndnz)
        or a
        jr z,.nn
        call rnd
        and 7
        add a,b
        ld b,a
.nn     ld a,b
        ld (sndcnt),a
        ld hl,sndsw             ; sweep every 4 toggles
        inc (hl)
        ld a,(hl)
        and 3
        jr nz,.ns
        ld a,(snddp)
        ld hl,sndper
        add a,(hl)
        cp 3
        jr nc,.sp
        ld a,3
.sp     cp 80
        jr c,.sq
        ld a,80
.sq     ld (hl),a
.ns     ld hl,sndlen
        dec (hl)
        jr .l

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
