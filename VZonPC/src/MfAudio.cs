using System;
using System.IO;
using System.Runtime.InteropServices;

/// <summary>Decodes any audio file Windows can play (WAV, MP3, FLAC, and Ogg with the Web Media Extensions) to 16-bit
/// PCM, through Media Foundation's source reader. Used for tape input.</summary>
public static class MfAudio
{
    [DllImport("mfplat.dll", ExactSpelling = true)] static extern int MFStartup(int version, int flags);
    [DllImport("mfplat.dll", ExactSpelling = true)] static extern int MFShutdown();
    [DllImport("mfplat.dll", ExactSpelling = true)] static extern int MFCreateMediaType(out IMFMediaType t);
    [DllImport("mfreadwrite.dll", ExactSpelling = true)]
    static extern int MFCreateSourceReaderFromURL([MarshalAs(UnmanagedType.LPWStr)] string url, IntPtr attr, out IMFSourceReader r);

    static readonly Guid MF_MT_MAJOR_TYPE = new Guid("48eba18e-f8c9-4687-bf11-0a74c9f96a8f");
    static readonly Guid MF_MT_SUBTYPE = new Guid("f7e34c9a-42e8-4714-b74b-cb29d72c35e5");
    static readonly Guid MF_MT_AUDIO_BITS_PER_SAMPLE = new Guid("f2deb57f-40fa-4764-aa33-ed4f2d1ff669");
    static readonly Guid MF_MT_AUDIO_NUM_CHANNELS = new Guid("37e48bf5-645e-4c5b-89de-ada9e29b696a");
    static readonly Guid MF_MT_AUDIO_SAMPLES_PER_SECOND = new Guid("5faeeae7-0290-4c31-9e8a-c534f68d9dba");
    static readonly Guid MFMediaType_Audio = new Guid("73647561-0000-0010-8000-00AA00389B71");
    static readonly Guid MFAudioFormat_PCM = new Guid("00000001-0000-0010-8000-00AA00389B71");
    const int FIRST_AUDIO = unchecked((int)0xFFFFFFFD), ALL_STREAMS = unchecked((int)0xFFFFFFFE);
    const int ENDOFSTREAM = 2;

    /// <summary>Returns interleaved 16-bit samples, with the rate and channel count.</summary>
    public static short[] Decode(string path, out int rate, out int channels)
    {
        int hr = MFStartup(0x20070, 0);
        if (hr < 0) throw new Exception("Media Foundation not available (0x" + hr.ToString("X8") + ")");
        try
        {
            IMFSourceReader r;
            hr = MFCreateSourceReaderFromURL(Path.GetFullPath(path), IntPtr.Zero, out r);
            if (hr < 0) throw new Exception("Windows can't open this audio file (0x" + hr.ToString("X8") + "). Ogg needs the Web Media Extensions.");
            r.SetStreamSelection(ALL_STREAMS, false);
            r.SetStreamSelection(FIRST_AUDIO, true);
            IMFMediaType want; MFCreateMediaType(out want);
            want.SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
            want.SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
            want.SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
            hr = r.SetCurrentMediaType(FIRST_AUDIO, IntPtr.Zero, want);
            if (hr < 0) throw new Exception("can't decode this audio to PCM (0x" + hr.ToString("X8") + ")");
            IMFMediaType got; r.GetCurrentMediaType(FIRST_AUDIO, out got);
            got.GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, out rate);
            got.GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, out channels);
            var ms = new MemoryStream();
            byte[] tmp = new byte[0];
            while (true)
            {
                int idx, flags; long ts; IMFSample s;
                hr = r.ReadSample(FIRST_AUDIO, 0, out idx, out flags, out ts, out s);
                if (hr < 0) throw new Exception("audio decode failed (0x" + hr.ToString("X8") + ")");
                if (s != null)
                {
                    IMFMediaBuffer b; s.ConvertToContiguousBuffer(out b);
                    IntPtr p; int max, len; b.Lock(out p, out max, out len);
                    if (tmp.Length < len) tmp = new byte[len];
                    Marshal.Copy(p, tmp, 0, len); ms.Write(tmp, 0, len);
                    b.Unlock();
                    Marshal.ReleaseComObject(b); Marshal.ReleaseComObject(s);
                }
                if ((flags & ENDOFSTREAM) != 0) break;
            }
            Marshal.ReleaseComObject(r);
            byte[] all = ms.ToArray();
            var o = new short[all.Length / 2];
            Buffer.BlockCopy(all, 0, o, 0, o.Length * 2);
            return o;
        }
        finally { MFShutdown(); }
    }

    // ---- COM interfaces (vtable order matters; unused methods are placeholders)
    [ComImport, Guid("2cd2d921-c447-44a7-a13c-4adabfc247e3"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMFAttributes { }

    [ComImport, Guid("44ae0fa8-ea31-4109-8d2e-4cae4997c555"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMFMediaType
    {
        void a0(); void a1(); void a2(); void a3();
        [PreserveSig] int GetUINT32([MarshalAs(UnmanagedType.LPStruct)] Guid key, out int v);
        void a5(); void a6(); void a7(); void a8(); void a9(); void a10(); void a11(); void a12(); void a13(); void a14();
        void a15(); void a16(); void a17();
        [PreserveSig] int SetUINT32([MarshalAs(UnmanagedType.LPStruct)] Guid key, int v);
        void a19(); void a20();
        [PreserveSig] int SetGUID([MarshalAs(UnmanagedType.LPStruct)] Guid key, [MarshalAs(UnmanagedType.LPStruct)] Guid v);
        void a22(); void a23(); void a24(); void a25(); void a26(); void a27(); void a28(); void a29();
        void m0(); void m1(); void m2(); void m3(); void m4();
    }

    [ComImport, Guid("70ae66f2-c809-4e4f-8915-bdcb406b7993"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMFSourceReader
    {
        void GetStreamSelection();
        [PreserveSig] int SetStreamSelection(int stream, [MarshalAs(UnmanagedType.Bool)] bool sel);
        void GetNativeMediaType();
        [PreserveSig] int GetCurrentMediaType(int stream, out IMFMediaType t);
        [PreserveSig] int SetCurrentMediaType(int stream, IntPtr reserved, IMFMediaType t);
        void SetCurrentPosition();
        [PreserveSig] int ReadSample(int stream, int control, out int actualStream, out int flags, out long timestamp, out IMFSample sample);
    }

    [ComImport, Guid("c40a00f2-b93a-4d80-ae8c-5a1c634f58e4"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMFSample
    {
        void a0(); void a1(); void a2(); void a3(); void a4(); void a5(); void a6(); void a7(); void a8(); void a9();
        void a10(); void a11(); void a12(); void a13(); void a14(); void a15(); void a16(); void a17(); void a18(); void a19();
        void a20(); void a21(); void a22(); void a23(); void a24(); void a25(); void a26(); void a27(); void a28(); void a29();
        void s0(); void s1(); void s2(); void s3(); void s4(); void s5(); void s6(); void s7();
        [PreserveSig] int ConvertToContiguousBuffer(out IMFMediaBuffer b);
    }

    [ComImport, Guid("045FA593-8799-42b8-BC8D-8968C6453507"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMFMediaBuffer
    {
        [PreserveSig] int Lock(out IntPtr p, out int max, out int len);
        [PreserveSig] int Unlock();
    }
}
