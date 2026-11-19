"""Render a scene straight out of HAMSAM2.DAT: scene_view.py index [mono]."""
import sys
from pathlib import Path
from PIL import Image
PAL=[(0,0,0),(170,0,0),(0,170,0),(170,170,0),(0,0,170),(170,0,170),(0,170,170),(170,170,170),(85,85,85),(255,85,85),(85,255,85),(255,255,85),(85,85,255),(255,85,255),(85,255,255),(255,255,255)]
n = int(sys.argv[1]); mono = len(sys.argv) > 2
d = Path('work/port/build/HAMSAM2.DAT').read_bytes()[(n * 2 + mono) * 16384:][:16000]
im = Image.new('RGB', (320, 250))
for c in range(1000):
    rec = d[c * 16:c * 16 + 16]; co = rec[14]
    for y in range(10):
        for x in range(8):
            im.putpixel(((c % 40) * 8 + x, (c // 40) * 10 + y), PAL[(co if rec[y] & (128 >> x) else co >> 4) & 15])
im.resize((960, 750), Image.Resampling.NEAREST).save(f'outputs/scene{n}{"m" if mono else ""}.png')
