"""THE FORGOTTEN DEPTHS - tile catalogue.

Tile id byte in the level map:  bit7 = explored, bit6 = opaque (blocks light),
bits 0-5 = index.  Animated tiles come in aligned groups of 4 (the animator
cycles the low 2 bits in place).

Light levels (variant pages):
   0 MEM   (not lit; drawn only if explored, else black)
   1 CDIM  faint cool light (crystal / pool fringe)
   2 DIM   faint warm light (torch fringe)
   3 COOL  cool light (crystal, luminous pool)
   4 LIT   warm light (torches, the player's lantern, fire)
"""
from glyph import T, V, S, BLK, G, Y, B, R, W, C, M, O

MEM, CDIM, DIM, COOL, LIT = range(5)

# light source kinds -> (ray table name, near level, far level)
LIGHTS = {
    'torch':   ('omni7', LIT, DIM),
    'brazier': ('omni9', LIT, DIM),
    'candle':  ('omni4', LIT, DIM),
    'crystal': ('omni5', COOL, CDIM),
    'pool':    ('omni2', COOL, CDIM),
    'shroom':  ('omni2', COOL, CDIM),
    'lava':    ('omni3', LIT, DIM),
    'seal':    ('omni2', COOL, CDIM),
    'portal':  ('omni3', COOL, CDIM),
}

TILES = {}       # name -> id
DEFS = {}        # id -> dict
_free = {'t': 0, 'o': 64}


def tile(name, lit, dim=None, cool=None, mem=BLK, cdim=None, solid=False, opaque=False,
         light=None, anim=0, at=None, special=0):
    key = 'o' if opaque else 't'
    tid = _free[key] if at is None else at
    _free[key] = max(_free[key], tid + 1)
    if dim is None:
        dim = BLK
    if cool is None:
        cool = dim
    if cdim is None:
        cdim = BLK
    TILES[name] = tid
    DEFS[tid] = dict(name=name, g=[mem, cdim, dim, cool, lit], solid=solid or opaque,
                     opaque=opaque, light=light, anim=anim, special=special)
    return tid


def group(name, frames, **kw):
    """4-frame animated group; frames = list of 4 dicts with lit/dim/cool/mem/cdim"""
    key = 'o' if kw.get('opaque') else 't'
    base = (_free[key] + 3) & ~3
    _free[key] = base
    for i, f in enumerate(frames):
        a = dict(kw)
        a.update(f)
        tile(f'{name}{i}', at=base + i, **a)
    TILES[name] = base
    return base


def F(lit, dim=None, cool=None, mem=BLK, cdim=None):
    return dict(lit=lit, dim=dim, cool=cool, mem=mem, cdim=cdim)


# ---------------------------------------------------------------- floors
# warm stone (temple / descent / crypt):   specks fade to red, memory = blue dots
tile('floor0', T(' '), cool=T(' '))
tile('floor1', T(' '), cool=T(' '))
tile('floor2', T('.'), dim=S(R, '..x.'), cool=T('.'), cdim=S(B, '..x.'))
tile('floor3', T(','), cool=T(','))
tile('floor4', T("'"), cool=T("'"))
tile('floor5', T(':'), dim=S(R, 'x...'), cool=T(':'), cdim=S(B, 'x...'))
tile('mosaic1', S(O, 'x..x'), dim=S(R, 'x..x'), cool=S(C, 'x..x'), mem=S(B, 'x..x'), cdim=S(B, 'x..x'))
tile('mosaic2', T('.'), dim=S(R, '..x.'), cool=T('.'), mem=S(B, '..x.'), cdim=S(B, '..x.'))
tile('bones', S(W, '..x.'), dim=S(W, '..x.'), cool=S(W, '.x.x'), mem=S(B, '..x.'), cdim=S(B, '..x.'))
tile('rubble', S(O, 'x.xx'), dim=S(R, 'x.xx'), cool=S(C, 'x.xx'), mem=S(B, '..xx'), cdim=S(B, 'x.xx'))
tile('debris', S(O, 'x...'), dim=S(R, 'x...'), cool=S(C, 'xx..'), cdim=S(B, 'x...'))
tile('doorway', T(':'), dim=S(R, 'x.x.'), cool=T(':'), mem=S(B, 'x.x.'), cdim=S(B, 'x.x.'))
tile('stairup', V('='), dim=S(W, 'xx..'), cool=S(W, 'xx..'), mem=S(M, 'xx..'), cdim=S(B, 'xx..'),
     special=1)
tile('stairdn', V('>'), dim=S(M, 'x.xx'), cool=S(M, 'x.xx'), mem=S(M, 'x.xx'), cdim=S(M, 'x.xx'),
     special=2)
# moss (cave, green CSS) : specks fade to green / cyan
tile('moss2', T('.'), dim=S(G, '..x.'), cool=T('.'), cdim=S(B, '..x.'))
tile('moss4', T('*'), dim=S(G, 'x..x'), cool=T('*'), cdim=S(C, 'x..x'), mem=S(B, '...x'))
tile('altar_l', S(W, '.xxx'), dim=S(R, '.xxx'), cool=S(C, '.xxx'), mem=S(B, '..xx'), cdim=S(B, '.xxx'), solid=True)
tile('altar_m', S(W, 'xxxx'), dim=S(R, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, '..xx'), cdim=S(B, 'xxxx'), solid=True)
tile('altar_r', S(W, 'xxx.'), dim=S(R, 'xxx.'), cool=S(C, 'xxx.'), mem=S(B, '..xx'), cdim=S(B, 'xxx.'), solid=True)
tile('tomb_l', S(W, '.xxx'), dim=S(B, '.xxx'), cool=S(C, '.xxx'), mem=S(B, '.x.x'), cdim=S(B, '.xxx'), solid=True)
tile('tomb_m', S(O, 'xxxx'), dim=S(B, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'x.x.'), cdim=S(B, 'xxxx'), solid=True)
tile('tomb_r', S(W, 'xxx.'), dim=S(B, 'xxx.'), cool=S(C, 'xxx.'), mem=S(B, 'x.x.'), cdim=S(B, 'xxx.'), solid=True)
tile('boulder', S(Y, '.xxx'), dim=S(R, '.xxx'), cool=S(C, '.xxx'), mem=S(B, '.xxx'), cdim=S(B, '.xxx'), solid=True)
tile('bridge', S(O, 'xx..'), dim=S(R, 'xx..'), cool=S(C, 'xx..'), mem=S(B, 'xx..'), cdim=S(B, 'xx..'))
tile('plate', V(' '), dim=S(R, 'xxxx'), cool=V(' '), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), special=10)
tile('brokenwall', T('%'), dim=S(R, 'x.xx'), cool=S(C, 'x.xx'), mem=S(B, 'x.x.'), cdim=S(B, 'x.xx'))

# animated transparent groups
group('water', [F(S(B, 'xx.x'), S(B, 'x...'), S(C, 'xx.x'), S(B, '.x..'), S(B, 'x...')),
                F(S(B, 'x.xx'), S(B, '.x..'), S(C, 'x.xx'), S(B, '.x..'), S(B, '.x..')),
                F(S(C, '.x..'), S(B, '..x.'), S(C, '.xx.'), S(B, '.x..'), S(B, '..x.')),
                F(S(B, '.xxx'), S(B, '...x'), S(C, '.xxx'), S(B, '.x..'), S(B, '...x'))], solid=True, special=7)
group('pool', [F(S(C, 'xxxx'), S(C, 'xx.x'), S(C, 'xxxx'), S(B, 'x.x.'), S(C, 'x.xx')),
               F(S(C, 'x.xx'), S(C, 'x.xx'), S(C, 'x.xx'), S(B, 'x.x.'), S(C, 'xx.x')),
               F(S(W, '.x..'), S(C, 'xxx.'), S(W, '.x..'), S(B, 'x.x.'), S(C, 'xxx.')),
               F(S(C, 'xxx.'), S(C, '.xxx'), S(C, 'xxx.'), S(B, 'x.x.'), S(C, '.xxx'))],
      solid=True, light='pool')
group('mote', [F(T(' ')), F(T("'"), S(W, 'x...'), S(C, 'x...')),
               F(T('.'), S(W, '..x.'), S(C, '..x.')), F(T(' '))])
group('portal', [F(S(M, 'x..x'), S(M, 'x..x'), S(M, 'x..x'), S(B, 'x..x'), S(M, 'x..x')),
                 F(S(C, '.xx.'), S(C, '.xx.'), S(C, '.xx.'), S(B, 'x..x'), S(C, '.xx.')),
                 F(S(W, 'x..x'), S(W, 'x..x'), S(W, 'x..x'), S(B, 'x..x'), S(W, 'x..x')),
                 F(S(M, '.xx.'), S(M, '.xx.'), S(M, '.xx.'), S(B, 'x..x'), S(M, '.xx.'))],
      light='portal', special=9)
group('rune', [F(V('X'), S(M, 'x..x'), S(M, 'x..x'), S(B, 'x..x'), S(B, 'x..x')),
               F(T('X'), S(M, '.xx.'), S(M, '.xx.'), S(B, 'x..x'), S(B, '.xx.')),
               F(T('+'), S(M, 'x..x'), S(M, 'x..x'), S(B, 'x..x'), S(B, 'x..x')),
               F(T('X'), S(M, '.xx.'), S(M, '.xx.'), S(B, 'x..x'), S(B, '.xx.'))], special=3)
group('shroom', [F(S(G, '..xx'), S(G, '..xx'), S(G, '..xx'), S(B, '..x.'), S(G, '..xx')),
                 F(S(C, '..xx'), S(C, '..xx'), S(C, '..xx'), S(B, '..x.'), S(C, '..xx')),
                 F(S(G, '..xx'), S(G, '..xx'), S(G, '..xx'), S(B, '..x.'), S(G, '..xx')),
                 F(S(C, '..x.'), S(G, '..x.'), S(C, '..x.'), S(B, '..x.'), S(G, '..x.'))],
      solid=True, light='shroom')
group('lava', [F(S(R, 'xxxx'), S(R, 'xx.x'), S(R, 'xxxx'), S(R, '.x..'), S(R, 'x.xx')),
               F(S(O, 'xx.x'), S(R, 'x.xx'), S(O, 'xx.x'), S(R, '.x..'), S(R, 'xx.x')),
               F(S(Y, '.x..'), S(O, 'xxx.'), S(Y, '.x..'), S(R, '.x..'), S(R, 'xxx.')),
               F(S(O, 'x.xx'), S(R, '.xxx'), S(O, 'x.xx'), S(R, '.x..'), S(R, '.xxx'))],
      solid=True, light='lava', special=6)
group('seal', [F(S(M, 'x.x.'), S(M, 'x.x.'), S(M, 'x.x.'), S(B, 'x.x.'), S(M, 'x.x.')),
               F(S(M, '.x.x'), S(M, '.x.x'), S(M, '.x.x'), S(B, 'x.x.'), S(M, '.x.x')),
               F(S(W, 'x.x.'), S(W, 'x.x.'), S(W, 'x.x.'), S(B, 'x.x.'), S(W, 'x.x.')),
               F(S(C, '.x.x'), S(C, '.x.x'), S(C, '.x.x'), S(B, 'x.x.'), S(C, '.x.x'))],
      solid=True, light='seal', special=8)
group('ember', [F(S(Y, 'xxxx'), S(Y, 'xxxx'), S(Y, 'xxxx'), S(R, 'xxxx'), S(Y, 'xxxx')),
                F(S(W, '.xx.'), S(W, '.xx.'), S(W, '.xx.'), S(R, 'xxxx'), S(W, '.xx.')),
                F(S(O, 'xxxx'), S(O, 'xxxx'), S(O, 'xxxx'), S(R, 'xxxx'), S(O, 'xxxx')),
                F(S(Y, 'x..x'), S(Y, 'x..x'), S(Y, 'x..x'), S(R, 'xxxx'), S(Y, 'x..x'))],
      light='brazier', special=2)

# ---------------------------------------------------------------- opaque
tile('rock', BLK, opaque=True)
# warm masonry: rims (wall tops seen from above) and faces (south facing)
tile('rim1', S(O, 'xxxx'), dim=S(R, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('rim2', S(O, 'xxxx'), dim=S(R, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('face1', S(Y, 'xxxx'), dim=S(O, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('face2', S(Y, 'xxxx'), dim=S(O, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('face3', S(Y, 'xxxx'), dim=S(O, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('pillar_t', S(Y, 'xxxx'), dim=S(R, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('pillar_m', S(W, 'xxxx'), dim=S(R, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('pillar_b', S(O, 'xxxx'), dim=S(R, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('statue_t', S(W, '.xx.'), dim=S(R, '.xx.'), cool=S(C, '.xx.'), mem=S(B, '.xx.'), cdim=S(B, '.xx.'), opaque=True)
tile('statue_b', S(W, 'xxxx'), dim=S(R, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('door', T('#'), dim=S(O, 'xxxx'), cool=S(C, 'x.x.'), mem=S(M, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True,
     special=4)
tile('hidden', S(G, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True, special=5)
# cave (green CSS): irregular rock in green / blue, faces in cyan/buff glints
tile('crim1', S(G, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('crim2', S(G, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('crim3', S(G, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('cface1', S(Y, 'xxxx'), dim=S(G, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('cface2', S(Y, 'xxxx'), dim=S(G, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('cface3', S(Y, 'xxxx'), dim=S(G, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
# crypt: cold blue-grey masonry
tile('krim1', S(M, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('krim2', S(M, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('kface1', S(W, 'xxxx'), dim=S(C, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('kface2', S(W, 'xxxx'), dim=S(C, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('kface3', S(W, 'xxxx'), dim=S(C, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)

group('torch', [F(S(Y, 'xx.x'), S(Y, 'xx.x'), S(Y, 'xx.x'), S(R, 'xx.x'), S(Y, 'xx.x')),
                F(S(O, 'x.xx'), S(O, 'x.xx'), S(O, 'x.xx'), S(R, 'xx.x'), S(O, 'x.xx')),
                F(S(Y, '.xxx'), S(Y, '.xxx'), S(Y, '.xxx'), S(R, 'xx.x'), S(Y, '.xxx')),
                F(S(W, 'xx..'), S(W, 'xx..'), S(W, 'xx..'), S(R, 'xx.x'), S(W, 'xx..'))],
      opaque=True, light='torch')
group('brazier', [F(S(Y, 'xxxx'), S(Y, 'xxxx'), S(Y, 'xxxx'), S(R, '..xx'), S(Y, 'xxxx')),
                  F(S(O, '.xxx'), S(O, '.xxx'), S(O, '.xxx'), S(R, '..xx'), S(O, '.xxx')),
                  F(S(W, 'x.xx'), S(W, 'x.xx'), S(W, 'x.xx'), S(R, '..xx'), S(W, 'x.xx')),
                  F(S(R, 'xxxx'), S(R, 'xxxx'), S(R, 'xxxx'), S(R, '..xx'), S(R, 'xxxx'))],
      opaque=True, light='brazier')
group('crystal', [F(S(C, '.xxx'), S(C, '.xxx'), S(C, '.xxx'), S(B, '.xx.'), S(C, '.xxx')),
                  F(S(W, '.x.x'), S(W, '.x.x'), S(W, '.x.x'), S(B, '.xx.'), S(W, '.x.x')),
                  F(S(M, '.xxx'), S(M, '.xxx'), S(M, '.xxx'), S(B, '.xx.'), S(M, '.xxx')),
                  F(S(C, 'xxx.'), S(C, 'xxx.'), S(C, 'xxx.'), S(B, '.xx.'), S(C, 'xxx.'))],
      opaque=True, light='crystal')
group('candle', [F(S(Y, 'x...'), S(Y, 'x...'), S(Y, 'x...'), S(B, 'x...'), S(Y, 'x...')),
                 F(S(Y, 'x...'), S(Y, 'x...'), S(Y, 'x...'), S(B, 'x...'), S(Y, 'x...')),
                 F(S(O, '.x..'), S(O, '.x..'), S(O, '.x..'), S(B, 'x...'), S(O, '.x..')),
                 F(S(Y, 'x...'), S(Y, 'x...'), S(Y, 'x...'), S(B, 'x...'), S(Y, 'x...'))],
      opaque=True, light='candle')

tile('gate', S(W, 'x.x.'), dim=S(B, 'x.x.'), cool=S(C, 'x.x.'), mem=S(B, 'x.x.'), cdim=S(B, 'x.x.'),
     opaque=True, special=11)
tile('hid_t', S(Y, 'xxxx'), dim=S(O, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True, special=5)
tile('hid_y', S(G, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True, special=5)
tile('hid_v', S(R, 'xxxx'), dim=S(M, 'xxxx'), cool=S(M, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True, special=5)
tile('hglow', S(M, 'xx.x'), dim=S(M, 'x..x'), cool=S(M, 'xx.x'), mem=S(M, '.xx.'), cdim=S(M, '.x.x'),
     opaque=True, special=5)
# library shelves
tile('shelf1', S(R, 'x.xx'), dim=S(R, 'x.x.'), cool=S(B, 'x.xx'), mem=S(B, 'x.x.'), cdim=S(B, 'x.x.'), opaque=True)
tile('shelf2', S(Y, 'xx.x'), dim=S(O, '.x.x'), cool=S(C, 'xx.x'), mem=S(B, '.x.x'), cdim=S(B, '.x.x'), opaque=True)
tile('shelf3', S(C, '.xxx'), dim=S(B, '.x.x'), cool=S(C, '.xxx'), mem=S(B, '.x.x'), cdim=S(B, '.x.x'), opaque=True)
# drowned city stone (green CSS): blue-grey rims, pale wet faces, moss cracks
tile('yrim1', S(G, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('yrim2', S(G, 'xxxx'), dim=S(B, 'xxxx'), cool=S(B, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('yface1', S(C, 'xxxx'), dim=S(B, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('yface2', S(C, 'xxxx'), dim=S(B, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('yface3', S(C, 'xxxx'), dim=S(B, 'xxxx'), cool=S(C, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
# volcanic basalt (warm CSS): dark red rims, glowing orange / obsidian faces
tile('vrim1', S(R, 'xxxx'), dim=S(M, 'xxxx'), cool=S(M, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('vrim2', S(R, 'xxxx'), dim=S(M, 'xxxx'), cool=S(M, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('vface1', S(O, 'xxxx'), dim=S(R, 'xxxx'), cool=S(M, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('vface2', S(O, 'xxxx'), dim=S(R, 'xxxx'), cool=S(M, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
tile('vface3', S(O, 'xxxx'), dim=S(R, 'xxxx'), cool=S(M, 'xxxx'), mem=S(B, 'xxxx'), cdim=S(B, 'xxxx'), opaque=True)
group('gear', [F(S(W, 'x..x'), S(B, 'x..x'), S(C, 'x..x'), S(B, 'x..x'), S(B, 'x..x')),
               F(S(Y, '.xx.'), S(B, '.xx.'), S(C, '.xx.'), S(B, 'x..x'), S(B, '.xx.')),
               F(S(W, 'x..x'), S(B, 'x..x'), S(C, 'x..x'), S(B, 'x..x'), S(B, 'x..x')),
               F(S(O, '.xx.'), S(B, '.xx.'), S(C, '.xx.'), S(B, 'x..x'), S(B, '.xx.'))], opaque=True)


def is_wall(name):
    return False


def _old_is_wall(name):
    return name in ('rock', 'rim1', 'rim2', 'face1', 'face2', 'face3') or name[:4] in ('crim', 'cfac', 'krim', 'kfac')


if __name__ == '__main__':
    for tid in sorted(DEFS):
        print(tid, DEFS[tid]['name'])
