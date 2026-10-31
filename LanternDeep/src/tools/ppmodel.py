"""Microbee Premium Plus test model (not cycle exact).

* Memory: 32 blocks of 32K. 8000-FFFF is always block 0; 0000-7FFF is the
  block selected by port 50h: block = (b7 b6 b5 >> 3) | (b1 b0), with b1
  inverted when b2 (ROMs off) is set - as ubee512 models the 1MB Premium
  Plus. b3 = 1 removes the video window, b4 moves it from F000 to 8000.
  ROM (boot ROM bn60.rom) at 8000-BFFF while b2 = 0.
* Video window: F000-F7FF screen RAM, or attribute RAM when port 1Ch b4;
  F800-FFFF PCG bank (port 1Ch b0-3) or colour RAM when port 08h b6.
  Premium: screen code >= 80h selects PCG (bank = attribute b0-3).
* 6545: register file, status b7 update ready, b6 light pen (keyboard),
  b5 vertical blanking derived from the T-state count and R4/R6/R9.
* Keyboard: light-pen test via R18/R19 + R31 dummy write.
* PIO B b6 speaker (toggles logged with T-state for WAV export), PIO A
  joystick.
* FD2793 at 40h-47h + 48h (enough for the boot ROM and CP/M BIOS).
"""
import sys
from pathlib import Path
sys.path.insert(0, '/root/tools/z80')
import z80
import numpy as np

HERE = Path(__file__).resolve().parent
FRAME_T = 67500           # 3.375 MHz / 50 Hz
PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 192, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]
KEY = {c: i + 1 for i, c in enumerate('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}
KEY.update({str(d): 0x20 + d for d in range(10)})
KEY.update({'@': 0, 'ESC': 0x30, 'BS': 0x31, 'TAB': 0x32, 'LF': 0x33, 'RET': 0x34, 'LOCK': 0x35, 'BRK': 0x36,
            'SPACE': 0x37, 'UP': 0x38, 'CTRL': 0x39, 'DOWN': 0x3A, 'LEFT': 0x3B, 'RIGHT': 0x3E, 'SHIFT': 0x3F})


class PP:
    def __init__(self, rom=None, disk=None):
        self.m = z80.Z80Machine()
        self.mem = self.m.memory
        self.blocks = [bytearray(32768) for _ in range(32)]
        self.lower = None              # block currently copied into mem[0:8000]
        self.p50 = 0
        self.p1c = 0
        self.p08 = 0
        self.p0b = 0
        self.scr = bytearray(2048)
        self.attr = bytearray(2048)
        self.col = bytearray(2048)
        self.pcg = bytearray(16 * 2048)
        self.crtc = [0] * 32
        self.creg = 0
        self.keys = set()
        self.joy = 0xFF
        self.spk = 0
        self.spk_log = []              # (tick, level)
        self.frames = 0
        self.lp_pending = False
        self.lp_addr = 0
        self.port_log = []
        self.autoscan = True
        self.rom = (rom or b'') + b'\xff' * (16384 - len(rom or b''))
        self.disk = disk
        self.fdc_track = 0
        self.fdc_wbuf = bytearray()
        self.fdc_writes = []
        self.write_protect = False
        self.fdc_sector = 1
        self.fdc_side = 0
        self.fdc_data = 0
        self.fdc_buf = b''
        self.fdc_pos = 0
        self.fdc_cmd = 0
        self.fdc_idx = 0
        self.writes_rom = 0
        self.m.set_read_callback(self.read)
        self.m.set_write_callback(self.write)
        self.m.set_input_callback(self.inp)
        self.m.set_output_callback(self.out)
        self.marked = None
        self.set_p50(0)

    # ------------------------------------------------------------ time
    def ticks(self):
        return self.frames * 100000 + self.m.frame_tick

    # ------------------------------------------------------------ memory
    def block_of(self, v):
        b = ((v & 0xE0) >> 3) | (v & 3)
        if v & 4:
            b ^= 2
        return b

    def set_p50(self, v):
        nb = self.block_of(v)
        if self.lower is not None and nb != self.lower:
            if self.lower == 0:
                # block 0 in the lower window is the upper 32K's RAM
                self.mem[0x8000:0x10000] = self.mem[0:0x8000]
            else:
                self.blocks[self.lower][:] = self.mem[0:0x8000]
        if self.lower != nb:
            if nb == 0:
                self.mem[0:0x8000] = self.mem[0x8000:0x10000]
            else:
                self.mem[0:0x8000] = self.blocks[nb]
            self.lower = nb
        self.p50 = v
        # upper 32K is block 0, held natively in mem[8000:]; only the video
        # window and the boot ROM go through callbacks
        want = []
        if not (v & 8):
            want.append((0x8000, 0x1000) if v & 0x10 else (0xF000, 0x1000))
        if not (v & 4):
            want.append((0x8000, 0x8000))
        want = tuple(want)
        if want != self.marked:
            self.m.unmark_addrs(0x8000, 0x8000, self.m.READ_MARK | self.m.WRITE_MARK)
            for a, n in want:
                self.m.mark_addrs(a, n, self.m.READ_MARK | self.m.WRITE_MARK)
            self.marked = want

    def sync_lower(self):
        self.blocks[self.lower][:] = self.mem[0:0x8000]

    def video_at(self, a):
        if self.p50 & 8:
            return False
        base = 0x8000 if self.p50 & 0x10 else 0xF000
        return base <= a < base + 0x1000

    def vread(self, o):
        if o < 0x800:
            if self.p0b & 1:
                return 0  # character ROM read (not modelled)
            return self.attr[o] if (self.p1c & 0x90) == 0x90 else self.scr[o]
        o -= 0x800
        if self.p08 & 0x40:
            return self.col[o]
        return self.pcg[(self.p1c & 15) * 2048 + o]

    def vwrite(self, o, v):
        if o < 0x800:
            if self.p1c & 0x10:
                if self.p1c & 0x80:
                    self.attr[o] = v
            else:
                self.scr[o] = v
            return
        o -= 0x800
        if (self.p08 & 0x40) and not (self.p0b & 1):
            self.col[o] = v
        else:
            self.pcg[(self.p1c & 15) * 2048 + o] = v

    def read(self, a):
        if self.video_at(a):
            return self.vread(a & 0xFFF)
        if not (self.p50 & 4):
            # boot ROM at 8000-BFFF; nothing readable above it (as the
            # earlier Premium test model that boots this ROM)
            return self.rom[a - 0x8000] if a < 0xC000 else 0xFF
        return self.mem[a]

    def write(self, a, v):
        if self.video_at(a):
            self.vwrite(a & 0xFFF, v)
            return
        if not (self.p50 & 4):
            self.writes_rom += 1
            return
        self.mem[a] = v

    def peek(self, a):
        if a < 0x8000:
            return self.mem[a]
        return self.read(a)

    def peek_block(self, b, a):
        if b == 0:
            return self.mem[0x8000 + a]
        if b == self.lower:
            return self.mem[a]
        return self.blocks[b][a]

    # ------------------------------------------------------------ crtc
    def vblank(self):
        lines_row = (self.crtc[9] & 31) + 1
        rows = self.crtc[6] or 24
        total = ((self.crtc[4] or 38) + 1) * lines_row + (self.crtc[5] & 31)
        total = max(total, 1)
        line_t = FRAME_T / 312
        line = int((self.ticks() % FRAME_T) / line_t)
        return line >= rows * lines_row

    def inp(self, port):
        p = port & 0xFF
        if p == 0x0C:
            st = 0x80
            # the 6545 scans the keyboard while it displays (port 0Bh = 0):
            # a held key latches the light-pen register
            if not self.lp_pending and self.keys and not (self.p0b & 1) and self.autoscan:
                self.lp_pending = True
                self.lp_addr = min(self.keys) << 4
            if self.lp_pending:
                st |= 0x40
            if self.vblank():
                st |= 0x20
            return st
        if p == 0x0D:
            if self.creg in (16, 17):
                self.lp_pending = False
                return (self.lp_addr >> 8) & 0x3F if self.creg == 16 else self.lp_addr & 0xFF
            return self.crtc[self.creg]
        if p == 0x00:
            return self.joy
        if p == 0x09:
            return 0
        if p == 0x02:
            return 0xFF
        if p == 0x1C:
            return self.p1c
        if p == 0x08:
            return self.p08
        if 0x40 <= p <= 0x48:
            return self.fdc_in(p)
        return 0xFF

    def out(self, port, v):
        p = port & 0xFF
        if p == 0x50:
            self.set_p50(v)
        elif p == 0x1C:
            self.p1c = v
        elif p == 0x08:
            self.p08 = v
        elif p == 0x0B:
            self.p0b = v
        elif p == 0x0C:
            self.creg = v & 31
        elif p == 0x0D:
            self.crtc[self.creg] = v
            if self.creg == 31:
                addr = ((self.crtc[18] & 0x3F) << 8) | self.crtc[19]
                key = ((self.crtc[18] & 3) << 4) | (self.crtc[19] >> 4)
                if key in self.keys:
                    self.lp_pending = True
                    self.lp_addr = addr
        elif p == 0x02:
            b = 1 if v & 0x40 else 0
            if b != self.spk:
                self.spk = b
                self.spk_log.append((self.ticks(), b))
        elif 0x40 <= p <= 0x48:
            self.fdc_out(p, v)
        self.port_log.append((p, v)) if len(self.port_log) < 0 else None

    # ------------------------------------------------------------ fdc (boot ROM / CP/M BIOS level)
    def fdc_in(self, p):
        if 0x44 <= p <= 0x47:
            p -= 4
        if p == 0x40:
            if (self.fdc_cmd & 0xE0) == 0xA0:                   # write sector
                return 0x03 if len(self.fdc_wbuf) < 512 else (0x40 if self.write_protect else 0x00)
            if (self.fdc_cmd & 0xF0) == 0xC0 and self.fdc_pos >= 4:
                return 0
            if self.fdc_pos < len(self.fdc_buf):
                return 0x03
            if self.fdc_cmd < 0x80:
                # type I status: track 0 and a spinning disk's index pulse
                self.fdc_idx += 1
                return (0x04 if self.fdc_track == 0 else 0) | (0x02 if self.fdc_idx & 1 else 0)
            return 0x00
        if p == 0x41:
            return self.fdc_track
        if p == 0x42:
            return self.fdc_sector
        if p == 0x43:
            if self.fdc_pos >= len(self.fdc_buf):
                return 0
            a = self.fdc_buf[self.fdc_pos]
            self.fdc_pos += 1
            return a
        if p == 0x48:
            return 0x80
        return 0xFF

    def fdc_out(self, p, v):
        if 0x44 <= p <= 0x47:
            p -= 4
        if p == 0x41:
            self.fdc_track = v
        elif p == 0x42:
            self.fdc_sector = v
        elif p == 0x43:
            self.fdc_data = v
            if (self.fdc_cmd & 0xE0) == 0xA0 and len(self.fdc_wbuf) < 512:
                self.fdc_wbuf.append(v)
                if len(self.fdc_wbuf) == 512 and not self.write_protect:
                    s = self.fdc_sector - 21 if self.fdc_sector >= 21 else self.fdc_sector - 1
                    o = (self.fdc_track * 2 + self.fdc_side) * 5120 + s * 512
                    d = bytearray(self.disk)
                    d[o:o + 512] = self.fdc_wbuf
                    self.disk = bytes(d)
                    self.fdc_writes.append((self.fdc_track, self.fdc_side, self.fdc_sector))
        elif p == 0x48:
            self.fdc_side = (v >> 2) & 1
        elif p == 0x40:
            self.fdc_cmd = v
            self.fdc_buf = b''
            self.fdc_pos = 0
            self.fdc_wbuf = bytearray()
            if (v & 0xF0) == 0:
                self.fdc_track = 0
            elif (v & 0xF0) == 0x10:
                self.fdc_track = self.fdc_data
            elif (v & 0xE0) == 0x40:
                self.fdc_track = min(79, self.fdc_track + 1)
            elif (v & 0xE0) == 0x60:
                self.fdc_track = max(0, self.fdc_track - 1)
            elif (v & 0xE0) == 0x80:
                s = self.fdc_sector - 21 if self.fdc_sector >= 21 else self.fdc_sector - 1
                o = (self.fdc_track * 2 + self.fdc_side) * 5120 + s * 512
                length = (10 - s) * 512 if v & 16 else 512
                self.fdc_buf = self.disk[o:o + length]
            elif (v & 0xF0) == 0xC0:
                self.fdc_buf = bytes([self.fdc_track, 0, 1 if self.fdc_track < 2 else 21, 2, 0, 0])

    # ------------------------------------------------------------ running
    def run_frames(self, n=1):
        for _ in range(n):
            target = self.ticks() + FRAME_T
            while self.ticks() < target:
                self.m.ticks_to_stop = max(1, target - self.ticks())
                ev = self.m.run()
                if ev & z80.Z80Machine._END_OF_FRAME:
                    self.frames += 1
                if ev & z80.Z80Machine._BREAKPOINT_HIT:
                    return self.m.pc
        return None

    def run_until(self, pc, max_frames=50):
        self.m.set_breakpoint(pc)
        hit = None
        limit = self.ticks() + max_frames * FRAME_T
        while self.ticks() < limit:
            self.m.ticks_to_stop = max(1, min(FRAME_T, limit - self.ticks()))
            ev = self.m.run()
            if ev & z80.Z80Machine._END_OF_FRAME:
                self.frames += 1
            if ev & z80.Z80Machine._BREAKPOINT_HIT:
                hit = self.m.pc
                break
        self.m.clear_breakpoint(pc)
        return hit

    # ------------------------------------------------------------ pictures and sound
    def text(self):
        cols = self.crtc[1] or 64
        rows = self.crtc[6] or 16
        out = []
        for r in range(rows):
            line = ''
            for c in range(cols):
                ch = self.scr[(r * cols + c) & 0x7FF]
                line += chr(ch) if 32 <= ch < 127 else ' '
            out.append(line.rstrip())
        return '\n'.join(out)

    def screen_rgb(self, mono=False):
        cols = self.crtc[1] or 80
        rows = self.crtc[6] or 24
        lines = (self.crtc[9] & 31) + 1
        start = ((self.crtc[12] & 0x3F) << 8) | self.crtc[13]
        img = np.zeros((rows * lines, cols * 8, 3), dtype=np.uint8)
        pal = np.array(PALETTE, dtype=np.uint8)
        for r in range(rows):
            for c in range(cols):
                a = (start + r * cols + c) & 0x7FF
                ch = self.scr[a]
                co = self.col[a]
                fg, bg = co & 15, co >> 4
                if ch & 0x80 and self.p1c & 0x80:
                    base = (self.attr[a] & 15) * 2048 + (ch & 0x7F) * 16
                    rowsb = self.pcg[base:base + lines]
                else:
                    rowsb = bytes(lines)      # character ROM not modelled
                for y in range(lines):
                    b = rowsb[y] if y < len(rowsb) else 0
                    bits = np.array([(b >> (7 - x)) & 1 for x in range(8)])
                    if mono:          # a monochrome monitor: pixels lit whatever the colour
                        img[r * lines + y, c * 8:c * 8 + 8] = np.where(bits[:, None] == 1, (255, 170, 0), (0, 0, 0))
                    else:
                        img[r * lines + y, c * 8:c * 8 + 8] = np.where(bits[:, None] == 1, pal[fg], pal[bg])
        return img

    def save_png(self, path, scale=2):
        from PIL import Image
        img = self.screen_rgb()
        im = Image.fromarray(img)
        im = im.resize((im.width * scale // 2 * 2 // 2 * 1 if False else im.width * scale // 1, im.height * scale * 2 // 1), Image.NEAREST) if False else im.resize((im.width * scale, im.height * scale * 2), Image.NEAREST)
        im.save(path)

    def save_wav(self, path, t0=0, t1=None, rate=22050):
        import wave
        log = [e for e in self.spk_log if e[0] >= t0 and (t1 is None or e[0] < t1)]
        t1 = t1 or self.ticks()
        n = int((t1 - t0) / 3375000 * rate)
        buf = np.zeros(n, dtype=np.int16)
        level = 0
        idx = 0
        prev = 0
        for (t, b) in log:
            i = int((t - t0) / 3375000 * rate)
            buf[prev:i] = 8000 if level else -8000
            level, prev = b, i
        buf[prev:] = 8000 if level else -8000
        # simple low-pass to resemble a small speaker
        k = np.ones(4) / 4
        buf = np.convolve(buf, k, mode='same').astype(np.int16)
        with wave.open(str(path), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(buf.tobytes())


def load_image(pp, image64k, entry=0x0600, lower_block=1, p50=0x0F):
    """Place a 64K image as the loader would: 0000-7FFF into lower_block,
    8000-FFFF into block 0, then jump."""
    pp.blocks[lower_block][:] = image64k[:0x8000]
    pp.mem[0x8000:0x10000] = image64k[0x8000:]
    pp.lower = None
    pp.set_p50(p50)
    pp.m.pc = entry
    pp.m.sp = 0xEFF0
