"""Native Premium Plus art: palette-limited pixel drawings and PCG cell compiler.

Every colour preview is produced from the same two-colour-per-8x10-cell data
used by the target. Monochrome is separately dithered before PCG compilation.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math,json,itertools
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT.parents[1]/'outputs'/'premium-plus-preview'
OUT.mkdir(parents=True,exist_ok=True)
PAL=[(0,0,0),(170,0,0),(0,170,0),(170,170,0),(0,0,170),(170,0,170),(0,170,170),(170,170,170),(85,85,85),(255,85,85),(85,255,85),(255,255,85),(85,85,255),(255,85,255),(85,255,255),(255,255,255)]
BAYER=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]
FONT=ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',10)
BOLD='C:/Windows/Fonts/arialbd.ttf'
def canvas(w,h):return Image.new('RGBA',(w,h),(0,0,0,0))
def ink(c):return PAL[c]+(255,)
def box(d,xy,c):d.rectangle(xy,fill=ink(c))
def line(d,xy,c,width=1):d.line(xy,fill=ink(c),width=width)

def tomato(kind='CH',frame=0,w=16,h=20):
 im=canvas(w,h);d=ImageDraw.Draw(im);phase=frame%4
 if w>16:
  # Large bosses get interior eye/mouth cells with independent red/white ink.
  d.ellipse((2,5,w-3,h-4),fill=ink(1))
  d.ellipse((3,5,w-6,h-8),fill=ink(9))
  d.arc((5,8,w-6,h-8),180,260,fill=ink(11),width=2)
  ex=w//5;ey=h//3;ew=max(6,w//5);eh=max(8,h//5)
  for x in [ex,w-ex-ew]:
   d.rounded_rectangle((x,ey,x+ew,ey+eh),radius=2,fill=ink(15))
   px=x+ew//2+(phase%3)-1
   d.rectangle((px,ey+2,px+2,ey+eh-2),fill=ink(0))
  line(d,(ex-2,ey-3,ex+ew,ey),0,2)
  line(d,(w-ex-ew,ey,w-ex+2,ey-3),0,2)
  d.polygon([(w//4,h*2//3),(w*3//4,h*2//3),(w*2//3,h-7),(w//3,h-7)],fill=ink(0))
  for x in range(w//3,w*2//3,5):box(d,(x,h*2//3,x+2,h*2//3+3),15)
  for x in range(w//4,w*3//4,7):
   d.polygon([(w//2,8),(x,1),(x+3,5)],fill=ink(10))
  if kind=='BARON':
   box(d,(w//3,0,w*2//3,7),4);box(d,(w//4,7,w*3//4,9),12)
   line(d,(w//2-2,ey+eh+5,w//3,ey+eh+2),0,2)
   line(d,(w//2+2,ey+eh+5,w*2//3,ey+eh+2),0,2)
  if kind=='MAMA':
   d.arc((0,0,w-1,19),180,360,fill=ink(15),width=3)
   for x in range(6,w-5,8):d.ellipse((x,1,x+5,6),fill=ink(15))
  if kind=='GREAT':
   d.polygon([(w//4,5),(w//4,0),(w//2,5),(w*3//4,0),(w*3//4,5)],fill=ink(11))
   for x in [3,w-7]:box(d,(x,h//2,x+3,h-8),13)
  return im
 # Small enemies have different silhouettes, not just palette swaps.
 body=10 if kind=='UN' else 11 if kind=='GO' else 5 if kind=='ROT' else 9
 dark=2 if kind=='UN' else 3 if kind=='GO' else 1
 bounds=(3,4,12,16) if kind=='RO' else (1,5,14,16)
 if kind=='BF':bounds=(0,4,15,17)
 if kind=='BALL':
  d.ellipse((1,4,14,17),fill=ink(8));d.arc((2,5,13,16),150,300,fill=ink(15),width=2)
  line(d,(5+phase,6,10,15),7);body=7
 else:
  d.ellipse(bounds,fill=ink(dark));d.ellipse((bounds[0],bounds[1],bounds[2]-2,bounds[3]-2),fill=ink(body))
  line(d,(bounds[0]+3,bounds[1]+2,bounds[0]+2,bounds[1]+4),11 if kind!='UN' else 14)
 # Stalk, glower, teeth, dancing shoes.
 line(d,(7,5,8,1,10,1),10)
 d.polygon([(7,5),(3,2),(4,5),(11,3),(10,6)],fill=ink(2))
 for x in [4,10]:
  box(d,(x,8,x+2,10),15);box(d,(x+1+(phase==3),9,x+1+(phase==3),10),0)
 line(d,(3,7,6,8),0);line(d,(10,8,13,7),0)
 line(d,(5,13,10,13),0);d.point((7,14),fill=ink(15))
 if kind=='HOP':
  line(d,(4,16,2,19,5,19),11);line(d,(11,16,14,19,11,19),11)
 elif kind=='ROT':
  for x in [3,7,12]:line(d,(x,14,x+(phase%2),18),2)
  box(d,(9,5,11,7),2)
 else:
  box(d,(2+phase%2*2,17,5+phase%2*2,18),8)
  box(d,(10-phase%2*2,18,13-phase%2*2,19),8)
 if kind=='UN':
  for y in [7,11,15]:line(d,(4,y,11,y),2)
 if kind=='GO':d.point((1,2+phase*3),fill=ink(15));d.point((14,14-phase*2),fill=ink(15))
 return im

def player(direction='R',frame=0):
 im=canvas(16,20);d=ImageDraw.Draw(im);s=frame%2
 # Blue overalls, white apron, orange face and a yellow hard hat.
 box(d,(5,2,10,7),11);box(d,(4,2,11,4),15);box(d,(3,4,12,4),15)
 if direction=='U':box(d,(5,5,10,7),3)
 else:
  d.point((9 if direction=='R' else 6,5),fill=ink(0))
  line(d,(7,7,10 if direction=='R' else 5,7),1)
 box(d,(4,8,11,14),12);box(d,(6,9,9,14),15)
 line(d,(3,9,2,12),11,2);line(d,(12,9,13,12),11,2)
 box(d,(4+s,15,6+s,18),4);box(d,(9-s,15,11-s,18),4)
 box(d,(3+s,18,7+s,19),15);box(d,(8-s,18,12-s,19),15)
 line(d,(14,11,14,4),3);box(d,(12,3,15,5),7)
 if direction=='L':im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 return im

def tile(kind,frame=0):
 im=canvas(16,20);d=ImageDraw.Draw(im);box(d,(0,0,15,19),0)
 if kind=='brick':
  box(d,(0,0,15,19),1)
  for y in [0,6,12,18]:
   line(d,(0,y,15,y),9)
   x=4 if y%12 else 12;line(d,(x,y,x,y+5),9)
   line(d,(1,y+1,14,y+1),9)
  line(d,(0,0,15,0),9);line(d,(0,1,0,19),9)
 elif kind=='machine':
  box(d,(0,0,15,19),4);box(d,(1,1,14,18),6)
  box(d,(2,3,13,7),0);line(d,(3,5,6,5,7,3+frame%3,9,6,12,4),10)
  box(d,(2,10,13,17),4)
  for x in [3,6,9,12]:line(d,(x,11,x,16),14)
  for x in [1,14]:d.point((x,1),fill=ink(15));d.point((x,18),fill=ink(15))
 elif kind=='lab':
  box(d,(0,0,15,19),4);d.rounded_rectangle((1,1,14,18),radius=2,outline=ink(12))
  line(d,(3,4,7,4,7,9,12,9,12,15),13)
  line(d,(3,15,5,15,5,11,9,11),6)
  d.ellipse((10,2,13,5),fill=ink(14 if frame%2 else 5))
  d.ellipse((2,13,5,16),fill=ink(10))
 elif kind.startswith('trap'):
  level=int(kind[-1]);box(d,(1,15,14,17),3);line(d,(1,15,14,15),11)
  if level>1:
   line(d,(1,15,3,7,7,12),7,2);line(d,(14,15,12,7,8,12),7,2)
  if level>2:
   for x in [3,6,9,12]:line(d,(x,7,x,11),15)
   box(d,(6,14,9,15),9 if frame%2 else 11)
 elif kind=='floor':
  for x,y in [(3,15),(12,5)]:d.point((x,y),fill=ink(8))
 return im

def dist(a,b):return sum((a[i]-b[i])**2*w for i,w in enumerate([2,3,1]))
def compile_cells(im,mono=False):
 """Return (width_cells,height_cells, cell records[mask10,data10,colour])."""
 w=(im.width+7)//8;h=(im.height+9)//10;records=[]
 padded=canvas(w*8,h*10);padded.paste(im,(0,0))
 for cy in range(h):
  for cx in range(w):
   pixels=[padded.getpixel((cx*8+x,cy*10+y)) for y in range(10) for x in range(8)]
   opaque=[p[:3] for p in pixels if p[3]]
   mask=[];data=[]
   if not opaque:records.append(bytes(21));continue
   if mono:
    bg,fg=0,15
   else:
    hist=Counter(opaque)
    counts={i:hist[rgb] for i,rgb in enumerate(PAL)}
    candidates=sorted(range(16),key=lambda i:counts[i],reverse=True)[:7]
    if 0 not in candidates:candidates.append(0)
    pairs=[(0,i) for i in candidates if i] if len(opaque)<80 else list(itertools.combinations(candidates,2))
    bg,fg=min(pairs,key=lambda pair:sum(n*min(dist(p,PAL[pair[0]]),dist(p,PAL[pair[1]])) for p,n in hist.items()))
    if bg and not fg:bg,fg=fg,bg
   for y in range(10):
    m=b=0
    for x in range(8):
     p=pixels[y*8+x]
     if not p[3]:continue
     m|=128>>x
     if mono:
      # Luma plus contrast boost; inked silhouettes remain recognizable.
      lum=(p[0]*.299+p[1]*.587+p[2]*.114)/255
      value=lum>(BAYER[(cy*10+y)%4][(cx*8+x)%4]+.5)/16
     else:value=dist(p[:3],PAL[fg])<dist(p[:3],PAL[bg])
     if value:b|=128>>x
    mask.append(m);data.append(b)
   records.append(bytes(mask+data+[(bg<<4)|fg]))
 return w,h,records

def render(compiled,bg=(0,0,0)):
 w,h,records=compiled;im=Image.new('RGB',(w*8,h*10),bg)
 for i,r in enumerate(records):
  for y in range(10):
   for x in range(8):
    if r[y]&(128>>x):im.putpixel((i%w*8+x,i//w*10+y),PAL[r[20]&15 if r[10+y]&(128>>x) else r[20]>>4])
 return im

def title():
 im=canvas(320,250);d=ImageDraw.Draw(im);d.fontmode='1';box(d,(0,0,319,249),0)
 # Marquee, midnight skyline, big illustrated villain and neon typography.
 for x in range(0,320,8):
  ht=12+(x*7)%37;box(d,(x,198-ht,x+7,205),4)
  for y in range(198-ht+4,197,7):
   if (x+y)%3:box(d,(x+2,y,x+3,y+2),11)
 for x in range(4,320,12):d.ellipse((x,3,x+3,6),fill=ink(11));d.ellipse((x,242,x+3,245),fill=ink(9))
 for y in range(15,240,12):d.ellipse((3,y,6,y+3),fill=ink(11));d.ellipse((313,y,316,y+3),fill=ink(11))
 d.text((96,12),'ATTACK OF THE',font=FONT,fill=ink(15))
 for word,y,size in [('KILLER',25,43),('TOMATOES',65,40)]:
  f=ImageFont.truetype(BOLD,size);bb=d.textbbox((0,0),word,font=f);x=(320-(bb[2]-bb[0]))//2
  for dx,dy,c in [(3,4,4),(1,2,1),(0,0,11 if word=='KILLER' else 9)]:d.text((x+dx,y+dy),word,font=f,fill=ink(c),stroke_width=1,stroke_fill=ink(c))
 hero=tomato('GREAT',1,88,94);im.alpha_composite(hero,(115,109))
 im.alpha_composite(player('R',0).resize((32,40),Image.Resampling.NEAREST),(74,162))
 im.alpha_composite(tomato('RO',0),(217,176));im.alpha_composite(tomato('UN',1),(239,180))
 f=ImageFont.truetype(BOLD,30);d.text((267,95),'2',font=f,fill=ink(11),stroke_width=1)
 box(d,(43,208,277,226),4);line(d,(43,208,277,208),14)
 d.text((67,211),'PREMIUM PLUS  M: COLOUR / MONO',font=FONT,fill=ink(15))
 d.text((87,229),'PRESS FIRE TO START',font=FONT,fill=ink(11))
 return im

def scene(mono=False):
 levels=json.loads((ROOT/'levels.json').read_text());rows=levels['mz_yard']['rows']
 im=Image.new('RGB',(320,250));d=ImageDraw.Draw(im)
 for y,row in enumerate(rows):
  for x,c in enumerate(row):im.paste(render(compile_cells(tile('brick' if c=='#' else 'floor'),mono)),(x*16,30+y*20))
 d.rectangle((0,0,319,25),fill=(0,0,0));d.line((0,25,319,25),fill=PAL[15 if mono else 14])
 d.text((5,1),'1UP  012500',font=FONT,fill=PAL[15 if mono else 11]);d.text((119,1),'HI  025000',font=FONT,fill=PAL[15])
 d.text((244,1),'LIVES  04',font=FONT,fill=PAL[15 if mono else 14]);d.text((5,13),'SAUCE: S A - - -',font=FONT,fill=PAL[15 if mono else 10]);d.text((209,13),'SAN DIEGO  1-1',font=FONT,fill=PAL[15])
 for name,x,y,frame in [('CH',0,0,0),('RO',12,4,1),('BF',7,6,0),('UN',18,6,1),('HOP',17,10,2),('GO',3,10,1),('ROT',2,2,0)]:
  im.paste(render(compile_cells(tomato(name,frame),mono)),(x*16,y*20+30))
 im.paste(render(compile_cells(player('R',1),mono)),(9*16,230))
 for x,y in [(10,10),(6,4)]:im.paste(render(compile_cells(tile('trap3',1),mono)),(x*16,30+y*20))
 return im

if __name__=='__main__':
 for mode in [False,True]:
  tag='mono' if mode else 'colour'
  scene(mode).resize((960,750),Image.Resampling.NEAREST).save(OUT/('arena-'+tag+'.png'))
  render(compile_cells(title(),mode)).resize((960,750),Image.Resampling.NEAREST).save(OUT/('title-'+tag+'.png'))
 print('Wrote hardware-cell-constrained art previews to',OUT)


