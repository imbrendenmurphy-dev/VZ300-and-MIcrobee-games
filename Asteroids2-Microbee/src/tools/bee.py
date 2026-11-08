"""ctypes wrapper around beemu.so (Microbee Premium Plus test model)."""
import ctypes as C
import os, subprocess
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
SO = HERE / 'beemu.so'
CORE = HERE.parent / 'orig' / 'tools' / 'z80core'


def build():
    src = [HERE / 'beemu.c', CORE / 'z80.c']
    if not SO.exists() or any(s.stat().st_mtime > SO.stat().st_mtime for s in src):
        subprocess.run(['cc', '-O2', '-shared', '-fPIC', '-I', str(CORE), '-o', str(SO)] + [str(s) for s in src], check=True)


build()
L = C.CDLL(str(SO))
L.bee_block.restype = C.POINTER(C.c_uint8)
L.bee_video.restype = C.POINTER(C.c_uint8)
L.bee_crtc.restype = C.POINTER(C.c_uint8)
L.bee_frame.restype = C.POINTER(C.c_uint8)
L.bee_cycles.restype = C.c_longlong
L.bee_frames.restype = C.c_longlong
L.bee_wait_t.restype = C.c_longlong
L.bee_prof.restype = C.POINTER(C.c_ulonglong)
L.bee_peek.restype = C.c_uint8
L.bee_spk.restype = C.c_long
L.bee_cyc_sim.restype = C.c_ulonglong
L.bee_cyc_art.restype = C.c_ulonglong
L.bee_load_disk.argtypes = [C.c_void_p, C.c_long]

PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 192, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
           (255, 170, 0)]
KEY = {c: i + 1 for i, c in enumerate('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}
KEY.update({str(d): 0x20 + d for d in range(10)})
KEY.update({'@': 0, 'ESC': 0x30, 'BS': 0x31, 'TAB': 0x32, 'LF': 0x33, 'RET': 0x34, 'LOCK': 0x35, 'BRK': 0x36,
            'SPACE': 0x37, 'UP': 0x38, 'CTRL': 0x39, 'DOWN': 0x3A, 'LEFT': 0x3B, 'RIGHT': 0x3E, 'SHIFT': 0x3F})
FRAME_T = 67500


class Bee:
    def __init__(self, rom=None, charrom=None, disk=None):
        L.bee_init()
        if rom:
            L.bee_load_rom(rom, len(rom))
        if charrom:
            L.bee_load_charrom(charrom, len(charrom))
        self._disk = None
        if disk is not None:
            self._disk = (C.c_uint8 * len(disk)).from_buffer_copy(disk)
            L.bee_load_disk(C.addressof(self._disk), len(disk))

    def block(self, b):
        return np.ctypeslib.as_array(L.bee_block(b), shape=(32768,))

    def video(self, which):
        n = 32768 if which == 3 else 2048
        return np.ctypeslib.as_array(L.bee_video(which), shape=(n,))

    @property
    def crtc(self):
        return np.ctypeslib.as_array(L.bee_crtc(), shape=(32,))

    def load(self, block, data, at=0):
        self.block(block)[at:at + len(data)] = np.frombuffer(bytes(data), dtype=np.uint8)

    def run(self, frames=1):
        return L.bee_run_frames(frames)

    def run_until(self, pc, max_frames=100):
        L.bee_set_bp(pc)
        for _ in range(max_frames):
            if L.bee_run_frames(1):
                L.bee_set_bp(-1)
                return True
        L.bee_set_bp(-1)
        return False

    def key(self, name, down=True):
        L.bee_set_key(KEY[name], 1 if down else 0)

    def keys_up(self):
        for k in range(128):
            L.bee_set_key(k, 0)

    def joy(self, v):
        L.bee_set_joy(v)

    def peek(self, a):
        return L.bee_peek(a)

    def peekw(self, a):
        return L.bee_peek(a) | L.bee_peek(a + 1) << 8

    def poke(self, a, v):
        L.bee_poke(a, v)

    def reg(self, name):
        return L.bee_reg(['pc', 'sp', 'a', 'hl', 'de', 'bc', 'ix', 'iy', 'iff1', 'im'].index(name))

    def set_pc(self, pc, sp):
        L.bee_set_pc(pc, sp)

    def port(self, p, v=None):
        if v is None:
            return L.bee_get_port(p)
        L.bee_set_port(p, v)

    @property
    def cycles(self):
        return L.bee_cycles()

    @property
    def frames(self):
        return L.bee_frames()

    def frame(self):
        w = C.c_int(); h = C.c_int()
        p = L.bee_frame(C.byref(w), C.byref(h))
        a = np.ctypeslib.as_array(p, shape=(300, 640))
        return a[:h.value, :w.value].copy()

    def image(self, mono=False, scale=2):
        from PIL import Image
        idx = self.frame()
        pal = np.array(PALETTE, dtype=np.uint8)
        if mono:
            rgb = np.where(idx[..., None] != 0, np.array((255, 170, 0), np.uint8), np.array((0, 0, 0), np.uint8))
        else:
            rgb = pal[idx]
        im = Image.fromarray(rgb.astype(np.uint8))
        w = im.width * scale
        return im.resize((w, w * 3 // 4), Image.Resampling.NEAREST)

    def profile(self, on=True):
        L.bee_profile(1 if on else 0)

    def prof(self):
        return np.ctypeslib.as_array(L.bee_prof(), shape=(65536,)).copy()

    def wait_range(self, lo, hi):
        L.bee_wait_range(lo, hi)

    def wait_t(self):
        return L.bee_wait_t()

    def speaker(self):
        t = C.POINTER(C.c_ulonglong)(); v = C.POINTER(C.c_uint8)()
        n = L.bee_spk(C.byref(t), C.byref(v))
        if n == 0:
            return np.zeros(0, np.uint64), np.zeros(0, np.uint8)
        return np.ctypeslib.as_array(t, shape=(n,)).copy(), np.ctypeslib.as_array(v, shape=(n,)).copy()

    def save_wav(self, path, rate=22050, t0=0, t1=None):
        import wave
        ts, vs = self.speaker()
        t1 = t1 or self.cycles
        n = int((t1 - t0) / 3375000 * rate)
        buf = np.zeros(n, dtype=np.float32)
        level, prev = 0, 0
        for t, v in zip(ts, vs):
            if t < t0:
                level = v; continue
            i = min(n, int((t - t0) / 3375000 * rate))
            buf[prev:i] = 1 if level else -1
            level, prev = v, i
        buf[prev:] = 1 if level else -1
        buf = np.convolve(buf, np.ones(4) / 4, mode='same')
        buf -= np.convolve(buf, np.ones(2001) / 2001, mode='same')
        out = (buf * 9000).astype(np.int16)
        with wave.open(str(path), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(out.tobytes())


def sym(path):
    import re
    return {k: int(v, 16) for k, v in re.findall(r'^(\S+): EQU 0x([0-9A-F]+)', Path(path).read_text(), re.M)}
