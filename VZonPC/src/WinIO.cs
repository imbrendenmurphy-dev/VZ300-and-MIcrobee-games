// VZonPC Windows I/O: waveOut audio, winmm joysticks, GDI blitting, keyboard polling.
using System;
using System.Runtime.InteropServices;
using System.Threading;

public sealed class WaveOut : IDisposable
{
    [StructLayout(LayoutKind.Sequential)]
    struct WAVEFORMATEX { public ushort wFormatTag, nChannels; public uint nSamplesPerSec, nAvgBytesPerSec; public ushort nBlockAlign, wBitsPerSample, cbSize; }
    [StructLayout(LayoutKind.Sequential)]
    struct WAVEHDR { public IntPtr lpData; public uint dwBufferLength, dwBytesRecorded; public IntPtr dwUser; public uint dwFlags, dwLoops; public IntPtr lpNext, reserved; }

    [DllImport("winmm.dll")] static extern int waveOutOpen(out IntPtr h, int dev, ref WAVEFORMATEX fmt, IntPtr cb, IntPtr inst, int flags);
    [DllImport("winmm.dll")] static extern int waveOutPrepareHeader(IntPtr h, IntPtr hdr, int size);
    [DllImport("winmm.dll")] static extern int waveOutUnprepareHeader(IntPtr h, IntPtr hdr, int size);
    [DllImport("winmm.dll")] static extern int waveOutWrite(IntPtr h, IntPtr hdr, int size);
    [DllImport("winmm.dll")] static extern int waveOutReset(IntPtr h);
    [DllImport("winmm.dll")] static extern int waveOutClose(IntPtr h);

    const int NBUF = 16, BUFSAMPLES = 4096, WHDR_DONE = 1;
    IntPtr h;
    IntPtr[] hdrs = new IntPtr[NBUF], data = new IntPtr[NBUF];
    bool[] busy = new bool[NBUF];
    int next;
    readonly int hsize = Marshal.SizeOf(typeof(WAVEHDR));
    public bool Ok { get; private set; }

    public WaveOut(int rate)
    {
        var f = new WAVEFORMATEX { wFormatTag = 1, nChannels = 1, nSamplesPerSec = (uint)rate, wBitsPerSample = 16, nBlockAlign = 2, nAvgBytesPerSec = (uint)rate * 2 };
        if (waveOutOpen(out h, -1, ref f, IntPtr.Zero, IntPtr.Zero, 0) != 0) return;
        for (int i = 0; i < NBUF; i++)
        {
            data[i] = Marshal.AllocHGlobal(BUFSAMPLES * 2);
            hdrs[i] = Marshal.AllocHGlobal(hsize);
            var w = new WAVEHDR { lpData = data[i], dwBufferLength = BUFSAMPLES * 2 };
            Marshal.StructureToPtr(w, hdrs[i], false);
        }
        Ok = true;
    }

    uint Flags(int i) { return (uint)Marshal.ReadInt32(hdrs[i], IntPtr.Size + 8 + IntPtr.Size); }

    /// <summary>Buffers queued and not yet played.</summary>
    public int Queued
    {
        get
        {
            int n = 0;
            for (int i = 0; i < NBUF; i++)
                if (busy[i])
                {
                    if ((Flags(i) & WHDR_DONE) != 0) { waveOutUnprepareHeader(h, hdrs[i], hsize); busy[i] = false; }
                    else n++;
                }
            return n;
        }
    }

    public void Write(short[] s, int n)
    {
        if (!Ok || n <= 0) return;
        int q = Queued;
        if (busy[next]) return;          // all buffers busy - drop
        n = Math.Min(n, BUFSAMPLES);
        Marshal.Copy(s, 0, data[next], n);
        var w = new WAVEHDR { lpData = data[next], dwBufferLength = (uint)(n * 2) };
        Marshal.StructureToPtr(w, hdrs[next], false);
        waveOutPrepareHeader(h, hdrs[next], hsize);
        waveOutWrite(h, hdrs[next], hsize);
        busy[next] = true;
        next = (next + 1) % NBUF;
    }

    public void Dispose()
    {
        if (!Ok) return;
        Ok = false;
        waveOutReset(h);
        for (int i = 0; i < NBUF; i++) { if (busy[i]) waveOutUnprepareHeader(h, hdrs[i], hsize); Marshal.FreeHGlobal(hdrs[i]); Marshal.FreeHGlobal(data[i]); }
        waveOutClose(h);
    }
}

public static class Joysticks
{
    [StructLayout(LayoutKind.Sequential)]
    struct JOYINFOEX { public int dwSize, dwFlags, dwXpos, dwYpos, dwZpos, dwRpos, dwUpos, dwVpos, dwButtons, dwButtonNumber, dwPOV, dwReserved1, dwReserved2; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    struct JOYCAPS
    {
        public ushort wMid, wPid;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szPname;
        public int wXmin, wXmax, wYmin, wYmax, wZmin, wZmax, wNumButtons, wPeriodMin, wPeriodMax,
            wRmin, wRmax, wUmin, wUmax, wVmin, wVmax, wCaps, wMaxAxes, wNumAxes, wMaxButtons;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szRegKey;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szOEMVxD;
    }
    [DllImport("winmm.dll")] static extern int joyGetPosEx(int id, ref JOYINFOEX ji);
    [DllImport("winmm.dll", CharSet = CharSet.Auto)] static extern int joyGetDevCaps(int id, ref JOYCAPS jc, int size);
    [DllImport("winmm.dll")] static extern int joyGetNumDevs();

    static int[] ids = new int[0];
    static JOYCAPS[] caps = new JOYCAPS[0];
    public static string[] Names = new string[0];
    static int rescanCountdown = 0;

    public static void Scan()
    {
        var l = new System.Collections.Generic.List<int>(); var c = new System.Collections.Generic.List<JOYCAPS>(); var n = new System.Collections.Generic.List<string>();
        int max = Math.Min(16, joyGetNumDevs());
        for (int i = 0; i < max; i++)
        {
            var ji = new JOYINFOEX { dwSize = Marshal.SizeOf(typeof(JOYINFOEX)), dwFlags = 0xFF };
            if (joyGetPosEx(i, ref ji) != 0) continue;
            var jc = new JOYCAPS();
            if (joyGetDevCaps(i, ref jc, Marshal.SizeOf(typeof(JOYCAPS))) != 0) continue;
            l.Add(i); c.Add(jc); n.Add(string.IsNullOrEmpty(jc.szPname) ? "Joystick " + (i + 1) : jc.szPname);
        }
        ids = l.ToArray(); caps = c.ToArray(); Names = n.ToArray();
    }

    public static int Count { get { return ids.Length; } }

    /// <summary>Reads PC joystick n as VZ bits (active low): 1 up, 2 down, 4 left, 8 right, 16 fire; arm = second fire.</summary>
    public static void Read(int n, out int bits, out int arm)
    {
        bits = 0xFF; arm = 0xFF;
        if (n >= ids.Length)
        {
            if (--rescanCountdown <= 0) { rescanCountdown = 250; Scan(); }   // hot-plug
            return;
        }
        var ji = new JOYINFOEX { dwSize = Marshal.SizeOf(typeof(JOYINFOEX)), dwFlags = 0xFF };
        if (joyGetPosEx(ids[n], ref ji) != 0) { Scan(); return; }
        var jc = caps[n];
        int xr = jc.wXmax - jc.wXmin, yr = jc.wYmax - jc.wYmin;
        int x = ji.dwXpos - jc.wXmin, y = ji.dwYpos - jc.wYmin;
        if (xr > 0) { if (x < xr * 3 / 10) bits &= ~4; else if (x > xr * 7 / 10) bits &= ~8; }
        if (yr > 0) { if (y < yr * 3 / 10) bits &= ~1; else if (y > yr * 7 / 10) bits &= ~2; }
        int pov = ji.dwPOV & 0xFFFF;
        if (pov != 0xFFFF)
        {
            if (pov >= 31500 || pov <= 4500) bits &= ~1;
            if (pov >= 4500 && pov <= 13500) bits &= ~8;
            if (pov >= 13500 && pov <= 22500) bits &= ~2;
            if (pov >= 22500 && pov <= 31500) bits &= ~4;
        }
        int b = ji.dwButtons;
        if ((b & 0x5) != 0) bits &= ~16;   // buttons 1 and 3 = fire
        if ((b & 0xA) != 0) arm &= ~16;    // buttons 2 and 4 = second fire ("arm")
    }
}

public static class Native
{
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("gdi32.dll")] public static extern int SetStretchBltMode(IntPtr dc, int mode);
    [DllImport("gdi32.dll")] public static extern int StretchDIBits(IntPtr dc, int xd, int yd, int wd, int hd, int xs, int ys, int ws, int hs, int[] bits, ref BITMAPINFO bmi, uint usage, uint rop);
    [DllImport("gdi32.dll")] public static extern int PatBlt(IntPtr dc, int x, int y, int w, int h, uint rop);
    [DllImport("winmm.dll")] public static extern int timeBeginPeriod(int ms);
    [DllImport("winmm.dll")] public static extern int timeEndPeriod(int ms);

    [StructLayout(LayoutKind.Sequential)]
    public struct BITMAPINFO
    {
        public int biSize, biWidth, biHeight; public short biPlanes, biBitCount;
        public int biCompression, biSizeImage, biXPelsPerMeter, biYPelsPerMeter, biClrUsed, biClrImportant;
        public int c0, c1, c2;
    }
    public const uint BLACKNESS = 0x00000042, SRCCOPY = 0x00CC0020;

    public struct Part { public int[] Px; public int W, H, X, Y, DW, DH; }

    /// <summary>Draws several images into a window and blacks out everything they don't cover (no flicker).</summary>
    public static void BlitParts(IntPtr hwnd, int cw, int ch, System.Collections.Generic.List<Part> parts)
    {
        IntPtr dc = GetDC(hwnd);
        if (dc == IntPtr.Zero) return;
        try
        {
            var ys = new System.Collections.Generic.List<int> { 0, ch };
            foreach (var p in parts) { ys.Add(Math.Max(0, Math.Min(ch, p.Y))); ys.Add(Math.Max(0, Math.Min(ch, p.Y + p.DH))); }
            ys.Sort();
            for (int i = 0; i + 1 < ys.Count; i++)
            {
                int y0 = ys[i], y1 = ys[i + 1]; if (y1 <= y0) continue;
                var xs = new System.Collections.Generic.List<int[]>();
                foreach (var p in parts) if (p.Y <= y0 && p.Y + p.DH >= y1) xs.Add(new[] { p.X, p.X + p.DW });
                xs.Sort((a, b) => a[0].CompareTo(b[0]));
                int x = 0;
                foreach (var r in xs) { if (r[0] > x) PatBlt(dc, x, y0, r[0] - x, y1 - y0, BLACKNESS); x = Math.Max(x, r[1]); }
                if (x < cw) PatBlt(dc, x, y0, cw - x, y1 - y0, BLACKNESS);
            }
            foreach (var p in parts)
            {
                SetStretchBltMode(dc, p.DW < p.W ? 4 : 3);   // HALFTONE when shrinking, else COLORONCOLOR
                var bmi = new BITMAPINFO { biSize = 40, biWidth = p.W, biHeight = -p.H, biPlanes = 1, biBitCount = 32 };
                StretchDIBits(dc, p.X, p.Y, p.DW, p.DH, 0, 0, p.W, p.H, p.Px, ref bmi, 0, SRCCOPY);
            }
        }
        finally { ReleaseDC(hwnd, dc); }
    }

    public static bool KeyDown(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

    /// <summary>Draws a 32-bit image scaled into the destination rectangle (nearest neighbour).</summary>
    public static void Blit(IntPtr hwnd, int[] px, int w, int h, int cw, int ch, int dx, int dy, int dw, int dh)
    {
        IntPtr dc = GetDC(hwnd);
        if (dc == IntPtr.Zero) return;
        try
        {
            SetStretchBltMode(dc, 3); // COLORONCOLOR
            var bmi = new BITMAPINFO { biSize = 40, biWidth = w, biHeight = -h, biPlanes = 1, biBitCount = 32 };
            if (dy > 0) PatBlt(dc, 0, 0, cw, dy, BLACKNESS);
            if (dy + dh < ch) PatBlt(dc, 0, dy + dh, cw, ch - dy - dh, BLACKNESS);
            if (dx > 0) PatBlt(dc, 0, dy, dx, dh, BLACKNESS);
            if (dx + dw < cw) PatBlt(dc, dx + dw, dy, cw - dx - dw, dh, BLACKNESS);
            StretchDIBits(dc, dx, dy, dw, dh, 0, 0, w, h, px, ref bmi, 0, SRCCOPY);
        }
        finally { ReleaseDC(hwnd, dc); }
    }
}
