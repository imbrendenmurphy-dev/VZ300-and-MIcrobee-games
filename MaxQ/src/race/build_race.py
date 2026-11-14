#!/usr/bin/env python3
"""
build_race.py - builds MAXQ.VZ (MAX Q, VZ300 3D hover racer) and test images.
VIBED BY BPM 2026

  python3 build_race.py          build the game  -> MAXQ.VZ
  python3 build_race.py test     render test camera states in the emulator and
                                 compare each frame byte-for-byte with ref3.py
"""
import os, sys, subprocess, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import ref3 as R
import road_ref as RR
import mkroad
import craft2, logo
from z80asm import Asm, vz_file

EMU = os.path.join(HERE, '..', 'tools', 'vzemu')

VARS = """CAM_I 2 CAM_F 1 CAM_LAT 2 CAM_TH 1 TK 2 HC 1 VX 2 VY 2 VZ 2 DYI 1 HZ 1 NSEC 1 DEPTHV 1
TIDX 2 DANG 1 HBXV 1 OXV 1 OZV 1 HBYV 1 LZ 2 PSX 1 PSY 1 PSIGN 1 YTOP 1 NGATE 1
PX0 1 PX1 1 PX2 1 PX3 1 PY0 1 PY1 1 PY2 1 PY3 1 ZNL 2 ZNR 2 CLIPPED 1 LZM 2 RW 1 SS 1 KK 1
FARP 2 TCL 1 CPT 6 YMIN 1 YMAX 1 YR0 1 YR1 1 YA0 1 YA1 1 SUC 1 RLC 1 STOP 1 YCUR 1
ETAG 1 EXA 1 EYA 1 EXB 1 EYB 1 EDY 1 ESIGN 1 ESLOPE 2 EX88 2 EY 1 PAR 1 SV 1 KV 1 KY 1
RUNP 2 NRUN 1 SA 1 SB 1 RA 1 RB 1 TLV 1 TRV 1 KA 1 KB 1 L1V 1 R1V 1 RUNS0 2 CR_R 1 LBASE 2
CLV 1 OLDCL 1 CR1 1 C0V 1 SPLIT 1 BAND 1 BACC 1 BGV 1 SKYTAB 2 crow 1 RX0 1 RX1 1 RY0 1 RY1 1
RY 1 MLEFT 1 MRIGHT 1 FIELDS 2 LASTF 2 ELAPSED 1 READY 1 FSPLIT 1 DSPLIT 1 COPIED 1
SPLITMODE 1 STEER 1 THROT 1 BRAKE 1 IDLE 2 AUTO 1 MPREV 1 SPEED 1 LATV 1 SPSV 2 LATCHV 1
RUNBUF 16 FRAMES 2 CRF 1 FLG 1 PKX 2 PKY 2 HALFON 1 HPREV 1 SKYD 1 HUDFG 1
SKYDIRTY 1 HUDFORCE 1 TOPCHG 1 FACC 1 FCNT 1 FAVG 1
SKYPTR 28 MKSH 1 SKYLN 1 SKY_Y 1 MSPLIT 1 CURMODE 1 ATIMER 2 RVANY 1"""
for _n in 'RUNBUF 16 CPT 6 ZNL 2 ZNR 2 FARP 2 RUNS0 2 LBASE 2 RUNP 2'.split()[0::2]: pass
VARS = VARS.replace('RUNBUF 16', 'RDX 2 RX 2 RDH 2 RH 2 RLX 2 RLS 2 RLP 2 RPGP 2').replace('CPT 6', 'RTOP 1 RD 1 RS0 1 RN 1 RBAND 1 RROW 1').replace('ZNL 2 ZNR 2', 'RB0 1 RB1 1 RB2 1 RB3 1')
CVARS = """PHASE 1 CUPN 1 PTS 4 SCORES 8 TSC 2 ORDERP 4 WEAPON 1 AIRT 1 AIRTOT 1 VOLTCD 2 RAZECD 2 PHITT 1
OBJCOL 2 LATBASE 1 FIREPREV 1 SHOTT 1 MINEOWN 1 OBJK 2"""
GVARS = """GSTATE 1 STIMER 2 LAPN 1 RTIME 2 LAPT0 2 BESTLAP 2 SHIELD 1 BOOSTT 1 STALLT 1 BUMPT 1 POS 1
FINPOS 1 NEWBEST 1 SFXT 1 SFXK 1 BANT 1 BANP 2 SPREV 1 TMPT 1 TPOS 2 LOWERFN 2 TBUF 20 RVDH 2 RVDC 1 SPLAIN 1 CLEAN 1 DMIN 1 CPYROW 1 EXSRC 2 EXDST 2 EXS 2 EXFREE 2"""

LAYOUT = dict(
    LATCH=0x6800, KEYROW=0x68EF, KEYH=0x687F, VRAM=0x7000,
    SQPAGE=0xB0, RDP0=0xD200, ROWPG=0xD240, RDP1=0xE600, XCA=0xE000, SECL=0xE100, ROWMAP=0xE180, ZTL=0xE200, DIDX=0xE300, SIN64=0xB400, COS64=0xB500, PATTAB=0xB600, LMASK=0xB620, SKYA=0xB628, SKYH=0xB650, RIDGE=0xAF00, HUDBUF=0x7E20, HUDPREV=0x7E60, GVARS=0x7D80, RV=0x7EC0, CVARS=0x7DC0, MARK=0x7E00, TOPT=0x7EA0, LOGO=0xDE40, SKY0=0xB630, SKY1=0xB638,
    GLYPHT=0xB640, GLYPHM=0xB648, FONT=0xB660, SKYIMG=0xFA00, EXPTP=0xB800, EXP88L=0xBA00, LOGL=0xC200,
    IM2TAB=0xDC00, 
    XMIN=0xE000, XMAX=0xE100, TMIN=0xE200, TMAX=0xE300, ROWCL=0xE400, ROWLP=0xE500,
    GATES=0xE600, BGROW=0xDE00, VARS=0xE700, SECS=0xE800, LISTS=0xEA00, BUFFER=0xF200, STACKTOP=0xE6FE,
)
CRAFTY = 52
HALF_INIT = None
ATTRACT_MODE = 0
RACE_AUTOPILOT = 0
VMAX = 110
COPYT = 128 * 244 + 32 * 25 + 80
DLY_COPY = max(1, ((56 + 64) * 226 - COPYT - 450) // 26)
DLY_COPYP = DLY_COPY + (32 * 244 + 8 * 25) // 26
DLY_NOCOPY = (64 * 226 - 60) // 26

CRAFT = [
    "......222222222222......",
    "....2222222222222222....",
    "...222222222222222222...",
    "..22233322222222233322..",
    "..22233322222222233322..",
    "..22222222222222222222..",
    "...222222111111222222...",
    "....2222222222222222....",
    ".......2222222222.......",
]

def sprites():
    out = []
    for sh in range(4):
        for row in CRAFT:
            px = ['.'] * sh + list(row) + ['.'] * (28 - sh - len(row))
            for b in range(7):
                mask = data = 0
                for q in range(4):
                    ch = px[b * 4 + q]; s = 6 - 2 * q
                    if ch == '.': mask |= 3 << s
                    else: data |= int(ch) << s
                out += [mask, data]
        out += [0, 0]           # pad set to 128 bytes
    return out

FONT = {
 ' ': [0,0,0,0,0], '#': [7,7,7,7,7], '0': [7,5,5,5,7], '1': [2,6,2,2,7], '2': [7,1,7,4,7], '3': [7,1,3,1,7],
 '4': [5,5,7,1,1], '5': [7,4,7,1,7], '6': [7,4,7,5,7], '7': [7,1,1,2,2], '8': [7,5,7,5,7],
 '9': [7,5,7,1,7], 'A': [2,5,7,5,5], 'B': [6,5,6,5,6], 'C': [3,4,4,4,3], 'D': [6,5,5,5,6],
 'E': [7,4,6,4,7], 'F': [7,4,6,4,4], 'G': [3,4,5,5,3], 'H': [5,5,7,5,5], 'I': [7,2,2,2,7],
 'J': [1,1,1,5,2], 'K': [5,5,6,5,5], 'L': [4,4,4,4,7], 'M': [5,7,7,5,5], 'N': [6,5,5,5,5],
 'O': [2,5,5,5,2], 'P': [6,5,6,4,4], 'Q': [2,5,5,6,3], 'R': [6,5,6,5,5], 'S': [3,4,2,1,6],
 'T': [7,2,2,2,2], 'U': [5,5,5,5,7], 'V': [5,5,5,5,2], 'W': [5,5,7,7,5], 'X': [5,5,2,5,5],
 'Y': [5,5,2,2,2], 'Z': [7,1,2,4,7], ':': [0,2,0,2,0], '-': [0,0,7,0,0], '.': [0,0,0,0,2],
 ',': [0,0,0,2,4], '/': [1,1,2,4,4], '!': [2,2,2,0,2],
}

def db(data, per=32):
    return '\n'.join('        DB ' + ','.join(str(v & 255) for v in data[i:i + per]) for i in range(0, len(data), per))

def equates():
    lines = [f'{k:10s} EQU ${v:04X}' for k, v in LAYOUT.items()]
    off = 0
    toks = VARS.split()
    for name, size in zip(toks[0::2], toks[1::2]):
        lines.append(f'{name:10s} EQU VARS+{off}'); off += int(size)
    assert off <= 256, off
    off = 0
    toks = GVARS.split()
    for name, size in zip(toks[0::2], toks[1::2]):
        lines.append(f'{name:10s} EQU GVARS+{off}'); off += int(size)
    assert off <= 0x40, off
    lines.append(f'LOG_RIVW EQU {R.LOGT[36]}')
    off = 0
    toks = CVARS.split()
    for name, size in zip(toks[0::2], toks[1::2]):
        lines.append(f'{name:10s} EQU CVARS+{off}'); off += int(size)
    assert off <= 64, off
    lines.append(f'SPRDESC EQU ${SPR_DESC_AT:04X}')
    lines.append(f'STAGE EQU ${STAGE:04X}')
    lines.append(f'STG_TRK EQU ${STG_TRK:04X}')
    for k in ('P0', 'SH', 'N_red0', 'M_red0', 'N_blue0', 'M_blue0'):
        lines.append(f'SPR_{k.upper()} EQU ${SPR_SYMS[k]:04X}')
    lines += [f'NEARZ EQU {R.NEARZ}', f'CH EQU {R.CH}', f'HORIZ EQU {R.HORIZ}', f'DEPTH EQU 30', f'HZ0 EQU {RR.HZ0}', f'ND EQU {RR.ND}', f'RYMIN EQU {RR.YMIN}', f'G_ID EQU {RR.G_ID}', f'R_ID EQU {RR.R_ID}', f'C_ID EQU {RR.C_ID}', f'PAD_ID EQU {RR.PAD_ID}', f'RAMP_ID EQU {RR.RAMP_ID}', f'LINE_ID EQU {RR.LINE_ID}',
              f'BIAS EQU {R.BIAS}', f'LOGFX EQU {R.LOGFX}', f'LOGFY EQU {R.LOGFY}',
              f'C_RAIL EQU {R.LOGT[R.RAIL_E] + R.LOGFX + R.BIAS}',
              f'C_SKIRT EQU {(R.LOGT[R.SKIRT_E] + R.LOGFY + R.BIAS) if R.SKIRT_ON else -4000}',
              f'LOD1 EQU {R.LOD1}', f'LOD2 EQU {R.LOD2}',
              f'HALFROW EQU {R.HALFROW}', f'TOPROW EQU {R.TOPROW}', f'SKYL_H EQU {R.SKYL_H}', f'ATTRACT_MODE EQU {ATTRACT_MODE}', f'RACE_AUTOPILOT EQU {RACE_AUTOPILOT}', f'HALF_INIT EQU {HALF_INIT if HALF_INIT is not None else (1 if R.HALF_ON else 0)}',
              f'C_GH EQU {R.LOGT[R.GATEH_E] + R.LOGFY + R.BIAS}',
              f'C_GW EQU {R.LOGT[R.GATEW_E] + R.LOGFX + R.BIAS}',
              f'C_GT EQU {R.LOGT[R.GATET_E] + R.LOGFY + R.BIAS}',
              f'SU_A EQU {R.SU_A}', f'BOOST_A EQU {R.BOOST_A}', f'BOOST_B EQU {R.BOOST_B}', f'RAMP_A EQU {R.RAMP_A}', f'RAMP_B EQU {R.RAMP_B}', f'SU_B EQU {R.SU_B}', f'RL_A EQU {R.RL_A}', f'RL_B EQU {R.RL_B}',
              f'SK EQU {R.SK}', f'VOID EQU {R.VOID}', f'HAZE EQU {R.HAZE}',
              f'CRAFTY EQU {CRAFTY}', f'VMAX EQU {VMAX}',
              f'DLY_COPY EQU {DLY_COPY}', f'DLY_NOCOPY EQU {DLY_NOCOPY}', f'DLY_COPYP EQU {DLY_COPYP}', f'LOGO_TOP EQU {logo.TOP}', f'LOGO_N EQU {len(LOGO_RLE)}', f'TDLY EQU {(64 + 34 * 3) * 226 // 26}', f'EXP88H EQU EXP88L+$400']
    return '\n'.join(lines)

def copy_routine():
    """BUFFER -> VRAM through the stack, 16 bytes per chunk, 4 chunks per loop pass."""
    chunk = ['        ld sp,ix', '        pop af', '        pop bc', '        pop de', '        pop hl',
             '        exx', '        pop bc', '        pop de', '        pop hl', "        ex af,af'", '        pop af',
             '        ld sp,iy', '        push af', "        ex af,af'", '        push hl', '        push de',
             '        push bc', '        exx', '        push hl', '        push de', '        push bc', '        push af',
             '        ld de,16', '        add ix,de', '        add iy,de']
    L = ['copy_buffer16:                   ; from row CPYROW (even) to the bottom',
         '        ld a,(CPYROW)', '        ld l,a', '        ld h,0', '        add hl,hl', '        add hl,hl',
         '        add hl,hl', '        add hl,hl', '        add hl,hl', '        push hl', '        ld de,BUFFER',
         '        add hl,de', '        push hl', '        pop ix', '        pop hl', '        ld de,VRAM+16',
         '        add hl,de', '        push hl', '        pop iy', '        jr cb_go',
         'copy_buffer:', '        ld ix,BUFFER', '        ld iy,VRAM+16',
         '@cb_go:', '        ld (SPSV),sp', '@cb_lp:']
    L += chunk * 4
    L += ['        ld a,ixh', '        cp (BUFFER+2048)/256', '        jp nz,cb_lp', '        ld sp,(SPSV)', '        ret']
    return '\n'.join(L)

LOGO_RLE = logo.rle(logo.logo())
STAGE = 0xE800                      # loaded with the program, moved into SRAM bank B at start-up
SPR_SRC, SPR_DESC, SPR_SYMS, SPR_END = craft2.build(STAGE)
SPR_DESC_AT = STAGE + len(SPR_SRC)
STG_TRK = SPR_DESC_AT + len(SPR_DESC)  # track tables (4 x 512) follow
assert STG_TRK + 2048 <= 0xF800, hex(STG_TRK + 2048)
BANK_TRK = SPR_END                     # their home in bank B
assert BANK_TRK + 2048 <= 0x6800
LAYOUT.update(TRK_H=BANK_TRK, TRK_DY=BANK_TRK + 512, TRK_CV=BANK_TRK + 1024, TRK_SL=BANK_TRK + 1536)
assert len(LOGO_RLE) <= 0xE000 - 0xDE40, len(LOGO_RLE)

def data_section(T):
    lo, hi = R.sq_tables()
    font = []
    for code in range(32, 96): font += FONT.get(chr(code), [7, 5, 5, 5, 7])
    glyph = []
    for bits in range(8):
        b = 0
        for q in range(4):
            on = q < 3 and (bits >> (2 - q)) & 1
            b |= (1 if on else 2) << (6 - 2 * q)
        glyph.append(b)
    expl = [v & 255 for v in R.EXP88]; exph = [v >> 8 for v in R.EXP88]
    logl = [v & 255 for v in R.LOGT]; logh = [v >> 8 for v in R.LOGT]
    parts = [
        ('SQPAGE*256', lo + hi), ('SIN64', R.SIN64), ('COS64', R.COS64),
        ('PATTAB', R.PATE + R.PATO), ('RDP0', RR.PAGE0), ('RDP1', RR.PAGE1),
        ('ZTL', [v & 255 for v in RR.ZT] + [0] * 31 + [v >> 8 for v in RR.ZT] + [0] * 31 + RR.WT + [0] * 31 + RR.RWT), ('DIDX', RR.DIDX), ('LMASK', [0xFF, 0x3F, 0x0F, 0x03, 0xC0, 0xF0, 0xFC, 0xFF]),
        ('SKY0', R.SKY_CSS0), ('SKYA', R.SKY_A), ('SKYH', R.SKY_H), ('RIDGE', R.RIDGE), ('SKY1', R.SKY_CSS1), ('GLYPHT', glyph), ('FONT', font),
        ('GLYPHM', [sum(3 << (6 - 2 * q) for q in range(3) if (bits >> (2 - q)) & 1) for bits in range(8)]),
        ('EXPTP', R.EXPT), ('EXP88L', expl + exph), ('LOGL', logl + logh),
        ('STAGE', SPR_SRC + SPR_DESC + T['H'] + T['DY'] + T['CURV'] + T['SLP']),
        ('IM2TAB', [0xDD] * 257), ('LOGO', LOGO_RLE),
    ]
    out = []
    for org, data in parts:
        out.append(f'        ORG {org}\n{db(data)}')
    out.append('        ORG $DD01\n' + open(os.path.join(HERE, 'skyline_init.asm')).read()
               + open(os.path.join(HERE, 'strings_title.asm')).read() + '\n@init_end:')
    objs = []
    for n in range(16):                       # pickups: boost, energy, missile, mine in turn
        k = 20 + 32 * n
        objs += [k & 255, k >> 8, (-28, 0, 28, 0)[n % 4] & 255, n % 4]
    for k in (40, 168, 296, 424):             # boost arrows on the pads
        objs += [k & 255, k >> 8, 0, 4]
    out.append('        ORG $D280\n' + open(os.path.join(HERE, 'game2.asm')).read()
               + '\nOBJTAB:\n' + db(objs) + '\n@game2_end:')
    out.append('        ORG $DDDD\n        jp isr')
    return '\n'.join(out)

def source(test_state=None):
    T = RR.build_track()
    eng = open(os.path.join(HERE, 'road.asm')).read()
    chk = '' if test_state else '        ld a,(LATCH)\n        rla\n        jr nc,$+3\n        ei'
    if test_state:
        st = test_state
        startup = f'''        ld hl,{st['i']}
        ld (CAM_I),hl
        ld a,{st['f']}
        ld (CAM_F),a
        ld hl,{st['lat'] & 0xFFFF}
        ld (CAM_LAT),hl
        ld a,{st['theta'] & 255}
        ld (CAM_TH),a
        xor a
        ld (AUTO),a
        call mode_upd
        call render
        call compose
        halt'''
    else:
        startup = '''        ld hl,TOPT              ; best times start empty
        ld b,8
.bt:    ld (hl),$FF
        inc hl
        djnz .bt
        call demo_reset
        ld hl,lower_keys
        call title_card
        ld a,IM2TAB/256
        ld i,a
        im 2
        ei
        jp main
'''
    src = open(os.path.join(HERE, 'race.asm')).read()
    src = src.replace('{EQUATES}', equates()).replace('{STARTUP}', startup)
    src = src.replace('{GAME}', open(os.path.join(HERE, 'game.asm')).read())
    src = src.replace('{ENGINE}', eng).replace('{COPY}', copy_routine())
    src = src.replace('{FILL}', '\n'.join('        ld (de),a\n        inc e' for _ in range(32)))
    src = src.replace('{DATA}', data_section(T))
    import re
    def _chk(m):
        lab = m.group(1) or ''
        return (lab + '\n' if lab else '') + chk
    src = re.sub(r'^([A-Za-z_.][A-Za-z0-9_.]*:)?[ \t]*CHKEI[ \t]*$', _chk, src, flags=re.M)
    return src, T

def assemble(src, name):
    asm = Asm()
    org, data = asm.assemble(src, HERE)
    code_end = max(asm.sym['FILL2'] + 66, asm.sym['LOGO_END'])
    assert asm.sym['CODE_END_REAL'] <= asm.sym['FILL2']
    assert code_end <= 0xAF00, f'code overruns the skyline ridge: ${code_end:04X}'
    assert org + len(data) <= 0xF800
    assert asm.sym['GAME2_END'] <= 0xDC00, f"game2 overruns: ${asm.sym['GAME2_END']:04X}"
    assert asm.sym['INIT_END'] <= 0xDDDD, f"init code overruns: ${asm.sym['INIT_END']:04X}"
    vz = os.path.join(HERE, name)
    open(vz, 'wb').write(vz_file(name.split('.')[0][:16], org, data))
    return asm, org, data, vz

def build_game():
    src, T = source()
    open(os.path.join(HERE, 'race_full.asm'), 'w').write(src)
    asm, org, data, vz = assemble(src, 'MAXQ.VZ')
    with open(os.path.join(HERE, 'race.lst'), 'w') as fh:
        fh.write('\n'.join(asm.listing) + '\n\nSYMBOLS\n')
        for k in sorted(asm.sym): fh.write(f'{k:24s} {asm.sym[k] & 0xFFFF:04X}\n')
    print(f'MAXQ.VZ ${org:04X}-${org + len(data) - 1:04X} ({len(data)} bytes); code ends ${asm.sym["LOGO_END"]:04X}')
    return asm

def run_test(states):
    T = RR.build_track()
    ok = 0
    for n, st in enumerate(states):
        src, _ = source(st)
        asm, org, data, vz = assemble(src, 'TEST.VZ')
        mem = os.path.join(HERE, 'mem_test.bin')
        out = subprocess.run([EMU, vz, '30000000', '--memdump', mem], capture_output=True, text=True,
                             stdin=subprocess.DEVNULL).stdout
        m = open(mem, 'rb').read()
        got = list(m[LAYOUT['BUFFER']:LAYOUT['BUFFER'] + 2048])
        exp, fr = RR.compose(T, st)
        same = got == exp
        ok += same
        tline = [l for l in out.splitlines() if l.startswith('stopped')]
        if not same:
            diff = [i for i in range(2048) if got[i] != exp[i]]
            print(f'state {n} {st}: MISMATCH {len(diff)} bytes, first at row {diff[0]//32} col {diff[0]%32}  {tline}')
        else:
            print(f'state {n}: match  {tline[0] if tline else out[-200:]}')
    print(f'{ok}/{len(states)} frames identical')
    return ok == len(states)

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        import random
        random.seed(3)
        states = [dict(i=4, f=0, lat=0, theta=0), dict(i=40, f=128, lat=20, theta=2), dict(i=30, f=60, lat=-10, theta=0)]
        for _ in range(int(sys.argv[2]) if len(sys.argv) > 2 else 10):
            states.append(dict(i=random.randrange(512), f=random.randrange(256),
                               lat=random.randrange(-56, 57), theta=random.randrange(-6, 7)))
        run_test(states)
    else:
        build_game()
