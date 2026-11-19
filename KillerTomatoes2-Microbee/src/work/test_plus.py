"""Execute the Premium Plus code with 1MB banking, 32K PCG and BDOS file I/O.
This is a hardware-model test, not a uBee512 screenshot.
"""
from test_boot import BootBee
import test_native as native
from pathlib import Path
import re,json
from PIL import Image
ROOT=Path('work/premiumplus')
sym={k:int(v,16) for k,v in re.findall(r'^(\S+): EQU 0x([0-9A-Fa-f]+)',(ROOT/'build/game.sym').read_text(),re.M)}
native.sym=sym
class PlusBee(BootBee):
 def __init__(self):
  super().__init__();self.ram=[bytearray(32768) for _ in range(32)];self.pcg=[bytearray(2048) for _ in range(16)]
  self.bank=12;self.m.pc=256;self.ram[2][256:256+len(self.com)]=self.com
  self.pak=(ROOT/'assets/KILLTOM2.PAK').read_bytes();self.filepos=0;self.dma=128
  self.m.set_breakpoint(5);self.messages='';self.bank_writes=set();self.pcg_writes=set()
 @property
 def com(self):return (ROOT/'build/KILLTOM2.COM').read_bytes()
 def read(self,a):
  if a>=0xf000 and not self.bank&8:
   o=a&2047
   if a&2048:return self.colour[o] if self.col&64 else self.pcg[self.lv&15][o]
   return self.attr[o] if self.lv&16 else self.scr[o]
  bank=((self.bank&3)^2)|((self.bank&0xe0)>>3) if a<32768 else 0
  return self.ram[bank][a&32767]
 def write(self,a,v):
  if a>=0xf000 and not self.bank&8:
   o=a&2047
   if a&2048:
    dest=self.colour if self.col&64 else self.pcg[self.lv&15]
    if not self.col&64:self.pcg_writes.add(self.lv&15)
   else:dest=self.attr if self.lv&16 else self.scr
   dest[o]=v;return
  bank=((self.bank&3)^2)|((self.bank&0xe0)>>3) if a<32768 else 0
  self.ram[bank][a&32767]=v
  if a<32768:self.bank_writes.add(bank)
 def run(self,n=1,ticks=67500):
  for _ in range(n):
   if self.m.pc==5:
    c=self.m.c
    if c==9:
     p=self.m.de
     while self.read(p)!=36:self.messages+=chr(self.read(p));p+=1
     self.m.a=0
    elif c==15:
     segment=int(bytes(self.read(self.m.de+i) for i in [10,11]).decode())
     self.filepos=segment*16384;self.fileend=min(len(self.pak),self.filepos+16384);self.m.a=0 if self.filepos<len(self.pak) else 255
    elif c==26:self.dma=self.m.de;self.m.a=0
    elif c==2:self.messages+=chr(self.m.e)
    elif c==20:
     data=self.pak[self.filepos:min(self.filepos+128,self.fileend)];self.filepos+=128
     for i,v in enumerate(data.ljust(128,b'\x1a')):self.write(self.dma+i,v)
     self.m.a=0 if data else 1
    else:raise AssertionError(('BDOS',c))
    self.m.pc=self.read(self.m.sp)|self.read(self.m.sp+1)<<8;self.m.sp+=2
   super().run(1,ticks)
 def call(self,label,limit=500):
  self.m.sp=0xEF00;self.write(0xEF00,0xFE);self.write(0xEF01,0xEF);self.m.pc=sym[label]
  self.m.set_breakpoint(0xEFFE);start=self.elapsed
  for _ in range(limit):
   self.run()
   if self.m.pc==0xEFFE:break
  self.m.clear_breakpoint(0xEFFE)
  assert self.m.pc==0xEFFE,(label,hex(self.m.pc))
  return self.elapsed-start
 def shot(self,name):
  from premiumplus.tools.arcade_art import PAL
  im=Image.new('RGB',(320,250));start=(self.crtc[12]<<8)|self.crtc[13]
  for cell in range(1000):
   off=(start+cell)&2047;c=self.scr[off];bank=self.attr[off]&15;co=self.colour[off];g=self.pcg[bank][(c&127)*16:(c&127)*16+10]
   for y,b in enumerate(g):
    for x in range(8):im.putpixel((cell%40*8+x,cell//40*10+y),PAL[(co if b&(128>>x) else co>>4)&15])
  im.resize((960,750),Image.Resampling.NEAREST).save('outputs/'+name+'.png')
 def match_page(self):
  start=(self.crtc[12]<<8)|self.crtc[13]
  for cell in range(1000):
   off=start+cell;bank=self.attr[off]&15;glyph=(self.scr[off]&127)*16
   assert self.pcg[bank][glyph:glyph+10]==bytes(self.read(0x8000+cell*16+i) for i in range(10)),('glyph',cell,bank)
   assert self.colour[off]==self.read(0x8000+cell*16+14),('colour',cell)

if __name__=='__main__':
 b=PlusBee();b.until('hw_init',limit=40000)
 raw=(ROOT/'assets/banks.bin').read_bytes();banks=list(range(4,32))
 for i in range(len(raw)//32768):assert b.ram[banks[i]]==raw[i*32768:(i+1)*32768],('load',banks[i])
 print('PASS compressed BDOS load and all asset banks',len(raw),flush=True)
 b.call('hw_init');b.call('plus_title');b.call('video_flush');b.match_page();b.shot('plus-title-colour')
 b.call('video_flush');b.match_page();assert b.pcg_writes==set(range(16))
 print('PASS both PCG pages and all 16 PCG banks',flush=True)
 b.write(sym['mono_mode'],1);b.call('plus_title');b.call('video_flush');b.match_page();b.shot('plus-title-mono')
 b.write(sym['mono_mode'],0)
 b.write(sym['seed'],0xE1);b.write(sym['seed']+1,0xAC)
 b.write(sym['trainer'],1);b.write(sym['diff'],1)
 b.call('setup_stage');b.call('draw_frame');b.call('video_flush');b.match_page();b.shot('plus-game-colour')
 print('PASS stage rendering',flush=True)
 results=[]
 for mode in [0,1]:
  b.write(sym['mono_mode'],mode)
  for stage in range(14):
   b.write(sym['stage'],stage);b.write(sym['lives'],4)
   b.call('setup_stage')
   costs=[]
   for frame in range(120):
    b.write(sym['frame_cnt'],frame&255)
    b.call('bot_input');b.call('game_logic');b.call('sound_tick')
    costs.append(b.call('draw_frame')+b.call('video_upload'))
    b.call('video_present')
    if frame%30==0:b.match_page()
    assert b.read(sym['stage'])==stage
    for end,base in [('dirty_end',0xC000),('dirty_end1',0xD000)]:
     value=b.read(sym[end])|b.read(sym[end]+1)<<8
     assert base<=value<=base+2000,(end,hex(value))
   b.match_page();b.shot(f'plus-stage-{stage+1:02d}-'+('mono' if mode else 'colour'))
   results.append(dict(stage=stage+1,mode=mode,mean_tstates=sum(costs)//len(costs),max_tstates=max(costs)))
   print('PASS',results[-1],flush=True)
 for i in range(len(raw)//32768):assert b.ram[banks[i]]==raw[i*32768:(i+1)*32768],('asset corruption',banks[i])
 # Idle frame synchronisation must wait for distinct PAL edges.
 b.call('cls');b.call('frame_sync');b.call('frame_sync')
 times=[b.call('frame_sync') for _ in range(6)]
 assert all(66000<t<69000 for t in times),times
 b.call('plus_title');b.write(sym['mono_mode'],0);b.keys={13}
 b.call('plus_title_anim');assert b.read(sym['mono_mode'])==1
 b.call('plus_title_anim');assert b.read(sym['mono_mode'])==1
 b.keys=set();b.call('plus_title_anim');b.keys={13};b.call('plus_title_anim');assert b.read(sym['mono_mode'])==0
 Path('work/plus-regression.json').write_text(json.dumps({'stages':results,'idle_frame_tstates':times},indent=2))
 print('PASS immutable banked art, PAL timing, and debounced monochrome selector',flush=True)


