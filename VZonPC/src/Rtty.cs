// VZonPC - the Dick Smith VZ-200/300 RTTY interface (K-6318).
// Memory map after MAME (devices/bus/vtech/memexp/rtty.cpp), which only stubs the signals:
//   $4000-$4FFF  4K ROM (roms\vzrtty.ic3)
//   $5000-$57FF  read: bit 7 = receive data from the demodulator
//   $5800-$5FFF  write: bit 7 = transmit data
//   $6000-$67FF  write: bit 7 = the relay (push-to-talk)
// The RTTY software does the 45.45 baud Baudot timing itself. Here the receive side is fed from an audio file
// (a recording of RTTY off air, or one made with fldigi) through an AFSK demodulator, mark 2125 Hz and
// space 2295 Hz (170 Hz shift), and the transmit side plays those tones through the speakers while the relay
// is keyed. Polarity, from the ROM itself: it waits for the receive bit to drop to 0 for a start bit (so mark
// reads 1), writes $FF to $5800 for the stop bit and 0 for the start bit (so 1 = mark), and writes $FF to $6000
// to key the transmitter. It offers 45, 50, 75 and 110 baud, in 5-bit Baudot. Both sides can be flipped.
using System;
using System.IO;

public sealed class VzRtty
{
    readonly VzMachine m;
    public byte[] Rom; public string RomName;
    public bool TxMark = true, Ptt;
    public bool RxInvert, TxInvert;
    public bool Loopback;                // receive what is being transmitted (a self-test)
    public double MarkHz = 2125, SpaceHz = 2295;
    public long TxChanges, RxReads;

    // receive audio, demodulated to one bit per sample at load time
    public string RxName; int rate; bool[] rxBits; long rxStart; public bool RxPlaying;
    double phase;

    public VzRtty(VzMachine machine) { m = machine; }

    // history for the visualiser: one sample every 52 lines (about 3.3 ms): bit 0 RX mark, 1 TX mark, 2 PTT, 3 RX read lately
    public readonly byte[] Hist = new byte[1024]; public int HistPos; int histLines; long lastReads;
    public void SampleLine(long cyc)
    {
        if (++histLines < 52) return;
        histLines = 0;
        Hist[HistPos] = (byte)((RxMark(cyc) ? 1 : 0) | (TxMark ? 2 : 0) | (Ptt ? 4 : 0) | (RxReads != lastReads ? 8 : 0));
        lastReads = RxReads; HistPos = (HistPos + 1) & 1023;
    }

    public void LoadRom(string dir)
    {
        Rom = null; RomName = null;
        foreach (var n in new[] { "vzrtty.ic3", "vzrtty.rom", "rtty.rom", "vzrtty.bin" })
        {
            string p = Portable.Find(dir, n);
            if (File.Exists(p) && new FileInfo(p).Length == 0x1000) { Rom = File.ReadAllBytes(p); RomName = n; return; }
        }
    }

    public void Reset() { TxMark = true; Ptt = false; }

    public bool RxMark(long cyc)
    {
        if (Loopback) return TxMark;
        if (!RxPlaying || rxBits == null) return true;   // no signal: the demodulator idles on mark
        long i = (long)((cyc - rxStart) * (double)rate / m.Clock);
        if (i < 0) return true;
        if (i >= rxBits.Length) { RxPlaying = false; return true; }
        return rxBits[i];
    }

    public int Read(int a, long cyc)
    {
        if (a < 0x5000) return Rom != null ? Rom[a - 0x4000] : 0xFF;
        if (a < 0x5800) { RxReads++; return 0x7F | ((RxMark(cyc) ^ RxInvert) ? 0x80 : 0); }
        return 0xFF;
    }

    public void Write(int a, int v)
    {
        if (a >= 0x5800 && a < 0x6000)
        {
            bool mk = ((v & 0x80) != 0) ^ TxInvert;
            if (mk != TxMark) { TxChanges++; if (rec != null) rec.Add(new long[] { m.Cpu.Cyc, mk ? 1 : 0, Ptt ? 1 : 0 }); }
            TxMark = mk;
        }
        else if (a >= 0x6000 && a < 0x6800)
        {
            bool p = (v & 0x80) != 0;
            if (p != Ptt && rec != null) rec.Add(new long[] { m.Cpu.Cyc, TxMark ? 1 : 0, p ? 1 : 0 });
            Ptt = p;
        }
    }

    // recording the transmitter to a WAV (vzemu rttytx FILE ... rttytxend)
    System.Collections.Generic.List<long[]> rec; long recStart; string recFile;
    public void RecordTx(string file) { rec = new System.Collections.Generic.List<long[]>(); recStart = m.Cpu.Cyc; recFile = file; }
    public void EndRecordTx()
    {
        if (rec == null) return;
        const int R = 44100;
        long end = m.Cpu.Cyc; int n = (int)((end - recStart) * (double)R / m.Clock);
        var pcm = new short[n]; double ph = 0; int k = 0; bool mk = TxMark, p = Ptt;
        if (rec.Count > 0) { mk = true; p = Ptt; }
        for (int i = 0; i < n; i++)
        {
            long cyc = recStart + (long)(i * (double)m.Clock / R);
            while (k < rec.Count && rec[k][0] <= cyc) { mk = rec[k][1] != 0; p = rec[k][2] != 0; k++; }
            if (!p) { pcm[i] = 0; continue; }
            ph += 2 * Math.PI * (mk ? MarkHz : SpaceHz) / R;
            pcm[i] = (short)(Math.Sin(ph) * 12000);
        }
        using (var bw = new BinaryWriter(File.Create(recFile)))
        {
            bw.Write(new[] { 'R', 'I', 'F', 'F' }); bw.Write(36 + n * 2); bw.Write(new[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
            bw.Write(16); bw.Write((short)1); bw.Write((short)1); bw.Write(R); bw.Write(R * 2); bw.Write((short)2); bw.Write((short)16);
            bw.Write(new[] { 'd', 'a', 't', 'a' }); bw.Write(n * 2); foreach (var v in pcm) bw.Write(v);
        }
        rec = null;
    }

    /// <summary>The transmit tone for one output sample (silent unless the relay is keyed).</summary>
    public int Tone(int sampleRate)
    {
        if (!Ptt) return 0;
        phase += 2 * Math.PI * (TxMark ? MarkHz : SpaceHz) / sampleRate;
        if (phase > 2 * Math.PI) phase -= 2 * Math.PI;
        return (int)(Math.Sin(phase) * 5000);
    }

    /// <summary>Plays an audio file into the receiver from now (WAV, or FLAC/MP3 through Windows).</summary>
    public void PlayRx(string path, long cyc)
    {
        var t = VzTape.Load(path, -1);
        short[] s = t.Samples; rate = t.Rate; RxName = Path.GetFileName(path);
        rxBits = Demodulate(s, rate, MarkHz, SpaceHz);
        rxStart = cyc; RxPlaying = true;
    }

    /// <summary>AFSK demodulator: mixes with the mark and space tones, low-passes each (two poles at ~65 Hz,
    /// fine for 45 to 75 baud), and compares the two. With no signal it holds mark.</summary>
    public static bool[] Demodulate(short[] s, int rate, double fm, double fs)
    {
        var r = new bool[s.Length];
        double a = 1 - Math.Exp(-2 * Math.PI * 65 / rate);
        double wm = 2 * Math.PI * fm / rate, ws = 2 * Math.PI * fs / rate;
        double mi1 = 0, mq1 = 0, mi2 = 0, mq2 = 0, si1 = 0, sq1 = 0, si2 = 0, sq2 = 0, env = 0;
        bool mark = true;
        for (int i = 0; i < s.Length; i++)
        {
            double x = s[i] / 32768.0;
            env += (Math.Abs(x) - env) * 0.002;
            mi1 += (x * Math.Cos(wm * i) - mi1) * a; mq1 += (x * Math.Sin(wm * i) - mq1) * a;
            si1 += (x * Math.Cos(ws * i) - si1) * a; sq1 += (x * Math.Sin(ws * i) - sq1) * a;
            mi2 += (mi1 - mi2) * a; mq2 += (mq1 - mq2) * a; si2 += (si1 - si2) * a; sq2 += (sq1 - sq2) * a;
            double pm = mi2 * mi2 + mq2 * mq2, ps = si2 * si2 + sq2 * sq2;
            if (env < 0.005) mark = true;                 // squelch
            else if (pm > ps * 1.2) mark = true;
            else if (ps > pm * 1.2) mark = false;
            r[i] = mark;
        }
        return r;
    }
}
