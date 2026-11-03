"""Execute indexed and original linear blocker code against identical states.

The original LINEAR_BLOCKERS path is retained as an executable oracle. This
checks queries, removals during a tick, collisions in both directions, and
full creature/terrain traces, rather than comparing two Python translations.
Requires generated compatibility assets in build/ and sjasmplus on PATH.
"""
from pathlib import Path
import json
import re
import subprocess
import sys

R=Path(__file__).resolve().parents[1]
B=R/'build'
sys.path.insert(0,str(R/'tools'))
import ppmodel


def symbols(path):
    return {m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',path.read_text())}


def call(p,s,label):
    p.m.sp=0xFFF0;p.mem[0xFFF0:0xFFF2]=b'\x00\x6f'
    p.m.pc=s[label];start=p.ticks()
    assert p.run_until(0x6F00,500),label
    return p.ticks()-start


def machine(linear=False):
    s=symbols(B/('bilbies-linear.sym' if linear else 'bilbies.sym'))
    p=ppmodel.PP(disk=(B/'BILBIES.DS8').read_bytes());p.set_p50(0x0F)
    data=(B/('BILBIES-LINEAR.HI' if linear else 'BILBIES.HI')).read_bytes()
    p.mem[0x8000:0x8000+len(data)]=data
    data=(B/'levels.bin').read_bytes();p.blocks[9][0x4000:0x4000+len(data)]=data
    data=(B/'PCG.BNK').read_bytes();p.blocks[8][:len(data)]=data
    p.m.pc=s['mb_boot'];assert p.run_until(s['mb_settings'],200)
    p.keys={ppmodel.KEY['SPACE']};assert p.run_until(s['front_main'],200);p.keys=set()
    p.m.a=1;call(p,s,'level_load');call(p,s,'game_init')
    return p,s


def setup(p,s,kind):
    p.mem[s['MASK']:s['MASK']+5120]=bytes(5120)
    p.mem[s['MASK']+60*64:s['MASK']+61*64]=bytes([255])*64
    p.mem[s['v_ncrt']]=40;p.mem[s['v_released']]=40
    for i in range(40):
        x=64+i*8
        r=bytearray(16);r[:6]=bytes([1,x&255,x>>8,59,i&1,i&7])
        if kind=='multiple' and i in [4,12,28]:r[0]=6
        if kind in ['one','unsupported','bomb'] and i==0:
            r[0]=6
            if kind=='bomb':r[6]=4;r[8]=1
        if kind in ['unsupported','bomb'] and i==1:
            r[1]=62;r[2]=0;r[4]=0
        p.mem[s['CRT']+16*i:s['CRT']+16*i+16]=r
    if kind=='unsupported':p.mem[s['MASK']+60*64+8]&=0x7F


def state(p,s):
    return (bytes(p.mem[s['CRT']:s['CRT']+640]),
            bytes(p.mem[s['MASK']:s['MASK']+5120]),bytes(p.mem[0x4000:0x6800]),
            bytes(p.mem[s['v_gtick']:s['v_gtick']+2]),
            tuple(p.peek(s[k]) for k in ['v_released','v_saved','v_lost','v_nblock','v_res']))


def main():
    for linear in [False,True]:
        opts=['-DLINEAR_BLOCKERS=1'] if linear else []
        sym='bilbies-linear.sym' if linear else 'bilbies.sym'
        subprocess.run(['sjasmplus','--nologo',*opts,f'--sym=../build/{sym}','main.asm'],cwd=R/'src',check=True)
    traces=[]
    for kind in ['one','unsupported','bomb','multiple','added_between_ticks']:
        a,sa=machine();b,sb=machine(True)
        setup(a,sa,kind);setup(b,sb,kind)
        costs=[[],[]]
        for tick in range(24):
            if kind=='added_between_ticks' and tick==1:
                a.mem[sa['CRT']]=6;b.mem[sb['CRT']]=6
            costs[0].append(call(a,sa,'game_tick'));costs[1].append(call(b,sb,'game_tick'))
            assert state(a,sa)==state(b,sb),(kind,tick)
        traces.append({'case':kind,'identical_ticks':24,'indexed_max':max(costs[0]),'linear_max':max(costs[1])})
    # Explicit edge queries after invalidating a formerly indexed blocker.
    a,sa=machine();b,sb=machine(True)
    for p,s in [(a,sa),(b,sb)]:
        setup(p,s,'multiple');call(p,s,'count_blockers')
        p.mem[s['CRT']+4*16]=2
    queries=0
    for x in range(90,300,3):
        for y in range(54,65):
            for direction in [1,255]:
                results=[]
                for p,s in [(a,sa),(b,sb)]:
                    p.m.de=x;p.m.bc=(direction<<8)|y;p.m.ix=s['CRT']
                    call(p,s,'blocked');results.append(bool(p.m.f&0x40))
                assert results[0]==results[1],(x,y,direction)
                queries+=1
    report={'reference':'executed original linear Z80 path','traces':traces,
            'matching_query_results':queries,'rendering_bypassed':True}
    print(json.dumps(report,indent=2),flush=True)
    out=R/'test-output/native';out.mkdir(parents=True,exist_ok=True)
    (out/'blocker-equivalence.json').write_text(json.dumps(report,indent=2))


if __name__=='__main__':main()
