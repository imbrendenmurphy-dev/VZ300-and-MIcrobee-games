#!/usr/bin/env python3
# stills (768x576, exact 6x9 pixels) and the showcase GIF (256x192) from cap/ frames
import os
from PIL import Image
PAL = [(0x30,0xD2,0x00),(0xF0,0xF0,0x70),(0x30,0x28,0xC8),(0xD0,0x20,0x20),(0xF0,0xF0,0xE0),(0x40,0xD0,0xA0),(0xD0,0x40,0xE0),(0xF0,0x80,0x20)]
def native(path):
    im = Image.open(path).convert('RGB'); out = Image.new('RGB', (128, 64))
    for y in range(64):
        for x in range(128): out.putpixel((x, y), im.getpixel((4*x+1, 6*y+2)))
    return out
def f(seq, n): return 'cap/%s/big_%05d.png' % (seq, n)
STILLS = [('01-title', 'attract', 164), ('02-story-dojo-burns', 'attract', 1204), ('03-story-fortress', 'attract', 1524),
 ('04-story-ashes', 'attract', 2004), ('05-story-mountain-road', 'attract', 2324), ('06-controls', 'attract', 2644),
 ('07-stage-card', 's1', 1700), ('08-stage1-rope-bridge', 's1', 2340), ('09-stage1-second-keeper', 's1', 3460),
 ('10-stage2-outer-court', 's2', 500), ('11-stage2-court-gate', 's2', 1300), ('12-kurokage-scene', 's3', 340),
 ('13-stage3-lantern-hall', 's3', 1780), ('14-stage4-falling-rocks', 's4', 372), ('15-stage4-scout-flying-kick', 's4', 548),
 ('16-stage4-cliff-duel', 's4', 1540), ('17-stage5-inner-gate', 's5', 580), ('18-stage5-gate-oni', 's5', 2980),
 ('19-hoshi-caged-scene', 's6', 460), ('20-stage6-tiger-throne', 's6', 2260), ('21-kurokage-falls', 's6', 4460), ('21b-knockout-flash', 's6', 4452),
 ('22-stage-clear', 's4', 1940), ('23-ending', 's6', 4900), ('24-cast-roll', 's6', 5380), ('25-credits', 's6', 5860),
 ('26-hall-of-masters', 'attract', 3044), ('27-demo-mode', 'demo', 3640)]
os.makedirs('release/screenshots', exist_ok=True)
for name, seq, n in STILLS:
    if os.path.exists(f(seq, n)):
        native(f(seq, n)).resize((768, 576), Image.NEAREST).save('release/screenshots/%s.png' % name)
    else: print('missing', name)
SEGS = [('attract', 84, 244), ('attract', 964, 1124), ('attract', 1364, 1524), ('attract', 1764, 1924), ('attract', 2164, 2324),
        ('s1', 1700, 1760), ('s1', 2240, 2500), ('s2', 2020, 2260), ('s3', 260, 380), ('s3', 1620, 1860),
        ('s4', 340, 560), ('s5', 2900, 3140), ('s6', 220, 400), ('s6', 3100, 3340), ('s6', 4400, 4600),
        ('s6', 4780, 4960), ('s6', 5140, 5180), ('s6', 5380, 5420), ('s6', 5860, 5900), ('attract', 2964, 3064)]
pal = Image.new('P', (1, 1)); pal.putpalette([c for rgb in PAL for c in rgb]+[0]*(768-24))
frames = []
for seq, a, b in SEGS:
    for n in range(a, b, 4):
        if os.path.exists(f(seq, n)):
            im = native(f(seq, n)).resize((256, 192), Image.NEAREST).quantize(palette=pal, dither=Image.Dither.NONE)
            frames.append(im)
frames[0].save('release/tigergate-showcase.gif', save_all=True, append_images=frames[1:], duration=80, loop=0, optimize=False, disposal=1)
print(len(frames), 'frames', os.path.getsize('release/tigergate-showcase.gif')//1024, 'KB')
