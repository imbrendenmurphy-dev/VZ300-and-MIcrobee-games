#!/usr/bin/env python3
"""Run DEPTHS.VZ in the headless emulator with a key script; save PNG snapshots.
usage: run.py name seconds "frame:key:dur,..." snapframes...
keys: R L U D FIRE MAG MAP INV N SPACE or rowXbitY ; J* = joystick"""
import subprocess, sys, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = {'R': (6, 4), 'L': (6, 1), 'U': (0, 4), 'D': (1, 4), 'FIRE': (4, 4), 'MAG': (4, 5), 'MAP': (6, 2),
        'INV': (6, 3), 'N': (4, 0), 'K': (7, 3), 'I': (6, 3), 'S': (1, 1)}
def run(name, secs, script, snaps, extra=()):
    out = f'{ROOT}/shots'
    os.makedirs(out, exist_ok=True)
    kf = f'{ROOT}/build/{name}.keys'
    with open(kf, 'w') as f:
        for item in script:
            fr, k, d = item
            r, b = KEYS[k]
            f.write(f'{fr} {r} {b} {d}\n')
    cmd = [f'{ROOT}/tools/vzemu', '-t', str(secs), '-keys', kf, '-snapbase', f'{out}/{name}'] + list(extra)
    for s in snaps:
        cmd += ['-snap', str(s)]
    cmd.append(f'{ROOT}/build/DEPTHS.VZ')
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT, env=dict(os.environ, VZFONT=f'{ROOT}/tools/font.txt'))
    for l in r.stderr.splitlines():
        if l.startswith('Frames') or 'DOS' in l or '!!' in l: print(l)
    pngs = []
    for s in snaps:
        p = f'{out}/{name}_{s:05d}.ppm'
        if os.path.exists(p):
            im = Image.open(p).resize((640, 480), Image.NEAREST)
            im.save(p[:-4] + '.png')
            os.remove(p)
            pngs.append(p[:-4] + '.png')
    return pngs
def state(memfile=None):
    import re
    syms = {}
    for l in open(f'{ROOT}/build/depths.sym'):
        m = re.match(r'^(\w+): EQU 0x([0-9A-F]+)', l)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    m = open(memfile or f'{ROOT}/build/mem.bin', 'rb').read()
    out = {k: m[syms[k]] for k in ('p_x', 'p_y', 'p_dir', 'p_hp', 'p_mp', 'p_staff', 'p_key', 'p_gems', 'p_xp', 'p_lvl', 'scr_x', 'scr_y', 'fb_on', 'boom_t', 'msg_t', 'p_dead', 'lv_num', 'lv_slot', 'b_on', 'b_hp', 'p_boots', 'p_sun', 'p_ring', 'p_blade', 'game_over')}
    ents = []
    for i in range(12):
        a = syms['ENTS'] + i * 8
        if m[a]:
            ents.append((m[a], m[a + 1], m[a + 2], m[a + 3]))
    out['b_xy'] = (m[syms['b_x']], m[syms['b_y']])
    out['ents'] = ents
    return out, m, syms

def montage(pngs, outp, cols=2):
    ims = [Image.open(p) for p in pngs]
    w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    m = Image.new('RGB', (cols * w + (cols - 1) * 6, rows * h + (rows - 1) * 6), (40, 40, 40))
    for i, im in enumerate(ims):
        m.paste(im, ((i % cols) * (w + 6), (i // cols) * (h + 6)))
    m.save(outp)
if __name__ == '__main__':
    name, secs = sys.argv[1], float(sys.argv[2])
    script = []
    if sys.argv[3]:
        for it in sys.argv[3].split(','):
            fr, k, d = it.split(':')
            script.append((int(fr), k, int(d)))
    snaps = [int(x) for x in sys.argv[4:]]
    pngs = run(name, secs, script, snaps)
    if pngs:
        montage(pngs, f'{ROOT}/shots/{name}_montage.png', cols=2 if len(pngs) > 1 else 1)
        print(f'{ROOT}/shots/{name}_montage.png')
