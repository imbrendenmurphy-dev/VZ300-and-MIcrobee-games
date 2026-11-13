; ================================================================ S3M (Scream Tracker 3)
MAXCH   EQU 32
PATMAX  EQU 0x2000
fmt_init: CALL mkclt
        XOR A
        LD H,A
        LD L,A
        LD (foff),HL
        LD (foff+2),A
        LD DE,hdr
        LD BC,0x60
        CALL fread
        LD HL,hdr+0x2C
        LD DE,s_scrm
        LD B,4
si_c:   LD A,(DE)
        CP (HL)
        JP NZ,si_bad
        INC HL
        INC DE
        DJNZ si_c
        LD HL,(hdr+0x20)  ; orders
        LD A,H
        OR A
        JR Z,si_1
        LD L,255
si_1:   LD A,L
        LD (nord),A
        LD HL,(hdr+0x22)  ; instruments
        LD A,H
        OR A
        JR NZ,si_2
        LD A,L
        CP 100
        JR C,si_3
si_2:   LD A,99
si_3:   LD (nins),A
        LD HL,(hdr+0x24)  ; patterns
        LD A,H
        OR A
        JR Z,si_4
        LD L,255
si_4:   LD A,L
        LD (npat),A
        LD A,(hdr+0x31)
        OR A
        JR NZ,si_5
        LD A,6
si_5:   LD (speed),A
        LD A,(hdr+0x32)
        CP 33
        JR NC,si_6
        LD A,125
si_6:   LD (tempo),A
        ; orders, instrument and pattern pointers follow the header
        LD HL,0x60
        LD (foff),HL
        LD A,(nord)
        LD C,A
        LD B,0
        LD DE,ords
        CALL fread
        LD A,(nins)
        LD L,A
        LD H,0
        ADD HL,HL
        LD B,H
        LD C,L
        LD DE,ipp
        CALL fread
        LD A,(npat)
        LD L,A
        LD H,0
        ADD HL,HL
        LD B,H
        LD C,L
        LD DE,ppp
        CALL fread
        ; each instrument: drum or tone, transpose, volume, how long it rings
        XOR A
        LD (ii),A
si_i:   LD A,(nins)
        LD B,A
        LD A,(ii)
        CP B
        JP NC,si_go
        ADD A,A
        LD E,A
        LD D,0
        LD HL,ipp
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        XOR A
        ADD HL,HL         ; para * 16
        RLA
        ADD HL,HL
        RLA
        ADD HL,HL
        RLA
        ADD HL,HL
        RLA
        LD (foff),HL
        LD (foff+2),A
        LD DE,ibuf
        LD BC,0x50
        CALL fread
        LD A,(ii)
        LD E,A
        LD D,0
        LD HL,iinfo
        ADD HL,DE
        ADD HL,DE
        ADD HL,DE
        ADD HL,DE
        PUSH HL
        LD A,(ibuf)
        CP 1
        JR Z,si_s
        POP HL            ; not a sample: silent
        LD (HL),0
        INC HL
        LD (HL),0
        INC HL
        LD (HL),0
        INC HL
        LD (HL),1
        JP si_n
si_s:   LD HL,ibuf+0x30
        CALL kwfind
        OR A
        JR NZ,si_k
        LD HL,ibuf+1
        CALL kwfind
si_k:   POP HL
        LD (HL),A         ; drum kind
        INC HL
        PUSH HL
        ; transpose from the sample's C-4 speed
        LD DE,(ibuf+0x20)
        LD A,(ibuf+0x22)
        OR A
        JR Z,si_t0
        LD DE,0xFFFF
si_t0:  LD HL,cthr
        LD B,0
si_t:   LD A,B
        CP 48
        JR NC,si_t2
        PUSH HL
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        OR A
        SBC HL,DE         ; threshold - speed
        POP HL
        JR NC,si_t2
        INC HL
        INC HL
        INC B
        JR si_t
si_t2:  LD A,B
        SUB 24
        POP HL
        LD (HL),A         ; transpose (semitones)
        INC HL
        LD A,(ibuf+0x1C)
        CP 65
        JR C,si_v
        LD A,64
si_v:   LD (HL),A         ; default volume
        INC HL
        ; ring time in 50 Hz ticks at C-4 = length / (speed / 50)
        LD A,(ibuf+0x1F)
        AND 1
        LD A,255
        JR NZ,si_d
        PUSH HL
        LD HL,(ibuf+0x20)
        LD A,H
        OR L
        JR NZ,si_d1
        LD HL,8363
si_d1:  LD C,50           ; HL / 50
        CALL div8
        LD A,H
        OR L
        JR NZ,si_d2
        INC L
si_d2:  LD B,H
        LD C,L
        LD HL,(ibuf+0x11) ; length / 256 ...
        LD A,(ibuf+0x13)
        OR A
        JR Z,si_d3
        LD HL,0xFFFF
si_d3:  LD A,H
        OR A
        JR Z,si_d4
        LD L,0xFF
si_d4:  LD H,L
        LD A,(ibuf+0x10)
        LD L,A            ; HL = length (low 16, saturated)
        LD DE,0
        EX DE,HL          ; DE = length
        LD L,0
        CALL div24        ; length / divisor (plib: L:D:E / BC)
        LD A,D
        OR A
        LD A,254
        JR NZ,si_d5
        LD A,E
        CP 255
        JR C,si_d6
        LD A,254
si_d5:
si_d6:  OR A
        JR NZ,si_d7
        INC A
si_d7:  POP HL
si_d:   LD (HL),A
si_n:   LD HL,ii
        INC (HL)
        JP si_i
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
si_bad: LD HL,s_nots3m
        OR 1
        RET
div8:   LD B,16           ; HL / C -> HL
        XOR A
dv8_l:  ADD HL,HL
        RLA
        CP C
        JR C,dv8_n
        SUB C
        INC L
dv8_n:  DJNZ dv8_l
        RET

; ---- load the pattern for order pos (skipping markers); NZ at the end of the song
ldpat:  LD A,(nord)
        LD B,A
        LD A,(pos)
        CP B
        JR NC,lp_end
        LD E,A
        LD D,0
        LD HL,ords
        ADD HL,DE
        LD A,(HL)
        CP 255
        JR Z,lp_end
        CP 254
        JR NZ,lp_1
        LD HL,pos
        INC (HL)
        JR ldpat
lp_1:   LD B,A
        LD A,(npat)
        DEC A
        CP B
        JR C,lp_empty
        LD A,B
        ADD A,A
        LD E,A
        LD D,0
        JR NC,lp_2
        INC D
lp_2:   LD HL,ppp
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD A,D
        OR E
        JR Z,lp_empty
        EX DE,HL
        XOR A
        ADD HL,HL
        RLA
        ADD HL,HL
        RLA
        ADD HL,HL
        RLA
        ADD HL,HL
        RLA
        LD (foff),HL
        LD (foff+2),A
        LD DE,plen
        LD BC,2
        CALL fread
        LD BC,(plen)
        LD HL,PATMAX
        OR A
        SBC HL,BC
        JR NC,lp_3
        LD BC,PATMAX
lp_3:   LD DE,patb
        CALL fread
        JR lp_ok
lp_empty: LD HL,patb      ; 64 empty rows
        LD B,64
lp_e:   LD (HL),0
        INC HL
        DJNZ lp_e
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
        ; one row
        LD A,1
        LD (rowflag),A
        LD A,(row)
        LD (rownum),A
        XOR A
        LD (rowk),A
        LD (brk),A
        DEC A
        LD (jmp),A
        LD HL,(rowp)
sr_l:   LD A,(HL)
        INC HL
        OR A
        JP Z,sr_end
        LD (what),A
        AND 31
        LD (rch),A
        LD A,0xFF
        LD (rnote),A
        LD (rvol),A
        XOR A
        LD (rins),A
        LD (rcmd),A
        LD A,(what)
        BIT 5,A
        JR Z,sr_1
        LD A,(HL)
        INC HL
        LD (rnote),A
        LD A,(HL)
        INC HL
        LD (rins),A
sr_1:   LD A,(what)
        BIT 6,A
        JR Z,sr_2
        LD A,(HL)
        INC HL
        LD (rvol),A
sr_2:   LD A,(what)
        BIT 7,A
        JR Z,sr_3
        LD A,(HL)
        INC HL
        LD (rcmd),A
        LD A,(HL)
        INC HL
        LD (rinfo),A
sr_3:   PUSH HL
        CALL apply
        POP HL
        JR sr_l
sr_end: LD (rowp),HL
        LD A,1
        LD (chg),A
        ; next row, or next pattern
        LD A,(jmp)
        CP 0xFF
        JR NZ,sr_j
        LD A,(brk)
        OR A
        JR NZ,sr_b
        LD HL,row
        INC (HL)
        LD A,(HL)
        CP 64
        RET C
        LD HL,pos
        INC (HL)
        JR sr_np
sr_j:   LD (pos),A
        LD B,A            ; a jump backwards ends the song (no looping)
        LD A,(ppos)
        CP B
        JR C,sr_np0
        JR Z,sr_np0
        LD A,1
        LD (mend),A
        RET
sr_np0: JR sr_np
sr_b:   LD HL,pos
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
        LD B,A
        LD HL,(rowp)
sr_sk:  LD A,(HL)         ; skip one packed row
        INC HL
        OR A
        JR Z,sr_sn
        LD C,A
        BIT 5,C
        JR Z,sr_s1
        INC HL
        INC HL
sr_s1:  BIT 6,C
        JR Z,sr_s2
        INC HL
sr_s2:  BIT 7,C
        JR Z,sr_sk
        INC HL
        INC HL
        JR sr_sk
sr_sn:  LD A,(row)
        INC A
        LD (row),A
        DJNZ sr_sk
        LD (rowp),HL
        RET

; ---- one channel's entry in the row
apply:  LD A,(rch)
        LD E,A
        LD D,0
        LD HL,hdr+0x40    ; channel disabled?
        ADD HL,DE
        LD A,(HL)
        CP 16
        JP NC,ap_fx
        LD A,(rins)
        OR A
        JR Z,ap_1
        LD HL,chins
        ADD HL,DE
        LD (HL),A
        CALL iptr         ; HL = instrument info
        INC HL
        INC HL
        LD A,(HL)
        LD HL,chvol
        ADD HL,DE
        LD (HL),A
ap_1:   LD A,(rvol)
        CP 0xFF
        JR Z,ap_2
        CP 65
        JR C,ap_1a
        LD A,64
ap_1a:  LD HL,chvol
        ADD HL,DE
        LD (HL),A
ap_2:   LD A,(rnote)
        CP 0xFF
        JP Z,ap_fx
        CP 0xFE
        JR NZ,ap_3
        LD HL,chnote
        ADD HL,DE
        LD (HL),0xFF
        LD A,0xFE
        CALL rrec
        JR ap_fx
ap_3:   LD B,A            ; octave * 12 + semitone - 12
        RRCA
        RRCA
        RRCA
        RRCA
        AND 15
        LD C,A
        ADD A,A
        ADD A,C
        ADD A,A
        ADD A,A
        LD C,A
        LD A,B
        AND 15
        ADD A,C
        SUB 12
        LD C,A
        LD HL,chins
        ADD HL,DE
        LD A,(HL)
        CALL iptr0        ; HL = info for instrument A
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
        ADD A,(HL)        ; transpose
        BIT 7,A
        JR Z,ap_4
        XOR A
ap_4:   CP 96
        JR C,ap_5
        LD A,95
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
        ; ring time for this octave
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
        CP 1              ; A: speed
        JR NZ,ap_f2
        LD A,(rinfo)
        OR A
        RET Z
        LD (speed),A
        LD (tcnt),A
        RET
ap_f2:  CP 20             ; T: tempo
        JR NZ,ap_f3
        LD A,(rinfo)
        CP 33
        RET C
        LD (tempo),A
        RET
ap_f3:  CP 2              ; B: jump
        JR NZ,ap_f4
        LD A,(rinfo)
        LD (jmp),A
        RET
ap_f4:  CP 3              ; C: break to row (decimal)
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
        CP 64
        JR C,ap_f5
        XOR A
ap_f5:  INC A
        LD (brk),A
        RET
iptr:   LD A,(rins)
iptr0:  OR A              ; instrument A (1-99) -> HL = its 4 info bytes
        JR NZ,ip_1
        INC A
ip_1:   DEC A
        PUSH DE
        LD E,A
        LD D,0
        LD HL,iinfo
        ADD HL,DE
        ADD HL,DE
        ADD HL,DE
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
        LD HL,hdr
        LD B,28
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
s_fmt:  DB "S3M PLAYER",0
s_pos:  DB "POS ",0
s_row:  DB "  ROW ",0
s_scrm: DB "SCRM"
s_nots3m: DB "NOT AN S3M FILE",13,0
