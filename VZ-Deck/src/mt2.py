from mtest import *
import subprocess
def run(mid,label,maxsteps=60000000,audio=None,stopat=None):
    sy=json.load(open('out/syms.json'))
    im,names=mkimg({'A.MID':mid}); m=boot(im); go(m,[(None,5)])
    z=m.z; st={'it':0,'fr':0,'grp':0,'ev':0,'t0':None,'on':[]}
    orig=z.step; elp=sy['e_lp']; fr=sy['frame']; tk=sy['tracks']; pe=sy['pe_e0']; non=sy['noteon']
    def step():
        pc=z.pc
        if pc==elp: st['it']+=1
        elif pc==fr: st['fr']+=1
        elif pc==tk:
            st['grp']+=1
            if st['t0'] is None: st['t0']=z.t
        elif pc==pe: st['ev']+=1
        elif pc==non: st['on'].append((z.t,z.r[0]))
        orig()
    z.step=step
    if audio: m.spk=[]
    cond=(lambda s:s.z.pc==sy['pm_out']) if stopat is None else (lambda s:s.z.pc==sy['pm_out'] or (st['t0'] and s.z.t-st['t0']>stopat*CPU))
    go(m,tap('DOWN',names.index('A.MID'))+tap('RET'),extra=10**9,maxsteps=maxsteps,cond=cond)
    T=z.t-st['t0']; st['T']=T
    print(label,'T=%.3fs iters=%d frames=%d groups=%d events=%d  nonloop T=%d'%(T/CPU,st['it'],st['fr'],st['grp'],st['ev'],T-st['it']*188))
    return m,st
if __name__=='__main__':
    # sparse: one 8-beat note at 120bpm = 4.000 s
    m,s1=run(midi0([(0,b'\x90\x45\x64'),(3840,b'\x80\x45\x00')]),'sparse')
    # dense: 64 sixteenth notes, 120bpm ppq 480 -> 120 ticks each, 8.000 s... use 32 = 4.000s
    ev=[]
    for i in range(32): ev+= [(0 if i==0 else 10,bytes([0x90,60+i%12,100])),(110,bytes([0x80,60+i%12,0]))]
    m,s2=run(midi0(ev),'dense')
    print('sparse expect 4.000; dense expect %.3f'%(32*120/480*0.5-10/480*0.5))
