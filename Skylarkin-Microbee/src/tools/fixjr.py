"""assemble; on 'relative jump out of range' turn that jr into jp (djnz into dec b / jp nz)"""
import re, subprocess, sys
for it in range(200):
    r = subprocess.run([sys.executable, '../tools/zasm.py', sys.argv[1] if len(sys.argv) > 1 else 'main.asm'], cwd='src', capture_output=True, text=True)
    out = r.stdout + r.stderr
    m = re.search(r'(\w+\.asm):(\d+): relative jump out of range', out.split('\n')[0].split('main.asm:')[-1] if 'main.asm:' in out else out)
    if not m:
        print(out.strip()[:600])
        break
    f, ln = m.group(1), int(m.group(2))
    L = open('src/' + f).read().split('\n')
    s = L[ln - 1]
    if 'djnz' in s:
        ind = s[:len(s) - len(s.lstrip())]
        lab = s.split('djnz')[1].strip()
        pre = s.split('djnz')[0]
        L[ln - 1] = pre + 'dec b\n' + ind + 'jp nz,' + lab
    else:
        L[ln - 1] = re.sub(r'\bjr\b', 'jp', s)
    open('src/' + f, 'w').write('\n'.join(L))
    print('fixed', f, ln)
