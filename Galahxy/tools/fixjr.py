import subprocess, re, sys
for _ in range(60):
    r = subprocess.run([sys.executable, 'tools/build.py'], capture_output=True, text=True)
    o = r.stdout + r.stderr
    m = re.search(r'(\S+\.asm):(\d+): relative jump out of range', o)
    if not m: print(o[-1500:]); break
    fn, ln = m.group(1), int(m.group(2))
    L = open(fn).read().split('\n')
    old = L[ln - 1]
    L[ln - 1] = re.sub(r'\bjr\b', 'jp', old, count=1)
    if L[ln-1] == old: print('cannot fix', fn, ln, old); break
    open(fn, 'w').write('\n'.join(L)); print('jr->jp', fn.split('/')[-1], ln)
