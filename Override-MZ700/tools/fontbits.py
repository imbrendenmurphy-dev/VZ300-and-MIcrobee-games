"""fontbits.py - print glyph bitmaps as text.  py tools/fontbits.py 0:43 0:4D 1:61 ..."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rom = open(os.path.join(ROOT, 'rom', 'mz700fon.int'), 'rb').read()
items = []
for a in sys.argv[1:]:
    b, c = a.split(':')
    items.append((int(b), int(c, 16)))
for i in range(0, len(items), 8):
    grp = items[i:i + 8]
    print('   '.join('%d:%02X    ' % g for g in grp))
    for y in range(8):
        line = []
        for b, c in grp:
            v = rom[(b * 256 + c) * 8 + y]
            line.append(''.join('#' if (v >> x) & 1 else '.' for x in range(8)))
        print('   '.join(line))
    print()
