#!/usr/bin/env python3
# Generates src/gen_data.inc : font, sprites, tiles, mazes, stages, strings, music, sfx
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from font import GLYPHS, CHARS, enc
from gfx import SPR, encode

OUT = []
def out(s=''): OUT.append(s)
def db(label, data, per=16):
    if label: out(label + ':')
    for i in range(0, len(data), per):
        out('        db ' + ','.join('$%02X' % (b & 255) for b in data[i:i + per]))

# ------------------------------------------------------------------ font
fb = []
for c, rows in GLYPHS:
    v = 0
    for r in reversed(rows):
        bits = 0
        for i, p in enumerate(r):
            if p == '#': bits |= 4 >> i
        v = (v << 3) | bits
    fb += [v & 255, v >> 8]
db('font', fb)
out('G_0 equ %d' % CHARS['0'])
out('G_SP equ 0')
for c, name in [('!', 'EXCL'), ('*', 'TIMES'), ('^', 'MAN'), ('@', 'HEART'), ('-', 'DASH'), ('#', 'BLOCK')]:
    out('G_%s equ %d' % (name, CHARS[c]))
for ch in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
    out('G_%s equ %d' % (ch, CHARS[ch]))

# ------------------------------------------------------------------ sprites
for name, rows in SPR.items():
    if name.startswith('T_') or name.startswith('W_'):
        continue
    db('spr_' + name, encode(rows))
# tiles: code order
TILES = ['T_FLOOR', 'T_STAIN', 'T_TRAP1', 'T_TRAP2', 'T_TRAP3', 'T_TRAPC', None, 'T_STINK',
         'T_GUN', 'T_SNEAK', 'T_RECORD', 'T_X2', 'T_COLAND', 'T_DISG', 'T_CAN', 'T_FLOOR',
         'T_LS', 'T_LA', 'T_LU', 'T_LC', 'T_LE', None, None, None,
         'T_CONVU0', 'T_CONVD0', 'T_CONVL0', 'T_CONVR0', 'HZ0', 'HZ1', 'HZ2', 'T_MANHOLE']
SPR['T_TRAPC'] = ['........', 'yyy..yyy', 'yyyyyyyy', 'bbbbbbbb', '.b....b.']
for i, t in enumerate(TILES):
    if t is None: TILES[i] = 'T_FLOOR'
tile_names = sorted(set(t for t in TILES if not t.startswith('HZ')) |
                    {'T_GRILL0', 'T_GRILL1', 'T_GRILL2', 'T_VENT0', 'T_VENT1', 'T_VENT2', 'T_ZAP0', 'T_ZAP1', 'T_ZAP2',
                     'T_CONVU1', 'T_CONVD1', 'T_CONVL1', 'T_CONVR1', 'W_BRICK', 'W_CANS', 'W_LAB',
                     'T_GRASS', 'T_GRASSSH', 'T_CHECK', 'T_CHECKSH', 'T_GRID', 'T_GRIDSH', 'T_PARTY'})
for t in tile_names:
    db('tl_' + t, encode(SPR[t]))
out('tile_src:')
for t in TILES:
    if t.startswith('HZ'):
        out('        dw 0')
    else:
        out('        dw tl_' + t)
out('hz_src:')
for w in ['GRILL', 'VENT', 'ZAP']:
    out('        dw tl_T_%s0,tl_T_%s1,tl_T_%s2' % (w, w, w))
out('conv_src1: dw tl_T_CONVU1,tl_T_CONVD1,tl_T_CONVL1,tl_T_CONVR1')
out('conv_src0: dw tl_T_CONVU0,tl_T_CONVD0,tl_T_CONVL0,tl_T_CONVR0')

# ------------------------------------------------------------------ mazes
# '#' wall '.' floor. Objects: P start, 1-9 spawn points (index), G hazard, M manhole,
# < > ^ v conveyors. Left half only when 8 wide (mirrored).
def mirror_maze(rows):
    res = []
    for r in rows:
        if len(r) == 8:
            mr = r[::-1]
            mr = mr.replace('<', '}').replace('>', '<').replace('}', '>')
            r = r + mr
        assert len(r) == 16, r
        res.append(r)
    assert len(res) == 11
    return res

MAZES = {}
MAZES['yard'] = mirror_maze("""
1.......
.##.###.
.#......
.#.##.##
.....G..
##.#.##.
........
.#.##.##
.#......
.##.###.
.......P""".strip().split('\n'))
MAZES['street'] = mirror_maze("""
1.......
.#.##.#.
.#.#..#.
...G.##.
###.#...
M...#.##
.##.....
.#..#.#.
.#.##...
.#.G..##
...##..P""".strip().split('\n'))
MAZES['market'] = mirror_maze("""
1.......
.######.
....G...
.###.###
M.......
##.##.##
........
.###.###
....G...
.######.
.......P""".strip().split('\n'))
MAZES['dock'] = mirror_maze("""
1.......
.##.#.#.
....#.#.
.##.>>#.
.#..#...
.#.##.##
...#....
##.#.##.
...>>>>.
.#.###.#
.......P""".strip().split('\n'))
MAZES['peel'] = mirror_maze("""
1.......
.#.###.#
.#.G...#
...#.#..
.###.#.#
.....#..
.#.#..G#
.#.#.###
........
.##.##.#
.......P""".strip().split('\n'))
MAZES['vats'] = mirror_maze("""
1.......
.##..##.
.##G.##.
..>>>...
##.##.##
....G...
.#.##.#.
.#....#.
.#.##.#.
..<<<...
.##..##P""".strip().split('\n'))
MAZES['lobby'] = mirror_maze("""
1.......
.#.#.##.
.#.#..G.
.#...##.
M..#.#..
##.#...#
...#.#..
.#...##.
.#.#.>>.
.#.#.##.
.......P""".strip().split('\n'))
MAZES['green'] = mirror_maze("""
1.......
.#.#.#.#
........
.#.#.#.#
...G....
.#.#.#.#
M.......
.#.#.#.#
....G...
.#.#.#.#
.......P""".strip().split('\n'))
MAZES['vault'] = mirror_maze("""
1.......
.######.
.#..G...
.#.####.
.#.#....
...#.##.
.#.#..^.
.#.####.
.#.....M
.######.
.......P""".strip().split('\n'))
MAZES['arena1'] = mirror_maze("""
1.......
........
..##....
..##....
........
........
......##
..##....
..##....
........
.......P""".strip().split('\n'))
MAZES['arena2'] = mirror_maze("""
1.......
........
..#.....
..#..G..
........
........
.....#..
..#.....
..#..G..
........
.......P""".strip().split('\n'))
MAZES['arena3'] = mirror_maze("""
1.......
........
........
........
........
.#....#.
........
...##...
........
.#....#.
.......P""".strip().split('\n'))
MAZES['bonus'] = mirror_maze("""
1.......
........
.##..##.
........
........
...##...
........
........
.##..##.
........
.......P""".strip().split('\n'))

def bfs_check(name, rows):
    cells = [(x, y) for y in range(11) for x in range(16) if rows[y][x] != '#']
    seen = {cells[0]}; st = [cells[0]]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < 16 and 0 <= ny < 11 and rows[ny][nx] != '#' and (nx, ny) not in seen:
                seen.add((nx, ny)); st.append((nx, ny))
    if len(seen) != len(cells):
        raise SystemExit('maze %s not connected (%d/%d)' % (name, len(seen), len(cells)))

maze_order = list(MAZES)
out('maze_tab:')
for n in maze_order:
    out('        dw mz_' + n)
for n in maze_order:
    rows = MAZES[n]
    bfs_check(n, rows)
    data = []
    objs = []
    start = None
    spawns = {}
    for y, r in enumerate(rows):
        bits = 0
        for x, c in enumerate(r):
            bits = (bits << 1) | (1 if c == '#' else 0)
            cell = y * 16 + x
            if c == 'P' and start is None: start = cell
            elif c == 'G': objs += [0x1C, cell]
            elif c == 'M': objs += [0x1F, cell]
            elif c in '^v<>': objs += [{'^': 0x18, 'v': 0x19, '<': 0x1A, '>': 0x1B}[c], cell]
            elif c.isdigit(): spawns[int(c)] = cell
        data += [bits >> 8, bits & 255]
    # mirrored P / spawn: also record right-side spawn (mirror of '1') as spawn 2
    s1 = spawns.get(1, 0)
    sx, sy = s1 % 16, s1 // 16
    sp2 = sy * 16 + (15 - sx)
    # third spawn: centre-ish top/bottom
    db('mz_' + n, data + [start, s1, sp2] + objs + [0xFF])

# ------------------------------------------------------------------ strings
COLS = {'g': 0, 'y': 1, 'b': 2, 'r': 3}
def tstr(s):
    o = []
    i = 0
    while i < len(s):
        ch = s[i]
        if ch == '\n':
            o.append(0xFE); i += 1
        elif ch == '{':
            j = s.index('}', i)
            tag = s[i + 1:j]
            if tag[0] == 'x': o += [0xFB, int(tag[1:])]
            elif tag.startswith('bg'): o += [0xFC, COLS[tag[2]]]
            else: o += [0xFD, COLS[tag]]
            i = j + 1
        else:
            o += enc(ch); i += 1
    return o + [0xFF]

STR = {}
def S(label, text): STR[label] = text

S('s_attack', 'ATTACK OF THE')
S('s_killer', 'KILLER')
S('s_tomatoes', 'TOMATOES')
S('s_resauced', '{r}- RE-SAUCED -')
S('s_pressfire', 'PRESS FIRE')
S('s_hi', 'HI')
S('s_vibed', '{y}BPM 2026')
S('s_after', '{b}AFTER A. IVANKOVIC 1984')

S('s_story1', "{y}SAN DIEGO.\n{g}A QUIET SUMMER EVENING.\n\n{y}SUDDENLY...\n{g}THE SALAD BOWL\n{g}STRIKES BACK!")
S('s_story2', "{y}KILLER TOMATOES ARE\n{y}ROLLING THROUGH TOWN.\n\n{g}THE ARMY IS BAFFLED.\n{g}THE SCIENTISTS ARE\n{g}MOSTLY HIDING.")
S('s_story3', "{y}ONLY ONE MAN STANDS\n{y}IN THEIR WAY:\n\n{g}MASON DIXON\n{g}ARMED WITH A MALLET\n{g}AND SOME HOMEMADE TRAPS.")
S('s_story4', "{y}BUILD TRAPS.\n{y}WAIT FOR A TOMATO\n{y}TO BLUNDER IN...\n\n{g}THEN WHACK IT\n{g}UNTIL IT GOES SPLAT!")

S('s_cast', '{y}THE CAST')
S('s_c1', '{r}CHERRY TOM\n{y}SMALL. ANGRY. 100')
S('s_c2', '{r}ROMA RUNNER\n{y}FAST. CHASES YOU. 200')
S('s_c3', '{r}BIG BEEFSTEAK\n{y}SPLITS IN TWO! 300')
S('s_c4', '{y}UNRIPE GREENIE\n{y}TRAPS DONT WORK. 250')
S('s_c5', '{y}GOLDEN TOMATO\n{y}RARE AND SHY. 2000')
S('s_pow', '{y}FREE STUFF!')
S('s_p1', '{r}KETCHUP GUN {b}STUNS')
S('s_p2', '{r}SNEAKERS {b}SPEED')
S('s_p3', '{r}PUBERTY LOVE {b}THE CURE!')
S('s_p4', '{r}SAUCE BOSS {b}DOUBLE PTS')
S('s_p5', '{r}COLANDER {b}SHIELD')
S('s_p6', '{r}DISGUISE {b}INVISIBLE')
S('s_p7', '{r}SOUP CAN {b}EXTRA LIFE')
S('s_p8', '{r}S-A-U-C-E {b}BONUS')

S('s_hiscores', '{y}HALL OF SAUCE')
S('s_demo', 'DEMO - PRESS FIRE')
S('s_ready', 'GET READY!')
S('s_paused', 'PAUSED\n\nRETURN  RESUME\nS  MUSIC ON/OFF\nR  QUIT TO TITLE')
S('s_gameover', 'GAME OVER')
S('s_gameover2', '{y}THE TOMATOES WIN\n{y}THIS ROUND...')
S('s_continue', '{b}FIRE TO CONTINUE')
S('s_clear', '{y}STAGE CLEAR!')
S('s_tbonus', '{b}TIME BONUS')
S('s_nodmg', '{b}NO DAMAGE')
S('s_perfect', '{y}PERFECT!')
S('s_newhi', "{y}A NEW HIGH SCORE!\n{g}TYPE YOUR INITIALS\n{g}OR JOYSTICK UP/DOWN\n{g}AND FIRE")
S('s_bonus', '{y}BONUS ROUND\n\n{b}SQUASH ALL THE\n{b}SLEEPING TOMATOES!')
S('s_stage', 'STAGE')
S('s_world1', 'WORLD 1\nSAN DIEGO SUBURBS')
S('s_world2', 'WORLD 2\nTHE CANNERY')
S('s_world3', 'WORLD 3\nTOP SECRET LAB')
S('s_lap2', '{y}SECOND HELPING!\n{b}EXTRA SPICY TOMATOES')

# stage names & tips
S('n11', 'THE BACKYARD');      S('t11', 'HOLD FIRE TO BUILD\nA TRAP IN FRONT.')
S('n12', 'MAIN STREET');       S('t12', 'BBQ GRILLS COOK\nTOMATOES. AND YOU.')
S('n13', 'THE SUPERMARKET');   S('t13', 'MANHOLES ARE\nSHORTCUTS.')
S('n14', 'MAMA BEEFSTEAK');    S('t14', 'SHE IS NOT HAPPY.\nTRAP HER, THEN WHACK!')
S('n21', 'LOADING DOCK');      S('t21', 'CONVEYORS PUSH\nEVERYONE ALONG.')
S('n22', 'THE PEELING ROOM');  S('t22', 'STEAM VENTS!\nMIND YOUR TOES.')
S('n23', 'THE SAUCE VATS');    S('t23', 'KETCHUP STUNS\nAND RIPENS GREENIES.')
S('n24', 'BARON VON BEEFSTEAK'); S('t24', 'HE CHARGES IN LINES.\nDODGE INTO A WALL!')
S('n31', 'THE LOBBY');         S('t31', 'THE LAB IS\nFULL OF ZAPPERS.')
S('n32', 'GREENHOUSE OF DOOM'); S('t32', 'THEY GROW THEM\nHERE. LOTS.')
S('n33', 'THE TOMATO VAULT');  S('t33', 'ALMOST THERE.\nKEEP SQUASHING.')
S('n34', 'THE GREAT TOMATO');  S('t34', 'ONLY THE SONG CAN\nHURT IT. FIND IT!')
S('nb', 'TOMATO SMASH');       S('tb', 'WALK OVER THEM!\n15 SECONDS!')

# ticker messages (<=32 chars)
MSGS = [
    ('m_hurry', 'WARNING! TOMATOES ENRAGED!'),
    ('m_giant', 'ALERT: GIANT TOMATO INBOUND!'),
    ('m_gun', 'KETCHUP GUN! PRESS Z TO SHOOT'),
    ('m_gun2', 'DOUBLE KETCHUP! PIERCES!'),
    ('m_gun3', 'HOT SAUCE! ONE-SHOT SPLATS!'),
    ('m_sneak', 'SNEAKERS! ZOOM ZOOM!'),
    ('m_record', 'PUBERTY LOVE! THEY HATE IT!'),
    ('m_x2', 'SAUCE BOSS! DOUBLE POINTS!'),
    ('m_coland', 'COLANDER HELMET! SAFE-ISH!'),
    ('m_disg', 'DISGUISE! YOU ARE A TOMATO NOW'),
    ('m_can', 'SOUP CAN! EXTRA LIFE!'),
    ('m_letter', 'A SAUCE LETTER!'),
    ('m_sauce', 'S-A-U-C-E! +5000 AND 1UP!'),
    ('m_golden', 'A GOLDEN TOMATO! CATCH IT!'),
    ('m_combo', 'SAUCE COMBO!'),
    ('m_notrap', 'OUT OF TRAPS! WHACK SOME!'),
    ('m_ripe', 'A GREENIE HAS RIPENED!'),
    ('m_grilled', 'FLAME GRILLED! +500'),
    ('m_bosshurt', 'BULLSEYE!'),
    ('m_sing', 'THE SONG IS WORKING!'),
    ('m_news1', 'NEWS: PANIC IN THE PRODUCE AISLE'),
    ('m_news2', 'NEWS: KETCHUP SALES SKYROCKET'),
    ('m_news3', 'NEWS: ARMY ORDERS MORE CROUTONS'),
    ('m_news4', 'NEWS: SALSA DECLARED ILLEGAL'),
    ('m_last', 'LAST TOMATO! GET IT!'),
    ('m_shield', 'CLANG! HELMET SAVED YOU!'),
    ('m_bonusend', 'BONUS OVER!'),
    ('m_demo', 'DEMO MODE - PRESS FIRE TO PLAY'),
]
for lab, t in MSGS:
    assert len(t) <= 32, t
    STR[lab] = t
out('MSG_COUNT equ %d' % len(MSGS))
out('msg_tab:')
for lab, t in MSGS:
    out('        dw ' + lab)
for i, (lab, t) in enumerate(MSGS):
    out('M_%s equ %d' % (lab[2:].upper(), i))

S('s_end1', "{y}THE GREAT TOMATO\n{y}HAS BEEN PUREED!\n\n{b}SAN DIEGO IS SAFE.\n{b}PASS THE PASTA.")
S('s_end2', "{y}MASON DIXON IS A HERO.\n\n{b}THE ARMY TAKES THE\n{b}CREDIT. OF COURSE.")
S('s_end3', "{b}BUT DEEP IN THE\n{b}VEGETABLE PATCH...\n\n\n\n{y}  PSST. THEY'RE GONE.\n{y}  OUR TURN NOW...")
S('s_end4', "{r}THE END?\n\n{y}NOW TRY A\n{y}SECOND HELPING!")

S('s_ending_carrot', '')


S('s_resauced_short', '{y}RE-\n{y}SAUCED!')
S('s_press', 'PRESS\nFIRE')
S('s_keys1', '{b}D T L\n{b}OPTION')
S('s_keys2', '{b}S MUSIC\n{b}ON/OFF')
S('s_opt_diff', 'SKILL')
S('s_opt_train', 'TRAINER')
S('s_opt_normal', 'NORMAL ')
S('s_opt_start', 'START')
S('s_easy', 'EASY  ')
S('s_normal', 'NORMAL')
S('s_hard', 'HARD  ')
S('s_c6', '{r}JUMPING JACK\n{y}AVOIDS TRAPS. 300')
S('s_c7', '{r}ROTTEN RONNIE\n{y}LEAVES A STINK. 250')
S('s_c8', '{r}CANNONBALL\n{y}ROLLS STRAIGHT. 350')
S('s_wanted', 'WANTED!')
S('s_b1', '{r}MAMA BEEFSTEAK\n{y}TRAP HER, THEN WHACK')
S('s_b2', '{r}BARON VON BEEFSTEAK\n{y}CHARGES. DIZZY ON IMPACT')
S('s_b3', '{r}THE GREAT TOMATO\n{y}ONLY THE SONG\n{y}CAN HURT IT')
S('s_haha', 'HA HA\nHA HA!')

for lab, t in STR.items():
    db(lab, tstr(t))

# ------------------------------------------------------------------ stages
# kind: 0 normal 1 boss 2 bonus
TY = {'C': 2, 'R': 3, 'B': 4, 'U': 5, 'G': 6, 'H': 7, 'S': 8, 'L': 9, 'X': 12}
STAGES = [
    # maze, world, kind, hurry(s), name, tip, waves "T@spawn+delay", pickup secs, boss
    ('yard', 0, 0, 70, 'n11', 't11', 'C1+0 C2+2 C1+12 C2+16', 14, 0),
    ('street', 0, 0, 60, 'n12', 't12', 'C1+0 C2+2 R1+8 C2+12 R2+24', 13, 0),
    ('market', 0, 0, 60, 'n13', 't13', 'C1+0 R2+2 H1+6 C2+12 H2+18 B0+40!', 12, 0),
    ('arena1', 0, 1, 99, 'n14', 't14', 'X1+0', 12, 1),
    ('bonus', 3, 2, 15, 'nb', 'tb', '', 0, 0),
    ('dock', 1, 0, 60, 'n21', 't21', 'C1+0 U2+2 L1+6 C2+10 R1+16 L2+22', 12, 0),
    ('peel', 1, 0, 55, 'n22', 't22', 'R1+0 S2+2 U1+6 B2+12 C1+18 S2+26', 12, 0),
    ('vats', 1, 0, 55, 'n23', 't23', 'R1+0 U2+2 S1+6 L2+10 H1+14 U2+20 B0+36!', 11, 0),
    ('arena2', 1, 1, 99, 'n24', 't24', 'X1+0', 12, 2),
    ('bonus', 3, 2, 15, 'nb', 'tb', '', 0, 0),
    ('lobby', 2, 0, 55, 'n31', 't31', 'R1+0 H2+2 L2+6 U1+8 S1+14 C2+20 R1+26', 11, 0),
    ('green', 2, 0, 50, 'n32', 't32', 'C1+0 C2+1 U1+4 U2+6 H1+9 S2+12 L1+20 R2+22 C1+30', 11, 0),
    ('vault', 2, 0, 50, 'n33', 't33', 'R1+0 R2+2 L1+6 H2+8 S1+14 U2+18 B0+30! L1+36', 10, 0),
    ('arena3', 2, 1, 120, 'n34', 't34', 'X1+0', 9, 3),
]
out('NSTAGES equ %d' % len(STAGES))
out('stage_tab:')
siw = {}
for i, st in enumerate(STAGES):
    maze, world, kind, hurry, name, tip, waves, pk, boss = st
    k = siw.get(world, 0); siw[world] = k + 1
    out('        db %d,%d,%d,%d,%d,%d,%d' % (maze_order.index(maze), world, kind, hurry, pk, boss, k))
    out('        dw %s,%s,wv_%d' % (name, tip, i))
for i, st in enumerate(STAGES):
    d = []
    for tok in st[6].split():
        ann = tok.endswith('!')
        tok = tok.rstrip('!')
        t = TY[tok[0]] | (0x80 if ann else 0)
        sp, dl = tok[1:].split('+')
        d += [t, int(sp), int(dl) * 2]
    db('wv_%d' % i, d + [0xFF])
# stage labels for HUD: "1-1".."3-B"
lab = []
for st in STAGES:
    w = st[1] + 1
    lab.append(None)

# ------------------------------------------------------------------ music
NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
def midi(n):
    name = n[:-1]; octv = int(n[-1])
    return 12 * (octv + 1) + NOTE_NAMES.index(name)
BASE = midi('F3')
CLK = 3546894
def ptab(f_of, base_midi, clk_per_iter, extra=0, half=1):
    t = [0]
    for i in range(1, 32):
        f = 440 * 2 ** ((base_midi + i - 1 - 69) / 12)
        c = round((CLK / (f * half) - extra) / clk_per_iter)
        t.append(max(2, min(255, c)))
    return t
periods = ptab(None, BASE, 40, 70)
db('notetab1', periods)
db('notetab2', ptab(None, BASE, 56))
db('notetab3', ptab(None, BASE - 12, 56, 0, 2))
db('div5', [y // 5 for y in range(55)])
DUR = [3, 6, 9, 12, 18, 24, 36, 48]

def tune(label, text, loop=True, base=None):
    base = BASE if base is None else base
    data = []
    for tok in text.split():
        n, d = tok.split(':')
        d = int(d)
        while d > 0:
            # choose largest duration <= d
            k = max(i for i in range(8) if DUR[i] <= d)
            if n == 'r': idx = 0
            else:
                idx = midi(n) - base + 1
                assert 1 <= idx <= 31, tok
                if k == 7 and idx >= 30: k = 6
            data.append(k << 5 | idx)
            d -= DUR[k]
            if n != 'r': n = n  # tie re-strikes (fine for staccato style)
    db(label, data + [0xFF if loop else 0xFE])

# title: gritty B-movie march in A minor (original composition)
tune('mus_title', """
A3:6 r:6 A3:6 C4:6 A3:6 r:6 E4:12 D#4:6 D4:6 C4:6 A3:6 C4:6 D4:6 E4:6 r:6 E4:6 r:6
G4:6 F4:6 E4:6 D4:6 C4:6 D4:6 E4:6 A3:6 B3:6 C4:6 B3:6 G#3:6 A3:12 r:12
A4:6 r:6 A4:6 G4:6 F4:6 E4:6 F4:12 E4:6 D4:6 C4:6 D4:6 E4:12 r:12
C5:6 B4:6 A4:6 G#4:6 A4:6 E4:6 C4:6 E4:6 F4:6 E4:6 D4:6 B3:6 A3:24
""")
tune('mus_title_b', """
A3:12 E3:12 A3:12 E3:12 F3:12 C4:12 E3:12 E3:12
C4:12 G3:12 A3:12 E3:12 G#3:12 E3:12 A3:12 A3:12
F3:12 C4:12 F3:12 C4:12 C4:12 G3:12 C4:12 C4:12
A3:12 E3:12 A3:12 E3:12 D4:12 G#3:12 A3:24
""", base=BASE - 12)
# in-game chase (worlds 1-3 share it, it's short and jaunty)
tune('mus_game', """
E4:6 r:3 E4:3 G4:6 A4:6 G4:6 E4:6 D4:6 r:6 C4:6 r:3 C4:3 D4:6 E4:6 G4:6 E4:6 r:12
A4:6 r:3 A4:3 C5:6 A4:6 G4:6 E4:6 G4:6 r:6 F4:6 E4:6 D4:6 C4:6 D4:6 B3:6 C4:12
""")
tune('mus_game2', """
D4:6 r:3 D4:3 F4:6 D4:6 G4:6 F4:6 E4:6 C4:6 D4:6 r:3 D4:3 F4:6 A4:6 G#4:12 r:12
A4:6 G4:6 F4:6 E4:6 D4:6 F4:6 E4:6 C#4:6 D4:6 A3:6 D4:6 E4:6 F4:12 r:12
""")
tune('mus_boss', """
A3:6 A3:6 A#3:6 A3:6 A3:6 A3:6 C4:6 B3:6 A3:6 A3:6 A#3:6 A3:6 E4:6 D#4:6 D4:6 C#4:6
F3:6 F3:6 F#3:6 F3:6 F3:6 F3:6 G#3:6 G3:6 A3:6 C4:6 E4:6 A4:6 G#4:12 r:12
""")
# "Puberty Love" - an original, deliberately sappy little waltz
tune('mus_love', """
C5:9 E5:9 G5:9 E5:18 D5:9 C5:9 A4:9 C5:9 G4:27
F4:9 A4:9 C5:9 A4:18 G4:9 F4:9 E4:9 D4:9 C4:27
""")
tune('mus_clear', "C4:6 E4:6 G4:6 C5:12 G4:6 C5:18 r:12", loop=False)
tune('mus_over', "G4:18 F#4:18 F4:18 E4:36 r:24", loop=False)
tune('mus_bonus', """
C5:6 G4:6 E4:6 G4:6 C5:6 D5:6 E5:12 D5:6 C5:6 A4:6 C5:6 D5:6 B4:6 G4:12
""")
tune('mus_end', """
C4:6 E4:6 G4:6 C5:12 B4:6 A4:6 G4:12 E4:6 F4:6 G4:6 A4:12 G4:6 E4:6 C4:24
F4:6 A4:6 C5:6 F5:12 E5:6 D5:6 C5:12 A4:6 B4:6 C5:6 D5:12 B4:6 G4:6 C5:36 r:24
""")

# ------------------------------------------------------------------ sfx scripts
def sfx(label, steps):
    d = []
    for (p, fr, *fl) in steps:
        f = fr
        if 'n' in fl: f |= 0x80
        if 's' in fl: f |= 0x40
        d += [p, f]
    db(label, d + [0xFF])
sfx('sfx_type', [(30, 1)])
sfx('sfx_build', [(110, 2), (90, 2)])
sfx('sfx_armed', [(80, 2), (60, 2), (40, 4)])
sfx('sfx_bonk', [(180, 2), (31, 2, 'n'), (140, 2)])
sfx('sfx_splat', [(63, 3, 'n'), (127, 6, 'n'), (255, 4, 'n')])
sfx('sfx_snap', [(25, 2), (15, 3, 'n'), (60, 3)])
sfx('sfx_pickup', [(120, 3), (90, 3), (70, 3), (50, 3), (40, 5)])
sfx('sfx_shot', [(30, 8, 's')])
sfx('sfx_die', [(40, 30, 's'), (127, 10, 'n'), (255, 12, 'n')])
sfx('sfx_hurry', [(45, 6), (70, 6), (45, 6), (70, 6), (45, 6), (70, 6)])
sfx('sfx_1up', [(100, 4), (80, 4), (65, 4), (50, 4), (40, 8)])
sfx('sfx_trample', [(31, 4, 'n')])
sfx('sfx_grill', [(7, 12, 'n'), (15, 8, 'n')])
sfx('sfx_tele', [(20, 12, 's')])
sfx('sfx_bosshit', [(255, 4, 'n'), (60, 3), (255, 6, 'n')])
sfx('sfx_spawn', [(90, 2), (70, 2), (90, 2)])
sfx('sfx_deny', [(220, 6), (0, 2), (220, 6)])
sfx('sfx_thunder', [(255, 20, 'n'), (127, 16, 'n')])
sfx('sfx_charge', [(200, 20, 's')])

open(os.path.join(os.path.dirname(__file__), '..', 'src', 'gen_data.inc'), 'w').write('\n'.join(OUT) + '\n')
print('ok', len(OUT), 'lines')
