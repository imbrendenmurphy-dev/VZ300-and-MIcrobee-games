#!/usr/bin/env python3
"""Build VZMEGA.VZ (resident core) + VZMEGA.DAT (overlay parts) for the VZ300 megademo."""
import subprocess, os, sys, re, importlib
ROOT = '/root/vzmega'
B = f'{ROOT}/build'
SJ = f'{ROOT}/tools/sjasmplus'
sys.path.insert(0, f'{ROOT}/tools')
PARTS = sys.argv[1].split(',') if len(sys.argv) > 1 and sys.argv[1] else ['p1']
DEFS = [d for d in sys.argv[2:] if not d.startswith('NAME=')]
NAME = ([d[5:] for d in sys.argv[2:] if d.startswith('NAME=')] or ['VZMEGA'])[0]

def asm(src, extra=()):
    r = subprocess.run([SJ, '--nologo', '--msg=war', f'--sym={B}/{os.path.basename(src)}.sym',
                        f'--lst={B}/{os.path.basename(src)}.lst'] + list(extra) + [src],
                       cwd=f'{ROOT}/src', capture_output=True, text=True)
    out = r.stdout + r.stderr
    errs = [l for l in out.splitlines() if 'error' in l.lower() and 'Errors: 0' not in l]
    if r.returncode != 0 or errs:
        print(out); raise SystemExit(f'assembly failed: {src}')
    for l in out.splitlines():
        if l.startswith('>'): print('   ', l)
    return out

def write(path, txt):
    open(path, 'w').write(txt)

os.makedirs(B, exist_ok=True)
write(f'{B}/datname.inc', f'datname: db \'"{NAME}"\',0\n')
subprocess.run(['python3', f'{ROOT}/tools/song.py', B], check=True)

# pass 1: placeholder layout
write(f'{B}/layout.inc', 'OVL EQU $B000\n')
write(f'{B}/parts.inc', ''.join('        db 0,1\n' for _ in PARTS))
asm('resident.asm', [f'-D{d}' for d in DEFS])
sym = open(f'{B}/resident.asm.sym').read()
rend = int(re.search(r'^resident_end: EQU 0x([0-9A-F]+)', sym, re.M).group(1), 16)
OVL = (rend + 0xFF) & ~0xFF
print(f'resident $8000-${rend-1:04X} ({rend-0x8000} bytes), overlays at ${OVL:04X}')
write(f'{B}/layout.inc', f'OVL EQU ${OVL:04X}\n')
asm('resident.asm', [f'-D{d}' for d in DEFS])
# export resident labels (no locals, no engine constants)
eng = set(re.findall(r'^(\w+)\s+EQU', open(f'{ROOT}/src/engine.inc').read(), re.M))
lines = []
for l in open(f'{B}/resident.asm.sym'):
    m = re.match(r'^(\w+): EQU 0x([0-9A-F]+)', l)
    if not m: continue
    name, val = m.group(1), int(m.group(2), 16)
    if name in eng or name in ('OVL',): continue
    lines.append(f'{name} EQU ${val:04X}')
write(f'{B}/resident.sym.inc', '\n'.join(lines) + '\n')

# overlays
dat = bytearray()
counts = []
for p in PARTS:
    mod = importlib.import_module(f'assets_{p}')
    mod.build(f'{B}/{p}')
    asm(f'{p}.asm')
    binp = open(f'{B}/{p}.bin', 'rb').read()
    secs = (len(binp) + 511) // 512
    b1secs = 0
    b1f = f'{B}/{p}/bank1.bin'
    if os.path.exists(b1f):
        b1 = open(b1f, 'rb').read()
        assert len(b1) <= 10240, 'bank1 payload too big'
        b1secs = (len(b1) + 511) // 512
        dat += b1 + bytes(b1secs * 512 - len(b1))
        print(f'  {p}: bank-1 payload {len(b1)} bytes, {b1secs} sectors')
    assert OVL + secs * 512 <= 0xFA00, f'{p} too big: sector padding would overwrite DOS RAM at $FA00 (needs {OVL + secs*512 - 0xFA00} bytes less)'
    if b1secs: assert OVL + b1secs * 512 <= 0xFA00
    print(f'  {p}: {len(binp)} bytes, {secs} sectors, ends ${OVL+len(binp)-1:04X} (free {0xFA00-OVL-secs*512} after sector padding)')
    dat += binp + bytes(secs * 512 - len(binp))
    counts.append((b1secs, secs))
write(f'{B}/parts.inc', ''.join(f'        db {a},{c}\n' for a, c in counts))
asm('resident.asm', [f'-D{d}' for d in DEFS])
sym2 = open(f'{B}/resident.asm.sym').read()
rend2 = int(re.search(r'^resident_end: EQU 0x([0-9A-F]+)', sym2, re.M).group(1), 16)
assert rend2 == rend
open(f'{B}/{NAME}.DAT', 'wb').write(dat)
subprocess.run(['python3', f'{ROOT}/tools/mkvz.py', f'{B}/resident.bin', f'{B}/{NAME}.VZ', NAME, '0x8000'], check=True)
print(f'{NAME}.DAT: {len(dat)} bytes ({len(dat)//512} sectors)')
