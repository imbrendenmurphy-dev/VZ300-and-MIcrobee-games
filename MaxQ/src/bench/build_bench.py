#!/usr/bin/env python3
"""
build_bench.py - generates bench.asm + BENCH.VZ for the VZ300 3D racer Stage 2
benchmark (VIBED BY BPM 2026), and the expected results the Z80 must match.

The bench times the engine's real inner routines against the VZ's field-sync
signal (no interrupts), shows the results on screen, then shows a genuine
renderer-D track frame composed by the Z80, with the sky in the second colour
set via a mid-frame CSS switch.
"""
import sys, os, math, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import proto
from z80asm import Asm, vz_file

FRAME = 150            # which prototype frame to export
LINE_T = 227
TOP_LINES = 64         # assumed lines from end of field sync to first picture line (to verify on hardware)

# ---------------------------------------------------------------- data
# colour ids from renderer D -> compose colour index (0..15)
IDMAP = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8, 20: 9, 21: 10, 22: 2, 23: 3, 24: 1}
PAT_PAIRS = {0: (0, 0), 1: (1, 1), 2: (2, 2), 3: (3, 3), 4: (0, 2), 5: (3, 2), 6: (1, 0), 7: (1, 3),
             8: (2, 0), 9: (1, 2), 10: (2, 3)}
def pat_byte(c, parity):
    a, b = PAT_PAIRS.get(c, (2, 2))
    if parity: a, b = b, a
    return (a << 6) | (b << 4) | (a << 2) | b
PATE = [pat_byte(c, 0) for c in range(16)]
PATO = [pat_byte(c, 1) for c in range(16)]
LM = {0: 0x00, 1: 0xC0, 2: 0xF0, 3: 0xFC}          # left pixels 0..s-1
MR = [0xFF, 0x3F, 0x0F, 0x03]                        # pixels k..3

def btab():
    out = []
    for par in (0, 1):
        P = PATO if par else PATE
        for cl in range(16):
            for cr in range(16):
                for s in range(4):
                    out.append((P[cl] & LM[s]) | (P[cr] & ~LM[s] & 0xFF))
    return out

def sq_tables():
    lo, hi = [], []
    for n in range(512):
        v = ((n - 256) ** 2) // 4
        lo.append(v & 0xFF); hi.append(v >> 8)
    return lo, hi

def recip():
    return [min(127, 2032 // max(1, z)) for z in range(256)]

def export_frame():
    """Run renderer D up to FRAME and return per-row run lists + split row."""
    secs = proto.build_track()
    pos = 3.0; speed = 0.0; lateral = 0.0; yawoff = 0.0; steer = 0.0
    for fr in range(FRAME + 1):
        speed = min(1.15, speed + 0.02); pos += speed
        curv = secs[int(pos) + 3][3] - secs[int(pos)][3]
        target = -curv * 6 * proto.HALFW * 0.6
        steer += ((target - lateral) * 0.6 - steer) * 0.25
        lateral += (target - lateral) * 0.08
        yawoff = (yawoff + (curv * 0.8 - yawoff) * 0.2)
        proto.render_d(secs, pos, lateral, -yawoff * 0.5, fr, max(-3, min(3, steer)))
    rows = []
    for y in range(64):
        cols = [IDMAP[c] for c in proto.LASTCOLS[y]]
        runs = []
        for x, c in enumerate(cols):
            if not runs or runs[-1][1] != c: runs.append((x, c))
        # list must fit a 32-byte slot: at most 15 pairs + terminator
        while len(runs) > 15:
            # merge the narrowest run into its left neighbour
            i = min(range(1, len(runs)), key=lambda k: (runs[k + 1][0] if k + 1 < len(runs) else 128) - runs[k][0])
            del runs[i]
            runs = [r for j, r in enumerate(runs) if j == 0 or r[1] != runs[j - 1][1]]
        rows.append(runs)
    return rows, proto.LASTSPLIT[0]

def compose_ref(rows):
    """Exactly what the Z80 composer must produce (2048 bytes)."""
    img = []
    for y, runs in enumerate(rows):
        P = PATO if y & 1 else PATE
        pix = []
        for i, (x, c) in enumerate(runs):
            x1 = runs[i + 1][0] if i + 1 < len(runs) else 128
            pix += [c] * (x1 - x)
        for j in range(32):
            b = 0
            for k in range(4):
                b |= P[pix[j * 4 + k]] & (0xC0 >> (2 * k))
            img.append(b)
    return img

def insert_ref(src, comp, X1):
    """Reference for the Z80 INSERT routine. src/comp are lists of (x,c)."""
    X0 = comp[0][0]
    out = []; i = 0; c = None
    while src[i][0] < X0:
        out.append(src[i]); c = src[i][1]; i += 1
    out += comp
    while i < len(src) and src[i][0] <= X1:
        c = src[i][1]; i += 1
    if X1 + 1 < 128 and not (i < len(src) and src[i][0] == X1 + 1):
        out.append((X1 + 1, c))
    out += src[i:]
    return out

def listbytes(runs):
    b = []
    for x, c in runs: b += [x, c]
    return b + [128]

# 3x5 font: rows top->bottom, 3 bits each (bit2 = left pixel)
FONT = {
 ' ': [0,0,0,0,0], '0': [7,5,5,5,7], '1': [2,6,2,2,7], '2': [7,1,7,4,7], '3': [7,1,3,1,7],
 '4': [5,5,7,1,1], '5': [7,4,7,1,7], '6': [7,4,7,5,7], '7': [7,1,1,2,2], '8': [7,5,7,5,7],
 '9': [7,5,7,1,7], 'A': [2,5,7,5,5], 'B': [6,5,6,5,6], 'C': [3,4,4,4,3], 'D': [6,5,5,5,6],
 'E': [7,4,6,4,7], 'F': [7,4,6,4,4], 'G': [3,4,5,5,3], 'H': [5,5,7,5,5], 'I': [7,2,2,2,7],
 'J': [1,1,1,5,2], 'K': [5,5,6,5,5], 'L': [4,4,4,4,7], 'M': [5,7,7,5,5], 'N': [6,5,5,5,5],
 'O': [2,5,5,5,2], 'P': [6,5,6,4,4], 'Q': [2,5,5,6,3], 'R': [6,5,6,5,5], 'S': [3,4,2,1,6],
 'T': [7,2,2,2,2], 'U': [5,5,5,5,7], 'V': [5,5,5,5,2], 'W': [5,5,7,7,5], 'X': [5,5,2,5,5],
 'Y': [5,5,2,2,2], 'Z': [7,1,2,4,7], ':': [0,2,0,2,0], '-': [0,0,7,0,0], '.': [0,0,0,0,2],
 '/': [1,1,2,4,4], '?': [7,1,3,0,2], '!': [2,2,2,0,2],
}
def font_table():
    t = []
    for code in range(32, 96):
        t += FONT.get(chr(code), [7, 5, 5, 5, 7])  # unknown -> box
    return t
def glyph_bytes(fg=1, bg=2):
    out = []
    for bits in range(8):
        b = 0
        for k in range(4):
            on = k < 3 and (bits >> (2 - k)) & 1
            b |= (fg if on else bg) << (6 - 2 * k)
        out.append(b)
    return out

def db_lines(data, per=16):
    return '\n'.join('        DB ' + ','.join(str(v) for v in data[i:i + per]) for i in range(0, len(data), per))

# ---------------------------------------------------------------- source
def build():
    rows, split = export_frame()
    img = compose_ref(rows)
    cks = sum(img) & 0xFFFF
    template = [(0, 2), (20, 5), (24, 7), (27, 4), (90, 7), (93, 5), (98, 2)]
    comp = [(30, 5), (33, 1), (36, 0), (70, 1), (73, 5)]
    X1 = 78
    ins_exp = listbytes(insert_ref(template, comp, X1))
    # MUL8 check: sum of products over a grid, 16-bit
    mulsum = 0
    for a in range(-128, 128, 7):
        for b in range(-128, 128, 11):
            mulsum = (mulsum + a * b) & 0xFFFF
    lo, hi = sq_tables()
    delay_t = (TOP_LINES + split * 3) * LINE_T - 40
    dly = max(1, delay_t // 26)
    edge = '\n'.join('        add hl,bc\n        ld a,h\n        ld (de),a\n        inc e' for _ in range(64))
    lists = []
    for y, runs in enumerate(rows):
        b = listbytes(runs); b += [0] * (32 - len(b)); lists += b
    src = TEMPLATE.format(
        EDGE=edge, DLY=dly,
        MULSUM=mulsum, CKS=cks,
        LISTS=db_lines(lists, 32),
        BTAB=db_lines(btab(), 32),
        SQLO=db_lines(lo, 32), SQHI=db_lines(hi, 32),
        RECIP=db_lines(recip(), 32),
        PATE=','.join(map(str, PATE)), PATO=','.join(map(str, PATO)),
        MR=','.join(map(str, MR)),
        GLYPH=','.join(map(str, glyph_bytes())),
        FONT=db_lines(font_table(), 20),
        TEMPL=','.join(map(str, listbytes(template))),
        COMP=','.join(map(str, [len(comp)] + [v for p in comp for v in p] + [X1])),
        INSEXP=','.join(map(str, ins_exp)), INSLEN=len(ins_exp),
    )
    open(os.path.join(HERE, 'bench.asm'), 'w').write(src)
    asm = Asm()
    org, data = asm.assemble(src, HERE)
    code_end = asm.sym['FILLBLK'] + 65
    assert code_end <= 0x9000, f'code runs into LISTS: ${code_end:04X}'
    assert len(data) < 31000, 'too big for a .VZ'
    open(os.path.join(HERE, 'BENCH.VZ'), 'wb').write(vz_file('BENCH', org, data))
    with open(os.path.join(HERE, 'bench.lst'), 'w') as fh:
        fh.write('\n'.join(asm.listing) + '\n\nSYMBOLS\n')
        for k in sorted(asm.sym): fh.write(f'{k:24s} {asm.sym[k] & 0xFFFF:04X}\n')
    meta = dict(org=org, end=org + len(data) - 1, split=split, cks=cks, mulsum=mulsum,
                dly=dly, sym={k: asm.sym[k] for k in asm.sym if not k.startswith('.')}, img=img,
                rows=[[list(r) for r in rr] for rr in rows])
    json.dump(meta, open(os.path.join(HERE, 'bench_meta.json'), 'w'))
    print(f'BENCH.VZ: ${org:04X}-${org + len(data) - 1:04X} ({len(data)} bytes), split row {split}, '
          f'max runs/row {max(len(r) for r in rows)}')
    return meta

TEMPLATE = r'''
; =====================================================================
;  BENCH.ASM - VZ300 3D racer, Stage 2 benchmark      VIBED BY BPM 2026
;  Loads low at $8000, no mapper writes, no ROM or DOS calls, DI throughout.
;  Times each routine against field sync (bit 7 of $6800): run it k times
;  from a field-sync edge, then count fixed 35T poll loops to the next edge,
;  and compare with the same run using an empty routine.
; =====================================================================
LATCH   EQU $6800
VRAM    EQU $7000
SQPAGE  EQU $A0
RECIPT  EQU $A400
PATTAB  EQU $A500       ; even row patterns +0, odd +16
MRTAB   EQU $A520
GLYPHT  EQU $A530
BTABP   EQU $98         ; boundary-byte table $9800-$9FFF
LISTS   EQU $9000       ; 64 row run lists x 32 bytes
STACKTOP EQU $BFF0
RAMBUF  EQU $C000       ; RAM compose target (contention comparison)
INSSRC  EQU $C800
INSDST  EQU $C820
XTAB    EQU $C900
VERT    EQU $CA00
RES     EQU $CB10       ; results, 3 bytes each (no slot has low byte 0)
CHK     EQU $CB80       ; check flags (1 = OK)
VARS    EQU $CC00

R_FIELD EQU RES+0
R_SYNC  EQU RES+3
R_MUL   EQU RES+6
R_XF    EQU RES+9
R_EDGE  EQU RES+12
R_INS   EQU RES+15
R_CV    EQU RES+18
R_CR    EQU RES+21
R_FV    EQU RES+24
R_FR    EQU RES+27

seed    EQU VARS+0
cdest   EQU VARS+2
crow    EQU VARS+4
spsv    EQU VARS+6
m_k     EQU VARS+8
pnull   EQU VARS+10
xr      EQU VARS+12
zr      EQU VARS+13
yr      EQU VARS+14
zr2     EQU VARS+15
pend    EQU VARS+16
numbuf  EQU VARS+32
cstart  EQU VARS+20
cend    EQU VARS+21
acc     EQU VARS+24
CY      EQU VARS+48
SY      EQU VARS+49
CPV     EQU VARS+50
SPV     EQU VARS+51

        ORG $8000
start:  di
        ld sp,STACKTOP
        ld a,$08                ; mode(1), colour set 0
        ld (LATCH),a
        ld hl,$AAAA
        ld (seed),hl
        call cls
        ld hl,s_wait
        ld de,$0000
        call print_at

; ---------- field calibration
        call sync_fall
        call poll_count         ; HL = total polls, DE = polls during sync
        push de
        call mul35
        ld ix,R_FIELD
        call store24
        pop hl
        call mul35
        ld ix,R_SYNC
        call store24

; ---------- fills (2048 bytes by PUSH) to VRAM and RAM
        ld hl,retonly
        ld de,fillv
        ld bc,2
        call bench2
        ld b,1
        ld ix,R_FV
        call result
        ld hl,retonly
        ld de,fillr
        ld bc,2
        call bench2
        ld b,1
        ld ix,R_FR
        call result

; ---------- MUL8 (quarter-square, signed 8x8)
        ld hl,mul_pre
        ld de,MUL8
        ld bc,128
        call bench2
        ld b,7
        ld ix,R_MUL
        call result
        call mul_check

; ---------- full vertex transform (yaw + pitch + project, 10 multiplies)
        ld a,118
        ld (CY),a
        ld a,48
        ld (SY),a
        ld a,126
        ld (CPV),a
        ld a,-15
        ld (SPV),a
        ld hl,xf_pre
        ld de,XFORM
        ld bc,16
        call bench2
        ld b,4
        ld ix,R_XF
        call result

; ---------- edge stepping, 64 rows unrolled
        ld hl,edge_pre
        ld de,EDGE64
        ld bc,16
        call bench2
        ld b,4
        ld ix,R_EDGE
        call result

; ---------- composite interval insert into a row run list
        ld hl,ins_pre
        ld de,INSERT
        ld bc,16
        call bench2
        ld b,4
        ld ix,R_INS
        call result
        call ins_check

; ---------- compose a full frame (64 rows) into RAM, then VRAM
        ld hl,RAMBUF
        ld (cdest),hl
        ld ix,R_CR
        call comp_timed
        call cmp_check
        ld hl,VRAM
        ld (cdest),hl
        ld ix,R_CV
        call comp_timed

; ---------- show results, then the composed frame with the sky split, forever
show:   call cls
        call print_results
showres:
        ld b,200
.w1:    push bc
        call sync_fall
        pop bc
        djnz .w1
        ld hl,VRAM
        ld (cdest),hl
        call compose_all
showimg:
        ld b,250
.w2:    push bc
        call sync_fall
.w3:    ld a,(LATCH)            ; wait for end of field sync
        rla
        jr nc,.w3
        ld a,$18                ; sky: colour set 1
        ld (LATCH),a
        ld bc,{DLY}
.dl:    dec bc
        ld a,b
        or c
        jr nz,.dl
        ld a,$08                ; track: colour set 0
        ld (LATCH),a
        pop bc
        djnz .w2
        jp show

; =====================================================================
;  timing harness
; =====================================================================
sync_fall:                      ; return just after field sync starts
.a:     ld a,(LATCH)
        rla
        jr nc,.a
.b:     ld a,(LATCH)
        rla
        jr c,.b
        ret

poll_count:                     ; polls (35T each) until next sync start
        ld hl,0
        ld de,0
.lo:    inc de
        ld a,(LATCH)
        rla
        jr nc,.lo
.hi:    inc hl
        ld a,(LATCH)
        rla
        jr c,.hi
        add hl,de
        ret

measure:                        ; BC = k ; returns HL = polls left in the field
        ld (m_k),bc
        call sync_fall
        ld bc,(m_k)
meas_lp: push bc
m_pre:  call retonly
m_tgt:  call retonly
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,meas_lp
        jp poll_count

bench2:                         ; HL = pre hook, DE = routine, BC = k ; HL = Pnull - Px
        ld (m_pre+1),hl
        push de
        push bc
        ld hl,retonly
        ld (m_tgt+1),hl
        call measure
        ld (pnull),hl
        pop bc
        pop de
        ld (m_tgt+1),de
        call measure
        ex de,hl
        ld hl,(pnull)
        or a
        sbc hl,de
        ret

result:                         ; HL = poll difference, B = log2(k), IX -> 3-byte slot
        push bc
        call mul35              ; C:HL = T for k calls
        pop af                  ; A = shift count (from B)
        or a
        jr z,store24
.sh:    srl c
        rr h
        rr l
        dec a
        jr nz,.sh
store24:
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+2),c
        ret

mul35:                          ; C:HL = HL * 35
        ld d,h
        ld e,l
        ld b,0
        ld c,0
        sla e
        rl d
        rl b
        add hl,de
        ld a,c
        adc a,b
        ld c,a
        sla e
        rl d
        rl b
        sla e
        rl d
        rl b
        sla e
        rl d
        rl b
        sla e
        rl d
        rl b
        add hl,de
        ld a,c
        adc a,b
        ld c,a
        ret

retonly:
        ret

comp_timed:                     ; time COMPOSE as 4 chunks of 16 rows, sum into (IX)
        push ix
        ld hl,0
        ld (acc),hl
        ld (acc+2),hl
        xor a
.ch:    ld (cstart),a
        add a,16
        ld (cend),a
        ld hl,retonly
        ld de,COMPOSE
        ld bc,1
        call bench2
        call mul35              ; C:HL
        ld de,(acc)
        add hl,de
        ld (acc),hl
        ld a,(acc+2)
        adc a,c
        ld (acc+2),a
        ld a,(cend)
        cp 64
        jr nz,.ch
        pop ix
        ld hl,(acc)
        ld a,(acc+2)
        ld c,a
        jp store24

compose_all:                    ; whole frame (used for display)
        xor a
        ld (cstart),a
        ld a,64
        ld (cend),a
        jp COMPOSE

; =====================================================================
;  routines under test
; =====================================================================
fillv:  ld (spsv),sp
        ld sp,VRAM+2048
        jr fill_go
fillr:  ld (spsv),sp
        ld sp,RAMBUF+2048
fill_go:
        ld hl,$AAAA
        ld b,64
.f:     push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        djnz .f
        ld sp,(spsv)
        ret

; ---- MUL8: HL = B * C (signed 8-bit), quarter squares: ab = f(a+b) - f(a-b)
mul_pre:
        ld a,(seed)
        add a,73
        ld (seed),a
        ld b,a
        rrca
        rrca
        xor $5A
        ld c,a
        ret

MUL8:   ld a,c
        xor $80
        ld h,a
        ld a,b
        xor $80
        ld l,a
        add a,h
        ld e,a
        ld a,SQPAGE
        adc a,0
        ld d,a                  ; DE -> f(a+b) low byte
        ld a,l
        sub h
        jr nc,.p
        neg
.p:     ld l,a
        ld h,SQPAGE+1           ; HL -> f(|a-b|) low byte
        ld a,(de)
        sub (hl)
        ld c,a
        inc d
        inc d
        inc h
        inc h
        ld a,(de)
        sbc a,(hl)
        ld h,a
        ld l,c
        ret

mul_check:                      ; sum of a*b over a grid must equal the Python value
        ld hl,0
        ld (pnull),hl
        ld b,-128
.ma:    ld c,-128
.mb:    push bc
        call MUL8
        ex de,hl
        ld hl,(pnull)
        add hl,de
        ld (pnull),hl
        pop bc
        ld a,c
        add a,11
        ld c,a
        jp po,.mb               ; until signed overflow wraps past 127
        ld a,b
        add a,7
        ld b,a
        jp po,.ma
        ld hl,(pnull)
        ld de,{MULSUM}
        or a
        sbc hl,de
        ld a,0
        jr nz,.bad
        inc a
.bad:   ld (CHK+0),a
        ret

; ---- XFORM: rotate (yaw, pitch) and project one vertex at IX
xf_pre: ld ix,VERT
        ld (ix+0),40
        ld (ix+1),-20
        ld (ix+2),90
        ret

XFORM:  ld b,(ix+0)
        ld a,(CY)
        ld c,a
        call MUL8               ; x*cy
        push hl
        ld b,(ix+2)
        ld a,(SY)
        ld c,a
        call MUL8               ; z*sy
        ex de,hl
        pop hl
        or a
        sbc hl,de
        add hl,hl
        ld a,h
        ld (xr),a
        ld b,(ix+0)
        ld a,(SY)
        ld c,a
        call MUL8               ; x*sy
        push hl
        ld b,(ix+2)
        ld a,(CY)
        ld c,a
        call MUL8               ; z*cy
        pop de
        add hl,de
        add hl,hl
        ld a,h
        ld (zr),a
        ld b,(ix+1)
        ld a,(CPV)
        ld c,a
        call MUL8               ; y*cp
        push hl
        ld a,(zr)
        ld b,a
        ld a,(SPV)
        ld c,a
        call MUL8               ; z'*sp
        ex de,hl
        pop hl
        or a
        sbc hl,de
        add hl,hl
        ld a,h
        ld (yr),a
        ld b,(ix+1)
        ld a,(SPV)
        ld c,a
        call MUL8               ; y*sp
        push hl
        ld a,(zr)
        ld b,a
        ld a,(CPV)
        ld c,a
        call MUL8               ; z'*cp
        pop de
        add hl,de
        add hl,hl
        ld a,h
        cp 8
        jr nc,.zok
        ld a,8
.zok:   ld l,a
        ld h,RECIPT/256
        ld a,(hl)
        ld (zr2),a              ; reciprocal
        ld c,a
        ld a,(xr)
        ld b,a
        call MUL8
        ld a,h
        add a,64
        ld (ix+3),a             ; screen x
        ld a,(zr2)
        ld c,a
        ld a,(yr)
        ld b,a
        call MUL8
        ld a,27
        sub h
        ld (ix+4),a             ; screen y
        ret

; ---- EDGE64: x (8.8) in HL, dx in BC, 64 rows into table at DE
edge_pre:
        ld hl,$2000
        ld bc,$0140
        ld de,XTAB
        ret

EDGE64:
{EDGE}
        ret

; ---- INSERT: paint a composite interval into a row run list
;      HL = source list, DE = destination list, IX -> n, (x,c)*n, X1
ins_pre:
        ld hl,templ
        ld de,INSSRC
        ld bc,16
        ldir
        ld hl,INSSRC
        ld de,INSDST
        ld ix,compos
        ret

INSERT: ld b,(ix+1)             ; X0
.p1:    ld a,(hl)
        cp b
        jr nc,.p1d
        ld (de),a
        inc l
        inc e
        ld a,(hl)
        ld c,a
        ld (de),a
        inc l
        inc e
        jr .p1
.p1d:   push hl
        push ix
        pop hl
        ld b,(hl)               ; n pairs
        inc hl
.em:    ld a,(hl)
        ld (de),a
        inc hl
        inc e
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        djnz .em
        ld b,(hl)               ; X1
        pop hl
.p3:    ld a,(hl)
        cp b
        jr z,.p3s
        jr nc,.p3d
.p3s:   inc l
        ld a,(hl)
        ld c,a
        inc l
        jr .p3
.p3d:   ld a,b
        inc a
        cp 128
        jr nc,.p5
        cp (hl)
        jr z,.p5
        ld (de),a
        inc e
        ld a,c
        ld (de),a
        inc e
.p5:    ld a,(hl)
        ld (de),a
        cp 128
        ret z
        inc l
        inc e
        ld a,(hl)
        ld (de),a
        inc l
        inc e
        jr .p5

ins_check:
        call ins_pre
        call INSERT
        ld hl,INSDST
        ld de,insexp
        ld b,{INSLEN}
.c:     ld a,(de)
        cp (hl)
        jr nz,.bad
        inc hl
        inc de
        djnz .c
        ld a,1
        ld (CHK+1),a
        ret
.bad:   xor a
        ld (CHK+1),a
        ret

; ---- COMPOSE: 64 row run lists -> 2048 screen bytes at (cdest)
;      every byte written exactly once; boundary bytes from BTAB
COMPOSE:
        ld a,(cstart)           ; rows (cstart) .. (cend)-1
        ld (crow),a
        ld l,a                  ; HL = LISTS + row*32 ; DE = cdest + row*32
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        ld de,(cdest)
        add hl,de
        ex de,hl
        pop hl
        ld bc,LISTS
        add hl,bc
        ld a,(crow)
.row:   and 1                   ; A = row number
        rrca
        rrca
        rrca
        rrca
        ld ixl,a                ; pattern offset $00 / $10
        push hl
        inc l
        ld c,(hl)               ; colour of first run
        inc l
        ld b,(hl)               ; next break x
        inc l
.seg:   ld a,e                  ; n = (b >> 2) - j
        and $1F
        ld ixh,a
        ld a,b
        rrca
        rrca
        and $3F
        sub ixh
        jr z,.nofill
        add a,a                 ; jump into the unrolled filler
        neg
        add a,64
        ld (.fc+1),a
        ld a,ixl
        add a,c
        ld (.pp+1),a
.pp:    ld a,(PATTAB)
.fc:    call FILLBLK
.nofill:
        ld a,b
        cp 128
        jr z,.rowend
        and 3
        jr nz,.bound
        ld c,(hl)               ; break on a byte boundary: next run
        inc l
        ld b,(hl)
        inc l
        jr .seg
.bound: ld (.bs+1),a            ; split s = b & 3
        ld a,b
        or 3
        inc a
        ld (pend),a             ; first pixel of the next byte
        ld a,c                  ; cl
        ld c,(hl)               ; advance: cr
        inc l
        ld b,(hl)
        inc l
        push hl
        rrca                    ; H = BTABP + par*4 + cl>>2 ; L = (cl&3)*64 + cr*4 + s
        rrca
        ld h,a
        and $C0
        ld l,a
        ld a,h
        and $03
        ld h,a
        ld a,ixl
        rrca
        rrca
        add a,h
        add a,BTABP
        ld h,a
        ld a,c
        add a,a
        add a,a
.bs:    add a,0
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
.more:  push af                 ; further breaks inside this byte (thin runs)
        ld a,(pend)
        cp b
        jr z,.done
        jr c,.done
        ld a,b
        and 3
        add a,MRTAB & 255
        ld (.mk+1),a
        ld c,(hl)
        inc l
        ld b,(hl)
        inc l
        push hl
.mk:    ld hl,MRTAB
        ld a,ixl
        add a,c
        ld (.p2+1),a
.p2:    ld a,(PATTAB)
        and (hl)                ; new colour on pixels k..3
        ld (pend+1),a
        ld a,(hl)
        cpl
        pop hl
        ld (.kk+1),a
        pop af
.kk:    and 0
        push hl
        ld hl,pend+1
        or (hl)
        pop hl
        jr .more
.done:  pop af
        ld (de),a
        inc e
        ld a,e                  ; boundary byte was the row's last byte?
        and $1F
        jr z,.rowend
        jp .seg
.rowend:
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr nc,.r1
        inc h
.r1:    ld a,e
        or a
        jr nz,.r2
        inc d
.r2:    ld a,(cend)
        ld b,a
        ld a,(crow)
        inc a
        ld (crow),a
        cp b
        jp nz,.row
        ret

cmp_check:                      ; checksum of the RAM-composed frame vs Python reference
        ld hl,RAMBUF
        ld de,0
        ld bc,2048
.c:     ld a,(hl)
        add a,e
        ld e,a
        jr nc,.n
        inc d
.n:     inc hl
        dec bc
        ld a,b
        or c
        jr nz,.c
        ex de,hl
        ld de,{CKS}
        or a
        sbc hl,de
        ld a,0
        jr nz,.bad
        inc a
.bad:   ld (CHK+2),a
        ret

; =====================================================================
;  text output (3x5 font, one byte per glyph row, yellow on blue)
; =====================================================================
cls:    call fillv
        ret

print_at:                       ; HL -> zero-terminated text, D = line, E = column
        push hl
        ld a,d                  ; addr = VRAM + line*6*32 + col
        add a,a
        add a,d
        add a,a                 ; line*6
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *32
        ld d,0
        add hl,de
        ld de,VRAM
        add hl,de
        ex de,hl                ; DE = screen address
        pop hl
.ch:    ld a,(hl)
        or a
        ret z
        push hl
        push de
        sub 32
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc               ; *5
        ld bc,font
        add hl,bc
        ld b,5
.gr:    ld a,(hl)
        push hl
        ld l,a
        ld h,GLYPHT/256
        ld a,l
        add a,GLYPHT & 255
        ld l,a
        ld a,(hl)
        ld (de),a
        pop hl
        inc hl
        ex de,hl
        ld a,l
        add a,32
        ld l,a
        jr nc,.nc
        inc h
.nc:    ex de,hl
        djnz .gr
        pop de
        pop hl
        inc de
        inc hl
        jr .ch

print_num:                      ; IX -> 3-byte value, D = line, E = column (6 digits)
        push de
        ld l,(ix+0)
        ld h,(ix+1)
        ld c,(ix+2)
        ld iy,pow10
        ld de,numbuf
        ld ixh,6                ; digit counter (C holds the value's top byte)
.dg:    ld b,'0'
.sub:   ld a,l                  ; C:HL -= power, count
        sub (iy+0)
        ld l,a
        ld a,h
        sbc a,(iy+1)
        ld h,a
        ld a,c
        sbc a,(iy+2)
        ld c,a
        jr c,.und
        inc b
        jr .sub
.und:   ld a,l                  ; add back
        add a,(iy+0)
        ld l,a
        ld a,h
        adc a,(iy+1)
        ld h,a
        ld a,c
        adc a,(iy+2)
        ld c,a
        ld a,b
        ld (de),a
        inc de
        inc iy
        inc iy
        inc iy
        dec ixh
        jr nz,.dg
        xor a
        ld (de),a
        ld hl,numbuf            ; blank leading zeros
        ld b,5
.lz:    ld a,(hl)
        cp '0'
        jr nz,.go
        ld (hl),' '
        inc hl
        djnz .lz
.go:    pop de
        ld hl,numbuf
        jp print_at

print_ok:                       ; A = flag, D,E = position
        ld hl,s_ok
        or a
        jr nz,.p
        ld hl,s_bad
.p:     jp print_at

print_results:
        ld hl,s_title
        ld de,$0000
        call print_at
        ld hl,s_credit
        ld de,$0100
        call print_at
        ld hl,s_fv
        ld de,$0211
        call print_at
        ld ix,R_FV
        ld de,$0217
        call print_num
        ld hl,s_fr
        ld de,$0311
        call print_at
        ld ix,R_FR
        ld de,$0317
        call print_num
        ld b,8
        ld hl,lines
.ln:    push bc
        ld e,(hl)               ; text
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)               ; line number
        inc hl
        push hl
        ex de,hl
        ld d,c
        ld e,0
        push de
        call print_at
        pop de
        pop hl
        ld a,(hl)               ; result slot low byte (0 = none)
        inc hl
        push hl
        or a
        jr z,.nr
        ld ixl,a
        ld ixh,RES/256
        ld e,9
        push de
        call print_num
        pop de
.nr:    pop hl
        ld a,(hl)               ; check flag index+1 (0 = none)
        inc hl
        push hl
        or a
        jr z,.nc
        dec a
        ld c,a
        ld b,0
        push de
        ld hl,CHK
        add hl,bc
        ld a,(hl)
        pop de
        ld e,17
        call print_ok
.nc:    pop hl
        pop bc
        djnz .ln
        ret

; =====================================================================
;  data
; =====================================================================
pow10:  DB $A0,$86,$01, $10,$27,$00, $E8,$03,$00, $64,$00,$00, $0A,$00,$00, $01,$00,$00
s_wait: DB "MEASURING...",0
s_title: DB "VZ RACER BENCH 1  T-STATES",0
s_credit: DB "VIBED BY BPM 2026",0
s_ok:   DB "CHECK OK",0
s_bad:  DB "CHECK BAD",0
t_fld:  DB "FIELD",0
t_syn:  DB "SYNC",0
t_mul:  DB "MUL8",0
t_xf:   DB "XFORM",0
t_edg:  DB "EDGE64",0
t_ins:  DB "INSERT",0
t_cr:   DB "COMP RAM",0
t_cv:   DB "COMP VRM",0
s_fr:   DB "FILL R",0
s_fv:   DB "FILL V",0
; text, line, result slot (low byte, 0 none), check index+1 (0 none)
lines:  DW t_fld
        DB 2, R_FIELD & 255, 0
        DW t_syn
        DB 3, R_SYNC & 255, 0
        DW t_mul
        DB 4, R_MUL & 255, 1
        DW t_xf
        DB 5, R_XF & 255, 0
        DW t_edg
        DB 6, R_EDGE & 255, 0
        DW t_ins
        DB 7, R_INS & 255, 2
        DW t_cr
        DB 8, R_CR & 255, 3
        DW t_cv
        DB 9, R_CV & 255, 0
templ:  DB {TEMPL}
        DS 16
compos: DB {COMP}
insexp: DB {INSEXP}
font:
{FONT}

; unrolled filler: 32 x (LD (DE),A : INC E), page aligned, entered at 64 - 2n
        ALIGN 256
FILLBLK:
        DS 0
'''
# append the unrolled filler and the page-aligned tables
TEMPLATE += '\n'.join('        ld (de),a\n        inc e' for _ in range(32)) + '\n        ret\n'
TEMPLATE += r'''
        ORG LISTS
{LISTS}
        ORG BTABP*256
{BTAB}
        ORG SQPAGE*256
{SQLO}
{SQHI}
        ORG RECIPT
{RECIP}
        ORG PATTAB
        DB {PATE}
        DB {PATO}
        ORG MRTAB
        DB {MR}
        ORG GLYPHT
        DB {GLYPH}
'''

if __name__ == '__main__':
    build()
