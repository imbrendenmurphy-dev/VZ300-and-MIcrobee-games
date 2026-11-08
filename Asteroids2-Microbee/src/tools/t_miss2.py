from harness import *
b,E=boot()
b.run(100); b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
inv={v:k for k,v in E.items()}
import bisect
ad=sorted(a for a in inv if a>=0x8000)
def name(pc):
    if pc<0x8000: return 'lower'
    i=bisect.bisect_right(ad,pc)-1; return inv[ad[i]]
for i in range(28):
    b.key('RIGHT', (i//25)%5==0); b.key('SPACE', i%8<3)
    if i<26: b.run(1); continue
    for t in range(0,67500,1500):
        L.bee_run_to(t)
        print(i, t*312//67500, b.peek(E['fields']), b.peek(E['vb_state']), name(b.reg('pc')))
    b.run(1)
