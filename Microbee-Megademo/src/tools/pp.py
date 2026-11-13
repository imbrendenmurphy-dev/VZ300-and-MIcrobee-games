"""Source preprocessor for the megademo: expands exact T-state delays.

    DELAY n      -> instructions taking exactly n T-states. They clobber A
                    and the flags (the kernel's W and X areas allow that).

Output files are written next to the sources as .s (zasm assembles those).
"""
import re
import sys
from pathlib import Path

_lab = [0]


def delay(n):
    """list of asm lines taking exactly n T (A and flags clobbered)"""
    if n == 0:
        return []
    if n < 0 or n in (1, 2, 3, 5, 6):
        raise ValueError('DELAY %d is not possible' % n)
    out = []
    # long: ld a,k / dec a / jp nz  = 7 + 14k
    if n >= 70:
        k = (n - 7 - 12) // 14          # leave at least 12 for the rest
        k = max(1, k)
        rest = n - 7 - 14 * k
        while rest in (1, 2, 3, 5, 6) or rest < 0:
            k -= 1
            rest = n - 7 - 14 * k
        _lab[0] += 1
        out += ['\tld a,%d' % k, '.dl%d:\tdec a' % _lab[0], '\tjp nz,.dl%d' % _lab[0]]
        return out + delay(rest)
    # short: combinations of 12 (jr $+2), 10 (jp $+3), 9 (ld a,i), 7 (ld a,0), 4 (nop)
    best = None
    for a12 in range(n // 12 + 1):
        for a10 in range(3):
            for a9 in range(2):
                for a7 in range(4):
                    r = n - 12 * a12 - 10 * a10 - 9 * a9 - 7 * a7
                    if r >= 0 and r % 4 == 0:
                        nb = 2 * a12 + 3 * a10 + 2 * a9 + 2 * a7 + r // 4
                        if best is None or nb < best[0]:
                            best = (nb, a12, a10, a9, a7, r // 4)
    if best is None:
        raise ValueError('DELAY %d: no combination' % n)
    _, a12, a10, a9, a7, a4 = best
    out += ['\tjr $+2'] * a12 + ['\tjp $+3'] * a10 + ['\tld a,i'] * a9 + ['\tld a,0'] * a7 + ['\tnop'] * a4
    return out


SYMS = {}


def collect(text):
    for line in text.splitlines():
        m = re.match(r'^([A-Za-z_]\w*)\s*:?\s+(?:equ|EQU)\s+([^;]+)', line)
        if m:
            v = m.group(2).strip().replace('$', '0x')
            try:
                SYMS[m.group(1)] = int(eval(v, {}, dict(SYMS)))
            except Exception:
                pass


def expand(text):
    out = []
    for line in text.splitlines():
        m = re.match(r'^([.\w]+:)?(\s*)DELAY\s+([^;]+?)\s*(;.*)?$', line)
        if m:
            expr = m.group(3).replace('$', '0x')
            n = int(eval(expr, {}, dict(SYMS)))
            if m.group(1):
                out.append(m.group(1))
            out.append('\t; DELAY %d' % n)
            out += delay(n)
        else:
            out.append(line)
    return '\n'.join(out) + '\n'


def run(srcdir):
    srcdir = Path(srcdir)
    for f in sorted(srcdir.glob('*.asm')) + sorted(srcdir.glob('*.inc')):
        collect(f.read_text())
    for f in srcdir.glob('*.asm'):
        (srcdir / (f.stem + '.s')).write_text(expand(f.read_text()))


if __name__ == '__main__':
    run(sys.argv[1] if len(sys.argv) > 1 else 'src')
