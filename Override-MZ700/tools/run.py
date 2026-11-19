"""run.py - run OVERRIDE in the MZ-700 simulator with scripted keys.

    py tools/run.py FIELDS [shot_field,...] [--keys "field:key+key,field:-,..."]

Screenshots go to build/shots/run_NNNN.png.  Stops if the PC leaves the
program or the stack runs wild.
"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from mzsim import MZ700, FIELD_T  # noqa: E402


def load_syms():
    syms = {}
    for ln in open(os.path.join(ROOT, 'build', 'override.sym')):
        if ': EQU ' in ln:
            k, v = ln.split(': EQU ')
            syms[k.strip()] = int(v.strip(), 16)
    return syms


S = load_syms()


class Game:
    def __init__(self):
        self.m = MZ700(os.path.join(ROOT, 'rom', 'mz700fon.int'))
        self.m.load_mzf(os.path.join(ROOT, 'build', 'OVERRIDE.MZT'))
        self.end = S['end_of_program']
        self.shots = os.path.join(ROOT, 'build', 'shots')
        os.makedirs(self.shots, exist_ok=True)

    def run(self, fields, keys=()):
        m = self.m
        m.held = set(keys)
        c = m.cpu
        end = c.t + int(fields * FIELD_T)
        lo, hi = 0x1200, self.end
        step = c.step
        while c.t < end:
            step()
            if not (lo <= c.pc < hi):
                raise RuntimeError('PC escaped to %04X (SP %04X)' % (c.pc, c.sp))
        if not (0xC400 < c.sp <= 0xCFF0):
            raise RuntimeError('stack pointer %04X' % c.sp)

    def shot(self, name):
        p = os.path.join(self.shots, name + '.png')
        self.m.screenshot(p)
        return p

    def rb(self, name, off=0):
        return self.m.mem[S[name] + off]

    def wb(self, name, v, off=0):
        self.m.mem[S[name] + off] = v & 0xFF

    def text(self, row):
        """screen row as rough ASCII"""
        out = ''
        for c in range(40):
            ch = self.m.mem[0xD000 + row * 40 + c]
            if 1 <= ch <= 26:
                out += chr(64 + ch)
            elif 0x20 <= ch <= 0x29:
                out += chr(48 + ch - 0x20)
            elif ch == 0:
                out += ' '
            else:
                out += '.'
        return out

    def screen_text(self):
        return '\n'.join('%2d|%s|' % (r, self.text(r)) for r in range(25))


def parse_keys(spec):
    ev = []
    for item in spec.split(','):
        f, k = item.split(':')
        ev.append((int(f), [] if k == '-' else k.split('+')))
    return sorted(ev)


if __name__ == '__main__':
    fields = int(sys.argv[1])
    shots = set()
    keys = []
    args = sys.argv[2:]
    if '--keys' in args:
        i = args.index('--keys')
        keys = parse_keys(args[i + 1])
        args = args[:i] + args[i + 2:]
    if args:
        shots = {int(x) for x in args[0].split(',') if x}
    g = Game()
    t0 = time.time()
    held = []
    for f in range(fields):
        for kf, k in keys:
            if kf == f:
                held = k
        g.run(1, held)
        if f in shots:
            print('shot', g.shot('run_%04d' % f))
    print('%d fields in %.1fs' % (fields, time.time() - t0))
    print(g.screen_text())
