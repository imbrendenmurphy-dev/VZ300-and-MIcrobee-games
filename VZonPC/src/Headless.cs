// VZonPC headless runner: scripted tests, screenshots, WAV capture, profiling, crash checks.
// Script commands are compatible with the per-game vzemu harnesses used for earlier VZ games.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

public sealed class Headless
{
    readonly VzMachine m = new VzMachine();
    VzVis vis;
    Z80 cpu { get { return m.Cpu; } }
    readonly Dictionary<string, int> sym = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    bool booted = false;
    string baseDir = ".";

    // diagnostics
    bool crashCheck = false, crashed = false;
    int sprLo = 0, sprHi = 0;
    int[] ringPc = new int[4096]; int ringPos = 0;
    int tmarkAddr = -1; long tmarkLast = -1; int[] tmarkHist = new int[16];
    long[] prof = null; long profC0;
    int minSp = 0xFFFF, spLo = 0x7C00, spHi = 0x8000;
    bool romTrap = false;
    List<int[]> watches = new List<int[]>();   // lo, hi

    // wav
    BinaryWriter wav = null; long wavN = 0; double wavAcc = 0, wavNext, tps; long wavLastT; int wavLatch;

    public Headless()
    {
        m.UseRom = false;      // tests are deterministic and ROM-free unless "rom auto" is given
        m.AudioOn = false;
        m.Quiet = false;
        m.Log = s => Console.Error.WriteLine(s);
        m.PreStep = PreStep;
        m.WriteHook = WriteHook;
    }

    void Boot()
    {
        if (booted) return;
        string rr = Environment.GetEnvironmentVariable("RANDRAM");
        m.PowerOn(rr != null ? int.Parse(rr) : -1);
        if (m.HasRom) m.RunFrames(100);
        if (!m.HasRom) { m.Cpu.SP = 0xB7F0; m.Cpu.IM = 1; }   // with a ROM, BASIC (or VZDOS) owns the stack
        if (m.Exp == MemExp.BennVenn && !m.RealDos) { m.Mapper = 1; m.Vz300Mode = m.Model == Model.VZ300; }
        if (Environment.GetEnvironmentVariable("DOSSCRIBBLE") != null) m.OnDosCall = DosScribble;
        booted = true;
    }

    void DosScribble()
    {
        var rnd = new Random((int)m.Frames);
        for (int i = 1; i <= 1536; i++) m.Wr((cpu.SP - 2 - i) & 0xFFFF, rnd.Next(256));
        for (int a = 0x7AF8; a < 0x7C00; a++) m.Wr(a, rnd.Next(256));
    }

    bool ringOn;
    bool PreStep()
    {
        int pc = m.CurPc;
        if (prof != null) { profC0 = cpu.Cyc; }
        if (ringOn && !crashCheck) { ringPc[ringPos] = pc | (cpu.SP << 16); ringPos = (ringPos + 1) & 4095; }
        if (crashCheck && !crashed)
        {
            ringPc[ringPos] = pc | (cpu.SP << 16); ringPos = (ringPos + 1) & 4095;
            bool bad = false;
            if (pc < 0x4000 && !(pc >= 0x38 && pc <= 0x3A) && !m.HasRom) bad = true;
            if (pc >= 0x6800 && pc < 0x7C00) bad = true;
            if (cpu.SP >= 0x7000 && cpu.SP < spLo - 0x80 && pc < 0xB800 && !(pc >= 0x5F00 && pc < 0x6800) && !(pc >= sprLo && pc < sprHi)) bad = true;
            if (bad)
            {
                crashed = true;
                Console.Error.WriteLine("CRASH? pc={0:X4} sp={1:X4} frame {2}", pc, cpu.SP, m.Frames);
                using (var w = new StreamWriter(Path.Combine(baseDir, "crash.txt")))
                    for (int i = 0; i < 4096; i++) { int k = (ringPos + i) & 4095; w.WriteLine("{0:X4} SP={1:X4} {2}", ringPc[k] & 0xFFFF, (ringPc[k] >> 16) & 0xFFFF, Near(ringPc[k] & 0xFFFF)); }
                return false;
            }
        }
        if (romTrap && !crashed && pc < 0x4000 && pc != 0x38 && pc != 0x39 && pc != 0x3A && pc != 0x66)
        {
            crashed = true; Console.Error.WriteLine("ROMTRAP: jump into ROM at {0:X4} (frame {1}, SP {2:X4})", pc, m.Frames, cpu.SP); return false;
        }
        if (cpu.SP >= spLo && cpu.SP < spHi && cpu.SP < minSp) minSp = cpu.SP;
        return true;
    }

    void WriteHook(int a, int v)
    {
        if (a == tmarkAddr)
        {
            long t = cpu.Cyc;
            if (tmarkLast >= 0) { int f = (int)((t - tmarkLast + VzMachine.FRAMET / 2) / VzMachine.FRAMET); if (f > 15) f = 15; tmarkHist[f]++; }
            tmarkLast = t;
        }
        foreach (var wr in watches)
            if (a >= wr[0] && a <= wr[1])
            {
                long rel = cpu.Cyc - m.FrameStart;   // the end of the instruction doing the write
                Console.Error.WriteLine("write {0:X4}={1:X2} pc={2:X4} {3} frame {4} line {5} t {6}", a, v & 255, m.CurPc, Near(m.CurPc), m.Frames, rel / VzMachine.LINET, rel % VzMachine.LINET);
            }
    }

    // run with optional profiling
    void Step()
    {
        if (prof == null) { m.StepOne(); return; }
        int pc = cpu.PC; long c0 = cpu.Cyc;
        m.StepOne();
        prof[pc] += cpu.Cyc - c0;
    }
    void RunFrames(long n) { long t = m.Frames + n; while (m.Frames < t && !crashed) Step(); }

    string Near(int a)
    {
        string best = null; int bv2 = -1;
        foreach (var kv in sym) if (kv.Value <= a && kv.Value > bv2 && a - kv.Value < 0x800) { bv2 = kv.Value; best = kv.Key; }
        return best == null ? "" : best + "+" + (a - bv2);
    }

    int Num(string s)
    {
        int plus = s.IndexOf('+', 1);
        if (plus > 0) return Num(s.Substring(0, plus)) + Num(s.Substring(plus + 1));
        int v; if (sym.TryGetValue(s, out v)) return v;
        if (s.StartsWith("$")) return Convert.ToInt32(s.Substring(1), 16);
        if (s.StartsWith("0x") || s.StartsWith("0X")) return Convert.ToInt32(s.Substring(2), 16);
        if (s.EndsWith("h") || s.EndsWith("H")) return Convert.ToInt32(s.Substring(0, s.Length - 1), 16);
        return int.Parse(s);
    }

    void SetKey(string k, bool down)
    {
        string K = k.ToUpperInvariant();
        if (K.StartsWith("J1") || K.StartsWith("J2"))
        {
            int j = K[1] == '1' ? 0 : 2; string w = K.Substring(2); int bit = -1, idx = j;
            if (w == "UP") bit = 1; else if (w == "DOWN") bit = 2; else if (w == "LEFT") bit = 4; else if (w == "RIGHT") bit = 8; else if (w == "FIRE") bit = 16; else if (w == "ARM") { bit = 16; idx = j + 1; }
            if (bit > 0) { if (down) m.Joy[idx] &= ~bit; else m.Joy[idx] |= bit; return; }
        }
        if (!m.SetKey(K, down)) Console.Error.WriteLine("unknown key " + k);
    }

    public void SaveScreen(string fn, int scale, bool border)
    {
        int w, h; int[] px = m.Snapshot(border, out w, out h);
        SavePng(fn, px, w, h, scale);
    }
    public static void SavePng(string fn, int[] src, int w, int h, int scale)
    {
        if (scale < 1) scale = 1;
        var bmp = new Bitmap(w * scale, h * scale, PixelFormat.Format32bppRgb);
        var bd = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.WriteOnly, PixelFormat.Format32bppRgb);
        int[] dst = new int[bmp.Width * bmp.Height];
        for (int y = 0; y < bmp.Height; y++) for (int x = 0; x < bmp.Width; x++) dst[y * bmp.Width + x] = src[(y / scale) * w + x / scale];
        System.Runtime.InteropServices.Marshal.Copy(dst, 0, bd.Scan0, dst.Length);
        bmp.UnlockBits(bd);
        string dir = Path.GetDirectoryName(Path.GetFullPath(fn)); if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        bmp.Save(fn, ImageFormat.Png); bmp.Dispose();
    }

    // ---- WAV (44.1 kHz mono, box filtered)
    void WavStart(string fn)
    {
        wav = new BinaryWriter(File.Create(fn)); wav.Write(new byte[44]); wavN = 0;
        tps = (double)m.Clock / 44100.0; wavLastT = cpu.Cyc; wavNext = cpu.Cyc + tps; wavAcc = 0; wavLatch = m.LastLatch;
        m.SpeakerHook = (t, v) => { WavAdvance(t); wavLatch = v; };
    }
    void WavAdvance(long t)
    {
        double lvl = (wavLatch & 1) - ((wavLatch >> 5) & 1);
        double cur = wavLastT;
        while (t >= wavNext)
        {
            wavAcc += lvl * (wavNext - cur);
            wav.Write((short)(wavAcc / tps * 14000)); wavN++;
            wavAcc = 0; cur = wavNext; wavNext += tps;
        }
        wavAcc += lvl * (t - cur); wavLastT = t;
    }
    void WavEnd()
    {
        if (wav == null) return;
        WavAdvance(cpu.Cyc);
        m.SpeakerHook = null;
        var s = wav.BaseStream; long n = wavN;
        s.Seek(0, SeekOrigin.Begin);
        var w = new BinaryWriter(s);
        w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write((int)(36 + n * 2)); w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
        w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(44100); w.Write(88200); w.Write((short)2); w.Write((short)16);
        w.Write(Encoding.ASCII.GetBytes("data")); w.Write((int)(n * 2));
        w.Flush(); s.Close(); wav = null;
    }

    string Regs()
    {
        return string.Format("frame {0} line {1} map {2:X2} latch {3:X2} PC={4:X4} {13} SP={5:X4} AF={6:X2}{7:X2} BC={8:X4} DE={9:X4} HL={10:X4} IX={11:X4} IY={12:X4} IFF1={14} IM={15}",
            m.Frames, m.Line, m.Mapper, m.Latch, cpu.PC, cpu.SP, cpu.A, cpu.F, (cpu.B << 8) | cpu.C, (cpu.D << 8) | cpu.E, (cpu.H << 8) | cpu.L, cpu.IX, cpu.IY, Near(cpu.PC), cpu.IFF1, cpu.IM);
    }

    // ---------------------------------------------------------------- script
    public int RunScript(string path)
    {
        baseDir = Path.GetDirectoryName(Path.GetFullPath(path));
        return RunLines(File.ReadAllLines(path));
    }

    public int RunLines(IEnumerable<string> lines)
    {
        foreach (var raw in lines)
        {
            string ln = raw.Trim(); if (ln.Length == 0 || ln.StartsWith(";") || ln.StartsWith("#")) continue;
            if (!Exec(ln)) break;
            if (crashed) { Console.Error.WriteLine("stopping: crash"); break; }
        }
        if (wav != null) WavEnd();
        m.FlushCard();
        Console.Error.WriteLine("done at frame {0}; min SP {1:X4}; snow {2}", m.Frames, minSp, m.SnowCount);
        return crashed ? 2 : 0;
    }

    void VisOn()
    {
        if (vis != null) return;
        m.Tr = new VzTrace(m); vis = new VzVis(m) { T = m.Tr };
        foreach (var kv in sym) if (!vis.Sym.ContainsKey(kv.Value & 0xFFFF)) vis.Sym[kv.Value & 0xFFFF] = kv.Key.ToUpperInvariant();
    }

    static readonly HashSet<string> configCmds = new HashSet<string> { "machine", "exp", "gfx", "rom", "joyif", "sd", "sym", "quiet", "topborder", "crash", "spok", "stack", "print", "romtrap", "watch", "linelog", "cart", "printer", "lpen" };

    bool Exec(string ln)
    {
        var a = ln.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
        string cmd = a[0].ToLowerInvariant();
        string a1 = a.Length > 1 ? a[1] : "", a2 = a.Length > 2 ? a[2] : "";
        if ((cmd == "sd" || cmd == "vz") && a.Length > 2)
        {
            // paths with spaces: the rest of the line (optionally in quotes)
            a1 = ln.Trim().Substring(a[0].Length).Trim().Trim('"');
        }
        if (!configCmds.Contains(cmd)) Boot();
        switch (cmd)
        {
            // ---- configuration (before the first run command)
            case "machine": m.Model = a1.ToLowerInvariant().Contains("200") ? Model.VZ200 : Model.VZ300; booted = false; break;
            case "exp":
                {
                    string e = a1.ToLowerInvariant();
                    m.Exp = e.StartsWith("b") || e.StartsWith("sd") || e == "128k" ? MemExp.BennVenn : (e.StartsWith("16") ? MemExp.Ram16K : MemExp.None);
                    booted = false;
                }
                break;
            case "cart":
                {
                    string c = a1.ToLowerInvariant();
                    m.Cartridge = c.StartsWith("d") || c.StartsWith("f") ? Cart.Disk : c.StartsWith("rs") || c.StartsWith("se") ? Cart.Rs232
                        : c.StartsWith("r") ? Cart.Rtty : c.StartsWith("w") ? Cart.WordPro : Cart.None;
                    booted = false;
                }
                break;
            case "disk":
                {
                    // disk N FILE: put a disk image in drive 1 or 2 (FILE = blank for a fresh formatted disk)
                    string rest = ln.Trim().Substring(cmd.Length).Trim(); int sp = rest.IndexOf(' ');
                    int n = int.Parse(rest.Substring(0, sp)) - 1; string f = rest.Substring(sp + 1).Trim().Trim('"');
                    var d = f.ToLowerInvariant() == "blank" ? VzDisk.Blank() : VzDisk.Load(f);
                    m.Fdc.Insert(n, d);
                    Console.WriteLine("drive {0}: {1} ({2} files)", n + 1, f, d.Directory().Count);
                }
                break;
            case "diskeject": m.Fdc.Eject(int.Parse(a1) - 1); break;
            case "diskdir":
                {
                    int n = a1 == "" ? 0 : int.Parse(a1) - 1;
                    var d = m.Fdc.Drive[n];
                    if (d == null) Console.WriteLine("drive {0}: empty", n + 1);
                    else Console.WriteLine("drive {0}: {1}", n + 1, string.Join("  ", d.Directory()));
                }
                break;
            case "diskstat":
                Console.WriteLine("disk: track {0} drive {1} latch {2:X2} reads {3} writes {4} steps {5}", m.Fdc.Track, m.Fdc.Selected + 1, m.Fdc.Latch, m.Fdc.Reads, m.Fdc.Writes, m.Fdc.Steps);
                break;
            case "disksave":
                {
                    // disksave N FILE: write drive N's disk to a .dsk
                    string rest = ln.Trim().Substring(cmd.Length).Trim(); int sp = rest.IndexOf(' ');
                    int n = int.Parse(rest.Substring(0, sp)) - 1; string f = rest.Substring(sp + 1).Trim().Trim('"');
                    System.IO.File.WriteAllBytes(f, m.Fdc.Drive[n].ToDsk());
                }
                break;
            case "rttyrx": m.Rtty.PlayRx(ln.Trim().Substring(6).Trim().Trim('"'), m.Cpu.Cyc); Console.WriteLine("rtty: receiving " + a1); break;
            case "rttytx": m.Rtty.RecordTx(ln.Trim().Substring(6).Trim().Trim('"')); break;
            case "rttytxend": m.Rtty.EndRecordTx(); break;
            case "rttyloop": m.Rtty.Loopback = a1 != "off"; break;
            case "rttyinvert": if (a1.Contains("rx")) m.Rtty.RxInvert = !m.Rtty.RxInvert; if (a1.Contains("tx")) m.Rtty.TxInvert = !m.Rtty.TxInvert; break;
            // ---- cassette output
            case "taperec":
                {
                    string f = ln.Trim().Substring(cmd.Length).Trim().Trim('"');
                    m.CassOut.Start(f, m.Cpu.Cyc, m.Clock, m.Latch);
                }
                break;
            case "taperecend": { double s = m.CassOut.Stop(m.Cpu.Cyc); Console.WriteLine("tape: recorded {0:F1} s to {1}", s, m.CassOut.File); } break;
            // ---- printer: printer off | printer FILE (text; the raw bytes go to FILE.prn)
            case "printer":
                {
                    string f = ln.Trim().Substring(cmd.Length).Trim().Trim('"');
                    if (f == "off") m.Printer.Enabled = false;
                    else if (f != "" && f != "on") { m.Printer.Enabled = true; m.Printer.TextPath = f; m.Printer.RawPath = Path.ChangeExtension(f, ".prn"); if (File.Exists(f)) File.Delete(f); if (File.Exists(m.Printer.RawPath)) File.Delete(m.Printer.RawPath); }
                    else m.Printer.Enabled = true;
                }
                break;
            case "bin":
                {
                    // bin FILE ADDR: copy a raw binary into memory without running it (call it with USR, or `until`)
                    var b = File.ReadAllBytes(a1); int ad = Num(a2);
                    for (int i = 0; i < b.Length; i++) m.Wr((ad + i) & 0xFFFF, b[i]);
                    Console.WriteLine("bin: {0} bytes at {1:X4}", b.Length, ad);
                }
                break;
            case "printstat": m.Printer.Close(); Console.WriteLine("printer: {0} bytes, {1} lines", m.Printer.Bytes, m.Printer.Lines); foreach (var l in m.Printer.Recent) Console.WriteLine("  | " + l); break;
            // ---- light pen: lpen on | lpen X Y (pressed at picture pixel X,Y) | lpen hover X Y | lpen up | lpen off
            case "lpen":
                {
                    m.Pen.Enabled = a1 != "off";
                    if (a1 == "up") m.Pen.Down = false;
                    else if (a1 == "hover") { m.Pen.X = Num(a2); m.Pen.Y = Num(a.Length > 3 ? a[3] : "0"); m.Pen.Down = false; }
                    else if (a1 != "" && a1 != "on" && a1 != "off") { m.Pen.X = Num(a1); m.Pen.Y = Num(a2); m.Pen.Down = true; }
                }
                break;
            case "lpenstat": Console.WriteLine("lpen: at {0},{1} {2} reads {3} lit {4}", m.Pen.X, m.Pen.Y, m.Pen.Down ? "pressed" : "up", m.Pen.Reads, m.Pen.Hits); break;
            // ---- RS-232 cartridge
            case "serial":
                {
                    // serial loop | serial send TEXT | serial file FILE | serial connect HOST:PORT|COMn | serial capture FILE | serial baud N
                    string rest = ln.Trim().Substring(cmd.Length).Trim(); int sp = rest.IndexOf(' ');
                    string sub = (sp < 0 ? rest : rest.Substring(0, sp)).ToLowerInvariant(), arg = sp < 0 ? "" : rest.Substring(sp + 1);
                    if (sub == "loop") m.Ser.Loopback = arg != "off";
                    else if (sub == "send") m.Ser.Send(System.Text.Encoding.ASCII.GetBytes(arg.Replace("\\r", "\r").Replace("\\n", "\n")));
                    else if (sub == "file") m.Ser.Send(File.ReadAllBytes(arg.Trim('"')));
                    else if (sub == "connect") m.Ser.Connect(arg);
                    else if (sub == "capture") m.Ser.Capture(arg.Trim('"'));
                    else if (sub == "baud") m.Ser.Baud = Num(arg);
                    else if (sub == "format") { m.Ser.DataBits = arg[0] - '0'; m.Ser.Parity = char.ToUpperInvariant(arg[1]); m.Ser.StopBits = arg[2] - '0'; }
                }
                break;
            case "serialstat":
                Console.WriteLine("serial: {0} baud {1}{2}{3}, tx {4} bytes ({5} changes), rx {6} bytes ({7} queued, {8} reads){9}", m.Ser.Baud, m.Ser.DataBits, m.Ser.Parity, m.Ser.StopBits,
                    m.Ser.TxBytes, m.Ser.TxChanges, m.Ser.RxBytes, m.Ser.RxQueued, m.Ser.RxReads, m.Ser.LinkName != null ? ", linked to " + m.Ser.LinkName : "");
                lock (m.Ser.Session) Console.WriteLine("  session: " + m.Ser.Session.ToString().Replace("\n", "|"));
                break;
            case "rttystat": Console.WriteLine("rtty: tx {0} ptt {1} tx changes {2} rx reads {3}", m.Rtty.TxMark ? "mark" : "space", m.Rtty.Ptt ? "on" : "off", m.Rtty.TxChanges, m.Rtty.RxReads); break;
            case "gfx":
                {
                    string g = a1.ToLowerInvariant();
                    m.Gfx = g.StartsWith("a") || g == "shrg" ? GfxMod.Australian : (g.StartsWith("g") ? GfxMod.German : GfxMod.None);
                    booted = false;
                }
                break;
            case "rom": m.UseRom = a1.ToLowerInvariant() != "none"; if (m.UseRom && a1.ToLowerInvariant() != "auto") VzMachine.RomDir = Path.GetFullPath(a1); booted = false; break;
            case "joyif": m.JoyInterface = a1 != "0" && a1.ToLowerInvariant() != "off"; break;
            case "sd": m.SdDir = Path.GetFullPath(a1); break;
            case "sym":
                foreach (var sl in File.ReadAllLines(a1))
                {
                    var p = sl.Split(new[] { ' ', '\t', '=' }, StringSplitOptions.RemoveEmptyEntries);
                    if (p.Length < 2) continue;
                    int v;
                    try { v = Convert.ToInt32(p[0].TrimStart('$'), 16); sym[p[1]] = v; }
                    catch { try { sym[p[0]] = Num(p[p.Length - 1]); } catch { } }
                }
                break;
            case "quiet": m.Quiet = true; break;
            case "topborder": m.TopBorder = Num(a1); break;
            case "crash": crashCheck = true; break;
            case "romtrap": romTrap = true; break;
            case "spok": sprLo = Num(a1); sprHi = Num(a2); break;
            case "stack": spLo = Num(a1); spHi = Num(a2); break;
            case "watch": watches.Add(new[] { Num(a1), a2 != "" ? Num(a2) : Num(a1) }); break;
            case "linelog": m.DebugLine = a1 == "off" ? -1 : Num(a1); break;
            case "print": Console.WriteLine(ln.Length > 5 ? ln.Substring(5).Trim() : ""); break;

            // ---- running
            case "vz":
                {
                    bool basic; m.LoadVz(a1, out basic);
                    if (vis != null && vis.Sym.Count == 0) vis.FindSymbols(a1);
                    if (basic) { if (m.HasRom) TypeText("RUN\r"); else Console.Error.WriteLine("BASIC program: needs 'rom auto' and a ROM in roms\\"); }
                }
                break;
            case "reset": m.Reset(); break;
            case "tape":
                {
                    // tape FILE.wav [left|right|mix] [invert]: play a WAV into the cassette input from now
                    string[] w = ln.Substring(4).Trim().Split(' ');
                    int chn = 0; bool inv = false; int k = w.Length;
                    while (k > 1 && (w[k - 1] == "left" || w[k - 1] == "right" || w[k - 1] == "mix" || w[k - 1] == "invert"))
                    {
                        k--;
                        if (w[k] == "right") chn = 1; else if (w[k] == "mix") chn = -1; else if (w[k] == "invert") inv = true;
                    }
                    string f = string.Join(" ", w, 0, k).Trim('"');
                    var t = VzTape.Load(f, chn); t.Invert = inv;
                    m.PlayTape(t);
                    Console.Error.WriteLine("tape: {0}, {1} Hz, {2:F1} s", t.Name, t.Rate, t.Seconds);
                }
                break;
            case "tapestop": if (m.Tape != null) m.Tape.Playing = false; break;
            case "tapepos": Console.Error.WriteLine("tape {0:F3} s{1}", m.Tape != null ? m.Tape.Position(cpu.Cyc) : 0, m.Tape != null && m.Tape.Playing ? "" : " (stopped)"); break;
            case "tapeinvert": if (m.Tape != null) m.Tape.Invert = a1 == "on" || (a1 == "" && !m.Tape.Invert); break;
            case "frames": RunFrames(Num(a1)); break;
            case "seconds": RunFrames(Num(a1) * 50); break;
            case "down": SetKey(a1, true); break;
            case "up": SetKey(a1, false); break;
            case "tap": SetKey(a1, true); RunFrames(a2 != "" ? Num(a2) : 4); SetKey(a1, false); RunFrames(4); break;
            case "type": TypeText(ln.Substring(4).TrimStart().Replace("\\r", "\r")); break;
            case "joy": m.Joy[Num(a1)] = Convert.ToInt32(a2.TrimStart('$'), 16); break;
            case "vis":
                // vis on = start tracing; vis FILE [panels] = save the visualiser (1920x1080 with the screen, or the two panels only)
                VisOn();
                if (a1 != "" && a1.ToLowerInvariant() != "on")
                {
                    vis.Render();
                    int vw, vh; int[] sp = m.Snapshot(true, out vw, out vh);
                    int[] img; int iw, ih;
                    if (a2.ToLowerInvariant() == "panels")
                    {
                        iw = VzVis.W * 2; ih = VzVis.H; img = new int[iw * ih];
                        for (int y = 0; y < ih; y++) { Array.Copy(vis.Left, y * VzVis.W, img, y * iw, VzVis.W); Array.Copy(vis.Right, y * VzVis.W, img, y * iw + VzVis.W, VzVis.W); }
                    }
                    else
                    {
                        iw = 1920; ih = 1080; img = new int[iw * ih];
                        int ox = (iw - vw * 4) / 2, oy = (ih - vh * 4) / 2;
                        for (int y = 0; y < ih; y++)
                        {
                            Array.Copy(vis.Left, y * VzVis.W, img, y * iw, VzVis.W);
                            Array.Copy(vis.Right, y * VzVis.W, img, y * iw + iw - VzVis.W, VzVis.W);
                            int sy = y - oy; if (sy < 0 || sy >= vh * 4) continue;
                            for (int x = 0; x < vw * 4; x++) img[y * iw + ox + x] = sp[(sy / 4) * vw + x / 4];
                        }
                    }
                    SavePng(a1, img, iw, ih, 1);
                }
                break;
            case "screen": SaveScreen(a1, a2 != "" ? Num(a2) : 1, a.Length > 3 && a[3] == "border"); break;
            case "shots":
                { int n = Num(a2), ev = a.Length > 3 ? Num(a[3]) : 25; for (int i = 0; i < n; i++) { RunFrames(ev); SaveScreen(a1 + i.ToString("D3") + ".png", 1, false); } }
                break;
            case "wav": WavStart(a1); break;
            case "wavend": WavEnd(); break;
            case "regs": Console.Error.WriteLine(Regs()); break;
            case "poke": m.Wr(Num(a1), Num(a2)); break;
            case "peek":
                { int ad = Num(a1), n = a2 != "" ? Num(a2) : 1; var sb = new StringBuilder(); sb.AppendFormat("{0} {1:X4}:", a1, ad); for (int i = 0; i < n; i++) sb.AppendFormat(" {0:X2}", m.Rd((ad + i) & 0xFFFF)); Console.WriteLine(sb.ToString()); }
                break;
            case "peekw": { int ad = Num(a1); Console.WriteLine("{0} = {1}", a1, m.Rd(ad) | (m.Rd((ad + 1) & 0xFFFF) << 8)); } break;
            case "dump": { var d = new byte[65536]; for (int i = 0; i < 65536; i++) d[i] = (byte)m.Rd(i); File.WriteAllBytes(a1, d); } break;
            case "dumpvram": File.WriteAllBytes(a1, m.Vram); break;
            case "rand":
                {
                    int n = Num(a1); var rnd = new Random(a2 != "" ? Num(a2) : 1);
                    string[] ks = a.Length > 3 ? a[3].Split(',') : new[] { "SPACE", "Q", "A", "O", "P" };
                    for (int i = 0; i < n && !crashed; i += 8) { for (int k = 0; k < ks.Length; k++) SetKey(ks[k], rnd.Next(3) == 0 || (k == 0 && rnd.Next(4) == 0)); RunFrames(8); }
                    for (int k = 0; k < ks.Length; k++) SetKey(ks[k], false);
                }
                break;
            case "snowreset": m.SnowCount = 0; m.SnowFirstPc = -1; m.SnowMaxLine = 0; Array.Clear(m.SnowLineHist, 0, m.SnowLineHist.Length); break;
            case "snow":
                Console.WriteLine("snow: {0} video accesses during the picture{1}", m.SnowCount,
                    m.SnowCount > 0 ? string.Format(" (first at PC {0:X4} {1}, frame {2}; last line {3})", m.SnowFirstPc, Near(m.SnowFirstPc), m.SnowFirstFrame, m.SnowMaxLine) : "");
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
                    var agg = new Dictionary<string, long>(); long tot = 0;
                    for (int i = 0; i < 65536; i++) if (prof[i] > 0) { string n = Near(i); int plus = n.IndexOf('+'); if (plus > 0) n = n.Substring(0, plus); if (n == "") n = i.ToString("X4"); long v; agg.TryGetValue(n, out v); agg[n] = v + prof[i]; tot += prof[i]; }
                    var l = new List<KeyValuePair<string, long>>(agg); l.Sort((x, y) => y.Value.CompareTo(x.Value));
                    using (var w = new StreamWriter(a1)) foreach (var kv in l) w.WriteLine("{0,8:F2}% {1,12} {2}", 100.0 * kv.Value / tot, kv.Value, kv.Key);
                }
                break;
            case "dis":
                {
                    int ad = Num(a1), n = a2 != "" ? Num(a2) : 16;
                    for (int i = 0; i < n; i++)
                    {
                        int len; string t = Z80Dis.Dis(m.Peek, ad, out len);
                        var hx = new System.Text.StringBuilder(); for (int k = 0; k < len; k++) hx.Append(m.Peek((ad + k) & 0xFFFF).ToString("X2"));
                        string nm = Near(ad);
                        Console.WriteLine("{0:X4}  {1,-9} {2,-20} {3}", ad, hx, t, nm);
                        ad = (ad + Math.Max(1, len)) & 0xFFFF;
                    }
                }
                break;
            case "ring":
                // ring on = record the last 4096 PCs; ring FILE = write them out (oldest first)
                if (a1.ToLowerInvariant() == "on") ringOn = true;
                else using (var w = new StreamWriter(Path.GetFullPath(a1)))
                    for (int i = 0; i < 4096; i++) { int k = (ringPos + i) & 4095; w.WriteLine("{0:X4} SP={1:X4} {2}", ringPc[k] & 0xFFFF, (ringPc[k] >> 16) & 0xFFFF, Near(ringPc[k] & 0xFFFF)); }
                break;
            case "until":
                {
                    int pc = Num(a1); long mx = m.Frames + (a2 != "" ? Num(a2) : 500); bool hit = false;
                    while (m.Frames < mx && !crashed) { Step(); if (cpu.PC == pc) { hit = true; break; } }
                    Console.Error.WriteLine("until {0}: {1} at frame {2}", a1, hit ? "reached" : "NOT reached", m.Frames);
                }
                break;
            case "untilmem":
                {
                    int ad = Num(a1), v = Num(a2); long mx = m.Frames + (a.Length > 3 ? Num(a[3]) : 500); bool hit = false;
                    while (m.Frames < mx && !crashed) { RunFrames(1); if (m.Rd(ad) == v) { hit = true; break; } }
                    Console.Error.WriteLine("untilmem {0}={1}: {2} at frame {3}", a1, a2, hit ? "reached" : "NOT reached", m.Frames);
                }
                break;
            case "minsp": Console.WriteLine("min SP {0:X4}", minSp); break;
            case "frame": Console.WriteLine("frame {0}", m.Frames); break;
            case "dos": Console.WriteLine("dos calls {0}{1}", m.DosCalls, m.Card != null ? string.Format(", SD card sectors read {0} written {1}{2}", m.Card.Reads, m.Card.Writes, m.RealDos ? " (real VZDOS)" : "") : ""); break;
            case "mode": Console.WriteLine("latch {0:X2} AG={1} CSS={2} GM={3} mapper {4:X2} shrg {5:X2}", m.Latch, m.AG ? 1 : 0, m.CSS ? 1 : 0, m.GmCode, m.Mapper, m.ShrgPort); break;
            case "out": m.Out(Num(a1), Num(a2)); break;
            case "in": Console.WriteLine("in {0} = {1:X2}", a1, m.In(Num(a1))); break;
            case "text": Console.WriteLine(ScreenText()); break;
            case "quit": case "exit": return false;
            default: Console.Error.WriteLine("?? " + cmd); break;
        }
        return true;
    }

    void TypeText(string s)
    {
        foreach (char ch in s)
        {
            var ks = VzMachine.CharKeys(ch); if (ks == null) continue;
            foreach (var k in ks) m.SetKey(k, true);
            RunFrames(3);
            foreach (var k in ks) m.SetKey(k, false);
            RunFrames(3);
        }
    }

    /// <summary>The text screen as ASCII (32 x 16), for checking BASIC output from a script.</summary>
    string ScreenText()
    {
        var sb = new StringBuilder();
        for (int r = 0; r < 16; r++)
        {
            for (int c = 0; c < 32; c++)
            {
                int b = m.Vram[r * 32 + c];
                if ((b & 0x80) != 0) { sb.Append('#'); continue; }
                int ch = b & 63; sb.Append((char)(ch < 32 ? ch + 64 : ch));
            }
            sb.AppendLine();
        }
        return sb.ToString().TrimEnd();
    }

    // ---------------------------------------------------------------- entry
    public static int Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("vzemu script.txt            run a test script (see README.md)");
            Console.Error.WriteLine("vzemu -e \"cmd; cmd; ...\"    run commands given inline");
            Console.Error.WriteLine("vzemu game.vz [frames] [out.png]   load, run, screenshot");
            return 1;
        }
        var h = new Headless();
        if (args[0] == "-e") return h.RunLines(string.Join(" ", args, 1, args.Length - 1).Split(';'));
        if (args[0].EndsWith(".vz", StringComparison.OrdinalIgnoreCase))
        {
            var l = new List<string>();
            l.Add("sd " + Path.GetDirectoryName(Path.GetFullPath(args[0])));
            l.Add("vz " + args[0]);
            l.Add("frames " + (args.Length > 1 ? args[1] : "250"));
            l.Add("screen " + (args.Length > 2 ? args[2] : "screen.png") + " 2");
            return h.RunLines(l);
        }
        return h.RunScript(args[0]);
    }
}
