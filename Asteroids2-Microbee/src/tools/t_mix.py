from harness import *
b,E=boot()
lo=E['snd_w1']; hi=E['snd_apply']; lo3=E['snd_w3']; hi3=lo3+60
def mixfrac(fields,lab):
    b.profile(True); b.run(fields); p=b.prof(); b.profile(False)
    m=p[lo:hi].sum()+p[lo3:hi3].sum()
    print('%-9s mixer running %3.0f%% of the time'%(lab,100*m/p.sum()))
def until(t):
    for i in range(4000):
        b.run(1)
        if t in ttext(b): return
b.run(150); mixfrac(200,'title')
until('ENEMY'); b.run(20); mixfrac(150,'roster')
until('TREASURE'); b.run(20); mixfrac(150,'treasure')
until('DEMO'); b.run(20); mixfrac(150,'demo')
until('HIGH SCORES'); b.run(20); mixfrac(100,'scores')
until('ROCKS ARE'); b.run(30)
b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
f0=b.peekw(E['flips'])
b.profile(True)
for i in range(500):
    b.key('RIGHT',(i//30)%4==0); b.key('SPACE',i%6<3); b.run(1)
p=b.prof(); m=p[lo:hi].sum()+p[lo3:hi3].sum(); print('game      mixer running %3.0f%%   fps %.1f'%(100*m/p.sum(),(b.peekw(E['flips'])-f0)/10))
