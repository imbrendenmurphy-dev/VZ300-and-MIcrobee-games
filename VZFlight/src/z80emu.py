"""Cycle-counting Z80 emulator with a minimal VZ300 hardware model.

Registers live in self.r = [B, C, D, E, H, L, F, A].
Hardware: keyboard/vsync read at $6800-$6FFF, latch write there, video RAM $7000,
field interrupt held low for the whole field-sync period (level triggered).
"""
FIELD = 70630       # T-states per field (measured on the real machine)
SYNC = 12740        # T-states the field sync (and /INT) stays low

SF, ZF, HF, PF, NF, CF = 0x80, 0x40, 0x10, 0x04, 0x02, 0x01

SZ = [0] * 256
SZP = [0] * 256
for _i in range(256):
    f = (_i & 0x80) | (0x40 if _i == 0 else 0)
    SZ[_i] = f
    SZP[_i] = f | (PF if bin(_i).count('1') % 2 == 0 else 0)

# keyboard matrix: row index (address bit that is low) -> keys for bits 5..0
KEYROWS = [
    ['R', 'Q', 'E', None, 'W', 'T'],
    ['F', 'A', 'D', 'CTRL', 'S', 'G'],
    ['V', 'Z', 'C', 'SHIFT', 'X', 'B'],
    ['4', '1', '3', None, '2', '5'],
    ['M', 'SPACE', ',', None, '.', 'N'],
    ['7', '0', '8', '-', '9', '6'],
    ['U', 'P', 'I', 'RETURN', 'O', 'Y'],
    ['J', ';', 'K', ':', 'L', 'H'],
]
KEYPOS = {}
for _r, _row in enumerate(KEYROWS):
    for _b, _k in enumerate(_row):
        if _k:
            KEYPOS[_k] = (_r, 5 - _b)


class Unimplemented(Exception):
    pass


class VZ:
    def __init__(self):
        self.m = bytearray(65536)
        self.r = [0] * 8
        self.r2 = [0] * 8
        self.ix = 0
        self.iy = 0
        self.sp = 0xFFFF
        self.pc = 0
        self.i = 0
        self.iff = 0
        self.eip = 0
        self.im = 0
        self.t = 0
        self.keys = set()
        self.rowmask = [0] * 8
        self.latch = 0
        self.spk = 0            # count of speaker state changes
        self.ports = {}
        self.halted = False
        self.int_count = 0
        self._build()

    # ------------------------------------------------------------ hardware
    def press(self, *names):
        for n in names:
            self.keys.add(n)
        self._rows()

    def release(self, *names):
        for n in names:
            self.keys.discard(n)
        self._rows()

    def release_all(self):
        self.keys.clear()
        self._rows()

    def _rows(self):
        self.rowmask = [0] * 8
        for k in self.keys:
            r, b = KEYPOS[k]
            self.rowmask[r] |= 1 << b

    def in_sync(self):
        return (self.t % FIELD) < SYNC

    def kbd(self, addr):
        v = 0x7F
        rm = self.rowmask
        for i in range(8):
            if not (addr >> i) & 1:
                v &= ~rm[i]
        if not self.in_sync():
            v |= 0x80
        return v & 0xFF

    def set_latch(self, v):
        if (v ^ self.latch) & 0x21:
            self.spk += 1
        self.latch = v

    def load(self, org, data):
        self.m[org:org + len(data)] = data

    # ----------------------------------------------------------------- cpu
    def _build(self):
        m = self.m
        r = self.r
        cpu = self

        def rd(a):
            if 0x6800 <= a < 0x7000:
                return cpu.kbd(a)
            return m[a]

        def wr(a, v):
            if a >= 0x7000:
                m[a] = v
            elif a >= 0x6800:
                cpu.set_latch(v)

        self.rd = rd
        self.wr = wr

        def fetch():
            pc = cpu.pc
            cpu.pc = (pc + 1) & 0xFFFF
            return m[pc]

        def fetch16():
            pc = cpu.pc
            cpu.pc = (pc + 2) & 0xFFFF
            return m[pc] | (m[(pc + 1) & 0xFFFF] << 8)

        def push(v):
            sp = (cpu.sp - 2) & 0xFFFF
            cpu.sp = sp
            wr(sp, v & 0xFF)
            wr((sp + 1) & 0xFFFF, v >> 8)

        def pop():
            sp = cpu.sp
            cpu.sp = (sp + 2) & 0xFFFF
            return rd(sp) | (rd((sp + 1) & 0xFFFF) << 8)

        self.push = push
        self.pop = pop

        # ---- 8-bit alu on A
        def add(v, c=0):
            a = r[7]
            res = a + v + c
            r[6] = SZ[res & 255] | (res >> 8) | ((a ^ v ^ res) & HF) | (((a ^ res) & (v ^ res) & 0x80) >> 5)
            r[7] = res & 255

        def adc(v):
            add(v, r[6] & 1)

        def sub(v, c=0):
            a = r[7]
            res = a - v - c
            r[6] = SZ[res & 255] | NF | ((res >> 8) & 1) | ((a ^ v ^ res) & HF) | (((a ^ v) & (a ^ res) & 0x80) >> 5)
            r[7] = res & 255

        def sbc(v):
            sub(v, r[6] & 1)

        def and_(v):
            r[7] &= v
            r[6] = SZP[r[7]] | HF

        def xor(v):
            r[7] ^= v
            r[6] = SZP[r[7]]

        def or_(v):
            r[7] |= v
            r[6] = SZP[r[7]]

        def cp(v):
            a = r[7]
            res = a - v
            r[6] = SZ[res & 255] | NF | ((res >> 8) & 1) | ((a ^ v ^ res) & HF) | (((a ^ v) & (a ^ res) & 0x80) >> 5)

        alu = [add, adc, sub, sbc, and_, xor, or_, cp]

        def inc8(v):
            v = (v + 1) & 255
            r[6] = (r[6] & 1) | SZ[v] | (HF if (v & 15) == 0 else 0) | (PF if v == 0x80 else 0)
            return v

        def dec8(v):
            v = (v - 1) & 255
            r[6] = (r[6] & 1) | SZ[v] | NF | (HF if (v & 15) == 15 else 0) | (PF if v == 0x7F else 0)
            return v

        def rot(k, v):
            c = r[6] & 1
            if k == 0:
                co = v >> 7; v = ((v << 1) | co) & 255
            elif k == 1:
                co = v & 1; v = (v >> 1) | (co << 7)
            elif k == 2:
                co = v >> 7; v = ((v << 1) | c) & 255
            elif k == 3:
                co = v & 1; v = (v >> 1) | (c << 7)
            elif k == 4:
                co = v >> 7; v = (v << 1) & 255
            elif k == 5:
                co = v & 1; v = (v >> 1) | (v & 0x80)
            elif k == 6:
                co = v >> 7; v = ((v << 1) | 1) & 255
            else:
                co = v & 1; v = v >> 1
            r[6] = SZP[v] | co
            return v

        def hl():
            return (r[4] << 8) | r[5]

        def cond(c):
            f = r[6]
            if c == 0: return not f & ZF
            if c == 1: return f & ZF
            if c == 2: return not f & CF
            if c == 3: return f & CF
            if c == 4: return not f & PF
            if c == 5: return f & PF
            if c == 6: return not f & SF
            return f & SF

        ops = [None] * 256

        # ---------------- LD r,r' / HALT
        def mk_ld(d, s):
            if s == 6:
                def f():
                    r[d] = rd((r[4] << 8) | r[5]); return 7
            elif d == 6:
                def f():
                    wr((r[4] << 8) | r[5], r[s]); return 7
            else:
                def f():
                    r[d] = r[s]; return 4
            return f

        for d in range(8):
            for s in range(8):
                if d == 6 and s == 6:
                    continue
                ops[0x40 | d << 3 | s] = mk_ld(d, s)

        def halt():
            cpu.halted = True
            cpu.pc = (cpu.pc - 1) & 0xFFFF
            return 4
        ops[0x76] = halt

        # ---------------- ALU r / n
        def mk_alu(k, s):
            fn = alu[k]
            if s == 6:
                def f():
                    fn(rd((r[4] << 8) | r[5])); return 7
            else:
                def f():
                    fn(r[s]); return 4
            return f

        def mk_alui(k):
            fn = alu[k]

            def f():
                fn(fetch()); return 7
            return f

        for k in range(8):
            for s in range(8):
                ops[0x80 | k << 3 | s] = mk_alu(k, s)
            ops[0xC6 | k << 3] = mk_alui(k)

        # ---------------- INC/DEC r, LD r,n
        def mk_inc(d):
            if d == 6:
                def f():
                    a = (r[4] << 8) | r[5]; wr(a, inc8(rd(a))); return 11
            else:
                def f():
                    r[d] = inc8(r[d]); return 4
            return f

        def mk_dec(d):
            if d == 6:
                def f():
                    a = (r[4] << 8) | r[5]; wr(a, dec8(rd(a))); return 11
            else:
                def f():
                    r[d] = dec8(r[d]); return 4
            return f

        def mk_ldn(d):
            if d == 6:
                def f():
                    wr((r[4] << 8) | r[5], fetch()); return 10
            else:
                def f():
                    r[d] = fetch(); return 7
            return f

        for d in range(8):
            ops[0x04 | d << 3] = mk_inc(d)
            ops[0x05 | d << 3] = mk_dec(d)
            ops[0x06 | d << 3] = mk_ldn(d)

        # ---------------- 16-bit
        def get16(p):
            if p == 3: return cpu.sp
            return (r[p * 2] << 8) | r[p * 2 + 1]

        def set16(p, v):
            if p == 3:
                cpu.sp = v
            else:
                r[p * 2] = v >> 8; r[p * 2 + 1] = v & 255

        def mk16(p):
            def ldnn():
                set16(p, fetch16()); return 10

            def inc():
                set16(p, (get16(p) + 1) & 0xFFFF); return 6

            def dec():
                set16(p, (get16(p) - 1) & 0xFFFF); return 6

            def addhl():
                h = (r[4] << 8) | r[5]; v = get16(p); res = h + v
                r[6] = (r[6] & 0xC4) | (res >> 16) | (((h ^ v ^ res) >> 8) & HF)
                r[4] = (res >> 8) & 255; r[5] = res & 255
                return 11
            return ldnn, inc, dec, addhl

        for p in range(4):
            a, b, c, d_ = mk16(p)
            ops[0x01 | p << 4] = a
            ops[0x03 | p << 4] = b
            ops[0x0B | p << 4] = c
            ops[0x09 | p << 4] = d_

        def mk_pushpop(p):
            if p == 3:
                def pu():
                    push((r[7] << 8) | r[6]); return 11

                def po():
                    v = pop(); r[7] = v >> 8; r[6] = v & 255; return 10
            else:
                def pu():
                    push((r[p * 2] << 8) | r[p * 2 + 1]); return 11

                def po():
                    v = pop(); r[p * 2] = v >> 8; r[p * 2 + 1] = v & 255; return 10
            return pu, po

        for p in range(4):
            pu, po = mk_pushpop(p)
            ops[0xC5 | p << 4] = pu
            ops[0xC1 | p << 4] = po

        # ---------------- misc main
        def nop(): return 4
        ops[0x00] = nop

        def ld_bc_a(): wr((r[0] << 8) | r[1], r[7]); return 7
        def ld_a_bc(): r[7] = rd((r[0] << 8) | r[1]); return 7
        def ld_de_a(): wr((r[2] << 8) | r[3], r[7]); return 7
        def ld_a_de(): r[7] = rd((r[2] << 8) | r[3]); return 7
        ops[0x02] = ld_bc_a; ops[0x0A] = ld_a_bc; ops[0x12] = ld_de_a; ops[0x1A] = ld_a_de

        def ld_nn_hl():
            a = fetch16(); wr(a, r[5]); wr((a + 1) & 0xFFFF, r[4]); return 16

        def ld_hl_nn():
            a = fetch16(); r[5] = rd(a); r[4] = rd((a + 1) & 0xFFFF); return 16

        def ld_nn_a(): wr(fetch16(), r[7]); return 13
        def ld_a_nn(): r[7] = rd(fetch16()); return 13
        ops[0x22] = ld_nn_hl; ops[0x2A] = ld_hl_nn; ops[0x32] = ld_nn_a; ops[0x3A] = ld_a_nn

        def rlca():
            a = r[7]; c = a >> 7; r[7] = ((a << 1) | c) & 255; r[6] = (r[6] & 0xC4) | c; return 4

        def rrca():
            a = r[7]; c = a & 1; r[7] = (a >> 1) | (c << 7); r[6] = (r[6] & 0xC4) | c; return 4

        def rla():
            a = r[7]; c = a >> 7; r[7] = ((a << 1) | (r[6] & 1)) & 255; r[6] = (r[6] & 0xC4) | c; return 4

        def rra():
            a = r[7]; c = a & 1; r[7] = (a >> 1) | ((r[6] & 1) << 7); r[6] = (r[6] & 0xC4) | c; return 4
        ops[0x07] = rlca; ops[0x0F] = rrca; ops[0x17] = rla; ops[0x1F] = rra

        def daa():
            a = r[7]; f = r[6]; adj = 0; c = f & 1
            if (f & HF) or (a & 15) > 9: adj |= 6
            if c or a > 0x99: adj |= 0x60; c = 1
            if f & NF:
                res = (a - adj) & 255
                h = HF if (f & HF) and (a & 15) < 6 else 0
            else:
                res = (a + adj) & 255
                h = HF if (a & 15) > 9 else 0
            r[7] = res; r[6] = SZP[res] | (f & NF) | c | h
            return 4

        def cpl(): r[7] ^= 255; r[6] |= HF | NF; return 4
        def scf(): r[6] = (r[6] & 0xC4) | 1; return 4
        def ccf(): f = r[6]; r[6] = (f & 0xC4) | ((f & 1) << 4) | ((f & 1) ^ 1); return 4
        ops[0x27] = daa; ops[0x2F] = cpl; ops[0x37] = scf; ops[0x3F] = ccf

        def ex_af():
            r2 = cpu.r2
            r[7], r2[7] = r2[7], r[7]; r[6], r2[6] = r2[6], r[6]; return 4

        def exx():
            r2 = cpu.r2
            for i in range(6):
                r[i], r2[i] = r2[i], r[i]
            return 4

        def ex_de_hl():
            r[2], r[4] = r[4], r[2]; r[3], r[5] = r[5], r[3]; return 4

        def ex_sp_hl():
            sp = cpu.sp
            lo = rd(sp); hi = rd((sp + 1) & 0xFFFF)
            wr(sp, r[5]); wr((sp + 1) & 0xFFFF, r[4])
            r[5] = lo; r[4] = hi
            return 19
        ops[0x08] = ex_af; ops[0xD9] = exx; ops[0xEB] = ex_de_hl; ops[0xE3] = ex_sp_hl

        def jp(): cpu.pc = fetch16(); return 10
        def jp_hl(): cpu.pc = (r[4] << 8) | r[5]; return 4
        def ld_sp_hl(): cpu.sp = (r[4] << 8) | r[5]; return 6
        ops[0xC3] = jp; ops[0xE9] = jp_hl; ops[0xF9] = ld_sp_hl

        def jr():
            d = fetch()
            cpu.pc = (cpu.pc + (d - 256 if d > 127 else d)) & 0xFFFF
            return 12

        def djnz():
            d = fetch()
            b = (r[0] - 1) & 255; r[0] = b
            if b:
                cpu.pc = (cpu.pc + (d - 256 if d > 127 else d)) & 0xFFFF
                return 13
            return 8
        ops[0x18] = jr; ops[0x10] = djnz

        def mk_cc(c):
            def jrcc():
                d = fetch()
                if cond(c):
                    cpu.pc = (cpu.pc + (d - 256 if d > 127 else d)) & 0xFFFF
                    return 12
                return 7

            def jpcc():
                a = fetch16()
                if cond(c): cpu.pc = a
                return 10

            def callcc():
                a = fetch16()
                if cond(c):
                    push(cpu.pc); cpu.pc = a; return 17
                return 10

            def retcc():
                if cond(c):
                    cpu.pc = pop(); return 11
                return 5
            return jrcc, jpcc, callcc, retcc

        for c in range(8):
            jrcc, jpcc, callcc, retcc = mk_cc(c)
            if c < 4: ops[0x20 | c << 3] = jrcc
            ops[0xC2 | c << 3] = jpcc
            ops[0xC4 | c << 3] = callcc
            ops[0xC0 | c << 3] = retcc

        def call():
            a = fetch16(); push(cpu.pc); cpu.pc = a; return 17

        def ret(): cpu.pc = pop(); return 10
        ops[0xCD] = call; ops[0xC9] = ret

        def mk_rst(a):
            def f():
                push(cpu.pc); cpu.pc = a; return 11
            return f
        for k in range(8):
            ops[0xC7 | k << 3] = mk_rst(k * 8)

        def di(): cpu.iff = 0; cpu.eip = 0; return 4
        def ei(): cpu.eip = 2; return 4
        ops[0xF3] = di; ops[0xFB] = ei

        def in_a_n():
            p = fetch(); r[7] = cpu.ports.get(p, 0xFF); return 11

        def out_n_a():
            fetch(); return 11
        ops[0xDB] = in_a_n; ops[0xD3] = out_n_a

        # ---------------- CB prefix
        def cb():
            op = fetch()
            x = op >> 6; y = (op >> 3) & 7; z = op & 7
            if z == 6:
                a = (r[4] << 8) | r[5]; v = rd(a)
            else:
                v = r[z]
            if x == 0:
                v = rot(y, v)
            elif x == 1:
                r[6] = (r[6] & 1) | HF | (0 if v & (1 << y) else ZF | PF) | (SF if y == 7 and v & 0x80 else 0)
                return 12 if z == 6 else 8
            elif x == 2:
                v &= ~(1 << y) & 255
            else:
                v |= 1 << y
            if z == 6:
                wr(a, v); return 15
            r[z] = v
            return 8
        ops[0xCB] = cb

        # ---------------- ED prefix
        def ed():
            op = fetch()
            if op & 0xCF == 0x42:            # sbc hl,rr
                h = (r[4] << 8) | r[5]; v = get16((op >> 4) & 3); res = h - v - (r[6] & 1)
                r[6] = ((res >> 16) & 1) | NF | ((res >> 8) & SF) | (ZF if res & 0xFFFF == 0 else 0) | \
                    (((h ^ v ^ res) >> 8) & HF) | (((h ^ v) & (h ^ res) & 0x8000) >> 13)
                r[4] = (res >> 8) & 255; r[5] = res & 255
                return 15
            if op & 0xCF == 0x4A:            # adc hl,rr
                h = (r[4] << 8) | r[5]; v = get16((op >> 4) & 3); res = h + v + (r[6] & 1)
                r[6] = ((res >> 16) & 1) | ((res >> 8) & SF) | (ZF if res & 0xFFFF == 0 else 0) | \
                    (((h ^ v ^ res) >> 8) & HF) | (((h ^ res) & (v ^ res) & 0x8000) >> 13)
                r[4] = (res >> 8) & 255; r[5] = res & 255
                return 15
            if op & 0xCF == 0x43:            # ld (nn),rr
                a = fetch16(); v = get16((op >> 4) & 3)
                wr(a, v & 255); wr((a + 1) & 0xFFFF, v >> 8); return 20
            if op & 0xCF == 0x4B:            # ld rr,(nn)
                a = fetch16(); set16((op >> 4) & 3, rd(a) | (rd((a + 1) & 0xFFFF) << 8)); return 20
            if op == 0x44:
                a = r[7]; r[7] = 0; sub(a); return 8
            if op == 0x46: cpu.im = 0; return 8
            if op == 0x56: cpu.im = 1; return 8
            if op == 0x5E: cpu.im = 2; return 8
            if op == 0x47: cpu.i = r[7]; return 9
            if op == 0x57:
                r[7] = cpu.i; r[6] = (r[6] & 1) | SZ[r[7]] | (PF if cpu.iff else 0); return 9
            if op == 0x4D or op == 0x45:
                cpu.pc = pop(); return 14
            if op in (0xA0, 0xB0, 0xA8, 0xB8):
                h = (r[4] << 8) | r[5]; d = (r[2] << 8) | r[3]; bc = (r[0] << 8) | r[1]
                wr(d, rd(h))
                step = 1 if op & 8 == 0 else -1
                h = (h + step) & 0xFFFF; d = (d + step) & 0xFFFF; bc = (bc - 1) & 0xFFFF
                r[4] = h >> 8; r[5] = h & 255; r[2] = d >> 8; r[3] = d & 255; r[0] = bc >> 8; r[1] = bc & 255
                r[6] = (r[6] & 0xC1) | (PF if bc else 0)
                if op & 0x10 and bc:
                    cpu.pc = (cpu.pc - 2) & 0xFFFF
                    return 21
                return 16
            if op & 0xC7 == 0x40:            # in r,(c)
                v = cpu.ports.get(r[1], 0xFF)
                y = (op >> 3) & 7
                if y != 6: r[y] = v
                r[6] = (r[6] & 1) | SZP[v]
                return 12
            if op & 0xC7 == 0x41:
                return 12
            raise Unimplemented('ED %02X at %04X' % (op, cpu.pc - 2))
        ops[0xED] = ed

        # ---------------- DD / FD prefix
        def mk_index(isx):
            def geti():
                return cpu.ix if isx else cpu.iy

            def seti(v):
                if isx: cpu.ix = v & 0xFFFF
                else: cpu.iy = v & 0xFFFF

            def ea():
                d = fetch()
                return (geti() + (d - 256 if d > 127 else d)) & 0xFFFF

            def f():
                op = fetch()
                if op == 0x21: seti(fetch16()); return 14
                if op == 0x22:
                    a = fetch16(); v = geti(); wr(a, v & 255); wr((a + 1) & 0xFFFF, v >> 8); return 20
                if op == 0x2A:
                    a = fetch16(); seti(rd(a) | (rd((a + 1) & 0xFFFF) << 8)); return 20
                if op == 0x23: seti(geti() + 1); return 10
                if op == 0x2B: seti(geti() - 1); return 10
                if op & 0xCF == 0x09:
                    p = (op >> 4) & 3
                    h = geti(); v = h if p == 2 else get16(p); res = h + v
                    r[6] = (r[6] & 0xC4) | (res >> 16) | (((h ^ v ^ res) >> 8) & HF)
                    seti(res)
                    return 15
                if op == 0x34:
                    a = ea(); wr(a, inc8(rd(a))); return 23
                if op == 0x35:
                    a = ea(); wr(a, dec8(rd(a))); return 23
                if op == 0x36:
                    a = ea(); wr(a, fetch()); return 19
                if op & 0xC7 == 0x46 and op != 0x76:
                    r[(op >> 3) & 7] = rd(ea()); return 19
                if op & 0xF8 == 0x70 and op != 0x76:
                    wr(ea(), r[op & 7]); return 19
                if op & 0xC7 == 0x86:
                    alu[(op >> 3) & 7](rd(ea())); return 19
                if op == 0xE1: seti(pop()); return 14
                if op == 0xE5: push(geti()); return 15
                if op == 0xE9: cpu.pc = geti(); return 8
                if op == 0xF9: cpu.sp = geti(); return 10
                if op == 0xE3:
                    sp = cpu.sp; v = rd(sp) | (rd((sp + 1) & 0xFFFF) << 8)
                    g = geti(); wr(sp, g & 255); wr((sp + 1) & 0xFFFF, g >> 8); seti(v); return 23
                if op == 0xCB:
                    a = ea(); op2 = fetch()
                    x = op2 >> 6; y = (op2 >> 3) & 7
                    if op2 & 7 != 6:
                        raise Unimplemented('DDCB undocumented')
                    v = rd(a)
                    if x == 0: v = rot(y, v)
                    elif x == 1:
                        r[6] = (r[6] & 1) | HF | (0 if v & (1 << y) else ZF | PF) | (SF if y == 7 and v & 0x80 else 0)
                        return 20
                    elif x == 2: v &= ~(1 << y) & 255
                    else: v |= 1 << y
                    wr(a, v)
                    return 23
                raise Unimplemented('%s %02X at %04X' % ('DD' if isx else 'FD', op, cpu.pc - 2))
            return f
        ops[0xDD] = mk_index(True)
        ops[0xFD] = mk_index(False)

        self.ops = ops

    # ------------------------------------------------------------- running
    def step(self):
        if self.iff and (self.t % FIELD) < SYNC:
            self.iff = 0
            self.int_count += 1
            if self.halted:
                self.halted = False
                self.pc = (self.pc + 1) & 0xFFFF
            self.push(self.pc)
            if self.im == 2:
                a = (self.i << 8) | 0xFF
                self.pc = self.m[a] | (self.m[(a + 1) & 0xFFFF] << 8)
                self.t += 19
            else:
                self.pc = 0x38
                self.t += 13
            return
        pc = self.pc
        op = self.m[pc]
        self.pc = (pc + 1) & 0xFFFF
        f = self.ops[op]
        if f is None:
            raise Unimplemented('%02X at %04X' % (op, pc))
        self.t += f()
        if self.eip:
            self.eip -= 1
            if self.eip == 0:
                self.iff = 1

    def run_until(self, addr, maxt=50_000_000):
        """run until PC == addr; returns T-states used"""
        t0 = self.t
        step = self.step
        while self.pc != addr:
            step()
            if self.t - t0 > maxt:
                raise RuntimeError('timeout at pc=%04X' % self.pc)
        return self.t - t0

    def call(self, addr, maxt=50_000_000):
        """call a subroutine and return when it returns; T-states used"""
        self.push(0x0001)
        self.pc = addr
        return self.run_until(0x0001, maxt)

    def run_t(self, tstates):
        end = self.t + tstates
        step = self.step
        while self.t < end:
            step()

    # helpers
    def w(self, a):
        return self.m[a] | (self.m[a + 1] << 8)

    def ws(self, a):
        v = self.w(a)
        return v - 65536 if v > 32767 else v

    def setw(self, a, v):
        self.m[a] = v & 255
        self.m[a + 1] = (v >> 8) & 255

    @property
    def hl(self):
        return (self.r[4] << 8) | self.r[5]

    @hl.setter
    def hl(self, v):
        self.r[4] = (v >> 8) & 255; self.r[5] = v & 255

    @property
    def de(self):
        return (self.r[2] << 8) | self.r[3]

    @de.setter
    def de(self, v):
        self.r[2] = (v >> 8) & 255; self.r[3] = v & 255

    @property
    def bc(self):
        return (self.r[0] << 8) | self.r[1]

    @bc.setter
    def bc(self, v):
        self.r[0] = (v >> 8) & 255; self.r[1] = v & 255


PALETTE = [(40, 224, 40), (240, 240, 80), (48, 48, 220), (208, 48, 48)]
PALETTE1 = [(236, 236, 210), (40, 220, 230), (220, 60, 220), (240, 140, 30)]


def screenshot(vz, fname, base=0x7000, scale=4):
    """mode(1) 128x64 screen to PNG, 4:3 aspect (pixels 1 : 1.5)"""
    from PIL import Image
    im = Image.new('RGB', (128, 64))
    px = im.load()
    pal = PALETTE1 if vz.latch & 0x10 else PALETTE
    for y in range(64):
        for xb in range(32):
            b = vz.m[base + y * 32 + xb]
            for k in range(4):
                px[xb * 4 + k, y] = pal[(b >> (6 - 2 * k)) & 3]
    im = im.resize((128 * scale, int(64 * scale * 1.5)), Image.NEAREST)
    im.save(fname)
    return im
