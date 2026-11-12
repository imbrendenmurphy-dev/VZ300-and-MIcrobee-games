import sys,struct,json,time
import numpy as np
from vz import *
import os
A=os.environ.get('VZDECK_FILES',os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','testfiles'))+os.sep
CPU=3546900.0
def vlq(n):
    b=[n&127]; n>>=7
    while n: b.append((n&127)|128); n>>=7
    return bytes(reversed(b))
def midi0(events,ppq=480,tempo=500000):
    # events: (delta, bytes)
    t=b'\x00\xff\x51\x03'+tempo.to_bytes(3,'big')+b''.join(vlq(d)+e for d,e in events)+b'\x00\xff\x2f\x00'
    return b'MThd'+struct.pack('>IHHH',6,0,1,ppq)+b'MTrk'+struct.pack('>I',len(t))+t
def mkimg(extra={}):
    im=FatImg(); files={'VZDOS.VZ':open('out/VZDOS.VZ','rb').read(),'SHELL.VZ':open('out/SHELL.VZ','rb').read()}
    files.update(extra)
    for n,d in files.items(): im.addfile(2,n,d)
    im.finish(); return im,sorted(files)
flash=open(A+'VZDOS.VZ','rb').read()[24:]
def boot(im):
    m=VZ(b'',flash,im,maxlba=max(im.sec)+100); m.ramsel=0; m.z.pc=0x4004; return m
def go(m,script,extra=30,maxsteps=8000000,cond=None):
    m.script=list(script); f0=[None]
    def until(s):
        if cond and cond(s): return True
        if not s.script:
            if f0[0] is None: f0[0]=s.frames
            return s.frames>f0[0]+extra
        return False
    return m.run(m.z.pc,maxsteps,until)
tap=lambda k,n=1:[(k,2),(None,2)]*n
def render(spk,rate=44100):
    t=np.array([x[0] for x in spk],dtype=np.float64); v=np.array([x[1] for x in spk])
    lev=((v&1).astype(float)-((v>>5)&1))
    t0=t[0]; t=t-t0
    I=np.concatenate([[0],np.cumsum(lev[:-1]*np.diff(t))])
    n=int(t[-1]/CPU*rate); edges=np.arange(n+1)*CPU/rate
    return np.diff(np.interp(edges,t,I))/(CPU/rate), t0
def wav(name,x,rate=44100):
    import wave
    w=wave.open(name,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes((np.clip(x,-1,1)*12000).astype('<i2').tobytes()); w.close()
def peak(x,rate=44100,lo=40,hi=4000):
    X=np.abs(np.fft.rfft(x*np.hanning(len(x)))); f=np.fft.rfftfreq(len(x),1/rate); k=(f>lo)&(f<hi)
    i=np.argmax(X*k); 
    # parabolic interp
    a,b,c=X[i-1],X[i],X[i+1]; d=0.5*(a-c)/(a-2*b+c)
    return (i+d)*rate/len(x)
