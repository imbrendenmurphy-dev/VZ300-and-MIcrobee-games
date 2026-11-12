from harness import Sim
def profile(s):
    vz,S=s.vz,s.S
    names=['readkeys','physics','setcam','buildmat','drawbg','poll','drawgrid','drawobjs','drawmsg','flip','drawpanel']
    base=S['mainloop']; out=[]
    for i,n in enumerate(names):
        t0=vz.t
        vz.run_until(base+3*(i+1) if i<len(names)-1 else base+3*(i+1), 30_000_000)
        out.append((n,vz.t-t0))
    vz.run_until(base)
    return out
if __name__=='__main__':
    s=Sim(); s.frame(2)
    for n,t in profile(s): print('%-10s %7d'%(n,t))
