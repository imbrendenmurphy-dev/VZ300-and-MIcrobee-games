"""Display codes for the deck view.

Every cell of the deck view is one byte, a "display code".  Three page tables
turn a code into the MZ-700 character, the attribute (bit 7 = second
character bank, bits 6-4 foreground, bits 2-0 background) and gameplay flags.
The renderer compares codes, so a cell is only written to VRAM when its code
changes.  Code FFh is never used (the shadow is filled with it to force a
full redraw).

Tiles exist twice: lit and dim (a cleared deck has its lights turned down).
DIMTAB maps every code to its dim twin (sprite codes map to themselves).
"""
import roster

BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)

# flags
F_SOLID = 0x01      # droids can't enter
F_SHOT = 0x02       # stops shots
F_DOOR = 0x04
F_LIFT = 0x08
F_CON = 0x10        # console
F_ENER = 0x20       # energizer
F_VOID = 0x40       # outside the hull

LIT = dict(floor=BLUE, mark=CYAN, wall=WHITE, face=CYAN, door=YELLOW, lift=YELLOW,
           con=GREEN, ener=(RED, YELLOW, WHITE, YELLOW), crate=YELLOW, barrel=RED, bank=GREEN,
           react=MAGENTA, pipe=CYAN)
DIM = dict(floor=BLACK, mark=BLUE, wall=BLUE, face=BLUE, door=BLUE, lift=CYAN,
           con=BLUE, ener=(MAGENTA, RED, MAGENTA, BLUE), crate=BLUE, barrel=BLUE, bank=BLUE,
           react=BLUE, pipe=BLUE)


class Code:
    def __init__(self, name, char, bank, fg, bg, flags):
        self.name, self.char, self.bank, self.fg, self.bg, self.flags = name, char, bank, fg, bg, flags

    @property
    def attr(self):
        return (self.bank << 7) | (self.fg << 4) | self.bg


codes = []
index = {}


def add(name, char, bank, fg, bg, flags=0):
    assert name not in index, name
    index[name] = len(codes)
    codes.append(Code(name, char, bank, fg, bg, flags))
    return index[name]


# ---------------------------------------------------------------- tiles
# tile name -> function(palette) -> (char, bank, fg, bg, flags)
def tiles(P):
    fl = P['floor']
    t = {}
    t['VOID'] = (0x00, 0, BLACK, BLACK, F_SOLID | F_SHOT | F_VOID)
    t['STAR1'] = (0x2E, 0, WHITE, BLACK, F_SOLID | F_SHOT | F_VOID)
    t['STAR2'] = (0x2E, 0, BLUE, BLACK, F_SOLID | F_SHOT | F_VOID)
    t['FLOOR'] = (0x00, 0, P['mark'], fl, 0)
    t['MARK'] = (0x85, 1, P['mark'], fl, 0)
    t['WALL'] = (0x00, 0, P['wall'], P['wall'], F_SOLID | F_SHOT)
    t['FACE'] = (0x7A, 0, P['wall'], P['face'], F_SOLID | F_SHOT)      # wall with floor below
    # horizontal door (in a horizontal wall, 3 wide): closed / half / open
    t['DH0'] = (0xB7, 1, P['door'], fl, F_DOOR | F_SHOT)
    t['DH1'] = (0x78, 0, P['door'], fl, F_DOOR | F_SHOT)
    t['DHO'] = (0x00, 0, P['door'], fl, F_DOOR)
    # vertical door (in a vertical wall, 2 tall)
    t['DV0'] = (0xB6, 1, P['door'], fl, F_DOOR | F_SHOT)
    t['DV1'] = (0x79, 0, P['door'], fl, F_DOOR | F_SHOT)
    t['DVO'] = (0x00, 0, P['door'], fl, F_DOOR)
    # lift pad 3x2
    for i, ch in enumerate((0x72, 0x50, 0x73, 0x32, 0x58, 0x33)):
        t['LIFT%d' % i] = (ch, 0, P['lift'], fl, F_LIFT)
    # console 2x1 (solid)
    t['CON0'] = (0x7B, 1, P['con'], fl, F_SOLID | F_SHOT | F_CON)
    t['CON1'] = (0x7C, 1, P['con'], fl, F_SOLID | F_SHOT | F_CON)
    # energizer 3x2, four colour phases
    for k, c in enumerate(P['ener']):
        t['ENER%d' % k] = (0xD0, 0, c, fl, F_ENER)
    # props
    t['CRATE'] = (0xB1, 1, P['crate'], fl, F_SOLID | F_SHOT)
    t['BARREL'] = (0x47, 0, P['barrel'], fl, F_SOLID | F_SHOT)
    t['BANK'] = (0x75, 1, P['bank'], fl, F_SOLID | F_SHOT)
    t['REACT'] = (0x8F, 1, P['react'], fl, F_SOLID | F_SHOT)
    return t


TILE_NAMES = list(tiles(LIT).keys())
for nm, spec in tiles(LIT).items():
    add(nm, *spec)
for nm, spec in tiles(DIM).items():
    if nm in ('VOID', 'STAR1', 'STAR2'):
        continue
    add(nm + '.d', *spec)


def dim_name(nm):
    return nm if nm in ('VOID', 'STAR1', 'STAR2') else nm + '.d'


# ---------------------------------------------------------------- droids
# body colours: hostile classes, player, flash
BODY = [GREEN, CYAN, MAGENTA, RED, YELLOW, WHITE]
BODY_PLAYER = 4
BODY_FLASH = 5
EYE_CHARS = [(0x85, 1), (0x86, 1), (0x87, 1), (0x86, 1)]
for bi, col in enumerate(BODY):
    for lit, fl in (('', BLUE), ('.d', BLACK)):
        add('DL%d%s' % (bi, lit), 0x4E, 0, col, fl)       # dome left  (lower-right triangle)
        add('DR%d%s' % (bi, lit), 0x4D, 0, col, fl)       # dome right (lower-left triangle)
    for k, (ch, bk) in enumerate(EYE_CHARS[:3]):
        add('EYE%d_%d' % (bi, k), ch, bk, BLACK, col)
    for d in range(10):
        add('DG%d_%d' % (bi, d), 0x20 + d, 0, BLACK, col)


def body_index(num):
    return BODY.index(roster.body_colour(num))


# ---------------------------------------------------------------- shots
SHOT_CHARS = [0x78, 0x79, 0x76, 0x77]           # horizontal, vertical, '/', '\'
for owner, col in (('P', WHITE), ('E', RED)):
    for k, ch in enumerate(SHOT_CHARS):
        for lit, fl in (('', BLUE), ('.d', BLACK)):
            add('SH%s%d%s' % (owner, k, lit), ch, 0, col, fl)

# ---------------------------------------------------------------- explosions
EXPL_GLYPHS = [(0x47, 0, WHITE), (0x6B, 0, YELLOW), (0xB3, 1, YELLOW), (0xB3, 1, RED),
               (0xA0, 1, RED), (0x9F, 1, MAGENTA)]
for k, (ch, bk, col) in enumerate(EXPL_GLYPHS):
    for lit, fl in (('', BLUE), ('.d', BLACK)):
        add('EX%d%s' % (k, lit), ch, bk, col, fl)

assert len(codes) <= 255, len(codes)


def dimtab():
    out = list(range(256))
    for nm in TILE_NAMES:
        out[index[nm]] = index[dim_name(nm)]
    # sprite codes with a floor background have dim twins too
    for c in codes:
        if c.name.endswith('.d'):
            base = c.name[:-2]
            out[index[base]] = index[c.name]
    return out


def tables_asm():
    """CHRTAB / ATRTAB / FLGTAB / DIMTAB pages + equates for every code"""
    pad = codes + [Code('-', 0, 0, 0, 0, 0)] * (256 - len(codes))
    lines = ['; generated by tools/codes.py - %d display codes' % len(codes)]
    for c in codes:
        lines.append('C_%s equ %d' % (c.name.replace('.', '_'), index[c.name]))
    def page(label, vals):
        lines.append('        align 256')
        lines.append(label + ':')
        for i in range(0, 256, 16):
            lines.append('        db ' + ','.join('%d' % v for v in vals[i:i + 16]))
    page('CHRTAB', [c.char for c in pad])
    page('ATRTAB', [c.attr for c in pad])
    page('FLGTAB', [c.flags for c in pad])
    page('DIMTAB', dimtab())
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    print(len(codes), 'codes')
