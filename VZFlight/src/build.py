"""Build the VZ flight sim: generate tables + templated code, assemble, write VZFLIGHT.VZ"""
import math, json, re, os, sys
from z80asm import Asm

HERE = os.path.dirname(os.path.abspath(__file__))

# ------------------------------------------------------------------ font
CH = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -+.!:/,#'?()<>%=^*"
GLY = """
0:###,#.#,#.#,#.#,###
1:.#.,##.,.#.,.#.,###
2:###,..#,###,#..,###
3:###,..#,###,..#,###
4:#.#,#.#,###,..#,..#
5:###,#..,###,..#,###
6:###,#..,###,#.#,###
7:###,..#,..#,..#,..#
8:###,#.#,###,#.#,###
9:###,#.#,###,..#,###
A:###,#.#,###,#.#,#.#
B:##.,#.#,##.,#.#,##.
C:###,#..,#..,#..,###
D:##.,#.#,#.#,#.#,##.
E:###,#..,##.,#..,###
F:###,#..,##.,#..,#..
G:###,#..,#.#,#.#,###
H:#.#,#.#,###,#.#,#.#
I:###,.#.,.#.,.#.,###
J:..#,..#,..#,#.#,###
K:#.#,#.#,##.,#.#,#.#
L:#..,#..,#..,#..,###
M:#.#,###,###,#.#,#.#
N:##.,#.#,#.#,#.#,#.#
O:###,#.#,#.#,#.#,###
P:###,#.#,###,#..,#..
Q:###,#.#,#.#,###,..#
R:##.,#.#,##.,#.#,#.#
S:.##,#..,.#.,..#,##.
T:###,.#.,.#.,.#.,.#.
U:#.#,#.#,#.#,#.#,###
V:#.#,#.#,#.#,#.#,.#.
W:#.#,#.#,###,###,#.#
X:#.#,#.#,.#.,#.#,#.#
Y:#.#,#.#,.#.,.#.,.#.
Z:###,..#,.#.,#..,###
 :...,...,...,...,...
-:...,...,###,...,...
+:...,.#.,###,.#.,...
.:...,...,...,...,.#.
!:.#.,.#.,.#.,...,.#.
::...,.#.,...,.#.,...
/:..#,..#,.#.,#..,#..
,:...,...,...,.#.,#..
#:###,###,###,###,###
':.#.,.#.,...,...,...
?:###,..#,.##,...,.#.
(:..#,.#.,.#.,.#.,..#
):#..,.#.,.#.,.#.,#..
<:..#,.#.,#..,.#.,..#
>:#..,.#.,..#,.#.,#..
%:#.#,..#,.#.,#..,#.#
=:...,###,...,###,...
^:.#.,###,#.#,.#.,.#.
*:#.#,.#.,###,.#.,#.#
"""
FONT = {}
for line in GLY.strip('\n').split('\n'):
    c, rows = line[0], line[2:].split(',')
    FONT[c] = [sum((0xC0 >> (2 * i)) for i in range(3) if r[i] == '#') for r in rows]


def text_codes(s):
    return [CH.index(c) for c in s]


def dbs(vals, per=16):
    out = []
    for i in range(0, len(vals), per):
        out.append('        db ' + ','.join(str(v & 255) for v in vals[i:i + per]))
    return '\n'.join(out)


def dws(vals, per=8):
    out = []
    for i in range(0, len(vals), per):
        out.append('        dw ' + ','.join(str(v & 0xFFFF) for v in vals[i:i + per]))
    return '\n'.join(out)


# ------------------------------------------------------------------ data
CHNAMES = {' ': 'sp', '/': 'slash', ':': 'colon', '.': 'dot', '%': 'pct', '<': 'lt', '>': 'gt', '^': 'up',
           '+': 'plus', '-': 'minus', '*': 'star', 'G': 'g', 'K': 'k'}


def tx(s):
    """text -> list of byte values terminated by $ff"""
    return text_codes(s) + [255]


def txm(lines):
    out = []
    for i, l in enumerate(lines):
        if i:
            out.append(254)
        out += text_codes(l)
    return out + [255]


CLOCK = 3546900


def note(name):
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[n] + 12 * (o - 4)) / 12.0)


def tune(notes, loop=True, blip_t=17000):
    """notes: list of (name or 'R', fields). bytes: period, half-cycles, fields"""
    out = []
    for nm, dur in notes:
        if nm == 'R':
            out += [1, 1, dur]
            continue
        half = CLOCK / (2 * note(nm))
        n = int(round((half - 32) / 16))
        assert 2 <= n <= 254, (nm, n)
        cyc = max(4, min(255, int(blip_t / (16 * n + 32))))
        out += [n, cyc, dur]
    out.append(255 if loop else 0)
    return out


def tunes():
    q, e, h = 16, 8, 32
    title = [('G5', e), ('B5', e), ('D6', q), ('B5', e), ('D6', e), ('E6', q), ('D6', q), ('B5', h),
             ('C6', e), ('E6', e), ('G6', q), ('E6', e), ('C6', e), ('D6', q), ('B5', q), ('A5', h),
             ('G5', e), ('B5', e), ('D6', q), ('G6', e), ('F#6', e), ('E6', q), ('D6', e), ('C6', e), ('B5', q),
             ('A5', q), ('G5', e), ('A5', e), ('B5', q), ('A5', q), ('F#5', q), ('G5', h), ('R', h)]
    gate = [('D6', 5), ('G6', 8)]
    done = [('G5', 6), ('B5', 6), ('D6', 6), ('G6', 12), ('D6', 6), ('G6', 30)]
    return dict(tune_title=tune(title), tune_gate=tune(gate, False, 9000), tune_done=tune(done, False, 12000))


def page_scripts():
    import pics
    o = {}
    V = lambda r, c=0: 'vram+%d*32+%d' % (r, c)

    def T(r, c, ink, text):          # left-aligned text
        assert c + len(text) <= 31, text
        return [('db', 1), ('dw', V(r, c)), ('db', ink), ('db', tx(text))]

    def C(r, ink, text):             # centred text
        assert len(text) <= 30, text
        return [('db', 7), ('dw', V(r)), ('db', ink), ('db', tx(text))]

    def P(r, label, rows):
        return [('db', 3), ('dw', V(r)), ('dw', label), ('db', rows)]
    G, Y, B, R = 0x00, 0x55, 0xAA, 0xFF
    o['ps_title'] = [('db', 5), ('dw', 'tune_title'), ('db', 2), ('db', 0), ('db', B)] + P(2, 'gfx_logo', 18) + \
        C(21, G, 'S I M U L A T O R') + C(51, Y, 'TRIBUTE TO DICK SMITH, AVIATOR') + [('db', 4)]
    o['ps_syd'] = [('db', 2), ('db', 0), ('db', B)] + P(2, 'gfx_syd', 26) + \
        T(30, 1, Y, '1982-83: DICK SMITH MADE THE') + T(36, 1, Y, 'FIRST SOLO HELICOPTER FLIGHT') + \
        T(42, 1, Y, 'AROUND THE WORLD. IN SYDNEY HE') + T(48, 1, Y, 'FLEW UNDER THE HARBOUR BRIDGE') + \
        T(54, 1, Y, 'AND LANDED AT DARLING HARBOUR.') + [('db', 4)]
    tl = [(3, R, 'DICK SMITH - AVIATOR', True),
          (10, Y, '1972 LEARNS TO FLY, BANKSTOWN', False),
          (16, Y, '1983 FIRST SOLO HELICOPTER', False),
          (22, G, '     FLIGHT AROUND THE WORLD', False),
          (28, Y, '1987 FIRST SOLO HELICOPTER', False),
          (34, G, '     FLIGHT TO THE NORTH POLE', False),
          (40, Y, '1989 POLE TO POLE, TWIN OTTER', False),
          (46, Y, '1993 FIRST BALLOON CROSSING', False),
          (52, G, '     OF AUSTRALIA', False),
          (57, Y, '2000 BALLOON, NZ TO AUSTRALIA', False)]
    sc = [('db', 2), ('db', 0), ('db', B)]
    for r, ink, t, c in tl:
        sc += C(r, ink, t) if c else T(r, 1, ink, t)
    o['ps_time'] = sc + [('db', 4)]
    o['ps_pole'] = [('db', 2), ('db', 0x10), ('db', 0x00)] + P(2, 'gfx_pole', 24) + \
        T(28, 1, B, '1987: ON HIS THIRD ATTEMPT,') + T(34, 1, B, 'DICK SMITH FLEW THE FIRST') + \
        T(40, 1, B, 'SOLO HELICOPTER FLIGHT TO THE') + T(46, 1, B, 'NORTH POLE.') + \
        C(55, R, 'CAN YOU DO IT ON ONE TANK?') + [('db', 4)]
    vz = [(3, R, 'THE VZ CONNECTION', True),
          (11, Y, 'THE VZ200 AND VZ300 WERE SOLD', False),
          (17, Y, 'IN AUSTRALIA BY DICK SMITH', False),
          (23, Y, 'ELECTRONICS, FOUNDED IN 1968.', False),
          (31, G, 'HE LAUNCHED AUSTRALIAN', False),
          (37, G, 'GEOGRAPHIC IN 1986 AND JOINED', False),
          (43, G, 'THE AUSTRALIAN AVIATION HALL', False),
          (49, G, 'OF FAME IN 2013.', False),
          (56, R, 'AN UNOFFICIAL TRIBUTE', True)]
    sc = [('db', 2), ('db', 0), ('db', B)]
    for r, ink, t, c in vz:
        sc += C(r, ink, t) if c else T(r, 1, ink, t)
    o['ps_vz'] = sc + [('db', 4)]
    ct = [(3, R, 'FLIGHT CONTROLS', True),
          (10, Y, 'Q A    NOSE UP / DOWN', False),
          (16, Y, 'M ,    BANK (HELI: TURN)', False),
          (22, Y, 'W S    THROTTLE / COLLECTIVE', False),
          (28, Y, 'SPACE  WHEEL BRAKES', False),
          (34, Y, '1-4    COCKPIT VIEWS', False),
          (40, Y, '5      MAP (AGAIN TO ZOOM)', False),
          (46, Y, 'P      PAUSE AND MENU', False),
          (52, Y, 'R      RESTART FLIGHT', False),
          (57, G, 'JOYSTICK AND FIRE WORK TOO', True)]
    sc = [('db', 2), ('db', 0), ('db', B)]
    for r, ink, t, c in ct:
        sc += C(r, ink, t) if c else T(r, 1, ink, t)
    o['ps_ctrl'] = sc + [('db', 4)]
    import locales
    sc = [('db', 2), ('db', 0), ('db', B)] + C(3, R, 'WHERE WILL YOU FLY?')
    r = 11
    for L in locales.LOCALES:
        n = len(L['missions'])
        sc += T(r, 2, Y, L['name']) + T(r, 20, G, '%d FLIGHTS' % n) + T(r + 6, 4, G, L['year'])
        r += 12
    o['ps_locs'] = sc + [('db', 4)]
    return o


def emit(items):
    out = []
    for kind, v in items:
        if kind == 'db':
            out.append(dbs(v if isinstance(v, list) else [v]))
        else:
            out.append('        dw %s' % v)
    return '\n'.join(out)


def gen_data():
    import locales, pics
    o = []
    A = o.append
    A('        align 256')
    A('sqlo:')
    sq = [(n * n) // 4 for n in range(512)]
    A(dbs([v & 255 for v in sq]))
    A('sqhi:')
    A(dbs([v >> 8 for v in sq]))
    A('sintab:')
    A(dws([int(round(32767 * math.sin(2 * math.pi * i / 1024))) for i in range(1024)]))
    A('font:')
    for c in CH:
        A(dbs(FONT[c]))
    for c, n in CHNAMES.items():
        A('ch_%s equ %d' % (n, CH.index(c)))
    A('mixmask: db $c0,$f0,$fc')
    A('p10tab: dw 10000,1000,100,10,1')
    # shapes
    for name, sh in locales.SHAPES.items():
        assert len(sh.verts) <= 40, name
        A('sh_%s:' % name)
        A('        db %d,%d' % (len(sh.verts), len(sh.edges)))
        for v in sh.verts:
            A(dbs(list(v)))
        for e in sh.edges:
            A(dbs(list(e)))
    # strings
    strs = {}

    def S(text, multi=False):
        key = (tuple(text) if multi else text)
        if key not in strs:
            lab = 'str_%d' % len(strs)
            strs[key] = (lab, txm(text) if multi else tx(text))
        return strs[key][0]
    # locales
    mid = 0
    loclabels = []
    mislist = []
    for li, L in enumerate(locales.LOCALES):
        k = L['key']
        loclabels.append('loc_' + k)
        # objects
        A('obj_%s:' % k)
        for (n, x, z, s_, vis, fl, yoff) in L['objects']:
            A('        dw %d,%d,sh_%s' % (x & 0xFFFF, z & 0xFFFF, n))
            A('        db %d,%d,%d,%d' % (s_, vis, fl, yoff))
        A('        dw 0,0,0')
        A('obs_%s:' % k)
        for ob in L['obstacles']:
            if ob[0] == 'pyr':
                _, x, z, R_ = ob
                A('        db 2')
                A('        dw %d,%d,%d,0,0,0' % (x & 0xFFFF, z & 0xFFFF, R_))
            else:
                t, x, z, hx, hz, y0, y1 = ob
                A('        db %d' % (1 if t == 'box' else 3))
                A('        dw %d,%d,%d,%d,%d,%d' % (x & 0xFFFF, z & 0xFFFF, hx, hz, y0 & 0xFFFF, y1))
        A('        db 0')
        A('plt_%s:' % k)
        for pl in L['platforms']:
            t, x, z, hx, hz, h = pl
            A('        db %d' % (2 if t == 'ship' else 1))
            A('        dw %d,%d,%d,%d,%d' % (x & 0xFFFF, z & 0xFFFF, hx, hz, h))
        A('        db 0')
        if L['ship']:
            shipobj = 'obj_%s+%d' % (k, 10 * L['ship']['obj'])
            shipz0 = L['objects'][L['ship']['obj']][2]
        else:
            shipobj, shipz0 = '0', 0
        A('loc_%s:' % k)
        A('        dw %s,%s' % (S(L['name']), S(L['desc'], True)))
        A('        db %d,%d,%d,%d' % (L['css'], L['sky'], L['gnd'], L['grid']))
        A('        dw obj_%s,obs_%s,plt_%s,%s' % (k, k, k, shipobj))
        A('        db %d,%d' % (L['water'], L['ink']))
        A('        dw %d,%s' % (shipz0 & 0xFFFF, S(L['year'])))
        A('        db %d' % len(L['missions']))
        A('        dw ' + ','.join('mis_%s_%d' % (k, i) for i in range(len(L['missions']))))
        for i, m in enumerate(L['missions']):
            mislist.append(('mis_%s_%d' % (k, i), m, mid if m['goals'] else 31))
            if m['goals']:
                mid += 1
    assert mid <= 31
    A('loctab: dw ' + ','.join(loclabels))

    def mission(lab, m, ident):
        A('%s:' % lab)
        A('        dw %s,%s' % (S(m['title']), S(m['brief'], True)))
        A('        db %d' % m['craft'])
        hdg = int(round(m['hdg'] * 65536 / 360)) & 0xFFFF
        A('        dw %d,%d,%d,%d' % (m['x'] & 0xFFFF, m['z'] & 0xFFFF, m['y'], hdg))
        A('        db %d,%d,%d' % (m['spd'], m['thr'], m['gnd']))
        A('        dw %d,%d' % (m['fuel'], m['par']))
        A('        db %d,%d' % (ident, len(m['goals'])))
        for g in m['goals']:
            A('        db %d' % g['type'])
            A('        dw %d,%d,%d,%d,%d,%s' % (g['x'] & 0xFFFF, g['z'] & 0xFFFF, g['r'], g['ylo'] & 0xFFFF,
                                             g['yhi'] & 0xFFFF, ('sh_' + g['shape']) if g['shape'] else '0'))
            A('        db %d,%d,0' % (g['s'], g['yoff']))
    for lab, m, ident in mislist:
        mission(lab, m, ident)
    D = locales.DEMO
    demo = dict(title='DEMO', brief=[''], craft=0, x=D['x'], z=D['z'], y=D['y'], hdg=D['hdg'], spd=D['spd'],
                thr=D['thr'], gnd=0, fuel=0, par=0, goals=[])
    mission('demomis', demo, 31)
    A('demowps:')
    for (x, z, y) in D['wps']:
        A('        dw %d,%d,%d' % (x & 0xFFFF, z & 0xFFFF, y))
    A('        dw $ffff')
    for key, (lab, vals) in strs.items():
        A('%s:' % lab)
        A(dbs(vals))
    # artwork
    for lab, pix in (('gfx_logo', pics.logo()), ('gfx_syd', pics.pic_sydney()), ('gfx_pole', pics.pic_pole())):
        A('%s:' % lab)
        A(dbs(pics.tobytes(pix)))
    # music
    for lab, vals in tunes().items():
        A('%s:' % lab)
        A(dbs(vals))
    # attract page scripts
    for lab, items in page_scripts().items():
        A('%s:' % lab)
        A(emit(items))
        A('        db 0')
    return '\n'.join(o) + '\n'


# ------------------------------------------------------------------ code templates
def gen_code():
    o = []
    A = o.append
    # --- transform origin: o{i} = sum_j d_j * m{i}{j}
    A('xform:')
    for i in range(3):
        A('        ld de,(dx)\n        ld hl,m%d0\n        call mul16m\n        push hl' % i)
        A('        ld de,(dy)\n        ld hl,m%d1\n        call mul16m\n        push hl' % i)
        A('        ld de,(dz)\n        ld hl,m%d2\n        call mul16m' % i)
        A('        pop de\n        add hl,de\n        pop de\n        add hl,de\n        ld (o%d),hl' % i)
    A('        ret')
    # --- vertex column accumulate
    for j in range(3):
        A('addcol%d:' % j)
        A('        ld c,0\n        or a\n        jp p,.p\n        neg\n        ld c,1')
        A('.p:     ld b,a\n        ld a,c\n        ld (ksgn),a')
        for i in range(3):
            A('        ld a,(m%d%d)\n        call umul8' % (i, j))
            A('        ld a,(m%d%d+1)\n        ld c,a\n        ld a,(ksgn)\n        xor c' % (i, j))
            A('        ld de,(acc%d)' % i)
            A('        jr z,.a%d' % i)
            A('        ex de,hl\n        or a\n        sbc hl,de\n        jr .s%d' % i)
            A('.a%d:    add hl,de' % i)
            A('.s%d:    ld (acc%d),hl' % (i, i))
        A('        ret')
    # --- vertex final coords
    A('vcoords:')
    for i in range(3):
        A('        ld hl,(acc%d)\n        ld a,(vshift)\n        call sran' % i)
        A('        ld de,(o%d)\n        add hl,de\n        sra h\n        rr l\n        ld (wpm+%d),hl' % (i, 2 * i))
    A('        ret')
    # --- midpoints
    for name, p, q in (('midab', 'wpa', 'wpb'), ('midio', 'wpi', 'wpo')):
        A('%s:' % name)
        for k in (0, 2, 4):
            A('        ld hl,(%s+%d)\n        ld de,(%s+%d)\n        add hl,de\n        sra h\n        rr l\n        ld (wpm+%d),hl' % (p, k, q, k, k))
        A('        ret')
    # --- grid
    A('gridvec:')
    for i in range(3):
        for col, nm in ((0, 'ga'), (2, 'gb')):
            A('        ld a,(m%d%d)\n        ld l,a\n        ld h,0\n        add hl,hl\n        add hl,hl' % (i, col))
            A('        ld a,(m%d%d+1)\n        or a\n        call nz,neghl' % (i, col))
            A('        ld (%s%d),hl\n        add hl,hl\n        add hl,hl\n        ld (%s4%d),hl' % (nm, i, nm, i))
    A('        ret')
    for nm, a, b in (('gridx', 'ga', 'gb'), ('gridz', 'gb', 'ga')):
        A('%s:' % nm)
        # gs = o - 3a
        for i in range(3):
            A('        ld hl,(%s%d)\n        ld d,h\n        ld e,l\n        add hl,hl\n        add hl,de\n        ex de,hl' % (a, i))
            A('        ld hl,(o%d)\n        or a\n        sbc hl,de\n        ld (gs%d),hl' % (i, i))
        A('        ld b,8')
        A('.l:     push bc')
        for i in range(3):
            A('        ld hl,(gs%d)\n        ld de,(%s4%d)\n        or a\n        sbc hl,de\n        sra h\n        rr l\n        ld (wpm+%d),hl' % (i, b, i, 2 * i))
        A('        ld iy,vtab\n        call vfin')
        for i in range(3):
            A('        ld hl,(gs%d)\n        ld de,(%s4%d)\n        add hl,de\n        sra h\n        rr l\n        ld (wpm+%d),hl' % (i, b, i, 2 * i))
        A('        ld iy,vtab+10\n        call vfin')
        A('        ld ix,vtab\n        ld iy,vtab+10\n        call drawseg\n        call poll')
        for i in range(3):
            A('        ld hl,(gs%d)\n        ld de,(%s%d)\n        add hl,de\n        ld (gs%d),hl' % (i, a, i, i))
        A('        pop bc\n        dec b\n        jp nz,.l\n        ret')
    # --- line blocks
    masks = [0xC0, 0x30, 0x0C, 0x03]
    for d, step in (('d', ['ld a,l', 'add a,32', 'ld l,a', 'jp nc,%s', 'inc h', 'jp %s']),
                    ('u', ['ld a,l', 'sub 32', 'ld l,a', 'jp nc,%s', 'dec h', 'jp %s'])):
        for p in range(4):
            nxt = 'xm%s%d' % (d, (p + 1) % 4)
            A('xm%s%d:' % (d, p))
            A('        ld a,(hl)\n        xor d\n        and %d\n        xor (hl)\n        ld (hl),a' % masks[p])
            A('        dec b\n        ret z')
            if p == 3:
                A('        inc l')
            A('        ld a,e\n        sub c\n        jr nc,.n')
            A('xm%s%d_p equ $+1' % (d, p))
            A('        add a,0\n        ld e,a')
            for s in step:
                A('        ' + (s % nxt if '%s' in s else s))
            A('.n:     ld e,a')
            if p == 3:
                A('        jp %s' % nxt)
        for p in range(4):
            nxt = 'ym%s%d' % (d, (p + 1) % 4)
            me = 'ym%s%d' % (d, p)
            A('%s:' % me)
            A('        ld a,(hl)\n        xor d\n        and %d\n        xor (hl)\n        ld (hl),a' % masks[p])
            A('        dec b\n        ret z')
            if d == 'd':
                A('        ld a,l\n        add a,32\n        ld l,a\n        jr nc,.h\n        inc h')
            else:
                A('        ld a,l\n        sub 32\n        ld l,a\n        jr nc,.h\n        dec h')
            A('.h:     ld a,e\n        sub c\n        jr nc,.n')
            A('%s_p equ $+1' % me)
            A('        add a,0\n        ld e,a')
            if p == 3:
                A('        inc l')
            A('        jp %s' % nxt)
            A('.n:     ld e,a\n        jp %s' % me)
    A('xmtab:  dw ' + ','.join('xm%s%d' % (d, p) for d in 'du' for p in range(4)))
    A('ymtab:  dw ' + ','.join('ym%s%d' % (d, p) for d in 'du' for p in range(4)))
    A('patchx:')
    for d in 'du':
        for p in range(4):
            A('        ld (xm%s%d_p),a' % (d, p))
    A('        ret')
    A('patchy:')
    for d in 'du':
        for p in range(4):
            A('        ld (ym%s%d_p),a' % (d, p))
    A('        ret')
    A('fill32:')
    for i in range(32):
        A('        ld (hl),a\n        inc hl')
    A('        ret')
    A('copy32:')
    for i in range(32):
        A('        ldi')
    A('        ret')
    return '\n'.join(o) + '\n'


def preprocess(src):
    out = []
    for line in src.split('\n'):
        m = re.match(r'^(\s*(?:[.\w]+:)?\s*)text\s+"(.*)"\s*$', line)
        if m:
            out.append(m.group(1) + 'db ' + ','.join(str(c) for c in text_codes(m.group(2)) + [255]))
        else:
            out.append(line)
    return '\n'.join(out)


def build(verbose=True):
    open(os.path.join(HERE, 'gen_data.asm'), 'w').write(gen_data())
    open(os.path.join(HERE, 'gen_code.asm'), 'w').write(gen_code())
    src = open(os.path.join(HERE, 'fs.asm')).read()
    for inc in ('flight.asm', 'front.asm', 'engine.asm'):
        src = src.replace('        include "%s"' % inc, open(os.path.join(HERE, inc)).read())
    open(os.path.join(HERE, 'fs_pp.asm'), 'w').write(preprocess(src))
    a = Asm(HERE)
    org, code, syms = a.assemble('fs_pp.asm')
    hdr = b'VZF0' + b'VZFLIGHT'.ljust(17, b'\0') + bytes([0xF1, org & 255, org >> 8])
    open(os.path.join(HERE, 'VZFLIGHT.VZ'), 'wb').write(hdr + code)
    json.dump(syms, open(os.path.join(HERE, 'syms.json'), 'w'))
    if verbose:
        print('org $%04X  image %d bytes (ends $%04X)  bss end $%04X  stack top $%04X' % (
            org, len(code), org + len(code), syms['bssend'], syms['stacktop']))
    return org, code, syms


if __name__ == '__main__':
    build()
