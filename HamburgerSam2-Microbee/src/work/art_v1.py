from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import runpy
P=Path('work/port/src'); lines=[]
def db(data):
 for i in range(0,len(data),64):lines.append(' db '+','.join(str(v) for v in data[i:i+64]))
def rows(im):
 return [sum((128>>b) if x+b<im.width and im.getpixel((x+b,y)) else 0 for b in range(8)) for y in range(im.height) for x in range(0,im.width,8)]
def asset(name,im,col):
 lines.append(name+':');db([(im.width+7)//8,im.height,col]+rows(im))
def chef(frame):
 im=Image.new('1',(24,28));d=ImageDraw.Draw(im)
 # Toque with three rounded lobes, face, neckerchief, double-breasted coat.
 d.ellipse((5,0,12,7),fill=1);d.ellipse((10,0,18,7),fill=1);d.ellipse((15,2,21,8),fill=1)
 d.rectangle((7,6,20,9),fill=1);d.rectangle((8,10,17,15),fill=1)
 d.point((15,11),fill=0);d.rectangle((16,13,20,14),fill=1)
 d.line((10,15,15,15),fill=0);d.polygon([(9,16),(17,16),(19,23),(7,23)],fill=1)
 d.point((14,18),fill=0);d.point((14,21),fill=0)
 d.line((8,17,4,21),fill=1,width=3)
 if frame in (4,5):d.line((18,18,23,15),fill=1,width=3)
 elif frame==9:d.line((18,17,22,10),fill=1,width=3);d.line((7,17,3,10),fill=1,width=3)
 else:d.line((18,17,21,21),fill=1,width=3)
 d.rectangle((8,24,10,26),fill=1);d.rectangle((16,24,18,26),fill=1)
 d.rectangle((6 if frame&2 else 8,26,11,27),fill=1);d.rectangle((16,26,21 if frame&2 else 19,27),fill=1)
 if frame in (1,3,5):im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 if frame==12:im=im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
 if frame==11:d.line((1,10,22,10),fill=1,width=2)
 return im
def enemy(kind,frame):
 im=Image.new('1',(24,28));d=ImageDraw.Draw(im)
 if kind==0:
  d.rounded_rectangle((6,2,17,22),radius=5,fill=1)
  d.line([(9,5),(14,8),(9,11),(14,14),(10,18)],fill=0,width=2)
 elif kind==1:
  d.ellipse((2,8,22,24),fill=1);d.ellipse((8,8,17,17),fill=0);d.ellipse((10,10,15,15),fill=1)
 elif kind==2:
  d.rounded_rectangle((6,1,18,23),radius=6,fill=1)
  for xy in [(8,6),(15,4),(10,17),(16,18),(7,13)]:d.point(xy,fill=0)
 else:
  d.polygon([(7,6),(19,6),(19,15),(15,21),(6,24),(10,16)],fill=1)
  d.line((12,6,14,1,18,1),fill=1,width=2)
 d.rectangle((8,8,10,10),fill=0);d.rectangle((14,8,16,10),fill=0)
 d.line((9,13,15,13),fill=0);d.line((5,15,1,19),fill=1,width=2);d.line((19,15,23,18),fill=1,width=2)
 d.line((9,23,7 if frame&2 else 9,27),fill=1,width=2);d.line((16,23,19 if frame&2 else 16,27),fill=1,width=2)
 if frame==4:
  d.line((7,7,11,11),fill=0);d.line((11,7,7,11),fill=0)
 if frame==5:im=im.resize((24,9));im2=Image.new('1',(24,28));im2.paste(im,(0,19));im=im2
 if frame&1:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 return im
names=[]
for n in range(46):
 name=f'sprite_{n}';names.append(name)
 if n<13:im=chef(n);col=15
 elif n<37:kind,frame=divmod(n-13,6);im=enemy(kind,frame);col=[9,11,10,13][kind]
 else:
  im=Image.new('1',(24,28));d=ImageDraw.Draw(im);col=14
  if n==37:
   d.rounded_rectangle((3,9,17,23),radius=3,fill=1);d.arc((13,10,23,20),270,90,fill=1,width=2);d.line((7,6,9,3,7,0),fill=1)
  elif n==38:
   col=11;d.polygon([(4,11),(20,11),(17,25),(7,25)],fill=1)
   for x in [5,9,13,17]:d.rectangle((x,2,x+2,14),fill=1)
   d.line((8,17,15,17),fill=0,width=2)
  elif n==39:col=13;d.ellipse((4,2,20,15),fill=1);d.polygon([(6,15),(18,15),(12,27)],fill=1)
  elif n==40:col=11;d.rounded_rectangle((5,0,18,11),radius=2,fill=1);d.rectangle((10,12,13,26),fill=1)
  else:
   for x,y in [(3,5),(14,3),(8,12),(21,15),(5,23),(17,25)]:d.ellipse((x,y,x+2,y+2),fill=1)
 asset(name,im,col)
lines.append('sprite_table: dw '+','.join(names))
for n in range(6):
 im=Image.new('1',(40,8));d=ImageDraw.Draw(im)
 if n==0:
  d.pieslice((0,-1,39,14),180,360,fill=1);d.line((1,7,38,7),fill=1)
  for x,y in [(9,4),(18,2),(28,3),(34,5)]:d.line((x,y,x+1,y),fill=0)
 elif n==1:
  d.polygon([(0,2),(5,0),(10,3),(15,0),(21,2),(26,0),(32,3),(39,1),(38,6),(33,7),(27,5),(20,7),(12,5),(5,7),(0,5)],fill=1)
 elif n==2:d.polygon([(0,1),(39,1),(39,4),(32,4),(29,7),(24,4),(15,4),(11,6),(7,4),(0,4)],fill=1)
 elif n==3:
  d.rounded_rectangle((0,1,39,7),radius=3,fill=1)
  for x in range(3,38,6):d.line((x,3,x+2,5),fill=0)
 elif n==4:
  for x in range(0,35,12):d.ellipse((x,0,x+15,7),fill=1);d.line((x+5,3,x+9,3),fill=0)
 else:d.rounded_rectangle((0,0,39,6),radius=3,fill=1);d.line((3,2,36,2),fill=0)
 asset(f'food{n}',im,[11,10,11,9,9,11][n])
lines.append('food_table: dw '+','.join(f'food{n}' for n in range(6)))
# A readable, newly rasterised condensed face at the actual target size.
font=ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',14)
lines.append('font_native:')
for ch in range(32,96):
 im=Image.new('1',(8,16));d=ImageDraw.Draw(im);d.text((0,-1),chr(ch),font=font,fill=1);db(rows(im))
lines.append('native_rows:')
for start in range(0,250,50):lines.append(' dw '+','.join(str(0x9000+(y//10)*640+y%10) for y in range(start,min(start+50,250))))
ns=runpy.run_path(r'C:/Users/Owner/Documents/HamburgerSam2_VZ300/src/levels.py');ks=ns['KITCHENS']+[ns['CLASSIC']]
atlas=[];maps=[]
for k in ks:
 im=Image.new('P',(320,250));d=ImageDraw.Draw(im)
 for f,g in enumerate(k['girders']):
  y=(14+9*f)*4
  for c,t in enumerate(g):
   if t=='=':
    x=c*10;d.rectangle((x,y,x+9,y+1),fill=14);d.line((x+1,y+3,x+8,y+3),fill=14);d.point((x+2,y+2),fill=14);d.point((x+7,y+2),fill=14)
 for f,cols in enumerate(k['ladders']):
  y=(14+f*9)*4+4
  for c in cols:
   x=c*10+4;d.line((x,y,x,y+31),fill=6,width=2);d.line((x+12,y,x+12,y+31),fill=6,width=2)
   for yy in range(y+3,y+30,7):d.line((x,yy,x+12,yy),fill=6,width=2)
 for c in k['cols']:
  x=c*10;d.line((x-4,246,x+44,246),fill=15,width=2);d.line((x,249,x+40,249),fill=15)
 m=[]
 for cy in range(25):
  for cx in range(40):
   tile=im.crop((cx*8,cy*10,cx*8+8,cy*10+10));col=max(tile.getdata());raw=tuple(rows(tile)+[col])
   if raw not in atlas:atlas.append(raw)
   m.append(atlas.index(raw))
 maps.append(m)
assert len(atlas)<256,len(atlas)
lines.append('background_atlas:')
for a in atlas:db(a)
lines.append('background_tables: dw '+','.join(f'background_{i}' for i in range(9)))
for i,m in enumerate(maps):
 lines.append(f'background_{i}:');r=[];p=0
 while p<len(m):
  n=1
  while p+n<len(m) and m[p+n]==m[p] and n<255:n+=1
  r.extend([n,m[p]]);p+=n
 r.append(0);db(r)
(P/'art.inc').write_text('\n'.join(lines)+'\n')
print('Native art:',len(atlas),'background glyphs; 46 characters; six ingredients; 8x16 font')
