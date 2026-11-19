"""helpers shared by the stage art modules.
Sprite letters are palette indices:  w = 1, c = 2 (the sky colour), m = 3, o = 0, '.' transparent.
  main palette (CSS0):   o green   w yellow   c blue      m red
  pastel palette (CSS1): o buff    w cyan     c magenta   m orange"""
import math, random
from sprites import G
from scenery import canvas, rect, disc, GH, SH, SKY_C
O_, W_, C_, M_ = 0, 1, 2, 3

def variant(frame_txt, rows):
    """a copy of a sprite drawing with some rows replaced: rows = {row: 'text'}"""
    L = frame_txt.strip('\n').split('\n')
    for i, t in rows.items(): L[i] = t
    return '\n'.join(L)

def frames(*txt): return [G(t) for t in txt]
