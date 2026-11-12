import json, random
from z80emu import VZ
import build
org, code, S = build.build(False)
def mk():
    vz = VZ(); vz.load(org, code); vz.sp = 0xF000; return vz
vz = mk()
random.seed(1)
def s16(v): return v-65536 if v>32767 else v
# umul8
bad=0; tt=0
for a in list(range(0,256,7))+[255,0,1,128]:
    for b in list(range(0,256,5))+[255,0,1,128]:
        vz.r[7]=a; vz.r[0]=b
        tt=vz.call(S['umul8'])
        if vz.hl!=a*b: bad+=1
print('umul8 bad',bad,'T',tt)
# umul16 / smul16 / fmul
bad=0
for i in range(300):
    a=random.randrange(65536); b=random.randrange(65536)
    vz.de=a; vz.bc=b; tt=vz.call(S['umul16'])
    if (vz.de<<16|vz.hl)!=a*b: bad+=1
print('umul16 bad',bad,'T',tt)
bad=0
for i in range(300):
    a=random.randrange(-32767,32768); b=random.randrange(-32767,32768)
    vz.de=a&0xFFFF; vz.bc=b&0xFFFF; vz.call(S['smul16'])
    r=(vz.de<<16|vz.hl); r = r-(1<<32) if r>=1<<31 else r
    if r!=a*b: bad+=1
print('smul16 bad',bad)
bad=0
for i in range(300):
    a=random.randrange(-32767,32768); b=random.randrange(-32767,32768)
    vz.de=a&0xFFFF; vz.bc=b&0xFFFF; tt=vz.call(S['fmul'])
    exp=(abs(a)*abs(b))>>15
    if (a<0)!=(b<0): exp=-exp
    if s16(vz.hl)!=exp: bad+=1
print('fmul bad',bad,'T',tt)
# udiv32
bad=0
for i in range(300):
    d=random.randrange(1,32768); q=random.randrange(65536); r=random.randrange(d)
    n=q*d+r
    vz.de=n>>16; vz.hl=n&0xFFFF; vz.bc=d; tt=vz.call(S['udiv32'])
    if vz.hl!=q or (vz.r[6]&1): bad+=1
vz.de=5; vz.hl=0; vz.bc=5; vz.call(S['udiv32']); print('udiv ovf flag',vz.r[6]&1)
print('udiv32 bad',bad,'T',tt)
# mul16m
bad=0
for i in range(500):
    d=random.randrange(-32767,32768); mag=random.randrange(256); sg=random.randrange(2)
    vz.m[0xE000]=mag; vz.m[0xE001]=sg
    vz.de=d&0xFFFF; vz.hl=0xE000; tt=vz.call(S['mul16m'])
    exp=(abs(d)*mag)>>8
    if (d<0)!=(sg==1): exp=-exp
    if s16(vz.hl)!=exp: bad+=1; 
print('mul16m bad',bad,'T',tt)
# sin/cos
import math
bad=0
for a in range(0,65536,97):
    vz.hl=a; vz.call(S['sin']); 
    if abs(s16(vz.hl)-32767*math.sin(2*math.pi*(a>>6)/1024))>1: bad+=1
    vz.hl=a; vz.call(S['cos'])
    if abs(s16(vz.hl)-32767*math.cos(2*math.pi*(a>>6)/1024))>1: bad+=1
print('sin/cos bad',bad)
# muldiv
bad=0
for i in range(500):
    d=random.randrange(1,193); e=random.randrange(0,d+1); a=random.randrange(0,193)
    vz.r[7]=a; vz.r[3]=e; vz.r[2]=d; tt=vz.call(S['muldiv'])
    if vz.r[7]!=(a*e+d//2)//d: bad+=1
print('muldiv bad',bad,'T',tt)
# clamp, addn24, add32s
bad=0
for i in range(200):
    v=random.randrange(-20000,20000); lim=random.randrange(1,15000)
    vz.hl=v&0xFFFF; vz.de=lim; vz.call(S['clamp'])
    if s16(vz.hl)!=max(-lim,min(lim,v)): bad+=1
print('clamp bad',bad)
bad=0
for i in range(200):
    v=random.randrange(1<<24); d=random.randrange(-32768,32768); n=random.randrange(1,13)
    vz.m[0xE000]=v&255; vz.m[0xE001]=(v>>8)&255; vz.m[0xE002]=v>>16
    vz.hl=0xE000; vz.de=d&0xFFFF; vz.r[0]=n; vz.call(S['addn24'])
    got=vz.m[0xE000]|vz.m[0xE001]<<8|vz.m[0xE002]<<16
    if got!=(v+d*n)&0xFFFFFF: bad+=1
print('addn24 bad',bad)
# addvel
bad=0
for i in range(200):
    v=random.randrange(-30000,30000); p=random.randrange(1<<32); n=random.randrange(1,13)
    for k in range(4): vz.m[0xE000+k]=(p>>(8*k))&255
    vz.m[S['nf']]=n; vz.hl=v&0xFFFF; vz.ix=0xE000; vz.call(S['addvel'])
    got=sum(vz.m[0xE000+k]<<(8*k) for k in range(4))
    d=v*4+v+(v>>3)
    if got!=(p+d*n)&0xFFFFFFFF: bad+=1
print('addvel bad',bad)
