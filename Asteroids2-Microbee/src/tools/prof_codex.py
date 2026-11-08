exec(open('boot_codex.py').read().split("b.run(100)")[0])
S=sym('/mnt/user-data/uploads/outputs/Asteroids2-Microbee/build/render.sym')
b.run(50); b.key('SPACE'); b.run(3); b.keys_up(); b.run(50)
fc=lambda: b.peekw(S['frame_counter'])
import collections
b.profile(True)
f0=fc(); t0=b.frames; ims=[]
for i in range(250):
    b.key('RIGHT', i%40<10); b.key('UP', i%30<8); b.key('SPACE', i%6<2)
    b.run(1)
    if 150<=i<200: ims.append(b.image(scale=1))
f1=fc(); print('render frames per 250 fields:', f1-f0, '=> fps', (f1-f0)/250*50)
p=b.prof(); tot=p.sum()
inv={v:k for k,v in S.items() if 0x8000<=v<0xF000}
addrs=sorted(inv)
import bisect
agg=collections.Counter()
for a in range(0x8000,0x10000):
    if p[a]:
        i=bisect.bisect_right(addrs,a)-1
        agg[inv[addrs[i]] if i>=0 else '?']+=p[a]
low=p[:0x8000].sum(); print('lower bank (sim) %.1f%%'%(100*low/tot))
for k,v in agg.most_common(25): print('%-28s %5.1f%%'%(k,100*v/tot))
ims[0].save('../out/codex_play.gif',save_all=True,append_images=ims[1:],duration=20,loop=0)
b.image().save('../out/codex_play.png')
