from pathlib import Path
import sys,re
sys.path.insert(0,str(Path(__file__).parent/'pylibs'))
import z80
from PIL import Image
sym={k:int(v,16) for k,v in re.findall(r'^(\S+): EQU 0x([0-9A-Fa-f]+)',Path('work/port/build/game.sym').read_text(),re.M)}
class Bee:
 def __init__(self):
  self.m=z80.Z80Machine(); self.m.memory[:]=bytes(65536)
  data=Path('work/port/build/HAMSAM2.COM').read_bytes();self.m.memory[256:256+len(data)]=data;self.m.pc=sym['game_entry']
  self.lowerbanks=[bytearray(32768) for _ in range(32)]; self.bank=4;pack=Path('work/port/build/HAMSAM2.DAT').read_bytes();
  for i in range(len(pack)//32768):self.lowerbanks[4+i][:]=pack[i*32768:(i+1)*32768]
  self.lv=0;self.col=0;self.reg=0;self.crtc=bytearray(32);self.lp=None;self.addr=0;self.keys=set();self.time=0
  self.latch=0;self.wide=False;self.ready_delay=0;self.lp_ready_delay=0;self.pending_lp=None;self.elapsed=0
  self.scr=bytearray(2048);self.attr=bytearray(2048);self.colour=bytearray(2048);self.pcg=[bytearray(2048) for _ in range(16)]
  self.m.set_read_callback(self.read);self.m.set_write_callback(self.write);self.m.mark_addrs(0xf000,4096,self.m.READ_MARK|self.m.WRITE_MARK)
  self.m.set_input_callback(self.input);self.m.set_output_callback(self.output)
 def peek(self,a):return self.m.memory[a]
 def read(self,a):
  if self.bank&8:return self.m.memory[a]
  o=a&2047
  if a&2048:return self.colour[o] if self.col&64 else self.pcg[self.lv&15][o]
  return self.attr[o] if self.lv&16 else self.scr[o]
 def write(self,a,v):
  if self.bank&8:self.m.memory[a]=v;return
  o=a&2047
  if a&2048:dest=self.colour if self.col&64 else self.pcg[self.lv&15]
  else:dest=self.attr if self.lv&16 else self.scr
  dest[o]=v
 def input(self,p):
  if p&255==9:self.wide=bool(p&256);return 0
  p&=255
  if p==12:
   if self.lp_ready_delay:
    self.lp_ready_delay-=1
    if not self.lp_ready_delay and self.lp is None:self.lp=self.pending_lp
   if self.ready_delay:
    self.ready_delay-=1
    if not self.ready_delay and self.crtc[8]&0x48==0x48 and ((self.addr>>4)&63) in self.keys:
     self.pending_lp=self.addr;self.lp_ready_delay=1
   if not self.latch and self.lp is None and self.keys:self.lp=min(self.keys)<<4
   t=self.elapsed+self.budget-self.m.ticks_to_stop
   return (0 if self.ready_delay else 128)|(64 if self.lp is not None else 0)|(32 if t%67500>54000 else 0)
  if p==13:
   if self.reg in (16,17):
    a=self.lp if self.lp is not None else getattr(self,'lastlp',0);self.lastlp=a;self.lp=None
    return (a>>8)&63 if self.reg==16 else a&255
   return self.crtc[self.reg]
  return 255
 def output(self,p,v):
  p&=255
  if p==80:
   old=(((self.bank&224)>>3)|(self.bank&3))^2; new=(((v&224)>>3)|(v&3))^2
   if old!=new:
    self.lowerbanks[old][:]=self.m.memory[:32768]
    self.m.memory[:32768]=self.lowerbanks[new]
   self.bank=v
  elif p==28:self.lv=v
  elif p==8:self.col=v
  elif p==11:self.latch=v&1
  elif p==12:self.reg=v&31
  elif p==13:
   self.crtc[self.reg]=v
   if self.reg==18:self.addr=(self.addr&255)|(v<<8)
   elif self.reg==19:self.addr=(self.addr&0xff00)|v
   elif self.reg==31:self.ready_delay=3;self.lp_ready_delay=0;self.pending_lp=None
 def run(self,n=1,ticks=67500):
  for _ in range(n):
   self.budget=ticks;self.m.ticks_to_stop=ticks;self.m.run();self.elapsed+=ticks-self.m.ticks_to_stop
 def until(self,label,limit=4000):
  address=sym[label];self.m.set_breakpoint(address)
  for _ in range(limit):
   self.run()
   if self.m.pc==address:break
  self.m.clear_breakpoint(address)
  assert self.m.pc==address,(label,hex(self.m.pc))
 def call(self,label,limit=500):
  self.m.sp=0xEF00;self.m.memory[0xEF00:0xEF02]=bytes([0xFE,0xEF]);self.m.pc=sym[label]
  self.m.set_breakpoint(0xEFFE)
  start=self.elapsed
  for _ in range(limit):
   self.run()
   if self.m.pc==0xEFFE:break
  self.m.clear_breakpoint(0xEFFE)
  assert self.m.pc==0xEFFE,(label,hex(self.m.pc))
  return self.elapsed-start
 def shot(self,name):
  im=Image.new('RGB',(320,250));pal=[(0,0,0),(170,0,0),(0,170,0),(170,170,0),(0,0,170),(170,0,170),(0,170,170),(170,170,170),(85,85,85),(255,85,85),(85,255,85),(255,255,85),(85,85,255),(255,85,255),(85,255,255),(255,255,255)]
  for cell in range(1000):
   address=(cell+((self.crtc[12]<<8)|self.crtc[13]))&2047;c=self.scr[address];bank=self.attr[address]&15;co=self.colour[address];g=self.pcg[bank][(c&127)*16:(c&127)*16+10]
   for y,b in enumerate(g):
    for x in range(8):im.putpixel(((cell%40)*8+x,(cell//40)*10+y),pal[(co if b&(128>>x) else co>>4)&15])
  im.resize((960,750),Image.Resampling.NEAREST).save('outputs/'+name+'.png')

if __name__=='__main__':
 b=Bee();b.until('title_screen.l');b.shot('01-title-progress')
 b.m.memory[sym['kitchen']]=0;b.m.memory[sym['mode']]=1;b.m.memory[sym['lives']]=4;b.m.memory[sym['peppers']]=6
 b.m.a=0;b.call('load_kitchen');b.call('draw_kitchen');b.call('setup_round');b.call('wipe_show')
 for i in range(100):b.call('game_frame')
 b.shot('02-game-progress')
 print('Sam',b.peek(sym['sx']),b.peek(sym['sy']),'time',b.elapsed)

