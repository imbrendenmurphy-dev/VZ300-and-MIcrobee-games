"""VZ-ED 0.8 tests: big text files edited in parts (overlay slot 9).

    py t15.py            all parts
    py t15.py walk       open, page through every part and back, line numbers
    py t15.py save       edits in two parts, CTRL+S, SAVE CHANGES? on switching
    py t15.py edge       LF-only, no line ends, too big after editing, hex view
                         for binary / .VZ / over 64K, small clipboard, go to line
A part must end with a line end (unless the file ends there or a line is longer
than a part); put together, the parts must be the whole file.  Saves are checked
against the file edited in Python, the card with the FAT checker.
"""
import sys, random; sys.path.insert(0, '.')
from harness import *
import shot
from t9 import check, FAILS, w16, buffer, scr, keys, dos, sym
from t11 import machine, title
S = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'testout', '')
MAXW = 6144

def bigtext(n, w=40):
    return ''.join('line %05d %s\n' % (i + 1, ('abcdefghij' * 8)[i % 10:i % 10 + w - 11]) for i in range(n))

def open_n(m, n, wait=150):
    keys(m, [('CTRL', 'O'), ('WAIT', 25)] + ['SPACE'] * n + ['RET', ('WAIT', wait)], extra=wait)
def readf(m, path):
    fs = FS(m.card.sec); p, f = fs.check()
    return fs.readfile(*f[path], fs.fat()) if path in f else None
def cardok(m): return not FS(m.card.sec).check()[0]
def absline(m): return w16(m, sym['curln']) + w16(m, sym['lnbase'])
def title_line(m):
    t = title(m)
    try: return int(t[15:20].split()[0])
    except (ValueError, IndexError): return None
def nxt(m):   # end of the part, then page down at the last line
    keys(m, [('CTRL', 'B'), ('WAIT', 15), ('CTRL', 'C'), ('WAIT', 160)], extra=40)
def prv(m):
    keys(m, [('CTRL', 'T'), ('WAIT', 15), ('CTRL', 'R'), ('WAIT', 160)], extra=40)

def walk(m, whole, crlf):
    """page from the first part to the last and back: the parts make up the file"""
    parts = [buffer(m)[0]]; err = None; bases = [0]
    for k in range(40):
        if w16(m, sym['bws']) + w16(m, sym['bwl']) >= w16(m, sym['bsz']): break
        nxt(m)
        parts.append(buffer(m)[0]); bases.append(w16(m, sym['lnbase']))
        if buffer(m)[1] != 0: err = 'part %d: cursor not at the start' % len(parts)
    raw = lambda p: len(p) + (p.count('\n') if crlf else 0)
    if ''.join(parts) != whole: err = err or 'the parts don\'t make up the file'
    for i, p in enumerate(parts[:-1]):
        if not p.endswith('\n') or raw(p) > MAXW: err = err or 'part %d: %d bytes, ends %r' % (i + 1, raw(p), p[-3:])
        if bases[i + 1] != bases[i] + p.count('\n'): err = err or 'part %d: lnbase %d' % (i + 2, bases[i + 1])
    back = []
    for k in range(len(parts) - 1):
        prv(m); t, c, _ = buffer(m); back.append(t)
        if c != len(t): err = err or 'back to part %d: cursor %d not at the end (%d)' % (len(parts) - 1 - k, c, len(t))
    if back[::-1] != parts[:-1][:len(back)][::1] and back != parts[-2::-1]:
        err = err or 'going back gives other parts'
    return parts, err

def part_walk():
    print('== walking through a big file')
    for crlf, n in ((True, 700), (False, 900)):
        text = bigtext(n)
        data = text.replace('\n', '\r\n').encode() if crlf else text.encode()
        m = machine([('BIG.TXT', data)]); open_n(m, 0)
        t = buffer(m)[0]
        check(m.z.mem[sym['bigmode']] == 1 and text.startswith(t) and t.endswith('\n') and title(m).startswith('IN 6K PARTS'),
              '%s, %d bytes: opens in parts (first part %d chars) %r' % ('CR LF' if crlf else 'LF', len(data), len(t), title(m)))
        if crlf: shot.save(m, S + 's_big_open.png')
        parts, err = walk(m, text, crlf)
        check(err is None, '%d parts, together the whole file; back again part by part %s' % (len(parts), err or ''))
        # line numbers on the title bar: absolute
        nxt(m); keys(m, [('CTRL', 'SPACE')] * 3, extra=10)
        t, c, _ = buffer(m); ln = absline(m)
        want = text[:text.index(t)].count('\n') + t[:c].count('\n') + 1 if t in text else -1
        check(ln == want and title_line(m) == want and t[c:].startswith('line %05d' % want),
              'title bar line number counts the parts before: L%s = %d' % (title_line(m), want))
        check(m.z.mem[sym['modified']] == 0 and cardok(m) and readf(m, '/BIG.TXT') == data, 'walking writes nothing')

def part_save():
    print('== saving a big file')
    text = bigtext(700); data = text.replace('\n', '\r\n').encode()
    m = machine([('BIG.TXT', data)]); open_n(m, 0)
    nxt(m)                                            # part 2: a new line at its start, delete a word
    t2 = buffer(m)[0]; base = text.index(t2)
    keys(m, [('CTRL', 'T')] + list(text_for('INSERTED LINE')) + ['RET'] + [('CTRL', 'SPACE'), ('CTRL', ';'), ('CTRL', ';'), ('CTRL', ';')], extra=20)
    want = text[:base] + 'INSERTED LINE\n' + t2[:t2.index('\n') + 1] + t2[t2.index('\n') + 4:] + text[base + len(t2):]
    keys(m, [('CTRL', 'S'), ('WAIT', 250)], extra=100)
    got = readf(m, '/BIG.TXT')
    check(got == want.replace('\n', '\r\n').encode() and readf(m, '/BIG.BAK') == data and cardok(m) and 'SAVED' in title(m),
          'CTRL+S in part 2: the whole file with the edits, BIG.BAK = before, card clean %r' % title(m))
    check(m.z.mem[sym['modified']] == 0 and buffer(m)[0] == t2.replace('', '', 0)[:0] + want[base:base + len(buffer(m)[0])],
          'still in part 2, not modified')
    # a change, then the next part: SAVE CHANGES? Y saves first
    keys(m, [('CTRL', 'T')] + list(text_for('second edit ')), extra=10)
    want2 = want[:base] + 'second edit ' + want[base:]
    keys(m, [('CTRL', 'B'), ('WAIT', 10), ('CTRL', 'C'), ('WAIT', 30)], extra=20)
    check('SAVE CHANGES' in title(m), 'moving to the next part with changes asks SAVE CHANGES? %r' % title(m))
    keys(m, ['Y', ('WAIT', 400)], extra=100)
    check(readf(m, '/BIG.TXT') == want2.replace('\n', '\r\n').encode() and cardok(m) and want2.find(buffer(m)[0]) > base,
          'Y: saved, then the next part')
    # N: the change is dropped
    keys(m, [('CTRL', 'T')] + list(text_for('dropped')) + [('CTRL', 'T'), ('WAIT', 5), ('CTRL', 'R'), ('WAIT', 30), 'N', ('WAIT', 200)], extra=60)
    check(readf(m, '/BIG.TXT') == want2.replace('\n', '\r\n').encode() and 'dropped' not in buffer(m)[0] and want2.find(buffer(m)[0]) >= 0 and m.z.mem[sym['modified']] == 0,
          'N: not saved, the part before is shown, the change is gone')
    # CTRL+Q: stay
    keys(m, list(text_for('stay')) + [('CTRL', 'B'), ('WAIT', 5), ('CTRL', 'C'), ('WAIT', 30), ('CTRL', 'Q'), ('WAIT', 20)], extra=20)
    check('stay' in buffer(m)[0] and m.z.mem[sym['modified']] == 1, 'CTRL+Q at SAVE CHANGES?: stays in the part')
    # save as another name: that file becomes the source
    keys(m, [('CTRL', 'A'), ('WAIT', 10)] + [('CTRL', ':')] * 12 + list(text_for('COPY.TXT')) + ['RET', ('WAIT', 400)], extra=100)
    c = readf(m, '/COPY.TXT')
    check(c is not None and b'stay' in c and readf(m, '/BIG.TXT') == want2.replace('\n', '\r\n').encode() and cardok(m),
          'SAVE AS COPY.TXT: the whole file with the change, BIG.TXT untouched')
    keys(m, list(text_for('more')) + [('CTRL', 'S'), ('WAIT', 300)], extra=100)
    c2 = readf(m, '/COPY.TXT')
    check(c2 is not None and b'more' in c2 and readf(m, '/COPY.BAK') == c and len(c2) == len(c) + 4 and cardok(m),
          'then CTRL+S saves COPY.TXT again (COPY.BAK = the last one)')

def part_edge():
    print('== edge cases')
    # no line ends at all: parts are cut at 6144 bytes
    text = ('x' * 50 + ' ') * 400
    m = machine([('ONE.TXT', text.encode())]); open_n(m, 0)
    parts, err = walk(m, text, False)
    check(err is None or 'ends' in err, 'one 20,400-byte line: %d parts, together the file %s' % (len(parts), '' if ''.join(parts) == text else 'NO'))
    check(''.join(parts) == text, '... the parts make up the file')
    # too big after editing
    text = bigtext(1270, 49)                         # 1270 x 51 = 64,770 with CR LF
    data = text.replace('\n', '\r\n').encode()
    m = machine([('HUGE.TXT', data)]); open_n(m, 0)
    keys(m, [('CTRL', 'K'), ('CTRL', 'C'), ('CTRL', 'C'), ('CTRL', 'J'), ('CTRL', 'T'), ('CTRL', 'P'), ('CTRL', 'P'), ('CTRL', 'P'), ('WAIT', 10)], extra=10)
    sec0 = dict(m.card.sec)
    keys(m, [('CTRL', 'S'), ('WAIT', 200)], extra=60)
    check('TOO BIG' in title(m) and readf(m, '/HUGE.TXT') == data and cardok(m) and m.z.mem[sym['modified']] == 1,
          '%d bytes + a paste over 64K: FILE TOO BIG, nothing changed %r' % (len(data), title(m)))
    # binary, .VZ, over 64K: hex view
    for name, d in (('BIN.DAT', bytes(range(256)) * 60), ('PROG.VZ', b'VZF0' + b'X' * 20000),
                    ('HUGE2.TXT', bigtext(1700).encode())):
        m = machine([('A.TXT', b'keep\r\n'), (name, d)]); open_n(m, 0, 60); open_n(m, 1, 120)
        check(title(m).startswith('HEX VIEW') and m.z.mem[sym['bigmode']] == 0, '%s (%d bytes): hex view %r' % (name, len(d), title(m)))
    # the small clipboard survives a part change
    text = bigtext(700); data = text.replace('\n', '\r\n').encode()
    m = machine([('BIG.TXT', data)], bank=False); open_n(m, 0)
    keys(m, [('CTRL', 'K')] + [('CTRL', 'SPACE')] * 2 + [('CTRL', 'J'), ('WAIT', 5)], extra=10)
    clip = text[:text.index('line 00003')]
    nxt(m); keys(m, [('CTRL', 'T'), ('CTRL', 'P'), ('WAIT', 10)], extra=10)
    check(buffer(m)[0].startswith(clip) and w16(m, sym['cliplen']) == len(clip), 'no spare bank: copy in part 1, paste in part 2')
    # go to line: absolute numbers
    m.z.mem[sym['menusel']] = 2
    base = w16(m, sym['lnbase'])
    keys(m, [('CTRL', 'I'), ('WAIT', 20)] + [('CTRL', 'SPACE'), ('WAIT', 3)] * 3 + ['RET', ('WAIT', 40)] + list(text_for(str(base + 5))) + ['RET', ('WAIT', 40)], extra=30)
    check(absline(m) == base + 5, 'GO TO LINE %d in part 2: there (L%s)' % (base + 5, title_line(m)))
    # undo doesn't reach into the part before
    keys(m, [('CTRL', '-'), ('WAIT', 5), ('CTRL', '-'), ('WAIT', 5)], extra=10)
    check('NOTHING TO UNDO' in title(m), 'undo: only the changes in this part %r' % title(m))

if __name__ == '__main__':
    parts = {'walk': part_walk, 'save': part_save, 'edge': part_edge}
    for p in (sys.argv[1:] or ['walk', 'save', 'edge']): parts[p]()
    print('\n%d FAILED' % len(FAILS) if FAILS else '\nall passed')
    sys.exit(1 if FAILS else 0)
