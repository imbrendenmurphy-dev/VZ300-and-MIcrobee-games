#!/usr/bin/env python3
"""build.py - generate assets, assemble, package ZEPHYR.VZ + ZZ*.DAT"""
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(__file__))
import tables, creatures as CR, hero as HE, pano
from spritepack import to_bytes, trim
from geom import LEV_S, NLEV
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'src'); GEN = os.path.join(SRC, 'gen'); BUILD = os.path.join(ROOT, 'build')
SD = os.path.join(BUILD, 'sd')
os.makedirs(GEN, exist_ok=True); os.makedirs(SD, exist_ok=True)

def chunk(m, dest, data):
    return bytes([m, dest & 255, dest >> 8, len(data) & 255, len(data) >> 8]) + bytes(data)
BUILD_ID = 0
DAT_ID = None
def datfile(name, chunks):
    if DAT_ID is not None:                       # stamp: this build's id -> dat_id
        chunks = list(chunks) + [chunk(3, DAT_ID, bytes([BUILD_ID & 255, BUILD_ID >> 8]))]
    d = b''.join(chunks) + b'\0'
    d += b'\0' * ((-len(d)) % 512)
    open(os.path.join(SD, name + '.DAT'), 'wb').write(d)
    print('%-6s.DAT %6d bytes' % (name, len(d)))

def key_for(g):
    used = {c for r in g for c in r if c >= 0}
    if 0 not in used: return 0
    if 2 not in used: return 2
    raise ValueError('sprite uses all four colours')

def record(g, ax, ay, ph):
    g, ax, ay = trim(g, ax, ay)
    k = key_for(g)
    b = to_bytes(g, ax, ay, ph)          # (wb, h, ax, ay) + (mask, data) pairs
    wb, h = b[0], b[1]
    assert wb <= 16, 'sprite too wide'
    data = bytes(b[5 + 2 * i] for i in range(wb * h))
    # data with transparent pixels in the key colour
    out = bytearray()
    for i in range(wb * h):
        m, d = b[4 + 2 * i], b[5 + 2 * i]
        v = d
        for j in range(4):
            sh = 6 - 2 * j
            if (m >> sh) & 3: v = (v & ~(3 << sh)) | (k << sh)
        out.append(v)
    return bytes([wb, h, b[2], b[3], k]) + bytes(out)

class SpriteBank:
    """directory (4 bytes/type) + frame tables + records, laid out from 'base'"""
    def __init__(self, base, ntypes, dir_addr=None, single=()):
        self.base = base; self.types = []; self.ntypes = ntypes
        self.dir_addr = dir_addr; self.single = set(single)
    def add(self, frames):   # frames[f][lev] = grid with anchor at bottom centre (ax, ay given)
        self.types.append(frames)
    def build(self):
        dirsz = 0 if self.dir_addr is not None else 4 * self.ntypes
        ft_size = sum(2 * len(fr) for fr in self.types)
        lt_size = sum(4 * len(fr) * len(fr[0]) for fr in self.types)
        recs = bytearray(); dirb = bytearray(); ftb = bytearray(); ltb = bytearray()
        ft_base = self.base + dirsz
        lt_base = ft_base + ft_size
        rec_base = lt_base + lt_size
        cache = {}
        for ti, fr in enumerate(self.types):
            dirb += bytes([(ft_base + len(ftb)) & 255, (ft_base + len(ftb)) >> 8, len(fr), len(fr[0])])
            for lv in fr:
                la = lt_base + len(ltb)
                ftb += bytes([la & 255, la >> 8])
                for (g, ax, ay) in lv:
                    key = (tuple(map(tuple, g)), ax, ay)
                    if key not in cache:
                        a0 = rec_base + len(recs); r0 = record(g, ax, ay, 0); recs += r0
                        if ti in self.single: a1 = a0
                        else: a1 = rec_base + len(recs); r1 = record(g, ax, ay, 2); recs += r1
                        cache[key] = (a0, a1)
                    a0, a1 = cache[key]
                    ltb += bytes([a0 & 255, a0 >> 8, a1 & 255, a1 >> 8])
        dirb += bytes(4 * (self.ntypes - len(self.types)))
        if self.dir_addr is not None: return bytes(dirb), bytes(ftb) + bytes(ltb) + bytes(recs)
        return bytes(dirb) + bytes(ftb) + bytes(ltb) + bytes(recs)

LEVCLAMP = {'spark': (3, 9), 'blobbit': (2, 11), 'spindle': (2, 11), 'hopcap': (2, 11), 'boom': (2, 11), 'orb': (2, 11), 'fireball': (2, 11), 'flame': (2, 11), 'wyrmhead': (3, 9), 'wyrmbody': (3, 9), 'wyrmtail': (3, 9), 'bush': (2, 11), 'sandray': (2, 11), 'cactoid': (2, 11), 'sundisc': (2, 11), 'rock': (2, 11), 'totemcore': (3, 9), 'firepod': (3, 9), 'podlink': (3, 9), 'glowmoth': (2, 11), 'prism': (2, 11), 'jellybell': (2, 11), 'glowcap': (2, 11), 'gemrock': (2, 11), 'shardhead': (3, 9), 'shardbody': (3, 9), 'shardtail': (3, 9), 'dartjet': (2, 11), 'copsaucer': (2, 11), 'gunmech': (3, 10), 'barrier': (2, 11), 'mechhead': (4, 9), 'gunpod': (3, 9), 'stoneface': (3, 11), 'dragonfly': (3, 11), 'snailops': (3, 10), 'puffballs': (2, 11), 'pedehead': (3, 9), 'pedebody': (3, 9), 'pedetail': (3, 9), 'tower': (2, 10), 'toadstool': (2, 10)}
def obj_frames(name, far_static=6):
    fn, nf, w, h = CR.OBJECTS[name]
    kmin, kmax = LEVCLAMP.get(name, (1, NLEV))
    out = []
    for f in range(nf):
        lv = []
        for k0 in range(1, NLEV + 1):
            k = max(kmin, min(kmax, k0))
            ff = f if k <= far_static else 0
            g = CR.render(name, ff, LEV_S[k] if k < len(LEV_S) else LEV_S[-1] * 0.78)
            lv.append((g, len(g[0]) // 2, len(g) - 1))
        out.append(lv)
    return out

def common():
    sb = SpriteBank(0xC800, 16, single=(6, 7))
    hero = [[(g, len(g[0]) // 2, len(g) - 1)] for n, g in HE.build()]
    sb.add(hero)
    for n in ('bolt', 'fireball', 'boom', 'shadow', 'orb'):
        sb.add(obj_frames(n))
    import font70
    za, zb = font70.logo_lines()
    W = len(za[0]); ox = (W - len(zb[0])) // 2
    combo = [r[:] for r in za] + [[-1] * ox + r + [-1] * (W - ox - len(r)) for r in zb]
    half = (W // 2) & ~3
    zl = [r[:half] for r in combo]; zr = [r[half:] for r in combo]
    # anchors: both drawn at (64, 7) = top of the logo, split point centred
    sb.add([[(zl, half, 0)]])                       # 6: logo left
    sb.add([[(zr, 0, 0)]])                          # 7: logo right
    for n in ('spark', 'flame'):                    # 8, 9
        sb.add(obj_frames(n))
    blob = sb.build()
    assert 0xC800 + len(blob) <= 0xF000, 'common sprites overflow $%04X' % (0xC800 + len(blob))
    print('common sprites $C800-$%04X' % (0xC800 + len(blob)))
    t = tables
    b3 = t.mask_tables() + t.proj_tables()
    global COMCHUNKS
    import speech
    send = tables.STRIPS + len(tables.ground()[1])
    sp, dly, fs = speech.build(0x6800 - send)
    open(os.path.join(GEN, 'speech.inc'), 'w').write('SPEECH equ $%04X\nSPEECH_END equ $%04X\nSPEECH_DLY equ %d\n' % (send, send + len(sp), dly))
    print('speech %d bytes at $%04X (%d Hz)' % (len(sp), send, fs))
    COMCHUNKS = chunk(3, send, sp) + chunk(3, 0x4000, b3) + chunk(7, 0xFC00, t.sq_tables()) + chunk(3, 0xC800, blob)
    open(os.path.join(BUILD, 'comchunks.bin'), 'wb').write(COMCHUNKS)

WORLDS = {
    1: dict(css=0, sky=2, ground=(0, 1), style='checker', pano='world1',
            objs=['lolly', 'column', 'bush', 'blobbit', 'spindle', 'hopcap', 'wyrmhead', 'wyrmbody', 'wyrmtail']),
    2: dict(css=1, sky=1, ground=(0, 2), style='bands', pano='world2',
            objs=['saguaro', 'obelisk', 'rock', 'sandray', 'sundisc', 'cactoid', 'totemcore', 'firepod', 'podlink']),
    3: dict(css=0, sky=3, ground=(1, 2), style='grid', pano='world3',
            objs=['spire', 'gemrock', 'glowcap', 'glowmoth', 'prism', 'jellybell', 'shardhead', 'shardbody', 'shardtail']),
    4: dict(css=1, sky=3, ground=(1, 2), style='grid', seam=0, pano='world4',
            objs=['tower', 'neonsign', 'barrier', 'dartjet', 'copsaucer', 'gunmech', 'mechhead', 'gunpod', 'podlink']),
    5: dict(css=0, sky=1, ground=(0, 2), style='checker', pano='world5',
            objs=['toadstool', 'mosspillar', 'puffballs', 'stoneface', 'dragonfly', 'snailops', 'pedehead', 'pedebody', 'pedetail']),
}
def world(n):
    w = WORLDS[n]
    A, Bc = w['ground']
    grow, strips, end = tables.ground(A, Bc, w['sky'], w.get('style', 'checker'), w.get('seam', 0))
    # the world module (boss code, timeline, tunes) at W_CODE = $B848
    src = os.path.join(SRC, 'w%d.asm' % n); binf = os.path.join(BUILD, 'w%d.bin' % n)
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'zasm.py'), src, '-o', binf,
                        '--sym', os.path.join(BUILD, 'w%d.sym' % n), '--start', '0xB848'], capture_output=True, text=True)
    if r.returncode: print(r.stdout, r.stderr); sys.exit(1)
    code = open(binf, 'rb').read()
    base = 0xB848 + len(code)
    sb = SpriteBank(base, 16, dir_addr=0xB808)
    for o in w['objs']: sb.add(obj_frames(o))
    dirb, blob = sb.build()
    pano_addr = base + len(blob)
    pb = pano.pack(getattr(pano, w['pano'])())
    end1 = pano_addr + len(pb)
    assert end1 <= 0xFC00, 'world %d overflows upper bank 1 ($%04X)' % (n, end1)
    skyb = w['sky'] * 0x55
    hdr = bytes([w['css'], skyb, pano_addr & 255, pano_addr >> 8, len(w['objs']), 0, 0, 0])
    print('world %d: code $B848-$%04X, sprites to $%04X, panorama to $%04X (%d free)' % (n, base - 1, pano_addr - 1, end1 - 1, 0xFC00 - end1))
    datfile('ZZW%d' % n, [chunk(7, tables.GROW, grow + bytes(tables.STRIPS - tables.GROW - len(grow)) + strips),
                          chunk(7, 0xB800, hdr + dirb + code + blob + pb)])

def finale():
    """ZZEND.DAT: the finale module at $B800 and its picture at $E000 (upper bank 1)"""
    import endpic, sound
    src = os.path.join(SRC, 'ending.asm'); binf = os.path.join(BUILD, 'ending.bin')
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'zasm.py'), src, '-o', binf,
                        '--sym', os.path.join(BUILD, 'ending.sym'), '--start', '0xB800'], capture_output=True, text=True)
    if r.returncode: print(r.stdout, r.stderr); sys.exit(1)
    code = open(binf, 'rb').read()
    print('finale: code $B800-$%04X, picture $E000-$E7FF' % (0xB800 + len(code) - 1))
    datfile('ZZEND', [chunk(7, 0xB800, code), chunk(7, 0xE000, endpic.pack(endpic.picture()))])

def mainsym():
    out = ['; generated: main program symbols for the world modules']
    for l in open(os.path.join(BUILD, 'zephyr.sym')):
        a, n = l.split()
        if '.' in n: continue
        out.append('%s equ $%s' % (n, a))
    open(os.path.join(BUILD, 'mainsym.inc'), 'w').write('\n'.join(out) + '\n')

def assemble():
    binf = os.path.join(BUILD, 'zephyr.bin')
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'zasm.py'), os.path.join(SRC, 'main.asm'), '-o', binf,
                        '--sym', os.path.join(BUILD, 'zephyr.sym'), '--lst', os.path.join(BUILD, 'zephyr.lst'),
                        '--start', '0x8000', '--end', '0xC800'], capture_output=True, text=True)
    print(r.stdout.strip(), r.stderr.strip())
    if r.returncode: sys.exit(1)
    full = open(binf, 'rb').read()
    sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(BUILD, 'zephyr.sym'))}
    global DAT_ID
    DAT_ID = sym['dat_id']
    data = full[:sym['code_end'] - 0x8000]
    fe = full[0xB800 - 0x8000:sym['fe_end'] - 0x8000]
    print('main code $8000-$%04X (%d free), front end $B800-$%04X (%d free)' % (sym['code_end'] - 1, sym['VARS'] - sym['code_end'], sym['fe_end'] - 1, 0xC800 - sym['fe_end']))
    # the front end rides in ZZCOM.DAT (mapping 3 -> upper bank 0)
    datfile('ZZCOM', [COMCHUNKS, chunk(3, 0xB800, fe)])
    hdr = b'VZF0' + b'ZEPHYR ZONE'.ljust(17, b'\0') + bytes([0xF1, 0x00, 0x80])
    open(os.path.join(SD, 'ZEPHYR.VZ'), 'wb').write(hdr + data)
    print('ZEPHYR.VZ: %d bytes, $8000-$%04X' % (len(data), 0x8000 + len(data) - 1))

COMCHUNKS = b''
def gen_src():
    import font, sound
    open(os.path.join(GEN, 'font.inc'), 'w').write(font.asm())
    import font70
    open(os.path.join(GEN, 'font70.inc'), 'w').write(font70.asm())
    open(os.path.join(GEN, 'sound.inc'), 'w').write(sound.asm())
    import speech
    rd, _, _ = speech.build_phrase(speech.GET_READY)
    open(os.path.join(GEN, 'ready.inc'), 'w').write('; "GET READY!" (tools/speech.py)\nready_snd:\n' +
        ''.join('            db ' + ','.join(str(x) for x in rd[i:i + 24]) + '\n' for i in range(0, len(rd), 24)) + 'ready_end:\n')
    for n in sound.WORLD_TUNES: open(os.path.join(GEN, 'tunes_w%d.inc' % n), 'w').write(sound.world_asm(n))

if __name__ == '__main__':
    gen_src()
    import time
    BUILD_ID = (int(time.time()) & 0xFFFF) | 1
    open(os.path.join(GEN, 'buildid.inc'), 'w').write('BUILD_ID    equ $%04X\n' % BUILD_ID)
    if os.path.exists(os.path.join(BUILD, 'comchunks.bin')): COMCHUNKS = open(os.path.join(BUILD, 'comchunks.bin'), 'rb').read()
    if '--noart' not in sys.argv: common()
    assemble()
    mainsym()
    for n in WORLDS: world(n)
    import titlepic
    datfile('ZZTTL', [chunk(7, 0xB800, titlepic.packed())])
    finale()
