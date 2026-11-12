from mtest import *
from mt2 import run
sy=json.load(open('out/syms.json'))
def chunk(b): return b'MTrk'+struct.pack('>I',len(b))+b
junk=b'\x00\xff\x01'+bytes([0x81,0xC3,0x50])+b'y'*25040      # 25040-byte text event
t0=b'\x00\xff\x51\x03\x07\xa1\x20\x00\xff\x03\x05Hello\x00\xff\x2f\x00'
t1=junk+b'\x00\x90\x45\x64\x83\x60\x80\x45\x00\x00\x90\x48\x64\x83\x60\x80\x48\x00\x00\xff\x2f\x00'
t2=b'\x83\x60\x90\x30\x64\x83\x60\x80\x30\x00'    # no end-of-track marker at all: must stop at the chunk end
f=b'MThd'+struct.pack('>IHHH',6,1,3,480)+chunk(t0)+chunk(t1)+chunk(t2)+b'TRAILING JUNK'*40
print('size',len(f))
m,st=run(f,'eof',maxsteps=10**9,stopat=8)
print('ended at pm_out:',m.z.pc==sy['pm_out'],'notes',[(round((t-st['t0'])/CPU,2),n) for t,n in st['on']],'strm',m.z.mem[sy['strm']],'hung',m.sd.hung)
print(m.screen().split('\n')[2:4])
