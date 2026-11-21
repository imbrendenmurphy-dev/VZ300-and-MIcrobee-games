// VZonPC: an SD card on the BennVenn's SPI port ($39), presented as a FAT32 volume built from a PC folder.
// Used when the real VZDOS (VZDOS.VZ) is running. File data is read from the PC files on demand.
// Changes the DOS makes (SAVE, delete, rename, new folders) are written back to the PC folder by Flush(),
// which the machine calls once the card has been quiet for half a second, at power-off and at exit.
// Deleted files go to the Windows Recycle Bin.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public sealed class SdCard
{
    public const int SPC = 8, RES = 32, SEC = 512;          // 4K clusters, like a typical card
    const int MAXFILES = 20000; const long MAXBYTES = 2L << 30;

    public readonly string Root;
    readonly List<uint> fat = new List<uint> { 0x0FFFFFF8, 0x0FFFFFFF };
    readonly Dictionary<long, byte[]> meta = new Dictionary<long, byte[]>();   // boot sector + directories
    readonly Dictionary<long, byte[]> written = new Dictionary<long, byte[]>();
    readonly List<string> paths = new List<string>();
    int[] owner;  // per cluster: file index, or -1
    int[] ownIdx; // cluster number within the file
    int fatSz; long data0, totalSec;
    int nfiles; long nbytes;
    public int FileCount { get { return paths.Count; } }
    public long Reads, Writes;

    // ------------------------------------------------------------ building the volume
    sealed class Dir { public int Clus; public List<byte[]> Ents = new List<byte[]>(); }
    readonly List<Dir> dirs = new List<Dir>();
    readonly List<KeyValuePair<int, int>> fileClus = new List<KeyValuePair<int, int>>();  // first cluster, count (per file)

    public SdCard(string root)
    {
        Root = root;
        var rootDir = new Dir { Clus = Alloc(1) };   // cluster 2
        dirs.Add(rootDir);
        if (Directory.Exists(root)) AddDir(rootDir, root, 0, 0);
        Finish();
    }

    int Alloc(int n)
    {
        int first = fat.Count;
        for (int i = 0; i < n; i++) fat.Add(i < n - 1 ? (uint)(first + i + 1) : 0x0FFFFFFF);
        return first;
    }

    static byte[] Ent(string name11, int attr, int clus, long size, DateTime t)
    {
        var b = new byte[32];
        Encoding.ASCII.GetBytes(name11, 0, 11, b, 0);
        b[11] = (byte)attr;
        int d = t.Year < 1980 ? (1 << 5) | 1 : ((t.Year - 1980) << 9) | (t.Month << 5) | t.Day;
        int tm = (t.Hour << 11) | (t.Minute << 5) | (t.Second / 2);
        b[0x14] = (byte)(clus >> 16); b[0x15] = (byte)(clus >> 24);
        b[0x16] = (byte)tm; b[0x17] = (byte)(tm >> 8); b[0x18] = (byte)d; b[0x19] = (byte)(d >> 8);
        b[0x1A] = (byte)clus; b[0x1B] = (byte)(clus >> 8);
        b[0x1C] = (byte)size; b[0x1D] = (byte)(size >> 8); b[0x1E] = (byte)(size >> 16); b[0x1F] = (byte)(size >> 24);
        return b;
    }

    static string Clean(string s)
    {
        var sb = new StringBuilder();
        foreach (char c in s.ToUpperInvariant())
            if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || "!#$%&'()-@^_`{}~".IndexOf(c) >= 0) sb.Append(c);
        return sb.ToString();
    }

    /// <summary>8.3 short name (11 chars, space padded); long or odd names get a ~N alias.</summary>
    static string ShortName(string name, bool isDir, HashSet<string> used)
    {
        string bn = isDir ? name : Path.GetFileNameWithoutExtension(name), ex = isDir ? "" : Path.GetExtension(name).TrimStart('.');
        string b = Clean(bn), e = Clean(ex);
        if (e.Length > 3) e = e.Substring(0, 3);
        bool fits = b.Length > 0 && b.Length <= 8 && b == bn.ToUpperInvariant() && e == ex.ToUpperInvariant() && name.Split('.').Length <= 2;
        string n11;
        if (fits) n11 = b.PadRight(8) + e.PadRight(3);
        else
        {
            if (b.Length == 0) b = "FILE";
            int k = 1;
            do { string t = "~" + k; n11 = (b.Length > 8 - t.Length ? b.Substring(0, 8 - t.Length) : b) + t; n11 = n11.PadRight(8) + e.PadRight(3); k++; }
            while (used.Contains(n11));
        }
        if (used.Contains(n11))
        {
            int k = 1; string b2 = n11.Substring(0, 8).TrimEnd();
            do { string t = "~" + k; n11 = ((b2.Length > 8 - t.Length ? b2.Substring(0, 8 - t.Length) : b2) + t).PadRight(8) + n11.Substring(8); k++; }
            while (used.Contains(n11));
        }
        used.Add(n11);
        return n11;
    }

    void AddDir(Dir d, string path, int parentClus, int depth)
    {
        var used = new HashSet<string>();
        if (depth > 0)
        {
            d.Ents.Add(Ent(".          ", 0x10, d.Clus, 0, Directory.GetLastWriteTime(path)));
            d.Ents.Add(Ent("..         ", 0x10, parentClus, 0, Directory.GetLastWriteTime(path)));
        }
        string[] subs, files;
        try { subs = Directory.GetDirectories(path); files = Directory.GetFiles(path); } catch { return; }
        Array.Sort(subs, StringComparer.OrdinalIgnoreCase); Array.Sort(files, StringComparer.OrdinalIgnoreCase);
        foreach (var s in subs)
        {
            var fi = new DirectoryInfo(s);
            if ((fi.Attributes & (FileAttributes.Hidden | FileAttributes.System)) != 0 || depth >= 8) continue;
            var sd = new Dir { Clus = Alloc(1) };
            dirs.Add(sd);
            string sn = ShortName(fi.Name, true, used);
            d.Ents.Add(Ent(sn, 0x10, sd.Clus, 0, fi.LastWriteTime));
            AddNode(new Node { IsDir = true, Clus = sd.Clus, Parent = d.Clus, Name11 = sn, PcPath = s });
            AddDir(sd, s, depth == 0 ? 0 : d.Clus, depth + 1);
        }
        foreach (var f in files)
        {
            var fi = new FileInfo(f);
            if ((fi.Attributes & (FileAttributes.Hidden | FileAttributes.System)) != 0) continue;
            if (nfiles >= MAXFILES || nbytes + fi.Length > MAXBYTES || fi.Length > 0xFFFFFFFFL) continue;
            int n = (int)((fi.Length + SPC * SEC - 1) / (SPC * SEC));
            int c = n > 0 ? Alloc(n) : 0;
            if (n > 0) { fileClus.Add(new KeyValuePair<int, int>(c, n)); paths.Add(f); }
            nfiles++; nbytes += fi.Length;
            string fn = ShortName(fi.Name, false, used);
            d.Ents.Add(Ent(fn, 0x20, c, fi.Length, fi.LastWriteTime));
            var node = new Node { Clus = c, Parent = d.Clus, Name11 = fn, PcPath = f, Size = fi.Length, File = n > 0 ? paths.Count - 1 : -1 };
            for (int k = 0; k < n; k++) node.Chain.Add(c + k);
            AddNode(node);
        }
    }

    void Finish()
    {
        // directories: extend chains for big folders, then store their sectors
        int per = SPC * SEC / 32;
        var dirData = new List<KeyValuePair<List<int>, byte[]>>();
        foreach (var d in dirs)
        {
            int need = Math.Max(1, (d.Ents.Count + 1 + per - 1) / per);
            var chain = new List<int> { d.Clus };
            while (chain.Count < need) { int n = fat.Count; fat.Add(0x0FFFFFFF); fat[chain[chain.Count - 1]] = (uint)n; chain.Add(n); }
            var data = new byte[need * SPC * SEC];
            for (int i = 0; i < d.Ents.Count; i++) Array.Copy(d.Ents[i], 0, data, i * 32, 32);
            dirData.Add(new KeyValuePair<List<int>, byte[]>(chain, data));
        }
        // spare free clusters so the DOS can save a little
        int clusters = fat.Count + 4096;
        fatSz = (clusters * 4 + SEC - 1) / SEC;
        data0 = RES + 2 * fatSz;
        totalSec = data0 + (long)(clusters - 2) * SPC;
        while (fat.Count < clusters) fat.Add(0);
        owner = new int[clusters]; ownIdx = new int[clusters];
        for (int i = 0; i < clusters; i++) owner[i] = -1;
        for (int f = 0; f < fileClus.Count; f++)
            for (int k = 0; k < fileClus[f].Value; k++) { owner[fileClus[f].Key + k] = f; ownIdx[fileClus[f].Key + k] = k; }
        foreach (var kv in dirData)
            for (int i = 0; i < kv.Key.Count; i++)
                for (int s = 0; s < SPC; s++)
                {
                    var sec = new byte[SEC]; Array.Copy(kv.Value, (i * SPC + s) * SEC, sec, 0, SEC);
                    meta[ClusLba(kv.Key[i]) + s] = sec;
                }
        // boot sector (FAT32 BPB, no partition table) and FSInfo
        var b = new byte[SEC];
        b[0] = 0xEB; b[1] = 0x58; b[2] = 0x90; Encoding.ASCII.GetBytes("MSDOS5.0", 0, 8, b, 3);
        W16(b, 11, SEC); b[13] = SPC; W16(b, 14, RES); b[16] = 2; b[21] = 0xF8; W16(b, 24, 63); W16(b, 26, 255);
        W32(b, 32, (uint)totalSec); W32(b, 36, (uint)fatSz); W32(b, 44, 2); W16(b, 48, 1); W16(b, 50, 6);
        b[64] = 0x80; b[66] = 0x29; W32(b, 67, 0x56A30001);
        Encoding.ASCII.GetBytes("VZONPC SD  FAT32   ", 0, 19, b, 71);
        b[510] = 0x55; b[511] = 0xAA;
        meta[0] = b; meta[6] = (byte[])b.Clone();
        var fsi = new byte[SEC]; W32(fsi, 0, 0x41615252); W32(fsi, 484, 0x61417272); W32(fsi, 488, 0xFFFFFFFF); W32(fsi, 492, 0xFFFFFFFF);
        fsi[510] = 0x55; fsi[511] = 0xAA; meta[1] = fsi;
    }
    static void W16(byte[] b, int o, int v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); }
    static void W32(byte[] b, int o, uint v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); b[o + 2] = (byte)(v >> 16); b[o + 3] = (byte)(v >> 24); }
    long ClusLba(int c) { return data0 + (long)(c - 2) * SPC; }

    // ------------------------------------------------------------ sectors
    FileStream cur; int curIdx = -1;

    public byte[] ReadSector(long lba) { Reads++; return Sector(lba); }

    byte[] Sector(long lba)
    {
        byte[] s;
        if (written.TryGetValue(lba, out s)) return s;
        if (meta.TryGetValue(lba, out s)) return s;
        var r = new byte[SEC];
        if (lba >= RES && lba < data0)
        {
            long off = (lba - RES) % fatSz * (SEC / 4);
            for (int i = 0; i < SEC / 4; i++)
            {
                long e = off + i; uint v = e < fat.Count ? fat[(int)e] : 0;
                W32(r, i * 4, v);
            }
            return r;
        }
        if (lba >= data0)
        {
            long cl = (lba - data0) / SPC + 2; int sub = (int)((lba - data0) % SPC);
            if (cl < owner.Length && owner[cl] >= 0)
            {
                int f = owner[cl];
                try
                {
                    if (curIdx != f) { if (cur != null) cur.Dispose(); cur = new FileStream(paths[f], FileMode.Open, FileAccess.Read, FileShare.ReadWrite); curIdx = f; }
                    cur.Position = ((long)ownIdx[cl] * SPC + sub) * SEC;
                    int got = 0; while (got < SEC) { int n = cur.Read(r, got, SEC - got); if (n <= 0) break; got += n; }
                }
                catch { if (cur != null) cur.Dispose(); cur = null; curIdx = -1; }
            }
        }
        return r;
    }

    public void WriteSector(long lba, byte[] d)
    {
        Writes++;
        written[lba] = d;
        dirty.Add(lba);
        if (lba >= RES && lba < data0)
        {
            // keep the FAT copy in step so later reads of either FAT agree
            long off = (lba - RES) % fatSz * (SEC / 4);
            for (int i = 0; i < SEC / 4; i++)
            {
                long e = off + i; if (e >= fat.Count) break;
                fat[(int)e] = (uint)(d[i * 4] | (d[i * 4 + 1] << 8) | (d[i * 4 + 2] << 16) | (d[i * 4 + 3] << 24));
            }
        }
    }

    public void Close() { if (cur != null) cur.Dispose(); cur = null; curIdx = -1; }

    // ------------------------------------------------------------ write-back to the PC folder
    sealed class Node
    {
        public bool IsDir; public int Clus, Parent; public string Name11, PcPath; public long Size; public int File = -1;
        public List<int> Chain = new List<int>();
        public string Key { get { return Clus != 0 ? "C" + Clus : "E" + Parent + "/" + Name11; } }
    }
    Dictionary<string, Node> baseline = new Dictionary<string, Node>();
    readonly HashSet<long> dirty = new HashSet<long>();
    public bool Dirty { get { return dirty.Count > 0; } }
    public int FlushedFiles;

    void AddNode(Node n) { baseline[n.Key] = n; }

    static string PcName(string n11)
    {
        string b = n11.Substring(0, 8).TrimEnd(), e = n11.Substring(8).TrimEnd();
        string n = e.Length > 0 ? b + "." + e : b;
        var sb = new StringBuilder();
        foreach (char c in n) sb.Append(c < 32 || Array.IndexOf(Path.GetInvalidFileNameChars(), c) >= 0 ? '_' : c);
        return sb.ToString();
    }

    List<int> ChainOf(int c)
    {
        var r = new List<int>();
        while (c >= 2 && c < fat.Count && r.Count < 1 << 20)
        {
            r.Add(c);
            uint nx = fat[c] & 0x0FFFFFFF;
            if (nx >= 0x0FFFFFF8 || nx < 2) break;
            c = (int)nx;
        }
        return r;
    }

    void Walk(int dirClus, string pcDir, List<Node> outList, int depth, HashSet<int> seen)
    {
        if (depth > 16 || !seen.Add(dirClus)) return;
        foreach (int c in ChainOf(dirClus))
            for (int s = 0; s < SPC; s++)
            {
                byte[] sec = Sector(ClusLba(c) + s);
                for (int o = 0; o < SEC; o += 32)
                {
                    int b0 = sec[o];
                    if (b0 == 0) return;
                    int attr = sec[o + 11];
                    if (b0 == 0xE5 || attr == 0x0F || (attr & 0x08) != 0 || b0 == '.') continue;
                    string n11 = Encoding.ASCII.GetString(sec, o, 11);
                    if (b0 == 0x05) n11 = (char)0xE5 + n11.Substring(1);
                    int cl = sec[o + 0x1A] | (sec[o + 0x1B] << 8) | (sec[o + 0x14] << 16) | (sec[o + 0x15] << 24);
                    long size = (uint)(sec[o + 0x1C] | (sec[o + 0x1D] << 8) | (sec[o + 0x1E] << 16) | (sec[o + 0x1F] << 24));
                    var n = new Node { IsDir = (attr & 0x10) != 0, Clus = cl, Parent = dirClus, Name11 = n11, Size = size };
                    Node old;
                    bool known = baseline.TryGetValue(n.Key, out old) && old.IsDir == n.IsDir;
                    n.PcPath = known && old.Name11 == n11 && old.Parent == dirClus ? old.PcPath : Path.Combine(pcDir, PcName(n11));
                    if (known) n.File = old.File;
                    if (!n.IsDir) n.Chain = cl >= 2 ? ChainOf(cl) : new List<int>();
                    outList.Add(n);
                    if (n.IsDir && cl >= 2) Walk(cl, n.PcPath, outList, depth + 1, seen);
                }
            }
    }

    bool Inside(string p)
    {
        string full = Path.GetFullPath(p), root = Path.GetFullPath(Root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return full.StartsWith(root, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>Copies a PC file's data into the card image, so the PC file can be changed or removed.</summary>
    void Pin(Node old)
    {
        if (old == null || old.File < 0) return;
        foreach (int c in old.Chain)
        {
            if (c >= owner.Length || owner[c] != old.File) continue;
            for (int s = 0; s < SPC; s++)
            {
                long lba = ClusLba(c) + s;
                if (!written.ContainsKey(lba)) written[lba] = Sector(lba);
            }
            owner[c] = -1;
        }
        Close();
    }

    static void Recycle(string p, bool dir) { Portable.Trash(p, dir); }

    /// <summary>Writes the DOS's changes back to the PC folder. Returns the number of files and folders changed.</summary>
    public int Flush(Action<string> log)
    {
        if (dirty.Count == 0) return 0;
        var now = new List<Node>();
        Walk(2, Root, now, 0, new HashSet<int>());
        var nowKeys = new Dictionary<string, Node>();
        foreach (var n in now) nowKeys[n.Key] = n;
        var targets = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var n in now) targets.Add(Path.GetFullPath(n.PcPath));
        int changes = 0;

        // 1. folders: create new ones, follow renames
        foreach (var n in now)
        {
            if (!n.IsDir || !Inside(n.PcPath)) continue;
            Node old; baseline.TryGetValue(n.Key, out old);
            try
            {
                if (old != null && old.IsDir && !string.Equals(old.PcPath, n.PcPath, StringComparison.OrdinalIgnoreCase) && Directory.Exists(old.PcPath) && !Directory.Exists(n.PcPath))
                { Directory.Move(old.PcPath, n.PcPath); changes++; log("SD card: renamed folder " + Path.GetFileName(old.PcPath) + " -> " + Path.GetFileName(n.PcPath)); }
                else if (!Directory.Exists(n.PcPath)) { Directory.CreateDirectory(n.PcPath); changes++; log("SD card: new folder " + Path.GetFileName(n.PcPath)); }
            }
            catch (Exception ex) { log("SD card: can't write " + n.PcPath + ": " + ex.Message); }
        }

        // 2. files: new, changed or renamed
        foreach (var n in now)
        {
            if (n.IsDir || !Inside(n.PcPath)) continue;
            Node old; baseline.TryGetValue(n.Key, out old);
            if (old != null && old.IsDir) old = null;
            bool renamed = old != null && !string.Equals(old.PcPath, n.PcPath, StringComparison.OrdinalIgnoreCase);
            bool changed = old == null || old.Size != n.Size || old.Chain.Count != n.Chain.Count;
            if (!changed) for (int i = 0; i < n.Chain.Count; i++) if (n.Chain[i] != old.Chain[i]) { changed = true; break; }
            if (!changed)
                foreach (int c in n.Chain) { for (int s = 0; s < SPC && !changed; s++) if (dirty.Contains(ClusLba(c) + s)) changed = true; if (changed) break; }
            if (!changed && !renamed) continue;
            try
            {
                if (renamed && !changed && File.Exists(old.PcPath) && !File.Exists(n.PcPath))
                {
                    File.Move(old.PcPath, n.PcPath);
                    if (old.File >= 0) { paths[old.File] = n.PcPath; Close(); }
                    log("SD card: renamed " + Path.GetFileName(old.PcPath) + " -> " + Path.GetFileName(n.PcPath));
                }
                else
                {
                    Pin(old);
                    // also free any other PC file about to be overwritten under this name
                    foreach (var b in baseline.Values)
                        if (!b.IsDir && b.File >= 0 && string.Equals(b.PcPath, n.PcPath, StringComparison.OrdinalIgnoreCase)) Pin(b);
                    var data = new byte[n.Size];
                    long pos = 0;
                    foreach (int c in n.Chain)
                        for (int s = 0; s < SPC && pos < n.Size; s++)
                        {
                            byte[] sec = Sector(ClusLba(c) + s);
                            int k = (int)Math.Min(SEC, n.Size - pos);
                            Array.Copy(sec, 0, data, pos, k); pos += k;
                        }
                    Directory.CreateDirectory(Path.GetDirectoryName(n.PcPath));
                    File.WriteAllBytes(n.PcPath, data);
                    n.File = -1;
                    if (renamed && File.Exists(old.PcPath) && !targets.Contains(Path.GetFullPath(old.PcPath))) Recycle(old.PcPath, false);
                    log("SD card: " + (old == null ? "saved " : "updated ") + Path.GetFileName(n.PcPath) + " (" + n.Size + " bytes)");
                }
                changes++; FlushedFiles++;
            }
            catch (Exception ex) { log("SD card: can't write " + n.PcPath + ": " + ex.Message); }
        }

        // 3. deleted files and folders (to the Recycle Bin), unless something new now lives at that path
        foreach (var old in baseline.Values)
        {
            if (nowKeys.ContainsKey(old.Key)) continue;
            string p = Path.GetFullPath(old.PcPath);
            if (targets.Contains(p) || !Inside(p)) { Pin(old); continue; }
            Pin(old);
            if (old.IsDir ? Directory.Exists(p) : File.Exists(p))
            {
                Recycle(p, old.IsDir); changes++;
                log("SD card: deleted " + Path.GetFileName(p) + " (moved to the Recycle Bin)");
            }
        }

        baseline = nowKeys;
        dirty.Clear();
        return changes;
    }

    // ------------------------------------------------------------ SPI (SD protocol, SDHC block addressing)
    readonly Queue<int> q = new Queue<int>();
    List<int> cmd; int last = 0xFF;
    long wrLba = -1; List<int> wrBuf; bool wrStarted; bool appCmd;

    public int In() { return last; }

    public void Out(int v)
    {
        if (wrLba >= 0)
        {
            if (!wrStarted)
            {
                if (v == 0xFE) wrStarted = true;
                last = q.Count > 0 ? q.Dequeue() : 0xFF; return;
            }
            wrBuf.Add(v);
            if (wrBuf.Count == SEC + 2)
            {
                var d = new byte[SEC]; for (int i = 0; i < SEC; i++) d[i] = (byte)wrBuf[i];
                WriteSector(wrLba, d); wrLba = -1;
                q.Clear(); q.Enqueue(0x05); q.Enqueue(0x00); q.Enqueue(0xFF);
            }
            last = 0xFF; return;
        }
        if (cmd != null)
        {
            cmd.Add(v); last = 0xFF;
            if (cmd.Count == 6) { Do(cmd); cmd = null; }
            return;
        }
        if ((v & 0xC0) == 0x40 && q.Count == 0) { cmd = new List<int> { v }; last = 0xFF; return; }
        last = q.Count > 0 ? q.Dequeue() : 0xFF;
    }

    void Do(List<int> c)
    {
        int n = c[0] & 0x3F; long arg = ((long)c[1] << 24) | ((long)c[2] << 16) | ((long)c[3] << 8) | (long)c[4];
        q.Clear();
        bool app = appCmd; appCmd = false;
        switch (n)
        {
            case 0: q.Enqueue(0x01); break;
            case 8: foreach (int x in new[] { 0x01, 0, 0, 1, 0xAA }) q.Enqueue(x); break;
            case 55: q.Enqueue(0x01); appCmd = true; break;
            case 41: q.Enqueue(0x00); break;
            case 1: q.Enqueue(0x00); break;
            case 58: foreach (int x in new[] { 0x00, 0xC0, 0xFF, 0x80, 0x00 }) q.Enqueue(x); break;
            case 16: q.Enqueue(0x00); break;
            case 12: q.Enqueue(0xFF); q.Enqueue(0x00); break;
            case 13: q.Enqueue(0x00); q.Enqueue(0x00); break;
            case 9: case 10:
                {
                    q.Enqueue(0x00); q.Enqueue(0xFF); q.Enqueue(0xFE);
                    var reg = new byte[16];
                    if (n == 9) { reg[0] = 0x40; long cs = Math.Max(1, totalSec / 1024) - 1; reg[7] = (byte)(cs >> 16); reg[8] = (byte)(cs >> 8); reg[9] = (byte)cs; }
                    else { reg[0] = 0x03; reg[1] = (byte)'V'; reg[2] = (byte)'Z'; }
                    foreach (var x in reg) q.Enqueue(x);
                    q.Enqueue(0); q.Enqueue(0);
                }
                break;
            case 17:
                {
                    q.Enqueue(0x00); q.Enqueue(0xFF); q.Enqueue(0xFE);
                    foreach (var x in ReadSector(arg)) q.Enqueue(x);
                    q.Enqueue(0); q.Enqueue(0);
                }
                break;
            case 24: q.Enqueue(0x00); wrLba = arg; wrBuf = new List<int>(); wrStarted = false; break;
            default: q.Enqueue(app ? 0x00 : 0x04); break;
        }
    }
}
