"""Checks every spr_draw call against a Python model of what it should
compose (pool glyphs, bucket entries, colours).  python tools/sprchk.py LEVEL CALLS"""
import sys; from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import starhive_run as sh
lv=int(sys.argv[1]); ncalls=int(sys.argv[2])
pp=sh.boot(); S=pp.S
pp.run_frames(250); pp.keys={'SPACE'}; pp.run_frames(6)
if lv>1:
    pp.poke(S['level'],lv-1); pp.poke(S['state'],3); pp.poke(S['stimer'],1); pp.run_frames(560)
for t in range(20):
    pp.keys={'SPACE',['LEFT','RIGHT'][(t//10)%2]}; pp.poke(S['inv'],100); pp.run_frames(10)
P=pp.peek; W=pp.peekw
BK=S['bk_s']; CL=11
def sx(v): return v-256 if v>127 else v
bad=0; cells=0; pairs=0; calls=0
while calls<ncalls:
    pp.keys={'SPACE',['LEFT','RIGHT'][(calls//200)%2]}; pp.poke(S['inv'],100)
    pp.run_until(S['spr_draw'],5)
    c=pp.cpu
    x16=c.d<<8|c.e; t=c.c; fr=c.h<<8|c.l
    ret=W(c.sp)
    ptr0=[W(BK+2*i) for i in range(22)]
    ns0=P(S['spr_draw.ns']+1)
    scrS=W(S['scrS']); k=P(S['k']); pg=P(S['pgbank']); mono=P(S['mono'])
    # run to return
    pp.run_until(ret,5)
    calls+=1
    wb,h,flag=P(fr),P(fr+1),P(fr+2); bsz=W(fr+4)
    sh_=x16&7; blk=(sh_//2 if flag&1 else sh_)
    b0=fr+6+blk*bsz
    data=b0+3*wb; strips=data+wb*2*h
    col0=(x16>>3)-2
    exp={}
    for cc in range(wb):
        first,end,colr=P(b0+3*cc),P(b0+3*cc+1),P(b0+3*cc+2)
        if end==0: continue
        cx=col0+cc
        if not 0<=cx<40: continue
        for line in range(first,end):
            tt=t+line
            if tt>255: break
            r=P(0xBC00+tt)
            if r<2 or r>23: continue
            exp.setdefault((r,cx),(cc,first,end,colr))
    # collect entries
    got={}
    for i in range(22):
        p=ptr0[i]; p1=W(BK+2*i)
        while p<p1:
            e=[P(p+j) for j in range(6)]
            ring=(e[0]|(e[1]<<8))&0x7ff
            got[(i+2,ring)]=e; p+=6
    for (r,cx),(cc,first,end,colr) in exp.items():
        ring=(scrS+40*r+cx)&0x7ff
        e=got.pop((r,ring),None)
        if e is None: bad+=1; print('missing',r,cx); continue
        cells+=1
        code=e[2]; slot=code&0x7f
        g=[int(pp.pcg[pg*2048+slot*16+y]) for y in range(CL)]
        s0=sx((11*r-6-t)&255)
        sha=P(0x7800|ring)
        if sha==11:
            want=[P(strips+cc*(h+22)+11+s0+y) for y in range(CL)]; paper=0
        else:
            pairs+=1
            ps=P(0x7000|ring)&0x7f
            cl=P(0xB000+256*k+ps)
            fl=P(0xBB00+ps+(128 if k>=8 else 0))>>(k%8)&1
            bg=[int(pp.pcg[k*2048+ps*16+y]) for y in range(CL)]
            if not fl:
                if cl&15==0: bg=[0]*CL
                paper=cl&0xF0
            else:
                if cl&0xF0==0: bg=[0]*CL
                else: bg=[v^255 for v in bg]
                paper=(cl&15)<<4
            want=list(bg)
            for y in range(CL):
                l=s0+y
                if first<=l<end:
                    m=P(data+cc*2*h+2*l); gg=P(data+cc*2*h+2*l+1)
                    want[y]=(bg[y]&m)|gg
        col=colr|paper
        if mono: col=(0x0F if col&15 else 0)|(0x80 if col&0xF0 else 0)
        if g!=want or e[3]!=pg or e[4]!=col:
            bad+=1
            if bad<6: print('bad r%d c%d sha%d'%(r,cx,sha),g,want,e,hex(col))
    if got:
        bad+=len(got); print('extra',list(got)[:4])
print('calls',calls,'cells',cells,'over scenery',pairs,'bad',bad)
