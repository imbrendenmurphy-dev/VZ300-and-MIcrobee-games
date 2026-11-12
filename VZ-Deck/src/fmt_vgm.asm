; ================================================================ VGM (SN76489 / SN76496 parts only)
fmt_init: CALL mkclt
        XOR A
        LD H,A
        LD L,A
        LD (foff),HL
        LD (foff+2),A
        LD DE,hdr
        LD BC,0x40
        CALL fread
        LD HL,hdr
        LD DE,s_vgm
        LD B,4
vn_c:   LD A,(DE)
        CP (HL)
        JR NZ,vn_bad
        INC HL
        INC DE
        DJNZ vn_c
        ; SN76489 clock (bits 30-31 are flags)
        LD A,(hdr+0x0F)
        AND 0x3F
        LD B,A
        LD HL,(hdr+0x0D)  ; clock / 256
        LD A,B
        OR A
        JR Z,vn_k
        LD HL,0xFFFF
vn_k:   LD A,H
        OR L
        JR NZ,vn_k2
        LD HL,s_nosn
        OR 1
        RET
vn_bad: LD A,(hdr)
        CP 0x1F           ; gzip: a .VGZ renamed
        LD HL,s_gz
        JR Z,vn_b2
        LD HL,s_notvgm
vn_b2:  OR 1
        RET
vn_k2:  LD (sclk),HL
        LD B,H            ; period scale = 2 * AY clock * 256 / clock
        LD C,L
        LD L,0x36
        LD DE,0x1EB0
        CALL div24
        LD (kscale),DE
        ; where the data starts
        LD HL,0x40
        XOR A
        LD (spos+2),A
        LD A,(hdr+0x09)   ; version >= 1.50: offset at 0x34
        CP 1
        JR C,vn_d
        JR NZ,vn_d1
        LD A,(hdr+0x08)
        CP 0x50
        JR C,vn_d
vn_d1:  LD HL,(hdr+0x34)
        LD A,H
        OR L
        JR Z,vn_d0
        LD DE,0x34
        ADD HL,DE
        LD A,(hdr+0x36)
        ADC A,0
        LD (spos+2),A
        JR vn_d
vn_d0:  LD HL,0x40
vn_d:   LD (spos),HL
        ; title from the GD3 tag, if there is one
        LD HL,(hdr+0x14)
        LD A,(hdr+0x16)
        LD B,A
        LD A,H
        OR L
        OR B
        JR Z,vn_t
        LD DE,0x14+12     ; skip "Gd3 ", version, length
        ADD HL,DE
        LD A,B
        ADC A,0
        LD (foff),HL
        LD (foff+2),A
        LD DE,gd3
        LD BC,256
        CALL fread
vn_t:   LD A,0x0F         ; all channels silent
        LD (att),A
        LD (att+1),A
        LD (att+2),A
        LD (att+3),A
        XOR A
        RET

; ---- next byte of the music data
vgetb:  PUSH HL
        PUSH DE
        PUSH BC
        LD A,(spos+2)
        LD H,A
        LD A,(spos+1)
        LD L,A
        SRL H
        RR L
        CALL rdsec
        JR NC,vg_1
        LD A,1
        LD (mend),A
        LD A,0x66
        JR vg_x
vg_1:   LD A,(spos+1)
        AND 1
        LD H,A
        LD A,(spos)
        LD L,A
        LD DE,0xF800
        ADD HL,DE
        LD A,(HL)
        LD HL,(spos)
        INC HL
        LD (spos),HL
        LD B,A
        LD A,H
        OR L
        LD A,B
        JR NZ,vg_x
        LD HL,spos+2
        INC (HL)
vg_x:   POP BC
        POP DE
        POP HL
        RET
vskip:  LD HL,(spos)      ; skip DE bytes (A = high byte of the count)
        ADD HL,DE
        LD (spos),HL
        LD HL,spos+2
        ADC A,(HL)
        LD (HL),A
        RET

; ---- one 50 Hz field: 882 samples at 44.1 kHz
fmt_tick: LD HL,(wait)
        LD A,(wait+2)
        LD B,A
        LD DE,882
        OR A
        SBC HL,DE
        LD A,B
        SBC A,0
        JR C,vt_run       ; less than a field left to wait
        LD (wait),HL
        LD (wait+2),A
        JP vt_out
vt_run: ; HL:A = wait - 882 < 0 : the rest of this field is -(that)
        LD (wait),HL
        LD (wait+2),A
vt_l:   LD A,(mend)
        OR A
        JP NZ,vt_end
        CALL vgetb
        CP 0x50
        JR Z,v_psg
        CP 0x61
        JR Z,v_w16
        CP 0x62
        JP Z,v_w735
        CP 0x63
        JP Z,v_w882
        CP 0x66
        JP Z,vt_end
        CP 0x67
        JP Z,v_blk
        CP 0x68
        LD C,11
        JR Z,v_sk
        LD B,A
        AND 0xF0
        CP 0x70
        JR Z,v_wn
        CP 0x80
        JR Z,v_wym
        LD A,B
        ; everything else: skip its operands
        LD HL,oplen
        CP 0x30
        JR C,vt_l         ; unknown single byte
        CP 0x60
        JR C,v_lo
        CP 0x70
        JR C,vt_l
v_lo:
        CP 0x40
        LD C,1
        JR C,v_sk
        CP 0x4F
        JR Z,v_sk
        CP 0x50
        LD C,2
        JR C,v_sk
        CP 0x90
        JR C,v_sk         ; 0x51-0x5F
        CP 0xA0
        JR NC,v_hi
        SUB 0x90          ; DAC stream commands
        CP 6
        JR NC,vt_l
        LD E,A
        LD D,0
        ADD HL,DE
        LD C,(HL)
        JR v_sk
v_hi:   LD C,2
        CP 0xC0
        JR C,v_sk
        LD C,3
        CP 0xE0
        JR C,v_sk
        LD C,4
v_sk:   LD E,C
        LD D,0
        XOR A
        CALL vskip
        JP vt_l
v_psg:  CALL vgetb
        CALL snwrite
        JP vt_l
v_w16:  CALL vgetb
        LD E,A
        CALL vgetb
        LD D,A
        JR v_wadd
v_w735: LD DE,735
        JR v_wadd
v_w882: LD DE,882
        JR v_wadd
v_wym:  LD A,B            ; YM2612 sample + wait n
        AND 15
        LD E,A
        LD D,0
        JR v_wadd
v_wn:   LD A,B
        AND 15
        INC A
        LD E,A
        LD D,0
v_wadd: LD HL,(wait)
        LD A,(wait+2)
        ADD HL,DE
        ADC A,0
        LD (wait),HL
        LD (wait+2),A
        BIT 7,A
        JP NZ,vt_l        ; still behind: keep reading
        LD A,H
        OR L
        JP Z,vt_l
        JR vt_out
v_blk:  CALL vgetb        ; 0x66
        CALL vgetb        ; type
        CALL vgetb
        LD E,A
        CALL vgetb
        LD D,A
        CALL vgetb
        LD B,A
        CALL vgetb        ; top byte ignored (blocks over 16MB)
        LD A,B
        CALL vskip
        JP vt_l
vt_end: OR 1
        RET
; ---- this field's sound
vt_out: LD HL,sfrac
        INC (HL)
        LD A,(HL)
        CP 50
        JR C,vt_o1
        LD (HL),0
        LD HL,ssec
        INC (HL)
        LD A,(HL)
        CP 60
        JR C,vt_o1
        LD (HL),0
        LD HL,smin
        INC (HL)
vt_o1:  LD A,(chg)
        OR A
        CALL NZ,snout
        XOR A
        RET

; ---- a byte for the SN76489
snwrite: BIT 7,A
        JR Z,sn_data
        LD B,A
        RRCA
        RRCA
        RRCA
        RRCA
        AND 7             ; channel * 2 + volume flag
        LD (latch),A
        LD A,B
        AND 0x0F
        LD C,A
        LD A,(latch)
        BIT 0,A
        JR Z,sn_tl
        ; volume (attenuation)
        SRL A
        LD E,A
        LD D,0
        LD HL,att
        ADD HL,DE
        LD (HL),C
        JR sn_c
sn_tl:  SRL A             ; tone / noise: low 4 bits
        CP 3
        JR Z,sn_nz
        ADD A,A
        LD E,A
        LD D,0
        LD HL,per
        ADD HL,DE
        LD A,(HL)
        AND 0xF0
        OR C
        LD (HL),A
        JR sn_c
sn_nz:  LD A,C
        LD (nctl),A
        JR sn_c
sn_data: LD C,A           ; data byte: top 6 bits of the latched tone
        LD A,(latch)
        BIT 0,A
        JR NZ,sn_dv
        SRL A
        CP 3
        JR Z,sn_c
        ADD A,A
        LD E,A
        LD D,0
        LD HL,per
        ADD HL,DE         ; period = (data & 63) << 4 | low nibble
        LD A,C
        AND 0x3F
        LD B,A
        RLCA
        RLCA
        RLCA
        RLCA
        AND 0xF0
        LD C,A
        LD A,(HL)
        AND 0x0F
        OR C
        LD (HL),A
        INC HL
        LD A,B
        RRCA
        RRCA
        RRCA
        RRCA
        AND 0x03
        LD (HL),A
        JR sn_c
sn_dv:  SRL A             ; data byte after a volume latch: new volume
        LD E,A
        LD D,0
        LD HL,att
        ADD HL,DE
        LD A,C
        AND 0x0F
        LD (HL),A
sn_c:   LD A,1
        LD (chg),A
        RET

; ---- registers -> the three voices
snout:  XOR A
        LD (chg),A
        LD (pk),A
so_l:   LD A,(pk)
        LD E,A
        LD D,0
        LD IY,vper
        ADD IY,DE
        ADD IY,DE
        LD HL,per
        ADD HL,DE
        ADD HL,DE
        LD C,(HL)
        INC HL
        LD B,(HL)         ; BC = SN period (10 bits)
        LD HL,att
        ADD HL,DE
        LD A,15
        SUB (HL)
        LD (IY+6),A
        LD (IY+12),1
        OR A
        JR NZ,so_1
        LD (IY+12),0
so_1:   ; AY period = SN period * scale / 256
        PUSH DE
        LD DE,(kscale)
        CALL mul16        ; HL:A? -> HL = BC * DE >> 8
        POP DE
        LD (IY+0),L
        LD (IY+1),H
        LD A,L
        CP (IY+24)
        JR NZ,so_q
        LD A,H
        CP (IY+25)
        JR Z,so_q2
so_q:   PUSH DE
        CALL per2note
        POP DE
        LD HL,vnote
        ADD HL,DE
        LD (HL),A
so_q2:  LD HL,pk
        INC (HL)
        LD A,(HL)
        CP 3
        JR C,so_l
        ; noise channel: a drum when it starts sounding
        LD A,(att+3)
        CP 10
        JR NC,so_off
        LD A,(nctl)
        BIT 2,A
        JR Z,so_off       ; periodic noise: a buzz, not a drum
        LD A,(non)
        OR A
        RET NZ
        LD A,1
        LD (non),A
        LD A,(nctl)
        AND 3
        LD B,1            ; fastest noise: hat
        JR Z,so_d
        LD B,2
so_d:   LD A,(dreq)
        CP B
        RET NC
        LD A,B
        LD (dreq),A
        JP showdrum
so_off: XOR A
        LD (non),A
        RET
mul16:  LD HL,0           ; HL = BC * DE / 256
        LD A,E
        LD E,8
mu_l:   RRA
        JR NC,mu_n
        ADD HL,BC
mu_n:   SRL H
        RR L
        DEC E
        JR NZ,mu_l
        LD A,D
        OR A
        RET Z
mu_d:   ADD HL,BC
        DEC A
        JR NZ,mu_d
        RET

; AY period HL -> nearest note 0-95
per2note: LD A,H
        OR L
        LD A,0xFF
        RET Z
        LD (p2t),HL
        LD B,0
        LD C,96
p2_l:   LD A,B
        CP C
        RET NC
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
        JR C,p2_hi
        LD C,A
        JR p2_l
p2_hi:  INC A
        LD B,A
        JR p2_l

fmt_title: LD DE,VRAM+3*32
        LD HL,gd3
        CALL utext
ft_j:   LD A,(HL)
        INC HL
        INC HL
        OR A
        JR NZ,ft_j
        LD DE,VRAM+4*32
utext:  LD B,32           ; UTF-16 text -> ASCII, up to its zero
        LD C,0
ut_l:   LD A,(HL)
        INC HL
        INC HL
        OR A
        RET Z
        CP 0x60
        JR C,ut_1
        SUB 0x20
ut_1:   CP 0x20
        JR NC,ut_2
        LD A,'?'
ut_2:   PUSH HL
        CALL putc
        POP HL
        DJNZ ut_l
ut_s:   LD A,(HL)         ; run on to the end of the string
        INC HL
        INC HL
        OR A
        JR NZ,ut_s
        RET
fmt_status: LD HL,s_time
        CALL puts
        LD A,(smin)
        CALL prhex
        LD A,':'
        CALL putc
        LD A,(ssec)
        LD B,0
fs_d:   CP 10
        JR C,fs_e
        SUB 10
        INC B
        JR fs_d
fs_e:   LD C,A
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
; ---- view 3: the SN76489 registers
fmt_v3i: LD DE,VRAM+5*32
        LD HL,s_v3hdr
        LD C,0x40
        CALL puts
        LD DE,VRAM+7*32
        LD HL,s_tone
        LD C,0
        CALL puts
        LD DE,VRAM+9*32
        LD HL,s_vol
        JP puts
fmt_v3: LD C,0
        OR A
        JR NZ,fv_2
        LD DE,VRAM+7*32+5
        LD HL,per
        LD B,3
fv_l:   INC HL
        LD A,(HL)
        DEC HL
        CALL ph1
        LD A,(HL)
        CALL prhex
        INC HL
        INC HL
        LD A,' '
        CALL putc
        DJNZ fv_l
        RET
fv_2:   CP 1
        RET NZ
        LD DE,VRAM+9*32+5
        LD HL,att
        LD B,4
fv_v:   LD A,(HL)
        CALL ph1
        LD A,' '
        CALL putc
        INC HL
        DJNZ fv_v
        LD A,'N'
        CALL putc
        LD A,(nctl)
        JP ph1

oplen:  DB 4,4,5,10,1,4
s_vgm:  DB "Vgm "
s_fmt:  DB "VGM PLAYER",0
s_time: DB "TIME ",0
s_v3hdr: DB "SN76489 REGISTERS               ",0
s_tone: DB "TONE",0
s_vol:  DB "ATT ",0
s_notvgm: DB "NOT A VGM FILE",13,0
s_gz:   DB "COMPRESSED (VGZ): UNZIP IT ON A PC FIRST",13,0
s_nosn: DB "NO SN76489 MUSIC IN THIS VGM",13,0
