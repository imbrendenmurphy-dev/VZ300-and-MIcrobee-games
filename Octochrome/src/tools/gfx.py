"""CHUNKY FUNKY - generated graphics and tables (all original)."""
import math

# ---------------------------------------------------------------- 5x7 font (mode 1 scroller)
F57 = {
    'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'C': ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
    'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
    'G': ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.####'],
    'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'I': ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    'J': ['..###', '...#.', '...#.', '...#.', '...#.', '#..#.', '.##..'],
    'K': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
    'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
    'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'N': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
    'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
    'Q': ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'],
    'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
    'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'V': ['#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'],
    'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
    'X': ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
    'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
    'Z': ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
    '0': ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
    '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    '2': ['.###.', '#...#', '....#', '..##.', '.#...', '#....', '#####'],
    '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
    '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
    '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
    '6': ['..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.'],
    '7': ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
    '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
    '9': ['.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..'],
    ' ': ['.....'] * 7,
    '.': ['.....', '.....', '.....', '.....', '.....', '.##..', '.##..'],
    ',': ['.....', '.....', '.....', '.....', '.##..', '..#..', '.#...'],
    '!': ['..#..', '..#..', '..#..', '..#..', '..#..', '.....', '..#..'],
    '?': ['.###.', '#...#', '....#', '..##.', '..#..', '.....', '..#..'],
    '-': ['.....', '.....', '.....', '.###.', '.....', '.....', '.....'],
    "'": ['..#..', '..#..', '.#...', '.....', '.....', '.....', '.....'],
    ':': ['.....', '.##..', '.##..', '.....', '.##..', '.##..', '.....'],
    '/': ['....#', '....#', '...#.', '..#..', '.#...', '#....', '#....'],
    '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
    '(': ['...#.', '..#..', '.#...', '.#...', '.#...', '..#..', '...#.'],
    ')': ['.#...', '..#..', '...#.', '...#.', '...#.', '..#..', '.#...'],
    '&': ['.##..', '#..#.', '#.#..', '.#...', '#.#.#', '#..#.', '.##.#'],
    '*': ['.....', '#.#.#', '.###.', '#####', '.###.', '#.#.#', '.....'],
    '=': ['.....', '.....', '#####', '.....', '#####', '.....', '.....'],
    '<': ['...#.', '..#..', '.#...', '#....', '.#...', '..#..', '...#.'],
    '>': ['.#...', '..#..', '...#.', '....#', '...#.', '..#..', '.#...'],
    '@': ['.###.', '#...#', '#.###', '#.#.#', '#.###', '#....', '.###.'],
    '#': ['.#.#.', '.#.#.', '#####', '.#.#.', '#####', '.#.#.', '.#.#.'],
}
FONT_CHARS = sorted(F57.keys(), key=lambda c: (c != ' ', c))   # space first


def font_index(c):
    return FONT_CHARS.index(c)


def font_mode1():
    """Each glyph: 2 byte-columns x 8 rows (left column first, top row first), 2bpp.
    Letter = colour 1 (yellow), shadow = colour 3 (red), background = colour 0 (transparent)."""
    out = bytearray()
    for c in FONT_CHARS:
        g = F57[c]
        px = [[0] * 8 for _ in range(8)]
        lit = [[False] * 8 for _ in range(8)]
        for y in range(7):
            for x in range(5):
                if g[y][x] == '#':
                    lit[y][x + 1] = True          # bold: pixel and its right neighbour
                    lit[y][x + 2] = True
        for y in range(8):
            for x in range(8):
                if lit[y][x]:
                    px[y][x] = 1
                elif y > 0 and x > 0 and lit[y - 1][x - 1]:
                    px[y][x] = 3
        for col in range(2):
            for y in range(8):
                b = 0
                for k in range(4):
                    b = (b << 2) | px[y][col * 4 + k]
                out.append(b)
    return bytes(out)


def text_codes(s):
    """A string as font indices for the mode 1 scroller (255 = end)."""
    return bytes(font_index(c) for c in s.upper())


def vz_text(s):
    """A string as 6847 text codes (green on dark green)."""
    out = bytearray()
    for c in s.upper():
        o = ord(c)
        assert 32 <= o < 96, c
        out.append(o & 0x3F)
    return bytes(out)


# ---------------------------------------------------------------- the logo (mode 0, semigraphics)
L47 = {
    'C': ['.###', '#...', '#...', '#...', '#...', '#...', '.###'],
    'H': ['#..#', '#..#', '#..#', '####', '#..#', '#..#', '#..#'],
    'U': ['#..#', '#..#', '#..#', '#..#', '#..#', '#..#', '.##.'],
    'N': ['#..#', '##.#', '##.#', '#.##', '#.##', '#..#', '#..#'],
    'K': ['#..#', '#.#.', '##..', '##..', '#.#.', '#..#', '#..#'],
    'Y': ['#..#', '#..#', '#..#', '.##.', '.##.', '.##.', '.##.'],
    'F': ['####', '#...', '#...', '###.', '#...', '#...', '#...'],
}


def logo_cells():
    """8 rows x 32 cells of quadrant masks (0-15) for CHUNKY / FUNKY.
    A logo pixel is one cell wide and half a cell tall."""
    W, H = 64, 16
    pix = [[0] * W for _ in range(H)]

    def word(w, y0):
        width = len(w) * 9 - 1
        x0 = (W - width) // 2
        x0 -= x0 & 1
        for i, c in enumerate(w):
            for y in range(7):
                for x in range(4):
                    if L47[c][y][x] == '#':
                        for dx in range(2):
                            pix[y0 + y][x0 + i * 9 + x * 2 + dx] = 1
    word('CHUNKY', 0)
    word('FUNKY', 9)
    out = bytearray()
    for cy in range(8):
        for cx in range(32):
            m = (pix[cy * 2][cx * 2] << 3) | (pix[cy * 2][cx * 2 + 1] << 2) | \
                (pix[cy * 2 + 1][cx * 2] << 1) | pix[cy * 2 + 1][cx * 2 + 1]
            out.append(m)
    return bytes(out)


# ---------------------------------------------------------------- tables
def sin_table():
    return bytes(int(round(127 * math.sin(i * 2 * math.pi / 256))) & 255 for i in range(256))


def sg(colour, mask):
    return 0x80 | (colour << 4) | mask


GREEN, YELLOW, BLUE, RED, BUFF, CYAN, MAGENTA, ORANGE = range(8)
BLACK = 0x80
HALF = 0b1001      # two diagonal quadrants
FULL = 0b1111


def plasma_colours():
    """256 semigraphic codes: a smooth 16-step ramp, each step 4 values wide, repeating every 64."""
    ramp = [BLACK, sg(BLUE, HALF), sg(BLUE, FULL), sg(MAGENTA, FULL), sg(RED, FULL), sg(ORANGE, FULL),
            sg(YELLOW, FULL), sg(BUFF, FULL), sg(YELLOW, FULL), sg(ORANGE, FULL), sg(RED, FULL),
            sg(MAGENTA, FULL), sg(BLUE, FULL), sg(CYAN, FULL), sg(GREEN, FULL), sg(GREEN, HALF)]
    return bytes(ramp[(i // 4) % 16] for i in range(256))


TUN_W, TUN_H = 40, 20     # the tunnel's lookup window (screen 32x16 moves inside it)


def tunnel_table():
    """Per cell: (ring << 4 | sector), 16 sectors, rings shrinking towards the centre.
    Adding (speed*16 + spin) to it and looking up a 256-entry texture makes a spiral tunnel."""
    out = bytearray()
    cx, cy = TUN_W / 2 - 0.5, TUN_H / 2 - 0.5
    for y in range(TUN_H):
        for x in range(TUN_W):
            dx = (x - cx) * 8.0          # a cell is 8 x 12 dots
            dy = (y - cy) * 12.0
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx) / (2 * math.pi) * 16
            sector = int(math.floor(a)) & 15
            ring = int(600.0 / max(r, 1.0)) & 15
            out.append((ring << 4) | sector)
    return bytes(out)


def tunnel_texture():
    """256 entries indexed by ring*16 + sector (with carries, so the pattern spirals).
    Bands of two rings in 8 colours; four arms of full blocks and half-tones."""
    out = bytearray()
    cols = [RED, ORANGE, YELLOW, BUFF, CYAN, BLUE, MAGENTA, GREEN]
    for i in range(256):
        ring, sec = i >> 4, i & 15
        c = cols[(ring >> 1) & 7]
        out.append(sg(c, FULL) if ((ring & 1) + (sec >> 2)) & 1 else sg(c, HALF))
    return bytes(out)


def tunnel_dark():
    """The cells round the tunnel's far end that are blacked out, as screen offsets from the
    cell just up and left of the centre (the centre lies on that cell's bottom-right corner...
    at +0.5 cells in table terms: cell (19, 9) of the table)."""
    out = []
    for dy in range(-5, 7):
        for dx in range(-7, 9):
            ex = (dx - 0.5) * 8.0
            ey = (dy - 0.5) * 12.0
            if math.hypot(ex, ey) < 44:
                out.append(dy * 32 + dx)
    return out


def star_proj():
    """31 rows (z index 1..31) x 64 (v = -32..31): v*8/z, or -128 when it is off any screen."""
    out = bytearray()
    for z in range(1, 32):
        for i in range(64):
            v = i - 32
            p = int(round(v * 8.0 / z))
            out.append(p & 255 if -64 <= p <= 63 else 0x80)
    return bytes(out)
