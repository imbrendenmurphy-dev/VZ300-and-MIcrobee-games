"""MAX Q title logo: chunky italic pixel letters, stored run-length encoded."""
from PIL import Image
CSS1 = [(230, 225, 190), (70, 200, 200), (220, 70, 220), (240, 130, 40)]
LET = {
'M': ["XX...XX", "XXX.XXX", "XXXXXXX", "XX.X.XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX"],
'A': ["..XXX..", ".XXXXX.", "XX...XX", "XX...XX", "XXXXXXX", "XX...XX", "XX...XX", "XX...XX"],
'X': ["XX...XX", "XX...XX", ".XX.XX.", "..XXX..", "..XXX..", ".XX.XX.", "XX...XX", "XX...XX"],
'Q': [".XXXXX..", "XX...XX.", "XX...XX.", "XX...XX.", "XX.X.XX.", "XX..XX..", ".XXX.XX.", "......XX"],
' ': ["..", "..", "..", "..", "..", "..", "..", ".."],
}
CW, CH = 3, 2           # cell size in VZ pixels (VZ pixels are ~1.5x taller than wide)
H = 22                  # logo box height (rows)
TOP = 2                 # first screen row of the box
BANDS = [(23, 1), (26, (1, 2)), (31, 2), (33, (2, 3)), (34, 3)]   # title gradient, rows 0..33

def letters(text='MAX Q'):
    cols = []
    for i, ch in enumerate(text):
        g = LET[ch]
        for c in range(len(g[0])): cols.append([g[r][c] == 'X' for r in range(8)])
        if i < len(text) - 1: cols.append([False] * 8)
    w = len(cols) * CW; h = 8 * CH
    m = [[cols[x // CW][y // CH] for x in range(w)] for y in range(h)]
    sh = (h - 1) // 3       # italic shear
    return [[(0 <= x - (h - 1 - y) // 3 < w) and m[y][x - (h - 1 - y) // 3] for x in range(w + sh)] for y in range(h)]

def logo():
    m = letters(); mh, mw = len(m), len(m[0])
    ox = 128 - mw - 1; oy = 2
    L = [[None] * 128 for _ in range(H)]
    ink = lambda x, y: 0 <= y - oy < mh and 0 <= x - ox < mw and m[y - oy][x - ox]
    for y, x0 in ((oy + 2, 0), (oy + 6, 3), (oy + 10, 6), (oy + 14, 9)):          # speed lines
        for x in range(x0, ox + (mh - 1 - (y - oy)) // 3 - 1):
            L[y][x] = 0 if x > x0 + 8 else 3
    for y in range(H):
        for x in range(128):
            r = y - oy
            if ink(x, y):
                L[y][x] = 0 if r < 7 else (2 if r in (9, 12) else 3)      # cream top, striped orange base
            elif ink(x - 1, y - 1) or ink(x - 1, y) or ink(x, y - 1) or ink(x + 1, y) or ink(x, y + 1):
                L[y][x] = 2                                                 # outline and drop shadow
    y = oy + mh + 2                                                         # swoosh underline
    for x in range(ox - 2, min(128, ox + mw + 2)):
        if L[y][x] is None: L[y][x] = 3
    return L

CODE = {0: 0, 3: 1, 2: 2}       # stored codes: 0 cream, 1 orange, 2 magenta, 3 skip
def rle(L):
    flat = [3 if c is None else CODE[c] for row in L for c in row]
    out = []; i = 0
    while i < len(flat):
        c = flat[i]; n = 1
        while i + n < len(flat) and n < 64 and flat[i + n] == c: n += 1
        out.append((c << 6) | (n - 1)); i += n
    return out

def preview(path):
    L = logo(); im = Image.new('RGB', (128, 34))
    for y in range(34):
        b = next(c for lim, c in BANDS if y < lim)
        for x in range(128):
            c = b[(x + y) & 1] if isinstance(b, tuple) else b
            if TOP <= y < TOP + H and L[y - TOP][x] is not None: c = L[y - TOP][x]
            im.putpixel((x, y), CSS1[c])
    im.resize((768, 34 * 9), Image.NEAREST).save(path)

if __name__ == '__main__':
    print(len(rle(logo())), 'bytes'); preview('logo_preview.png')
