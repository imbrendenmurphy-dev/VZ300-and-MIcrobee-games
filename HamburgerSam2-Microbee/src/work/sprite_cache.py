from pathlib import Path
from PIL import Image,ImageDraw
ns={};exec(Path('work/art_v1.py').read_text().split('names=[]')[0],ns)
SCENES=11                       # 9 kitchens, title, Order Up! (32K each)
pack=bytearray(Path('work/port/build/HAMSAM2.DAT').read_bytes()[:SCENES*32768]);table=[]
assert len(pack)==SCENES*32768,'run spectacle.py first'
for mono in [False,True]:
 cache=bytearray()
 for n in range(46):
  if n<13:im=ns['chef'](n);bands=[15,9,15]
  elif n<37:
   kind,fr=divmod(n-13,6);im=ns['enemy'](kind,fr);bands=[[11,9,15],[15,11,15],[10,10,10],[10,9,9]][kind]
  else:
   im=Image.new('1',(24,28));d=ImageDraw.Draw(im);bands=[14]*3
   if n in [37,38]:
    for x,y in [(3,5),(14,3),(8,12),(21,15),(5,23),(17,25)]:d.ellipse((x,y,x+2,y+2),fill=1)
   elif n==39:
    d.rounded_rectangle((3,9,17,23),radius=3,fill=1);d.arc((13,10,23,20),270,90,fill=1,width=2);d.line((7,6,9,3,7,0),fill=1);bands=[15,15,14]
   elif n==40:
    d.polygon([(4,11),(20,11),(17,25),(7,25)],fill=1)
    for x in [5,9,13,17]:d.rectangle((x,2,x+2,14),fill=1)
    d.line((8,17,15,17),fill=0,width=2);bands=[11,9,9]
   elif n==41:
    d.ellipse((4,2,20,15),fill=1);d.polygon([(6,15),(18,15),(12,27)],fill=1);bands=[15,13,11]
   elif n==42:
    d.rounded_rectangle((5,0,18,11),radius=2,fill=1);d.rectangle((10,12,13,26),fill=1);bands=[11]*3
   elif n==45:d.polygon([(3,8),(14,8),(14,3),(23,13),(14,23),(14,18),(3,18)],fill=1);bands=[11]*3
   else:
    d.line((2,13,22,13),fill=1);d.line((12,3,12,23),fill=1);d.line((5,6,19,20),fill=1);d.line((19,6,5,20),fill=1);bands=[15]*3
  for phase in range(8):
   if len(cache)%32768+160>32768:cache.extend(bytes(32768-len(cache)%32768))
   if not mono:table.append((len(cache)//32768+4+SCENES,len(cache)%32768))
   rec=bytearray([4,30,128])
   for y in range(30):
    col=bands[y//10];rec.append(15 if mono else col)
    for xx in range(4):
     bits=0
     for bit in range(8):
      x=xx*8+bit-phase;on=0<=x<24 and y<28 and im.getpixel((x,y))
      if on and mono and col!=15:
       edge=any(not(0<=x+dx<24 and 0<=y+dy<28) or not im.getpixel((x+dx,y+dy)) for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)])
       on=edge or ((x+y)%2==0 if col in [9,13] else (x%2==0 or y%2==0))
      if on:bits|=128>>bit
     rec.append(bits)
   cache.extend(rec+bytes(160-len(rec)))
 cache.extend(bytes(65536-len(cache)));pack.extend(cache)
Path('work/port/build/HAMSAM2.DAT').write_bytes(pack)
lines=['sprite_cache_table:']
for bank,off in table:lines.extend([f' db {bank}',f' dw {off}'])
Path('work/port/src/cache.inc').write_text('\n'.join(lines)+'\n')
print('Resident art',len(pack),'bytes; 736 prepared colour/mono sprite poses')
