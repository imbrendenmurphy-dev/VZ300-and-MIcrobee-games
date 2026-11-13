"""Assemble; while a JR/DJNZ-free relative jump is out of range, turn that
JR into a JP in the source (.asm) and try again."""
import re, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
for it in range(60):
    r = subprocess.run([sys.executable, 'tools/build.py'], cwd=ROOT, capture_output=True, text=True)
    out = r.stdout + r.stderr
    m = re.search(r'(\w+)\.s:(\d+): relative jump out of range', out)
    if not m:
        print('\n'.join(l for l in out.splitlines() if not l.startswith('; ')))
        break
    sfile = ROOT / 'src' / (m.group(1) + '.s')
    line = sfile.read_text().split('\n')[int(m.group(2)) - 1].strip()
    afile = ROOT / 'src' / (m.group(1) + '.asm')
    src = afile.read_text().split('\n')
    for i, l in enumerate(src):
        if l.strip() == line and l.strip().startswith('jr'):
            src[i] = l.replace('jr', 'jp', 1)
            print('fixed %s: %s' % (afile.name, line))
            break
    else:
        print('cannot fix', line)
        break
    afile.write_text('\n'.join(src))
