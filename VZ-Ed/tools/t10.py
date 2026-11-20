"""VZ-ED 0.2: T-states per keystroke in wrap mode (like t7.py for 0.1).
A document of 600-character paragraphs (about 20 screen rows each)."""
import sys; sys.path.insert(0, '.')
from harness import *
dos = open('VZDOS.VZ', 'rb').read(); ed = open('../out/VZED.VZ', 'rb').read()
sym = {l.split()[1]: int(l.split()[0], 16) for l in open('../out/vzed.sym')}
para = ' '.join('word%d' % (i % 97) for i in range(100))[:600]
doc = (''.join(para + '\r\n\r\n' for _ in range(16))).encode()       # ~9.6K
c = Card(spc=8); c.addfile(2, 'VZDOS.VZ', dos); c.addfile(2, 'SHELL.VZ', ed); c.addfile(2, 'DOC.TXT', doc); c.finish()
m = VZ(dos[24:], c, maxlba=max(c.sec) + 5000); m.run(0x4004, frames=120)
m.type_keys([('CTRL', 'O'), ('WAIT', 20), 'RET', ('WAIT', 40), ('CTRL', 'W'), ('WAIT', 5)]); m.run_script(extra=5)
z = m.z
def measure(keys, label):
    m.type_keys(keys)
    disp = sym['dispatch']; edlp = sym['ed_lp']; start = None; res = []
    f0 = m.frame
    while (m.script or start is not None) and m.frame - f0 < 3000:
        if z.pc < 0x4000: m.trap(); continue
        if z.pc == disp: start = z.t
        if z.pc == edlp and start is not None: res.append(z.t - start); start = None
        z.step()
    r = max(res) if res else 0
    if label: print('%-44s %7d T-states  (= %.2f frames)' % (label, r, r / 70630))
for style in (0, 2):
    if style: m.type_keys([('CTRL', 'D'), ('WAIT', 5), ('CTRL', 'D'), ('WAIT', 5), ('CTRL', 'T'), ('WAIT', 10)]); m.run_script(extra=5)
    measure(['A'], 'style %d: type a letter, start of a paragraph' % style)
    measure([('CTRL', 'X')], 'style %d: end of the line (paragraph)' % style)
    measure(['A'], 'style %d: type a letter, end of a paragraph' % style)
    measure([('CTRL', 'M')] * 1, 'style %d: cursor left' % style)
    for i in range(10): measure([('CTRL', '.')], 'style %d: cursor up (inside the paragraph)' % style) if i in (0, 9) else measure([('CTRL', '.')], '')
    measure([('CTRL', 'SPACE')], 'style %d: cursor down' % style)
    measure([('CTRL', 'C')], 'style %d: page down' % style)
    measure([('CTRL', 'R')], 'style %d: page up' % style)
    measure([('CTRL', 'B')], 'style %d: end of file' % style)
    measure([('CTRL', 'T')], 'style %d: top of file' % style)
    measure([('CTRL', 'B'), ('CTRL', 'Z')], 'style %d: start of the last line' % style)
