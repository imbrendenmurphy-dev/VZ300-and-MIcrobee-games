"""Turn out-of-range JRs into JPs: assemble, patch the reported line, repeat."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import zasm

src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'src', 'main.asm')
for it in range(400):
    a = zasm.Asm()
    try:
        a.assemble(src)
        print('clean after', it, 'fixes')
        break
    except zasm.AsmError as e:
        msg = str(e)
        m = re.findall(r'([^\n:]+\.asm):(\d+): relative jump out of range', msg)
        if not m:
            print(msg); break
        fn, ln = m[-1]
        ln = int(ln)
        lines = open(fn).read().split('\n')
        old = lines[ln - 1]
        new = re.sub(r'\bjr\b', 'jp', old, count=1, flags=re.I)
        if new == old:
            print('cannot fix', fn, ln, old); break
        lines[ln - 1] = new
        open(fn, 'w').write('\n'.join(lines))
        print('fixed %s:%d' % (os.path.basename(fn), ln))
