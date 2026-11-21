// VZonPC - the Dick Smith VZ disk drive: the DD20 / X-7304 controller and two 5.25" 40-track drives.
// Hardware model after MAME (devices/bus/vtech/memexp/floppy.cpp, lib/formats/vt_dsk.cpp):
//   $4000-$5FFF  the controller's 8K DOS ROM (roms\vzdos.rom)
//   OUT $10      latch: bits 0-3 stepper phases, 4 drive 1 select, 5 write data, 6 /write request, 7 drive 2 select
//   IN  $11      shift register: shifts in NOT(latching inverter), clears the inverter, returns the 8 bits
//   IN  $12      bit 7 = the latching inverter, which toggles on every flux transition under the head
//   IN  $13      bit 7 = write protect
// The DOS does the encoding in software: every bit cell starts with a flux transition, and a 1 has a second one
// 7.9 us later. The cell is 32.4 us, and the disk turns at 85 RPM. Each track is held as flux transition
// positions in 1/200,000,000ths of a revolution (as MAME does), so the DOS's own read and write timing counts.
using System;
using System.Collections.Generic;
using System.IO;

public sealed class VzDisk
{
    public const int TRACKS = 40, SECTORS = 16, SECSIZE = 128, SIZE = TRACKS * SECTORS * SECSIZE;
    public const int REV = 200000000;                    // flux units per revolution
    public const int CELL = 9187, ONE = 2237;           // bit cell, and the position of a 1's extra transition
    public static readonly int[] SectorMap = { 0x0, 0xb, 0x6, 0x1, 0xc, 0x7, 0x2, 0xd, 0x8, 0x3, 0xe, 0x9, 0x4, 0xf, 0xa, 0x5 };

    public string Path;                  // null = not backed by a file
    public bool WriteProtect;
    public bool Dirty;                   // written since it was last saved
    public long DirtyFrame;
    public readonly byte[] Data = new byte[SIZE];       // the logical disk, 40 x 16 x 128
    readonly int[][] flux = new int[TRACKS][];           // sorted transition positions per track
    readonly int[] fluxEnd = new int[TRACKS];            // where the formatted part of each track ends

    public static VzDisk Blank()
    {
        var d = new VzDisk();
        for (int t = 0; t < TRACKS; t++) d.BuildTrack(t);
        return d;
    }

    public static VzDisk Load(string path)
    {
        var d = new VzDisk { Path = path };
        byte[] f = File.ReadAllBytes(path);
        int found = d.Parse(f);
        if (found == 0) throw new InvalidDataException("no VZ disk sectors found in " + System.IO.Path.GetFileName(path));
        try { d.WriteProtect = (File.GetAttributes(path) & FileAttributes.ReadOnly) != 0; } catch { }
        for (int t = 0; t < TRACKS; t++) d.BuildTrack(t);
        return d;
    }

    /// <summary>Reads sectors from a raw track image (.dsk/.dvz of any size, as MAME does: scan for the marks).
    /// Returns the number of sectors found.</summary>
    int Parse(byte[] f)
    {
        const ulong HDR = 0x80808000FEE718C3UL, DAT = 0x80808000C318E7FEUL;
        ulong win = 0; int state = 0, trk = 0, sec = 0, n = 0, found = 0;
        for (int i = 0; i < f.Length; i++)
        {
            byte b = f[i];
            win = (win << 8) | b;
            switch (state)
            {
                case 0: if (win == HDR) state = 1; else if (win == DAT) state = 0; break;
                case 1: trk = b; state = 2; break;
                case 2: sec = b; state = 3; break;
                case 3: state = ((trk + sec) & 0xFF) == b && trk < TRACKS && sec < SECTORS ? 4 : 0; break;
                case 4: if (win == DAT) { state = 5; n = 0; } else if (win == HDR) state = 1; break;
                case 5:
                    Data[(trk * SECTORS + sec) * SECSIZE + n] = b;
                    if (++n == SECSIZE) { state = 0; found++; }
                    break;
            }
        }
        return found;
    }

    /// <summary>The 155-byte-per-sector layout MAME writes (99,200 bytes), sectors in their interleaved order.</summary>
    public byte[] ToDsk()
    {
        var o = new List<byte>(TRACKS * SECTORS * 155);
        for (int t = 0; t < TRACKS; t++)
            foreach (int s in SectorMap) o.AddRange(SectorBytes(t, s));
        return o.ToArray();
    }

    List<byte> SectorBytes(int t, int s)
    {
        var o = new List<byte>(155);
        for (int i = 0; i < 7; i++) o.Add(0x80);
        o.Add(0); o.Add(0xFE); o.Add(0xE7); o.Add(0x18); o.Add(0xC3);
        o.Add((byte)t); o.Add((byte)s); o.Add((byte)(t + s));
        for (int i = 0; i < 5; i++) o.Add(0x80);
        o.Add(0); o.Add(0xC3); o.Add(0x18); o.Add(0xE7); o.Add(0xFE);
        int chk = 0, b0 = (t * SECTORS + s) * SECSIZE;
        for (int i = 0; i < SECSIZE; i++) { o.Add(Data[b0 + i]); chk += Data[b0 + i]; }
        o.Add((byte)chk); o.Add((byte)(chk >> 8));
        return o;
    }

    public void Save()
    {
        if (Path == null || !Dirty) return;
        File.WriteAllBytes(Path, ToDsk());
        Dirty = false;
    }

    // ---------------------------------------------------------------- flux
    void BuildTrack(int t)
    {
        var f = new List<int>(20000 * 2);
        int pos = 0;
        Action<bool> bit = one => { f.Add(pos); if (one) { f.Add(pos + ONE); } pos += CELL; };
        bit(false);
        foreach (int s in SectorMap)
            foreach (byte b in SectorBytes(t, s))
                for (int i = 7; i >= 0; i--) bit(((b >> i) & 1) != 0);
        flux[t] = f.ToArray(); fluxEnd[t] = pos;
    }

    /// <summary>Number of flux transitions on a track in the half-open window (a, b] of revolution units,
    /// where a and b are absolute (they can span several revolutions).</summary>
    public long Count(int t, double a, double b)
    {
        if (t < 0 || t >= TRACKS || b <= a) return 0;
        var f = flux[t]; if (f.Length == 0) return 0;
        double ra = Math.Floor(a / REV), rb = Math.Floor(b / REV);
        int pa = (int)(a - ra * REV), pb = (int)(b - rb * REV);
        long revs = (long)(rb - ra);
        // count(<= pb) - count(<= pa) + revs * total
        return revs * f.Length + Upper(f, pb) - Upper(f, pa);
    }
    static int Upper(int[] f, int p)   // number of entries <= p
    {
        int lo = 0, hi = f.Length;
        while (lo < hi) { int mid = (lo + hi) >> 1; if (f[mid] <= p) lo = mid + 1; else hi = mid; }
        return lo;
    }

    /// <summary>Replaces the part of a track between two absolute positions with the transitions written there,
    /// then decodes the track again into the logical sectors.</summary>
    public void Splice(int t, double start, double end, List<double> written)
    {
        if (t < 0 || t >= TRACKS || end <= start) return;
        var keep = new List<int>();
        if (end - start >= REV) { /* a whole revolution or more: nothing old survives */ }
        else
        {
            int ps = (int)(start % REV), pe = (int)(end % REV);
            foreach (int p in flux[t])
            {
                bool inside = ps <= pe ? (p >= ps && p < pe) : (p >= ps || p < pe);
                if (!inside) keep.Add(p);
            }
        }
        foreach (double w in written) keep.Add((int)(w % REV));
        keep.Sort();
        flux[t] = keep.ToArray();
        fluxEnd[t] = REV;
        Decode(t);
        Dirty = true;
    }

    /// <summary>Turns a track's flux back into bits and finds its sectors (twice round, so a sector over the
    /// index is still found). Cells are told apart by spacing: a short gap is a 1, about one cell is a 0.</summary>
    public int Decode(int t)
    {
        var f = flux[t]; int n = f.Length; if (n < 2) return 0;
        const ulong HDR = 0x80808000FEE718C3UL, DAT = 0x80808000C318E7FEUL;
        ulong win = 0; int bits = 0, state = 0, trk = 0, sec = 0, k = 0, found = 0, cur = 0;
        byte[] buf = new byte[SECSIZE + 2];
        int i = 0;
        Func<int, long> Pos = j => f[j % n] + (long)(j / n) * REV;
        while (i < 2 * n - 1)
        {
            long d = Pos(i + 1) - Pos(i);
            int bit;
            if (d < CELL / 2) { bit = 1; i += 2; }
            else if (d < CELL * 3 / 2) { bit = 0; i += 1; }
            else { i += 1; win = 0; bits = 0; state = 0; continue; }   // unformatted gap
            win = (win << 1) | (uint)bit; cur = (cur << 1) | bit; bits++;
            if (state == 0 || state == 4)
            {
                if (win == HDR) { state = 1; bits = 0; cur = 0; }
                else if (state == 4 && win == DAT) { state = 5; bits = 0; cur = 0; k = 0; }
                continue;
            }
            if (bits < 8) continue;
            byte b = (byte)cur; bits = 0; cur = 0;
            switch (state)
            {
                case 1: trk = b; state = 2; break;
                case 2: sec = b; state = 3; break;
                case 3: state = ((trk + sec) & 0xFF) == b && trk == t && sec < SECTORS ? 4 : 0; break;
                case 5:
                    buf[k++] = b;
                    if (k == SECSIZE + 2)
                    {
                        int chk = 0; for (int j = 0; j < SECSIZE; j++) chk += buf[j];
                        if ((chk & 0xFFFF) == (buf[SECSIZE] | (buf[SECSIZE + 1] << 8)))
                        { Array.Copy(buf, 0, Data, (trk * SECTORS + sec) * SECSIZE, SECSIZE); found++; }
                        state = 0; win = 0;
                    }
                    break;
            }
        }
        return found;
    }

    // ---------------------------------------------------------------- directory (for the status bar / menus)
    /// <summary>The files in the directory (track 0, sectors 0-14): "B:NAME" or "T:NAME".</summary>
    public List<string> Directory()
    {
        var r = new List<string>();
        for (int s = 0; s < 15; s++)
            for (int e = 0; e < 8; e++)
            {
                int o = s * SECSIZE + e * 16;
                byte ty = Data[o];
                if (ty == 0) return r;
                if (ty == 1) continue;   // deleted
                var name = new System.Text.StringBuilder();
                for (int i = 2; i < 10; i++) name.Append((char)(Data[o + i] & 0x7F));
                r.Add((char)(ty & 0x7F) + ":" + name.ToString().TrimEnd());
            }
        return r;
    }
}

public sealed class VzFloppy
{
    readonly VzMachine m;
    public readonly VzDisk[] Drive = new VzDisk[2];
    public byte[] Rom;                  // 8K DOS ROM, or null
    public string RomName;
    public int Latch = 0xFF;
    int sel = -1;                       // selected drive, -1 = none
    public int HalfTrack;               // head position of the selected drive, in half tracks
    readonly int[] headHalf = new int[2];
    int shifter; bool inverter; double lastUnits;
    bool writing; double wStart; readonly List<double> wFlux = new List<double>(); int wTrack;
    public long Reads, Writes, Steps; public int LastTrack = -1;
    public bool Active;                 // the motor is on (a drive is selected)

    public VzFloppy(VzMachine machine) { m = machine; }

    public int Track { get { return HalfTrack >> 1; } }
    public bool Writing { get { return writing; } }
    public bool Inverter { get { return inverter; } }
    /// <summary>Where the disk is under the head now, 0..1 of a revolution.</summary>
    public double Angle { get { double u = Units(m.Cpu.Cyc); return (u % VzDisk.REV) / VzDisk.REV; } }
    public int Selected { get { return sel; } }

    /// <summary>The disk's position in absolute flux units (revolutions x REV) at CPU T-state cyc.</summary>
    double Units(long cyc)
    {
        double rev = m.Clock * 60.0 / 85.0;   // T-states per revolution at 85 RPM
        return cyc / rev * VzDisk.REV;
    }

    public void LoadRom(string dir)
    {
        Rom = null; RomName = null;
        foreach (var n in new[] { "vzdos.rom", "vzdos12.rom", "vzdos.bin", "dd20.rom" })
        {
            string p = Path.Combine(dir, n);
            if (File.Exists(p) && new FileInfo(p).Length == 0x2000) { Rom = File.ReadAllBytes(p); RomName = n; return; }
        }
    }

    public void Reset()
    {
        EndWrite(m.Cpu.Cyc);
        Latch = 0xFF; sel = -1; Active = false; shifter = 0; inverter = false;
    }

    void Update(long cyc)
    {
        double u = Units(cyc);
        if (sel >= 0 && Drive[sel] != null && !writing && u > lastUnits)
            if ((Drive[sel].Count(Track, lastUnits, u) & 1) != 0) inverter = !inverter;
        lastUnits = u;
    }

    public int In(int lo, long cyc)
    {
        switch (lo)
        {
            case 0x11: Update(cyc); shifter = ((shifter << 1) | (inverter ? 0 : 1)) & 0xFF; inverter = false; Reads++; return shifter;
            case 0x12: Update(cyc); return inverter ? 0x80 : 0x00;
            case 0x13: return sel >= 0 && Drive[sel] != null && Drive[sel].WriteProtect ? 0x80 : 0x00;
        }
        return 0xFF;
    }

    public void Out(int lo, int v, long cyc)
    {
        if (lo != 0x10) return;
        Update(cyc);
        int diff = Latch ^ v;
        Latch = v;
        int ns = (v & 0x10) != 0 ? 0 : (v & 0x80) != 0 ? 1 : -1;
        if (ns != sel)
        {
            EndWrite(cyc);
            if (sel >= 0) headHalf[sel] = HalfTrack;
            sel = ns; Active = sel >= 0;
            if (sel >= 0) HalfTrack = headHalf[sel];
            inverter = false;
        }
        if (sel < 0) return;
        // write request (bit 6 low) and write data (every change of bit 5 is a flux transition)
        if ((diff & 0x40) != 0)
        {
            if ((v & 0x40) == 0) BeginWrite(cyc); else EndWrite(cyc);
        }
        if (writing && (diff & 0x20) != 0) wFlux.Add(Units(cyc));
        // stepper: the head follows the energised phase next to the one it sits on
        int cph = HalfTrack & 3, prev = HalfTrack;
        if ((v & (1 << cph)) == 0)
        {
            if (HalfTrack < 84 * 2 && (v & (1 << ((cph + 1) & 3))) != 0) HalfTrack++;
            if (HalfTrack > 0 && (v & (1 << ((cph + 3) & 3))) != 0) HalfTrack--;
            if (HalfTrack != prev && (HalfTrack & 1) == 0)
            {
                if (HalfTrack > (VzDisk.TRACKS - 1) * 2) HalfTrack = (VzDisk.TRACKS - 1) * 2;   // the drive's end stop
                Steps++; EndWrite(cyc);
            }
        }
    }

    void BeginWrite(long cyc)
    {
        if (sel < 0 || Drive[sel] == null || Drive[sel].WriteProtect) return;
        writing = true; wStart = Units(cyc); wFlux.Clear(); wTrack = Track;
    }

    void EndWrite(long cyc)
    {
        if (!writing) return;
        writing = false;
        var d = sel >= 0 ? Drive[sel] : null;
        if (d == null) return;
        d.Splice(wTrack, wStart, Units(cyc), wFlux);
        d.DirtyFrame = m.Frames; Writes++; LastTrack = wTrack;
        wFlux.Clear();
        lastUnits = Units(cyc);
    }

    /// <summary>Saves written disks back to their files once nothing has been written for a second.</summary>
    public void Tick()
    {
        if (writing && Units(m.Cpu.Cyc) - wStart > VzDisk.REV) { long c = m.Cpu.Cyc; EndWrite(c); if (sel >= 0) BeginWrite(c); }
        for (int i = 0; i < 2; i++)
        {
            var d = Drive[i];
            if (d != null && d.Dirty && !writing && m.Frames - d.DirtyFrame > 50)
                try { d.Save(); } catch (Exception ex) { m.Log("disk save failed: " + ex.Message); d.Dirty = false; }
        }
    }

    public void Insert(int n, VzDisk d) { Eject(n); Drive[n] = d; }
    public void Eject(int n)
    {
        if (n == sel) EndWrite(m.Cpu.Cyc);
        var d = Drive[n]; Drive[n] = null;
        if (d != null && d.Dirty) try { d.Save(); } catch (Exception ex) { m.Log("disk save failed: " + ex.Message); }
    }
    public void SaveAll() { for (int i = 0; i < 2; i++) if (Drive[i] != null && Drive[i].Dirty) try { Drive[i].Save(); } catch { } }
}
