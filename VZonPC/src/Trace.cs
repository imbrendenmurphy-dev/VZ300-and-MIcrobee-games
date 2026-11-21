// VZonPC live trace: records what the Z80, the bus, the 6847, the ports and the BennVenn are doing,
// for the visualiser panels (Vis.cs). Attach with machine.Tr = new VzTrace(machine); detach with null.
using System;
using System.Collections.Generic;

public sealed class VzTrace
{
    readonly VzMachine m;
    public const int FT = VzMachine.FRAMET, LINES = VzMachine.LINES, LT = VzMachine.LINET;

    // memory heat (255 = touched this frame, fades over ~1/2 second)
    public readonly byte[] HR = new byte[65536], HW = new byte[65536], HX = new byte[65536];
    public readonly bool[] Start = new bool[65536];        // addresses seen as instruction starts
    public readonly bool[] CallTarget = new bool[65536];   // CALL / RST destinations (routine starts)
    readonly long[] visit = new long[65536];               // T of the last visit to each PC (spin detection)

    // profile (T-states per PC) and opcode counts: collected over 50 frames, then published
    public readonly long[] Prof = new long[65536]; public long[] ProfShown = new long[65536]; public long ProfShownT;
    public readonly int[] Ops = new int[256]; public int[] OpsShown = new int[256]; public long OpsShownN;
    public int ProfVersion;
    int window;

    // per-T-state CPU activity for one frame, and bus overlays (double buffered: *Shown = last whole frame)
    public const byte S_NONE = 0, S_BUSY = 1, S_IDLE = 2, S_ISR = 3, S_DOS = 4;
    public const byte O_VR = 1, O_VW = 2, O_SPK = 3, O_OUT = 4, O_IN = 5, O_KEY = 6;
    byte[] ras = new byte[FT], ov = new byte[FT];
    public byte[] Ras = new byte[FT], Ov = new byte[FT];
    public readonly int[] LineMode = new int[LINES]; public int[] LineModeShown = new int[LINES];
    // the 6847 latch at every T-state of every line, the row each picture line showed (-1 = border) and
    // line flags (1 = AG flipped during the line, so the row counter was held; 2 = AG or CSS changed during the line)
    byte[] lineLat = new byte[FT]; public byte[] LineLat = new byte[FT];
    short[] lineRow = new short[LINES]; public short[] LineRow = new short[LINES];
    byte[] lineFlag = new byte[LINES]; public byte[] LineFlag = new byte[LINES];
    int holds, splits; public int Holds, Splits;
    public void Line(int ln, int[] lat, int row, bool held)
    {
        int o = ln * LT; byte f = 0; int prev = lat[0];
        for (int t = 0; t < LT; t++) { int v = lat[t]; lineLat[o + t] = (byte)v; if (((v ^ prev) & 0x18) != 0) f = 2; prev = v; }
        if (row >= 0 && held) { f |= 1; holds++; }
        if (row >= 0 && f != 0) splits++;
        lineRow[ln] = (short)row; lineFlag[ln] = f;
    }

    long lastWriteT, idleMark, dosCarry; bool inIsr; int isrSp; long isrT0;
    int intsFrame; public int Ints;

    // frame budget history (percent)
    public const int HIST = 300;
    public readonly byte[] HBusy = new byte[HIST], HIsr = new byte[HIST], HDos = new byte[HIST];
    public readonly int[] HSp = new int[HIST]; public int HPos;
    public double Busy, Isr, Idle, DosF;
    int spMin = 0xFFFF; public int SpMinSecond = 0xFFFF; int spMinWin = 0xFFFF; int spMaxWin; public int SpMaxSecond = 0xFFFF;

    // ports
    public readonly byte[] PIn = new byte[256], POut = new byte[256];
    public readonly int[] PValIn = new int[256], PValOut = new int[256];
    readonly int[] pCount = new int[512]; public int[] PCountShown = new int[512];
    public readonly List<int> Recent = new List<int>();   // (out?256:0)+port, most recent first
    public readonly byte[] RowScan = new byte[8];

    // video RAM
    int vramW, vramR, picAcc; public int VramW, VramR, PicAccess;

    // speaker: level per 64 T
    public const int SPKBIN = 64, SPKN = FT / SPKBIN + 1;
    short[] spk = new short[SPKN]; public short[] SpkShown = new short[SPKN];
    int spkPos; short spkLevel; int spkWrites; public int SpkWrites;
    public readonly float[] SpkRing = new float[2048]; public int SpkRingPos;

    // BennVenn
    public byte DosLed;

    // sampled "busy" PC for the code panel
    readonly Random rnd = new Random(1);
    int sampleT, sampleCand = -1, lastSample = -1; public int ShownPc = -1; int frameNo;

    static readonly byte[] decay = new byte[256];
    static VzTrace() { for (int i = 0; i < 256; i++) decay[i] = (byte)Math.Max(0, i - (i >> 4) - 2); }

    public VzTrace(VzMachine machine) { m = machine; sampleT = rnd.Next(FT); }

    int Rel { get { long r = m.Cpu.Cyc - m.FrameStart; return r < 0 ? 0 : r >= FT ? FT - 1 : (int)r; } }

    // ---------------------------------------------------------------- bus events
    public void R(int a)
    {
        HR[a] = 255;
        if (a >= 0x7000 && a < 0x7800) { vramR++; ov[Rel] = O_VR; Pic(); }
        else if (a >= 0x6800 && a < 0x7000)
        {
            int lo = a & 0xFF;
            for (int i = 0; i < 8; i++) if ((lo & (1 << i)) == 0) RowScan[i] = 255;
            if (lo != 0xFF) ov[Rel] = O_KEY;
        }
    }
    public void X(int a) { HX[a] = 255; }
    public void W(int a, int v)
    {
        HW[a] = 255;
        lastWriteT = m.Cpu.Cyc;
        if (a >= 0x7000 && a < 0x7800) { vramW++; ov[Rel] = O_VW; Pic(); }
        else if (a >= 0x6800 && a < 0x7000)
        {
            int r = Rel;
            short lvl = (short)((v & 1) - ((v >> 5) & 1));
            if (lvl != spkLevel) { spkWrites++; ov[r] = O_SPK; }
            int idx = r / SPKBIN;
            while (spkPos < idx) spk[spkPos++] = spkLevel;
            spkLevel = lvl;
        }
    }
    void Pic()
    {
        long r = m.Cpu.Cyc - m.FrameStart;
        int ln = (int)(r / LT), t = (int)(r % LT);
        if (ln >= m.PicStart && ln < m.PicStart + 192 && t >= m.H0 && t < m.H0 + 128) picAcc++;
    }
    public void Port(int lo, int v, bool isOut)
    {
        if (isOut) { POut[lo] = 255; PValOut[lo] = v; pCount[256 + lo]++; lastWriteT = m.Cpu.Cyc; ov[Rel] = O_OUT; }
        else { PIn[lo] = 255; PValIn[lo] = v; pCount[lo]++; ov[Rel] = O_IN; }
        int key = (isOut ? 256 : 0) + lo;
        if (Recent.Count == 0 || Recent[0] != key)
        {
            Recent.Remove(key); Recent.Insert(0, key);
            if (Recent.Count > 16) Recent.RemoveAt(16);
        }
    }

    // ---------------------------------------------------------------- instructions
    public void Pre() { }

    public void Step(int pc, long t0, long t1, bool intTaken, bool halted)
    {
        long fs = m.FrameStart;
        byte st;
        if (intTaken)
        {
            if (!inIsr) { inIsr = true; isrSp = (m.Cpu.SP + 2) & 0xFFFF; isrT0 = t0; }
            intsFrame++;
            st = S_ISR;
            Prof[0x38] += t1 - t0;
        }
        else
        {
            Start[pc] = true;
            Prof[pc] += t1 - t0;
            int op = m.Peek(pc);
            Ops[op]++;
            st = inIsr ? S_ISR : halted ? S_IDLE : S_BUSY;
            if (!halted)
            {
                // routine starts: CALL nn / CALL cc,nn (when taken) and RST
                if (op == 0xCD || (op & 0xC7) == 0xC4) { if (m.Cpu.PC != ((pc + 3) & 0xFFFF)) CallTarget[m.Cpu.PC] = true; }
                else if ((op & 0xC7) == 0xC7) CallTarget[op & 0x38] = true;
            }
            if (st == S_BUSY)
            {
                // a loop that comes back to the same PC within 256 T without writing anything is waiting
                long pv = visit[pc]; visit[pc] = t0;
                if (pv != 0 && pv < t0 && pv > lastWriteT && t0 - pv < 256)
                {
                    long from = Math.Max(pv, Math.Max(idleMark, fs));
                    for (long t = from; t < t0; t++) { int r = (int)(t - fs); if (r < FT && ras[r] == S_BUSY) ras[r] = S_IDLE; }
                    st = S_IDLE;
                }
            }
            if (inIsr && (m.Cpu.SP >= isrSp || t1 - isrT0 > FT)) inIsr = false;
        }
        if (st == S_IDLE) idleMark = t1;
        int r0 = (int)(t0 - fs), r1 = (int)(t1 - fs);
        if (r0 < 0) r0 = 0; if (r1 > FT) r1 = FT;
        for (int r = r0; r < r1; r++) ras[r] = st;
        if (sampleT >= r0 && sampleT < r1 && st == S_BUSY) sampleCand = pc;
        int sp = m.Cpu.SP; if (sp >= 0x7800) { if (sp < spMin) spMin = sp; if (sp > spMaxWin) spMaxWin = sp; }
    }

    public void Dos(long t0, long t1)
    {
        DosLed = 255; lastWriteT = t1;
        long fs = m.FrameStart;
        int r0 = (int)Math.Max(0, t0 - fs), r1 = (int)Math.Min(FT, t1 - fs);
        for (int r = r0; r < r1; r++) ras[r] = S_DOS;
        if (t1 - fs > FT) dosCarry = t1 - fs - FT;
    }

    public void ResetTimes()
    {
        Array.Clear(visit, 0, visit.Length);
        lastWriteT = idleMark = 0; inIsr = false; dosCarry = 0; spkPos = 0;
    }

    // ---------------------------------------------------------------- end of a frame
    public void EndFrame()
    {
        while (spkPos < SPKN) spk[spkPos++] = spkLevel;
        spkPos = 0;
        var t = SpkShown; SpkShown = spk; spk = t;
        for (int i = 0; i < SPKN; i++) { SpkRing[SpkRingPos] = SpkShown[i]; SpkRingPos = (SpkRingPos + 1) & 2047; }
        SpkWrites = spkWrites; spkWrites = 0;

        int nb = 0, ni = 0, nd = 0, nx = 0;
        for (int i = 0; i < FT; i++)
        {
            switch (ras[i]) { case S_BUSY: case S_NONE: nb++; break; case S_ISR: ni++; break; case S_DOS: nd++; break; default: nx++; break; }
        }
        Busy = (double)nb / FT; Isr = (double)ni / FT; DosF = (double)nd / FT; Idle = (double)nx / FT;
        HBusy[HPos] = (byte)Math.Round(Busy * 100); HIsr[HPos] = (byte)Math.Round(Isr * 100); HDos[HPos] = (byte)Math.Round(DosF * 100);
        HSp[HPos] = spMin; HPos = (HPos + 1) % HIST;
        if (spMin < spMinWin) spMinWin = spMin;
        spMin = 0xFFFF;

        var b = Ras; Ras = ras; ras = b; Array.Clear(ras, 0, FT);
        b = Ov; Ov = ov; ov = b; Array.Clear(ov, 0, FT);
        if (dosCarry > 0) { for (int i = 0; i < Math.Min(FT, dosCarry); i++) ras[i] = S_DOS; dosCarry = 0; }
        Array.Copy(LineMode, LineModeShown, LINES);
        var lb = LineLat; LineLat = lineLat; lineLat = lb;
        var rb = LineRow; LineRow = lineRow; lineRow = rb;
        var fb = LineFlag; LineFlag = lineFlag; lineFlag = fb;
        Holds = holds; Splits = splits; holds = splits = 0;

        Ints = intsFrame; intsFrame = 0;
        VramW = vramW; VramR = vramR; PicAccess = picAcc; vramW = vramR = picAcc = 0;
        Array.Copy(pCount, PCountShown, 512); Array.Clear(pCount, 0, 512);

        for (int i = 0; i < 65536; i++) { HR[i] = decay[HR[i]]; HW[i] = decay[HW[i]]; HX[i] = decay[HX[i]]; }
        for (int i = 0; i < 256; i++) { PIn[i] = decay[PIn[i]]; POut[i] = decay[POut[i]]; }
        for (int i = 0; i < 8; i++) RowScan[i] = decay[decay[RowScan[i]]];
        DosLed = decay[decay[DosLed]];

        // sampled busy PC (the code panel follows it, 8 times a second)
        if (sampleCand >= 0 && Ras[sampleT] == S_BUSY) lastSample = sampleCand;
        sampleCand = -1; sampleT = rnd.Next(FT);
        frameNo++;
        if (frameNo % 6 == 0 || ShownPc < 0) ShownPc = lastSample >= 0 ? lastSample : m.Cpu.PC;

        if (++window >= 50)
        {
            window = 0;
            long tot = 0;
            for (int i = 0; i < 65536; i++) { ProfShown[i] = Prof[i]; tot += Prof[i]; Prof[i] = 0; }
            ProfShownT = tot;
            long n = 0;
            for (int i = 0; i < 256; i++) { OpsShown[i] = Ops[i]; n += Ops[i]; Ops[i] = 0; }
            OpsShownN = n;
            SpMinSecond = spMinWin; spMinWin = 0xFFFF; SpMaxSecond = spMaxWin == 0 ? 0xFFFF : spMaxWin; spMaxWin = 0;
            ProfVersion++;
        }
    }
}
