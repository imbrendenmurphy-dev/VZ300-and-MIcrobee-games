"""VZ-ED 0.7 tests: undo, bookmarks, go to line, word count, quitting through ovl_quit.

    py t14.py            all parts
    py t14.py undo       random edits, then undo all the way back (with and without the spare bank)
    py t14.py cases      undo of each kind of change; history full; NEW / OPEN forget it
    py t14.py marks      bookmarks follow the edits; go to line; word count
Undo is checked against the snapshots taken after every key: each undo must give
back an earlier text (going back in order), the line count must stay right, and
the last one must give the text as it was loaded.
"""
import sys, random; sys.path.insert(0, '.')
from harness import *
import shot
from t9 import check, FAILS, w16, buffer, scr, keys, dos, sym
from t11 import machine, open_t, title
S = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'testout', '')

TEXT = ('The quick brown fox jumps over the lazy dog.\nA second line, with a fox in it.\n\n'
        'TARGET is where bookmark one goes.\n' + ''.join('line %d of the filler text\n' % i for i in range(3, 40)) +
        'and the end, no line feed')

def state(m):
    t, c, ln = buffer(m)
    return t, c, ln
def lines_ok(m):
    t, c, ln = buffer(m)
    return ln == t[:c].count('\n') + 1
def undo(m, n=1):
    keys(m, [('CTRL', '-'), ('WAIT', 4)] * n, extra=6)
def utop(m): return w16(m, sym['utop']) - sym['UBUF']

RANDKEYS = (['A', 'B', 'E', 'S', 'SPACE', 'RET', ('SHIFT', 'X'), '1'] * 4 + [('CTRL', ':')] * 6 + [('CTRL', ';')] * 4 +
            [('CTRL', 'M'), ('CTRL', ','), ('CTRL', '.'), ('CTRL', 'SPACE'), ('CTRL', 'Z'), ('CTRL', 'X')] * 2 +
            ['INS', 'BLOCKDEL', 'CUT', 'PASTE', 'COPY'])

def run_undo(seed, bank, steps=70):
    random.seed(seed)
    m = machine([('T.TXT', TEXT.replace('\n', '\r\n').encode())], bank=bank); open_t(m)
    snaps = [buffer(m)[0]]
    err = None
    for i in range(steps):
        k = random.choice(RANDKEYS)
        if k == 'INS': ks = [('CTRL', 'L')]
        elif k == 'BLOCKDEL': ks = [('CTRL', 'K')] + [random.choice([('CTRL', ','), ('CTRL', 'SPACE')])] * random.randint(1, 6) + [('CTRL', ':')]
        elif k == 'CUT': ks = [('CTRL', 'K')] + [('CTRL', ',')] * random.randint(1, 8) + [('CTRL', 'Y')]
        elif k == 'COPY': ks = [('CTRL', 'K')] + [('CTRL', 'M')] * random.randint(1, 8) + [('CTRL', 'J')]
        elif k == 'PASTE': ks = [('CTRL', 'P')]
        else: ks = [k]
        keys(m, [x for kk in ks for x in (kk, ('WAIT', 2))], extra=4)
        t = buffer(m)[0]
        if t != snaps[-1]: snaps.append(t)
        if not lines_ok(m): err = 'line count wrong after step %d %r' % (i, ks); break
    if m.z.mem[sym['insmode']] == 0: keys(m, [('CTRL', 'L')])
    used = utop(m)
    j = len(snaps) - 1; n = 0
    while not err:
        undo(m); n += 1
        t = buffer(m)[0]
        if not lines_ok(m): err = 'line count wrong after undo %d' % n; break
        if 'NOTHING TO UNDO' in title(m):
            if t != snaps[j]: err = 'NOTHING TO UNDO but the text changed'
            break
        k = max((x for x in range(j + 1) if snaps[x] == t), default=None)
        if k is None: err = 'undo %d gave a text that never was: %r' % (n, t[:60]); break
        j = k
        if n > 400: err = 'never ends'; break
    check(err is None and j == 0 and buffer(m)[0] == TEXT,
          'seed %d bank %d: %d changes (%d bytes of history), %d undos back to the loaded text %s' %
          (seed, bank, len(snaps) - 1, used, n - 1, err or ''))

def part_undo():
    print('== undo: random edits, then all the way back')
    for seed, bank in ((1, True), (2, False), (3, True), (4, False), (5, True)):
        run_undo(seed, bank)

def fresh(bank=True, text=TEXT):
    m = machine([('T.TXT', text.replace('\n', '\r\n').encode())], bank=bank); open_t(m)
    return m

def part_cases():
    print('== undo: each kind of change')
    m = fresh()
    undo(m)
    check('NOTHING TO UNDO' in title(m), 'just loaded: NOTHING TO UNDO %r' % title(m))
    # a typed run is one step; moving away and typing again is another
    keys(m, list(text_for('hello there')) + [('CTRL', 'B')] + list(text_for('abc')), extra=10)
    undo(m); a = buffer(m)
    check(a[0] == 'hello there' + TEXT and a[1] == len(a[0]) and 'UNDONE' in title(m), 'undo: the last typing run goes, cursor where it was typed')
    undo(m)
    check(buffer(m)[0] == TEXT, 'undo again: the first run goes too')
    # backspace run and delete run
    keys(m, [('CTRL', 'T'), ('CTRL', 'SPACE'), ('CTRL', 'X')] + [('CTRL', ':')] * 7 + [('CTRL', 'Z')] + [('CTRL', ';')] * 5, extra=10)
    t1 = buffer(m)[0]
    undo(m)
    t2, c2, _ = buffer(m)
    check(t2 == TEXT.replace('A second line, with a fox in it.', 'A second line, with a fox') and c2 == TEXT.index('A second'),
          'undo the DEL run: the 5 letters come back after the cursor')
    undo(m); t3, c3, _ = buffer(m)
    check(t3 == TEXT and c3 == TEXT.index('A second') + len('A second line, with a fox in it.'),
          'undo the BS run: the 7 letters come back before the cursor (cursor after them)')
    # block delete, cut, paste
    keys(m, [('CTRL', 'T'), ('CTRL', 'K')] + [('CTRL', 'SPACE')] * 3 + [('CTRL', ':'), ('WAIT', 5)], extra=10)
    check(buffer(m)[0] == TEXT[TEXT.index('TARGET'):], 'block of 3 lines deleted')
    undo(m)
    check(buffer(m)[0] == TEXT and buffer(m)[1] == 0 and lines_ok(m), 'undo: the block is back, line count right')
    keys(m, [('CTRL', 'K')] + [('CTRL', ',')] * 4 + [('CTRL', 'Y'), ('CTRL', 'B'), ('CTRL', 'P'), ('CTRL', 'P'), ('WAIT', 5)], extra=10)
    check(buffer(m)[0] == TEXT[4:] + 'The The ', 'cut 4, pasted twice at the end')
    undo(m); check(buffer(m)[0] == TEXT[4:] + 'The ', 'undo: the second paste goes')
    undo(m, 2); check(buffer(m)[0] == TEXT, 'undo twice more: the first paste, then the cut')
    # replace all: one step
    keys(m, [('CTRL', 'T'), ('CTRL', 'E'), ('WAIT', 10)] + list(text_for('fox')) + ['RET', ('WAIT', 10)] + list(text_for('big cat')) + ['RET', ('WAIT', 10), 'A', ('WAIT', 30)], extra=30)
    check(buffer(m)[0] == TEXT.replace('fox', 'big cat'), 'replace all fox -> big cat')
    undo(m)
    check(buffer(m)[0] == TEXT and lines_ok(m), 'one undo puts every fox back %r' % title(m))
    # replace with nothing
    keys(m, [('CTRL', 'T'), ('CTRL', 'E'), ('WAIT', 10)] + [('CTRL', ':')] * 3 + list(text_for('the')) + ['RET', ('WAIT', 10)] + [('CTRL', ':')] * 7 + ['RET', ('WAIT', 10), 'A', ('WAIT', 30)], extra=30)
    check('the' not in buffer(m)[0].lower(), 'replace all "the" with nothing')
    undo(m); check(buffer(m)[0] == TEXT, '... undone')
    # overtype: one step for the run
    keys(m, [('CTRL', 'T'), ('CTRL', 'L')] + list(text_for('A slow')) + [('CTRL', 'L')], extra=10)
    check(buffer(m)[0] == 'A slow' + TEXT[6:], 'overtyped "The q" with "A slow"')
    undo(m)
    check(buffer(m)[0] == TEXT and buffer(m)[1] == 0, 'one undo: the old letters are back')
    undo(m)
    check('NOTHING TO UNDO' in title(m) and buffer(m)[0] == TEXT, 'and then nothing is left to undo')
    # history full: 3 blocks of ~500 bytes; only the last two fit in the history
    big = ''.join('%03d %s\n' % (i, 'x' * 40) for i in range(36))      # 36 lines of 45 = 1620 bytes
    m = fresh(text=big)
    for k in range(3):
        keys(m, [('CTRL', 'T'), ('CTRL', 'K')] + [('CTRL', 'SPACE')] * 11 + [('CTRL', ':'), ('WAIT', 5)], extra=10)
    check(buffer(m)[0] == big[33 * 45:], 'three blocks of 495 bytes deleted')
    undo(m); undo(m)
    check(buffer(m)[0] == big[11 * 45:], 'two undos bring back the last two blocks')
    undo(m)
    check('NOTHING TO UNDO' in title(m) and buffer(m)[0] == big[11 * 45:], 'the oldest one was dropped to make room (history %d bytes)' % (sym['UBEND'] - sym['UBUF']))
    # a block bigger than the whole history: forgotten (and the text is still right)
    m = fresh(text=big)
    keys(m, [('CTRL', 'T'), ('CTRL', 'K'), ('CTRL', 'B'), ('CTRL', ':'), ('WAIT', 5)] + list(text_for('new')), extra=10)
    undo(m)
    check(buffer(m)[0] == '', 'deleted all 1,620 bytes at once, typed: undo takes the typing back')
    undo(m)
    check('NOTHING TO UNDO' in title(m) and buffer(m)[0] == '', '... but not the delete: too big for the history')
    # NEW and OPEN forget it
    m = fresh()
    keys(m, list(text_for('abc')) + [('CTRL', 'N'), ('WAIT', 10), 'N', ('WAIT', 10)], extra=10)
    undo(m)
    check('NOTHING TO UNDO' in title(m) and buffer(m)[0] == '', 'CTRL+N: a new text has no history')
    m = fresh()
    keys(m, list(text_for('abc')) + [('CTRL', 'S'), ('WAIT', 80)], extra=40)
    open_t(m)
    undo(m)
    check('NOTHING TO UNDO' in title(m) and buffer(m)[0] in ('abc' + TEXT, TEXT), 'saved and opened again: no history')
    # menu EDIT > UNDO
    m = fresh(bank=False)
    keys(m, list(text_for('xyz')), extra=5)
    m.z.mem[sym['menusel']] = 1
    keys(m, [('CTRL', 'I'), ('WAIT', 20), 'RET', ('WAIT', 30)], extra=30)
    check(buffer(m)[0] == TEXT, 'EDIT menu, UNDO (first item): undone (small clipboard)')

def wc(t):
    return len(t.split()), t.count('\n') + 1, len(t)

def part_marks():
    print('== bookmarks, go to line, word count')
    for bank in (True, False):
        m = fresh(bank=bank)
        keys(m, [('CTRL', 'F'), ('WAIT', 10)] + list(text_for('TARGET')) + ['RET', ('WAIT', 20), ('CTRL', 'Z'),
                 ('CTRL', '0'), ('WAIT', 30), '1', ('WAIT', 30)], extra=30)
        check('MARK 1 SET' in title(m) and buffer(m)[1] == TEXT.index('TARGET'), 'CTRL+0 1: MARK 1 SET %r' % title(m))
        keys(m, [('CTRL', 'B'), ('CTRL', '0'), ('WAIT', 30), ('CTRL', '2'), ('WAIT', 30)], extra=20)     # mark 2 at the end, CTRL+digit
        keys(m, [('CTRL', 'T')] + list(text_for('Inserted at the top. ')) + [('CTRL', 'SPACE')] + [('CTRL', ';')] * 9, extra=10)
        keys(m, [('CTRL', '1'), ('WAIT', 40)], extra=30)
        t, c, _ = buffer(m)
        check(t[c:].startswith('TARGET') and lines_ok(m), 'typed and deleted before it: CTRL+1 still goes to TARGET (%d)' % c)
        keys(m, [('CTRL', 'T'), ('CTRL', '2'), ('WAIT', 40)], extra=30)
        check(buffer(m)[1] == len(buffer(m)[0]), 'CTRL+2: the end')
        keys(m, [('CTRL', '3'), ('WAIT', 40)], extra=30)
        check('NO MARK 3' in title(m), 'CTRL+3: NO MARK 3 %r' % title(m))
        # a mark inside a deleted block goes to where the block was
        keys(m, [('CTRL', '1'), ('WAIT', 40), ('CTRL', 'M'), ('CTRL', 'K')] + [('CTRL', ',')] * 4 + [('CTRL', ':'), ('CTRL', 'T'), ('CTRL', '1'), ('WAIT', 40)], extra=30)
        t, c, _ = buffer(m)
        check(t[c:].startswith('GET is') and t[c - 1] == '\n', 'mark inside a deleted block: at the block start')
        # go to line (FIND menu, 4th)
        m.z.mem[sym['menusel']] = 2
        keys(m, [('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * 3 + ['RET', ('WAIT', 40)] + list(text_for('12')) + ['RET', ('WAIT', 30)], extra=30)
        t, c, ln = buffer(m)
        check(ln == 12 and (c == 0 or t[c - 1] == '\n'), 'GO TO LINE 12: line %d, at its start' % ln)
        m.z.mem[sym['menusel']] = 2
        keys(m, [('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * 3 + ['RET', ('WAIT', 40)] + list(text_for('999')) + ['RET', ('WAIT', 30)], extra=30)
        t, c, ln = buffer(m)
        check(ln == t.count('\n') + 1 and (c == 0 or t[c - 1] == '\n'), 'GO TO LINE 999: the last line (%d)' % ln)
        m.z.mem[sym['menusel']] = 2
        keys(m, [('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * 3 + ['RET', ('WAIT', 40)] + list(text_for('x')) + ['RET', ('WAIT', 30)], extra=30)
        check('LINE NO.?' in title(m) and buffer(m)[2] == ln, 'GO TO LINE x: LINE NO.?, cursor stays')
        # word count (VIEW menu, 4th): the whole text, then a marked block
        m.z.mem[sym['menusel']] = 3
        m.type_keys([('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * 3 + ['RET', ('WAIT', 60)]); m.run_script(extra=40)
        w, l, ch = wc(buffer(m)[0]); want = '%d WORDS %d LINES %d CHARS' % (w, l, ch)
        got = title(m).strip()
        if bank: shot.save(m, S + 's_wordcount.png')
        keys(m, ['SPACE', ('WAIT', 10)], extra=10)
        check(got == want and buffer(m)[0] == t, 'WORD COUNT: %r (want %r); a key closes it, the text unchanged' % (got, want))
        keys(m, [('CTRL', 'T'), ('CTRL', 'K')] + [('CTRL', 'SPACE')] + [('CTRL', ',')] * 4, extra=10)
        m.z.mem[sym['menusel']] = 3
        m.type_keys([('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * 3 + ['RET', ('WAIT', 60)]); m.run_script(extra=40)
        t = buffer(m)[0]; e = t.index(chr(10)) + 5; _ = [i for i, x in enumerate(t) if x == '\n'][1] + 5
        w, l, ch = wc(t[:e]); want = 'BLOCK %d WORDS %d LINES %d CHARS' % (w, l, ch)
        got = title(m).strip()
        keys(m, ['SPACE', ('WAIT', 10)], extra=10)
        check(got == want, 'WORD COUNT with a block marked: %r (want %r)' % (got, want))

def part_quit():
    print('== quitting (ovl_quit) and the settings file')
    m = fresh()
    keys(m, [('CTRL', 'D'), ('WAIT', 10), ('CTRL', 'Q'), ('WAIT', 60)], extra=200)
    fs = FS(m.card.sec); p, f = fs.check()
    cfg = fs.readfile(*f['/VZED.CFG'], fs.fat()) if '/VZED.CFG' in f else None
    check(cfg is not None and cfg[:4] == b'VZED' and cfg[5] == 1 and not p, 'CTRL+Q: VZED.CFG written (display style 1), card clean')
    check(getattr(m, 'resets', 0) > 0, 'and it restarted')
    m = machine([('T.TXT', b'abc\r\n')], ovl=None); open_t(m)
    keys(m, [('CTRL', 'Q'), ('WAIT', 60)], extra=100)
    check(getattr(m, 'resets', 0) > 0, 'no VZED.OVL: CTRL+Q still restarts')

if __name__ == '__main__':
    parts = {'undo': part_undo, 'cases': part_cases, 'marks': part_marks, 'quit': part_quit}
    for p in (sys.argv[1:] or ['cases', 'marks', 'quit', 'undo']): parts[p]()
    print('\n%d FAILED' % len(FAILS) if FAILS else '\nall passed')
    sys.exit(1 if FAILS else 0)
