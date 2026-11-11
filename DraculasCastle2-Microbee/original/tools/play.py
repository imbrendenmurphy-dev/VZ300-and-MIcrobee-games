# play.py - drive the emulator with a key script, capture screenshots after chosen steps
# usage: play.py out_dir "SPACE*  W W A ..." ; tokens: KEY[:wait]  ('!' suffix = capture)
import sys, os, subprocess
sys.path.insert(0, os.path.dirname(__file__))
from render import render
from PIL import Image
def run(outdir, script, start=160, default_wait=28, extra=60, vz='/home/claude/dc2/build/DRACDBG.VZ', wav=None):
    os.makedirs(outdir, exist_ok=True)
    for f in os.listdir(outdir):
        if f.endswith('.bin') or f.endswith('.png'): os.remove(os.path.join(outdir, f))
    f = start; keys = []; caps = []
    for tok in script.split():
        cap = tok.endswith('!'); tok = tok.rstrip('!')
        if ':' in tok: k, w = tok.split(':'); w = int(w)
        else: k, w = tok, default_wait
        if k != '_': keys.append('%d:%s:3' % (f, k))
        f += w
        if cap: caps.append(f - 1)
    caps.append(f + extra - 1)
    cmd = ['/home/claude/dc2/tools/vzemu', vz, '-s', '/home/claude/dc2/build/sd', '-f', str(f + extra), '-o', outdir, '-M', os.path.join(outdir, 'mem.bin')]
    if keys: cmd += ['-k', ','.join(keys)]
    cmd += ['-d', ','.join(map(str, caps))]
    if wav: cmd += ['-w', wav]
    r = subprocess.run(cmd, capture_output=True, text=True)
    print('\n'.join(l for l in r.stdout.splitlines() if not l.startswith('[mark')))
    ims = []
    for c in caps:
        p = os.path.join(outdir, 'f%05d.bin' % c)
        ims.append(render(open(p, 'rb').read(), 2))
    cols = 4; w, h = ims[0].size
    W = Image.new('RGB', (cols * (w + 4), ((len(ims) + cols - 1) // cols) * (h + 4)), (0, 0, 0))
    for i, im in enumerate(ims): W.paste(im, ((i % cols) * (w + 4), (i // cols) * (h + 4)))
    W.save(os.path.join(outdir, 'sheet.png'))
    return caps
if __name__ == '__main__':
    run(sys.argv[1], sys.argv[2])
