import json
from mtest import *
KEYS['O']=(0xBF,1)
sy=json.load(open('out/syms.json'))
ev=[]
for i in range(16): ev+=[(0 if i==0 else 10,bytes([0x90,60+i%12,100])),(230,bytes([0x80,60+i%12,0]))]
for mode in (0,3):
    im=FatImg()
    for n in ('VZDOS.VZ','SHELL.VZ'): im.addfile(2,n,open('out/'+n,'rb').read())
    im.addfile(2,'A.MID',midi0(ev)); im.addfile(2,'ACID.MOD',open(A+'ACIDBAT2.MOD','rb').read()); im.finish()
    names=sorted(['VZDOS.VZ','SHELL.VZ','A.MID','ACID.MOD'])
    m=boot(im); go(m,[(None,5)])
    go(m,tap('O',mode),extra=10,maxsteps=10**8)
    z=m.z; st={'on':[],'rows':[]}; orig=z.step
    def step():
        if z.pc==sy['noteadd']: st['on'].append(z.t)
        if z.pc==sy['mod_row']: st['rows'].append(z.t)
        orig()
    z.step=step
    go(m,tap('UP',5)+tap('DOWN',names.index('A.MID'))+tap('RET'),extra=10**9,maxsteps=10**9,cond=lambda s:s.z.pc==sy['pm_out'])
    on=np.array(st['on'])/CPU; print('mode',mode,'MIDI 16 notes, expect 0.5000 s apart: %.4f'%np.diff(on).mean())
    go(m,[(None,20)],maxsteps=10**8)
    go(m,tap('UP',5)+tap('DOWN',names.index('ACID.MOD'))+tap('RET'),extra=10**9,maxsteps=10**9,cond=lambda s:len(st['rows'])>40)
    r=np.array(st['rows'])/CPU; print('   MOD row period (0.1400): %.4f'%np.diff(r[5:]).mean())
