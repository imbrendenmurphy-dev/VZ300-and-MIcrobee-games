#!/usr/bin/env python3
# build.py - generate assets, assemble, package DRACULA2.VZ
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(__file__))
from lz2 import compress_opt as lz_compress
import area, walls

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'src'); GEN = os.path.join(SRC, 'gen'); BUILD = os.path.join(ROOT, 'build')
os.makedirs(GEN, exist_ok=True); os.makedirs(BUILD, exist_ok=True)

def write(name, data):
    p = os.path.join(GEN, name)
    old = open(p, 'rb').read() if os.path.exists(p) else None
    if isinstance(data, str): data = data.encode()
    if old != data: open(p, 'wb').write(data)

def geom():
    fx = []; fw = []; fy = []; fr = []
    for d in (1, 2, 3):
        y0, y1 = walls.face_rows(d)
        fx.append((walls.CX - walls.WB[d] // 2) // 4); fw.append(walls.WB[d] // 4); fy.append(y0); fr.append(y1 - y0)
    s = '; generated geometry\n'
    s += 'front_x:    db %s\n' % ','.join(map(str, fx))
    s += 'front_wb:   db %s\n' % ','.join(map(str, fw))
    s += 'front_y0:   db %s\n' % ','.join(map(str, fy))
    s += 'front_rows: db %s\n' % ','.join(map(str, fr))
    write('geom.inc', s)

SAMPLE_T = 204
def notes():
    fs = 3546900 / SAMPLE_T
    lines = ['; generated note step table: n=1 -> C1, fs=%.1f Hz' % fs, 'note_steps:']
    vals = [min(65535, round(440 * 2 ** ((n + 23 - 69) / 12) * 65536 / fs)) for n in range(1, 96)]
    for i in range(0, len(vals), 12): lines.append('            dw ' + ','.join(map(str, vals[i:i + 12])))
    write('notes.inc', '\n'.join(lines) + '\n')

SD = os.path.join(BUILD, 'sd')

def dat(name, data):
    """write an SD data file; returns its asm file entry"""
    assert len(name) <= 8
    os.makedirs(SD, exist_ok=True)
    open(os.path.join(SD, name + '.DAT'), 'wb').write(data)
    return 'f_%s: dw %d\n            db 34,"%s",34,0\n' % (name.lower(), len(data), name)

def sd_files():
    """all bulky assets become .DAT files on the SD card"""
    import monsters as M, title_art
    s = ['; generated SD file table']
    total = 0
    names = []
    for i, ad in enumerate(area.AREAS):
        p1, p2, ref = area.build_area(ad)
        s.append(dat('DC2A%dP1' % i, p1)); s.append(dat('DC2A%dP2' % i, p2)); total += len(p1) + len(p2)
        names.append('f_dc2a%dp1,f_dc2a%dp2' % (i, i))
        print('area %-8s part1 %5d  part2 %5d' % (ad.name, len(p1), len(p2)))
    s.append('area_files: dw %s' % ','.join(names))
    s.append('monsters:')
    monfiles = []
    for i, (name, fn, hp, at, df, xp, gold, flags, css) in enumerate(M.MONSTERS):
        frames = b''; key = None
        for f in range(3):
            c, key = fn(f); frames += M.frame_bytes(c, key)
        s.append('            dw mname_%d' % i)
        s.append('            db %d,%d,%d,%d,%d,%d,%d,3' % (hp, at, df, xp, gold, flags, css))
        s.append('            dw f_dc2mon%d' % (i + 1))
        s.append('            db %d,0,0,0' % key)
        monfiles.append(dat('DC2MON%d' % (i + 1), frames)); total += len(frames)
    s += monfiles
    for i, (name, *_r) in enumerate(M.MONSTERS): s.append('mname_%d: db "%s",0' % (i, name))
    s.append(dat('DC2BBG0', M.backdrop_bytes(M.backdrop_grounds())))
    s.append(dat('DC2BBG1', M.backdrop_bytes(M.backdrop_hall())))
    s.append('bbg_files: dw f_dc2bbg0,f_dc2bbg1')
    c = title_art.title_screen()
    raw = bytes(sum((c.p[y][xb * 4 + i] & 3) << (6 - 2 * i) for i in range(4)) for y in range(64) for xb in range(32))
    s.append(dat('DC2TITLE', raw).replace('f_dc2title', 'f_title'))
    try:
        import egg      # needs orig/lines.pkl (from tools/detok.py on the original DRACULA.VZ)
        eg = b''.join(egg.run(a_, b_) for n_, a_, b_ in egg.SCREENS)
    except FileNotFoundError:
        eg = open(os.path.join(ROOT, 'release', 'DC2EGG.DAT'), 'rb').read()
    s.append(dat('DC2EGG', eg).replace('f_dc2egg', 'f_egg'))
    write('files.inc', '\n'.join(s) + '\n')
    print('SD files in', SD, ':', ' '.join(sorted(os.listdir(SD))))

def assemble(main='main.asm', out='DRACULA2'):
    binf = os.path.join(BUILD, out + '.bin')
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'zasm.py'), os.path.join(SRC, main), '-o', binf,
                        '--sym', os.path.join(BUILD, out + '.sym'), '--lst', os.path.join(BUILD, out + '.lst'),
                        '--start', '0x8000'], capture_output=True, text=True)
    print(r.stdout.strip(), r.stderr.strip())
    if r.returncode: sys.exit(1)
    data = open(binf, 'rb').read()
    name = b'DRACULA II'
    hdr = b'VZF0' + name.ljust(17, b'\0') + bytes([0xF1, 0x00, 0x80])
    open(os.path.join(BUILD, out + '.VZ'), 'wb').write(hdr + data)
    end = 0x8000 + len(data)
    print('%s.VZ: %d bytes, $8000-$%04X (limit $C7FF, %d free)' % (out, len(data), end - 1, 0xC800 - end))
    if end > 0xC800: print('!!! TOO BIG'); sys.exit(1)

if __name__ == '__main__':
    import font
    write('font.inc', font.asm())
    geom()
    notes()
    write('debug.inc', 'DEBUG equ %d\n' % (1 if '--debug' in sys.argv else 0))
    import maps, texts
    write('maps.inc', maps.asm())
    write('texts.inc', texts.asm())
    import music
    write('music.inc', music.asm())
    if '--noart' not in sys.argv or not os.path.exists(os.path.join(GEN, 'files.inc')):
        sd_files()
    main = 'main.asm'
    for a in sys.argv[1:]:
        if a.endswith('.asm'): main = a
    assemble(main, ('DRACDBG' if '--debug' in sys.argv else 'DRACULA2') if main == 'main.asm' else os.path.splitext(main)[0].upper())
