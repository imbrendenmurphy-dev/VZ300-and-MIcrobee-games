; ================================================================ MUSIC PLAYER
MBUF    EQU 0x9A00
NNOTE   EQU 10
SPK     EQU 0x6800

play_mid: ; HL = record of a .MID file
        PUSH HL
        CALL savepos
        POP HL
        PUSH HL
        INC HL
        LD DE,pname
        LD BC,11
        LDIR
        POP HL
        PUSH HL
        LD BC,13
        ADD HL,BC
        LD DE,mcl
        LD BC,4
        LDIR
        POP HL
        LD BC,17
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD A,(HL)
        INC HL
        OR (HL)
        LD (fsize),DE
        LD HL,0
        LD (ceof),HL
        LD (cbendh),HL
        JR NZ,pm_strm
        LD HL,0x5E00
        OR A
        SBC HL,DE
        JR C,pm_strm
        LD A,D
        OR E
        JP Z,pm_bad
        LD HL,mcl
        LD DE,0xFA12
        LD BC,4
        LDIR
        LD HL,(fsize)
        LD DE,511
        ADD HL,DE
        LD A,H
        SRL A
        LD (secs),A
        CALL CLS
        LD HL,s_load
        CALL PRINT
        LD HL,MBUF
        LD (0xFB80),HL
        CALL D_C2S
        CALL D_READ
        DI
pm_ld:  LD A,(secs)
        DEC A
        LD (secs),A
        JR Z,pm_ld2
        LD HL,(0xFB80)
        LD DE,512
        ADD HL,DE
        LD (0xFB80),HL
        CALL D_NEXT
        DI
        JR pm_ld
        JR pm_ld2
pm_strm: LD A,1
        LD (strm),A
        CALL CLS
        LD HL,s_load
        CALL PRINT
        CALL mkclt
        LD HL,0
        LD DE,MBUF
        CALL rdfsec
pm_ld2: LD HL,0xF800
        LD (0xFB80),HL
        ; ---- header
        LD HL,MBUF
        LD A,(HL)
        CP 'M'
        JP NZ,pm_bad
        INC HL
        LD A,(HL)
        CP 'T'
        JP NZ,pm_bad
        LD A,(MBUF+12)
        BIT 7,A
        JP NZ,pm_bad
        LD H,A
        LD A,(MBUF+13)
        LD L,A
        LD (ppq),HL
        OR H
        JP Z,pm_bad
        LD A,(MBUF+11)
        CP 17
        JR C,pm_h1
        LD A,16
pm_h1:  OR A
        JP Z,pm_bad
        LD (ntrk),A
        LD A,(strm)
        OR A
        JP NZ,pm_ss
        ; file end
        LD HL,(fsize)
        LD DE,MBUF
        ADD HL,DE
        LD (fend),HL
        ; first chunk after header: MBUF + 8 + header length (low word)
        LD A,(MBUF+6)
        LD H,A
        LD A,(MBUF+7)
        LD L,A
        LD DE,MBUF+8
        ADD HL,DE
        ; ---- tracks
        LD DE,trk
        LD A,(ntrk)
        LD B,A
        LD C,0            ; tracks found
pm_t:   PUSH BC
        ; HL = chunk, DE = struct
        PUSH DE
        LD DE,(fend)
        PUSH HL
        OR A
        SBC HL,DE
        POP HL
        POP DE
        JR NC,pm_tx       ; ran off the file
        LD A,(HL)
        CP 'M'
        JR NZ,pm_tx
        PUSH DE
        LD DE,6
        ADD HL,DE
        LD D,(HL)
        INC HL
        LD E,(HL)
        INC HL            ; HL = data start, DE = length
        PUSH HL
        ADD HL,DE         ; HL = end
        LD (cend),HL
        POP HL            ; data start
        CALL rdvlq        ; DE = first delta, HL = ptr
        LD B,D
        LD C,E
        POP DE            ; struct
        LD A,1
        LD (DE),A
        INC DE
        LD A,C
        LD (DE),A
        INC DE
        LD A,B
        LD (DE),A
        INC DE
        LD A,L
        LD (DE),A
        INC DE
        LD A,H
        LD (DE),A
        INC DE
        LD HL,(cend)
        LD A,L
        LD (DE),A
        INC DE
        LD A,H
        LD (DE),A
        INC DE
        XOR A
        LD (DE),A
        INC DE
        POP BC
        INC C
        DJNZ pm_t
        JR pm_t2
pm_tx:  POP BC
pm_t2:  LD A,C
        OR A
        JP Z,pm_bad
        LD (ntrk),A
pm_go:  CALL pinit
        CALL pscreen
        ; ---- main loop
pm_loop: LD DE,(mind)
        CALL dowait
        LD A,(stopf)
        OR A
        JR NZ,pm_end
        CALL tracks
        LD A,(nchg)
        OR A
        CALL NZ,select
        LD A,(anyon)
        OR A
        JR NZ,pm_loop
pm_end: XOR A
        LD (SPK),A
pm_out: LD A,1
        LD (restore),A
        JP reenter
pm_bad: LD HL,0xF800
        LD (0xFB80),HL
        LD HL,s_bad
pm_msg: PUSH HL
        CALL CLS
        POP HL
        CALL PRINT
        LD B,100
pm_m1:  PUSH BC
        CALL vsync
        POP BC
        DJNZ pm_m1
        JR pm_out

; ---- find each track by walking the chunk headers on the card
pm_ss:  LD A,(MBUF+6)
        LD H,A
        LD A,(MBUF+7)
        LD L,A
        LD DE,8
        ADD HL,DE
        LD (spos),HL
        XOR A
        LD (spos+2),A
        LD (sidx),A
        LD HL,0xFFFF
        LD (cendsec),HL
ss_l:   CALL tseek
        CALL getb
        CP 'M'
        JP NZ,ss_x
        CALL getb
        CALL getb
        CALL getb
        CALL getb
        CALL getb
        LD (slen3+2),A
        CALL getb
        LD (slen3+1),A
        CALL getb
        LD (slen3),A
        PUSH HL
        LD HL,(spos)
        LD DE,8
        ADD HL,DE
        LD A,(spos+2)
        ADC A,0
        LD B,A
        LD DE,(slen3)
        ADD HL,DE
        LD A,(slen3+2)
        ADC A,B
        LD (spos),HL
        LD (spos+2),A
        LD DE,1
        OR A
        SBC HL,DE
        SBC A,0
        PUSH AF
        PUSH HL
        LD A,H
        AND 1
        LD H,A
        INC HL
        EX DE,HL
        LD A,(sidx)
        ADD A,A
        LD C,A
        LD B,0
        LD HL,tendo
        ADD HL,BC
        LD (HL),E
        INC HL
        LD (HL),D
        POP HL
        POP AF
        SRL A
        RR H
        LD L,H
        LD H,A
        EX DE,HL
        LD A,(sidx)
        ADD A,A
        LD C,A
        LD B,0
        LD HL,tend
        ADD HL,BC
        LD (HL),E
        INC HL
        LD (HL),D
        POP HL
        CALL rdvlq
        PUSH HL
        PUSH DE
        LD A,(sidx)
        ADD A,A
        ADD A,A
        ADD A,A
        LD C,A
        LD B,0
        LD HL,trk
        ADD HL,BC
        POP DE
        LD (HL),1
        INC HL
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        POP DE
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD DE,(csec)
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD (HL),0
        LD HL,sidx
        INC (HL)
        LD A,(ntrk)
        CP (HL)
        JP NZ,ss_l
ss_x:   LD A,(sidx)
        OR A
        JP Z,pm_bad
        LD (ntrk),A
        JP pm_go
tseek:  LD A,(sidx)
        ADD A,A
        ADD A,TBH
        LD (cbaseh),A
        ADD A,2
        LD (cbendh),A
        LD A,(spos+2)
        LD H,A
        LD A,(spos+1)
        LD L,A
        SRL H
        RR L
        LD (csec),HL
        LD A,(cbaseh)
        LD D,A
        LD E,0
        CALL rdfsec
        LD HL,0xF800
        LD (0xFB80),HL
        LD A,(spos+1)
        AND 1
        LD H,A
        LD A,(spos)
        LD L,A
        LD A,(cbaseh)
        ADD A,H
        LD H,A
        RET
setlim: LD HL,(csec)      ; where this track's data stops, if it stops in this sector
        LD DE,(cendsec)
        OR A
        SBC HL,DE
        LD HL,0xFFFF
        JR NZ,sl_x
        LD HL,(cendo)
        LD A,(cbaseh)
        ADD A,H
        LD H,A
sl_x:   LD (climit),HL
        RET
; ---- next byte of the current track; refills its buffer from the card
getb:   LD A,(HL)
        INC L
        RET NZ
        INC H
        PUSH AF
        LD A,(cbendh)
        CP H
        JR Z,gb_r
        POP AF
        RET
gb_r:   PUSH BC
        PUSH DE
        LD HL,(csec)
        INC HL
        LD (csec),HL
        EX DE,HL
        LD HL,(cendsec)
        OR A
        SBC HL,DE
        JR C,gb_eof
        EX DE,HL
        LD A,(cbaseh)
        LD D,A
        LD E,0
        CALL rdfsec
        LD HL,0xF800
        LD (0xFB80),HL
        LD A,(debt)
        ADD A,REFC
        JR NC,gb_1
        LD A,255
gb_1:   LD (debt),A
        LD A,(mend)
        OR A
        JR NZ,gb_eof
        CALL setlim
        JR gb_ok
gb_eof: LD A,(cbaseh)
        LD H,A
        LD L,0
        LD D,H
        LD E,1
        LD (HL),0
        LD BC,511
        LDIR
        LD A,1
        LD (ceof),A
gb_ok:  LD A,(cbaseh)
        LD H,A
        LD L,0
        POP DE
        POP BC
        POP AF
        RET

pinit:  LD A,(outmode)
        CALL outset
        LD HL,ntab
        LD B,NNOTE*3
        LD A,0xFF
pm_i1:  LD (HL),A
        INC HL
        DJNZ pm_i1
        LD HL,vce
        LD B,3
pm_i2:  LD (HL),0xFF
        INC HL
        LD (HL),0
        INC HL
        INC HL
        LD (HL),0x80
        INC HL
        LD (HL),0
        INC HL
        LD (HL),0
        INC HL
        LD (HL),0
        INC HL
        INC HL
        DJNZ pm_i2
        LD HL,0
        LD (pha0),HL
        LD (pha1),HL
        LD (pha2),HL
        LD (mind),HL
        LD HL,0xACE1
        LD (nseed),HL
        XOR A
        LD (seqnow),A
        LD (dreq),A
        LD (evn),A
        LD (debt),A
        LD (stopf),A
        LD (armed),A
        LD (wfrac),A
        LD (fcnt),A
        LD (dshow),A
        LD (gottitle),A
        LD HL,VRAM+3*32
        LD (tcur),HL
        LD (lastpc),A
        LD (nchg),A
        LD (ismod),A
        LD (resel),A
        LD (pausef),A
        LD (viewf),A
        LD (fx),A
        LD HL,512
        LD (fl),HL
        LD HL,0xFFFF
        LD (blen),HL
        LD (blen+1),HL
        LD HL,0xA120      ; 500000 us per beat until the file says otherwise
        LD (tempo),HL
        LD A,7
        LD (tempo+2),A
        CALL settempo
        JP applyv

; ---- one pass over the tracks: take the elapsed ticks off each, run the
;      ones that are due, and find the next gap
tracks: LD HL,0xFFFF
        LD (newmin),HL
        XOR A
        LD (anyon),A
        LD (nchg),A
        LD HL,trk
        LD A,(ntrk)
        LD B,A
tk_l:   PUSH BC
        PUSH HL
        LD A,(HL)
        OR A
        JR Z,tk_n
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        PUSH HL
        EX DE,HL
        LD DE,(mind)
        OR A
        SBC HL,DE
        EX DE,HL          ; DE = delta - elapsed
        POP HL
        LD (HL),D
        DEC HL
        LD (HL),E
        LD A,D
        OR E
        JR NZ,tk_m
        DEC HL            ; struct base
        CALL ptrk
        POP HL
        PUSH HL
        LD A,(HL)
        OR A
        JR Z,tk_n         ; track ended
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
tk_m:   LD A,1
        LD (anyon),A
        LD HL,(newmin)
        OR A
        SBC HL,DE
        JR C,tk_n
        LD (newmin),DE
tk_n:   POP HL
        LD DE,8
        ADD HL,DE
        POP BC
        DJNZ tk_l
        LD HL,(newmin)
        LD (mind),HL
        RET

; ---- run one track's events until it has a non-zero wait
ptrk:   LD (tbase),HL
        LD A,(strm)
        OR A
        JR Z,pt_1
        PUSH HL
        LD DE,trk
        OR A
        SBC HL,DE
        LD A,L
        RRCA
        RRCA
        AND 0x3E
        LD C,A
        ADD A,TBH
        LD (cbaseh),A
        ADD A,2
        LD (cbendh),A
        LD B,0
        LD HL,tend
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD (cendsec),DE
        LD HL,tendo
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD (cendo),DE
        XOR A
        LD (ceof),A
        POP HL
pt_1:   INC HL
        INC HL
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD A,(HL)
        LD (csec),A
        INC HL
        LD A,(HL)
        LD (csec+1),A
        INC HL
        LD A,(HL)
        LD (cstat),A
        LD A,(strm)
        OR A
        JR NZ,pt_2
        LD HL,(csec)
        LD (climit),HL
        JR pt_3
pt_2:   PUSH DE
        CALL setlim
        POP DE
pt_3:   EX DE,HL
pe_ev:  LD A,(ceof)
        OR A
        JP NZ,pe_off
        LD DE,(climit)
        PUSH HL
        OR A
        SBC HL,DE
        POP HL
        JP NC,pe_off
        LD A,(evn)
        INC A
        JR Z,pe_e0
        LD (evn),A
pe_e0:  CALL getb
        CP 0xFF
        JR Z,pe_meta
        CP 0xF0
        JP Z,pe_sx
        CP 0xF7
        JP Z,pe_sx
        OR A
        JP P,pe_run
        LD (cstat),A
        CALL getb
pe_run: LD B,A
        LD A,(cstat)
        LD C,A
        AND 0xF0
        CP 0x90
        JR Z,pe_on
        CP 0x80
        JR Z,pe_of
        CP 0xC0
        JP Z,pe_nx
        CP 0xD0
        JP Z,pe_nx
        CALL getb
        JP pe_nx
pe_on:  CALL getb
        OR A
        JR Z,pe_of2
        PUSH HL
        CALL noteon
        POP HL
        JP pe_nx
pe_of:  CALL getb
pe_of2: PUSH HL
        CALL noteoff
        POP HL
        JP pe_nx
pe_meta: CALL getb
        LD (mtype),A
        CALL rdvlq
        LD A,(mtype)
        CP 0x2F
        JP Z,pe_off
        CP 0x51
        JR NZ,pe_m1
        CALL getb
        LD (tempo+2),A
        CALL getb
        LD (tempo+1),A
        CALL getb
        LD (tempo),A
        DEC DE
        DEC DE
        DEC DE
        PUSH HL
        PUSH DE
        CALL settempo
        POP DE
        POP HL
        JR pe_sk
pe_m1:  CP 0x03
        JR NZ,pe_sk
        LD A,(gottitle)
        OR A
        JR NZ,pe_sk
        INC A
        LD (gottitle),A
        LD B,32
pe_t2:  LD A,D
        OR E
        JR Z,pe_nx
        CALL getb
        DEC DE
        CP 0x60
        JR C,pe_t3
        SUB 0x20
pe_t3:  PUSH DE
        PUSH BC
        LD DE,(tcur)
        LD C,0
        CALL putc
        LD (tcur),DE
        POP BC
        POP DE
        DJNZ pe_t2
pe_sk:  LD A,D
        OR E
        JR Z,pe_nx
        CALL getb
        DEC DE
        JR pe_sk
pe_sx:  CALL rdvlq
        JR pe_sk
pe_nx:  CALL rdvlq
        LD A,D
        OR E
        JP Z,pe_ev
        PUSH HL
        LD HL,(tbase)
        INC HL
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        POP DE
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD DE,(csec)
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD A,(cstat)
        LD (HL),A
        RET
pe_off: LD HL,(tbase)
        LD (HL),0
        RET

; ---- variable-length number from the track -> DE (saturates at 65535)
rdvlq:  LD DE,0
rv_l:   CALL getb
        LD C,A
        AND 0x7F
        LD B,A
        LD A,D
        CP 2
        JR NC,rv_s
        SRL D
        RR E
        LD D,E
        LD A,0
        RRA
        OR B
        LD E,A
        BIT 7,C
        JR NZ,rv_l
        RET
rv_s:   BIT 7,C
        JR Z,rv_s2
        CALL getb
        LD C,A
        JR rv_s
rv_s2:  LD DE,0xFFFF
        RET

; ---- note table: pitch, channel, sequence number
noteon: LD A,C            ; B = note, C = status byte
        AND 0x0F
        CP 9
        JR Z,drum
        LD C,A
noteadd: LD A,1
        LD (nchg),A
        LD HL,seqnow
        INC (HL)
        LD HL,ntab
        LD D,NNOTE
no_f:   LD A,(HL)
        INC A
        JR Z,no_p
        INC HL
        INC HL
        INC HL
        DEC D
        JR NZ,no_f
        LD HL,ntab
no_p:   LD (HL),B
        INC HL
        LD (HL),C
        INC HL
        LD A,(seqnow)
        LD (HL),A
        RET
noteoff: LD A,C
        AND 0x0F
        CP 9
        RET Z
        LD C,A
        LD HL,ntab
        LD D,NNOTE
nf_l:   LD A,(HL)
        CP B
        JR NZ,nf_n
        INC HL
        LD A,(HL)
        DEC HL
        CP C
        JR NZ,nf_n
        LD (HL),0xFF
        LD A,1
        LD (nchg),A
        RET
nf_n:   INC HL
        INC HL
        INC HL
        DEC D
        JR NZ,nf_l
        RET
drum:   LD A,B            ; General MIDI drum note -> kick 3, snare 2, hat 1
        LD C,3
        CP 37
        JR C,dr_s
        LD C,2
        CP 41
        JR C,dr_s
        LD C,1
        CP 42
        JR Z,dr_s
        CP 44
        JR Z,dr_s
        CP 46
        JR Z,dr_s
        CP 49
        JR NC,dr_s
        LD C,3            ; toms
dr_s:   LD A,(dreq)
        CP C
        RET NC
        LD A,C
        LD (dreq),A
        RET

; ---- choose what the three voices play: highest note, lowest note, and
;      the most recently struck of the rest
select: LD HL,ntab
        LD B,NNOTE
        LD D,0xFF
        LD E,0
se_1:   LD A,(HL)
        CP 0xFF
        JR Z,se_1n
        CP D
        JR NC,se_1a
        LD D,A
        INC HL
        INC HL
        LD C,(HL)
        DEC HL
        DEC HL
        LD A,C
        LD (loseq),A
        LD A,(HL)
se_1a:  CP E
        JR C,se_1n
        JR Z,se_1n
        LD E,A
        INC HL
        INC HL
        LD C,(HL)
        DEC HL
        DEC HL
        LD A,C
        LD (hiseq),A
se_1n:  INC HL
        INC HL
        INC HL
        DJNZ se_1
        LD A,D
        CP 0xFF
        JR NZ,se_2
        LD E,0xFF         ; nothing sounding
se_2:   LD A,0xFF
        LD (mipit),A
        LD HL,ntab
        LD B,NNOTE
        LD C,0xFF
se_3:   LD A,(HL)
        CP 0xFF
        JR Z,se_3n
        CP D
        JR Z,se_3n
        CP E
        JR Z,se_3n
        INC HL
        INC HL
        LD A,(seqnow)
        SUB (HL)
        DEC HL
        DEC HL
        CP C
        JR NC,se_3n
        LD C,A
        LD A,(HL)
        LD (mipit),A
se_3n:  INC HL
        INC HL
        INC HL
        DJNZ se_3
        LD A,(seqnow)
        SUB C
        LD (miseq),A
        ; lead = highest
        PUSH DE
        LD A,(hiseq)
        LD L,A
        LD A,E
        LD C,0
        CALL setv
        POP DE
        ; bass = lowest, unless it is the same note as the lead
        LD A,D
        CP E
        JR NZ,se_4
        LD A,0xFF
se_4:   PUSH AF
        LD A,(loseq)
        LD L,A
        POP AF
        LD C,1
        CALL setv
        LD A,(miseq)
        LD L,A
        LD A,(mipit)
        LD C,2
        CALL setv
        JP applyv

; ---- voice C (0 lead, 1 bass, 2 mid) plays pitch A (FF = silent), id L
setv:   LD (sv_p),A
        LD A,L
        LD (sv_s),A
        LD A,C
        LD (sv_v),A
        ADD A,A
        ADD A,A
        ADD A,A
        LD E,A
        LD D,0
        LD HL,vce
        ADD HL,DE
        LD A,(sv_p)
        CP 0xFF
        JR NZ,sv_on
        CP (HL)
        RET Z
        LD (HL),A
        PUSH HL
        LD DE,6
        ADD HL,DE
        LD (HL),0
        POP HL
        JR sv_nm
sv_on:  CP (HL)
        JR NZ,sv_new
        INC HL
        LD A,(sv_s)
        CP (HL)
        DEC HL
        RET Z
sv_new: LD A,(sv_p)
        LD (HL),A
        INC HL
        LD A,(sv_s)
        LD (HL),A
        INC HL
        INC HL
        PUSH HL
        LD A,(sv_v)
        LD E,A
        LD D,0
        LD HL,wstart
        ADD HL,DE
        LD A,(HL)
        POP HL
        LD (HL),A
        INC HL
        PUSH HL
        LD A,(sv_p)
        CALL getfreq
        EX DE,HL
        POP HL
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD (HL),1
sv_nm:  LD A,(vmode)
        OR A
        JR Z,sv_nb
        CP 1
        RET NZ
        JP scopev
sv_nb:
        LD A,(sv_v)
        ADD A,A
        LD E,A
        LD D,0
        LD HL,baraddr
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD HL,17
        ADD HL,DE
        EX DE,HL
        LD C,0
        LD A,(sv_p)
        CP 0xFF
        JR NZ,sv_n1
        LD A,'-'
        CALL putc
        LD A,'-'
        CALL putc
        LD A,'-'
        JP putc
sv_n1:  LD A,(t_semi)
        ADD A,A
        PUSH DE
        LD E,A
        LD D,0
        LD HL,nnames
        ADD HL,DE
        POP DE
        LD A,(HL)
        CALL putc
        INC HL
        LD A,(HL)
        CALL putc
        LD A,(t_oct)
        ADD A,'0'-1
        JP putc

getfreq: CALL gfraw        ; A = MIDI note -> HL = phase step
        LD A,(omode)
        CP 3
        RET NZ
        LD D,H            ; the printer port loop is 3% slower: step it up
        LD E,L
        SRL D
        RR E
        SRL D
        RR E
        SRL D
        RR E
        SRL D
        RR E
        SRL D
        RR E
        ADD HL,DE
        RET
gfraw:  LD C,0
gf_l:   CP 12
        JR C,gf_1
        SUB 12
        INC C
        JR gf_l
gf_1:   LD (t_semi),A
        ADD A,A
        LD E,A
        LD D,0
        LD HL,ftab
        ADD HL,DE
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        LD A,C
        LD (t_oct),A
        LD A,9
        SUB C
        RET Z
        RET C
        LD B,A
gf_s:   SRL H
        RR L
        DJNZ gf_s
        RET

; ---- copy pulse widths and mute state into the engine's instructions
applyv: LD A,(vce+3)
        LD (e_w0+1),A
        LD A,(vce+6)
        CALL av_m
        LD (e_m0+1),A
        LD A,B
        LD (e_x0+1),A
        LD A,(vce+11)
        LD (e_w1+1),A
        LD A,(vce+14)
        CALL av_m
        LD (e_m1+1),A
        LD A,B
        LD (e_x1+1),A
        LD A,(vce+19)
        LD (e_w2+1),A
        LD A,(vce+22)
        CALL av_m
        LD (e_m2+1),A
        LD A,B
        LD (e_x2+1),A
        RET
av_m:   OR A
        LD A,(xorm)
        LD B,A
        LD A,0
        RET Z
        LD A,(xorv)
        LD B,A
        LD A,(andv)
        RET

; ---- wait DE ticks, playing
dowait: PUSH DE
        LD A,(evn)
        LD B,A
        ADD A,A
        JR C,dw_s
        ADD A,A
        JR C,dw_s
        ADD A,B
        JR C,dw_s
        LD HL,ntrk
        ADD A,(HL)
        JR C,dw_s
        ADD A,GRC
        JR C,dw_s
        LD HL,debt
        ADD A,(HL)
        JR NC,dw_o
dw_s:   LD A,255
dw_o:   LD (debt),A
        XOR A
        LD (evn),A
        POP DE
dw_0:   LD A,D
        OR E
        JR NZ,dw_1
        ; no time passes, but a pending drum still has to sound
        LD A,(dreq)
        OR A
        RET Z
        CALL dodrum
        RET
dw_1:   LD A,D
        OR A
        JR Z,dw_2
        LD A,255
        JR dw_3
dw_2:   LD A,E
dw_3:   ; A = this piece, DE -= A
        LD C,A
        LD A,E
        SUB C
        LD E,A
        JR NC,dw_4
        DEC D
dw_4:   PUSH DE
        LD A,(lastpc)
        CP C
        JR Z,dw_5
        LD A,C
        LD (lastpc),A
        CALL mulp
dw_5:   ; wt = product (int part) with the running fraction carried
        LD A,(wfrac)
        LD HL,pr0
        ADD A,(HL)
        LD (wfrac),A
        INC HL
        LD A,(HL)
        ADC A,0
        LD (wt0),A
        INC HL
        LD A,(HL)
        ADC A,0
        LD (wt0+1),A
        INC HL
        LD A,(HL)
        ADC A,0
        LD (wt2),A
        ; overheads we owe: event work, then any drum
        LD A,(debt)
        OR A
        CALL NZ,owe
        XOR A
        LD (debt),A
        LD A,(dreq)
        OR A
        CALL NZ,dodrum
        CALL wait
        POP DE
        LD A,(stopf)
        OR A
        RET NZ
        JR dw_0

; ---- take A loop passes off the wait still to come (never below zero)
owe:    LD E,A
        LD D,0
        LD A,(wt2)
        OR A
        JR NZ,ow_1
        LD HL,(wt0)
        OR A
        SBC HL,DE
        JR NC,ow_2
        LD HL,0
ow_2:   LD (wt0),HL
        RET
ow_1:   LD HL,(wt0)
        OR A
        SBC HL,DE
        LD (wt0),HL
        RET NC
        LD HL,wt2
        DEC (HL)
        RET

dodrum: LD C,A
        XOR A
        LD (dreq),A
        LD A,C
        PUSH AF
        ; show it
        LD DE,VRAM+14*32+26
        LD HL,s_kick
        CP 3
        JR Z,dd_1
        LD HL,s_snare
        CP 2
        JR Z,dd_1
        LD HL,s_hat
dd_1:   LD C,0x40
        CALL puts
        LD A,12
        LD (dshow),A
        POP AF
        CP 3
        JR Z,d_kick
        CP 2
        JR Z,d_snare
        LD B,HATN
        CALL noise
        LD A,HATC
        JP owe
d_snare: LD B,SNRN
        CALL noise
        LD A,SNRC
        JP owe
d_kick: LD HL,0
        LD DE,KICKF
        LD B,KICKN
dk_l:   ADD HL,DE
        LD A,H
        RLCA
        SBC A,A
o_ka:   AND 0x21
o_kx:   XOR 0x20
o_ko:   LD (SPK),A
        LD A,E
        SUB KICKS
        LD E,A
        JR NC,dk_1
        DEC D
dk_1:   LD C,14
dk_2:   DEC C
        JR NZ,dk_2
        DJNZ dk_l
        LD A,KICKC
        JP owe
noise:  LD HL,(nseed)
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

; ---- play wt loop passes, doing the per-frame work every 256
wait:   LD HL,(wt0)
        LD A,(wt2)
        OR H
        OR L
        RET Z
        LD DE,(fl)
        LD A,(wt2)
        OR A
        JR NZ,wa_f
        PUSH HL
        OR A
        SBC HL,DE
        POP HL
        JR NC,wa_f
        EX DE,HL          ; less than a frame left: play it all
wa_f:   LD HL,(wt0)
        OR A
        SBC HL,DE
        LD (wt0),HL
        JR NC,wa_1
        LD HL,wt2
        DEC (HL)
wa_1:   LD HL,(fl)
        OR A
        SBC HL,DE
        LD (fl),HL
        LD B,E
        LD C,D
        LD A,E
        OR A
        JR Z,wa_2
        INC C
wa_2:   CALL engrun
        LD HL,(fl)
        LD A,H
        OR L
        JR NZ,wait
        LD HL,512
        LD (fl),HL
        CALL frame
        LD A,(fx)
        ADD A,FRC
        CALL owe
        XOR A
        LD (fx),A
        LD A,(resel)
        OR A
        JR Z,wa_3
        XOR A
        LD (resel),A
        CALL select
wa_3:   LD A,(pausef)
        LD HL,viewf
        OR (HL)
        CALL NZ,pflags
        LD A,(stopf)
        OR A
        RET NZ
        JR wait

; ---- the sound loop: three square waves, one speaker bit, B passes
engrun: LD (spsave),SP
        LD HL,(pha1)
        LD DE,(vce+12)
        EXX
        LD HL,(pha2)
        LD BC,(vce+20)
        LD DE,(pha0)
        EXX
        LD SP,(vce+4)
e_lp:   ADD HL,DE
        LD A,H
e_w1:   CP 0x80
        SBC A,A
e_m1:   AND 0x21
e_x1:   XOR 0x20
o_e1:   LD (SPK),A
        EXX
        ADD HL,BC
        LD A,H
e_w2:   CP 0x80
        SBC A,A
e_m2:   AND 0x21
e_x2:   XOR 0x20
o_e2:   LD (SPK),A
        EX DE,HL
        ADD HL,SP
        LD A,H
e_w0:   CP 0x80
        SBC A,A
e_m0:   AND 0x21
e_x0:   XOR 0x20
o_e0:   LD (SPK),A
        EX DE,HL
        EXX
        DJNZ e_lp
        DEC C
        JP NZ,e_lp
        LD (pha1),HL
        EXX
        LD (pha2),HL
        LD (pha0),DE
        EXX
        LD SP,(spsave)
        RET

; ---- every 256 passes: fade the pulse widths, redraw one bar, read keys
frame:  LD A,(vce+3)
        SUB 6
        CP 0x28
        JR NC,fr_0
        LD A,0x28
fr_0:   LD (vce+3),A
        LD (e_w0+1),A
        LD A,(vce+11)
        SUB 6
        CP 0x48
        JR NC,fr_1
        LD A,0x48
fr_1:   LD (vce+11),A
        LD (e_w1+1),A
        LD A,(vce+19)
        SUB 6
        CP 0x18
        JR NC,fr_2
        LD A,0x18
fr_2:   LD (vce+19),A
        LD (e_w2+1),A
        LD A,(ismod)
        OR A
        CALL NZ,mdtick
        LD HL,fcnt
        INC (HL)
        LD A,(HL)
        AND 3
        CP 3
        JR Z,fr_d
        LD B,A
        LD A,(vmode)
        OR A
        LD A,B
        JP Z,drawbar
        CP 1
        RET NZ
        LD A,(vmode)
        CP 2
        RET NZ
        JP rollstep
fr_d:   LD A,(dshow)
        OR A
        JP Z,pkeys
        DEC A
        LD (dshow),A
        JP NZ,pkeys
        LD DE,VRAM+14*32+26
        LD HL,s_blank
        LD C,0
        CALL puts
        JP pkeys

drawbar: LD C,A           ; A = voice
        ADD A,A
        ADD A,A
        ADD A,A
        LD E,A
        LD D,0
        LD HL,vce+3
        ADD HL,DE
        LD A,(HL)
        SRL A
        SRL A
        SRL A
        LD B,A
        INC HL
        INC HL
        INC HL
        LD A,(HL)
        OR A
        JR NZ,db_1
        LD B,0
db_1:   LD E,C
        LD HL,blen
        ADD HL,DE
        LD A,(HL)
        CP B
        RET Z
        LD (db_old),A
        LD (HL),B
        LD A,C
        ADD A,A
        LD E,A
        LD HL,baraddr
        ADD HL,DE
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        PUSH HL
        LD E,C
        LD HL,barcol
        ADD HL,DE
        LD C,(HL)
        POP DE
        LD A,(db_old)
        CP 17
        JR NC,db_full
        CP B
        JR C,db_grow
        SUB B
        LD H,A
        LD A,B
        LD C,0x80
        JR db_go
db_grow: LD L,A
        LD A,B
        SUB L
        LD H,A
        LD A,L
db_go:  ADD A,E
        LD E,A
        JR NC,db_g1
        INC D
db_g1:  LD B,H
        LD A,C
db_f:   LD (DE),A
        INC DE
        DJNZ db_f
        RET
db_full: LD H,16
db_l:   LD A,B
        OR A
        JR Z,db_e
        DEC B
        LD A,C
        JR db_p
db_e:   LD A,0x80
db_p:   LD (DE),A
        INC DE
        DEC H
        JR NZ,db_l
        RET

; ---- pr = piece (A) x ipt (24 bit)
mulp:   LD C,A
        LD DE,(ipt)
        LD HL,0
        LD B,8
mp_l:   ADD HL,HL
        RLA
        JR NC,mp_n
        ADD HL,DE
        ADC A,0
mp_n:   DJNZ mp_l
        LD (pr0),HL
        LD (pr0+2),A
        XOR A
        LD (pr0+3),A
        LD A,(ipt+2)
        OR A
        RET Z
        LD E,A
        LD D,0
        LD A,C
        LD HL,0
        LD B,8
mp_2:   ADD HL,HL
        RLA
        JR NC,mp_3
        ADD HL,DE
        ADC A,0
mp_3:   DJNZ mp_2
        LD A,(pr0+2)
        ADD A,L
        LD (pr0+2),A
        LD A,H
        ADC A,0
        LD (pr0+3),A
        RET

; ---- ipt = loop passes per MIDI tick (16.8) = tempo x TMUL / 256 / ppq
settempo: XOR A
        LD (lastpc),A
        LD HL,(tempo)
        LD (mc0),HL
        LD A,(tempo+2)
        LD (mc0+2),A
        XOR A
        LD (mc0+3),A
        LD HL,0
        LD (pp0),HL
        LD (pp0+2),HL
        LD DE,(tmulv)
        LD B,16
st_l:   SRL D
        RR E
        JR NC,st_n
        PUSH BC
        PUSH DE
        LD HL,pp0
        LD DE,mc0
        LD B,4
        OR A
st_a:   LD A,(DE)
        ADC A,(HL)
        LD (HL),A
        INC HL
        INC DE
        DJNZ st_a
        POP DE
        POP BC
st_n:   LD HL,mc0
        SLA (HL)
        INC HL
        RL (HL)
        INC HL
        RL (HL)
        INC HL
        RL (HL)
        DJNZ st_l
        ; divide pp0+1..3 by ppq
        LD HL,0
        LD B,24
st_d:   LD A,(pp0+1)
        ADD A,A
        LD (pp0+1),A
        LD A,(pp0+2)
        RLA
        LD (pp0+2),A
        LD A,(pp0+3)
        RLA
        LD (pp0+3),A
        ADC HL,HL
        LD DE,(ppq)
        JR C,st_s
        OR A
        SBC HL,DE
        JR NC,st_1
        ADD HL,DE
        JR st_e
st_s:   OR A
        SBC HL,DE
st_1:   LD A,(pp0+1)
        INC A
        LD (pp0+1),A
st_e:   DJNZ st_d
        LD HL,(pp0+1)
        LD (ipt),HL
        LD A,(pp0+3)
        LD (ipt+2),A
        OR H
        OR L
        RET NZ
        INC A
        LD (ipt),A
        RET

wstart: DB 0x80,0x80,0x60
baraddr: DW VRAM+5*32+6, VRAM+7*32+6, VRAM+9*32+6
barcol: DB 0x9F,0xDF,0xBF
nnames: DB "C-C#D-D#E-F-F#G-G#A-A#B-"
s_ptitle: DB "VZ-DECK 0.9        MUSIC PLAYER ",0
s_phelp: DB "V:VIEW  SPACE:PAUSE  RETURN:STOP",0
s_lead: DB "LEAD",0
s_bass: DB "BASS",0
s_mid:  DB "MID",0
s_kick: DB "KICK ",0
s_snare: DB "SNARE",0
s_hat:  DB "HAT  ",0
s_blank: DB "     ",0
s_bad:  DB "NOT A MIDI FILE I CAN PLAY",13,0

; ---- "scope": a square wave drawn at the voice's pitch
scopev: LD A,(sv_v)
        ADD A,A
        LD E,A
        LD D,0
        LD HL,baraddr
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD A,(sv_v)
        LD C,A
        LD B,0
        LD HL,barcol
        ADD HL,BC
        LD A,(HL)
        AND 0xF0
        LD C,A
        LD A,(sv_p)
        CP 0xFF
        JR NZ,sc_on
        LD B,26
        LD A,0x80
sc_m:   LD (DE),A
        INC DE
        DJNZ sc_m
        RET
sc_on:  LD A,(t_semi)
        LD L,A
        LD H,0
        PUSH DE
        LD DE,hpbase
        ADD HL,DE
        POP DE
        LD H,(HL)
        LD A,(t_oct)
        SUB 3
        JR C,sc_1
        JR Z,sc_1
        LD B,A
sc_s:   SRL H
        DJNZ sc_s
sc_1:   LD A,H
        OR A
        JR NZ,sc_2
        INC H
sc_2:   LD B,26
        LD L,H
        LD A,0x0C
        LD (sclev),A
sc_l:   LD A,(sclev)
        OR C
        LD (DE),A
        INC DE
        DEC L
        JR NZ,sc_n
        LD L,H
        LD A,(sclev)
        XOR 0x0F
        LD (sclev),A
sc_n:   DJNZ sc_l
        RET

; ---- piano roll: scroll up a line and drop a dot for each voice
rollstep: LD HL,VRAM+7*32
        LD DE,VRAM+6*32
        LD BC,160
        LDIR
        LD H,D
        LD L,E
        LD B,32
        LD A,0x80
rs_c:   LD (HL),A
        INC HL
        DJNZ rs_c
        LD HL,vce
        LD C,0
rs_v:   LD A,(HL)
        CP 0xFF
        JR Z,rs_n
        SUB 36
        JR NC,rs_1
        XOR A
rs_1:   CP 64
        JR C,rs_2
        LD A,63
rs_2:   PUSH HL
        LD B,A            ; x
        SRL A
        LD E,A
        LD D,0
        LD HL,VRAM+11*32
        ADD HL,DE
        EX DE,HL          ; DE = cell
        LD HL,barcol
        LD A,C
        ADD A,L
        LD L,A
        JR NC,rs_3
        INC H
rs_3:   LD A,(HL)
        AND 0xF0
        BIT 0,B
        JR Z,rs_4
        OR 0x05
        JR rs_5
rs_4:   OR 0x0A
rs_5:   LD (DE),A
        POP HL
rs_n:   LD DE,8
        ADD HL,DE
        INC C
        LD A,C
        CP 3
        JR C,rs_v
        LD A,ROLLC
        LD (fx),A
        RET

; ---- tracker view: scroll four lines and write the row just played
trkrow: LD HL,VRAM+7*32+2
        LD DE,VRAM+6*32+2
        LD A,4
tr_s:   LD BC,28
        LDIR
        INC HL
        INC HL
        INC HL
        INC HL
        INC DE
        INC DE
        INC DE
        INC DE
        DEC A
        JR NZ,tr_s
        LD DE,VRAM+10*32+2
        LD HL,rowpit
        LD B,4
        LD C,0
tr_c:   PUSH BC
        PUSH HL
        LD A,(HL)
        CP 0xFF
        JR NZ,tr_n
        LD A,'-'
        CALL putc
        LD A,'-'
        CALL putc
        LD A,'-'
        CALL putc
        JR tr_m
tr_n:   LD B,0
tr_d:   CP 12
        JR C,tr_e
        SUB 12
        INC B
        JR tr_d
tr_e:   ADD A,A
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
        ADD A,'0'-1
        CALL putc
tr_m:   LD A,' '
        CALL putc
        POP HL
        PUSH HL
        INC HL
        INC HL
        INC HL
        INC HL
        LD A,(HL)
        OR A
        JR NZ,tr_h
        LD A,'.'
        CALL putc
        LD A,'.'
        CALL putc
        JR tr_x
tr_h:   CALL prhex
tr_x:   LD A,' '
        CALL putc
        POP HL
        INC HL
        POP BC
        DJNZ tr_c
        RET

