#!/usr/bin/env python3
"""Run SCROSS.COM in the emulator with a key script; save frames as PNG and report T-states."""
import sys, os, re
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tools'))
from z80emu import Bee, Z80
from PIL import Image, ImageDraw, ImageFont

here = os.path.dirname(os.path.abspath(__file__))
syms = {}
for line in open(os.path.join(here, 'build', 'scross.lst')):
    m = re.match(r'^(\w+)\s+([0-9A-F]{4})$', line.strip())
    if m: syms[m.group(1)] = int(m.group(2), 16)

def make_font():
    f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 11) if os.path.exists('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf') else ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 11)
    glyphs = {}
    for ch in range(32, 127):
        im = Image.new('L', (8, 16), 0)
        d = ImageDraw.Draw(im)
        d.text((0, 1), chr(ch), fill=255, font=f)
        glyphs[ch] = im.point(lambda v: 1 if v > 110 else 0, '1')
    return glyphs
FONT = make_font()

AMBER = (255, 176, 0)

def render(m, scale=2):
    start = (m.crtc[12] << 8 | m.crtc[13]) & 0x7ff
    img = Image.new('RGB', (512, 256), (0, 0, 0))
    px = img.load()
    for row in range(16):
        for col in range(64):
            o = (start + row * 64 + col) & 0x7ff
            code = m.screen[o]
            if code >= 128:
                bank = m.attr[o] & 15
                base = bank * 2048 + (code - 128) * 16
                for ln in range(16):
                    bits = m.pcg[base + ln]
                    if bits:
                        for b in range(8):
                            if bits & (0x80 >> b):
                                px[col * 8 + b, row * 16 + ln] = AMBER
            else:
                g = FONT.get(code)
                if g:
                    gp = g.load()
                    for yy in range(16):
                        for xx in range(8):
                            if gp[xx, yy]:
                                px[col * 8 + xx, row * 16 + yy] = AMBER
    # 4:3 display: 512x256 -> 1024x768
    return img.resize((1024, 768), Image.NEAREST)

def run(script, outdir, prefix='f', save_every=1, verbose=True):
    m = Bee()
    cpu = Z80(m)
    data = open(os.path.join(here, 'build', 'SCROSS.COM'), 'rb').read()
    m.ram[0x100:0x100 + len(data)] = data
    # pretend DOS left white text colour in colour RAM
    cpu.pc = 0x100
    flip = syms['flip']
    frame = 0
    last_t = 0
    times = []
    os.makedirs(outdir, exist_ok=True)
    steps = 0
    while frame < len(script):
        m.keys = script[frame]
        if cpu.pc == flip:
            dt = cpu.t - last_t; last_t = cpu.t
            times.append(dt)
            # flip happens now; render after flip by stepping until ret
            sp0 = cpu.sp
            cpu.step()
            while cpu.sp <= sp0 - 0 and cpu.pc != syms['timing']:
                cpu.step()
            if frame % save_every == 0 or frame == len(script) - 1:
                render(m).save(os.path.join(outdir, '%s%03d.png' % (prefix, frame)))
            if verbose:
                r = lambda n: int.from_bytes(m.ram[syms[n]:syms[n] + 2], 'little', signed=True)
                print('frame %3d  T=%7d (%.1f fps @3.375MHz)  px=%d pz=%d alt=%d vel=%.1f pitch=%.2f roll=%.2f hdg=%d thr=%d gnd=%d crash=%d' % (
                    frame, dt, 3375000 / dt if dt else 0, r('px'), r('pz'), r('alt'), r('vel') / 256,
                    r('pitch') / 256, r('roll') / 256, (r('hdg') & 0xffff) >> 8, m.ram[syms['thr']],
                    m.ram[syms['ongnd']], m.ram[syms['crashed']]))
            frame += 1
            continue
        cpu.step()
        steps += 1
    return m, times

if __name__ == '__main__':
    K = {'Q': 17, 'A': 1, 'O': 15, 'P': 16, 'T': 20, 'G': 7, 'R': 18, 'F': 6, ' ': 55}
    script = [set() for _ in range(3)]
    run(script, os.path.join(here, 'shots'))
