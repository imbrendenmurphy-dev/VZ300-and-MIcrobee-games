"""Assemble; whenever a JR is out of range, turn that one into a JP and try again."""
import subprocess, sys, re, os
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src')
for n in range(200):
    r = subprocess.run([sys.executable, os.path.join(SRC, '..', 'tools', 'zasm.py'), 'main.asm', '--sym=../build/main.sym'], cwd=SRC, capture_output=True, text=True)
    m = re.search(r'error: .*?(\w+\.asm):(\d+): relative jump out of range', r.stdout + r.stderr)
    if not m:
        sys.stdout.write(r.stdout + r.stderr)
        break
    f, ln = os.path.join(SRC, m.group(1)), int(m.group(2))
    L = open(f).read().split('\n')
    assert re.search(r'\bjr\b', L[ln - 1]), L[ln - 1]
    L[ln - 1] = re.sub(r'\bjr\b', 'jp', L[ln - 1], count=1)
    open(f, 'w').write('\n'.join(L))
    print('jp at %s:%d' % (m.group(1), ln))
