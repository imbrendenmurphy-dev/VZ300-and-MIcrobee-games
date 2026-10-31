import sys
FT=70938; FS=int(192*FT/312)
ev=[]
for l in open(sys.argv[1]):
    f,t,n=l.split(); ev.append((int(f)*FT+int(t),n))
seq=[]; res={'copy':[],'logic':[],'draw':[],'copy_start':[],'idleA':[],'idleB':[],'overrun':0,'frames':0}
for i,(t,n) in enumerate(ev):
    if n=='copy_buf':
        # find following events
        try:
            h=next(x for x in ev[i:] if x[1]=='hud_update'); g=next(x for x in ev[i:] if x[1]=='game_update')
            w=[x for x in ev[i:] if x[1]=='wait_fs'][:2]; d=next(x for x in ev[i:] if x[1]=='game_draw')
            if len(w)<2: break
        except StopIteration: break
        edge=((t-FS)//FT)*FT+FS
        res['copy_start'].append(t-edge); res['copy'].append(h[0]-t)
        res['logic'].append(w[0][0]-g[0]); res['draw'].append(w[1][0]-d[0])
        # idle = time from wait entry to next edge
        e1=((w[0][0]-FS)//FT+1)*FT+FS; e2=((w[1][0]-FS)//FT+1)*FT+FS
        res['idleA'].append(e1-w[0][0]); res['idleB'].append(e2-w[1][0]); res['frames']+=1
        if e1-edge>FT or e2-e1>FT: res['overrun']+=1
def st(k): v=res[k]; return 'min %6d avg %6d max %6d'%(min(v),sum(v)//len(v),max(v))
for k in ('copy_start','copy','logic','draw','idleA','idleB'): print('%-10s %s'%(k,st(k)))
tot=sum(res['idleA'])+sum(res['idleB']); print('frames',res['frames'],'overruns',res['overrun'],'sound duty %.0f%%'%(100*tot/(res['frames']*2*FT)))
import statistics
for k in ('logic','draw'):
    v=sorted(res[k]); n=len(v)
    print(k,'p50',v[n//2],'p90',v[n*9//10],'p98',v[n*98//100],'>47K',sum(1 for x in v if x>47000) if k=='logic' else sum(1 for x in v if x>70000))
