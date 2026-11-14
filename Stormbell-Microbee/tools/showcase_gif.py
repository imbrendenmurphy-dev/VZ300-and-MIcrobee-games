"""STORMBELL showcase GIF, from the segments tools/showcase.py recorded.

    python3 tools/showcase_gif.py OUTDIR GIF [scale]

The segments are frames taken every second field (25 a second); the GIF
keeps every second one (12.5 a second), drawn in the Microbee's own 16
colours (and amber for the monochrome mode) at the true 40-column shape.
"""
import sys
import pickle
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mbee import PALETTE

# (segment, first frame, frames) in showing order
CUT = [('a_title', 0, 50), ('b_road1', 20, 70), ('c_bow', 0, 50), ('d_duel1', 0, 130), ('e_fall1', 0, 40),
       ('f_road2', 0, 50), ('g_duel2', 10, 80), ('g_duel3', 10, 80), ('j_mono2', 20, 90), ('g_duel4', 10, 70),
       ('f_road5', 0, 50), ('g_duel5', 60, 130), ('h_fall5', 0, 41), ('i_ending', 20, 110)]
ASPECT = 0.92


def palette_image():
    cols = [tuple(c) for c in PALETTE] + [(255, 176, 0)]
    flat = [v for c in cols for v in c]
    flat += [0] * (768 - len(flat))
    p = Image.new('P', (1, 1))
    p.putpalette(flat)
    return p


def main(out, gif, scale=2):
    out = Path(out)
    segs = pickle.load(open(out / 'segments.pkl', 'rb'))
    segs.update(pickle.load(open(out / 'segments_mono.pkl', 'rb')))
    pal = palette_image()
    frames = []
    for name, a, n in CUT:
        src = segs[name][a:a + n][::2]
        for img in src:
            h, w = img.shape[:2]
            im = Image.fromarray(img).resize((w * scale, round(h * ASPECT) * scale), Image.NEAREST)
            frames.append(im.quantize(palette=pal, dither=Image.Dither.NONE))
    frames[0].save(gif, save_all=True, append_images=frames[1:], duration=80, loop=0, optimize=False,
                   disposal=1)
    size = Path(gif).stat().st_size
    print('%s: %d frames, %.1f s, %dx%d, %.1f MB' % (gif, len(frames), len(frames) * 0.08,
                                                    frames[0].width, frames[0].height, size / 1e6))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 2)
