import sys
v=[(int(l.split()[0]),int(l.split()[-1],16)) for l in sys.stdin if 'PC=' in l]
# find gaps: frames between successive tickpar changes
last=None; gaps={}
for f,t in v:
    if last is None: last=(f,t); continue
    if t!=last[1]:
        g=f-last[0]; gaps[g]=gaps.get(g,0)+1; last=(f,t)
print('frames-per-update histogram:',dict(sorted(gaps.items())))
