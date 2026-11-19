// VZ300 + BennVenn SD loader / 128K test harness for OVERRIDE.
// Modelled on the vzemu.c harness used by the other VZ games (same memory
// map, port $37 banking, DOS file-call traps at $5F00/$5F03/$5F09, field-sync
// INT), rewritten in C# so it builds with the csc that ships with Windows.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

public static class VzEmu
{
    const int LINES = 312, LINET = 228, FRAMET = LINES * LINET;
    const int FSLINES = 56;            // INT / FS low for the first 56 lines of a field
    static int TOPBORDER = 25;         // lines between the end of FS and the first picture line
    static int PICSTART { get { return FSLINES + TOPBORDER; } }

    static byte[] ram = new byte[0x10000];
    static byte[] bv = new byte[0x20000];
    static int mapper = 0, latch = 0;
    static int[] keys = new int[8];
    static int[] joy = { 0xFF, 0xFF, 0xFF, 0xFF };
    static Z80 cpu = new Z80();
    static long fstart = 0; static long frames = 0;
    static bool fsLow = false;
    static string sddir = ".";
    static FileStream sdf = null;
    static Dictionary<string, int> sym = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    static Dictionary<int, string> symRev = new Dictionary<int, string>();

    // diagnostics
    static long snowCount = 0; static int snowFirstPc = -1; static long snowFirstFrame = 0; static int snowMaxLine = 0;
    static int[] snowLineHist = new int[LINES];
    static bool crashCheck = false; static bool crashed = false;
    static int codeLo = 0x8000, codeHi = 0xB800; static int sprLo = 0, sprHi = 0;
    static int[] ringPc = new int[4096]; static int ringPos = 0;
    static int tmarkAddr = -1; static long tmarkLast = -1; static int[] tmarkHist = new int[16];
    static long[] prof = null;
    static int curPc;
    static int minSp = 0xFFFF;
    static int spLo = 0x7C00, spHi = 0x8000;
    static long dosCalls = 0;
    static int lastLatch = 0;
    static bool quiet = false;

    // wav
    static BinaryWriter wav = null; static long wavN = 0; static double wavAcc = 0, wavHi = 0; static long wavLastT = 0;

    static long Now { get { return cpu.Cyc; } }
    static int Line { get { return (int)((cpu.Cyc - fstart) / LINET); } }

    static int Bv(int a)
    {
        if (a >= 0x4000 && a < 0x6800) return ((mapper & 2) != 0 ? 0x8000 : 0) + (a - 0x4000);
        if (a >= 0xB800) return ((mapper & 4) != 0 ? 0x18000 : 0x10000) + (a & 0x7FFF);
        return -1;
    }

    static void VideoAccess()
    {
        int ln = Line;
        if (ln >= PICSTART && ln < PICSTART + 192)
        {
            snowCount++; snowLineHist[ln]++;
            if (snowFirstPc < 0) { snowFirstPc = curPc; snowFirstFrame = frames; }
            if (ln > snowMaxLine) snowMaxLine = ln;
        }
    }

    static int Rd(int a)
    {
        if (a < 0x4000) { if (a == 0x38) return 0xFB; if (a == 0x39) return 0xED; if (a == 0x3A) return 0x4D; return 0xFF; }
        if (a < 0x6800) { if ((mapper & 1) != 0) return bv[Bv(a)]; return 0xFF; }
        if (a < 0x7000)
        {
            int r = 0x3F, lo = a & 0xFF;
            for (int i = 0; i < 8; i++) if ((lo & (1 << i)) == 0) r &= keys[i];
            r |= 0x40; if (!fsLow) r |= 0x80;
            return r;
        }
        if (a < 0x7800) { VideoAccess(); return ram[a]; }
        if (a < 0xB800) return ram[a];
        return bv[Bv(a)];
    }

    static void Wr(int a, int v)
    {
        if (a == tmarkAddr)
        {
            long t = Now;
            if (tmarkLast >= 0) { int f = (int)((t - tmarkLast + FRAMET / 2) / FRAMET); if (f > 15) f = 15; tmarkHist[f]++; }
            tmarkLast = t;
        }
        if (a < 0x4000) return;
        if (a < 0x6800) { bv[Bv(a)] = (byte)v; return; }
        if (a < 0x7000) { SpeakerTo(v); latch = v; return; }
        if (a < 0x7800) { VideoAccess(); ram[a] = (byte)v; return; }
        if (a < 0xB800) { ram[a] = (byte)v; return; }
        bv[Bv(a)] = (byte)v;
    }

    static int In(int port)
    {
        int lo = port & 0xFF;
        if (lo >= 0x20 && lo <= 0x2F)
        {
            int r = 0xFF;
            if ((lo & 1) == 0) r &= joy[0];
            if ((lo & 2) == 0) r &= joy[1];
            if ((lo & 4) == 0) r &= joy[2];
            if ((lo & 8) == 0) r &= joy[3];
            return r;
        }
        return 0xFF;
    }
    static void Out(int port, int v) { if ((port & 0xFF) == 0x37) mapper = v; }

    // ---- speaker -> wav (44.1 kHz, box filtered)
    static int SpkLevel(int v) { return ((v >> 5) & 1) - (v & 1); } // -1, 0, +1
    static void SpeakerTo(int v)
    {
        if (wav != null) WavAdvance(Now);
        lastLatch = v;
    }
    const double TPS = 3546875.0 / 44100.0;
    static double wavNext;
    static void WavAdvance(long t)
    {
        double lvl = SpkLevel(lastLatch);
        double cur = wavLastT;
        while (t >= wavNext)
        {
            wavHi += lvl * (wavNext - cur);
            wav.Write((short)(wavHi / TPS * 14000)); wavN++;
            wavHi = 0; cur = wavNext; wavNext += TPS;
        }
        wavHi += lvl * (t - cur); wavLastT = t;
    }

    // ---- DOS trap
    static void DosTrap()
    {
        int pc = cpu.PC;
        int buf = Rd(0xFB80) | (Rd(0xFB81) << 8);
        if (pc == 0x5F00)
        {
            var sb = new StringBuilder(); int p = (cpu.H << 8) | cpu.L; if (Rd(p) == '"') p++;
            for (int n = 0; n < 60; n++) { int c = Rd(p++ & 0xFFFF); if (c == '"' || c == 0) break; sb.Append((char)c); }
            string fn = Path.Combine(sddir, sb.ToString() + ".DAT");
            if (sdf != null) sdf.Close();
            sdf = File.Exists(fn) ? File.OpenRead(fn) : null;
            Wr(0xFB03, sdf != null ? 1 : 0); Wr(0xFB05, 0);
            if (!quiet) Console.Error.WriteLine("DOS open {0} -> {1} (frame {2}, SP {3:X4})", fn, sdf != null ? "ok" : "MISSING", frames, cpu.SP);
            dosCalls++;
        }
        else
        {
            byte[] d = new byte[512]; if (sdf != null) sdf.Read(d, 0, 512);
            for (int i = 0; i < 512; i++) Wr((buf + i) & 0xFFFF, d[i]);
        }
        // the real DOS uses its own stack below the caller's SP and the system area
        if (Environment.GetEnvironmentVariable("DOSSCRIBBLE") != null)
        {
            var rnd = new Random((int)frames);
            for (int i = 1; i <= 1536; i++) Wr((cpu.SP - 2 - i) & 0xFFFF, rnd.Next(256));
            for (int a = 0x7AF8; a < 0x7C00; a++) Wr(a, rnd.Next(256));
        }
        cpu.Cyc += 200000; // a sector read takes a while
        int r = Rd(cpu.SP) | (Rd((cpu.SP + 1) & 0xFFFF) << 8); cpu.SP = (cpu.SP + 2) & 0xFFFF; cpu.PC = r;
    }

    // ---- one instruction; returns false at a frame boundary
    static bool StepOne()
    {
        if (cpu.Cyc - fstart >= FRAMET) { fstart += FRAMET; frames++; return false; }
        int line = Line;
        fsLow = line < FSLINES;
        cpu.IntLine = fsLow;
        curPc = cpu.PC;
        if ((mapper & 2) == 0 && (curPc == 0x5F00 || curPc == 0x5F03 || curPc == 0x5F09)) { DosTrap(); return true; }
        if (crashCheck && !crashed)
        {
            ringPc[ringPos] = curPc | (cpu.SP << 16); ringPos = (ringPos + 1) & 4095;
            bool bad = false;
            if (curPc < 0x4000 && curPc != 0x38 && curPc != 0x39 && curPc != 0x3A) bad = true;
            if (curPc >= 0x6800 && curPc < 0x7C00) bad = true;
            if (cpu.SP >= 0x7000 && cpu.SP < spLo - 0x80 && curPc < 0xB800 && !(curPc >= 0x5F00 && curPc < 0x6800) && !(curPc >= sprLo && curPc < sprHi)) bad = true;
            if (bad)
            {
                crashed = true;
                Console.Error.WriteLine("CRASH? pc={0:X4} sp={1:X4} frame {2}", curPc, cpu.SP, frames);
                using (var w = new StreamWriter("crash.txt"))
                    for (int i = 0; i < 4096; i++) { int k = (ringPos + i) & 4095; w.WriteLine("{0:X4} SP={1:X4} {2}", ringPc[k] & 0xFFFF, (ringPc[k] >> 16) & 0xFFFF, Near(ringPc[k] & 0xFFFF)); }
            }
        }
        if (cpu.SP >= spLo && cpu.SP < spHi && cpu.SP < minSp) minSp = cpu.SP;
        long c0 = cpu.Cyc;
        cpu.Step();
        if (prof != null) prof[curPc] += cpu.Cyc - c0;
        return true;
    }
    static void RunFrames(long n) { long t = frames + n; while (frames < t) StepOne(); }

    static string Near(int a)
    {
        string best = null; int bv2 = -1;
        foreach (var kv in sym) if (kv.Value <= a && kv.Value > bv2 && a - kv.Value < 0x800) { bv2 = kv.Value; best = kv.Key; }
        return best == null ? "" : best + "+" + (a - bv2);
    }

    // ---- screen
    static readonly int[,] pal = {
        {0x30,0xd2,0x00},{0xc1,0xe5,0x00},{0x4c,0x3a,0xb4},{0x9a,0x32,0x36},
        {0xbf,0xc8,0xad},{0x41,0xaf,0x71},{0xc8,0x4e,0xf0},{0xd4,0x7f,0x00} };
    static void SaveScreen(string fn, int scale)
    {
        int mode = (latch >> 3) & 1, css = (latch >> 4) & 1;
        var bmp = new Bitmap(256 * scale, 192 * scale, PixelFormat.Format24bppRgb);
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var bd = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
        byte[] px = new byte[bd.Stride * bmp.Height];
        for (int y = 0; y < 192; y++) for (int x = 0; x < 256; x++)
            {
                int r, g, b;
                if (mode == 1)
                {
                    int vy = y / 3, vx = x / 2; int by = ram[0x7000 + vy * 32 + vx / 4];
                    int c = ((by >> (6 - 2 * (vx & 3))) & 3) + (css != 0 ? 4 : 0);
                    r = pal[c, 0]; g = pal[c, 1]; b = pal[c, 2];
                }
                else
                {
                    int cy = y / 12, cx = x / 8; int by = ram[0x7000 + cy * 32 + cx]; int ry = y % 12, rx = x % 8;
                    if ((by & 0x80) != 0)
                    {
                        int q = (ry < 6 ? 0 : 2) + (rx < 4 ? 0 : 1); bool on = ((by >> (3 - q)) & 1) != 0; int fg = (by >> 4) & 7;
                        if (on) { r = pal[fg, 0]; g = pal[fg, 1]; b = pal[fg, 2]; } else { r = g = b = 0x10; }
                    }
                    else
                    {
                        bool on = false; int ch = by & 63;
                        if (ry >= 3 && ry < 10 && rx >= 1 && rx < 6) on = ((Font6847.F[ch, ry - 3] >> (4 - (rx - 1))) & 1) != 0;
                        if (((by >> 6) & 1) != 0) on = !on;
                        if (on) { r = css != 0 ? 0xff : 0x30; g = css != 0 ? 0xb7 : 0xd2; b = 0; } else { r = css != 0 ? 0x6b : 0; g = css != 0 ? 0x27 : 0x7c; b = 0; }
                    }
                }
                for (int sy = 0; sy < scale; sy++) for (int sx = 0; sx < scale; sx++)
                    {
                        int o = (y * scale + sy) * bd.Stride + (x * scale + sx) * 3;
                        px[o] = (byte)b; px[o + 1] = (byte)g; px[o + 2] = (byte)r;
                    }
            }
        System.Runtime.InteropServices.Marshal.Copy(px, 0, bd.Scan0, px.Length);
        bmp.UnlockBits(bd);
        bmp.Save(fn, ImageFormat.Png);
        bmp.Dispose();
    }

    static void LoadVz(string fn)
    {
        byte[] d = File.ReadAllBytes(fn);
        int start = d[22] | (d[23] << 8);
        for (int i = 24; i < d.Length; i++) Wr((start + i - 24) & 0xFFFF, d[i]);
        Console.Error.WriteLine("loaded {0} start {1:X4} end {2:X4}", fn, start, start + d.Length - 24);
        cpu.PC = start;
    }

    static readonly string[,] KROWS = {
        {"T","W","","E","Q","R"},{"G","S","CTRL","D","A","F"},{"B","X","SHIFT","C","Z","V"},{"5","2","","3","1","4"},
        {"N",".","",",","SPACE","M"},{"6","9","-","8","0","7"},{"Y","O","RETURN","I","P","U"},{"H","L",":","K",";","J"} };
    static void SetKey(string k, bool down)
    {
        for (int r = 0; r < 8; r++) for (int b = 0; b < 6; b++)
                if (KROWS[r, b].Length > 0 && KROWS[r, b] == k.ToUpper()) { if (down) keys[r] &= ~(1 << b); else keys[r] |= 1 << b; return; }
        Console.Error.WriteLine("unknown key " + k);
    }

    static int Num(string s)
    {
        int plus = s.IndexOf('+', 1);
        if (plus > 0) return Num(s.Substring(0, plus)) + Num(s.Substring(plus + 1));
        if (sym.ContainsKey(s)) return sym[s];
        if (s.StartsWith("$")) return Convert.ToInt32(s.Substring(1), 16);
        if (s.StartsWith("0x")) return Convert.ToInt32(s.Substring(2), 16);
        return int.Parse(s);
    }

    static void WavEnd()
    {
        if (wav == null) return;
        var s = wav.BaseStream; long n = wavN;
        s.Seek(0, SeekOrigin.Begin);
        var w = new BinaryWriter(s);
        w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write((int)(36 + n * 2)); w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
        w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(44100); w.Write(88200); w.Write((short)2); w.Write((short)16);
        w.Write(Encoding.ASCII.GetBytes("data")); w.Write((int)(n * 2));
        w.Flush(); s.Close(); wav = null;
    }

    public static int Main(string[] args)
    {
        if (args.Length < 1) { Console.Error.WriteLine("vzemu script.txt"); return 1; }
        for (int i = 0; i < 8; i++) keys[i] = 0x3F;
        string rr = Environment.GetEnvironmentVariable("RANDRAM");
        if (rr != null) { var rnd = new Random(int.Parse(rr)); for (int i = 0x7800; i < 0x10000; i++) ram[i] = (byte)rnd.Next(256); for (int i = 0; i < bv.Length; i++) bv[i] = (byte)rnd.Next(256); }
        cpu.Rd = Rd; cpu.Wr = Wr; cpu.In = In; cpu.Out = Out;
        cpu.SP = 0xB7F0; cpu.IM = 1;
        var lines = File.ReadAllLines(args[0]);
        var randGen = new Random(1);
        foreach (var raw in lines)
        {
            string ln = raw.Trim(); if (ln.Length == 0 || ln.StartsWith(";") || ln.StartsWith("#")) continue;
            var a = ln.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            string cmd = a[0].ToLower();
            string a1 = a.Length > 1 ? a[1] : "", a2 = a.Length > 2 ? a[2] : "";
            switch (cmd)
            {
                case "vz": LoadVz(a1); break;
                case "sd": sddir = a1; break;
                case "sym":
                    foreach (var sl in File.ReadAllLines(a1)) { var p = sl.Split(' '); if (p.Length >= 2) { int v = Convert.ToInt32(p[0], 16); sym[p[1]] = v; } }
                    break;
                case "frames": RunFrames(Num(a1)); break;
                case "seconds": RunFrames(Num(a1) * 50); break;
                case "down": SetKey(a1, true); break;
                case "up": SetKey(a1, false); break;
                case "tap": SetKey(a1, true); RunFrames(a2 != "" ? Num(a2) : 4); SetKey(a1, false); RunFrames(4); break;
                case "joy": joy[Num(a1)] = Convert.ToInt32(a2, 16); break;
                case "screen": SaveScreen(a1, a2 != "" ? Num(a2) : 1); break;
                case "shots": // shots prefix count every
                    { int n = Num(a2), ev = a.Length > 3 ? Num(a[3]) : 25; for (int i = 0; i < n; i++) { RunFrames(ev); SaveScreen(a1 + i.ToString("D3") + ".png", 1); } }
                    break;
                case "wav": wav = new BinaryWriter(File.Create(a1)); wav.Write(new byte[44]); wavN = 0; wavLastT = Now; wavNext = Now + TPS; wavHi = 0; break;
                case "wavend": if (wav != null) WavAdvance(Now); WavEnd(); break;
                case "regs":
                    Console.Error.WriteLine("frame {0} line {1} map {2:X2} latch {3:X2} PC={4:X4} {13} SP={5:X4} AF={6:X2}{7:X2} BC={8:X4} DE={9:X4} HL={10:X4} IX={11:X4} IY={12:X4} IFF1={14}",
                        frames, Line, mapper, latch, cpu.PC, cpu.SP, cpu.A, cpu.F, (cpu.B << 8) | cpu.C, (cpu.D << 8) | cpu.E, (cpu.H << 8) | cpu.L, cpu.IX, cpu.IY, Near(cpu.PC), cpu.IFF1);
                    break;
                case "poke": Wr(Num(a1), Num(a2)); break;
                case "peek":
                    { int ad = Num(a1), n = a2 != "" ? Num(a2) : 1; var sb = new StringBuilder(); sb.AppendFormat("{0} {1:X4}:", a1, ad); for (int i = 0; i < n; i++) sb.AppendFormat(" {0:X2}", Rd((ad + i) & 0xFFFF)); Console.WriteLine(sb.ToString()); }
                    break;
                case "peekw": { int ad = Num(a1); Console.WriteLine("{0} = {1}", a1, Rd(ad) | (Rd(ad + 1) << 8)); } break;
                case "dump": { var d = new byte[65536]; for (int i = 0; i < 65536; i++) d[i] = (byte)Rd(i); File.WriteAllBytes(a1, d); } break;
                case "rand": // rand frames seed : random play keys
                    {
                        int n = Num(a1); var rnd = new Random(a2 != "" ? Num(a2) : 1);
                        string[] ks = { "SPACE", "Q", "A", "O", "P" };
                        for (int i = 0; i < n; i += 8) { for (int k = 0; k < 5; k++) SetKey(ks[k], rnd.Next(3) == 0 || (k == 0 && rnd.Next(4) == 0)); RunFrames(8); }
                        for (int k = 0; k < 5; k++) SetKey(ks[k], false);
                    }
                    break;
                case "crash": crashCheck = true; break;
                case "spok": sprLo = Num(a1); sprHi = Num(a2); break;
                case "stack": spLo = Num(a1); spHi = Num(a2); break;
                case "quiet": quiet = true; break;
                case "topborder": TOPBORDER = Num(a1); break;
                case "snowreset": snowCount = 0; snowFirstPc = -1; snowMaxLine = 0; Array.Clear(snowLineHist, 0, LINES); break;
                case "snow":
                    Console.WriteLine("snow: {0} video accesses during the picture{1}", snowCount,
                        snowCount > 0 ? string.Format(" (first at PC {0:X4} {1}, frame {2}; last line {3})", snowFirstPc, Near(snowFirstPc), snowFirstFrame, snowMaxLine) : "");
                    break;
                case "tmark": tmarkAddr = Num(a1); tmarkLast = -1; Array.Clear(tmarkHist, 0, 16); break;
                case "tstats":
                    {
                        long tot = 0; for (int i = 0; i < 16; i++) tot += tmarkHist[i];
                        var sb = new StringBuilder("fields per frame:"); for (int i = 0; i < 16; i++) if (tmarkHist[i] > 0) sb.AppendFormat("  {0}:{1:F1}%", i, 100.0 * tmarkHist[i] / Math.Max(1, tot));
                        Console.WriteLine(sb.ToString() + "  (" + tot + " frames)");
                    }
                    break;
                case "prof": prof = Num(a1) != 0 ? new long[65536] : null; break;
                case "profsave":
                    {
                        // aggregate by symbol
                        var agg = new Dictionary<string, long>(); long tot = 0;
                        for (int i = 0; i < 65536; i++) if (prof[i] > 0) { string n = Near(i); int plus = n.IndexOf('+'); if (plus > 0) n = n.Substring(0, plus); if (n == "") n = i.ToString("X4"); long v; agg.TryGetValue(n, out v); agg[n] = v + prof[i]; tot += prof[i]; }
                        var l = new List<KeyValuePair<string, long>>(agg); l.Sort((x, y) => y.Value.CompareTo(x.Value));
                        using (var w = new StreamWriter(a1)) foreach (var kv in l) w.WriteLine("{0,8:F2}% {1,12} {2}", 100.0 * kv.Value / tot, kv.Value, kv.Key);
                    }
                    break;
                case "until": // until addr maxframes
                    {
                        int pc = Num(a1); long mx = frames + (a2 != "" ? Num(a2) : 500); bool hit = false;
                        while (frames < mx) { StepOne(); if (cpu.PC == pc) { hit = true; break; } }
                        Console.Error.WriteLine("until {0}: {1} at frame {2}", a1, hit ? "reached" : "NOT reached", frames);
                    }
                    break;
                case "untilmem": // untilmem addr value maxframes
                    {
                        int ad = Num(a1), v = Num(a2); long mx = frames + (a.Length > 3 ? Num(a[3]) : 500); bool hit = false;
                        while (frames < mx) { RunFrames(1); if (Rd(ad) == v) { hit = true; break; } }
                        Console.Error.WriteLine("untilmem {0}={1}: {2} at frame {3}", a1, a2, hit ? "reached" : "NOT reached", frames);
                    }
                    break;
                case "print": Console.WriteLine(ln.Substring(5).Trim()); break;
                case "minsp": Console.WriteLine("min SP {0:X4}", minSp); break;
                case "frame": Console.WriteLine("frame {0}", frames); break;
                default: Console.Error.WriteLine("?? " + cmd); break;
            }
            if (crashed) { Console.Error.WriteLine("stopping: crash"); break; }
        }
        if (wav != null) WavEnd();
        Console.Error.WriteLine("done at frame {0}; min SP {1:X4}; snow {2}", frames, minSp, snowCount);
        return crashed ? 2 : 0;
    }
}
