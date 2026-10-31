# repeatedly assemble and turn out-of-range JRs into JPs
import re, subprocess, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
for _ in range(30):
    subprocess.run(['./build.sh'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    log = open('build/asm.log').read()
    m = re.findall(r'(\S+\.asm)\((\d+)\): error: \[JR\] Target out of range', log)
    if not m: break
    for f, ln in m:
        f = os.path.basename(f); path = 'src/' + f
        L = open(path).read().split('\n'); i = int(ln) - 1
        L[i] = L[i].replace('jr ', 'jp ', 1); open(path, 'w').write('\n'.join(L))
        print('fixed', f, ln, L[i].strip())
print(open('build/asm.log').read())
