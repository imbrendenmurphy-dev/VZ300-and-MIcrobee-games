import run, sym, ppmodel, z80, bisect, collections, sys
S=sym.load()
labs=sorted((v,k) for k,v in S.items() if 0x0600<=v<0xC000)
addrs=[v for v,k in labs]
def lab(pc):
    i=bisect.bisect_right(addrs,pc)-1
    return labs[i][1] if i>=0 else '?'
def profile(pp, end, top=20):
    m=pp.m
    prof=collections.Counter()
    t=m.frame_tick
    n=0
    while m.pc!=end:
        pc=m.pc
        m.ticks_to_stop=1; m.run()
        nt=m.frame_tick; d=(nt-t)%100000; t=nt
        prof[lab(pc)]+=d
        n+=1
    tot=sum(prof.values()); print('total',tot,'instr',n)
    for k,v in prof.most_common(top): print('%-22s %6d %4.1f%%'%(k,v,100*v/tot))
if __name__=='__main__':
    pp=run.boot(); pp.run_frames(120)
    pp.keys={ppmodel.KEY['RIGHT']}
    for i in range(int(sys.argv[1]) if len(sys.argv)>1 else 10): pp.run_until(S['relight'],30)
    profile(pp, S['render_dirty'])
