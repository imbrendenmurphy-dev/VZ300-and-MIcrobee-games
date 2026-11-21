using System;
using System.IO;

/// <summary>Cassette input: a WAV file played into the VZ's tape socket ($6800 bit 6), in step with the CPU clock.
/// PCM 8 or 16 bit, mono or stereo (pick the channel; 2018 A.D.'s CD audio has the data on the left and music on the
/// right). The level goes through a Schmitt trigger like the VZ's input stage.</summary>
public class VzTape
{
    public string Name;
    public int Rate;
    short[] s;                      // the chosen channel, 16-bit signed
    short[] mon;                    // the other channel of a stereo file (2018 A.D.'s music), played through the PC
    long startCyc; double clock;
    public bool Playing;
    public bool Invert;
    bool level;
    // The VZ's tape input is an inverting comparator whose threshold sits a little above zero, so silence reads the
    // same as no tape (bit 6 = 1). Real-hardware evidence: 2018 A.D.'s CD audio loads only this way round, and its
    // speedloader needs the silence after each block to read as 1 to finish the last bit. A small band gives hysteresis.
    const int THR_LO = 300, THR_HI = 1200;

    public static VzTape Load(string path, int channel)   // channel: 0 left/mono, 1 right, -1 mix
    {
        if (!path.EndsWith(".wav", StringComparison.OrdinalIgnoreCase))
        {
            // Ogg, MP3, FLAC...: Windows' own decoders, through Media Foundation
            int rate, ch;
            short[] pcm = MfAudio.Decode(path, out rate, out ch);
            var m = new VzTape { Name = Path.GetFileName(path), Rate = rate };
            if (channel >= ch) channel = 0;
            int n = pcm.Length / ch;
            m.s = new short[n];
            if (ch >= 2 && channel >= 0) m.mon = new short[n];
            for (int i = 0; i < n; i++)
            {
                if (m.mon != null) m.mon[i] = pcm[i * ch + (1 - channel)];
                if (channel >= 0) m.s[i] = pcm[i * ch + channel];
                else { int acc = 0; for (int c = 0; c < ch; c++) acc += pcm[i * ch + c]; m.s[i] = (short)(acc / ch); }
            }
            return m;
        }
        var t = new VzTape { Name = Path.GetFileName(path) };
        using (var br = new BinaryReader(File.OpenRead(path)))
        {
            if (new string(br.ReadChars(4)) != "RIFF") throw new Exception("not a WAV file");
            br.ReadInt32();
            if (new string(br.ReadChars(4)) != "WAVE") throw new Exception("not a WAV file");
            int fmt = 0, ch = 0, bits = 0; byte[] data = null;
            while (br.BaseStream.Position + 8 <= br.BaseStream.Length)
            {
                string id = new string(br.ReadChars(4)); int len = br.ReadInt32();
                long next = br.BaseStream.Position + len + (len & 1);
                if (id == "fmt ")
                {
                    fmt = br.ReadInt16(); ch = br.ReadInt16(); t.Rate = br.ReadInt32(); br.ReadInt32(); br.ReadInt16(); bits = br.ReadInt16();
                    if (fmt == unchecked((short)0xFFFE) && len >= 26) { br.ReadInt16(); br.ReadInt16(); br.ReadInt32(); fmt = br.ReadInt16(); }
                }
                else if (id == "data") data = br.ReadBytes((int)Math.Min(len, br.BaseStream.Length - br.BaseStream.Position));
                if (next > br.BaseStream.Length) break;
                br.BaseStream.Position = next;
            }
            if (data == null || fmt != 1 || (bits != 8 && bits != 16) || ch < 1)
                throw new Exception("needs a PCM WAV, 8 or 16 bit (this one: format " + fmt + ", " + bits + " bit)");
            int bps = bits / 8, frame = bps * ch, n = data.Length / frame;
            if (channel >= ch) channel = 0;
            t.s = new short[n];
            if (ch >= 2 && channel >= 0) t.mon = new short[n];
            for (int i = 0; i < n; i++)
            {
                int acc = 0, cnt = 0;
                for (int c = 0; c < ch; c++)
                {
                    if (channel >= 0 && c != channel) continue;
                    int o = i * frame + c * bps;
                    acc += bits == 8 ? (data[o] - 128) << 8 : (short)(data[o] | (data[o + 1] << 8));
                    cnt++;
                }
                t.s[i] = (short)(acc / cnt);
                if (t.mon != null) { int o = i * frame + (1 - channel) * bps; t.mon[i] = bits == 8 ? (short)((data[o] - 128) << 8) : (short)(data[o] | (data[o + 1] << 8)); }
            }
        }
        return t;
    }

    public double Seconds { get { return s.Length / (double)Rate; } }
    public short[] Samples { get { return s; } }

    public bool HasMonitor { get { return mon != null; } }

    /// <summary>The other channel's sample at CPU cycle cyc (0 when there is none).</summary>
    public int Monitor(double cyc)
    {
        if (!Playing || mon == null) return 0;
        long i = (long)((cyc - startCyc) * Rate / clock);
        return i >= 0 && i < mon.Length ? mon[i] : 0;
    }

    public void Play(long cyc, double clockHz) { startCyc = cyc; clock = clockHz; Playing = true; }

    public double Position(long cyc) { return Playing ? (cyc - startCyc) / clock : 0; }

    /// <summary>The tape input bit at CPU cycle cyc.</summary>
    public bool Level(long cyc)
    {
        if (!Playing) return true;
        long i = (long)((cyc - startCyc) * Rate / clock);
        if (i < 0) return true;
        if (i >= s.Length) { Playing = false; return true; }
        int v = s[i];
        if (v > THR_HI) level = true; else if (v < THR_LO) level = false;
        return level == Invert;      // inverting input: a high signal reads as bit 6 = 0
    }
}
