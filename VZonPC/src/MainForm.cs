// VZonPC main window: menus, display scaling / fullscreen, keyboard + joystick input,
// emulation thread paced by the sound card.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;

public static class VzApp
{
    [STAThread]
    public static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm(args));
        return 0;
    }
}

sealed class DisplayPanel : Panel
{
    public Action Repaint;
    public DisplayPanel() { SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.Opaque, true); BackColor = Color.Black; }
    protected override void OnPaint(PaintEventArgs e) { if (Repaint != null) Repaint(); }
}

public sealed class MainForm : Form
{
    readonly VzMachine m = new VzMachine();
    readonly ConcurrentQueue<Action> cmds = new ConcurrentQueue<Action>();
    readonly DisplayPanel display = new DisplayPanel();
    readonly MenuStrip menu = new MenuStrip();
    readonly StatusStrip status = new StatusStrip();
    readonly ToolStripStatusLabel stLeft = new ToolStripStatusLabel(), stRight = new ToolStripStatusLabel();
    Thread emuThread; volatile bool running = true;
    IntPtr displayHwnd, formHwnd;
    volatile int dispW, dispH;

    // settings
    readonly string iniPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "vzonpc.ini");
    int scale = 3;
    bool integerScale = true, showBorder = true, fullscreen = false, arrowsJoy = true, swapJoy = false, muted = false;
    bool paused = false, warp = false;
    string lastProgram = null; bool sessionProgram = false;
    string message = ""; int messageFrames = 0;

    // frame shared with the UI thread
    readonly object frameLock = new object();
    int[] frame = new int[VzMachine.FBW * VzMachine.FBH]; int frameW = VzMachine.FBW, frameH = VzMachine.FBH;

    // paste / auto-type queue (emulation thread only)
    readonly Queue<string[]> typeQueue = new Queue<string[]>();
    string[] typing; int typePhase;

    double fps; Rectangle savedBounds; FormWindowState savedState;

    // visualiser (F10): sidebars in fullscreen, its own window otherwise
    readonly VzVis vis;
    volatile bool visOn;
    VisForm visForm; volatile IntPtr visHwnd; volatile int visW, visH;

    public MainForm(string[] args)
    {
        Text = "VZonPC";
        try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
        KeyPreview = true;
        AllowDrop = true;
        vis = new VzVis(m);
        m.SdDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "SD");
        if (!Array.Exists(args, x => x == "--no-settings" || x == "--quit-after")) LoadSettings();
        ParseArgs(args);

        display.Dock = DockStyle.Fill;
        display.Repaint = BlitLatest;
        display.Resize += (s, e) => { dispW = display.ClientSize.Width; dispH = display.ClientSize.Height; BlitLatest(); };
        display.MouseDoubleClick += (s, e) => ToggleFullscreen();
        status.Items.Add(stLeft); stLeft.Spring = true; stLeft.TextAlign = ContentAlignment.MiddleLeft;
        status.Items.Add(stRight);
        BuildMenu();
        Controls.Add(display);
        Controls.Add(status);
        Controls.Add(menu);
        MainMenuStrip = menu;

        DragEnter += (s, e) => { if (e.Data.GetDataPresent(DataFormats.FileDrop)) e.Effect = DragDropEffects.Copy; };
        DragDrop += OnDrop;

        Load += (s, e) =>
        {
            displayHwnd = display.Handle; formHwnd = Handle;
            dispW = display.ClientSize.Width; dispH = display.ClientSize.Height;
            ApplyScale();
            if (fullscreen) { fullscreen = false; ToggleFullscreen(); }
            if (visOn) { visOn = false; ToggleVis(); }
            Joysticks.Scan();
            emuThread = new Thread(EmuLoop) { IsBackground = true, Name = "emulation" };
            emuThread.Start();
            var t = new System.Windows.Forms.Timer { Interval = 500 }; t.Tick += (s2, e2) => UpdateStatus(); t.Start();
            if (quitAfter > 0)
            {
                var q = new System.Windows.Forms.Timer { Interval = (int)(quitAfter * 1000) };
                q.Tick += (s2, e2) =>
                {
                    q.Stop();
                    UpdateStatus(); Refresh();
                    if (shotPath != null)
                    {
                        // capture the real window from the screen (checks the GUI path end to end)
                        var r = RectangleToScreen(ClientRectangle);
                        using (var bmp = new Bitmap(r.Width, r.Height))
                        {
                            using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(r.Location, Point.Empty, r.Size);
                            bmp.Save(shotPath, System.Drawing.Imaging.ImageFormat.Png);
                        }
                        if (visForm != null)
                        {
                            var r2 = visForm.RectangleToScreen(visForm.ClientRectangle);
                            using (var bmp = new Bitmap(r2.Width, r2.Height))
                            {
                                using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(r2.Location, Point.Empty, r2.Size);
                                bmp.Save(Path.ChangeExtension(shotPath, null) + "_vis.png", System.Drawing.Imaging.ImageFormat.Png);
                            }
                        }
                    }
                    Console.WriteLine("fps " + fps.ToString("0.0"));
                    Close();
                };
                q.Start();
            }
        };
        FormClosing += (s, e) => { running = false; if (emuThread != null) emuThread.Join(1000); m.FlushCard(); if (!noSettings) SaveSettings(); };

        m.Log = s => ShowMessage(s);
        cmds.Enqueue(() =>
        {
            PowerOnNow();
            if (startProgram != null) LaunchNow(startProgram);
            if (autoType != null) { if (startProgram == null && m.HasRom) typeHold = 150; TypeString(autoType); }   // let BASIC reach READY first
            if (startTape != null)
            {
                // --tape FILE: start it once --type has finished, half a second later (as if pressing PLAY)
                var t = VzTape.Load(startTape, tapeRight ? 1 : 0); t.Invert = tapeInvert;
                pendingTape = t; pendingTapeDelay = 25;
            }
        });
    }

    VzTape pendingTape; int pendingTapeDelay, typeHold;
    string startProgram, shotPath, autoType, startTape; double quitAfter; bool noSettings;
    void ParseArgs(string[] args)
    {
        noSettings = Array.Exists(args, x => x == "--no-settings" || x == "--quit-after");
        for (int i = 0; i < args.Length; i++)
        {
            string a = args[i].ToLowerInvariant();
            string v = i + 1 < args.Length ? args[i + 1] : "";
            if (a == "--sd") { m.SdDir = Path.GetFullPath(v); i++; }
            else if (a == "--machine") { m.Model = v.Contains("200") ? Model.VZ200 : Model.VZ300; i++; }
            else if (a == "--exp") { v = v.ToLowerInvariant(); m.Exp = v.StartsWith("b") || v.StartsWith("sd") ? MemExp.BennVenn : v.StartsWith("16") ? MemExp.Ram16K : MemExp.None; i++; }
            else if (a == "--gfx") { v = v.ToLowerInvariant(); m.Gfx = v.StartsWith("a") ? GfxMod.Australian : v.StartsWith("g") ? GfxMod.German : GfxMod.None; i++; }
            else if (a == "--scale") { int.TryParse(v, out scale); i++; }
            else if (a == "--fullscreen") fullscreen = true;
            else if (a == "--window") fullscreen = false;
            else if (a == "--shot") { shotPath = Path.GetFullPath(v); i++; }
            else if (a == "--quit-after") { double.TryParse(v, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out quitAfter); i++; }
            else if (a == "--type") { autoType = v.Replace("\\r", "\r"); i++; }
            else if (a == "--tape") { startTape = v; i++; }
            else if (a == "--border") { showBorder = v != "0"; i++; }
            else if (a == "--integer") { integerScale = v != "0"; i++; }
            else if (a == "--no-settings") { }
            else if (a == "--vis") visOn = true;
            else if (File.Exists(args[i])) startProgram = Path.GetFullPath(args[i]);
            else if (Directory.Exists(args[i])) m.SdDir = Path.GetFullPath(args[i]);
        }
    }

    // ------------------------------------------------------------------ menus
    ToolStripMenuItem miVz200, miVz300, miExpNone, miExp16, miExpBv, miGfxNone, miGfxAus, miGfxGer, miJoyIf, miVzdos, miWriteBack,
        miBorder, miVis, miInteger, miMono, miSnow, miStatus, miFull, miArrowsJoy, miArrowsCursor, miSwap, miPause, miWarp, miMute, miJoyList;
    ToolStripMenuItem[] miScale = new ToolStripMenuItem[6];

    static ToolStripMenuItem Item(string text, Keys keys, EventHandler click)
    {
        var mi = new ToolStripMenuItem(text, null, click);
        if (keys != Keys.None) { mi.ShortcutKeys = keys; }
        return mi;
    }

    void BuildMenu()
    {
        var file = new ToolStripMenuItem("&File");
        file.DropDownItems.Add(Item("Load program from SD card...", Keys.F2, (s, e) => OpenSdBrowser()));
        file.DropDownItems.Add(Item("Load .VZ file...", Keys.F3, (s, e) => OpenVzDialog()));
        file.DropDownItems.Add(Item("Reload last program", Keys.F5, (s, e) => { if (lastProgram != null) Launch(lastProgram); }));
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(Item("Mount SD card folder...", Keys.None, (s, e) => ChooseSdFolder()));
        file.DropDownItems.Add(Item("Open SD card folder in Explorer", Keys.None, (s, e) => { try { Process.Start("explorer.exe", "\"" + m.SdDir + "\""); } catch { } }));
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(Item("Play tape (audio file)...", Keys.None, (s, e) => OpenTapeDialog()));
        miTapeRight = Item("Tape: use the right channel", Keys.None, (s, e) => { tapeRight = !tapeRight; miTapeRight.Checked = tapeRight; });
        miTapeInvert = Item("Tape: invert the signal", Keys.None, (s, e) => { tapeInvert = !tapeInvert; miTapeInvert.Checked = tapeInvert; cmds.Enqueue(() => { if (m.Tape != null) m.Tape.Invert = tapeInvert; }); });
        file.DropDownItems.Add(miTapeRight);
        file.DropDownItems.Add(miTapeInvert);
        file.DropDownItems.Add(Item("Stop tape", Keys.None, (s, e) => cmds.Enqueue(() => { if (m.Tape != null) m.Tape.Playing = false; })));
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(Item("Paste text as typing", Keys.F7, (s, e) => PasteText()));
        file.DropDownItems.Add(Item("Save screenshot", Keys.F12, (s, e) => Screenshot()));
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(Item("Exit", Keys.None, (s, e) => Close()));

        var mach = new ToolStripMenuItem("&Machine");
        miVz200 = Item("VZ200 (8K, 3.58 MHz)", Keys.None, (s, e) => Reconfigure(() => m.Model = Model.VZ200));
        miVz300 = Item("VZ300 (18K, 3.55 MHz)", Keys.None, (s, e) => Reconfigure(() => m.Model = Model.VZ300));
        mach.DropDownItems.AddRange(new ToolStripItem[] { miVz200, miVz300, new ToolStripSeparator() });
        var exp = new ToolStripMenuItem("Memory expansion");
        miExpNone = Item("None", Keys.None, (s, e) => Reconfigure(() => m.Exp = MemExp.None));
        miExp16 = Item("16K RAM pack", Keys.None, (s, e) => Reconfigure(() => m.Exp = MemExp.Ram16K));
        miExpBv = Item("BennVenn SD loader + 128K", Keys.None, (s, e) => Reconfigure(() => m.Exp = MemExp.BennVenn));
        exp.DropDownItems.AddRange(new ToolStripItem[] { miExpNone, miExp16, miExpBv });
        var gfx = new ToolStripMenuItem("Graphics");
        miGfxNone = Item("Standard (MC6847, 2K video RAM)", Keys.None, (s, e) => Reconfigure(() => m.Gfx = GfxMod.None));
        miGfxAus = Item("Australian super hi-res mod (6K, 256x192, OUT 32)", Keys.None, (s, e) => Reconfigure(() => m.Gfx = GfxMod.Australian));
        miGfxGer = Item("German hi-res mod (6K, 256x192, latch bit 1)", Keys.None, (s, e) => Reconfigure(() => m.Gfx = GfxMod.German));
        gfx.DropDownItems.AddRange(new ToolStripItem[] { miGfxNone, miGfxAus, miGfxGer });
        miJoyIf = Item("Joystick interface", Keys.None, (s, e) => cmds.Enqueue(() => m.JoyInterface = !m.JoyInterface));
        miVzdos = Item("Boot VZDOS.VZ at power-on (BennVenn)", Keys.None, (s, e) => cmds.Enqueue(() => { m.BootVzdos = !m.BootVzdos; PowerOnNow(); }));
        miWriteBack = Item("Save SD card changes to the PC folder", Keys.None, (s, e) => cmds.Enqueue(() => { m.SdWriteBack = !m.SdWriteBack; if (m.SdWriteBack) m.FlushCard(); ShowMessage(m.SdWriteBack ? "SD card saves go to the PC folder" : "SD card saves stay in memory until power off"); }));
        mach.DropDownItems.AddRange(new ToolStripItem[] { exp, gfx, miJoyIf, miVzdos, miWriteBack, new ToolStripSeparator() });
        mach.DropDownItems.Add(Item("Power cycle", Keys.F4, (s, e) => cmds.Enqueue(PowerOnNow)));
        mach.DropDownItems.Add(Item("Reset CPU", Keys.Shift | Keys.F4, (s, e) => cmds.Enqueue(() => m.Cpu.Reset())));
        miPause = Item("Pause", Keys.F6, (s, e) => { paused = !paused; });
        miWarp = Item("Warp speed", Keys.F9, (s, e) => { warp = !warp; });
        miMute = Item("Mute sound", Keys.F8, (s, e) => { muted = !muted; });
        mach.DropDownItems.AddRange(new ToolStripItem[] { miPause, miWarp, miMute });

        var view = new ToolStripMenuItem("&View");
        for (int i = 1; i <= 5; i++)
        {
            int s0 = i;
            miScale[i] = Item(i == 1 ? "1:1 pixels (x1)" : "Scale x" + i, Keys.None, (s, e) => { scale = s0; if (fullscreen) ToggleFullscreen(); ApplyScale(); });
            view.DropDownItems.Add(miScale[i]);
        }
        view.DropDownItems.Add(new ToolStripSeparator());
        miVis = Item("Visualiser   (F10)", Keys.None, (s, e) => ToggleVis());
        view.DropDownItems.Add(miVis);
        view.DropDownItems.Add(new ToolStripSeparator());
        miInteger = Item("Whole-pixel scaling only (sharp)", Keys.None, (s, e) => { integerScale = !integerScale; BlitLatest(); });
        miFull = Item("Fullscreen   (F11 / Alt+Enter)", Keys.F11, (s, e) => ToggleFullscreen());
        miBorder = Item("Show border", Keys.None, (s, e) => { showBorder = !showBorder; ApplyScale(); });
        miMono = Item("Monochrome TV", Keys.None, (s, e) => { m.Mono = !m.Mono; });
        miSnow = Item("Show VRAM snow", Keys.None, (s, e) => { m.ShowSnow = !m.ShowSnow; });
        miStatus = Item("Status bar", Keys.None, (s, e) => { status.Visible = !status.Visible; ApplyScale(); });
        view.DropDownItems.AddRange(new ToolStripItem[] { miInteger, miFull, new ToolStripSeparator(), miBorder, miMono, miSnow, miStatus });

        var input = new ToolStripMenuItem("&Input");
        miArrowsJoy = Item("Arrow keys + Right Ctrl = joystick 1", Keys.None, (s, e) => arrowsJoy = true);
        miArrowsCursor = Item("Arrow keys = VZ cursor keys", Keys.None, (s, e) => arrowsJoy = false);
        miSwap = Item("Swap joysticks 1 and 2", Keys.None, (s, e) => swapJoy = !swapJoy);
        miJoyList = new ToolStripMenuItem("PC joysticks found: 0") { Enabled = false };
        input.DropDownItems.AddRange(new ToolStripItem[] { miArrowsJoy, miArrowsCursor, new ToolStripSeparator(), miSwap,
            Item("Rescan joysticks", Keys.None, (s, e) => { Joysticks.Scan(); ShowMessage(Joysticks.Count + " joystick(s): " + string.Join(", ", Joysticks.Names)); }), miJoyList });

        var help = new ToolStripMenuItem("&Help");
        help.DropDownItems.Add(Item("Keys and controls", Keys.F1, (s, e) => MessageBox.Show(this, HelpText, "VZonPC keys")));
        help.DropDownItems.Add(Item("About", Keys.None, (s, e) => MessageBox.Show(this,
            "VZonPC - Dick Smith VZ200 / VZ300 emulator\n\nZ80, MC6847 video (standard + Australian and German 6K hi-res mods), " +
            "BennVenn SD loader with 128K, joysticks, sound.\n\nROM: " + (m.HasRom ? m.RomName : "none (built-in stub)") +
            "\nROM folder: " + VzMachine.RomDir + "\nSD folder: " + m.SdDir, "About VZonPC")));

        menu.Items.AddRange(new ToolStripItem[] { file, mach, view, input, help });
        menu.MenuActivate += (s, e) => SyncMenu();
        file.DropDownOpening += (s, e) => SyncMenu();
    }

    const string HelpText =
        "VZ keyboard: letters, digits, SPACE, RETURN, SHIFT, CTRL, , . - ; and ' (= VZ ':' key).\n" +
        "  Backspace = RUBOUT (CTRL+;)    Insert = INSERT (CTRL+L)    Esc = BREAK (CTRL+-)\n" +
        "  = key types '=' (SHIFT+-)\n\n" +
        "Joystick 1: arrow keys + Right Ctrl (fire) when 'Arrow keys = joystick' is on,\n" +
        "  or the first USB joystick / gamepad (button 1 or 3 = fire, 2 or 4 = second fire).\n" +
        "Joystick 2: the second USB joystick.\n\n" +
        "F1 help   F2 SD card browser   F3 load .VZ   F4 power cycle   F5 reload program\n" +
        "F6 pause   F7 paste text   F8 mute   F9 warp   F10 visualiser   F11 / Alt+Enter fullscreen   F12 screenshot\n" +
        "Drop a .VZ file on the window to run it; drop a folder to mount it as the SD card.";

    void SyncMenu()
    {
        miVz200.Checked = m.Model == Model.VZ200; miVz300.Checked = m.Model == Model.VZ300;
        miExpNone.Checked = m.Exp == MemExp.None; miExp16.Checked = m.Exp == MemExp.Ram16K; miExpBv.Checked = m.Exp == MemExp.BennVenn;
        miGfxNone.Checked = m.Gfx == GfxMod.None; miGfxAus.Checked = m.Gfx == GfxMod.Australian; miGfxGer.Checked = m.Gfx == GfxMod.German;
        miJoyIf.Checked = m.JoyInterface;
        miVzdos.Checked = m.BootVzdos;
        miVzdos.Enabled = m.Exp == MemExp.BennVenn;
        miWriteBack.Checked = m.SdWriteBack;
        miWriteBack.Enabled = m.Exp == MemExp.BennVenn;
        for (int i = 1; i <= 5; i++) miScale[i].Checked = scale == i && !fullscreen;
        miVis.Checked = visOn;
        miInteger.Checked = integerScale; miFull.Checked = fullscreen; miBorder.Checked = showBorder; miMono.Checked = m.Mono;
        miSnow.Checked = m.ShowSnow; miStatus.Checked = status.Visible;
        miArrowsJoy.Checked = arrowsJoy; miArrowsCursor.Checked = !arrowsJoy; miSwap.Checked = swapJoy;
        miPause.Checked = paused; miWarp.Checked = warp; miMute.Checked = muted;
        miJoyList.Text = "PC joysticks found: " + (Joysticks.Count == 0 ? "none" : string.Join(", ", Joysticks.Names));
    }

    void Reconfigure(Action change)
    {
        cmds.Enqueue(() =>
        {
            change();
            if (sessionProgram && lastProgram != null && File.Exists(lastProgram)) LaunchNow(lastProgram);
            else PowerOnNow();
            ShowMessage(ConfigText());
        });
    }

    /// <summary>Power cycle (emulation thread). With the BennVenn, a ROM and a VZDOS.VZ this boots the real DOS.</summary>
    void PowerOnNow()
    {
        sessionProgram = false;
        m.PowerOn();
        if (!m.HasRom) ShowMessage("Power on: no ROM - press F2");
        else if (m.VzdosFile != null) ShowMessage("Power on: BennVenn booting " + Path.GetFileName(m.VzdosFile) + " from " + Path.GetFileName(Path.GetDirectoryName(m.VzdosFile)) + "\\");
        else ShowMessage("Power on: " + m.RomName + (m.Exp == MemExp.BennVenn && m.BootVzdos ? " (no VZDOS.VZ on the SD card or in roms)" : ""));
        BeginInvoke((Action)(() => Text = "VZonPC"));
    }

    /// <summary>Mounts a folder as the SD card. If the real VZDOS is running, the machine restarts, as after swapping cards.</summary>
    void MountSd(string dir)
    {
        cmds.Enqueue(() =>
        {
            m.SdDir = dir;
            if (m.RealDos) PowerOnNow();
            ShowMessage("SD card: " + dir);
        });
    }

    string ConfigText()
    {
        string s = m.Model == Model.VZ300 ? "VZ300" : "VZ200";
        if (m.Exp == MemExp.BennVenn) s += " + BennVenn SD 128K" + (m.RealDos ? " (VZDOS)" : ""); else if (m.Exp == MemExp.Ram16K) s += " + 16K";
        if (m.Gfx == GfxMod.Australian) s += " + Aus hi-res"; else if (m.Gfx == GfxMod.German) s += " + German hi-res";
        return s;
    }

    // ------------------------------------------------------------------ loading
    void Launch(string path) { cmds.Enqueue(() => LaunchNow(path)); }

    void LaunchNow(string path)
    {
        try
        {
            typeQueue.Clear(); typing = null;
            bool basic = m.Launch(path);
            vis.FindSymbols(path);
            if (basic && m.HasRom) TypeString("RUN\r");
            lastProgram = path; sessionProgram = true;
            string name = Path.GetFileName(path);
            BeginInvoke((Action)(() => Text = "VZonPC - " + name));
            ShowMessage("Loaded " + name + (basic && !m.HasRom ? " - BASIC program needs the VZ ROM" : ""));
        }
        catch (Exception ex) { ShowMessage("Can't load " + Path.GetFileName(path) + ": " + ex.Message); }
    }

    void OpenSdBrowser()
    {
        bool wasPaused = paused; paused = true;
        using (var b = new SdBrowser(m.SdDir))
        {
            if (b.ShowDialog(this) == DialogResult.OK)
            {
                if (b.RootChanged && b.Selected == null) MountSd(b.Root);
                else if (b.RootChanged) m.SdDir = b.Root;
                if (b.Selected != null) Launch(b.Selected);
            }
        }
        paused = wasPaused;
    }

    ToolStripMenuItem miTapeRight, miTapeInvert;
    bool tapeRight, tapeInvert;

    /// <summary>Plays an audio file into the cassette input from now (type CLOAD or CRUN first, as on the real VZ).</summary>
    void OpenTapeDialog()
    {
        using (var d = new OpenFileDialog { Filter = "Audio (*.wav;*.flac;*.mp3)|*.wav;*.flac;*.mp3|All files|*.*" })
        {
            if (d.ShowDialog(this) != DialogResult.OK) return;
            try
            {
                var t = VzTape.Load(d.FileName, tapeRight ? 1 : 0);
                t.Invert = tapeInvert;
                cmds.Enqueue(() => m.PlayTape(t));
                ShowMessage("Tape: " + t.Name + " (" + (int)(t.Seconds / 60) + ":" + ((int)t.Seconds % 60).ToString("00") + ")");
            }
            catch (Exception ex) { MessageBox.Show(this, ex.Message, "Play tape", MessageBoxButtons.OK, MessageBoxIcon.Warning); }
        }
    }

    void OpenVzDialog()
    {
        using (var d = new OpenFileDialog { Filter = "VZ programs (*.vz)|*.vz|All files|*.*", InitialDirectory = m.SdDir })
            if (d.ShowDialog(this) == DialogResult.OK) Launch(d.FileName);
    }

    void ChooseSdFolder()
    {
        using (var d = new FolderBrowserDialog { Description = "Choose the folder to use as the VZ's SD card", SelectedPath = m.SdDir })
            if (d.ShowDialog(this) == DialogResult.OK) MountSd(d.SelectedPath);
    }

    void OnDrop(object sender, DragEventArgs e)
    {
        var files = (string[])e.Data.GetData(DataFormats.FileDrop);
        if (files == null || files.Length == 0) return;
        if (Directory.Exists(files[0])) MountSd(files[0]);
        else Launch(files[0]);
    }

    void PasteText()
    {
        if (!Clipboard.ContainsText()) { ShowMessage("Clipboard has no text"); return; }
        string t = Clipboard.GetText().Replace("\r\n", "\r").Replace('\n', '\r');
        cmds.Enqueue(() => TypeString(t));
    }

    void TypeString(string s) { foreach (char c in s) { var k = VzMachine.CharKeys(c); if (k != null) typeQueue.Enqueue(k); } }

    void Screenshot()
    {
        int[] px; int w, h;
        lock (frameLock) { px = (int[])frame.Clone(); w = frameW; h = frameH; }
        string dir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "screenshots");
        Directory.CreateDirectory(dir);
        string name = (lastProgram != null ? Path.GetFileNameWithoutExtension(lastProgram) : "VZ") + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".png";
        string fn = Path.Combine(dir, name);
        Headless.SavePng(fn, px, w, h, 2);
        ShowMessage("Saved screenshots\\" + name);
    }

    // ------------------------------------------------------------------ display
    void ApplyScale()
    {
        if (fullscreen) return;
        int w = showBorder ? VzMachine.FBW : 256, h = showBorder ? VzMachine.FBH : 192;
        if (WindowState == FormWindowState.Maximized) WindowState = FormWindowState.Normal;
        ClientSize = new Size(w * scale, h * scale + (menu.Visible ? menu.Height : 0) + (status.Visible ? status.Height : 0));
        BlitLatest();
    }

    void ToggleFullscreen()
    {
        fullscreen = !fullscreen;
        if (fullscreen)
        {
            savedBounds = Bounds; savedState = WindowState;
            menu.Visible = false; status.Visible = false;
            FormBorderStyle = FormBorderStyle.None;
            WindowState = FormWindowState.Normal;
            Bounds = Screen.FromControl(this).Bounds;
            Cursor.Hide();
        }
        else
        {
            FormBorderStyle = FormBorderStyle.Sizable;
            menu.Visible = true; status.Visible = true;
            Bounds = savedBounds; WindowState = savedState;
            Cursor.Show();
        }
        UpdateVisWindow();
        BlitLatest();
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == (Keys.Alt | Keys.Enter)) { ToggleFullscreen(); return true; }
        if (keyData == Keys.F10) { ToggleVis(); return true; }
        if (keyData == Keys.Menu || keyData == (Keys.Alt | Keys.Menu)) return true;  // no menu activation by Alt / F10
        return base.ProcessCmdKey(ref msg, keyData);
    }

    // swallow keys so Windows doesn't beep or move focus
    protected override void OnKeyDown(KeyEventArgs e) { e.Handled = true; e.SuppressKeyPress = true; }

    void BlitLatest()
    {
        if (displayHwnd == IntPtr.Zero) return;
        int[] px; int w, h;
        lock (frameLock)
        {
            px = frame; w = frameW; h = frameH;
            Present(px, w, h);
        }
    }

    void Present(int[] px, int w, int h)
    {
        int cw = dispW, ch = dispH;
        if (cw <= 0 || ch <= 0) return;
        if (fullscreen && visOn) { PresentWithSidebars(px, w, h, cw, ch); return; }
        PresentVisWindow();
        int dw, dh;
        if (integerScale)
        {
            int s = Math.Max(1, Math.Min(cw / w, ch / h));
            dw = w * s; dh = h * s;
        }
        else
        {
            double s = Math.Min((double)cw / w, (double)ch / h);
            dw = (int)(w * s); dh = (int)(h * s);
        }
        Native.Blit(displayHwnd, px, w, h, cw, ch, (cw - dw) / 2, (ch - dh) / 2, dw, dh);
    }

    void PresentWithSidebars(int[] px, int w, int h, int cw, int ch)
    {
        // the picture keeps whole-pixel scaling and leaves at least 320 px either side for the panels if it can
        int s = Math.Min((cw - 2 * VzVis.W) / w, ch / h);
        if (s < 1) s = Math.Max(1, Math.Min(cw / 2 / w, ch / h));
        int dw = w * s, dh = h * s;
        int side = (cw - dw) / 2;
        var parts = new List<Native.Part>();
        parts.Add(new Native.Part { Px = px, W = w, H = h, X = side, Y = (ch - dh) / 2, DW = dw, DH = dh });
        double k = Math.Min((double)side / VzVis.W, (double)ch / VzVis.H);
        if (k >= 2) k = Math.Floor(k); else if (k > 1) k = 1;
        int pw = (int)(VzVis.W * k), ph = (int)(VzVis.H * k);
        int py = (ch - ph) / 2;
        parts.Add(new Native.Part { Px = vis.Left, W = VzVis.W, H = VzVis.H, X = (side - pw) / 2, Y = py, DW = pw, DH = ph });
        parts.Add(new Native.Part { Px = vis.Right, W = VzVis.W, H = VzVis.H, X = side + dw + (cw - side - dw - pw) / 2, Y = py, DW = pw, DH = ph });
        Native.BlitParts(displayHwnd, cw, ch, parts);
    }

    void PresentVisWindow()
    {
        IntPtr hw = visHwnd; int cw = visW, ch = visH;
        if (hw == IntPtr.Zero || cw <= 0 || ch <= 0 || fullscreen) return;
        double k = Math.Min((double)cw / (2 * VzVis.W), (double)ch / VzVis.H);
        if (k >= 2) k = Math.Floor(k); else if (k > 1) k = 1;
        int pw = (int)(VzVis.W * k), ph = (int)(VzVis.H * k);
        int x0 = (cw - 2 * pw) / 2;
        var parts = new List<Native.Part>();
        parts.Add(new Native.Part { Px = vis.Left, W = VzVis.W, H = VzVis.H, X = x0, Y = 0, DW = pw, DH = ph });
        parts.Add(new Native.Part { Px = vis.Right, W = VzVis.W, H = VzVis.H, X = x0 + pw, Y = 0, DW = pw, DH = ph });
        Native.BlitParts(hw, cw, ch, parts);
    }

    void ToggleVis()
    {
        visOn = !visOn;
        bool on = visOn;
        cmds.Enqueue(() =>
        {
            if (on) { if (m.Tr == null) m.Tr = new VzTrace(m); vis.T = m.Tr; if (vis.Sym.Count == 0 && lastProgram != null) vis.FindSymbols(lastProgram); }
            else { m.Tr = null; vis.T = null; }
        });
        if (on) ShowMessage("Visualiser on (F10 to close)");
        UpdateVisWindow();
        BlitLatest();
    }

    void UpdateVisWindow()
    {
        bool want = visOn && !fullscreen;
        if (want && visForm == null)
        {
            var f = new VisForm(this);
            var wa = Screen.FromControl(this).WorkingArea;
            int ch = Math.Min(VzVis.H, wa.Height - 40);
            int cw = (int)Math.Round(2.0 * VzVis.W * ch / VzVis.H);
            f.ClientSize = new Size(cw, ch);
            f.StartPosition = FormStartPosition.Manual;
            int x = Right + 4; if (x + f.Width > wa.Right) x = Math.Max(wa.Left, wa.Right - f.Width);
            int extra = f.Height - f.ClientSize.Height;
            if (f.Height > wa.Height) { ch = wa.Height - extra; cw = (int)Math.Round(2.0 * VzVis.W * ch / VzVis.H); f.ClientSize = new Size(cw, ch); }
            f.Location = new Point(x, wa.Top);
            f.Panel.Resize += (s, e) => { visW = f.Panel.ClientSize.Width; visH = f.Panel.ClientSize.Height; };
            f.Panel.Repaint = () => { lock (frameLock) PresentVisWindow(); };
            f.FormClosed += (s, e) =>
            {
                if (visForm != f) return;
                visHwnd = IntPtr.Zero; visForm = null;
                if (!fullscreen && visOn) { visOn = false; cmds.Enqueue(() => { m.Tr = null; vis.T = null; }); }
            };
            visForm = f;
            f.Show(this);
            visW = f.Panel.ClientSize.Width; visH = f.Panel.ClientSize.Height;
            visHwnd = f.Panel.Handle;
            Activate();
        }
        else if (!want && visForm != null)
        {
            var f = visForm; visHwnd = IntPtr.Zero; visForm = null; f.Close();
        }
    }

    void ShowMessage(string s) { message = s; messageFrames = 150; }

    void UpdateStatus()
    {
        string sd = m.SdDir;
        if (sd.Length > 50) sd = "..." + sd.Substring(sd.Length - 47);
        stLeft.Text = messageFrames > 0 ? message : ConfigText() + (m.HasRom ? "" : " (no ROM)") + "   SD: " + sd;
        string tape = "";
        var tp = m.Tape;
        if (tp != null && tp.Playing) { double p = tp.Position(m.Cpu.Cyc); tape = "TAPE " + (int)(p / 60) + ":" + ((int)p % 60).ToString("00") + "  "; }
        stRight.Text = tape + (paused ? "PAUSED  " : "") + (warp ? "WARP  " : "") + (muted ? "MUTE  " : "") + fps.ToString("0") + " fps";
    }

    // ------------------------------------------------------------------ input
    static readonly int[] letterVk = new int[36];
    static readonly string[] letterKey = new string[36];
    static MainForm()
    {
        for (int i = 0; i < 26; i++) { letterVk[i] = 'A' + i; letterKey[i] = ((char)('A' + i)).ToString(); }
        for (int i = 0; i < 10; i++) { letterVk[26 + i] = '0' + i; letterKey[26 + i] = ((char)('0' + i)).ToString(); }
    }

    void PollInput()
    {
        for (int i = 0; i < 8; i++) m.Keys[i] = 0x3F;
        int j1 = 0xFF, j1a = 0xFF, j2 = 0xFF, j2a = 0xFF;
        bool focused = Native.GetForegroundWindow() == formHwnd;
        if (focused)
        {
            for (int i = 0; i < 36; i++) if (Native.KeyDown(letterVk[i])) m.SetKey(letterKey[i], true);
            if (Native.KeyDown(0x20)) m.SetKey("SPACE", true);
            if (Native.KeyDown(0x0D)) m.SetKey("RETURN", true);
            if (Native.KeyDown(0xA0) || Native.KeyDown(0xA1)) m.SetKey("SHIFT", true);
            if (Native.KeyDown(0xA2) || (!arrowsJoy && Native.KeyDown(0xA3))) m.SetKey("CTRL", true);
            if (Native.KeyDown(0xBC)) m.SetKey(",", true);
            if (Native.KeyDown(0xBE)) m.SetKey(".", true);
            if (Native.KeyDown(0xBD)) m.SetKey("-", true);
            if (Native.KeyDown(0xBA)) m.SetKey(";", true);
            if (Native.KeyDown(0xDE)) m.SetKey(":", true);
            if (Native.KeyDown(0xBB)) { m.SetKey("SHIFT", true); m.SetKey("-", true); }        // =
            if (Native.KeyDown(0x08)) { m.SetKey("CTRL", true); m.SetKey(";", true); }        // backspace = rubout
            if (Native.KeyDown(0x2D)) { m.SetKey("CTRL", true); m.SetKey("L", true); }        // insert
            if (Native.KeyDown(0x1B)) { m.SetKey("CTRL", true); m.SetKey("-", true); }        // esc = break
            bool up = Native.KeyDown(0x26), dn = Native.KeyDown(0x28), lf = Native.KeyDown(0x25), rt = Native.KeyDown(0x27);
            if (arrowsJoy)
            {
                if (up) j1 &= ~1; if (dn) j1 &= ~2; if (lf) j1 &= ~4; if (rt) j1 &= ~8;
                if (Native.KeyDown(0xA3)) j1 &= ~16;
            }
            else
            {
                if (lf) { m.SetKey("CTRL", true); m.SetKey("M", true); }
                if (rt) { m.SetKey("CTRL", true); m.SetKey(",", true); }
                if (up) { m.SetKey("CTRL", true); m.SetKey(".", true); }
                if (dn) { m.SetKey("CTRL", true); m.SetKey("SPACE", true); }
            }
        }
        int b, a;
        Joysticks.Read(0, out b, out a); if (swapJoy) { j2 &= b; j2a &= a; } else { j1 &= b; j1a &= a; }
        Joysticks.Read(1, out b, out a); if (swapJoy) { j1 &= b; j1a &= a; } else { j2 &= b; j2a &= a; }
        m.Joy[0] = j1; m.Joy[1] = j1a; m.Joy[2] = j2; m.Joy[3] = j2a;

        // auto-typing (paste, RUN)
        if (typeHold > 0) typeHold--;
        else if (typing == null && typeQueue.Count > 0) { typing = typeQueue.Dequeue(); typePhase = 0; }
        if (typing != null)
        {
            if (typePhase < 3) foreach (var k in typing) m.SetKey(k, true);
            if (++typePhase >= 6) typing = null;
        }
    }

    // ------------------------------------------------------------------ emulation thread
    void EmuLoop()
    {
        Native.timeBeginPeriod(1);
        WaveOut wave = null;
        try { wave = new WaveOut(VzMachine.RATE); } catch { wave = null; }
        var sw = Stopwatch.StartNew();
        double nextT = 0; int fpsFrames = 0; double fpsT = 0;
        try
        {
            while (running)
            {
                Action c;
                while (cmds.TryDequeue(out c)) { try { c(); } catch (Exception ex) { ShowMessage(ex.Message); } }
                if (messageFrames > 0) messageFrames--;
                if (paused) { Thread.Sleep(20); nextT = sw.Elapsed.TotalMilliseconds; BlitLatest(); continue; }

                PollInput();
                if (pendingTape != null && typeQueue.Count == 0 && typing == null && typeHold == 0 && --pendingTapeDelay <= 0) { m.PlayTape(pendingTape); pendingTape = null; }
                m.AudioOn = !warp && wave != null && wave.Ok;
                m.RunFrame();
                if (vis.T != null && visOn) vis.Render();

                int w, h; int[] px = m.Snapshot(showBorder, out w, out h);
                lock (frameLock) { frame = px; frameW = w; frameH = h; Present(px, w, h); }

                fpsFrames++;
                double now = sw.Elapsed.TotalMilliseconds;
                if (now - fpsT >= 1000) { fps = fpsFrames * 1000.0 / (now - fpsT); fpsFrames = 0; fpsT = now; }

                if (warp) { nextT = now; continue; }
                double frameMs = 1000.0 * VzMachine.FRAMET / m.Clock;
                if (m.AudioOn)
                {
                    if (muted) for (int i = 0; i < m.AudioN; i++) m.Audio[i] = 0;
                    wave.Write(m.Audio, m.AudioN);
                    // the sound card sets the pace: keep ~3 frames queued
                    int guard = 0;
                    while (running && wave.Queued > 3 && guard++ < 100) Thread.Sleep(1);
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
        }
        finally
        {
            if (wave != null) wave.Dispose();
            Native.timeEndPeriod(1);
        }
    }

    // ------------------------------------------------------------------ settings
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
                    case "graphics": m.Gfx = (GfxMod)Enum.Parse(typeof(GfxMod), v); break;
                    case "joyinterface": m.JoyInterface = v == "1"; break;
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
            catch { }
        }
    }

    void SaveSettings()
    {
        try
        {
            File.WriteAllLines(iniPath, new[] {
                "machine=" + m.Model, "expansion=" + m.Exp, "graphics=" + m.Gfx, "joyinterface=" + (m.JoyInterface ? 1 : 0), "bootvzdos=" + (m.BootVzdos ? 1 : 0), "sdwriteback=" + (m.SdWriteBack ? 1 : 0),
                "sd=" + m.SdDir, "scale=" + scale, "integerscale=" + (integerScale ? 1 : 0), "border=" + (showBorder ? 1 : 0),
                "fullscreen=" + (fullscreen ? 1 : 0), "mono=" + (m.Mono ? 1 : 0), "snow=" + (m.ShowSnow ? 1 : 0),
                "arrowsjoystick=" + (arrowsJoy ? 1 : 0), "swapjoysticks=" + (swapJoy ? 1 : 0), "muted=" + (muted ? 1 : 0), "visualiser=" + (visOn ? 1 : 0),
                "lastprogram=" + (lastProgram ?? "") });
        }
        catch { }
    }
}

/// <summary>The visualiser's own window (used when the emulator isn't fullscreen).</summary>
sealed class VisForm : Form
{
    public readonly DisplayPanel Panel = new DisplayPanel();
    public VisForm(Form owner)
    {
        Text = "VZonPC visualiser";
        try { Icon = owner.Icon; } catch { }
        Panel.Dock = DockStyle.Fill;
        Controls.Add(Panel);
        KeyPreview = true;
        KeyDown += (s, e) => { if (e.KeyCode == Keys.F10 || e.KeyCode == Keys.Escape) Close(); };
    }
}
