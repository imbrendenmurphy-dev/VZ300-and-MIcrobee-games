// The small part of SDL2 that VZonPC's cross-platform front end uses: a window, a renderer, queued audio, the
// keyboard, game controllers and joysticks, drag-and-drop, the clipboard and message boxes.
//
// SDL2 is found as SDL2.dll on Windows (next to the exe), as libSDL2-2.0.so.0 on Linux and libSDL2-2.0.0.dylib
// on macOS. Mono maps the name through VZonPC-SDL.exe.config; modern .NET is pointed at it by Sdl.Setup(),
// which installs a DllImport resolver through reflection, since this compiles against .NET Framework 4.
using System;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

public static class Sdl
{
    const string L = "SDL2";
    const CallingConvention C = CallingConvention.Cdecl;

    public const uint INIT_AUDIO = 0x10, INIT_VIDEO = 0x20, INIT_JOYSTICK = 0x200, INIT_GAMECONTROLLER = 0x2000;
    public const int WINDOWPOS_CENTERED = 0x2FFF0000;
    public const uint WINDOW_FULLSCREEN_DESKTOP = 0x1001, WINDOW_RESIZABLE = 0x20, WINDOW_ALLOW_HIGHDPI = 0x2000;
    public const uint RENDERER_ACCELERATED = 2;
    public const uint PIXELFORMAT_RGB888 = 0x16161804;          // 0x00RRGGBB in a 32-bit int, as the core makes
    public const int TEXTUREACCESS_STREAMING = 1;
    public const ushort AUDIO_S16SYS = 0x8010;

    // events
    public const uint QUIT = 0x100, WINDOWEVENT = 0x200, KEYDOWN = 0x300, KEYUP = 0x301,
        MOUSEMOTION = 0x400, MOUSEBUTTONDOWN = 0x401, MOUSEBUTTONUP = 0x402,
        JOYDEVICEADDED = 0x605, JOYDEVICEREMOVED = 0x606, DROPFILE = 0x1000;
    public const byte WINDOWEVENT_LEAVE = 11, WINDOWEVENT_FOCUS_LOST = 13;

    // keyboard scancodes (USB HID usage numbers)
    public const int SC_A = 4, SC_1 = 30, SC_0 = 39, SC_RETURN = 40, SC_ESCAPE = 41, SC_BACKSPACE = 42, SC_SPACE = 44,
        SC_MINUS = 45, SC_EQUALS = 46, SC_SEMICOLON = 51, SC_APOSTROPHE = 52, SC_COMMA = 54, SC_PERIOD = 55,
        SC_F1 = 58, SC_INSERT = 73, SC_RIGHT = 79, SC_LEFT = 80, SC_DOWN = 81, SC_UP = 82, SC_KP_ENTER = 88,
        SC_LCTRL = 224, SC_LSHIFT = 225, SC_LALT = 226, SC_LGUI = 227, SC_RCTRL = 228, SC_RSHIFT = 229, SC_RALT = 230, SC_RGUI = 231;
    public const ushort KMOD_SHIFT = 0x0003, KMOD_CTRL = 0x00C0, KMOD_ALT = 0x0300;

    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int x, y, w, h; public Rect(int x, int y, int w, int h) { this.x = x; this.y = y; this.w = w; this.h = h; } }
    [StructLayout(LayoutKind.Sequential)]
    public struct AudioSpec { public int freq; public ushort format; public byte channels, silence; public ushort samples, padding; public uint size; public IntPtr callback, userdata; }

    [DllImport(L, CallingConvention = C)] public static extern int SDL_Init(uint flags);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_InitSubSystem(uint flags);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_Quit();
    [DllImport(L, CallingConvention = C)] static extern IntPtr SDL_GetError();
    [DllImport(L, CallingConvention = C)] static extern int SDL_SetHint(byte[] name, byte[] value);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_free(IntPtr p);
    [DllImport(L, CallingConvention = C)] static extern void SDL_GetVersion(byte[] v);

    [DllImport(L, CallingConvention = C)] static extern IntPtr SDL_CreateWindow(byte[] title, int x, int y, int w, int h, uint flags);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_DestroyWindow(IntPtr w);
    [DllImport(L, CallingConvention = C)] static extern void SDL_SetWindowTitle(IntPtr w, byte[] title);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_SetWindowFullscreen(IntPtr w, uint flags);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_SetWindowSize(IntPtr w, int width, int height);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_GetWindowSize(IntPtr w, out int width, out int height);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_SetWindowMinimumSize(IntPtr w, int width, int height);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_SetWindowIcon(IntPtr w, IntPtr surface);
    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_GetKeyboardFocus();
    [DllImport(L, CallingConvention = C)] public static extern int SDL_ShowCursor(int toggle);
    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_CreateRGBSurfaceWithFormatFrom(int[] pixels, int w, int h, int depth, int pitch, uint format);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_FreeSurface(IntPtr s);
    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_CreateSystemCursor(int id);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_SetCursor(IntPtr c);

    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_CreateRenderer(IntPtr w, int index, uint flags);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_DestroyRenderer(IntPtr r);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_GetRendererOutputSize(IntPtr r, out int w, out int h);
    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_CreateTexture(IntPtr r, uint format, int access, int w, int h);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_DestroyTexture(IntPtr t);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_UpdateTexture(IntPtr t, IntPtr rect, int[] pixels, int pitch);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_SetTextureScaleMode(IntPtr t, int mode);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_SetRenderDrawColor(IntPtr r, byte cr, byte cg, byte cb, byte ca);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_RenderClear(IntPtr r);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_RenderCopy(IntPtr r, IntPtr t, IntPtr src, ref Rect dst);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_RenderFillRect(IntPtr r, ref Rect rect);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_RenderPresent(IntPtr r);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_RenderReadPixels(IntPtr r, IntPtr rect, uint format, int[] pixels, int pitch);

    [DllImport(L, CallingConvention = C)] public static extern int SDL_PollEvent(IntPtr ev);
    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_GetKeyboardState(IntPtr numkeys);
    [DllImport(L, CallingConvention = C)] public static extern ushort SDL_GetModState();
    [DllImport(L, CallingConvention = C)] static extern IntPtr SDL_GetClipboardText();
    [DllImport(L, CallingConvention = C)] static extern int SDL_ShowSimpleMessageBox(uint flags, byte[] title, byte[] message, IntPtr window);

    [DllImport(L, CallingConvention = C)] public static extern uint SDL_OpenAudioDevice(IntPtr device, int iscapture, ref AudioSpec desired, out AudioSpec obtained, int allowedChanges);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_PauseAudioDevice(uint dev, int pause);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_QueueAudio(uint dev, short[] data, uint len);
    [DllImport(L, CallingConvention = C)] public static extern uint SDL_GetQueuedAudioSize(uint dev);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_ClearQueuedAudio(uint dev);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_CloseAudioDevice(uint dev);

    [DllImport(L, CallingConvention = C)] public static extern int SDL_NumJoysticks();
    [DllImport(L, CallingConvention = C)] public static extern int SDL_IsGameController(int index);
    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_GameControllerOpen(int index);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_GameControllerClose(IntPtr gc);
    [DllImport(L, CallingConvention = C)] static extern IntPtr SDL_GameControllerName(IntPtr gc);
    [DllImport(L, CallingConvention = C)] public static extern short SDL_GameControllerGetAxis(IntPtr gc, int axis);
    [DllImport(L, CallingConvention = C)] public static extern byte SDL_GameControllerGetButton(IntPtr gc, int button);
    [DllImport(L, CallingConvention = C)] public static extern IntPtr SDL_JoystickOpen(int index);
    [DllImport(L, CallingConvention = C)] public static extern void SDL_JoystickClose(IntPtr j);
    [DllImport(L, CallingConvention = C)] static extern IntPtr SDL_JoystickName(IntPtr j);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_JoystickNumAxes(IntPtr j);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_JoystickNumButtons(IntPtr j);
    [DllImport(L, CallingConvention = C)] public static extern int SDL_JoystickNumHats(IntPtr j);
    [DllImport(L, CallingConvention = C)] public static extern short SDL_JoystickGetAxis(IntPtr j, int axis);
    [DllImport(L, CallingConvention = C)] public static extern byte SDL_JoystickGetButton(IntPtr j, int button);
    [DllImport(L, CallingConvention = C)] public static extern byte SDL_JoystickGetHat(IntPtr j, int hat);

    // ---- strings are UTF-8 both ways
    static byte[] U(string s) { var b = Encoding.UTF8.GetBytes(s ?? ""); Array.Resize(ref b, b.Length + 1); return b; }
    public static string Str(IntPtr p)
    {
        if (p == IntPtr.Zero) return null;
        int n = 0; while (Marshal.ReadByte(p, n) != 0) n++;
        var b = new byte[n]; Marshal.Copy(p, b, 0, n);
        return Encoding.UTF8.GetString(b);
    }
    public static string Error() { return Str(SDL_GetError()); }
    public static void SetHint(string name, string value) { SDL_SetHint(U(name), U(value)); }
    public static IntPtr CreateWindow(string title, int w, int h, uint flags) { return SDL_CreateWindow(U(title), WINDOWPOS_CENTERED, WINDOWPOS_CENTERED, w, h, flags); }
    public static void SetWindowTitle(IntPtr w, string t) { SDL_SetWindowTitle(w, U(t)); }
    public static void MessageBox(IntPtr w, string title, string text) { SDL_ShowSimpleMessageBox(0x40, U(title), U(text), w); }
    public static string GameControllerName(IntPtr gc) { return Str(SDL_GameControllerName(gc)); }
    public static string JoystickName(IntPtr j) { return Str(SDL_JoystickName(j)); }
    public static string Clipboard()
    {
        IntPtr p = SDL_GetClipboardText();
        string s = Str(p); if (p != IntPtr.Zero) SDL_free(p);
        return s ?? "";
    }
    public static string Version()
    {
        var v = new byte[3]; SDL_GetVersion(v);
        return v[0] + "." + v[1] + "." + v[2];
    }

    // ---- finding the library
    static readonly string[] Candidates = {
        "libSDL2-2.0.so.0", "libSDL2-2.0.so", "libSDL2.so",                                    // Linux
        "libSDL2-2.0.0.dylib", "libSDL2.dylib", "/opt/homebrew/lib/libSDL2-2.0.0.dylib",       // macOS
        "/usr/local/lib/libSDL2-2.0.0.dylib", "SDL2.dll" };

    /// <summary>On modern .NET, teaches DllImport where SDL2 is (Mono uses the .exe.config instead, and Windows finds
    /// SDL2.dll next to the exe by itself).</summary>
    public static void Setup()
    {
        Type nl = Type.GetType("System.Runtime.InteropServices.NativeLibrary");
        Type res = Type.GetType("System.Runtime.InteropServices.DllImportResolver");
        if (nl == null || res == null || Type.GetType("Mono.Runtime") != null) return;
        try
        {
            var set = nl.GetMethod("SetDllImportResolver", new[] { typeof(Assembly), res });
            var d = Delegate.CreateDelegate(res, typeof(Sdl).GetMethod("Resolve", BindingFlags.NonPublic | BindingFlags.Static));
            set.Invoke(null, new object[] { typeof(Sdl).Assembly, d });
        }
        catch (Exception) { }
    }

    static IntPtr Resolve(string name, Assembly asm, DllImportSearchPath? path)
    {
        if (name != L) return IntPtr.Zero;
        Type nl = Type.GetType("System.Runtime.InteropServices.NativeLibrary");
        var tryLoad = nl.GetMethod("TryLoad", new[] { typeof(string), typeof(IntPtr).MakeByRefType() });
        var tryLoadNear = nl.GetMethod("TryLoad", new[] { typeof(string), typeof(Assembly), typeof(DllImportSearchPath?), typeof(IntPtr).MakeByRefType() });
        foreach (var c in Candidates)
        {
            var a = new object[] { c, asm, path, IntPtr.Zero };
            if (tryLoadNear != null && (bool)tryLoadNear.Invoke(null, a)) return (IntPtr)a[3];
            var b = new object[] { c, IntPtr.Zero };
            if ((bool)tryLoad.Invoke(null, b)) return (IntPtr)b[1];
        }
        return IntPtr.Zero;
    }
}
