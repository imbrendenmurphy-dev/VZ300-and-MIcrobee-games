#!/usr/bin/env python3
# Generates src/gfx.inc from art.py (+ font, title art)
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from art import *
import titleart

out = []
def emit(s): out.append(s)
def cidx(c): return 'gybr'.index(c)

def rows_to_bytes(rows, xoff=0, wbytes=None):
    """Return list of rows, each list of (mask,data) bytes; pixel x placed at x+xoff."""
    w = len(rows[0])
    if wbytes is None: wbytes = (w + xoff + 3)//4
    res = []
    for r in rows:
        mrow=[];drow=[]
        m=[0xff]*wbytes; d=[0]*wbytes
        for x,c in enumerate(r):
            if c=='.': continue
            px=x+xoff; b=px//4; sh=6-2*(px%4)
            if b>=wbytes: continue
            m[b]&=~(3<<sh)&0xff; d[b]|=cidx(c)<<sh
        res.append(list(zip(m,d)))
    return res

def db(vals):
    lines=[]
    for i in range(0,len(vals),16):
        lines.append("\tdb "+",".join("$%02X"%v for v in vals[i:i+16]))
    return "\n".join(lines)

def sprite(name, rows):
    """pre-shifted masked sprite: db h,wb ; dw s0..s3 ; data rows x wb x (mask,data)"""
    h=len(rows); w=len(rows[0]); wb=(w+3+3)//4
    emit(f"{name}:\n\tdb {h},{wb}")
    emit("\tdw "+",".join(f"{name}_s{k}" for k in range(4)))
    for k in range(4):
        rb=rows_to_bytes(rows,k,wb)
        flat=[]
        for r in rb:
            for m,d in r: flat+=[m,d]
        emit(f"{name}_s{k}:"); emit(db(flat))

def obj(name, rows):
    """byte aligned object for stamping: db wb ; 6 rows x wb x (mask,data)"""
    w=len(rows[0]); assert w%4==0, name
    wb=w//4
    rb=rows_to_bytes(rows,0,wb)
    flat=[]
    for r in rb:
        for m,d in r: flat+=[m,d]
    emit(f"{name}:\n\tdb {wb}"); emit(db(flat))

def mir(rows): return [r[::-1] for r in rows]
def flipv(rows): return rows[::-1]

def bg(name, rows):
    flat=[]
    for r in rows:
        r=(r*2)[:32][:8*4]
        bb=rows_to_bytes([r[:32]],0,8)[0]
        flat+=[d for m,d in bb]
    emit(f"{name}:"); emit(db(flat))

def opaque(name, rows):
    """opaque bitmap: db wb,h ; data"""
    w=len(rows[0]); wb=(w+3)//4
    flat=[]
    for r in rows:
        bb=rows_to_bytes([r.replace('.','g')],0,wb)[0]
        flat+=[d for m,d in bb]
    emit(f"{name}:\n\tdb {wb},{len(rows)}"); emit(db(flat))

def masked(name, rows):
    """byte aligned masked bitmap: db wb,h ; rows x wb x (mask,data)"""
    w=len(rows[0]); wb=(w+3)//4
    rb=rows_to_bytes(rows,0,wb)
    flat=[]
    for r in rb:
        for m,d in r: flat+=[m,d]
    emit(f"{name}:\n\tdb {wb},{len(rows)}"); emit(db(flat))

# ---------------- frog & co
F=FROG
sprite("spr_fup", F['up']); sprite("spr_fupj", F['upj'])
sprite("spr_fdn", flipv(F['up'])); sprite("spr_fdnj", flipv(F['upj']))
sprite("spr_frt", F['right']); sprite("spr_frtj", F['rightj'])
sprite("spr_flt", mir(F['right'])); sprite("spr_fltj", mir(F['rightj']))
sprite("spr_squash", F['squash']); sprite("spr_squash2", F['squash2'])
sprite("spr_ring1", F['ring1']); sprite("spr_ring2", F['ring2']); sprite("spr_ring3", F['ring3'])
sprite("spr_faint", F['faint']); sprite("spr_angel", F['angel'])
sprite("spr_hoppina", HOPPINA)
def asprite0(name, rows):
    w=len(rows[0]); wb=(w+3)//4; h=len(rows)
    emit(f"{name}:\n\tdb {h},{wb}")
    emit("\tdw "+",".join([f"{name}_s0"]*4))
    rb=rows_to_bytes([r+'.'*(wb*4-w) for r in rows],0,wb)
    flat=[]
    for r in rb:
        for m,d in r: flat+=[m,d]
    emit(f"{name}_s0:"); emit(db(flat))
asprite0("spr_fly", FLY); asprite0("spr_fly2", FLY2)
asprite0("spr_bcpeek", BAYCROC_PEEK); asprite0("spr_bcroc", BAYCROC)
for k,v in PICK.items(): sprite("spr_"+k, v)
def hsprite(name, rows):
    h=len(rows); w=len(rows[0]); wb=(w+3+3)//4
    emit(f"{name}:\n\tdb {h},{wb}")
    emit(f"\tdw {name}_s0,{name}_s0,{name}_s2,{name}_s2")
    for k in (0,2):
        rb=rows_to_bytes(rows,k,wb)
        flat=[]
        for r in rb:
            for m,d in r: flat+=[m,d]
        emit(f"{name}_s{k}:"); emit(db(flat))
hsprite("spr_snake", SNAKE); hsprite("spr_snake2", SNAKE2)
hsprite("spr_snakel", mir(SNAKE)); hsprite("spr_snake2l", mir(SNAKE2))
def asprite(name, rows):
    w=len(rows[0]); wb=(w+3)//4
    h=len(rows)
    emit(f"{name}:\n\tdb {h},{wb}")
    emit("\tdw "+",".join([f"{name}_s0"]*4))
    rb=rows_to_bytes([r+'.'*(wb*4-w) for r in rows],0,wb)
    flat=[]
    for r in rb:
        for m,d in r: flat+=[m,d]
    emit(f"{name}_s0:"); emit(db(flat))
ALIGNED={'spr_mini','spr_snailt','spr_LH','spr_LO','spr_LP','spr_LY','spr_L2','spr_hop','spr_hopb','spr_hopc','spr_hopg','spr_hopw','spr_sun','spr_pad','spr_dozer','spr_dozer2'}
for k,v in titleart.SPRITES.items():
    (asprite if k in ALIGNED else sprite)(k, v)

# ---------------- lane objects
for k,v in VEH.items():
    obj(f"o_{k}_r", v); obj(f"o_{k}_l", mir(v))
for n in (2,3,4,6):
    obj(f"o_log{n}_r", log(n)); obj(f"o_log{n}_l", mir(log(n)))
for k,v in TURTLE.items():
    obj(f"o_t_{k}_r", v); obj(f"o_t_{k}_l", mir(v))
for k,v in TURTLE.items():
    for n in (2,3):
        rows=[r*n for r in v]
        obj(f"o_t{n}_{k}_r", rows); obj(f"o_t{n}_{k}_l", mir(rows))
obj("o_croc_r", CROC); obj("o_croc_l", mir(CROC))
# croc heads (last 2 bytes) for jaw animation
obj("o_crhc_r", [r[24:] for r in CROC]); obj("o_crhc_l", mir([r[24:] for r in CROC]))
obj("o_crho_r", [r[24:] for r in CROC_OPEN]); obj("o_crho_l", mir([r[24:] for r in CROC_OPEN]))
obj("o_lily_r", LILY); obj("o_lily_l", mir(LILY))
obj("o_water", ["bbbbbbbb"]*6)

# ---------------- backgrounds
for k,v in BG.items(): bg("bg_"+k, v)

# ---------------- home row (32 x 6 opaque, built here)
HOME = titleart.HOME
opaque("home_bg", HOME)

# ---------------- title / big art
for k,v in titleart.MASKED.items(): (obj if k.startswith('o_') else masked)(k, v)
for k,v in titleart.OPAQUE.items(): opaque(k, v)

# ---------------- font 3x5 (ASCII 32..95)
from font import FONT
flat=[]
for ch in range(32,96):
    g=FONT.get(chr(ch), ["000"]*5)
    for r in g: flat.append(int(r.replace('.','0').replace('#','1'),2))
emit("font35:"); emit(db(flat))

open(os.path.join(os.path.dirname(__file__),'..','gfx.inc'),'w').write("\n".join(out)+"\n")
print("gfx.inc lines",len(out))
