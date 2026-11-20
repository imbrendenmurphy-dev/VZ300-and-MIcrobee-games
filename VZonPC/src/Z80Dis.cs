// Z80 disassembler (documented + common undocumented opcodes) for the VZonPC visualiser.
using System;

public static class Z80Dis
{
    static readonly string[] R = { "B", "C", "D", "E", "H", "L", "(HL)", "A" };
    static readonly string[] RP = { "BC", "DE", "HL", "SP" };
    static readonly string[] RP2 = { "BC", "DE", "HL", "AF" };
    static readonly string[] CC = { "NZ", "Z", "NC", "C", "PO", "PE", "P", "M" };
    static readonly string[] ALU = { "ADD A,", "ADC A,", "SUB ", "SBC A,", "AND ", "XOR ", "OR ", "CP " };
    static readonly string[] ROT = { "RLC", "RRC", "RL", "RR", "SLA", "SRA", "SLL", "SRL" };
    static readonly string[] X0Z7 = { "RLCA", "RRCA", "RLA", "RRA", "DAA", "CPL", "SCF", "CCF" };
    static readonly string[] IMS = { "0", "0", "1", "2", "0", "0", "1", "2" };
    static readonly string[,] BLK = {
        { "LDI", "CPI", "INI", "OUTI" }, { "LDD", "CPD", "IND", "OUTD" },
        { "LDIR", "CPIR", "INIR", "OTIR" }, { "LDDR", "CPDR", "INDR", "OTDR" } };

    sealed class Ctx
    {
        public Func<int, int> Rd; public int Pc, Start; public bool Generic; public Func<int, string> Label;
        public string Idx; public int Disp; public bool HaveDisp;
        public int Byte() { int v = Rd(Pc & 0xFFFF); Pc++; return v; }
        public string N() { int v = Byte(); return Generic ? "N" : "$" + v.ToString("X2"); }
        public string NN(bool isAddr)
        {
            int v = Byte() | (Byte() << 8);
            if (Generic) return "NN";
            if (isAddr && Label != null) { string l = Label(v); if (l != null) return l; }
            return "$" + v.ToString("X4");
        }
        public string Rel()
        {
            int d = Byte(); if (d >= 128) d -= 256;
            if (Generic) return "D";
            int t = (Pc + d) & 0xFFFF;
            if (Label != null) { string l = Label(t); if (l != null) return l; }
            return "$" + t.ToString("X4");
        }
        public string IdxMem()
        {
            if (!HaveDisp) { Disp = Byte(); if (Disp >= 128) Disp -= 256; HaveDisp = true; }
            if (Generic) return "(" + Idx + "+D)";
            return "(" + Idx + (Disp < 0 ? "-" : "+") + "$" + Math.Abs(Disp).ToString("X2") + ")";
        }
        // r[i] with index-register substitution (useHL8: H/L become IXH/IXL)
        public string Reg(int i, bool useHL8)
        {
            if (Idx == null) return R[i];
            if (i == 6) return IdxMem();
            if (useHL8 && i == 4) return Idx + "H";
            if (useHL8 && i == 5) return Idx + "L";
            return R[i];
        }
        public string Rp(int p) { return p == 2 && Idx != null ? Idx : RP[p]; }
        public string Rp2(int p) { return p == 2 && Idx != null ? Idx : RP2[p]; }
    }

    /// <summary>Disassembles one instruction at pc. generic = show operands as N / NN / D.</summary>
    public static string Dis(Func<int, int> rd, int pc, out int len, Func<int, string> label = null, bool generic = false)
    {
        var c = new Ctx { Rd = rd, Pc = pc, Start = pc, Generic = generic, Label = label };
        string s = One(c);
        len = c.Pc - pc;
        return s;
    }

    static string One(Ctx c)
    {
        int op = c.Byte();
        if (op == 0xDD || op == 0xFD)
        {
            int nx = c.Rd(c.Pc & 0xFFFF);
            if (nx == 0xDD || nx == 0xFD || nx == 0xED) return "NOP*";
            c.Idx = op == 0xDD ? "IX" : "IY";
            op = c.Byte();
            if (op == 0xCB)
            {
                string m = c.IdxMem();
                int o2 = c.Byte();
                int x2 = o2 >> 6, y2 = (o2 >> 3) & 7, z2 = o2 & 7;
                string dst = z2 != 6 ? "," + R[z2] : "";
                if (x2 == 0) return ROT[y2] + " " + m + dst;
                if (x2 == 1) return "BIT " + y2 + "," + m;
                return (x2 == 2 ? "RES " : "SET ") + y2 + "," + m + dst;
            }
        }
        if (op == 0xCB && c.Idx == null)
        {
            int o2 = c.Byte();
            int x2 = o2 >> 6, y2 = (o2 >> 3) & 7, z2 = o2 & 7;
            if (x2 == 0) return ROT[y2] + " " + R[z2];
            return (x2 == 1 ? "BIT " : x2 == 2 ? "RES " : "SET ") + y2 + "," + R[z2];
        }
        if (op == 0xED && c.Idx == null) return Ed(c);

        int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
        string hl = c.Idx ?? "HL";
        switch (x)
        {
            case 0:
                switch (z)
                {
                    case 0:
                        if (y == 0) return "NOP";
                        if (y == 1) return "EX AF,AF'";
                        if (y == 2) return "DJNZ " + c.Rel();
                        if (y == 3) return "JR " + c.Rel();
                        return "JR " + CC[y - 4] + "," + c.Rel();
                    case 1: return q == 0 ? "LD " + c.Rp(p) + "," + c.NN(false) : "ADD " + hl + "," + c.Rp(p);
                    case 2:
                        if (q == 0) return p == 0 ? "LD (BC),A" : p == 1 ? "LD (DE),A" : p == 2 ? "LD (" + c.NN(true) + ")," + hl : "LD (" + c.NN(true) + "),A";
                        return p == 0 ? "LD A,(BC)" : p == 1 ? "LD A,(DE)" : p == 2 ? "LD " + hl + ",(" + c.NN(true) + ")" : "LD A,(" + c.NN(true) + ")";
                    case 3: return (q == 0 ? "INC " : "DEC ") + c.Rp(p);
                    case 4: return "INC " + c.Reg(y, true);
                    case 5: return "DEC " + c.Reg(y, true);
                    case 6: { string d = c.Reg(y, true); return "LD " + d + "," + c.N(); }
                    default: return X0Z7[y];
                }
            case 1:
                if (y == 6 && z == 6) return "HALT";
                if (y == 6 || z == 6) return "LD " + c.Reg(y, false) + "," + c.Reg(z, false);
                return "LD " + c.Reg(y, true) + "," + c.Reg(z, true);
            case 2:
                return ALU[y] + c.Reg(z, true);
            default:
                switch (z)
                {
                    case 0: return "RET " + CC[y];
                    case 1:
                        if (q == 0) return "POP " + c.Rp2(p);
                        return p == 0 ? "RET" : p == 1 ? "EXX" : p == 2 ? "JP (" + hl + ")" : "LD SP," + hl;
                    case 2: return "JP " + CC[y] + "," + c.NN(true);
                    case 3:
                        switch (y)
                        {
                            case 0: return "JP " + c.NN(true);
                            case 1: return "CB?";
                            case 2: return "OUT (" + c.N() + "),A";
                            case 3: return "IN A,(" + c.N() + ")";
                            case 4: return "EX (SP)," + hl;
                            case 5: return "EX DE,HL";
                            case 6: return "DI";
                            default: return "EI";
                        }
                    case 4: return "CALL " + CC[y] + "," + c.NN(true);
                    case 5:
                        if (q == 0) return "PUSH " + c.Rp2(p);
                        return p == 0 ? "CALL " + c.NN(true) : "NOP*";
                    case 6: return ALU[y] + c.N();
                    default: return "RST $" + (y * 8).ToString("X2");
                }
        }
    }

    static string Ed(Ctx c)
    {
        int op = c.Byte();
        int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
        if (x == 1)
        {
            switch (z)
            {
                case 0: return y == 6 ? "IN (C)" : "IN " + R[y] + ",(C)";
                case 1: return y == 6 ? "OUT (C),0" : "OUT (C)," + R[y];
                case 2: return (q == 0 ? "SBC HL," : "ADC HL,") + RP[p];
                case 3: return q == 0 ? "LD (" + c.NN(true) + ")," + RP[p] : "LD " + RP[p] + ",(" + c.NN(true) + ")";
                case 4: return "NEG";
                case 5: return y == 1 ? "RETI" : "RETN";
                case 6: return "IM " + IMS[y];
                default:
                    switch (y)
                    {
                        case 0: return "LD I,A"; case 1: return "LD R,A"; case 2: return "LD A,I"; case 3: return "LD A,R";
                        case 4: return "RRD"; case 5: return "RLD"; default: return "NOP*";
                    }
            }
        }
        if (x == 2 && z <= 3 && y >= 4) return BLK[y - 4, z];
        return "NOP*";
    }
}
