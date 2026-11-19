"""Hand-drawn native Microbee assets. No VZ pixel data is read or scaled."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import re,sys
ROOT=Path(__file__).parent
orig=Path(r'C:/Users/Owner/Documents/KillerTomatoes_VZ300/src/gen_data.inc').read_text()
fontpath='C:/Windows/Fonts/consolab.ttf'
small=ImageFont.truetype(fontpath,12)
large=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',43)
out=[]
def db(name,data):
 out.append(name+':')
 for i in range(0,len(data),24):out.append(' db '+','.join(str(v) for v in data[i:i+24]))
def bits(im):
 return [sum((128>>k) if im.getpixel((x+k,y)) else 0 for k in range(8)) for y in range(im.height) for x in range(0,im.width,8)]
chars=' ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.,-:\'/\*"()+=@^<>#%&'.replace('\\','')
assert len(chars)==58,len(chars)
f=[]
for ch in chars:
 im=Image.new('1',(8,16));d=ImageDraw.Draw(im);d.text((0,0),ch,font=small,fill=1)
 f+=bits(im)
db('font',f)
for i,ch in enumerate(chars):
 if i>36 and ch not in '!-':
  out.append('bigfont_'+str(i)+' equ bigfont_0')
  continue
 im=Image.new('1',(24,52));d=ImageDraw.Draw(im)
 box=d.textbbox((0,0),ch,font=large);w=box[2]-box[0]
 temp=Image.new('1',(max(w,24),52));ImageDraw.Draw(temp).text((-box[0],0),ch,font=large,fill=1)
 if w>24: temp=temp.resize((24,52))
 im.paste(temp,(0,0))
 im=im.resize((16,40))
 db('bigfont_'+str(i),[2,40,9]+bits(im))
out.append('big_font_table: dw '+','.join('bigfont_'+str(i) for i in range(len(chars))))

def tomato(w,h,variant,frame):
 im=Image.new('1',(w,h));d=ImageDraw.Draw(im)
 # leafy crown, scalloped fruit silhouette, highlights, angry eyes and teeth.
 d.ellipse((1,4,w-2,h-3),fill=1)
 d.polygon([(w//2,1),(w//2+2,5),(w*3//4,2),(w*2//3,7),(w//3,7),(w//4,2),(w//2-2,5)],fill=1)
 d.line([(w//2,1),(w//2+2,0)],fill=1,width=1)
 d.line([(4,7),(3,10)],fill=0)
 ey=h//2-2;ex=max(3,w//5);ew=max(3,w//7);eh=max(3,h//10)
 d.rectangle((ex,ey,ex+ew-1,ey+eh-1),fill=0);d.rectangle((w-ex-ew,ey,w-ex-1,ey+eh-1),fill=0)
 d.line((ex-1,ey-2,ex+3,ey-1),fill=0);d.line((w-ex-4,ey-1,w-ex,ey-2),fill=0)
 d.arc((w//3,h//2,w*2//3,h-5),0,180,fill=0,width=1)
 d.line((4,h-3,3+(frame%2)*2,h-1),fill=1,width=2)
 d.line((w-5,h-3,w-4-(frame%2)*2,h-1),fill=1,width=2)
 if variant=='ROT':
  for x,y in [(5,8),(10,14),(4,13)]:d.point((x,y),fill=0)
 if variant=='BARON':d.rectangle((w//3,1,w*2//3,5),fill=1);d.line((2,6,w-3,6),fill=1)
 if variant=='MAMA':d.arc((1,0,w-2,8),180,360,fill=1,width=2)
 return im

def art(name,w,h):
 n=name.replace('spr_','').replace('tl_',''); im=Image.new('1',(w,h));d=ImageDraw.Draw(im);col=9
 frame=int(n[-1]) if n[-1:].isdigit() else 0
 if name.startswith('spr_') and (n[:2] in ('PR','PL','PU','PD') or n=='PWIN'):
  col=14
  d.ellipse((5,1,11,7),fill=1);d.rectangle((3,1,12,3),fill=1)
  if n.startswith('PU'):d.rectangle((5,3,11,6),fill=1)
  else:d.point((10 if n.startswith('PR') else 6,4),fill=0)
  d.polygon([(5,8),(10,8),(12,14),(3,14)],fill=1)
  d.line((4,9,1,12),fill=1,width=2);d.line((11,9,14,7),fill=1,width=2)
  d.line((6,14,4+frame%2*2,18),fill=1,width=2);d.line((9,14,11-frame%2*2,18),fill=1,width=2)
  d.rectangle((12,4,15,7),fill=1)
 elif name.startswith('spr_'):
  if any(t in n for t in ['SHOT','SEED','SHIELD','BONK','POP','FLAT']):
   col=11
   if 'SHOT' in n:d.line((2,9,13,9),fill=1,width=3);d.line((1,6,5,7),fill=1)
   elif 'FLAT' in n:d.ellipse((1,14,14,18),fill=1)
   elif 'SHIELD' in n:d.arc((1,1,w-2,h-2),0,360,fill=1,width=1)
   else:
    for x,y in [(2,2),(12,3),(7,8),(2,14),(13,16)]:d.line((8,10,x,y),fill=1)
  else:
   variant=next((v for v in ['BARON','MAMA','ROT'] if v in n),'')
   im=tomato(w,h,variant,frame)
   col=10 if n.startswith(('UN','ROT')) else 11 if n.startswith('GO') else 13 if n.startswith('HOP') else 9
 elif n.startswith('W_'):
  col=0x3B if n=='W_BRICK' else 0x16 if n=='W_CANS' else 0x45
  if n=='W_BRICK':
   d.rectangle((0,0,w-1,h-1),outline=1)
   for y in [5,10,15]:d.line((0,y,w-1,y),fill=1)
   for y in range(0,h,5):d.line((4 if y%10 else 11,y,4 if y%10 else 11,y+5),fill=1)
  elif n=='W_CANS':
   for x in [1,9]:d.rounded_rectangle((x,1,x+5,18),radius=2,outline=1);d.line((x,6,x+5,6),fill=1);d.line((x,14,x+5,14),fill=1)
  else:d.rectangle((1,1,14,18),outline=1);d.line((3,5,10,5,10,12,13,12),fill=1);d.ellipse((3,12,6,15),outline=1)
 elif any(t in n for t in ['FLOOR','GRASS','CHECK','GRID','PARTY','SH']):
  col=8
  if 'SH' not in n:d.point((3,17),fill=1);d.point((12,7),fill=1)
 elif 'TRAP' in n:
  col=11
  d.line((1,16,14,16),fill=1,width=2);d.line((2,14,13,14),fill=1)
  if '1' not in n:d.line((1,15,3,7,6,11),fill=1);d.line((14,15,12,7,9,11),fill=1)
  if '3' in n or 'C' in n:
   for x in range(3,14,3):d.line((x,7,x,11),fill=1)
 elif any(t in n for t in ['GRILL','VENT','ZAP','MANHOLE']):
  col=9 if n[-1:]=='2' else 11 if n[-1:]=='1' else 8
  d.ellipse((1,4,14,17),outline=1)
  for x in [4,7,10]:d.line((x,7,x,14),fill=1)
 elif 'CONV' in n:
  col=6;d.line((0,2,15,2),fill=1);d.line((0,17,15,17),fill=1)
  for y in [5,10,15]:d.line((4,y-2+frame*2,8,y+frame*2,12,y-2+frame*2),fill=1)
 else:
  col=14
  d.rounded_rectangle((2,3,13,17),radius=2,outline=1)
  symbol= 'K' if 'GUN' in n else 'S' if 'SNEAK' in n else 'P' if 'RECORD' in n else '2' if 'X2' in n else 'C' if 'CAN' in n else n[-1] if n.startswith('T_L') else '+'
  d.text((4,4),symbol,font=small,fill=1)
 return im,col

names=list(re.finditer(r'^(spr_\w+|tl_\w+):\n((?:\s+db[^\n]*\n)+)',orig,re.M))
sheet=Image.new('RGB',(640,((len(names)+15)//16)*64),(12,16,24));sd=ImageDraw.Draw(sheet)
pal=[(0,0,0),(160,35,35),(35,140,50),(130,100,50),(35,60,150),(130,40,130),(30,140,140),(170,170,170),(65,65,65),(255,80,65),(100,220,85),(255,215,80),(100,130,245),(240,100,230),(90,220,240),(245,245,225)]
for i,m in enumerate(names):
 name=m[1];count=len(re.findall(r'\$[0-9A-F]{2}',m[2]))
 w,h=(48,60) if count==90 else (32,40) if count==40 else (16,20)
 im,col=art(name,w,h);db(name,[w//8,h,col]+bits(im))
 x=i%16*40;y=i//16*64
 preview=Image.new('RGB',im.size,pal[(col>>4)&15]);preview.paste(pal[col&15],mask=im)
 sheet.paste(preview,(x,y));sd.text((x,y+43),name.replace('spr_','').replace('tl_','')[:6],fill='white',font=ImageFont.truetype(fontpath,8))
im=tomato(80,80,'MAMA',0);db('title_tomato',[10,80,9]+bits(im))
im=Image.new('1',(16,20));d=ImageDraw.Draw(im)
d.line((8,0,6,5,9,12,7,19),fill=1,width=2)
d.polygon([(7,5),(1,2),(2,7),(7,9)],fill=1)
d.polygon([(8,12),(14,8),(14,13),(8,15)],fill=1)
db('border_vine',[2,20,2]+bits(im))
out.append('native_rows:')
for y in range(0,250,10):out.append(' dw '+','.join(str(0x8000+(r//10)*640+r%10) for r in range(y,y+10)))
(ROOT/'src/native_art.inc').write_text('\n'.join(out)+'\n')
Path('outputs').mkdir(exist_ok=True);sheet.save('outputs/art-progress.png')
print('Native assets:',len(names))
