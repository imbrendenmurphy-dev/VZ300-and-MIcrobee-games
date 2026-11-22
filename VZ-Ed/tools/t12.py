"""VZ-ED 0.5 tests: SAVE AS PDF and PRINT (FILE menu, overlay slots 3 and 4).

    py t12.py           all parts
    py t12.py pdf       only the PDF
    py t12.py print     only printing
Each PDF is checked as a PDF (header, every xref offset points at its object,
startxref at the xref, stream lengths, page tree) and its text, page by page,
against a Python model of the 80-column layout.  The card is checked with the
FAT32 checker after every write.
"""
import sys, re, random; sys.path.insert(0, '.')
from harness import *
import shot
from t9 import check, FAILS, w16, buffer, scr, keys, PARA, dos, sym
from t11 import machine as machine11, title
S = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'testout', '')
ed = open('../out/VZED.VZ', 'rb').read(); OVL = open('../out/VZED.OVL', 'rb').read()

def machine(files, **kw):
    m = machine11(files, **kw)
    return m
def open_t(m):     # list: SHELL.VZ, T.TXT, VZDOS.VZ, VZED.OVL
    keys(m, [('CTRL', 'O'), ('WAIT', 20), 'SPACE', 'RET', ('WAIT', 30)])
def menu_pick(m, item, wait=60):
    """FILE menu item: 0 NEW 1 OPEN 2 SAVE 3 SAVE AS 4 SAVE AS PDF 5 PRINT 6 QUIT"""
    m.z.mem[sym['menusel']] = 0
    keys(m, [('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * item + ['RET', ('WAIT', wait)], extra=wait)

# ------------------------------------------------------------------ the layout model
def layout(t):
    lines = []; p = 0; n = len(t)
    while p < n:
        seg = t[p:p + 81]; i = seg.find('\n')
        if 0 <= i <= 80: lines.append(seg[:i]); p += i + 1; continue
        if len(seg) <= 80: lines.append(seg); p += len(seg); continue
        k = seg[:80].rfind(' ')
        k = 80 if k < 0 else k + 1
        lines.append(seg[:k]); p += k
    return lines
def printable(s): return ''.join(c if ord(c) >= 32 else ' ' for c in s)

def pdf_check(data, text):
    """None if data is a good PDF of text, else what is wrong"""
    if not data.startswith(b'%PDF-1.4\n'): return 'no %PDF header'
    if not data.endswith(b'%%EOF\n'): return 'no %%EOF'
    m = re.search(rb'startxref\n(\d+)\n%%EOF\n$', data)
    if not m: return 'no startxref'
    xr = int(m.group(1))
    if data[xr:xr + 5] != b'xref\n': return 'startxref %d is not at the xref' % xr
    m = re.match(rb'xref\n0 (\d+)\n', data[xr:])
    n = int(m.group(1)); e0 = xr + m.end()
    ents = [data[e0 + 20 * i:e0 + 20 * i + 20] for i in range(n)]
    if ents[0] != b'0000000000 65535 f\r\n': return 'xref entry 0 %r' % ents[0]
    for i in range(1, n):
        mm = re.match(rb'(\d{10}) 00000 n\r\n$', ents[i])
        if not mm: return 'xref entry %d %r' % (i, ents[i])
        off = int(mm.group(1))
        if not data[off:].startswith(b'%d 0 obj\n' % i): return 'object %d not at offset %d' % (i, off)
    if not re.search(rb'trailer\n<</Size %d/Root 1 0 R>>' % n, data): return 'trailer'
    pages = (n - 4) // 2
    if not re.search(rb'2 0 obj\n<</Type/Pages/Count %d/Kids\[' % pages + b''.join(b'%d 0 R ' % (4 + 2 * k) for k in range(pages)) + rb'\]>>', data):
        return 'page tree'
    want = layout(text); got = []
    for k in range(pages):
        o = 5 + 2 * k
        mm = re.search(rb'\n%d 0 obj\n<</Length (\d{5})>>\nstream\n' % o, data)
        if not mm: return 'contents %d' % o
        L = int(mm.group(1)); s0 = mm.end(); body = data[s0:s0 + L]
        if not body.startswith(b'BT /F1 10 Tf 12 TL 50 812 Td\n') or not body.endswith(b'ET'): return 'stream %d body' % o
        if data[s0 + L:s0 + L + 11] != b'\nendstream\n': return 'stream %d length %d wrong' % (o, L)
        ls = re.findall(rb'\(((?:\\.|[^\\)])*)\)\'\n', body)
        if len(ls) > 64: return 'page %d has %d lines' % (k, len(ls))
        if k < pages - 1 and len(ls) != 64: return 'page %d has only %d lines' % (k, len(ls))
        got += [re.sub(rb'\\(.)', rb'\1', x).decode('latin1') for x in ls]
    want = [printable(x) for x in want]
    if got != want:
        i = next((i for i in range(min(len(got), len(want))) if got[i] != want[i]), min(len(got), len(want)))
        return 'text differs at line %d: %r / %r (%d lines, expected %d)' % (
            i, got[i] if i < len(got) else None, want[i] if i < len(want) else None, len(got), len(want))
    if pages != max(1, (len(want) + 63) // 64): return '%d pages for %d lines' % (pages, len(want))
    import shutil, subprocess, tempfile
    tool = shutil.which('pdftotext')            # a real PDF reader (poppler), if there is one
    if tool:
        fn = os.path.join(tempfile.gettempdir(), 'vzed_t12.pdf'); open(fn, 'wb').write(data)
        r = subprocess.run([tool, fn, '-'], capture_output=True)
        if r.returncode or r.stderr.strip(): return 'pdftotext: %r' % r.stderr[:200]
    return None

def files(m):
    p, f = FS(m.card.sec).check()
    return p, f
def readf(m, path):
    fs = FS(m.card.sec); p, f = fs.check()
    return fs.readfile(*f[path], fs.fat()) if path in f else None

LONGT = ('A line with (brackets) and a back\\slash, then a tab\there. ' * 3 + '\n'
         + ('word ' * 30).strip() + '\n' + 'x' * 200 + '\n\n\nshort\n' + PARA + '\n') * 12

def part_pdf():
    print('== save as PDF')
    for name, text in [('long text', LONGT[:9000]), ('PARA', PARA), ('empty', ''), ('one line, no LF', 'hello (world)'),
                       ('3000 empty lines', '\n' * 3000), ('exactly 64 lines', 'line\n' * 64),
                       ('80/81 columns', 'a' * 80 + '\n' + 'b' * 81 + '\n' + 'c' * 79 + ' ' + 'd' * 5 + '\n' + ' ' * 100)]:
        m = machine([('T.TXT', text.encode())]); open_t(m)
        if buffer(m)[0] != text: check(False, '%s: did not load (%r)' % (name, title(m))); continue
        menu_pick(m, 4, wait=200 + len(text) // 30)
        p, f = files(m)
        data = readf(m, '/T.PDF')
        err = 'no T.PDF (%r)' % title(m) if data is None else pdf_check(data, text)
        check(err is None and not p and 'PDF SAVED' in title(m) and readf(m, '/T.TXT') == text.encode()
              and '/VZEDTEMP.$$$' not in f,
              'PDF of %s: %s bytes, card %s %s' % (name, len(data) if data else '-', p or 'clean', err or ''))
        if name == 'long text': open(S + 'T_long.pdf', 'wb').write(data)
        if name == 'PARA':
            shot.save(m, S + 's_pdf_saved.png')
            # again: asks first; N keeps the old one, Y replaces it with the edited text
            keys(m, ['Z', ('WAIT', 5)])
            menu_pick(m, 4, wait=30)
            check('REPLACE THE .PDF' in title(m), 'second time: asks before replacing (%r)' % title(m))
            keys(m, ['N', ('WAIT', 20)], extra=20)
            check(readf(m, '/T.PDF') == data, 'N: the old PDF stays')
            menu_pick(m, 4, wait=30)
            keys(m, ['Y', ('WAIT', 200)], extra=100)
            d2 = readf(m, '/T.PDF'); p, f = files(m)
            check(d2 is not None and pdf_check(d2, 'z' + PARA) is None and not p and '/VZEDTEMP.$$$' not in f,
                  'Y: replaced with the edited text, card clean')
    # untitled
    m = machine([]); keys(m, ['H', 'I', ('WAIT', 5)])
    menu_pick(m, 4, wait=100)
    d = readf(m, '/UNTITLED.PDF')
    check(d is not None and pdf_check(d, 'hi') is None and not files(m)[0], 'a new, unnamed text: UNTITLED.PDF')
    # too big for the card code (over 64K): refused, nothing written
    m = machine([('T.TXT', b'\n' * 12000)]); open_t(m)
    sec0 = dict(m.card.sec)
    menu_pick(m, 4, wait=600)
    check('PDF TOO BIG' in title(m) and m.card.sec == sec0, '12,000 empty lines: PDF TOO BIG, card untouched (%r)' % title(m))
    # editing a .PDF as text: not replaced by its own PDF
    m = machine([('T.PDF', b'not really a pdf')])
    keys(m, [('CTRL', 'O'), ('WAIT', 20), 'SPACE', 'RET', ('WAIT', 30)])
    sec0 = dict(m.card.sec)
    menu_pick(m, 4, wait=60)
    check('FILE IS PDF' in title(m) and m.card.sec == sec0, 'the document is T.PDF itself: refused (%r)' % title(m))
    # card full
    c = Card(spc=1, fatsz=64, totclus=600)
    c.addfile(2, 'VZDOS.VZ', dos); c.addfile(2, 'SHELL.VZ', ed); c.addfile(2, 'VZED.OVL', OVL)
    c.addfile(2, 'T.TXT', PARA.encode())
    c.fill_used(2, c.totclus - len(c.fat) + 2 - 2)   # 2 free clusters of 512: the 1,099-byte PDF needs 3
    c.finish()
    m = VZ(dos[24:], c, maxlba=max(c.sec) + 5000); m.run(0x4004, frames=400); m.card = c   # (slow to load with 512-byte clusters)
    keys(m, [('CTRL', 'O'), ('WAIT', 60), 'SPACE', 'SPACE', 'RET', ('WAIT', 60)], extra=60)   # FILLER.BIN comes first
    check(buffer(m)[0] == PARA, 'card-full set-up: T.TXT open (%r)' % title(m))
    menu_pick(m, 4, wait=200)
    p, f = FS(c.sec).check()
    check('CARD FULL' in title(m) and not p and '/T.PDF' not in f and readf(m, '/T.TXT') == PARA.encode(),
          'card full: CARD FULL - NOT SAVED, card clean (%r, %s)' % (title(m), p or 'clean'))

def part_print():
    print('== print')
    text = LONGT[:5000]
    m = machine([('T.TXT', text.encode())]); open_t(m)
    menu_pick(m, 5, wait=200)
    want = (''.join(printable(x) + '\r\n' for x in layout(text)) + '\f').encode('latin1')
    check(bytes(m.prn) == want and 'PRINTED' in title(m), 'printout = the 80-column lines, CR LF, form feed (%d bytes) %r' % (len(m.prn), title(m)))
    check(buffer(m)[0] == text, 'text unchanged')
    # no printer / busy: says so, CTRL+Q stops
    m = machine([('T.TXT', PARA.encode())]); open_t(m)
    m.prn_busy = True
    menu_pick(m, 5, wait=100)
    check('PRINTER NOT READY' in title(m), 'printer busy: says so (%r)' % title(m))
    shot.save(m, S + 's_print_notready.png')
    keys(m, [('CTRL', 'Q'), ('WAIT', 20)], extra=20)
    check('STOPPED' in title(m) and len(m.prn) == 0, 'CTRL+Q stops (%r)' % title(m))
    keys(m, ['A', ('WAIT', 5)])
    check(buffer(m)[0] == 'a' + PARA, 'back in the editor')
    # busy for a while, then ready: carries on
    m = machine([('T.TXT', b'one\ntwo\n')]); open_t(m)
    m.prn_busy = True
    menu_pick(m, 5, wait=80)
    m.prn_busy = False; m.run(frames=60)
    check(bytes(m.prn) == b'one\r\ntwo\r\n\f' and 'PRINTED' in title(m), 'busy, then ready: prints it all (%r)' % bytes(m.prn))
    # CTRL+Q while printing a long text
    m = machine([('T.TXT', (LONGT * 2)[:11000].encode())]); open_t(m)
    m.z.mem[sym['menusel']] = 0
    m.type_keys([('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * 5 + ['RET'])
    m.run_script(extra=2)
    for f in range(40):                 # a slow printer: busy every other frame
        m.prn_busy = f % 2 == 0
        if f == 20: m.type_keys([('CTRL', 'Q'), ('WAIT', 10)])
        m.run(frames=1)
    m.prn_busy = False; m.run_script(extra=30)
    check('STOPPED' in title(m) and 0 < len(m.prn) < 11000, 'CTRL+Q in the middle stops it (%d bytes out)' % len(m.prn))

if __name__ == '__main__':
    parts = {'pdf': part_pdf, 'print': part_print}
    for p in (sys.argv[1:] or ['pdf', 'print']): parts[p]()
    print('\n%d FAILED' % len(FAILS) if FAILS else '\nall passed')
    sys.exit(1 if FAILS else 0)
