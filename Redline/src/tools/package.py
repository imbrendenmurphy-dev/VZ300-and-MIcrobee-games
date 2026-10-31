"""RLCOM.DAT (engine tables -> bank 3, common sprites + title -> upper bank 0)
and REDLINE.VZ (main code $8000 + front end in upper bank 0 from $B800)."""
import os, struct, sys
sys.path.insert(0, os.path.dirname(__file__))
import sprites
from mkvz import mkvz
B = os.path.join(os.path.dirname(__file__), '..', 'build')
OUT = os.path.join(os.path.dirname(__file__), '..', 'release')
os.makedirs(OUT, exist_ok=True)
def chunk(mp, dest, data): return struct.pack('<BHH', mp, dest, len(data)) + data
tables = open(os.path.join(B, 'tables.bin'), 'rb').read()
title = open(os.path.join(B, 'title.bin'), 'rb').read()
common = sprites.common()
assert sprites.COMMON + len(common) <= 0xF800
d = chunk(3, 0x4000, tables) + chunk(3, 0xCC00, title) + chunk(3, sprites.COMMON, common) + b'\x00'
open(os.path.join(OUT, 'RLCOM.DAT'), 'wb').write(d)
main = open(os.path.join(B, 'main.bin'), 'rb').read()
fe = open(os.path.join(B, 'fe.bin'), 'rb').read()
img = main + bytes(0xB800 - 0x8000 - len(main)) + fe
assert 0x8000 + len(img) <= 0xCC00
open(os.path.join(B, 'redline.bin'), 'wb').write(img)
mkvz(os.path.join(B, 'redline.bin'), os.path.join(OUT, 'REDLINE.VZ'), 0x8000, 'REDLINE')
print('RLCOM.DAT %d  REDLINE.VZ %d (loads $8000-$%04X)' % (len(d), len(img) + 24, 0x8000 + len(img)))
