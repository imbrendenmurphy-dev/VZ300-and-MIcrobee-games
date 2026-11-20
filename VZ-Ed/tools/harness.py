"""VZ300 + BennVenn SD test harness for VZ-ED.
Runs the real VZDOS ROM (as flash) and SD card at SPI level (from VZ-DECK's tools),
with a full keyboard matrix (several keys at once), joystick, frame-accurate field sync,
a FAT32 image builder (optionally MBR-partitioned) and a FAT32 consistency checker."""
import struct, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from z80 import Z80
from vz import SD

FRAME = 70630
ROWADDR = [0xFE,0xFD,0xFB,0xF7,0xEF,0xDF,0xBF,0x7F]
MATRIX = [['T','W',None,'E','Q','R'],['G','S','CTRL','D','A','F'],['B','X','SHIFT','C','Z','V'],
          ['5','2',None,'3','1','4'],['N','.',None,',','SPACE','M'],['6','9','-','8','0','7'],
          ['Y','O','RET','I','P','U'],['H','L',':','K',';','J']]
KEYPOS = {}
for r,row in enumerate(MATRIX):
    for b,k in enumerate(row):
        if k: KEYPOS[k]=(r,b)

# ------------------------------------------------------------------ FAT32 image
class Card:
    """FAT32 image in a dict of sectors.  part = partition start (0 = no MBR)."""
    def __init__(s, spc=8, reserved=32, fatsz=64, part=0, totclus=None):
        s.spc, s.res, s.fatsz, s.part = spc, reserved, fatsz, part
        s.sec = {}
        s.fat = [0x0FFFFFF8, 0x0FFFFFFF, 0x0FFFFFFF]
        s.data0 = part + reserved + 2*fatsz
        s.totclus = totclus or fatsz*128 - 2
        s.dirs = {2: []}
    def alloc(s, n):
        first = len(s.fat)
        for i in range(n): s.fat.append(first+i+1 if i < n-1 else 0x0FFFFFFF)
        return first
    def lba(s, c): return s.data0 + (c-2)*s.spc
    def putdata(s, c, data):
        for i in range(0, len(data), 512): s.sec[s.lba(c)+i//512] = bytes(data[i:i+512].ljust(512, b'\0'))
    @staticmethod
    def ent(name, attr, clus, size):
        if name in ('.', '..'): nm = name.ljust(11).encode()
        else:
            n, _, e = name.partition('.'); nm = (n.ljust(8)+e.ljust(3)).encode()
        b = bytearray(32); b[0:11] = nm; b[11] = attr
        struct.pack_into('<H', b, 0x14, clus >> 16); struct.pack_into('<HH', b, 0x18, 0x5B21, 0)
        struct.pack_into('<H', b, 0x1A, clus & 0xFFFF); struct.pack_into('<I', b, 0x1C, size); return bytes(b)
    def addfile(s, d, name, data, attr=0x20, frag=False):
        per = 512*s.spc; n = -(-len(data)//per) if data else 0
        if not n: c = 0
        elif frag:     # scatter the clusters
            cl = []
            for i in range(n): cl.append(s.alloc(1)); s.alloc(1)
            for a, b2 in zip(cl, cl[1:]): s.fat[a] = b2
            for i, cc in enumerate(cl): s.putdata(cc, data[i*per:(i+1)*per])
            c = cl[0]
            for k in range(len(s.fat)):   # free the spacer clusters
                if k > 2 and k not in cl and s.fat[k] == 0x0FFFFFFF and k-1 in cl: s.fat[k] = 0
        else:
            c = s.alloc(n); s.putdata(c, data)
        s.dirs[d].append(s.ent(name, attr, c, len(data))); return c
    def addraw(s, d, raw): s.dirs[d].append(raw)
    def mkdir(s, d, name):
        c = s.alloc(1); s.dirs[c] = [s.ent('.', 0x10, c, 0), s.ent('..', 0x10, 0 if d == 2 else d, 0)]
        s.dirs[d].append(s.ent(name, 0x10, c, 0)); return c
    def fill_used(s, d, n):
        """a filler file using n clusters"""
        c = s.alloc(n); s.dirs[d].append(s.ent('FILLER.BIN', 0x20, c, n*512*s.spc))
    def finish(s, nextfree=None):
        for c, ents in s.dirs.items():
            data = b''.join(ents); per = 512*s.spc; need = max(1, -(-len(data)//per))
            chain = [c]
            while len(chain) < need:
                n = len(s.fat); s.fat.append(0x0FFFFFFF); s.fat[chain[-1]] = n; chain.append(n)
            data = data.ljust(need*per, b'\0')
            for i, cl in enumerate(chain): s.putdata(cl, data[i*per:(i+1)*per])
        fb = b''.join(struct.pack('<I', x) for x in s.fat).ljust(s.fatsz*512, b'\0')
        for k in range(2):
            for i in range(s.fatsz): s.sec[s.part+s.res+k*s.fatsz+i] = fb[i*512:(i+1)*512]
        b = bytearray(512); b[0:3] = b'\xEB\x58\x90'; b[3:11] = b'MSDOS5.0'
        struct.pack_into('<HBHB', b, 11, 512, s.spc, s.res, 2)
        totsec = s.res + 2*s.fatsz + s.totclus*s.spc
        struct.pack_into('<I', b, 0x20, totsec); struct.pack_into('<I', b, 0x24, s.fatsz)
        struct.pack_into('<I', b, 0x2C, 2); struct.pack_into('<H', b, 0x30, 1)
        b[510:512] = b'\x55\xAA'; s.sec[s.part] = bytes(b)
        fi = bytearray(512); fi[0:4] = b'RRaA'; fi[0x1E4:0x1E8] = b'rrAa'
        struct.pack_into('<II', fi, 0x1E8, 0xFFFFFFFF, nextfree if nextfree else len(s.fat))
        fi[510:512] = b'\x55\xAA'; s.sec[s.part+1] = bytes(fi)
        if s.part:
            m = bytearray(512); m[0x1BE+4] = 0x0C; struct.pack_into('<II', m, 0x1BE+8, s.part, totsec)
            m[510:512] = b'\x55\xAA'; s.sec[0] = bytes(m)
        return s

# ------------------------------------------------------------------ FAT32 checker
class FS:
    def __init__(s, sec):
        s.sec = sec
        p = 0
        if sec.get(0, bytes(512))[0] != 0xEB: p = struct.unpack_from('<I', sec[0], 0x1C6)[0]
        b = sec[p]; s.part = p
        s.spc = b[13]; s.res = struct.unpack_from('<H', b, 14)[0]; s.nf = b[16]
        s.fatsz = struct.unpack_from('<I', b, 0x24)[0]; s.root = struct.unpack_from('<I', b, 0x2C)[0]
        s.data0 = p + s.res + s.nf*s.fatsz
        tot = struct.unpack_from('<I', b, 0x20)[0]; s.nclus = (tot - s.res - s.nf*s.fatsz)//s.spc
    def fatbytes(s, k):
        return b''.join(s.sec.get(s.part+s.res+k*s.fatsz+i, bytes(512)) for i in range(s.fatsz))
    def fat(s, k=0):
        fb = s.fatbytes(k); return [x & 0x0FFFFFFF for x in struct.unpack('<%dI' % (len(fb)//4), fb)]
    def rd(s, c, i): return s.sec.get(s.data0 + (c-2)*s.spc + i, bytes(512))
    def chain(s, c, F):
        out = []; seen = set()
        while 2 <= c < 0x0FFFFFF8:
            if c in seen: raise Exception('loop in chain at %d' % c)
            seen.add(c); out.append(c); c = F[c]
            if c == 0: raise Exception('chain runs into a free cluster')
        return out
    def readfile(s, c, size, F):
        d = b''.join(s.rd(cc, i) for cc in s.chain(c, F) for i in range(s.spc)) if c else b''
        return d[:size]
    def walk(s, c=None, path='/', F=None, out=None):
        F = F or s.fat(); out = out if out is not None else {}
        c = c or s.root
        raw = b''.join(s.rd(cc, i) for cc in s.chain(c, F) for i in range(s.spc))
        out.setdefault('_dirclusters', []).extend(s.chain(c, F))
        for i in range(0, len(raw), 32):
            e = raw[i:i+32]
            if e[0] == 0: break
            if e[0] == 0xE5 or e[11] == 0x0F or e[11] & 8: continue
            name = e[0:8].decode('latin1').rstrip(); ext = e[8:11].decode('latin1').rstrip()
            full = name + ('.' + ext if ext else '')
            cl = struct.unpack_from('<H', e, 0x14)[0] << 16 | struct.unpack_from('<H', e, 0x1A)[0]
            size = struct.unpack_from('<I', e, 0x1C)[0]
            if e[11] & 0x10:
                if name in ('.', '..'): continue
                s.walk(cl, path + full + '/', F, out)
            else:
                out[path + full] = (cl, size)
        return out
    def check(s):
        """returns list of problems ([] = clean) and the file table"""
        probs = []; F = s.fat(0)
        if s.nf == 2 and s.fatbytes(0) != s.fatbytes(1): probs.append('FAT copies differ')
        files = s.walk(F=F)
        owner = {}
        for c in files['_dirclusters']: owner[c] = 'dir'
        for p, v in files.items():
            if p == '_dirclusters': continue
            c, size = v
            try: ch = s.chain(c, F) if c else []
            except Exception as ex: probs.append('%s: %s' % (p, ex)); continue
            per = 512*s.spc
            if len(ch) != -(-size//per): probs.append('%s: %d clusters for %d bytes' % (p, len(ch), size))
            for cc in ch:
                if cc in owner: probs.append('%s: cluster %d cross-linked with %s' % (p, cc, owner[cc]))
                owner[cc] = p
        used = [c for c in range(2, min(len(F), s.nclus+2)) if F[c] != 0]
        lost = [c for c in used if c not in owner]
        beyond = [c for c in range(s.nclus+2, len(F)) if F[c] != 0]
        if lost: probs.append('%d lost clusters %s' % (len(lost), lost[:8]))
        if beyond: probs.append('clusters used past the end of the volume %s' % beyond[:8])
        return probs, files

# ------------------------------------------------------------------ the machine
class VZ:
    def __init__(s, dos, card, maxlba=None, bank=True):
        z = s.z = Z80(); s.flash = dos; s.sd = SD(card, maxlba); s.ramsel = 0; s.mapper = 0
        # port $37 bit 1 = the second 10K SRAM bank at $4000-$67FF (MAME sdloader);
        # bank=False: a machine without it (OUT ($37),3 changes nothing)
        s.bank1 = bytearray((i * 37 + 11) & 0xFF for i in range(0x2800)) if bank else None
        s.keys = set(); s.joy = set(); s.script = []; s.frame = 0; s.stop = None; s.con = ''
        s.writes_low = []; s.guard = None
        def rd(a):
            if s.bank1 is not None and (s.mapper & 3) == 3 and 0x4000 <= a < 0x6800:
                return s.bank1[a-0x4000]
            if 0x4000 <= a < 0x6000 and not s.ramsel:
                return s.flash[a-0x4000] if a-0x4000 < len(s.flash) else 0xFF
            if 0x6800 <= a < 0x7000:
                s.sync_frame()
                v = 0x7F
                lo = a & 0xFF
                for k in s.keys:
                    r, b = KEYPOS[k]
                    if not lo & (1 << r): v &= ~(1 << b)
                ph = z.t % FRAME
                return (v & 0x7F) | (0 if ph < 12740 else 0x80)
            return z.mem[a]
        def wr(a, v):
            if a < 0x4000: return
            if s.bank1 is not None and (s.mapper & 3) == 3 and 0x4000 <= a < 0x6800:
                s.bank1[a-0x4000] = v; return
            if 0x4000 <= a < 0x6000 and not s.ramsel: return
            if 0x6800 <= a < 0x7000: s.latch = v; return
            if s.guard and s.guard(a, v): s.writes_low.append((z.pc, a, v))
            z.mem[a] = v
        z.rd = rd; z.wr = wr; s.latch = 0
        def outp(p, v):
            p &= 0xFF
            if p == 0x39: s.sd.out(v)
            elif p == 0x37:
                if s.bank1 is None and (v & 3) == 3: return   # no spare bank: setting 3 does nothing
                s.ramsel = v & 1; s.mapper = v
        def inp(p):
            p &= 0xFF
            if p == 0x39: return s.sd.inp()
            J = {'UP':0,'DOWN':1,'LEFT':2,'RIGHT':3}
            if p == 0x2C:
                v = 0xFF
                for j in s.joy:
                    if j in J: v &= ~(1 << J[j])
                return v
            if p == 0x2E: return 0xEF if 'FIRE' in s.joy else 0xFF
            return 0xFF
        z.outp = outp; z.inp = inp
    def sync_frame(s):
        f = s.z.t // FRAME
        while s.frame < f:
            s.frame += 1
            if s.script:
                k, n = s.script[0]
                s.keys = set(k) if k else set()
                n -= 1
                if n <= 0: s.script.pop(0)
                else: s.script[0] = (k, n)
            else:
                s.keys = set()
    def putch(s, c):
        s.con += chr(c) if c != 13 else '\n'
    def trap(s):
        z = s.z; pc = z.pc
        if pc == 0x01C9: z.mem[0x7000:0x7200] = b'\x20'*512
        elif pc == 0x28A7:
            a = z.hl()
            while z.rd(a): s.putch(z.rd(a)); a += 1
        elif pc == 0x033A: s.putch(z.r[7])
        elif pc == 0x2EF4: z.r[7] = 0
        elif pc == 0x06A0: s.stop = 'BASIC'; return
        elif pc == 0x0000:
            s.con += '[RESET]'; s.resets = getattr(s, 'resets', 0) + 1; z.pc = 0x4004; s.ramsel = 0; s.mapper = 0; return
        elif pc in (0x3450, 0x1A19): pass
        else: s.stop = 'ROM %04X' % pc; return
        z.pc = z.pop()
    def run(s, pc=None, frames=100, until=None, maxsteps=200000000):
        z = s.z
        if pc is not None: z.pc = pc
        end = z.t + frames*FRAME; n = 0
        while z.t < end and not s.stop and n < maxsteps:
            if z.pc < 0x4000: s.trap(); continue
            z.step(); n += 1
            if until and n % 500 == 0 and until(s): return 'until'
        return s.stop or 'frames'
    def type_keys(s, items, hold=3, gap=3):
        """items: list of key names or tuples (combos) -> script"""
        for it in items:
            if isinstance(it, tuple) and it[0] == 'WAIT':
                s.script.append((None, it[1])); continue
            k = it if isinstance(it, tuple) else (it,)
            s.script.append((k, hold)); s.script.append((None, gap))
    def run_script(s, extra=10, maxframes=4000):
        f0 = s.frame
        while s.script and s.frame - f0 < maxframes and not s.stop:
            s.run(frames=5)
        return s.run(frames=extra)
    # screen
    def text(s):
        out = []
        for r in range(16):
            line = ''
            for c in s.z.mem[0x7000+r*32:0x7020+r*32]:
                if c & 0x80: line += '#'
                else:
                    ch = c & 0x3F; ch = ch + 0x40 if ch < 0x20 else ch
                    line += chr(ch).lower() if (c & 0x40 and chr(ch).isalpha()) else chr(ch)
            out.append(line)
        return '\n'.join(out)

def text_for(chars):
    """turn a string into key presses (lower case letters, SHIFT for capitals/symbols)"""
    SH = {'!':'1','"':'2','#':'3','$':'4','%':'5','&':'6',"'":'7','(':'8',')':'9','@':'0',
          '=':'-','+':';','*':':','<':',','>':'.'}
    CS = {'?':'L','/':'K','[':'O',']':'P','{':'I','}':'U','\\':'M','^':'N','|':'J','~':'H','_':'-','`':'7'}
    out = []
    for ch in chars:
        if ch == '\n': out.append('RET')
        elif ch == ' ': out.append('SPACE')
        elif ch.isalpha() and ch.islower(): out.append(ch.upper())
        elif ch.isalpha(): out.append(('SHIFT', ch))
        elif ch.isdigit() or ch in ',.;:-': out.append(ch)
        elif ch in SH: out.append(('SHIFT', SH[ch]))
        elif ch in CS: out.append(('CTRL', 'SHIFT', CS[ch]))
        else: raise Exception(ch)
    return out
