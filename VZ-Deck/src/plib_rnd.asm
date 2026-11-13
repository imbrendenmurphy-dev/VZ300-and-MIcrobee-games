; ================================================================ random access to the music file
D_NCLUS EQU 0x49F8
; list the file's clusters (up to MAXCLT)
mkclt:  LD HL,0xFFFF
        LD (cursec),HL
        LD HL,HO+3
        LD DE,0xFA12
        LD BC,4
        LDIR
        LD HL,0xF800
        LD (0xFB80),HL
        LD HL,clt
        LD (clp),HL
        XOR A
        LD (nclt),A
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
        CP MAXCLT
        RET Z
        CALL D_NCLUS
        DI
        LD A,(0xFA3C)
        OR A
        JR NZ,mk_c
        RET
; read sector HL of the file into F800; carry set if it is past the end
rdsec:  LD A,H
        CP 0xFF
        JR NZ,rs_0
        LD A,L
        CP 0xFF
        JR NZ,rs_0
        SCF               ; HL = FFFF: never valid
        RET
rs_0:   LD DE,(cursec)
        LD A,E
        CP L
        JR NZ,rs_1
        LD A,D
        CP H
        RET Z             ; already there (carry clear)
rs_1:   LD (cursec),HL
        LD A,(0xFA20)
        LD B,A
        DEC A
        AND L
        LD (rf_off),A
rs_s:   SRL B
        JR Z,rs_2
        SRL H
        RR L
        JR rs_s
rs_2:   LD A,H
        OR A
        JR NZ,rs_bad
        LD A,(nclt)
        LD B,A
        LD A,L
        CP B
        JR NC,rs_bad
        ADD HL,HL
        ADD HL,HL
        LD DE,clt
        ADD HL,DE
        LD DE,0xFA12
        LD BC,4
        LDIR
        LD HL,0xF800
        LD (0xFB80),HL
        CALL D_C2S
        LD A,(rf_off)
        LD HL,0xFA26
        ADD A,(HL)
        LD (HL),A
        JR NC,rs_3
rs_c:   INC HL
        INC (HL)
        JR Z,rs_c
rs_3:   CALL D_READ
        DI
        OR A
        RET
rs_bad: LD HL,0xFFFF
        LD (cursec),HL
        SCF
        RET
; copy BC bytes from file offset foff (3 bytes) to DE; past the end reads zeros
fread:  LD (fdst),DE
fr_l:   LD A,B
        OR C
        RET Z
        PUSH BC
        LD A,(foff+2)
        LD H,A
        LD A,(foff+1)
        LD L,A
        SRL H
        RR L              ; sector
        CALL rdsec
        POP BC
        JR NC,fr_ok
        LD HL,(fdst)      ; past the end: zeros
fr_z:   LD (HL),0
        INC HL
        DEC BC
        LD A,B
        OR C
        JR NZ,fr_z
        RET
fr_ok:  LD A,(foff+1)
        AND 1
        LD H,A
        LD A,(foff)
        LD L,A            ; offset in sector
        PUSH HL
        EX DE,HL
        LD HL,512
        OR A
        SBC HL,DE         ; bytes left in this sector
        PUSH HL
        OR A
        SBC HL,BC
        POP HL
        JR C,fr_1
        LD H,B            ; fits: take all
        LD L,C
fr_1:   PUSH HL           ; n
        LD A,C
        SUB L
        LD C,A
        LD A,B
        SBC A,H
        LD B,A            ; BC = remaining after this
        POP HL
        POP DE            ; DE = offset in sector
        PUSH BC
        LD B,H
        LD C,L            ; BC = n
        LD HL,(foff)      ; foff += n
        ADD HL,BC
        LD (foff),HL
        JR NC,fr_2
        LD HL,foff+2
        INC (HL)
fr_2:   LD HL,0xF800
        ADD HL,DE
        LD DE,(fdst)
        LDIR
        LD (fdst),DE
        POP BC
        JR fr_l
