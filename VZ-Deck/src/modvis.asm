; ================================================================ block that lives at 0x6000
blk_src:
        PHASE 0x6000
CLT     EQU MBUF+0x600
PBUF    EQU MBUF+0x800

savepos: LD A,(depth)     ; remember the browser cursor for the trip back
        LD L,A
        LD H,0
        ADD HL,HL
        LD BC,dstack
        ADD HL,BC
        LD A,(cur)
        LD (HL),A
        INC HL
        LD A,(top)
        LD (HL),A
        RET

pscreen: CALL CLS
        LD DE,VRAM
        LD HL,s_ptitle
        LD C,0x40
        CALL puts
        LD DE,VRAM+15*32
        LD HL,s_phelp
        LD C,0x40
        CALL puts
        CALL showom
        LD DE,VRAM+2*32
        LD HL,pname
        LD C,0
        LD B,8
        CALL putn
        LD A,'.'
        CALL putc
        LD B,3
        CALL putn
vinit:  LD HL,VRAM+5*32
        LD DE,VRAM+5*32+1
        LD BC,9*32-1
        LD (HL),0x20
        LDIR
        LD HL,0xFFFF
        LD (blen),HL
        LD (blen+1),HL
        LD C,0
        LD A,(vmode)
        CP 2
        JR Z,vi_roll
        CP 3
        JR Z,vi_trk
        LD DE,VRAM+5*32
        LD HL,s_lead
        CALL puts
        LD DE,VRAM+7*32
        LD HL,s_bass
        CALL puts
        LD DE,VRAM+9*32
        LD HL,s_mid
        CALL puts
        ; show what each voice is doing right now
        XOR A
vi_v:   LD (sv_v),A
        ADD A,A
        ADD A,A
        ADD A,A
        LD E,A
        LD D,0
        LD HL,vce
        ADD HL,DE
        LD A,(HL)
        LD (sv_p),A
        CP 0xFF
        CALL NZ,getfreq
        CALL sv_nm
        LD A,(sv_v)
        INC A
        CP 3
        JR C,vi_v
        RET
vi_roll: LD HL,VRAM+6*32
        LD DE,VRAM+6*32+1
        LD BC,6*32-1
        LD (HL),0x80
        LDIR
        LD DE,VRAM+12*32
        LD HL,s_ruler
        JP puts
vi_trk: LD DE,VRAM+5*32
        LD HL,s_trk
        CALL puts
        LD A,0x3E
        LD (VRAM+10*32),A
        LD A,0x3C
        LD (VRAM+10*32+31),A
        RET

; ---- player keys: 1 stop, 2 pause, 3 change view
pkscan: LD A,(0x68BF)
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
        LD A,(0x68FB)
        CPL
        AND 0x20
        LD A,3
        RET NZ
        LD A,(joyon)
        OR A
        RET Z
        IN A,(0x2E)
        CPL
        AND 0x10
        RET Z
        LD A,1
        RET
pkeys:  CALL pkscan
        OR A
        JR NZ,pk_1
        LD A,1
        LD (armed),A
        RET
pk_1:   LD B,A
        LD A,(armed)
        OR A
        RET Z
        XOR A
        LD (armed),A
        LD A,B
        DEC A
        JR NZ,pk_2
        LD A,1
        LD (stopf),A
        RET
pk_2:   DEC A
        JR NZ,pk_3
        LD A,1
        LD (pausef),A
        RET
pk_3:   LD A,1
        LD (viewf),A
        RET
pflags: LD A,(pausef)
        OR A
        JR Z,pf_v
        XOR A
        LD (pausef),A
        LD (SPK),A
        LD DE,VRAM+14*32+19
        LD HL,s_paused
        LD C,0x40
        CALL puts
pf_1:   CALL vsync
        CALL pkscan
        OR A
        JR NZ,pf_1
pf_2:   CALL vsync
        CALL pkscan
        OR A
        JR Z,pf_2
        DEC A
        JR NZ,pf_3
        LD A,1
        LD (stopf),A
pf_3:   XOR A
        LD (armed),A
        LD DE,VRAM+14*32+19
        LD HL,s_blank6
        LD C,0
        CALL puts
pf_v:   LD A,(viewf)
        OR A
        RET Z
        XOR A
        LD (viewf),A
        LD A,(vmode)
        INC A
        CP 3
        JR C,pf_4
        JR NZ,pf_0
        LD A,(ismod)
        OR A
        LD A,3
        JR NZ,pf_4
pf_0:   XOR A
pf_4:   LD (vmode),A
        JP vinit

; ================================================================ MOD files
play_mod: PUSH HL
        CALL savepos
        POP HL
        PUSH HL
        INC HL
        LD DE,pname
        LD BC,11
        LDIR
        POP HL
        PUSH HL
        LD BC,17
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD A,(HL)
        INC HL
        OR (HL)
        POP HL
        JR NZ,md_ok
        PUSH HL
        EX DE,HL
        LD DE,1624
        OR A
        SBC HL,DE
        POP HL
        JP C,md_bad
md_ok:  LD BC,13
        ADD HL,BC
        LD DE,mcl
        LD BC,4
        LDIR
        LD HL,mcl
        LD DE,0xFA12
        LD BC,4
        LDIR
        CALL CLS
        LD HL,s_load
        CALL PRINT
        LD HL,MBUF
        LD (0xFB80),HL
        CALL D_C2S
        CALL D_READ
        DI
        CALL md_nx
        CALL md_nx
        LD HL,MBUF+1080
        LD A,(HL)
        INC HL
        INC HL
        LD B,(HL)
        CP 'M'
        JR NZ,md_d1
        LD A,B
        CP 'K'
        JR Z,md_31
        JR md_15
md_d1:  CP 'F'
        JR NZ,md_d2
        LD A,B
        CP 'T'
        JR Z,md_31
        JR md_15
md_d2:  CP '4'
        JR NZ,md_15
        LD A,B
        CP 'H'
        JR Z,md_31
md_15:  LD A,15
        LD HL,600
        LD DE,MBUF+470
        JR md_s
md_31:  LD A,31
        LD HL,1084
        LD DE,MBUF+950
md_s:   LD (nsmp),A
        LD (mhdr),HL
        LD A,(DE)
        LD (slen),A
        OR A
        JP Z,md_bad
        CP 129
        JP NC,md_bad
        INC DE
        INC DE
        LD (mord),DE
        LD B,A
        LD C,0
md_m:   LD A,(DE)
        CP C
        JR C,md_m1
        LD C,A
md_m1:  INC DE
        DJNZ md_m
        INC C
        LD A,C
        LD (npat),A
        CALL classify
        LD A,(npat)
        ADD A,A
        JR C,md_st
        LD B,A
        LD A,(nsmp)
        CP 31
        LD A,2
        JR NZ,md_n1
        INC A
md_n1:  ADD A,B
        JR C,md_st
        CP 50
        JR NC,md_st
        SUB 3
        LD B,A
md_r:   PUSH BC
        CALL md_nx
        POP BC
        DJNZ md_r
        XOR A
        LD (mstream),A
        JR md_go
md_st:  LD A,1
        LD (mstream),A
        CALL mkclt
md_go:  LD HL,0xF800
        LD (0xFB80),HL
        CALL pinit
        LD A,1
        LD (ismod),A
        LD A,MODTRIM
        LD (ntrk),A
        LD HL,125
        LD (ppq),HL
        LD HL,0x25A0      ; 2,500,000 us: one tick at "1 beat per minute"
        LD (tempo),HL
        LD A,0x26
        LD (tempo+2),A
        CALL settempo
        LD A,6
        LD (mspeed),A
        XOR A
        LD (pos),A
        LD (mrow),A
        LD (mbreak),A
        LD (mend),A
        LD HL,msmp
        LD B,8
md_z:   LD (HL),A
        INC HL
        DJNZ md_z
        CALL pscreen
        ; song name
        LD HL,MBUF
        LD DE,VRAM+3*32
        LD B,20
        LD C,0
md_t:   LD A,(HL)
        OR A
        JR Z,md_t2
        CP 0x60
        JR C,md_t1
        SUB 0x20
md_t1:  CALL putc
        INC HL
        DJNZ md_t
md_t2:  LD DE,VRAM+14*32
        LD HL,s_pos
        LD C,0
        CALL puts
        CALL mpat
md_loop: LD A,(mend)
        OR A
        JP NZ,pm_end
        CALL mod_row
        LD A,(nchg)
        OR A
        JR Z,md_l1
        XOR A
        LD (nchg),A
        CALL select
md_l1:  LD A,(vmode)
        CP 3
        JR NZ,md_l2
        CALL trkrow
        LD A,(evn)
        ADD A,TRKC
        LD (evn),A
md_l2:  LD DE,VRAM+14*32+4
        LD C,0
        LD A,(pos)
        CALL prhex
        INC DE
        LD A,(slen)
        DEC A
        CALL prhex
        LD DE,VRAM+14*32+14
        LD A,(mrow)
        CALL prhex
        LD A,(mspeed)
        LD E,A
        LD D,0
        CALL dowait
        LD A,(stopf)
        OR A
        JP NZ,pm_end
        LD A,(mbreak)
        OR A
        JR NZ,md_np
        LD HL,(rowp)
        LD DE,16
        ADD HL,DE
        LD (rowp),HL
        LD HL,mrow
        INC (HL)
        LD A,(HL)
        CP 64
        JR C,md_loop
md_np:  XOR A
        LD (mrow),A
        LD (mbreak),A
        LD HL,pos
        INC (HL)
        LD A,(slen)
        LD B,A
        LD A,(HL)
        CP B
        JP NC,pm_end
        CALL mpat
        JP md_loop
md_bad: LD HL,0xF800
        LD (0xFB80),HL
        LD HL,s_badm
        JP pm_msg
md_nx:  LD HL,(0xFB80)
        LD DE,512
        ADD HL,DE
        LD (0xFB80),HL
        CALL D_NEXT
        DI
        RET

; ---- list the file's clusters so any sector can be fetched directly
mkclt:  LD HL,0xF800
        LD (0xFB80),HL
        LD HL,mcl
        LD DE,0xFA12
        LD BC,4
        LDIR
        LD HL,CLT
        LD (clp),HL
        XOR A
        LD (nclt),A
        LD (mend),A
        INC A
        LD (0xFA3C),A
mk_c:   LD DE,(clp)
        LD HL,0xFA12
        LD BC,4
        LDIR
        LD (clp),DE
        LD HL,nclt
        INC (HL)
        LD A,(HL)
        CP 128
        RET Z
        CALL D_NCLUS
        DI
        LD A,(0xFA3C)
        OR A
        JR NZ,mk_c
        RET

; ---- point rowp at the pattern for the current position
mpat:   LD A,(pos)
        LD E,A
        LD D,0
        LD HL,(mord)
        ADD HL,DE
        LD B,(HL)
        LD A,(mstream)
        OR A
        JR NZ,mp_st
        LD H,B
        LD L,0
        ADD HL,HL
        ADD HL,HL
        LD DE,(mhdr)
        ADD HL,DE
        LD DE,MBUF
        ADD HL,DE
        LD (rowp),HL
        RET
mp_st:  LD L,B
        LD H,0
        ADD HL,HL
        LD A,(mhdr+1)
        SRL A
        LD E,A
        LD D,0
        ADD HL,DE
        LD DE,PBUF
        CALL rdfsec
        INC HL
        LD DE,PBUF+512
        CALL rdfsec
        INC HL
        LD DE,PBUF+1024
        CALL rdfsec
        LD HL,0xF800
        LD (0xFB80),HL
        LD HL,(mhdr)
        LD A,H
        AND 1
        LD H,A
        LD DE,PBUF
        ADD HL,DE
        LD (rowp),HL
        RET
; ---- read sector HL of the file to DE, through the cluster table
rdfsec: LD (0xFB80),DE
        PUSH HL
        LD A,(0xFA20)
        LD B,A
        DEC A
        AND L
        LD (rf_off),A
rf_s:   SRL B
        JR Z,rf_1
        SRL H
        RR L
        JR rf_s
rf_1:   LD A,H
        OR A
        JR NZ,rf_bad
        LD A,(nclt)
        LD B,A
        LD A,L
        CP B
        JR NC,rf_bad
        ADD HL,HL
        ADD HL,HL
        LD DE,CLT
        ADD HL,DE
        LD DE,0xFA12
        LD BC,4
        LDIR
        CALL D_C2S
        LD A,(rf_off)
        LD HL,0xFA26
        ADD A,(HL)
        LD (HL),A
        JR NC,rf_2
rf_c:   INC HL
        INC (HL)
        JR Z,rf_c
rf_2:   CALL D_READ
        DI
        POP HL
        RET
rf_bad: LD A,1
        LD (mend),A
        POP HL
        RET

; ---- one pattern row
mod_row: LD HL,(rowp)
        LD C,0
mr_c:   PUSH BC
        LD A,C
        LD (mr_ch),A
        LD A,(HL)
        LD D,A
        AND 0x0F
        LD B,A
        INC HL
        LD E,(HL)
        INC HL
        LD A,(HL)
        INC HL
        LD (mr_b2),A
        LD A,(HL)
        INC HL
        LD (mr_b3),A
        PUSH HL
        LD H,B
        LD L,E
        LD (mr_per),HL
        LD A,D
        AND 0xF0
        LD D,A
        LD A,(mr_b2)
        RRCA
        RRCA
        RRCA
        RRCA
        AND 0x0F
        OR D
        LD (mr_s),A
        LD E,C
        LD D,0
        LD HL,rowpit
        ADD HL,DE
        LD (HL),0xFF
        INC HL
        INC HL
        INC HL
        INC HL
        LD (HL),A
        OR A
        JR Z,mr_1
        LD HL,msmp
        ADD HL,DE
        LD (HL),A
mr_1:   LD HL,(mr_per)
        LD A,H
        OR L
        JP Z,mr_fx
        CALL per2n
        LD (mr_pit),A
        LD A,(mr_ch)
        LD E,A
        LD D,0
        LD HL,rowpit
        ADD HL,DE
        LD A,(mr_pit)
        LD (HL),A
        LD A,20
        LD (mr_dur),A
        LD HL,msmp
        ADD HL,DE
        LD A,(HL)
        OR A
        JR Z,mr_ton
        DEC A
        LD E,A
        LD HL,sdrum
        ADD HL,DE
        LD A,(HL)
        OR A
        JR Z,mr_t1
        LD C,A
        LD A,(dreq)
        CP C
        JP NC,mr_fx
        LD A,C
        LD (dreq),A
        JP mr_fx
mr_t1:  LD HL,sdrum+31
        ADD HL,DE
        LD A,(HL)
        CP 0xFF
        JR Z,mr_t3
        LD B,A
        LD HL,(mr_per)
        SRL H
        RR L
        SRL H
        RR L
        SRL H
        RR L
        SRL H
        RR L
        LD E,L
        LD D,0
        LD HL,0
        LD A,B
        LD B,8
mu_l:   ADD HL,HL
        RLA
        JR NC,mu_n
        ADD HL,DE
mu_n:   DJNZ mu_l
        LD B,4
mu_s:   SRL H
        RR L
        DJNZ mu_s
        LD D,H
        LD E,L
        SRL H
        RR L
        SRL H
        RR L
        EX DE,HL
        OR A
        SBC HL,DE
        LD A,H
        OR A
        JR Z,mu_1
        LD L,254
mu_1:   LD A,L
        CP 255
        JR C,mu_2
        LD A,254
mu_2:   CP 2
        JR NC,mr_t3
        LD A,2
mr_t3:  LD (mr_dur),A
mr_ton: LD A,(mr_ch)
        LD C,A
        CALL chanoff
        LD A,(mr_pit)
        LD B,A
        LD A,(mr_ch)
        LD C,A
        CALL noteadd
        LD A,(mr_ch)
        LD E,A
        LD D,0
        LD HL,mdur
        ADD HL,DE
        LD A,(mr_dur)
        LD (HL),A
        LD HL,evn
        INC (HL)
mr_fx:  LD A,(mr_b2)
        AND 0x0F
        CP 0x0C
        JR NZ,mr_f1
        LD A,(mr_b3)
        OR A
        JR NZ,mr_fe
        LD A,(mr_ch)
        LD C,A
        CALL chanoff
        JR mr_fe
mr_f1:  CP 0x0F
        JR NZ,mr_f2
        LD A,(mr_b3)
        OR A
        JR Z,mr_fe
        CP 0x20
        JR NC,mr_bpm
        LD (mspeed),A
        JR mr_fe
mr_bpm: LD L,A
        LD H,0
        LD (ppq),HL
        CALL settempo
        JR mr_fe
mr_f2:  CP 0x0D
        JR NZ,mr_f3
        LD A,1
        LD (mbreak),A
        JR mr_fe
mr_f3:  CP 0x0B
        JR NZ,mr_fe
        LD A,(pos)
        LD B,A
        LD A,(mr_b3)
        CP B
        JR Z,mr_j0
        JR C,mr_j0
        DEC A
        LD (pos),A
        JR mr_j1
mr_j0:  LD A,(slen)
        DEC A
        LD (pos),A
mr_j1:  LD A,1
        LD (mbreak),A
mr_fe:  POP HL
        POP BC
        INC C
        LD A,C
        CP 4
        JP NZ,mr_c
        RET

chanoff: LD HL,ntab       ; silence whatever channel C was playing
        LD D,NNOTE
co_l:   LD A,(HL)
        INC A
        JR Z,co_n
        INC HL
        LD A,(HL)
        DEC HL
        CP C
        JR NZ,co_n
        LD (HL),0xFF
        LD A,1
        LD (nchg),A
co_n:   INC HL
        INC HL
        INC HL
        DEC D
        JR NZ,co_l
        RET

mdtick: LD HL,mdur        ; once a frame: let un-looped samples run out
        LD C,0
mt_l:   LD A,(HL)
        OR A
        JR Z,mt_n
        INC A
        JR Z,mt_n
        DEC (HL)
        JR NZ,mt_n
        PUSH HL
        PUSH BC
        CALL chanoff
        POP BC
        POP HL
        LD A,1
        LD (resel),A
mt_n:   INC HL
        INC C
        LD A,C
        CP 4
        JR NZ,mt_l
        RET

per2n:  LD B,0            ; HL = Amiga period -> A = note number
p2_a:   LD A,H
        CP 3
        JR C,p2_dbl
        JR NZ,p2_ok
        LD A,L
        CP 0x71
        JR NC,p2_ok
p2_dbl: ADD HL,HL
        INC B
        LD A,B
        CP 6
        JR C,p2_a
p2_ok:  LD A,B
        LD (p2t),A
        LD DE,p2thr
p2_b:   LD A,(DE)
        INC DE
        LD C,A
        LD A,(DE)
        INC DE
        LD B,A
        PUSH HL
        OR A
        SBC HL,BC
        POP HL
        JR NC,p2_d
        LD A,E
        CP (p2thr+22)&255
        JR NZ,p2_b
        INC DE
        INC DE
p2_d:   ; semitone = (DE - p2thr - 2) / 2
        LD HL,0-p2thr-2
        ADD HL,DE
        SRL L
        LD A,(p2t)
        LD B,A
        ADD A,A
        ADD A,B
        ADD A,A
        ADD A,A
        ADD A,L
        ADD A,36
        RET

; ---- which instruments are drums? go by their names
classify: LD HL,MBUF+20
        LD A,(nsmp)
        LD B,A
        LD DE,sdrum
cl_l:   PUSH BC
        PUSH DE
        PUSH HL
        CALL kwfind
        POP HL
        POP DE
        LD (DE),A
        PUSH HL
        PUSH DE
        LD BC,22
        ADD HL,BC
        LD A,(HL)
        INC HL
        LD C,(HL)
        CP 0x80
        JR C,cl_1
        LD A,0x7F
        LD C,0xFF
cl_1:   RLC C
        RLA
        LD B,A
        INC HL
        INC HL
        INC HL
        INC HL
        INC HL
        LD A,(HL)
        INC HL
        OR A
        JR NZ,cl_lp
        LD A,(HL)
        CP 2
        JR C,cl_2
cl_lp:  LD B,0xFF
cl_2:   POP HL            ; sdrum slot
        PUSH HL
        LD DE,31
        ADD HL,DE
        LD (HL),B
        POP DE
        INC DE
        POP HL
        LD BC,30
        ADD HL,BC
        POP BC
        DJNZ cl_l
        RET
kwfind: LD (kwname),HL
        LD DE,kwtab
kw_k:   LD A,(DE)
        CP 0xFF
        JR Z,kw_none
        LD (kwkind),A
        INC DE
        LD HL,(kwname)
        LD B,22
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

kwtab:  DB 2,"SNAR",0,2,"CLAP",0,1,"HAT",0,1,"SHAK",0,1,"CYM",0,1,"CRASH",0,1,"TAMB",0
        DB 3,"KICK",0,3,"DRUM",0,3,"TOM",0,3,"CONGA",0,3,"BONGO",0,0xFF
p2thr:  DW 1664,1570,1482,1398,1319,1245,1175,1109,1047,989,934
hpbase: DB 16,15,14,13,13,12,11,11,10,10,9,8
s_ruler: DB "C2    C3    C4    C5    C6    C7",0
s_trk:  DB "  CH1    CH2    CH3    CH4",0
s_pos:  DB "POS   /    ROW",0
s_paused: DB "PAUSED",0
s_blank6: DB "      ",0
s_badm: DB "NOT A MOD FILE I CAN PLAY",13,0
blk_end0:
        DEPHASE
blk_end:
