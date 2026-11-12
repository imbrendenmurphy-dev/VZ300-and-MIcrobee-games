from mtest import *
import sys
KEYS.update({'V':(0xFB,5),'P':(0xBF,4),'SPACE':(0xEF,4)})
def runmod(data,secs,keys=(),name='ACIDBAT2.MOD',audio=False,spc=8):
    sy=json.load(open('out/syms.json'))
    im=FatImg(spc=spc); files={'VZDOS.VZ':open('out/VZDOS.VZ','rb').read(),'SHELL.VZ':open('out/SHELL.VZ','rb').read(),name:data}
    for n,d in files.items(): im.addfile(2,n,d)
    im.finish(); names=sorted(files)
    m=boot(im); go(m,[(None,5)])
    z=m.z; st={'it':0,'rows':[],'t0':None,'fr':0,'on':[],'dr':[]}
    orig=z.step; elp=sy['e_lp']; mr=sy['mod_row']; fr=sy['frame']; na=sy['noteadd']; dd=sy['dodrum']
    def step():
        pc=z.pc
        if pc==elp: st['it']+=1
        elif pc==mr:
            if st['t0'] is None: st['t0']=z.t
            st['rows'].append((z.t,z.mem[sy['pos']],z.mem[sy['mrow']]))
        elif pc==fr: st['fr']+=1
        elif pc==na: st['on'].append((z.t,z.r[1],z.r[0]))
        elif pc==dd: st['dr'].append((z.t,z.r[7]))
        orig()
    z.step=step
    if audio: m.spk=[]
    # key schedule: list of (time_s, key)
    ks=sorted(keys); state={'i':0,'hold':0}
    def cond(s):
        if s.z.pc==sy['pm_out']: return True
        if st['t0'] is None: return False
        t=(s.z.t-st['t0'])/CPU
        if state['hold'] and t>state['hold']: s.held=None; state['hold']=0
        if state['i']<len(ks) and t>=ks[state['i']][0]:
            s.held=ks[state['i']][1]; state['hold']=t+0.25; state['i']+=1
        return t>secs
    idx=names.index(name)
    m.script=tap('DOWN',idx)+tap('RET'); 
    def until(s):
        if s.script: return False
        return cond(s)
    # run browser keys first using normal script, then free-run with manual key control
    go(m,tap('DOWN',idx)+tap('RET'),extra=10**9,maxsteps=10**9,cond=lambda s: st['t0'] is not None)
    m.script=[]; m.tick=lambda: None; m.held=None
    m.run(m.z.pc,10**9,cond)
    st['T']=z.t-st['t0']; return m,st,sy
if __name__=='__main__':
    d=open(A+'ACIDBAT2.MOD','rb').read()
    secs=float(sys.argv[1]) if len(sys.argv)>1 else 12
    m,st,sy=runmod(d,secs,audio=True)
    rows=st['rows']; print('rows',len(rows),'first',rows[:3],'last',rows[-1][1:])
    ts=np.array([r[0] for r in rows])/CPU; dt=np.diff(ts); print('row period mean %.4f min %.4f max %.4f (expect 0.1200)'%(dt.mean(),dt.min(),dt.max()))
    print('T %.2f nonloop %.2f%% frames %d notes %d drums %d'%(st['T']/CPU,100*(st['T']-st['it']*188)/st['T'],st['fr'],len(st['on']),len(st['dr'])))
    print('drum kinds',sorted(set(k for _,k in st['dr'])),'pitches',sorted(set(p for _,c,p in st['on'])))
    print([m.z.mem[sy['sdrum']+i] for i in range(15)],[m.z.mem[sy['sdrum']+31+i] for i in range(15)])
    print(m.screen())
    x,_=render(m.spk); wav('out/acid_preview.wav',x)
