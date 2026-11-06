#!/usr/bin/env python3
"""GRAVES 'N' GARGOYLES - stages 2-7: themes, tiles, creatures, bosses, music,
level builder and pack emitter.  Stage 1 (Gallows Hill) keeps its hand-built
level from mkassets.py; this file only writes its pack header.

Colour letters: g y b r = colour indexes 0 1 2 3.  In colour set 0 that is
green yellow blue red; stages using colour set 1 (CSS=1) show the same indexes
as buff cyan magenta orange.
"""
import os, sys, random, math
sys.path.insert(0, os.path.dirname(__file__))
from art import TILES as T1, SPRITES as SP1
from mkassets import pack, hexrow, db_lines, seq

# ------------------------------------------------------------------ helpers
def recolour(rows, m):
    return [''.join(m.get(c, c) for c in r) for r in rows]

def headless(frame, rows=5, neck='r'):
    """remove the head (top rows) leaving a neck stump: for the 'tough' role"""
    out = ['.' * len(frame[0])] * rows + frame[rows:]
    # stump on the first body row
    r = list(out[rows])
    mid = [i for i, c in enumerate(r) if c != '.']
    if mid:
        c = mid[len(mid) // 2]
        top = list(out[rows - 1]); top[c] = neck; out[rows - 1] = ''.join(top)
    return out

def bob(frame):
    return ['.' * len(frame[0])] + frame[:-1]

def legs(frame, alt):
    return frame[:len(frame) - len(alt)] + alt

def mirror_wings(frame):
    return frame[::-1]

def sprite_lines(sprites, prefix, nop2=()):
    desc, data = [], []
    for name, frames in sprites.items():
        for fi, f in enumerate(frames):
            w = len(f[0]); h = len(f)
            assert all(len(r) == w for r in f), (prefix, name, fi, [len(r) for r in f])
            pw = (w + 3) // 4
            rows = [r + '.' * (pw * 4 - w) for r in f]
            p0 = []
            for r in rows:
                k, d = pack(r)
                for a, b in zip(k, d): p0 += [a, b]
            lab = '%s%s_%d' % (prefix, name.upper(), fi)
            if name in nop2:
                desc.append('%s: db %d,%d\n    dw %s_P0,0' % (lab, pw, h, lab))
            else:
                p2 = []
                for r in rows:
                    k, d = pack('..' + r + '..')
                    for a, b in zip(k, d): p2 += [a, b]
                desc.append('%s: db %d,%d\n    dw %s_P0,%s_P2' % (lab, pw, h, lab, lab))
            data.append('%s_P0:' % lab)
            data += db_lines(p0)
            if name not in nop2:
                data.append('%s_P2:' % lab)
                data += db_lines(p2)
    return desc + data

# base tile shapes taken from stage 1, recoloured per theme
BASE = dict(T1)

# ------------------------------------------------------------------ themes
THEMES = {}

def theme(n, **kw):
    THEMES[n] = kw

# ---------------- 2: THE WITCHWOOD -----------------------------------------
W = {}
W['sky'] = ['bbbbbbbb'] * 8
W['star1'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbgb', 'bbbbbbbb', 'bbbbbbbb', 'bgbbbbbb', 'bbbbbbbb', 'bbbbbbbb']
W['star2'] = ['bbbbbbbb', 'bbbbbybb', 'bbbbbbbb', 'bbbbbbbb', 'bbybbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']
W['back_t'] = ['bbbbbbbb', 'bbbgbbbb', 'bbgggbbb', 'bgggggbb', 'bbgggbgb', 'bgggggggg'[:8], 'gggbgggg', 'gbggggbg']
W['back_m'] = ['gbggbggg', 'ggbgggbg', 'gggggggg', 'bggbgggb', 'gggggbgg', 'gbgggggg', 'gggbgggg', 'gggggggg']
W['top'] = ['gggggggg', 'gygggggy', 'gggbgggg', 'bgbgbgbg', 'gbgbgbgb', 'bbgbbbgb', 'bgbbbbbb', 'bbbgbbbg']
W['top_l'] = ['bbbbgggg', 'bbgggggy', 'bggbgggg', 'bgbgbgbg', 'gbgbgbgb', 'bbgbbbgb', 'bgbbbbbb', 'bbbgbbbg']
W['top_r'] = ['ggggbbbb', 'gyggggbb', 'gggbgggb', 'bgbgbgbg', 'gbgbgbgb', 'bbgbbbgb', 'bgbbbbbb', 'bbbgbbbg']
W['fill'] = ['bbgbbbgb', 'bgbbbbbb', 'bbbbgbbb', 'gbbbbbbg', 'bbbgbbbb', 'bbbbbbgb', 'bgbbbbbb', 'bbbbgbbb']
W['fill2'] = ['bbgbbbgb', 'brrbbbbb', 'bbrrrbbb', 'gbbbrbbg', 'bbbbbrrb', 'bbbbbbgb', 'bgbbbbbb', 'bbbbgbbb']
W['fill3'] = W['fill']
W['block'] = ['rrrrrrrr', 'ryyyyyrr', 'rrrrrrrr', 'rrryrrrr', 'rrrrrrrr', 'yrrrrryr', 'rrrrrrrr', 'rryrrrrr']   # log
W['block_top'] = ['gggggggg', 'gyrrrryg', 'rrrrrrrr', 'rrryrrrr', 'rrrrrrrr', 'yrrrrryr', 'rrrrrrrr', 'rryrrrrr']
W['sm_t'] = ['bbrrrrbb', 'brryyrrb', 'rryrryrr', 'rryyyyrr', 'rrrrrrrr', 'rryrrrrr', 'rrrrryrr', 'rrrrrrrr']   # stump
W['sm_b'] = ['rrrrrrrr', 'rryrrrrr', 'rrrrbrrr', 'rrrbbbrr', 'rrrrbrrr', 'rrrrrrrr', 'grrrrrrg', 'gggggggg']
W['small'] = ['bbbbbbbb', 'bbbrrbbb', 'bbryyrbb', 'brrrrrrb', 'rryrryrr', 'rrrrrrrr', 'grrrrrrg', 'gggggggg']
W['deco_t'] = ['bbbrbbbb', 'rbbrbbrb', 'brbrbrbb', 'bbrrrbbb', 'bbbrrbbr', 'rbbrrbrb', 'brrrrrbb', 'bbbrrbbb']
W['deco_m'] = ['bbbrrbbb', 'bbbrrbbb', 'brrrrbbb', 'bbbrrbbb', 'bbbrrrrb', 'bbbrrbbb', 'bbbrybbb', 'bbbrrbbb']
W['deco_b'] = ['bbbrrbbb', 'bbbrrbbb', 'bbrrrrbb', 'brrrrrrb', 'rrbrrbrr', 'gbgrrgbg', 'gggggggg', 'gggggggg']
W['deco2'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbybbbb', 'bbgbgbyb', 'bgbgbgbg', 'gbgbgbgb']   # ferns
W['plat'] = ['brrrrrrb', 'rryrryrr', 'ryyrryyr', 'rrrrrrrr', 'bbbyybbb', 'bbbyybbb', 'bbbbbbbb', 'bbbbbbbb']   # toadstool cap
W['plat_post'] = ['brrrrrrb', 'rryrryrr', 'ryyrryyr', 'rrrrrrrr', 'bbbyybbb', 'bbbyybbb', 'bbbyybbb', 'bbbyybbb']
W['stalk'] = ['bbbyybbb'] * 8
W['haz'] = ['bbbbbbbb', 'brbbbbrb', 'rgrbbrgr', 'grgrrgrg', 'rgrgrgrg', 'grrgrrgr', 'rgrgrgrg', 'grgrgrgr']   # brambles
W['haz2'] = ['bbbbbbbb', 'bbbrbbbb', 'bbrgrbbr', 'rgrgrrgr', 'grgrgrgr', 'rgrrgrrg', 'grgrgrgr', 'rgrgrgrg']
W['spike'] = ['bbbbbbbb', 'bbbbbbbb', 'brbbbrbb', 'brbbbrbb', 'rrrbrrrb', 'rgrrrgrr', 'gggggggg', 'bgbgbgbg']
W['roof_l'] = recolour(BASE['roof_l'], {'r': 'r', 'y': 'y', 'g': 'r'})
W['roof_m'] = recolour(BASE['roof_m'], {'r': 'r', 'y': 'y', 'g': 'r'})
W['roof_r'] = recolour(BASE['roof_r'], {'r': 'r', 'y': 'y', 'g': 'r'})
W['door_t'] = BASE['door_t']; W['door_b'] = BASE['door_b']
W['pillar'] = W['block']; W['column'] = W['deco_m']
theme(2, name='THE WITCHWOOD', css=0, amb=0, tiles=W, stars=0.08,
      card='WHERE THE TREES HAVE TEETH', boss='THE HUNGRY OAK STIRS!')

# ---------------- 3: THE DROWNED VILLAGE -----------------------------------
D = {}
D['sky'] = ['bbbbbbbb'] * 8
D['star1'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbybbb', 'bbbbybbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']   # rain
D['star2'] = ['bbbbbbbb', 'bybbbbbb', 'bybbbbbb', 'bbbbbbbb', 'bbbbbbyb', 'bbbbbbyb', 'bbbbbbbb', 'bbbbbbbb']
D['back_t'] = ['bbbbbbbb', 'bbbbrbbb', 'bbbrrrbb', 'bbrrrrrb', 'brrrrrrr', 'brryrrrb', 'brrrrrrb', 'brrrryrb']   # far houses
D['back_m'] = ['brrrrrrb', 'brryrrrb', 'brrrrrrb', 'gbgbgbgb', 'bgbgbgbg', 'gbgbgbgb', 'bgbgbgbg', 'gbgbgbgb']
D['top'] = ['yryryryr', 'rrrrrrrr', 'rgrrrgrr', 'rrrrrrrr', 'rrrgrrrr', 'rrrrrrgr', 'grrrrrrr', 'rrrrgrrr']   # cobbles
D['top_l'] = D['top']; D['top_r'] = D['top']
D['fill'] = ['rrrgrrrr', 'rrrrrrgr', 'grrrrrrr', 'rrrrgrrr', 'rrrrrrrr', 'rgrrrrrg', 'rrrrrrrr', 'rrgrrrrr']
D['fill2'] = D['fill']; D['fill3'] = D['fill']
D['block'] = recolour(BASE['stone'], {'g': 'r', 'y': 'y', 'b': 'b'})
D['block_top'] = recolour(BASE['stone_top'], {'g': 'r', 'y': 'y', 'b': 'b'})
D['sm_t'] = ['bbyyyybb', 'byyyyyyb', 'brbbbbrb', 'brbbbbrb', 'yyyyyyyy', 'rrrrrrrr', 'ryrryrry', 'rrrrrrrr']   # well
D['sm_b'] = ['rrrrrrrr', 'ryrryrry', 'rrrrrrrr', 'rrryrrrr', 'rrrrrrrr', 'ryrrryrr', 'rrrrrrrr', 'rrrrrrrr']
D['small'] = ['bbbbbbbb', 'bbbbbbbb', 'byyyyyyb', 'yrrrrrry', 'ryrryrry', 'yrrrrrry', 'ryyyyyyr', 'rrrrrrrr']   # barrel
D['deco_t'] = ['bbbyybbb', 'bbyyyybb', 'bbyyyybb', 'bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb']   # lamp
D['deco_m'] = ['bbbrrbbb'] * 8
D['deco_b'] = ['bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb', 'bbrrrrbb', 'brrrrrrb', 'yryryryr', 'rrrrrrrr']
D['deco2'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bybbbybb', 'yryyyryy', 'yryyyryy', 'yryryryr']   # rail
D['plat'] = recolour(BASE['plank'], {})
D['plat_post'] = recolour(BASE['plank_post'], {})
D['stalk'] = ['bbbrrbbb'] * 8
D['haz'] = ['bbbbbbbb', 'bgbbbbgb', 'gbgbbgbg', 'bbbgbbbb', 'gbbbbbgb', 'bgbbgbbb', 'bbbgbbbg', 'gbbbbbbb']   # flood water
D['haz2'] = ['bbbbbbbb', 'bbbbgbbb', 'bbbgbgbb', 'gbbbbbbg', 'bbgbbbbb', 'bbbbbgbb', 'gbbbbbbb', 'bbbgbbbg']
D['spike'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'byrybyry', 'yrryyrry', 'rrrrrrrr', 'yryryryr', 'rrrrrrrr']   # broken glass
D['roof_l'] = BASE['roof_l']; D['roof_m'] = BASE['roof_m']; D['roof_r'] = BASE['roof_r']
D['door_t'] = ['ryyyyyyr', 'rybbbbyr', 'rybbbbyr', 'rybyybyr', 'rybyybyr', 'rybbbbyr', 'rybbbbyr', 'ryyyyyyr']   # lit window
D['door_b'] = BASE['door_b']
D['pillar'] = D['block']; D['column'] = D['deco_m']
theme(3, name='THE DROWNED VILLAGE', css=0, amb=1, tiles=D, stars=0.30,
      card='MIND THE WATER. IT BITES.', boss='LEVIATHAN RISES!')

# ---------------- 4: THE SWAMP OF THE DAMNED --------------------------------
S = {}
S['sky'] = ['bbbbbbbb'] * 8
S['star1'] = BASE['star1']; S['star2'] = BASE['star2']
S['back_t'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbgbbbbb', 'bggbbgbb', 'gggbgggb', 'ggggggbg', 'gbgggggg']
S['back_m'] = ['ggbggggg', 'gggggbgg', 'bgggggg'+'g', 'gggbgggg', 'gggggggb', 'gbgggggg', 'ggggbggg', 'gggggggg']
S['top'] = ['grgrgrgg', 'rgrgrgrr', 'rrrrrrrr', 'rgrrrgrr', 'rrrrrrrr', 'rrgrrrrr', 'rrrrrgrr', 'grrrrrrr']   # mud
S['top_l'] = S['top']; S['top_r'] = S['top']
S['fill'] = ['rrrrrrrr', 'rrgrrrrr', 'rrrrrgrr', 'grrrrrrr', 'rrrrrrrr', 'rrrgrrrg', 'rrrrrrrr', 'rgrrrrrr']
S['fill2'] = ['rrrrrrrr', 'rryyrrrr', 'ryrryrrr', 'rryyrrgr', 'rrrrrrrr', 'rrrgrrrg', 'rrrrrrrr', 'rgrrrrrr']   # bones
S['fill3'] = S['fill']
S['block'] = recolour(BASE['stone'], {'g': 'g', 'y': 'r', 'b': 'b'})      # mossy ruins
S['block_top'] = recolour(BASE['stone_top'], {'g': 'g', 'y': 'r', 'b': 'b'})
S['sm_t'] = ['bbbggbbb', 'bbggggbb', 'bggyyggb', 'bggggggb', 'ggggggg'+'g', 'gbggggbg', 'gggggggg', 'gggbgggg']   # moss mound
S['sm_b'] = ['gggggggg', 'gbggggbg', 'gggggggg', 'ggggbggg', 'gggggggg', 'bggggggb', 'gggggggg', 'gggggggg']
S['small'] = ['bbbbbbbb', 'bbbbbbbb', 'bbggggbb', 'bggyyggb', 'gggggggg', 'gbggggbg', 'gggggggg', 'gggggggg']
S['deco_t'] = ['bbbbbbbb', 'bbgbbgbb', 'bbbgbgbb', 'gbbgggbb', 'bgbgbbbg', 'bbgggbgb', 'bbbggggb', 'bbbggbbb']   # dead willow
S['deco_m'] = ['bbbggbbb', 'bbbggbbb', 'bgbggbbb', 'bbbggbgb', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb']
S['deco_b'] = ['bbbggbbb', 'bbbggbbb', 'bbggggbb', 'bggggggb', 'ggbggbgg', 'rgrggrgr', 'rrrrrrrr', 'rrrrrrrr']
S['deco2'] = ['bbbbbbbb', 'bbbbbbbb', 'bybbbbyb', 'bgbbbbgb', 'bgbybbgb', 'bgbgbgbg', 'ggggggg'+'g', 'rgrgrgrg']   # reeds
S['plat'] = ['gggggggg', 'grggrggr', 'rrrrrrrr', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']   # lily raft
S['plat_post'] = ['gggggggg', 'grggrggr', 'rrrrrrrr', 'bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb', 'bbbrrbbb']
S['stalk'] = ['bbbrrbbb'] * 8
S['haz'] = T1['bog']; S['haz2'] = T1['bog2']
S['spike'] = ['bbbbbbbb', 'bbbbbbbb', 'bbybbbyb', 'bbybbbyb', 'byyybyyy', 'rrrrrrrr', 'grgrgrgr', 'rrrrrrrr']   # bone spikes
S['roof_l'] = recolour(BASE['roof_l'], {'r': 'g', 'y': 'y', 'g': 'g'})
S['roof_m'] = recolour(BASE['roof_m'], {'r': 'g', 'y': 'y', 'g': 'g'})
S['roof_r'] = recolour(BASE['roof_r'], {'r': 'g', 'y': 'y', 'g': 'g'})
S['door_t'] = BASE['door_t']; S['door_b'] = BASE['door_b']
S['pillar'] = S['block']; S['column'] = S['deco_m']
theme(4, name='THE SWAMP OF THE DAMNED', css=0, amb=1, tiles=S, stars=0.12,
      card='SOMETHING VERY LARGE IS HUNGRY', boss='OLD CROAKER SURFACES!')

# ---------------- 5: THE CRYSTAL DEEPS (colour set 1) -----------------------
# g=buff y=cyan b=magenta r=orange
C = {}
C['sky'] = ['bbbbbbbb'] * 8
C['star1'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbybbbb', 'bbyyybbb', 'bbbybbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']   # glints
C['star2'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbybb', 'bbbbbbbb', 'bybbbbbb', 'bbbbbbbb']
C['back_t'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbybb', 'bbbbbybb', 'bbybyyyb', 'bbybyyyb', 'byyyyyyb', 'byyyyyyy']   # crystal spires
C['back_m'] = ['yyyyyyyy', 'yyybyyyy', 'ybyyyyby', 'yyyyyyyy', 'yyyyybyy', 'byyyyyyy', 'yyyybyyy', 'yyyyyyyy']
C['top'] = ['yyyyyyyy', 'rryrrryr', 'rrrrrrrr', 'rrrgrrrr', 'rrrrrrrr', 'rrrrrrgr', 'rgrrrrrr', 'rrrrrrrr']
C['top_l'] = C['top']; C['top_r'] = C['top']
C['fill'] = ['rrrrrrrr', 'rrrgrrrr', 'rrrrrrrr', 'rrrrrrgr', 'rgrrrrrr', 'rrrrrrrr', 'rrrrgrrr', 'rrrrrrrr']
C['fill2'] = ['rrrrrrrr', 'rrryrrrr', 'rryyyrrr', 'rrryrrgr', 'rgrrrrrr', 'rrrrrrrr', 'rrrrgrrr', 'rrrrrrrr']   # gem
C['fill3'] = C['fill']
C['block'] = ['ggggggrg', 'gyyyygrg', 'gyggggrg', 'gggggggg', 'rrgrrrrr', 'ggggrggg', 'yggggrgy', 'ggggggrg']
C['block_top'] = ['yyyyyyyy', 'gyyyygrg', 'gyggggrg', 'gggggggg', 'rrgrrrrr', 'ggggrggg', 'yggggrgy', 'ggggggrg']
C['sm_t'] = ['bbbybbbb', 'bbyyybbb', 'bbyyybyb', 'byyyyyyb', 'byyyyyyb', 'yyyyyyyy', 'yyygyyyy', 'yyyyyyyy']   # crystal
C['sm_b'] = ['yyyyyyyy', 'yygyyyyy', 'yyyyyyyy', 'yyyyygyy', 'yyyyyyyy', 'ryyyyyyr', 'rrrrrrrr', 'rrrrrrrr']
C['small'] = ['bbbbbbbb', 'bbbbybbb', 'bbbyyybb', 'bbyyyyyb', 'byyyyyyb', 'yyyygyyy', 'ryyyyyyr', 'rrrrrrrr']
C['deco_t'] = ['rrrrrrrr', 'brrrrrrb', 'bbrrrrbb', 'bbrrrrbb', 'bbbrrbbb', 'bbbrrbbb', 'bbbbrbbb', 'bbbbbbbb']   # stalactite
C['deco_m'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbybbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']
C['deco_b'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbrbbb', 'bbbrrbbb', 'bbrrrrbb', 'brrrrrrb', 'yyyyyyyy']   # stalagmite
C['deco2'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbyb', 'bbybbyyb', 'byyybyyy', 'yyyyyyyy', 'rrrrrrrr']
C['plat'] = ['yyyyyyyy', 'gyygyygy', 'bbyybbbb', 'bbbybbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']   # crystal ledge
C['plat_post'] = C['plat']
C['stalk'] = ['bbbbbbbb'] * 8
C['haz'] = ['bbbbbbbb', 'bbbbbbbb', 'rgrrrrgr', 'grgrgrrg', 'rrgrrgrr', 'grrrgrrg', 'rrgrrrgr', 'rrrrrrrr']   # lava
C['haz2'] = ['bbbbbbbb', 'bbbgbbbb', 'rrgrrgrr', 'rgrrgrrg', 'grrgrrgr', 'rrgrrrrg', 'rgrrgrrr', 'rrrrrrrr']
C['spike'] = ['bbbbbbbb', 'bbbbbbbb', 'bybbbybb', 'bybbbybb', 'yyybyyyb', 'yyyyyyyy', 'rrrrrrrr', 'rrrrrrrr']
C['roof_l'] = C['block_top']; C['roof_m'] = C['block_top']; C['roof_r'] = C['block_top']
C['door_t'] = ['gbbbbbbg', 'bbbbbbbb', 'bbbyybbb', 'bbyyyybb', 'bbyyyybb', 'bbbyybbb', 'bbbbbbbb', 'bbbbbbbb']
C['door_b'] = ['bbbbbbbb'] * 7 + ['gbbbbbbg']
C['pillar'] = C['block']; C['column'] = C['deco_m']
theme(5, name='THE CRYSTAL DEEPS', css=0x10, amb=0, tiles=C, stars=0.15,
      card='EVERYTHING GLITTERS. SOME OF IT BITES.', boss='THE PRISM GOLEM WAKES!')

# ---------------- 6: THE DEMON CASTLE ---------------------------------------
K = {}
K['sky'] = ['rbrrrbrr', 'brrrbrrr', 'rrrbrrrb', 'rrbrrrbr', 'rbrrrbrr', 'brrrbrrr', 'rrrbrrrb', 'rrbrrrbr']   # dark brick wall
K['sky'] = ['bbbbbbbb'] * 8
K['star1'] = ['bbbbbbbb', 'bbbrbbbb', 'bbryrbbb', 'bbryrbbb', 'bbryrbbb', 'bbrrrbbb', 'bbbbbbbb', 'bbbbbbbb']   # lit arrow slit
K['star2'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbybb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']
K['back_t'] = ['bbbyybbb', 'bbyrryyb', 'byrrbyrb', 'byrbbyrb', 'byybbyyb', 'byrbbyrb', 'byrrbyrb', 'byyyyyyb']   # stained glass
K['back_m'] = ['byrbbyrb', 'byrrbyrb', 'byybbyyb', 'byrbbyrb', 'byyyyyyb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']
K['top'] = ['yryryryr', 'rrrrrrrr', 'rbrrrbrr', 'rrrrrrrr', 'rrrbrrrb', 'rrrrrrrr', 'rbrrrbrr', 'rrrrrrrr']   # flagstones
K['top_l'] = K['top']; K['top_r'] = K['top']
K['fill'] = ['rrrbrrrb', 'rrrrrrrr', 'rbrrrbrr', 'rrrrrrrr', 'rrrbrrrb', 'rrrrrrrr', 'rbrrrbrr', 'rrrrrrrr']
K['fill2'] = K['fill']; K['fill3'] = K['fill']
K['block'] = BASE['stone']
K['block_top'] = BASE['stone_top']
K['sm_t'] = ['bbbbbbbb', 'bbbbbbbb', 'byyyyyyb', 'bbrrrrbb', 'brryyrrb', 'brrrrrrb', 'bbrrrrbb', 'byyyyyyb']   # urn on a plinth
K['sm_b'] = ['bbyyyybb', 'bbyrryyb', 'bbyrryyb', 'bbyrryyb', 'bbyrryyb', 'bbyrryyb', 'byyyyyyb', 'yyyyyyyy']
K['small'] = ['bbbbbbbb', 'bbbbbbbb', 'yyyyyyyy', 'yrrrrrry', 'yrryyrry', 'yrrrrrry', 'yyyyyyyy', 'gggggggg']   # chest/table
K['deco_t'] = ['bbbyybbb', 'bbyrryyb', 'bbbyybbb', 'bbbrrbbb', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb']   # torch sconce
K['deco_m'] = ['bbbggbbb'] * 8
K['deco_b'] = ['bbbggbbb', 'bbbggbbb', 'bbggggbb', 'bggggggb', 'gggggggg', 'yryryryr', 'rrrrrrrr', 'rrrrrrrr']
K['deco2'] = BASE['fence']
K['plat'] = ['yyyyyyyy', 'gggggggg', 'bgbbbbgb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']   # ledge
K['plat_post'] = ['yyyyyyyy', 'gggggggg', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb', 'bbbggbbb']
K['stalk'] = ['bbbggbbb'] * 8
K['haz'] = ['bbbbbbbb', 'bbbbbbbb', 'bybbbybb', 'bybbbybb', 'yyybyyyb', 'yyyyyyyy', 'gggggggg', 'rgrgrgrg']
K['haz2'] = K['haz']
K['spike'] = K['haz']
K['roof_l'] = BASE['roof_l']; K['roof_m'] = BASE['roof_m']; K['roof_r'] = BASE['roof_r']
K['door_t'] = BASE['door_t']; K['door_b'] = BASE['door_b']
K['pillar'] = BASE['pillar']; K['column'] = BASE['column']
theme(6, name='THE DEMON CASTLE', css=0, amb=1, tiles=K, stars=0.10,
      card='MIND THE GARGOYLES', boss='GARGANTUA DESCENDS!')

# ---------------- 7: MORGRAVE'S CITADEL (colour set 1) ----------------------
M = {}
M['sky'] = ['bbbbbbbb'] * 8
M['star1'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbybbbb', 'bbyryybb', 'bbbybbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']   # magic sparks
M['star2'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbrb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']
M['back_t'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'gggggggg', 'brbrrbrb', 'brbrrbyb', 'brbrrbrb']   # dim bookshelves
M['back_m'] = ['brbrrbyb', 'gggggggg', 'bbrbyrbr', 'bbrbrrbr', 'bbrbrrbr', 'gggggggg', 'brrbbrbr', 'byrbbrbr']
M['top'] = ['yyyyyyyy', 'gygggygg', 'gggggggg', 'ggbggggg', 'gggggbgg', 'gggggggg', 'gbgggggg', 'ggggggbg']
M['top_l'] = M['top']; M['top_r'] = M['top']
M['fill'] = ['gggggggg', 'ggbggggg', 'gggggbgg', 'gggggggg', 'gbgggggg', 'ggggggbg', 'gggggggg', 'gggbgggg']
M['fill2'] = M['fill']; M['fill3'] = M['fill']
M['block'] = ['gggggggg', 'gyyyyyyg', 'gyrrrryg', 'gyryyryg', 'gyrrrryg', 'gyyyyyyg', 'gggggggg', 'bgbgbgbg']   # rune block
M['block_top'] = M['block']
M['sm_t'] = ['bbbbbbbb', 'byyyyyyb', 'yrrrrrry', 'yrryyrry', 'yrrrrrry', 'yyyyyyyy', 'gyggggyg', 'gyggggyg']   # lectern
M['sm_b'] = ['bbbyybbb', 'bbbyybbb', 'bbbyybbb', 'bbbyybbb', 'bbbyybbb', 'bbyyyybb', 'byyyyyyb', 'gggggggg']
M['small'] = ['bbbbbbbb', 'bbbrrbbb', 'bbryyrbb', 'brrrrrrb', 'ryyyyyyr', 'ryrrrryr', 'ryyyyyyr', 'rrrrrrrr']   # cauldron
M['deco_t'] = ['bbbrbbbb', 'bbryrbbb', 'bbbybbbb', 'bbbgbbbb', 'bbbgbbbb', 'bbbgbbbb', 'bbggg'+'bbb', 'bbbgbbbb']   # candle
M['deco_m'] = ['bbbgbbbb'] * 8
M['deco_b'] = ['bbbgbbbb', 'bbbgbbbb', 'bbggg'+'bbb', 'bgggggbb', 'gggggggg', 'yyyyyyyy', 'gggggggg', 'gggggggg']
M['deco2'] = ['bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'rbbrbbbr', 'ryrryrry', 'yrryrryr', 'ryrryrry', 'gggggggg']   # book piles
M['plat'] = ['yyyyyyyy', 'ryrryrry', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb', 'bbbbbbbb']   # floating books
M['plat_post'] = M['plat']
M['stalk'] = ['bbbbbbbb'] * 8
M['haz'] = ['bbbbbbbb', 'bbbbbbbb', 'brbbbrbb', 'rgrbrgrb', 'grgrgrgr', 'rgrgrgrg', 'grgrgrgr', 'rgrgrgrg']   # arcane fire
M['haz2'] = ['bbbbbbbb', 'bbbbrbbb', 'bbbrgrbb', 'brrgrgrb', 'rgrgrgrg', 'grgrgrgr', 'rgrgrgrg', 'grgrgrgr']
M['spike'] = M['haz']
M['roof_l'] = M['block']; M['roof_m'] = M['block']; M['roof_r'] = M['block']
M['door_t'] = ['gbbbbbbg', 'bbbyybbb', 'bbyrryb'+'b', 'byrrrryb', 'byrrrryb', 'bbyrrybb', 'bbbyybbb', 'bbbbbbbb']   # portal
M['door_b'] = ['bbbbbbbb'] * 7 + ['gbbbbbbg']
M['pillar'] = M['block']; M['column'] = ['bgyyyygb', 'bggggggb', 'bgybbygb', 'bgybbygb', 'bgybbygb', 'bgybbygb', 'bggggggb', 'bgyyyygb']
theme(7, name="MORGRAVE'S CITADEL", css=0x10, amb=0, tiles=M, stars=0.12,
      card='THE SORCERER AWAITS', boss='MORGRAVE!')

TILE_ROLES = ['sky', 'star1', 'star2', 'back_t', 'back_m', 'top', 'top_l', 'top_r', 'fill', 'fill2', 'fill3',
              'block', 'block_top', 'sm_t', 'sm_b', 'small', 'deco_t', 'deco_m', 'deco_b', 'deco2', 'plat',
              'plat_post', 'stalk', 'haz', 'haz2', 'spike', 'roof_l', 'roof_m', 'roof_r', 'door_t', 'door_b',
              'pillar', 'column']
SOLID = {'top', 'top_l', 'top_r', 'fill', 'fill2', 'fill3', 'block', 'block_top', 'sm_t', 'sm_b', 'small',
         'roof_l', 'roof_m', 'roof_r', 'pillar'}
ONEWAY = {'plat', 'plat_post'}
HAZARD = {'haz', 'haz2', 'spike'}

# ------------------------------------------------------------------ creatures
# roles: walker (rises from the ground, 12 wide, 14 tall), tough (16 tall: loses
# its head on the first hit), flyer, floater, diver, spitter, mini (mini-boss)
CREATURES = {}
def creatures(n, **kw):
    CREATURES[n] = kw

# --- 2 Witchwood
mush = ['...rrrrrr...', '..ryyrryyr..', '.rrrrrrrrrr.', '.ryyrrrryyr.', '...yyyyyy...', '...ybyyby...',
        '...yyyyyy...', '..g.yyyy.g..', '..g.yyyy.g..', '....yyyy....', '....y..y....', '....y..y....', '...gg..gg...', '............']
scare = ['....rrrr....', '...rryyrr...', '...rbrrbr...', '...rrrrrr...', '....rbbr....', '.....gg.....',
         'yyyyrrrryyyy', '...yrrrry...', '...yrrrry...', '....rrrr....', '....gggg....', '.....gg.....', '.....gg.....', '.....gg.....', '.....gg.....', '....gggg....']
moth = ['y.........y.', 'yy.r..r..yy.', 'yyyyrrrryyy.', '.yyyrbrbyyy.', '..yyrrrryy..', '...y.rr.y...']
wisp = ['....yyyy....', '..yyyyyyyy..', '.yyygyygyyy.', '.yyyyyyyyyy.', '..yyyyyyyy..', '...yyyyyy...', '....yyyy....', '.....yy.....', '......y.....', '............']
owl = ['.rr....rr.', '.rrrrrrrr.', 'rryyrryyrr', 'rybyrrybyr', 'rryyrryyrr', '.rrrryrrr.', '..rrrrrr..', '..y.rr.y..']
snap = ['.rrr..rrr.', 'rgggrrgggr', 'r.y.yy.y.r', 'rgggrrgggr', '.rrr..rrr.', '....gg....', '.gggg.....', '..gg.gg...', '....gg....', '..gggg....']
witch = ['.....rr.....', '....rrrr....', '...rrrrrr...', '.rrrrrrrrrr.', '...ygyyg....', '...yyyyy....', '..rrrrrrr...',
         'yyyyyyyyyyyy', '..rrrrrrr...', '...rr..rr...']
creatures(2,
    walker=('TOADSTOOL TRUDGER', 'LIFTS ITS CAP TO SAY HELLO', [mush, legs(mush, ['...y....y...', '..gg....gg..', '............'])]),
    tough=('SCARECROW', 'KNOCK HIS PUMPKIN OFF', [scare, legs(scare, ['....gggg....', '...gg..gg...', '..gg....gg..', '.ggg....ggg.', '............'])]),
    flyer=('FANG MOTH', 'DRAWN TO SHINY ARMOUR', [moth, mirror_wings(moth)]),
    floater=('WITCH-WISP', 'LURES KNIGHTS OFF PATHS', [wisp, bob(wisp)]),
    diver=('HOOT OWL', 'WHO? YOU.', [owl, ['r........r', 'rr.rrrr.rr', 'rryyrryyrr', 'rybyrrybyr', '.ryyrryyr.', '..rrryrr..', '...rrrr...', '...y..y...']]),
    spitter=('SNAPVINE', 'HUNGRY FROM THE ROOTS UP', [snap, ['..rrrrrr..', '.r......r.', 'rgggggggg' + 'r', '.rrrrrrrr.', '..rrrrrr..', '....gg....', '.gggg.....', '..gg.gg...', '....gg....', '..gggg....']]),
    mini=('GRANNY GRIMWEED', 'WITCH OF THE WOOD', [witch, bob(witch)]),
    head=['.rrrr...', 'rryyrr..', 'rbrrbr..', 'rrrrrr..', '.rbbr...', '........'])

# --- 3 Drowned Village
sailor = ['....ggg.....', '...ggggg....', '...gbggb....', '...ggggg....', '....gyg.....', '..yyyyyyy...', '.gyyyyyyyg..',
          '.g.yyyyy.g..', '...rrrrr....', '...yyyyy....', '...yy.yy....', '...gg.gg....', '..ggg.ggg...', '............']
pirate = ['...rrrrrr...', '..rryyyyrr..', '....yyyy....', '...yybybyy..', '....yyyy....', '.....yy.....',
          '..rrryyrrr..', '..y.ryyr.y..', '..y.ryyr.y..', '....rrrr....', '....yyyy....', '....y..y....', '....y..y....', '....y..y....', '....r..r....', '...rr..rr...']
gull = ['............', 'yy...yy...yy', '.yyy.yyyyyy.', '..yyyyrbyyy.', '...yyyyy.r..', '....y.y.....']
lantern = ['....rrrr....', '...ryyyyr...', '...rybbyr...', '...ryyyyr...', '...rybbyr...', '...ryyyyr...', '....rrrr....', '.....yy.....', '....y..y....', '............']
crow2 = ['r......r', 'rr.rr.rr', '.rryrrr.', '..rrr...', '...rr...', '........']
spout = ['..gggggg..', '.ggyggygg.', '.gbggggbg.', '.gggrrggg.', '..grrrrg..', '...gggg...', '..gggggg..', '.gggggggg.', 'gggggggggg', 'gggggggggg']
seahag = ['....gggg....', '..gggggggg..', '.ggyggggyg..', '.gggggggg...', '..grrrrg....', 'g.gggggg.g..', 'gggggggggg..',
          '..gggggg....', '..g.gg.g....', '.yy....yy...']
creatures(3,
    walker=('DROWNED SAILOR', 'STILL LOOKING FOR HIS SHIP', [sailor, legs(sailor, ['...yy..yy...', '..gg....gg..', '............'])]),
    tough=('PIRATE BONES', 'LOSES HIS HEAD OVER TREASURE', [pirate, legs(pirate, ['...y....y...', '..y......y..', '..y......y..', '.rr......rr.', '............'])]),
    flyer=('GULL GHOUL', 'STEALS CHIPS AND SOULS', [gull, mirror_wings(gull)]),
    floater=('LANTERN GHOST', 'LIGHTS THE WAY TO DOOM', [lantern, bob(lantern)]),
    diver=('STORM CROW', 'RIDES THE THUNDER', [crow2, ['........', '..rrr...', '.rryrrr.', 'rrrrr...', '..rrrr..', '...rr...']]),
    spitter=('GARGOYLE SPOUT', 'SPITS FIRE, NOT WATER', [spout, ['..gggggg..', '.ggyggygg.', '.gbggggbg.', '.grrrrrrg.', '..grrrrg..', '...gggg...', '..gggggg..', '.gggggggg.', 'gggggggggg', 'gggggggggg']]),
    mini=('THE SEA HAG', 'MISTRESS OF THE FLOOD', [seahag, bob(seahag)]),
    head=['.rrrr...', 'ryyyyr..', '.yyyy...', 'yybyby..', '.yyyy...', '........'])

# --- 4 Swamp
lurker = ['............', '....gggg....', '...gggggg...', '..ggyggygg..', '..gggggggg..', '..grrrrrrg..', 'gggggggggggg',
          'g.gggggggg.g', '..gggggggg..', '...gggggg...', '...gg..gg...', '...gg..gg...', '..ggg..ggg..', '............']
golem = ['....rrrr....', '...rrrrrr...', '...ryrryr...', '...rrrrrr...', '....rggr....', '...rrrrrr...',
         '.rrrrrrrrrr.', 'rrr.rrrr.rrr', 'rr..rrrr..rr', '....rrrr....', '...rrrrrr...', '...rr..rr...', '...rr..rr...', '...rr..rr...', '..rrr..rrr..', '............']
mozzie = ['y..........y', '.y..rrr...y.', '..yyrrryyy..', '...rrrrrrrrr', '..r.r..r....', '.r..r..r....']
marsh = ['............', '.....yy.....', '....yyyy....', '...yyggyy...', '...yyggyy...', '....yyyy....', '.....yy.....', '............', '............', '............']
vulture = ['rr.......rr', 'rrr.ggg.rrr', '.rrrgygrrr.', '..rrgggrr..', '....rrr....', '....y.y....']
toad = ['..gg..gg..', '.gyggggyg.', 'gggggggggg', 'grrrrrrrrg', 'gggggggggg', 'g.gggggg.g', '..g....g..', '..........', '..........', '..........']
gator = ['............', '.........gg.', 'ggggggggggyg', 'gyygygygyggg', 'gggggggggggg', '..g.....g...', '.gg.....gg..', '............', '............', '............']
creatures(4,
    walker=('BOG LURKER', 'RISES FROM THE MUCK', [lurker, legs(lurker, ['...gg..gg...', '..gg....gg..', '............'])]),
    tough=('MUD GOLEM', 'HIS HEAD COMES OFF EASY', [golem, legs(golem, ['...rr..rr...', '..rr....rr..', '..rr....rr..', '.rrr....rrr.', '............'])]),
    flyer=('MEGA MOSQUITO', 'THIRSTY FOR KNIGHTS', [mozzie, mirror_wings(mozzie)]),
    floater=('MARSH LIGHT', 'FOLLOW IT. GO ON.', [marsh, bob(marsh)]),
    diver=('BOG VULTURE', 'PATIENT. VERY PATIENT.', [[r + '.' for r in vulture], [r + '.' for r in vulture[::-1]]]),
    spitter=('SPITTING TOAD', 'SPITS BURNING SLIME', [toad, ['..gg..gg..', '.gyggggyg.', 'grrrrrrrrg', 'g........g', 'gggggggggg', 'g.gggggg.g', '..g....g..', '..........', '..........', '..........']]),
    mini=('SNAPJAW', 'THE GATOR GUARDIAN', [gator, bob(gator)]),
    head=['.rrrr...', 'rrrrrr..', 'ryrryr..', 'rrrrrr..', '.rggr...', '........'])

# --- 5 Crystal Deeps (g buff y cyan b magenta r orange)
crawler = ['............', '............', '.....y......', '....yyy.....', '...yyyyy....', '..yygyygy...', '.yyyyyyyyy..',
           'yyyyyyyyyyy.', 'yrryrryrryy.', '.r.r.r.r.r..', '............', '............', '............', '............']
gemk = ['....yyyy....', '...yyyyyy...', '...ybyyby...', '...yyyyyy...', '....yrry....', '.....gg.....',
        '..gggggggg..', '.yg.gyyg.gy.', '.yg.gyyg.gy.', '....gggg....', '....gyyg....', '....g..g....', '....g..g....', '....g..g....', '....y..y....', '...yy..yy...']
cbat = ['r..........r', 'rr..rrr...rr', 'rrrrryrrrrr.', '.rrrrrrrrr..', '...r...r....', '............']
shade = ['....gggg....', '...gggggg...', '..ggbggbgg..', '..gggggggg..', '..gggggggg..', '..gggbbggg..', '..gggggggg..', '..gg.gg.gg..', '..g..g..g...', '............']
shard = ['...y....', '..yyy...', '.yyyyy..', 'yyygyyy.', '.yyyyy..', '..yyy...']
eye = ['..yyyyyy..', '.yyggggyy.', 'yyggrrggyy', 'yygrbbrgyy', 'yyggrrggyy', '.yyggggyy.', '..yyyyyy..', '...yyyy...', '..yyyyyy..', '.yyyyyyyy.']
glim = ['.y........y.', '.yy.yyyy.yy.', '..yyyggyyy..', 'y.yyyyyyyy.y', 'yy.yyyyyy.yy', 'yyyyyryyyyyy', '.yyyyyyyyyy.', '...yyyyyy...', '...y....y...', '..gg....gg..']
creatures(5,
    walker=('CRYSTAL CRAWLER', 'GROWS FROM THE ROCK', [crawler, ['............', '............', '.....y......', '....yyy.....', '...yyyyy....', '..yygyygy...', '.yyyyyyyyy..', 'yyyyyyyyyyy.', 'yrryrryrryy.', 'r.r.r.r.r.r.', '............', '............', '............', '............']]),
    tough=('GEM KNIGHT', 'HIS HELM IS THE PRIZE', [gemk, legs(gemk, ['....g..g....', '...g....g...', '..g......g..', '.yy......yy.', '............'])]),
    flyer=('CAVE BAT', 'HATES THE LIGHT', [cbat, ['............', '....rrr.....', '..rrryrrr...', '.rrrrrrrrr..', 'rr.r...r.rr.', 'r.........r.']]),
    floater=('SHADE', 'WHAT THE CRYSTALS REFLECT', [shade, bob(shade)]),
    diver=('SHARD SPRITE', 'SHARP. VERY SHARP.', [shard, ['..y.....', '.yyy....', 'yyyyy...', '.yyyyy..', '..yyy...', '...y....']]),
    spitter=('CRYSTAL EYE', 'WATCHES. FIRES.', [eye, ['..yyyyyy..', '.yyggggyy.', 'yygrrrrgyy', 'yyrrbbrryy', 'yygrrrrgyy', '.yyggggyy.', '..yyyyyy..', '...yyyy...', '..yyyyyy..', '.yyyyyyyy.']]),
    mini=('GLIMMER IMP', 'GUARDIAN OF THE DEEP', [glim, bob(glim)]),
    head=['.yyyy...', 'yyyyyy..', 'ybyyby..', 'yyyyyy..', '.yrry...', '........'])

# --- 6 Demon Castle
ghoul = ['....ggg.....', '...ggggg....', '...grggr....', '...ggggg....', '....gbg.....', '..yyyyyyy...', '.gyyryyyyg..',
         '.g.yyyyy.g..', '...yyyyy....', '...rrrrr....', '...yy.yy....', '...gg.gg....', '..ggg.ggg...', '............']
armour = ['....yyyy....', '...yyyyyy...', '...ybbbby...', '...yyyyyy...', '....yrry....', '.....yy.....',
          '..yyyyyyyy..', '.yy.yggy.yy.', '.yy.yggy.yy.', '....yyyy....', '....yggy....', '....y..y....', '....y..y....', '....y..y....', '....g..g....', '...gg..gg...']
gbat = ['g..........g', 'gg..ggg...gg', 'ggggrgrgggg.', '.ggggggggg..', '...g...g....', '............']
bride = ['....yyyy....', '...yyyyyy...', '..yybyybyy..', '..yyyyyyyy..', '..yyrrrryy..', '..yyyyyyyy..', '.yyyyyyyyyy.', '.yyyyyyyyyy.', 'yyyyyyyyyyyy', 'y.yy.yy.yy.y']
garg = ['g......g', 'gg.gg.gg', '.ggrggg.', '..ggg...', '...gg...', '........']
wall = ['gggggggggg', 'gyggggggyg', 'gbbggggbbg', 'gggggggggg', 'ggggrrgggg', 'ggrrrrrrgg', 'gggrrrrggg', 'gggggggggg', 'gyggggggyg', 'gggggggggg']
redg = ['.r........r.', '.rr.rrrr.rr.', '..rrryyrrr..', 'r.rrrrrrrr.r', 'rr.rrrrrr.rr', 'rrrrryrrrrrr', '.rrrrrrrrrr.', '...rrrrrr...', '...r....r...', '..yy....yy..']
creatures(6,
    walker=('GHOUL GUARD', 'NEVER OFF DUTY', [ghoul, legs(ghoul, ['...yy..yy...', '..gg....gg..', '............'])]),
    tough=('LIVING ARMOUR', 'NOBODY HOME UNDER THE HELM', [armour, legs(armour, ['....y..y....', '...y....y...', '..y......y..', '.gg......gg.', '............'])]),
    flyer=('GARGOYLE BAT', 'STONE WINGS, SHARP TEETH', [gbat, ['............', '....ggg.....', '..gggrggg...', '.ggggggggg..', 'gg.g...g.gg.', 'g.........g.']]),
    floater=('PHANTOM BRIDE', 'STILL WAITING AT THE ALTAR', [bride, bob(bride)]),
    diver=('STONE GARGOYLE', 'COMES ALIVE AT NIGHT', [garg, ['........', '..ggg...', '.ggrggg.', 'ggggg...', '..gggg..', '...gg...']]),
    spitter=('WALL FACE', 'THE WALLS HAVE MOUTHS', [wall, ['gggggggggg', 'gyggggggyg', 'gbbggggbbg', 'gggggggggg', 'ggrrrrrrgg', 'grrrrrrrrg', 'ggrrrrrrgg', 'gggggggggg', 'gyggggggyg', 'gggggggggg']]),
    mini=('THE RED GARGOYLE', 'LORD OF THE BATTLEMENTS', [redg, bob(redg)]),
    head=['.yyyy...', 'yyyyyy..', 'ybbbby..', 'yyyyyy..', '.yrry...', '........'])

# --- 7 Citadel (g buff y cyan b magenta r orange)
tome = ['............', '..rrrrrrrr..', '..ryyyyyyr..', '..ryrrrryr..', '..ryyyyyyr..', '..ryrrrryr..', '..ryyyyyyr..',
        '..rrrrrrrr..', '...gbggbg...', '...gggggg...', '...gg..gg...', '...gg..gg...', '..ggg..ggg..', '............']
mage = ['.....yy.....', '....yyyy....', '...yyyyyy...', '..yyyyyyyy..', '...gbggbg...', '...gggggg...',
        '..yyyyyyyy..', '.yyyyyyyyyy.', 'g.yyyyyyyy.g', '..yyyyyyyy..', '..yyyyyyyy..', '...yyyyyy...', '...g....g...', '...g....g...', '...g....g...', '..gg....gg..']
ftome = ['r..........r', 'rr.rrrrrr.rr', 'ryyyyyyyyyyr', '.rryrrrryrr.', '..rrrrrrrr..', '............']
spirit = ['....yyyy....', '...yyyyyy...', '..yyryyryy..', '..yyyyyyyy..', '...yyyyyy...', '....yyyy....', '...yyyyyy...', '..yy.yy.yy..', '..y..y..y...', '............']
raven = ['b......b', 'bb.bb.bb', '.bbrbbb.', '..bbb...', '...bb...', '........']
mirror = ['..yyyyyy..', '.yrrrrrry.', 'yrbbbbbbry', 'yrbgbbgbry', 'yrbbbbbbry', 'yrbbrrbbry', 'yrbbbbbbry', '.yrrrrrry.', '..yyyyyy..', '...yyyy...']
famil = ['.b........b.', '.bb.bbbb.bb.', '..bbbrrbbb..', 'b.bbbbbbbb.b', 'bb.bbbbbb.bb', 'bbbbbybbbbbb', '.bbbbbbbbbb.', '...bbbbbb...', '...b....b...', '..yy....yy..']
creatures(7,
    walker=('SHAMBLING TOME', 'A REAL PAGE-TURNER', [tome, legs(tome, ['...gg..gg...', '..gg....gg..', '............'])]),
    tough=('SKELETON MAGE', 'HIS HAT IS HIS HEAD', [mage, legs(mage, ['...g....g...', '..g......g..', '..g......g..', '.gg......gg.', '............'])]),
    flyer=('FLYING TOME', 'FORBIDDEN AND FLAPPING', [ftome, mirror_wings(ftome)]),
    floater=('BOUND SPIRIT', 'TRAPPED IN THE LIBRARY', [spirit, bob(spirit)]),
    diver=("MORGRAVE'S RAVEN", 'SPIES FOR ITS MASTER', [raven, ['........', '..bbb...', '.bbrbbb.', 'bbbbb...', '..bbbb..', '...bb...']]),
    spitter=('MAGIC MIRROR', 'SHOWS YOU YOUR DOOM', [mirror, ['..yyyyyy..', '.yrrrrrry.', 'yrrrrrrrry', 'yrryyyyrry', 'yrrrrrrrry', 'yrryyyyrry', 'yrrrrrrrry', '.yrrrrrry.', '..yyyyyy..', '...yyyy...']]),
    mini=('THE FAMILIAR', "MORGRAVE'S PET", [famil, bob(famil)]),
    head=['..yy....', '.yyyy...', 'yyyyyy..', '.gbgb...', '.gggg...', '........'])

# ------------------------------------------------------------------ bosses
# each boss: a 32x20 top and a 32x8 jaw (the part that opens), plus params
BOSSES = {}
BOSSES[2] = dict(  # THE HUNGRY OAK
 top=[
 '......rr..r..rr...r..rr.........',
 '...r..rrr.rr.rrr.rr.rrr..r......',
 '..rrr.rrrrrrrrrrrrrrrrrrrrr.....',
 '.rrrrrrrrgrrrrrrrrrrgrrrrrrr....',
 '..rrrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '...rrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '..rrrrrrrrrrrrrrrrrrrrrrrrrrrr..',
 '..rrrrrbbbbbrrrrrrrbbbbbrrrrrr..',
 '.rrrrrbbbbbbbrrrrrbbbbbbbrrrrrr.',
 '.rrrrrbbbyybbrrrrrbbyybbbrrrrrr.',
 '.rrrrrbbyyyybrrrrrbyyyybbrrrrrr.',
 '.rrrrrbbbyybbrrrrrbbyybbbrrrrrr.',
 '.rrrrrrbbbbbrrrgrrrbbbbbrrrrrrr.',
 '..rrrrrrrrrrrrrrrrrrrrrrrrrrrr..',
 '..rrrgrrrrrrrrrrrrrrrrrrrgrrrr..',
 '...rrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '...rrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '....yyyyyyyyyyyyyyyyyyyyyyyy....',
 '....yrrryrrryrrryrrryrrryrry....',
 '.....y...y...y...y...y...y......'],
 jaw=[
 '.....y...y...y...y...y...y......',
 '....yrrryrrryrrryrrryrrryrry....',
 '....yyyyyyyyyyyyyyyyyyyyyyyy....',
 '...rrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '..rrgrrrrrrrrrrrrrrrrrrrrrgrr...',
 '..rrrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '.rr.rr..rrr..rrrr..rrr..rr.rr...',
 '.r...r...r....rr....r...r...r...'],
 hp=(16, 22, 30), summon='flyer', speed=0, volley=3)
BOSSES[3] = dict(  # LEVIATHAN
 top=[
 '..........gg........gg..........',
 '.........gggg......gggg.........',
 '........gggggg....gggggg........',
 '......gggggggggggggggggggg......',
 '....gggggggggggggggggggggggg....',
 '...ggggyyyggggggggggggyyygggg...',
 '..ggggyrrryggggggggggyrrryggggg.',
 '..gggyrrbrryggggggggyrrbrryggggg',
 '..gggyrrbrryggggggggyrrbrryggggg',
 '..ggggyrrryggggggggggyrrryggggg.',
 '..gggggyyyggggggggggggyyyggggg..',
 '..gggggggggggggbbgggggggggggggg.',
 '..ggggbggggggggbbggggggggbggggg.',
 '...ggggggggggggggggggggggggggg..',
 '...gbgggggbgggggggbgggggbggggg..',
 '....ggggggggggggggggggggggggg...',
 '.....gggggggggggggggggggggggg...',
 '.....yyyyyyyyyyyyyyyyyyyyyyy....',
 '.....y.y.y.y.y.y.y.y.y.y.y.y....',
 '......y...y...y...y...y...y.....'],
 jaw=[
 '......y...y...y...y...y...y.....',
 '.....y.y.y.y.y.y.y.y.y.y.y.y....',
 '.....yyyyyyyyyyyyyyyyyyyyyyy....',
 '.....gggggggggggggggggggggggg...',
 '......gggbggggggggggggbgggggg...',
 '.......gggggggggggggggggggg.....',
 '.........gggggggggggggggg.......',
 '...........gggggggggggg.........'],
 hp=(18, 24, 32), summon='flyer', speed=1, volley=3)
BOSSES[4] = dict(  # OLD CROAKER
 top=[
 '.......gggg..........gggg.......',
 '.....gggggggg......gggggggg.....',
 '....ggyyyyyygg....ggyyyyyygg....',
 '....gyyrrrryyg....gyyrrrryyg....',
 '....gyrrbbrryg....gyrrbbrryg....',
 '....gyrrbbrryg....gyrrbbrryg....',
 '....gyyrrrryygggggggyyrrrryyg...',
 '...gggyyyyyyggggggggggyyyyyyggg.',
 '..ggggggggggggggggggggggggggggg.',
 '.ggggggggggggggggggggggggggggggg',
 '.gggbgggggggggggggggggggggbggggg',
 '.ggggggggggrggggggggrggggggggggg',
 '.gggggggggggggggggggggggggggggg.',
 '..ggggbggggggggggggggggggbgggg..',
 '..gggggggggggggggggggggggggggg..',
 '...gggggggggggggggggggggggggg...',
 '...rrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '...rrrrrrrrrrrrrrrrrrrrrrrrrr...',
 '...yrrrrrrrrrrrrrrrrrrrrrrrry...',
 '....yyyyyyyyyyyyyyyyyyyyyyyy....'],
 jaw=[
 '....yyyyyyyyyyyyyyyyyyyyyyyy....',
 '...gggggggggggggggggggggggggg...',
 '..gggggbggggggggggggggbgggggg...',
 '..gggggggggggggggggggggggggggg..',
 '...gggggggggggggggggggggggggg...',
 '....gggggggggggggggggggggggg....',
 '.....gg.gg.........gg.gg........',
 '....gg...gg.......gg...gg.......'],
 hp=(18, 26, 34), summon='flyer', speed=0, volley=5)
BOSSES[5] = dict(  # THE PRISM GOLEM (colour set 1)
 top=[
 '...........y......y.............',
 '..........yyy....yyy............',
 '.........yyyyy..yyyyy...........',
 '......gggggggggggggggggggg......',
 '....gggggggggggggggggggggggg....',
 '...ggyyyggggggggggggggggyyygg...',
 '..ggggggggggggggggggggggggggg...',
 '..gggrrrrrrggggggggrrrrrrgggg...',
 '..ggrrbbbbrrggggggrrbbbbrrggg...',
 '..ggrbbyybbrggggggrbbyybbrggg...',
 '..ggrrbbbbrrggggggrrbbbbrrggg...',
 '..gggrrrrrrggggggggrrrrrrgggg...',
 '..gggggggggggyyggggggggggggg....',
 '..ggyyggggggyyyyggggggggyygg....',
 '...gggggggggggggggggggggggg.....',
 '...ggggyggggggggggggggyggggg....',
 '....gggggggggggggggggggggggg....',
 '....rrrrrrrrrrrrrrrrrrrrrrrr....',
 '....r.yy.r.yy.r.yy.r.yy.r.yy....',
 '......yy...yy...yy...yy...yy....'],
 jaw=[
 '......yy...yy...yy...yy...yy....',
 '....r.yy.r.yy.r.yy.r.yy.r.yy....',
 '....rrrrrrrrrrrrrrrrrrrrrrrr....',
 '....gggggggggggggggggggggggg....',
 '....ggyyggggggggggggggggyygg....',
 '.....gggggggggggggggggggggg.....',
 '......gggg..gggggggg..gggg......',
 '.......gg....gggggg....gg.......'],
 hp=(20, 28, 36), summon='flyer', speed=1, volley=5)
BOSSES[6] = dict(  # GARGANTUA, KING OF GARGOYLES
 top=[
 'g..............................g',
 'gg...........gggggg...........gg',
 'ggg........gggggggggg........ggg',
 '.ggg.....gggggggggggggg.....ggg.',
 '..gggg..gggggggggggggggg..gggg..',
 '...gggggggggggggggggggggggggg...',
 '....gggrrrrggggggggggrrrrggg....',
 '....ggrryyrrggggggggrryyrrgg....',
 '...gggrybbyrggggggggrybbyrggg...',
 '...gggrryyrrggggggggrryyrrggg...',
 '...ggggrrrrggggbbggggrrrrgggg...',
 '...ggggggggggggbbgggggggggggg...',
 '...gggbgggggggbbbbgggggggbggg...',
 '....gggggggggggggggggggggggg....',
 '....ggggbgggggggggggggggbggg....',
 '.....gggggggggggggggggggggg.....',
 '.....yyyyyyyyyyyyyyyyyyyyyy.....',
 '.....yy..yy..yy..yy..yy..yy.....',
 '.....y....y...y..y...y....y.....',
 '................................'],
 jaw=[
 '.....y....y...y..y...y....y.....',
 '.....yy..yy..yy..yy..yy..yy.....',
 '.....yyyyyyyyyyyyyyyyyyyyyy.....',
 '.....gggggggggggggggggggggg.....',
 '......gggbggggggggggggbggg......',
 '.......gggggggggggggggggg.......',
 '.........gggggggggggggg.........',
 '...........gggggggggg...........'],
 hp=(22, 30, 40), summon='diver', speed=1, volley=3)
BOSSES[7] = dict(  # MORGRAVE (colour set 1)
 top=[
 '...............yy...............',
 '..............yyyy..............',
 '.............yyrryy.............',
 '............yyyyyyyy............',
 '...........yyyyyyyyyy...........',
 '.........yyyyyyyyyyyyyy.........',
 '......yyyyyyyyyyyyyyyyyyyy......',
 '...yyyyyyyyyyyyyyyyyyyyyyyyyy...',
 '.........gggggggggggggg.........',
 '........gggggggggggggggg........',
 '.......ggrrrrggggggrrrrgg.......',
 '.......ggrbbrggggggrbbrgg.......',
 '.......ggrrrrggggggrrrrgg.......',
 '.......gggggggggggggggggg.......',
 '.......ggggggggrrgggggggg.......',
 '........gggggggrrggggggg........',
 '........ggggggggggggggggg.......',
 '.........grrrrrrrrrrrrrrg.......',
 '.........rrrrrrrrrrrrrrrr.......',
 '........rrrrrrrrrrrrrrrrrr......'],
 jaw=[
 '........rrrryyyyyyyyyyrrrrr.....',
 '.......rrrrrrrrrrrrrrrrrrrrr....',
 '.......rrrrrrrrrrrrrrrrrrrrr....',
 '........rrrrrrrrrrrrrrrrrrr.....',
 '.........rrrrrrrrrrrrrrrrr......',
 '..........rrrrrrrrrrrrrrr.......',
 '............rrrrrrrrrrr.........',
 '..............rrrrrrr...........'],
 hp=(24, 34, 44), summon='floater', speed=1, volley=5)

# ------------------------------------------------------------------ music
SONGS = {
 2: ('E3 3 G3 3 B3 3 E4 6 D4 3 B3 3 C4 3 B3 3 A3 6 - 3 G3 3 A3 3 B3 3 G3 3 F#3 3 E3 9 - 3 '
     'B3 3 D4 3 F#4 3 B4 6 A4 3 F#4 3 G4 3 F#4 3 E4 6 - 3 D4 3 C4 3 B3 3 A3 3 B3 3 E3 9 - 3',
     'E2 3 - 3 B2 3 - 3 ' * 4 + 'C3 3 - 3 G2 3 - 3 ' * 2 + 'B2 3 - 3 F#2 3 - 3 ' * 2 + 'E2 3 - 3 B2 3 - 3 ' * 4, 3),
 3: ('D4 2 F4 2 A4 2 G4 2 F4 2 E4 2 D4 4 C4 2 D4 2 E4 2 F4 4 E4 2 D4 2 C#4 4 - 2 '
     'D4 2 F4 2 A4 2 D5 4 C5 2 A4 2 Bb4 2 A4 2 G4 2 F4 2 E4 4 D4 6 - 2',
     'D2 4 A2 4 D3 4 A2 4 ' * 2 + 'Bb2 4 F3 4 A2 4 E3 4 ' + 'D2 4 A2 4 G2 4 A2 4 ', 3),
 4: ('A3 4 C4 2 B3 2 A3 4 E3 4 F3 2 G3 2 A3 4 G3 4 - 4 '
     'C4 4 E4 2 D4 2 C4 4 G3 4 A3 2 B3 2 C4 4 B3 4 A3 8 - 4',
     'A2 2 - 2 A2 2 E2 2 ' * 4 + 'F2 2 - 2 F2 2 C3 2 ' * 2 + 'E2 2 - 2 E2 2 B2 2 ' * 2, 3),
 5: ('E5 2 B4 2 G4 2 E4 2 F#4 2 G4 2 B4 4 A4 2 G4 2 F#4 2 D4 2 E4 6 - 2 '
     'G4 2 B4 2 E5 2 G5 4 F#5 2 E5 2 D5 2 B4 2 C5 2 A4 2 B4 6 - 2',
     'E3 2 B3 2 ' * 8 + 'C3 2 G3 2 ' * 4 + 'B2 2 F#3 2 ' * 4, 2),
 6: ('C4 2 Eb4 2 G4 2 C5 4 B4 2 G4 2 Ab4 2 G4 2 F4 2 Eb4 2 D4 4 - 2 '
     'G4 2 B4 2 D5 2 G5 4 F5 2 D5 2 Eb5 2 D5 2 C5 2 B4 2 C5 6 - 2',
     'C2 2 C3 2 ' * 8 + 'Ab2 2 Ab3 2 ' * 4 + 'G2 2 G3 2 ' * 4, 2),
 7: ('B3 2 D4 2 F4 2 Ab4 4 G4 2 F4 2 D4 2 F4 2 Ab4 2 B4 4 C5 4 B4 8 - 2 '
     'D5 2 C5 2 B4 2 Ab4 2 G4 2 F4 2 D4 2 F4 2 E4 2 D4 2 C#4 2 D4 8 - 2',
     'B2 2 F3 2 ' * 4 + 'Ab2 2 D3 2 ' * 4 + 'G2 2 C#3 2 ' * 4 + 'B2 2 F3 2 ' * 4, 2),
}

# ------------------------------------------------------------------ level builder
OT = {'zombie': 1, 'skel': 2, 'bat': 3, 'ghost': 4, 'crow': 5, 'imp': 6, 'plant': 7,
      'chest': 8, 'item': 9, 'checkpt': 10, 'zzone': 11, 'boss': 12, 'torch': 13}
ROLE_TYPE = {'walker': 1, 'tough': 2, 'flyer': 3, 'floater': 4, 'diver': 5, 'spitter': 7, 'mini': 6}
IT = {'coin': 0, 'jewel': 1, 'armour': 2, 'potion': 3, 'lance': 4, 'dagger': 5, 'axe': 6, 'torchw': 7, 'heart': 8}

def build_level(n, W=176):
    th = THEMES[n]
    rnd = random.Random(1000 + n)
    M = [['sky'] * W for _ in range(7)]
    ground = [5] * W
    pit = set()
    objs = []
    def o(c, kind, param=0, y=None):
        if y is None: y = ground[c] * 8
        objs.append((c, y, OT[kind], param))
    def put(c, r, t):
        if 0 <= c < W and 0 <= r < 7: M[r][c] = t
    # --- terrain: sections from a theme-seeded recipe
    c = 12
    sections = ['hill', 'pit', 'struct', 'flat', 'steps', 'pit', 'high', 'hill', 'struct', 'pit', 'flat', 'steps']
    rnd.shuffle(sections)
    sections = ['flat'] + sections
    cps = []
    while c < 150:
        s = sections.pop(0) if sections else rnd.choice(['flat', 'pit', 'hill', 'struct'])
        if s == 'hill':
            ln = rnd.randint(12, 18)
            for x in range(c, c + ln): ground[x] = 4
            for x in range(c + 3, c + ln - 3): ground[x] = 3
            c += ln + 2
        elif s == 'pit':
            ln = rnd.randint(8, 14)
            for x in range(c, c + ln): pit.add(x)
            # stepping platforms with gaps
            x = c + 1
            while x < c + ln - 1:
                pl = rnd.randint(2, 3)
                hy = rnd.choice([3, 4, 4])
                for k in range(pl):
                    if x + k < c + ln: put(x + k, hy, 'plat')
                x += pl + rnd.randint(1, 2)
            c += ln + 2
        elif s == 'struct':
            ln = rnd.randint(8, 11)
            for x in range(c, c + ln):
                put(x, 3, 'block'); put(x, 4, 'block')
                put(x, 2, 'roof_m')
            put(c, 2, 'roof_l'); put(c + ln - 1, 2, 'roof_r')
            mid = c + ln // 2
            put(mid, 3, 'door_t'); put(mid, 4, 'door_b')
            put(c - 1, 4, 'block_top'); put(c - 2, 4, 'small')
            c += ln + 3
        elif s == 'steps':
            for k in range(4):
                for x in range(c + k * 2, c + k * 2 + 2):
                    ground[x] = 5 - min(k, 2)
            c += 10
        elif s == 'high':
            ln = rnd.randint(6, 9)
            for x in range(c, c + ln): put(x, 2, 'plat')
            put(c - 1, 4, 'plat_post')
            c += ln + 2
        else:   # flat
            c += rnd.randint(8, 12)
        if not cps and c > 70: cps.append(c); c += 3
    if len(cps) < 2: cps.append(min(c, 152))
    # ground fill
    for x in range(W):
        if x in pit:
            put(x, 6, 'haz' if x % 2 else 'haz2')
            continue
        g = ground[x]
        for r in range(g, 7):
            if M[r][x] not in ('sky',): continue
            if r == g:
                left = ground[x - 1] if x > 0 and (x - 1) not in pit else 9
                right = ground[x + 1] if x < W - 1 and (x + 1) not in pit else 9
                put(x, r, 'top_l' if left > g else 'top_r' if right > g else 'top')
            else:
                put(x, r, rnd.choice(['fill'] * 6 + ['fill2', 'fill3']))
    # decorations on the ground (avoid pits, structures)
    def free(x, r): return 0 <= x < W and M[r][x] == 'sky'
    for x in range(4, 156):
        if x in pit or (x - 1) in pit or (x + 1) in pit: continue
        g = ground[x]
        roll = rnd.random()
        if roll < 0.07 and free(x, g - 1) and free(x, g - 2) and free(x, g - 3):
            put(x, g - 1, 'deco_b'); put(x, g - 2, 'deco_m'); put(x, max(0, g - 4), 'deco_t')
            if g - 3 >= 0 and free(x, g - 3): put(x, g - 3, 'deco_m')
        elif roll < 0.13 and free(x, g - 1) and free(x, g - 2):
            put(x, g - 1, 'sm_b'); put(x, g - 2, 'sm_t')
        elif roll < 0.18 and free(x, g - 1):
            put(x, g - 1, 'small')
        elif roll < 0.26 and free(x, g - 1):
            put(x, g - 1, 'deco2')
    # spike patches on flat ground
    for _ in range(3):
        x = rnd.randint(20, 140)
        if all(ground[k] == ground[x] and k not in pit and M[ground[x] - 1][k] == 'sky' for k in range(x, x + 3)):
            for k in range(x, x + 3): put(k, ground[k], 'spike')
    # boss arena
    for x in range(158, W):
        ground[x] = 5
        for r in range(0, 5): put(x, r, 'sky')
        put(x, 5, 'top')
        put(x, 6, 'fill')
        if x in pit: pit.discard(x)
    for x in (158, W - 1):
        for r in range(1, 5): put(x, r, 'column')
        put(x, 0, 'roof_m')
    # backdrop band + stars
    hill = [3 if (math.sin(x * 0.19 + n) + math.sin(x * 0.47 + n * 2)) > 0.5 else 4 for x in range(W)]
    for x in range(W):
        for r in range(7):
            if M[r][x] != 'sky': continue
            if r == 4 and ground[x] > 4:
                M[r][x] = 'back_m' if hill[x] == 3 else 'back_t'
            elif r == 3 and hill[x] == 3 and ground[x] > 3:
                M[r][x] = 'back_t'
            elif r <= 2 and rnd.random() < th['stars']:
                M[r][x] = rnd.choice(['star1', 'star2'])
    # --- objects
    cr = CREATURES[n]
    roles_early = ['walker', 'walker', 'flyer', 'tough', 'diver']
    roles_late = ['walker', 'tough', 'flyer', 'floater', 'diver', 'spitter', 'tough', 'floater']
    x = 14
    while x < 152:
        role = rnd.choice(roles_early if x < 60 else roles_late)
        g = ground[x]
        if x in pit:
            role = 'flyer'
        if role in ('walker',):
            o(x, 'zombie')
        elif role == 'tough':
            o(x, 'skel')
        elif role == 'flyer':
            o(x, 'bat', 0, rnd.choice([4, 8, 12]))
        elif role == 'floater':
            o(x, 'ghost', 0, rnd.choice([8, 16]))
        elif role == 'diver':
            o(x, 'crow', 0, max(0, g * 8 - 24))
        elif role == 'spitter':
            if x not in pit: o(x, 'plant', 0, g * 8 - 10 + 10)
        x += rnd.randint(5, 9)
    # zombie zones, mini-boss, items, chests
    o(40, 'zzone', 10); o(110, 'zzone', 12)
    o(124, 'imp', 0, 4)
    weap = ['dagger', 'axe', 'torchw', 'lance']
    for i, xc in enumerate([30, 64, 98, 136]):
        y = ground[xc] * 8 if xc not in pit else 32
        o(xc, 'chest', IT[weap[(n + i) % 4]] if i % 2 == 0 else IT['armour'], y)
    for xc in range(18, 150, 13):
        y = max(4, ground[xc] * 8 - 20) if xc not in pit else 20
        o(xc, 'item', IT[rnd.choice(['coin', 'coin', 'coin', 'jewel', 'potion'])], y)
    o(cps[0] if cps[0] not in pit else cps[0] + 2, 'checkpt')
    o(150, 'checkpt')
    o(154, 'item', IT['heart'], 20)
    o(160, 'boss', 0, 0)
    for (xc, r) in [(30, 1), (90, 1), (159, 0), (174, 0)]:
        o(xc, 'torch', 0, r * 8)
    fixed = []
    for (xc, y, t, p) in objs:
        if t in (OT['checkpt'], OT['chest'], OT['zombie'], OT['skel'], OT['plant']):
            if t in (OT['zombie'], OT['plant']) and xc in pit: continue
            while xc in pit: xc += 1
            y = ground[xc] * 8
        fixed.append((xc, y, t, p))
    objs = sorted(fixed)
    return M, objs

# ------------------------------------------------------------------ emitters
def boss_song(n):
    """copy of the stage 1 boss theme (each pack carries its own), transposed per stage"""
    src = open(os.path.join(os.path.dirname(__file__), '..', 'src', 'gen', 'music_s1.asm')).read().split('\n')
    i = src.index('SONG_BOSS: dw SONG_BOSS_A,SONG_BOSS_B')
    tr = [0, 0, 2, -2, 3, 1, -1, 4][n]
    out = ['SONG_BOSS_%d: dw SONG_BOSS_%d_A,SONG_BOSS_%d_B' % (n, n, n)]
    for l in src[i + 1:]:
        if l.startswith('SONG_BOSS_'):
            out.append(l.replace('SONG_BOSS_', 'SONG_BOSS_%d_' % n)); continue
        if not l.startswith('    db'): break
        bs = [int(x.strip()[1:], 16) for x in l.split('db')[1].split(',')]
        if bs == [0xFF]: out.append(l); continue
        nb = []
        for k, b in enumerate(bs):
            if k % 2 == 0 and b not in (0, 0xFF): b = max(1, min(63, b + tr))
            nb.append(b)
        out.append('    db ' + hexrow(nb))
    return out

def stage_asm(n):
    th = THEMES[n]; cr = CREATURES[n]; bs = BOSSES[n]
    tiles = th['tiles']
    sfx = '_%d' % n
    L = ['; generated by tools/stages.py - stage %d: %s' % (n, th['name'])]
    # header
    roles = ['walker', 'tough', 'flyer', 'floater', 'diver', 'spitter', 'mini']
    sprs = {}
    for role in roles:
        nm, desc, frames = cr[role]
        if role == 'tough':
            hl = [headless(f) for f in frames]
            sprs[role] = frames + hl
        else:
            sprs[role] = frames
    summon = ROLE_TYPE[bs['summon']]
    L.append("        db 'S',%d" % n)
    L.append('        dw MAP%s,%d,OBJ%s,TILES%s,TATTR%s,SONG_ST%s,SONG_BOSS_%d,0,S%d_BTOP_0,S%d_BJAW_0' % (sfx, 176, sfx, sfx, sfx, sfx, n, n, n))
    L.append('        db %d,%d,%d,%d,$%02X,%d' % (bs['hp'][0], bs['hp'][1], bs['hp'][2], summon, th['css'], th['amb']))
    L.append('        dw CARD%s,BNAME%s' % (sfx, sfx))
    for role in roles:
        fr = ['S%d_%s_%d' % (n, role.upper(), i) for i in range(len(sprs[role]))]
        while len(fr) < 4: fr += fr[:4 - len(fr)]
        L.append('        dw ' + ','.join(fr[:4]))
    L.append('        dw S%d_HEAD_0,S%d_MINI_0' % (n, n))
    L.append('        db %d,%d,18' % (bs['speed'], bs['volley']))
    # tiles
    L.append('TILES%s:' % sfx)
    for t in TILE_ROLES:
        rows = tiles[t]
        assert len(rows) == 8 and all(len(r) == 8 for r in rows), (n, t, rows)
        bsx = []
        for r in rows:
            k, d = pack(r); bsx += d
        L.append('    db ' + hexrow(bsx) + '   ; ' + t)
    L.append('TATTR%s:' % sfx)
    L += db_lines([1 if t in SOLID else 2 if t in ONEWAY else 3 if t in HAZARD else 0 for t in TILE_ROLES])
    # sprites
    allspr = {}
    for role in roles:
        allspr[role] = sprs[role]
    allspr['head'] = [cr['head']]
    allspr['btop'] = [bs['top']]
    allspr['bjaw'] = [bs['jaw']]
    L += sprite_lines(allspr, 'S%d_' % n, nop2=('btop', 'bjaw'))
    # level
    M, objs = build_level(n)
    idx = {t: i for i, t in enumerate(TILE_ROLES)}
    L.append('MAP%s:' % sfx)
    for c in range(176):
        L.append('    db ' + hexrow([idx[M[r][c]] for r in range(7)] + [0]))
    L.append('OBJ%s:' % sfx)
    for c, y, t, p in objs:
        L.append('    db %d,%d,%d,%d' % (c, y & 255, t, p))
    L.append('    db $FF')
    # music
    mel, bass, u = SONGS[n]
    for nm, (a, b) in (('ST%s' % sfx, (seq(mel, u), seq(bass, u))),):
        L.append('SONG_%s: dw SONG_%s_A,SONG_%s_B' % (nm, nm, nm))
        for ch, d in (('A', a), ('B', b)):
            L.append('SONG_%s_%s:' % (nm, ch)); L += db_lines(d); L.append('    db $FF')
    L += boss_song(n)
    # text
    L.append('CARD%s:' % sfx)
    L.append('        db 8,0,"STAGE %d",0' % n)
    L.append('        db 16,0,"%s",0' % th['name'])
    L.append('        db 46,2,"%s",0' % th['card'][:32])
    L.append('        db $FF')
    L.append('BNAME%s: db "%s",0' % (sfx, th['boss'][:28]))
    return L, M, objs

def stage1_header():
    return ["; stage 1 header (Gallows Hill content comes from mkassets.py)",
            "        db 'S',1",
            "        dw LEVEL1_MAP,LEVEL1_W,LEVEL1_OBJ,TILES,TATTR,SONG_STAGE1,SONG_BOSS,S_MOON_0,S_BSKULL_0,S_BJAW_0",
            "        db 14,20,28,3,$00,1",
            "        dw CARD_STAGE1,STR_BOSS",
            "        dw S_ZOMBIE_0,S_ZOMBIE_1,S_ZOMBIE_0,S_ZOMBIE_1",
            "        dw S_SKEL_0,S_SKEL_1,S_SKEL_2,S_SKEL_3",
            "        dw S_BAT_0,S_BAT_1,S_BAT_0,S_BAT_1",
            "        dw S_GHOST_0,S_GHOST_1,S_GHOST_0,S_GHOST_1",
            "        dw S_CROW_0,S_CROW_1,S_CROW_0,S_CROW_1",
            "        dw S_PLANT_0,S_PLANT_1,S_PLANT_0,S_PLANT_1",
            "        dw S_IMP_0,S_IMP_1,S_IMP_0,S_IMP_1",
            "        dw S_SKULL_0,S_SKULL_0",
            "        db 0,3,18"]

def main(out):
    open(os.path.join(out, 'stage1_hdr.asm'), 'w').write('\n'.join(stage1_header()) + '\n')
    P = ['; generated: stage packs 2-7']
    previews = {}
    for n in range(2, 8):
        L, M, objs = stage_asm(n)
        open(os.path.join(out, 'stage%d.asm' % n), 'w').write('\n'.join(L) + '\n')
        previews[n] = (M, objs)
    return previews

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else '../src/gen'
    pv = main(out)
    if '--preview' not in sys.argv: sys.exit(0)
    try:
        from PIL import Image
        PALS = {0: {'g': (40, 224, 40), 'y': (240, 240, 80), 'b': (40, 40, 200), 'r': (220, 40, 40)},
                0x10: {'g': (240, 240, 230), 'y': (60, 230, 230), 'b': (210, 50, 210), 'r': (250, 140, 30)}}
        for n, (M, objs) in pv.items():
            th = THEMES[n]; P = PALS[th['css']]
            im = Image.new('RGB', (176 * 8, 56))
            for r in range(7):
                for c in range(176):
                    t = th['tiles'][M[r][c]]
                    for yy in range(8):
                        for xx in range(8): im.putpixel((c * 8 + xx, r * 8 + yy), P[t[yy][xx]])
            im.resize((176 * 8 * 2, 56 * 4), Image.NEAREST).save('/tmp/claude-0/stage%d.png' % n)
            # creature sheet
            cr = CREATURES[n]; bs = BOSSES[n]
            sheet = Image.new('RGB', (440, 300), (30, 30, 30))
            x = 4; y = 4
            def blit(f, x, y, sx=3, sy=4):
                for j, row in enumerate(f):
                    for i, ch in enumerate(row):
                        if ch != '.':
                            for a in range(sx):
                                for b in range(sy): sheet.putpixel((x + i * sx + a, y + j * sy + b), P[ch])
            for role in ['walker', 'tough', 'flyer', 'floater', 'diver', 'spitter', 'mini']:
                for f in cr[role][2]:
                    blit(f, x, y); x += 44
                    if x > 390: x = 4; y += 70
            blit(cr['head'], x, y)
            blit(bs['top'], 4, 210, 2, 3); blit(bs['jaw'], 4, 210 + 60, 2, 3)
            sheet.save('/tmp/claude-0/creatures%d.png' % n)
    except Exception as e:
        print('preview failed', e)
    print('stages ok')
