#!/usr/bin/env python3
"""Check vzemu T-state counts for every opcode (base/CB/ED/DD/FD/DDCB) against
standard Z80 timing tables. cond 0: flags=00 (NZ,NC,PO,P true), BC=1/B=1;
cond 1: flags=FF (Z,C,PE,M true), BC=2/B=2."""
import subprocess, sys

base = {}
for op in range(256):
    x, y, z = op >> 6, (op >> 3) & 7, op & 7
    if x == 1:
        base[op] = 4 if op == 0x76 else (7 if (y == 6 or z == 6) else 4)
    elif x == 2:
        base[op] = 7 if z == 6 else 4
t0 = [4,10,7,6,4,4,7,4, 4,11,7,6,4,4,7,4, None,10,7,6,4,4,7,4, 12,11,7,6,4,4,7,4,
      None,10,16,6,4,4,7,4, None,11,16,6,4,4,7,4, None,10,13,6,11,11,10,4, None,11,13,6,4,4,7,4]
for i, v in enumerate(t0):
    if v is not None: base[i] = v
t3 = {0xC1:10,0xC2:10,0xC3:10,0xC5:11,0xC6:7,0xC7:11,0xC9:10,0xCA:10,0xCD:17,0xCE:7,0xCF:11,
      0xD1:10,0xD2:10,0xD3:11,0xD5:11,0xD6:7,0xD7:11,0xD9:4,0xDA:10,0xDB:11,0xDE:7,0xDF:11,
      0xE1:10,0xE2:10,0xE3:19,0xE5:11,0xE6:7,0xE7:11,0xE9:4,0xEA:10,0xEB:4,0xEE:7,0xEF:11,
      0xF1:10,0xF2:10,0xF3:4,0xF5:11,0xF6:7,0xF7:11,0xF9:6,0xFA:10,0xFB:4,0xFE:7,0xFF:11}
base.update(t3)

def cond_true(cc, c):
    # flags 00: NZ NC PO P true ; FF: Z C PE M true
    return (cc & 1) == c

def expect_base(op, c):
    x, y, z = op >> 6, (op >> 3) & 7, op & 7
    if op == 0x10: return 13 if c else 8
    if op in (0x20, 0x28, 0x30, 0x38): return 12 if cond_true(y - 4, c) else 7
    if x == 3 and z == 0: return 11 if cond_true(y, c) else 5
    if x == 3 and z == 4: return 17 if cond_true(y, c) else 10
    return base[op]

tests = []  # (cond, bytes, expected)
for op in range(256):
    if op in (0xCB, 0xDD, 0xED, 0xFD, 0x76): continue
    for c in (0, 1):
        tests.append((c, [op, 0, 0, 0], expect_base(op, c), 'base %02X' % op))
for op in range(256):
    z, x = op & 7, op >> 6
    e = (12 if x == 1 else 15) if z == 6 else 8
    tests.append((0, [0xCB, op], e, 'CB %02X' % op))
    for p in (0xDD, 0xFD):
        tests.append((0, [p, 0xCB, 0xFE, op], 20 if x == 1 else 23, '%02X CB d %02X' % (p, op)))
hl_ops = set()
for op in range(256):
    if op in (0xCB, 0xDD, 0xED, 0xFD, 0x76): continue
    x, y, z = op >> 6, (op >> 3) & 7, op & 7
    uses_m = (x == 1 and (y == 6 or z == 6)) or (x == 2 and z == 6) or op in (0x34, 0x35, 0x36)
    for p in (0xDD, 0xFD):
        for c in (0, 1):
            e = expect_base(op, c) + 4
            if uses_m: e = {7: 19, 11: 23, 10: 19}[expect_base(op, c)]
            tests.append((c, [p, op, 0x05, 0x00, 0], e, '%02X %02X' % (p, op)))
ed = {}
for y in range(8):
    p = y >> 1
    ed[0x40 | y << 3] = 12; ed[0x41 | y << 3] = 12; ed[0x42 | y << 3] = 15
    ed[0x43 | y << 3] = 20; ed[0x44 | y << 3] = 8; ed[0x45 | y << 3] = 14; ed[0x46 | y << 3] = 8
ed.update({0x47: 9, 0x4F: 9, 0x57: 9, 0x5F: 9, 0x67: 18, 0x6F: 18, 0x77: 8, 0x7F: 8})
for op in range(256):
    if op in ed:
        tests.append((0, [0xED, op, 0, 0], ed[op], 'ED %02X' % op))
for op in (0xA0, 0xA1, 0xA2, 0xA3, 0xA8, 0xA9, 0xAA, 0xAB):
    tests.append((0, [0xED, op], 16, 'ED %02X' % op))
for op in (0xB0, 0xB1, 0xB2, 0xB3, 0xB8, 0xB9, 0xBA, 0xBB):
    tests.append((0, [0xED, op], 16, 'ED %02X stop' % op))
    tests.append((1, [0xED, op], 21, 'ED %02X repeat' % op))

inp = ''.join('%d %s\n' % (c, ' '.join('%02X' % b for b in bs)) for c, bs, e, n in tests)
out = subprocess.run([sys.argv[1], '--selftest-timing'], input=inp, capture_output=True, text=True).stdout.split('\n')
bad = 0
for (c, bs, e, n), line in zip(tests, out):
    got = int(line.split()[1])
    if got != e:
        bad += 1
        if bad < 30: print('MISMATCH %s cond%d: got %d want %d' % (n, c, got, e))
print('timing tests: %d, mismatches: %d' % (len(tests), bad))
print('TIMING CHECK', 'PASS' if bad == 0 else 'FAIL')
sys.exit(1 if bad else 0)
