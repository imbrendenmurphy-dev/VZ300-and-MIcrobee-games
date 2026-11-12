from harness import Sim
from collections import defaultdict
def prof_frame(s, names):
    vz,S=s.vz,s.S
    ent={S[n]:n for n in names}
    stack=[]; tot=defaultdict(int); cnt=defaultdict(int)
    vz.step()
    while vz.pc!=S['mainloop']:
        pc=vz.pc
        if pc in ent:
            ret=vz.m[vz.sp]|vz.m[vz.sp+1]<<8
            stack.append((ent[pc],vz.t,ret,vz.sp))
        vz.step()
        while stack and vz.pc==stack[-1][2] and vz.sp==stack[-1][3]+2:
            n,t0,_,_=stack.pop(); tot[n]+=vz.t-t0; cnt[n]+=1
    return tot,cnt
if __name__=='__main__':
    s=Sim(); s.frame(2)
    names=['xform','vfin','drawseg','bisect','line2d','projpm','ocode','tcode','addcol0','addcol1','addcol2','vcoords','gridx','gridz','drawobj','midio','midab','mul16m','umul8','poll']
    tot,cnt=prof_frame(s,names)
    for n in names: print('%-9s calls %4d  total %7d  avg %6d'%(n,cnt[n],tot[n],tot[n]//max(1,cnt[n])))
