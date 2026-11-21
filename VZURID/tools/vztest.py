#!/usr/bin/env python3
"""VZ300 test harness: runs the built binary in the Z80 emulator with a model of
the keyboard matrix, field sync timing (312 lines, 56 lines FS low) and the TV beam,
and checks every VRAM write against the beam position (tearing / late-row check)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from z80emu import Z80
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
FIELD = 70630                      # measured T-states per field on real hardware
LINES = 312
LT = FIELD / LINES                 # T per scanline
FS_FALL = 256 * LT                 # phase (in T) at which field sync goes low
PALETTE = {0: (0x20, 0xC0, 0x20), 1: (0xE0, 0xE0, 0x30), 2: (0x30, 0x40, 0xE0), 3: (0xE0, 0x30, 0x30)}

KEYS = {   # name -> (row index, bit)
    'M': (4, 5), ',': (4, 3), '.': (4, 1), ' ': (4, 4), 'Q': (0, 4), 'A': (1, 4),
}


def load_syms(path):
    syms = {}
    for line in open(path):
        a, n = line.split()
        syms[n] = int(a, 16)
    return syms


class VZ:
    def __init__(self, binpath, sympath):
        self.cpu = Z80()
        blob = open(binpath, 'rb').read()
        self.cpu.mem[0x8000:0x8000 + len(blob)] = blob
        self.cpu.pc = 0x8000
        self.syms = load_syms(sympath)
        self.keys = set()
        self.cpu.on_read = self.on_read
        self.cpu.on_write = self.on_write
        self.cpu.on_in = lambda port, c: 0xFF
        self.latch = 0
        self.frames = []            # per-frame records
        self.cur = None
        self.last_write = {}        # row -> t of last write in current frame
        self.beam_conflicts = []    # writes landing while the beam is inside the row
        self.t_off = 0
        self.vram_writes = 0

    # --- hardware model ---
    def phase(self, t):
        return (t + self.t_off) % FIELD

    def fs_high(self, t):
        return self.phase(t) < FS_FALL

    def on_read(self, addr, cpu):
        if 0x6800 <= addr < 0x7000:
            rows = 0x3F
            for name in self.keys:
                r, b = KEYS[name]
                if not addr & (1 << r):          # row selected (address line low)
                    rows &= ~(1 << b)
            return rows | 0x40 | (0x80 if self.fs_high(cpu.t) else 0)
        return None

    def on_write(self, addr, val, cpu):
        if addr == 0x6800 or (0x6800 <= addr < 0x7000):
            self.latch = val
            return False
        if 0x7000 <= addr < 0x7800:
            row = (addr - 0x7000) >> 5
            t = cpu.t
            self.vram_writes += 1
            if self.cur is not None:
                self.last_write[row] = t
                # is the beam inside this row right now?
                ph = self.phase(t)
                w = ((120 + 3 * row) % LINES) * LT
                if w <= ph < w + 3 * LT:
                    self.beam_conflicts.append((self.cur['n'], row, t))
        return True

    # --- running ---
    def vram_image(self, scale=(4, 6)):
        img = Image.new('RGB', (128, 64))
        mem = self.cpu.mem
        css = (self.latch >> 4) & 1
        for y in range(64):
            for xb in range(32):
                b = mem[0x7000 + y * 32 + xb]
                for p in range(4):
                    c = b >> (6 - 2 * p) & 3
                    img.putpixel((xb * 4 + p, y), PALETTE[c])
        return img.resize((128 * scale[0], 64 * scale[1]), Image.NEAREST)

    def run(self, nframes, script=None, shots=None, shot_dir=None, skip_splash=False, controller=None):
        """script: dict frame -> list of (key, True/False).  Frame numbering counts game frames
        (render calls).  shots: set of frame numbers to save as PNG."""
        cpu = self.cpu
        s = self.syms
        render, fwait = s['frame_sync_ret'], s['frame_wait']
        n = -1
        script = script or {}
        shots = shots or set()
        # align field phase so that the FS fall is at an arbitrary start offset
        self.t_off = 0
        prev_render_t = None
        max_steps = 400_000_000
        steps = 0
        game_started = False
        while steps < max_steps:
            pc = cpu.pc
            if pc == render:
                if prev_render_t is not None and self.cur is not None:
                    self.finish_frame()
                n += 1
                if n >= nframes:
                    break
                if n in script:
                    for k, down in script[n]:
                        (self.keys.add if down else self.keys.discard)(k)
                if controller:
                    controller(n, self)
                ph = self.phase(cpu.t)
                since_fall = (ph - FS_FALL) % FIELD
                self.cur = {'n': n, 't_start': cpu.t, 'since_fall': since_fall, 'sync': cpu.t - since_fall}
                self.last_write = {}
                prev_render_t = cpu.t
                if n in shots and shot_dir:
                    self.vram_image().save(os.path.join(shot_dir, 'frame_%04d.png' % n))
            elif pc == fwait and self.cur is not None and 'work' not in self.cur:
                self.cur['work'] = cpu.t - self.cur['t_start']
            cpu.step()
            steps += 1
        return self.frames

    def finish_frame(self):
        c = self.cur
        # late-row check: last write of each playfield row must precede the beam
        worst = None
        for row, t in self.last_write.items():
            if row < 16:
                continue
            deadline = c['sync'] + (120 + 3 * row) * LT
            margin = deadline - t
            if worst is None or margin < worst[0]:
                worst = (margin, row)
        c['margin'] = worst
        c['late_rows'] = [r for r, t in self.last_write.items() if r >= 16 and t >= c['sync'] + (120 + 3 * r) * LT]
        self.frames.append(c)
        self.cur = None

    def var(self, name, size=1):
        a = self.syms[name]
        v = self.cpu.mem[a]
        if size == 2:
            v |= self.cpu.mem[a + 1] << 8
        return v
