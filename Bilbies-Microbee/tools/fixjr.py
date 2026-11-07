"""assemble src/main.asm; turn out-of-range jr into jp until it assembles"""
import re, subprocess, sys, os
SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src')
main = sys.argv[1] if len(sys.argv) > 1 else 'main.asm'
for _ in range(60):
    r = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zasm.py'), main, '--sym=../build/%s.sym' % main[:-4]], cwd=SRC, capture_output=True, text=True)
    err = r.stdout + r.stderr
    m = re.search(r'(\w+\.asm):(\d+): relative jump out of range', err)
    if not m:
        print(err.strip()[:600] or 'ok')
        break
    f, ln = os.path.join(SRC, m.group(1)), int(m.group(2))
    lines = open(f).read().split('\n')
    lines[ln - 1] = re.sub(r'\bjr\b', 'jp', lines[ln - 1], count=1)
    open(f, 'w').write('\n'.join(lines))
    print('jr->jp', m.group(1), ln)
