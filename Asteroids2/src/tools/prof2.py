import sys
FT=70938
ev=[]
for l in open(sys.argv[1]):
    f,t,n=l.split(); ev.append((int(f)*FT+int(t),n))
copies=[t for t,n in ev if n=='copy_buf']
iv=[(b-a)/FT for a,b in zip(copies,copies[1:])]
over=[x for x in iv if x>2.5]
# busy = from copy to the next wait_fs after game_draw
busy=[]
for i,(t,n) in enumerate(ev):
    if n=='game_draw':
        c=max(x for x in copies if x<=t) if any(x<=t for x in copies) else None
        w=next((x for x,m in ev[i:] if m=='wait_fs'),None)
        if c is not None and w: busy.append(w-c)
busy.sort(); n=len(busy)
print('frames %d  slow frames %d (%.1f%%)  busy p50 %d p90 %d p98 %d max %d  (budget %d)'%(len(iv),len(over),100*len(over)/len(iv),busy[n//2],busy[n*9//10],busy[n*98//100],busy[-1],2*FT))
