#!/usr/bin/env python3
"""Build DEPTHS.VZ (single file: everything is in the load image, like BIX)."""
import subprocess, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = f'{ROOT}/build'
SJ = f'{ROOT}/tools/sjasmplus'
ZX0 = f'{ROOT}/tools/zx0'
os.makedirs(B, exist_ok=True)
subprocess.run(['python3', f'{ROOT}/tools/gen.py', B], check=True)


def asm(src, cwd, extra=(), quiet=False):
    r = subprocess.run([SJ, '--nologo', '--msg=war'] + list(extra) + [src], cwd=cwd, capture_output=True, text=True)
    out = r.stdout + r.stderr
    show = [l for l in out.splitlines() if 'error' in l.lower() or 'warn' in l.lower() or l.startswith('>')]
    if not quiet:
        print('\n'.join(show))
    if r.returncode or any('error' in l.lower() for l in show):
        if quiet:
            print('\n'.join(show))
        sys.exit(f'assembly failed: {src}')


def zx0(src, dst):
    subprocess.run([ZX0, '-f', src, dst], check=True, capture_output=True)


def sum16(d):
    return sum(d) & 0xFFFF


# chapter blocks -> archive (home bank image)
arch = bytearray()
tab = []
for n in (1, 2, 3):
    asm(f'level{n}.asm', B)
    b = open(f'{B}/level{n}.bin', 'rb').read()
    tab.append((0x4000 + len(arch), len(b)))
    arch += b
open(f'{B}/arch.bin', 'wb').write(arch)
zx0(f'{B}/arch.bin', f'{B}/arch.zx0')
defs = [f'-D{d}' for d in sys.argv[1:]]


def stage(cold_sum):
    open(f'{B}/stage.inc', 'w').write(
        'ARCH: dw ' + ','.join(f'{a},{l}' for a, l in tab) + '\n' +
        f'ARCH_SIZE EQU {len(arch)}\nARCH_SUM EQU {sum16(arch)}\nCOLD_SUM EQU {cold_sum}\n')


# pass 1: produces cold.bin
stage(0)
if not os.path.exists(f'{B}/cold.zx0'):
    open(f'{B}/cold.zx0', 'wb').write(b'\0')
asm('main.asm', f'{ROOT}/src', [f'--sym={B}/depths.sym', f'--lst={B}/depths.lst'] + defs, quiet=True)
cold = open(f'{B}/cold.bin', 'rb').read()
zx0(f'{B}/cold.bin', f'{B}/cold.zx0')
stage(sum16(cold))
# pass 2: final image
asm('main.asm', f'{ROOT}/src', [f'--sym={B}/depths.sym', f'--lst={B}/depths.lst'] + defs)
# packed program + stub -> the .VZ
ulen = os.path.getsize(f'{B}/depths.bin')
zx0(f'{B}/depths.bin', f'{B}/pay.zx0')
plen = os.path.getsize(f'{B}/pay.zx0')
open(f'{B}/stubdefs.inc', 'w').write(f'PLEN EQU {plen}\nULEN EQU {ulen}\n')
asm('stub.asm', f'{ROOT}/src')
subprocess.run(['python3', f'{ROOT}/tools/mkvz.py', f'{B}/stub.bin', f'{B}/DEPTHS.VZ', 'DEPTHS', '0x8000'], check=True)
print(f'archive {len(arch)} bytes ({os.path.getsize(B + "/arch.zx0")} packed), common {len(cold)} ({os.path.getsize(B + "/cold.zx0")} packed)')
