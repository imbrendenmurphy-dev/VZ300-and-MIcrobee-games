"""Generate vars.inc and tables.inc for VZ-ED (font, keyboard, text-mode and colour tables)."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- variables
VARS = [('gs',2),('ge',2),('top',2),('hs',2),('curln',2),('goal',2),('curcell',2),
 ('modified',1),('insmode',1),('caps',1),('crlf',1),('named',1),('fname',11),('dstyle',1),
 ('nrows',1),('docrows',1),('ncells',2),('tinvm',1),('crow',1),('ccol',1),('gpair',1),('rrows',1),('bnd',2),('evn',1),('bphase',1),
 ('edmode',1),('blinkc',1),('blinkon',1),('msgflag',1),('msgp',2),('lz',1),('n24',3),('NUMTMP',8),
 ('lastidx',1),('lastmod',1),('rpt',1),('waitrel',1),('joyon',1),('askmode',1),('inlen',1),
 ('lcur',1),('ltop',1),('lidx',1),('lrow',2),('dcount',1),('dwr',2),('skey',2),('hptr',2),
 ('fs_ok',1),('part',3),('spc',1),('sh',1),('nfats',1),('bpc',3),('fat1',3),('fatsz',3),('data',3),
 ('rootcl',3),('fsinfo',3),('clend',3),('hint',3),('cwd',3),('fatcache',3),('fatdirty',1),
 ('setv',3),('setv3',1),('anum',1),('afound',1),('acur',3),('aleft',3),('fccl',3),('fcnext',3),
 ('fcflag',1),('dwcl',3),('dwsec',1),('dwptr',2),('dwlba',3),('seg1p',2),('seg1l',2),('seg2p',2),
 ('seg2l',2),('wcrlf',1),('wdir',3),('outlen',2),('wncl',1),('wci',1),('wsec',1),('wpos',2),
 ('wfirst',3),('ldcl',3),('ldsz',3),('lddst',2),('ldrem',2),('ldcur',3),('lsec',1),('trunc',1),
 ('plugmode',1),('cfgcl',3),('cfghave',1),('cfg_ds',1),('cfg_caps',1),('cfg_ins',1),
 # 0.2
 ('wrap',1),('selon',1),('anchor',2),('dsel',1),('clipbank',1),('clipbase',2),('clipmax',2),('cliplen',2),
 ('askall',1),('clhome',1),
 # 0.3
 ('ovslot',1),('ovskip',1),('ovcnt',1),('ovst',1),('menusel',1),
 # 0.6
 ('ovok',1),('basmode',1),('bashdr',19),
 # 0.7
 ('utop',2),('useal',1),('ujoin',1),('uovr',1),('uty',1),('ukind',1),('upos',2),('ulen',2),('usrc',2),
 ('udsz',2),('uend',2),('mkp',2),('mkn',2),('marks',18),('ovkey',1),
 # 0.8
 ('bigmode',1),('bigop',1),('bsrc',3),('bsz',2),('bws',2),('bwl',2),('bwlf',2),('lnbase',2)]
def gen_vars():
    a = 0x9730; out = ['VARS equ $%04X' % a]          # right after DPTR
    for n, s in VARS:
        if n == 'NUMTMP': assert (a & 0xFF) + s <= 0x100, n   # used with "sub X&255"
        out.append('%s equ $%04X' % (n, a)); a += s
    out.append('VARS_END equ $%04X' % a)
    assert a <= 0x9C00
    open(os.path.join(HERE, 'vars.inc'), 'w').write('\n'.join(out) + '\n')

# ---------------------------------------------------------------- keyboard
# VZ matrix, bit0..bit5 of each row ($68FE, $68FD, ... $687F)
ROWS = [['T','W',None,'E','Q','R'],
        ['G','S','CTRL','D','A','F'],
        ['B','X','SHIFT','C','Z','V'],
        ['5','2',None,'3','1','4'],
        ['N','.',None,',',' ','M'],
        ['6','9','-','8','0','7'],
        ['Y','O','RET','I','P','U'],
        ['H','L',':','K',';','J']]
K = dict(LEFT=1,RIGHT=2,UP=3,DOWN=4,PGUP=5,PGDN=6,TOP=7,BOT=8,HOME=9,END=10,BS=11,DEL=12,RET=13,
         INS=14,CAPS=15,OPEN=16,SAVE=17,SAVEAS=18,NEW=19,QUIT=20,DISP=21,HELP=22,
         MARK=24,COPY=25,CUT=26,PASTE=27,FIND=28,NEXT=29,REPL=30,WRAP=31,SHEET=127,MENU=128,UNDO=131,SETMK=135,
         MK1=136,MK2=137,MK3=138,MK4=139,MK5=140,MK6=141,MK7=142,MK8=143,MK9=144)
SHIFT = {'1':'!','2':'"','3':'#','4':'$','5':'%','6':'&','7':"'",'8':'(','9':')','0':'@',
         '-':'=',';':'+',':':'*',',':'<','.':'>',' ':' '}
CTRL = {'M':'LEFT',',':'RIGHT','.':'UP',' ':'DOWN','R':'PGUP','C':'PGDN','T':'TOP','B':'BOT',
        'Z':'HOME','X':'END',':':'BS',';':'DEL','L':'INS','U':'CAPS','O':'OPEN','S':'SAVE',
        'A':'SAVEAS','N':'NEW','Q':'QUIT','D':'DISP','H':'HELP',
        'K':'MARK','J':'COPY','Y':'CUT','P':'PASTE','F':'FIND','G':'NEXT','E':'REPL','W':'WRAP','V':'SHEET','I':'MENU',
        '-':'UNDO','0':'SETMK','1':'MK1','2':'MK2','3':'MK3','4':'MK4','5':'MK5','6':'MK6','7':'MK7','8':'MK8','9':'MK9'}
CSHIFT = {'L':'?','K':'/','O':'[','P':']','I':'{','U':'}','M':'\\','N':'^','J':'|','H':'~',
          '-':'_','7':'`'}
def ktab():
    t = [0]*256
    for r, row in enumerate(ROWS):
        for b, k in enumerate(row):
            if k in (None, 'CTRL', 'SHIFT'): continue
            i = r*8 + b
            if k == 'RET':
                for m in range(4): t[m*64+i] = 13
                continue
            t[i] = ord(k.lower())
            t[64+i] = ord(k) if k.isalpha() else ord(SHIFT.get(k, k))
            if k in CTRL: t[128+i] = K[CTRL[k]]
            if k in CSHIFT: t[192+i] = ord(CSHIFT[k])
    return t

# ---------------------------------------------------------------- text mode (MC6847)
def ttab():
    t = []
    sub = {'_':'-','`':"'",'{':'(','}':')','|':'!','~':'-'}
    for c in range(128):
        ch = chr(c)
        if 'A' <= ch <= 'Z': v = (c-64) | 0x40
        elif 'a' <= ch <= 'z': v = (c-96) | 0x80
        elif ch in '@[\\]^': v = {'@':0,'[':27,'\\':28,']':29,'^':30}[ch]
        elif 32 <= c < 64: v = c
        elif ch in sub: v = ord(sub[ch])
        elif c == 9: v = ord('>')
        else: v = ord('?')
        t.append(v)
    return t

# ---------------------------------------------------------------- 4x6 font (3 pixels + gap)
G = {}
def g(ch, *rows):
    rows = list(rows) + ['...']*(6-len(rows))
    G[ch] = rows
g(' ')
g('!','.X.','.X.','.X.','...','.X.')
g('"','X.X','X.X')
g('#','X.X','XXX','X.X','XXX','X.X')
g('$','.XX','XX.','.X.','.XX','XX.')
g('%','X..','..X','.X.','X..','..X')
g('&','.X.','X.X','.X.','X.X','.XX')
g("'",'.X.','.X.')
g('(','..X','.X.','.X.','.X.','..X')
g(')','X..','.X.','.X.','.X.','X..')
g('*','...','X.X','.X.','X.X')
g('+','...','.X.','XXX','.X.')
g(',','...','...','...','.X.','X..')
g('-','...','...','XXX')
g('.','...','...','...','...','.X.')
g('/','..X','..X','.X.','X..','X..')
g('0','XXX','X.X','X.X','X.X','XXX')
g('1','.X.','XX.','.X.','.X.','XXX')
g('2','XX.','..X','.X.','X..','XXX')
g('3','XX.','..X','.X.','..X','XX.')
g('4','X.X','X.X','XXX','..X','..X')
g('5','XXX','X..','XX.','..X','XX.')
g('6','.XX','X..','XXX','X.X','XXX')
g('7','XXX','..X','.X.','X..','X..')
g('8','XXX','X.X','XXX','X.X','XXX')
g('9','XXX','X.X','XXX','..X','XX.')
g(':','...','.X.','...','.X.')
g(';','...','.X.','...','.X.','X..')
g('<','..X','.X.','X..','.X.','..X')
g('=','...','XXX','...','XXX')
g('>','X..','.X.','..X','.X.','X..')
g('?','XX.','..X','.X.','...','.X.')
g('@','.X.','X.X','X.X','X..','.XX')
g('A','.X.','X.X','XXX','X.X','X.X')
g('B','XX.','X.X','XX.','X.X','XX.')
g('C','.XX','X..','X..','X..','.XX')
g('D','XX.','X.X','X.X','X.X','XX.')
g('E','XXX','X..','XXX','X..','XXX')
g('F','XXX','X..','XXX','X..','X..')
g('G','.XX','X..','X.X','X.X','.XX')
g('H','X.X','X.X','XXX','X.X','X.X')
g('I','XXX','.X.','.X.','.X.','XXX')
g('J','..X','..X','..X','X.X','.X.')
g('K','X.X','X.X','XX.','X.X','X.X')
g('L','X..','X..','X..','X..','XXX')
g('M','X.X','XXX','XXX','X.X','X.X')
g('N','XX.','X.X','X.X','X.X','X.X')
g('O','.X.','X.X','X.X','X.X','.X.')
g('P','XX.','X.X','XX.','X..','X..')
g('Q','.X.','X.X','X.X','XXX','.XX')
g('R','XX.','X.X','XX.','X.X','X.X')
g('S','XXX','X..','XXX','..X','XXX')
g('T','XXX','.X.','.X.','.X.','.X.')
g('U','X.X','X.X','X.X','X.X','XXX')
g('V','X.X','X.X','X.X','X.X','.X.')
g('W','X.X','X.X','XXX','XXX','X.X')
g('X','X.X','X.X','.X.','X.X','X.X')
g('Y','X.X','X.X','.X.','.X.','.X.')
g('Z','XXX','..X','.X.','X..','XXX')
g('[','XX.','X..','X..','X..','XX.')
g('\\','X..','X..','.X.','..X','..X')
g(']','.XX','..X','..X','..X','.XX')
g('^','.X.','X.X')
g('_','...','...','...','...','...','XXX')
g('`','X..','.X.')
g('a','...','XX.','.XX','X.X','XXX')
g('b','X..','XX.','X.X','X.X','XX.')
g('c','...','.XX','X..','X..','.XX')
g('d','..X','.XX','X.X','X.X','.XX')
g('e','...','.X.','XXX','X..','.XX')
g('f','..X','.X.','XXX','.X.','.X.')
g('g','...','.XX','X.X','.XX','..X','XX.')
g('h','X..','XX.','X.X','X.X','X.X')
g('i','.X.','...','.X.','.X.','.X.')
g('j','..X','...','..X','..X','X.X','.X.')
g('k','X..','X.X','XX.','X.X','X.X')
g('l','XX.','.X.','.X.','.X.','XXX')
g('m','...','XX.','XXX','X.X','X.X')
g('n','...','XX.','X.X','X.X','X.X')
g('o','...','.X.','X.X','X.X','.X.')
g('p','...','XX.','X.X','XX.','X..','X..')
g('q','...','.XX','X.X','.XX','..X','..X')
g('r','...','X.X','XX.','X..','X..')
g('s','...','.XX','X..','..X','XX.')
g('t','.X.','XXX','.X.','.X.','..X')
g('u','...','X.X','X.X','X.X','.XX')
g('v','...','X.X','X.X','X.X','.X.')
g('w','...','X.X','X.X','XXX','X.X')
g('x','...','X.X','.X.','.X.','X.X')
g('y','...','X.X','X.X','.XX','..X','XX.')
g('z','...','XXX','..X','.X.','XXX')
g('{','..X','.X.','XX.','.X.','..X')
g('|','.X.','.X.','.X.','.X.','.X.')
g('}','X..','.X.','.XX','.X.','X..')
g('~','...','.XX','XX.')
def font():
    out = []
    for c in range(32, 127):
        rows = G[chr(c)]
        assert len(rows) == 6 and all(len(r) == 3 for r in rows), chr(c)
        for r in rows: out.append(sum(8 >> i for i, p in enumerate(r) if p == 'X'))
    out += [14]*5 + [0]           # glyph 95: block for anything unprintable
    return [out[i] << 4 | out[i+1] for i in range(0, len(out), 2)]   # two rows per byte

# ---------------------------------------------------------------- 4-colour expansion (CSS 0)
# 0 green, 1 yellow, 2 blue, 3 red.  pairs: text, title bar, cursor, overtype cursor, selected text
PAIRS = [(2,0),(1,3),(0,2),(1,3),(2,1)]
def ctab():
    out = []
    for fg, bg in PAIRS:
        for m in range(16):
            v = 0
            for px in range(4):
                v |= (fg if (m >> (3-px)) & 1 else bg) << (6-2*px)
            out.append(v)
    return out

def db(name, data, per=16):
    s = [name + ':']
    for i in range(0, len(data), per):
        s.append('        db ' + ','.join(str(x) for x in data[i:i+per]))
    return '\n'.join(s)

def gen_tables():
    # CTAB lives in the upper half of TTAB's page: colour pair p is $80+16*p
    parts = ['        align 256', db('KTAB', ktab()),
             '        align 256', db('TTAB', ttab()), db('CTAB', ctab()),
             '        assert (CTAB&255) == $80',
             db('FONT', font(), 3)]
    open(os.path.join(HERE, 'tables.inc'), 'w').write('\n'.join(parts) + '\n')

if __name__ == '__main__':
    gen_vars(); gen_tables()

# ---------------------------------------------------------------- VZ BASIC keywords (0.6)
# The ROM's table at $1650: token = $80 + index; None = a token the VZ doesn't use.
BASIC_KW = ['END', 'FOR', 'RESET', 'SET', 'CLS', None, 'RANDOM', 'NEXT', 'DATA', 'INPUT', 'DIM', 'READ', 'LET',
      'GOTO', 'RUN', 'IF', 'RESTORE', 'GOSUB', 'RETURN', 'REM', 'STOP', 'ELSE', 'COPY', 'COLOR', 'VERIFY',
      'DEFINT', 'DEFSNG', 'DEFDBL', 'CRUN', 'MODE', 'SOUND', 'RESUME', 'OUT', 'ON', None, None, None, None,
      None, None, None, None, None, None, None, None, 'SYSTEM', 'LPRINT', None, 'POKE', 'PRINT', 'CONT', 'LIST',
      'LLIST', 'DELETE', 'AUTO', 'CLEAR', 'CLOAD', 'CSAVE', 'NEW', 'TAB(', 'TO', None, 'USING', 'VARPTR', 'USR',
      'ERL', 'ERR', 'STRING$', None, 'POINT', None, 'MEM', 'INKEY$', 'THEN', 'NOT', 'STEP', '+', '-', '*', '/',
      '^', 'AND', 'OR', '>', '=', '<', 'SGN', 'INT', 'ABS', 'FRE', 'INP', 'POS', 'SQR', 'RND', 'LOG', 'EXP',
      'COS', 'SIN', 'TAN', 'ATN', 'PEEK', None, None, None, None, None, None, None, None, None, 'CINT', 'CSNG',
      'CDBL', 'FIX', 'LEN', 'STR$', 'VAL', 'ASC', 'CHR$', 'LEFT$', 'RIGHT$', 'MID$', "'"]
assert len(BASIC_KW) == 124
def gen_basic():
    """basic_kw.inc for the BASIC overlays: each keyword with bit 7 on its first
    character; an unused token is a single $FF; $80 ends the table"""
    out = ['; generated by gen.py - do not edit', 'bas_kw:']
    for w in BASIC_KW:
        if w is None: out.append('        db $FF'); continue
        b = [ord(w[0]) | 0x80] + [ord(c) for c in w[1:]]
        out.append('        db ' + ','.join('$%02X' % x for x in b) + '   ; ' + w)
    out.append('        db $80')
    open(os.path.join(HERE, 'basic_kw.inc'), 'w').write('\n'.join(out) + '\n')
