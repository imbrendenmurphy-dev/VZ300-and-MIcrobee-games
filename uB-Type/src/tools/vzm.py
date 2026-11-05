"""VZ300 reference model (tools/emu/vz.c) for running the original VZ-TYPE."""
import ctypes as C
import subprocess
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
SO = HERE / 'emu' / 'libvz.so'
src = [HERE / 'emu' / 'z80.c', HERE / 'emu' / 'vz.c']
if not SO.exists() or any(s.stat().st_mtime > SO.stat().st_mtime for s in src):
    subprocess.check_call(['gcc', '-O2', '-shared', '-fPIC', '-o', str(SO)] + [str(s) for s in src])
L = C.CDLL(str(SO))
from mbee import Z80
FIELD = 70824
L.vz_new.restype = C.c_void_p
L.vz_mem.restype = C.POINTER(C.c_uint8); L.vz_mem.argtypes = [C.c_void_p]
L.vz_sram.restype = C.POINTER(C.c_uint8); L.vz_sram.argtypes = [C.c_void_p, C.c_int]
L.vz_cpu.restype = C.POINTER(Z80); L.vz_cpu.argtypes = [C.c_void_p]
L.vz_tick.restype = C.c_uint64; L.vz_tick.argtypes = [C.c_void_p]
L.vz_run.argtypes = [C.c_void_p, C.c_uint64]
L.vz_set_rows.argtypes = [C.c_void_p, C.c_char_p]
L.vz_peek.argtypes = [C.c_void_p, C.c_uint16]; L.vz_peek.restype = C.c_uint8
L.vz_latch.argtypes = [C.c_void_p]; L.vz_latch.restype = C.c_uint8
L.vz_bank.argtypes = [C.c_void_p]
L.vz_set_bp.argtypes = [C.c_void_p, C.c_uint16, C.c_int]
L.vz_set_watch.argtypes = [C.c_void_p, C.c_uint16, C.c_int]
L.vz_events.argtypes = [C.c_void_p, C.POINTER(C.POINTER(C.c_uint64)), C.POINTER(C.POINTER(C.c_uint16))]
L.vz_clear_events.argtypes = [C.c_void_p]
L.vz_spk.argtypes = [C.c_void_p, C.POINTER(C.POINTER(C.c_uint64)), C.POINTER(C.POINTER(C.c_uint8))]
L.vz_profile.argtypes = [C.c_void_p, C.c_int]
L.vz_prof.restype = C.POINTER(C.c_uint32); L.vz_prof.argtypes = [C.c_void_p]
VZKEY = {'T': (0, 0), 'Q': (0, 4), 'A': (1, 4), 'Z': (2, 4), 'X': (2, 1), 'SPACE': (4, 4), 'M': (4, 5),
         'O': (6, 1), 'P': (6, 4), 'RET': (6, 2), 'H': (7, 0)}
VZPAL = [[(0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 0)], [(255, 255, 255), (0, 255, 255), (255, 0, 255), (255, 128, 0)]]


class VZ:
    def __init__(self, vzfile):
        self.h = C.c_void_p(L.vz_new())
        d = open(vzfile, 'rb').read()
        start = d[22] | (d[23] << 8)
        mem = np.ctypeslib.as_array(L.vz_mem(self.h), shape=(65536,))
        mem[start:start + len(d) - 24] = np.frombuffer(d[24:], np.uint8)
        self.mem = mem
        self.cpu = L.vz_cpu(self.h).contents
        self.cpu.pc = start
        self.cpu.sp = 0xFFF0
        self._keys = set()

    @property
    def tick(self):
        return L.vz_tick(self.h)

    @property
    def keys(self):
        return self._keys

    @keys.setter
    def keys(self, ks):
        self._keys = set(ks)
        rows = bytearray(8)
        for k in ks:
            r, b = VZKEY[k]
            rows[r] |= 1 << b
        L.vz_set_rows(self.h, bytes(rows))

    def peek(self, a):
        return L.vz_peek(self.h, a)

    def run_fields(self, n=1):
        target = (self.tick // FIELD + n) * FIELD
        return L.vz_run(self.h, target)

    def run_until(self, pc, max_fields=100):
        L.vz_set_bp(self.h, pc, 1)
        hit = L.vz_run(self.h, self.tick + max_fields * FIELD)
        L.vz_set_bp(self.h, pc, 0)
        return hit

    def watch(self, pc, on=1):
        L.vz_set_watch(self.h, pc, on)

    def events(self, clear=True):
        t = C.POINTER(C.c_uint64)(); p = C.POINTER(C.c_uint16)()
        n = L.vz_events(self.h, C.byref(t), C.byref(p))
        r = [(t[i], p[i]) for i in range(n)]
        if clear:
            L.vz_clear_events(self.h)
        return r

    def speaker(self):
        t = C.POINTER(C.c_uint64)(); v = C.POINTER(C.c_uint8)()
        n = L.vz_spk(self.h, C.byref(t), C.byref(v))
        return (np.ctypeslib.as_array(t, shape=(n,)).copy(), np.ctypeslib.as_array(v, shape=(n,)).copy()) if n else (np.zeros(0), np.zeros(0))

    def profile(self, on=True):
        L.vz_profile(self.h, 1 if on else 0)

    def prof(self):
        return np.ctypeslib.as_array(L.vz_prof(self.h), shape=(65536,)).copy()

    def screen_rgb(self):
        latch = L.vz_latch(self.h)
        vram = self.mem[0x7000:0x7800]
        css = (latch >> 4) & 1
        if not (latch & 8):
            img = np.zeros((192, 256, 3), np.uint8)   # text mode: not rendered
            return img
        px = np.zeros((64, 128), np.uint8)
        for i in range(4):
            px[:, i::4] = (vram.reshape(64, 32) >> (6 - 2 * i)) & 3
        pal = np.array(VZPAL[css], np.uint8)
        img = pal[px]
        return np.repeat(np.repeat(img, 3, axis=0), 2, axis=1)

    def png(self, path, scale=2):
        from PIL import Image
        im = Image.fromarray(self.screen_rgb())
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        im.save(path)

    def wav(self, path, t0=0, t1=None, rate=22050, clock=3546900):
        import wave
        t, v = self.speaker()
        t1 = t1 or self.tick
        n = int((t1 - t0) / clock * rate)
        buf = np.zeros(max(n, 1), np.float32)
        level, prev = 0, 0
        for tt, vv in zip(t, v):
            if tt < t0:
                level = vv; continue
            if tt >= t1:
                break
            i = int((tt - t0) / clock * rate)
            buf[prev:i] = 1.0 if level else -1.0
            level, prev = vv, i
        buf[prev:] = 1.0 if level else -1.0
        buf = np.convolve(buf, np.ones(3) / 3, mode='same')
        buf = buf - np.convolve(buf, np.ones(441) / 441, mode='same')
        out = (np.clip(buf, -1, 1) * 9000).astype(np.int16)
        with wave.open(str(path), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(out.tobytes())
