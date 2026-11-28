"""Execute native terrain bridge Z80 code against an independent pixel oracle."""
from pathlib import Path
import random
import re
import subprocess
import sys

R=Path(__file__).resolve().parents[1]
B=R/'build/native-simulation'
sys.path.insert(0,str(R/'tools'))
import ppmodel


def main():
    B.mkdir(parents=True,exist_ok=True)
    subprocess.run(['sjasmplus','--nologo','--sym=../build/native-simulation/terrain-test.sym',
                    'slice_terrain_test.asm'],cwd=R/'native',check=True)
    symbols={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',
                                                    (B/'terrain-test.sym').read_text())}
    p=ppmodel.PP();p.set_p50(0x0F)
    code=(B/'TERRTEST.BIN').read_bytes();p.mem[0x600:0x600+len(code)]=code
    def call(label):
        p.m.sp=0xDFF0;p.mem[0xDFF0:0xDFF2]=b'\x00\x70';p.m.pc=symbols[label]
        start=p.ticks();assert p.run_until(0x7000,500),label
        return p.ticks()-start
    rng=random.Random(19482)
    mask=bytes(rng.getrandbits(8) for _ in range(5120));p.mem[0x4000:0x5400]=mask
    call('st_init')
    dirty={(0,0),(0,1),(1,2),(3,40),(4,41),(7,76),(9,126),(9,127)}
    for row,col in sorted(dirty):
        x=col*4+rng.randrange(4);y=row*8+rng.randrange(8)
        p.m.de=x;p.m.bc=0x5A00|y;p.m.hl=0x1234;p.m.a=0xA5;p.m.f=0x45
        call('st_mark')
        assert (p.m.de,p.m.bc,p.m.hl,p.m.a,p.m.f)==(x,0x5A00|y,0x1234,0xA5,0x45)
    checks=0;costs=[]
    for camera in (*range(16),127,383,384):
        for mono in (0,1):
            p.m.hl=camera;p.m.de=0xE600;p.m.a=mono
            costs.append(call('st_jobs'));assert not (p.m.f&1)
            n=p.m.a;data=bytes(p.mem[0xE600:0xE600+n*19]);actual={}
            for i in range(n):
                job=data[i*19:(i+1)*19];cell=int.from_bytes(job[:2],'little')
                assert cell not in actual
                actual[cell]=job[2:]
            cells=set()
            for row,col in dirty:
                left=col*8-camera
                for dx in range(8):
                    sx=left+dx
                    if 0<=sx<640:cells.add((row+4)*80+sx//8)
            expected={}
            for cell in cells:
                row,col=divmod(cell,80);rows=[]
                for yy in range(16):
                    y=(row*16+yy-64)//2;bits=0
                    for xx in range(8):
                        x=(camera+col*8+xx)//2
                        bit=bool(mask[y*64+x//8]&(0x80>>(x&7)))
                        bits=(bits<<1)|bit
                    rows.append(bits)
                expected[cell]=bytes(rows)+bytes([15 if mono else 0x63])
            assert actual==expected,(camera,mono,actual.keys(),expected.keys())
            checks+=1
    # Repeated frames reuse jobs. Further edits within an already-dirty cell
    # must invalidate the cache, even though its dirty bit was already set.
    previous=bytes(p.mem[0xE600:0xE600+n*19])
    p.m.hl=384;p.m.de=0xE600;p.m.a=1
    cached_cost=call('st_jobs')
    assert cached_cost<1500 and bytes(p.mem[0xE600:0xE600+n*19])==previous
    p.mem[0x4000+72*64+63]^=0x08
    p.m.de=508;p.m.bc=72;call('st_mark')
    p.m.hl=384;p.m.de=0xE600;p.m.a=1;call('st_jobs')
    assert bytes(p.mem[0xE600:0xE600+n*19])!=previous
    # Overflow must be explicit, and must not write beyond the 32-job buffer.
    call('st_init')
    for col in range(33):
        p.m.de=col*4;p.m.bc=0;call('st_mark')
    p.mem[0xE600+608:0xE600+616]=bytes([0xA5])*8
    p.m.hl=0;p.m.de=0xE600;p.m.a=0;call('st_jobs')
    assert (p.m.f&1) and p.m.a==32
    assert bytes(p.mem[0xE600+608:0xE600+616])==bytes([0xA5])*8
    print(f'PASS {checks} camera/mode cases, register preservation, cached/invalidation, persistent/deduplicated jobs, overflow; max {max(costs)} T-states; cached {cached_cost}')


if __name__=='__main__':main()
