// VZonPC - small peripherals: the printer interface, the light pen and the cassette recorder.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

/// <summary>The VZ printer interface (DSE X-7320 / VTech PI 20), after MAME (devices/bus/vtech/ioexp/printer.cpp):
/// IN $00 bit 0 = BUSY (0 = ready), OUT to an even port = the data latch, OUT to an odd port = strobe.
/// The BASIC ROM's LPRINT, LLIST and COPY drive it. The printer here is always ready; what it gets goes to a
/// text file (control codes dropped, CR as a line end) and, byte for byte, to a .prn file.</summary>
public sealed class VzPrinter
{
    public bool Enabled = true;
    int data;
    public long Bytes, Lines;
    public string TextPath, RawPath;          // where printouts go (null = keep in memory only)
    StreamWriter txt; FileStream raw;
    readonly StringBuilder line = new StringBuilder();
    public readonly List<string> Recent = new List<string>();   // the last lines printed, for the visualiser
    bool lastCr;
    public long LastFrame = -1000;            // frame of the last byte (activity light)
    public Action<byte> OnByte;

    public int In(int lo) { return lo == 0x00 ? 0xFE : 0xFF; }   // never busy
    // The interface only decodes A0 within $00-$0F: BASIC writes the data to $0E and strobes $0D, and DSE's own
    // WordPro cartridge writes the data to $00 and strobes $01 (VZEM also takes data on both $0E and $00).
    public void Out(int lo, int v, long frame)
    {
        if ((lo & 1) == 0) data = v;
        else Print((byte)data, frame);
    }
    public int Data { get { return data; } }   // the latch outputs (CONTROL.VZ drives a robot from them)

    public void Print(byte b, long frame)
    {
        Bytes++; LastFrame = frame;
        if (OnByte != null) OnByte(b);
        try
        {
            if (RawPath != null) { if (raw == null) { Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(RawPath))); raw = new FileStream(RawPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite); } raw.WriteByte(b); raw.Flush(); }
            if (TextPath != null && txt == null)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(TextPath)));
                bool more = File.Exists(TextPath) && new FileInfo(TextPath).Length > 0;
                txt = new StreamWriter(new FileStream(TextPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite), new UTF8Encoding(false)) { AutoFlush = true };
                if (more) txt.Write("\r\n---- VZonPC printout, " + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + " ----\r\n\r\n");
            }
        }
        catch (Exception) { }
        if (b == 13 || (b == 10 && !lastCr)) EndLine();
        else if (b == 12) { EndLine(); Emit("\f"); }
        else if (b >= 32 && b < 127) line.Append((char)b);
        lastCr = b == 13;
    }

    void EndLine()
    {
        Lines++;
        string s = line.ToString(); line.Length = 0;
        Recent.Add(s); if (Recent.Count > 12) Recent.RemoveAt(0);
        Emit(s + "\r\n");
    }
    void Emit(string s) { if (txt != null) try { txt.Write(s); } catch (IOException) { } }

    /// <summary>The line being printed now (not ended yet).</summary>
    public string Partial { get { return line.ToString(); } }

    /// <summary>Writes out a line that hasn't ended yet (before showing the printout).</summary>
    public void Flush() { if (line.Length > 0 && txt != null) EndLine(); }

    public void Close()
    {
        if (line.Length > 0) EndLine();
        if (txt != null) { txt.Dispose(); txt = null; }
        if (raw != null) { raw.Dispose(); raw = null; }
    }
}

/// <summary>The VTech light pen interface, ports $40-$4F (MAME's lpen.cpp documents only the ports). How it works
/// comes from the light pen driver's own source (LPEN, on vz200.org): bit 6 reads 0 while the pen is pressed to
/// the screen, and bit 7 drops to 0 when the pen sees the beam go past. The driver finds the row by timing the
/// beam down a screen of bright blocks, then the column by flipping to MODE(1) at that row mid-frame and
/// lighting halves of a line until the pen sees it. Here the pen is a point on the picture (the mouse), and
/// it sees light for a short while (the photocell's response) after the beam draws a bright pixel under it.</summary>
public sealed class VzLightPen
{
    public bool Enabled;
    public int X = -1, Y = -1;          // picture pixel under the pen, 0..255 x 0..191 (-1 = away from the screen)
    public bool Down;                   // pressed against the screen
    public int Window = 48;             // T-states the photocell stays on after the beam passes (about 13 us)
    public int Threshold = 100;         // luma (0..255) the pen needs to see: green, yellow, buff, cyan, orange and text
                                        // characters count; blue, red, magenta, dark green and black don't
    public long Reads, Hits;
    public bool OnScreen { get { return X >= 0 && Y >= 0; } }
}

/// <summary>Records the cassette output (latch bits 1 and 2, written by CSAVE) to a WAV file. The VZ drives the
/// tape socket with a square wave; a real recorder's input is AC-coupled, so a level held for more than a few
/// milliseconds fades to silence.</summary>
public sealed class VzCassRecorder
{
    readonly List<long> edgeT = new List<long>(); readonly List<sbyte> edgeL = new List<sbyte>();
    long start; int clock; public string File; public bool Recording;
    public long Edges { get { return edgeT.Count; } }
    public long StartCycle { get { return start; } }

    // CSAVE writes $26 and $20: bits 1 and 2 move together. The polarity matches the cassette input, which loads
    // real VZ tapes (2018 A.D.'s CD audio) without inverting, so a recording made here loads like a real one.
    public static int Level(int latch) { return ((latch >> 1) & 1) + ((latch >> 2) & 1) - 1; }

    public void Start(string file, long cyc, int clk, int latch)
    {
        File = file; start = cyc; clock = clk; Recording = true;
        edgeT.Clear(); edgeL.Clear(); edgeT.Add(cyc); edgeL.Add((sbyte)Level(latch));
    }

    public void Latch(long cyc, int latch)
    {
        if (!Recording) return;
        int l = Level(latch);
        if (edgeL[edgeL.Count - 1] != l) { edgeT.Add(cyc); edgeL.Add((sbyte)l); }
    }

    /// <summary>Stops and writes the WAV (44.1 kHz, 16-bit mono). Returns its length in seconds.</summary>
    public double Stop(long cyc)
    {
        if (!Recording) return 0;
        Recording = false;
        const int R = 44100;
        // trim silence: from 0.5 s before the first edge to 0.5 s after the last
        long first = edgeT.Count > 1 ? edgeT[1] : start, last = edgeT.Count > 1 ? edgeT[edgeT.Count - 1] : start;
        long t0 = Math.Max(start, first - clock / 2), t1 = Math.Min(cyc, last + clock / 2);
        if (t1 < t0) t1 = t0;
        int n = (int)((t1 - t0) * (double)R / clock);
        var pcm = new short[n];
        int k = 0; long held = 0; int lvl = edgeL[0]; long lastEdge = start;
        long hold = clock / 200;   // 5 ms
        for (int i = 0; i < n; i++)
        {
            long t = t0 + (long)(i * (double)clock / R);
            while (k < edgeT.Count && edgeT[k] <= t) { lvl = edgeL[k]; lastEdge = edgeT[k]; k++; }
            held = t - lastEdge;
            pcm[i] = (short)(held > hold ? 0 : lvl * 24000);
        }
        using (var bw = new BinaryWriter(System.IO.File.Create(File)))
        {
            bw.Write(new[] { 'R', 'I', 'F', 'F' }); bw.Write(36 + n * 2); bw.Write(new[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
            bw.Write(16); bw.Write((short)1); bw.Write((short)1); bw.Write(R); bw.Write(R * 2); bw.Write((short)2); bw.Write((short)16);
            bw.Write(new[] { 'd', 'a', 't', 'a' }); bw.Write(n * 2); foreach (var v in pcm) bw.Write(v);
        }
        edgeT.Clear(); edgeL.Clear();
        return n / (double)R;
    }
}
