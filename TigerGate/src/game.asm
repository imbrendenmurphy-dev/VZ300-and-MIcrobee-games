; ============================================================================
;  TIGER GATE - a martial arts adventure for the VZ300
;  BennVenn SD loader + 128K SRAM.  Mode 1 (128x64, 4 colours).
;  VIBED BY BPM 2026
;  " : " separates statements on a line; rept/endr repeats lines.
;  tools/build.py expands both before tools/z80asm.py sees the source.
;
;  Screen:  rows  0-19  far layer (parallax, 1/4 speed)
;           rows 20-31  far + mid layer composited (blue in mid = see-through)
;           rows 32-43  mid layer (full speed) - fighters' upper bodies
;           rows 44-57  perspective floor (4 precomputed scroll phases)
;           rows 58-63  health bars and score
; ============================================================================
VRAM equ $7000
LATCH equ $6800
VARS equ $7800
STACKTOP equ $7FF0
PACK equ $C800          ; front / stage / ending pack loaded from SD
TOPBUF equ $E800        ; 12 rows x 32: composited rows 20-31
WORK equ $E980          ; 26 rows x 48: rows 32-57, 8 spare columns each side
BW equ 48
DOSSTACK equ $F7F0
SECBUF equ $F800        ; SD sector buffer.  $FA00 and up belongs to the DOS.
FOE0 equ $4000          ; opponent frames in SRAM bank B (port $37 = 3)
FOE1 equ $5000
FW equ 52
MW equ 112
HXMIN equ 7
EXMAX equ 34
HRUNX equ 14
MINSEP equ 1
PREACH equ 2
KREACH equ 3

FX equ 0
FST equ 1
FTM equ 2
FFR equ 3
FHP equ 4
FHG equ 5
FDIR equ 6
FMAX equ 7
FREG equ 8
FCOOL equ 9
FBLIM equ 10
FRRATE equ 11
FWC equ 12
FFEINT equ 13
FDMG equ 14
FGFX equ 15

ST_UP equ 0
ST_RUN equ 1
ST_STANCE equ 2
ST_STEP equ 3
ST_PUNCH equ 4
ST_KICK equ 5
ST_HIT equ 6
ST_FALL equ 7
ST_DEAD equ 8
ST_BOW equ 9
ST_GUARD equ 10
ST_WAIT equ 11
ST_LEAP equ 12

FL_COUNTER equ 1
FL_RETREAT equ 2
FL_FEINT equ 4
FL_RHYTHM equ 8
FL_HEAVY equ 16
FL_BOSS equ 32

SFX_STEP equ 1
SFX_BOW equ 2
SFX_SWISH equ 3
SFX_RUMBLE equ 4
SFX_BLOCK equ 5
SFX_THUD equ 6
SFX_HIT equ 7
SFX_CTR equ 8
SFX_GONG equ 9
SFX_KO equ 10
SFX_WIN equ 11

hero equ VARS
enemy equ VARS+16
vars0 equ VARS+32       ; cleared at the start of every stage
scrollpos equ vars0+0
epresent equ vars0+1
stagedone equ vars0+2
flash equ vars0+3
sfxreq equ vars0+4
tick equ vars0+5
threat equ vars0+6
prevst equ vars0+7
bowed equ vars0+8
huddirty equ vars0+9
hitstop equ vars0+10
vicflag equ vars0+11
duelhit equ vars0+12
cmd equ vars0+13
cmdh equ vars0+14
ctrflag equ vars0+15
topdirty equ vars0+16
topready equ vars0+17
deadcnt equ vars0+18
retreat equ vars0+19
riposte equ vars0+20
reacted equ vars0+21
aicount equ vars0+22
fadecnt equ vars0+23
bossend equ vars0+24
rockst equ vars0+25
rockx equ vars0+26
rocky equ vars0+27
rockt equ vars0+28
hazard equ vars0+29
curlvl equ vars0+30
aiflags equ vars0+31
entr equ vars0+32
evadep equ vars0+33
guardp equ vars0+34
aibase equ vars0+35
skos equ vars0+36
sclean equ vars0+37
sretry equ vars0+38
democnt equ vars0+39     ; 2 bytes
animfr equ vars0+41      ; 8
parts equ vars0+49       ; 4 x (x, y, t)
manual equ vars0+61
VARS0LEN equ 62
stage equ VARS+100
diff equ VARS+101
musicon equ VARS+102
sfxon equ VARS+103
joyon equ VARS+104
latchv equ VARS+105
seed equ VARS+106
score equ VARS+108
retries equ VARS+110
kos equ VARS+111
cleanw equ VARS+112
maxstage equ VARS+113
startstage equ VARS+114
DOSMAP equ VARS+115
tunekeys equ VARS+116
tplayed equ VARS+117
demo equ VARS+118
curpack equ VARS+119
farptr equ VARS+120
midptr equ VARS+122
musptr equ VARS+124
musbase equ VARS+126
musdiv equ VARS+128
scrollmax equ VARS+129
evptr equ VARS+130
ptype equ VARS+132
ld_sp equ VARS+133
ld_n equ VARS+135
ld_name equ VARS+136
gf_hl equ VARS+138
gf_bc equ VARS+140
gf_de equ VARS+142
tmpcnt equ VARS+144
herovis equ VARS+145
hitab equ VARS+150      ; 5 x (3 letters, score word)
numbuf equ VARS+180
namepos equ VARS+188
keyrep equ VARS+189

    include "gen/frames.asm"
    include "gen/opts.asm"

    org $8000
start:
    di
    ld sp,STACKTOP
    call dos_probe
    ld a,3 : out ($37),a
    ld a,$09 : ld (latchv),a : ld (LATCH),a
    ld hl,$ACE1 : ld (seed),hl
    ld a,1 : ld (diff),a : ld (musicon),a : ld (sfxon),a
    ld a,DBGSTAGE : ld (maxstage),a : ld (startstage),a
    xor a : ld (curpack),a : ld (demo),a
    call joydet
    ld hl,hidef : ld de,hitab : ld bc,25 : ldir
attract:
    call ensurefront
    call titlescr : jr nz,newgame
    call opening : jr nz,newgame
    ld hl,ctrl_txt : call textscr : jr nz,newgame
    call hiscr : jr nz,newgame
    call rundemo
    jr attract

newgame:
    ld hl,0 : ld (score),hl
    xor a : ld (retries),a : ld (cleanw),a : ld (kos),a : ld (demo),a
    ld a,(startstage) : ld (stage),a
    cp 1 : jr nz,.sl
    call opening
.sl: call stagecard : jp c,attract
    call playstage
    ld a,(stagedone) : cp 2 : jr z,.over
    call results
    ld a,(stage) : cp 6 : jr z,.won
    inc a : ld (stage),a
    ld hl,maxstage : cp (hl) : jr c,.sl
    ld (hl),a : jr .sl
.won: call ending
.over: call hientry
    jp attract

; ---------------------------------------------------------------------------
;  SD loading.  The DOS is called exactly as Graves 'n' Gargoyles calls it on
;  the real machine: sector buffer $F800, a deep stack, DI after every call.
; ---------------------------------------------------------------------------
dos_probe:
    ld hl,$5FFF : ld b,(hl) : ld a,b : cpl : ld (hl),a : ld a,(hl) : xor b : ld (hl),b
    and 1 : ld (DOSMAP),a : ret

loadfile:                       ; HL = quoted name, B = sectors -> PACK, carry on failure
    ld (ld_name),hl
    ld a,b : ld (ld_n),a
    di
    ld (ld_sp),sp
    ld sp,DOSSTACK
    ld a,(DOSMAP) : out ($37),a
    ld hl,SECBUF : ld ($FB80),hl
    ld hl,(ld_name) : ld a,1 : call $5F00
    di
    ld a,($FB03) : cp 1 : jr nz,.err
    ld a,($FB05) : cp 1 : jr z,.err
    ld a,1 : call $5F03
    di
    ld de,PACK
.lp: ld hl,SECBUF : ld bc,512 : ldir
    ld a,(ld_n) : dec a : ld (ld_n),a : jr z,.ok
    push de
    ld hl,SECBUF : ld ($FB80),hl
    call $5F09
    di
    pop de
    jr .lp
.ok: or a : jr .out
.err: scf
.out: ld sp,(ld_sp)
    push af
    ld a,3 : out ($37),a
    pop af
    ret

verify:                         ; E = magic, C = number, B = sectors -> carry if bad
    ld a,(PACK) : cp 'T' : jr nz,.bad
    ld a,(PACK+1) : cp e : jr nz,.bad
    ld a,(PACK+2) : cp c : jr nz,.bad
    ld a,b : add a,a : ld d,a : ld e,0
    dec de : dec de : dec de : dec de
    ld hl,PACK+4 : ld c,0
.ck: ld a,(hl) : xor c : ld c,a : inc hl : dec de : ld a,d : or e : jr nz,.ck
    ld a,(PACK+3) : cp c : jr nz,.bad
    or a : ret
.bad: scf : ret

getfile:                        ; HL name, B sectors, E magic, C number -> carry = user chose title
    ld (gf_hl),hl : ld (gf_bc),bc : ld (gf_de),de
.try: ld hl,(gf_hl) : ld bc,(gf_bc) : call loadfile : jr c,.fail
    ld bc,(gf_bc) : ld de,(gf_de) : call verify : ret nc
.fail: xor a : ld (curpack),a
    call sderror : jr nc,.try
    ret

sderror:                        ; -> NC retry, carry title
    ld hl,(gf_hl) : inc hl : ld de,numbuf-8   ; build NAME.DAT in a scratch area
    ld de,errname
.c: ld a,(hl) : cp 34 : jr z,.e : ld (de),a : inc hl : inc de : jr .c
.e: ld hl,dat_txt : ld bc,5 : ldir
    ld hl,VRAM+44*32 : ld bc,20*32-1 : ld a,$AA : call fillbc
    ld a,$FF : ld (txtcol),a
    ld hl,sderr_txt : ld de,45*256+4 : call printat
    ld a,$55 : ld (txtcol),a
    ld hl,errname : ld de,52*256+10 : call printat
    ld hl,retry_txt : ld de,58*256+5 : call printat
    call waitnokey
.w: call waitvs : call anykey : jr nz,.r
    ld a,($68FE) : and $10 : jr nz,.w
    scf : ret
.r: ld hl,VRAM+44*32 : ld bc,20*32-1 : ld a,$AA : call fillbc
    ld a,$55 : ld (txtcol),a
    ld hl,load_txt : ld de,52*256+11 : call printat
    or a : ret
errname: ds 14

ensurefront:
    ld a,(curpack) : cp 'F' : ret z
    call loadingmsg
    ld hl,n_front : ld b,7 : ld e,'R' : ld c,0 : call getfile : jr c,ensurefront
    ld a,'F' : ld (curpack),a : ret
loadingmsg:
    ld a,$AA : call cls
    ld a,$55 : ld (txtcol),a
    ld hl,load_txt : ld de,52*256+11 : jp printat

loadstagefiles:                 ; -> carry if the player chose the title
    ld a,(stage) : add a,'0' : ld (n_foes+7),a : ld (n_stage+8),a
    ld a,(stage) : ld c,a : ld hl,n_foes : ld b,16 : ld e,'F' : call getfile : ret c
    xor a : ld (curpack),a
    ld hl,PACK+4 : ld de,FOE0 : ld bc,8188 : ldir
    ld a,(demo) : or a : jr nz,.nf
    ld de,FOE0+F_FIGHT1*192 : ld hl,VRAM+30*32+12 : call sprvram
.nf: ld a,(stage) : ld c,a : ld hl,n_stage : ld b,16 : ld e,'G' : call getfile : ret c
    ld a,'S' : ld (curpack),a
    or a : ret

n_front: db 34,"TGFRONT",34,0
n_end: db 34,"TGEND",34,0
n_foes: db 34,"TGFOES1",34,0
n_stage: db 34,"TGSTAGE1",34,0
dat_txt: db ".DAT",0

; ---------------------------------------------------------------------------
;  Front end
; ---------------------------------------------------------------------------
titlescr:                       ; -> NZ start game, Z timed out
    ld hl,PACK+256 : ld de,VRAM : ld bc,2048 : ldir
    call waitnokey
    xor a : ld (tplayed),a
.again:
    call titleopts
    ld a,(tplayed) : or a : jr nz,.wait
    inc a : ld (tplayed),a
    ld a,1 : ld (tunekeys),a
    ld hl,tune_title : call playtune : jr nz,.key
.wait: ld bc,450
.w: push bc : call waitvs : call menukey : pop bc : jr nz,.key
    dec bc : ld a,b : or c : jr nz,.w
    xor a : ret
.key: call menukey
    cp 1 : jr nz,.opt
    or a : ret
.opt: cp 2 : jr nz,.o3
    ld a,(diff) : inc a : cp 3 : jr c,.d1
    xor a
.d1: ld (diff),a : jr .rel
.o3: cp 5 : jr nz,.o4
    ld a,(startstage) : ld hl,maxstage : cp (hl) : jr c,.s1
    xor a
.s1: inc a : ld (startstage),a : jr .rel
.o4: ld hl,musicon : cp 3 : jr z,.tog
    ld hl,sfxon : cp 4 : jr nz,.again
.tog: ld a,(hl) : xor 1 : ld (hl),a
.rel: call menukey : jr nz,.rel
    jr .again

titleopts:
    ld a,$55 : ld (txtcol),a
    ld hl,press_txt : ld de,48*256+6 : call printat
    ld a,(diff) : ld e,a : add a,a : add a,a : add a,a : add a,e : ld e,a : ld d,0
    ld hl,diff_txt : add hl,de : ld de,54*256+1 : call printat
    ld hl,mus_on : ld a,(musicon) : or a : jr nz,.m
    ld hl,mus_off
.m: ld de,54*256+10 : call printat
    ld hl,fx_on : ld a,(sfxon) : or a : jr nz,.f
    ld hl,fx_off
.f: ld de,54*256+19 : call printat
    ld a,(startstage) : add a,'0' : ld (stg_txt+4),a
    ld hl,stg_txt : ld de,54*256+26 : call printat
    ld a,$FF : ld (txtcol),a
    ld hl,vibed_txt : ld de,59*256+8 : jp printat

menukey:                        ; -> A: 0 none 1 start 2 D 3 M 4 E 5 S, NZ if any
    call anykey : jr z,.m2
    ld a,1 : ret
.m2: ld a,($68FD) : and $08 : jr nz,.m3
    ld a,2 : or a : ret
.m3: ld a,($68EF) : and $20 : jr nz,.m4
    ld a,3 : or a : ret
.m4: ld a,($68FE) : and $08 : jr nz,.m5
    ld a,4 : or a : ret
.m5: ld a,($68FD) : and $02 : jr nz,.m6
    ld a,5 : or a : ret
.m6: xor a : ret

anykey:                         ; SPACE, RETURN or fire -> NZ
    ld a,($68EF) : cpl : and $10 : ret nz
    ld a,($68BF) : cpl : and $04 : ret nz
    ld a,(joyon) : or a : ret z
    in a,($2E) : cpl : and $10 : ret

waitnokey:
    call waitvs : call menukey : jr nz,waitnokey
    ret

joydet:                         ; joystick ports must idle high or they are ignored
    ld b,0
.l: in a,($2E) : and $1F : cp $1F : jr nz,.no
    in a,($2C) : and $1F : cp $1F : jr nz,.no
    in a,($2D) : and $10 : jr z,.no
    djnz .l
    ld a,1 : jr .set
.no: xor a
.set: ld (joyon),a : ret

opening:                        ; -> NZ if a key skipped it
    ld hl,PACK+2304 : ld de,open_txt : call scene : ret nz
    ld hl,story_txt : jp textscr

scene:                          ; HL = 128x40 picture, DE = text -> NZ if a key ended it
    push de : push hl
    call waitnokey
    ld a,$AA : call cls
    pop hl
    ld de,VRAM : ld b,40
.r: push bc : ld bc,32 : ldir
    push hl : push de : call waitvs : pop de : pop hl
    pop bc : djnz .r
    pop hl : call printlines
    ld bc,500 : jp waitkeyto

textscr:                        ; HL = text table -> NZ if a key ended it
    push hl : call waitnokey : ld a,$AA : call cls : pop hl
    call printlines
    ld bc,450
waitkeyto:                      ; BC frames or a key (NZ)
.w: push bc : call waitvs : call anykey : pop bc : ret nz
    dec bc : ld a,b : or c : jr nz,.w
    ret

printlines:                     ; table: col,row,colour,"text",0 ... $FF
.l: ld a,(hl) : cp $FF : ret z
    ld e,a : inc hl : ld d,(hl) : inc hl : ld a,(hl) : inc hl : ld (txtcol),a
    call printat
    jr .l

printat:                        ; E=col D=row HL=text
    push hl
    ld l,d : ld h,0 : add hl,hl : add hl,hl : add hl,hl : add hl,hl : add hl,hl
    ld d,0 : add hl,de : ld de,VRAM : add hl,de : ex de,hl
    pop hl
.next: ld a,(hl) : inc hl : or a : ret z
    push hl : push de
    sub 32 : ld l,a : ld h,0 : ld b,h : ld c,l : add hl,hl : add hl,hl : add hl,bc
    ld bc,font : add hl,bc
    ex de,hl
    ld b,5
.row: ld a,(de) : cpl : and $AA : ld c,a
    ld a,(de)
txtcol equ $+1
    and $55
    or c : ld (hl),a
    inc de
    ld a,l : add a,32 : ld l,a : jr nc,.nc
    inc h
.nc: djnz .row
    pop de : inc de : pop hl
    jr .next

cls:
    ld hl,VRAM : ld bc,2047
fillbc:                         ; HL start, BC count-1, A value
    ld (hl),a : ld d,h : ld e,l : inc de : ldir : ret
waitvs:                         ; wait for the start of field sync
    ld a,(LATCH) : rla : jr nc,waitvs
.w2: ld a,(LATCH) : rla : jr c,.w2
    ret
waitfrk:                        ; B frames or a key (NZ)
.l: push bc : call waitvs : call anykey : pop bc : ret nz
    djnz .l
    ret

sprvram:                        ; DE = 32x24 frame, HL = screen address: masked draw
    ld b,24
.r: push bc : push hl
    ld c,8
.c: ld a,(de) : or a : jr z,.s
    push de : ld e,a : ld d,masktab/256 : ld a,(de) : and (hl) : or e : ld (hl),a : pop de
.s: inc de : inc hl : dec c : jr nz,.c
    pop hl : ld bc,32 : add hl,bc : pop bc : djnz .r
    ret

stagecard:                      ; card, load, story scene.  Carry = back to title
    ld a,(demo) : or a : jr z,.card
    call loadingmsg : jp loadstagefiles
.card: ld a,$AA : call cls
    ld a,(stage) : add a,'0' : ld (stage_txt+6),a
    ld a,$FF : ld (txtcol),a
    ld hl,stage_txt : ld de,3*256+12 : call printat
    ld a,(stage) : dec a : add a,a : add a,a : ld e,a : ld d,0
    ld ix,cardtab : add ix,de
    ld a,$55 : ld (txtcol),a
    ld l,(ix+0) : ld h,(ix+1) : call ctrline : ld d,11 : call printat
    xor a : ld (txtcol),a
    ld l,(ix+2) : ld h,(ix+3) : call ctrline : ld d,20 : call printat
    ld a,$55 : ld (txtcol),a
    ld hl,load_txt : ld de,58*256+11 : call printat
    call loadstagefiles : ret c
    ld hl,VRAM+58*32 : ld bc,6*32-1 : ld a,$AA : call fillbc
    ld hl,tune_stage : call playtune_nk
    ld b,75 : call waitfrk
    ld hl,(PACK+17) : ld a,h : or l : ret z
    ld de,(PACK+19) : call scene
    or a : ret
ctrline:                        ; HL = text -> E = column that centres it
    push hl : ld e,0
.l: ld a,(hl) : or a : jr z,.d : inc e : inc hl : jr .l
.d: ld a,32 : sub e : srl a : ld e,a : pop hl : ret

results:
    ld a,$AA : call cls
    ld a,(stage) : add a,'0' : ld (clr_txt+6),a
    ld a,(sretry) : or a : ld hl,0 : jr nz,.nb
    ld a,(stage) : ld b,a : ld de,300
.m: add hl,de : djnz .m
.nb: push hl : ld de,(score) : add hl,de : ld (score),hl : pop hl
    ld de,res_b+11 : call num5
    ld a,(skos) : ld hl,res_k+15 : call num2
    ld a,(sclean) : ld hl,res_c+15 : call num2
    ld a,(sretry) : ld hl,res_r+15 : call num2
    ld hl,(score) : ld de,res_s+11 : call num5
    ld hl,res_txt : call printlines
    ld hl,tune_clear : call playtune_nk
    call waitnokey
    ld bc,500 : jp waitkeyto
num2:
    ld b,'0'-1
.t: inc b : sub 10 : jr nc,.t
    add a,10+'0' : ld (hl),b : inc hl : ld (hl),a : ret
num5:                           ; HL value -> DE 5 digits
    ld bc,-10000 : call .d
    ld bc,-1000 : call .d
    ld bc,-100 : call .d
    ld bc,-10 : call .d
    ld a,l : add a,'0' : ld (de),a : ret
.d: ld a,'0'-1
.l: inc a : add hl,bc : jr c,.l
    sbc hl,bc : ld (de),a : inc de : ret

hiscr:                          ; -> NZ if a key ended it
    call waitnokey
    ld a,$AA : call cls
    ld a,$FF : ld (txtcol),a
    ld hl,hall_txt : ld de,4*256+8 : call printat
    ld ix,hitab : ld d,16 : ld b,5 : ld c,'1'
.l: push bc : push de
    ld a,c : ld (hiline),a
    ld a,(ix+0) : ld (hiline+3),a : ld a,(ix+1) : ld (hiline+4),a : ld a,(ix+2) : ld (hiline+5),a
    ld l,(ix+3) : ld h,(ix+4) : ld de,hiline+9 : call num5
    pop de : push de
    ld a,$55 : ld (txtcol),a
    ld hl,hiline : ld e,9 : call printat
    pop de : ld a,d : add a,8 : ld d,a
    ld bc,5 : add ix,bc
    pop bc : inc c : djnz .l
    ld bc,400 : jp waitkeyto
hiline: db "1. AAA   00000",0

hientry:                        ; insert the score in the table if it earns a place
    ld ix,hitab : ld b,0
.f: ld l,(ix+3) : ld h,(ix+4) : ld de,(score)
    or a : sbc hl,de : jr c,.found
    ld de,5 : add ix,de : inc b : ld a,b : cp 5 : jr nz,.f
    ret
.found: ld a,b : ld (namepos),a
    ; shift the entries below down one place
    ld a,4 : sub b : jr z,.ins
    ld c,a : xor a : ld b,c : ld hl,0 : ld de,5
.mm: add hl,de : djnz .mm
    ld b,h : ld c,l
    ld hl,hitab+19 : ld de,hitab+24 : lddr
.ins: ld a,'A' : ld (ix+0),a : ld (ix+1),a : ld (ix+2),a
    ld hl,(score) : ld (ix+3),l : ld (ix+4),h
    call waitnokey
    ld a,$AA : call cls
    ld a,$FF : ld (txtcol),a
    ld hl,newm_txt : ld de,10*256+7 : call printat
    ld a,$55 : ld (txtcol),a
    ld hl,name_txt : ld de,22*256+4 : call printat
    xor a : ld (tmpcnt),a
.ed: push ix : pop hl : ld a,(tmpcnt) : ld e,a : ld d,0 : add hl,de
.ch: push hl
    ld a,(hl) : ld (onech),a
    ld a,(tmpcnt) : add a,14 : ld e,a : ld d,36
    ld a,$FF : ld (txtcol),a
    ld hl,onech : call printat
    pop hl
    ld b,6 : call waitfrk : jr nz,.next
    ld a,($68EF) : and $20 : jr z,.dn
    ld a,($68EF) : and $08 : jr z,.up
    ld a,(joyon) : or a : jr z,.ch
    in a,($2C) : bit 2,a : jr z,.dn
    bit 3,a : jr z,.up
    jr .ch
.up: inc (hl) : ld a,(hl) : cp 'Z'+1 : jr c,.ch
    ld (hl),'A' : jr .ch
.dn: dec (hl) : ld a,(hl) : cp 'A' : jr nc,.ch
    ld (hl),'Z' : jr .ch
.next: push hl : ld a,$55 : ld (txtcol),a
    ld a,(hl) : ld (onech),a
    ld a,(tmpcnt) : add a,14 : ld e,a : ld d,36 : ld hl,onech : call printat
    call waitnokey
    pop hl
    ld a,(tmpcnt) : inc a : ld (tmpcnt),a : cp 3 : jr nz,.ed
    jp hiscr
onech: db "A",0

ending:
    call loadingmsg
    ld hl,n_end : ld b,6 : ld e,'E' : ld c,0 : call getfile : ret c
    ld a,'E' : ld (curpack),a
    ld hl,PACK+256 : ld de,end_txt : call scene
    ld ix,casttab : ld b,7
.cast: push bc
    call waitnokey
    ld a,$AA : call cls
    ld e,(ix+0) : ld d,(ix+1)
    ld hl,VRAM+12*32+12 : call sprvram
    ld a,$55 : ld (txtcol),a
    ld l,(ix+2) : ld h,(ix+3) : call ctrline : ld d,44 : call printat
    ld b,100 : call waitfrk
    ld bc,4 : add ix,bc
    pop bc : djnz .cast
    ld hl,credit_txt : call textscr0
    ld hl,tune_end : call playtune_nk
    ld bc,600 : jp waitkeyto
textscr0:
    push hl : call waitnokey : ld a,$AA : call cls : pop hl : jp printlines

rundemo:
    ld a,1 : ld (stage),a : ld (demo),a
    call stagecard : jr c,.x
    call playstage
.x: xor a : ld (demo),a : ret

; ---------------------------------------------------------------------------
;  A stage
; ---------------------------------------------------------------------------
stagesetup:
    ld hl,vars0 : ld bc,VARS0LEN-1 : xor a : call fillbc
    ld a,(PACK+10) : ld (scrollmax),a
    ld hl,(PACK+11) : ld (evptr),hl
    ld hl,(PACK+21) : ld (musbase),hl : ld (musptr),hl
    ld a,(PACK+23) : ld (ptype),a
    call setptrs
    ld a,1 : ld (topdirty),a : ld (huddirty),a : ld (herovis),a
    ld a,12 : ld (musdiv),a
    ld a,20 : ld (rockt),a
    ld hl,VRAM+58*32 : ld bc,6*32-1 : ld a,$AA : call fillbc
    ld b,4 : ld hl,parts
.p: push hl : call rnd : pop hl : and 127 : ld (hl),a : inc hl
    push hl : call rnd : pop hl : and 15 : ld (hl),a : inc hl : ld (hl),0 : inc hl : djnz .p
    ret

setptrs:
    ld a,(scrollpos) : ld e,a : ld d,0
    ld hl,(PACK+6) : add hl,de : ld (midptr),hl
    srl e : srl e
    ld hl,(PACK+4) : add hl,de : ld (farptr),hl
    ret

playstage:
    call stagesetup
    ld ix,hero
    ld (ix+FX),8 : ld (ix+FST),ST_UP : ld (ix+FFR),F_STAND : ld (ix+FDIR),1
    ld (ix+FBLIM),HXMIN : ld (ix+FREG),0 : ld (ix+FWC),0 : ld (ix+FFEINT),0 : ld (ix+FDMG),0
    ld (ix+FGFX),herogfx/256
    ld a,(diff) : ld e,a : ld d,0
    ld hl,dif_hp : add hl,de : ld a,(hl) : ld (ix+FHP),a : ld (ix+FMAX),a
    ld hl,dif_reg : add hl,de : ld a,(hl) : ld (ix+FRRATE),a
    call render : call blit
.loop:
    call waitvs
    call blit
    call doflash
    ld a,(huddirty) : or a : call nz,drawhud
    call gametick
    call dosound
    call waitvs
    call render
    ld a,(stagedone) : or a : jr z,.loop
    ret
dif_hp: db 16,12,10
dif_reg: db 50,80,140
dif_cool: db 6,0,$FD

doflash:
    ld a,(flash) : or a : ld b,$09 : jr z,.set
    dec a : ld (flash),a : ld b,$19
.set: ld a,b : ld (latchv),a : ld (LATCH),a : ret

; ---- rendering -------------------------------------------------------------
blit:                           ; in the blanking: top (if new) and the fight band
    ld a,(topready) : or a : jr z,.band
    xor a : ld (topready),a
    ld hl,(farptr) : ld de,VRAM : ld a,20
.f: call ldi32
    ld bc,FW-32 : add hl,bc
    dec a : jr nz,.f
    ld hl,TOPBUF : ld a,12
.t: call ldi32 : dec a : jr nz,.t
    jr .b2
.band: ld de,VRAM+32*32
.b2: ld hl,WORK+8 : ld a,26
.b: call ldi32
    ld bc,16 : add hl,bc
    dec a : jr nz,.b
    ret
ldi32:
    rept 32
    ldi
    endr
    ret

render:
    ld a,(topdirty) : or a : jr z,.band
    xor a : ld (topdirty),a
    inc a : ld (topready),a
    call comptop
.band:
    ld hl,(midptr) : ld de,MW*12 : add hl,de
    ld de,WORK+8 : ld a,12
.m: call ldi32
    ld bc,MW-32 : add hl,bc
    ex de,hl : ld bc,16 : add hl,bc : ex de,hl
    dec a : jr nz,.m
    push de
    ld a,(scrollpos) : and 3 : ld b,a : ld hl,(PACK+8)
    jr z,.f0
    ld de,448
.fm: add hl,de : djnz .fm
.f0: pop de
    ld a,14
.fl: call ldi32
    ex de,hl : ld bc,16 : add hl,bc : ex de,hl
    dec a : jr nz,.fl
    call drawparts
    call drawshadow
    ld a,(epresent) : or a : jr z,.ne
    ld a,(fadecnt) : or a : jr z,.ed
    cp 20 : jr nc,.ed
    ld a,(tick) : rra : jr c,.ne
.ed: ld a,(enemy+FX) : ld e,a
    ld a,(enemy+FGFX) : ld h,a : ld l,0
    ld a,(enemy+FFR) : call sprat
.ne: ld a,(herovis) : or a : jr z,.nh
    ld a,(hero+FX) : ld e,a
    ld a,(hero+FGFX) : ld h,a : ld l,0
    ld a,(hero+FFR) : call sprat
.nh: jp drawrock
sprat:                          ; A = frame, HL = frame set, E = column (buffer)
    push de
    ld e,a : ld d,0 : ex de,hl
    add hl,hl : add hl,hl : add hl,hl : add hl,hl : add hl,hl : add hl,hl
    ld b,h : ld c,l : add hl,hl : add hl,bc : add hl,de
    pop de : ex de,hl           ; DE = frame data, L = column
    ld h,0 : ld bc,WORK : add hl,bc : ld b,h : ld c,l
    ld h,masktab/256
    exx : ld b,24 : exx
.row:
    rept 8
    ld a,(de)
    or a
    jr z,$+7
    ld l,a
    ld a,(bc)
    and (hl)
    or l
    ld (bc),a
    inc de
    inc bc
    endr
    ld a,c : add a,BW-8 : ld c,a : jr nc,.nc
    inc b
.nc: exx : dec b : exx
    jp nz,.row
    ret

comptop:                        ; TOPBUF = far rows 20-31 with mid rows 0-11 over them
    ld hl,(farptr) : ld de,FW*20 : add hl,de
    ld de,TOPBUF : ld a,12
.r: push hl : call ldi32 : pop hl
    ld bc,FW : add hl,bc
    dec a : jr nz,.r
    ld de,(midptr) : ld bc,TOPBUF : ld h,bmask/256
    ld a,12 : ld (tmpcnt),a
.mr: call comp32
    ld a,e : add a,MW-32 : ld e,a : jr nc,.nc
    inc d
.nc: ld a,(tmpcnt) : dec a : ld (tmpcnt),a : jr nz,.mr
    ret
comp32:
    rept 32
    ld a,(de)
    ld l,a
    ld a,(bc)
    and (hl)
    inc h
    or (hl)
    dec h
    ld (bc),a
    inc de
    inc bc
    endr
    ret

drawparts:                      ; petals, leaves or embers in the fight band
    ld a,(ptype) : or a : ret z
    ld c,a : ld b,0 : ld hl,pcol-1 : add hl,bc : ld a,(hl) : ld (.pc+1),a
    ld ix,parts : ld b,4
.l: push bc
    ld e,(ix+0) : ld d,(ix+1)
.pc: ld c,0
    call plot
    ld bc,3 : add ix,bc
    pop bc : djnz .l
    ret
pcol: db 3,0,1
plot:                           ; D = band row, E = x, C = colour
    push bc
    ld l,d : ld h,0 : add hl,hl : add hl,hl : add hl,hl : add hl,hl
    ld b,h : ld c,l : add hl,hl : add hl,bc
    ld a,e : rrca : rrca : and $3F : add a,8
    ld c,a : ld b,0 : add hl,bc : ld bc,WORK : add hl,bc
    pop bc
    ld a,e : and 3 : xor 3 : ld b,a
    ld a,c : ld c,3
    inc b
.sh: dec b : jr z,.put
    rlca : rlca : rlc c : rlc c : jr .sh
.put: ld b,a : ld a,c : cpl : and (hl) : or b : ld (hl),a : ret

partupd:
    ld a,(ptype) : or a : ret z
    ld ix,parts : ld b,4
.l: push bc
    ld a,(ptype) : cp 3 : jr z,.ember
    inc (ix+2) : ld a,(ix+2) : and 1 : jr nz,.nx
    inc (ix+1) : dec (ix+0)
    ld a,(ix+0) : cp 128 : jr c,.y
    ld (ix+0),127
.y: ld a,(ix+1) : cp 24 : jr c,.nx
    ld (ix+1),0
    call rnd : and 127 : ld (ix+0),a
    jr .nx
.ember: inc (ix+2) : ld a,(ix+2) : and 1 : jr nz,.nx
    dec (ix+1) : ld a,(ix+1) : cp 26 : jr c,.jit
    ld (ix+1),20
    call rnd : and 127 : ld (ix+0),a
.jit: call rnd : and 1 : jr z,.nx
    call rnd : and 2 : dec a : add a,(ix+0) : and 127 : ld (ix+0),a
.nx: ld bc,3 : add ix,bc
    pop bc : djnz .l
    ret

drawshadow:                     ; green shadow where a boulder will land
    ld a,(rockst) : or a : ret z
    cp 3 : ret z
    call rockcol : ret nc
    ld hl,WORK+22*BW : add hl,de
    inc hl : ld (hl),0 : ld bc,BW-1 : add hl,bc
    ld (hl),0 : inc hl : ld (hl),0 : inc hl : ld (hl),0
    ret
rockcol:                        ; -> DE = buffer column, carry if on screen
    ld a,(rockx) : ld hl,scrollpos : sub (hl) : cp 45 : ld e,a : ld d,0 : ret
drawrock:
    ld a,(rockst) : cp 2 : jr c,.x
    call rockcol : ret nc
    ld a,(rockst) : cp 3 : jr z,.rub
    ld a,(rocky) : ld bc,rockgfx : jr .spr
.rub: ld a,16 : ld bc,rockgfx+24
.spr: push bc
    ld l,a : ld h,0 : add hl,hl : add hl,hl : add hl,hl : add hl,hl
    ld b,h : ld c,l : add hl,hl : add hl,bc
    add hl,de : ld bc,WORK : add hl,bc
    pop de
    ld b,8
.r: push bc : push hl
    ld c,3
.c: ld a,(de) : or a : jr z,.s
    push de : ld e,a : ld d,masktab/256 : ld a,(de) : and (hl) : or e : ld (hl),a : pop de
.s: inc de : inc hl : dec c : jr nz,.c
    pop hl : ld bc,BW : add hl,bc : pop bc : djnz .r
.x: ret

doanims:
    ld ix,(PACK+15) : ld hl,animfr
.l: ld a,(ix+0) : or (ix+1) : ret z
    ld a,(tick) : add a,(ix+10) : and (ix+6) : jr nz,.next
    ld a,(hl) : inc a : cp (ix+5) : jr c,.k
    xor a
.k: ld (hl),a
    push hl
    ld e,(ix+7) : ld d,(ix+8)
    or a : jr z,.s0
    ld b,a : ld c,(ix+11)
.mul: ld a,e : add a,c : ld e,a : jr nc,.mn
    inc d
.mn: djnz .mul
.s0: ld l,(ix+0) : ld h,(ix+1)
    ld b,(ix+4)
.r: push bc
    ld c,(ix+3) : ld b,0
    ex de,hl : ldir : ex de,hl
    ld c,(ix+2) : ld b,0 : add hl,bc
    pop bc : djnz .r
    ld a,(ix+9) : or a : jr z,.nt
    ld (topdirty),a
.nt: pop hl
.next: inc hl : ld bc,12 : add ix,bc : jr .l

drawhud:
    xor a : ld (huddirty),a
    ld ix,hero : call pips
    ld c,$56 : ld hl,VRAM+59*32 : ld de,1 : call bar
    ld b,0 : ld a,(epresent) : or a : jr z,.e
    ld a,(enemy+FST) : cp ST_WAIT : jr z,.e
    ld ix,enemy : call pips
.e: ld c,$FE : ld hl,VRAM+59*32+30 : ld de,-1 : call bar
    ld a,(demo) : or a : jr z,.sc
    ld a,$FF : ld (txtcol),a
    ld hl,demo_txt : ld de,59*256+13 : jp printat
.sc: ld hl,(score) : ld de,numbuf : call num5 : xor a : ld (numbuf+5),a
    ld a,$55 : ld (txtcol),a
    ld hl,numbuf : ld de,59*256+13 : jp printat
pips:                           ; IX fighter -> B pips (12 max)
    ld a,(ix+FMAX) : cp 13 : ld a,(ix+FHP) : jr c,.n
    inc a : srl a
.n: ld b,a : ret
bar:                            ; B=pips C=pip byte HL=first pip DE=step
    ld a,12
.l: push af
    ld a,b : or a : jr z,.empty
    dec b : ld a,c : jr .put
.empty: ld a,$AA
.put: push hl : push de
    ld de,32 : ld (hl),a : add hl,de : ld (hl),a : add hl,de : ld (hl),a : add hl,de : ld (hl),a
    pop de : pop hl
    add hl,de : pop af : dec a : jr nz,.l
    ret

; ---- game logic ------------------------------------------------------------
gametick:
    ld a,(hitstop) : or a : jr z,.go
    dec a : ld (hitstop),a : ret
.go: ld hl,tick : inc (hl)
    call doanims
    call partupd
    ld a,(demo) : or a : jr z,.pl
    call anykey : jr z,.dm
.dq: ld a,2 : ld (stagedone),a : ret
.dm: ld hl,(democnt) : inc hl : ld (democnt),hl : ld a,h : cp 6 : jr z,.dq
.auto: call calcthreat
    ld c,2 : ld b,1
    ld a,(threat) : or a : jr z,.dset
    ld ix,hero : ld iy,enemy : call ai
.dset: ld a,c : ld (cmd),a : ld a,b : ld (cmdh),a : jr .in
.pl: ld a,AUTOPLAY : or a : jr nz,.auto
    call readin
.in: call calcthreat
    ld a,(hero+FST) : cp ST_DEAD : jr nz,.alive
    ld hl,deadcnt : inc (hl) : ld a,(hl) : cp 30 : jr nz,.alive
    ld a,(demo) : or a : jr nz,.dq
    call defeat
    ld a,(stagedone) : or a : ret nz
.alive:
    ld ix,hero : ld iy,enemy
    ld a,(cmd) : ld c,a : ld a,(cmdh) : ld b,a
    call fupdate
    call herorun
    call enemyupd
    call rocks
    call script
    ld a,(bossend) : or a : ret z
    dec a : ld (bossend),a : ret nz
    ld a,1 : ld (stagedone),a : ret

calcthreat:
    xor a : ld (threat),a
    ld a,(epresent) : or a : ret z
    ld a,(enemy+FST)
    cp ST_FALL : ret z
    cp ST_DEAD : ret z
    cp ST_WAIT : ret z
    ld a,1 : ld (threat),a : ret

defeat:                         ; the hero is down: instant retry of this duel, or quit
    ld hl,VRAM+58*32 : ld bc,6*32-1 : ld a,$AA : call fillbc
    ld a,$FF : ld (txtcol),a
    ld hl,defeat_txt : ld de,59*256+3 : call printat
    ld hl,tune_lose : call playtune_nk
    call waitnokey
    ld a,AUTOPLAY : or a : jr nz,.retry
.w: call waitvs : call anykey : jr nz,.retry
    ld a,($68FE) : and $10 : jr nz,.w
    ld a,2 : ld (stagedone),a : ret
.retry: ld hl,retries : inc (hl) : ld hl,sretry : inc (hl)
    ld hl,VRAM+58*32 : ld bc,6*32-1 : ld a,$AA : call fillbc
    xor a : ld (deadcnt),a : ld (rockst),a
    ld ix,hero
    ld a,(ix+FMAX) : ld (ix+FHP),a : ld (ix+FST),ST_STANCE : ld (ix+FX),10
    ld a,1 : ld (huddirty),a
    ld a,(epresent) : or a : ret z
    ld a,(enemy+FST) : cp ST_FALL : ret z
    cp ST_DEAD : ret z
    ld a,(curlvl) : ld c,a : call spawn
    ld a,1 : ld (duelhit),a : ret

herorun:
    ld a,(hero+FST) : cp ST_RUN : ret nz
    ld a,(tick) : and 1 : ret nz
    ld a,(tick) : and 7 : jr nz,.ns
    ld a,SFX_STEP : call sfx
.ns: ld a,(hero+FX) : cp HRUNX : jr c,.walk
    ld a,(scrollpos) : ld hl,scrollmax : cp (hl) : jr nc,.walk
    inc a : ld (scrollpos),a
    call setptrs
    ld a,1 : ld (topdirty),a
    ld a,(epresent) : or a : ret z
    ld hl,enemy+FX : dec (hl) : ret nz
    xor a : ld (epresent),a : inc a : ld (huddirty),a : ret
.walk: ld hl,hero+FX : inc (hl) : ld a,(hl) : cp 40 : ret c
    xor a : ld (herovis),a : inc a : ld (stagedone),a : ret

enemyupd:
    ld a,(epresent) : or a : ret z
    ld ix,enemy : ld iy,hero
    ld a,(ix+FST)
    cp ST_RUN : jr z,.run
    cp ST_LEAP : jr z,.leap
    cp ST_WAIT : jr z,.wait
    cp ST_DEAD : jr z,.dead
    cp ST_FALL : jr z,.upd0
    call ai : jp fupdate
.upd0: ld bc,0 : jp fupdate
.run: ld a,(entr) : cp 3 : jr nz,.r1
    ld a,(tick) : and 4 : ld a,F_STEP : jr z,.hf
    ld a,F_FIGHT1
.hf: ld (ix+FFR),a
    ld a,(tick) : and 3 : jr nz,.rchk
    dec (ix+FX) : ld a,SFX_THUD : call sfx : jr .rchk
.r1: dec (ix+FX)
    ld a,(tick) : rra : and 3 : add a,F_RUN1 : ld (ix+FFR),a
.rchk: call getsep : cp 8 : ret nc
    ld (ix+FST),ST_STANCE : ret
.leap: dec (ix+FX) : dec (ix+FX) : ld (ix+FFR),F_KH
    call getsep : cp 7 : ret nc
    ld (ix+FST),ST_STANCE : ld a,SFX_THUD : jp sfx
.wait: ld (ix+FFR),F_BOW
    call getsep : cp 14 : ret nc
    ld (ix+FST),ST_STANCE : ld (ix+FCOOL),12 : ld a,1 : ld (huddirty),a
    ld a,SFX_GONG : jp sfx
.dead: ld (ix+FFR),F_FALL2
    ld a,(vicflag) : or a : jr z,.fade
    xor a : ld (vicflag),a
    ld a,(hero+FST) : cp ST_HIT : jr nc,.nb
    ld a,ST_BOW : ld (hero+FST),a : ld a,20 : ld (hero+FTM),a
.nb: ld a,SFX_WIN : call sfx
    ld a,(aiflags) : and FL_BOSS : jr z,.f1
    ld a,90 : ld (bossend),a : ret
.f1: ld a,60 : ld (fadecnt),a : ret
.fade: ld a,(fadecnt) : or a : ret z
    dec a : ld (fadecnt),a : ret nz
    xor a : ld (epresent),a : inc a : ld (huddirty),a
    ld a,(demo) : or a : ret z
    ld a,2 : ld (stagedone),a : ret

getsep:
    ld a,(enemy+FX) : ld hl,hero+FX : sub (hl) : ret

script:                         ; stage events: scroll position, kind, parameter
    ld a,(threat) : or a : ret nz
    ld hl,(evptr) : ld a,(hl) : cp $FF : ret z
    ld b,a : ld a,(scrollpos) : cp b : ret c
    inc hl : ld a,(hl) : inc hl : ld c,(hl) : inc hl
    or a : jr nz,.haz
    ld a,(epresent) : or a : ret nz
    ld (evptr),hl
    ld a,c : ld (curlvl),a
    jp spawn
.haz: ld (evptr),hl
    dec a : ld (hazard),a
    jr z,.on
    xor a : ld (hazard),a : ret
.on: ld a,1 : ld (hazard),a : ret

spawn:                          ; C = opponent level in the pack
    ld a,c : add a,a : add a,a : add a,a : ld e,a : ld d,0
    ld hl,(PACK+13) : add hl,de
    ld a,(hl) : ld (enemy+FHP),a : ld (enemy+FMAX),a : inc hl
    push hl
    ld a,(diff) : ld e,a : ld d,0 : ld hl,dif_cool : add hl,de : ld a,(hl)
    pop hl
    add a,(hl) : ld (aibase),a : inc hl
    ld a,(hl) : ld (evadep),a : inc hl
    ld a,(hl) : ld (guardp),a : inc hl
    ld a,(hl) : or a : ld a,FOE0/256 : jr z,.t0
    ld a,FOE1/256
.t0: ld (enemy+FGFX),a : inc hl
    ld a,(hl) : ld (aiflags),a : inc hl
    ld a,(hl) : ld (entr),a : inc hl
    ld a,(hl) : ld (enemy+FDMG),a
    ld ix,enemy
    ld (ix+FX),40 : ld (ix+FFR),F_RUN1 : ld (ix+FDIR),$FF
    ld (ix+FBLIM),EXMAX : ld (ix+FRRATE),240 : ld (ix+FREG),0 : ld (ix+FCOOL),8
    ld (ix+FWC),0 : ld (ix+FFEINT),0
    ld a,(entr) : ld e,a : ld d,0 : ld hl,enttab : add hl,de : ld a,(hl) : ld (ix+FST),a
    ld a,(entr) : cp 4 : jr nz,.e1
    ld a,(hero+FX) : add a,12 : ld (ix+FX),a : ld a,4 : ld (flash),a
.e1: ld a,1 : ld (epresent),a : ld (huddirty),a
    xor a : ld (bowed),a : ld (duelhit),a : ld (vicflag),a : ld (retreat),a
    ld (riposte),a : ld (reacted),a : ld (fadecnt),a : ld (manual),a
    ld a,(hero+FST) : cp ST_STANCE : jr nc,.s
    ld a,ST_STANCE : ld (hero+FST),a
.s: ld a,SFX_GONG : jp sfx
enttab: db ST_RUN,ST_WAIT,ST_LEAP,ST_RUN,ST_STANCE

rocks:                          ; the cliff path: boulders drop where Ren is heading
    ld a,(rockst) : or a : jr nz,.act
    ld a,(hazard) : or a : ret z
    ld a,(threat) : or a : ret nz
    ld hl,rockt : ld a,(hl) : or a : jr z,.spawn
    dec (hl) : ret
.spawn: ld a,(hero+FX) : add a,9 : ld b,a
    call rnd : and 3 : add a,b
    ld hl,scrollpos : add a,(hl) : ld (rockx),a
    ld a,1 : ld (rockst),a : ld a,14 : ld (rockt),a
    ld a,SFX_RUMBLE : jp sfx
.act: cp 1 : jr nz,.a2
    ld hl,rockt : dec (hl) : ret nz
    ld a,2 : ld (rockst),a : xor a : ld (rocky),a : ret
.a2: cp 2 : jr nz,.a3
    ld a,(rocky) : add a,3 : ld (rocky),a : cp 16 : ret c
    ld a,3 : ld (rockst),a : ld a,8 : ld (rockt),a
    ld a,SFX_THUD : call sfx
    ld a,(rockx) : ld hl,scrollpos : sub (hl) : ld b,a
    ld a,(hero+FX) : add a,3 : sub b : add a,2 : cp 5 : ret nc
    ld a,(hero+FST) : cp ST_HIT : ret nc
    ld hl,hero+FHP : ld a,(hl) : sub 2 : jr nc,.hp
    xor a
.hp: ld (hl),a
    ld a,1 : ld (huddirty),a : ld (duelhit),a : ld (flash),a
    ld a,(hero+FX) : sub 2 : cp HXMIN : jr nc,.hx
    ld a,HXMIN
.hx: ld (hero+FX),a
    ld a,(hero+FHP) : or a : jr z,.dead
    ld a,ST_HIT : ld (hero+FST),a : ld a,6 : ld (hero+FTM),a
    ld a,SFX_HIT : jp sfx
.dead: ld a,ST_FALL : ld (hero+FST),a : ld a,8 : ld (hero+FTM),a
    ld a,SFX_KO : jp sfx
.a3: ld hl,rockt : dec (hl) : ret nz
    xor a : ld (rockst),a
    call rnd : and 15 : add a,6 : ld (rockt),a : ret

; ---------------------------------------------------------------------------
;  Fighters.  IX = fighter, IY = opponent, C = command bits, B = height
;  command: 0 back, 1 forward, 2 punch, 3 kick, 4 stance, 5 bow, 6 guard
; ---------------------------------------------------------------------------
fupdate:
    ld a,(ix+FST) : cp ST_HIT : jr nc,.noreg
    inc (ix+FREG) : ld a,(ix+FREG) : cp (ix+FRRATE) : jr c,.noreg
    ld (ix+FREG),0
    ld a,(ix+FHP) : cp (ix+FMAX) : jr nc,.noreg
    inc (ix+FHP) : ld a,1 : ld (huddirty),a
.noreg:
    ld a,(ix+FST) : add a,a : ld e,a : ld d,0 : ld hl,.jt : add hl,de
    ld a,(hl) : inc hl : ld h,(hl) : ld l,a : jp (hl)
.jt: dw s_up,s_run,s_stance,s_step,s_punch,s_kick,s_hit,s_fall,s_dead,s_bow,s_guard,s_wait,s_leap

s_wait:
s_leap:
    ret
s_up:
    ld (ix+FFR),F_STAND
    bit 5,c : jr nz,gobow
    bit 4,c : jr nz,.man
    bit 1,c : ret z
    ld a,(threat) : or a : jr nz,gostance
    ld (ix+FST),ST_RUN : ret
.man: ld a,1 : ld (manual),a
gostance:
    ld (ix+FST),ST_STANCE : ret
gobow:
    ld (ix+FST),ST_BOW : ld (ix+FTM),14
    ld a,SFX_BOW : jp sfx
s_run:
    ld a,(tick) : rra : and 3 : add a,F_RUN1 : ld (ix+FFR),a
    ld a,(threat) : or a : jr nz,gostance
    bit 1,c : ret nz
    ld (ix+FST),ST_UP : ret
s_stance:
    ld a,(tick) : rra : rra : rra : and 1 : add a,F_FIGHT1 : ld (ix+FFR),a
    bit 6,c : jr nz,.guard
    bit 2,c : jr nz,.punch
    bit 3,c : jr nz,.kick
    bit 1,c : jr nz,.fwd
    bit 0,c : jr nz,.back
    bit 5,c : jr nz,gobow
    bit 4,c : ret z
    xor a : ld (manual),a
    ld (ix+FST),ST_UP : ret
.guard: ld (ix+FST),ST_GUARD : ld (ix+FTM),6 : ld (ix+FFR),F_GUARD : ret
.punch: ld (ix+FST),ST_PUNCH : ld (ix+FTM),7 : ld (ix+FFR),F_PWIND : jr .atk
.kick: ld (ix+FST),ST_KICK : ld (ix+FTM),10 : ld (ix+FFR),F_KWIND
.atk: ld (ix+FHG),b
    xor a
    bit 7,(ix+FDIR) : jr z,.wc
    ld a,(aiflags) : and FL_HEAVY : jr z,.wc
    ld a,3
.wc: bit 0,(ix+FFEINT) : jr z,.wc2
    add a,4
.wc2: ld (ix+FWC),a
    ld a,SFX_SWISH : jp sfx
.fwd: bit 7,(ix+FDIR) : jr nz,.fstep
    ld a,(threat) : or a : jr nz,.fstep
    ld a,(manual) : or a : jr nz,.free
    ld (ix+FST),ST_RUN : ret
.fstep: call getsep : cp MINSEP+1 : ret c
    jr .dostep
.free: ld a,(ix+FX) : cp 30 : ret nc
.dostep: ld a,(ix+FX) : add a,(ix+FDIR) : ld (ix+FX),a
.stp: ld (ix+FST),ST_STEP : ld (ix+FTM),3 : ld (ix+FFR),F_STEP : ret
.back: ld a,(ix+FX) : cp (ix+FBLIM) : ret z
    sub (ix+FDIR) : ld (ix+FX),a : jr .stp
s_step:
    dec (ix+FTM) : ret nz
tostance:
    ld (ix+FST),ST_STANCE : ret
atkend:
    ld (ix+FST),ST_STANCE
    bit 7,(ix+FDIR) : ret z
    ld a,(aiflags) : and FL_RETREAT : ret z
    ld a,2 : ld (retreat),a : ret
s_punch:                        ; (held wind-up) 2 ticks wind-up, 3 out (hits on the first), 2 back
    ld a,(ix+FWC) : or a : jr z,.go
    dec a : ld (ix+FWC),a
    ld (ix+FFR),F_PWIND
    ret nz
    ld a,(ix+FFEINT) : or a : ret z
    ld (ix+FFEINT),0 : jr tostance
.go: dec (ix+FTM) : ld a,(ix+FTM) : jr z,atkend
    cp 5 : jr nc,.wind
    cp 2 : jr c,.wind
    push af : ld a,(ix+FHG) : add a,F_PH : ld (ix+FFR),a : pop af
    cp 4 : ret nz
    ld d,PREACH : ld e,1 : jp hitchk
.wind: ld (ix+FFR),F_PWIND : ret
s_kick:                         ; (held wind-up) 3 ticks wind-up, 4 out, 3 back
    ld a,(ix+FWC) : or a : jr z,.go
    dec a : ld (ix+FWC),a
    ld (ix+FFR),F_KWIND
    ret nz
    ld a,(ix+FFEINT) : or a : ret z
    ld (ix+FFEINT),0 : jr tostance
.go: dec (ix+FTM) : ld a,(ix+FTM) : jr z,atkend
    cp 7 : jr nc,.wind
    cp 3 : jr c,.wind
    push af : ld a,(ix+FHG) : add a,F_KH : ld (ix+FFR),a : pop af
    cp 6 : ret nz
    ld d,KREACH : ld e,2 : jp hitchk
.wind: ld (ix+FFR),F_KWIND : ret
s_hit:
    ld (ix+FFR),F_HIT
    dec (ix+FTM) : ret nz
    jp tostance
s_fall:
    ld (ix+FFR),F_FALL1
    dec (ix+FTM) : ret nz
    ld (ix+FST),ST_DEAD
s_dead:
    ld (ix+FFR),F_FALL2 : ret
s_bow:
    ld (ix+FFR),F_BOW
    dec (ix+FTM) : ret nz
    ld (ix+FST),ST_UP : ret
s_guard:
    ld (ix+FFR),F_GUARD
    bit 6,c : ret nz
    dec (ix+FTM) : ret nz
    jp tostance

hitchk:                         ; D = reach, E = damage
    ld a,(epresent) : or a : ret z
    ld a,(iy+FST) : cp ST_GUARD : jr z,.rng
    cp ST_HIT : jr c,.rng
    cp ST_BOW : ret nz
.rng: push de : call getsep : pop de
    cp d : jr z,.in
    ret nc
.in: ld a,e : add a,(ix+FDMG) : ld e,a
    ld a,(iy+FST) : cp ST_GUARD : jr nz,.land
    ld a,d : cp KREACH : call z,pushback
    bit 7,(iy+FDIR) : jr z,.bs
    ld a,(aiflags) : and FL_COUNTER : jr z,.bs
    ld a,1 : ld (riposte),a : ld (iy+FCOOL),0
.bs: ld a,SFX_BLOCK : jp sfx
.land: cp ST_STANCE : jr c,.dbl
    cp ST_BOW : jr z,.dbl
    cp ST_PUNCH : jr z,.ctr
    cp ST_KICK : jr nz,dohit
.ctr: inc e : ld a,1 : ld (ctrflag),a : jr dohit
.dbl: sla e
dohit:
    ld a,(iy+FHP) : sub e : jr nc,.hp
    xor a
.hp: ld (iy+FHP),a
    ld (iy+FREG),0 : ld (iy+FWC),0 : ld (iy+FFEINT),0
    ld a,1 : ld (huddirty),a
    call pushback
    bit 7,(iy+FDIR) : jr nz,.onenemy
    ld a,1 : ld (duelhit),a
.onenemy:
    ld a,(iy+FHP) : or a : jr z,.ko
    ld (iy+FST),ST_HIT : ld (iy+FTM),5 : ld (iy+FFR),F_HIT
    ld a,2 : ld (hitstop),a
    ld a,(ctrflag) : or a : ld a,SFX_HIT : jr z,.s
    xor a : ld (ctrflag),a : inc a : ld (flash),a
    ld a,SFX_CTR
.s: jp sfx
.ko: ld (iy+FST),ST_FALL : ld (iy+FTM),8 : ld (iy+FFR),F_FALL1
    ld a,(iy+FX) : sub (iy+FDIR) : sub (iy+FDIR) : ld (iy+FX),a
    xor a : ld (ctrflag),a
    ld a,2 : ld (flash),a : ld a,4 : ld (hitstop),a
    bit 7,(iy+FDIR) : jr z,.kos
    ld hl,kos : inc (hl) : ld hl,skos : inc (hl)
    ld a,(stage) : ld b,a : ld hl,(score) : ld de,100
.sc: add hl,de
    ld a,(duelhit) : or a : jr nz,.nc
    add hl,de
.nc: djnz .sc
    ld (score),hl
    ld a,(duelhit) : or a : jr nz,.vf
    ld hl,cleanw : inc (hl) : ld hl,sclean : inc (hl)
.vf: ld a,1 : ld (vicflag),a
.kos: ld a,SFX_KO : jp sfx
pushback:
    ld a,(iy+FX) : cp (iy+FBLIM) : ret z
    sub (iy+FDIR) : ld (iy+FX),a : ret

ai:                             ; IX = self (in stance), IY = opponent -> C command, B height
    ld c,0 : ld b,1
    ld a,(ix+FST) : cp ST_STANCE : ret nz
    ld a,(iy+FST)
    cp ST_FALL : ret z
    cp ST_DEAD : ret z
    cp ST_BOW : jr nz,.nb
    ld a,(bowed) : or a : ret nz
    inc a : ld (bowed),a : ld c,$20 : ret
.nb: ld a,(retreat) : or a : jr z,.nr
    dec a : ld (retreat),a : ld c,1 : ret
.nr: ld a,(riposte) : or a : jr z,.nrp
    xor a : ld (riposte),a : jp .strike
.nrp: ld a,(iy+FST) : cp ST_PUNCH : jr z,.oa
    cp ST_KICK : jr z,.oa
    xor a : ld (reacted),a : jr .norm
.oa: ld a,(aiflags) : and FL_COUNTER : jr z,.re
    ld a,(iy+FWC) : or a : jr nz,.re
    ld a,(iy+FTM) : cp 3 : jr nc,.re
    call getsep : cp PREACH+1 : jr c,.strike
.re: ld a,(reacted) : or a : jr nz,.norm
    inc a : ld (reacted),a
    call getsep : cp KREACH+2 : jr nc,.norm
    call rnd : ld hl,evadep : cp (hl) : jr nc,.g
    ld c,1 : ret
.g: sub (hl) : ld hl,guardp : cp (hl) : jr nc,.norm
    ld c,$40 : ret
.norm: ld a,(ix+FCOOL) : or a : jr z,.act
    dec (ix+FCOOL) : ret
.act: call rnd : and 7 : ld hl,aibase : add a,(hl) : ld (ix+FCOOL),a
    ld a,(aiflags) : and FL_BOSS : jr z,.nbs
    ld a,(ix+FHP) : add a,a : cp (ix+FMAX) : jr nc,.nbs
    call rnd : and 3 : ld (ix+FCOOL),a
.nbs: ld a,(aiflags) : and FL_RHYTHM : jr z,.nrh
    ld hl,aicount : inc (hl) : bit 2,(hl) : jr z,.nrh
    ld (ix+FCOOL),1
.nrh: call getsep : ld e,a
    call rnd : ld d,a
    ld a,e : cp KREACH+1 : jr nc,.fwd
    cp KREACH : jr z,.kr
    ld a,d : cp 100 : jr c,.punch
    cp 190 : jr c,.kick
    cp 225 : jr c,.back
    ret
.kr: ld a,d : cp 140 : jr c,.kick
    cp 215 : jr c,.fwd
    ret
.strike: call getsep : cp PREACH+1 : jr nc,.kick
.punch: call aiheight : call aifeint : ld c,4 : ret
.kick: call aiheight : call aifeint : ld c,8 : ret
.fwd: ld (ix+FCOOL),2 : ld c,2 : ret
.back: ld c,1 : ret
aiheight:
    call rnd : and 3 : cp 3 : jr nz,.h
    ld a,1
.h: ld b,a : ret
aifeint:
    ld a,(aiflags) : and FL_FEINT : ret z
    call rnd : cp 90 : ret nc
    ld (ix+FFEINT),1 : ret

rnd:
    ld hl,(seed)
    ld a,h : rra : ld a,l : rra : xor h : ld h,a
    ld a,l : rra : ld a,h : rra : xor l : ld l,a
    xor h : ld h,a
    ld (seed),hl : ret

; ---------------------------------------------------------------------------
;  Input
; ---------------------------------------------------------------------------
readin:
    ld c,0 : ld b,1
    ld a,(joyon) : or a : jr z,.keys
    in a,($2C) : ld e,a : in a,($2E) : ld d,a : and e : ld e,a
    bit 2,e : jr nz,.j1
    set 0,c
.j1: bit 3,e : jr nz,.j2
    set 1,c
.j2: bit 0,e : jr nz,.j3
    ld b,0
.j3: bit 1,e : jr nz,.j4
    ld b,2
.j4: bit 4,d : jr nz,.j5
    set 2,c
.j5: in a,($2D) : bit 4,a : jr nz,.keys
    set 3,c
.keys: ld hl,keytab
.kl: ld a,(hl) : or a : jr z,.kd
    ld e,a : ld d,$68 : ld a,(de) : inc hl : and (hl) : inc hl : jr nz,.kn
    ld a,(hl) : or c : ld c,a : inc hl : ld a,(hl) : inc hl
    cp 3 : jr nc,.kl
    ld b,a : jr .kl
.kn: inc hl : inc hl : jr .kl
.kd: ld a,c : and $0C : cp $0C : jr nz,.ng       ; both buttons = guard
    ld a,c : and $F3 : or $40 : ld c,a
.ng: ld a,(prevst) : ld e,a
    ld a,c : and $10 : ld (prevst),a
    ld a,e : or a : jr z,.st
    res 4,c
.st: ld a,c : ld (cmd),a
    ld a,b : ld (cmdh),a : ret
keytab:                         ; row address low byte, bit mask, command bits, height
    db $EF,$20,$01,9            ; M  back
    db $EF,$08,$02,9            ; ,  forward
    db $EF,$10,$10,9            ; SPACE stance
    db $EF,$01,$40,9            ; N  guard
    db $FE,$10,$04,0            ; Q  punch high
    db $FE,$02,$08,0            ; W  kick high
    db $FD,$10,$04,1            ; A  punch mid
    db $FD,$02,$08,1            ; S  kick mid
    db $FB,$10,$04,2            ; Z  punch low
    db $FB,$02,$08,2            ; X  kick low
    db $FB,$01,$20,9            ; B  bow
    db 0

; ---------------------------------------------------------------------------
;  Sound: one-bit speaker on the latch (bits 0 and 5 in push-pull)
; ---------------------------------------------------------------------------
sfx:                            ; request an effect (higher number wins)
    ld hl,sfxreq : cp (hl) : ret c
    ld (hl),a : ret
dosound:
    ld a,(sfxreq) : or a : jr z,.mus
    ld e,a : xor a : ld (sfxreq),a
    ld a,e : cp SFX_WIN : jr z,.win
    ld a,(sfxon) : or a : ret z
    ld a,(demo) : or a : ret nz
    ld a,e : add a,a : ld e,a : ld d,0 : ld hl,sfxtab-2 : add hl,de
    ld a,(hl) : inc hl : ld h,(hl) : ld l,a : jp (hl)
.win: ld a,(demo) : or a : ret nz
    ld hl,tune_win : jp playtune_nk
.mus: ld a,(musicon) : or a : ret z
    ld a,(demo) : or a : ret nz
    ld hl,musdiv : dec (hl) : ret nz
    ld (hl),12
    ld hl,(musptr) : ld a,(hl) : cp $FF : jr nz,.n
    ld hl,(musbase) : ld a,(hl)
.n: inc hl : ld (musptr),hl
    or a : ret z
    dec a : ld e,a : add a,a : add a,e : add a,a : ld e,a : ld d,0
    ld hl,bliptab : add hl,de
playrec:                        ; HL -> pulse, gap, cycles
    ld e,(hl) : inc hl : ld d,(hl) : inc hl : push de
    ld e,(hl) : inc hl : ld d,(hl) : inc hl
    ld c,(hl) : inc hl : ld b,(hl)
    pop hl
ptone:                          ; HL = pulse width, DE = gap, BC = cycles
    ld (.n1+1),hl : ld (.n2+1),de
.l: ld a,(latchv) : xor $21 : ld (LATCH),a
.n1: ld hl,0
.d1: dec hl : ld a,h : or l : jr nz,.d1
    ld a,(latchv) : ld (LATCH),a
.n2: ld hl,0
.d2: dec hl : ld a,h : or l : jr nz,.d2
    dec bc : ld a,b : or c : jr nz,.l
    ret
noise:                          ; B = length, C = pitch
.l: call rnd : and 1 : jr z,.s
    ld a,(latchv) : xor $21 : ld (LATCH),a : jr .d
.s: ld a,(latchv) : ld (LATCH),a
.d: ld a,c
.w: dec a : jr nz,.w
    djnz .l
    ld a,(latchv) : ld (LATCH),a : ret

sfxtab: dw x_step,x_bow,x_swish,x_rumble,x_block,x_thud,x_hit,x_ctr,x_gong,x_ko
x_step: ld hl,r_step : jp playrec
x_bow: ld hl,r_bow : jp playrec
x_swish: ld b,22 : ld c,3 : jp noise
x_rumble: ld b,120 : ld c,40 : jp noise
x_block: ld hl,r_blk : call playrec
    ld b,20 : ld c,2 : jp noise
x_thud: ld hl,r_heavy : call playrec
    ld b,30 : ld c,25 : jp noise
x_hit: ld b,60 : ld c,12 : call noise
    ld hl,r_thud : jp playrec
x_ctr: ld hl,r_ctr : call playrec
    jr x_hit
x_gong: ld hl,r_gong : call playrec
    ld b,40 : ld c,30 : jp noise
x_ko: ld b,90 : ld c,16 : call noise
    ld hl,r_ko1 : call playrec
    ld hl,r_ko2 : call playrec
    ld hl,r_ko3 : jp playrec

playtune_nk:                    ; play a tune, no key abort
    xor a : ld (tunekeys),a
playtune:                       ; HL = tune -> NZ if a key stopped it
    ld a,(musicon) : or a : jr nz,.l
    xor a : ret
.l: ld e,(hl) : inc hl : ld d,(hl) : inc hl
    ld a,d : and e : inc a : ret z
    push de
    ld e,(hl) : inc hl : ld d,(hl) : inc hl
    ld c,(hl) : inc hl : ld b,(hl) : inc hl
    ex (sp),hl
    ld a,h : or l : jr z,.rest
    call ptone
    jr .chk
.rest:
.d: dec de : ld a,d : or e : jr nz,.d
.chk: pop hl
    ld a,(tunekeys) : or a : jr z,.l
    push hl : call menukey : pop hl
    jr z,.l
    ret

; ---------------------------------------------------------------------------
;  Text
; ---------------------------------------------------------------------------
press_txt: db "PRESS SPACE OR FIRE",0
diff_txt: db "D:EASY  ",0
    db "D:NORMAL",0
    db "D:HARD  ",0
mus_on: db "MUSIC:ON ",0
mus_off: db "MUSIC:OFF",0
fx_on: db "FX:ON ",0
fx_off: db "FX:OFF",0
stg_txt: db "STG:1",0
vibed_txt: db "VIBED BY BPM 2026",0
stage_txt: db "STAGE 1",0
load_txt: db "LOADING...",0
sderr_txt: db "CAN'T READ FROM SD CARD:",0
retry_txt: db "FIRE: RETRY   Q: TITLE",0
defeat_txt: db "FIRE: RETRY DUEL  Q: QUIT",0
demo_txt: db "DEMO ",0
hall_txt: db "HALL OF MASTERS",0
newm_txt: db "A NEW MASTER!",0
name_txt: db "M , CHANGE   FIRE NEXT",0
cardtab:
    dw n1,h1,n2,h2,n3,h3,n4,h4,n5,h5,n6,h6
n1: db "THE ROPE BRIDGE",0
h1: db "KICKS REACH FURTHER THAN FISTS",0
n2: db "THE OUTER COURT",0
h2: db "STRIKE AS HE WINDS UP",0
n3: db "THE LANTERN HALL",0
h3: db "HE COUNTERS. LET HIM MOVE FIRST",0
n4: db "THE CLIFF PATH",0
h4: db "STOP WHEN A SHADOW FALLS",0
n5: db "THE INNER GATE",0
h5: db "THREE FOES. SAVE YOUR STRENGTH",0
n6: db "THE TIGER THRONE",0
h6: db "WATCH FOR HIS FEINTS",0
open_txt:
    db 1,43,$55,"THREE PINES DOJO BURNS. OLD",0
    db 1,50,$55,"MASTER HOSHI IS DRAGGED AWAY",0
    db 4,57,$FF,"INTO THE NIGHT.",0
    db $FF
story_txt:
    db 11,2,$FF,"TIGER GATE",0
    db 1,12,$55,"KUROKAGE'S RAIDERS BURNED THE",0
    db 0,20,$55,"DOJO AT THREE PINES AND DRAGGED",0
    db 0,28,$55,"OLD MASTER HOSHI TO THE FORTRESS",0
    db 5,36,$55,"BEYOND THE TIGER GATE.",0
    db 0,46,$00,"REN, HIS LAST STUDENT, FOLLOWS.",0
    db 7,54,$00,"ALONE. BAREHANDED.",0
    db $FF
ctrl_txt:
    db 3,1,$FF,"THE WAY OF THE EMPTY HAND",0
    db 3,10,$55,"Q A Z   PUNCH HIGH MID LOW",0
    db 3,17,$55,"W S X   KICK  HIGH MID LOW",0
    db 2,24,$55,"M AND , STEP BACK OR FORWARD",0
    db 1,31,$55,"N GUARD   B BOW   SPACE STANCE",0
    db 1,39,$00,"JOYSTICK: FIRE PUNCH, ARM KICK",0
    db 1,46,$00,"BOTH BUTTONS GUARD. UP OR DOWN",0
    db 7,52,$00,"AIMS HIGH OR LOW.",0
    db 5,59,$FF,"HOLD FORWARD TO RUN ON",0
    db $FF
end_txt:
    db 1,43,$55,"THE TIGER GATE STANDS OPEN.",0
    db 0,50,$55,"REN WALKS HOME BESIDE HIS MASTER",0
    db 0,57,$FF,"AND THREE PINES WILL RISE AGAIN.",0
    db $FF
credit_txt:
    db 11,6,$FF,"TIGER GATE",0
    db 7,20,$55,"VIBED BY BPM 2026",0
    db 5,34,$00,"FOR THE DICK SMITH VZ300",0
    db 3,42,$00,"BENNVENN SD LOADER AND 128K",0
    db 5,56,$55,"THANK YOU FOR PLAYING",0
    db $FF
casttab:
    dw herogfx+F_FIGHT1*192,c0, PACK+1536,c1, PACK+1728,c2, PACK+1920,c3
    dw PACK+2112,c4, PACK+2304,c5, PACK+2496,c6
c0: db "REN, THE LAST STUDENT",0
c1: db "THE BRIDGE KEEPER",0
c2: db "THE COURT GUARDS",0
c3: db "THE LANTERN MONK",0
c4: db "THE CLIFF SCOUT",0
c5: db "THE GATE ONI",0
c6: db "KUROKAGE",0
clr_txt: db "STAGE 1 CLEAR",0
res_txt:
    db 9,4,$FF
    db "STAGE CLEAR",0
    db 7,16,$55
res_k: db "FOES DEFEATED  00",0
    db 7,24,$55
res_c: db "CLEAN WINS     00",0
    db 7,32,$55
res_r: db "RETRIES        00",0
    db 7,40,$00
res_b: db "BONUS      00000",0
    db 7,50,$FF
res_s: db "SCORE      00000",0
    db $FF
hidef: db "BPM",$88,$13,"REN",$A0,$0F,"HSH",$B8,$0B,"KRK",$D0,$07,"ONI",$E8,$03

    include "gen/music.asm"
font: incbin "gen/font.bin"
rockgfx: incbin "gen/rock.bin"
    align 256
masktab: incbin "gen/tables.bin"
bmask equ masktab+256
herogfx: incbin "gen/hero.bin"
resend:
    assert resend <= PACK
