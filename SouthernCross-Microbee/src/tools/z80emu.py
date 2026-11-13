"""Compact Z80 emulator (no IX/IY) with a Microbee Premium video/keyboard/RTC model.
A call to 0005h is handled as a small CP/M BDOS (console out, open/read/close files
from FILEDIR, set DMA) so programs that load data files before taking over can be tested."""
import os
FILEDIR = os.environ.get('CPM_DIR', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build'))

class CPM:
    def __init__(self):
        self.dma = 0x80
        self.open = {}          # FCB address -> (data, offset)
        self.console = ''
    def name(self, m, fcb):
        n = bytes(m.ram[fcb + 1:fcb + 9]).decode('latin1').strip()
        t = bytes(m.ram[fcb + 9:fcb + 12]).decode('latin1').strip()
        return n + ('.' + t if t else '')
    def call(self, cpu):
        m = cpu.m; c = cpu.c; de = cpu.d << 8 | cpu.e; a = 0
        if c == 2: self.console += chr(cpu.e)
        elif c == 9:
            while m.ram[de] != 0x24: self.console += chr(m.ram[de]); de += 1
        elif c == 26: self.dma = de
        elif c == 15:
            fn = os.path.join(FILEDIR, self.name(m, de))
            if os.path.exists(fn): self.open[de] = [open(fn, 'rb').read(), 0]; a = 0
            else: a = 0xFF
        elif c == 16:
            f = self.open.pop(de, None)
            if f and len(f) > 2:            # a file we wrote: save it
                open(f[2], 'wb').write(bytes(f[0]))
        elif c == 19:
            fn = os.path.join(FILEDIR, self.name(m, de))
            a = 0 if os.path.exists(fn) else 0xFF
            if a == 0: os.remove(fn)
        elif c == 22:
            self.open[de] = [bytearray(), 0, os.path.join(FILEDIR, self.name(m, de))]
        elif c == 21:
            f = self.open.get(de)
            if not f or len(f) < 3: a = 0xFF
            else: f[0] += bytes(m.ram[self.dma:self.dma + 128])
        elif c == 20:
            f = self.open.get(de)
            if not f or f[1] >= len(f[0]): a = 1
            else:
                blk = f[0][f[1]:f[1] + 128]; blk = blk + b'\x1a' * (128 - len(blk))
                m.ram[self.dma:self.dma + 128] = blk; f[1] += 128
        cpu.a = a; cpu.l = a; cpu.h = 0; cpu.b = 0

SF, ZF, HF, PF, NF, CF = 0x80, 0x40, 0x10, 0x04, 0x02, 0x01
PARITY = [0] * 256
for i in range(256):
    PARITY[i] = PF if bin(i).count('1') % 2 == 0 else 0

class Bee:
    def __init__(self):
        self.ram = bytearray(65536)
        self.screen = bytearray(2048)
        self.attr = bytearray(2048)
        self.colour = bytearray([0x0e] * 2048)
        self.pcg = bytearray(16 * 2048)
        self.latch = 0
        self.port08 = 0
        self.crtc = [0] * 32
        self.creg = 0
        self.status = 0
        self.keys = set()
        self.cycles = 0
        self.outlog = []
        self.bdos = CPM()

    # memory
    def rd(self, a):
        if a >= 0xF000:
            if a < 0xF800:
                o = a - 0xF000
                if self.latch & 0x10: return self.attr[o]
                return self.screen[o]
            if self.port08 & 0x40: return self.colour[a - 0xF800]
            return self.pcg[(self.latch & 15) * 2048 + a - 0xF800]
        return self.ram[a]

    def wr(self, a, v):
        if a >= 0xF000:
            if a < 0xF800:
                o = a - 0xF000
                if self.latch & 0x10: self.attr[o] = v
                else: self.screen[o] = v
            elif self.port08 & 0x40:
                self.colour[a - 0xF800] = v
            else:
                self.pcg[(self.latch & 15) * 2048 + a - 0xF800] = v
            return
        if a < 0x5C:            # the FCB (5Ch) and DMA buffer (80h) are fair game
            raise Exception('write to page zero %04X' % a)
        self.ram[a] = v

    def out(self, p, v):
        p &= 0xff
        if p == 0x0C: self.creg = v & 31
        elif p == 0x0D:
            self.crtc[self.creg] = v
            if self.creg == 31:
                addr = (self.crtc[18] << 8 | self.crtc[19]) & 0x3fff
                key = (addr >> 4) & 63
                self.status |= 0x80
                if key in self.keys: self.status |= 0x40
        elif p == 0x1C: self.latch = v
        elif p == 0x08: self.port08 = v
        elif p == 0x04: self.rtcreg = v

    def inp(self, p):
        p &= 0xff
        if p == 0x0C:
            vb = 0x20 if (self.cycles % 67500) >= 67500 - 12300 else 0
            return (self.status & 0xDF) | vb
        if p == 0x0D:
            if self.creg in (16, 17): self.status &= ~0x40
            return self.crtc[self.creg]
        if p == 0x07: return (self.cycles // 3375000) % 60
        return 0xff


class Z80:
    def __init__(self, m):
        self.m = m
        self.a = self.f = self.b = self.c = self.d = self.e = self.h = self.l = 0
        self.sp = 0xFFFF; self.pc = 0x100
        self.a_ = self.f_ = 0; self.alt = [0]*6
        self.t = 0

    # register helpers
    def r8(self, i):
        if i == 0: return self.b
        if i == 1: return self.c
        if i == 2: return self.d
        if i == 3: return self.e
        if i == 4: return self.h
        if i == 5: return self.l
        if i == 6: return self.m.rd(self.h << 8 | self.l)
        return self.a

    def w8(self, i, v):
        v &= 0xff
        if i == 0: self.b = v
        elif i == 1: self.c = v
        elif i == 2: self.d = v
        elif i == 3: self.e = v
        elif i == 4: self.h = v
        elif i == 5: self.l = v
        elif i == 6: self.m.wr(self.h << 8 | self.l, v)
        else: self.a = v

    def rp(self, i):
        if i == 0: return self.b << 8 | self.c
        if i == 1: return self.d << 8 | self.e
        if i == 2: return self.h << 8 | self.l
        return self.sp

    def wrp(self, i, v):
        v &= 0xffff
        if i == 0: self.b, self.c = v >> 8, v & 0xff
        elif i == 1: self.d, self.e = v >> 8, v & 0xff
        elif i == 2: self.h, self.l = v >> 8, v & 0xff
        else: self.sp = v

    def fetch(self):
        v = self.m.rd(self.pc); self.pc = (self.pc + 1) & 0xffff; return v

    def fetch16(self):
        lo = self.fetch(); return lo | self.fetch() << 8

    def push(self, v):
        self.sp = (self.sp - 1) & 0xffff; self.m.wr(self.sp, v >> 8)
        self.sp = (self.sp - 1) & 0xffff; self.m.wr(self.sp, v & 0xff)

    def pop(self):
        lo = self.m.rd(self.sp); self.sp = (self.sp + 1) & 0xffff
        hi = self.m.rd(self.sp); self.sp = (self.sp + 1) & 0xffff
        return hi << 8 | lo

    def cond(self, cc):
        f = self.f
        return [not f & ZF, f & ZF, not f & CF, f & CF, not f & PF, f & PF, not f & SF, f & SF][cc]

    def alu(self, op, v):
        a = self.a
        if op in (0, 1):
            c = (self.f & CF) if op == 1 else 0
            r = a + v + c
            f = (r & 0x80) | (0 if r & 0xff else ZF) | ((a ^ v ^ r) & HF)
            f |= PF if (~(a ^ v) & (a ^ r) & 0x80) else 0
            f |= CF if r > 0xff else 0
            self.a = r & 0xff; self.f = f
        elif op in (2, 3, 7):
            c = (self.f & CF) if op == 3 else 0
            r = a - v - c
            f = (r & 0x80) | (0 if r & 0xff else ZF) | ((a ^ v ^ r) & HF) | NF
            f |= PF if ((a ^ v) & (a ^ r) & 0x80) else 0
            f |= CF if r < 0 else 0
            if op != 7: self.a = r & 0xff
            self.f = f
        else:
            if op == 4: r = a & v; h = HF
            elif op == 5: r = a ^ v; h = 0
            else: r = a | v; h = 0
            self.a = r
            self.f = (r & 0x80) | (0 if r else ZF) | h | PARITY[r]

    def step(self):
        if self.pc == 5 and self.m.bdos:
            self.m.bdos.call(self); self.pc = self.pop(); self.t += 200; return
        op = self.fetch()
        t = 4
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        p, q = y >> 1, y & 1
        if x == 1:
            if op == 0x76: raise Exception('HALT at %04X' % (self.pc - 1))
            self.w8(y, self.r8(z)); t = 7 if (y == 6 or z == 6) else 4
        elif x == 2:
            self.alu(y, self.r8(z)); t = 7 if z == 6 else 4
        elif x == 0:
            if z == 0:
                if y == 0: pass
                elif y == 1:
                    self.a, self.a_ = self.a_, self.a; self.f, self.f_ = self.f_, self.f
                elif y == 2:
                    d = self.fetch(); self.b = (self.b - 1) & 0xff
                    if self.b: self.pc = (self.pc + (d ^ 0x80) - 0x80) & 0xffff; t = 13
                    else: t = 8
                else:
                    d = self.fetch()
                    if y == 3 or self.cond(y - 4):
                        self.pc = (self.pc + (d ^ 0x80) - 0x80) & 0xffff; t = 12
                    else: t = 7
            elif z == 1:
                if q == 0: self.wrp(p, self.fetch16()); t = 10
                else:
                    hl = self.rp(2); v = self.rp(p); r = hl + v
                    self.f = (self.f & (SF | ZF | PF)) | (CF if r > 0xffff else 0) | (((hl ^ v ^ r) >> 8) & HF)
                    self.wrp(2, r); t = 11
            elif z == 2:
                if p == 0 and q == 0: self.m.wr(self.rp(0), self.a); t = 7
                elif p == 1 and q == 0: self.m.wr(self.rp(1), self.a); t = 7
                elif p == 0: self.a = self.m.rd(self.rp(0)); t = 7
                elif p == 1: self.a = self.m.rd(self.rp(1)); t = 7
                elif p == 2:
                    a = self.fetch16()
                    if q == 0: self.m.wr(a, self.l); self.m.wr((a + 1) & 0xffff, self.h)
                    else: self.l = self.m.rd(a); self.h = self.m.rd((a + 1) & 0xffff)
                    t = 16
                else:
                    a = self.fetch16()
                    if q == 0: self.m.wr(a, self.a)
                    else: self.a = self.m.rd(a)
                    t = 13
            elif z == 3:
                self.wrp(p, self.rp(p) + (1 if q == 0 else -1)); t = 6
            elif z in (4, 5):
                v = self.r8(y)
                r = (v + 1) & 0xff if z == 4 else (v - 1) & 0xff
                f = (self.f & CF) | (r & 0x80) | (0 if r else ZF)
                if z == 4:
                    f |= HF if (v & 0xf) == 0xf else 0
                    f |= PF if v == 0x7f else 0
                else:
                    f |= NF | (HF if (v & 0xf) == 0 else 0)
                    f |= PF if v == 0x80 else 0
                self.f = f; self.w8(y, r); t = 11 if y == 6 else 4
            elif z == 6:
                self.w8(y, self.fetch()); t = 10 if y == 6 else 7
            else:
                a = self.a; f = self.f
                if y == 0: c = a >> 7; self.a = (a << 1 | c) & 0xff; self.f = (f & (SF|ZF|PF)) | c
                elif y == 1: c = a & 1; self.a = (a >> 1 | c << 7); self.f = (f & (SF|ZF|PF)) | c
                elif y == 2: c = a >> 7; self.a = (a << 1 | (f & CF)) & 0xff; self.f = (f & (SF|ZF|PF)) | c
                elif y == 3: c = a & 1; self.a = (a >> 1 | (f & CF) << 7); self.f = (f & (SF|ZF|PF)) | c
                elif y == 4: raise Exception('DAA')
                elif y == 5: self.a = a ^ 0xff; self.f = f | HF | NF
                elif y == 6: self.f = (f & (SF|ZF|PF)) | CF
                else: self.f = (f & (SF|ZF|PF)) | ((f & CF) ^ CF) | ((f & CF) << 4)
        else:  # x == 3
            if z == 0:
                if self.cond(y): self.pc = self.pop(); t = 11
                else: t = 5
            elif z == 1:
                if q == 0:
                    v = self.pop()
                    if p == 3: self.a, self.f = v >> 8, v & 0xff
                    else: self.wrp(p, v)
                    t = 10
                elif p == 0: self.pc = self.pop(); t = 10
                elif p == 1:
                    for i, n in enumerate('bcdehl'):
                        cur = getattr(self, n); setattr(self, n, self.alt[i]); self.alt[i] = cur
                elif p == 2: self.pc = self.rp(2)
                else: self.sp = self.rp(2); t = 6
            elif z == 2:
                a = self.fetch16(); t = 10
                if self.cond(y): self.pc = a
            elif z == 3:
                if y == 0: self.pc = self.fetch16(); t = 10
                elif y == 1: t = self.cb()
                elif y == 2: self.m.out(self.fetch(), self.a); t = 11
                elif y == 3: self.a = self.m.inp(self.fetch()); t = 11
                elif y == 4:
                    lo = self.m.rd(self.sp); hi = self.m.rd((self.sp + 1) & 0xffff)
                    self.m.wr(self.sp, self.l); self.m.wr((self.sp + 1) & 0xffff, self.h)
                    self.h, self.l = hi, lo; t = 19
                elif y == 5:
                    self.d, self.h = self.h, self.d; self.e, self.l = self.l, self.e
                elif y == 6: pass  # DI
                else: pass  # EI
            elif z == 4:
                a = self.fetch16()
                if self.cond(y): self.push(self.pc); self.pc = a; t = 17
                else: t = 10
            elif z == 5:
                if q == 0:
                    v = (self.a << 8 | self.f) if p == 3 else self.rp(p)
                    self.push(v); t = 11
                elif p == 0:
                    a = self.fetch16(); self.push(self.pc); self.pc = a; t = 17
                elif p == 2: t = self.ed()
                else: raise Exception('IX/IY prefix at %04X' % (self.pc - 1))
            elif z == 6:
                self.alu(y, self.fetch()); t = 7
            else:
                self.push(self.pc); self.pc = y * 8; t = 11
        self.t += t
        self.m.cycles = self.t

    def cb(self):
        op = self.fetch()
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        v = self.r8(z)
        t = 15 if z == 6 else 8
        if x == 0:
            c = self.f & CF
            if y == 0: co = v >> 7; r = (v << 1 | co) & 0xff
            elif y == 1: co = v & 1; r = v >> 1 | co << 7
            elif y == 2: co = v >> 7; r = (v << 1 | c) & 0xff
            elif y == 3: co = v & 1; r = v >> 1 | c << 7
            elif y == 4: co = v >> 7; r = (v << 1) & 0xff
            elif y == 5: co = v & 1; r = (v >> 1) | (v & 0x80)
            elif y == 6: co = v >> 7; r = (v << 1 | 1) & 0xff
            else: co = v & 1; r = v >> 1
            self.f = (r & 0x80) | (0 if r else ZF) | PARITY[r] | co
            self.w8(z, r)
        elif x == 1:
            self.f = (self.f & CF) | HF | (0 if v & (1 << y) else ZF | PF) | (v & 0x80 if y == 7 else 0)
            t = 12 if z == 6 else 8
        elif x == 2: self.w8(z, v & ~(1 << y))
        else: self.w8(z, v | (1 << y))
        return t

    def ed(self):
        op = self.fetch()
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        p, q = y >> 1, y & 1
        if x == 1:
            if z == 0:
                v = self.m.inp(self.c)
                if y != 6: self.w8(y, v)
                self.f = (self.f & CF) | (v & 0x80) | (0 if v else ZF) | PARITY[v]; return 12
            if z == 1: self.m.out(self.c, self.r8(y) if y != 6 else 0); return 12
            if z == 2:
                hl = self.rp(2); v = self.rp(p); c = self.f & CF
                if q == 0:
                    r = hl - v - c
                    f = NF | (CF if r < 0 else 0)
                    f |= PF if ((hl ^ v) & (hl ^ r) & 0x8000) else 0
                else:
                    r = hl + v + c
                    f = CF if r > 0xffff else 0
                    f |= PF if (~(hl ^ v) & (hl ^ r) & 0x8000) else 0
                r &= 0xffff
                f |= (r >> 8) & 0x80 | (0 if r else ZF) | (((hl ^ v ^ r) >> 8) & HF)
                self.f = f; self.wrp(2, r); return 15
            if z == 3:
                a = self.fetch16()
                if q == 0:
                    v = self.rp(p); self.m.wr(a, v & 0xff); self.m.wr((a + 1) & 0xffff, v >> 8)
                else:
                    self.wrp(p, self.m.rd(a) | self.m.rd((a + 1) & 0xffff) << 8)
                return 20
            if z == 4:
                v = self.a; self.a = 0; self.alu(2, v); return 8
            if z == 5: self.pc = self.pop(); return 14
            if z == 6: return 8
        if x == 2 and z == 0 and y >= 4:
            # LDI LDD LDIR LDDR
            inc = 1 if y in (4, 6) else -1
            rep = y >= 6
            t = 0
            while True:
                hl = self.rp(2); de = self.rp(1); bc = self.rp(0)
                self.m.wr(de, self.m.rd(hl))
                self.wrp(2, hl + inc); self.wrp(1, de + inc); bc = (bc - 1) & 0xffff; self.wrp(0, bc)
                t += 21
                if not rep or bc == 0: break
            self.f = (self.f & (SF | ZF | CF)) | (PF if bc else 0)
            return t - 5
        raise Exception('unknown ED %02X at %04X' % (op, self.pc - 2))
