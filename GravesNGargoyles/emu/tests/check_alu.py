#!/usr/bin/env python3
"""Cross-check vzemu --selftest-alu output against an independent reference."""
import struct, sys, subprocess, os

def s8(v): return v - 256 if v & 0x80 else v
def s16(v): return v - 65536 if v & 0x8000 else v
def par(v): return 0x04 if bin(v & 0xFF).count('1') % 2 == 0 else 0
def szxy(r): return (r & 0x80) | (0x40 if r == 0 else 0) | (r & 0x28)

def add(a, b, c):
    r = (a + b + c) & 0xFF
    h = 0x10 if (a & 15) + (b & 15) + c > 15 else 0
    v = 0x04 if not -128 <= s8(a) + s8(b) + c <= 127 else 0
    cy = 1 if a + b + c > 255 else 0
    return r, szxy(r) | h | v | cy

def sub(a, b, c):
    r = (a - b - c) & 0xFF
    h = 0x10 if (a & 15) - (b & 15) - c < 0 else 0
    v = 0x04 if not -128 <= s8(a) - s8(b) - c <= 127 else 0
    cy = 1 if a - b - c < 0 else 0
    return r, szxy(r) | h | v | cy | 0x02

def ref(op, fin, x, y):
    c = fin & 1
    if op < 8:
        a, b = x, y
        if op == 0: return add(a, b, 0)
        if op == 1: return add(a, b, c)
        if op == 2: return sub(a, b, 0)
        if op == 3: return sub(a, b, c)
        if op == 4: r = a & b; return r, szxy(r) | par(r) | 0x10
        if op == 5: r = a ^ b; return r, szxy(r) | par(r)
        if op == 6: r = a | b; return r, szxy(r) | par(r)
        if op == 7:
            _, f = sub(a, b, 0)
            return a, (f & ~0x28) | (b & 0x28)
    if op == 8:
        r, f = add(x, 1, 0); return r, (f & ~1) | c
    if op == 9:
        r, f = sub(x, 1, 0); return r, (f & ~1) | c
    if 10 <= op <= 17:
        k = op - 10; v = x
        if k == 0: cy = v >> 7; r = ((v << 1) | cy) & 0xFF
        elif k == 1: cy = v & 1; r = (v >> 1) | (cy << 7)
        elif k == 2: cy = v >> 7; r = ((v << 1) | c) & 0xFF
        elif k == 3: cy = v & 1; r = (v >> 1) | (c << 7)
        elif k == 4: cy = v >> 7; r = (v << 1) & 0xFF
        elif k == 5: cy = v & 1; r = (v >> 1) | (v & 0x80)
        elif k == 6: cy = v >> 7; r = ((v << 1) | 1) & 0xFF
        else: cy = v & 1; r = v >> 1
        return r, szxy(r) | par(r) | cy
    if 18 <= op <= 21:
        k = op - 18; v = x
        if k == 0: cy = v >> 7; r = ((v << 1) | cy) & 0xFF
        elif k == 1: cy = v & 1; r = (v >> 1) | (cy << 7)
        elif k == 2: cy = v >> 7; r = ((v << 1) | c) & 0xFF
        else: cy = v & 1; r = (v >> 1) | (c << 7)
        return r, (fin & 0xC4) | (r & 0x28) | cy
    if op == 22:  # DAA, table-style definition from Sean Young
        a, n, h = x, fin & 2, fin & 0x10
        hi, lo = a >> 4, a & 15
        if c: diff = 0x66 if (h or lo > 9) else 0x60
        elif hi <= 9 and lo <= 9 and not h: diff = 0
        elif hi <= 9 and not h and lo > 9 and hi <= 8: diff = 6
        elif hi <= 9 and h and lo <= 9: diff = 6
        elif hi <= 8 and lo > 9: diff = 6
        elif hi >= 10 and lo <= 9 and not h: diff = 0x60
        else: diff = 0x66
        if c or (hi >= 10 and lo <= 9) or (hi >= 9 and lo > 9): cy = 1
        else: cy = 0
        if not n: hf = 0x10 if lo > 9 else 0
        else: hf = 0x10 if (h and lo <= 5) else 0
        r = (a - diff) & 0xFF if n else (a + diff) & 0xFF
        return r, szxy(r) | par(r) | hf | n | cy
    if op == 23:
        r = x ^ 0xFF; return r, (fin & 0xC5) | 0x12 | (r & 0x28)
    if op == 24: return x, (fin & 0xC4) | (x & 0x28) | 1
    if op == 25: return x, (fin & 0xC4) | (x & 0x28) | (0x10 if c else 0) | (c ^ 1)
    if op == 26: return sub(0, x, 0)
    if 27 <= op <= 34:
        b = op - 27; z = not (x >> b) & 1
        f = (fin & 1) | 0x10 | (0x44 if z else 0) | (0x80 if (b == 7 and not z) else 0) | (x & 0x28)
        return x, f
    if op == 40:
        r = (x + y) & 0xFFFF
        h = 0x10 if (x & 0xFFF) + (y & 0xFFF) > 0xFFF else 0
        return r, (fin & 0xC4) | ((r >> 8) & 0x28) | h | (1 if x + y > 0xFFFF else 0)
    if op in (41, 42):
        if op == 41:
            t = x + y + c; r = t & 0xFFFF
            h = 0x10 if (x & 0xFFF) + (y & 0xFFF) + c > 0xFFF else 0
            v = 0x04 if not -32768 <= s16(x) + s16(y) + c <= 32767 else 0
            cy = 1 if t > 0xFFFF else 0; n = 0
        else:
            t = x - y - c; r = t & 0xFFFF
            h = 0x10 if (x & 0xFFF) - (y & 0xFFF) - c < 0 else 0
            v = 0x04 if not -32768 <= s16(x) - s16(y) - c <= 32767 else 0
            cy = 1 if t < 0 else 0; n = 2
        f = ((r >> 8) & 0xA8) | (0x40 if r == 0 else 0) | h | v | cy | n
        return r, f
    raise ValueError(op)

def main():
    emu, out = sys.argv[1], sys.argv[2]
    subprocess.check_call([emu, '--selftest-alu', out])
    data = open(out, 'rb').read()
    n = len(data) // 10
    bad = {}
    cnt = {}
    for i in range(n):
        op, fin, x, y, r, f, _ = struct.unpack_from('<BBHHHBB', data, i * 10)
        er, ef = ref(op, fin, x, y)
        cnt[op] = cnt.get(op, 0) + 1
        if er != r or ef != f:
            bad.setdefault(op, []).append((fin, x, y, r, f, er, ef))
    print('records: %d, opcodes: %d' % (n, len(cnt)))
    for op, lst in sorted(bad.items()):
        print('op %d: %d mismatches, e.g. fin=%02X x=%04X y=%04X got %04X/%02X want %04X/%02X' % ((op, len(lst)) + lst[0]))
    print('ALU CHECK', 'PASS' if not bad else 'FAIL')
    sys.exit(1 if bad else 0)

main()
