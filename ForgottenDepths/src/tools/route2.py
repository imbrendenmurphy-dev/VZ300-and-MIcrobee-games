import sys; sys.path.insert(0,'/home/claude/depths/tools')
import run, play1
def build(legs, start=110):
    sc=[(30,'N',3),(80,'FIRE',3)]
    f=start+60
    for leg in legs:
        s,f=play1.path(leg,start=f)
        sc+=s; f+=20
    return sc,f
def go(legs, snaps=(), extra_t=1.0, name='r2'):
    sc,f=build(legs)
    p=run.run(name,(f+50)/50+extra_t,sc,list(snaps),extra=['-dumpmem',str(f+20),'/home/claude/depths/build/mem.bin'])
    st=run.state()[0]
    return st,f,p
