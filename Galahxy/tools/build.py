#!/usr/bin/env python3
"""build.py - generate the assets, assemble, and package GALAHXY.VZ + GLXCOM.DAT + GLXS1.DAT
   python3 tools/build.py      -> build/sd/*"""
import os, sys, math, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprites, font, sound, scenery, logo
from zasm import Asm, AsmError
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'src'); GEN = os.path.join(SRC, 'gen'); BUILD = os.path.join(ROOT, 'build')
SD = os.path.join(BUILD, 'sd')
os.makedirs(GEN, exist_ok=True); os.makedirs(SD, exist_ok=True)

def w(name, text):
    open(os.path.join(GEN, name), 'w').write(text)

BUILD_ID = int(time.time()) & 0xFFFF or 1
w('buildid.inc', 'BUILD_ID equ $%04X\n' % BUILD_ID)
w('font.inc', font.asm())
w('sound.inc', sound.asm())
w('sine.inc', 'sine16:\n' + '\n'.join('            db %d' % round(16 * math.sin(i * 2 * math.pi / 64)) for i in range(64)) + '\n')
sprites.LOW = {'BIGTOAST', 'SHOPBAL'}; sprites.LOW_SPLIT = True
tab, rec, rec2 = sprites.asm(sprites.COMMON, 'com_spr', 0)
sprites.LOW = set(); sprites.LOW_SPLIT = False
w('comspr.inc', tab + rec)
w('comspr_lo.inc', rec2)
tab, rec = sprites.asm(sprites.STAGE1, 's1spr', 128)
w('s1spr_tab.inc', tab)
w('s1spr_rec.inc', rec)
w('s1scen.inc', scenery.asm())
w('logo.inc', logo.asm())
tt = []
for fg in range(4):
    for bg in range(4):
        for p in range(8):
            px = [fg if p & d else bg for d in (4, 2, 1)] + [bg]
            tt.append(px[0] << 6 | px[1] << 4 | px[2] << 2 | px[3])
w('txtab.inc', 'tx_tabs:\n' + '\n'.join('            db ' + ','.join('$%02X' % v for v in tt[i:i + 16]) for i in range(0, 128, 16)) + '\n')

a = Asm()
cwd = os.getcwd(); os.chdir(SRC)
try:
    out = a.assemble('main.asm')
except AsmError as e:
    print('ERROR:', e); sys.exit(1)
finally:
    os.chdir(cwd)
S = a.sym
def sym(n): return S[n] if n in S else S[n.upper()]
with open(os.path.join(BUILD, 'galahxy.sym'), 'w') as f:
    for k, v in sorted(S.items(), key=lambda x: x[1]): f.write('%04X %s\n' % (v & 0xFFFF, k))
with open(os.path.join(BUILD, 'galahxy.lst'), 'w') as f:
    for pc, bs, line in a.listing: f.write('%04X %-12s %s\n' % (pc, ''.join('%02X' % b for b in bs), line))

def grab(lo, hi): return bytes(out.get(i, 0) for i in range(lo, hi))
def chunk(m, dest, data):
    return bytes([m, dest & 255, dest >> 8, len(data) & 255, len(data) >> 8]) + bytes(data)
def datfile(name, chunks):
    chunks = list(chunks) + [chunk(7, sym('dat_id'), bytes([BUILD_ID & 255, BUILD_ID >> 8]))]
    d = b''.join(chunks) + b'\0'
    d += b'\0' * ((-len(d)) % 512)
    open(os.path.join(SD, name + '.DAT'), 'wb').write(d)
    print('%-7s.DAT %6d bytes' % (name, len(d)))

# GALAHXY.VZ: $8000 .. code_end
main = grab(0x8000, sym('code_end'))
hdr = b'VZF0' + b'GALAHXY'.ljust(16, b'\0')[:16] + b'\0' + bytes([0xF1, 0x00, 0x80])
open(os.path.join(SD, 'GALAHXY.VZ'), 'wb').write(hdr + main)
print('GALAHXY.VZ  $8000-$%04X (%d bytes, %d free below the variables)' % (sym('code_end') - 1, len(main), sym('VARS') - sym('code_end')))
datfile('GLXCOM', [chunk(7, sym('COM_HI'), grab(sym('COM_HI'), sym('com_hi_end'))),
                   chunk(7, sym('COM_LO'), grab(sym('COM_LO'), sym('com_lo_end')))])
print('  common hi $%04X-$%04X (%d free)  lo $%04X-$%04X (%d free)' % (sym('COM_HI'), sym('com_hi_end') - 1,
      0x10000 - sym('com_hi_end'), sym('COM_LO'), sym('com_lo_end') - 1, sym('HISCORES') - sym('com_lo_end')))
datfile('GLXS1', [chunk(7, 0xB800, grab(0xB800, sym('s1_end')))])
print('  stage 1 $B800-$%04X (%d free)' % (sym('s1_end') - 1, sym('STAGE_END') - sym('s1_end')))
print('vars $%04X-$%04X' % (sym('VARS'), sym('vars_end') - 1))
