"""VZ-ED 0.6 tests: BASIC programs (.VZ) as text, and the hex viewer.

    py t13.py            all parts
    py t13.py basic      BASIC open / save
    py t13.py hex        the hex viewer
The test program is made of lines typed into the real VZ ROM (vzemu): opening
and saving it unchanged must give back exactly the same file.  Edited programs
are checked against tools/basic.py (itself checked against the ROM).
"""
import sys, random; sys.path.insert(0, '.')
from harness import *
import shot
from t9 import check, FAILS, w16, buffer, scr, keys, dos, sym
from t11 import title
from basic import detokenise, tokenise, vzfile, program_lines
S = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'testout', '')
ed = open('../out/VZED.VZ', 'rb').read(); OVL = open('../out/VZED.OVL', 'rb').read()
B = os.path.join(S, 'basic')

def rom_prog(name):      # programs typed into the real ROM (tools/basicrom)
    return open(os.path.join('basicrom', name), 'rb').read()
NAME = b'TEST PROGRAM'.ljust(17, b'\0')
PROG = rom_prog('rom1.bin')
PROGVZ = vzfile(NAME, PROG)

def machine(files, ovl=OVL, spc=8):
    c = Card(spc=spc); c.addfile(2, 'VZDOS.VZ', dos); c.addfile(2, 'SHELL.VZ', ed)
    for name, data in files: c.addfile(2, name, data)
    if ovl is not None: c.addfile(2, 'VZED.OVL', ovl)
    c.finish()
    m = VZ(dos[24:], c, maxlba=max(c.sec) + 70000); m.run(0x4004, frames=150)
    m.card = c
    return m
def open_n(m, n, wait=60):
    """open the n-th entry of the root list (sorted: folders, then names)"""
    keys(m, [('CTRL', 'O'), ('WAIT', 25)] + ['SPACE'] * n + ['RET', ('WAIT', wait)], extra=wait)
def readf(m, path):
    fs = FS(m.card.sec); p, f = fs.check()
    return fs.readfile(*f[path], fs.fat()) if path in f else None
def cardok(m): return not FS(m.card.sec).check()[0]
def text_of(m): return buffer(m)[0]

def part_basic():
    print('== BASIC programs')
    want, rest = detokenise(PROG)
    m = machine([('PROG.VZ', PROGVZ), ('A.TXT', b'old text\r\n')])
    open_n(m, 0)                          # A.TXT, PROG.VZ, SHELL.VZ, ...
    open_n(m, 1)
    t = text_of(m)
    check(t == want and m.z.mem[sym['basmode']] == 1 and title(m).startswith('PROG.VZ'),
          'open PROG.VZ: listed like the ROM does (%d lines) %r' % (t.count('\n'), title(m)))
    if t != want:
        for a, b in zip(t.split('\n'), want.split('\n')):
            if a != b: print('     got ', repr(a)); print('     want', repr(b)); break
    shot.save(m, S + 's_basic_open.png')
    keys(m, [('CTRL', 'S'), ('WAIT', 150)], extra=100)
    check(readf(m, '/PROG.VZ') == PROGVZ and readf(m, '/PROG.BAK') == PROGVZ and cardok(m) and 'SAVED' in title(m),
          'saved unchanged: the very same bytes as the ROM made, PROG.BAK kept, card clean (%r)' % title(m))
    # edits: lower case keywords and letters, a new line, changed lines
    keys(m, [('CTRL', 'B'), ('WAIT', 20)] + list(text_for('170 for k=1 to 3:print "lower";k:next')) + ['RET'] +
         list(text_for("175 if k then goto 10 else print k ' done")) + ['RET', ('WAIT', 10)], extra=20)
    keys(m, [('CTRL', 'T'), ('WAIT', 20), ('CTRL', 'X')] + list(text_for(':?fre(0)')) + [('WAIT', 10)], extra=20)
    t = text_of(m)
    keys(m, [('CTRL', 'S'), ('WAIT', 200)], extra=100)
    got = readf(m, '/PROG.VZ')
    exp = vzfile(NAME, tokenise(t))
    check(got == exp and cardok(m), 'edited and saved: = the model tokeniser (%d bytes) %r' % (len(got or b''), title(m)))
    open(S + 'PROG_EDITED.VZ', 'wb').write(got or b'')
    # reopen what was saved: same text (keywords now as LIST shows them)
    open_n(m, 2, wait=60)                 # A.TXT, PROG.BAK, PROG.VZ
    t2 = text_of(m)
    check(t2 == detokenise(exp[24:])[0], 'opened again: lists the same')
    # errors: no line number / out of order / too long: nothing written, cursor on the line
    for name, line, msg in [('no number', 'print 5', 'NO LINE NO.'), ('order', '5 print 5', 'LINE ORDER'),
                            ('too long', '9999 rem ' + 'x' * 260, 'LONG LINE')]:
        m2 = machine([('PROG.VZ', PROGVZ)]); open_n(m2, 0)
        keys(m2, [('CTRL', 'B'), ('WAIT', 20)] + list(text_for(line)) + [('WAIT', 10), ('CTRL', 'T'), ('WAIT', 20)], extra=20)
        sec0 = dict(m2.card.sec)
        keys(m2, [('CTRL', 'S'), ('WAIT', 150)], extra=60)
        tt, c, ln = buffer(m2)
        check(msg in title(m2) and m2.card.sec == sec0 and ln == tt.count('\n') + 1 and m2.z.mem[sym['modified']],
              'save with a bad line (%s): %s, nothing written, cursor on it (line %d) %r' % (name, msg, ln, title(m2)))
    # save as .TXT: the listing as text
    m2 = machine([('PROG.VZ', PROGVZ)]); open_n(m2, 0)
    keys(m2, [('CTRL', 'A'), ('WAIT', 10)] + [('CTRL', ':')] * 12 + list(text_for('PROG.TXT')) + ['RET', ('WAIT', 120)], extra=60)
    check(readf(m2, '/PROG.TXT') == want.replace('\n', '\r\n').encode('latin1') and cardok(m2) and readf(m2, '/PROG.VZ') == PROGVZ,
          'save as PROG.TXT: the listing as text (CR LF), PROG.VZ untouched')
    # the second ROM program and a program with machine code after it
    p2 = vzfile(NAME, rom_prog('rom2.bin'))
    m2 = machine([('P2.VZ', p2)]); open_n(m2, 0)
    keys(m2, [('CTRL', 'S'), ('WAIT', 150)], extra=60)
    check(text_of(m2) == detokenise(p2[24:])[0] and readf(m2, '/P2.VZ') == p2, 'second ROM program: open + save gives the same file')
    star = open('../../StarBlaster2_VZ300/ref/STARBLAS.VZ', 'rb').read() if os.path.exists('../../StarBlaster2_VZ300/ref/STARBLAS.VZ') \
        else vzfile(NAME, PROG + bytes(range(256)) * 4)
    m2 = machine([('STAR.VZ', star), ('A.TXT', b'old\r\n')]); open_n(m2, 0); open_n(m2, 2)   # A.TXT, SHELL.VZ, STAR.VZ
    check(title(m2).startswith('HEX VIEW'), 'BASIC with machine code after it: hex view (%r)' % title(m2))
    keys(m2, ['Q', ('WAIT', 20)], extra=20)
    check(text_of(m2) == '' and m2.z.mem[sym['named']] == 0 and m2.z.mem[sym['basmode']] == 0,
          '... and the editor is left empty and untitled (the old text was overwritten)')
    # a new text is not BASIC
    keys(m2, [('CTRL', 'N'), ('WAIT', 10)])
    check(m2.z.mem[sym['basmode']] == 0, 'CTRL+N: not BASIC')

def hexrows(data, off, rows):
    out = []
    for r in range(rows):
        o = off + 8 * r
        if o >= len(data): out.append(' ' * 32); continue
        b = data[o:o + 8]
        out.append(('%06X %s %s' % (o, b.hex().upper().ljust(16), ''.join(chr(x) if 32 <= x < 127 else '.' for x in b))).ljust(32))
    return out
def hex_check(m, data):
    rows = m.z.mem[sym['docrows']]
    first = bytes(b & 0x7F for b in scr(m, 1)).decode('latin1')
    try: off = int(first[:6], 16)
    except ValueError: return 'row 1 %r' % first
    want = hexrows(data, off, rows)
    for r in range(rows):
        got = bytes(b & 0x7F for b in scr(m, r + 1)).decode('latin1')
        if got != want[r]: return 'row %d: %r, expected %r' % (r + 1, got, want[r])
    return None

def part_hex():
    print('== hex viewer')
    random.seed(5)
    big = bytes(random.randrange(256) for _ in range(70000))       # over 64K: 24-bit offsets
    mid = ('A line of text for the hex viewer %05d\r\n' % 0) * 400
    mid = b'\0' + ''.join('A line of text for the hex viewer %05d\r\n' % i for i in range(400)).encode()[1:]   # 16,400 bytes (0.8: a 0 byte, or it opens in parts)
    for style in (0, 2):
        m = machine([('A.TXT', b'keep me\r\n'), ('BIG.BIN', big), ('MID.TXT', mid)])
        if style: keys(m, [('CTRL', 'D'), ('WAIT', 5)] * style)
        open_n(m, 0)
        for name, data, idx in (('MID.TXT', mid, 2), ('BIG.BIN', big, 1), ('SHELL.VZ', ed, 3)):
            open_n(m, idx, wait=80)
            err = None if title(m).startswith('HEX VIEW') else 'not in the hex view: %r' % title(m)
            seq = [('start', []), ('down', [('CTRL', 'SPACE')]), ('page down x3', [('CTRL', 'C')] * 3), ('up', [('CTRL', '.')]),
                   ('end', [('CTRL', 'B')]), ('page up', [('CTRL', 'R')]), ('down at the end', [('CTRL', 'B'), ('CTRL', 'SPACE')]),
                   ('top', [('CTRL', 'T')]), ('up at the top', [('CTRL', '.')])]
            for what, ks in seq:
                if err: break
                keys(m, [x for k in ks for x in (k, ('WAIT', 25))], extra=25)
                e = hex_check(m, data)
                if e: err = '%s: %s' % (what, e)
                if what == 'end' and style == 0 and name == 'BIG.BIN': shot.save(m, S + 's_hex_end.png')
            if style == 0 and name == 'SHELL.VZ': shot.save(m, S + 's_hex_vz.png')
            keys(m, ['Q', ('WAIT', 25)], extra=25)
            check(err is None and text_of(m) == 'keep me\n' and m.z.mem[sym['basmode']] == 0,
                  'style %d: %s (%d bytes) in hex, every row right; Q: the text is still there %s' % (style, name, len(data), err or ''))
    m = machine([('A.TXT', b'keep me\r\n'), ('BIG.BIN', big)], ovl=None)
    open_n(m, 0); open_n(m, 1)
    check('VZED.OVL MISSING' in title(m) and text_of(m) == 'keep me\n', 'no VZED.OVL: says so, text kept')

if __name__ == '__main__':
    parts = {'basic': part_basic, 'hex': part_hex}
    for p in (sys.argv[1:] or ['basic', 'hex']): parts[p]()
    print('\n%d FAILED' % len(FAILS) if FAILS else '\nall passed')
    sys.exit(1 if FAILS else 0)
