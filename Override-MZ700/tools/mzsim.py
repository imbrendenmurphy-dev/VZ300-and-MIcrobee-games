"""mzsim.py - a minimal Sharp MZ-700 (PAL) machine model for automated testing.

Models: 64K RAM with VRAM at D000/D800, the 8255 keyboard matrix and /VBLK
bit, 8253 counter 0 (sound) and counter 1 (clocked by HSYNC), the sound gate
at E008, and PNG screenshots using a 4K character ROM image if one is given.
It does NOT model VRAM wait states, so real hardware will be a bit slower.
"""
import os
import struct
import zlib

from z80 import Z80

CPU_HZ = 3546875
LINE_T = 227.2                     # T-states per scan line (15.611 kHz HSYNC)
LINES = 312
FIELD_T = int(LINE_T * LINES)      # ~70886 T-states per 50 Hz field
VISIBLE_LINES = 200
PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
       (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]

# key name -> (matrix row, bit); from MZ700WIN key.def
KEYS = {
    'cr': (0, 0), 'left': (7, 2), 'right': (7, 3), 'down': (7, 4), 'up': (7, 5),
    'space': (6, 4), 'j': (3, 6), 'z': (1, 6), 'x': (2, 0), 'break': (8, 7), 'shift': (8, 0),
    '1': (5, 7), '2': (5, 6), '3': (5, 5), 'a': (4, 7), 's': (2, 5),
}


def read_mzf(path):
    raw = open(path, 'rb').read()
    size, load, exe = struct.unpack_from('<HHH', raw, 18)
    return load, raw[128:128 + size], exe


class MZ700:
    def __init__(self, font_path=None):
        self.mem = bytearray(65536)
        self.row = 0
        self.held = set()
        self.ctr1_load_t = 0
        self.ctr1_init = 0
        self.ctr1_latch = None
        self.ctr1_bytes = []
        self.ctr0_value = 0
        self.ctr0_bytes = []
        self.ctr_mode_byte = {}
        self.gate = 0
        self.sound_log = []          # (t, gate, divisor)
        self.waits = 0
        self.font = None
        if font_path and os.path.exists(font_path):
            # MZ-700 CG-ROM dumps store the leftmost pixel in bit 0; flip to MSB-left
            raw = open(font_path, 'rb').read()
            self.font = bytes(int('{:08b}'.format(b)[::-1], 2) for b in raw)
        self.cpu = Z80(self.mem, io_read=lambda p: 0xFF, io_write=self.io_write,
                       mem_read=self.mem_read, mem_write=self.mem_write)

    # ---------------------------------------------------------------- loading
    def load_mzf(self, path):
        load, data, exe = read_mzf(path)
        self.mem[load:load + len(data)] = data
        self.cpu.pc = exe
        self.cpu.sp = 0x10F0
        return load, data, exe

    # ---------------------------------------------------------------- timing
    def line(self):
        return int((self.cpu.t % FIELD_T) / LINE_T)

    def field(self):
        return self.cpu.t // FIELD_T

    # ---------------------------------------------------------------- I/O
    def io_write(self, port, v):
        pass                          # bank switching ports E0-E6: ignored (RAM model)

    # MZ-1X03 joystick on connector A, modelled as in the MiSTer SharpMZ
    # core: during VBLANK bits 1 (X) and 2 (Y) are low for 68 + 28 * pos
    # T-states from the VBLANK start (pos 0 left/up, 128 centre, 255
    # right/down); in the picture they are fire 1 / fire 2, low = pressed.
    # joy = None means nothing is plugged in (E008h reads FFh).
    joy = None                       # dict(x=-1/0/1, y=-1/0/1, f1=bool, f2=bool)

    def joy_read(self):
        j = self.joy
        ft = self.cpu.t % FIELD_T
        line = int(ft / LINE_T)
        v = 0xF9
        if line >= VISIBLE_LINES:
            dt = ft - VISIBLE_LINES * LINE_T
            for bit, axis in ((1, 'x'), (2, 'y')):
                pos = {-1: 0, 0: 128, 1: 255}[j[axis]]
                if dt >= 68 + 28 * pos:
                    v |= 1 << bit
        else:
            if not j.get('f1'):
                v |= 2
            if not j.get('f2'):
                v |= 4
        return v

    vram_wait = None                 # None, 'all' (every line) or 'display'
    WIN0, WIN1 = 128, 191            # T-states into the line when VRAM is free

    def vwait(self):
        t = self.cpu.t
        ft = t % FIELD_T
        line = int(ft / LINE_T)
        if self.vram_wait == 'display' and line >= VISIBLE_LINES:
            return
        x = ft - line * LINE_T
        if self.WIN0 <= x < self.WIN1:
            return
        w = (self.WIN0 - x) if x < self.WIN0 else (LINE_T - x + self.WIN0)
        w = int(w + 0.999)
        self.cpu.t += w
        self.waits += w

    def mem_read(self, a):
        if 0xD000 <= a < 0xE000:
            if self.vram_wait:
                self.vwait()
            return None
        if a < 0xE000 or a > 0xE00F:
            return None
        if a == 0xE008 and self.joy is not None:
            return self.joy_read()
        if a == 0xE001:
            v = 0xFF
            for k in self.held:
                r, b = KEYS[k]
                if r == self.row:
                    v &= ~(1 << b) & 0xFF
            return v
        if a == 0xE002:
            # bit7 = /VBLK (0 during vertical blanking), bit6 = cursor blink
            return 0x7F if self.line() >= VISIBLE_LINES else 0xFF
        if a == 0xE005:
            if self.ctr1_latch is None:
                self.ctr1_latch = [self.ctr1_now() & 0xFF, self.ctr1_now() >> 8]
            v = self.ctr1_latch.pop(0)
            if not self.ctr1_latch:
                self.ctr1_latch = None
            return v
        return 0xFF

    def ctr1_now(self):
        elapsed = int((self.cpu.t - self.ctr1_load_t) / LINE_T)
        init = self.ctr1_init or 65536
        return (init - (elapsed % init)) & 0xFFFF

    def mem_write(self, a, v):
        if a < 0x1000:
            return True               # monitor ROM area
        if 0xD000 <= a < 0xE000:
            if self.vram_wait:
                self.vwait()
            return False
        if a < 0xE000 or a > 0xE00F:
            return False
        if a == 0xE000:
            self.row = v & 0x0F
        elif a == 0xE004:
            self.ctr0_bytes.append(v)
            if len(self.ctr0_bytes) == 2:
                self.ctr0_value = self.ctr0_bytes[0] | (self.ctr0_bytes[1] << 8)
                self.ctr0_bytes = []
                self.sound_log.append((self.cpu.t, self.gate, self.ctr0_value))
        elif a == 0xE005:
            self.ctr1_bytes.append(v)
            if len(self.ctr1_bytes) == 2:
                self.ctr1_init = self.ctr1_bytes[0] | (self.ctr1_bytes[1] << 8)
                self.ctr1_bytes = []
                self.ctr1_load_t = self.cpu.t
        elif a == 0xE007:
            counter = v >> 6
            if (v >> 4) & 3 == 0:     # latch command
                if counter == 1:
                    n = self.ctr1_now()
                    self.ctr1_latch = [n & 0xFF, n >> 8]
            elif counter == 0:
                self.ctr0_bytes = []
            elif counter == 1:
                self.ctr1_bytes = []
        elif a == 0xE008:
            self.gate = v & 1
            self.sound_log.append((self.cpu.t, self.gate, self.ctr0_value))
        return True

    # ---------------------------------------------------------------- running
    def run_t(self, tt):
        c = self.cpu
        end = c.t + tt
        step = c.step
        while c.t < end:
            step()

    def run_fields(self, n):
        self.run_t(n * FIELD_T)

    def run_until_pc(self, pc, max_t=50_000_000):
        c = self.cpu
        end = c.t + max_t
        while c.pc != pc and c.t < end:
            c.step()
        return c.pc == pc

    # ---------------------------------------------------------------- screenshots
    def glyph(self, code, alt):
        if self.font:
            off = (code + (256 if alt else 0)) * 8
            if off + 8 <= len(self.font):
                return self.font[off:off + 8]
        # fallback: 2x2 dot blocks F0-FF (bit0 TL, bit1 TR, bit2 BL, bit3 BR),
        # solid 43, everything else a small box
        if 0xF0 <= code <= 0xFF:
            q = code & 15
            rows = []
            for r in range(8):
                if r in (0, 4):
                    rows.append(0)
                    continue
                top = r < 4
                left = (q & (1 if top else 4)) != 0
                right = (q & (2 if top else 8)) != 0
                rows.append((0x70 if left else 0) | (0x07 if right else 0))
            return bytes(rows)
        if code == 0:
            return bytes(8)
        if code == 0x43:
            return bytes([0xFF] * 8)
        return bytes([0, 0x7E, 0x42, 0x42, 0x42, 0x42, 0x7E, 0])

    def screenshot(self, path, scale=2):
        w, h = 320, 200
        pix = bytearray(w * h * 3)
        for r in range(25):
            for c in range(40):
                ch = self.mem[0xD000 + r * 40 + c]
                at = self.mem[0xD800 + r * 40 + c]
                fg = PAL[(at >> 4) & 7]
                bg = PAL[at & 7]
                g = self.glyph(ch, at & 0x80)
                for y in range(8):
                    bits = g[y]
                    base = ((r * 8 + y) * w + c * 8) * 3
                    for x in range(8):
                        col = fg if bits & (0x80 >> x) else bg
                        i = base + x * 3
                        pix[i:i + 3] = bytes(col)
        write_png(path, w, h, pix, scale)


def write_png(path, w, h, rgb, scale=1):
    rows = []
    for y in range(h):
        line = rgb[y * w * 3:(y + 1) * w * 3]
        if scale > 1:
            out = bytearray()
            for x in range(w):
                out += line[x * 3:x * 3 + 3] * scale
            line = bytes(out)
        for _ in range(scale):
            rows.append(b'\x00' + bytes(line))
    raw = b''.join(rows)

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w * scale, h * scale, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
