"""Python front end for the C Premium Plus model (tools/emu/mbee.c).

    pp = Mbee(rom=..., disk=...)   pp.run_frames(n)   pp.png(path)
"""
import ctypes as C
import os
import subprocess
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
FRAME_T = 67500
SO = HERE / 'emu' / 'libmbee.so'


def build_lib():
    src = [HERE / 'emu' / 'z80.c', HERE / 'emu' / 'mbee.c']
    if not SO.exists() or any(s.stat().st_mtime > SO.stat().st_mtime for s in src):
        subprocess.check_call(['gcc', '-O2', '-shared', '-fPIC', '-o', str(SO)] + [str(s) for s in src])


build_lib()
L = C.CDLL(str(SO))


class Z80(C.Structure):
    _fields_ = [(n, C.c_uint8) for n in ('a', 'f', 'b', 'c', 'd', 'e', 'h', 'l',
                                         'a_', 'f_', 'b_', 'c_', 'd_', 'e_', 'h_', 'l_')] + \
               [('ix', C.c_uint16), ('iy', C.c_uint16), ('sp', C.c_uint16), ('pc', C.c_uint16)] + \
               [(n, C.c_uint8) for n in ('i', 'r', 'iff1', 'iff2', 'im', 'halted', 'ei_pending')]


L.mb_new.restype = C.c_void_p
for fn in ('mb_block', 'mb_scr', 'mb_attr', 'mb_col', 'mb_pcg', 'mb_crtc', 'mb_regs', 'mb_disk'):
    getattr(L, fn).restype = C.POINTER(C.c_uint8)
L.mb_block.argtypes = [C.c_void_p, C.c_int]
for fn in ('mb_scr', 'mb_attr', 'mb_col', 'mb_pcg', 'mb_crtc', 'mb_regs', 'mb_disk'):
    getattr(L, fn).argtypes = [C.c_void_p]
L.mb_cpu.restype = C.POINTER(Z80)
L.mb_cpu.argtypes = [C.c_void_p]
L.mb_tick.restype = C.c_uint64
L.mb_tick.argtypes = [C.c_void_p]
L.mb_run.argtypes = [C.c_void_p, C.c_uint64]
L.mb_set_keys.argtypes = [C.c_void_p, C.c_uint64]
L.mb_set_joy.argtypes = [C.c_void_p, C.c_int]
L.mb_set_rom.argtypes = [C.c_void_p, C.c_char_p, C.c_int]
L.mb_set_disk.argtypes = [C.c_void_p, C.c_char_p, C.c_int]
L.mb_peek.argtypes = [C.c_void_p, C.c_uint16]
L.mb_peek.restype = C.c_uint8
L.mb_poke.argtypes = [C.c_void_p, C.c_uint16, C.c_uint8]
L.mb_out.argtypes = [C.c_void_p, C.c_int, C.c_int]
L.mb_set_bp.argtypes = [C.c_void_p, C.c_uint16, C.c_int]
L.mb_set_watch.argtypes = [C.c_void_p, C.c_uint16, C.c_int]
L.mb_events.argtypes = [C.c_void_p, C.POINTER(C.POINTER(C.c_uint64)), C.POINTER(C.POINTER(C.c_uint16))]
L.mb_spk.argtypes = [C.c_void_p, C.POINTER(C.POINTER(C.c_uint64)), C.POINTER(C.POINTER(C.c_uint8))]
L.mb_clear_events.argtypes = [C.c_void_p]
L.mb_clear_spk.argtypes = [C.c_void_p]
L.mb_profile.argtypes = [C.c_void_p, C.c_int]
L.mb_prof.restype = C.POINTER(C.c_uint32)
L.mb_prof.argtypes = [C.c_void_p]
L.mb_vram_disp_writes.restype = C.c_uint32
L.mb_vram_disp_writes.argtypes = [C.c_void_p, C.c_int]
L.mb_fdc_writes.argtypes = [C.c_void_p]
L.mb_set_wp.argtypes = [C.c_void_p, C.c_int]
L.mb_mouse.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int]
L.mb_mouse_busy.argtypes = [C.c_void_p]
L.mb_mouse_stat.argtypes = [C.c_void_p, C.c_int]
L.mb_mouse_stat.restype = C.c_uint32

# Premium palette (RGBI). Colour 3 is shown dark yellow, as MAME does.
PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
KEY = {c: i + 1 for i, c in enumerate('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}
KEY.update({str(d): 0x20 + d for d in range(10)})
KEY.update({'@': 0, 'ESC': 0x30, 'BS': 0x31, 'TAB': 0x32, 'LF': 0x33, 'RET': 0x34, 'LOCK': 0x35, 'BRK': 0x36,
            'SPACE': 0x37, 'UP': 0x38, 'CTRL': 0x39, 'DOWN': 0x3A, 'LEFT': 0x3B, 'RIGHT': 0x3E, 'SHIFT': 0x3F})


def arr(ptr, n):
    return np.ctypeslib.as_array(ptr, shape=(n,))


class Mbee:
    def __init__(self, rom=None, disk=None):
        self.h = C.c_void_p(L.mb_new())
        if rom:
            L.mb_set_rom(self.h, rom, len(rom))
        if disk:
            L.mb_set_disk(self.h, disk, len(disk))
        self.cpu = L.mb_cpu(self.h).contents
        self.blocks = [arr(L.mb_block(self.h, b), 32768) for b in range(32)]
        self.scr = arr(L.mb_scr(self.h), 2048)
        self.attr = arr(L.mb_attr(self.h), 2048)
        self.col = arr(L.mb_col(self.h), 2048)
        self.pcg = arr(L.mb_pcg(self.h), 16 * 2048)
        self.crtc = arr(L.mb_crtc(self.h), 32)
        self._keys = set()
        self.cpu.sp = 0xFFFF

    # ---- state
    @property
    def tick(self):
        return L.mb_tick(self.h)

    @property
    def frames(self):
        return self.tick // FRAME_T

    def regs(self):
        r = arr(L.mb_regs(self.h), 8)
        return dict(p50=int(r[0]), p1c=int(r[1]), p08=int(r[2]), p0b=int(r[3]), lower=int(r[4]))

    def out(self, port, v):
        L.mb_out(self.h, port, v)

    def peek(self, a):
        return L.mb_peek(self.h, a & 0xFFFF)

    def peekw(self, a):
        return self.peek(a) | (self.peek(a + 1) << 8)

    def poke(self, a, v):
        L.mb_poke(self.h, a & 0xFFFF, v & 0xFF)

    def disk(self, n=819200):
        return bytes(arr(L.mb_disk(self.h), n))

    # ---- input
    @property
    def keys(self):
        return self._keys

    @keys.setter
    def keys(self, ks):
        self._keys = set(ks)
        m = 0
        for k in self._keys:
            m |= 1 << (KEY[k] if isinstance(k, str) else k)
        L.mb_set_keys(self.h, m)

    def set_joy(self, v):
        L.mb_set_joy(self.h, v)

    def mouse(self, dx, dy, btn=0):
        """queue Microsoft-protocol packets for a relative move (split into
        steps of at most 127) with buttons b0 left, b1 right"""
        while True:
            sx = max(-127, min(127, dx))
            sy = max(-127, min(127, dy))
            L.mb_mouse(self.h, sx, sy, btn)
            dx -= sx
            dy -= sy
            if dx == 0 and dy == 0:
                break

    def mouse_busy(self):
        return bool(L.mb_mouse_busy(self.h))

    def mouse_stats(self):
        return dict(irqs=L.mb_mouse_stat(self.h, 0), overruns=L.mb_mouse_stat(self.h, 1), packets=L.mb_mouse_stat(self.h, 2))

    # ---- running
    def run_ticks(self, n):
        return L.mb_run(self.h, self.tick + n)

    def run_frames(self, n=1):
        target = (self.tick // FRAME_T + n) * FRAME_T
        while self.tick < target:
            if L.mb_run(self.h, target):
                return self.cpu.pc
        return None

    def run_until(self, pc, max_frames=100):
        L.mb_set_bp(self.h, pc, 1)
        target = self.tick + max_frames * FRAME_T
        hit = L.mb_run(self.h, target)
        L.mb_set_bp(self.h, pc, 0)
        return self.cpu.pc if hit else None

    def watch(self, pc, on=1):
        L.mb_set_watch(self.h, pc, on)

    def events(self, clear=True):
        t = C.POINTER(C.c_uint64)()
        p = C.POINTER(C.c_uint16)()
        n = L.mb_events(self.h, C.byref(t), C.byref(p))
        res = [(t[i], p[i]) for i in range(n)]
        if clear:
            L.mb_clear_events(self.h)
        return res

    def speaker(self, clear=False):
        t = C.POINTER(C.c_uint64)()
        v = C.POINTER(C.c_uint8)()
        n = L.mb_spk(self.h, C.byref(t), C.byref(v))
        res = (np.ctypeslib.as_array(t, shape=(n,)).copy() if n else np.zeros(0, np.uint64),
               np.ctypeslib.as_array(v, shape=(n,)).copy() if n else np.zeros(0, np.uint8))
        if clear:
            L.mb_clear_spk(self.h)
        return res

    def profile(self, on=True):
        L.mb_profile(self.h, 1 if on else 0)

    def prof(self):
        return arr(L.mb_prof(self.h), 65536).copy()

    def vram_display_writes(self, reset=True):
        return L.mb_vram_disp_writes(self.h, 1 if reset else 0)

    def snap(self):
        return C.c_void_p(L.mb_snap(self.h))

    def restore(self, s):
        L.mb_restore(self.h, s)

    def snap_free(self, s):
        L.mb_snap_free(s)

    def set_wp(self, on):
        L.mb_set_wp(self.h, 1 if on else 0)

    def fdc_writes(self):
        return L.mb_fdc_writes(self.h)

    # ---- pictures
    def start_addr(self):
        return ((int(self.crtc[12]) & 0x3F) << 8) | int(self.crtc[13])

    def screen_rgb(self, mono=False):
        cols = int(self.crtc[1]) or 64
        rows = int(self.crtc[6]) or 16
        lines = (int(self.crtc[9]) & 31) + 1
        start = self.start_addr()
        a = (start + np.arange(rows * cols)) & 0x7FF
        ch = self.scr[a].astype(np.int32)
        at = self.attr[a].astype(np.int32)
        co = self.col[a].astype(np.int32)
        p1c = self.regs()['p1c']
        pcgon = (ch & 0x80) != 0
        if not (p1c & 0x80):
            pcgon[:] = False
        base = ((at & 15) * 2048 + (ch & 0x7F) * 16)
        rowsel = np.arange(lines)
        glyph = np.where(pcgon[:, None], self.pcg[(base[:, None] + rowsel[None, :]) % (16 * 2048)], 0)
        bits = ((glyph[:, :, None] >> (7 - np.arange(8))[None, None, :]) & 1).astype(bool)
        pal = np.array(PALETTE, dtype=np.uint8)
        if mono:
            fg = np.broadcast_to(np.array((255, 176, 0), np.uint8), (rows * cols, 3))
            bg = np.zeros((rows * cols, 3), np.uint8)
        else:
            fg = pal[co & 15]
            bg = pal[(co >> 4) & 15]
        img = np.where(bits[:, :, :, None], fg[:, None, None, :], bg[:, None, None, :])
        img = img.reshape(rows, cols, lines, 8, 3).transpose(0, 2, 1, 3, 4).reshape(rows * lines, cols * 8, 3)
        return img

    def png(self, path, scale=2, mono=False, aspect=1.5):
        """save the screen; each pixel is drawn about 1.5-1.8x taller than wide
        on a real monitor, so the default scales rows by 1.5 x scale"""
        from PIL import Image
        im = Image.fromarray(self.screen_rgb(mono))
        im = im.resize((im.width * scale, int(im.height * scale * aspect)), Image.NEAREST)
        im.save(path)
        return im

    def text(self, cols=None, rows=None):
        cols = cols or int(self.crtc[1]) or 64
        rows = rows or int(self.crtc[6]) or 16
        start = self.start_addr()
        out = []
        for r in range(rows):
            line = ''
            for c in range(cols):
                v = int(self.scr[(start + r * cols + c) & 0x7FF])
                line += chr(v) if 32 <= v < 127 else ' '
            out.append(line.rstrip())
        return '\n'.join(out)

    def wav(self, path, t0=0, t1=None, rate=22050):
        import wave
        t, v = self.speaker()
        t1 = t1 or self.tick
        n = int((t1 - t0) / 3375000 * rate)
        buf = np.zeros(max(n, 1), dtype=np.float32)
        level, prev = 0, 0
        for tt, vv in zip(t, v):
            if tt < t0:
                level = vv
                continue
            if tt >= t1:
                break
            i = int((tt - t0) / 3375000 * rate)
            buf[prev:i] = 1.0 if level else -1.0
            level, prev = vv, i
        buf[prev:] = 1.0 if level else -1.0
        # a small speaker: DC-blocked, gently low-passed
        k = np.ones(3) / 3
        buf = np.convolve(buf, k, mode='same')
        buf = buf - np.convolve(buf, np.ones(441) / 441, mode='same')
        out = (np.clip(buf, -1, 1) * 9000).astype(np.int16)
        with wave.open(str(path), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(out.tobytes())


L.mb_snap.restype = C.c_void_p
L.mb_snap.argtypes = [C.c_void_p]
L.mb_restore.argtypes = [C.c_void_p, C.c_void_p]
L.mb_snap_free.argtypes = [C.c_void_p]
L.mb_set_ww.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int]
L.mb_ww.argtypes = [C.c_void_p, C.POINTER(C.c_int)]


def write_watch(pp, blk, lo, hi):
    """stop the next run when block blk (100 = upper 32K) gets a write in [lo, hi)"""
    L.mb_set_ww(pp.h, blk, lo, hi)


def write_hit(pp):
    a = C.c_int()
    pc = L.mb_ww(pp.h, C.byref(a))
    return pc, a.value
