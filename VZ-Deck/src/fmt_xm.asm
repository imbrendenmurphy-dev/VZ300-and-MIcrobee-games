; ================================================================ XM (FastTracker 2)
MAXCH   EQU 32
PATMAX  EQU 0x3000
fmt_init: CALL mkclt
        XOR A
        LD H,A
        LD L,A
        LD (foff),HL
        LD (foff+2),A
        LD DE,hdr
        LD BC,80
        CALL fread
        LD HL,hdr
        LD DE,s_xmid
        LD B,17
xi_c:   LD A,(DE)
        CP (HL)
        JP NZ,xi_bad
        INC HL
        INC DE
        DJNZ xi_c
        LD HL,(hdr+64)    ; song length
        LD A,H
        OR A
        JR Z,xi_1
        LD L,255
xi_1:   LD A,L
        LD (nord),A
        LD HL,(hdr+68)    ; channels
        LD A,H
        OR A
        JR Z,xi_2
        LD L,255
xi_2:   LD A,L
        LD (nch),A
        LD HL,(hdr+70)    ; patterns
        LD A,H
        OR A
        JR Z,xi_3
        LD L,255
xi_3:   LD A,L
        LD (npat),A
        LD HL,(hdr+72)    ; instruments
        LD A,H
        OR A
        JR NZ,xi_4a
        LD A,L
        CP 129
        JR C,xi_4
xi_4a:  LD A,128
xi_4:   LD (nins),A
        LD A,(hdr+76)
        OR A
        JR NZ,xi_5
        LD A,6
xi_5:   LD (speed),A
        LD HL,(hdr+78)
        LD A,H
        OR A
        LD A,255
        JR NZ,xi_6
        LD A,L
        CP 32
        JR NC,xi_6
        LD A,125
xi_6:   LD (tempo),A
        LD A,(nord)
        LD C,A
        LD B,0
        LD DE,ords
        CALL fread        ; the order list follows at 80
        ; walk the patterns: where each one's data is, its rows and size
        LD HL,(hdr+60)
        LD A,(hdr+62)
        LD DE,60
        ADD HL,DE
        ADC A,0
        LD (foff),HL
        LD (foff+2),A
        XOR A
        LD (ii),A
xp_l:   LD A,(npat)
        LD B,A
        LD A,(ii)
        CP B
        JP NC,xp_done
        LD DE,ibuf
        LD BC,9
        CALL fread
        LD HL,(foff)      ; data = (foff - 9) + header length
        LD A,(foff+2)
        LD DE,(ibuf)
        ADD HL,DE
        LD B,A
        LD A,(ibuf+2)
        ADC A,B
        LD DE,9
        OR A
        SBC HL,DE
        SBC A,0
        PUSH AF
        PUSH HL
        LD A,(ii)
        LD L,A
        LD H,0
        LD D,H
        LD E,L
        ADD HL,HL
        ADD HL,DE
        ADD HL,HL
        LD DE,ppp
        ADD HL,DE
        EX DE,HL
        POP HL
        POP AF
        EX DE,HL          ; HL = entry, A:DE = data offset
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD (HL),A
        INC HL
        LD C,A
        LD A,(ibuf+5)
        LD (HL),A         ; rows (0 = 256)
        INC HL
        LD A,(ibuf+7)
        LD (HL),A
        INC HL
        LD A,(ibuf+8)
        LD (HL),A         ; packed size
        EX DE,HL
        LD DE,(ibuf+7)
        ADD HL,DE
        LD A,C
        ADC A,0
        LD (foff),HL
        LD (foff+2),A
        LD HL,ii
        INC (HL)
        JP xp_l
xp_done: LD HL,iinfo      ; every instrument silent to start with
        LD B,129
xz:     LD (HL),0
        INC HL
        LD (HL),0
        INC HL
        LD (HL),0
        INC HL
        LD (HL),1
        INC HL
        DJNZ xz
        XOR A
        LD (ii),A
xn_l:   LD A,(nins)
        LD B,A
        LD A,(ii)
        CP B
        JP NC,si_go
        LD HL,(foff)
        LD (istart),HL
        LD A,(foff+2)
        LD (istart+2),A
        LD DE,ibuf
        LD BC,33
        CALL fread
        CALL ist_isz      ; foff = after the instrument header
        LD HL,(ibuf+27)   ; samples
        LD A,H
        OR L
        JP Z,xn_n
        LD HL,(foff)
        LD (shst),HL
        LD A,(foff+2)
        LD (shst+2),A
        LD DE,sbuf
        LD BC,40
        CALL fread        ; the first sample's header
        ; drum kind from the instrument name, else the sample name
        LD HL,ibuf+4
        CALL kwcopy
        OR A
        JR NZ,xn_k
        LD HL,sbuf+18
        CALL kwcopy
xn_k:   PUSH AF
        LD A,(ii)
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        LD DE,iinfo
        ADD HL,DE
        POP AF
        LD (HL),A         ; kind
        INC HL
        LD A,(sbuf+16)
        LD (HL),A         ; transpose: relative note
        INC HL
        LD A,(sbuf+12)
        CP 65
        JR C,xn_v
        LD A,64
xn_v:   LD (HL),A         ; volume
        INC HL
        PUSH HL
        LD A,(sbuf+14)
        AND 3
        LD A,255          ; looped: rings on
        JR NZ,xn_d
        LD A,(sbuf+14)
        BIT 4,A
        JR Z,xn_8
        LD HL,sbuf+3      ; 16-bit: half as many samples
        SRL (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
xn_8:   LD DE,(sbuf)
        LD HL,(sbuf+2)
        LD A,H
        OR L
        JR Z,xn_9
        LD DE,0xFFFF
xn_9:   LD L,0
        LD BC,167         ; 8363 / 50: ticks at C-4
        CALL div24
        LD A,D
        OR A
        LD A,254
        JR NZ,xn_d
        LD A,E
        CP 255
        JR C,xn_da
        LD A,254
xn_da:  OR A
        JR NZ,xn_d
        INC A
xn_d:   POP HL
        LD (HL),A         ; ring time
        ; skip every sample header and all the sample data
        LD HL,(shst)
        LD (foff),HL
        LD A,(shst+2)
        LD (foff+2),A
        XOR A
        LD (ssum),A
        LD (ssum+1),A
        LD (ssum+2),A
        LD BC,(ibuf+27)
xs_l:   PUSH BC
        LD DE,tmp4
        LD BC,4
        CALL fread
        LD HL,(ssum)
        LD DE,(tmp4)
        ADD HL,DE
        LD (ssum),HL
        LD A,(ssum+2)
        LD B,A
        LD A,(tmp4+2)
        ADC A,B
        LD (ssum+2),A
        LD HL,(ibuf+29)
        LD DE,-4
        ADD HL,DE
        EX DE,HL
        CALL fadd
        POP BC
        DEC BC
        LD A,B
        OR C
        JR NZ,xs_l
        LD DE,(ssum)
        CALL fadd
        LD A,(ssum+2)
        LD HL,foff+2
        ADD A,(HL)
        LD (HL),A
xn_n:   LD HL,ii
        INC (HL)
        JP xn_l
ist_isz: LD HL,(istart)   ; foff = instrument start + its header size
        LD A,(istart+2)
        LD DE,(ibuf)
        ADD HL,DE
        LD B,A
        LD A,(ibuf+2)
        ADC A,B
        LD (foff),HL
        LD (foff+2),A
        RET
fadd:   LD HL,(foff)      ; foff += DE
        ADD HL,DE
        LD (foff),HL
        RET NC
        LD HL,foff+2
        INC (HL)
        RET
kwcopy: LD DE,kbuf        ; a 22-letter name, padded with zeros, into kwfind
        LD BC,22
        LDIR
        LD B,10
kc_z:   XOR A
        LD (DE),A
        INC DE
        DJNZ kc_z
        LD HL,kbuf
        JP kwfind
si_go:  LD A,0xFF
        LD B,MAXCH
        LD HL,chnote
si_z:   LD (HL),A
        INC HL
        DJNZ si_z
        LD A,1
        LD (tcnt),A
        LD A,0xFF
        LD (rownote),A
        LD (rownote+1),A
        LD (rownote+2),A
        XOR A
        LD (pos),A
        CALL ldpat
        RET NZ
        XOR A
        RET
xi_bad: LD HL,s_notxm
        OR 1
        RET

; ---- load the pattern for order pos; NZ at the end of the song
ldpat:  LD A,(nord)
        LD B,A
        LD A,(pos)
        CP B
        JP NC,lp_end
        LD E,A
        LD D,0
        LD HL,ords
        ADD HL,DE
        LD A,(HL)
        LD HL,npat
        CP (HL)
        JR NC,lp_empty
        LD L,A
        LD H,0
        LD D,H
        LD E,L
        ADD HL,HL
        ADD HL,DE
        ADD HL,HL
        LD DE,ppp
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD A,(HL)
        INC HL
        LD (foff),DE
        LD (foff+2),A
        LD A,(HL)
        INC HL
        LD (prows),A
        LD C,(HL)
        INC HL
        LD B,(HL)
        LD A,B
        OR C
        JR Z,lp_fill
        LD HL,PATMAX
        OR A
        SBC HL,BC
        JR NC,lp_3
        LD BC,PATMAX
lp_3:   LD DE,patb
        CALL fread
        JR lp_ok
lp_empty: LD A,64
        LD (prows),A
lp_fill: LD HL,patb       ; rows of empty notes
        LD A,(prows)
        LD D,A
lp_f1:  LD A,(nch)
        OR A
        JR Z,lp_ok
        LD B,A
lp_f2:  LD (HL),0x80
        INC HL
        DJNZ lp_f2
        LD A,H
        CP ((patb+PATMAX-256)>>8)&255
        JR NC,lp_ok
        DEC D
        JR NZ,lp_f1
lp_ok:  LD HL,patb
        LD (rowp),HL
        XOR A
        LD (row),A
        LD (rownum),A
        RET
lp_end: OR 1
        RET

; ---- one 50 Hz field: run the S3M ticks that fall in it
fmt_tick: LD A,(tempo)
        LD HL,tacc
        ADD A,(HL)
        LD (HL),A
        JR NC,ft_1
        ; carry: more than 255 - plenty of ticks
        LD A,255
        LD (HL),A
ft_1:   LD HL,tacc
        LD A,(HL)
        CP 125
        JR C,ft_2
        SUB 125
        LD (HL),A
        CALL stick
        LD A,(mend)
        OR A
        RET NZ
        JR ft_1
ft_2:   ; sounds that have run out
        LD HL,chdur
        LD DE,chnote
        LD B,MAXCH
fd_l:   LD A,(DE)
        CP 0xFF
        JR Z,fd_n
        LD A,(HL)
        INC A
        JR Z,fd_n         ; 255: rings on
        DEC (HL)
        JR NZ,fd_n
        LD A,0xFF
        LD (DE),A
        LD A,1
        LD (chg),A
fd_n:   INC HL
        INC DE
        DJNZ fd_l
        LD A,(chg)
        OR A
        CALL NZ,choose
        XOR A
        RET

stick:  LD HL,tcnt
        DEC (HL)
        RET NZ
        LD A,(speed)
        LD (HL),A
        ; one row: an entry for every channel
        LD A,1
        LD (rowflag),A
        LD A,(row)
        LD (rownum),A
        XOR A
        LD (rowk),A
        LD (brk),A
        LD (rch),A
        DEC A
        LD (jmp),A
        LD HL,(rowp)
sr_l:   LD A,(nch)
        LD B,A
        LD A,(rch)
        CP B
        JP NC,sr_end
        XOR A
        LD (rnote),A
        LD (rins),A
        LD (rvol),A
        LD (rcmd),A
        LD (rinfo),A
        LD A,(HL)
        INC HL
        BIT 7,A
        JR NZ,sr_pk
        LD (rnote),A      ; unpacked: all five bytes
        LD DE,rins
        LD BC,4
        LDIR
        JR sr_ap
sr_pk:  LD C,A            ; packed: bits say which bytes follow
        LD DE,rnote
        LD B,5
sr_b:   RRC C
        JR NC,sr_b1
        LD A,(HL)
        INC HL
        LD (DE),A
sr_b1:  INC DE
        DJNZ sr_b
sr_ap:  PUSH HL
        LD A,(rch)
        CP MAXCH
        JR NC,sr_fx
        CALL apply
        JR sr_nx
sr_fx:  CALL ap_fx
sr_nx:  POP HL
        LD A,(rch)
        INC A
        LD (rch),A
        JR sr_l
sr_end: LD (rowp),HL
        LD A,1
        LD (chg),A
        LD A,(jmp)
        CP 0xFF
        JR NZ,sr_j
        LD A,(brk)
        OR A
        JR NZ,sr_bk
        LD HL,row
        INC (HL)
        LD A,(prows)
        CP (HL)
        RET NZ
        LD HL,pos
        INC (HL)
        JR sr_np
sr_j:   LD (pos),A
        LD B,A            ; a jump backwards ends the song (no looping)
        LD A,(ppos)
        CP B
        JR C,sr_np
        LD A,1
        LD (mend),A
        RET
sr_bk:  LD HL,pos
        INC (HL)
sr_np:  LD A,(pos)
        LD (ppos),A
        CALL ldpat
        JR Z,sr_r
        LD A,1
        LD (mend),A
        RET
sr_r:   LD A,(brk)        ; pattern break: skip to the row asked for
        OR A
        RET Z
        DEC A
        RET Z
        LD C,A
        LD A,(prows)
        OR A
        JR Z,sr_ok
        CP C
        RET C
        RET Z
sr_ok:  LD HL,(rowp)
sr_sr:  LD A,(nch)
        OR A
        JR Z,sr_sn
        LD B,A
sr_se:  LD A,(HL)
        INC HL
        BIT 7,A
        JR NZ,sr_sp
        INC HL
        INC HL
        INC HL
        INC HL
        JR sr_sx
sr_sp:  LD E,5
sr_sq:  RRCA
        JR NC,sr_sq1
        INC HL
sr_sq1: DEC E
        JR NZ,sr_sq
sr_sx:  DJNZ sr_se
sr_sn:  LD A,(row)
        INC A
        LD (row),A
        DEC C
        JR NZ,sr_sr
        LD (rowp),HL
        RET

; ---- one channel's entry in the row
apply:  LD A,(rch)
        LD E,A
        LD D,0
        LD A,(rins)
        OR A
        JR Z,ap_1
        LD HL,chins
        ADD HL,DE
        LD (HL),A
        CALL iptr
        INC HL
        INC HL
        LD A,(HL)
        LD HL,chvol
        ADD HL,DE
        LD (HL),A
ap_1:   LD A,(rvol)       ; volume column 10-50
        SUB 0x10
        JR C,ap_1b
        CP 0x41
        JR NC,ap_1b
        LD HL,chvol
        ADD HL,DE
        LD (HL),A
ap_1b:  LD A,(rcmd)       ; C: set volume
        CP 0x0C
        JR NZ,ap_2
        LD A,(rinfo)
        CP 65
        JR C,ap_1c
        LD A,64
ap_1c:  LD HL,chvol
        ADD HL,DE
        LD (HL),A
ap_2:   LD A,(rnote)
        OR A
        JP Z,ap_fx
        CP 97
        JR NZ,ap_3
        LD HL,chnote      ; key off
        ADD HL,DE
        LD (HL),0xFF
        LD A,0xFE
        CALL rrec
        JP ap_fx
ap_3:   JP NC,ap_fx
        SUB 13            ; C-4 (49) -> 36
        LD C,A
        LD HL,chins
        ADD HL,DE
        LD A,(HL)
        CALL iptr0
        LD A,(HL)         ; drum?
        OR A
        JR Z,ap_t
        LD B,A
        LD A,(dreq)
        CP B
        JP NC,ap_fx
        LD A,B
        LD (dreq),A
        PUSH DE
        CALL showdrum
        POP DE
        JR ap_fx
ap_t:   INC HL
        LD A,C
        ADD A,(HL)        ; relative note
        JP PE,ap_ov
        BIT 7,A
        JR Z,ap_4
        XOR A
ap_4:   CP 96
        JR C,ap_5
        LD A,95
        JR ap_5
ap_ov:  LD A,(HL)
        BIT 7,A
        LD A,95
        JR Z,ap_5
        XOR A
ap_5:   LD C,A
        INC HL
        INC HL
        LD B,(HL)         ; ring time at C-4
        LD HL,chnote
        ADD HL,DE
        LD (HL),C
        LD HL,seqc
        INC (HL)
        LD A,(HL)
        LD HL,chseq
        ADD HL,DE
        LD (HL),A
        LD A,B
        CP 255
        JR Z,ap_d
        LD A,C
ap_o:   CP 48             ; each octave above C-4 halves it
        JR C,ap_o2
        SUB 12
        SRL B
        JR ap_o
ap_o2:  CP 36
        JR NC,ap_o3
        ADD A,12
        SLA B
        JR NC,ap_o2
        LD B,254
ap_o3:  LD A,B
        OR A
        JR NZ,ap_d
        INC A
ap_d:   LD HL,chdur
        ADD HL,DE
        LD (HL),A
        LD A,C
        CALL rrec
ap_fx:  LD A,(rcmd)
        CP 0x0F           ; F: speed below 32, else BPM
        JR NZ,ap_f3
        LD A,(rinfo)
        OR A
        RET Z
        CP 32
        JR NC,ap_ft
        LD (speed),A
        LD (tcnt),A
        RET
ap_ft:  LD (tempo),A
        RET
ap_f3:  CP 0x0B           ; B: jump
        JR NZ,ap_f4
        LD A,(rinfo)
        LD (jmp),A
        RET
ap_f4:  CP 0x0D           ; D: break to row (decimal)
        RET NZ
        LD A,(rinfo)
        LD B,A
        RRCA
        RRCA
        RRCA
        RRCA
        AND 15
        LD C,A
        ADD A,A
        ADD A,A
        ADD A,C
        ADD A,A
        LD C,A
        LD A,B
        AND 15
        ADD A,C
        INC A
        LD (brk),A
        RET
iptr:   LD A,(rins)
iptr0:  OR A              ; instrument A (1-255) -> HL = its 4 info bytes
        JR NZ,ip_1
        INC A
ip_1:   CP 130
        JR C,ip_2
        LD A,129
ip_2:   DEC A
        PUSH DE
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        LD DE,iinfo
        ADD HL,DE
        POP DE
        RET
rrec:   LD B,A            ; note A of channel rch into the tracker row (first three)
        LD A,(rowk)
        CP 3
        RET NC
        PUSH DE
        LD E,A
        INC A
        LD (rowk),A
        LD D,0
        LD HL,rownote
        ADD HL,DE
        LD (HL),B
        INC HL
        INC HL
        INC HL
        LD A,(rins)
        OR A
        JR NZ,rr_1
        LD A,(rch)
        LD E,A
        LD D,0
        PUSH HL
        LD HL,chins
        ADD HL,DE
        LD A,(HL)
        POP HL
rr_1:   LD (HL),A
        POP DE
        RET

; ---- three voices from the channels: highest, lowest, newest of the rest
choose: XOR A
        LD (chg),A
        LD A,0xFF
        LD (vlo),A
        LD (vmid),A
        LD (vhi),A
        LD B,MAXCH
        LD HL,chnote
        LD C,0
ch_l:   LD A,(HL)
        CP 0xFF
        JR Z,ch_n
        LD D,A
        LD A,(vhi)
        CP 0xFF
        JR Z,ch_h
        CP D
        JR NC,ch_2
ch_h:   LD A,D
        LD (vhi),A
        LD A,C
        LD (vhic),A
ch_2:   LD A,(vlo)
        CP D
        JR C,ch_n
        JR Z,ch_n
        LD A,D
        LD (vlo),A
        LD A,C
        LD (vloc),A
ch_n:   INC HL
        INC C
        DJNZ ch_l
        ; newest of the others
        LD A,0xFF
        LD (best),A
        XOR A
        LD (bestage),A
        DEC A
        LD (bestage),A
        LD B,MAXCH
        LD C,0
        LD HL,chnote
ch_m:   LD A,(HL)
        CP 0xFF
        JR Z,ch_mn
        LD A,(vhic)
        CP C
        JR Z,ch_mn
        LD A,(vloc)
        CP C
        JR Z,ch_mn
        PUSH HL
        LD DE,chseq-chnote
        ADD HL,DE
        LD A,(seqc)
        SUB (HL)          ; age
        POP HL
        LD D,A
        LD A,(bestage)
        CP D
        JR C,ch_mn
        JR Z,ch_mn
        LD A,D
        LD (bestage),A
        LD A,C
        LD (best),A
        LD A,(HL)
        LD (vmid),A
ch_mn:  INC HL
        INC C
        DJNZ ch_m
        LD A,(vhi)
        LD B,A
        LD A,(vlo)
        CP B
        JR NZ,ch_o
        LD A,0xFF         ; one note only: lead plays it
        LD (vlo),A
ch_o:   LD IX,vper
        LD A,(vhi)
        LD C,0
        CALL setvo
        LD IX,vper+2
        LD A,(vlo)
        LD C,1
        CALL setvo
        LD IX,vper+4
        LD A,(vmid)
        LD C,2
setvo:  LD HL,vnote       ; voice C plays note A (FF silent)
        LD E,C
        LD D,0
        ADD HL,DE
        LD (HL),A
        CP 0xFF
        JR NZ,sv_1
        LD (IX+6),0
        LD (IX+12),0
        RET
sv_1:   PUSH AF
        ADD A,A
        LD E,A
        LD HL,ptab
        ADD HL,DE
        LD A,(HL)
        LD (IX+0),A
        INC HL
        LD A,(HL)
        LD (IX+1),A
        POP AF
        ; its channel's volume
        LD B,A
        LD A,C
        OR A
        LD A,(vhic)
        JR Z,sv_2
        DEC C
        LD A,(vloc)
        JR Z,sv_2
        LD A,(best)
sv_2:   LD E,A
        LD HL,chvol
        ADD HL,DE
        LD A,(HL)
        SRL A
        SRL A
        CP 16
        JR C,sv_3
        LD A,15
sv_3:   LD (IX+6),A
        LD (IX+12),1
        RET

; keyword search (instrument names) - kind: 1 hat, 2 snare, 3 kick
kwfind: LD (kwname),HL
        LD DE,kwtab
kw_k:   LD A,(DE)
        CP 0xFF
        JR Z,kw_none
        LD (kwkind),A
        INC DE
        LD HL,(kwname)
        LD B,26
kw_p:   PUSH HL
        PUSH DE
        PUSH BC
kw_c:   LD A,(DE)
        OR A
        JR Z,kw_hit
        LD C,A
        LD A,(HL)
        CP 0x61
        JR C,kw_u
        SUB 0x20
kw_u:   CP C
        JR NZ,kw_miss
        INC HL
        INC DE
        JR kw_c
kw_miss: POP BC
        POP DE
        POP HL
        INC HL
        DJNZ kw_p
kw_sk:  LD A,(DE)
        INC DE
        OR A
        JR NZ,kw_sk
        JR kw_k
kw_hit: POP BC
        POP DE
        POP HL
        LD A,(kwkind)
        RET
kw_none: XOR A
        RET
kwtab:  DB 2,"SNAR",0,2,"CLAP",0,1,"HAT",0,1,"HH",0,1,"SHAK",0,1,"CYM",0,1,"CRASH",0,1,"RIDE",0,1,"TAMB",0
        DB 3,"KICK",0,3,"BD",0,3,"BASSDR",0,3,"DRUM",0,3,"TOM",0,3,"CONGA",0,3,"BONGO",0,2,"SD",0,0xFF

fmt_title: LD DE,VRAM+3*32
        LD HL,hdr+17
        LD B,20
        LD C,0
        JP ptext
fmt_status: LD HL,s_pos
        CALL puts
        LD A,(pos)
        CALL prhex
        LD A,'/'
        CALL putc
        LD A,(nord)
        DEC A
        CALL prhex
        LD HL,s_row
        CALL puts
        LD A,(row)
        JP prhex
fmt_v3  EQU trkview
fmt_v3i EQU trkinit
s_v3hdr: DB "ROW   NOTES THIS ROW            ",0
s_fmt:  DB "XM PLAYER",0
s_pos:  DB "POS ",0
s_row:  DB "  ROW ",0
s_xmid: DB "Extended Module: "
s_notxm: DB "NOT AN XM FILE",13,0
