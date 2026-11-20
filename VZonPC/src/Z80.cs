// Z80 CPU core (C# 5 / .NET Framework csc). Originally written for the VZ game
// test harnesses (Override, Crownfall); used by VZonPC.
// T-state tables follow the usual documented timings.
using System;

public sealed class Z80
{
    public const int CF = 1, NF = 2, PF = 4, XF = 8, HF = 16, YF = 32, ZF = 64, SF = 128;

    public int A, F, B, C, D, E, H, L;
    public int A_, F_, B_, C_, D_, E_, H_, L_;
    public int IX, IY, SP, PC, I, R;
    public bool IFF1, IFF2, Halted;
    public int IM;
    public int EiDelay;
    public long Cyc;
    public int IntData = 0xFF;

    public Func<int, int> Rd;
    public Func<int, int> Fetch;   // opcode / operand fetches (defaults to Rd)
    public Action<int, int> Wr;
    public Func<int, int> In;
    public Action<int, int> Out;

    static readonly int[] SZP = new int[256];
    static readonly int[] SZ = new int[256];

    static readonly byte[] cyc00 = {
        4,10,7,6,4,4,7,4,4,11,7,6,4,4,7,4, 8,10,7,6,4,4,7,4,12,11,7,6,4,4,7,4,
        7,10,16,6,4,4,7,4,7,11,16,6,4,4,7,4, 7,10,13,6,11,11,10,4,7,11,13,6,4,4,7,4,
        4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4,
        4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 7,7,7,7,7,7,4,7,4,4,4,4,4,4,7,4,
        4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4,
        4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4,
        5,10,10,10,10,11,7,11,5,10,10,0,10,17,7,11, 5,10,10,11,10,11,7,11,5,4,10,11,10,0,7,11,
        5,10,10,19,10,11,7,11,5,4,10,4,10,0,7,11, 5,10,10,4,10,11,7,11,5,6,10,4,10,0,7,11 };

    static Z80()
    {
        for (int i = 0; i < 256; i++)
        {
            int s = (i & 0x80) | (i & (XF | YF)) | (i == 0 ? ZF : 0);
            int p = 0; for (int b = 0; b < 8; b++) p ^= (i >> b) & 1;
            SZ[i] = s;
            SZP[i] = s | (p == 0 ? PF : 0);
        }
    }

    public void Reset() { PC = 0; SP = 0xFFFF; A = F = 0xFF; IFF1 = IFF2 = false; IM = 0; Halted = false; I = R = 0; }

    int BC { get { return (B << 8) | C; } set { B = (value >> 8) & 255; C = value & 255; } }
    int DE { get { return (D << 8) | E; } set { D = (value >> 8) & 255; E = value & 255; } }
    int HL { get { return (H << 8) | L; } set { H = (value >> 8) & 255; L = value & 255; } }

    int rb(int a) { return Rd(a & 0xFFFF); }
    void wb(int a, int v) { Wr(a & 0xFFFF, v & 255); }
    int rw(int a) { return rb(a) | (rb(a + 1) << 8); }
    void ww(int a, int v) { wb(a, v); wb(a + 1, v >> 8); }
    int nb() { int v = (Fetch ?? Rd)(PC); PC = (PC + 1) & 0xFFFF; return v; }
    int nw() { int v = rw(PC); PC = (PC + 2) & 0xFFFF; return v; }
    void push(int v) { SP = (SP - 2) & 0xFFFF; ww(SP, v); }
    int pop() { int v = rw(SP); SP = (SP + 2) & 0xFFFF; return v; }
    void incR() { R = (R & 0x80) | ((R + 1) & 0x7F); }

    // ---- interrupts
    public bool IntLine;   // level-sensitive INT input
    public void Nmi() { Halted = false; IFF1 = false; push(PC); PC = 0x66; Cyc += 11; }

    bool TryInt()
    {
        if (!IntLine || !IFF1 || EiDelay > 0) return false;
        Halted = false; IFF1 = IFF2 = false; incR();
        if (IM == 2) { push(PC); PC = rw((I << 8) | (IntData & 0xFF)); Cyc += 19; }
        else { push(PC); PC = 0x38; Cyc += 13; }
        return true;
    }

    public void Step()
    {
        if (TryInt()) return;
        if (EiDelay > 0) EiDelay--;
        if (Halted) { Cyc += 4; incR(); return; }
        incR();
        int op = nb();
        Exec(op);
    }

    // ---- ALU
    void add8(int v, int cy)
    {
        int r = A + v + cy;
        int f = SZ[r & 255] | ((r >> 8) & CF) | ((A ^ v ^ r) & HF);
        if ((((A ^ ~v) & (A ^ r)) & 0x80) != 0) f |= PF;
        A = r & 255; F = f;
    }
    void sub8(int v, int cy, bool store)
    {
        int r = A - v - cy;
        int f = SZ[r & 255] | NF | ((r >> 8) & CF) | ((A ^ v ^ r) & HF);
        if ((((A ^ v) & (A ^ r)) & 0x80) != 0) f |= PF;
        if (store) { A = r & 255; F = f; }
        else F = (f & ~(XF | YF)) | (v & (XF | YF));
    }
    void alu(int y, int v)
    {
        switch (y)
        {
            case 0: add8(v, 0); break;
            case 1: add8(v, F & CF); break;
            case 2: sub8(v, 0, true); break;
            case 3: sub8(v, F & CF, true); break;
            case 4: A &= v; F = SZP[A] | HF; break;
            case 5: A ^= v; F = SZP[A]; break;
            case 6: A |= v; F = SZP[A]; break;
            case 7: sub8(v, 0, false); break;
        }
    }
    int inc8(int v) { int r = (v + 1) & 255; F = (F & CF) | SZ[r] | (r == 0x80 ? PF : 0) | ((r & 0xF) == 0 ? HF : 0); return r; }
    int dec8(int v) { int r = (v - 1) & 255; F = (F & CF) | SZ[r] | NF | (r == 0x7F ? PF : 0) | ((r & 0xF) == 0xF ? HF : 0); return r; }
    int add16(int a, int b)
    {
        int r = a + b;
        F = (F & (SF | ZF | PF)) | ((r >> 16) & CF) | (((a ^ b ^ r) >> 8) & HF) | ((r >> 8) & (XF | YF));
        return r & 0xFFFF;
    }
    void adc16(int v)
    {
        int a = HL; int c = F & CF; int r = a + v + c;
        int f = ((r >> 16) & CF) | (((a ^ v ^ r) >> 8) & HF) | ((r >> 8) & (SF | XF | YF));
        if ((r & 0xFFFF) == 0) f |= ZF;
        if ((((a ^ ~v) & (a ^ r)) & 0x8000) != 0) f |= PF;
        HL = r & 0xFFFF; F = f;
    }
    void sbc16(int v)
    {
        int a = HL; int c = F & CF; int r = a - v - c;
        int f = NF | ((r >> 16) & CF) | (((a ^ v ^ r) >> 8) & HF) | ((r >> 8) & (SF | XF | YF));
        if ((r & 0xFFFF) == 0) f |= ZF;
        if ((((a ^ v) & (a ^ r)) & 0x8000) != 0) f |= PF;
        HL = r & 0xFFFF; F = f;
    }
    int rot(int y, int v)
    {
        int c;
        switch (y)
        {
            case 0: c = v >> 7; v = ((v << 1) | c) & 255; break;          // RLC
            case 1: c = v & 1; v = (v >> 1) | (c << 7); break;              // RRC
            case 2: c = v >> 7; v = ((v << 1) | (F & CF)) & 255; break;     // RL
            case 3: c = v & 1; v = (v >> 1) | ((F & CF) << 7); break;       // RR
            case 4: c = v >> 7; v = (v << 1) & 255; break;                  // SLA
            case 5: c = v & 1; v = (v >> 1) | (v & 0x80); break;            // SRA
            case 6: c = v >> 7; v = ((v << 1) | 1) & 255; break;            // SLL
            default: c = v & 1; v = v >> 1; break;                          // SRL
        }
        F = SZP[v] | c;
        return v;
    }

    // ---- register access: 0..7 = B C D E H L (HL) A ; idx: 0 HL, 1 IX, 2 IY
    int idx; int disp;
    int getIdx() { return idx == 1 ? IX : IY; }
    int r8(int r)
    {
        switch (r)
        {
            case 0: return B; case 1: return C; case 2: return D; case 3: return E;
            case 4: return idx == 0 ? H : (idx == 1 ? IX >> 8 : IY >> 8);
            case 5: return idx == 0 ? L : (idx == 1 ? IX & 255 : IY & 255);
            case 6: return rb(memAddr());
            default: return A;
        }
    }
    void w8(int r, int v)
    {
        v &= 255;
        switch (r)
        {
            case 0: B = v; break; case 1: C = v; break; case 2: D = v; break; case 3: E = v; break;
            case 4: if (idx == 0) H = v; else if (idx == 1) IX = (IX & 0xFF) | (v << 8); else IY = (IY & 0xFF) | (v << 8); break;
            case 5: if (idx == 0) L = v; else if (idx == 1) IX = (IX & 0xFF00) | v; else IY = (IY & 0xFF00) | v; break;
            case 6: wb(memAddr(), v); break;
            default: A = v; break;
        }
    }
    // plain H/L (used when (IX+d) is the other operand)
    int r8p(int r) { if (r == 4) return H; if (r == 5) return L; return r8(r); }
    void w8p(int r, int v) { if (r == 4) H = v & 255; else if (r == 5) L = v & 255; else w8(r, v); }
    int memAddr() { return idx == 0 ? HL : ((getIdx() + disp) & 0xFFFF); }
    void fetchDisp() { if (idx != 0) { int d = nb(); disp = d < 128 ? d : d - 256; } }

    int rp(int p) { switch (p) { case 0: return BC; case 1: return DE; case 2: return idx == 0 ? HL : getIdx(); default: return SP; } }
    void wrp(int p, int v)
    {
        v &= 0xFFFF;
        switch (p) { case 0: BC = v; break; case 1: DE = v; break; case 2: if (idx == 0) HL = v; else if (idx == 1) IX = v; else IY = v; break; default: SP = v; break; }
    }
    int rp2(int p) { if (p == 3) return (A << 8) | F; return rp(p); }
    void wrp2(int p, int v) { if (p == 3) { A = (v >> 8) & 255; F = v & 255; } else wrp(p, v); }
    bool cc(int y)
    {
        switch (y)
        {
            case 0: return (F & ZF) == 0; case 1: return (F & ZF) != 0;
            case 2: return (F & CF) == 0; case 3: return (F & CF) != 0;
            case 4: return (F & PF) == 0; case 5: return (F & PF) != 0;
            case 6: return (F & SF) == 0; default: return (F & SF) != 0;
        }
    }

    void Exec(int op)
    {
        idx = 0;
        Cyc += cyc00[op];
        if (op == 0xDD || op == 0xFD)
        {
            // chain of prefixes: last one wins
            int pre = op;
            Cyc += 4;
            while (true)
            {
                incR();
                op = nb();
                if (op == 0xDD || op == 0xFD) { Cyc += 4; pre = op; continue; }
                break;
            }
            idx = pre == 0xDD ? 1 : 2;
            if (op == 0xCB) { ExecIdxCB(); return; }
            if (op == 0xED) { idx = 0; incR(); Cyc += 0; ExecED(nb()); return; }
            Cyc += cyc00[op];
            ExecMain(op, true);
            idx = 0;
            return;
        }
        if (op == 0xCB) { incR(); ExecCB(nb()); return; }
        if (op == 0xED) { incR(); ExecED(nb()); return; }
        ExecMain(op, false);
    }

    void ExecMain(int op, bool pref)
    {
        int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
        switch (x)
        {
            case 0:
                switch (z)
                {
                    case 0:
                        switch (y)
                        {
                            case 0: break; // NOP
                            case 1: { int t; t = A; A = A_; A_ = t; t = F; F = F_; F_ = t; } break;
                            case 2: { int d = nb(); B = (B - 1) & 255; if (B != 0) { PC = (PC + (d < 128 ? d : d - 256)) & 0xFFFF; Cyc += 5; } } break;
                            case 3: { int d = nb(); PC = (PC + (d < 128 ? d : d - 256)) & 0xFFFF; } break;
                            default: { int d = nb(); if (cc(y - 4)) { PC = (PC + (d < 128 ? d : d - 256)) & 0xFFFF; Cyc += 5; } } break;
                        }
                        break;
                    case 1:
                        if (q == 0) wrp(p, nw());
                        else wrp(2, add16(rp(2), rp(p)));
                        break;
                    case 2:
                        switch (y)
                        {
                            case 0: wb(BC, A); break;
                            case 1: A = rb(BC); break;
                            case 2: wb(DE, A); break;
                            case 3: A = rb(DE); break;
                            case 4: ww(nw(), rp(2)); break;
                            case 5: wrp(2, rw(nw())); break;
                            case 6: wb(nw(), A); break;
                            default: A = rb(nw()); break;
                        }
                        break;
                    case 3:
                        if (q == 0) wrp(p, rp(p) + 1); else wrp(p, rp(p) - 1);
                        break;
                    case 4:
                        if (y == 6) { fetchDisp(); if (pref) Cyc += 8; int a = memAddr(); wb(a, inc8(rb(a))); }
                        else w8(y, inc8(r8(y)));
                        break;
                    case 5:
                        if (y == 6) { fetchDisp(); if (pref) Cyc += 8; int a = memAddr(); wb(a, dec8(rb(a))); }
                        else w8(y, dec8(r8(y)));
                        break;
                    case 6:
                        if (y == 6) { fetchDisp(); if (pref) Cyc += 5; int a = memAddr(); wb(a, nb()); }
                        else w8(y, nb());
                        break;
                    case 7:
                        switch (y)
                        {
                            case 0: { int c = A >> 7; A = ((A << 1) | c) & 255; F = (F & (SF | ZF | PF)) | (A & (XF | YF)) | c; } break;
                            case 1: { int c = A & 1; A = (A >> 1) | (c << 7); F = (F & (SF | ZF | PF)) | (A & (XF | YF)) | c; } break;
                            case 2: { int c = A >> 7; A = ((A << 1) | (F & CF)) & 255; F = (F & (SF | ZF | PF)) | (A & (XF | YF)) | c; } break;
                            case 3: { int c = A & 1; A = (A >> 1) | ((F & CF) << 7); F = (F & (SF | ZF | PF)) | (A & (XF | YF)) | c; } break;
                            case 4: daa(); break;
                            case 5: A ^= 255; F = (F & (SF | ZF | PF | CF)) | HF | NF | (A & (XF | YF)); break;
                            case 6: F = (F & (SF | ZF | PF)) | CF | (A & (XF | YF)); break;
                            default: { int c = F & CF; F = (F & (SF | ZF | PF)) | (c != 0 ? HF : 0) | (c ^ 1) | (A & (XF | YF)); } break;
                        }
                        break;
                }
                break;
            case 1:
                if (op == 0x76) { Halted = true; break; }
                if (y == 6) { fetchDisp(); if (pref) Cyc += 8; wb(memAddr(), r8p(z)); }
                else if (z == 6) { fetchDisp(); if (pref) Cyc += 8; w8p(y, rb(memAddr())); }
                else w8(y, r8(z));
                break;
            case 2:
                if (z == 6) { fetchDisp(); if (pref) Cyc += 8; alu(y, rb(memAddr())); }
                else alu(y, r8(z));
                break;
            default:
                switch (z)
                {
                    case 0: if (cc(y)) { PC = pop(); Cyc += 6; } break;
                    case 1:
                        if (q == 0) wrp2(p, pop());
                        else switch (p)
                            {
                                case 0: PC = pop(); break;
                                case 1: { int t; t = B; B = B_; B_ = t; t = C; C = C_; C_ = t; t = D; D = D_; D_ = t; t = E; E = E_; E_ = t; t = H; H = H_; H_ = t; t = L; L = L_; L_ = t; } break;
                                case 2: PC = rp(2); break;
                                default: SP = rp(2); break;
                            }
                        break;
                    case 2: { int a = nw(); if (cc(y)) PC = a; } break;
                    case 3:
                        switch (y)
                        {
                            case 0: PC = nw(); break;
                            case 2: Out((A << 8) | nb(), A); break;
                            case 3: A = In((A << 8) | nb()); break;
                            case 4: { int v = rw(SP); ww(SP, rp(2)); wrp(2, v); } break;
                            case 5: { int t = DE; DE = HL; HL = t; } break;
                            case 6: IFF1 = IFF2 = false; break;
                            case 7: IFF1 = IFF2 = true; EiDelay = 1; break;
                        }
                        break;
                    case 4: { int a = nw(); if (cc(y)) { push(PC); PC = a; Cyc += 7; } } break;
                    case 5:
                        if (q == 0) push(rp2(p));
                        else if (p == 0) { int a = nw(); push(PC); PC = a; }
                        break;
                    case 6: alu(y, nb()); break;
                    default: push(PC); PC = y * 8; break;
                }
                break;
        }
    }

    void daa()
    {
        int a = A, cor = 0, c = F & CF;
        if ((F & HF) != 0 || (a & 0xF) > 9) cor |= 6;
        if (c != 0 || a > 0x99) { cor |= 0x60; c = 1; }
        int r;
        if ((F & NF) != 0) r = (a - cor) & 255; else r = (a + cor) & 255;
        int h = ((a ^ r) & HF);
        A = r; F = SZP[r] | (F & NF) | c | h;
    }

    void ExecCB(int op)
    {
        int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
        Cyc += (z == 6) ? (x == 1 ? 12 : 15) : 8;
        int v = r8(z);
        switch (x)
        {
            case 0: w8(z, rot(y, v)); break;
            case 1: { int r = v & (1 << y); F = (F & CF) | HF | (r == 0 ? (ZF | PF) : 0) | (r & SF) | (v & (XF | YF)); } break;
            case 2: w8(z, v & ~(1 << y)); break;
            default: w8(z, v | (1 << y)); break;
        }
    }

    void ExecIdxCB()
    {
        int d = nb(); disp = d < 128 ? d : d - 256;
        int op = nb();
        int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
        int a = (getIdx() + disp) & 0xFFFF;
        int v = rb(a);
        Cyc += (x == 1 ? 16 : 19);   // + 4 for the prefix already counted = 20 / 23
        int r;
        switch (x)
        {
            case 0: r = rot(y, v); wb(a, r); if (z != 6) { int sv = idx; idx = 0; w8(z, r); idx = sv; } break;
            case 1: { int t = v & (1 << y); F = (F & CF) | HF | (t == 0 ? (ZF | PF) : 0) | (t & SF) | ((a >> 8) & (XF | YF)); } break;
            case 2: r = v & ~(1 << y); wb(a, r); if (z != 6) { int sv = idx; idx = 0; w8(z, r); idx = sv; } break;
            default: r = v | (1 << y); wb(a, r); if (z != 6) { int sv = idx; idx = 0; w8(z, r); idx = sv; } break;
        }
        idx = 0;
    }

    void ExecED(int op)
    {
        idx = 0;
        int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
        if (x == 1)
        {
            switch (z)
            {
                case 0: { int v = In(BC); if (y != 6) w8(y, v); F = (F & CF) | SZP[v]; Cyc += 12; } break;
                case 1: Out(BC, y == 6 ? 0 : r8(y)); Cyc += 12; break;
                case 2: if (q == 0) sbc16(rp(p)); else adc16(rp(p)); Cyc += 15; break;
                case 3: { int a = nw(); if (q == 0) ww(a, rp(p)); else wrp(p, rw(a)); Cyc += 20; } break;
                case 4: { int v = A; A = 0; sub8(v, 0, true); Cyc += 8; } break;
                case 5: PC = pop(); IFF1 = IFF2; Cyc += 14; break;
                case 6: IM = (y & 3) == 0 || (y & 3) == 1 ? 0 : ((y & 3) == 2 ? 1 : 2); Cyc += 8; break;
                default:
                    switch (y)
                    {
                        case 0: I = A; Cyc += 9; break;
                        case 1: R = A; Cyc += 9; break;
                        case 2: A = I; F = (F & CF) | SZ[A] | (IFF2 ? PF : 0); Cyc += 9; break;
                        case 3: A = R; F = (F & CF) | SZ[A] | (IFF2 ? PF : 0); Cyc += 9; break;
                        case 4: { int m = rb(HL); wb(HL, (A << 4) | (m >> 4)); A = (A & 0xF0) | (m & 0xF); F = (F & CF) | SZP[A]; Cyc += 18; } break;
                        case 5: { int m = rb(HL); wb(HL, (m << 4) | (A & 0xF)); A = (A & 0xF0) | (m >> 4); F = (F & CF) | SZP[A]; Cyc += 18; } break;
                        default: Cyc += 8; break;
                    }
                    break;
            }
            return;
        }
        if (x == 2 && z <= 3 && y >= 4)
        {
            bool inc = (y & 1) == 0, rep = y >= 6;
            int dlt = inc ? 1 : -1;
            Cyc += 16;
            switch (z)
            {
                case 0: // LDI/LDD
                    {
                        int v = rb(HL); wb(DE, v);
                        HL = (HL + dlt) & 0xFFFF; DE = (DE + dlt) & 0xFFFF; BC = (BC - 1) & 0xFFFF;
                        int n = (v + A) & 255;
                        F = (F & (SF | ZF | CF)) | (BC != 0 ? PF : 0) | (n & XF) | ((n << 4) & YF);
                        if (rep && BC != 0) { PC = (PC - 2) & 0xFFFF; Cyc += 5; }
                    }
                    break;
                case 1: // CPI/CPD
                    {
                        int v = rb(HL); int r = (A - v) & 255;
                        int h = (A ^ v ^ r) & HF;
                        HL = (HL + dlt) & 0xFFFF; BC = (BC - 1) & 0xFFFF;
                        F = (F & CF) | SZ[r] & ~(XF | YF) | NF | h | (BC != 0 ? PF : 0);
                        if (rep && BC != 0 && r != 0) { PC = (PC - 2) & 0xFFFF; Cyc += 5; }
                    }
                    break;
                case 2: // INI/IND
                    {
                        int v = In(BC); wb(HL, v); HL = (HL + dlt) & 0xFFFF; B = (B - 1) & 255;
                        F = SZ[B] | NF; if (rep && B != 0) { PC = (PC - 2) & 0xFFFF; Cyc += 5; }
                    }
                    break;
                default: // OUTI/OUTD
                    {
                        int v = rb(HL); B = (B - 1) & 255; Out(BC, v); HL = (HL + dlt) & 0xFFFF;
                        F = SZ[B] | NF; if (rep && B != 0) { PC = (PC - 2) & 0xFFFF; Cyc += 5; }
                    }
                    break;
            }
            return;
        }
        Cyc += 8; // NONI
    }
}
