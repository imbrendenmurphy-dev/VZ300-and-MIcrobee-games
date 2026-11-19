"""Premium Plus native scenery: colour-cell constrained art + bespoke mono planes."""
from pathlib import Path
from collections import Counter
from PIL import Image,ImageDraw,ImageFont
import runpy,math
P=Path('work/port/src');B=Path('work/port/build')
PAL=[(0,0,0),(170,0,0),(0,170,0),(170,170,0),(0,0,170),(170,0,170),(0,170,170),(170,170,170),(85,85,85),(255,85,85),(85,255,85),(255,255,85),(85,85,255),(255,85,255),(85,255,255),(255,255,255)]
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',n)
small=ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',10)
# The kitchens' layouts come from the VZ300 original's levels.py: the PC
# project folder, or the repo's sibling HamburgerSam2/ folder.
LEVELS=next(p for p in [Path(r'C:/Users/Owner/Documents/HamburgerSam2_VZ300/src/levels.py'),
 Path('../../HamburgerSam2/src/levels.py')] if p.exists())
ns=runpy.run_path(str(LEVELS))
ks=ns['KITCHENS']+[ns['CLASSIC']]
def centered(d,y,t,ft,c):
 w=d.textbbox((0,0),t,font=ft)[2];d.text(((320-w)//2,y),t,font=ft,fill=c)
def star(d,x,y,c):
 d.line((x-2,y,x+2,y),fill=c);d.line((x,y-2,x,y+2),fill=c)
def stage(k,n):
 im=Image.new('P',(320,250));d=ImageDraw.Draw(im)
 # Diner marquee in cell rows 0-1, laid out on cell boundaries so no 8x10
 # cell ever needs more than two colours: row 0 = awning stripes on blue,
 # row 1 = kitchen name (yellow on blue).  Row 2 is left black for the HUD.
 d.rectangle((0,0,319,19),fill=4)
 for x in range(0,320,16):
  d.rectangle((x,0,x+7,4),fill=9);d.rectangle((x+8,0,x+15,4),fill=11)
  for xx in (x+3,x+11):d.point((xx,5),fill=9 if xx<x+8 else 11)
 ft=font(12);w=d.textbbox((0,0),k['name'],font=ft)[2];x0=(320-w)//2
 d.text((x0,19),k['name'],font=ft,fill=11,anchor='ls')
 for sx in (x0-16,x0+w+9):
  d.line((sx,14,sx+6,14),fill=11);d.line((sx+3,11,sx+3,17),fill=11)
  d.point((sx+1,12),fill=11);d.point((sx+5,16),fill=11);d.point((sx+5,12),fill=11);d.point((sx+1,16),fill=11)
 rail=[14,11,10,13,9,14,13,11,11][n]
 for f,g in enumerate(k['girders']):
  y=60+40*f
  for c,t in enumerate(g):
   if t!='=':continue
   x=c*10
   d.rectangle((x,y,x+9,y+1),fill=rail)
   d.rectangle((x,y+3,x+9,y+5),fill=rail)
   d.point((x+2,y+4),fill=0);d.point((x+7,y+4),fill=0)
   d.line((x+1,y+7,x+8,y+7),fill=8)
 for f,cols in enumerate(k['ladders']):
  y=60+40*f+8
  for c in cols:
   x=c*10+4
   d.line((x,y,x,y+31),fill=6,width=2);d.line((x+12,y,x+12,y+31),fill=6,width=2)
   for yy in range(y+3,y+30,7):d.line((x,yy,x+12,yy),fill=6,width=2)
 # Plate rack: porcelain scallops and a red/white chequered counter.
 for c in k['cols']:
  x=c*10
  d.arc((x-6,237,x+46,249),0,180,fill=15,width=2)
  d.line((x-4,242,x+44,242),fill=14,width=2)
 for x in range(0,320,8):
  d.rectangle((x,247,x+7,249),fill=9 if x%16==0 else 15)
 return im
def title():
 im=Image.new('P',(320,250));d=ImageDraw.Draw(im)
 d.rectangle((0,0,319,249),fill=4)
 # Velvet curtains and a lit proscenium frame surround the illustration.
 for x in range(0,320,8):
  d.polygon([(x,0),(x+7,0),(x+7,18+(x%24)),(x,22+(x%24))],fill=9 if x%16==0 else 1)
 for x in [0,304]:
  d.polygon([(x,0),(x+15,0),(x+15,73),(x+5,148),(x+15,225),(x,249)],fill=1)
  d.line((x+5,4,x+6,140,x+9,246),fill=9,width=3)
 for x in range(21,305,16):star(d,x,8,11);star(d,x,244,11)
 # Logo: one ink per 10-pixel cell row gives an arcade colour ramp that can
 # never clash (a pixel-offset shadow did, leaving red fragments).
 def banded(y,t,ft,bands):
  m=Image.new('1',(320,250));md=ImageDraw.Draw(m);centered(md,y,t,ft,1)
  for yy in range(250):
   c=bands.get(yy//10)
   if c is None:continue
   for xx in range(320):
    if m.getpixel((xx,yy)):im.putpixel((xx,yy),c)
 banded(19,'HAMBURGER',font(30),{1:15,2:11,3:11,4:9,5:9})
 banded(50,'SAM II',font(38),{5:15,6:15,7:14,8:14,9:12})
 centered(d,93,'THE BURGER RUSH',font(12),14)
 # Original illustrated chef, outlined and coloured at native resolution.
 d.ellipse((118,122,199,221),fill=0)
 d.ellipse((131,124,183,178),fill=9)
 d.ellipse((128,111,151,138),fill=15);d.ellipse((146,105,172,135),fill=15);d.ellipse((166,113,191,139),fill=15)
 d.rectangle((132,134,187,143),fill=15);d.line((134,141,184,141),fill=14,width=2)
 d.ellipse((170,150,194,161),fill=9)
 d.ellipse((146,148,151,155),fill=0);d.ellipse((168,148,173,155),fill=0)
 d.arc((146,153,174,171),0,180,fill=0,width=3)
 d.polygon([(137,173),(179,173),(190,211),(125,211)],fill=15)
 d.polygon([(148,172),(158,181),(169,172),(163,187),(154,187)],fill=9)
 for y in [189,200]:d.ellipse((165,y,168,y+3),fill=4)
 d.line((136,180,117,195,101,173),fill=15,width=8)
 d.line((181,181,205,174,213,155),fill=15,width=8)
 d.rectangle((132,211,149,225),fill=12);d.rectangle((168,211,184,225),fill=12)
 # Towering burger on Sam's raised tray.
 d.line((199,153,247,153),fill=14,width=3)
 d.pieslice((201,123,245,146),180,360,fill=11)
 for x in [210,221,233]:d.line((x,130,x+1,129),fill=15)
 d.line((201,137,245,137),fill=10,width=3)
 d.line((202,142,244,142),fill=9,width=4)
 d.line((203,147,243,147),fill=11,width=3)
 for x,y in [(42,125),(266,121),(57,185),(262,191),(87,113)]:star(d,x,y,11)
 # Footer on its own cell row (230-239), clear of Sam's feet and the stars.
 ft=ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',11)
 t='SPACE: PLAY    V: COLOUR / MONO'
 w=d.textbbox((0,0),t,font=ft)[2];d.rectangle((40,230,279,239),fill=4)
 d.text(((320-w)//2,238),t,font=ft,fill=15,anchor='ls')
 return im
def orderup():
 """Order Up! bonus stage: the falling layers repair from this, so it must
 hold every static element (counter, ticket rail).  Text is drawn by code."""
 im=Image.new('P',(320,250));d=ImageDraw.Draw(im)
 # ticket rail: cell column 30, rows 2-21, cyan with rivets
 d.rectangle((241,20,242,219),fill=14);d.rectangle((245,20,246,219),fill=14)
 for y in range(24,219,10):d.rectangle((243,y,244,y+1),fill=14)
 # serving counter: cell row 22 = steel top, rows 23-24 = red/white tiles
 d.rectangle((0,222,239,222),fill=15);d.rectangle((0,224,239,226),fill=14)
 for x in range(0,240,4):d.point((x+1,225),fill=0)
 for cy in (23,24):
  for cx in range(30):
   d.rectangle((cx*8,cy*10,cx*8+7,cy*10+9),fill=9)
   for yy in range(0,10,5):
    for xx in range(0,8,4):
     if ((xx//4)+(yy//5)+cx+cy)%2:d.rectangle((cx*8+xx,cy*10+yy,cx*8+xx+3,cy*10+yy+4),fill=15)
 # the rail's foot stands on the counter
 d.rectangle((240,220,247,249),fill=14)
 return im
threshold=((0,8,2,10),(12,4,14,6),(3,11,1,9),(15,7,13,5))
def encode(im,mono=False,mono_dark=()):
 # mono_dark: palette inks shown as plain black in mono (keeps lettering on
 # them readable instead of sitting in dither)
 if mono and mono_dark:
  px=im.get_flattened_data() if hasattr(im,'get_flattened_data') else im.getdata()
  im=im.copy();im.putdata([0 if p in mono_dark else p for p in px])
 raw=bytearray();preview=Image.new('RGB',im.size)
 for cy in range(25):
  for cx in range(40):
   pixels=[im.getpixel((cx*8+x,cy*10+y)) for y in range(10) for x in range(8)]
   cs=Counter(pixels).most_common(2);bg=cs[0][0];fg=cs[1][0] if len(cs)>1 else bg
   if bg!=0 and fg==0:bg,fg=fg,bg
   rr=[]
   for y in range(10):
    row=0
    for x in range(8):
     px=pixels[y*8+x]
     if mono:
      r,g,b=PAL[px];density=(0.22*r+0.64*g+0.14*b)/255*16
      edge=px and any(im.getpixel((max(0,min(319,cx*8+x+dx)),max(0,min(249,cy*10+y+dy))))==0 for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)])
      bit=edge or density>threshold[(cy*10+y)%4][(cx*8+x)%4]
      col=(255,255,255) if bit else (0,0,0)
     else:
      dist=lambda q:sum((PAL[px][a]-PAL[q][a])**2 for a in range(3))
      bit=dist(fg)<dist(bg);col=PAL[fg if bit else bg]
     if bit:row|=128>>x
     preview.putpixel((cx*8+x,cy*10+y),col)
    rr.append(row)
   raw.extend(rr+[0]*4+[15 if mono else (bg<<4)|fg,0])
 return bytes(raw)+bytes(384),preview
pack=bytearray()
for i,im in enumerate([stage(k,n) for n,k in enumerate(ks)]+[title(),orderup()]):
 for mono in [False,True]:
  data,preview=encode(im,mono,(4,) if i<9 else ());pack.extend(data)
  if i in [0,9,10]:preview.resize((960,750),Image.Resampling.NEAREST).save(f'outputs/layout-{i}-'+('mono' if mono else 'colour')+'.png')
(B/'HAMSAM2.DAT').write_bytes(pack)
print('Scenery:',len(pack),'bytes, colour/mono, ten resident 32K banks')
