"""Frame-time measurement of the original VZ-TYPE in the VZ300 model."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from vzm import VZ, FIELD
import statistics as st

def vzsyms(path):
    S = {}
    for l in open(path):
        if ': equ ' in l:
            n, v = l.split(': equ ')
            S[n.strip()] = int(v.strip().replace('0x', '').replace('$', ''), 16)
        elif ':' in l:
            try:
                n, v = l.split(':', 1)
                S[n.strip()] = int(v.strip().replace('equ', '').strip().replace('0x', '').replace('$', ''), 16)
            except ValueError:
                pass
    return S

def run(vzfile, symfile, fields=400, script=None, warm=80):
    S = vzsyms(symfile)
    v = VZ(vzfile)
    v.run_fields(150)
    v.keys = {'SPACE'}; v.run_fields(4); v.keys = set()
    v.run_until(S['mainloop'], 2000)
    v.run_fields(warm)
    v.watch(S['blit']); v.watch(S['waitframe'])
    v.events()
    for f in range(fields):
        if script:
            script(v, f)
        v.run_fields(1)
    ev = v.events()
    blits = [t for t, p in ev if p == S['blit']]
    waits = [t for t, p in ev if p == S['waitframe']]
    busy = []
    for b in blits:
        w = [x for x in waits if x > b]
        if w:
            busy.append(w[0] - b)
    per = [(b - a) / FIELD for a, b in zip(blits, blits[1:])]
    return v, S, busy, per

if __name__ == '__main__':
    def fire(v, f):
        v.keys = {'SPACE'} if (f // 6) % 2 else set()
    v, S, busy, per = run('/home/claude/work/orig/VZTYPE.VZ', '/home/claude/work/vzbuild/sym.txt', 400, fire)
    print('VZ busy T mean %d max %d (field %d T, 2 fields = %d)' % (st.mean(busy), max(busy), FIELD, 2 * FIELD))
    print('fields/frame mean %.2f  -> %.1f fps; frames at 2 fields: %.0f%%' % (st.mean(per), 50 / st.mean(per), 100 * sum(1 for p in per if p < 2.05) / len(per)))
