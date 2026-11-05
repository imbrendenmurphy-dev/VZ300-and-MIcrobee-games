# egg.py - extract the original 1984 Dracula's Castle mode 0 pictures for the Easter egg
import pickle
from lz2 import compress_opt as lz_compress
import os
lines = pickle.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'orig', 'lines.pkl'), 'rb'))
L = {ln: (s, raw) for ln, s, raw in lines}

def run(a, b):
    scr = [[32, 0] for _ in range(512)]; pos = 0; col = 0
    for ln in sorted(L):
        if ln < a or ln > b: continue
        raw = L[ln][1]
        st = []; cur = []; q = False
        for c in raw:
            if c == 34: q = not q
            if c == 58 and not q: st.append(cur); cur = []
            else: cur.append(c)
        st.append(cur)
        for s in st:
            if not s: continue
            t = s[0]
            if t == 0x97: col = int(bytes(s[1:]).decode() or 1) - 1
            elif t == 0x84: scr = [[32, 0] for _ in range(512)]; pos = 0
            elif t == 0xB2:
                j = 1
                if j < len(s) and s[j] == 64:
                    j += 1; n = ''
                    while s[j] != 44: n += chr(s[j]); j += 1
                    j += 1; pos = int(n)
                semi = False
                while j < len(s):
                    if s[j] == 34:
                        j += 1
                        while j < len(s) and s[j] != 34:
                            if pos < 512: scr[pos] = [s[j], col]
                            pos += 1; j += 1
                        j += 1
                        semi = (j < len(s) and s[j] == 59)
                        if semi: j += 1
                    else: j += 1
                if not semi: pos = (pos // 32 + 1) * 32
    out = bytearray()
    for c, cl in scr:
        if c >= 128:
            out.append(0x80 | (c & 0x7F) if (c & 0x70) else 0x80 | (cl << 4) | (c & 0x0F))
        else:
            out.append(c & 0x3F)
    return bytes(out)

SCREENS = [('ahead', 251, 272), ('left', 187, 213), ('right', 219, 245), ('dracula', 451, 481)]
def asm():
    s = ['; generated: original 1984 mode 0 pictures']
    tot = 0
    for n, a, b in SCREENS:
        d = run(a, b)
        c = lz_compress(d); tot += len(c)
        s.append('egg_%s: db %s' % (n, ','.join(map(str, c))))
    s.append('; egg bytes %d' % tot)
    return '\n'.join(s) + '\n'
if __name__ == '__main__':
    print(asm().splitlines()[-1])
