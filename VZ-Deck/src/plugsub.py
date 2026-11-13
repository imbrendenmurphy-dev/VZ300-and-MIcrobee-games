import json
from mtest import *
KEYS.update({'SPACE':(0xEF,4)})
sy=json.load(open('out/playpt3.json'))
im=FatImg()
for n in ('VZDOS.VZ','SHELL.VZ','PLAYPT3.VZ','PLAYPSG.VZ'): im.addfile(2,n,open('out/'+n,'rb').read())
mus=im.mkdir(2,'MUSIC')
im.addfile(mus,'AAA.TXT',b'x'); im.addfile(mus,'BAD.PT3',b'hello this is not a module'*40); im.addfile(mus,'SONG.PT3',open('out/TEST.PT3','rb').read()); im.addfile(mus,'ZZZ.PSG',open('out/TEST.PSG','rb').read())
im.finish()
m=boot(im); m.tsync=True
go(m,[(None,5)],maxsteps=40000000)
s=m.screen().split('\n'); print(s[2:7])
go(m,tap('DOWN',0)+tap('RET'),extra=20,maxsteps=40000000); s=m.screen().split('\n'); print('in MUSIC:',s[1:7])
# play SONG.PT3 (index: .., AAA, BAD, SONG, ZZZ) -> 3 downs
go(m,tap('DOWN',3)+tap('RET'),extra=60,maxsteps=10**9); print('\n'.join(m.screen().split('\n')))
go(m,tap('SPACE'),extra=40,maxsteps=10**9); print('paused?',m.screen().split('\n')[14])
go(m,tap('SPACE'),extra=20,maxsteps=10**9); print('resumed',m.screen().split('\n')[14])
go(m,tap('RET'),extra=80,maxsteps=10**9); s=m.screen().split('\n'); print('after stop:',s[1:7])
go(m,tap('UP')+tap('RET'),extra=150,maxsteps=10**9); s=m.screen().split('\n'); print('bad file:',s[0:3])
go(m,[(None,1)],extra=150,maxsteps=10**9); s=m.screen().split('\n'); print('after bad:',s[1:7])
go(m,tap('DOWN',2)+tap('RET'),extra=100,maxsteps=10**9); s=m.screen().split('\n'); print('psg playing:',s[0],s[2],s[6],s[14])
go(m,tap('RET'),extra=80,maxsteps=10**9); s=m.screen().split('\n'); print('after psg stop:',s[1:7])
