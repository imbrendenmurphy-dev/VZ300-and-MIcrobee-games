// VZonPC - the Dick Smith VZ-200/300 RS-232 interface (K-6317).
// Memory map after MAME (devices/bus/vtech/memexp/rs232.cpp):
//   $4000-$47FF  2K ROM (roms\rs232_v15.ic2 or rs232_v16.ic2): a terminal program
//   $5000-$57FF  read: bit 7 = RXD (1 = mark, the idle state)
//   $5800-$5FFF  write: bit 7 = TXD, inverted (writing 0 sends mark)
// The ROM does the serial timing itself, bit by bit. Here a software UART turns its TXD line back into bytes
// and turns incoming bytes into an RXD waveform at the same speed, so the VZ can talk to a TCP host (a telnet
// BBS), a real COM port, a text file, or itself (loopback).
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Sockets;
using System.Text;

public sealed class VzRs232
{
    readonly VzMachine m;
    public byte[] Rom; public string RomName;

    // line format (set by the ROM's menu; read from its settings when they are known)
    public int Baud = 300, DataBits = 8, StopBits = 1; public char Parity = 'N';
    public bool TxInvert = true;        // MAME: TXD = NOT bit 7
    public bool Loopback;
    public long TxBytes, RxBytes, TxChanges, RxReads;

    public VzRs232(VzMachine machine) { m = machine; }

    public void LoadRom(string dir)
    {
        Rom = null; RomName = null;
        foreach (var n in new[] { "rs232_v16.ic2", "rs232_v15.ic2", "rs232.rom", "vzrs232.rom" })
        {
            string p = Portable.Find(dir, n);
            if (File.Exists(p) && new FileInfo(p).Length == 0x800) { Rom = File.ReadAllBytes(p); RomName = n; return; }
        }
    }

    public void Reset() { txMark = true; txBusy = false; rxBusy = false; }

    /// <summary>The ROM keeps its settings as characters in its menu text in RAM ($8031 data bits, $8049 stop bits,
    /// $8061 parity N/E/O) and its send and receive routines read them from there, so the UART follows them.</summary>
    public bool FollowRom = true;
    void SyncFormat()
    {
        if (!FollowRom || Rom == null) return;
        int d = m.Peek(0x8031) - '0', s = m.Peek(0x8049) - '0', p = m.Peek(0x8061);
        if (d >= 5 && d <= 8) DataBits = d;
        if (s == 1 || s == 2) StopBits = s;
        if (p == 'N' || p == 'E' || p == 'O') Parity = (char)p;
    }

    double BitT { get { return (double)m.Clock / Baud; } }
    int FrameBits { get { return 1 + DataBits + (Parity == 'N' ? 0 : 1) + StopBits; } }

    public int Read(int a, long cyc)
    {
        if (a < 0x4800) return Rom != null ? Rom[a - 0x4000] : 0xFF;
        if (a >= 0x5000 && a < 0x5800) { RxReads++; return 0x7F | (RxLevel(cyc) ? 0x80 : 0); }
        return 0xFF;
    }

    public void Write(int a, int v, long cyc)
    {
        if (a < 0x5800 || a >= 0x6000) return;
        bool mk = ((v & 0x80) == 0) == TxInvert;
        if (mk == txMark) return;
        TxChanges++;
        TxEdge(cyc, mk);
    }

    // ---------------------------------------------------------------- transmit: TXD edges -> bytes
    bool txMark = true, txBusy; long txStart; readonly List<long> txT = new List<long>(); readonly List<bool> txL = new List<bool>();
    public bool TxMark { get { return txMark; } }

    void TxEdge(long cyc, bool mk)
    {
        TxPoll(cyc);
        if (!txBusy && !mk) { SyncFormat(); txBusy = true; txStart = cyc; txT.Clear(); txL.Clear(); }
        if (txBusy) { txT.Add(cyc); txL.Add(mk); }
        txMark = mk;
    }

    bool TxLevelAt(double t)
    {
        bool l = true;
        for (int i = 0; i < txT.Count && txT[i] <= t; i++) l = txL[i];
        return l;
    }

    /// <summary>Finishes a byte once the line has been sampled past its last data (or parity) bit.</summary>
    public void TxPoll(long now)
    {
        if (!txBusy) return;
        double bt = BitT;
        int dataEnd = 1 + DataBits + (Parity == 'N' ? 0 : 1);
        if (now < txStart + (dataEnd + 0.5) * bt) return;
        int b = 0;
        for (int i = 0; i < DataBits; i++) if (TxLevelAt(txStart + (1.5 + i) * bt)) b |= 1 << i;
        txBusy = false;
        TxBytes++;
        Sent((byte)b);
    }

    void Sent(byte b)
    {
        Log(b, true);
        if (Loopback) lock (rxq) rxq.Enqueue(b);
        try
        {
            if (ns != null) ns.Write(new[] { b }, 0, 1);
            if (sp != null && sp.IsOpen) sp.Write(new[] { b }, 0, 1);
            if (capture != null) { capture.WriteByte(b); capture.Flush(); }
        }
        catch (Exception ex) { LinkError = ex.Message; Disconnect(); }
    }

    // ---------------------------------------------------------------- receive: bytes -> RXD waveform
    readonly Queue<byte> rxq = new Queue<byte>();
    bool rxBusy; long rxStart; int rxByte;
    public int RxQueued { get { lock (rxq) return rxq.Count; } }

    public bool RxLevel(long cyc)
    {
        if (rxBusy)
        {
            int bit = (int)((cyc - rxStart) / BitT);
            if (bit >= FrameBits) rxBusy = false;
            else
            {
                if (bit == 0) return false;                           // start bit
                if (bit <= DataBits) return ((rxByte >> (bit - 1)) & 1) != 0;
                if (Parity != 'N' && bit == DataBits + 1)
                {
                    int ones = 0; for (int i = 0; i < DataBits; i++) ones += (rxByte >> i) & 1;
                    return Parity == 'E' ? (ones & 1) != 0 : Parity == 'O' ? (ones & 1) == 0 : Parity == 'M';
                }
                return true;                                         // stop bits
            }
        }
        lock (rxq)
        {
            if (rxq.Count == 0) return true;
            rxByte = rxq.Dequeue();
        }
        // the next byte starts now: the line drops for its start bit
        SyncFormat();
        rxBusy = true; rxStart = cyc; RxBytes++;
        Log((byte)rxByte, false);
        return false;
    }

    /// <summary>Queues bytes to arrive on RXD (a text file, or typed text). A lone LF is sent as CR LF.</summary>
    public void Send(byte[] data)
    {
        lock (rxq)
            for (int i = 0; i < data.Length; i++)
            {
                byte b = data[i];
                if (b == 10 && (i == 0 || data[i - 1] != 13)) rxq.Enqueue(13);   // a lone LF (a PC text file) is CR LF
                rxq.Enqueue(b);
            }
    }
    public void ClearQueue() { lock (rxq) rxq.Clear(); }

    // ---------------------------------------------------------------- links: TCP, COM port, capture file
    TcpClient tcp; NetworkStream ns; ComLink sp; FileStream capture;
    public string LinkName, LinkError, CapturePath;
    readonly byte[] rbuf = new byte[4096];
    int telnet;   // telnet option negotiation state: 0 data, 1 after IAC, 2 option byte

    public bool Connected { get { return ns != null || (sp != null && sp.IsOpen); } }

    /// <summary>"host:port" for TCP (telnet), or "COM3" for a serial port.</summary>
    public void Connect(string target)
    {
        Disconnect(); LinkError = null;
        target = target.Trim();
        if (target.StartsWith("COM", StringComparison.OrdinalIgnoreCase) || target.StartsWith("/dev/"))
        {
            // a PC serial port: COM3 on Windows, /dev/ttyUSB0 on Linux
            try { sp = ComLink.Open(target, Baud, Parity, DataBits, StopBits, rxq); }
            catch (TypeLoadException) { throw new Exception("serial ports need Mono, or the System.IO.Ports package, on this .NET"); }
            catch (FileNotFoundException) { throw new Exception("serial ports need Mono, or the System.IO.Ports package, on this .NET"); }
        }
        else
        {
            int colon = target.LastIndexOf(':');
            string host = colon > 0 ? target.Substring(0, colon) : target;
            int port = colon > 0 ? int.Parse(target.Substring(colon + 1)) : 23;
            tcp = new TcpClient(); tcp.NoDelay = true;
            tcp.Connect(host, port);
            ns = tcp.GetStream(); telnet = 0;
            ns.BeginRead(rbuf, 0, rbuf.Length, OnTcp, ns);
        }
        LinkName = target;
    }

    void OnTcp(IAsyncResult ar)
    {
        var s = (NetworkStream)ar.AsyncState;
        int n;
        try { n = s.EndRead(ar); } catch (Exception) { n = 0; }
        if (n <= 0 || s != ns) { if (s == ns) { LinkError = "connection closed"; Disconnect(); } return; }
        var reply = new List<byte>();
        lock (rxq)
            for (int i = 0; i < n; i++)
            {
                byte b = rbuf[i];
                // telnet: answer option requests with "won't"/"don't", and pass the data through
                if (telnet == 0) { if (b == 255) telnet = 1; else rxq.Enqueue(b); }
                else if (telnet == 1)
                {
                    if (b == 255) { rxq.Enqueue(b); telnet = 0; }
                    else if (b >= 251 && b <= 254) { telnet = b; }
                    else telnet = 0;
                }
                else
                {
                    if (telnet == 253) reply.AddRange(new byte[] { 255, 252, b });       // DO -> WON'T
                    else if (telnet == 251) reply.AddRange(new byte[] { 255, 254, b });  // WILL -> DON'T
                    telnet = 0;
                }
            }
        try
        {
            if (reply.Count > 0) s.Write(reply.ToArray(), 0, reply.Count);
            s.BeginRead(rbuf, 0, rbuf.Length, OnTcp, s);
        }
        catch (Exception) { if (s == ns) { LinkError = "connection closed"; Disconnect(); } }
    }

    public void Disconnect()
    {
        var t = tcp; var p = sp;
        ns = null; tcp = null; sp = null; LinkName = null;
        try { if (t != null) t.Close(); } catch (Exception) { }
        try { if (p != null) p.Close(); } catch (Exception) { }
    }

    /// <summary>Writes every byte the VZ sends to a file (null stops).</summary>
    public void Capture(string path)
    {
        if (capture != null) { capture.Dispose(); capture = null; }
        CapturePath = path;
        if (path != null) capture = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.Read);
    }

    // ---------------------------------------------------------------- session log for the visualiser
    public readonly StringBuilder Session = new StringBuilder();
    public readonly List<int> SessionDir = new List<int>();   // per character: 1 sent, 0 received
    void Log(byte b, bool tx)
    {
        char c = b == 13 ? '\n' : b >= 32 && b < 127 ? (char)b : (char)0;
        if (c == 0) return;
        lock (Session)
        {
            Session.Append(c); SessionDir.Add(tx ? 1 : 0);
            if (Session.Length > 4000) { Session.Remove(0, 1000); SessionDir.RemoveRange(0, 1000); }
        }
    }
}

/// <summary>A PC serial port. It is a class of its own so that System.IO.Ports is loaded only when a port is used:
/// modern .NET on Linux doesn't include it, but Mono and .NET Framework do.</summary>
sealed class ComLink
{
    object sp;   // a SerialPort, kept as object so loading this class needs no System.IO.Ports

    // the factory keeps the SerialPort type out of the caller, so a missing System.IO.Ports fails here, catchably
    public static ComLink Open(string name, int baud, char parity, int dataBits, int stopBits, Queue<byte> rxq)
    {
        var c = new ComLink(); c.Init(name, baud, parity, dataBits, stopBits, rxq); return c;
    }
    void Init(string name, int baud, char parity, int dataBits, int stopBits, Queue<byte> rxq)
    {
        var p = new System.IO.Ports.SerialPort(name, baud, parity == 'E' ? System.IO.Ports.Parity.Even : parity == 'O' ? System.IO.Ports.Parity.Odd : System.IO.Ports.Parity.None,
            dataBits, stopBits == 2 ? System.IO.Ports.StopBits.Two : System.IO.Ports.StopBits.One);
        p.DataReceived += (s, e) =>
        {
            try { int n = p.BytesToRead; var b = new byte[n]; p.Read(b, 0, n); lock (rxq) foreach (var x in b) rxq.Enqueue(x); }
            catch (Exception) { }
        };
        p.Open();
        sp = p;
    }
    public bool IsOpen { get { return sp != null && ((System.IO.Ports.SerialPort)sp).IsOpen; } }
    public void Write(byte[] b, int o, int n) { ((System.IO.Ports.SerialPort)sp).Write(b, o, n); }
    public void Close() { if (sp != null) ((System.IO.Ports.SerialPort)sp).Close(); }
}
