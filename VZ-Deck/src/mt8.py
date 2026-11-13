from mtest import *
from mt2 import run
import sys
def parse(d):
    ppq=struct.unpack('>H',d[12:14])[0]; p=14; exp=[]; ti=0; tracks=[]
    while p<len(d):
        n=struct.unpack('>I',d[p+4:p+8])[0]; body=d[p+8:p+8+n]; p+=8+n; i=0; t=0; rs=0; k=0; last=0
        while i<len(body):
            last=i; v=0
            while True:
                b=body[i]; i+=1; v=(v<<7)|(b&127)
                if b<128: break
            t+=v; b=body[i]
            if b==0xFF:
                ty=body[i+1]; i+=2; l=0
                while True:
                    c=body[i]; i+=1; l=(l<<7)|(c&127)
                    if c<128: break
                i+=l; continue
            if b in(0xF0,0xF7): raise Exception('sysex')
            if b&0x80: rs=b; i+=1
            if rs&0xF0 in (0xC0,0xD0): i+=1
            else:
                a,vel=body[i],body[i+1]; i+=2
                if rs&0xF0==0x90 and vel: exp.append((t,ti,k,a)); k+=1
        tracks.append((body,last)); ti+=1
    exp.sort(); return ppq,exp,tracks
def chunk(b): return b'MTrk'+struct.pack('>I',len(b))+b
d=open(A+'BJROCK.MID','rb').read()
ppq,exp,tracks=parse(d)
which=sys.argv[1]; secs=float(sys.argv[2])
if which=='double':
    # every track played twice: 40K file
    f=d[:14]+b''.join(chunk(b[:last]+b'\x00'+ (b if not b[0]&0x80 else b)) for b,last in tracks)
elif which=='pad':
    # 12K of text at the head of track 1, then the song
    junk=b'\x00\xff\x01'+bytes([0x80|(12000>>7),12000&127])+b'x'*12000
    f=d[:14]+chunk(tracks[0][0])+chunk(junk+tracks[1][0])+b''.join(chunk(b) for b,_ in tracks[2:])
else: f=d
print(which,'file size',len(f))
ppq,exp,_=parse(f)
import mt2
sy=json.load(open('out/syms.json'))
m,st=run(f,which,maxsteps=10**9,stopat=secs)
on=st['on']; t0=st['t0']; n=min(len(on),len(exp)); bad=sum(1 for i in range(n) if on[i][1]!=exp[i][3])
print('stream flag',m.z.mem[sy['strm']],'tracks',m.z.mem[sy['ntrk']],'note-ons',len(on),'mismatched',bad,'hung',m.sd.hung,'sector reads',len(m.sd.reads))
for i in (5,n//2,n-1):
    et=exp[i][0]*300000/ppq/1e6; mt=(on[i][0]-t0)/CPU; print('  #%d expected %.3fs measured %.3fs err %+.0f ms'%(i,et,mt,(mt-et)*1000))
print(m.screen().split('\n')[2:4])
