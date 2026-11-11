#!/usr/bin/env python3
"""imgcmp.py dirA dirB - compare frames by frame index, ignoring the HUD row"""
import sys, glob, os
from PIL import Image, ImageChops
a, b = sys.argv[1], sys.argv[2]
bad = 0
fa = sorted(glob.glob(a + '/f*.png'))
for f in fa:
    g = os.path.join(b, os.path.basename(f))
    if not os.path.exists(g): continue
    A = Image.open(f).convert('RGB'); B = Image.open(g).convert('RGB')
    A = A.crop((0, 32, A.width, A.height)); B = B.crop((0, 32, B.width, B.height))
    if ImageChops.difference(A, B).getbbox(): bad += 1
print('%d of %d frames differ' % (bad, len(fa)))
