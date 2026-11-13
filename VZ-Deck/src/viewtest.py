import sys,json
from mtest import *
KEYS['V']=(0xFB,5)
fmt,fn,src=sys.argv[1],sys.argv[2],sys.argv[3]
sy=json.load(open('out/play%s.json'%fmt))
im=FatImg()
for n in ('VZDOS.VZ','SHELL.VZ','PLAY%s.VZ'%fmt.upper()): im.addfile(2,n,open('out/'+n,'rb').read())
im.addfile(2,fn,open(src,'rb').read()); im.finish()
names=sorted(['VZDOS.VZ','SHELL.VZ','PLAY%s.VZ'%fmt.upper(),fn])
m=boot(im); m.tsync=True; go(m,[(None,5)],maxsteps=40000000)
go(m,tap('DOWN',names.index(fn))+tap('RET'),extra=150,maxsteps=10**9)
for v in range(4):
    print('\n'.join(m.screen().split('\n')[0:16])); print('-'*32)
    go(m,tap('V'),extra=120,maxsteps=10**9)
