// VZonPC's cross-platform front end (Linux, macOS, and Windows too), on SDL2. The same emulator core as the
// Windows version; instead of menus it has keys (F1 lists them), a command line and vzonpc.ini, and it uses
// zenity or kdialog for file dialogs when they're installed. Everything runs on one thread: events, one emulated
// frame, drawing, and the sound card sets the pace.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class VzSdl
{
    [STAThread]
    public static int Main(string[] args)
    {
        Sdl.Setup();
        try { return new SdlFront(args).Run(); }
        catch (DllNotFoundException)
        {
            string msg = "VZonPC needs the SDL2 library.\n" +
                "  Fedora:        sudo dnf install SDL2\n" +
                "  Debian/Ubuntu: sudo apt install libsdl2-2.0-0\n" +
                "  Arch:          sudo pacman -S sdl2\n" +
                "  macOS:         brew install sdl2\n" +
                "  Windows:       put SDL2.dll next to VZonPC-SDL.exe";
            Console.Error.WriteLine(msg);
            return 1;
        }
    }
}

public sealed class SdlFront
{
    readonly VzMachine m = new VzMachine();
    readonly VzVis vis;
    readonly string baseDir = AppDomain.CurrentDomain.BaseDirectory;
    readonly string iniPath;

    IntPtr win, ren, texPic, texL, texR, texMsg;
    int texPicW, texPicH, texMsgW, texMsgH; string texMsgText;
    uint audio;
    IntPtr ev = Marshal.AllocHGlobal(64);
    IntPtr crossCursor, arrowCursor;

    // settings (the same vzonpc.ini keys as the Windows version)
    int scale = 3;
    bool integerScale = true, showBorder = true, fullscreen, arrowsJoy = true, swapJoy, muted, visOn;
    bool paused, warp, running = true;
    string lastProgram; bool sessionProgram;
    string lastSerialTarget = "localhost:23";
    readonly string[] diskPath = new string[2];
    bool tapeRight, tapeInvert;
    string message = ""; int messageFrames;
    double fps;

    // what's on screen
    int[] frame = new int[VzMachine.FBW * VzMachine.FBH]; int frameW = VzMachine.FBW, frameH = VzMachine.FBH;
    int destX, destY, destW = 1, destH = 1, destFW = 256, destFH = 192;   // the picture, in renderer pixels

    // auto-typing
    readonly Queue<string[]> typeQueue = new Queue<string[]>();
    string[] typing; int typePhase, typeHold;
    VzTape pendingTape; int pendingTapeDelay;

    // command line
    string startProgram, shotPath, autoType, startTape, startRtty, startSerial; double quitAfter; bool noSettings;
    readonly string[] startDisk = new string[2];

    public SdlFront(string[] args)
    {
        iniPath = Path.Combine(baseDir, "vzonpc.ini");
        vis = new VzVis(m);
        m.SdDir = Path.Combine(baseDir, "SD");
        string prDir = Path.Combine(baseDir, "printer");
        m.Printer.TextPath = Path.Combine(prDir, "printout.txt"); m.Printer.RawPath = Path.Combine(prDir, "printout.prn");
        noSettings = Array.Exists(args, x => x == "--no-settings" || x == "--quit-after");
        if (!noSettings) LoadSettings();
        ParseArgs(args);
        m.Log = s => ShowMessage(s);
    }

    // ------------------------------------------------------------------ startup and the main loop
    public int Run()
    {
        if (Sdl.SDL_Init(Sdl.INIT_VIDEO | Sdl.INIT_JOYSTICK | Sdl.INIT_GAMECONTROLLER) != 0)
        {
            Console.Error.WriteLine("SDL: " + Sdl.Error());
            return 1;
        }
        Sdl.SetHint("SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR", "0");
        Sdl.SetHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", "1");
        int w, h; PictureSize(out w, out h);
        win = Sdl.CreateWindow("VZonPC", w * scale, h * scale, Sdl.WINDOW_RESIZABLE | Sdl.WINDOW_ALLOW_HIGHDPI);
        if (win == IntPtr.Zero) { Console.Error.WriteLine("SDL: can't open a window: " + Sdl.Error()); return 1; }
        Sdl.SDL_SetWindowMinimumSize(win, 256, 192);
        SetIcon();
        ren = Sdl.SDL_CreateRenderer(win, -1, Sdl.RENDERER_ACCELERATED);
        if (ren == IntPtr.Zero) ren = Sdl.SDL_CreateRenderer(win, -1, 0);
        if (ren == IntPtr.Zero) { Console.Error.WriteLine("SDL: no renderer: " + Sdl.Error()); return 1; }
        crossCursor = Sdl.SDL_CreateSystemCursor(3); arrowCursor = Sdl.SDL_CreateSystemCursor(0);
        OpenAudio();
        ScanPads();
        if (fullscreen) { fullscreen = false; ToggleFullscreen(); }
        if (visOn) { visOn = false; ToggleVis(); }

        PowerOnNow();
        if (startProgram != null) LaunchNow(startProgram);
        if (autoType != null) { if (startProgram == null && m.HasRom) typeHold = 150; TypeString(autoType); }
        for (int d = 0; d < 2; d++) if (startDisk[d] != null) InsertDiskNow(d, startDisk[d]);
        if (startRtty != null) { try { m.Rtty.PlayRx(startRtty, m.Cpu.Cyc); } catch (Exception ex) { ShowMessage("RTTY: " + ex.Message); } }
        if (startSerial != null) SerialConnectNow(startSerial);
        if (startTape != null)
        {
            try { var t = VzTape.Load(startTape, tapeRight ? 1 : 0); t.Invert = tapeInvert; pendingTape = t; pendingTapeDelay = 25; }
            catch (Exception ex) { ShowMessage("Tape: " + ex.Message); }
        }

        var sw = Stopwatch.StartNew();
        double nextT = 0, fpsT = 0; int fpsFrames = 0, titleCount = 0;
        long quitAtFrame = quitAfter > 0 ? (long)(quitAfter * 50) : -1, framesRun = 0;
        while (running)
        {
            PumpEvents();
            if (!running) break;
            if (messageFrames > 0) messageFrames--;
            if (++titleCount >= 25) { titleCount = 0; UpdateTitle(); }
            if (paused)
            {
                Render(); Thread.Sleep(20); nextT = sw.Elapsed.TotalMilliseconds;
                if (audio != 0) Sdl.SDL_ClearQueuedAudio(audio);
                continue;
            }

            PollInput();
            if (pendingTape != null && typeQueue.Count == 0 && typing == null && typeHold == 0 && --pendingTapeDelay <= 0) { m.PlayTape(pendingTape); pendingTape = null; }
            m.AudioOn = !warp && audio != 0;
            m.RunFrame();
            if (vis.T != null && visOn) vis.Render();
            int fw, fh; frame = m.Snapshot(showBorder, out fw, out fh); frameW = fw; frameH = fh;
            if (!warp || (m.Frames & 7) == 0) Render();

            fpsFrames++; framesRun++;
            double now = sw.Elapsed.TotalMilliseconds;
            if (now - fpsT >= 1000) { fps = fpsFrames * 1000.0 / (now - fpsT); fpsFrames = 0; fpsT = now; }
            if (quitAtFrame >= 0 && framesRun >= quitAtFrame) { QuitWithShot(); break; }

            if (warp) { nextT = now; continue; }
            double frameMs = 1000.0 * VzMachine.FRAMET / m.Clock;
            if (m.AudioOn)
            {
                if (muted) for (int i = 0; i < m.AudioN; i++) m.Audio[i] = 0;
                Sdl.SDL_QueueAudio(audio, m.Audio, (uint)(m.AudioN * 2));
                // the sound card sets the pace: keep about three frames queued
                uint keep = (uint)(VzMachine.RATE / 50 * 2 * 3);
                int guard = 0;
                while (running && Sdl.SDL_GetQueuedAudioSize(audio) > keep && guard++ < 100) Thread.Sleep(1);
                nextT = sw.Elapsed.TotalMilliseconds;
            }
            else
            {
                nextT += frameMs;
                double wait = nextT - sw.Elapsed.TotalMilliseconds;
                if (wait > 1) Thread.Sleep((int)wait);
                else if (wait < -100) nextT = sw.Elapsed.TotalMilliseconds;
            }
        }
        Shutdown();
        return 0;
    }

    void OpenAudio()
    {
        if (Sdl.SDL_InitSubSystem(Sdl.INIT_AUDIO) != 0) { ShowMessage("No sound: " + Sdl.Error()); return; }
        var want = new Sdl.AudioSpec { freq = VzMachine.RATE, format = Sdl.AUDIO_S16SYS, channels = 1, samples = 1024 };
        Sdl.AudioSpec got;
        audio = Sdl.SDL_OpenAudioDevice(IntPtr.Zero, 0, ref want, out got, 0);
        if (audio == 0) { ShowMessage("No sound: " + Sdl.Error()); return; }
        Sdl.SDL_PauseAudioDevice(audio, 0);
    }

    void Shutdown()
    {
        m.FlushCard(); m.Fdc.SaveAll(); StopRecordingNow(); m.Printer.Close(); m.Ser.Disconnect();
        if (!noSettings) SaveSettings();
        if (audio != 0) Sdl.SDL_CloseAudioDevice(audio);
        foreach (var p in pads) p.Close();
        Sdl.SDL_DestroyRenderer(ren); Sdl.SDL_DestroyWindow(win);
        Sdl.SDL_Quit();
    }

    /// <summary>--quit-after with --shot: saves what the window shows (checks the drawing path end to end).</summary>
    void QuitWithShot()
    {
        Render();
        if (shotPath != null)
        {
            int cw, ch; Sdl.SDL_GetRendererOutputSize(ren, out cw, out ch);
            var px = new int[cw * ch];
            if (Sdl.SDL_RenderReadPixels(ren, IntPtr.Zero, Sdl.PIXELFORMAT_RGB888, px, cw * 4) == 0) Portable.SavePng(shotPath, px, cw, ch, 1);
            else Console.Error.WriteLine("can't read the window back: " + Sdl.Error());
        }
        Console.WriteLine("fps " + fps.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture));
        running = false;
    }

    void SetIcon()
    {
        // a VZ-green 32x32 icon with "VZ" in the 6847's own letters
        var px = new int[32 * 32];
        for (int i = 0; i < px.Length; i++) px[i] = unchecked((int)0xFF0F3F0F);
        for (int y = 2; y < 30; y++) for (int x = 2; x < 30; x++) px[y * 32 + x] = unchecked((int)0xFF00C000);
        DrawText(px, 32, 4, 9, "VZ", unchecked((int)0xFF003000), 2);
        IntPtr s = Sdl.SDL_CreateRGBSurfaceWithFormatFrom(px, 32, 32, 32, 32 * 4, 0x16362004);   // ARGB8888
        if (s != IntPtr.Zero) { Sdl.SDL_SetWindowIcon(win, s); Sdl.SDL_FreeSurface(s); }
    }

    // ------------------------------------------------------------------ events
    void PumpEvents()
    {
        while (Sdl.SDL_PollEvent(ev) != 0)
        {
            uint type = (uint)Marshal.ReadInt32(ev, 0);
            switch (type)
            {
                case Sdl.QUIT: running = false; break;
                case Sdl.KEYDOWN:
                    if (Marshal.ReadByte(ev, 13) == 0) KeyDown(Marshal.ReadInt32(ev, 16), (ushort)Marshal.ReadInt16(ev, 24));
                    break;
                case Sdl.MOUSEMOTION: PenTo(Marshal.ReadInt32(ev, 20), Marshal.ReadInt32(ev, 24)); break;
                case Sdl.MOUSEBUTTONDOWN:
                    if (Marshal.ReadByte(ev, 16) == 1)
                    {
                        int x = Marshal.ReadInt32(ev, 20), y = Marshal.ReadInt32(ev, 24);
                        if (m.Pen.Enabled) { PenTo(x, y); m.Pen.Down = true; }
                        else if (Marshal.ReadByte(ev, 18) == 2) ToggleFullscreen();
                    }
                    break;
                case Sdl.MOUSEBUTTONUP: if (Marshal.ReadByte(ev, 16) == 1) m.Pen.Down = false; break;
                case Sdl.WINDOWEVENT:
                    if (Marshal.ReadByte(ev, 12) == Sdl.WINDOWEVENT_LEAVE) { m.Pen.X = m.Pen.Y = -1; m.Pen.Down = false; }
                    break;
                case Sdl.JOYDEVICEADDED: case Sdl.JOYDEVICEREMOVED: ScanPads(); break;
                case Sdl.DROPFILE:
                    IntPtr f = Marshal.ReadIntPtr(ev, 8);
                    string path = Sdl.Str(f); Sdl.SDL_free(f);
                    if (path != null) OnDrop(path);
                    break;
            }
        }
    }

    void KeyDown(int sc, ushort mod)
    {
        bool alt = (mod & Sdl.KMOD_ALT) != 0, shift = (mod & Sdl.KMOD_SHIFT) != 0;
        if (sc >= Sdl.SC_F1 && sc < Sdl.SC_F1 + 12)
        {
            switch (sc - Sdl.SC_F1 + 1)
            {
                case 1: Sdl.MessageBox(win, "VZonPC keys", HelpText); break;
                case 2: case 3: OpenVzDialog(); break;
                case 4: if (shift) { m.Cpu.Reset(); ShowMessage("CPU reset"); } else PowerOnNow(); break;
                case 5: if (lastProgram != null) LaunchNow(lastProgram); break;
                case 6: paused = !paused; ShowMessage(paused ? "Paused (F6)" : "Running"); break;
                case 7: PasteText(); break;
                case 8: muted = !muted; ShowMessage(muted ? "Sound off (F8)" : "Sound on"); break;
                case 9: warp = !warp; ShowMessage(warp ? "Warp speed (F9)" : "Normal speed"); break;
                case 10: ToggleVis(); break;
                case 11: ToggleFullscreen(); break;
                case 12: Screenshot(); break;
            }
            return;
        }
        if (!alt) return;
        if (sc == Sdl.SC_RETURN || sc == Sdl.SC_KP_ENTER) { ToggleFullscreen(); return; }
        if (sc >= Sdl.SC_1 && sc <= Sdl.SC_1 + 4) { scale = sc - Sdl.SC_1 + 1; if (fullscreen) ToggleFullscreen(); ApplyScale(); return; }
        char k = sc >= Sdl.SC_A && sc < Sdl.SC_A + 26 ? (char)('A' + sc - Sdl.SC_A) : '\0';
        switch (k)
        {
            case 'M': Reconfigure(() => m.Model = m.Model == Model.VZ200 ? Model.VZ300 : Model.VZ200); break;
            case 'X': Reconfigure(() => { m.Exp = m.Exp == MemExp.None ? MemExp.Ram16K : m.Exp == MemExp.Ram16K ? MemExp.BennVenn : MemExp.None; if (m.Exp == MemExp.BennVenn && m.Cartridge != Cart.None) m.Cartridge = Cart.None; }); break;
            case 'C':
                Reconfigure(() =>
                {
                    m.Cartridge = m.Cartridge == Cart.None ? Cart.Disk : m.Cartridge == Cart.Disk ? Cart.Rtty : m.Cartridge == Cart.Rtty ? Cart.Rs232 : m.Cartridge == Cart.Rs232 ? Cart.WordPro : Cart.None;
                    if (m.Cartridge == Cart.WordPro) m.Exp = MemExp.None; else if (m.Cartridge != Cart.None && m.Exp == MemExp.BennVenn) m.Exp = MemExp.Ram16K;
                });
                break;
            case 'G': Reconfigure(() => m.Gfx = m.Gfx == GfxMod.None ? GfxMod.Australian : m.Gfx == GfxMod.Australian ? GfxMod.German : GfxMod.None); break;
            case 'J': m.JoyInterface = !m.JoyInterface; ShowMessage("Joystick interface " + (m.JoyInterface ? "in" : "out")); break;
            case 'N': m.Printer.Enabled = !m.Printer.Enabled; ShowMessage("Printer interface " + (m.Printer.Enabled ? "in" : "out")); break;
            case 'L': m.Pen.Enabled = !m.Pen.Enabled; ShowMessage(m.Pen.Enabled ? "Light pen on: point with the mouse, hold the left button" : "Light pen off"); break;
            case 'A': arrowsJoy = !arrowsJoy; ShowMessage(arrowsJoy ? "Arrow keys + Right Ctrl = joystick 1" : "Arrow keys = VZ cursor keys"); break;
            case 'W': swapJoy = !swapJoy; ShowMessage("Joysticks " + (swapJoy ? "swapped" : "not swapped")); break;
            case 'B': showBorder = !showBorder; ApplyScale(); break;
            case 'I': integerScale = !integerScale; ShowMessage(integerScale ? "Whole-pixel scaling" : "Smooth scaling"); break;
            case 'O': m.Mono = !m.Mono; ShowMessage(m.Mono ? "Monochrome TV" : "Colour TV"); break;
            case 'V': m.ShowSnow = !m.ShowSnow; ShowMessage(m.ShowSnow ? "VRAM snow shown" : "VRAM snow hidden"); break;
            case 'T': OpenTapeDialog(); break;
            case 'S': if (m.Tape != null) { m.Tape.Playing = false; ShowMessage("Tape stopped"); } break;
            case 'R': if (m.CassOut.Recording) StopRecordingNow(); else RecordDialog(); break;
            case 'D': if (shift) Eject(0); else OpenDiskDialog(0); break;
            case 'F': if (shift) Eject(1); else OpenDiskDialog(1); break;
            case 'K': NewDiskDialog(0); break;
            case 'P': OpenPrintout(); break;
            case 'E': SerialDialog(); break;
            case 'Q': running = false; break;
        }
    }

    const string HelpText =
        "VZ keyboard: letters, digits, SPACE, RETURN, SHIFT, CTRL, , . - ; and ' (= the VZ's : key).\n" +
        "  Backspace = RUBOUT   Insert = INSERT   Esc = BREAK   = types '='\n" +
        "Joystick 1: arrow keys + Right Ctrl, or the first game controller (A/X fire, B/Y second fire).\n" +
        "Joystick 2: the second game controller.\n\n" +
        "F1 these keys   F2/F3 load a .VZ   F4 power cycle (Shift+F4 reset CPU)   F5 reload\n" +
        "F6 pause   F7 paste text   F8 mute   F9 warp   F10 visualiser   F11 / Alt+Enter fullscreen   F12 screenshot\n\n" +
        "Alt+M  VZ200 / VZ300            Alt+X  memory: none, 16K, BennVenn SD 128K\n" +
        "Alt+C  cartridge: none, disk drive, RTTY, RS-232, disk drive + WordPro\n" +
        "Alt+G  graphics: standard, Australian hi-res, German hi-res\n" +
        "Alt+J  joystick interface   Alt+N  printer interface   Alt+L  light pen (the mouse)\n" +
        "Alt+T  play a tape   Alt+S  stop it   Alt+R  record CSAVE to a WAV (again to stop)\n" +
        "Alt+D / Alt+F  insert a disk in drive 1 / 2 (with Shift: eject)   Alt+K  new blank disk\n" +
        "Alt+E  RS-232 connect   Alt+P  open the printout\n" +
        "Alt+1..5  window size   Alt+B  border   Alt+I  whole-pixel scaling   Alt+O  monochrome\n" +
        "Alt+V  VRAM snow   Alt+A  arrow keys: joystick / VZ cursor   Alt+W  swap joysticks   Alt+Q  quit\n\n" +
        "Drop a .VZ, a tape (.wav, .mp3...) or a disk (.dsk) on the window to use it; drop a folder to mount it as the SD card.\n" +
        "File dialogs need zenity or kdialog. Command-line options are the Windows version's (see README.md).";

    // ------------------------------------------------------------------ input
    readonly int[] letterSc = new int[36];
    readonly string[] letterKey = new string[36];
    byte[] keys = new byte[512];

    void PollInput()
    {
        for (int i = 0; i < 8; i++) m.Keys[i] = 0x3F;
        int j1 = 0xFF, j1a = 0xFF, j2 = 0xFF, j2a = 0xFF;
        if (letterKey[0] == null)
        {
            for (int i = 0; i < 26; i++) { letterSc[i] = Sdl.SC_A + i; letterKey[i] = ((char)('A' + i)).ToString(); }
            for (int i = 0; i < 9; i++) { letterSc[26 + i] = Sdl.SC_1 + i; letterKey[26 + i] = ((char)('1' + i)).ToString(); }
            letterSc[35] = Sdl.SC_0; letterKey[35] = "0";
        }
        if (Sdl.SDL_GetKeyboardFocus() == win)
        {
            Marshal.Copy(Sdl.SDL_GetKeyboardState(IntPtr.Zero), keys, 0, keys.Length);
            bool alt = K(Sdl.SC_LALT) || K(Sdl.SC_RALT) || K(Sdl.SC_LGUI) || K(Sdl.SC_RGUI);   // Alt keys are VZonPC's, not the VZ's
            if (!alt)
            {
                for (int i = 0; i < 36; i++) if (K(letterSc[i])) m.SetKey(letterKey[i], true);
                if (K(Sdl.SC_SPACE)) m.SetKey("SPACE", true);
                if (K(Sdl.SC_RETURN) || K(Sdl.SC_KP_ENTER)) m.SetKey("RETURN", true);
                if (K(Sdl.SC_LSHIFT) || K(Sdl.SC_RSHIFT)) m.SetKey("SHIFT", true);
                if (K(Sdl.SC_LCTRL) || (!arrowsJoy && K(Sdl.SC_RCTRL))) m.SetKey("CTRL", true);
                if (K(Sdl.SC_COMMA)) m.SetKey(",", true);
                if (K(Sdl.SC_PERIOD)) m.SetKey(".", true);
                if (K(Sdl.SC_MINUS)) m.SetKey("-", true);
                if (K(Sdl.SC_SEMICOLON)) m.SetKey(";", true);
                if (K(Sdl.SC_APOSTROPHE)) m.SetKey(":", true);
                if (K(Sdl.SC_EQUALS)) { m.SetKey("SHIFT", true); m.SetKey("-", true); }        // =
                if (K(Sdl.SC_BACKSPACE)) { m.SetKey("CTRL", true); m.SetKey(";", true); }     // rubout
                if (K(Sdl.SC_INSERT)) { m.SetKey("CTRL", true); m.SetKey("L", true); }        // insert
                if (K(Sdl.SC_ESCAPE)) { m.SetKey("CTRL", true); m.SetKey("-", true); }        // break
                bool up = K(Sdl.SC_UP), dn = K(Sdl.SC_DOWN), lf = K(Sdl.SC_LEFT), rt = K(Sdl.SC_RIGHT);
                if (arrowsJoy)
                {
                    if (up) j1 &= ~1; if (dn) j1 &= ~2; if (lf) j1 &= ~4; if (rt) j1 &= ~8;
                    if (K(Sdl.SC_RCTRL)) j1 &= ~16;
                }
                else
                {
                    if (lf) { m.SetKey("CTRL", true); m.SetKey("M", true); }
                    if (rt) { m.SetKey("CTRL", true); m.SetKey(",", true); }
                    if (up) { m.SetKey("CTRL", true); m.SetKey(".", true); }
                    if (dn) { m.SetKey("CTRL", true); m.SetKey("SPACE", true); }
                }
            }
        }
        int b, a;
        ReadPad(0, out b, out a); if (swapJoy) { j2 &= b; j2a &= a; } else { j1 &= b; j1a &= a; }
        ReadPad(1, out b, out a); if (swapJoy) { j1 &= b; j1a &= a; } else { j2 &= b; j2a &= a; }
        m.Joy[0] = j1; m.Joy[1] = j1a; m.Joy[2] = j2; m.Joy[3] = j2a;

        if (typeHold > 0) typeHold--;
        else if (typing == null && typeQueue.Count > 0) { typing = typeQueue.Dequeue(); typePhase = 0; }
        if (typing != null)
        {
            if (typePhase < 3) foreach (var k in typing) m.SetKey(k, true);
            if (++typePhase >= 6) typing = null;
        }
    }
    bool K(int sc) { return keys[sc] != 0; }

    // ---- game controllers (and plain joysticks SDL has no mapping for)
    sealed class Pad
    {
        public IntPtr Gc, Joy; public string Name;
        public void Close() { if (Gc != IntPtr.Zero) Sdl.SDL_GameControllerClose(Gc); else if (Joy != IntPtr.Zero) Sdl.SDL_JoystickClose(Joy); }
    }
    readonly List<Pad> pads = new List<Pad>();

    void ScanPads()
    {
        foreach (var p in pads) p.Close();
        pads.Clear();
        int n = Sdl.SDL_NumJoysticks();
        for (int i = 0; i < n && pads.Count < 4; i++)
        {
            var p = new Pad();
            if (Sdl.SDL_IsGameController(i) != 0) { p.Gc = Sdl.SDL_GameControllerOpen(i); if (p.Gc != IntPtr.Zero) p.Name = Sdl.GameControllerName(p.Gc); }
            if (p.Gc == IntPtr.Zero) { p.Joy = Sdl.SDL_JoystickOpen(i); if (p.Joy != IntPtr.Zero) p.Name = Sdl.JoystickName(p.Joy); }
            if (p.Gc != IntPtr.Zero || p.Joy != IntPtr.Zero) pads.Add(p);
        }
    }

    /// <summary>Controller n as VZ joystick bits (active low): 1 up, 2 down, 4 left, 8 right, 16 fire; arm = second fire.</summary>
    void ReadPad(int n, out int bits, out int arm)
    {
        bits = 0xFF; arm = 0xFF;
        if (n >= pads.Count) return;
        var p = pads[n];
        const int T = 13000;
        if (p.Gc != IntPtr.Zero)
        {
            int x = Sdl.SDL_GameControllerGetAxis(p.Gc, 0), y = Sdl.SDL_GameControllerGetAxis(p.Gc, 1);
            if (x < -T || Sdl.SDL_GameControllerGetButton(p.Gc, 13) != 0) bits &= ~4;
            if (x > T || Sdl.SDL_GameControllerGetButton(p.Gc, 14) != 0) bits &= ~8;
            if (y < -T || Sdl.SDL_GameControllerGetButton(p.Gc, 11) != 0) bits &= ~1;
            if (y > T || Sdl.SDL_GameControllerGetButton(p.Gc, 12) != 0) bits &= ~2;
            if (Sdl.SDL_GameControllerGetButton(p.Gc, 0) != 0 || Sdl.SDL_GameControllerGetButton(p.Gc, 2) != 0) bits &= ~16;   // A, X
            if (Sdl.SDL_GameControllerGetButton(p.Gc, 1) != 0 || Sdl.SDL_GameControllerGetButton(p.Gc, 3) != 0) arm &= ~16;    // B, Y
        }
        else
        {
            if (Sdl.SDL_JoystickNumAxes(p.Joy) >= 2)
            {
                int x = Sdl.SDL_JoystickGetAxis(p.Joy, 0), y = Sdl.SDL_JoystickGetAxis(p.Joy, 1);
                if (x < -T) bits &= ~4; else if (x > T) bits &= ~8;
                if (y < -T) bits &= ~1; else if (y > T) bits &= ~2;
            }
            if (Sdl.SDL_JoystickNumHats(p.Joy) > 0)
            {
                int h = Sdl.SDL_JoystickGetHat(p.Joy, 0);
                if ((h & 1) != 0) bits &= ~1; if ((h & 2) != 0) bits &= ~8; if ((h & 4) != 0) bits &= ~2; if ((h & 8) != 0) bits &= ~4;
            }
            int nb = Sdl.SDL_JoystickNumButtons(p.Joy);
            for (int i = 0; i < Math.Min(4, nb); i++)
                if (Sdl.SDL_JoystickGetButton(p.Joy, i) != 0) { if ((i & 1) == 0) bits &= ~16; else arm &= ~16; }
        }
    }

    /// <summary>Moves the light pen to the picture pixel under the mouse (window coordinates).</summary>
    void PenTo(int mx, int my)
    {
        if (!m.Pen.Enabled) { Sdl.SDL_SetCursor(arrowCursor); return; }
        Sdl.SDL_SetCursor(crossCursor);
        int ww, wh, cw, ch; Sdl.SDL_GetWindowSize(win, out ww, out wh); Sdl.SDL_GetRendererOutputSize(ren, out cw, out ch);
        if (ww > 0) mx = mx * cw / ww; if (wh > 0) my = my * ch / wh;      // window points to renderer pixels (HiDPI)
        int fx = (int)((mx - destX) * (long)destFW / Math.Max(1, destW)), fy = (int)((my - destY) * (long)destFH / Math.Max(1, destH));
        if (destFW == VzMachine.FBW) { fx -= VzMachine.BX; fy -= VzMachine.BY; }
        if (fx < 0 || fx >= 256 || fy < 0 || fy >= 192) { m.Pen.X = m.Pen.Y = -1; return; }
        m.Pen.X = fx; m.Pen.Y = fy;
    }

    // ------------------------------------------------------------------ drawing
    void PictureSize(out int w, out int h) { w = showBorder ? VzMachine.FBW : 256; h = showBorder ? VzMachine.FBH : 192; }

    static IntPtr Texture(IntPtr ren, ref IntPtr tex, int w, int h, int scaleMode)
    {
        if (tex == IntPtr.Zero)
        {
            tex = Sdl.SDL_CreateTexture(ren, Sdl.PIXELFORMAT_RGB888, Sdl.TEXTUREACCESS_STREAMING, w, h);
            try { Sdl.SDL_SetTextureScaleMode(tex, scaleMode); } catch (EntryPointNotFoundException) { }
        }
        return tex;
    }

    void Render()
    {
        int cw, ch;
        Sdl.SDL_GetRendererOutputSize(ren, out cw, out ch);
        Sdl.SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
        Sdl.SDL_RenderClear(ren);
        int w = frameW, h = frameH;
        if (texPic != IntPtr.Zero && (texPicW != w || texPicH != h)) { Sdl.SDL_DestroyTexture(texPic); texPic = IntPtr.Zero; }
        Texture(ren, ref texPic, w, h, integerScale ? 0 : 1); texPicW = w; texPicH = h;
        Sdl.SDL_UpdateTexture(texPic, IntPtr.Zero, frame, w * 4);

        int areaX = 0, areaW = cw;
        if (visOn && vis.T != null)
        {
            // the panels fill the height (at whole multiples when there's room) and the picture takes the middle
            double k = (double)ch / VzVis.H;
            if (k >= 2) k = Math.Floor(k); else if (k > 1) k = 1;
            int pw = (int)(VzVis.W * k), ph = (int)(VzVis.H * k), py = (ch - ph) / 2;
            if (cw - 2 * pw < w) { pw = Math.Max(0, (cw - w) / 2); ph = (int)((long)pw * VzVis.H / VzVis.W); py = (ch - ph) / 2; }
            Texture(ren, ref texL, VzVis.W, VzVis.H, 1); Texture(ren, ref texR, VzVis.W, VzVis.H, 1);
            Sdl.SDL_UpdateTexture(texL, IntPtr.Zero, vis.Left, VzVis.W * 4);
            Sdl.SDL_UpdateTexture(texR, IntPtr.Zero, vis.Right, VzVis.W * 4);
            areaX = pw; areaW = cw - 2 * pw;
            var rl = new Sdl.Rect(0, py, pw, ph); Sdl.SDL_RenderCopy(ren, texL, IntPtr.Zero, ref rl);
            var rr = new Sdl.Rect(cw - pw, py, pw, ph); Sdl.SDL_RenderCopy(ren, texR, IntPtr.Zero, ref rr);
        }

        int dw, dh;
        if (integerScale && areaW >= w && ch >= h)
        {
            int s = Math.Max(1, Math.Min(areaW / w, ch / h)); dw = w * s; dh = h * s;
        }
        else
        {
            double s = Math.Min((double)areaW / w, (double)ch / h); dw = Math.Max(1, (int)(w * s)); dh = Math.Max(1, (int)(h * s));
        }
        destX = areaX + (areaW - dw) / 2; destY = (ch - dh) / 2; destW = dw; destH = dh; destFW = w; destFH = h;
        var r = new Sdl.Rect(destX, destY, dw, dh);
        Sdl.SDL_RenderCopy(ren, texPic, IntPtr.Zero, ref r);

        if (messageFrames > 0 && message.Length > 0) DrawMessage(cw, ch);
        Sdl.SDL_RenderPresent(ren);
    }

    /// <summary>Shows the current message along the bottom of the window, in the 6847's own letters.</summary>
    void DrawMessage(int cw, int ch)
    {
        string text = message.ToUpperInvariant();
        int t = Math.Max(1, Math.Min(3, ch / 300));
        int maxChars = Math.Max(10, cw / (6 * t) - 2);
        if (text.Length > maxChars) text = text.Substring(0, maxChars - 3) + "...";
        int tw = text.Length * 6 + 4, th = 11;
        if (texMsg == IntPtr.Zero || texMsgText != text)
        {
            if (texMsg != IntPtr.Zero && (texMsgW != tw || texMsgH != th)) { Sdl.SDL_DestroyTexture(texMsg); texMsg = IntPtr.Zero; }
            Texture(ren, ref texMsg, tw, th, 0); texMsgW = tw; texMsgH = th; texMsgText = text;
            var px = new int[tw * th];
            for (int i = 0; i < px.Length; i++) px[i] = 0x001800;
            DrawText(px, tw, 2, 2, text, 0x40FF40, 1);
            Sdl.SDL_UpdateTexture(texMsg, IntPtr.Zero, px, tw * 4);
        }
        var r = new Sdl.Rect((cw - tw * t) / 2, ch - th * t - 4 * t, tw * t, th * t);
        Sdl.SDL_RenderCopy(ren, texMsg, IntPtr.Zero, ref r);
    }

    static void DrawText(int[] px, int stride, int x0, int y0, string s, int colour, int size)
    {
        int rows = px.Length / stride;
        for (int i = 0; i < s.Length; i++)
        {
            int c = s[i]; if (c >= 'a' && c <= 'z') c -= 32;
            if (c < 32 || c > 95) c = '?';
            int g = c & 0x3F;
            for (int y = 0; y < 7; y++)
                for (int x = 0; x < 5; x++)
                    if ((Font6847.F[g, y] & (16 >> x)) != 0)
                        for (int dy = 0; dy < size; dy++) for (int dx = 0; dx < size; dx++)
                        {
                            int X = x0 + (i * 6 + x) * size + dx, Y = y0 + y * size + dy;
                            if (X >= 0 && X < stride && Y >= 0 && Y < rows) px[Y * stride + X] = colour;
                        }
        }
    }

    void ApplyScale()
    {
        if (fullscreen) return;
        int w, h; PictureSize(out w, out h);
        int ww = w * scale, wh = h * scale;
        if (visOn) ww += 2 * (int)(VzVis.W * (double)wh / VzVis.H);
        // SDL sizes windows in points; on a HiDPI screen the renderer has more pixels than that
        int pw, ph, cw, ch; Sdl.SDL_GetWindowSize(win, out pw, out ph); Sdl.SDL_GetRendererOutputSize(ren, out cw, out ch);
        if (pw > 0 && cw > pw) { ww = ww * pw / cw; wh = wh * pw / cw; }
        Sdl.SDL_SetWindowSize(win, ww, wh);
    }

    void ToggleFullscreen()
    {
        fullscreen = !fullscreen;
        Sdl.SDL_SetWindowFullscreen(win, fullscreen ? Sdl.WINDOW_FULLSCREEN_DESKTOP : 0);
        Sdl.SDL_ShowCursor(fullscreen && !m.Pen.Enabled ? 0 : 1);
        if (!fullscreen) ApplyScale();
    }

    void ToggleVis()
    {
        visOn = !visOn;
        if (visOn) { if (m.Tr == null) m.Tr = new VzTrace(m); vis.T = m.Tr; if (vis.Sym.Count == 0 && lastProgram != null) vis.FindSymbols(lastProgram); ShowMessage("Visualiser on (F10 to close)"); }
        else { m.Tr = null; vis.T = null; }
        ApplyScale();
    }

    void UpdateTitle()
    {
        string t = "VZonPC" + (lastProgram != null && sessionProgram ? " - " + Path.GetFileName(lastProgram) : "") + "  |  " + ConfigText() + (m.HasRom ? "" : " (no ROM)");
        var tp = m.Tape;
        if (tp != null && tp.Playing) { double p = tp.Position(m.Cpu.Cyc); t += "  |  TAPE " + (int)(p / 60) + ":" + ((int)p % 60).ToString("00"); }
        if (m.DiskOn && m.Fdc.Active) t += "  |  DISK " + (m.Fdc.Selected + 1) + " T" + m.Fdc.Track.ToString("00");
        if (m.RttyOn) t += "  |  RTTY " + (m.Rtty.Ptt ? "TX" : m.Rtty.RxPlaying ? "RX" : "IDLE");
        if (m.CassOut.Recording) t += "  |  REC " + ((m.Cpu.Cyc - m.CassOut.StartCycle) / m.Clock) + "s";
        if (m.Printer.Enabled && m.Frames - m.Printer.LastFrame < 100) t += "  |  PRINTING";
        if (m.Rs232On) t += "  |  RS-232 " + (m.Ser.LinkName ?? (m.Ser.Loopback ? "LOOP" : "-"));
        if (m.Pen.Enabled) t += "  |  PEN " + (m.Pen.OnScreen ? m.Pen.X + "," + m.Pen.Y + (m.Pen.Down ? " DOWN" : "") : "OFF SCREEN");
        if (m.Ser.LinkError != null) { ShowMessage("RS-232: " + m.Ser.LinkError); m.Ser.LinkError = null; }
        t += "  |  " + (paused ? "PAUSED  " : "") + (warp ? "WARP  " : "") + (muted ? "MUTE  " : "") + fps.ToString("0") + " fps  |  F1 keys";
        Sdl.SetWindowTitle(win, t);
    }

    void ShowMessage(string s) { message = s ?? ""; messageFrames = 150; }

    // ------------------------------------------------------------------ machine
    void Reconfigure(Action change)
    {
        change();
        if (sessionProgram && lastProgram != null && File.Exists(lastProgram)) LaunchNow(lastProgram);
        else PowerOnNow();
        ShowMessage(ConfigText());
    }

    void PowerOnNow()
    {
        sessionProgram = false;
        m.PowerOn();
        if (!m.HasRom) ShowMessage("Power on: no ROM - put one in roms/, or press F2 for a machine-code .VZ");
        else if (m.VzdosFile != null) ShowMessage("Power on: BennVenn booting " + Path.GetFileName(m.VzdosFile));
        else ShowMessage("Power on: " + m.RomName);
    }

    string ConfigText()
    {
        string s = m.Model == Model.VZ300 ? "VZ300" : "VZ200";
        if (m.Exp == MemExp.BennVenn) s += " + BennVenn SD 128K" + (m.RealDos ? " (VZDOS)" : ""); else if (m.Exp == MemExp.Ram16K) s += " + 16K";
        if (m.DiskOn) s += " + disk drive" + (m.Fdc.Rom == null ? " (no vzdos.rom)" : "");
        if (m.RttyOn) s += " + RTTY" + (m.Rtty.Rom == null ? " (no vzrtty.ic3)" : "");
        if (m.Rs232On) s += " + RS-232" + (m.Ser.Rom == null ? " (no rs232_v15.ic2)" : "");
        if (m.WordProOn) s += " + WordPro" + (m.WordProRom == null ? " (no wordpro.u3-u5)" : "");
        if (m.Pen.Enabled) s += " + light pen";
        if (m.Gfx == GfxMod.Australian) s += " + Aus hi-res"; else if (m.Gfx == GfxMod.German) s += " + German hi-res";
        return s;
    }

    void LaunchNow(string path)
    {
        try
        {
            typeQueue.Clear(); typing = null;
            bool basic = m.Launch(path);
            vis.FindSymbols(path);
            if (basic && m.HasRom) TypeString("RUN\r");
            lastProgram = path; sessionProgram = true;
            ShowMessage("Loaded " + Path.GetFileName(path) + (basic && !m.HasRom ? " - BASIC program needs the VZ ROM" : ""));
            UpdateTitle();
        }
        catch (Exception ex) { ShowMessage("Can't load " + Path.GetFileName(path) + ": " + ex.Message); }
    }

    void TypeString(string s) { foreach (char c in s) { var k = VzMachine.CharKeys(c); if (k != null) typeQueue.Enqueue(k); } }

    void PasteText()
    {
        string t = Sdl.Clipboard();
        if (t.Length == 0) { ShowMessage("Clipboard has no text"); return; }
        TypeString(t.Replace("\r\n", "\r").Replace('\n', '\r'));
    }

    void Screenshot()
    {
        string dir = Path.Combine(baseDir, "screenshots");
        string name = (lastProgram != null ? Path.GetFileNameWithoutExtension(lastProgram) : "VZ") + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".png";
        try { Portable.SavePng(Path.Combine(dir, name), frame, frameW, frameH, 2); ShowMessage("Saved screenshots/" + name); }
        catch (Exception ex) { ShowMessage("Screenshot: " + ex.Message); }
    }

    void InsertDiskNow(int d, string path)
    {
        try
        {
            var dk = VzDisk.Load(path);
            m.Fdc.Insert(d, dk); diskPath[d] = path;
            ShowMessage("Drive " + (d + 1) + ": " + Path.GetFileName(path) + (dk.WriteProtect ? " (write-protected)" : "") + ", " + dk.Directory().Count + " files");
        }
        catch (Exception ex) { ShowMessage("Can't read " + Path.GetFileName(path) + ": " + ex.Message); }
    }
    void Eject(int d) { m.Fdc.Eject(d); diskPath[d] = null; ShowMessage("Drive " + (d + 1) + " empty"); }

    void EnsureDisk()
    {
        if (!m.DiskOn) Reconfigure(() => { m.Cartridge = Cart.Disk; if (m.Exp == MemExp.BennVenn) m.Exp = MemExp.Ram16K; });
    }

    void PlayTapeFile(string p)
    {
        try
        {
            var t = VzTape.Load(p, tapeRight ? 1 : 0); t.Invert = tapeInvert;
            m.PlayTape(t);
            ShowMessage("Tape: " + t.Name + " (" + (int)(t.Seconds / 60) + ":" + ((int)t.Seconds % 60).ToString("00") + ") - type CLOAD or CRUN first");
        }
        catch (Exception ex) { ShowMessage("Tape: " + ex.Message); }
    }

    void StopRecordingNow()
    {
        if (!m.CassOut.Recording) return;
        try { double sec = m.CassOut.Stop(m.Cpu.Cyc); ShowMessage(string.Format("Saved {0:F1} s of tape to {1}", sec, Path.GetFileName(m.CassOut.File))); }
        catch (Exception ex) { ShowMessage("Tape: " + ex.Message); }
    }

    void SerialConnectNow(string target)
    {
        try { m.Ser.Connect(target); ShowMessage("RS-232 connected to " + target + " (" + m.Ser.Baud + " baud)"); }
        catch (Exception ex) { ShowMessage("RS-232: can't connect to " + target + ": " + ex.Message); }
    }

    void OnDrop(string p)
    {
        string ext = Path.GetExtension(p).ToLowerInvariant();
        if (Directory.Exists(p)) { m.SdDir = p; if (m.RealDos) PowerOnNow(); ShowMessage("SD card: " + p); }
        else if (ext == ".dsk" || ext == ".dvz") { EnsureDisk(); InsertDiskNow(0, p); }
        else if (ext == ".wav" || ext == ".mp3" || ext == ".flac" || ext == ".ogg") PlayTapeFile(p);
        else LaunchNow(p);
    }

    // ------------------------------------------------------------------ dialogs (zenity or kdialog, when installed)
    /// <summary>Asks for a file with zenity or kdialog. Returns null when cancelled or when neither is installed
    /// (then the message says to drop the file on the window).</summary>
    string Pick(string title, string filterName, string patterns, bool save, string start)
    {
        if (Portable.IsWindows) { ShowMessage("Drop the file on the window (file dialogs need zenity or kdialog)"); return null; }
        string pats = patterns + " " + patterns.ToUpperInvariant();
        string[][] tries = {
            new[] { "zenity", "--file-selection --title=" + Q(title) + (save ? " --save --confirm-overwrite" : "") + (start != null ? " --filename=" + Q(start) : "") +
                (patterns.Length > 0 ? " --file-filter=" + Q(filterName + " | " + pats) + " --file-filter=" + Q("All files | *") : "") },
            new[] { "kdialog", (save ? "--getsavefilename " : "--getopenfilename ") + Q(start ?? ".") + (patterns.Length > 0 ? " " + Q(pats + "|" + filterName) : "") + " --title " + Q(title) } };
        foreach (var t in tries)
        {
            try
            {
                var psi = new ProcessStartInfo(t[0], t[1]) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
                using (var p = Process.Start(psi))
                {
                    string o = p.StandardOutput.ReadToEnd().Trim();
                    p.WaitForExit();
                    if (audio != 0) Sdl.SDL_ClearQueuedAudio(audio);
                    return p.ExitCode == 0 && o.Length > 0 ? o : null;
                }
            }
            catch (Exception) { }
        }
        ShowMessage("Drop the file on the window (file dialogs need zenity or kdialog)");
        return null;
    }
    static string Q(string s) { return "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\""; }

    string Ask(string title, string text, string value)
    {
        if (Portable.IsWindows) return null;
        foreach (var t in new[] { new[] { "zenity", "--entry --title=" + Q(title) + " --text=" + Q(text) + " --entry-text=" + Q(value) },
                                   new[] { "kdialog", "--title " + Q(title) + " --inputbox " + Q(text) + " " + Q(value) } })
        {
            try
            {
                var psi = new ProcessStartInfo(t[0], t[1]) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
                using (var p = Process.Start(psi))
                {
                    string o = p.StandardOutput.ReadToEnd().Trim(); p.WaitForExit();
                    return p.ExitCode == 0 && o.Length > 0 ? o : null;
                }
            }
            catch (Exception) { }
        }
        return null;
    }

    void OpenVzDialog() { string p = Pick("Load a VZ program", "VZ programs", "*.vz", false, m.SdDir + "/"); if (p != null) LaunchNow(p); }
    void OpenTapeDialog() { string p = Pick("Play a tape (type CLOAD or CRUN first)", "Audio", "*.wav *.mp3 *.flac *.ogg", false, null); if (p != null) PlayTapeFile(p); }
    void OpenDiskDialog(int d) { string p = Pick("Insert a disk in drive " + (d + 1), "VZ disk images", "*.dsk *.dvz", false, null); if (p != null) { EnsureDisk(); InsertDiskNow(d, p); } }
    void NewDiskDialog(int d)
    {
        string p = Pick("Save the new blank disk as", "VZ disk images", "*.dsk", true, "blank.dsk");
        if (p == null) return;
        try { File.WriteAllBytes(p, VzDisk.Blank().ToDsk()); EnsureDisk(); InsertDiskNow(d, p); } catch (Exception ex) { ShowMessage("New disk: " + ex.Message); }
    }
    void RecordDialog()
    {
        string p = Pick("Record the cassette output to", "WAV audio", "*.wav", true, "vz-tape.wav");
        if (p == null) return;
        m.CassOut.Start(p, m.Cpu.Cyc, m.Clock, m.Latch);
        ShowMessage("Recording to " + Path.GetFileName(p) + ": type CSAVE \"NAME\", then Alt+R to stop");
    }
    void SerialDialog()
    {
        if (!m.Rs232On) { ShowMessage("Fit the RS-232 cartridge first (Alt+C)"); return; }
        string t = Ask("RS-232", "Connect the VZ's RS-232 port to a telnet host (host:port) or a serial port (/dev/ttyUSB0):", lastSerialTarget);
        if (string.IsNullOrEmpty(t)) { if (Portable.IsWindows) ShowMessage("Use --serial host:port on the command line"); return; }
        lastSerialTarget = t; SerialConnectNow(t);
    }
    void OpenPrintout()
    {
        m.Printer.Flush();
        string p = m.Printer.TextPath;
        if (p == null || !File.Exists(p)) { ShowMessage("Nothing printed yet (LPRINT, LLIST or COPY prints)"); return; }
        try
        {
            if (Portable.IsWindows) Process.Start(new ProcessStartInfo(p) { UseShellExecute = true });
            else Process.Start(new ProcessStartInfo(Environment.OSVersion.Platform == PlatformID.MacOSX || Directory.Exists("/System/Library") ? "open" : "xdg-open", Q(p)) { UseShellExecute = false });
        }
        catch (Exception ex) { ShowMessage(ex.Message); }
    }

    // ------------------------------------------------------------------ command line and settings
    void ParseArgs(string[] args)
    {
        for (int i = 0; i < args.Length; i++)
        {
            string a = args[i].ToLowerInvariant();
            string v = i + 1 < args.Length ? args[i + 1] : "";
            if (a == "--sd") { m.SdDir = Path.GetFullPath(v); i++; }
            else if (a == "--machine") { m.Model = v.Contains("200") ? Model.VZ200 : Model.VZ300; i++; }
            else if (a == "--exp") { v = v.ToLowerInvariant(); m.Exp = v.StartsWith("b") || v.StartsWith("sd") ? MemExp.BennVenn : v.StartsWith("16") ? MemExp.Ram16K : MemExp.None; i++; }
            else if (a == "--gfx") { v = v.ToLowerInvariant(); m.Gfx = v.StartsWith("a") ? GfxMod.Australian : v.StartsWith("g") ? GfxMod.German : GfxMod.None; i++; }
            else if (a == "--scale") { int.TryParse(v, out scale); scale = Math.Max(1, Math.Min(5, scale)); i++; }
            else if (a == "--fullscreen") fullscreen = true;
            else if (a == "--window") fullscreen = false;
            else if (a == "--shot") { shotPath = Path.GetFullPath(v); i++; }
            else if (a == "--quit-after") { double.TryParse(v, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out quitAfter); i++; }
            else if (a == "--type") { autoType = v.Replace("\\r", "\r"); i++; }
            else if (a == "--tape") { startTape = v; i++; }
            else if (a == "--tape-right") tapeRight = true;
            else if (a == "--tape-invert") tapeInvert = true;
            else if (a == "--cart")
            {
                v = v.ToLowerInvariant();
                m.Cartridge = v.StartsWith("d") || v.StartsWith("f") ? Cart.Disk : v.StartsWith("rs") || v.StartsWith("se") ? Cart.Rs232 : v.StartsWith("r") ? Cart.Rtty : v.StartsWith("w") ? Cart.WordPro : Cart.None;
                if (m.Cartridge == Cart.WordPro) m.Exp = MemExp.None;
                i++;
            }
            else if (a == "--lpen") m.Pen.Enabled = true;
            else if (a == "--printer") m.Printer.Enabled = true;
            else if (a == "--serial") { startSerial = v; m.Cartridge = Cart.Rs232; i++; }
            else if (a == "--disk" || a == "--disk1") { startDisk[0] = Path.GetFullPath(v); if (m.Cartridge != Cart.Rtty && m.Cartridge != Cart.WordPro) m.Cartridge = Cart.Disk; i++; }
            else if (a == "--disk2") { startDisk[1] = Path.GetFullPath(v); i++; }
            else if (a == "--rtty") { startRtty = Path.GetFullPath(v); m.Cartridge = Cart.Rtty; i++; }
            else if (a == "--border") { showBorder = v != "0"; i++; }
            else if (a == "--integer") { integerScale = v != "0"; i++; }
            else if (a == "--no-settings") { }
            else if (a == "--vis") visOn = true;
            else if (a == "--help" || a == "-h") { Console.WriteLine(HelpText); Environment.Exit(0); }
            else if (File.Exists(args[i])) startProgram = Path.GetFullPath(args[i]);
            else if (Directory.Exists(args[i])) m.SdDir = Path.GetFullPath(args[i]);
            else Console.Error.WriteLine("ignored: " + args[i]);
        }
    }

    void LoadSettings()
    {
        if (!File.Exists(iniPath)) return;
        foreach (var line in File.ReadAllLines(iniPath))
        {
            int eq = line.IndexOf('='); if (eq < 0) continue;
            string k = line.Substring(0, eq).Trim().ToLowerInvariant(), v = line.Substring(eq + 1).Trim();
            try
            {
                switch (k)
                {
                    case "machine": m.Model = v == "VZ200" ? Model.VZ200 : Model.VZ300; break;
                    case "expansion": m.Exp = (MemExp)Enum.Parse(typeof(MemExp), v); break;
                    case "cartridge": m.Cartridge = (Cart)Enum.Parse(typeof(Cart), v); break;
                    case "disk1": if (File.Exists(v) && startDisk[0] == null) startDisk[0] = v; break;
                    case "disk2": if (File.Exists(v) && startDisk[1] == null) startDisk[1] = v; break;
                    case "graphics": m.Gfx = (GfxMod)Enum.Parse(typeof(GfxMod), v); break;
                    case "joyinterface": m.JoyInterface = v == "1"; break;
                    case "printer": m.Printer.Enabled = v == "1"; break;
                    case "lightpen": m.Pen.Enabled = v == "1"; break;
                    case "rs232": lastSerialTarget = v; break;
                    case "bootvzdos": m.BootVzdos = v == "1"; break;
                    case "sdwriteback": m.SdWriteBack = v == "1"; break;
                    case "sd": if (Directory.Exists(v)) m.SdDir = v; break;
                    case "scale": scale = Math.Max(1, Math.Min(5, int.Parse(v))); break;
                    case "integerscale": integerScale = v == "1"; break;
                    case "border": showBorder = v == "1"; break;
                    case "fullscreen": fullscreen = v == "1"; break;
                    case "mono": m.Mono = v == "1"; break;
                    case "snow": m.ShowSnow = v == "1"; break;
                    case "arrowsjoystick": arrowsJoy = v == "1"; break;
                    case "swapjoysticks": swapJoy = v == "1"; break;
                    case "muted": muted = v == "1"; break;
                    case "visualiser": visOn = v == "1"; break;
                    case "lastprogram": lastProgram = File.Exists(v) ? v : null; break;
                }
            }
            catch (Exception) { }
        }
    }

    void SaveSettings()
    {
        try
        {
            File.WriteAllLines(iniPath, new[] {
                "machine=" + m.Model, "expansion=" + m.Exp, "cartridge=" + m.Cartridge, "disk1=" + (diskPath[0] ?? ""), "disk2=" + (diskPath[1] ?? ""), "graphics=" + m.Gfx, "joyinterface=" + (m.JoyInterface ? 1 : 0), "printer=" + (m.Printer.Enabled ? 1 : 0), "lightpen=" + (m.Pen.Enabled ? 1 : 0), "rs232=" + lastSerialTarget, "bootvzdos=" + (m.BootVzdos ? 1 : 0), "sdwriteback=" + (m.SdWriteBack ? 1 : 0),
                "sd=" + m.SdDir, "scale=" + scale, "integerscale=" + (integerScale ? 1 : 0), "border=" + (showBorder ? 1 : 0),
                "fullscreen=" + (fullscreen ? 1 : 0), "mono=" + (m.Mono ? 1 : 0), "snow=" + (m.ShowSnow ? 1 : 0),
                "arrowsjoystick=" + (arrowsJoy ? 1 : 0), "swapjoysticks=" + (swapJoy ? 1 : 0), "muted=" + (muted ? 1 : 0), "visualiser=" + (visOn ? 1 : 0),
                "lastprogram=" + (lastProgram ?? "") });
        }
        catch (Exception) { }
    }
}
