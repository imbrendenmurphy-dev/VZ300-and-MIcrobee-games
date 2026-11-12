#!/usr/bin/env python3
# TIGER GATE - builds resident assets (gen/) and the SD data files (build/sd/)
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from art import *
OUT = sys.argv[1] if len(sys.argv) > 1 else 'gen'
SD = sys.argv[2] if len(sys.argv) > 2 else 'build/sd'
os.makedirs(OUT, exist_ok=True); os.makedirs(SD, exist_ok=True)
PACK = 0xC800
def fb(fr): return b''.join(packrows(f) for f in fr)
def xorsum(b):
    x = 0
    for v in b: x ^= v
    return x
def seal(p, m2, num, nsec):
    assert len(p) <= nsec*512, (len(p), nsec)
    p = bytearray(p)+bytes(nsec*512-len(p))
    p[0] = ord('T'); p[1] = ord(m2); p[2] = num; p[3] = xorsum(p[4:])
    return bytes(p)

# ---------------------------------------------------------------- resident
hero = frames(HERO)
open(OUT+'/hero.bin', 'wb').write(fb(hero))
with open(OUT+'/frames.asm', 'w') as f:
    for i, (n, _) in enumerate(POSES): f.write('F_%s equ %d\n' % (n, i))
masktab = bytes(sum((0 if (b >> s) & 3 else 3) << s for s in (0, 2, 4, 6)) for b in range(256))
bmask = bytes(sum((3 if (b >> s) & 3 == 2 else 0) << s for s in (0, 2, 4, 6)) for b in range(256))
bclr = bytes(b & ~bmask[b] & 255 for b in range(256))
open(OUT+'/tables.bin', 'wb').write(masktab+bmask+bclr)
FONT = {
'A':'010101111101101','B':'110101110101110','C':'011100100100011','D':'110101101101110','E':'111100110100111',
'F':'111100110100100','G':'011100101101011','H':'101101111101101','I':'111010010010111','J':'001001001101010',
'K':'101101110101101','L':'100100100100111','M':'101111111101101','N':'110101101101101','O':'111101101101111',
'P':'110101110100100','Q':'010101101111011','R':'110101110101101','S':'011100010001110','T':'111010010010010',
'U':'101101101101111','V':'101101101101010','W':'101101111111101','X':'101101010101101','Y':'101101010010010',
'Z':'111001010100111','0':'010101101101010','1':'010110010010111','2':'110001010100111','3':'110001010001110',
'4':'101101111001001','5':'111100110001110','6':'011100110101010','7':'111001010010010','8':'010101010101010',
'9':'010101011001110','.':'000000000000010',',':'000000000010100','!':'010010010000010',"'":'010010000000000',
'-':'000000111000000',':':'000010000010000','?':'110001010000010',' ':'000000000000000','/':'001001010100100'}
fnt = bytearray()
for c in range(32, 91):
    g = FONT.get(chr(c), '0'*15)
    for r in range(5): fnt.append(sum(3 << (6-2*i) for i in range(3) if g[r*3+i] == '1'))
open(OUT+'/font.bin', 'wb').write(fnt)
rock = Cv(12, 8, G)
rock.ell(5.5, 3.5, 5, 3.4, B); rock.ell(5.5, 3.3, 4.2, 2.7, Y)
rock.px(7, 2, B); rock.px(4, 4, B); rock.px(8, 4, B); rock.line([(3, 6), (8, 6)], B)
rub = Cv(12, 8, G)
for (x, y) in ((1, 5), (5, 4), (9, 5)): rub.ell(x+1, y+1, 1.8, 1.4, B); rub.ell(x+1, y+1, 1.2, 0.9, Y)
open(OUT+'/rock.bin', 'wb').write(packrows(rock.rows())+packrows(rub.rows()))

# ---------------------------------------------------------------- music
CLK = 3546900
NOTE = {n: i for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}
def freq(n): return 440*2**((NOTE[n[:-1]]-9+12*(int(n[-1])-4))/12)
def rec(f, ms):
    T = CLK/f; tot = max(4, round((T-95)/26)); n1 = max(1, tot//4)
    return (n1, tot-n1, max(1, round(ms/1000*f)))
def tune(name, beat, notes, gap=0.3):
    s = name+':\n'
    for n, b in notes:
        if n:
            s += ' dw %d,%d,%d\n' % rec(freq(n), beat*b*(1-gap))
            s += ' dw 0,%d,0\n' % max(1, round(beat*b*gap/1000*CLK/26))
        else: s += ' dw 0,%d,0\n' % min(65535, round(beat*b/1000*CLK/26))
    return s+' dw $FFFF\n'
m = ''
m += tune('tune_title', 150, [('A4',1),('C5',1),('E5',2),('F5',1),('E5',1),('C5',2),('B4',1),('C5',1),('E5',1),('C5',1),('B4',2),('A4',2),
 ('A4',1),('C5',1),('E5',2),('F5',1),('E5',1),('A5',2),('F5',1),('E5',1),('C5',1),('B4',1),('A4',3),(None,1),
 ('E5',1),('E5',1),('F5',1),('E5',1),('C5',2),('B4',2),('C5',1),('B4',1),('A4',1),('F4',1),('E4',2),(None,2),
 ('A4',1),('B4',1),('C5',1),('E5',1),('F5',2),('E5',2),('C5',1),('B4',1),('A4',4)])
m += tune('tune_end', 170, [('E4',1),('A4',1),('B4',1),('C5',2),('B4',1),('A4',1),('E5',3),(None,1),
 ('F5',1),('E5',1),('C5',1),('B4',1),('A4',2),('C5',2),('B4',4),(None,1),
 ('A4',1),('C5',1),('E5',1),('A5',2),('G5',1),('F5',1),('E5',2),('C5',1),('E5',1),('F5',2),('E5',2),
 ('C5',1),('B4',1),('A4',1),('B4',1),('C5',2),('E5',2),('A5',6)])
m += tune('tune_stage', 120, [('E4',1),('A4',1),('E5',1),('A5',3)])
m += tune('tune_win', 110, [('A4',1),('C5',1),('E5',1),('A5',2)])
m += tune('tune_clear', 130, [('A4',1),('B4',1),('C5',1),('E5',1),('F5',1),('E5',1),('A5',3)])
m += tune('tune_lose', 200, [('E4',1),('C4',1),('B3',1),('A3',3)], 0.2)
BL = ['A4', 'B4', 'C5', 'E5', 'F5', 'A5', 'E4', 'F4']
m += 'bliptab:\n'+''.join(' dw %d,%d,%d\n' % rec(freq(n), 9) for n in BL)
for nm, f, ms in [('r_step', 1500, 2), ('r_thud', 110, 28), ('r_ko1', 420, 45), ('r_ko2', 280, 45), ('r_ko3', 150, 70),
                  ('r_gong', 98, 130), ('r_bow', 520, 18), ('r_blk', 900, 10), ('r_ctr', 1320, 22), ('r_heavy', 70, 40)]:
    m += '%s: dw %d,%d,%d\n' % ((nm,)+rec(f, ms))
open(OUT+'/music.asm', 'w').write(m)

# ---------------------------------------------------------------- text helpers
def tl(lines):
    """printlines table: (col,row,colour,text)"""
    b = bytearray()
    for c, r, col, t in lines:
        assert c+len(t) <= 32, t
        b += bytes([c, r, col])+t.encode()+b'\0'
    return bytes(b+b'\xff')
YEL, RED, GRN = 0x55, 0xFF, 0x00
def centre(t, row, col): return ((32-len(t))//2, row, col, t)

# ---------------------------------------------------------------- stages
# level: hp, cooldown, evade%, guard%, type, flags, entrance, damage bonus
COUNTER, RETREAT, FEINT, RHYTHM, HEAVY, BOSS = 1, 2, 4, 8, 16, 32
STAGES = [
 dict(art=stage1, foes=['keeper', 'keeper'], music=[1, 0, 0, 4, 0, 3, 0, 0, 1, 0, 2, 0, 0, 0, 7, 0],
      script=[(22, 0, 0), (62, 0, 1)],
      levels=[(8, 18, 5, 5, 0, 0, 0, 0), (8, 14, 15, 15, 0, 0, 0, 0)]),
 dict(art=stage2, foes=['guard', 'guard'], music=[4, 0, 5, 4, 0, 0, 3, 0, 2, 0, 0, 1, 0, 0, 7, 0],
      script=[(14, 0, 0), (42, 0, 1), (70, 0, 2)],
      levels=[(10, 13, 35, 25, 0, 0, 0, 0), (10, 11, 40, 30, 0, 0, 0, 0), (12, 9, 45, 35, 0, 0, 0, 0)]),
 dict(art=stage3, foes=['monk', 'monk'], music=[7, 0, 0, 0, 1, 0, 0, 0, 7, 0, 0, 0, 3, 0, 2, 0],
      script=[(52, 0, 0)],
      levels=[(12, 10, 15, 60, 0, COUNTER, 1, 0)],
      cut=(scene_kuro, [centre("KUROKAGE: SO THE BOY CROSSED", 43, YEL), centre("MY COURT? LET THE LANTERN MONK", 50, YEL),
                        centre("TEACH HIM PATIENCE.", 57, RED)])),
 dict(art=stage4, foes=['scout', 'scout'], music=[1, 0, 2, 0, 4, 0, 2, 0, 1, 0, 2, 0, 7, 0, 8, 0],
      script=[(4, 1, 0), (46, 2, 0), (64, 0, 0)],
      levels=[(10, 7, 50, 20, 0, RETREAT, 2, 0)]),
 dict(art=stage5, foes=['guard', 'oni'], music=[7, 0, 0, 7, 0, 0, 1, 0, 7, 0, 0, 7, 0, 0, 2, 0],
      script=[(40, 0, 0), (40, 0, 1), (40, 0, 2)],
      levels=[(8, 11, 40, 30, 0, 0, 0, 0), (8, 9, 45, 35, 0, 0, 0, 0), (22, 12, 10, 30, 1, HEAVY, 3, 1)]),
 dict(art=stage6, foes=['kuro', 'kuro'], music=[1, 0, 0, 7, 0, 0, 1, 0, 3, 0, 0, 2, 0, 0, 7, 0],
      script=[(40, 0, 0)],
      levels=[(20, 8, 45, 40, 0, FEINT | RHYTHM | BOSS, 4, 0)],
      cut=(scene_cage, [centre("MASTER HOSHI HANGS ABOVE THE", 43, YEL), centre("SUMMIT. KUROKAGE WAITS.", 50, YEL),
                        centre("NO MORE GUARDS. NO MORE TRICKS.", 57, RED)])),
]
PARTS = {1: 1, 2: 1, 3: 0, 4: 2, 5: 3, 6: 0}
previews = []
for n, sd in enumerate(STAGES, 1):
    st = sd['art']()
    # foes file: type 0 at +4, type 1 at +4100 (SRAM $4000 / $5000)
    f0 = fb([mirror(f) for f in frames(STYLES[sd['foes'][0]])])
    f1 = fb([mirror(f) for f in frames(STYLES[sd['foes'][1]])])
    foes = bytearray(4)+f0+bytes(4100-4-len(f0))+f1
    open('%s/TGFOES%d.DAT' % (SD, n), 'wb').write(seal(foes, 'F', n, 16))
    # stage pack
    p = bytearray(32); off = 32
    def put(data):
        global off
        a = PACK+len(p); p.extend(data); return a
    def w16(at, v): p[at] = v & 255; p[at+1] = v >> 8
    w16(11, put(bytes(b for e in sd['script'] for b in e)+b'\xff'))
    w16(13, put(bytes(b for l in sd['levels'] for b in l)))
    w16(21, put(bytes(sd['music'])+b'\xff'))
    p[10] = MW-32; p[23] = PARTS[n]
    # animation frames, then table
    ent = []
    for a in st.anims:
        fa = put(b''.join(a['frames']))
        stride = FW if a['layer'] == 'far' else MW
        ent.append((a, fa, stride))
    far = packrows(st.farrows); mid = packrows(st.midrows)
    fl = b''.join(packrows(ph) for ph in st.floor)
    fa_ = put(far); ma_ = put(mid); w16(4, fa_); w16(6, ma_); w16(8, put(fl))
    tab = bytearray()
    for a, fa, stride in ent:
        base = fa_ if a['layer'] == 'far' else ma_
        tgt = base+a['row']*stride+a['bx']
        pm = a['period']
        pmask = {1: 0, 3: 3, 7: 7, 15: 15}.get(pm, pm)
        tab += bytes([tgt & 255, tgt >> 8, stride-a['wb'], a['wb'], a['h'], len(a['frames']), pmask,
                      fa & 255, fa >> 8, a['top'], a['phase'] & 255, a['wb']*a['h']])
    tab += b'\0\0'
    w16(15, put(bytes(tab)))
    if 'cut' in sd:
        img, txt = sd['cut']
        w16(17, put(packrows(img().rows()))); w16(19, put(tl(txt)))
    print('stage %d pack %d bytes, %d anims' % (n, len(p), len(st.anims)))
    open('%s/TGSTAGE%d.DAT' % (SD, n), 'wb').write(seal(p, 'G', n, 16))
    previews.append(st)

# front: title + opening scene
fr = bytearray(256)+packrows(title().rows())+packrows(scene_open().rows())
open(SD+'/TGFRONT.DAT', 'wb').write(seal(fr, 'R', 0, 7))
# end: ending scene + cast frames
cast = [mirror(frames(STYLES[k])[pidx('FIGHT1')]) for k in ('keeper', 'guard', 'monk', 'scout', 'oni', 'kuro')]
en = bytearray(256)+packrows(scene_end().rows())+fb(cast)
open(SD+'/TGEND.DAT', 'wb').write(seal(en, 'E', 0, 6))
print('gen ok')
