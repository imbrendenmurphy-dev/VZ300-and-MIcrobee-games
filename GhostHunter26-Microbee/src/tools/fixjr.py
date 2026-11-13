"""assemble main.asm; turn any out-of-range JR into JP and try again"""
import re, subprocess, sys, os
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src')
for i in range(200):
    r = subprocess.run([sys.executable, '../tools/zasm.py', 'main.asm', '--sym=../build/main.sym'], cwd=SRC, capture_output=True, text=True)
    out = r.stdout + r.stderr
    m = re.search(r'(\w+\.asm):(\d+): relative jump out of range', out)
    if not m:
        print(out[-1500:])
        break
    f, n = os.path.join(SRC, m.group(1)), int(m.group(2))
    L = open(f).read().split('\n')
    assert re.search(r'\bjr\b', L[n - 1]), L[n - 1]
    L[n - 1] = re.sub(r'\bjr\b', 'jp', L[n - 1], count=1)
    open(f, 'w').write('\n'.join(L))
