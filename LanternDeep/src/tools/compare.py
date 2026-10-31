"""Compare the Z80 engine's screen with the Python reference renderer."""
import sys
import numpy as np
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
import sym
import world as W
import art


def model_cells(pp):
    out = {}
    for y in range(W.ROWS):
        for x in range(W.COLS):
            a = y * 80 + x
            ch, at, co = pp.scr[a], pp.attr[a], pp.col[a]
            base = (at & 15) * 2048 + (ch & 0x7F) * 16
            g = tuple(pp.pcg[base:base + 8])
            out[(x, y)] = (g, co & 15, co >> 4)
    return out


def ref_cells(view, px, py, facing, zones, sprites, seen=None):
    dyn = W.cast(view.trees[facing], view.tilemap, px, py, {}, 0)
    out = {}
    if seen is not None:
        view.seen[:, :] = seen
    for y in range(W.ROWS):
        for x in range(W.COLS):
            g, fg, bg = view.cell(x, y, dyn, zones, sprites)
            out[(x, y)] = (g, fg, bg)
    return out


def norm(c):
    g, fg, bg = c
    if not any(g):
        fg = bg
    if fg == bg:
        g = (0,) * 8 if fg == 0 else g
    return c if any(g) else ((0,) * 8, bg, bg)


if __name__ == '__main__':
    S = sym.load()
    import play
    pp = run.boot()
    pp.run_frames(200)
    play.tap(pp, 'RET', 10)                 # title: NEW GAME
    pp.run_frames(int(sys.argv[1]) if len(sys.argv) > 1 else 150)
    m = model_cells(pp)
    room = W.build_showcase()
    ts, tm = W.build_tiles(room)
    view = W.View(room, ts, tm)
    pc = pp.peek(S['player_cell']) | (pp.peek(S['player_cell'] + 1) << 8)
    px, py = (pc & 0x7F) - 1, ((pc - 0xC000) >> 7) - 1
    print('player at', px, py)
    seen = np.zeros((W.ROWS, W.COLS), dtype=bool)
    for y in range(W.ROWS):
        for x in range(W.COLS):
            fl = pp.peek(0xC000 + (y + 1) * 128 + x + 1)
            seen[y, x] = bool(fl & 0x80)
    r = ref_cells(view, px, py, 'right', {1}, {(px, py): (art.PLAYER['right0'], W.WHT)}, seen)
    diffs = [(k, m[k], r[k]) for k in r if norm(m[k]) != norm(r[k])]
    print('cells differing:', len(diffs))
    for k, a, b in diffs[:12]:
        print(k, 'model', a[1:], 'ref', b[1:], 'glyph same' if a[0] == b[0] else 'glyph differs')
