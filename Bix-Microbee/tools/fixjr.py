"""Build; while a JR is out of range, turn that JR into a JP in the source
and build again."""
import re, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
for it in range(80):
    r = subprocess.run([sys.executable, 'tools/build.py'], cwd=ROOT, capture_output=True, text=True)
    out = r.stdout + r.stderr
    m = re.search(r'(\w+)\.asm:(\d+): relative jump out of range', out)
    if not m:
        print('\n'.join(l for l in out.splitlines() if not l.startswith('; ')))
        sys.exit(r.returncode)
    f = ROOT / 'src' / (m.group(1) + '.asm')
    src = f.read_text().split('\n')
    i = int(m.group(2)) - 1
    if 'djnz' in src[i]:
        src[i] = src[i].replace('djnz', 'dec b\n        jp nz,', 1)
    else:
        assert 'jr' in src[i], src[i]
        src[i] = src[i].replace('jr', 'jp', 1)
    print('fixed %s:%d %s' % (f.name, i + 1, src[i].strip()))
    f.write_text('\n'.join(src))
