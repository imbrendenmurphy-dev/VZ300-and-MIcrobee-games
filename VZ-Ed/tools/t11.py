"""VZ-ED 0.3 tests: overlays (VZED.OVL) and the sheet view.

    py t11.py           all parts
    py t11.py sheet     only the sheet view
The sheet's video memory is compared with a Python model of what it should show
after every move; RETURN is checked against where the editor ends up.
"""
import sys, random; sys.path.insert(0, '.')
from harness import *
import shot
from t9 import (check, FAILS, w16, buffer, scr, wrap_rows, Model, keyfor, screen_check, keys, PARA, dos, sym)
S = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'testout', '')
ed = open('../out/VZED.VZ', 'rb').read(); OVL = open('../out/VZED.OVL', 'rb').read()
osym = {l.split()[1]: int(l.split()[0], 16) for l in open('../out/ovl_sheet.sym')}

def machine(files, bank=True, ovl=OVL):
    c = Card(spc=8); c.addfile(2, 'VZDOS.VZ', dos); c.addfile(2, 'SHELL.VZ', ed)
    for name, data in files: c.addfile(2, name, data)
    if ovl is not None: c.addfile(2, 'VZED.OVL', ovl)
    c.finish()
    m = VZ(dos[24:], c, maxlba=max(c.sec) + 5000, bank=bank); m.run(0x4004, frames=120)
    m.card = c; m.sec0 = dict(c.sec)
    return m
def open_t(m):     # list: SHELL.VZ, T.TXT, VZDOS.VZ, VZED.OVL
    keys(m, [('CTRL', 'O'), ('WAIT', 20), 'SPACE', 'RET', ('WAIT', 30)])
def title(m): return bytes(b & 0x7F for b in scr(m, 0)).decode('latin1')
def card_same(m): return m.card.sec == m.sec0 or FS(m.card.sec).check() is None

# ------------------------------------------------------------------ model of the sheet
def rows_of(t, wrap):
    if wrap: return wrap_rows(t)
    st = [0]
    for i, ch in enumerate(t):
        if ch == '\n': st.append(i + 1)
    return st
def sheet_model(t, wrap, S0, H0, b, bh, DR):
    R = rows_of(t, wrap); n = len(t)
    SH, W = (256, 32) if wrap else (64, 128)
    def start(r): return R[r] if r < len(R) else n
    v = bytearray(2048)
    for i in range(SH):
        s, e = start(S0 + i), start(S0 + i + 1)
        cnt = e - s
        chars = t[s + H0:s + H0 + min(cnt - H0, W)] if cnt > H0 else ''
        inrow = 0 <= S0 + i - b < DR
        for x in range(W):
            ch = chars[x] if x < len(chars) else ' '
            c = 2 if ord(ch) > 32 else 0
            if inrow and bh - H0 <= x < bh - H0 + 32: c += 1
            a = (i & 63) * 32 + (i >> 6) * 8 + x // 4
            v[a] |= c << ((3 - x % 4) * 2)
    return bytes(v)
def sheet_check(m, md, wrap, what):
    g = lambda n: w16(m, osym[n])
    S0, H0, b, bh = g('zS0'), g('zH0'), g('zB'), g('zBH'); DR = m.z.mem[osym['zDR']]
    R = rows_of(md.T(), wrap)
    if not (m.latch & 8): return '%s: not in graphics mode' % what
    if g('zNR') != len(R): return '%s: %d rows, expected %d' % (what, g('zNR'), len(R))
    SH = 256 if wrap else 64
    if not (S0 <= b and b + min(DR, len(R) - b) <= S0 + SH): return '%s: box row %d not on show (S0 %d)' % (what, b, S0)
    if not (H0 <= bh <= H0 + 96): return '%s: box column %d not on show (H0 %d)' % (what, bh, H0)
    want = sheet_model(md.T(), wrap, S0, H0, b, bh, DR)
    got = bytes(m.z.mem[0x7000:0x7800])
    if got != want:
        a = next(i for i in range(2048) if got[i] != want[i])
        return '%s: video differs at +%d (row %d): %02X, expected %02X  (S0 %d H0 %d b %d bh %d)' % (
            what, a, a // 32, got[a], want[a], S0, H0, b, bh)
    return None

LONG = ('\n'.join(('line %d ' % i) + ('x' * (i * 7 % 150)) + (' end' if i % 3 else '') for i in range(110))
        + '\n\n  indented text\nlast')

def run_sheet(wrap, style, seed, shots=False):
    random.seed(seed)
    text = LONG if not wrap else PARA * 6
    m = machine([('T.TXT', text.encode())]); open_t(m)
    if buffer(m)[0] != text: return 'the test text did not load: ' + title(m)
    for i in range(style): keys(m, [('CTRL', 'D'), ('WAIT', 5)])
    if wrap: keys(m, [('CTRL', 'W'), ('WAIT', 5)])
    md = Model(text, m.z.mem[sym['docrows']], wrap)
    for k in ['PD', 'PD', 'DN', 'DN'] + (['RT'] * 40 if not wrap else []):     # somewhere inside
        m.type_keys([keyfor(k)] + ([('WAIT', 15)] if k == 'PD' else []))
    m.run_script(extra=30)
    md.t = list(buffer(m)[0]); md.c = buffer(m)[1]
    keys(m, [('CTRL', 'V'), ('WAIT', 60)], extra=60)
    err = sheet_check(m, md, wrap, 'entry')
    if err: return err
    if w16(m, osym['zB']) != rows_of(md.T(), wrap).index(w16(m, sym['top'])): return 'entry: box not at the top row'
    if shots: shot.save(m, S + 's_sheet_%s_%d.png' % ('wrap' if wrap else 'nowrap', style))
    pool = ['UP', 'DN', 'DN', 'PU', 'PD', 'PD', 'LT', 'RT', 'RT', 'TOP', 'BOT']
    for step in range(14):
        k = random.choice(pool)
        m.type_keys([keyfor(k), ('WAIT', 20)]); m.run_script(extra=40)
        err = sheet_check(m, md, wrap, 'step %d %s' % (step, k))
        if err: return err
    for k in ['UP'] * 3 + ['PD'] + ['RT'] * 3:
        m.type_keys([keyfor(k), ('WAIT', 20)])
    m.run_script(extra=40)
    err = sheet_check(m, md, wrap, 'last moves')
    if err: return err
    if shots: shot.save(m, S + 's_sheet_%s_%d_moved.png' % ('wrap' if wrap else 'nowrap', style))
    b, bh = w16(m, osym['zB']), w16(m, osym['zBH'])
    R = rows_of(md.T(), wrap); t = md.T()
    keys(m, ['RET', ('WAIT', 30)], extra=40)
    if m.latch & 8 and style != 2: return 'RETURN: still in graphics mode'
    _, c, ln = buffer(m)
    s = R[b]
    if wrap: want = s
    else:
        e = t.find('\n', s); e = len(t) if e < 0 else e
        want = s + min(bh, e - s)
    if c != want: return 'RETURN: cursor %d, expected %d (row %d col %d)' % (c, want, b, bh)
    if w16(m, sym['top']) != s: return 'RETURN: top %d, expected %d' % (w16(m, sym['top']), s)
    md.c = c; md.goal = None
    err = screen_check(m, md, 'after RETURN')
    if err: return 'after RETURN: ' + err
    if shots: shot.save(m, S + 's_sheet_%s_%d_back.png' % ('wrap' if wrap else 'nowrap', style))
    # back out with Q: nothing moves
    keys(m, [('CTRL', 'V'), ('WAIT', 60), ('CTRL', 'C'), ('WAIT', 20), 'Q', ('WAIT', 30)], extra=40)
    if buffer(m)[1] != c: return 'Q moved the cursor'
    err = screen_check(m, md, 'after Q')
    if err: return 'after Q: ' + err
    if buffer(m)[0] != text: return 'the text changed'
    if not card_same(m): return 'the card changed'
    return None

def part_sheet():
    print('== sheet view')
    for wrap, style, seed in [(False, 0, 1), (False, 2, 2), (True, 0, 3), (True, 2, 4), (False, 1, 5), (True, 1, 6)]:
        err = run_sheet(wrap, style, seed, shots=True)
        check(err is None, 'wrap %s style %d seed %d %s' % (wrap, style, seed, err or ''))
    # small and empty texts
    for text in ['', 'one line', 'a\n']:
        m = machine([('T.TXT', text.encode())]); open_t(m)
        keys(m, [('CTRL', 'V'), ('WAIT', 30), ('CTRL', 'C'), ('CTRL', 'B'), ('WAIT', 20)], extra=30)
        md = Model(text, m.z.mem[sym['docrows']], False)
        err = sheet_check(m, md, False, repr(text))
        keys(m, ['RET', ('WAIT', 30)], extra=30)
        check(err is None and not (m.latch & 8) and buffer(m)[0] == text, 'sheet of %r %s' % (text, err or ''))

def part_ovl():
    print('== overlays')
    m = machine([('T.TXT', PARA.encode())]); open_t(m)
    keys(m, [('CTRL', 'H'), ('WAIT', 20)], extra=20)
    check(title(m).startswith('VZ-ED 0.3 HELP'), 'CTRL+H shows help: %r' % title(m))
    shot.save(m, S + 's_help_03.png')
    pages = 1
    for i in range(8):
        if title(m).startswith('VZ-ED 0.3 HELP'):
            keys(m, ['SPACE', ('WAIT', 10)], extra=20); pages += 1
    md = Model(PARA, m.z.mem[sym['docrows']], False)
    check(screen_check(m, md, '') is None and buffer(m)[0] == PARA, 'help pages, then back in the text (%d pages)' % (pages - 1))
    m = machine([('T.TXT', PARA.encode())], ovl=None); open_t(m)
    keys(m, [('CTRL', 'H'), ('WAIT', 20)], extra=20)
    check('VZED.OVL MISSING' in title(m), 'no VZED.OVL: says so: %r' % title(m))
    keys(m, [('CTRL', 'V'), ('WAIT', 20)], extra=20)
    check('VZED.OVL MISSING' in title(m) and not (m.latch & 8), 'no VZED.OVL: sheet view says so')
    bad = bytearray(OVL); bad[3072] ^= 0x55
    m = machine([('T.TXT', PARA.encode())], ovl=bytes(bad)); open_t(m)
    keys(m, [('CTRL', 'V'), ('WAIT', 20)], extra=20)
    check('VZED.OVL MISSING OR OLD' in title(m) and not (m.latch & 8), 'VZED.OVL from another build: refused')
    keys(m, [('CTRL', 'H'), ('WAIT', 20)], extra=20)
    check(title(m).startswith('VZ-ED 0.3 HELP'), '... its other slot still works')
    m = machine([('T.TXT', PARA.encode())], ovl=OVL[:3072]); open_t(m)
    keys(m, [('CTRL', 'V'), ('WAIT', 20)], extra=20)
    check('VZED.OVL MISSING' in title(m), 'VZED.OVL too short: refused')
    # the small clipboard (no spare bank) is parked while an overlay runs
    m = machine([('T.TXT', PARA.encode())], bank=False); open_t(m)
    check(m.z.mem[sym['clipbank']] == 0, 'no spare bank here')
    keys(m, [('CTRL', 'K')] + [('CTRL', ',')] * 20 + [('CTRL', 'J'), ('WAIT', 5)], extra=20)
    keys(m, [('CTRL', 'H'), ('WAIT', 20), ('CTRL', 'Q'), ('WAIT', 10), ('CTRL', 'V'), ('WAIT', 40), 'Q', ('WAIT', 20),
             ('CTRL', 'B'), ('WAIT', 20), ('CTRL', 'P'), ('WAIT', 10)], extra=30)
    check(buffer(m)[0] == PARA + PARA[:20], 'small clipboard kept across help and sheet view')
    # ... unless the text leaves no room for it
    big = ('y' * 60 + '\n') * 200
    m = machine([('T.TXT', big.encode())], bank=False); open_t(m)
    keys(m, [('CTRL', 'K')] + [('CTRL', 'C'), ('WAIT', 15)] * 2 + [('CTRL', 'J'), ('WAIT', 10)], extra=30)
    n = w16(m, sym['cliplen'])
    gap = w16(m, sym['ge']) - w16(m, sym['gs'])
    keys(m, [('CTRL', 'H'), ('WAIT', 20), ('CTRL', 'Q'), ('WAIT', 10)], extra=20)
    if n > gap:
        check('SMALL CLIPBOARD EMPTIED' in title(m) and w16(m, sym['cliplen']) == 0,
              'no room to park it (%d > gap %d): emptied, and says so' % (n, gap))
    else:
        check(False, 'set-up: block %d fits the gap %d' % (n, gap))
    check(card_same(m), 'card unchanged')

if __name__ == '__main__':
    parts = {'sheet': part_sheet, 'ovl': part_ovl}
    for p in (sys.argv[1:] or ['ovl', 'sheet']): parts[p]()
    print('\n%d FAILED' % len(FAILS) if FAILS else '\nall passed')
    sys.exit(1 if FAILS else 0)
