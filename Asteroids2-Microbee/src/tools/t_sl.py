from harness import *
b,E=boot()
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
f0=b.peekw(E['flips']); b.profile(True)
for i in range(300):
    b.key('RIGHT',(i//30)%4==0); b.key('SPACE',i%6<3); b.run(1)
p=b.prof(); nf=b.peekw(E['flips'])-f0
# calls: count executions of first instruction ~ prof/T
print('frames',nf)
print('vb_poll_sim calls/frame %.0f'%(p[E['vb_poll_sim']]/17/nf))
print('snd_slice entries/frame %.0f'%(p[E['snd_slice']]/13/nf))
w3=p[E['snd_w3']:E['snd_w3']+70].sum(); print('slice T/frame %.0f'%(w3/nf), 'total T/frame %.0f'%(p.sum()/nf))
