import sys; sys.path.insert(0,'/home/claude/depths/tools')
import run, play1
LEGS = [
  [('D',1)] + [('R',1),('D',1)]*8 + [('R',22)],
]
def build(legs, start=110):
    sc=[(30,'N',3)]
    f=start
    marks=[]
    for leg in legs:
        s,f=play1.path(leg,start=f)
        sc+=s; f+=20; marks.append(f)
    return sc,f,marks
if __name__=='__main__':
    sc,f,marks=build(LEGS)
    run.run('route',(f+20)/50,sc,[f],extra=['-dumpmem',str(f),'/home/claude/depths/build/mem.bin'])
    print(run.state()[0])
