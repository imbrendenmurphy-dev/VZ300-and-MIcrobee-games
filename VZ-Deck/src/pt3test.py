import sys,json
from mtest import *
import pt3ref
sy=json.load(open('out/playpt3.json'))
def runplug(files,target,secs,keys=()):
    import os; im=FatImg(spc=int(os.environ.get('SPC','8'))); allf={'VZDOS.VZ':open('out/VZDOS.VZ','rb').read(),'SHELL.VZ':open('out/SHELL.VZ','rb').read()}; allf.update(files)
    for n,d in allf.items(): im.addfile(2,n,d)
    im.finish(); names=sorted(allf)
    m=boot(im); m.tsync=True
    go(m,[(None,5)],maxsteps=40000000)
    z=m.z; st={'ticks':[],'t0':None}; orig=z.step
    def step():
        if z.pc==sy['vapply'] and z.pc>=0xA000 and z.mem[0xA000]==0xF3:
            if st['t0'] is None: st['t0']=z.t
            v=[(z.mem[sy['vper']+2*k]|z.mem[sy['vper']+2*k+1]<<8, z.mem[sy['vamp']+2*k], z.mem[sy['vton']+2*k]) for k in range(3)]
            st['ticks'].append((z.t,v,z.mem[sy['dreq']]))
        orig()
    z.step=step
    idx=names.index(target)
    def cond(s):
        if st['t0'] is None: return False
        return (s.z.t-st['t0'])/CPU>secs
    go(m,tap('DOWN',idx)+tap('RET')+[(None,1)]*2+[(k,1) for k in keys],extra=10**9,maxsteps=10**9,cond=cond)
    return m,st
if __name__=='__main__':
    d=open('out/TEST.PT3','rb').read()
    ref=pt3ref.PT3(d); R=[]
    while True:
        r=ref.tick()
        if r is None: break
        R.append([(x['per'],x['amp'],x['ton']) for x in r])
    m,st=runplug({'TEST.PT3':d,'PLAYPT3.VZ':open('out/PLAYPT3.VZ','rb').read()},'TEST.PT3',len(R)/50.0+1.5)
    T=st['ticks']; print('ref ticks',len(R),'z80 ticks',len(T))
    bad=0
    for i,(t,v,dr) in enumerate(T[:len(R)]):
        exp=[(p if a else p, a, tn) for p,a,tn in R[i]]
        got=[(p if a else p,a,tn) for p,a,tn in v]
        # compare period only where the channel sounds
        e2=[(p if a and tn else None,a,tn if a else None) for p,a,tn in R[i]]; g2=[(p if a and tn else None,a,tn if a else None) for p,a,tn in v]
        if e2!=g2:
            bad+=1
            if bad<6: print('tick',i,'exp',R[i],'got',v)
    print('mismatched ticks',bad)
    ts=np.array([t for t,_,_ in T])/CPU; print('tick period %.4f'%np.diff(ts).mean())
    print('drum requests',sum(1 for _,_,d in T if d))
    print(m.screen())
