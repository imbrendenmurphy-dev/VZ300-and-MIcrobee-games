#!/usr/bin/env python3
# TRANSCENDENCE build: generates data.asm (tables, music, models), assembles, wraps .VZ
import math, subprocess, sys, os, random
os.chdir(os.path.dirname(os.path.abspath(__file__)))
import music

TI = float(os.environ.get('TI', '360'))      # sound tick interval (T-states), measured
CPU = 3546894.0
RATE = CPU / TI

out = []
def db(label, data, per=16):
    out.append(f'{label}:' if label else '')
    for i in range(0, len(data), per):
        out.append('        db ' + ','.join(str(x & 255) for x in data[i:i+per]))
def dw(label, data, per=12):
    out.append(f'{label}:')
    for i in range(0, len(data), per):
        out.append('        dw ' + ','.join(str(x & 65535) for x in data[i:i+per]))
def align():
    out.append('        align 256')

# ---- page aligned tables
align()
db('SINTAB', [int(round(127*math.sin(2*math.pi*i/256))) for i in range(256)])
align()
db('RTAB', [min(255, int(4096/max(z,1))) for z in range(256)])
align()
random.seed(7)
# 1D fractal mountains (wrapping), 0..20
pts = [0.0]*256
for octave,amp in [(64,9),(32,5),(16,3),(8,1.6),(4,0.8)]:
    ctrl = [random.random() for _ in range(256//octave)]
    for i in range(256):
        a = i//octave; f = (i % octave)/octave
        v0 = ctrl[a % len(ctrl)]; v1 = ctrl[(a+1) % len(ctrl)]
        f = f*f*(3-2*f)
        pts[i] += amp*(v0 + (v1-v0)*f)
mn, mx = min(pts), max(pts)
db('MTN', [int(round((p-mn)/(mx-mn)*20)) for p in pts])
# quarter squares 0..511
align()
db('SQL', [(i*i//4) & 255 for i in range(512)])
db('SQH', [(i*i//4) >> 8 for i in range(512)])
# circle half widths, aspect 1.5 (mode 0 pixels are 2:3)
cw = []
for r in range(0, 56):
    for dy in range(0, r+1):
        cw.append(int(round(1.5*math.sqrt(max(0, r*r - dy*dy + 0.3*r)))) if r else 0)
db('CIRCW', cw)
offs = []; o = 0
for r in range(56): offs.append(o); o += r + 1
out.append('CIRCOFF:')
out.append('        dw ' + ','.join('CIRCW+%d' % x for x in offs))
# note increments
freq = []
for n in range(96):
    f = 32.703 * 2 ** (n/12.0)
    freq.append(min(65535, int(round(f*65536/RATE))))
dw('FREQ', freq)
# envelopes: kind(0 decay,1 swell), A, S, step, per
db('ENVTAB', sum(music.ENVS, []), 5)
# drums: frames, duty, inc
def inc(f): return int(round(f*65536/RATE))
drums = [(6,128,inc(240)), (1,34,0), (4,70,0), (10,120,inc(95)), (3,40,0)]
dd = []
for fr,du,i in drums: dd += [fr, du, i & 255, i >> 8]
db('DRUMTAB', dd, 4)
# geometric profile (terraced pyramids) and flight scale table
out.append('        align 256')
db('GEO', [min(20, (abs((i % 40) - 20)//4)*5) for i in range(256)])
dw('SCL', [min(65535, int(round(3*256*16/max(i, 8)))) for i in range(256)])
# tunnel tables: 48x24 cells, centre (24,12); cells are 2:3 (w:h)
TA = []; TD = []
for y in range(24):
    for x in range(48):
        dx = (x - 24 + 0.5)*2.0; dy = (y - 12 + 0.5)*3.0
        TA.append(int(round(math.atan2(dy, dx)/(2*math.pi)*256)) & 255)
        dist = math.hypot(dx, dy)
        TD.append(int(round(900.0/(dist + 2.0))) & 255)
db('TA', TA)
db('TD', TD)
def C(c): return 0x80 | (c << 4)
G,Y,B,R,BF,CY,MG,OR = range(8)
def pal(seq):
    out = []
    while len(out) < 32: out += seq
    return [C(c) for c in out[:32]]
TPALS = (pal([B,B,CY,B,MG,B,CY,BF]) + pal([B,MG,MG,R,MG,B,B,CY]) + pal([R,OR,OR,Y,OR,R,MG,R])
         + pal([R,OR,Y,G,CY,B,MG,R]) + pal([BF,Y,CY,BF,Y,BF,CY,G]))
db('TPALS', TPALS)
PATS = []
for s in range(5):
    for i in range(16):
        a, d = i & 3, i >> 2
        if s == 0: m = [0xF, 0xC, 0x0, 0x3][d]
        elif s == 1: m = 0xF if (a ^ d) & 1 else [0x0, 0x9, 0x0, 0x6][d]
        elif s == 2: m = [0xF, 0xF, 0xC, 0x0][(a + d) & 3]
        elif s == 3: m = [0xF, 0xF, 0xF, 0x9][(a + d) & 3]
        else: m = 0xF
        PATS.append(m)
db('PATS', PATS)
db('FONT', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 5, 2, 5, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 2, 1, 1, 2, 4, 4, 7, 5, 5, 5, 7, 2, 6, 2, 2, 7, 6, 1, 2, 4, 7, 6, 1, 2, 1, 6, 5, 5, 7, 1, 1, 7, 4, 6, 1, 6, 3, 4, 7, 5, 7, 7, 1, 2, 2, 2, 7, 5, 7, 5, 7, 7, 5, 7, 1, 6, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 5, 7, 5, 5, 6, 5, 6, 5, 6, 3, 4, 4, 4, 3, 6, 5, 5, 5, 6, 7, 4, 6, 4, 7, 7, 4, 6, 4, 4, 3, 4, 5, 5, 3, 5, 5, 7, 5, 5, 7, 2, 2, 2, 7, 1, 1, 1, 5, 2, 5, 5, 6, 5, 5, 4, 4, 4, 4, 7, 5, 7, 7, 5, 5, 6, 5, 5, 5, 5, 2, 5, 5, 5, 2, 6, 5, 6, 4, 4, 2, 5, 5, 6, 3, 6, 5, 6, 5, 5, 3, 4, 2, 1, 6, 7, 2, 2, 2, 2, 5, 5, 5, 5, 7, 5, 5, 5, 5, 2, 5, 5, 7, 7, 5, 5, 5, 2, 5, 5, 5, 5, 2, 2, 2, 7, 1, 2, 4, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
# smoothstep table (page aligned)
out.append('        align 256')
db('SMOOTH', [int(round(255*(x/255)**2*(3-2*x/255))) for x in range(256)])
import scenes
for nm in ('CAM3', 'CAM4', 'CAM5'):
    db(nm, getattr(scenes, nm), 13)
# songs
s1, s2 = music.compile_song()
db('SONG1', s1)
db('SONG2', s2)
open('data.asm','w').write('\n'.join(out)+'\n')
# ---- bank-3 assets (loaded from SD into SRAM bank 3 at $4000)
import models
out = []
Dp = 150
db('PTAB', [min(255, max(1, int(round(128*Dp/(Dp - (z-128)))))) for z in range(256)])
ptrs, blob = models.templates(9)
dw('TPTR', ptrs)
db('TBLOB', blob)
keys = []
segs = {}
for nm, seg in (('LY', models.LYING), ('RI', models.RISING), ('TC', models.TAICHI), ('SE', models.SETTLE)):
    segs[nm] = (len(keys), len(seg)); keys += seg
out.append('KEYS:')
kb = models.to_bytes_keys(keys)
for i in range(0, len(kb), 48):
    out.append('        db ' + ','.join(str(x) for x in kb[i:i+48]))
for nm, (st, n) in segs.items():
    out.append(f'K_{nm} equ KEYS+{st*48}')
    out.append(f'N_{nm} equ {n}')
sp = []
for a_, b_, t_, r_ in models.SPH: sp += [models.JI[a_], models.JI[b_], t_, r_]
out.append(f'NSPHT equ {len(models.SPH)}')
db('SPHT', sp, 4)
ft = []
for a_, b_, c_, r_, k_ in models.FEAT: ft += [a_ & 255, b_ & 255, c_ & 255, r_, k_]
out.append(f'NFEAT equ {len(models.FEAT)}')
db('FEATT', ft, 5)
open('assets.asm','w').write('\n'.join(out)+'\n')

print('music bytes', len(s1), len(s2))

# ---- preprocess: each TICK site -> call sndK (K from measured timing) + label
import json, glob, re
os.makedirs('build', exist_ok=True)
def preprocess():
    try: kt = json.load(open('ticks.json'))
    except Exception: kt = {}
    site = 0; maps = {}
    for fn in sorted(glob.glob('*.asm')):
        src = open(fn).read().split('\n'); dst = []; mp = []
        for i, ln in enumerate(src):
            if re.match(r'^\s*(\.?\w+:)?\s*TICK\s*(;.*)?$', ln):
                lab = re.match(r'^\s*(\.?\w+:)', ln)
                if lab: dst.append(lab.group(1)); mp.append(i)
                k = kt.get(str(site), 1)
                dst.append(f'        call {"snd" if k == 1 else "snd%d" % k}'); mp.append(i)
                dst.append(f'.TK{site}:'); mp.append(i)
                site += 1
            else:
                dst.append(ln); mp.append(i)
        open('build/' + fn, 'w').write('\n'.join(dst)); maps[fn] = mp
    return site, maps
dbg = os.environ.get('DBG')   # e.g. DBG=44:ch_encounter
open('dbg.asm','w').write(('  define DBGBAR %s\n  define DBGCH %s\n' % tuple(dbg.split(':'))) if dbg else '')
for attempt in range(12):
    nsites, maps = preprocess()
    r = subprocess.run(['sjasmplus', '--nologo', '--msg=war', '--lst=../demo.lst', '--outprefix=../', 'main.asm'], capture_output=True, text=True, cwd='build')
    errs = re.findall(r'(\w+\.asm)\((\d+)\): error: \[(JR|DJNZ)\] Target out of range', r.stdout + r.stderr)
    fixed = False
    for fn, ln, kind in errs:
        sl = maps[fn][int(ln)-1]
        src = open(fn).read().split('\n')
        if kind == 'JR':
            new_l = re.sub(r'\bjr\b', 'jp', src[sl], count=1)
        else:
            new_l = re.sub(r'\bdjnz\s+(\S+)', r'dec b\n        jp nz,\1', src[sl], count=1)
        if new_l != src[sl]:
            src[sl] = new_l; open(fn, 'w').write('\n'.join(src)); fixed = True
    if not fixed: break
print('tick sites', nsites)
print(r.stdout[-3000:], r.stderr[-3000:])
if r.returncode: sys.exit(1)
code = open('demo.bin','rb').read()
bank = open('bank3.bin','rb').read()
ldr = open('loader.bin','rb').read()
open('TRANSCN1.DAT','wb').write(code)
open('TRANSCN2.DAT','wb').write(bank)
hdr = b'VZF0' + b'TRANSCEND'.ljust(16, b'\0') + b'\0' + bytes([0xF1, 0x00, 0xF0])
open('TRANSCND.VZ','wb').write(hdr + ldr)
end = 0x8000 + len(code)
print(f'TRANSCN1.DAT {len(code)} bytes $8000-${end-1:04X} | TRANSCN2.DAT {len(bank)} bytes $4000-${0x4000+len(bank)-1:04X} | loader {len(ldr)}')
assert end <= 0xE800, 'program overlaps the back buffer'
assert len(bank) <= 0x2800, 'bank 3 overflow'
# emulator image: loader skipped, both DATs preloaded, start $8000
img = bytearray(b'VZF0' + b'TEST'.ljust(16, b'\0') + b'\0' + bytes([0xF1, 0x00, 0x40]))
mem = bytearray(0x8000 - 0x4000 + len(code))
mem[0:len(bank)] = bank
mem[0x4000:] = code
for i in range(len(bank), 0x2800): mem[i] = 0
# jump stub at $6000? no: start address must be load address -> put JP $8000 at $67FD region? use first bytes trick:
img += mem
open('emu.vz','wb').write(img)
