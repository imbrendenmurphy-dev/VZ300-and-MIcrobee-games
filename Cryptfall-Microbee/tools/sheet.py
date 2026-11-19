"""Preview sheet of every tile picture and frame (build/sheet.png)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
import art as A
import tiles as TL
PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
       (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
S = A.slots()
fr = [(S[n], f) for n in TL.ARTS for f in A.tall(S[n].frames)]
W = 14
img = np.zeros((((len(fr) + W - 1) // W) * 24, W * 20, 3), np.uint8)
for i, (s, f) in enumerate(fr):
    x0, y0 = (i % W) * 20 + 2, (i // W) * 24 + 2
    for y in range(20):
        for x in range(16):
            if f[y, x]:
                img[y0 + y, x0 + x] = PAL[s.cols[(y // 10) * 2 + x // 8]]
Image.fromarray(img).resize((W * 20 * 4, img.shape[0] * 4 * 11 // 12), Image.NEAREST).save(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'sheet.png'))
