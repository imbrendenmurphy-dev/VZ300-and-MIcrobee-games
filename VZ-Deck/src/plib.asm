; ================================================================ VZ-DECK player plug-in runtime
; loaded at 0xA000 by VZ-DECK; returns by reloading SHELL.VZ
HO      EQU 0x7FC0
VRAM    EQU 0x7000
SPK     EQU 0x6800
CLS     EQU 0x01C9
PRINT   EQU 0x28A7
D_C2S   EQU 0x480D
D_READ  EQU 0x578E
D_NEXT  EQU 0x48BF

        ORG 0xA000
entry:  DI
        LD SP,0xFFFF
        XOR A
        LD (SPK),A
        LD HL,vars
        LD DE,vars+1
        LD BC,vars_end-vars-1
        LD (HL),0
        LDIR
        LD HL,HO+3
        LD DE,0xFA12
        LD BC,4
        LDIR
        LD A,(HO+29)
        CALL outset
        LD HL,(HO+7)
        LD (fsize),HL
        LD A,(HO+9)
        LD (fsize+2),A
        CALL fmt_init      ; NZ = can't play it, HL = message
        JR NZ,fail
        CALL screen
        CALL vsync
mloop:  CALL fmt_tick      ; NZ = the song has ended
        JR NZ,done
        CALL vapply
        CALL drums
        CALL keys
        LD A,(stopf)
        OR A
        JR NZ,done
        CALL draw
        CALL tickrun
        JR mloop
fail:   PUSH HL
        CALL CLS
        POP HL
        CALL PRINT
        LD B,100
fl_w:   CALL vsync
        DJNZ fl_w
done:   XOR A
        LD (SPK),A
        LD HL,rl_src       ; the shell is about to land on top of us: run the
        LD DE,0x7600       ; reloader from spare video RAM
        LD BC,rl_end-rl_src
        LDIR
        JP 0x7600
rl_src: LD HL,0x4456       ; "VD": tells the shell it is coming back
        LD (HO),HL
        LD HL,HO+22
        LD DE,0xFA12
        LD BC,4
        LDIR
        LD HL,0x7FE8
        LD (0xFB80),HL
        LD HL,(HO+26)
        LD DE,511
        ADD HL,DE
        LD A,H
        SRL A
        LD (HO+28),A
        CALL D_C2S
        CALL D_READ
        DI
rl_l:   LD HL,HO+28
        DEC (HL)
        JR Z,rl_x
        LD HL,(0xFB80)
        LD DE,512
        ADD HL,DE
        LD (0xFB80),HL
        CALL D_NEXT
        DI
        JR rl_l
rl_x:   LD HL,0xF800
        LD (0xFB80),HL
        JP 0x8000
rl_end:

; ---- load the whole file to fbuf; NZ if it will not fit
loadall: LD HL,(fsize)
        LD A,(fsize+2)
        OR A
        JR NZ,la_big
        LD DE,0xF800-fbuf+1
        PUSH HL
        OR A
        SBC HL,DE
        POP HL
        JR NC,la_big
        LD A,H
        OR L
        JR Z,la_big
        LD DE,511
        ADD HL,DE
        LD A,H
        SRL A
        LD (secs),A
        LD HL,fbuf
        LD (0xFB80),HL
        CALL D_C2S
        CALL D_READ
        DI
la_l:   LD HL,secs
        DEC (HL)
        JR Z,la_x
        LD HL,(0xFB80)
        LD DE,512
        ADD HL,DE
        LD (0xFB80),HL
        CALL D_NEXT
        DI
        JR la_l
la_x:   LD HL,0xF800
        LD (0xFB80),HL
        XOR A
        RET
la_big: LD HL,s_big
        OR 1
        RET

; ---- read the file a sector at a time through the DOS buffer at F800
sopen:  LD HL,(fsize)
        LD DE,511
        ADD HL,DE
        LD A,(fsize+2)
        ADC A,0
        SRL A
        RR H
        LD L,H
        LD H,A
        LD (srem),HL       ; sectors still to come
        LD HL,0xF800
        LD (0xFB80),HL
        CALL D_C2S
        CALL D_READ
        DI
        LD HL,0xF800
        LD (sptr),HL
        RET
sgetb:  PUSH HL           ; next byte -> A; 0xFD (end mark) past the end
        LD HL,(sptr)
        LD A,H
        CP 0xFA
        JR NZ,sg_1
        PUSH DE
        PUSH BC
        LD HL,(srem)
        DEC HL
        LD (srem),HL
        LD A,H
        OR L
        JR Z,sg_e
        CALL D_NEXT
        DI
        LD A,(debt)
        ADD A,1
        LD (debt),A
sg_e:   POP BC
        POP DE
        LD HL,0xF800
        LD A,(srem)
        LD B,A
        LD A,(srem+1)
        OR B
        JR NZ,sg_1
        POP HL
        LD A,0xFD
        RET
sg_1:   LD A,(HL)
        INC HL
        LD (sptr),HL
        POP HL
        RET

; ---- voice outputs -> sound loop. Arrays of 3, stride 2:
;      vper AY period, vamp 0-15 (16+ = envelope: full), vton tone on, vstep result
vapply: LD IX,vper
        LD IY,e_w0
        CALL va_1
        LD IX,vper+2
        LD IY,e_w1
        CALL va_1
        LD IX,vper+4
        LD IY,e_w2
va_1:   LD A,(IX+12)
        OR A
        JR Z,va_m
        LD A,(IX+6)
        AND 0x1F
        JR Z,va_m
        CP 16
        JR C,va_2
        LD A,15
va_2:   ADD A,A
        ADD A,A
        ADD A,A
        LD (IY+1),A
        LD L,(IX+0)
        LD A,(IX+1)
        AND 0x0F
        LD H,A
        LD DE,12
        PUSH HL
        OR A
        SBC HL,DE
        POP HL
        JR C,va_m
        LD A,L
        CP (IX+24)
        JR NZ,va_d
        LD A,H
        CP (IX+25)
        JR Z,va_s          ; same pitch as last time: step still good
va_d:   LD (IX+24),L
        LD (IX+25),H
        LD B,H
        LD C,L
        LD A,(ksh)
        LD L,A
        LD DE,(ksl)
        CALL div24
        LD (IX+18),E
        LD (IX+19),D
va_s:
        LD A,(andv)
        LD (IY+4),A
        LD A,(xorv)
        LD (IY+6),A
        RET
va_m:   LD (IY+4),0
        LD A,(xorm)
        LD (IY+6),A
        RET
div24:  LD H,0            ; L:D:E / BC -> DE   (L < BC)
        LD A,16
dv_l:   SLA E
        RL D
        ADC HL,HL
        SBC HL,BC
        JR NC,dv_1
        ADD HL,BC
        DEC A
        JR NZ,dv_l
        RET
dv_1:   INC E
        DEC A
        JR NZ,dv_l
        RET

; ---- noise bursts for drum hits (dreq: 1 hat, 2 snare)
drums:  LD A,(dreq)
        OR A
        RET Z
        LD B,50
        CP 1
        JR Z,dm_1
        LD B,250
dm_1:   XOR A
        LD (dreq),A
        LD HL,(nseed)
        LD A,H
        OR L
        JR NZ,ns_l
        LD HL,0xACE1
ns_l:   ADD HL,HL
        JR NC,ns_1
        LD A,H
        XOR 0x10
        LD H,A
        LD A,L
        XOR 0x21
        LD L,A
ns_1:   LD A,H
        RLCA
        SBC A,A
o_na:   AND 0x21
o_nx:   XOR 0x20
o_no:   LD (SPK),A
        LD C,4
ns_2:   DEC C
        JR NZ,ns_2
        DJNZ ns_l
        LD (nseed),HL
        RET

; ---- the sound loop, run until the next field starts (50 ticks a second)
tickrun: LD (spsave),SP
        LD HL,(pha1)
        LD DE,(vstep+2)
        EXX
        LD HL,(pha2)
        LD BC,(vstep+4)
        LD DE,(pha0)
        EXX
        LD SP,(vstep)
        LD C,0x80
tr_ch:  LD B,16
e_lp:   ADD HL,DE
        LD A,H
e_w1:   CP 0x80
        SBC A,A
        AND 0
        XOR 0
o_e1:   LD (SPK),A
        EXX
        ADD HL,BC
        LD A,H
e_w2:   CP 0x80
        SBC A,A
        AND 0
        XOR 0
o_e2:   LD (SPK),A
        EX DE,HL
        ADD HL,SP
        LD A,H
e_w0:   CP 0x80
        SBC A,A
        AND 0
        XOR 0
o_e0:   LD (SPK),A
        EX DE,HL
        EXX
        DJNZ e_lp
        LD A,(0x6800)
        XOR C
        AND 0x80
        JP NZ,tr_ch
        LD A,C
        OR A
        JR Z,tr_x
        LD C,0
        JP tr_ch
tr_x:   LD (pha1),HL
        EXX
        LD (pha2),HL
        LD (pha0),DE
        EXX
        LD SP,(spsave)
        RET

; ---- sound output: 0 speaker, 1 cassette, 2 both, 3 printer port
outset: AND 3
        LD (omode),A
        LD C,A
        ADD A,A
        ADD A,C
        LD E,A
        LD D,0
        LD HL,omtab
        ADD HL,DE
        LD A,(HL)
        LD (andv),A
        LD (o_na+1),A
        INC HL
        LD A,(HL)
        LD (xorv),A
        LD (o_nx+1),A
        INC HL
        LD A,(HL)
        LD (xorm),A
        LD HL,KSTEP&0xFFFF
        LD A,KSTEP/65536
        LD B,0x32
        LD C,0x00
        LD D,0x68
        LD E,A
        LD A,(omode)
        CP 3
        LD A,E
        JR NZ,os_1
        LD HL,KSTEPP&0xFFFF
        LD A,KSTEPP/65536
        LD B,0xD3
        LD C,14
        LD D,0
os_1:   LD (ksl),HL
        LD (ksh),A
        LD HL,o_e0
        CALL os_w
        LD HL,o_e1
        CALL os_w
        LD HL,o_e2
        CALL os_w
        LD HL,o_no
os_w:   LD (HL),B
        INC HL
        LD (HL),C
        INC HL
        LD (HL),D
        RET
omtab:  DB 0x21,0x20,0x00, 0x02,0x04,0x04, 0x23,0x24,0x04, 0x21,0x20,0x00
s_otag: DB "SPK",0,"CAS",0,"S+C",0,"PRN",0

; ---- screen
screen: CALL CLS
        LD DE,VRAM
        LD HL,s_top
        LD C,0x40
        CALL puts
        LD HL,s_fmt
        CALL puts
        LD A,(omode)
        ADD A,A
        ADD A,A
        LD L,A
        LD H,0
        LD DE,s_otag
        ADD HL,DE
        LD DE,VRAM+28
        CALL puts
        LD DE,VRAM+15*32
        LD HL,s_help
        CALL puts
        LD DE,VRAM+2*32
        LD HL,HO+11
        LD C,0
        LD B,8
        CALL putn
        LD A,'.'
        CALL putc
        LD B,3
        CALL putn
        LD DE,VRAM+6*32
        LD HL,s_ca
        CALL puts
        LD DE,VRAM+8*32
        LD HL,s_cb
        CALL puts
        LD DE,VRAM+10*32
        LD HL,s_cc
        CALL puts
        LD A,0xFF
        LD (blen),A
        LD (blen+1),A
        LD (blen+2),A
        JP fmt_title
; text from HL, at most B characters, stops at a zero; lower case made upper
ptext:  LD A,(HL)
        OR A
        RET Z
        CP 0x60
        JR C,pt_1
        SUB 0x20
pt_1:   CALL putc
        INC HL
        DJNZ ptext
        RET
putc:   AND 0x3F
        OR C
        LD (DE),A
        INC DE
        RET
puts:   LD A,(HL)
        OR A
        RET Z
        CALL putc
        INC HL
        JR puts
putn:   LD A,(HL)
        CALL putc
        INC HL
        DJNZ putn
        RET
prhex:  PUSH AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL ph1
        POP AF
ph1:    AND 15
        CP 10
        JR C,ph2
        ADD A,7
ph2:    ADD A,'0'
        JP putc
vsync:  LD A,(0x6800)
        RLCA
        JR NC,vsync
vs2:    LD A,(0x6800)
        RLCA
        JR C,vs2
        RET

; ---- one voice row per tick, status line every 8 ticks
draw:   LD HL,dcnt2
        INC (HL)
        LD A,(HL)
        AND 3
        CP 3
        JR NZ,dw_v
        LD A,(HL)
        AND 0x1C
        RET NZ
        LD DE,VRAM+14*32
        LD C,0
        CALL fmt_status
        LD A,(dshow)
        OR A
        RET Z
        DEC A
        LD (dshow),A
        RET NZ
        LD DE,VRAM+12*32+6
        LD HL,s_blank
        LD C,0
        JP puts
dw_v:   LD C,A            ; voice
        ADD A,A
        LD E,A
        LD D,0
        LD HL,vamp
        ADD HL,DE
        LD A,(HL)
        LD B,A
        LD HL,vton+0
        ADD HL,DE
        LD A,(HL)
        OR A
        JR NZ,dw_1
        LD B,0
dw_1:   LD A,B
        CP 16
        JR C,dw_2
        LD B,15
dw_2:   LD HL,vnote
        LD E,C
        ADD HL,DE
        LD A,B
        OR A
        LD A,(HL)
        JR NZ,dw_3
        LD A,0xFF
dw_3:   LD (dnote),A
        LD HL,blen
        ADD HL,DE
        LD A,(HL)
        CP B
        JR NZ,dw_4
        LD HL,dlast
        ADD HL,DE
        LD A,(dnote)
        CP (HL)
        RET Z
dw_4:   LD HL,blen
        ADD HL,DE
        LD (HL),B
        LD HL,dlast
        ADD HL,DE
        LD A,(dnote)
        LD (HL),A
        LD A,C
        ADD A,A
        ADD A,A
        ADD A,A
        ADD A,A
        ADD A,A
        ADD A,A
        LD L,A
        LD H,0
        LD DE,VRAM+6*32+4
        ADD HL,DE
        EX DE,HL          ; DE = bar start
        LD HL,barcol
        LD A,C
        ADD A,L
        LD L,A
        JR NC,dw_5
        INC H
dw_5:   LD A,(HL)
        LD H,15
dw_b:   LD L,0x80
        DEC B
        JP M,dw_6
        LD L,A
dw_6:   PUSH AF
        LD A,L
        LD (DE),A
        POP AF
        INC DE
        DEC H
        JR NZ,dw_b
        INC DE
        LD C,0
        LD A,(dnote)
        CP 0xFF
        JR NZ,dw_n
        LD A,'-'
        CALL putc
        LD A,'-'
        CALL putc
        LD A,'-'
        JP putc
dw_n:   LD B,0
dw_o:   CP 12
        JR C,dw_p
        SUB 12
        INC B
        JR dw_o
dw_p:   ADD A,A
        LD L,A
        LD H,0
        PUSH DE
        LD DE,nnames
        ADD HL,DE
        POP DE
        LD A,(HL)
        CALL putc
        INC HL
        LD A,(HL)
        CALL putc
        LD A,B
        ADD A,'1'
        JP putc
; mark a drum hit on screen
showdrum: LD DE,VRAM+12*32+6
        LD HL,s_hat
        CP 1
        JR Z,sd_1
        LD HL,s_snare
sd_1:   LD C,0x40
        CALL puts
        LD A,6
        LD (dshow),A
        RET

; ---- keys: RETURN / fire stop, SPACE / P pause
keys:   CALL kscan
        OR A
        JR NZ,ky_1
        LD (armed),A
        INC A
        LD (armed),A
        RET
ky_1:   LD B,A
        LD A,(armed)
        OR A
        RET Z
        XOR A
        LD (armed),A
        LD A,B
        DEC A
        JR NZ,ky_p
        INC A
        LD (stopf),A
        RET
ky_p:   XOR A
        LD (SPK),A
        LD DE,VRAM+14*32+24
        LD HL,s_paused
        LD C,0x40
        CALL puts
ky_w1:  CALL vsync
        CALL kscan
        OR A
        JR NZ,ky_w1
ky_w2:  CALL vsync
        CALL kscan
        OR A
        JR Z,ky_w2
        DEC A
        JR NZ,ky_w3
        INC A
        LD (stopf),A
ky_w3:  LD DE,VRAM+14*32+24
        LD HL,s_blank8
        LD C,0
        JP puts
kscan:  LD A,(0x68BF)
        CPL
        LD B,A
        BIT 2,B
        LD A,1
        RET NZ
        BIT 4,B
        LD A,2
        RET NZ
        LD A,(0x68EF)
        CPL
        AND 0x10
        LD A,2
        RET NZ
        LD A,(HO+2)
        OR A
        RET Z
        IN A,(0x2E)
        CPL
        AND 0x10
        RET Z
        LD A,1
        RET

barcol: DB 0x9F,0xDF,0xBF
nnames: DB "C-C#D-D#E-F-F#G-G#A-A#B-"
s_top:  DB "VZ-DECK 0.8  ",0
s_help: DB "SPACE:PAUSE        RETURN:STOP  ",0
s_ca:   DB "A",0
s_cb:   DB "B",0
s_cc:   DB "C",0
s_hat:  DB "HAT  ",0
s_snare: DB "SNARE",0
s_blank: DB "     ",0
s_blank8: DB "        ",0
s_paused: DB "PAUSED",0
s_big:  DB "FILE TOO BIG FOR THIS PLAYER",13,0
E_LIB:
