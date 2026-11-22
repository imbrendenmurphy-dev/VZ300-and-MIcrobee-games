"""VZ-ED 0.2 tests: screen wrap (against a Python model of the wrap rule),
blocks + clipboard (spare SRAM bank and fallback), find / replace, wrap in
VZED.CFG, selection highlighting, and the card staying clean.

    py t9.py            all parts
    py t9.py wrap 5     only the random wrap test, seed 5
"""
import sys, random; sys.path.insert(0, '.')
from harness import *
dos = open('VZDOS.VZ', 'rb').read(); ed = open('../out/VZED.VZ', 'rb').read()
sym = {l.split()[1]: int(l.split()[0], 16) for l in open('../out/vzed.sym')}
FAILS = []
def check(cond, what):
    print(('  ok   ' if cond else '  FAIL ') + what)
    if not cond: FAILS.append(what)

def w16(m, a): return m.z.mem[a] | m.z.mem[a+1] << 8
def buffer(m):
    gs, ge = w16(m, sym['gs']), w16(m, sym['ge']); B = sym['BUFS']
    return bytes(m.z.mem[B:gs] + m.z.mem[ge:0xF600]).decode('latin1'), gs - B, w16(m, sym['curln'])
def scr(m, r): return bytes(m.z.mem[0x8000 + 32*r:0x8020 + 32*r])

# ------------------------------------------------------------------ model of the wrap rule
def wrap_rows(t):
    """start of every screen row (wrap mode), for the whole text"""
    S = []; p = 0; n = len(t)
    while True:
        S.append(p)
        i = 0; sp = None; nxt = None
        while i < 32:
            if p + i == n: return S
            ch = t[p+i]
            if ch == '\n': nxt = p + i + 1; break
            i += 1
            if ch == ' ': sp = p + i
        if nxt is None: nxt = sp if sp is not None else p + 32
        p = nxt
def row_end(S, k, n): return S[k+1] if k + 1 < len(S) else n + 1
def row_of(S, c): return max(k for k in range(len(S)) if S[k] <= c)

class Model:
    def __init__(s, text, rows, wrap=True):
        s.t = list(text); s.c = 0; s.goal = None; s.ins = True; s.rows = rows; s.wrap = wrap
    def T(s): return ''.join(s.t)
    def ls(s):
        i = s.c
        while i > 0 and s.t[i-1] != '\n': i -= 1
        return i
    def le(s):
        i = s.c
        while i < len(s.t) and s.t[i] != '\n': i += 1
        return i
    def sg(s):
        if s.goal is None:
            if s.wrap:
                S = wrap_rows(s.T()); s.goal = s.c - S[row_of(S, s.c)]
            else: s.goal = s.c - s.ls()
    def vmove(s, d):
        if not s.wrap:
            if d < 0:
                a = s.ls()
                if a == 0: return
                b = a - 1
                while b > 0 and s.t[b-1] != '\n': b -= 1
                s.c = b + min(s.goal, a - 1 - b)
            else:
                e = s.le()
                if e >= len(s.t): return
                a = e + 1; s.c = a; s.c = a + min(s.goal, s.le() - a)
            return
        S = wrap_rows(s.T()); n = len(s.t); r = row_of(S, s.c) + d
        if r < 0 or r >= len(S): return
        s.c = S[r] + min(s.goal, row_end(S, r, n) - S[r] - 1)
    def key(s, k):
        if len(k) == 1 and k != '\n':
            if not s.ins and s.c < len(s.t) and s.t[s.c] != '\n': del s.t[s.c]
            s.t.insert(s.c, k); s.c += 1; s.goal = None
        elif k == '\n': s.t.insert(s.c, '\n'); s.c += 1; s.goal = None
        elif k == 'LT': s.c = max(0, s.c - 1); s.goal = None
        elif k == 'RT': s.c = min(len(s.t), s.c + 1); s.goal = None
        elif k == 'UP': s.sg(); s.vmove(-1)
        elif k == 'DN': s.sg(); s.vmove(1)
        elif k == 'PU':
            s.sg()
            for i in range(s.rows - 1): s.vmove(-1)
        elif k == 'PD':
            s.sg()
            for i in range(s.rows - 1): s.vmove(1)
        elif k == 'HOME': s.c = s.ls(); s.goal = None
        elif k == 'END': s.c = s.le(); s.goal = None
        elif k == 'BS':
            if s.c > 0: del s.t[s.c-1]; s.c -= 1
            s.goal = None
        elif k == 'DEL':
            if s.c < len(s.t): del s.t[s.c]
            s.goal = None
        elif k == 'TOP': s.c = 0; s.goal = None
        elif k == 'BOT': s.c = len(s.t); s.goal = None
        elif k == 'INS': s.ins = not s.ins
    def line(s): return s.t[:s.c].count('\n') + 1

KEY = {'\n': 'RET', 'LT': ('CTRL', 'M'), 'RT': ('CTRL', ','), 'UP': ('CTRL', '.'), 'DN': ('CTRL', 'SPACE'),
       'PU': ('CTRL', 'R'), 'PD': ('CTRL', 'C'), 'HOME': ('CTRL', 'Z'), 'END': ('CTRL', 'X'), 'BS': ('CTRL', ':'),
       'DEL': ('CTRL', ';'), 'TOP': ('CTRL', 'T'), 'BOT': ('CTRL', 'B'), 'INS': ('CTRL', 'L'), ' ': 'SPACE'}
def keyfor(k): return KEY.get(k) or (('SHIFT', k) if k.isupper() else (k.upper() if k.isalpha() else k))

def screen_check(m, md, label):
    """the screen rows, top and the cursor cell against the model"""
    t = md.T(); n = len(t); docrows = m.z.mem[sym['docrows']]
    top = w16(m, sym['top']); cur = w16(m, sym['curcell'])
    if md.wrap:
        S = wrap_rows(t)
        if top not in S: return 'top %d is not a row start' % top
        g0 = S.index(top); exp = []
        for k in range(docrows):
            g = g0 + k
            if g >= len(S): exp.append(''); continue
            e = row_end(S, g, n); exp.append(t[S[g]:min(e, n)].rstrip('\n'))
        cr = row_of(S, md.c); ccell = (cr - g0 + 1) * 32 + (md.c - S[cr])
    else:
        lines = t.split('\n'); starts = [0]
        for L in lines[:-1]: starts.append(starts[-1] + len(L) + 1)
        if top not in starts: return 'top %d is not a line start' % top
        hs = w16(m, sym['hs']); g0 = starts.index(top); exp = []
        for k in range(docrows):
            exp.append(lines[g0 + k][hs:hs + 32] if g0 + k < len(lines) else '')
        cl = md.line() - 1; ccell = (cl - g0 + 1) * 32 + (md.c - starts[cl] - hs)
    for k in range(docrows):
        got = bytes(b & 0x7F for b in scr(m, k + 1)).decode('latin1')
        if got != exp[k].ljust(32): return 'row %d: %r, expected %r' % (k + 1, got, exp[k].ljust(32))
    if cur != ccell: return 'cursor cell %d, expected %d' % (cur, ccell)
    return None

def sel_check(m, md, anchor):
    """highlighted cells (bit 7, apart from the cursor) = the block on screen"""
    t = md.T(); n = len(t); docrows = m.z.mem[sym['docrows']]
    top = w16(m, sym['top']); cur = w16(m, sym['curcell'])
    s0, s1 = min(anchor, md.c), max(anchor, md.c)
    want = set()
    if md.wrap:
        S = wrap_rows(t); g0 = S.index(top)
        for k in range(docrows):
            g = g0 + k
            if g >= len(S): break
            for p in range(S[g], row_end(S, g, n)):
                if s0 <= p < s1: want.add((k + 1) * 32 + p - S[g])
    else:
        hs = w16(m, sym['hs']); lines = t.split('\n'); starts = [0]
        for L in lines[:-1]: starts.append(starts[-1] + len(L) + 1)
        g0 = starts.index(top)
        for k in range(docrows):
            if g0 + k >= len(lines): break
            for x in range(min(32, max(0, len(lines[g0+k]) + 1 - hs))):
                p = starts[g0+k] + hs + x
                if s0 <= p < s1: want.add((k + 1) * 32 + x)
    got = {i for i in range(32, 32 * (docrows + 1)) if m.z.mem[0x8000 + i] & 0x80}
    got.discard(cur); want.discard(cur)
    return None if got == want else 'highlight: extra %s missing %s' % (sorted(got - want)[:8], sorted(want - got)[:8])

def machine(files, bank=True, cfg=None):
    c = Card(spc=8); c.addfile(2, 'VZDOS.VZ', dos); c.addfile(2, 'SHELL.VZ', ed)
    for name, data in files: c.addfile(2, name, data)
    if cfg is not None: c.addfile(2, 'VZED.CFG', cfg)
    c.addfile(2, 'VZED.OVL', open('../out/VZED.OVL', 'rb').read())   # (0.7: quitting needs it)
    c.finish()
    m = VZ(dos[24:], c, maxlba=max(c.sec) + 5000, bank=bank); m.run(0x4004, frames=160)
    m.card = c
    return m
def keys(m, ks, extra=10):
    m.type_keys(ks); m.run_script(extra=extra)
def open_t(m):     # the file list: SHELL.VZ, T.TXT, VZDOS.VZ (folders first, then by name)
    keys(m, [('CTRL', 'O'), ('WAIT', 20), 'SPACE', 'RET', ('WAIT', 30)])

PARA = ('The VZ300 was sold by Dick Smith in Australia and New Zealand, a colour computer with a '
        'Z80 and the 6847 video chip. Thisisaverylongwordwithnospacesatalltoforceahardbreak here. '
        'abcdefghijklmnopqrstuvwxyz012345\nexactly 31 characters on a line\n'
        'exactly 32 characters on a line!\n\n\nshort\n' + 'word ' * 40 + '\nlast line without a line feed')

def run_wrap(seed, style=0, steps=10, per=12, wrap=True):
    random.seed(seed)
    m = machine([('T.TXT', PARA.encode())]); open_t(m)
    for i in range(style): keys(m, [('CTRL', 'D'), ('WAIT', 5)])
    if wrap: keys(m, [('CTRL', 'W'), ('WAIT', 5)])
    md = Model(PARA, m.z.mem[sym['docrows']], wrap)
    err = screen_check(m, md, 'start')
    if err: return 'after CTRL+W: ' + err
    pool = ['a', 'b', ' ', ' ', 'Q', '.', '\n', 'LT', 'RT', 'UP', 'DN', 'UP', 'DN', 'UP', 'DN', 'HOME', 'END',
            'BS', 'DEL', 'PU', 'PD', 'TOP', 'BOT', 'x', 'y', 'z', ' ']
    for step in range(steps):
        seq = [random.choice(pool) for _ in range(per)]
        for k in seq:
            md.key(k); m.type_keys([keyfor(k)])
            if k in ('TOP', 'BOT', 'PU', 'PD'): m.type_keys([('WAIT', 15)])
        m.run_script(extra=25)
        t, cur, ln = buffer(m)
        if t != md.T() or cur != md.c or ln != md.line():
            return 'step %d %s: text/cursor/line differ: emu c=%d l=%d, model c=%d l=%d' % (step, seq, cur, ln, md.c, md.line())
        err = screen_check(m, md, 'step')
        if err: return 'step %d %s: %s' % (step, seq, err)
    return None

def part_wrap():
    print('== screen wrap: random editing against the model')
    for seed, style in ((1, 0), (2, 0), (3, 2), (4, 1), (5, 0), (6, 2)):
        err = run_wrap(seed, style)
        check(err is None, 'seed %d style %d%s' % (seed, style, '' if err is None else ': ' + err))

def part_blocks():
    print('== blocks and clipboard')
    text = 'alpha beta gamma\ndelta epsilon\nzeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma\n'
    for bank in (True, False):
        for wrap in (False, True):
            m = machine([('T.TXT', text.encode())], bank=bank); open_t(m)
            if wrap: keys(m, [('CTRL', 'W'), ('WAIT', 5)])
            md = Model(text, m.z.mem[sym['docrows']], wrap)
            tag = '(%s bank, wrap %s)' % ('spare' if bank else 'no', 'on' if wrap else 'off')
            check(m.z.mem[sym['clipbank']] == (1 if bank else 0), 'clipboard place %s' % tag)
            # mark "beta gamma\ndelta" forwards: 6 right, mark, 16 right
            keys(m, [('CTRL', ',')] * 6 + [('CTRL', 'K')] + [('CTRL', ',')] * 16)
            for k in ['RT'] * 22: md.key(k)
            err = sel_check(m, md, 6); check(err is None, 'block shown %s %s' % (tag, err or ''))
            keys(m, [('CTRL', 'J'), ('WAIT', 5), ('CTRL', 'B'), ('WAIT', 5), ('CTRL', 'P'), ('WAIT', 5)])
            t, cur, ln = buffer(m); exp = text + 'beta gamma\ndelta'
            check(t == exp and cur == len(exp) and ln == 5, 'copy + paste at the end %s' % tag)
            # mark backwards over "epsilon\nzeta " and cut it
            # end of "delta epsilon", 6 right = after "zeta ", mark, 13 left = start of "epsilon"
            keys(m, [('CTRL', 'T'), ('WAIT', 5), ('CTRL', 'SPACE'), ('CTRL', 'X')] + [('CTRL', ',')] * 6
                 + [('CTRL', 'K')] + [('CTRL', 'M')] * 13 + [('CTRL', 'Y'), ('WAIT', 5)])
            t, cur, ln = buffer(m)
            exp2 = exp.replace('epsilon\nzeta ', '', 1)
            check(t == exp2 and cur == exp.index('epsilon') and ln == 2, 'cut (marked backwards) %s' % tag)
            keys(m, [('CTRL', 'P'), ('WAIT', 5)])
            t, cur, ln = buffer(m)
            check(t == exp and ln == 3, 'paste it back %s' % tag)
            # delete key with a block: mark "alpha " and press CTRL+;
            keys(m, [('CTRL', 'T'), ('WAIT', 5), ('CTRL', 'K')] + [('CTRL', ',')] * 6 + [('CTRL', ';'), ('WAIT', 5)])
            t, cur, ln = buffer(m)
            check(t == exp[6:] and cur == 0, 'delete a marked block %s' % tag)
            # copy with nothing marked: message, text unchanged
            keys(m, [('CTRL', 'J'), ('WAIT', 5)])
            check(bytes(scr(m, 0)).startswith(b'MARK A BLOCK FIRST'), 'copy without a block says so %s' % tag)
            # typing while marking ends the mark and keeps the text
            keys(m, [('CTRL', 'K'), ('CTRL', ','), ('CTRL', ','), 'Q'])
            t, cur, ln = buffer(m)
            check(t == exp[6:8] + 'q' + exp[8:] and m.z.mem[sym['selon']] == 0, 'typing ends marking %s' % tag)
    # fallback clipboard is cleared by the file list; the bank one survives
    for bank in (True, False):
        m = machine([('T.TXT', b'one two three\n')], bank=bank); open_t(m)
        keys(m, [('CTRL', 'K')] + [('CTRL', ',')] * 3 + [('CTRL', 'J'), ('WAIT', 5)])
        open_t(m)
        keys(m, [('CTRL', 'B'), ('WAIT', 5), ('CTRL', 'P'), ('WAIT', 5)])
        t, cur, ln = buffer(m)
        if bank: check(t == 'one two three\none', 'clipboard kept across CTRL+O (spare bank)')
        else: check(t == 'one two three\n' and bytes(scr(m, 0)).startswith(b'CLIPBOARD EMPTY'),
                    'fallback clipboard emptied by CTRL+O (and says so)')
    # big block: 9000 characters (fits the bank, not the fallback)
    big = ''.join('line %04d of the big block test\n' % i for i in range(290))
    for bank in (True, False):
        m = machine([('T.TXT', big.encode())], bank=bank); open_t(m)
        if bank:     # cut the whole file, then paste it back
            keys(m, [('CTRL', 'K'), ('CTRL', 'B'), ('WAIT', 20), ('CTRL', 'Y'), ('WAIT', 20)])
            check(buffer(m)[0] == '', 'whole file cut')
            keys(m, [('CTRL', 'P'), ('WAIT', 20)])
            t, cur, ln = buffer(m)
            check(t == big and ln == 291, '%d-character block cut and pasted back (spare bank)' % len(big))
        else:
            keys(m, [('CTRL', 'K'), ('CTRL', 'B'), ('WAIT', 20), ('CTRL', 'Y'), ('WAIT', 10)])
            check(bytes(scr(m, 0)).startswith(b'BLOCK TOO BIG') and buffer(m)[0] == big,
                  'too big for the fallback clipboard: says so, nothing cut')
    # graphics style + selection colours: draw the block, the cursor and normal text
    m = machine([('T.TXT', text.encode())]); open_t(m)
    keys(m, [('CTRL', 'D'), ('WAIT', 5), ('CTRL', 'D'), ('WAIT', 5), ('CTRL', 'K')] + [('CTRL', ',')] * 5)
    md = Model(text, m.z.mem[sym['docrows']], False)
    for k in ['RT'] * 5: md.key(k)
    err = sel_check(m, md, 0); check(err is None, 'block shown in graphics style %s' % (err or ''))
    import shot; shot.save(m, '../testout/t9_block_graphics.png')
    keys(m, [('CTRL', 'D'), ('WAIT', 5)])
    shot.save(m, '../testout/t9_block_text.png')

def part_find():
    print('== find and replace')
    text = 'The cat sat.\nA Cat? cat-like CATS\nend cat\n'
    m = machine([('T.TXT', text.encode())]); open_t(m)
    keys(m, [('CTRL', 'F'), ('WAIT', 5)] + text_for('cat') + ['RET', ('WAIT', 10)])
    t, cur, ln = buffer(m)
    check(cur == 4 and m.z.mem[sym['selon']] == 2 and w16(m, sym['anchor']) == 7, 'find "cat": first match, shown')
    md = Model(text, 15, False); md.c = 4
    err = sel_check(m, md, 7); check(err is None, 'match highlighted %s' % (err or ''))
    pos = []
    for i in range(6):
        keys(m, [('CTRL', 'G'), ('WAIT', 10)]); pos.append(buffer(m)[1])
    exp = [i for i in range(len(text)) if text.lower().startswith('cat', i)]
    check(pos == exp[1:] + [exp[0], exp[1]], 'find again goes through every match, either case, then from the top %s' % pos)
    keys(m, [('CTRL', ',')])
    check(m.z.mem[sym['selon']] == 0, 'the highlight goes at the next key')
    keys(m, [('CTRL', 'F'), ('WAIT', 5), ('CTRL', ':'), ('CTRL', ':'), ('CTRL', ':')] + text_for('dog') + ['RET', ('WAIT', 10)])
    t, cur, ln = buffer(m)
    check(bytes(scr(m, 0)).startswith(b'NOT FOUND') and cur == exp[1] + 1, 'not found: cursor stays, says so')
    # replace: Y, N, then A (all the rest)
    keys(m, [('CTRL', 'T'), ('WAIT', 5), ('CTRL', 'E'), ('WAIT', 5), ('CTRL', ':'), ('CTRL', ':'), ('CTRL', ':')]
         + text_for('cat') + ['RET', ('WAIT', 5)] + text_for('dog') + ['RET', ('WAIT', 15), 'Y', ('WAIT', 15), 'N', ('WAIT', 15), 'A', ('WAIT', 20)])
    t, cur, ln = buffer(m)
    check(t == 'The dog sat.\nA Cat? dog-like dogS\nend dog\n', 'replace: yes, no, all  -> %r' % t)
    check(bytes(scr(m, 0)).startswith(b'4 REPLACED'), 'says how many: %r' % bytes(scr(m, 0))[:16])
    # replace with nothing, stop with CTRL+Q
    keys(m, [('CTRL', 'T'), ('WAIT', 5), ('CTRL', 'E'), ('WAIT', 5), ('CTRL', ':'), ('CTRL', ':'), ('CTRL', ':')]
         + text_for('dog') + ['RET', ('WAIT', 5), ('CTRL', ':'), ('CTRL', ':'), ('CTRL', ':'), 'RET', ('WAIT', 15),
         'Y', ('WAIT', 15), ('CTRL', 'Q'), ('WAIT', 15)])
    t, cur, ln = buffer(m)
    check(t == 'The  sat.\nA Cat? dog-like dogS\nend dog\n' and bytes(scr(m, 0)).startswith(b'1 REPLACED'),
          'replace with nothing, then stop -> %r' % t)
    # save: the card is clean and the file is what's in the editor
    keys(m, [('CTRL', 'S'), ('WAIT', 60)])
    p, f = FS(m.card.sec).check(); fs = FS(m.card.sec)
    check(not p and fs.readfile(*f['/T.TXT'], fs.fat()) == t.replace('\n', '\r\n').encode() if '\r' in text else
          fs.readfile(*f['/T.TXT'], fs.fat()) == t.encode(), 'saved, card clean %s' % (p or ''))

def part_cfg():
    print('== word wrap in VZED.CFG')
    m = machine([('T.TXT', PARA.encode())])
    keys(m, [('CTRL', 'W'), ('WAIT', 5), ('CTRL', 'Q'), ('WAIT', 80)], extra=40)
    p, f = FS(m.card.sec).check(); fs = FS(m.card.sec)
    cfg = fs.readfile(*f['/VZED.CFG'], fs.fat()) if '/VZED.CFG' in f else None
    check(cfg is not None and cfg[:5] == b'VZED\x01' and cfg[7] == 3, 'quit writes VZED.CFG with wrap on: %r' % cfg)
    check(not p, 'card clean %s' % (p or ''))
    m = machine([('T.TXT', PARA.encode())], cfg=b'VZED\x01\x00\x00\x03')
    check(m.z.mem[sym['wrap']] == 1 and m.z.mem[sym['insmode']] == 1, 'VZED.CFG with wrap on: starts wrapped')
    m = machine([('T.TXT', PARA.encode())], cfg=b'VZED\x01\x00\x00\x01')
    check(m.z.mem[sym['wrap']] == 0 and m.z.mem[sym['insmode']] == 1, '0.1 VZED.CFG: wrap off, insert on')
    open_t(m); keys(m, [('CTRL', 'W'), ('WAIT', 5), ('CTRL', ','), ('WAIT', 5)])
    check(bytes(scr(m, 0))[30:31] == b'W', 'title bar shows W in wrap mode')
    import shot; shot.save(m, '../testout/t9_wrap_text.png')
    keys(m, [('CTRL', 'D'), ('WAIT', 5), ('CTRL', 'D'), ('WAIT', 5)])
    shot.save(m, '../testout/t9_wrap_graphics.png')

def part_sel_wrap():
    print('== block highlighting while moving (wrap on and off)')
    for wrap in (False, True):
        random.seed(11 + wrap)
        m = machine([('T.TXT', PARA.encode())]); open_t(m)
        if wrap: keys(m, [('CTRL', 'W'), ('WAIT', 5)])
        md = Model(PARA, m.z.mem[sym['docrows']], wrap)
        keys(m, [('CTRL', 'SPACE')] * 2); md.key('DN'); md.key('DN')
        keys(m, [('CTRL', 'K')]); anchor = md.c
        bad = None
        for i in range(25):
            k = random.choice(['LT', 'RT', 'UP', 'DN', 'DN', 'END', 'HOME', 'PD'])
            md.key(k); keys(m, [keyfor(k), ('WAIT', 10)], extra=5)
            t, cur, ln = buffer(m)
            err = (cur != md.c and 'cursor %d vs %d' % (cur, md.c)) or screen_check(m, md, '') or sel_check(m, md, anchor)
            if err: bad = 'after %d keys: %s' % (i + 1, err); break
        check(bad is None, 'wrap %s: %s' % ('on' if wrap else 'off', bad or '25 moves'))

def part_hscroll():
    print('== wrap off: sideways scrolling, every screen row checked (0.1 bug: blank screen)')
    for seed, style in ((21, 0), (22, 2), (23, 1)):
        err = run_wrap(seed, style, wrap=False)
        check(err is None, 'seed %d style %d%s' % (seed, style, '' if err is None else ': ' + err))

parts = dict(hscroll=part_hscroll, wrap=part_wrap, blocks=part_blocks, find=part_find, cfg=part_cfg, sel=part_sel_wrap)
if __name__ != '__main__': pass
elif len(sys.argv) > 2 and sys.argv[1] == 'wrap':
    err = run_wrap(int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 0, steps=20)
    print('seed', sys.argv[2], 'ok' if err is None else err)
else:
    for name in (sys.argv[1:] or parts):
        parts[name]()
    print('\n%d FAILED' % len(FAILS) if FAILS else '\nALL PASSED')
