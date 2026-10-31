"""Title / story / help / credits / ending pages, entity glyphs, automap colours."""
from glyph import T, V, S, BLK, G, Y, B, R, W, C, M, O, text
from tiles import DEFS, TILES

# 3x5 pixel capitals for the big logo
BIGF = {
    'A': ['###', '#.#', '###', '#.#', '#.#'], 'D': ['##.', '#.#', '#.#', '#.#', '##.'],
    'E': ['###', '#..', '##.', '#..', '###'], 'F': ['###', '#..', '##.', '#..', '#..'],
    'G': ['###', '#..', '#.#', '#.#', '###'], 'H': ['#.#', '#.#', '###', '#.#', '#.#'],
    'N': ['##.', '#.#', '#.#', '#.#', '#.#'], 'O': ['###', '#.#', '#.#', '#.#', '###'],
    'P': ['###', '#.#', '###', '#..', '#..'], 'R': ['##.', '#.#', '##.', '#.#', '#.#'],
    'S': ['###', '#..', '###', '..#', '###'], 'T': ['###', '.#.', '.#.', '.#.', '.#.'],
    ' ': ['...'] * 5,
}


class Screen:
    def __init__(self, fill=0x80):
        self.v = bytearray([fill] * 512)
        self.px = [[None] * 64 for _ in range(32)]   # pixel colours for SG composition

    def text(self, row, s, col=None, inv=False):
        if col is None:
            col = (32 - len(s)) // 2
        for i, ch in enumerate(s.upper()):
            self.v[row * 32 + col + i] = V(ch) if inv else T(ch)

    def pset(self, x, y, c):
        if 0 <= x < 64 and 0 <= y < 32:
            self.px[y][x] = c

    def compose(self):
        for r in range(16):
            for c in range(32):
                q = [self.px[2 * r][2 * c], self.px[2 * r][2 * c + 1], self.px[2 * r + 1][2 * c],
                     self.px[2 * r + 1][2 * c + 1]]
                cols = [x for x in q if x is not None]
                if not cols:
                    continue
                best = max(set(cols), key=cols.count)
                self.v[r * 32 + c] = S(best, ''.join('x' if x == best else '.' for x in q))

    def big(self, word, x0, y0, colrows):
        x = x0
        for ch in word:
            g = BIGF[ch]
            for yy in range(5):
                for xx in range(3):
                    if g[yy][xx] == '#':
                        self.pset(x + xx, y0 + yy, colrows[yy])
            x += 4


def frame_border(sc, c1=O, c2=Y):
    for x in range(64):
        sc.pset(x, 0, c1 if x % 4 else c2)
        sc.pset(x, 31, c1 if x % 4 else c2)
    for y in range(32):
        sc.pset(0, y, c1 if y % 4 else c2)
        sc.pset(63, y, c1 if y % 4 else c2)


def title_screen():
    sc = Screen()
    # logo
    sc.big('FORGOTTEN', 14, 4, [Y, Y, O, O, R])
    sc.big('DEPTHS', 20, 10, [W, W, Y, Y, O])
    # the gate: stone arch with steps descending into the dark
    for y in range(18, 27):
        for x in (23, 24, 39, 40):
            sc.pset(x, y, R if (x + y) % 3 else O)
    for x in range(23, 41):
        sc.pset(x, 17, O)
        sc.pset(x, 18, R if x % 3 else O)
    for i, y in enumerate(range(21, 27)):
        for x in range(26 + i // 2, 38 - i // 2):
            if (y % 2) == 1:
                sc.pset(x, y, B if i > 2 else R)
    # flanking torches (animated in code)
    for x in (19, 44):
        sc.pset(x, 21, R)
        sc.pset(x, 22, R)
    # floor line
    for x in range(8, 56):
        sc.pset(x, 27, R if x % 5 else O)
    sc.compose()
    sc.text(1, 'T H E')
    sc.text(14, 'VIBED BY BPM - 2026')
    torches = [(10, 9), (10, 22)]   # (row, col) of torch flame cells
    for r, c in torches:
        sc.v[r * 32 + c] = S(Y, 'xx.x')
    return sc, torches


def page(lines, border=True, css_title=None):
    sc = Screen(fill=T(' '))
    sc.v = bytearray([T(' ')] * 512)
    if border:
        for c in range(32):
            sc.v[c] = S(O, '..xx') if c % 2 else S(Y, '..xx')
            sc.v[15 * 32 + c] = S(O, 'xx..') if c % 2 else S(Y, 'xx..')
    for i, ln in enumerate(lines):
        if ln:
            sc.text(1 + i, ln)
    return sc


STORY = page([
    '',
    'BENEATH THE VILLAGE OF ASHFORD',
    'LIE HALLS OLDER THAN MEMORY.',
    '',
    'THEIR BUILDERS VANISHED, BUT',
    'THE EMBER THEY GUARDED STILL',
    'BURNS IN THE DARK BELOW.',
    '',
    'TAKE YOUR LANTERN. DESCEND.',
    'FIND WHAT THE DEPTHS FORGOT.',
    '',
    '',
    'PRESS N TO BEGIN'])
HELP = page([
    'HOW TO PLAY',
    '',
    'Q A O P  OR JOYSTICK  MOVE',
    'SPACE / FIRE     SWING SWORD',
    'M / ARM          CAST FIRE',
    'RETURN MAP   I INVENTORY',
    'T MUSIC ON/OFF',
    'WALK INTO FOES TO STRIKE THEM.',
    '& KEY  $ GEM  ! POTION  % MANA',
    '+ HEART  [ BOOTS  ) BLADE',
    'YOUR LANTERN LIGHTS THE WAY YOU',
    'FACE. RUNES WHISPER SECRETS AND',
    'SOME WALLS ARE NOT WALLS. NOTE',
    'THE PASSWORD AT EACH CHAPTER.',
    'PRESS N TO BEGIN'])
CREDITS = page([
    '',
    'THE FORGOTTEN DEPTHS',
    '',
    'VIBED BY BPM - 2026',
    '',
    'DESIGN  CODE  ART  MUSIC',
    'BPM / VIBED',
    '',
    'FOR THE DICK SMITH VZ300',
    'WITH BENNVENN SD + 128K',
    '',
    'THREE CHAPTERS OF THE DEEP',
    'PRESS N TO BEGIN'])


def end_page():
    sc = Screen()
    for i, y in enumerate(range(14, 30, 2)):
        for x in range(20 + i * 2, 44 - i * 2):
            sc.pset(x, y, [W, Y, O, R, M, B, B, B][i])
    sc.compose()
    sc.text(1, 'THE EMBER BURNS AGAIN')
    sc.text(3, 'THE WYRM IS SLAIN, AND THE OLD')
    sc.text(4, 'FIRE WAKES. FAR ABOVE, ASHFORD')
    sc.text(5, 'FEELS ITS FIRST SPRING IN YEARS')
    sc.text(14, 'THANK YOU FOR PLAYING')
    sc.text(15, 'VIBED BY BPM - 2026')
    return sc


SCROLL = ('      THE FORGOTTEN DEPTHS  ...  AN ATMOSPHERIC DUNGEON ADVENTURE FOR THE VZ300  ...  '
          'VIBED BY BPM 2026  ...  CARRY YOUR LANTERN INTO THE DARK, FOLLOW THE WHISPERING RUNES, '
          'WAKE THE EMBER  ...  N NEW GAME   C PASSWORD   I HOW TO PLAY   K CREDITS   S STORY   T MUSIC ON/OFF  ...  ')

# entity glyphs -------------------------------------------------------
ENTNAMES = ['none', 'player', 'skeleton', 'bat', 'slime', 'ghost', 'eel', 'drowned', 'imp', 'magma', 'spider',
            'staff', 'key', 'gem', 'potion', 'heart', 'boots', 'sunstone', 'ring', 'blade', 'mana']
ENT = [  # hp, speed, xp, g0, g1   (order = ENTNAMES)
    (0, 0, 0, BLK, BLK), (0, 0, 0, BLK, BLK),
    (4, 9, 3, S(W, 'xx.x'), S(W, 'xxx.')),       # skeleton
    (1, 4, 1, S(M, 'x..x'), S(M, '.xx.')),       # bat
    (2, 15, 2, S(G, '..xx'), S(G, '.xxx')),      # slime
    (3, 11, 3, S(C, 'xxx.'), S(W, 'x.x.')),      # ghost
    (2, 7, 2, S(G, '.xx.'), S(Y, 'x..x')),       # eel (water only)
    (5, 16, 4, S(G, 'xx.x'), S(G, 'xxx.')),      # drowned
    (2, 9, 3, S(R, 'x.xx'), S(O, 'xx.x')),       # imp (shoots)
    (3, 11, 3, S(O, '..xx'), S(Y, '.xxx')),      # magma slime
    (2, 6, 2, S(Y, 'x..x'), S(Y, '.xx.')),       # spider
    (0, 0, 0, T('/'), V('/')),                   # staff
    (0, 0, 0, T('&'), V('&')),                   # key
    (0, 0, 0, T('$'), V('$')),                   # gem
    (0, 0, 0, T('!'), V('!')),                   # potion
    (0, 0, 0, T('+'), V('+')),                   # heart crystal
    (0, 0, 0, T('['), V('[')),                   # boots
    (0, 0, 0, T('*'), V('*')),                   # sunstone
    (0, 0, 0, T('O'), V('O')),                   # ring of embers
    (0, 0, 0, T(')'), V(')')),                   # runeblade
    (0, 0, 0, T('%'), V('%')),                   # mana crystal
]
G_ = dict(PCAST=V('*'), PGET=V('@'), PATK=V('@'), FLASH=S(W, 'xxxx'), FB0=S(Y, 'xxxx'), FB1=S(O, '.xx.'),
          HPF=S(R, 'xxx.'), MPF=S(C, 'xxx.'), BOSSF=S(M, 'xxx.'), PIPE=T('.'), STAFF=T('/'), KEY=V('&'), GEM=V('$'))
PGLY = [[S(R, '...x'), S(O, '.x..'), S(Y, 'x..x'), S(W, '.xx.')],
        [S(B, 'x...'), S(C, '..x.'), S(C, 'x..x'), S(W, '.xx.')],
        [S(B, '...x'), S(W, '.x..'), S(W, 'x..x'), T('*')],
        [S(Y, 'x...'), S(W, '.x..'), S(C, 'x..x'), S(Y, '.xx.')],
        [S(R, '...x'), S(O, '..x.'), S(Y, '.x..'), S(O, 'x.x.')]]


def slash():
    out = []
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx == 0 and dy == 0:
                out.append(BLK)
            elif dy == 0:
                out.append(V('-'))
            elif dx == 0:
                out.append(V('!'))
            elif dx * dy > 0:
                out.append(V('\\'))
            else:
                out.append(V('/'))
    return out


def mapcol():
    """automap colour per tile (mode 1 CSS1 parchment: 0 buff paper 1 cyan 2 magenta 3 orange ink)."""
    out = []
    for t in range(128):
        d = DEFS.get(t)
        if d is None:
            out.append(0)
            continue
        n = d['name'].rstrip('0123456789')
        if n in ('water', 'pool', 'crystal', 'bridge'):
            out.append(1)
        elif n in ('torch', 'brazier', 'candle', 'rune', 'stairup', 'stairdn', 'door', 'shroom', 'lava', 'seal',
                   'ember'):
            out.append(2)
        elif d['opaque'] or d['solid']:
            out.append(3)
        else:
            out.append(0)
    return out


def inv_page():
    sc = page(['THE ADVENTURER'])
    sc.text(3, 'LEVEL', 5)
    sc.text(3, 'XP', 17)
    sc.text(4, 'LIFE', 5)
    sc.text(5, 'MANA', 5)
    sc.text(6, 'GEMS', 5)
    sc.text(14, 'PRESS ANY KEY')
    return sc


INV = inv_page()


CHAP = page(['', '', '', '', '', '', '', '', '', 'PASSWORD', '', '', 'PRESS FIRE OR SPACE'])
PW = page(['', 'THE FORGOTTEN DEPTHS', '', '', 'SPEAK THE WORD OF PASSAGE', '', '', '', '',
           'TYPE SIX LETTERS', 'DELETE WITH CTRL', 'RETURN ACCEPTS  SPACE CANCELS', ''])


def emit_hot(L):
    def db(name, vals):
        L.append(f'{name}:')
        vals = list(vals)
        for i in range(0, len(vals), 16):
            L.append('        db ' + ','.join(str(v & 255) for v in vals[i:i + 16]))
    sc, torches = title_screen()
    L.append('TITLE_TORCH: dw ' + ','.join(f'VRAM+{r * 32 + c}' for r, c in torches))
    cells = [i for i in range(2 * 32, 8 * 32) if sc.v[i] & 0x80 and sc.v[i] != 0x80]
    L.append(f'TITLE_NLOGO EQU {len(cells)}')
    db('ETAB', [v for e in ENT for v in e])
    for k, v in G_.items():
        L.append(f'G_{k} EQU {v}')
    db('PGLY', [v for k in PGLY for v in k])
    db('SLASH', slash())
    db('SLASH2', [(0x80 | (4 << 4) | (v & 15)) if v & 0x80 else v for v in slash()])


def emit_cold(C, zx0bytes):
    def db(name, vals):
        C.append(f'{name}:')
        vals = list(vals)
        for i in range(0, len(vals), 16):
            C.append('        db ' + ','.join(str(v & 255) for v in vals[i:i + 16]))
    sc, torches = title_screen()
    db('TITLE_Z', zx0bytes('title', sc.v))
    cells = [i for i in range(2 * 32, 8 * 32) if sc.v[i] & 0x80 and sc.v[i] != 0x80]
    C.append('TITLE_LOGO:')
    for i in cells:
        C.append(f'        dw VRAM+{i}')
        C.append(f'        db {sc.v[i]}')
    for nm, pg in (('STORY', STORY), ('HELP', HELP), ('CREDITS', CREDITS), ('END', end_page()), ('INV', INV),
                   ('CHAP', CHAP), ('PW', PW)):
        db(f'PAGE_{nm}', zx0bytes(f'page_{nm.lower()}', pg.v))
    db('SCROLLTXT', list(text(SCROLL)) + [255])
    for nm, g, t in (('STAFF', V('/'), ' EMBER STAFF  FIRE (M)'), ('KEY', V('&'), ' A KEY'),
                     ('BOOTS', V('['), ' REED BOOTS  WADE WATER'), ('SUN', V('*'), ' SUNSTONE  BRIGHT LIGHT'),
                     ('RING', V('O'), ' RING OF EMBERS  LAVA'), ('BLADE', V(')'), ' RUNEBLADE  +2 DAMAGE')):
        db(f'INV_{nm}', [g] + list(text(t.ljust(23))))
    db('END_GEMS', list(text('GEMS FOUND:')))


if __name__ == '__main__':
    import vzpreview
    import sys
    sc, _ = title_screen()
    vzpreview.mode0(bytes(sc.v), css=1).save(sys.argv[1] + '/title.png')
    vzpreview.mode0(bytes(HELP.v), css=1).save(sys.argv[1] + '/help.png')
    vzpreview.mode0(bytes(end_page().v), css=1).save(sys.argv[1] + '/end.png')
