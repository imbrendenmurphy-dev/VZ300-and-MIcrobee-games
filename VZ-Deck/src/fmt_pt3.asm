; ================================================================ PT3 (ProTracker 3 / Vortex Tracker II)
C_ADDR  EQU 0
C_SKIP  EQU 2
C_SKIPC EQU 3
C_NOTE  EQU 4
C_SMP   EQU 5
C_ORN   EQU 7
C_PSMP  EQU 9
C_PORN  EQU 10
C_VOL   EQU 11
C_EN    EQU 12
C_ENV   EQU 13
C_TACC  EQU 14
C_TSLD  EQU 16
C_TSTEP EQU 18
C_TDLY  EQU 20
C_TCNT  EQU 21
C_ASLD  EQU 22
C_NSLD  EQU 23
C_PORT  EQU 24
C_TDELT EQU 25
C_SLTN  EQU 27
C_VON   EQU 28
C_VOFF  EQU 29
C_VCNT  EQU 30
C_OUTP  EQU 31
C_OUTA  EQU 33
C_OUTT  EQU 34
C_OUTN  EQU 35
C_NOIS  EQU 36
C_NEWN  EQU 37
C_PREVN EQU 38
C_IDX   EQU 39
CHSZ    EQU 40

fmt_init: CALL loadall
        RET NZ
        LD A,(fbuf)
        CP 'P'
        JR Z,pi_1
        CP 'V'
        JR Z,pi_v
pi_bad: LD HL,s_notpt3
        OR 1
        RET
pi_v:   LD A,6
        JR pi_2
pi_1:   LD A,(fbuf+1)
        CP 'r'
        JR NZ,pi_bad
        LD A,(fbuf+13)
        SUB '0'
        CP 10
        JR C,pi_2
        LD A,6
pi_2:   LD (ver),A
        LD A,(fbuf+0x64)
        OR A
        JR NZ,pi_3
        INC A
pi_3:   LD (delay),A
        LD A,(fbuf+0x65)
        LD (npos),A
        LD HL,(fbuf+0x67)
        LD DE,fbuf
        ADD HL,DE
        LD (patp),HL
        LD IX,chA
        CALL chinit
        LD IX,chB
        CALL chinit
        LD IX,chC
        CALL chinit
        LD A,1
        LD (dcnt),A
        LD (chB+C_IDX),A
        INC A
        LD (chC+C_IDX),A
        LD A,0xFF
        LD (rownote),A
        LD (rownote+1),A
        LD (rownote+2),A
        XOR A
        LD (posi),A
        LD (nbase),A
        CALL setpat
        RET NZ
        XOR A
        RET
chinit: LD (IX+C_SKIP),1
        LD (IX+C_SKIPC),1
        LD (IX+C_VOL),15
        LD A,1
        CALL setsmp
        XOR A
        CALL setorn
        RET

; position posi -> the three channels' pattern data; NZ when the song is over
setpat: LD A,(npos)
        LD B,A
        LD A,(posi)
        CP B
        JR NC,sp_end
        LD E,A
        LD D,0
        LD HL,fbuf+0xC9
        ADD HL,DE
        LD A,(HL)
        CP 0xFF
        JR Z,sp_end
        LD E,A
        LD HL,(patp)
        ADD HL,DE
        ADD HL,DE
        LD IX,chA
        CALL sp_1
        LD IX,chB
        CALL sp_1
        LD IX,chC
        CALL sp_1
        XOR A
        RET
sp_end: OR 1
        RET
sp_1:   LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        PUSH HL
        LD HL,fbuf
        ADD HL,DE
        LD (IX+C_ADDR),L
        LD (IX+C_ADDR+1),H
        POP HL
        RET

setsmp: LD (cursmp),A
        ADD A,A           ; A = sample number
        LD E,A
        LD D,0
        LD HL,fbuf+0x69
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD HL,fbuf
        ADD HL,DE
        LD (IX+C_SMP),L
        LD (IX+C_SMP+1),H
        RET
setorn: ADD A,A           ; A = ornament number
        LD E,A
        LD D,0
        LD HL,fbuf+0xA9
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD HL,fbuf
        ADD HL,DE
        LD (IX+C_ORN),L
        LD (IX+C_ORN+1),H
        RET

; ---- one 50 Hz tick
fmt_tick: LD HL,dcnt
        DEC (HL)
        JR NZ,ft_r
        LD A,(delay)
        LD (HL),A
        LD A,1
        LD (rowflag),A
        LD HL,rownum
        INC (HL)
        LD IX,chA
        DEC (IX+C_SKIPC)
        JR NZ,ft_b
        LD L,(IX+C_ADDR)
        LD H,(IX+C_ADDR+1)
        LD A,(HL)
        OR A
        JR NZ,ft_a
        LD HL,posi
        INC (HL)
        CALL setpat
        RET NZ
        XOR A
        LD (nbase),A
        LD (rownum),A
        LD IX,chA
ft_a:   CALL interp
ft_b:   LD IX,chB
        DEC (IX+C_SKIPC)
        CALL Z,interp
        LD IX,chC
        DEC (IX+C_SKIPC)
        CALL Z,interp
ft_r:   LD IX,chA
        CALL chregs
        LD IX,chB
        CALL chregs
        LD IX,chC
        CALL chregs
        ; hand the results to the player
        LD IX,chA
        LD IY,vper
        LD HL,vnote
        LD B,3
fo_l:   LD A,(IX+C_OUTP)
        LD (IY+0),A
        LD A,(IX+C_OUTP+1)
        LD (IY+1),A
        LD A,(IX+C_OUTA)
        LD (IY+6),A
        LD A,(IX+C_OUTT)
        LD (IY+12),A
        LD A,(IX+C_NOTE)
        LD (HL),A
        ; a drum? noise at some volume, once per note
        LD A,(IX+C_NEWN)
        OR A
        JR Z,fo_0
        LD (IX+C_PREVN),0
fo_0:   LD A,(IX+C_OUTN)
        OR A
        JR Z,fo_x
        LD A,(IX+C_OUTA)
        CP 6
        JR C,fo_x
        LD A,(IX+C_PREVN)
        OR A
        JR NZ,fo_x
        LD (IX+C_PREVN),1
        PUSH HL
        PUSH BC
        LD C,2
        LD A,(IX+C_OUTT)
        OR A
        JR NZ,fo_d1
        LD A,(IX+C_NOIS)
        CP 4
        JR NC,fo_d1
        LD C,1
fo_d1:  LD A,(dreq)
        CP C
        JR NC,fo_d2
        LD A,C
        LD (dreq),A
        CALL showdrum
fo_d2:  POP BC
        POP HL
fo_x:   LD (IX+C_NEWN),0
        LD DE,CHSZ
        ADD IX,DE
        INC IY
        INC IY
        INC HL
        DJNZ fo_l
        XOR A
        RET

; ---- read one row of a channel's pattern data
interp: LD A,(IX+C_NOTE)
        LD (prnote),A
        LD A,(IX+C_TSLD)
        LD (prsld),A
        LD A,(IX+C_TSLD+1)
        LD (prsld+1),A
        LD HL,fcnt
        LD B,8
in_z:   LD (HL),0
        INC HL
        DJNZ in_z
        LD L,(IX+C_ADDR)
        LD H,(IX+C_ADDR+1)
in_l:   LD A,(HL)
        CP 0xF0
        JR C,in_1
        SUB 0xF0
        PUSH HL
        CALL setorn
        POP HL
        INC HL
        LD A,(HL)
        SRL A
        PUSH HL
        CALL setsmp
        POP HL
        LD (IX+C_ENV),0
        LD (IX+C_PORN),0
        JP in_n
in_1:   CP 0xD1
        JR C,in_2
        SUB 0xD0
        PUSH HL
        CALL setsmp
        POP HL
        JP in_n
in_2:   CP 0xD0
        JP Z,in_q
        CP 0xC1
        JR C,in_3
        SUB 0xC0
        LD (IX+C_VOL),A
        JP in_n
in_3:   CP 0xC0
        JR NZ,in_4
        LD A,0xFE
        CALL rowrec
        CALL chreset
        LD (IX+C_EN),0
        JP in_q
in_4:   CP 0xB2
        JR C,in_5
        INC HL
        INC HL
        LD (IX+C_ENV),1
        LD (IX+C_PORN),0
        JP in_n
in_5:   CP 0xB1
        JR NZ,in_6
        INC HL
        LD A,(HL)
        LD (IX+C_SKIP),A
        JP in_n
in_6:   CP 0xB0
        JR NZ,in_7
        LD (IX+C_ENV),0
        LD (IX+C_PORN),0
        JP in_n
in_7:   CP 0x50
        JR C,in_8
        SUB 0x50
        LD (IX+C_NOTE),A
        CALL rowrec
        CALL chreset
        LD (IX+C_EN),1
        LD (IX+C_NEWN),1
        JR in_q
in_8:   CP 0x40
        JR C,in_9
        SUB 0x40
        PUSH HL
        CALL setorn
        POP HL
        LD (IX+C_PORN),0
        JP in_n
in_9:   CP 0x20
        JR C,in_10
        SUB 0x20
        LD (nbase),A
        JP in_n
in_10:  CP 0x10
        JR C,in_11
        JR Z,in_10a
        INC HL
        INC HL
        LD (IX+C_ENV),1
        JR in_10b
in_10a: LD (IX+C_ENV),0
in_10b: INC HL
        LD A,(HL)
        SRL A
        PUSH HL
        CALL setsmp
        POP HL
        LD (IX+C_PORN),0
        JP in_n
in_11:  OR A
        JR Z,in_q
        CP 10
        JR NC,in_n
        CP 8
        JR C,in_11a
        SUB 2
        JR in_11b
in_11a: CP 6
        JR NC,in_n
in_11b: LD C,A
        LD B,0
        LD A,(fcnt)
        INC A
        LD (fcnt),A
        PUSH HL
        LD HL,fcnt
        ADD HL,BC
        LD (HL),A
        POP HL
in_n:   INC HL
        JP in_l
in_q:   INC HL
        ; effect parameters, last effect first
ef_l:   LD A,(fcnt)
        OR A
        JR Z,ef_x
        LD B,A
        LD A,(fcnt+1)
        CP B
        CALL Z,ef1
        LD A,(fcnt+2)
        CP B
        CALL Z,ef2
        LD A,(fcnt+3)
        CP B
        CALL Z,ef3
        LD A,(fcnt+4)
        CP B
        CALL Z,ef4
        LD A,(fcnt+5)
        CP B
        CALL Z,ef5
        LD A,(fcnt+6)
        CP B
        CALL Z,ef8
        LD A,(fcnt+7)
        CP B
        CALL Z,ef9
        LD A,(fcnt)
        DEC A
        LD (fcnt),A
        JR ef_l
ef_x:   LD (IX+C_ADDR),L
        LD (IX+C_ADDR+1),H
        LD A,(IX+C_SKIP)
        LD (IX+C_SKIPC),A
        RET
ef1:    LD A,(HL)         ; glissando
        INC HL
        LD (IX+C_TDLY),A
        LD (IX+C_TCNT),A
        LD A,(HL)
        INC HL
        LD (IX+C_TSTEP),A
        LD A,(HL)
        INC HL
        LD (IX+C_TSTEP+1),A
        LD (IX+C_PORT),0
        LD (IX+C_VCNT),0
        LD A,(IX+C_TCNT)
        OR A
        RET NZ
        LD A,(ver)
        CP 7
        RET C
        INC (IX+C_TCNT)
        RET
ef2:    LD A,(HL)         ; portamento
        LD (IX+C_TDLY),A
        LD (IX+C_TCNT),A
        INC HL
        INC HL
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        BIT 7,D
        JR Z,ef2_1
        XOR A
        SUB E
        LD E,A
        SBC A,A
        SUB D
        LD D,A
ef2_1:  PUSH HL
        PUSH DE
        LD (IX+C_PORT),1
        LD A,(IX+C_NOTE)
        LD (IX+C_SLTN),A
        CALL nfreq
        PUSH HL
        LD A,(prnote)
        LD (IX+C_NOTE),A
        CALL nfreq
        EX DE,HL
        POP HL
        OR A
        SBC HL,DE         ; delta = freq(new) - freq(old)
        LD (IX+C_TDELT),L
        LD (IX+C_TDELT+1),H
        LD A,(ver)
        CP 6
        JR C,ef2_2
        LD DE,(prsld)
        LD (IX+C_TSLD),E
        LD (IX+C_TSLD+1),D
ef2_2:  LD E,(IX+C_TSLD)
        LD D,(IX+C_TSLD+1)
        OR A
        SBC HL,DE
        POP DE
        JP P,ef2_3
        XOR A
        SUB E
        LD E,A
        SBC A,A
        SUB D
        LD D,A
ef2_3:  LD (IX+C_TSTEP),E
        LD (IX+C_TSTEP+1),D
        POP HL
        RET
ef3:    LD A,(HL)
        INC HL
        LD (IX+C_PSMP),A
        RET
ef4:    LD A,(HL)
        INC HL
        LD (IX+C_PORN),A
        RET
ef5:    LD A,(HL)
        INC HL
        LD (IX+C_VON),A
        LD (IX+C_VCNT),A
        LD A,(HL)
        INC HL
        LD (IX+C_VOFF),A
        XOR A
        LD (IX+C_TCNT),A
        LD (IX+C_TSLD),A
        LD (IX+C_TSLD+1),A
        RET
ef8:    INC HL
        INC HL
        INC HL
        RET
ef9:    LD A,(HL)
        INC HL
        OR A
        RET Z
        LD (delay),A
        RET

chreset: XOR A
        LD (IX+C_PSMP),A
        LD (IX+C_ASLD),A
        LD (IX+C_NSLD),A
        LD (IX+C_PORN),A
        LD (IX+C_TCNT),A
        LD (IX+C_TSLD),A
        LD (IX+C_TSLD+1),A
        LD (IX+C_TACC),A
        LD (IX+C_TACC+1),A
        LD (IX+C_VCNT),A
        RET

nfreq:  CP 96             ; A = note -> HL = AY period
        JR C,nf_1
        LD A,95
nf_1:   ADD A,A
        LD E,A
        LD D,0
        LD HL,ptab
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        RET

; ---- this tick's sound for one channel
chregs: LD A,(IX+C_EN)
        OR A
        JP Z,cr_off
        LD L,(IX+C_SMP)
        LD H,(IX+C_SMP+1)
        LD E,(IX+C_PSMP)
        LD D,0
        EX DE,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,DE
        INC HL
        INC HL
        LD A,(HL)
        LD (b0),A
        INC HL
        LD A,(HL)
        LD (b1),A
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD L,(IX+C_TACC)
        LD H,(IX+C_TACC+1)
        ADD HL,DE
        LD A,(b1)
        AND 0x40
        JR Z,cr_1
        LD (IX+C_TACC),L
        LD (IX+C_TACC+1),H
cr_1:   PUSH HL           ; tone offset
        ; note + ornament
        LD L,(IX+C_ORN)
        LD H,(IX+C_ORN+1)
        LD E,(IX+C_PORN)
        LD D,0
        ADD HL,DE
        INC HL
        INC HL
        LD A,(IX+C_NOTE)
        ADD A,(HL)
        BIT 7,A
        JR Z,cr_2
        XOR A
cr_2:   CP 96
        JR C,cr_3
        LD A,95
cr_3:   CALL nfreq
        POP DE
        ADD HL,DE
        LD E,(IX+C_TSLD)
        LD D,(IX+C_TSLD+1)
        ADD HL,DE
        LD A,H
        AND 0x0F
        LD (IX+C_OUTP),L
        LD (IX+C_OUTP+1),A
        ; slides
        LD A,(IX+C_TCNT)
        OR A
        JR Z,cr_s
        DEC A
        LD (IX+C_TCNT),A
        JR NZ,cr_s
        LD A,(IX+C_TDLY)
        LD (IX+C_TCNT),A
        LD L,(IX+C_TSLD)
        LD H,(IX+C_TSLD+1)
        LD E,(IX+C_TSTEP)
        LD D,(IX+C_TSTEP+1)
        ADD HL,DE
        LD (IX+C_TSLD),L
        LD (IX+C_TSLD+1),H
        LD A,(IX+C_PORT)
        OR A
        JR Z,cr_s
        LD E,(IX+C_TDELT)
        LD D,(IX+C_TDELT+1)
        OR A
        SBC HL,DE         ; sliding - delta
        LD A,H
        OR L
        JR Z,cr_hit
        LD A,(IX+C_TSTEP+1)
        XOR H
        JP P,cr_hit
        JR cr_s
cr_hit: LD A,(IX+C_SLTN)
        LD (IX+C_NOTE),A
        XOR A
        LD (IX+C_TCNT),A
        LD (IX+C_TSLD),A
        LD (IX+C_TSLD+1),A
cr_s:   ; amplitude
        LD A,(b0)
        BIT 7,A
        JR Z,cr_a2
        BIT 6,A
        LD A,(IX+C_ASLD)
        JR Z,cr_a1
        CP 15
        JR Z,cr_a2
        INC (IX+C_ASLD)
        JR cr_a2
cr_a1:  CP 0xF1
        JR Z,cr_a2
        DEC (IX+C_ASLD)
cr_a2:  LD A,(b1)
        AND 15
        ADD A,(IX+C_ASLD)
        BIT 7,A
        JR Z,cr_a3
        XOR A
cr_a3:  CP 16
        JR C,cr_a4
        LD A,15
cr_a4:  LD E,A
        LD A,(IX+C_VOL)
        ADD A,A
        ADD A,A
        ADD A,A
        ADD A,A
        ADD A,E
        LD E,A
        LD D,0
        LD HL,voltab
        ADD HL,DE
        LD A,(HL)
        LD C,A
        LD A,(b0)
        AND 1
        JR NZ,cr_a5
        LD A,(IX+C_ENV)
        OR A
        JR Z,cr_a5
        LD C,16
cr_a5:  LD (IX+C_OUTA),C
        ; noise and tone switches
        LD A,(b1)
        BIT 7,A
        JR NZ,cr_ne
        LD A,(b0)
        RRCA
        AND 0x1F
        ADD A,(IX+C_NSLD)
        LD C,A
        LD A,(b1)
        AND 0x20
        JR Z,cr_n1
        LD (IX+C_NSLD),C
cr_n1:  LD A,(nbase)
        ADD A,C
        AND 0x1F
        LD (IX+C_NOIS),A
        LD (IX+C_OUTN),1
        JR cr_t
cr_ne:  LD (IX+C_OUTN),0
cr_t:   LD A,(b1)
        CPL
        RRCA
        RRCA
        RRCA
        RRCA
        AND 1
        LD (IX+C_OUTT),A
        ; step through sample and ornament
        LD L,(IX+C_SMP)
        LD H,(IX+C_SMP+1)
        LD A,(IX+C_PSMP)
        INC A
        INC HL
        CP (HL)
        JR C,cr_p1
        DEC HL
        LD A,(HL)
cr_p1:  LD (IX+C_PSMP),A
        LD L,(IX+C_ORN)
        LD H,(IX+C_ORN+1)
        LD A,(IX+C_PORN)
        INC A
        INC HL
        CP (HL)
        JR C,cr_p2
        DEC HL
        LD A,(HL)
cr_p2:  LD (IX+C_PORN),A
        JR cr_v
cr_off: XOR A
        LD (IX+C_OUTA),A
        LD (IX+C_OUTT),A
        LD (IX+C_OUTN),A
cr_v:   ; on/off "vibrato" (effect 5)
        LD A,(IX+C_VCNT)
        OR A
        RET Z
        DEC A
        LD (IX+C_VCNT),A
        RET NZ
        LD A,(IX+C_EN)
        XOR 1
        LD (IX+C_EN),A
        LD A,(IX+C_VON)
        JR NZ,cr_v1
        LD A,(IX+C_VOFF)
cr_v1:  LD (IX+C_VCNT),A
        RET

fmt_title: LD DE,VRAM+3*32
        LD HL,fbuf+0x1E
        LD B,32
        LD C,0
        CALL ptext
        LD DE,VRAM+4*32
        LD HL,fbuf+0x42
        LD B,32
        JP ptext
fmt_status: LD HL,s_pos
        CALL puts
        LD A,(posi)
        CALL prhex
        LD A,'/'
        CALL putc
        LD A,(npos)
        DEC A
        JP prhex

s_fmt:  DB "PT3 PLAYER",0
s_pos:  DB "POS ",0
s_notpt3: DB "NOT A PT3 FILE",13,0

rowrec: PUSH HL           ; A = note (FE = off) into this channel's tracker column
        PUSH DE
        LD E,(IX+C_IDX)
        LD D,0
        LD HL,rownote
        ADD HL,DE
        LD (HL),A
        INC HL
        INC HL
        INC HL
        LD A,(cursmp)
        LD (HL),A
        POP DE
        POP HL
        RET

fmt_v3  EQU trkview
fmt_v3i EQU trkinit
s_v3hdr: DB "ROW    A        B        C     ",0
