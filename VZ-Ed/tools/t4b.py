import sys, random; sys.path.insert(0,'.')
from harness import *
dos=open('VZDOS.VZ','rb').read(); ed=open('../out/VZED.VZ','rb').read()
random.seed(1)
def para(n):
    words='vz retro micro bee joystick cassette basic z80 sound colour screen keyboard disk card'.split()
    out=[]
    while sum(len(x)+2 for x in out)<n:
        out.append(' '.join(random.choice(words) for _ in range(random.randint(3,12))).capitalize()+'.')
    return '\r\n'.join(out).encode()[:n]
def run(name, card_kw, setup, script, expect=None, frames=150):
    kw=dict(card_kw); kw.pop('nf',None); c=Card(**kw)
    c.addfile(2,'VZDOS.VZ',dos); c.addfile(2,'SHELL.VZ',ed)
    big=setup(c); c.finish(nextfree=card_kw.get('nf'))
    m=VZ(dos[24:],c,maxlba=max(c.sec)+70000)
    m.run(0x4004,frames=frames)
    p0,_=FS(c.sec).check(); assert not p0, p0
    m.type_keys(script); m.run_script(extra=200,maxframes=9000)
    p,f=FS(c.sec).check(); fs=FS(c.sec); F=fs.fat()
    print('==',name,'| FS:',p or 'clean','| status:',m.text().split('\n')[0].strip(), '| stop', m.stop)
    if expect:
        for path,data in expect.items():
            got=fs.readfile(*f[path],F) if path in f else None
            print('   ',path,'OK' if got==data else 'MISMATCH %r'%(got[:60] if got else got))
    return m,c,f
# 4. card full: save must fail cleanly
def s4(c): c.addfile(2,'A.TXT',b'a'); c.fill_used(2,c.totclus-len(c.fat)+2-6-1)
run('card nearly full', dict(spc=1,fatsz=64,totclus=600), s4,
    text_for('a'*700)+[('CTRL','A')]+text_for('wontfit')+['RET'])
# 5. FSInfo hint points into used space / past the end
def s5(c): c.addfile(2,'HINT.TXT',b'hint')
run('stale free-space hint', dict(spc=8,fatsz=64,nf=5), s5,
    [('CTRL','O'),('WAIT',30),'RET',('WAIT',30),'Q',('CTRL','S')], {'/HINT.TXT':b'qhint'})
run('hint past the end', dict(spc=8,fatsz=64,nf=99999999), s5,
    [('CTRL','O'),('WAIT',30),'RET',('WAIT',30),'R',('CTRL','S')], {'/HINT.TXT':b'rhint'})
# 6. file too big
def s6(c): c.addfile(2,'HUGE.TXT',b'h'*20000)
run('file too big', dict(spc=8), s6, [('CTRL','O'),('WAIT',30),'RET'])
