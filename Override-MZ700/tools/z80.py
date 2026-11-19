"""z80.py - a straightforward Z80 interpreter with T-state counting (stdlib only).

Good enough for testing game code: all documented instructions, IX/IY with the
undocumented half registers, DDCB/FDCB, and the common ED instructions.
Undocumented flag bits 3 and 5 are not modelled.
"""

SF, ZF, HF, PF, NF, CF = 0x80, 0x40, 0x10, 0x04, 0x02, 0x01

SZ = [0] * 256
SZP = [0] * 256
for _i in range(256):
    _s = (SF if _i & 0x80 else 0) | (ZF if _i == 0 else 0)
    SZ[_i] = _s
    SZP[_i] = _s | (PF if bin(_i).count('1') % 2 == 0 else 0)


class Z80:
    def __init__(self, mem, io_read=None, io_write=None, mem_read=None, mem_write=None):
        self.mem = mem                    # bytearray(65536)
        self.mem_read_hook = mem_read     # f(addr) -> value or None
        self.mem_write_hook = mem_write   # f(addr, value) -> True if handled
        self.io_read = io_read or (lambda port: 0xFF)
        self.io_write = io_write or (lambda port, v: None)
        self.a = self.f = self.b = self.c = self.d = self.e = self.h = self.l = 0
        self.a_ = self.f_ = self.b_ = self.c_ = self.d_ = self.e_ = self.h_ = self.l_ = 0
        self.ix = self.iy = 0xFFFF
        self.sp = 0xFFFF
        self.pc = 0
        self.i = self.r = 0
        self.iff1 = self.iff2 = 0
        self.im = 0
        self.halted = False
        self.t = 0

    # ------------------------------------------------------------- memory
    def rb(self, a):
        if self.mem_read_hook is not None:
            v = self.mem_read_hook(a)
            if v is not None:
                return v
        return self.mem[a]

    def wb(self, a, v):
        if self.mem_write_hook is not None and self.mem_write_hook(a, v):
            return
        self.mem[a] = v

    def rw(self, a):
        return self.rb(a) | (self.rb((a + 1) & 0xFFFF) << 8)

    def ww(self, a, v):
        self.wb(a, v & 0xFF)
        self.wb((a + 1) & 0xFFFF, (v >> 8) & 0xFF)

    def fetch(self):
        v = self.rb(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetchw(self):
        lo = self.fetch()
        return lo | (self.fetch() << 8)

    def fetchd(self):
        d = self.fetch()
        return d - 256 if d > 127 else d

    def push(self, v):
        self.sp = (self.sp - 2) & 0xFFFF
        self.ww(self.sp, v)

    def pop(self):
        v = self.rw(self.sp)
        self.sp = (self.sp + 2) & 0xFFFF
        return v

    # ------------------------------------------------------------- pairs
    def get_bc(self): return (self.b << 8) | self.c
    def get_de(self): return (self.d << 8) | self.e
    def get_hl(self): return (self.h << 8) | self.l
    def get_af(self): return (self.a << 8) | self.f

    def set_bc(self, v): self.b = (v >> 8) & 0xFF; self.c = v & 0xFF
    def set_de(self, v): self.d = (v >> 8) & 0xFF; self.e = v & 0xFF
    def set_hl(self, v): self.h = (v >> 8) & 0xFF; self.l = v & 0xFF
    def set_af(self, v): self.a = (v >> 8) & 0xFF; self.f = v & 0xFF

    # 8-bit register access by index (6 = (HL) handled by caller)
    def g8(self, r):
        if r == 0: return self.b
        if r == 1: return self.c
        if r == 2: return self.d
        if r == 3: return self.e
        if r == 4: return self.h
        if r == 5: return self.l
        if r == 6: return self.rb(self.get_hl())
        return self.a

    def s8(self, r, v):
        if r == 0: self.b = v
        elif r == 1: self.c = v
        elif r == 2: self.d = v
        elif r == 3: self.e = v
        elif r == 4: self.h = v
        elif r == 5: self.l = v
        elif r == 6: self.wb(self.get_hl(), v)
        else: self.a = v

    def g16(self, p):  # BC DE HL SP
        if p == 0: return self.get_bc()
        if p == 1: return self.get_de()
        if p == 2: return self.get_hl()
        return self.sp

    def s16(self, p, v):
        if p == 0: self.set_bc(v)
        elif p == 1: self.set_de(v)
        elif p == 2: self.set_hl(v)
        else: self.sp = v & 0xFFFF

    # ------------------------------------------------------------- ALU
    def alu(self, op, v):
        a = self.a
        if op == 0 or op == 1:  # ADD / ADC
            c = 1 if (op == 1 and self.f & CF) else 0
            r = a + v + c
            f = SZ[r & 0xFF] | (HF if ((a & 0xF) + (v & 0xF) + c) & 0x10 else 0)
            if ((a ^ ~v) & (a ^ r)) & 0x80: f |= PF
            if r > 0xFF: f |= CF
            self.a = r & 0xFF; self.f = f
        elif op == 2 or op == 3 or op == 7:  # SUB / SBC / CP
            c = 1 if (op == 3 and self.f & CF) else 0
            r = a - v - c
            f = SZ[r & 0xFF] | NF | (HF if ((a & 0xF) - (v & 0xF) - c) & 0x10 else 0)
            if ((a ^ v) & (a ^ r)) & 0x80: f |= PF
            if r < 0: f |= CF
            if op != 7: self.a = r & 0xFF
            self.f = f
        elif op == 4:
            self.a = a & v; self.f = SZP[self.a] | HF
        elif op == 5:
            self.a = a ^ v; self.f = SZP[self.a]
        else:
            self.a = a | v; self.f = SZP[self.a]

    def inc8(self, v):
        r = (v + 1) & 0xFF
        f = (self.f & CF) | SZ[r]
        if (v & 0xF) == 0xF: f |= HF
        if v == 0x7F: f |= PF
        self.f = f
        return r

    def dec8(self, v):
        r = (v - 1) & 0xFF
        f = (self.f & CF) | SZ[r] | NF
        if (v & 0xF) == 0: f |= HF
        if v == 0x80: f |= PF
        self.f = f
        return r

    def add16(self, a, b):
        r = a + b
        f = self.f & (SF | ZF | PF)
        if ((a & 0xFFF) + (b & 0xFFF)) & 0x1000: f |= HF
        if r > 0xFFFF: f |= CF
        self.f = f
        return r & 0xFFFF

    def adc16(self, a, b):
        c = self.f & CF
        r = a + b + c
        f = 0
        if (r & 0xFFFF) == 0: f |= ZF
        if r & 0x8000: f |= SF
        if ((a & 0xFFF) + (b & 0xFFF) + c) & 0x1000: f |= HF
        if ((a ^ ~b) & (a ^ r)) & 0x8000: f |= PF
        if r > 0xFFFF: f |= CF
        self.f = f
        return r & 0xFFFF

    def sbc16(self, a, b):
        c = self.f & CF
        r = a - b - c
        f = NF
        if (r & 0xFFFF) == 0: f |= ZF
        if r & 0x8000: f |= SF
        if ((a & 0xFFF) - (b & 0xFFF) - c) & 0x1000: f |= HF
        if ((a ^ b) & (a ^ r)) & 0x8000: f |= PF
        if r < 0: f |= CF
        self.f = f
        return r & 0xFFFF

    def rot(self, op, v):
        c = self.f & CF
        if op == 0:   # RLC
            co = v >> 7; v = ((v << 1) | co) & 0xFF
        elif op == 1:  # RRC
            co = v & 1; v = (v >> 1) | (co << 7)
        elif op == 2:  # RL
            co = v >> 7; v = ((v << 1) | c) & 0xFF
        elif op == 3:  # RR
            co = v & 1; v = (v >> 1) | (c << 7)
        elif op == 4:  # SLA
            co = v >> 7; v = (v << 1) & 0xFF
        elif op == 5:  # SRA
            co = v & 1; v = (v >> 1) | (v & 0x80)
        elif op == 6:  # SLL
            co = v >> 7; v = ((v << 1) | 1) & 0xFF
        else:          # SRL
            co = v & 1; v = v >> 1
        self.f = SZP[v] | co
        return v

    def cond(self, cc):
        f = self.f
        if cc == 0: return not (f & ZF)
        if cc == 1: return bool(f & ZF)
        if cc == 2: return not (f & CF)
        if cc == 3: return bool(f & CF)
        if cc == 4: return not (f & PF)
        if cc == 5: return bool(f & PF)
        if cc == 6: return not (f & SF)
        return bool(f & SF)

    # ------------------------------------------------------------- interrupts
    def interrupt(self, vector=0xFF):
        if not self.iff1:
            return False
        if self.halted:
            self.halted = False
            self.pc = (self.pc + 1) & 0xFFFF
        self.iff1 = self.iff2 = 0
        self.push(self.pc)
        if self.im == 2:
            self.pc = self.rw((self.i << 8) | (vector & 0xFE))
            self.t += 19
        else:
            self.pc = 0x38
            self.t += 13
        return True

    # ------------------------------------------------------------- step
    def step(self):
        if self.halted:
            self.t += 4
            return
        self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F)
        op = self.fetch()
        self.t += self.exec_main(op)

    def exec_main(self, op):
        x = op >> 6
        y = (op >> 3) & 7
        z = op & 7
        if x == 1:
            if op == 0x76:
                self.halted = True
                self.pc = (self.pc - 1) & 0xFFFF
                return 4
            self.s8(y, self.g8(z))
            return 7 if (y == 6 or z == 6) else 4
        if x == 2:
            self.alu(y, self.g8(z))
            return 7 if z == 6 else 4
        if x == 0:
            return self.exec_x0(op, y, z)
        return self.exec_x3(op, y, z)

    def exec_x0(self, op, y, z):
        p = y >> 1
        q = y & 1
        if z == 0:
            if y == 0: return 4
            if y == 1:
                self.a, self.a_ = self.a_, self.a
                self.f, self.f_ = self.f_, self.f
                return 4
            if y == 2:
                d = self.fetchd()
                self.b = (self.b - 1) & 0xFF
                if self.b:
                    self.pc = (self.pc + d) & 0xFFFF
                    return 13
                return 8
            d = self.fetchd()
            if y == 3 or self.cond(y - 4):
                self.pc = (self.pc + d) & 0xFFFF
                return 12
            return 7
        if z == 1:
            if q == 0:
                self.s16(p, self.fetchw())
                return 10
            self.set_hl(self.add16(self.get_hl(), self.g16(p)))
            return 11
        if z == 2:
            if y == 0: self.wb(self.get_bc(), self.a); return 7
            if y == 1: self.a = self.rb(self.get_bc()); return 7
            if y == 2: self.wb(self.get_de(), self.a); return 7
            if y == 3: self.a = self.rb(self.get_de()); return 7
            if y == 4: self.ww(self.fetchw(), self.get_hl()); return 16
            if y == 5: self.set_hl(self.rw(self.fetchw())); return 16
            if y == 6: self.wb(self.fetchw(), self.a); return 13
            self.a = self.rb(self.fetchw()); return 13
        if z == 3:
            v = self.g16(p)
            self.s16(p, (v + (1 if q == 0 else -1)) & 0xFFFF)
            return 6
        if z == 4:
            self.s8(y, self.inc8(self.g8(y)))
            return 11 if y == 6 else 4
        if z == 5:
            self.s8(y, self.dec8(self.g8(y)))
            return 11 if y == 6 else 4
        if z == 6:
            self.s8(y, self.fetch())
            return 10 if y == 6 else 7
        # z == 7
        a = self.a
        if y == 0:
            c = a >> 7; self.a = ((a << 1) | c) & 0xFF
            self.f = (self.f & (SF | ZF | PF)) | c
        elif y == 1:
            c = a & 1; self.a = (a >> 1) | (c << 7)
            self.f = (self.f & (SF | ZF | PF)) | c
        elif y == 2:
            c = a >> 7; self.a = ((a << 1) | (self.f & CF)) & 0xFF
            self.f = (self.f & (SF | ZF | PF)) | c
        elif y == 3:
            c = a & 1; self.a = (a >> 1) | ((self.f & CF) << 7)
            self.f = (self.f & (SF | ZF | PF)) | c
        elif y == 4:  # DAA
            corr = 0
            c = self.f & CF
            if (self.f & HF) or (a & 0xF) > 9: corr |= 0x06
            if c or a > 0x99: corr |= 0x60; c = CF
            if self.f & NF:
                h = HF if (self.f & HF) and (a & 0xF) < 6 else 0
                r = (a - corr) & 0xFF
            else:
                h = HF if (a & 0xF) > 9 else 0
                r = (a + corr) & 0xFF
            self.a = r
            self.f = SZP[r] | h | c | (self.f & NF)
        elif y == 5:
            self.a = a ^ 0xFF; self.f |= HF | NF
        elif y == 6:
            self.f = (self.f & (SF | ZF | PF)) | CF
        else:
            c = self.f & CF
            self.f = (self.f & (SF | ZF | PF)) | (HF if c else 0) | (0 if c else CF)
        return 4

    def exec_x3(self, op, y, z):
        p = y >> 1
        q = y & 1
        if z == 0:
            if self.cond(y):
                self.pc = self.pop(); return 11
            return 5
        if z == 1:
            if q == 0:
                v = self.pop()
                if p == 0: self.set_bc(v)
                elif p == 1: self.set_de(v)
                elif p == 2: self.set_hl(v)
                else: self.set_af(v)
                return 10
            if p == 0: self.pc = self.pop(); return 10
            if p == 1:
                self.b, self.b_ = self.b_, self.b
                self.c, self.c_ = self.c_, self.c
                self.d, self.d_ = self.d_, self.d
                self.e, self.e_ = self.e_, self.e
                self.h, self.h_ = self.h_, self.h
                self.l, self.l_ = self.l_, self.l
                return 4
            if p == 2: self.pc = self.get_hl(); return 4
            self.sp = self.get_hl(); return 6
        if z == 2:
            a = self.fetchw()
            if self.cond(y): self.pc = a
            return 10
        if z == 3:
            if y == 0: self.pc = self.fetchw(); return 10
            if y == 1:
                return self.exec_cb()
            if y == 2: self.io_write((self.a << 8) | self.fetch(), self.a); return 11
            if y == 3: self.a = self.io_read((self.a << 8) | self.fetch()); return 11
            if y == 4:
                v = self.rw(self.sp); self.ww(self.sp, self.get_hl()); self.set_hl(v); return 19
            if y == 5:
                self.d, self.h = self.h, self.d
                self.e, self.l = self.l, self.e
                return 4
            if y == 6: self.iff1 = self.iff2 = 0; return 4
            self.iff1 = self.iff2 = 1; return 4
        if z == 4:
            a = self.fetchw()
            if self.cond(y):
                self.push(self.pc); self.pc = a; return 17
            return 10
        if z == 5:
            if q == 0:
                if p == 0: v = self.get_bc()
                elif p == 1: v = self.get_de()
                elif p == 2: v = self.get_hl()
                else: v = self.get_af()
                self.push(v); return 11
            if p == 0:
                a = self.fetchw(); self.push(self.pc); self.pc = a; return 17
            if p == 1: return self.exec_index('ix')
            if p == 2: return self.exec_ed()
            return self.exec_index('iy')
        if z == 6:
            self.alu(y, self.fetch()); return 7
        self.push(self.pc); self.pc = y * 8; return 11

    def exec_cb(self):
        op = self.fetch()
        self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F)
        x = op >> 6; y = (op >> 3) & 7; z = op & 7
        v = self.g8(z)
        if x == 0:
            self.s8(z, self.rot(y, v))
            return 15 if z == 6 else 8
        if x == 1:
            r = v & (1 << y)
            self.f = (self.f & CF) | HF | (ZF | PF if not r else 0) | (SF if (y == 7 and r) else 0)
            return 12 if z == 6 else 8
        if x == 2:
            self.s8(z, v & ~(1 << y) & 0xFF)
        else:
            self.s8(z, v | (1 << y))
        return 15 if z == 6 else 8

    def exec_ed(self):
        op = self.fetch()
        self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F)
        x = op >> 6; y = (op >> 3) & 7; z = op & 7
        p = y >> 1; q = y & 1
        if x == 1:
            if z == 0:
                v = self.io_read(self.get_bc())
                if y != 6: self.s8(y, v)
                self.f = (self.f & CF) | SZP[v]
                return 12
            if z == 1:
                self.io_write(self.get_bc(), 0 if y == 6 else self.g8(y)); return 12
            if z == 2:
                if q == 0: self.set_hl(self.sbc16(self.get_hl(), self.g16(p)))
                else: self.set_hl(self.adc16(self.get_hl(), self.g16(p)))
                return 15
            if z == 3:
                a = self.fetchw()
                if q == 0: self.ww(a, self.g16(p))
                else: self.s16(p, self.rw(a))
                return 20
            if z == 4:
                v = self.a; self.a = 0; self.alu(2, v); return 8
            if z == 5:
                self.pc = self.pop(); self.iff1 = self.iff2; return 14
            if z == 6:
                self.im = [0, 0, 1, 2, 0, 0, 1, 2][y]; return 8
            if y == 0: self.i = self.a; return 9
            if y == 1: self.r = self.a; return 9
            if y == 2:
                self.a = self.i; self.f = (self.f & CF) | SZ[self.a] | (PF if self.iff2 else 0); return 9
            if y == 3:
                self.a = self.r; self.f = (self.f & CF) | SZ[self.a] | (PF if self.iff2 else 0); return 9
            if y == 4:  # RRD
                hl = self.get_hl(); m = self.rb(hl)
                self.wb(hl, ((self.a << 4) | (m >> 4)) & 0xFF)
                self.a = (self.a & 0xF0) | (m & 0x0F)
                self.f = (self.f & CF) | SZP[self.a]; return 18
            if y == 5:  # RLD
                hl = self.get_hl(); m = self.rb(hl)
                self.wb(hl, ((m << 4) | (self.a & 0x0F)) & 0xFF)
                self.a = (self.a & 0xF0) | (m >> 4)
                self.f = (self.f & CF) | SZP[self.a]; return 18
            return 8
        if x == 2 and z <= 3 and y >= 4:
            inc = 1 if (y & 1) == 0 else -1
            rep = y >= 6
            if z == 0:  # LDI/LDD/LDIR/LDDR
                self.wb(self.get_de(), self.rb(self.get_hl()))
                self.set_hl((self.get_hl() + inc) & 0xFFFF)
                self.set_de((self.get_de() + inc) & 0xFFFF)
                bc = (self.get_bc() - 1) & 0xFFFF
                self.set_bc(bc)
                self.f = (self.f & (SF | ZF | CF)) | (PF if bc else 0)
                if rep and bc:
                    self.pc = (self.pc - 2) & 0xFFFF; return 21
                return 16
            if z == 1:  # CPI/CPD/CPIR/CPDR
                v = self.rb(self.get_hl())
                r = (self.a - v) & 0xFF
                self.set_hl((self.get_hl() + inc) & 0xFFFF)
                bc = (self.get_bc() - 1) & 0xFFFF
                self.set_bc(bc)
                self.f = (self.f & CF) | SZ[r] | NF | (HF if ((self.a & 0xF) - (v & 0xF)) & 0x10 else 0) | (PF if bc else 0)
                if rep and bc and r != 0:
                    self.pc = (self.pc - 2) & 0xFFFF; return 21
                return 16
            if z == 2:  # INI...
                self.wb(self.get_hl(), self.io_read(self.get_bc()))
                self.set_hl((self.get_hl() + inc) & 0xFFFF)
                self.b = (self.b - 1) & 0xFF
                self.f = NF | (ZF if self.b == 0 else 0)
                if rep and self.b:
                    self.pc = (self.pc - 2) & 0xFFFF; return 21
                return 16
            v = self.rb(self.get_hl())  # OUTI...
            self.b = (self.b - 1) & 0xFF
            self.io_write(self.get_bc(), v)
            self.set_hl((self.get_hl() + inc) & 0xFFFF)
            self.f = NF | (ZF if self.b == 0 else 0)
            if rep and self.b:
                self.pc = (self.pc - 2) & 0xFFFF; return 21
            return 16
        return 8

    def exec_index(self, reg):
        op = self.fetch()
        self.r = (self.r & 0x80) | ((self.r + 1) & 0x7F)
        xv = self.ix if reg == 'ix' else self.iy

        def setx(v):
            if reg == 'ix': self.ix = v & 0xFFFF
            else: self.iy = v & 0xFFFF

        if op == 0x21: setx(self.fetchw()); return 14
        if op == 0x22: self.ww(self.fetchw(), xv); return 20
        if op == 0x2A: setx(self.rw(self.fetchw())); return 20
        if op == 0x23: setx(xv + 1); return 10
        if op == 0x2B: setx(xv - 1); return 10
        if op in (0x09, 0x19, 0x29, 0x39):
            other = {0x09: self.get_bc(), 0x19: self.get_de(), 0x29: xv, 0x39: self.sp}[op]
            setx(self.add16(xv, other)); return 15
        if op == 0xE1: setx(self.pop()); return 14
        if op == 0xE5: self.push(xv); return 15
        if op == 0xE9: self.pc = xv; return 8
        if op == 0xF9: self.sp = xv; return 10
        if op == 0xE3:
            v = self.rw(self.sp); self.ww(self.sp, xv); setx(v); return 23
        if op == 0x36:
            d = self.fetchd(); n = self.fetch()
            self.wb((xv + d) & 0xFFFF, n); return 19
        if op == 0x34 or op == 0x35:
            d = self.fetchd(); a = (xv + d) & 0xFFFF
            v = self.rb(a)
            self.wb(a, self.inc8(v) if op == 0x34 else self.dec8(v)); return 23
        if op == 0xCB:
            d = self.fetchd(); op2 = self.fetch()
            a = (xv + d) & 0xFFFF
            v = self.rb(a)
            x = op2 >> 6; y = (op2 >> 3) & 7
            if x == 0:
                self.wb(a, self.rot(y, v)); return 23
            if x == 1:
                r = v & (1 << y)
                self.f = (self.f & CF) | HF | (ZF | PF if not r else 0) | (SF if (y == 7 and r) else 0)
                return 20
            self.wb(a, (v & ~(1 << y)) & 0xFF if x == 2 else v | (1 << y)); return 23

        x = op >> 6; y = (op >> 3) & 7; z = op & 7

        def gh(r):  # register read with H/L -> IXH/IXL
            if r == 4: return xv >> 8
            if r == 5: return xv & 0xFF
            return self.g8(r)

        def sh(r, v):
            nonlocal xv
            if r == 4: xv = (xv & 0xFF) | (v << 8); setx(xv)
            elif r == 5: xv = (xv & 0xFF00) | v; setx(xv)
            else: self.s8(r, v)

        if x == 1 and op != 0x76:
            if z == 6:
                d = self.fetchd(); self.s8(y, self.rb((xv + d) & 0xFFFF)); return 19
            if y == 6:
                d = self.fetchd(); self.wb((xv + d) & 0xFFFF, self.g8(z)); return 19
            sh(y, gh(z)); return 8
        if x == 2:
            if z == 6:
                d = self.fetchd(); self.alu(y, self.rb((xv + d) & 0xFFFF)); return 19
            self.alu(y, gh(z)); return 8
        if x == 0 and z in (4, 5) and y in (4, 5):
            v = gh(y)
            sh(y, self.inc8(v) if z == 4 else self.dec8(v)); return 8
        if x == 0 and z == 6 and y in (4, 5):
            sh(y, self.fetch()); return 11
        # not an index instruction: behaves as the plain opcode
        return 4 + self.exec_main(op)
