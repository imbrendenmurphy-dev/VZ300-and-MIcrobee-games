"""render a 2K mode-1 buffer (from a 64K dump) as PNG: vzshot.py dump.bin addr out.png [css]"""
import sys
sys.path.insert(0, 'tools')
from vzpal import to_img, unpack
m = open(sys.argv[1], 'rb').read()
a = int(sys.argv[2], 16)
to_img(unpack(m[a:a + 2048]), int(sys.argv[4]) if len(sys.argv) > 4 else 0, 4, 6).save(sys.argv[3])
