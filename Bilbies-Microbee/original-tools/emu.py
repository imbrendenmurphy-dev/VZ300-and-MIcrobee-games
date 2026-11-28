"""Run the VZ emulator with symbol names: python3 tools/emu.py script (lines may use {sym})"""
import subprocess, sys, re, os
W = os.path.dirname(os.path.abspath(__file__)) + '/..'
def syms():
    d = {}
    for l in open(W + '/build/vz.sym'):
        m = re.match(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)', l)
        if m: d[m.group(1)] = int(m.group(2), 16)
    return d
def run(body, name='t'):
    S = syms()
    body = re.sub(r'\{([\w.]+)\}', lambda m: '%04X' % S[m.group(1)], body)
    open(W + '/run/%s.scr' % name, 'w').write(body)
    r = subprocess.run([W + '/emu/vzemu', name + '.scr'], cwd=W + '/run', capture_output=True, text=True)
    return r.stderr
def png(names, out=None, cols=3):
    from PIL import Image
    ims = [Image.open(W + '/run/' + n + '.ppm') for n in names]
    if out is None:
        for n, im in zip(names, ims): im.resize((512, 384), Image.NEAREST).save(W + '/run/' + n + '.png')
        return
    rows = (len(ims) + cols - 1) // cols
    o = Image.new('RGB', (256 * cols, 192 * rows))
    for i, im in enumerate(ims): o.paste(im, ((i % cols) * 256, (i // cols) * 192))
    o.resize((o.width * 2, o.height * 2), Image.NEAREST).save(W + '/run/' + out)
if __name__ == '__main__':
    print(run(open(sys.argv[1]).read()))
