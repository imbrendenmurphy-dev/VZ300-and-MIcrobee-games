from test_native import *
from collections import Counter
class BootBee(Bee):
 def __init__(self,mode="colour"):
  super().__init__();self.ram=[bytearray(32768) for _ in range(4)]
  self.rom=Path('work/ubee/bn60.rom').read_bytes()+bytes([255])*8192
  self.bank=0;self.m.pc=0x8000;self.track=0;self.sector=1;self.side=0;self.buf=b'';self.pos=0;self.cmd=0;self.fdc_reads=[];self.ports=Counter()
  self.disk=Path('outputs/KILLTOM2.DS80').read_bytes()
  self.m.mark_addrs(0,65536,self.m.READ_MARK|self.m.WRITE_MARK)
  self.m.set_get_int_vector_callback(lambda:0)
 def run(self,n=1,ticks=67500):
  for _ in range(n):
   self.budget=ticks;self.m.ticks_to_stop=ticks;self.m.run();self.elapsed+=ticks-self.m.ticks_to_stop
 def peek(self,a):
  return self.read(a)
 def read(self,a):
  if not(self.bank&8) and (a&0xf000)==(0x8000 if self.bank&16 else 0xf000):return super().read(0xf000+(a&4095))
  if a>=0x8000 and not(self.bank&4):return self.rom[a-0x8000] if a<0xc000 else 255
  idx=((self.bank&3)^(2 if self.bank&4 else 0)) if a<0x8000 else 0
  return self.ram[idx][a&32767]
 def write(self,a,v):
  if not(self.bank&8) and (a&0xf000)==(0x8000 if self.bank&16 else 0xf000):return super().write(0xf000+(a&4095),v)
  if a>=0x8000 and not(self.bank&4):return
  idx=((self.bank&3)^(2 if self.bank&4 else 0)) if a<0x8000 else 0
  self.ram[idx][a&32767]=v
 def input(self,p):
  p&=255;self.ports[('r',p)]+=1
  if 0x44<=p<=0x47:p-=4
  if 0x40<=p<0x44:
   if p==0x40:
    if self.cmd&0xf0==0xc0 and self.pos>=4:return 0
    return 3 if self.pos<len(self.buf) else (((4 if self.track==0 else 0)|(2 if self.ports[('r',0x44)]%2 else 0)) if self.cmd<0x80 else 0)
   if p==0x41:return self.track
   if p==0x42:return self.sector
   if p==0x43:
    if self.pos>=len(self.buf):return 0
    a=self.buf[self.pos];self.pos+=1;return a
  if p in (0x44,0x48):return 128
  if p==9:return 0
  return super().input(p)
 def output(self,p,v):
  p&=255;self.ports[('w',p)]+=1
  if 0x44<=p<=0x47:p-=4
  if p==0x41:self.track=v
  elif p==0x42:self.sector=v
  elif p==0x43:self.data=v
  elif p in (0x44,0x48):self.side=(v>>2)&1
  elif p==0x40:
   self.cmd=v
   self.buf=b'';self.pos=0
   if v&0xf0==0xd0:self.buf=b'';self.pos=0
   if (v&0xf0)==0:self.track=0
   elif (v&0xf0)==0x10:self.track=self.data
   elif v&0xe0==0x40:self.track=min(79,self.track+1)
   elif v&0xe0==0x60:self.track=max(0,self.track-1)
   elif v&0xe0==0x80:
    s=self.sector-21 if self.sector>=21 else self.sector-1
    o=(self.track*2+self.side)*5120+s*512
    length=(10-s)*512 if v&16 else 512
    self.buf=self.disk[o:o+length];self.pos=0;self.fdc_reads.append((self.track,self.side,self.sector))
   elif v&0xf0==0xc0:
    self.buf=bytes([self.track,0,1 if self.track<2 else 21,2,0,0]);self.pos=0
  else:super().output(p,v)
if __name__=='__main__':
 b=BootBee()
 for i in range(1000):
  b.run(ticks=100000)
  if i%100==0:print(i,hex(b.m.pc),hex(b.bank),'reads',len(b.fdc_reads),flush=True)
 print('reads',b.fdc_reads[:30]);print('ports',b.ports.most_common(12))
 b.shot('boot');Path('work/boot-memory.bin').write_bytes(bytes(b.read(i) for i in range(65536)))
