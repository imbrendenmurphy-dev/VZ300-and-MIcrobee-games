// Bits of the core that differ between Windows, Linux and macOS: file-name case, the recycle bin, PNG writing,
// and decoding compressed audio. Everything here works on .NET Framework, Mono and modern .NET.
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;

public static class Portable
{
    public static readonly bool IsWindows = Environment.OSVersion.Platform == PlatformID.Win32NT;

    /// <summary>dir/name, matching the name's case loosely on case-sensitive file systems (so roms/VZDOS.ROM is
    /// found as vzdos.rom on Linux, as it would be on Windows).</summary>
    public static string Find(string dir, string name)
    {
        string p = Path.Combine(dir, name);
        if (IsWindows || File.Exists(p) || !Directory.Exists(dir)) return p;
        try
        {
            foreach (var f in Directory.GetFiles(dir))
                if (string.Equals(Path.GetFileName(f), name, StringComparison.OrdinalIgnoreCase)) return f;
        }
        catch (Exception) { }
        return p;
    }

    /// <summary>Deletes a file or folder the safe way: the Recycle Bin on Windows, the desktop's trash
    /// (freedesktop.org trash spec) on Linux, and a plain delete if neither works.</summary>
    public static void Trash(string p, bool dir)
    {
        if (IsWindows) { try { RecycleWindows(p, dir); return; } catch (Exception) { } }
        else
        {
            try
            {
                string data = Environment.GetEnvironmentVariable("XDG_DATA_HOME");
                if (string.IsNullOrEmpty(data)) data = Path.Combine(Environment.GetEnvironmentVariable("HOME") ?? "/tmp", ".local/share");
                string files = Path.Combine(data, "Trash/files"), info = Path.Combine(data, "Trash/info");
                Directory.CreateDirectory(files); Directory.CreateDirectory(info);
                string bn = Path.GetFileName(p.TrimEnd('/')), n = bn;
                for (int i = 2; File.Exists(Path.Combine(files, n)) || Directory.Exists(Path.Combine(files, n)) || File.Exists(Path.Combine(info, n + ".trashinfo")); i++) n = bn + "." + i;
                File.WriteAllText(Path.Combine(info, n + ".trashinfo"), "[Trash Info]\nPath=" + Uri.EscapeUriString(Path.GetFullPath(p)) + "\nDeletionDate=" + DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss") + "\n");
                if (dir) Directory.Move(p, Path.Combine(files, n)); else File.Move(p, Path.Combine(files, n));
                return;
            }
            catch (Exception) { }
        }
        try { if (dir) Directory.Delete(p, true); else File.Delete(p); } catch (Exception) { }
    }

    // kept in its own method so Microsoft.VisualBasic is only loaded on Windows
    static void RecycleWindows(string p, bool dir)
    {
        if (dir) Microsoft.VisualBasic.FileIO.FileSystem.DeleteDirectory(p, Microsoft.VisualBasic.FileIO.UIOption.OnlyErrorDialogs, Microsoft.VisualBasic.FileIO.RecycleOption.SendToRecycleBin);
        else Microsoft.VisualBasic.FileIO.FileSystem.DeleteFile(p, Microsoft.VisualBasic.FileIO.UIOption.OnlyErrorDialogs, Microsoft.VisualBasic.FileIO.RecycleOption.SendToRecycleBin);
    }

    // ---------------------------------------------------------------- PNG
    static uint[] crcTable;
    static uint Crc(byte[] b, int o, int n, uint c)
    {
        if (crcTable == null)
        {
            var t = new uint[256];
            for (uint i = 0; i < 256; i++) { uint v = i; for (int k = 0; k < 8; k++) v = (v & 1) != 0 ? 0xEDB88320 ^ (v >> 1) : v >> 1; t[i] = v; }
            crcTable = t;
        }
        for (int i = 0; i < n; i++) c = crcTable[(c ^ b[o + i]) & 0xFF] ^ (c >> 8);
        return c;
    }
    static void BE(Stream s, uint v) { s.WriteByte((byte)(v >> 24)); s.WriteByte((byte)(v >> 16)); s.WriteByte((byte)(v >> 8)); s.WriteByte((byte)v); }
    static void Chunk(Stream s, string type, byte[] data)
    {
        var all = new byte[4 + data.Length];
        for (int i = 0; i < 4; i++) all[i] = (byte)type[i];
        Array.Copy(data, 0, all, 4, data.Length);
        BE(s, (uint)data.Length); s.Write(all, 0, all.Length); BE(s, Crc(all, 0, all.Length, 0xFFFFFFFF) ^ 0xFFFFFFFF);
    }

    /// <summary>Writes 0xRRGGBB pixels as a 24-bit PNG, each pixel scaled up to scale x scale.</summary>
    public static void SavePng(string fn, int[] src, int w, int h, int scale)
    {
        if (scale < 1) scale = 1;
        int W = w * scale, H = h * scale;
        var raw = new byte[(W * 3 + 1) * H];
        int o = 0;
        for (int y = 0; y < H; y++)
        {
            raw[o++] = 0;                         // filter: none
            int row = (y / scale) * w;
            for (int x = 0; x < W; x++) { int c = src[row + x / scale]; raw[o++] = (byte)(c >> 16); raw[o++] = (byte)(c >> 8); raw[o++] = (byte)c; }
        }
        var z = new MemoryStream();
        z.WriteByte(0x78); z.WriteByte(0x9C);     // zlib header
        using (var d = new DeflateStream(z, CompressionMode.Compress, true)) d.Write(raw, 0, raw.Length);
        uint a = 1, b = 0;                        // Adler-32 of the uncompressed data
        for (int i = 0; i < raw.Length; i++) { a = (a + raw[i]) % 65521; b = (b + a) % 65521; }
        BE(z, (b << 16) | a);

        string dir = Path.GetDirectoryName(Path.GetFullPath(fn)); if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        using (var f = File.Create(fn))
        {
            f.Write(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }, 0, 8);
            var ihdr = new MemoryStream(); BE(ihdr, (uint)W); BE(ihdr, (uint)H); ihdr.Write(new byte[] { 8, 2, 0, 0, 0 }, 0, 5);
            Chunk(f, "IHDR", ihdr.ToArray());
            Chunk(f, "IDAT", z.ToArray());
            Chunk(f, "IEND", new byte[0]);
        }
    }

    // ---------------------------------------------------------------- compressed audio
    /// <summary>Decodes MP3, FLAC, Ogg and the rest to interleaved 16-bit samples: Media Foundation on Windows,
    /// ffmpeg elsewhere (it is in every Linux distribution's repositories and in Homebrew).</summary>
    public static short[] DecodeAudio(string path, out int rate, out int channels)
    {
        if (IsWindows) return MfAudio.Decode(path, out rate, out channels);
        rate = 44100; channels = 2;
        var psi = new ProcessStartInfo("ffmpeg", "-v error -nostdin -i \"" + Path.GetFullPath(path).Replace("\"", "\\\"") + "\" -f s16le -acodec pcm_s16le -ac 2 -ar 44100 -")
        { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        Process p;
        try { p = Process.Start(psi); }
        catch (Exception) { throw new Exception("needs ffmpeg to play this file (install it, or convert the file to WAV)"); }
        var ms = new MemoryStream();
        var err = p.StandardError.ReadToEndAsync();
        p.StandardOutput.BaseStream.CopyTo(ms);
        p.WaitForExit();
        if (p.ExitCode != 0 || ms.Length == 0) throw new Exception("ffmpeg can't decode it: " + err.Result.Trim());
        var o = new short[ms.Length / 2];
        Buffer.BlockCopy(ms.GetBuffer(), 0, o, 0, o.Length * 2);
        return o;
    }
}
