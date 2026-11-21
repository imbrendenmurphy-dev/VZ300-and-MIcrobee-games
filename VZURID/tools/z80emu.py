#!/usr/bin/env python3
"""Compact Z80 emulator with T-state counting (documented instruction set,
IX/IY with displacements, and IXH/IXL/IYH/IYL halves).  Written for verifying
VZ300 code: it counts T-states exactly per the Zilog tables (no wait states)."""

PARITY = [bin(i).count('1') % 2 == 0 for i in range(256)]


class Z80:
    def __init__(self):
        self.mem = bytearray(65536)
        self.a = self.f = self.b = self.c = self.d = self.e = self.h = self.l = 0
        self.a2 = self.f2 = self.b2 = self.c2 = self.d2 = self.e2 = self.h2 = self.l2 = 0
        self.ix = self.iy = 0
        self.sp = 0xFFFF
        self.pc = 0
        self.i = self.r = 0
        self.iff = False
        self.halted = False
        self.t = 0                   # total T-states
        self.on_read = None          # fn(addr, cpu) -> byte or None
        self.on_write = None         # fn(addr, val, cpu)
        self.on_in = None
        self.on_out = None
        self.pending_t = 0

    # ---- memory ----
    def rb(self, a):
        a &= 0xFFFF
        if self.on_read:
            v = self.on_read(a, self)
            if v is not None:
                return v
        return self.mem[a]

    def wb(self, a, v):
        a &= 0xFFFF
        if self.on_write:
            if self.on_write(a, v & 255, self) is False:
                return
        self.mem[a] = v & 255

    def rw(self, a):
        return self.rb(a) | self.rb(a + 1) << 8

    def ww(self, a, v):
        self.wb(a, v & 255)
        self.wb(a + 1, v >> 8)

    def fetch(self):
        v = self.rb(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetchw(self):
        lo = self.fetch()
        return lo | self.fetch() << 8

    # ---- register pair helpers ----
    @property
    def bc(self): return self.b << 8 | self.c
    @bc.setter
    def bc(self, v): self.b, self.c = v >> 8 & 255, v & 255
    @property
    def de(self): return self.d << 8 | self.e
    @de.setter
    def de(self, v): self.d, self.e = v >> 8 & 255, v & 255
    @property
    def hl(self): return self.h << 8 | self.l
    @hl.setter
    def hl(self, v): self.h, self.l = v >> 8 & 255, v & 255
    @property
    def af(self): return self.a << 8 | self.f
    @af.setter
    def af(self, v): self.a, self.f = v >> 8 & 255, v & 255

    def push(self, v):
        self.sp = (self.sp - 1) & 0xFFFF
        self.wb(self.sp, v >> 8)
        self.sp = (self.sp - 1) & 0xFFFF
        self.wb(self.sp, v & 255)

    def pop(self):
        v = self.rb(self.sp) | self.rb(self.sp + 1) << 8
        self.sp = (self.sp + 2) & 0xFFFF
        return v

    # ---- flags ----
    S, Z, Y, H, X, PV, N, C = 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01

    def szp(self, v):
        v &= 255
        return (v & 0xA8) | (0x40 if v == 0 else 0) | (0x04 if PARITY[v] else 0)

    def alu(self, op, v):
        a = self.a
        if op == 0 or op == 1:   # ADD/ADC
            cy = (self.f & 1) if op == 1 else 0
            r = a + v + cy
            f = (r & 0xA8) | (0x40 if (r & 255) == 0 else 0)
            f |= 0x10 if (a & 15) + (v & 15) + cy > 15 else 0
            f |= 0x04 if (~(a ^ v) & (a ^ r) & 0x80) else 0
            f |= 1 if r > 255 else 0
            self.a = r & 255
            self.f = f
        elif op in (2, 3, 7):    # SUB/SBC/CP
            cy = (self.f & 1) if op == 3 else 0
            r = a - v - cy
            f = (r & 0x80) | (0x40 if (r & 255) == 0 else 0) | 2
            f |= 0x10 if (a & 15) - (v & 15) - cy < 0 else 0
            f |= 0x04 if ((a ^ v) & (a ^ r) & 0x80) else 0
            f |= 1 if r < 0 else 0
            if op == 7:
                f = (f & ~0x28) | (v & 0x28)
            else:
                f |= r & 0x28
                self.a = r & 255
            self.f = f
        elif op == 4:
            self.a = a & v
            self.f = self.szp(self.a) | 0x10
        elif op == 5:
            self.a = a ^ v
            self.f = self.szp(self.a)
        else:
            self.a = a | v
            self.f = self.szp(self.a)

    def inc8(self, v):
        r = (v + 1) & 255
        self.f = (self.f & 1) | (r & 0xA8) | (0x40 if r == 0 else 0) | (0x10 if (v & 15) == 15 else 0) | (0x04 if v == 0x7F else 0)
        return r

    def dec8(self, v):
        r = (v - 1) & 255
        self.f = (self.f & 1) | (r & 0xA8) | (0x40 if r == 0 else 0) | (0x10 if (v & 15) == 0 else 0) | (0x04 if v == 0x80 else 0) | 2
        return r

    def rot(self, op, v):
        c = self.f & 1
        if op == 0:
            c = v >> 7; v = (v << 1 | c) & 255
        elif op == 1:
            c = v & 1; v = (v >> 1 | c << 7) & 255
        elif op == 2:
            n = v >> 7; v = (v << 1 | c) & 255; c = n
        elif op == 3:
            n = v & 1; v = (v >> 1 | c << 7) & 255; c = n
        elif op == 4:
            c = v >> 7; v = (v << 1) & 255
        elif op == 5:
            c = v & 1; v = (v >> 1 | v & 0x80) & 255
        elif op == 6:
            c = v >> 7; v = (v << 1 | 1) & 255
        else:
            c = v & 1; v = v >> 1
        self.f = self.szp(v) | c
        return v

    def add16(self, a, b):
        r = a + b
        self.f = (self.f & 0xC4) | (r >> 8 & 0x28) | (0x10 if (a & 0xFFF) + (b & 0xFFF) > 0xFFF else 0) | (1 if r > 0xFFFF else 0)
        return r & 0xFFFF

    def adc16(self, a, b):
        cy = self.f & 1
        r = a + b + cy
        f = (r >> 8 & 0xA8) | (0x40 if (r & 0xFFFF) == 0 else 0)
        f |= 0x10 if (a & 0xFFF) + (b & 0xFFF) + cy > 0xFFF else 0
        f |= 0x04 if (~(a ^ b) & (a ^ r) & 0x8000) else 0
        f |= 1 if r > 0xFFFF else 0
        self.f = f
        return r & 0xFFFF

    def sbc16(self, a, b):
        cy = self.f & 1
        r = a - b - cy
        f = (r >> 8 & 0xA8) | (0x40 if (r & 0xFFFF) == 0 else 0) | 2
        f |= 0x10 if (a & 0xFFF) - (b & 0xFFF) - cy < 0 else 0
        f |= 0x04 if ((a ^ b) & (a ^ r) & 0x8000) else 0
        f |= 1 if r < 0 else 0
        self.f = f
        return r & 0xFFFF

    def cond(self, cc):
        f = self.f
        return [not f & 0x40, bool(f & 0x40), not f & 1, bool(f & 1),
                not f & 4, bool(f & 4), not f & 0x80, bool(f & 0x80)][cc]

    # ---- 8-bit register access by code (with IX/IY half substitution) ----
    def getr(self, r, pre=None):
        if r == 0: return self.b
        if r == 1: return self.c
        if r == 2: return self.d
        if r == 3: return self.e
        if r == 4: return (self.ix if pre == 'x' else self.iy) >> 8 if pre else self.h
        if r == 5: return (self.ix if pre == 'x' else self.iy) & 255 if pre else self.l
        if r == 7: return self.a
        raise ValueError

    def setr(self, r, v, pre=None):
        v &= 255
        if r == 0: self.b = v
        elif r == 1: self.c = v
        elif r == 2: self.d = v
        elif r == 3: self.e = v
        elif r == 4:
            if pre == 'x': self.ix = self.ix & 255 | v << 8
            elif pre == 'y': self.iy = self.iy & 255 | v << 8
            else: self.h = v
        elif r == 5:
            if pre == 'x': self.ix = self.ix & 0xFF00 | v
            elif pre == 'y': self.iy = self.iy & 0xFF00 | v
            else: self.l = v
        elif r == 7: self.a = v

    def rp(self, p):
        return (self.bc, self.de, self.hl, self.sp)[p]

    def setrp(self, p, v):
        v &= 0xFFFF
        if p == 0: self.bc = v
        elif p == 1: self.de = v
        elif p == 2: self.hl = v
        else: self.sp = v

    # ---- main step ----
    def step(self):
        """Execute one instruction; returns T-states used."""
        t0 = self.t
        self.r = (self.r + 1) & 127 | self.r & 128
        op = self.fetch()
        pre = None
        if op in (0xDD, 0xFD):
            pre = 'x' if op == 0xDD else 'y'
            op = self.fetch()
            self.r = (self.r + 1) & 127 | self.r & 128
            self.t += 4
            if op in (0xDD, 0xFD, 0xED):
                self.pc = (self.pc - 1) & 0xFFFF
                return self.t - t0 if False else self.finish(t0)
        if op == 0xCB:
            self.do_cb(pre)
        elif op == 0xED and pre is None:
            self.do_ed()
        else:
            self.do_main(op, pre)
        return self.finish(t0)

    def finish(self, t0):
        return self.t - t0

    def ixd(self, pre):
        d = self.fetch()
        if d > 127:
            d -= 256
        base = self.ix if pre == 'x' else self.iy
        return (base + d) & 0xFFFF

    def do_main(self, op, pre):
        x, y, z = op >> 6, op >> 3 & 7, op & 7
        p, q = y >> 1, y & 1
        ixy = (lambda: self.ix) if pre == 'x' else (lambda: self.iy)

        def get_hl():
            if pre is None: return self.hl
            return self.ix if pre == 'x' else self.iy

        def set_hl(v):
            v &= 0xFFFF
            if pre is None: self.hl = v
            elif pre == 'x': self.ix = v
            else: self.iy = v

        def rp_(pp):
            return get_hl() if pp == 2 else self.rp(pp)

        def setrp_(pp, v):
            if pp == 2: set_hl(v)
            else: self.setrp(pp, v)

        if x == 1:
            if op == 0x76:
                self.halted = True
                self.t += 4
                return
            # LD r,r'
            if pre and (y == 6 or z == 6):
                addr = self.ixd(pre)
                if y == 6:
                    self.wb(addr, self.getr(z))
                else:
                    self.setr(y, self.rb(addr))
                self.t += 15
                return
            if y == 6:
                self.wb(self.hl, self.getr(z, pre)); self.t += 7
            elif z == 6:
                self.setr(y, self.rb(self.hl)); self.t += 7
            else:
                self.setr(y, self.getr(z, pre), pre); self.t += 4
            return
        if x == 2:
            if z == 6:
                if pre:
                    v = self.rb(self.ixd(pre)); self.t += 15
                else:
                    v = self.rb(self.hl); self.t += 7
            else:
                v = self.getr(z, pre); self.t += 4
            self.alu(y, v)
            return
        if x == 0:
            if z == 0:
                if y == 0: self.t += 4
                elif y == 1:
                    self.a, self.a2 = self.a2, self.a
                    self.f, self.f2 = self.f2, self.f
                    self.t += 4
                elif y == 2:
                    d = self.fetch(); d = d - 256 if d > 127 else d
                    self.b = (self.b - 1) & 255
                    if self.b:
                        self.pc = (self.pc + d) & 0xFFFF; self.t += 13
                    else: self.t += 8
                elif y == 3:
                    d = self.fetch(); d = d - 256 if d > 127 else d
                    self.pc = (self.pc + d) & 0xFFFF; self.t += 12
                else:
                    d = self.fetch(); d = d - 256 if d > 127 else d
                    if self.cond(y - 4):
                        self.pc = (self.pc + d) & 0xFFFF; self.t += 12
                    else: self.t += 7
            elif z == 1:
                if q == 0:
                    setrp_(p, self.fetchw()); self.t += 10
                else:
                    set_hl(self.add16(get_hl(), rp_(p))); self.t += 11
            elif z == 2:
                if q == 0:
                    if p == 0: self.wb(self.bc, self.a); self.t += 7
                    elif p == 1: self.wb(self.de, self.a); self.t += 7
                    elif p == 2: self.ww(self.fetchw(), get_hl()); self.t += 16
                    else: self.wb(self.fetchw(), self.a); self.t += 13
                else:
                    if p == 0: self.a = self.rb(self.bc); self.t += 7
                    elif p == 1: self.a = self.rb(self.de); self.t += 7
                    elif p == 2: set_hl(self.rw(self.fetchw())); self.t += 16
                    else: self.a = self.rb(self.fetchw()); self.t += 13
            elif z == 3:
                v = rp_(p)
                setrp_(p, v + 1 if q == 0 else v - 1); self.t += 6
            elif z == 4 or z == 5:
                fn = self.inc8 if z == 4 else self.dec8
                if y == 6:
                    if pre:
                        a = self.ixd(pre); self.wb(a, fn(self.rb(a))); self.t += 19
                    else:
                        self.wb(self.hl, fn(self.rb(self.hl))); self.t += 11
                else:
                    self.setr(y, fn(self.getr(y, pre)), pre); self.t += 4
            elif z == 6:
                if y == 6:
                    if pre:
                        a = self.ixd(pre); self.wb(a, self.fetch()); self.t += 15
                    else:
                        self.wb(self.hl, self.fetch()); self.t += 10
                else:
                    self.setr(y, self.fetch(), pre); self.t += 7
            else:
                a = self.a
                if y == 0:
                    c = a >> 7; self.a = (a << 1 | c) & 255
                    self.f = self.f & 0xC4 | self.a & 0x28 | c
                elif y == 1:
                    c = a & 1; self.a = (a >> 1 | c << 7) & 255
                    self.f = self.f & 0xC4 | self.a & 0x28 | c
                elif y == 2:
                    c = a >> 7; self.a = (a << 1 | self.f & 1) & 255
                    self.f = self.f & 0xC4 | self.a & 0x28 | c
                elif y == 3:
                    c = a & 1; self.a = (a >> 1 | (self.f & 1) << 7) & 255
                    self.f = self.f & 0xC4 | self.a & 0x28 | c
                elif y == 4:
                    r = 0; c = self.f & 1
                    if (a & 15) > 9 or self.f & 0x10: r |= 6
                    if a > 0x99 or c: r |= 0x60; c = 1
                    if self.f & 2:
                        h = 0x10 if self.f & 0x10 and (a & 15) < 6 else 0
                        a = (a - r) & 255
                    else:
                        h = 0x10 if (a & 15) > 9 else 0
                        a = (a + r) & 255
                    self.a = a
                    self.f = self.szp(a) | (self.f & 2) | h | c
                elif y == 5:
                    self.a = a ^ 255
                    self.f = self.f & 0xC5 | 0x12 | self.a & 0x28
                elif y == 6:
                    self.f = self.f & 0xC4 | 1 | a & 0x28
                else:
                    self.f = self.f & 0xC4 | (0x10 if self.f & 1 else 0) | (0 if self.f & 1 else 1) | a & 0x28
                self.t += 4
            return
        # x == 3
        if z == 0:
            self.t += 5
            if self.cond(y):
                self.pc = self.pop(); self.t += 6
        elif z == 1:
            if q == 0:
                v = self.pop()
                if p == 3: self.af = v
                elif p == 2: set_hl(v)
                else: self.setrp(p, v)
                self.t += 10
            else:
                if p == 0: self.pc = self.pop(); self.t += 10
                elif p == 1:
                    self.b, self.b2 = self.b2, self.b; self.c, self.c2 = self.c2, self.c
                    self.d, self.d2 = self.d2, self.d; self.e, self.e2 = self.e2, self.e
                    self.h, self.h2 = self.h2, self.h; self.l, self.l2 = self.l2, self.l
                    self.t += 4
                elif p == 2: self.pc = get_hl(); self.t += 4
                else: self.sp = get_hl(); self.t += 6
        elif z == 2:
            a = self.fetchw()
            if self.cond(y): self.pc = a
            self.t += 10
        elif z == 3:
            if y == 0: self.pc = self.fetchw(); self.t += 10
            elif y == 2:
                port = self.fetch() | self.a << 8
                if self.on_out: self.on_out(port, self.a, self)
                self.t += 11
            elif y == 3:
                port = self.fetch() | self.a << 8
                self.a = self.on_in(port, self) if self.on_in else 0xFF
                self.t += 11
            elif y == 4:
                v = self.rw(self.sp); self.ww(self.sp, get_hl()); set_hl(v); self.t += 19
            elif y == 5:
                v = self.de; self.de = self.hl; self.hl = v; self.t += 4
            elif y == 6: self.iff = False; self.t += 4
            elif y == 7: self.iff = True; self.t += 4
        elif z == 4:
            a = self.fetchw()
            if self.cond(y):
                self.push(self.pc); self.pc = a; self.t += 17
            else: self.t += 10
        elif z == 5:
            if q == 0:
                v = self.af if p == 3 else (get_hl() if p == 2 else self.rp(p))
                self.push(v); self.t += 11
            elif p == 0:
                a = self.fetchw(); self.push(self.pc); self.pc = a; self.t += 17
        elif z == 6:
            self.alu(y, self.fetch()); self.t += 7
        else:
            self.push(self.pc); self.pc = y * 8; self.t += 11

    def do_cb(self, pre):
        if pre:
            addr = self.ixd(pre)
            op = self.fetch()
            x, y, z = op >> 6, op >> 3 & 7, op & 7
            v = self.rb(addr)
            if x == 0:
                r = self.rot(y, v); self.wb(addr, r)
                if z != 6: self.setr(z, r)
                self.t += 19
            elif x == 1:
                r = v & (1 << y)
                self.f = self.f & 1 | 0x10 | (0x40 | 4 if r == 0 else 0) | (0x80 if r & 0x80 else 0) | (addr >> 8 & 0x28)
                self.t += 16
            else:
                r = v & ~(1 << y) if x == 2 else v | 1 << y
                self.wb(addr, r)
                if z != 6: self.setr(z, r)
                self.t += 19
            return
        self.r = (self.r + 1) & 127 | self.r & 128
        op = self.fetch()
        x, y, z = op >> 6, op >> 3 & 7, op & 7
        v = self.rb(self.hl) if z == 6 else self.getr(z)
        if x == 0:
            r = self.rot(y, v)
            if z == 6: self.wb(self.hl, r); self.t += 15
            else: self.setr(z, r); self.t += 8
        elif x == 1:
            r = v & (1 << y)
            self.f = self.f & 1 | 0x10 | (0x44 if r == 0 else 0) | (0x80 if r & 0x80 else 0) | (v & 0x28)
            self.t += 12 if z == 6 else 8
        else:
            r = v & ~(1 << y) if x == 2 else v | 1 << y
            if z == 6: self.wb(self.hl, r); self.t += 15
            else: self.setr(z, r); self.t += 8

    def do_ed(self):
        self.r = (self.r + 1) & 127 | self.r & 128
        op = self.fetch()
        x, y, z = op >> 6, op >> 3 & 7, op & 7
        p, q = y >> 1, y & 1
        if x == 1:
            if z == 0:
                v = self.on_in(self.bc, self) if self.on_in else 0xFF
                if y != 6: self.setr(y, v)
                self.f = self.f & 1 | self.szp(v); self.t += 12
            elif z == 1:
                if self.on_out: self.on_out(self.bc, self.getr(y) if y != 6 else 0, self)
                self.t += 12
            elif z == 2:
                if q == 0: self.hl = self.sbc16(self.hl, self.rp(p))
                else: self.hl = self.adc16(self.hl, self.rp(p))
                self.t += 15
            elif z == 3:
                a = self.fetchw()
                if q == 0: self.ww(a, self.rp(p))
                else: self.setrp(p, self.rw(a))
                self.t += 20
            elif z == 4:
                v = self.a; self.a = 0; self.alu(2, v); self.t += 8
            elif z == 5:
                self.pc = self.pop(); self.t += 14
            elif z == 6:
                self.t += 8
            else:
                if y == 0: self.i = self.a; self.t += 9
                elif y == 1: self.r = self.a; self.t += 9
                elif y == 2:
                    self.a = self.i; self.f = self.f & 1 | self.szp(self.a) & 0xE8 | (4 if self.iff else 0); self.t += 9
                elif y == 3:
                    self.a = self.r; self.f = self.f & 1 | self.szp(self.a) & 0xE8 | (4 if self.iff else 0); self.t += 9
                elif y == 4:
                    m = self.rb(self.hl); n = self.a
                    self.wb(self.hl, (self.a & 0xF0 | m >> 4) if False else (n << 4 & 0xF0 | m >> 4))
                    self.a = n & 0xF0 | m & 15
                    self.f = self.f & 1 | self.szp(self.a); self.t += 18
                elif y == 5:
                    m = self.rb(self.hl); n = self.a
                    self.wb(self.hl, (m << 4 & 0xF0) | n & 15)
                    self.a = n & 0xF0 | m >> 4
                    self.f = self.f & 1 | self.szp(self.a); self.t += 18
                else: self.t += 8
            return
        if x == 2 and z <= 3 and y >= 4:
            if z == 0:      # LDI/LDD/LDIR/LDDR
                self.wb(self.de, self.rb(self.hl))
                d = 1 if y in (4, 6) else -1
                self.hl += d; self.de += d
                self.hl &= 0xFFFF; self.de &= 0xFFFF
                self.bc = (self.bc - 1) & 0xFFFF
                self.f = self.f & 0xC1 | (4 if self.bc else 0)
                if y >= 6 and self.bc:
                    self.pc = (self.pc - 2) & 0xFFFF; self.t += 21
                else: self.t += 16
            elif z == 1:    # CPI family
                v = self.rb(self.hl)
                r = (self.a - v) & 255
                d = 1 if y in (4, 6) else -1
                self.hl = (self.hl + d) & 0xFFFF
                self.bc = (self.bc - 1) & 0xFFFF
                self.f = self.f & 1 | 2 | (r & 0x80) | (0x40 if r == 0 else 0) | (4 if self.bc else 0) | (0x10 if (self.a & 15) < (v & 15) else 0)
                if y >= 6 and self.bc and r:
                    self.pc = (self.pc - 2) & 0xFFFF; self.t += 21
                else: self.t += 16
            elif z == 2:    # INI family
                v = self.on_in(self.bc, self) if self.on_in else 0xFF
                self.wb(self.hl, v)
                self.hl = (self.hl + (1 if y in (4, 6) else -1)) & 0xFFFF
                self.b = (self.b - 1) & 255
                self.f = self.f & 1 | 2 | (0x40 if self.b == 0 else 0)
                if y >= 6 and self.b:
                    self.pc = (self.pc - 2) & 0xFFFF; self.t += 21
                else: self.t += 16
            else:           # OUTI family
                v = self.rb(self.hl)
                self.b = (self.b - 1) & 255
                if self.on_out: self.on_out(self.bc, v, self)
                self.hl = (self.hl + (1 if y in (4, 6) else -1)) & 0xFFFF
                self.f = self.f & 1 | 2 | (0x40 if self.b == 0 else 0)
                if y >= 6 and self.b:
                    self.pc = (self.pc - 2) & 0xFFFF; self.t += 21
                else: self.t += 16
            return
        self.t += 8   # NOP-like undefined ED opcode
