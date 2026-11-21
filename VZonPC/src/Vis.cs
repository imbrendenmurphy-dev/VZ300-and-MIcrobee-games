// VZonPC visualiser: draws the live panels (Z80, code, hot spots, frame budget, opcodes, stack | memory map,
// beam timing, 6847, speaker, keyboard + joysticks, ports, BennVenn) into two 320x1080 bitmaps,
// in the VZ's own 6847 font. Shared by the window (sidebars / visualiser window) and vzemu ("vis" command).
using System;
using System.Collections.Generic;
using System.IO;

public sealed class VzVis
{
    public const int W = 320, H = 1080;
    public readonly int[] Left = new int[W * H], Right = new int[W * H];
    readonly VzMachine m;
    public VzTrace T;
    public readonly Dictionary<int, string> Sym = new Dictionary<int, string>();
    public string SymFile;

    // colours
    const int BG = 0x060A08, PANEL = 0x0A120E, FRAME = 0x1E4630, TBG = 0x10301E, TITLE = 0x46F010, TXT = 0xB8DCB0,
        DIM = 0x4E6A58, HI = 0xFFFFFF, AMBER = 0xFFB700, RED = 0xFF4848, CYAN = 0x41E0E0, MAG = 0xD060FF, BLUE = 0x5A84FF,
        GREEN = 0x40E040, ORANGE = 0xFF8A00, IDLEC = 0x14264A, GRID = 0x16261C;

    int[] buf;   // current target

    public VzVis(VzMachine machine) { m = machine; }

    // ================================================================ symbols
    /// <summary>Loads ADDR NAME symbols (zasm --sym) for a program: GAME.sym next to the .VZ, or in ../build, ../out, ..</summary>
    public void FindSymbols(string vzPath)
    {
        Sym.Clear(); SymFile = null;
        if (vzPath == null) return;
        string dir = Path.GetDirectoryName(Path.GetFullPath(vzPath)), bn = Path.GetFileNameWithoutExtension(vzPath);
        var dirs = new List<string> { dir };
        string par = Path.GetDirectoryName(dir);
        if (par != null) { dirs.Add(Path.Combine(par, "build")); dirs.Add(Path.Combine(par, "out")); dirs.Add(par); }
        foreach (var d in dirs)
        {
            string p = Path.Combine(d, bn + ".sym");
            if (File.Exists(p)) { LoadSymbols(p); return; }
        }
    }
    public void LoadSymbols(string path)
    {
        try
        {
            foreach (var line in File.ReadAllLines(path))
            {
                var p = line.Trim().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                if (p.Length < 2) continue;
                int a; try { a = Convert.ToInt32(p[0].TrimStart('$'), 16); } catch { continue; }
                string n = p[1].ToUpperInvariant();
                if (n.StartsWith(".") || n.StartsWith("@")) continue;
                if (!Sym.ContainsKey(a & 0xFFFF)) Sym[a & 0xFFFF] = n;
            }
            SymFile = path;
        }
        catch { }
    }
    string Label(int a)
    {
        string s; if (Sym.TryGetValue(a, out s)) return s;
        if (T != null && routine[a] && a >= 0x4000) return "SUB_" + a.ToString("X4");
        return null;
    }

    // ================================================================ drawing primitives
    void Fill(int x, int y, int w, int h, int c)
    {
        if (x < 0) { w += x; x = 0; } if (y < 0) { h += y; y = 0; }
        if (x + w > W) w = W - x; if (y + h > H) h = H - y;
        for (int j = 0; j < h; j++) { int o = (y + j) * W + x; for (int i = 0; i < w; i++) buf[o + i] = c; }
    }
    void Px(int x, int y, int c) { if ((uint)x < W && (uint)y < H) buf[y * W + x] = c; }
    void Rect(int x, int y, int w, int h, int c) { Fill(x, y, w, 1, c); Fill(x, y + h - 1, w, 1, c); Fill(x, y, 1, h, c); Fill(x + w - 1, y, 1, h, c); }

    static int Glyph(char ch)
    {
        if (ch >= 'a' && ch <= 'z') ch = (char)(ch - 32);
        if (ch >= '@' && ch <= '_') return ch - 64;
        if (ch >= ' ' && ch <= '?') return ch;
        if (ch == '\'') return 39;
        return 63;
    }
    /// <summary>Draws text in the 6847 font (6x8 cells). Returns the x after the text.</summary>
    int Text(int x, int y, string s, int c)
    {
        foreach (char ch in s)
        {
            if (x > W - 6) break;
            if (ch == '_') { for (int i = 0; i < 5; i++) Px(x + i, y + 6, c); }
            else if (ch != ' ')
            {
                int g = Glyph(ch);
                for (int r = 0; r < 7; r++)
                {
                    int bits = Font6847.F[g, r];
                    if (bits == 0) continue;
                    int o = (y + r) * W + x;
                    if (y + r >= H) break;
                    for (int i = 0; i < 5; i++) if (((bits >> (4 - i)) & 1) != 0) buf[o + i] = c;
                }
            }
            x += 6;
        }
        return x;
    }
    int TextR(int xr, int y, string s, int c) { return Text(xr - s.Length * 6, y, s, c); }

    static int Lerp(int a, int b, double t)
    {
        if (t < 0) t = 0; if (t > 1) t = 1;
        int r = (int)(((a >> 16) & 255) + (((b >> 16) & 255) - ((a >> 16) & 255)) * t);
        int g = (int)(((a >> 8) & 255) + (((b >> 8) & 255) - ((a >> 8) & 255)) * t);
        int bl = (int)((a & 255) + ((b & 255) - (a & 255)) * t);
        return (r << 16) | (g << 8) | bl;
    }
    static int Heat(double t)   // 0..1 -> dark, green, yellow, white
    {
        if (t <= 0) return 0x0C1610;
        if (t < 0.33) return Lerp(0x0C3010, 0x30D200, t / 0.33);
        if (t < 0.66) return Lerp(0x30D200, 0xFFD000, (t - 0.33) / 0.33);
        return Lerp(0xFFD000, 0xFFFFFF, (t - 0.66) / 0.34);
    }

    /// <summary>Panel frame with a title bar; returns the y where content starts.</summary>
    int Panel(int y, int h, string title, string info)
    {
        Fill(0, y, W, h, PANEL);
        Rect(0, y, W, h, FRAME);
        Fill(1, y + 1, W - 2, 11, TBG);
        Text(5, y + 3, title, TITLE);
        if (info != null) TextR(W - 5, y + 3, info, DIM);
        return y + 15;
    }

    static string H2(int v) { return (v & 255).ToString("X2"); }
    static string H4(int v) { return (v & 0xFFFF).ToString("X4"); }

    // ================================================================ render
    int[] prevRegs = new int[12];

    public void Render()
    {
        if (T == null) return;
        if (++routineScan % 25 == 1) UpdateRoutines();
        buf = Left; Array.Clear(buf, 0, buf.Length); Fill(0, 0, W, H, BG);
        int y = 0;
        y = PRegs(y) + 6;
        y = PCode(y, 18) + 6;
        y = PHot(y, 7) + 6;
        y = PBudget(y) + 6;
        y = PLines(y) + 6;
        y = POps(y) + 6;
        y = PStack(y, H - y);

        buf = Right; Array.Clear(buf, 0, buf.Length); Fill(0, 0, W, H, BG);
        y = 0;
        y = PMem(y) + 6;
        y = PBeam(y) + 6;
        y = PVideo(y) + 6;
        y = PSpeaker(y) + 6;
        y = PKeys(y) + 6;
        y = PPorts(y) + 6;
        y = PBennVenn(y, H - y);
    }

    // ---------------------------------------------------------------- Z80 registers
    int PRegs(int y0)
    {
        var c = m.Cpu;
        int h = 15 + 6 * 11 + 4;
        int y = Panel(y0, h, "Z80 REGISTERS", m.Model == Model.VZ300 ? "3.55 MHZ" : "3.58 MHZ");
        int[] v = { (c.A << 8) | c.F, (c.B << 8) | c.C, (c.D << 8) | c.E, (c.H << 8) | c.L,
                    (c.A_ << 8) | c.F_, (c.B_ << 8) | c.C_, (c.D_ << 8) | c.E_, (c.H_ << 8) | c.L_, c.IX, c.IY, c.SP, c.PC };
        string[] n = { "AF ", "BC ", "DE ", "HL ", "AF'", "BC'", "DE'", "HL'", "IX ", "IY ", "SP ", "PC " };
        for (int i = 0; i < 12; i++)
        {
            int x = 5 + (i % 4) * 78, yy = y + (i / 4) * 11;
            Text(x, yy, n[i], DIM);
            Text(x + 20, yy, H4(v[i]), v[i] != prevRegs[i] ? AMBER : TXT);
            prevRegs[i] = v[i];
        }
        int y3 = y + 33;
        int x3 = Text(5, y3, "I ", DIM); x3 = Text(x3, y3, H2(c.I), TXT);
        x3 = Text(x3 + 8, y3, "R ", DIM); x3 = Text(x3, y3, H2(c.R), TXT);
        x3 = Text(x3 + 8, y3, "IM ", DIM); x3 = Text(x3, y3, c.IM.ToString(), TXT);
        x3 = Text(x3 + 8, y3, "IFF ", DIM); x3 = Text(x3, y3, (c.IFF1 ? "1" : "0") + (c.IFF2 ? "1" : "0"), c.IFF1 ? GREEN : RED);
        x3 = Text(x3 + 8, y3, "INT/FRAME ", DIM); Text(x3, y3, T.Ints.ToString(), TXT);
        if (c.Halted) TextR(W - 5, y3, "HALT", AMBER);
        // flag lamps
        int y4 = y + 45;
        Text(5, y4 + 1, "FLAGS", DIM);
        string fl = "SZYHXPNC";
        for (int i = 0; i < 8; i++)
        {
            bool on = ((c.F >> (7 - i)) & 1) != 0;
            int x = 44 + i * 25;
            Fill(x, y4 - 1, 21, 10, on ? 0x30D200 : 0x12241A);
            Text(x + 8, y4 + 1, fl[i].ToString(), on ? 0x002000 : DIM);
        }
        int y5 = y + 57;
        int x5 = Text(5, y5, "T ", DIM); x5 = Text(x5, y5, c.Cyc.ToString(), TXT);
        x5 = Text(x5 + 12, y5, "FRAME ", DIM); Text(x5, y5, m.Frames.ToString(), TXT);
        return y0 + h;
    }

    // ---------------------------------------------------------------- code
    int PCode(int y0, int lines)
    {
        int h = 15 + lines * 9 + 4;
        int y = Panel(y0, h, "CODE", "SAMPLED WHILE BUSY");
        int pc = T.ShownPc >= 0 ? T.ShownPc : m.Cpu.PC;
        // walk back over known instruction starts
        int start = pc, back = 0;
        for (int a = pc - 1; a >= pc - 60 && back < 9; a--)
            if (a >= 0 && T.Start[a]) { start = a; back++; }
        Func<int, int> rd = m.Peek;
        int ad = start, ln = 0;
        while (ln < lines)
        {
            string lab = Label(ad);
            if (lab != null)
            {
                Text(5, y + ln * 9, lab + ":", AMBER);
                ln++; if (ln >= lines) break;
            }
            int len;
            string s = Z80Dis.Dis(rd, ad, out len, Label);
            int yy = y + ln * 9;
            bool isPc = ad == pc;
            if (isPc) Fill(2, yy - 1, W - 4, 9, 0x1E5030);
            int hx = T.HX[ad];
            int col = isPc ? HI : hx > 0 ? Lerp(DIM, TXT, hx / 255.0) : DIM;
            if (ad == m.Cpu.PC) Text(5, yy, ">", RED);
            Text(12, yy, H4(ad), isPc ? HI : DIM);
            string bytes = "";
            for (int i = 0; i < len && i < 4; i++) bytes += H2(rd((ad + i) & 0xFFFF));
            Text(42, yy, bytes, isPc ? TXT : 0x3C5A48);
            Text(96, yy, s, col);
            ad = (ad + Math.Max(1, len)) & 0xFFFF; ln++;
        }
        return y0 + h;
    }

    // ---------------------------------------------------------------- hot spots
    readonly bool[] routine = new bool[65536];   // call targets kept as routine starts (dense clusters merged)
    int routineScan;
    void UpdateRoutines()
    {
        // merge call targets closer than 16 bytes (calls into the middle of unrolled code)
        int last = -100;
        for (int a = 0; a < 65536; a++)
        {
            routine[a] = false;
            if (!T.CallTarget[a]) continue;
            if (a - last >= 16 || Sym.ContainsKey(a)) routine[a] = true;
            last = a;
        }
    }
    int hotVersion = -1; List<KeyValuePair<string, long>> hot = new List<KeyValuePair<string, long>>();

    void BuildHot()
    {
        hotVersion = T.ProfVersion; hot.Clear();
        var starts = new List<int>();
        foreach (var k in Sym.Keys) starts.Add(k);
        UpdateRoutines();
        for (int a = 0x4000; a < 65536; a++) if (routine[a] && !Sym.ContainsKey(a)) starts.Add(a);
        starts.Sort();
        var sums = new Dictionary<string, long>();
        for (int a = 0; a < 65536; a++)
        {
            long t = T.ProfShown[a]; if (t == 0) continue;
            string name;
            if (a < 0x4000) name = a >= 0x38 && a < 0x40 ? "ROM ISR" : "ROM $" + H4(a & 0xFF00);
            else
            {
                int i = starts.BinarySearch(a); if (i < 0) i = ~i - 1;
                if (i >= 0 && a - starts[i] < 0x1000) { int s = starts[i]; string sn; name = Sym.TryGetValue(s, out sn) ? sn : "SUB_" + H4(s); }
                else name = "$" + H4(a & 0xFF00) + " BLOCK";
                if (a >= 0x4000 && a < 0x6800 && (i < 0 || !Sym.ContainsKey(starts[i]))) name = "DOS $" + H4(a & 0xFF00);
            }
            long o; sums.TryGetValue(name, out o); sums[name] = o + t;
        }
        foreach (var kv in sums) hot.Add(kv);
        hot.Sort((p, q) => q.Value.CompareTo(p.Value));
    }

    int PHot(int y0, int lines)
    {
        if (hotVersion != T.ProfVersion) BuildHot();
        int h = 15 + lines * 11 + 2;
        int y = Panel(y0, h, "HOT SPOTS", Sym.Count > 0 ? "CPU TIME, SYMBOLS" : "CPU TIME, LAST SECOND");
        long tot = Math.Max(1, T.ProfShownT);
        for (int i = 0; i < lines && i < hot.Count; i++)
        {
            int yy = y + i * 11;
            double f = (double)hot[i].Value / tot;
            string nm = hot[i].Key; if (nm.Length > 17) nm = nm.Substring(0, 17);
            Text(5, yy, nm, i == 0 ? HI : TXT);
            string pct = (f * 100).ToString(f < 0.1 ? "0.0" : "0") + "%";
            TextR(146, yy, pct, AMBER);
            int bw = (int)(f * 166);
            Fill(150, yy - 1, 166, 9, 0x0E1C14);
            Fill(150, yy - 1, Math.Max(1, bw), 9, Heat(0.25 + f * 0.75));
        }
        if (hot.Count == 0) Text(5, y, "COLLECTING...", DIM);
        return y0 + h;
    }

    // ---------------------------------------------------------------- frame budget
    int PBudget(int y0)
    {
        int h = 15 + 12 + 4 + 10 + 50 + 4;
        int y = Panel(y0, h, "FRAME BUDGET", "50 HZ FIELD = " + VzMachine.FRAMET + " T");
        int x = 5, bw = W - 10;
        int wb = (int)(T.Busy * bw), wi = (int)(T.Isr * bw), wd = (int)(T.DosF * bw);
        Fill(x, y, bw, 12, IDLEC);
        Fill(x, y, wb, 12, GREEN); Fill(x + wb, y, wi, 12, MAG); Fill(x + wb + wi, y, wd, 12, ORANGE);
        Text(x + 4, y + 3, ((int)Math.Round((T.Busy + T.Isr + T.DosF) * 100)) + "% USED", 0x002000);
        int yt = y + 16;
        int xt = Text(5, yt, "BUSY ", GREEN); xt = Text(xt, yt, Pct(T.Busy), TXT);
        xt = Text(xt + 8, yt, "ISR ", MAG); xt = Text(xt, yt, Pct(T.Isr), TXT);
        xt = Text(xt + 8, yt, "DOS ", ORANGE); xt = Text(xt, yt, Pct(T.DosF), TXT);
        xt = Text(xt + 8, yt, "WAIT ", BLUE); Text(xt, yt, Pct(T.Idle), TXT);
        // history: 300 frames = 6 seconds
        int gy = yt + 12, gh = 48;
        Fill(5, gy, 300, gh, 0x08100C);
        for (int i = 0; i < VzTrace.HIST; i++)
        {
            int k = (T.HPos + i) % VzTrace.HIST;
            int b = T.HBusy[k] * gh / 100, s = T.HIsr[k] * gh / 100, d = T.HDos[k] * gh / 100;
            int yb = gy + gh;
            Fill(5 + i, yb - b, 1, b, 0x28A028); yb -= b;
            Fill(5 + i, yb - s, 1, s, MAG); yb -= s;
            Fill(5 + i, yb - d, 1, d, ORANGE);
        }
        Fill(5, gy + gh / 2, 300, 1, 0x1A3020);
        TextR(W - 4, gy, "100", DIM); TextR(W - 4, gy + gh - 8, "0", DIM);
        return y0 + h;
    }
    static string Pct(double f) { return ((int)Math.Round(f * 100)) + "%"; }

    // ---------------------------------------------------------------- opcode heatmap
    int POps(int y0)
    {
        int cw = 18, ch = 9;
        int h = 15 + 9 + 16 * ch + 4 + 20;
        int y = Panel(y0, h, "OPCODES", "FIRST BYTE, LAST SECOND");
        int gx = 17;
        for (int i = 0; i < 16; i++) Text(gx + i * cw + 6, y, i.ToString("X"), DIM);
        y += 9;
        long n = Math.Max(1, T.OpsShownN);
        int max = 1; for (int i = 0; i < 256; i++) if (T.OpsShown[i] > max) max = T.OpsShown[i];
        double lmax = Math.Log(1 + max);
        for (int r = 0; r < 16; r++)
        {
            Text(5, y + r * ch + 1, r.ToString("X"), DIM);
            for (int col = 0; col < 16; col++)
            {
                int cnt = T.OpsShown[r * 16 + col];
                Fill(gx + col * cw, y + r * ch, cw - 1, ch - 1, cnt == 0 ? 0x0C1610 : Heat(Math.Log(1 + cnt) / lmax));
            }
        }
        // top opcodes
        var idx = new List<int>(); for (int i = 0; i < 256; i++) if (T.OpsShown[i] > 0) idx.Add(i);
        idx.Sort((a, b) => T.OpsShown[b].CompareTo(T.OpsShown[a]));
        int ty = y + 16 * ch + 3;
        for (int i = 0; i < 4 && i < idx.Count; i++)
        {
            int op = idx[i]; int len;
            byte[] fake = { (byte)op, 0, 0, 0 };
            string s = op == 0xCB ? "CB PREFIX" : op == 0xED ? "ED PREFIX" : op == 0xDD ? "IX PREFIX" : op == 0xFD ? "IY PREFIX"
                : Z80Dis.Dis(a => fake[a & 3], 0, out len, null, true);
            string line = ((int)Math.Round(100.0 * T.OpsShown[op] / n)) + "% " + s;
            if (line.Length > 25) line = line.Substring(0, 25);
            Text(5 + (i % 2) * 156, ty + (i / 2) * 10, line, i == 0 ? HI : TXT);
        }
        return y0 + h;
    }

    // ---------------------------------------------------------------- stack
    int PStack(int y0, int avail)
    {
        int h = Math.Min(avail, 15 + 10 + 38 + 4 + 10 + 8 * 10 + 4);
        int y = Panel(y0, h, "STACK", null);
        int sp = m.Cpu.SP;
        int x = Text(5, y, "SP ", DIM); x = Text(x, y, H4(sp), TXT);
        x = Text(x + 12, y, "LOWEST THIS SECOND ", DIM); Text(x, y, T.SpMinSecond == 0xFFFF ? "----" : H4(T.SpMinSecond), AMBER);
        int gy = y + 11, gh = 36;
        Fill(5, gy, 300, gh, 0x08100C);
        int lo = 0xFFFF, hi = 0;
        for (int i = 0; i < VzTrace.HIST; i++) { int v = T.HSp[i]; if (v == 0xFFFF || v == 0) continue; if (v < lo) lo = v; if (v > hi) hi = v; }
        if (hi >= lo)
        {
            hi = Math.Max(hi, lo + 16);
            for (int i = 0; i < VzTrace.HIST; i++)
            {
                int v = T.HSp[(T.HPos + i) % VzTrace.HIST]; if (v == 0xFFFF || v == 0) continue;
                int py = gy + (int)((long)(v - lo) * (gh - 2) / (hi - lo));   // lower SP = deeper = higher up
                Fill(5 + i, py, 1, gy + gh - py, 0x1C4060); Px(5 + i, py, CYAN);
            }
            TextR(W - 4, gy, H4(lo), DIM); TextR(W - 4, gy + gh - 8, H4(hi), DIM);
        }
        int ly = gy + gh + 4;
        Text(5, ly, "RETURN ADDRESSES ON THE STACK", DIM); ly += 10;
        int shown = 0;
        for (int k = 0; k < 24 && shown < 8 && ly + 9 < y0 + h; k++)
        {
            int a = (sp + k * 2) & 0xFFFF;
            if (a >= T.SpMaxSecond + 2 || a < sp) break;
            int w = m.Peek(a) | (m.Peek((a + 1) & 0xFFFF) << 8);
            int b3 = m.Peek((w - 3) & 0xFFFF), b1 = m.Peek((w - 1) & 0xFFFF);
            bool call = b3 == 0xCD || (b3 & 0xC7) == 0xC4;
            bool rst = (b1 & 0xC7) == 0xC7 && b1 != 0xFF;
            if (!call && !rst) continue;
            string from = "";
            if (call) { int tgt = m.Peek((w - 2) & 0xFFFF) | (m.Peek((w - 1) & 0xFFFF) << 8); from = "CALL " + (Label(tgt) ?? "$" + H4(tgt)); }
            else from = "RST $" + H2(b1 & 0x38);
            int xx = Text(5, ly, H4(a), DIM); xx = Text(xx + 6, ly, H4(w), TXT);
            Text(xx + 8, ly, "FROM " + from, shown == 0 ? AMBER : TXT);
            ly += 10; shown++;
        }
        if (shown == 0) Text(5, ly, "(NONE)", DIM);
        return y0 + h;
    }

    // ================================================================ right column
    int PMem(int y0)
    {
        int h = 15 + 256 + 4 + 10 + 2;
        int y = Panel(y0, h, "MEMORY MAP", "64K, 1 PIXEL = 1 BYTE");
        int mx = 4;
        bool bv = m.Exp == MemExp.BennVenn;
        int ramTop = m.Model == Model.VZ300 ? 0xB800 : 0x9000;
        for (int a = 0; a < 65536; a++)
        {
            int tr, tg, tb; bool mapped = true;
            if (a < 0x4000) { tr = 14; tg = 16; tb = 34; }
            else if (a < 0x6800) { tr = 30; tg = 18; tb = 0; mapped = bv; }
            else if (a < 0x7000) { tr = 34; tg = 28; tb = 0; mapped = false; }
            else if (a < 0x7800) { tr = 0; tg = 34; tb = 12; }
            else if (a < ramTop) { tr = 8; tg = 14; tb = 8; }
            else { tr = 18; tg = 8; tb = 26; mapped = m.Exp != MemExp.None; }
            int v = mapped ? m.Peek(a) : 0;
            int lum = mapped ? (v >> 3) : 0;
            int r = tr + lum, g = tg + lum, b = tb + lum;
            int hr = T.HR[a], hw = T.HW[a], hx = T.HX[a];
            if (hw > r) r = hw;
            if (hw / 3 > g) g = hw / 3;
            if (hr * 7 / 8 > g) g = hr * 7 / 8;
            if (hx > b) b = hx;
            if (hx / 2 > g) g = Math.Max(g, hx / 2);
            if (hx / 4 > r) r = Math.Max(r, hx / 4);
            buf[(y + (a >> 8)) * W + mx + (a & 255)] = (Math.Min(255, r) << 16) | (Math.Min(255, g) << 8) | Math.Min(255, b);
        }
        // PC / SP markers
        int pc = m.Cpu.PC, sp = m.Cpu.SP;
        Fill(mx + 257, y + (pc >> 8), 5, 1, HI);
        Fill(mx + 257, y + (sp >> 8), 5, 1, AMBER);
        for (int d = -2; d <= 2; d++) { Px(mx + (pc & 255) + d, y + (pc >> 8), HI); Px(mx + (pc & 255), y + (pc >> 8) + d, HI); }
        // region labels
        int lx = mx + 264;
        int expAt = m.Exp == MemExp.BennVenn ? (m.Model == Model.VZ300 ? 0xB800 : 0x9000) : ramTop;
        LabelAt(lx, y, 0x0000, "ROM", 0x8090D0, 0x4000);
        LabelAt(lx, y, 0x4000, bv ? "DOS" : "----", ORANGE, 0x6800);
        LabelAt(lx, y, 0x6800, "I/O", AMBER, 0x7000);
        LabelAt(lx, y, 0x7000, "VRAM", GREEN, 0x7800);
        LabelAt(lx, y, 0x7800, "RAM", TXT, expAt);
        LabelAt(lx, y, expAt, m.Exp == MemExp.BennVenn ? "128K" : m.Exp == MemExp.Ram16K ? "16K" : "----", MAG, 0x10000);
        int ly = y + 256 + 4;
        int x = Text(5, ly, "READ", GREEN); x = Text(x + 10, ly, "WRITE", RED); x = Text(x + 10, ly, "EXECUTE", BLUE);
        x = Text(x + 14, ly, "PC", HI); Text(x + 10, ly, "SP", AMBER);
        return y0 + h;
    }
    void LabelAt(int x, int y, int addr, string name, int c, int next)
    {
        int yy = y + (addr >> 8);
        Fill(x - 4, yy, 3, 1, c);
        Text(x, yy + 1, name, c);
        if (((next - addr) >> 8) >= 18) Text(x, yy + 10, H4(addr), DIM);
    }

    // ---------------------------------------------------------------- beam / CPU timing
    static readonly int[] stCol = { 0x0A100C, 0x1E8A2A, IDLEC, 0x9A3CC8, 0xC86A00 };
    static readonly int[] ovCol = { 0, CYAN, HI, RED, AMBER, 0xE0E060, 0x808080 };
    static readonly int[] stPri = { 0, 2, 1, 4, 3 };

    int PBeam(int y0)
    {
        int rh = VzTrace.LINES / 2;   // 2 scan lines per row
        int h = 15 + rh + 4 + 20;
        int y = Panel(y0, h, "BEAM AND CPU", "1 FIELD: 228 T X 312 LINES");
        int bx = 4;
        var ras = T.Ras; var ov = T.Ov;
        for (int r = 0; r < rh; r++)
        {
            int l0 = r * 2, l1 = l0 + 1;
            int o = (y + r) * W + bx;
            for (int t = 0; t < VzTrace.LT; t++)
            {
                int i0 = l0 * VzTrace.LT + t, i1 = l1 * VzTrace.LT + t;
                int ovv = ov[i0] != 0 ? ov[i0] : ov[i1];
                if (ov[i0] == VzTrace.O_VW || ov[i1] == VzTrace.O_VW) ovv = VzTrace.O_VW;
                if (ovv != 0) { buf[o + t] = ovCol[ovv]; continue; }
                int s = stPri[ras[i0]] >= stPri[ras[i1]] ? ras[i0] : ras[i1];
                buf[o + t] = stCol[s];
            }
        }
        // picture area guides
        int p0 = m.PicStart / 2, p1 = (m.PicStart + 192) / 2, fs = VzMachine.FSLINES / 2;
        for (int t = 0; t < VzTrace.LT; t += 2) { Px(bx + t, y + p0, 0x50A060); Px(bx + t, y + p1, 0x50A060); Px(bx + t, y + fs, 0x806020); }
        for (int r = p0; r < p1; r += 2) { Px(bx + m.H0, y + r, 0x50A060); Px(bx + m.H0 + 128, y + r, 0x50A060); }
        // 6847 mode strip
        int sx = bx + VzTrace.LT + 3;
        for (int r = 0; r < rh; r++)
        {
            Fill(sx, y + r, 6, 1, ModeColour(T.LineModeShown[r * 2]));
            int f = T.LineFlag[r * 2] | T.LineFlag[r * 2 + 1];   // a mode change during the line: a white tick
            if (f != 0) Fill(sx + 6, y + r, 2, 1, (f & 1) != 0 ? AMBER : HI);
        }
        int lx = sx + 10;
        Text(lx, y, "0 SYNC", 0xC09040); Text(lx, y + 9, "INT", 0xC09040);
        Text(lx, y + fs + 1, VzMachine.FSLINES.ToString(), DIM);
        Text(lx, y + p0 + 1, m.PicStart + " PIC", 0x70C080);
        Text(lx, y + p1 + 1, (m.PicStart + 192).ToString(), DIM);
        Text(lx, y + rh - 8, "311", DIM);
        int ly = y + rh + 4;
        int x = Text(5, ly, "BUSY", 0x30C040); x = Text(x + 8, ly, "ISR", MAG); x = Text(x + 8, ly, "DOS", ORANGE);
        x = Text(x + 8, ly, "WAIT", BLUE); x = Text(x + 8, ly, "KEYS", 0x909090);
        ly += 10;
        x = Text(5, ly, "VRAM WRITE", HI); x = Text(x + 8, ly, "READ", CYAN); x = Text(x + 8, ly, "SPEAKER", RED);
        x = Text(x + 8, ly, "OUT", AMBER); Text(x + 8, ly, "IN", 0xE0E060);
        return y0 + h;
    }
    static int ModeColour(int lm)
    {
        if ((lm & 8) == 0) return (lm & 16) != 0 ? 0xC06000 : 0x1E6A1E;
        int gm = lm & 7;
        int[] c = { 0x3050C0, 0x40A0C0, 0x30C060, 0x8040C0, 0xC04080, 0xC0A030, 0xE06030, 0xFFFFFF };
        return c[gm];
    }

    // ---------------------------------------------------------------- 6847 picture lines
    // Every picture line at one pixel per T-state: the mode the 6847 latch held at each T (dim in the side
    // borders, bright in the 128 T-states the 6847 is drawing), white where AG or CSS changed during the line,
    // and on the right the row the 6847's row counter showed on that line, amber where a mid-line flip held it.
    int PLines(int y0)
    {
        int h = 15 + 192 + 22;
        int y = Panel(y0, h, "6847 BEAM, LINE BY LINE", "228 T X 192 LINES");
        int bx = 4, ps = m.PicStart, h0 = m.H0;
        var lat = T.LineLat;
        for (int py = 0; py < 192; py++)
        {
            int ln = ps + py; if (ln >= VzTrace.LINES) break;
            int o = (y + py) * W + bx, lo = ln * VzTrace.LT, prev = lat[lo];
            for (int t = 0; t < VzTrace.LT; t++)
            {
                int v = lat[lo + t];
                int c = ModeColour(((v & 8) != 0 ? 8 | m.GmCode : 0) | (v & 16));
                if (t < h0 || t >= h0 + 128) c = (c >> 2) & 0x3F3F3F;
                if (((v ^ prev) & 0x18) != 0) c = HI;
                prev = v;
                buf[o + t] = c;
            }
        }
        for (int py = 0; py < 192; py += 2) { Px(bx + h0 - 1, y + py, 0x80C090); Px(bx + h0 + 128, y + py, 0x80C090); }
        // the row counter
        int rx = bx + VzTrace.LT + 4, rw = W - 4 - rx;
        Fill(rx, y, rw, 192, 0x081008);
        for (int py = 0; py < 192; py++)
        {
            int ln = ps + py; if (ln >= VzTrace.LINES) break;
            int row = T.LineRow[ln]; if (row < 0) continue;
            int rows = (T.LineLat[ln * VzTrace.LT + h0 + 64] & 8) != 0 ? 64 : 16;
            int len = Math.Min(rw, 1 + row * (rw - 1) / Math.Max(1, rows - 1));
            bool held = (T.LineFlag[ln] & 1) != 0;
            Fill(rx, y + py, len, 1, held ? 0x5A3C00 : 0x1A4A1E);
            Px(rx + len - 1, y + py, held ? AMBER : GREEN);
        }
        int ly = y + 194;
        Text(bx + h0 - 3 * 6 / 2, ly, h0.ToString(), DIM); Text(bx + h0 + 128 - 9, ly, (h0 + 128).ToString(), DIM);
        Text(bx, ly, "T 0", DIM); TextR(bx + VzTrace.LT, ly, "227", DIM); Text(rx, ly, "ROW", DIM);
        int x = Text(5, ly + 10, "MODE CHANGE ", DIM); x = Fill2(x, ly + 10, HI);
        x = Text(x + 8, ly + 10, "ROW HELD ", DIM); x = Fill2(x, ly + 10, AMBER);
        x = Text(x + 8, ly + 10, "LINE ", DIM); Text(x, ly + 10, ps + "-" + (ps + 191), TXT);
        return y0 + h;
    }
    int Fill2(int x, int y, int c) { Fill(x, y + 1, 10, 5, c); return x + 10; }

    // ---------------------------------------------------------------- 6847
    static readonly string[] gmName = { "CG1  64X64  4 COLOURS", "RG1 128X64  2 COLOURS", "CG2 128X64  4 COLOURS", "RG2 128X96  2 COLOURS",
        "CG3 128X96  4 COLOURS", "RG3 128X192 2 COLOURS", "CG6 128X192 4 COLOURS", "RG6 256X192 2 COLOURS" };

    int PVideo(int y0)
    {
        int h = 15 + 4 * 10 + 2;
        string gfx = m.Gfx == GfxMod.Australian ? "AUSTRALIAN SHRG" : m.Gfx == GfxMod.German ? "GERMAN HI-RES" : "STANDARD 2K";
        int y = Panel(y0, h, "MC6847 VIDEO", gfx);
        string mode = m.AG ? gmName[m.GmCode] : "TEXT + SEMIGRAPHICS 4  32X16";
        int x = Text(5, y, "MODE ", DIM); Text(x, y, mode, HI);
        int y2 = y + 10;
        x = Text(5, y2, "AG ", DIM); x = Text(x, y2, m.AG ? "1" : "0", TXT);
        x = Text(x + 8, y2, "CSS ", DIM); x = Text(x, y2, m.CSS ? "1" : "0", TXT);
        int gm = m.GmCode;
        x = Text(x + 8, y2, "GM ", DIM); x = Text(x, y2, ((gm >> 2) & 1) + "" + ((gm >> 1) & 1) + (gm & 1), TXT);
        x = Text(x + 8, y2, "LATCH ", DIM); x = Text(x, y2, "$" + H2(m.Latch), TXT);
        if (m.Gfx == GfxMod.Australian) { x = Text(x + 8, y2, "OUT32 ", DIM); x = Text(x, y2, "$" + H2(m.ShrgPort), TXT); Text(x + 8, y2, "PG " + (m.ShrgPort & 3), TXT); }
        else if (m.Gfx == GfxMod.German) { x = Text(x + 8, y2, "BANK ", DIM); Text(x, y2, m.GerBank.ToString(), TXT); }
        int y3 = y + 20;
        x = Text(5, y3, "VRAM PER FRAME  WRITES ", DIM); x = Text(x, y3, T.VramW.ToString(), HI);
        x = Text(x + 8, y3, "READS ", DIM); Text(x, y3, T.VramR.ToString(), CYAN);
        int y4 = y + 30;
        x = Text(5, y4, "SNOW ", DIM); x = Text(x, y4, T.PicAccess.ToString(), T.PicAccess > 0 ? AMBER : TXT);
        x = Text(x + 8, y4, "SPLIT LINES ", DIM); x = Text(x, y4, T.Splits.ToString(), T.Splits > 0 ? AMBER : TXT);
        x = Text(x + 8, y4, "HOLDS ", DIM); Text(x, y4, T.Holds.ToString(), T.Holds > 0 ? AMBER : TXT);
        return y0 + h;
    }

    // ---------------------------------------------------------------- speaker
    readonly double[] fre = new double[1024], fim = new double[1024];
    readonly double[] spec = new double[512];

    int PSpeaker(int y0)
    {
        int h = 15 + 40 + 4 + 36 + 4 + 10 + 2;
        int y = Panel(y0, h, "SPEAKER", "LATCH BITS 0 + 5");
        int sx = 5, sw = 300, shh = 40;
        Fill(sx, y, sw, shh, 0x08100C);
        Fill(sx, y + shh / 2, sw, 1, 0x16301E);
        var s = T.SpkShown; int n = VzTrace.SPKN;
        for (int col = 0; col < sw; col++)
        {
            int a = col * n / sw, b = Math.Max(a + 1, (col + 1) * n / sw);
            int lo = 1, hi = -1;
            for (int i = a; i < b && i < n; i++) { if (s[i] < lo) lo = s[i]; if (s[i] > hi) hi = s[i]; }
            int ylo = y + shh / 2 - hi * (shh / 2 - 3), yhi = y + shh / 2 - lo * (shh / 2 - 3);
            Fill(sx + col, ylo, 1, yhi - ylo + 1, lo != hi ? 0x60FF60 : 0x30C030);
        }
        // spectrum of the last 1024 bins (~18 ms at 55 kHz)
        int rp = T.SpkRingPos;
        for (int i = 0; i < 1024; i++)
        {
            double wv = 0.5 - 0.5 * Math.Cos(2 * Math.PI * i / 1023);
            fre[i] = T.SpkRing[(rp - 1024 + i) & 2047] * wv; fim[i] = 0;
        }
        double mean = 0; for (int i = 0; i < 1024; i++) mean += fre[i]; mean /= 1024;
        for (int i = 0; i < 1024; i++) fre[i] -= mean * (0.5 - 0.5 * Math.Cos(2 * Math.PI * i / 1023));
        Fft(fre, fim);
        double rate = (double)m.Clock / VzTrace.SPKBIN;
        int maxBin = (int)(6000 / (rate / 1024)); if (maxBin > 511) maxBin = 511;
        int peak = 0; double pv = 0;
        for (int i = 1; i <= maxBin; i++) { spec[i] = Math.Sqrt(fre[i] * fre[i] + fim[i] * fim[i]); if (spec[i] > pv) { pv = spec[i]; peak = i; } }
        int gy = y + shh + 4, gh = 36;
        Fill(sx, gy, sw, gh, 0x08100C);
        for (int col = 0; col < sw; col++)
        {
            int bin = 1 + col * maxBin / sw;
            double v = spec[bin];
            int bh = v <= 0 ? 0 : (int)Math.Min(gh, Math.Max(0, Math.Log10(1 + v) * 14));
            Fill(sx + col, gy + gh - bh, 1, bh, Heat(0.3 + 0.7 * bh / gh));
        }
        TextR(sx + sw, gy, "6 KHZ", DIM); Text(sx + 2, gy, "0", DIM);
        int ty = gy + gh + 4;
        int x = Text(5, ty, "LEVEL CHANGES/FRAME ", DIM); x = Text(x, ty, T.SpkWrites.ToString(), TXT);
        if (T.SpkWrites > 2 && pv > 1) { x = Text(x + 12, ty, "PEAK ", DIM); Text(x, ty, ((int)(peak * rate / 1024)) + " HZ", AMBER); }
        else Text(x + 12, ty, "SILENT", DIM);
        return y0 + h;
    }

    static void Fft(double[] re, double[] im)
    {
        int n = re.Length;
        for (int i = 1, j = 0; i < n; i++)
        {
            int bit = n >> 1;
            for (; (j & bit) != 0; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j) { double t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
        }
        for (int len = 2; len <= n; len <<= 1)
        {
            double ang = -2 * Math.PI / len, wr = Math.Cos(ang), wi = Math.Sin(ang);
            for (int i = 0; i < n; i += len)
            {
                double cr = 1, ci = 0;
                for (int k = 0; k < len / 2; k++)
                {
                    int a = i + k, b = a + len / 2;
                    double xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr;
                    re[b] = re[a] - xr; im[b] = im[a] - xi; re[a] += xr; im[a] += xi;
                    double t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
                }
            }
        }
    }

    // ---------------------------------------------------------------- keyboard + joysticks
    int PKeys(int y0)
    {
        int h = 15 + 8 * 11 + 2;
        int y = Panel(y0, h, "KEYBOARD MATRIX", "JOYSTICKS");
        for (int r = 0; r < 8; r++)
        {
            int yy = y + r * 11;
            int sc = T.RowScan[r];
            Fill(4, yy - 1, 15, 9, Lerp(0x0E1C14, 0x30D200, sc / 255.0));
            Text(5, yy, "A" + r, sc > 128 ? 0x002000 : DIM);
            for (int b = 0; b < 6; b++)
            {
                string k = VzMachine.KROWS[r, 5 - b];
                int x = 22 + b * 33;
                if (k.Length == 0) continue;
                bool down = (m.Keys[r] & (1 << (5 - b))) == 0;
                string lab = k == "RETURN" ? "RET" : k == "SHIFT" ? "SHFT" : k == "SPACE" ? "SPC" : k;
                Fill(x, yy - 1, 31, 9, down ? AMBER : 0x12221A);
                Text(x + (31 - lab.Length * 6) / 2 + 1, yy, lab, down ? 0x201000 : TXT);
            }
        }
        // joysticks: active-low port bits 1 up 2 down 4 left 8 right 16 fire
        for (int j = 0; j < 2; j++)
        {
            int jx = 228 + j * 46, jy = y + 6;
            int v = m.Joy[j * 2], arm = m.Joy[j * 2 + 1];
            Text(jx + 10, jy - 6, "J" + (j + 1), DIM);
            Pad(jx + 12, jy + 6, (v & 1) == 0); Pad(jx + 12, jy + 30, (v & 2) == 0);
            Pad(jx, jy + 18, (v & 4) == 0); Pad(jx + 24, jy + 18, (v & 8) == 0);
            Fill(jx + 12, jy + 18, 11, 11, 0x0A140E);
            Fill(jx + 2, jy + 48, 15, 9, (v & 16) == 0 ? RED : 0x301414); Text(jx + 4, jy + 49, "F", (v & 16) == 0 ? HI : DIM);
            Fill(jx + 20, jy + 48, 15, 9, (arm & 16) == 0 ? RED : 0x301414); Text(jx + 22, jy + 49, "A", (arm & 16) == 0 ? HI : DIM);
            Text(jx + 2, jy + 62, H2(v), DIM);
        }
        if (!m.JoyInterface) Text(230, y + 80, "NO JOY IF", DIM);
        return y0 + h;
    }
    void Pad(int x, int y, bool on) { Fill(x, y, 11, 11, on ? AMBER : 0x1A2C20); }

    // ---------------------------------------------------------------- ports
    int PPorts(int y0)
    {
        int h = 15 + 16 * 5 + 4 + 2;
        int y = Panel(y0, h, "I/O PORTS", "IN / OUT, PER FRAME");
        for (int p = 0; p < 256; p++)
        {
            int x = 5 + (p & 15) * 9, yy = y + (p >> 4) * 5;
            int i = T.PIn[p], o = T.POut[p];
            int c = (i == 0 && o == 0) ? 0x0E1A12 : (Math.Min(255, o + 20) << 16) | (Math.Min(255, i + 20) << 8) | 0x10;
            Fill(x, yy, 8, 4, c);
        }
        int lx = 152, ly = y;
        for (int k = 0; k < T.Recent.Count && k < 8; k++)
        {
            int key = T.Recent[k]; bool isOut = key >= 256; int p = key & 255;
            int cnt = T.PCountShown[key];
            int v = isOut ? T.PValOut[p] : T.PValIn[p];
            int x = Text(lx, ly, isOut ? "OUT" : "IN ", isOut ? RED : GREEN);
            x = Text(x + 6, ly, "$" + H2(p), TXT); x = Text(x + 6, ly, "$" + H2(v), HI);
            Text(x + 8, ly, cnt > 0 ? "X" + cnt : "", DIM);
            string nm = PortName(p);
            if (nm != null) TextR(W - 4, ly, nm, DIM);
            ly += 10;
        }
        if (T.Recent.Count == 0) Text(lx, ly, "NO PORT ACCESS YET", DIM);
        return y0 + h;
    }
    string PortName(int p)
    {
        if (p >= 0x20 && p <= 0x2F) return m.Gfx == GfxMod.Australian ? "JOY/SHRG" : "JOY";
        if (p == 0x37 && m.Exp == MemExp.BennVenn) return "BV MAP";
        if (p == 0x3A && m.Exp == MemExp.BennVenn) return "BV MODE";
        if (p >= 0xD0 && p <= 0xDF && m.Gfx == GfxMod.German) return "GER BANK";
        return null;
    }

    // ---------------------------------------------------------------- BennVenn
    // ---------------------------------------------------------------- disk drive
    int PDisk(int y0, int avail)
    {
        var f = m.Fdc;
        int h = Math.Min(avail, 15 + 104);
        int y = Panel(y0, h, m.WordProOn ? "DISK DRIVE + WORDPRO" : "DISK DRIVE  DD20", f.Rom != null ? "VZ DOS ROM AT 4000" : "NO VZDOS.ROM");
        int led = T.DosLed;
        Fill(5, y - 1, 9, 9, f.Active ? Lerp(0x401000, 0xFF3030, Math.Max(0.35, led / 255.0)) : 0x301010);
        int x = Text(20, y, f.Active ? "DRIVE " + (f.Selected + 1) : "MOTOR OFF", f.Active ? HI : DIM);
        x = Text(x + 10, y, "TRACK ", DIM); x = Text(x, y, f.Track.ToString("00"), HI);
        x = Text(x + 10, y, "LATCH $", DIM); x = Text(x, y, H2(f.Latch), TXT);
        if (f.Writing) Text(x + 10, y, "WRITING", RED);
        // the 40 tracks, with the head
        int ty = y + 11, tw = 7;
        for (int t = 0; t < VzDisk.TRACKS; t++)
        {
            int c = t == f.Track ? (f.Writing ? RED : f.Active ? HI : TXT) : t == f.LastTrack ? 0x805A10 : t == 0 ? 0x284A34 : 0x18301E;
            Fill(5 + t * tw + (t / 10) * 2, ty, tw - 1, 8, c);
        }
        // the track under the head: its 16 sectors in their interleaved order, and where the head is now
        int ry = ty + 12, rw = W - 10;
        double cellUnits = VzDisk.CELL, secUnits = 155 * 8 * cellUnits;
        for (int i = 0; i < 16; i++)
        {
            int x0 = 5 + (int)((cellUnits + i * secUnits) / VzDisk.REV * rw), x1 = 5 + (int)((cellUnits + (i + 1) * secUnits) / VzDisk.REV * rw);
            Fill(x0, ry, x1 - x0 - 1, 10, i % 2 == 0 ? 0x1E4630 : 0x163624);
            Text(x0 + (x1 - x0) / 2 - 5, ry + 2, VzDisk.SectorMap[i].ToString("X"), DIM);
        }
        if (f.Active) { int hx = 5 + (int)(f.Angle * rw); Fill(hx, ry - 2, 2, 14, f.Writing ? RED : AMBER); }
        int y3 = ry + 14;
        x = Text(5, y3, "INVERTER ", DIM); x = Text(x, y3, f.Inverter ? "1" : "0", TXT);
        x = Text(x + 8, y3, "PHASES ", DIM); x = Text(x, y3, Convert.ToString(f.Latch & 15, 2).PadLeft(4, '0'), TXT);
        x = Text(x + 8, y3, "85 RPM  16 X 128 BYTES", DIM);
        y3 += 10;
        x = Text(5, y3, "SHIFTS ", DIM); x = Text(x, y3, f.Reads.ToString(), TXT);
        x = Text(x + 8, y3, "WRITES ", DIM); x = Text(x, y3, f.Writes.ToString(), TXT);
        x = Text(x + 8, y3, "STEPS ", DIM); Text(x, y3, f.Steps.ToString(), TXT);
        for (int d = 0; d < 2; d++)
        {
            y3 += 10; var dk = f.Drive[d];
            x = Text(5, y3, "D" + (d + 1) + " ", DIM);
            string n = dk == null ? "EMPTY" : (dk.Path != null ? Path.GetFileName(dk.Path) : "BLANK DISK").ToUpperInvariant();
            if (n.Length > 34) n = n.Substring(0, 34);
            x = Text(x, y3, n, dk == null ? DIM : TXT);
            if (dk != null) Text(x + 6, y3, (dk.WriteProtect ? "PROTECTED " : "") + (dk.Dirty ? "UNSAVED" : ""), AMBER);
        }
        return y0 + h;
    }

    // ---------------------------------------------------------------- RTTY
    int PRtty(int y0, int avail)
    {
        var r = m.Rtty;
        int h = Math.Min(avail, 15 + 104);
        int y = Panel(y0, h, "RTTY  K-6318", r.Rom != null ? "2125 / 2295 HZ AFSK" : "NO VZRTTY.IC3");
        int x = Text(5, y, "RX ", DIM); x = Text(x, y, r.Loopback ? "LOOPBACK" : r.RxPlaying ? (r.RxName ?? "AUDIO").ToUpperInvariant() : "NO SIGNAL", r.RxPlaying || r.Loopback ? HI : DIM);
        int y2 = y + 10;
        x = Text(5, y2, "PTT ", DIM); x = Text(x, y2, r.Ptt ? "KEYED" : "OFF", r.Ptt ? RED : TXT);
        x = Text(x + 10, y2, "TX ", DIM); x = Text(x, y2, r.TxMark ? "MARK" : "SPACE", r.Ptt ? HI : DIM);
        x = Text(x + 10, y2, "RX ", DIM); Text(x, y2, r.RxMark(m.Cpu.Cyc) ? "MARK" : "SPACE", TXT);
        // the last second of both lines, one column per 3.3 ms (a 45.45 baud bit is about 7 columns)
        int sy = y2 + 14, sw = W - 30;
        Text(5, sy + 3, "RX", CYAN); Text(5, sy + 25, "TX", AMBER);
        Fill(22, sy, sw, 18, 0x081008); Fill(22, sy + 22, sw, 18, 0x081008);
        int prevR = -1, prevT = -1;
        for (int i = 0; i < sw; i++)
        {
            int v = r.Hist[(r.HistPos - sw + i + 2048) & 1023];
            int ry = (v & 1) != 0 ? sy + 3 : sy + 14, tyy = (v & 2) != 0 ? sy + 25 : sy + 36;
            if (prevR >= 0 && prevR != ry) Fill(22 + i, Math.Min(prevR, ry), 1, Math.Abs(prevR - ry) + 1, CYAN); else Px(22 + i, ry, CYAN);
            if ((v & 4) != 0) { if (prevT >= 0 && prevT != tyy) Fill(22 + i, Math.Min(prevT, tyy), 1, Math.Abs(prevT - tyy) + 1, AMBER); else Px(22 + i, tyy, AMBER); }
            if ((v & 8) != 0) Px(22 + i, sy + 17, 0x40A040);
            prevR = ry; prevT = (v & 4) != 0 ? tyy : -1;
        }
        int y4 = sy + 44;
        x = Text(5, y4, "TX BIT CHANGES ", DIM); x = Text(x, y4, r.TxChanges.ToString(), TXT);
        x = Text(x + 8, y4, "RX POLLS ", DIM); Text(x, y4, r.RxReads.ToString(), TXT);
        Text(5, y4 + 10, "MARK HIGH, 1 SECOND ACROSS", DIM);
        return y0 + h;
    }

    // ---------------------------------------------------------------- RS-232
    int PSerial(int y0, int avail)
    {
        var r = m.Ser;
        int h = Math.Min(avail, 15 + 104);
        int y = Panel(y0, h, "RS-232  K-6317", r.Rom == null ? "NO RS232_V15.IC2" : r.Baud + " BAUD " + r.DataBits + r.Parity + r.StopBits);
        int x = Text(5, y, "LINK ", DIM);
        x = Text(x, y, r.LinkName != null ? r.LinkName.ToUpperInvariant() : r.Loopback ? "LOOPBACK" : "NOT CONNECTED", r.LinkName != null || r.Loopback ? HI : DIM);
        int y2 = y + 10;
        x = Text(5, y2, "TXD ", DIM); x = Text(x, y2, r.TxMark ? "MARK" : "SPACE", r.TxMark ? TXT : AMBER);
        x = Text(x + 8, y2, "SENT ", DIM); x = Text(x, y2, r.TxBytes.ToString(), AMBER);
        x = Text(x + 8, y2, "RECEIVED ", DIM); x = Text(x, y2, r.RxBytes.ToString(), CYAN);
        int q = r.RxQueued; if (q > 0) { x = Text(x + 8, y2, "QUEUED ", DIM); Text(x, y2, q.ToString(), TXT); }
        // the last lines of the session: sent in amber, received in cyan
        int y3 = y2 + 14, rows = Math.Max(0, (y0 + h - y3 - 2) / 10), cols = (W - 10) / 6;
        string s; int[] dir;
        lock (r.Session) { s = r.Session.ToString(); dir = r.SessionDir.ToArray(); }
        var lines = new List<KeyValuePair<int, int>>();   // start, length
        int st = 0;
        for (int i = 0; i <= s.Length; i++)
            if (i == s.Length || s[i] == '\n' || i - st >= cols) { lines.Add(new KeyValuePair<int, int>(st, i - st)); st = i < s.Length && s[i] == '\n' ? i + 1 : i; }
        for (int k = Math.Max(0, lines.Count - rows), row = 0; k < lines.Count; k++, row++)
            for (int i = 0; i < lines[k].Value; i++)
            {
                int ci = lines[k].Key + i;
                Text(5 + i * 6, y3 + row * 10, s[ci].ToString().ToUpperInvariant(), dir[ci] != 0 ? AMBER : CYAN);
            }
        return y0 + h;
    }

    // ---------------------------------------------------------------- printer, light pen and tape recorder
    int PIo(int y0, int avail)
    {
        int h = Math.Min(avail, 15 + 104);
        string info = m.WordProOn ? "WORDPRO CARTRIDGE" : m.Exp == MemExp.Ram16K ? "16K RAM PACK" : "NO MEMORY EXPANSION";
        int y = Panel(y0, h, "PRINTER  PEN  TAPE", info);
        var pr = m.Printer;
        bool busy = m.Frames - pr.LastFrame < 25;
        Fill(5, y - 1, 9, 9, !pr.Enabled ? 0x202020 : busy ? 0x40FF40 : 0x104010);
        int x = Text(20, y, pr.Enabled ? "PRINTER" : "NO PRINTER INTERFACE", pr.Enabled ? TXT : DIM);
        if (pr.Enabled)
        {
            x = Text(x + 8, y, "BYTES ", DIM); x = Text(x, y, pr.Bytes.ToString(), TXT);
            x = Text(x + 8, y, "LINES ", DIM); x = Text(x, y, pr.Lines.ToString(), TXT);
            x = Text(x + 8, y, "LATCH $", DIM); Text(x, y, H2(pr.Data), TXT);
        }
        // the paper: the last few lines printed
        int py = y + 12, rows = 5;
        Fill(5, py - 2, W - 10, rows * 10 + 2, 0xE8E4D8);
        var rec = pr.Recent; int n = rec.Count;
        for (int i = 0; i < rows - 1; i++)
        {
            int k = n - (rows - 1) + i; if (k < 0) continue;
            string l = rec[k]; if (l.Length > 50) l = l.Substring(0, 50);
            Text(8, py + i * 10, l.ToUpperInvariant(), 0x202020);
        }
        string part = pr.Partial; if (part.Length > 50) part = part.Substring(part.Length - 50);
        Text(8, py + (rows - 1) * 10, part.ToUpperInvariant(), 0x202020);
        int y3 = py + rows * 10 + 4;
        var pen = m.Pen;
        x = Text(5, y3, "LIGHT PEN ", DIM);
        if (!pen.Enabled) Text(x, y3, "OFF", DIM);
        else
        {
            x = Text(x, y3, pen.OnScreen ? pen.X + "," + pen.Y : "AWAY", pen.OnScreen ? TXT : DIM);
            if (pen.Down) x = Text(x + 8, y3, "PRESSED", AMBER);
            x = Text(x + 8, y3, "READS ", DIM); x = Text(x, y3, pen.Reads.ToString(), TXT);
            x = Text(x + 8, y3, "LIT ", DIM); Text(x, y3, pen.Hits.ToString(), pen.Hits > 0 ? HI : TXT);
        }
        y3 += 10;
        var co = m.CassOut;
        x = Text(5, y3, "TAPE OUT ", DIM);
        if (co.Recording)
        {
            Fill(x, y3 - 1, 7, 7, (m.Frames / 25) % 2 == 0 ? RED : 0x401010);
            x = Text(x + 10, y3, "RECORDING " + ((m.Cpu.Cyc - co.StartCycle) / m.Clock) + " S", RED);
            Text(x + 8, y3, co.Edges + " EDGES", TXT);
        }
        else Text(x, y3, "LATCH BITS 1+2  " + (((m.Latch >> 1) & 3) != 0 ? "HIGH" : "LOW"), TXT);
        return y0 + h;
    }

    int PBennVenn(int y0, int avail)
    {
        if (m.DiskOn) return PDisk(y0, avail);
        if (m.RttyOn) return PRtty(y0, avail);
        if (m.Rs232On) return PSerial(y0, avail);
        if (m.Exp != MemExp.BennVenn) return PIo(y0, avail);
        int h = Math.Min(avail, 15 + 3 * 10 + 8 * 10);
        int y = Panel(y0, h, "BENNVENN SD", "128K + SD CARD");
        int led = T.DosLed;
        Fill(5, y - 1, 9, 9, Lerp(0x301000, 0xFF8A00, led / 255.0));
        int mp = m.Mapper;
        int x = Text(20, y, "PORT 37 $" + H2(mp), TXT);
        x = Text(x + 10, y, "4000: " + ((mp & 1) != 0 ? "DOS RAM " + ((mp >> 1) & 1) : "DOS ROM"), (mp & 1) != 0 ? AMBER : TXT);
        Text(x + 10, y, "EXP BANK " + ((mp >> 2) & 1), TXT);
        int y2 = y + 10;
        x = Text(5, y2, "VZ300 MODE ", DIM); x = Text(x, y2, m.Vz300Mode ? "ON" : "OFF", TXT);
        if (!m.RealDos)
        {
            x = Text(x + 10, y2, "OPENS ", DIM); x = Text(x, y2, m.DosOpens.ToString(), TXT);
            x = Text(x + 10, y2, "SECTORS ", DIM); Text(x, y2, m.DosSectors + " (" + (m.DosSectors / 2) + "K)", TXT);
        }
        int y3 = y2 + 12;
        if (m.RealDos)
        {
            // the real VZDOS is running: show the SD card traffic instead of the emulator's DOS log
            var c = m.Card;
            x = Text(5, y3, "REAL VZDOS: ", DIM); Text(x, y3, m.VzdosFile != null ? Path.GetFileName(m.VzdosFile) : "VZDOS.VZ", AMBER); y3 += 10;
            if (c != null)
            {
                x = Text(5, y3, "SPI SD CARD  SECTORS READ ", DIM); x = Text(x, y3, c.Reads.ToString(), TXT);
                x = Text(x + 8, y3, "WRITTEN ", DIM); Text(x, y3, c.Writes.ToString(), TXT); y3 += 10;
                x = Text(5, y3, "FAT32 IMAGE OF ", DIM); Text(x, y3, c.FileCount + " FILES", TXT); y3 += 10;
                string root = c.Root; if (root.Length > 51) root = "..." + root.Substring(root.Length - 48);
                Text(5, y3, root.ToUpperInvariant(), DIM);
            }
            return y0 + h;
        }
        var log = m.DosLog;
        int rows = Math.Max(0, (y0 + h - y3 - 2) / 10);
        int first = Math.Max(0, log.Count - rows);
        for (int i = first; i < log.Count; i++)
        {
            string s = log[i]; if (s.Length > 51) s = s.Substring(0, 51);
            Text(5, y3, s, i == log.Count - 1 ? HI : DIM); y3 += 10;
        }
        if (log.Count == 0) Text(5, y3, "NO SD ACCESS YET", DIM);
        return y0 + h;
    }
}
