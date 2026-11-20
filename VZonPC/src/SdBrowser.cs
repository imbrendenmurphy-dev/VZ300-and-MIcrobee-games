// VZonPC SD card browser: lists .VZ programs in the mounted folder (and its subfolders),
// the way the BennVenn loader's menu does.
using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

public sealed class SdBrowser : Form
{
    public string Root, Selected;
    public bool RootChanged;
    string cur;
    readonly ListBox list = new ListBox();
    readonly Label path = new Label();
    readonly Label info = new Label();

    public SdBrowser(string root)
    {
        Root = root; cur = root;
        Text = "SD card";
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(460, 440);
        MinimizeBox = false; MaximizeBox = false; ShowInTaskbar = false;
        KeyPreview = true;

        path.Dock = DockStyle.Top; path.Height = 22; path.TextAlign = ContentAlignment.MiddleLeft; path.AutoEllipsis = true;
        list.Dock = DockStyle.Fill; list.IntegralHeight = false;
        list.Font = new Font(FontFamily.GenericMonospace, 10f);
        list.DoubleClick += (s, e) => Choose();
        list.SelectedIndexChanged += (s, e) => ShowInfo();
        info.Dock = DockStyle.Bottom; info.Height = 22; info.TextAlign = ContentAlignment.MiddleLeft;

        var buttons = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 36, FlowDirection = FlowDirection.RightToLeft, Padding = new Padding(4) };
        var ok = new Button { Text = "Load", Width = 80 }; ok.Click += (s, e) => Choose();
        var cancel = new Button { Text = "Cancel", Width = 80, DialogResult = DialogResult.Cancel };
        var mount = new Button { Text = "Mount another folder...", Width = 160 };
        mount.Click += (s, e) =>
        {
            using (var d = new FolderBrowserDialog { SelectedPath = Root, Description = "Folder to use as the SD card" })
                if (d.ShowDialog(this) == DialogResult.OK) { Root = d.SelectedPath; cur = Root; RootChanged = true; Fill(); }
        };
        buttons.Controls.AddRange(new Control[] { cancel, ok, mount });
        CancelButton = cancel;

        Controls.Add(list); Controls.Add(info); Controls.Add(buttons); Controls.Add(path);
        KeyDown += (s, e) =>
        {
            if (e.KeyCode == Keys.Enter) { Choose(); e.Handled = true; }
            else if (e.KeyCode == Keys.Back) { Up(); e.Handled = true; }
        };
        Fill();
    }

    sealed class Entry
    {
        public string Path, Label; public bool Dir;
        public override string ToString() { return Label; }
    }

    void Fill()
    {
        list.Items.Clear();
        path.Text = " " + cur;
        if (!Directory.Exists(cur)) { info.Text = " Folder not found - use 'Mount another folder'"; return; }
        if (!string.Equals(Path.GetFullPath(cur).TrimEnd('\\'), Path.GetFullPath(Root).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
            list.Items.Add(new Entry { Path = Path.GetDirectoryName(cur), Label = "[..]", Dir = true });
        foreach (var d in Directory.GetDirectories(cur))
            list.Items.Add(new Entry { Path = d, Label = "[" + Path.GetFileName(d) + "]", Dir = true });
        int n = 0;
        foreach (var f in Directory.GetFiles(cur, "*.vz"))
        {
            list.Items.Add(new Entry { Path = f, Label = Path.GetFileName(f).ToUpperInvariant() });
            n++;
        }
        info.Text = " " + n + " program(s)";
        if (list.Items.Count > 0) list.SelectedIndex = 0;
    }

    void ShowInfo()
    {
        var e = list.SelectedItem as Entry;
        if (e == null || e.Dir) return;
        try
        {
            var d = new byte[24];
            using (var f = File.OpenRead(e.Path)) f.Read(d, 0, 24);
            long len = new FileInfo(e.Path).Length - 24;
            string name = System.Text.Encoding.ASCII.GetString(d, 4, 16).TrimEnd('\0', ' ');
            int start = d[22] | (d[23] << 8);
            info.Text = string.Format(" \"{0}\"  {1}  ${2:X4}-${3:X4}  ({4} bytes)", name, d[21] == 0xF0 ? "BASIC" : "machine code", start, start + len - 1, len);
        }
        catch { info.Text = ""; }
    }

    void Up() { if (!string.Equals(cur.TrimEnd('\\'), Root.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) { cur = Path.GetDirectoryName(cur); Fill(); } }

    void Choose()
    {
        var e = list.SelectedItem as Entry;
        if (e == null) return;
        if (e.Dir) { cur = e.Path; Fill(); return; }
        Selected = e.Path;
        DialogResult = DialogResult.OK;
        Close();
    }
}
