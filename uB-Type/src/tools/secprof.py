import sys, bisect, run
def section_profile(prefixes, frames=100, warm=80):
    pp=run.boot(); S=pp.S
    pp.run_until(S['mainloop'],400); pp.run_frames(warm)
    pp.profile(True); pp.watch(S['flip']); pp.watch(S['cell']); pp.watch(S['drawspr']); pp.events()
    f0=pp.frames
    while pp.frames-f0<frames:
        f=pp.frames-f0; pp.keys={'SPACE'} if (f//6)%2 else set(); pp.run_frames(1)
    ev=pp.events(); nfl=sum(1 for t,p in ev if p==S['flip'])
    print('per frame: drawspr %.1f cells %.1f'%(sum(1 for t,p in ev if p==S['drawspr'])/nfl, sum(1 for t,p in ev if p==S['cell'])/nfl))
    prof=pp.prof()
    labs=sorted((v,k) for k,v in S.items() if 0x8000<=v<0xEF00)
    addrs=[v for v,k in labs]
    acc={}
    for pc in prof.nonzero()[0]:
        i=bisect.bisect_right(addrs,pc)-1
        k=labs[i][1]
        if any(k.startswith(p) for p in prefixes):
            acc[k]=acc.get(k,0)+int(prof[pc])
    for k,v in sorted(acc.items(),key=lambda x:-x[1])[:30]: print('%-22s %7.0f/frame'%(k,v/nfl))
if __name__=='__main__':
    section_profile(sys.argv[1:])
