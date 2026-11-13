#!/usr/bin/env python3
"""
build_opt.py - optimised renderer routines (Stage 2 -> 4), measured on the
cycle-exact emulator's profiler and checked against Python references.

  COMP2   row composer v2: pattern bytes pre-resolved per row parity, boundary
          byte = ((Pcur ^ Pnew) & leftmask) ^ Pnew, thin runs patched in place
  XFORM2  yaw rotation + projection with inline quarter-square multiplies
          (pitch/roll applied later as screen-space offsets): 6 multiplies
"""
import os, sys, json, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import build_bench as bb
from z80asm import Asm, vz_file

def inline_mul(tag):
    """HL = B * C signed, inline (no CALL/RET). Clobbers A, C, DE, HL."""
    return f'''        ld a,c
        xor $80
        ld h,a
        ld a,b
        xor $80
        ld l,a
        add a,h
        ld e,a
        ld a,SQPAGE
        adc a,0
        ld d,a
        ld a,l
        sub h
        jr nc,.m{tag}
        neg
.m{tag}: ld l,a
        ld h,SQPAGE+1
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
'''

def build():
    meta = json.load(open(os.path.join(HERE, 'bench_meta.json')))
    rows = meta['rows']
    # lists with row parity folded into the colour index (+16 on odd rows)
    lists = []
    for y, runs in enumerate(rows):
        b = []
        for x, c in runs: b += [x, c + (16 if y & 1 else 0)]
        b += [128]; b += [0] * (32 - len(b)); lists += b
    lo, hi = bb.sq_tables()
    src = f'''
LATCH   EQU $6800
SQPAGE  EQU $A0
RECIPT  EQU $A400
PATTAB  EQU $A500
LISTS   EQU $9000
RAMBUF  EQU $C000
VERT    EQU $CA00
VARS    EQU $CC00
cstart  EQU VARS+20
cend    EQU VARS+21
cdest   EQU VARS+2
crow    EQU VARS+4
CY      EQU VARS+48
SY      EQU VARS+49

        ORG $8000
start:  di
        ld sp,$BFF0
        ld a,118
        ld (CY),a
        ld a,48
        ld (SY),a
        ld ix,VERT
        ld (ix+0),40
        ld (ix+1),-20
        ld (ix+2),90
        ld b,8
xl:     push bc
        call XFORM2
        pop bc
        djnz xl
        ld hl,RAMBUF
        ld (cdest),hl
        xor a
        ld (cstart),a
        ld a,64
        ld (cend),a
        call COMP2
        call COMP2
        halt

; ---- XFORM2: (IX+0..2) = dx, dy, dz relative to camera ; out (IX+3)=sx, (IX+4)=sy
XFORM2: ld b,(ix+0)
        ld a,(CY)
        ld c,a
{inline_mul('a')}        push hl                 ; x*cy
        ld b,(ix+2)
        ld a,(SY)
        ld c,a
{inline_mul('b')}        ex de,hl
        pop hl
        or a
        sbc hl,de
        add hl,hl
        ld a,h
        ld (ix+5),a             ; x'
        ld b,(ix+0)
        ld a,(SY)
        ld c,a
{inline_mul('c')}        push hl                 ; x*sy
        ld b,(ix+2)
        ld a,(CY)
        ld c,a
{inline_mul('d')}        pop de
        add hl,de
        add hl,hl
        ld a,h                  ; z'
        cp 8
        jr nc,.z
        ld a,8
.z:     ld l,a
        ld h,RECIPT/256
        ld c,(hl)               ; r = k/z'
        ld (ix+6),c
        ld b,(ix+5)
{inline_mul('e')}        ld a,h
        add a,64
        ld (ix+3),a
        ld c,(ix+6)
        ld b,(ix+1)
{inline_mul('f')}        ld a,27
        sub h
        ld (ix+4),a
        ret

; ---- COMP2: rows (cstart)..(cend)-1 of LISTS -> (cdest)
COMP2:  ld a,(cstart)
        ld (crow),a
        ld l,a
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
        ld b,PATTAB/256
        ld iy,c2back
c2row:  ld a,e
        ld ixl,a                ; row start (low byte)
        push hl
        inc l
        ld c,(hl)
        inc l
        ld a,(bc)
        ld ixh,a                ; current pattern byte
c2seg:  ld a,(hl)               ; x of next run
        ld (c2x+1),a
        rrca
        rrca
        and $3F
        ld c,a                  ; target byte index
        ld a,e
        sub ixl                 ; j = bytes written so far this row
        sub c                   ; j - target = -n  (or +1: x is in the byte just written)
        cp 1
        jr z,c2thin
        add a,a
        add a,64                ; entry = 64 - 2n
        ld (c2j+1),a
        ld a,ixh
c2j:    jp FILL2                ; unrolled filler returns via JP (IY)
c2back:
c2x:    ld a,0
        cp 128
        jr z,c2end
        inc l
        and 3
        jr z,c2al
        ex af,af'               ; keep s
        ld c,(hl)
        inc l
        ld a,(bc)
        ld c,a                  ; new pattern
        xor ixh                 ; Pcur ^ Pnew
c2mix:  ex af,af'
        dec a
        jr z,c2s1
        dec a
        jr z,c2s2
        ex af,af'
        and $FC
        jr c2sx
c2s2:   ex af,af'
        and $F0
        jr c2sx
c2s1:   ex af,af'
        and $C0
c2sx:   xor c
        ld (de),a
        inc e
        ld ixh,c
        jp c2seg
c2al:   ld c,(hl)               ; run starts on a byte boundary
        inc l
        ld a,(bc)
        ld ixh,a
        jp c2seg
c2thin: dec e                   ; x lies in the byte just written: patch it
        inc l
        ld a,(c2x+1)
        and 3
        jr z,c2t0
        ex af,af'
        ld c,(hl)
        inc l
        ld a,(bc)
        ld c,a
        ld a,(de)
        xor c                   ; old ^ Pnew
        jr c2mix
c2t0:   ld c,(hl)               ; whole byte replaced
        inc l
        ld a,(bc)
        ld c,a
        xor a
        jr c2sx
c2end:  pop hl
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
        ld c,a
        ld a,(crow)
        inc a
        ld (crow),a
        cp c
        jp nz,c2row
        ret

        ALIGN 256
FILL2:
''' + '\n'.join('        ld (de),a\n        inc e' for _ in range(32)) + f'''
        jp (iy)

        ORG LISTS
{bb.db_lines(lists, 32)}
        ORG SQPAGE*256
{bb.db_lines(lo, 32)}
{bb.db_lines(hi, 32)}
        ORG RECIPT
{bb.db_lines(bb.recip(), 32)}
        ORG PATTAB
        DB {",".join(map(str, bb.PATE))}
        DB {",".join(map(str, bb.PATO))}
'''
    open(os.path.join(HERE, 'opt.asm'), 'w').write(src)
    asm = Asm()
    org, data = asm.assemble(src, HERE)
    open(os.path.join(HERE, 'OPT.VZ'), 'wb').write(vz_file('OPT', org, data))
    sym = asm.sym
    out = subprocess.run([os.path.join(HERE, '..', 'tools', 'vzemu'), os.path.join(HERE, 'OPT.VZ'), '20000000',
                          '--prof', f"{sym['XFORM2']:04X}", 'XFORM2', '--prof', f"{sym['COMP2']:04X}", 'COMP2',
                          '--memdump', os.path.join(HERE, 'mem_opt.bin')],
                         capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout
    print(out)
    mem = open(os.path.join(HERE, 'mem_opt.bin'), 'rb').read()
    ok = list(mem[0xC000:0xC800]) == meta['img']
    print('COMP2 output matches reference frame:', ok)
    # XFORM2 result vs Python model of the same fixed-point maths
    x, y, z, cy, sy = 40, -20, 90, 118, 48
    xr = ((x * cy - z * sy) * 2 >> 8); xr = xr - 256 if xr > 127 else xr
    zr = ((x * sy + z * cy) * 2 >> 8) & 0xFF
    zr = max(8, zr if zr < 128 else 8)
    r = bb.recip()[zr]
    sx = (64 + ((xr * r) >> 8)) & 0xFF; syv = (27 - ((y * r) >> 8)) & 0xFF
    print(f'XFORM2 out sx={mem[0xCA03]} sy={mem[0xCA04]}  python sx={sx} sy={syv}')
    return out

if __name__ == '__main__':
    build()
