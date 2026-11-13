#!/usr/bin/env python3
"""Export the chosen captures (build/cap) as 512x384 PNGs plus contact sheets."""
import os
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAP = os.path.join(ROOT, 'build', 'cap')
OUT = os.path.join(ROOT, 'screenshots')
ATTRACT = [('title', 'attract', 1000), ('letters', 'attract', 5600), ('briefing', 'attract', 1400),
           ('fleet', 'attract', 2000), ('controls', 'attract', 2400), ('demo', 'attract', 2800),
           ('demo_play', 'attract', 3800), ('hall_of_fame', 'attract', 5200)]
GAME = [('warp_in', 's1', 225), ('lock_on', 's1', 750), ('hit_bezel', 's1', 825),
        ('rock_belt', 's2', 1050), ('minefield', 's3', 1350), ('troops_landed', 's4', 1170),
        ('invasion_planet', 's4', 1890), ('nebula', 's5', 900), ('ace_squadron', 's6', 1200),
        ('gauntlet', 's7', 750), ('mothership', 's8', 750), ('core_destroyed', 's8', 1800),
        ('sector_clear', 'clear', 1020), ('warp_out', 'clear', 1470), ('mission_complete', 's8', 2550),
        ('paused', 'pause', 753), ('game_over', 'over', 750), ('initials', 'over', 1650)]


def shot(cap, f):
    return Image.open('%s/%s_%05d.ppm' % (CAP, cap, f)).convert('RGB').crop((32, 24, 288, 216)).resize((512, 384), Image.NEAREST)


def export(kind, lst, cols):
    ims = []
    for i, (n, cap, f) in enumerate(lst, 1):
        im = shot(cap, f)
        im.save('%s/%s/SB2_%s_%02d_%s.png' % (OUT, kind, kind, i, n))
        ims.append(im)
    tw, th, g = 256, 192, 8
    rows = (len(ims) + cols - 1) // cols
    sh = Image.new('RGB', (cols * (tw + g) + g, rows * (th + g) + g), (0, 0, 0))
    for i, im in enumerate(ims):
        sh.paste(im.resize((tw, th), Image.NEAREST), (g + (i % cols) * (tw + g), g + (i // cols) * (th + g)))
    sh.save('%s/SB2_%s_sheet.png' % (OUT, kind))


export('attract', ATTRACT, 4)
export('gameplay', GAME, 6)
