// VZonPC - Dick Smith VZ200 / VZ300 emulator.
// Machine core: memory map, BennVenn SD loader (MAME sdloader.cpp model + high-level DOS calls),
// MC6847 video (standard, Australian SHRG and German 6K hi-res mods), speaker, keyboard, joysticks.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public enum Model { VZ200, VZ300 }
public enum MemExp { None, Ram16K, BennVenn }
public enum GfxMod { None, Australian, German }

public sealed class VzMachine
{
    // ---------------------------------------------------------------- configuration
    public Model Model = Model.VZ300;
    public MemExp Exp = MemExp.BennVenn;
    public GfxMod Gfx = GfxMod.None;
    public bool JoyInterface = true;
    public bool ShowSnow = false;
    public bool UseRom = true;          // false = always use the built-in stub ROM
    public bool BootVzdos = true;       // BennVenn: boot VZDOS.VZ from the SD card (or roms\) at power-on, as the real loader does

    // ---------------------------------------------------------------- timing
    public const int LINES = 312, LINET = 228, FRAMET = LINES * LINET;
    public const int FSLINES = 56;      // field sync (INT held, $6800 bit 7 low) for the first 56 lines
    public int TopBorder = 25;          // lines between the end of FS and the first picture line
    public int PicStart { get { return FSLINES + TopBorder; } }
    public int Clock { get { return Model == Model.VZ300 ? 3546894 : 3579500; } }

    // ---------------------------------------------------------------- state
    public readonly Z80 Cpu = new Z80();
    public byte[] Rom = new byte[0x4000];
    public string RomName = "";          // "" = stub
    public byte[] Ram = new byte[0x10000];  // internal RAM + 16K pack (flat)
    public byte[] Vram = new byte[0x2000];  // 2K standard, 8K with a hi-res mod
    public byte[] Bv = new byte[0x20000];   // BennVenn 128K SRAM
    public byte[] DosRom = new byte[0x2800];
    public int Mapper, Latch, ShrgPort = 0x08, GerBank;
    public bool Vz300Mode = true;
    public int[] Keys = new int[8];
    public int[] Joy = { 0xFF, 0xFF, 0xFF, 0xFF };   // joy1, joy1 arm, joy2, joy2 arm
    public long FrameStart, Frames;
    public bool FsLow;
    public int CurPc;

    // SD card (high-level DOS)
    public string SdDir = ".";
    public string AltDir = null;          // folder of the last loaded .VZ (searched after SdDir)
    FileStream sdf;
    public bool Quiet;
    public long DosCalls;
    public Action<string> Log = delegate (string s) { Console.Error.WriteLine(s); };

    // video
    public const int FBW = 320, FBH = 240, BX = 32, BY = 24;
    public int[] Fb = new int[FBW * FBH];
    int lastLine = -1;

    // snow diagnostics
    public long SnowCount; public int SnowFirstPc = -1; public long SnowFirstFrame; public int SnowMaxLine;
    public int[] SnowLineHist = new int[LINES];

    // hooks used by the headless test runner
    public Action<int, int> WriteHook;   // (addr, value) before every memory write
    public Func<bool> PreStep;           // return false to stop stepping (crash checks)

    // live visualiser trace (null = off; costs a little speed when on)
    public VzTrace Tr;
    public List<string> DosLog = new List<string>();
    public long DosSectors, DosOpens;

    int ramTop, packLo, packHi;

    public VzMachine()
    {
        Cpu.Rd = Rd; Cpu.Fetch = Fetch; Cpu.Wr = Wr; Cpu.In = In; Cpu.Out = Out;
        for (int i = 0; i < 8; i++) Keys[i] = 0x3F;
        BuildStubRom();
        BuildDosRom();
    }

    // ---------------------------------------------------------------- ROMs
    public static string RomDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "roms");

    void BuildStubRom()
    {
        for (int i = 0; i < 0x4000; i++) Rom[i] = 0xFF;
        // 0000: DI ; JR $  (sits there - the emulator writes a message to the screen)
        Rom[0] = 0xF3; Rom[1] = 0x18; Rom[2] = 0xFE;
        // 0038: IM 1 handler. The real ROM jumps through $787D; the stub does EI / RETI so
        // programs that run with interrupts on (and never hook $787D) still work.
        Rom[0x38] = 0xFB; Rom[0x39] = 0xED; Rom[0x3A] = 0x4D;
        // 0066: NMI -> RETN
        Rom[0x66] = 0xED; Rom[0x67] = 0x45;
        RomName = "";
    }

    void BuildDosRom()
    {
        // Stand-in for the BennVenn DOS: RET at the three entry points that games call; the
        // emulator traps them before they execute.
        for (int i = 0; i < DosRom.Length; i++) DosRom[i] = 0xFF;
        DosRom[0x1F00] = 0xC9; DosRom[0x1F03] = 0xC9; DosRom[0x1F09] = 0xC9;
    }

    /// <summary>Looks for a BASIC ROM for the current model in roms/. Returns false if none.</summary>
    public bool LoadRom()
    {
        BuildStubRom();
        if (!UseRom) return false;
        string[] one16 = Model == Model.VZ300
            ? new[] { "vz300.rom", "vtechv20.u12", "laser310.rom", "vz200.rom", "vzrom.bin", "vz.rom" }
            : new[] { "vz200.rom", "vzrom.bin", "vz.rom", "vz300.rom", "vtechv20.u12", "laser310.rom" };
        foreach (var n in one16)
        {
            string p = Path.Combine(RomDir, n);
            if (File.Exists(p) && new FileInfo(p).Length == 0x4000) { Rom = File.ReadAllBytes(p); RomName = n; return true; }
        }
        string a = Path.Combine(RomDir, "vtechv20.u09"), b = Path.Combine(RomDir, "vtechv20.u10");
        if (File.Exists(a) && File.Exists(b))
        {
            var r1 = File.ReadAllBytes(a); var r2 = File.ReadAllBytes(b);
            if (r1.Length == 0x2000 && r2.Length == 0x2000)
            {
                Rom = new byte[0x4000]; Array.Copy(r1, 0, Rom, 0, 0x2000); Array.Copy(r2, 0, Rom, 0x2000, 0x2000);
                RomName = "vtechv20.u09+u10"; return true;
            }
        }
        return false;
    }
    public bool HasRom { get { return RomName != ""; } }

    // ---------------------------------------------------------------- reset
    public void PowerOn(int randSeed = -1) { PowerOn(randSeed, true); }

    // ---------------------------------------------------------------- BennVenn BIOS + real VZDOS
    // The loader's flash shows an extension-ROM signature at $4000, so the VZ ROM jumps to $4004 at boot.
    // The flash BIOS then loads VZDOS.VZ from the root of the card into the DOS RAM and runs it. Here the BIOS
    // is a stand-in: the jump to $4004 is trapped, VZDOS.VZ is copied in, and the real DOS takes over, talking
    // to the emulated SD card (SdCard) over SPI. Without a VZDOS.VZ the loader boots straight to BASIC.
    public bool RealDos;                // the real VZDOS is running (high-level DOS traps off)
    public string VzdosFile;            // the VZDOS.VZ found at power-on
    bool biosArmed;
    public SdCard Card;
    public bool SdWriteBack = true;     // write the DOS's changes on the card back to the PC folder
    long cardWriteFrame;

    /// <summary>Writes SD card changes back to the PC folder now (power-off, exit, before mounting another folder).</summary>
    public void FlushCard()
    {
        if (Card == null || !Card.Dirty || !SdWriteBack) return;
        try { Card.Flush(s => Log(s)); } catch (Exception ex) { Log("SD card write-back failed: " + ex.Message); }
    }
    public bool SdFound { get { return Exp == MemExp.BennVenn && RealDos; } }

    public static string FindVzdos(string sdDir)
    {
        foreach (var d in new[] { sdDir, RomDir })
        {
            if (d == null || !Directory.Exists(d)) continue;
            foreach (var f in Directory.GetFiles(d))
                if (string.Equals(Path.GetFileName(f), "VZDOS.VZ", StringComparison.OrdinalIgnoreCase)) return f;
        }
        return null;
    }

    void ArmBios()
    {
        biosArmed = false; VzdosFile = null;
        if (Exp != MemExp.BennVenn || !BootVzdos || !HasRom) return;
        VzdosFile = FindVzdos(SdDir);
        if (VzdosFile == null) return;
        DosRom[0] = 0xAA; DosRom[1] = 0x55; DosRom[2] = 0xE7; DosRom[3] = 0x18;
        DosRom[4] = 0xC3; DosRom[5] = 0x04; DosRom[6] = 0x40;   // JP $4004 (trapped)
        biosArmed = true;
    }

    void BiosBoot()
    {
        // what the flash BIOS does: re-read VZDOS.VZ from the card into DOS RAM bank 0 and map it in
        string f = FindVzdos(SdDir) ?? VzdosFile;
        byte[] d = f != null && File.Exists(f) ? File.ReadAllBytes(f) : null;
        if (d == null || d.Length < 24 + 8) { Mapper = 0; Log("BennVenn BIOS: no VZDOS.VZ"); biosArmed = false; BuildDosRom(); Cpu.PC = 0; return; }
        int n = Math.Min(d.Length - 24, 0x2800);
        Array.Copy(d, 24, Bv, 0, n);
        Mapper = 1;
        RealDos = true;
        if (!Quiet) Log("BennVenn BIOS: booting " + Path.GetFileName(f) + " from " + Path.GetDirectoryName(f));
    }

    SdCard GetCard()
    {
        if (Card == null || !string.Equals(Card.Root, SdDir, StringComparison.OrdinalIgnoreCase))
        {
            if (Card != null) { FlushCard(); Card.Close(); }
            Card = new SdCard(SdDir);
            if (!Quiet) Log("SD card: " + Card.FileCount + " files from " + SdDir);
        }
        return Card;
    }

    public void PowerOn(int randSeed, bool allowBios)
    {
        ramTop = Model == Model.VZ300 ? 0xB800 : 0x9000;
        if (Model == Model.VZ300) { packLo = 0xB800; packHi = 0xF800; } else { packLo = 0x9000; packHi = 0xD000; }
        if (randSeed >= 0)
        {
            var rnd = new Random(randSeed);
            for (int i = 0x7800; i < 0x10000; i++) Ram[i] = (byte)rnd.Next(256);
            for (int i = 0; i < Bv.Length; i++) Bv[i] = (byte)rnd.Next(256);
            for (int i = 0; i < Vram.Length; i++) Vram[i] = (byte)rnd.Next(256);
        }
        else { Array.Clear(Ram, 0, Ram.Length); Array.Clear(Bv, 0, Bv.Length); Array.Clear(Vram, 0, Vram.Length); }
        LoadRom();
        Mapper = 0; Latch = 0; ShrgPort = 0x08; GerBank = 0; Vz300Mode = false;
        if (sdf != null) { sdf.Close(); sdf = null; }
        DosLog.Clear(); DosSectors = DosOpens = 0;
        BuildDosRom(); RealDos = false;
        if (Card != null) { FlushCard(); Card.Close(); Card = null; }   // re-read the folder
        if (allowBios) ArmBios(); else biosArmed = false;
        Reset();
        if (!HasRom) WriteNoRomMessage();
    }

    public void Reset()
    {
        Cpu.Reset();
        Cpu.Cyc = 0; FrameStart = 0; lastLine = -1;
        Mapper = 0; Vz300Mode = false;
        tps = 0;   // restart the sample clock
        if (Tr != null) Tr.ResetTimes();
    }

    void WriteNoRomMessage()
    {
        string[] msg = {
            "", "            VZONPC", "",
            " NO VZ BASIC ROM FOUND IN ROMS\\", "",
            " PRESS F2 TO LOAD A PROGRAM", " FROM THE SD CARD FOLDER", "",
            " (OR DROP A .VZ FILE ON THE", "  WINDOW)", "",
            " SEE README.MD FOR ROM NAMES" };
        for (int i = 0; i < 512; i++) Vram[i] = 0x60;   // inverse space = green
        for (int r = 0; r < msg.Length; r++)
            for (int c = 0; c < msg[r].Length && c < 32; c++)
                Vram[r * 32 + c] = (byte)((msg[r][c] & 0x3F) | 0x40);
    }

    // ---------------------------------------------------------------- memory
    int VBank { get { return Gfx == GfxMod.Australian ? (ShrgPort & 3) : (Gfx == GfxMod.German ? GerBank : 0); } }
    int DosOff(int a) { return ((Mapper & 2) != 0 ? 0x8000 : 0) + (a - 0x4000); }
    int ExpOff(int a) { return ((Mapper & 4) != 0 ? 0x18000 : 0x10000) + (a & 0x7FFF); }

    public int Line { get { return (int)((Cpu.Cyc - FrameStart) / LINET); } }

    public int Rd(int a) { if (Tr != null) Tr.R(a); return Mem(a, false); }
    public int Fetch(int a) { if (Tr != null) Tr.X(a); return Mem(a, false); }
    /// <summary>Reads memory as the CPU sees it, without side effects (for debuggers and visualisers).</summary>
    public int Peek(int a) { return Mem(a & 0xFFFF, true); }

    int Mem(int a, bool peek)
    {
        if (a < 0x4000) return Rom[a];
        if (a < 0x6800)
        {
            if (Exp != MemExp.BennVenn) return 0xFF;
            if ((Mapper & 1) != 0) return Bv[DosOff(a)];
            return DosRom[a - 0x4000];
        }
        if (a < 0x7000)
        {
            int r = 0x3F, lo = a & 0xFF;
            for (int i = 0; i < 8; i++) if ((lo & (1 << i)) == 0) r &= Keys[i];
            r |= 0x40;                      // cassette input: no signal
            if (!FsLow) r |= 0x80;          // field sync
            return r;
        }
        if (a < 0x7800) { if (!peek) VideoAccess(a, -1); return Vram[(VBank << 11) + (a - 0x7000)]; }
        if (a < ramTop) return Ram[a];
        if (Exp == MemExp.Ram16K) return (a >= packLo && a < packHi) ? Ram[a] : 0xFF;
        if (Exp == MemExp.BennVenn && a >= 0x9000 && (!Vz300Mode || a >= 0xB800)) return Bv[ExpOff(a)];
        return 0xFF;
    }

    public void Wr(int a, int v)
    {
        if (WriteHook != null) WriteHook(a, v);
        if (Tr != null) Tr.W(a, v);
        if (a < 0x4000) return;
        if (a < 0x6800) { if (Exp == MemExp.BennVenn) Bv[DosOff(a)] = (byte)v; return; }
        if (a < 0x7000) { SpeakerTo(v); Latch = v; return; }
        if (a < 0x7800) { VideoAccess(a, v); Vram[(VBank << 11) + (a - 0x7000)] = (byte)v; return; }
        if (a < ramTop) { Ram[a] = (byte)v; return; }
        if (Exp == MemExp.Ram16K) { if (a >= packLo && a < packHi) Ram[a] = (byte)v; return; }
        if (Exp == MemExp.BennVenn && a >= 0x9000 && (!Vz300Mode || a >= 0xB800)) Bv[ExpOff(a)] = (byte)v;
    }

    public int In(int port)
    {
        int lo = port & 0xFF;
        if (JoyInterface && lo >= 0x20 && lo <= 0x2F)
        {
            int r = 0xFF;
            if ((lo & 1) == 0) r &= Joy[0];
            if ((lo & 2) == 0) r &= Joy[1];
            if ((lo & 4) == 0) r &= Joy[2];
            if ((lo & 8) == 0) r &= Joy[3];
            if (Tr != null) Tr.Port(lo, r, false);
            return r;
        }
        if (Exp == MemExp.BennVenn && lo == 0x39) { int r = GetCard().In(); if (Tr != null) { Tr.Port(lo, r, false); Tr.DosLed = 255; } return r; }
        if (Tr != null) Tr.Port(lo, 0xFF, false);
        return 0xFF;
    }

    public void Out(int port, int v)
    {
        int lo = port & 0xFF;
        if (Tr != null) Tr.Port(lo, v, true);
        if (Exp == MemExp.BennVenn)
        {
            if (lo == 0x37) Mapper = v;
            else if (lo == 0x3A) Vz300Mode = (v & 1) != 0;
            else if (lo == 0x39)
            {
                var c = GetCard(); long w = c.Writes; c.Out(v);
                if (c.Writes != w) cardWriteFrame = Frames;
                if (Tr != null) Tr.DosLed = 255;
            }
        }
        if (Gfx == GfxMod.Australian && lo >= 0x20 && lo <= 0x2F) ShrgPort = v;
        if (Gfx == GfxMod.German && lo >= 0xD0 && lo <= 0xDF) GerBank = v & 3;
    }

    // ---------------------------------------------------------------- snow
    void VideoAccess(int a, int v)
    {
        int ln = Line;
        if (ln < PicStart || ln >= PicStart + 192) return;
        SnowCount++; SnowLineHist[ln]++;
        if (SnowFirstPc < 0) { SnowFirstPc = CurPc; SnowFirstFrame = Frames; }
        if (ln > SnowMaxLine) SnowMaxLine = ln;
        if (!ShowSnow) return;
        // the 6847 shows the CPU's data byte instead of the fetched one: draw it as 8 dots
        int t = (int)((Cpu.Cyc - FrameStart) % LINET);
        int x = (t - 50) * 2; if (x < 0 || x > 248) return;
        int oy = ln - (PicStart - BY); if (oy < 0 || oy >= FBH) return;
        int b = v >= 0 ? v : Vram[(VBank << 11) + (a - 0x7000)];
        int o = oy * FBW + BX + (x & ~7);
        for (int i = 0; i < 8; i++) Fb[o + i] = ((b >> (7 - i)) & 1) != 0 ? 0xFFFFFF : 0x202020;
    }

    // ---------------------------------------------------------------- speaker -> samples
    public const int RATE = 44100;
    public short[] Audio = new short[4096]; public int AudioN;
    public bool AudioOn = true;
    public int Volume = 9000;
    double tps, sampNext, sampAcc; long sampLastT;
    int lastLatch;
    public Action<long, int> SpeakerHook;  // (cycle, latch) for the WAV writer

    static int SpkLevel(int v) { return (v & 1) - ((v >> 5) & 1); }   // MAME: (b5<<1)|b0 -> {0,+1,-1,0}

    void SpeakerTo(int v)
    {
        if (SpeakerHook != null) SpeakerHook(Cpu.Cyc, v);
        if (AudioOn) AudioAdvance(Cpu.Cyc);
        lastLatch = v;
    }
    public int LastLatch { get { return lastLatch; } }

    void AudioAdvance(long t)
    {
        if (tps == 0) { tps = (double)Clock / RATE; sampNext = t + tps; sampLastT = t; }
        double lvl = SpkLevel(lastLatch);
        double cur = sampLastT;
        while (t >= sampNext)
        {
            sampAcc += lvl * (sampNext - cur);
            if (AudioN < Audio.Length) Audio[AudioN++] = (short)(sampAcc / tps * Volume);
            sampAcc = 0; cur = sampNext; sampNext += tps;
        }
        sampAcc += lvl * (t - cur); sampLastT = t;
    }

    // ---------------------------------------------------------------- DOS (high level)
    public bool DosTrapActive { get { return Exp == MemExp.BennVenn && (Mapper & 2) == 0 && !RealDos; } }

    string FindSdFile(string name)
    {
        var clean = new StringBuilder();
        foreach (char c in name) if (c > ' ' && c < 127 && Array.IndexOf(Path.GetInvalidFileNameChars(), c) < 0) clean.Append(c);
        name = clean.ToString();
        if (name.Length == 0) return null;
        foreach (var dir in new[] { SdDir, AltDir })
        {
            if (dir == null || !Directory.Exists(dir)) continue;
            string p = Path.Combine(dir, name);
            if (File.Exists(p)) return p;
            p = Path.Combine(dir, name + ".DAT");
            if (File.Exists(p)) return p;
            foreach (var f in Directory.GetFiles(dir))
                if (string.Equals(Path.GetFileNameWithoutExtension(f), name, StringComparison.OrdinalIgnoreCase)
                    && !f.EndsWith(".VZ", StringComparison.OrdinalIgnoreCase)) return f;
        }
        return null;
    }

    public Action OnDosCall;   // test hook (DOSSCRIBBLE etc.)
    int dosRun;
    void AddDosLog(string s) { DosLog.Add(s); if (DosLog.Count > 40) DosLog.RemoveAt(0); }

    void DosTrap()
    {
        int pc = Cpu.PC;
        int buf = Rd(0xFB80) | (Rd(0xFB81) << 8);
        if (pc == 0x5F00)
        {
            var sb = new StringBuilder(); int p = (Cpu.H << 8) | Cpu.L; if (Rd(p) == '"') p++;
            for (int n = 0; n < 60; n++) { int c = Rd(p++ & 0xFFFF); if (c == '"' || c == 0 || c == 13) break; sb.Append((char)c); }
            string fn = FindSdFile(sb.ToString().Trim());
            if (sdf != null) sdf.Close();
            sdf = fn != null ? File.OpenRead(fn) : null;
            Wr(0xFB03, sdf != null ? 1 : 0); Wr(0xFB05, 0);
            if (!Quiet) Log(string.Format("DOS open \"{0}\" -> {1} (frame {2}, SP {3:X4})", sb, fn ?? "MISSING", Frames, Cpu.SP));
            DosOpens++;
            AddDosLog("OPEN " + sb.ToString().Trim() + (fn == null ? "  (MISSING)" : ""));
            Cpu.Cyc += 20000;
        }
        else
        {
            byte[] d = new byte[512]; if (sdf != null) sdf.Read(d, 0, 512);
            for (int i = 0; i < 512; i++) Wr((buf + i) & 0xFFFF, d[i]);
            Cpu.Cyc += 44000;   // measured on real hardware: ~44,000 T per sector
            DosSectors++;
            int last = DosLog.Count - 1;
            if (last >= 0 && DosLog[last].StartsWith("READ ")) { dosRun++; DosLog[last] = "READ " + dosRun + " SECTOR" + (dosRun > 1 ? "S" : "") + " -> $" + buf.ToString("X4"); }
            else { dosRun = 1; AddDosLog("READ 1 SECTOR -> $" + buf.ToString("X4")); }
        }
        DosCalls++;
        if (OnDosCall != null) OnDosCall();
        int r = Rd(Cpu.SP) | (Rd((Cpu.SP + 1) & 0xFFFF) << 8); Cpu.SP = (Cpu.SP + 2) & 0xFFFF; Cpu.PC = r;
    }

    // ---------------------------------------------------------------- execution
    /// <summary>Executes one instruction. Returns false (without executing) at a frame boundary.</summary>
    public bool StepOne()
    {
        long rel = Cpu.Cyc - FrameStart;
        if (rel >= FRAMET)
        {
            RenderTo(LINES); if (Tr != null) Tr.EndFrame(); FrameStart += FRAMET; Frames++; lastLine = -1;
            if (Card != null && Card.Dirty && SdWriteBack && Frames - cardWriteFrame > 25) FlushCard();   // the DOS has finished writing
            return false;
        }
        int line = (int)(rel / LINET);
        if (line != lastLine) RenderTo(line + 1);
        FsLow = line < FSLINES;
        Cpu.IntLine = FsLow;
        CurPc = Cpu.PC;
        if (biosArmed && CurPc == 0x4004 && (Mapper & 1) == 0 && Exp == MemExp.BennVenn) BiosBoot();
        if (DosTrapActive && (CurPc == 0x5F00 || CurPc == 0x5F03 || CurPc == 0x5F09))
        {
            long d0 = Cpu.Cyc; DosTrap();
            if (Tr != null) Tr.Dos(d0, Cpu.Cyc);
            return true;
        }
        if (PreStep != null && !PreStep()) return true;
        if (Tr == null) { Cpu.Step(); return true; }
        long t0 = Cpu.Cyc;
        bool intTaken = Cpu.IntLine && Cpu.IFF1 && Cpu.EiDelay == 0;
        bool halted = Cpu.Halted && !intTaken;
        Tr.Pre();
        Cpu.Step();
        Tr.Step(CurPc, t0, Cpu.Cyc, intTaken, halted);
        return true;
    }

    public void RunFrame()
    {
        AudioN = 0;
        if (AudioOn && tps != 0 && Math.Abs(Cpu.Cyc - sampLastT) > FRAMET * 2) tps = 0;   // after warp / pause
        long end = Frames + 1;
        while (Frames < end) StepOne();
        if (AudioOn) AudioAdvance(Cpu.Cyc);
    }

    public void RunFrames(long n) { long t = Frames + n; while (Frames < t) StepOne(); }

    // ---------------------------------------------------------------- MC6847 video
    // 6847 colours: green, yellow, blue, red, buff, cyan, magenta, orange
    public static readonly int[] Pal = {
        0x30D200, 0xC1E500, 0x4C3AB4, 0x9A3236, 0xBFC8AD, 0x41AF71, 0xC84EF0, 0xD47F00 };
    const int BLACK = 0x101010, DKGREEN = 0x007C00, DKORANGE = 0x6B2700, BRORANGE = 0xFFB700;
    public bool Mono;

    /// <summary>GM2..GM0 currently presented to the 6847.</summary>
    public int GmCode
    {
        get
        {
            if (Gfx == GfxMod.Australian) return (ShrgPort >> 2) & 7;
            if (Gfx == GfxMod.German) return (Latch & 2) != 0 ? 7 : 2;
            return 2;
        }
    }
    public bool AG { get { return (Latch & 8) != 0; } }
    public bool CSS { get { return (Latch & 16) != 0; } }

    void RenderTo(int lineEnd)
    {
        for (int ln = lastLine + 1; ln < lineEnd; ln++) RenderLine(ln);
        lastLine = lineEnd - 1;
    }

    int VramByte(int off) { return Gfx == GfxMod.None ? Vram[off & 0x7FF] : Vram[off & 0x1FFF]; }

    void RenderLine(int ln)
    {
        if (Tr != null && ln < LINES) Tr.LineMode[ln] = (AG ? 8 | GmCode : 0) | (CSS ? 16 : 0);
        int oy = ln - (PicStart - BY);
        if (oy < 0 || oy >= FBH) return;
        int o = oy * FBW;
        bool ag = AG, css = CSS;
        int border = ag ? (css ? Pal[4] : Pal[0]) : BLACK;
        int py = ln - PicStart;
        if (py < 0 || py >= 192)
        {
            for (int x = 0; x < FBW; x++) Fb[o + x] = border;
            return;
        }
        for (int x = 0; x < BX; x++) { Fb[o + x] = border; Fb[o + FBW - 1 - x] = border; }
        o += BX;
        if (!ag)
        {
            int row = py / 12, ry = py % 12;
            // 6847 text on the VZ: normal characters are bright green on dark green; inverse is dark on bright (checked on real hardware)
            int fgA = css ? BRORANGE : Pal[0], bgA = css ? DKORANGE : DKGREEN;
            for (int cx = 0; cx < 32; cx++)
            {
                int b = VramByte(row * 32 + cx);
                if ((b & 0x80) != 0)
                {
                    int fg = Pal[(b >> 4) & 7];
                    int top = ry < 6 ? 3 : 1;   // bit3 TL bit2 TR (top half), bit1 BL bit0 BR
                    bool l = ((b >> top) & 1) != 0, r = ((b >> (top - 1)) & 1) != 0;
                    for (int i = 0; i < 4; i++) { Fb[o + i] = l ? fg : BLACK; Fb[o + 4 + i] = r ? fg : BLACK; }
                }
                else
                {
                    int ch = b & 63; bool inv = (b & 0x40) != 0;
                    int bits = (ry >= 3 && ry < 10) ? Font6847.F[ch, ry - 3] : 0;
                    for (int i = 0; i < 8; i++)
                    {
                        bool on = i >= 1 && i < 6 && ((bits >> (5 - i)) & 1) != 0;
                        if (inv) on = !on;
                        Fb[o + i] = on ? fgA : bgA;
                    }
                }
                o += 8;
            }
            return;
        }
        int gm = GmCode;
        bool color = (gm & 1) == 0;                  // CG modes are the even codes
        int bpr = (gm == 0 || gm == 1 || gm == 3 || gm == 5) ? 16 : 32;
        int rep = gm <= 2 ? 3 : (gm <= 4 ? 2 : 1);
        int pixPerByte = color ? 4 : 8;
        int pw = 256 / (bpr * pixPerByte);          // output dots per pixel
        int baseOff = (py / rep) * bpr;
        int on1 = css ? Pal[4] : Pal[0];
        int cofs = css ? 4 : 0;
        for (int bx = 0; bx < bpr; bx++)
        {
            int b = VramByte(baseOff + bx);
            if (color)
            {
                for (int k = 0; k < 4; k++)
                {
                    int c = Pal[((b >> (6 - 2 * k)) & 3) + cofs];
                    for (int i = 0; i < pw; i++) Fb[o++] = c;
                }
            }
            else
            {
                for (int k = 0; k < 8; k++)
                {
                    int c = ((b >> (7 - k)) & 1) != 0 ? on1 : BLACK;
                    for (int i = 0; i < pw; i++) Fb[o++] = c;
                }
            }
        }
    }

    /// <summary>Copies the frame buffer (optionally without border) for display.</summary>
    public int[] Snapshot(bool border, out int w, out int h)
    {
        if (border) { w = FBW; h = FBH; var r = new int[FBW * FBH]; Array.Copy(Fb, r, r.Length); if (Mono) ToMono(r); return r; }
        w = 256; h = 192; var s = new int[256 * 192];
        for (int y = 0; y < 192; y++) Array.Copy(Fb, (y + BY) * FBW + BX, s, y * 256, 256);
        if (Mono) ToMono(s);
        return s;
    }
    static void ToMono(int[] p)
    {
        for (int i = 0; i < p.Length; i++)
        {
            int c = p[i]; int l = (((c >> 16) & 255) * 30 + ((c >> 8) & 255) * 59 + (c & 255) * 11) / 100;
            p[i] = (l << 16) | (l << 8) | l;
        }
    }

    // ---------------------------------------------------------------- keyboard
    // rows = address lines A0..A7; index = data bit 0..5 (bit 5 is the first key in the manual)
    public static readonly string[,] KROWS = {
        {"T","W","","E","Q","R"},{"G","S","CTRL","D","A","F"},{"B","X","SHIFT","C","Z","V"},{"5","2","","3","1","4"},
        {"N",".","",",","SPACE","M"},{"6","9","-","8","0","7"},{"Y","O","RETURN","I","P","U"},{"H","L",":","K",";","J"} };

    static Dictionary<string, int> keyIndex;
    public static int KeyIndex(string k)
    {
        if (keyIndex == null)
        {
            keyIndex = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            for (int r = 0; r < 8; r++) for (int b = 0; b < 6; b++) if (KROWS[r, b].Length > 0) keyIndex[KROWS[r, b]] = r * 8 + b;
            keyIndex["ENTER"] = keyIndex["RETURN"]; keyIndex["COMMA"] = keyIndex[","]; keyIndex["PERIOD"] = keyIndex["."];
            keyIndex["MINUS"] = keyIndex["-"]; keyIndex["SEMI"] = keyIndex[";"]; keyIndex["COLON"] = keyIndex[":"];
        }
        int v; return keyIndex.TryGetValue(k, out v) ? v : -1;
    }
    public bool SetKey(string k, bool down)
    {
        int i = KeyIndex(k); if (i < 0) return false;
        SetKey(i, down); return true;
    }
    public void SetKey(int i, bool down) { int r = i >> 3, b = i & 7; if (down) Keys[r] &= ~(1 << b); else Keys[r] |= 1 << b; }

    /// <summary>Maps a character to VZ keys (key, needs shift). Returns null if not typeable.</summary>
    public static string[] CharKeys(char ch)
    {
        ch = char.ToUpperInvariant(ch);
        if (ch >= 'A' && ch <= 'Z' || ch >= '0' && ch <= '9') return new[] { ch.ToString() };
        switch (ch)
        {
            case ' ': return new[] { "SPACE" };
            case '\r': case '\n': return new[] { "RETURN" };
            case ',': return new[] { "," }; case '.': return new[] { "." }; case '-': return new[] { "-" };
            case ';': return new[] { ";" }; case ':': return new[] { ":" };
            case '!': return new[] { "SHIFT", "1" }; case '"': return new[] { "SHIFT", "2" }; case '#': return new[] { "SHIFT", "3" };
            case '$': return new[] { "SHIFT", "4" }; case '%': return new[] { "SHIFT", "5" }; case '&': return new[] { "SHIFT", "6" };
            case '\'': return new[] { "SHIFT", "7" }; case '(': return new[] { "SHIFT", "8" }; case ')': return new[] { "SHIFT", "9" };
            case '@': return new[] { "SHIFT", "0" }; case '=': return new[] { "SHIFT", "-" }; case '+': return new[] { "SHIFT", ";" };
            case '*': return new[] { "SHIFT", ":" }; case '<': return new[] { "SHIFT", "," }; case '>': return new[] { "SHIFT", "." };
            case '/': return new[] { "SHIFT", "K" }; case '?': return new[] { "SHIFT", "L" }; case '^': return new[] { "SHIFT", "N" };
            case '\\': return new[] { "SHIFT", "M" }; case '[': return new[] { "SHIFT", "O" }; case ']': return new[] { "SHIFT", "P" };
            case '~': return new[] { "SHIFT", "SPACE" };
        }
        return null;
    }

    // ---------------------------------------------------------------- program loading
    public string LoadedName = "";

    /// <summary>Loads a .VZ file into memory the way the BennVenn loader / MAME quickload does.
    /// Machine code starts at once; BASIC programs get their pointers set and need RUN.</summary>
    public int LoadVz(string fn, out bool isBasic)
    {
        byte[] d = File.ReadAllBytes(fn);
        isBasic = false;
        if (d.Length < 24) throw new InvalidDataException("not a .VZ file (too short)");
        int type = d[21];
        int start = d[22] | (d[23] << 8);
        int end = start + d.Length - 24;
        for (int i = 24; i < d.Length; i++) Wr((start + i - 24) & 0xFFFF, d[i]);
        int bad = 0;
        for (int i = 24; i < d.Length; i++) if (Rd((start + i - 24) & 0xFFFF) != d[i]) bad++;
        if (bad > 0) Log(string.Format("warning: {0} bytes of {1} did not stick (no RAM there for this configuration)", bad, Path.GetFileName(fn)));
        AltDir = Path.GetDirectoryName(Path.GetFullPath(fn));
        LoadedName = Path.GetFileName(fn);
        if (type == 0xF0)
        {
            isBasic = true;
            Wr(0x78A4, start & 255); Wr(0x78A5, start >> 8);
            for (int a = 0x78F9; a <= 0x78FD; a += 2) { Wr(a, end & 255); Wr(a + 1, (end >> 8) & 255); }
        }
        else
        {
            Wr(0x788E, start & 255); Wr(0x788F, start >> 8);
            Cpu.PC = start;
        }
        if (!Quiet) Log(string.Format("loaded {0} ({1}) {2:X4}-{3:X4}", Path.GetFileName(fn), isBasic ? "BASIC" : "machine code", start, end - 1));
        return start;
    }

    /// <summary>Power-on, boot BASIC if a ROM is present, then load and start a program, as the
    /// BennVenn menu would. Returns true for a BASIC program (caller types RUN).</summary>
    public bool Launch(string fn)
    {
        PowerOn(-1, false);
        if (HasRom) RunFrames(100);     // let BASIC initialise (READY)
        else { Cpu.SP = (Exp != MemExp.None || Model == Model.VZ300) ? 0xB7F0 : 0x8FF0; Cpu.IM = 1; for (int i = 0; i < 512; i++) Vram[i] = 0x60; }
        if (Exp == MemExp.BennVenn)
        {
            // the DOS leaves its RAM copy mapped in (mapping 1) and VZ300 mode set
            Mapper = 1; Vz300Mode = Model == Model.VZ300;
            Array.Copy(DosRom, 0, Bv, 0, DosRom.Length);
        }
        bool basic;
        LoadVz(fn, out basic);
        if (basic && !HasRom) Log("this is a BASIC program: it needs the VZ BASIC ROM in roms\\");
        return basic;
    }
}
