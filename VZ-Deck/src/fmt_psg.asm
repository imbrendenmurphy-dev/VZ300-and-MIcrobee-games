; ================================================================ PSG (AY register dump, 50 frames a second)
fmt_init: LD A,(fsize+2)
        OR A
        JR NZ,pg_1
        LD HL,(fsize)
        LD DE,17
        OR A
        SBC HL,DE
        JR C,pg_bad
pg_1:   CALL sopen
        CALL sgetb
        CP 'P'
        JR NZ,pg_bad
        CALL sgetb
        CP 'S'
        JR NZ,pg_bad
        CALL sgetb
        CP 'G'
        JR NZ,pg_bad
        LD B,13
pg_h:   CALL sgetb
        DJNZ pg_h
        LD A,0xFF
        LD (regs+7),A
        XOR A
        RET
pg_bad: LD HL,s_notpsg
        OR 1
        RET

fmt_tick: LD HL,(wcnt)
        LD A,H
        OR L
        JR Z,pg_r
        DEC HL
        LD (wcnt),HL
        JR pg_o
pg_r:   CALL sgetb
        CP 0xFF
        JR Z,pg_o
        CP 0xFE
        JR Z,pg_sk
        CP 0xFD
        JR Z,pg_end
        CP 16
        JR NC,pg_r1
        LD E,A
        LD D,0
        CALL sgetb
        LD HL,regs
        ADD HL,DE
        LD (HL),A
        JR pg_r
pg_r1:  CALL sgetb
        JR pg_r
pg_sk:  CALL sgetb
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        LD A,H
        OR L
        JR Z,pg_o
        DEC HL
        LD (wcnt),HL
        JR pg_o
pg_end: OR 1
        RET
pg_o:   LD HL,sfrac       ; play time
        INC (HL)
        LD A,(HL)
        CP 50
        JR C,pg_t
        LD (HL),0
        LD HL,ssec
        INC (HL)
        LD A,(HL)
        CP 60
        JR C,pg_t
        LD (HL),0
        LD HL,smin
        INC (HL)
pg_t:   XOR A
        LD (pk),A
po_l:   LD A,(pk)         ; channel k
        LD E,A
        LD D,0
        LD IY,vper
        ADD IY,DE
        ADD IY,DE
        LD HL,regs
        ADD HL,DE
        ADD HL,DE
        LD A,(HL)
        LD (IY+0),A
        INC HL
        LD A,(HL)
        AND 0x0F
        LD (IY+1),A
        LD HL,regs+8
        ADD HL,DE
        LD A,(HL)
        AND 0x1F
        LD (IY+6),A
        LD HL,bits
        ADD HL,DE
        LD C,(HL)         ; this channel's tone bit in R7
        LD A,(regs+7)
        AND C
        LD A,0
        JR NZ,po_1
        INC A
po_1:   LD (IY+12),A
        LD L,(IY+0)
        LD H,(IY+1)
        LD A,L
        CP (IY+24)
        JR NZ,po_q
        LD A,H
        CP (IY+25)
        JR Z,po_q2        ; vapply keeps vlast: same period, same note
po_q:   PUSH DE
        PUSH BC
        CALL per2note
        POP BC
        POP DE
        LD HL,vnote
        ADD HL,DE
        LD (HL),A
po_q2:
        ; drum: noise switched on at some volume, with a short hold-off
        LD HL,cool
        ADD HL,DE
        LD A,(HL)
        OR A
        JR Z,po_c
        DEC (HL)
po_c:   LD A,C
        RLCA
        RLCA
        RLCA
        LD B,A
        LD A,(regs+7)
        AND B
        JR NZ,po_off
        LD A,(IY+6)
        CP 6
        JR C,po_off
        INC HL
        INC HL
        INC HL            ; ison
        LD A,(HL)
        LD (HL),1
        OR A
        JR NZ,po_n
        DEC HL
        DEC HL
        DEC HL
        LD A,(HL)
        OR A
        JR NZ,po_n
        LD (HL),8
        LD B,2
        LD A,(IY+12)
        OR A
        JR NZ,po_d
        LD A,(regs+6)
        AND 0x1F
        CP 4
        JR NC,po_d
        LD B,1
po_d:   LD A,(dreq)
        CP B
        JR NC,po_n
        LD A,B
        LD (dreq),A
        CALL showdrum
        JR po_n
po_off: INC HL
        INC HL
        INC HL
        LD (HL),0
po_n:   LD HL,pk
        INC (HL)
        LD A,(HL)
        CP 3
        JP C,po_l
        XOR A
        RET
bits:   DB 1,2,4

; AY period HL -> nearest note 0-95 (binary search of the period table)
per2note: LD A,H
        OR L
        LD A,0xFF
        RET Z
        LD (p2t),HL
        LD B,0            ; lo
        LD C,96           ; hi
p2_l:   LD A,B
        CP C
        RET NC            ; A = first note whose period <= target
        ADD A,C
        RRA
        LD (p2m),A
        ADD A,A
        LD E,A
        LD D,0
        LD HL,pthr
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD HL,(p2t)
        OR A
        SBC HL,DE
        LD A,(p2m)
        JR C,p2_hi        ; period > target: answer is higher
        LD C,A
        JR p2_l
p2_hi:  INC A
        LD B,A
        JR p2_l

fmt_title: LD DE,VRAM+3*32
        LD HL,s_ay
        LD C,0
        JP puts
fmt_status: LD HL,s_time
        CALL puts
        LD A,(smin)
        CALL prhex
        LD A,':'
        CALL putc
        LD A,(ssec)
        LD B,0
ps_d:   CP 10
        JR C,ps_e
        SUB 10
        INC B
        JR ps_d
ps_e:   LD C,A
        LD A,B
        ADD A,'0'
        PUSH BC
        LD C,0
        CALL putc
        POP BC
        LD A,C
        ADD A,'0'
        LD C,0
        JP putc

s_fmt:  DB "PSG PLAYER",0
s_ay:   DB "AY REGISTER DUMP",0
s_time: DB "TIME ",0
s_notpsg: DB "NOT A PSG FILE",13,0

; ---- view 3: the AY registers, live
fmt_v3i: LD DE,VRAM+5*32
        LD HL,s_v3hdr
        LD C,0x40
        CALL puts
        LD DE,VRAM+7*32
        LD HL,s_r0
        LD C,0
        CALL puts
        LD DE,VRAM+9*32
        LD HL,s_r7
        JP puts
fmt_v3: CP 2
        RET NC
        LD HL,regs
        LD DE,VRAM+7*32+4
        OR A
        JR Z,pv_1
        LD HL,regs+7
        LD DE,VRAM+9*32+4
pv_1:   LD C,0
        LD B,7
pv_l:   LD A,(HL)
        CALL prhex
        LD A,' '
        CALL putc
        INC HL
        DJNZ pv_l
        RET
s_v3hdr: DB "AY REGISTERS                    ",0
s_r0:   DB "0-6",0
s_r7:   DB "7-D",0
