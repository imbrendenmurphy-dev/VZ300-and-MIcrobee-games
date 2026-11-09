"""BILBIES! Microbee art previews: contact sheets of every level compiled
through compile_cells (what the hardware shows), colour and mono, plus the
raw painted pictures and the bilby sheet.

usage: python3 preview_art.py [outdir] [level numbers...]
       (levels: 0-23, or 't' for the title scene; default all + title)
"""
import os
import sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import world      # noqa: E402

AMBER = np.array([255, 176, 0], np.float64)


def amber(rgb):
    """an amber monitor: brightness from the colour's luminance"""
    lum = (rgb.astype(np.float64) * np.array([0.30, 0.59, 0.11])).sum(-1) / 255.0
    return (lum[..., None] * AMBER).clip(0, 255).astype(np.uint8)


def level_images(lv):
    img, solid, rep = world.paint_level(lv)
    bits, col, dug = world.compile_cells(img, solid, bgimg=rep['backdrop'])
    c = world.render_cells(bits, col)
    bm, cm, dm = world.compile_cells(img, solid, mono=True, bgimg=rep['backdrop'])
    m = amber(world.render_cells(bm, cm))
    raw = world.to_rgb(img)
    h = lv.height * 2
    return raw[:h], c[:h], m[:h]


def stack(ims, gap=6, bg=(30, 30, 30)):
    w = max(i.shape[1] for i in ims)
    hh = sum(i.shape[0] for i in ims) + gap * (len(ims) - 1)
    out = np.zeros((hh, w, 3), np.uint8)
    out[:] = bg
    y = 0
    for i in ims:
        out[y:y + i.shape[0], :i.shape[1]] = i
        y += i.shape[0] + gap
    return out


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/bilbies_art'
    os.makedirs(out, exist_ok=True)
    args = sys.argv[2:]
    lvs = []
    if not args:
        lvs = [(i, l) for i, l in enumerate(world.levels.LEVELS)] + [('t', world.levels.TITLE)]
    else:
        for a in args:
            lvs.append((a, world.levels.TITLE) if a == 't' else (int(a), world.levels.LEVELS[int(a)]))
    cols, monos, raws = [], [], []
    for i, lv in lvs:
        raw, c, m = level_images(lv)
        world.save_preview(os.path.join(out, 'lv_%s_col.png' % i), c, scale=1)
        world.save_preview(os.path.join(out, 'lv_%s_mono.png' % i), m, scale=1)
        world.save_preview(os.path.join(out, 'lv_%s_raw.png' % i), raw, scale=1)
        cols.append(c)
        monos.append(m)
        raws.append(raw)
    # contact sheets: 6 levels each
    for k in range(0, len(cols), 6):
        tag = '%02d' % k
        world.save_preview(os.path.join(out, 'sheet_col_%s.png' % tag), stack(cols[k:k + 6]), scale=1)
        world.save_preview(os.path.join(out, 'sheet_mono_%s.png' % tag), stack(monos[k:k + 6]), scale=1)
    import bilby
    bilby.sheet(os.path.join(out, 'bilby_sheet.png'))
    import stamps_hi
    for th in ('sky', 'dusk', 'night', 'cave'):
        stamps_hi.sheet(os.path.join(out, 'stamps_%s.png' % th), th)
    print('previews in', out)


if __name__ == '__main__':
    main()
