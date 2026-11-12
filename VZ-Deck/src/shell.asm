; VZ-DECK 0.8.  VIBED BY BPM 2026
VRAM    EQU 0x7000
ENT     EQU 0x9A00
RECSZ   EQU 24
MAXENT  EQU 250
HO      EQU 0x7FC0
PTR     EQU 0xB200
LROWS   EQU 12
CLS     EQU 0x01C9
PRINT   EQU 0x28A7
D_ROOT  EQU 0x4A8D
D_DIR1  EQU 0x4A7A
D_NEXT  EQU 0x48BF
D_NCLUS EQU 0x49F8
D_RDSEC EQU 0x575D
D_C2S   EQU 0x480D
D_READ  EQU 0x578E
D_BASIC EQU 0x4C4E
D_CLI   EQU 0x4AD2
D_LAUNCH EQU 0x5BBD

start:  DI
        LD SP,0xFFFF
        LD HL,blk_src
        LD DE,0x6000
        LD BC,blk_end0-0x6000
        LDIR
        LD HL,(HO)
        LD DE,0-0x4456
        ADD HL,DE
        LD A,H
        OR L
        JR NZ,st_new
        LD (HO),HL        ; back from a player plug-in
        LD (0x6800),A
        LD A,(HO+2)
        LD (joyon),A
        LD A,1
        LD (restore),A
        JP reenter
st_new: XOR A
        LD (vmode),A
        LD (outmode),A
        XOR A
        LD (0x6800),A
        LD (0x783B),A
        CALL CLS
        CALL D_ROOT
        DI
        LD A,'/'
        LD (path),A
        LD A,1
        LD (pathlen),A
        XOR A
        LD (depth),A
        LD (restore),A
        LD (joyon),A
        IN A,(0x2C)
        AND 0x0F
        CP 0x0F
        JR NZ,nojoy
        IN A,(0x2E)
        BIT 4,A
        JR Z,nojoy
        LD A,1
        LD (joyon),A
nojoy:  CALL readdir
        CALL plscan
reenter: DI
        LD SP,0xFFFF
        CALL scan
        LD (lastkey),A
        CALL CLS
        ; static rows
        LD DE,VRAM
        LD HL,s_title
        LD C,0x40
        CALL puts
        LD DE,VRAM+15*32
        LD HL,s_help
        LD C,0x40
        CALL puts
newdir: CALL readdir
        LD A,(restore)
        OR A
        JR Z,redraw
        XOR A
        LD (restore),A
        LD A,(depth)
        LD L,A
        LD H,0
        ADD HL,HL
        LD BC,dstack
        ADD HL,BC
        LD A,(count)
        LD B,A
        LD A,(HL)
        CP B
        JR NC,redraw
        LD (cur),A
        INC HL
        LD A,(HL)
        LD (top),A
redraw: CALL drawpath
        CALL drawlist
        CALL drawinfo
keys:   CALL getkey
        CP 1
        JR Z,k_up
        CP 2
        JR Z,k_down
        CP 3
        JR Z,k_pgup
        CP 4
        JR Z,k_pgdn
        CP 5
        JP Z,k_enter
        CP 6
        JP Z,k_basic
        CP 7
        JP Z,k_cli
        CP 8
        JP Z,k_out
        JR keys
k_up:   CALL goup
        JR redraw
k_down: CALL godown
        JR redraw
k_pgup: LD B,LROWS
kpu:    PUSH BC
        CALL goup
        POP BC
        DJNZ kpu
        JR redraw
k_pgdn: LD B,LROWS
kpd:    PUSH BC
        CALL godown
        POP BC
        DJNZ kpd
        JR redraw

goup:   LD A,(cur)
        OR A
        RET Z
        DEC A
        LD (cur),A
        LD HL,top
        CP (HL)
        RET NC
        LD (HL),A
        RET
godown: LD A,(count)
        LD B,A
        LD A,(cur)
        INC A
        CP B
        RET NC
        LD (cur),A
        LD HL,top
        SUB (HL)
        CP LROWS
        RET C
        INC (HL)
        RET

k_basic: CALL CLS
        JP D_BASIC
k_cli:  CALL CLS
        JP D_CLI
k_enter: LD A,(count)
        OR A
        JP Z,keys
        LD A,(cur)
        CALL recptr
        LD A,(HL)
        CP 2
        JR NZ,chdir
        CALL isvz
        JR Z,k_run
        PUSH HL
        LD BC,9
        ADD HL,BC
        LD A,(HL)
        CP 'M'
        JR NZ,k_no
        INC HL
        LD A,(HL)
        CP 'I'
        JR Z,k_mi
        CP 'O'
        JR NZ,k_no
        INC HL
        LD A,(HL)
        CP 'D'
        POP HL
        JP Z,play_mod
        JP keys
k_mi:   INC HL
        LD A,(HL)
        CP 'D'
k_no:   POP HL
        JP Z,play_mid
        CALL plugfind
        JP Z,plugrun
        JP keys
k_run:  ; launch: name -> FB28, DOS stub does the rest
        PUSH HL
        CALL CLS
        LD HL,s_load
        CALL PRINT
        POP HL
        INC HL
        PUSH HL
        LD B,8
ld_n:   LD A,(HL)
        CP ' '
        JR Z,ld_x
        CALL 0x41FA
        INC HL
        DJNZ ld_n
ld_x:   LD A,13
        CALL 0x41FA
        POP HL
        LD DE,0xFB28
        LD BC,11
        LDIR
        JP D_LAUNCH

chdir:  ; HL = record of a folder (key 0 = parent, 1 = folder)
        LD A,(HL)
        INC HL            ; HL = name
        OR A
        JR Z,cd_up
        LD A,(pathlen)
        CP 110
        JP NC,keys
        PUSH HL
        LD A,(depth)
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
        LD HL,depth
        INC (HL)
        POP HL
        LD A,(pathlen)
        ; append name to path
        PUSH HL
        LD E,A
        LD D,0
        LD HL,path
        ADD HL,DE
        EX DE,HL          ; DE = path end
        POP HL
        PUSH HL
        LD B,8
cd_a:   LD A,(HL)
        CP ' '
        JR Z,cd_b
        LD (DE),A
        INC DE
        INC HL
        DJNZ cd_a
cd_b:   LD A,'/'
        LD (DE),A
        INC DE
        LD HL,path
        EX DE,HL
        OR A
        SBC HL,DE
        LD A,L
        LD (pathlen),A
        POP HL
        JR cd_go
cd_up:  PUSH HL
        LD A,(depth)
        OR A
        JR Z,cd_u0
        DEC A
        LD (depth),A
        LD A,1
        LD (restore),A
cd_u0:
        LD A,(pathlen)
        DEC A             ; drop trailing '/'
        LD E,A
        LD D,0
        LD HL,path
        ADD HL,DE         ; HL -> trailing '/'
cd_u1:  DEC HL
        DEC A
        JR Z,cd_u2
        LD B,A
        LD A,(HL)
        CP '/'
        LD A,B
        JR NZ,cd_u1
cd_u2:  INC A
        LD (pathlen),A
        POP HL
cd_go:  LD BC,12
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD (0xFB45),DE
        LD A,D
        OR E
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD (0xFB47),DE
        OR D
        OR E
        JP NZ,newdir
        CALL D_ROOT
        DI
        JP newdir

; ---------------------------------------------------------------- plug-in players
; PLAYxxx.VZ in the root folder plays files of type xxx
plscan: XOR A
        LD (nplug),A
        LD A,(count)
        OR A
        RET Z
        LD B,A
        LD C,0
ps_l:   PUSH BC
        LD A,C
        CALL recptr
        LD A,(HL)
        CP 2
        JR NZ,ps_n
        CALL isvz
        JR NZ,ps_n
        PUSH HL
        INC HL
        LD DE,s_shnm
        LD B,8
        CALL cmpn
        POP HL
        JR NZ,ps_p
        PUSH HL
        LD BC,13
        ADD HL,BC
        LD DE,shcl
        LD BC,6
        LDIR
        POP HL
        JR ps_n
ps_p:   PUSH HL
        INC HL
        LD DE,s_play
        LD B,4
        CALL cmpn
        POP HL
        JR NZ,ps_n
        LD A,(nplug)
        CP 8
        JR NC,ps_n
        LD E,A
        ADD A,A
        ADD A,A
        ADD A,A
        ADD A,E
        LD E,A
        LD D,0
        PUSH HL
        LD HL,plugs
        ADD HL,DE
        EX DE,HL
        POP HL
        PUSH HL
        LD BC,5
        ADD HL,BC
        LD BC,3
        LDIR
        POP HL
        LD BC,13
        ADD HL,BC
        LD BC,6
        LDIR
        LD HL,nplug
        INC (HL)
ps_n:   POP BC
        INC C
        DJNZ ps_l
        RET
cmpn:   LD A,(DE)         ; Z if B bytes at HL match DE
        CP (HL)
        RET NZ
        INC HL
        INC DE
        DJNZ cmpn
        RET

plugfind: PUSH HL         ; HL = record -> Z, DE = plug entry, if a plug-in plays it
        LD BC,9
        ADD HL,BC
        LD DE,plugs
        LD A,(nplug)
        OR A
        JR Z,pf_no
        LD B,A
pf_l:   PUSH BC
        PUSH HL
        PUSH DE
        LD B,3
        CALL cmpn
        POP DE
        POP HL
        POP BC
        JR Z,pf_y
        LD A,E
        ADD A,9
        LD E,A
        JR NC,pf_m
        INC D
pf_m:   DJNZ pf_l
pf_no:  POP HL
        OR 1
        RET
pf_y:   POP HL
        XOR A
        RET

plugrun: PUSH DE          ; HL = record, DE = plug entry
        PUSH HL
        CALL savepos
        POP HL
        LD A,(joyon)
        LD (HO+2),A
        LD A,(outmode)
        LD (HO+29),A
        PUSH HL
        LD BC,13
        ADD HL,BC
        LD DE,HO+3
        LD BC,8
        LDIR
        POP HL
        INC HL
        LD BC,11
        LDIR
        LD HL,shcl
        LD BC,6
        LDIR
        LD HL,0
        LD (HO),HL
        CALL CLS
        LD HL,s_load
        CALL PRINT
        POP HL
        INC HL
        INC HL
        INC HL
        LD DE,0xFA12
        LD BC,4
        LDIR
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD HL,511
        ADD HL,DE
        LD A,H
        SRL A
        LD (secs),A
        LD HL,0x9FE8
        LD (0xFB80),HL
        CALL D_C2S
        CALL D_READ
        DI
pr_l:   LD HL,secs
        DEC (HL)
        JR Z,pr_x
        LD HL,(0xFB80)
        LD DE,512
        ADD HL,DE
        LD (0xFB80),HL
        CALL D_NEXT
        DI
        JR pr_l
pr_x:   LD HL,0xF800
        LD (0xFB80),HL
        JP 0xA000

s_shnm: DB "SHELL   "
s_play: DB "PLAY"

; ---------------------------------------------------------------- sound output
; 0 speaker, 1 cassette port, 2 speaker + cassette, 3 printer port (OUT 14)
k_out:  LD A,(outmode)
        INC A
        AND 3
        LD (outmode),A
        CALL outset
        LD DE,VRAM+14*32
        CALL clrrow
        LD HL,s_out
        LD C,0
        CALL puts
        LD A,(outmode)
        ADD A,A
        ADD A,A
        ADD A,A
        ADD A,A
        LD L,A
        LD H,0
        LD BC,s_omodes
        ADD HL,BC
        LD C,0
        CALL puts
        ; test tone: 0.2 s of 880 Hz on the chosen output
        LD B,176
ko_l:   LD A,(xorv)
        CALL ko_w
        LD A,(andv)
        LD C,A
        LD A,(xorv)
        XOR C
        CALL ko_w
        DJNZ ko_l
        LD A,(xorm)
        CALL ko_w
        JP keys
ko_w:   LD C,A
        LD A,(omode)
        CP 3
        LD A,C
        JR Z,ko_p
        LD (0x6800),A
        JR ko_d
ko_p:   OUT (14),A
ko_d:   LD C,140
ko_d1:  DEC C
        JR NZ,ko_d1
        RET
outset: AND 3             ; A = output mode: set the values and patch the code
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
        INC HL
        LD A,(HL)
        LD (xorv),A
        INC HL
        LD A,(HL)
        LD (xorm),A
        LD HL,TMUL
        LD A,(omode)
        CP 3
        JR NZ,os_1
        LD HL,TMULP
os_1:   LD (tmulv),HL
        LD HL,o_sites
os_l:   LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD A,D
        OR E
        JR Z,os_ax
        LD A,(omode)
        CP 3
        JR Z,os_p
        LD A,0x32         ; LD (0x6800),A
        LD (DE),A
        INC DE
        XOR A
        LD (DE),A
        INC DE
        LD A,0x68
        LD (DE),A
        JR os_l
os_p:   LD A,0xD3         ; OUT (14),A : NOP
        LD (DE),A
        INC DE
        LD A,14
        LD (DE),A
        INC DE
        XOR A
        LD (DE),A
        JR os_l
os_ax:  LD A,(andv)
        LD (o_ka+1),A
        LD (o_na+1),A
        LD A,(xorv)
        LD (o_kx+1),A
        LD (o_nx+1),A
        RET
o_sites: DW o_e0,o_e1,o_e2,o_ko,o_no,0
omtab:  DB 0x21,0x20,0x00, 0x02,0x04,0x04, 0x23,0x24,0x04, 0x21,0x20,0x00
s_out:  DB "SOUND OUT: ",0
s_omodes: DB "SPEAKER",0,0,0,0,0,0,0,0,0
        DB "CASSETTE PORT",0,0,0
        DB "SPEAKER+CASSETT",0
        DB "PRINTER PORT",0,0,0,0
s_otag: DB "SPK",0,"CAS",0,"S+C",0,"PRN",0
showom: LD A,(omode)      ; mode tag on the player's title line
        ADD A,A
        ADD A,A
        LD L,A
        LD H,0
        LD DE,s_otag
        ADD HL,DE
        LD DE,VRAM+13
        LD C,0x40
        JP puts

; ---------------------------------------------------------------- keyboard
scan:   LD A,(joyon)
        OR A
        JR Z,sc_kb
        IN A,(0x2C)
        CPL
        LD B,A
        LD A,1
        BIT 0,B
        RET NZ
        INC A
        BIT 1,B
        RET NZ
        INC A
        BIT 2,B
        RET NZ
        INC A
        BIT 3,B
        RET NZ
        IN A,(0x2E)
        BIT 4,A
        LD A,5
        RET Z
sc_kb:  LD A,(0x68EF)
        CPL
        LD B,A
        LD A,1
        BIT 1,B
        RET NZ
        INC A
        BIT 4,B
        RET NZ
        INC A
        BIT 5,B
        RET NZ
        INC A
        BIT 3,B
        RET NZ
        LD A,(0x68BF)
        CPL
        BIT 2,A
        LD A,5
        RET NZ
        LD A,(0x68FB)
        CPL
        LD B,A
        LD A,6
        BIT 0,B
        RET NZ
        INC A
        BIT 3,B
        RET NZ
        LD A,(0x68BF)
        CPL
        BIT 1,A
        LD A,8
        RET NZ
        XOR A
        RET

getkey: CALL vsync
        CALL scan
        LD HL,lastkey
        OR A
        JR NZ,gk_some
        LD (HL),A
        JR getkey
gk_some: CP (HL)
        JR Z,gk_same
        LD (HL),A
        LD B,A
        LD A,18
        LD (rpt),A
        LD A,B
        RET
gk_same: CP 5
        JR NC,getkey
        LD B,A
        LD HL,rpt
        DEC (HL)
        JR NZ,getkey
        LD (HL),3
        LD A,B
        RET

vsync:  LD A,(0x6800)
        RLCA
        JR NC,vsync
vs2:    LD A,(0x6800)
        RLCA
        JR C,vs2
        RET

; ---------------------------------------------------------------- directory
readdir: XOR A
        LD (count),A
        LD (cur),A
        LD (top),A
        LD HL,ENT
        LD (wptr),HL
        LD A,1
        LD (0xFA3C),A
        CALL D_DIR1
        DI
rd_sec: LD HL,0xF800
        LD B,16
rd_ent: LD A,(HL)
        OR A
        JP Z,rd_done
        CP 0xE5
        JP Z,rd_next
        PUSH HL
        LD DE,11
        ADD HL,DE
        LD A,(HL)
        POP HL
        LD C,A
        AND 0x0A          ; volume label / long name / hidden
        JR NZ,rd_next
        LD A,(HL)
        CP '.'
        JR NZ,rd_keep
        INC HL
        LD A,(HL)
        DEC HL
        CP ' '
        JR Z,rd_next      ; the dot entry
rd_keep: LD A,C
        AND 0x10
        LD A,2
        JR Z,rk1          ; file
        LD A,(HL)
        CP '.'
        LD A,1
        JR NZ,rk1         ; folder
        XOR A             ; parent
rk1:    PUSH HL
        PUSH BC
        LD DE,(wptr)
        LD (DE),A
        PUSH HL
        LD A,(count)
        LD L,A
        LD H,0
        ADD HL,HL
        LD BC,PTR
        ADD HL,BC
        LD (HL),E
        INC HL
        LD (HL),D
        POP HL
        INC DE
        LD BC,12
        LDIR              ; name + attr, HL = entry+12
        PUSH HL
        LD BC,0x1A-12
        ADD HL,BC
        LD A,(HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(HL)
        LD (DE),A
        INC DE
        POP HL
        PUSH HL
        LD BC,0x14-12
        ADD HL,BC
        LD A,(HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(HL)
        LD (DE),A
        INC DE
        POP HL
        PUSH HL
        LD BC,0x1C-12
        ADD HL,BC
        LD BC,4
        LDIR              ; size
        POP HL
        LD BC,0x18-12
        ADD HL,BC
        LD BC,2
        LDIR              ; date
        INC DE
        LD (wptr),DE
        POP BC
        POP HL
        LD A,(count)
        INC A
        LD (count),A
        CP MAXENT
        JR Z,rd_done
rd_next: LD DE,32
        ADD HL,DE
        DEC B
        JP NZ,rd_ent
        ; next sector - follow the cluster chain ourselves at a boundary so
        ; we never ask the card for a sector past the end of the chain
        LD A,(0xFA20)
        LD B,A
        LD A,(0xFA21)
        INC A
        CP B
        JR Z,rd_clus
        CALL D_NEXT
        DI
        JP rd_sec
rd_clus: CALL D_NCLUS
        DI
        LD A,(0xFA3C)
        OR A
        JR Z,rd_done
        LD DE,(0xFA28)
        LD HL,(0xFA26)
        CALL D_RDSEC
        DI
        JP rd_sec
rd_done: ; fall into sort

sort:   LD A,(count)
        CP 2
        RET C
        LD (gap),A
so_pass: LD A,(gap)
        CP 2
        JR C,so_g1
        LD B,A
        SRL A
        SRL A
        JR NZ,so_g0
        INC A
so_g0:  LD C,A
        LD A,B
        SUB C
        LD (gap),A
so_g1:  XOR A
        LD (swapped),A
        LD A,(gap)
        LD C,A
        LD A,(count)
        SUB C
        LD B,A            ; B = comparisons this pass
        LD L,C
        LD H,0
        ADD HL,HL
        LD DE,PTR
        ADD HL,DE
        EX DE,HL          ; HL = &ptr[i], DE = &ptr[i+gap]
so_i:   PUSH BC
        PUSH HL
        PUSH DE
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        EX DE,HL          ; DE = rec i
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A            ; HL = rec j
        LD B,12
so_c:   LD A,(DE)
        LD C,A
        LD A,(HL)
        CP C
        JR NZ,so_d
        INC HL
        INC DE
        DJNZ so_c
        OR A
so_d:   POP DE
        POP HL
        JR NC,so_ns
        LD A,(DE)
        LD C,(HL)
        LD (HL),A
        LD A,C
        LD (DE),A
        INC HL
        INC DE
        LD A,(DE)
        LD C,(HL)
        LD (HL),A
        LD A,C
        LD (DE),A
        DEC HL
        DEC DE
        LD A,1
        LD (swapped),A
so_ns:  INC HL
        INC HL
        INC DE
        INC DE
        POP BC
        DJNZ so_i
        LD A,(gap)
        CP 1
        JR NZ,so_pass
        LD A,(swapped)
        OR A
        JR NZ,so_pass
        RET

recptr: PUSH BC           ; A = index -> HL = record
        LD L,A
        LD H,0
        ADD HL,HL
        LD BC,PTR
        ADD HL,BC
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        POP BC
        RET

isvz:   PUSH HL           ; Z if extension is VZ
        PUSH BC
        LD BC,9
        ADD HL,BC
        LD A,(HL)
        CP 'V'
        JR NZ,iv_x
        INC HL
        LD A,(HL)
        CP 'Z'
        JR NZ,iv_x
        INC HL
        LD A,(HL)
        CP ' '
iv_x:   POP BC
        POP HL
        RET

; ---------------------------------------------------------------- drawing
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
clrrow: PUSH DE
        LD B,32
        LD A,0x20
cr_l:   LD (DE),A
        INC DE
        DJNZ cr_l
        POP DE
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
pr2:    PUSH HL           ; A = 0..99 as two digits
        LD H,0xFF
p2_l:   INC H
        SUB 10
        JR NC,p2_l
        ADD A,10
        LD L,A
        LD A,H
        ADD A,'0'
        CALL putc
        LD A,L
        ADD A,'0'
        CALL putc
        POP HL
        RET
pr5:    LD HL,pow10       ; numv (24 bit) as 5 digits, leading blanks
        LD B,5
        XOR A
        LD (lz),A
p5_d:   PUSH BC
        LD B,0xFF
p5_c:   INC B
        CALL p5_sub
        JR NC,p5_c
        CALL p5_add
        LD A,B
        POP BC
        OR A
        JR NZ,p5_nz
        LD A,(lz)
        OR A
        JR NZ,p5_z
        LD A,B
        CP 1
        JR Z,p5_z
        LD A,' '
        JR p5_o
p5_z:   XOR A
p5_nz:  PUSH AF
        LD A,1
        LD (lz),A
        POP AF
        ADD A,'0'
p5_o:   CALL putc
        INC HL
        INC HL
        INC HL
        DJNZ p5_d
        RET
p5_sub: PUSH DE
        LD DE,numv
        LD A,(DE)
        SUB (HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(DE)
        SBC A,(HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(DE)
        SBC A,(HL)
        LD (DE),A
        DEC HL
        DEC HL
        POP DE
        RET
p5_add: PUSH DE
        LD DE,numv
        LD A,(DE)
        ADD A,(HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(DE)
        ADC A,(HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(DE)
        ADC A,(HL)
        LD (DE),A
        DEC HL
        DEC HL
        POP DE
        RET
pow10:  DB 0x10,0x27,0, 0xE8,0x03,0, 100,0,0, 10,0,0, 1,0,0

icon:   PUSH HL           ; HL = record -> A = coloured block for its type
        PUSH DE
        LD DE,12
        ADD HL,DE
        LD A,(HL)
        AND 0x10
        JR Z,ic_f
        LD A,0x9F         ; folder: yellow
        JR ic_x
ic_f:   DEC HL
        DEC HL
        DEC HL
        LD A,(HL)
        INC HL
        CP 'V'
        JR NZ,ic_1
        LD A,(HL)
        CP 'Z'
        JR NZ,ic_o
        LD A,0xBF         ; VZ program: red
        JR ic_x
ic_1:   CP 'D'
        JR NZ,ic_2
        LD A,(HL)
        CP 'A'
        JR NZ,ic_o
        LD A,0xDF         ; DAT: cyan
        JR ic_x
ic_2:   CP 'M'
        JR NZ,ic_o
        LD A,(HL)
        CP 'O'
        JR Z,ic_m
        CP 'I'
        JR NZ,ic_o
ic_m:   LD A,0xEF         ; MOD / MID: magenta
        JR ic_x
ic_o:   POP DE
        POP HL
        PUSH HL
        PUSH DE
        PUSH BC
        CALL plugfind
        POP BC
        LD A,0xEF         ; something a plug-in plays: magenta
        JR Z,ic_x
        LD A,0xCF         ; anything else: buff
ic_x:   POP DE
        POP HL
        RET

drawrow: LD C,0           ; A = index, DE = row start; leaves DE at next row
        LD HL,cur
        CP (HL)
        JR NZ,dr_1
        LD C,0x40
dr_1:   CALL recptr
        CALL icon
        LD (DE),A
        INC DE
        INC HL
        LD A,' '
        CALL putc
        LD B,8
        CALL putn
        LD A,' '
        CALL putc
        LD B,3
        CALL putn         ; HL = rec+12 (attr)
        LD A,' '
        CALL putc
        LD A,(HL)
        AND 0x10
        JR Z,dr_file
        PUSH HL
        LD HL,s_dir
        CALL puts
        POP HL
        JR dr_date
dr_file: PUSH HL
        INC HL
        INC HL
        INC HL
        INC HL
        INC HL            ; rec+16 = size
        PUSH DE
        LD DE,numv
        LD A,(HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(HL)
        LD (DE),A
        INC HL
        INC DE
        LD A,(HL)
        LD (DE),A
        INC HL
        POP DE
        LD A,(HL)
        OR A
        JR Z,dr_s1
        LD HL,s_huge
        CALL puts
        JR dr_sd
dr_s1:  LD A,(numv+2)
        CP 2
        JR NC,dr_k
        OR A
        JR Z,dr_b
        LD HL,(numv)
        PUSH DE
        LD DE,0x86A0
        OR A
        SBC HL,DE
        POP DE
        JR NC,dr_k
dr_b:   LD A,' '
        CALL putc
        CALL pr5
        JR dr_sd
dr_k:   LD HL,(numv+1)
        SRL H
        RR L
        SRL H
        RR L
        LD (numv),HL
        XOR A
        LD (numv+2),A
        CALL pr5
        LD A,'K'
        CALL putc
dr_sd:  POP HL
dr_date: LD A,' '
        CALL putc
        PUSH BC
        LD BC,9
        ADD HL,BC
        POP BC
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A            ; HL = FAT date
        OR H
        JR NZ,dr_d1
        LD B,8
dr_d0:  LD A,' '
        CALL putc
        DJNZ dr_d0
        JR dr_t
dr_d1:  LD A,L
        AND 0x1F
        CALL pr2
        LD A,'-'
        CALL putc
        LD A,L
        RLCA
        RLCA
        RLCA
        AND 7
        LD B,A
        LD A,H
        AND 1
        RLCA
        RLCA
        RLCA
        OR B
        CALL pr2
        LD A,'-'
        CALL putc
        LD A,H
        SRL A
        ADD A,80
        CP 100
        JR C,dr_y
        SUB 100
dr_y:   CALL pr2
dr_t:   LD A,' '
        CALL putc
        LD A,' '
        JP putc

drawlist: LD DE,VRAM+64
        LD A,(top)
        LD B,LROWS
dl_l:   PUSH BC
        PUSH AF
        LD HL,count
        CP (HL)
        JR NC,dl_b
        CALL drawrow
        JR dl_n
dl_b:   CALL clrrow
        LD HL,32
        ADD HL,DE
        EX DE,HL
dl_n:   POP AF
        INC A
        POP BC
        DJNZ dl_l
        RET

drawpath: LD DE,VRAM+32
        CALL clrrow
        PUSH DE
        LD A,(pathlen)
        CP 25
        JR C,dp_1
        SUB 24
        LD L,A
        LD H,0
        LD BC,path
        ADD HL,BC
        LD B,24
        JR dp_2
dp_1:   LD HL,path
        LD B,A
dp_2:   LD C,0
        CALL putn
        POP HL
        LD DE,25
        ADD HL,DE
        EX DE,HL
        LD A,(count)
        OR A
        RET Z
        LD A,(cur)
        INC A
        CALL pr3
        LD A,'/'
        CALL putc
        LD A,(count)
pr3:    LD L,0            ; A = 0..255 as three digits, leading blanks
        LD H,100
        CALL p3_d
        LD H,10
        CALL p3_d
        ADD A,'0'
        JP putc
p3_d:   LD B,0xFF
p3_l:   INC B
        SUB H
        JR NC,p3_l
        ADD A,H
        PUSH AF
        LD A,B
        OR A
        JR NZ,p3_n
        LD A,L
        OR A
        JR NZ,p3_z
        LD A,' '
        JR p3_o
p3_z:   XOR A
p3_n:   LD L,1
        ADD A,'0'
p3_o:   CALL putc
        POP AF
        RET

drawinfo: LD DE,VRAM+14*32
        CALL clrrow
        LD C,0
        LD A,(count)
        OR A
        JR NZ,di_1
        LD HL,s_empty
        JP puts
di_1:   LD A,(cur)
        CALL recptr
        LD A,(HL)
        LD C,0
        CP 2
        JR Z,di_f
        OR A
        LD HL,s_folder
        JP NZ,puts
        LD HL,s_parent
        JP puts
di_f:   CALL isvz
        RET NZ
        PUSH DE
        LD BC,13
        ADD HL,BC
        LD DE,0xFA12
        LD BC,4
        LDIR
        POP DE
        LD HL,(0xFA12)
        LD A,H
        OR L
        LD HL,(0xFA14)
        OR H
        OR L
        RET Z
        PUSH DE
        CALL D_C2S
        CALL D_READ
        DI
        POP DE
        LD HL,0xF804
        LD B,16
        LD C,0
di_n:   LD A,(HL)
        OR A
        JR Z,di_s
        INC HL
        CP 0x60
        JR C,di_p
        SUB 0x20
        JR di_p
di_s:   LD A,' '
di_p:   CALL putc
        DJNZ di_n
        LD A,' '
        CALL putc
        LD A,(0xF815)
        CP 0xF0
        LD HL,s_basic
        JR Z,di_t
        LD HL,s_mc
di_t:   CALL puts
        LD A,(0xF817)
        CALL prhex
        LD A,(0xF816)
        JP prhex

s_title: DB "VZ-DECK 0.8    VIBED BY BPM 2026",0
s_help:  DB "RET:OPEN B:BASIC C:CLI O:OUTPUT ",0
s_dir:   DB " <DIR>",0
s_huge:  DB "  HUGE",0
s_empty: DB "EMPTY FOLDER",0
s_folder: DB "FOLDER - RETURN TO OPEN",0
s_parent: DB "BACK TO PARENT FOLDER",0
s_basic: DB "BASIC  ",0
s_mc:    DB "M/C AT ",0
s_load:  DB "LOADING ",0

