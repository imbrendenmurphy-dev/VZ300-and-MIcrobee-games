"""Blackout Protocol's own typeface: squared, retro-futuristic, 7 x 9 in an 8 x 12 cell.

Heavy two-pixel uprights, one-pixel horizontals, clipped outer corners, a high
crossbar on row 4, a slashed zero.  Characters 32..95 (no lower case: the game
shouts).  Each glyph sits on cell rows 1..9, columns 0..6.

python tools/font.py -> build/font_preview.png ;  glyphs() is imported by gen.py
"""
G = {}
def g(ch, *rows):
    rows = list(rows) + ['.......'] * (9 - len(rows))
    assert len(rows) == 9 and all(len(r) == 7 for r in rows), ch
    G[ch] = rows
def mirror(src, dst): G[dst] = [r[::-1] for r in G[src]]

g(' ')
g('!', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', '.......', '..XX...', '..XX...')
g('"', '.XX.XX.', '.XX.XX.')
g('#', '.XX.XX.', '.XX.XX.', 'XXXXXXX', '.XX.XX.', '.XX.XX.', 'XXXXXXX', '.XX.XX.', '.XX.XX.')
g('$', '...X...', '.XXXXXX', 'XX.X...', 'XX.X...', '.XXXXX.', '...X.XX', '...X.XX', 'XXXXXX.', '...X...')
g('%', 'XX....X', 'XX...XX', '....XX.', '...XX..', '..XX...', '.XX....', 'XX...XX', 'X....XX')
g('&', '.XXXX..', 'XX..XX.', 'XX..XX.', '.XXXX..', 'XX.XX.X', 'XX..XX.', 'XX..XX.', '.XXX.XX')
g("'", '..XX...', '..XX...', '.XX....')
g('(', '...XX..', '..XX...', '.XX....', '.XX....', '.XX....', '.XX....', '.XX....', '..XX...', '...XX..')
mirror('(', ')')
g('*', '.......', '.X.X.X.', '..XXX..', 'XXXXXXX', '..XXX..', '.X.X.X.')
g('+', '.......', '..XX...', '..XX...', 'XXXXXX.', '..XX...', '..XX...')
g(',', '.......', '.......', '.......', '.......', '.......', '.......', '.......', '..XX...', '.XX....')
g('-', '.......', '.......', '.......', '.......', 'XXXXXX.')
g('.', '.......', '.......', '.......', '.......', '.......', '.......', '.......', '..XX...', '..XX...')
g('/', '.....XX', '.....XX', '....XX.', '...XX..', '..XX...', '.XX....', 'XX.....', 'XX.....')
g('0', '.XXXXX.', 'XX...XX', 'XX...XX', 'XX..XXX', 'XX.X.XX', 'XXX..XX', 'XX...XX', 'XX...XX', '.XXXXX.')
g('1', '..XX...', '.XXX...', 'XXXX...', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', 'XXXXXX.')
g('2', 'XXXXXX.', '.....XX', '.....XX', '.....XX', '.XXXXX.', 'XX.....', 'XX.....', 'XX.....', 'XXXXXXX')
g('3', 'XXXXXX.', '.....XX', '.....XX', '.....XX', '..XXXX.', '.....XX', '.....XX', '.....XX', 'XXXXXX.')
g('4', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXXX', '.....XX', '.....XX', '.....XX', '.....XX')
g('5', 'XXXXXXX', 'XX.....', 'XX.....', 'XX.....', 'XXXXXX.', '.....XX', '.....XX', '.....XX', 'XXXXXX.')
g('6', '.XXXXX.', 'XX.....', 'XX.....', 'XX.....', 'XXXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', '.XXXXX.')
g('7', 'XXXXXXX', '.....XX', '.....XX', '....XX.', '...XX..', '..XX...', '..XX...', '..XX...', '..XX...')
g('8', '.XXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', '.XXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', '.XXXXX.')
g('9', '.XXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', '.XXXXXX', '.....XX', '.....XX', '.....XX', '.XXXXX.')
g(':', '.......', '.......', '..XX...', '..XX...', '.......', '.......', '..XX...', '..XX...')
g(';', '.......', '.......', '..XX...', '..XX...', '.......', '.......', '..XX...', '..XX...', '.XX....')
g('<', '.......', '....XX.', '...XX..', '..XX...', '.XX....', '..XX...', '...XX..', '....XX.')
mirror('<', '>')
g('=', '.......', '.......', '.......', 'XXXXXX.', '.......', 'XXXXXX.')
g('?', 'XXXXXX.', '.....XX', '.....XX', '...XXX.', '..XX...', '..XX...', '.......', '..XX...', '..XX...')
g('@', '.XXXXX.', 'XX...XX', 'XX.XXXX', 'XX.X.XX', 'XX.XXXX', 'XX.....', 'XX.....', '.XXXXX.')
g('A', '.XXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXXX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX')
g('B', 'XXXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXX.')
g('C', '.XXXXXX', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XX.....', '.XXXXXX')
g('D', 'XXXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXX.')
g('E', 'XXXXXXX', 'XX.....', 'XX.....', 'XX.....', 'XXXXX..', 'XX.....', 'XX.....', 'XX.....', 'XXXXXXX')
g('F', 'XXXXXXX', 'XX.....', 'XX.....', 'XX.....', 'XXXXX..', 'XX.....', 'XX.....', 'XX.....', 'XX.....')
g('G', '.XXXXXX', 'XX.....', 'XX.....', 'XX.....', 'XX..XXX', 'XX...XX', 'XX...XX', 'XX...XX', '.XXXXX.')
g('H', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXXX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX')
g('I', 'XXXXXX.', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', 'XXXXXX.')
g('J', '.....XX', '.....XX', '.....XX', '.....XX', '.....XX', '.....XX', 'XX...XX', 'XX...XX', '.XXXXX.')
g('K', 'XX...XX', 'XX..XX.', 'XX.XX..', 'XXXX...', 'XXX....', 'XXXX...', 'XX.XX..', 'XX..XX.', 'XX...XX')
g('L', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XX.....', 'XXXXXXX')
g('M', 'XX...XX', 'XXX.XXX', 'XXXXXXX', 'XX.X.XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX')
g('N', 'XX...XX', 'XXX..XX', 'XXXX.XX', 'XX.XXXX', 'XX..XXX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX')
g('O', '.XXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', '.XXXXX.')
g('P', 'XXXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXX.', 'XX.....', 'XX.....', 'XX.....', 'XX.....')
g('Q', '.XXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX.X.XX', 'XX..XX.', '.XXX.XX')
g('R', 'XXXXXX.', 'XX...XX', 'XX...XX', 'XX...XX', 'XXXXXX.', 'XX..XX.', 'XX...XX', 'XX...XX', 'XX...XX')
g('S', '.XXXXXX', 'XX.....', 'XX.....', 'XX.....', '.XXXXX.', '.....XX', '.....XX', '.....XX', 'XXXXXX.')
g('T', 'XXXXXX.', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...', '..XX...')
g('U', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', '.XXXXX.')
g('V', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', '.XX.XX.', '.XX.XX.', '..XXX..', '...X...')
g('W', 'XX...XX', 'XX...XX', 'XX...XX', 'XX...XX', 'XX.X.XX', 'XXXXXXX', 'XXX.XXX', 'XX...XX', 'X.....X')
g('X', 'XX...XX', 'XX...XX', '.XX.XX.', '..XXX..', '..XXX..', '.XX.XX.', 'XX...XX', 'XX...XX', 'XX...XX')
g('Y', 'XX...XX', 'XX...XX', 'XX...XX', '.XX.XX.', '..XXX..', '..XX...', '..XX...', '..XX...', '..XX...')
g('Z', 'XXXXXXX', '.....XX', '....XX.', '...XX..', '..XX...', '.XX....', 'XX.....', 'XX.....', 'XXXXXXX')
g('[', '.XXXX..', '.XX....', '.XX....', '.XX....', '.XX....', '.XX....', '.XX....', '.XX....', '.XXXX..')
mirror('/', '\\')
mirror('[', ']')
g('^', '..XX...', '.XXXX..', 'XX..XX.')
g('_', '.......', '.......', '.......', '.......', '.......', '.......', '.......', '.......', 'XXXXXXX')

def glyphs():
    """64 glyphs (chars 32..95) as 12-byte cells."""
    out = []
    for code in range(32, 96):
        rows = G[chr(code)]
        cell = [0] + [int(r.replace('.', '0').replace('X', '1') + '0', 2) for r in rows] + [0, 0]
        out.append(cell)
    return out

if __name__ == '__main__':
    from PIL import Image
    Z = 4; text = [' !"#$%&\'()*+,-./0123456789:;<=>?', '@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_', 'BLACKOUT PROTOCOL  07:59:58  KEY 1']
    im = Image.new('RGB', (8 * Z * 34, 12 * Z * len(text)), (10, 10, 30))
    gl = glyphs()
    for ln, s in enumerate(text):
        for i, ch in enumerate(s):
            cell = gl[ord(ch) - 32]
            for y in range(12):
                for x in range(8):
                    if cell[y] >> (7 - x) & 1:
                        for a in range(Z - 1):
                            for b in range(Z):
                                im.putpixel(((i * 8 + x) * Z + a, (ln * 12 + y) * Z + b), (120, 230, 255))
    im.save('build/font_preview.png')
