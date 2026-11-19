"""Native 8x10-cell art direction, dual colour/ordered-dither PCG banks.

Scenes are drawn at 320x250. Each hardware cell is reduced to two colours,
then encoded as one PCG mask plus a foreground/background attribute.
Monochrome is separately authored from those colours, not a greyscale filter.
"""
from pathlib import Path
from collections import Counter
import math,json
from PIL import Image,ImageDraw,ImageFont
import pixfont
R=Path(__file__).resolve().parents[1]
PAL=[(0,0,0),(176,0,0),(0,176,0),(176,176,0),(0,0,176),(176,0,176),(0,176,176),(192,192,192),(96,96,96),(255,48,48),(64,255,64),(255,240,96),(80,96,255),(255,96,255),(96,240,255),(255,255,255)]
# Deliberate tone separation makes red velvet, blue canvas and gold distinct.
TONE=[0,6,7,9,2,5,8,12,5,9,12,15,6,10,13,16]
BAYER=((0,8,2,10),(12,4,14,6),(3,11,1,9),(15,7,13,5))
def font(size,bold=True):return ImageFont.truetype('C:/Windows/Fonts/'+('georgiab.ttf' if bold else 'georgia.ttf'),size)
def bitmap_font(size=10):return ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',size)
def new():return Image.new('P',(320,250),0)
def star(d,x,y,c=11,r=3):
 d.line((x-r,y,x+r,y),fill=c);d.line((x,y-r,x,y+r),fill=c)
 if r>3:d.point((x-2,y-2),fill=c);d.point((x+2,y+2),fill=c)
def text(d,xy,s,size,colour,outline=0):
 d.text(xy,s,font=font(size),fill=colour,stroke_width=1 if outline else 0,stroke_fill=outline)
def curtain(d,left=True,top=0,bottom=224,width=32,colour=1):
 for xx in range(width):
  x=xx if left else 319-xx
  c=colour if xx%8<5 else 9
  d.line((x,top,x,bottom),fill=c)
  if xx%8==0:d.line((x,top,x,bottom),fill=0)
 for y in range(top+8,bottom,22):
  xx=width-3
  x=xx if left else 319-xx
  d.line((x-2,y,x+2,y+3),fill=11,width=2)
def portrait(d,x,y,flip=False):
 # 44x70 illustrated clown, drawn in native pixels.
 d.ellipse((x+5,y+10,x+37,y+39),fill=9)
 d.ellipse((x+11,y+12,x+31,y+39),fill=15)
 d.polygon([(x+20,y),(x+8,y+14),(x+33,y+14)],fill=14)
 d.line((x+7,y+15,x+34,y+15),fill=11,width=2)
 d.rectangle((x+15,y+21,x+17,y+24),fill=0);d.rectangle((x+26,y+21,x+28,y+24),fill=0)
 d.ellipse((x+19,y+26,x+25,y+31),fill=9)
 d.arc((x+15,y+25,x+29,y+35),5,175,fill=0,width=2)
 d.polygon([(x+21,y+41),(x+7,y+35),(x+8,y+47)],fill=11)
 d.polygon([(x+22,y+41),(x+37,y+35),(x+36,y+47)],fill=11)
 d.polygon([(x+12,y+45),(x+32,y+45),(x+39,y+63),(x+5,y+63)],fill=14)
 d.line((x+21,y+47,x+21,y+61),fill=0,width=2)
 d.ellipse((x+20,y+49,x+24,y+53),fill=11)
 d.ellipse((x+2,y+62,x+19,y+69),fill=9);d.ellipse((x+25,y+62,x+43,y+69),fill=9)
def title():
 im=new();d=ImageDraw.Draw(im)
 # Dark indigo proscenium, framed by repeated velvet folds.
 d.rectangle((0,0,319,249),fill=0)
 curtain(d,True,0,208,24);curtain(d,False,0,208,24)
 for x in range(24,296,16):
  d.pieslice((x-8,-25,x+24,25),0,180,fill=1)
  d.arc((x-8,-25,x+24,25),0,180,fill=11,width=2)
 for x in range(32,290,16):d.ellipse((x,17,x+2,19),fill=11)
 for x,y in [(44,40),(276,39),(38,89),(281,92),(77,101),(250,112)]:star(d,x,y,14,3)
 # Decorative marquee letterforms originate from a vector serif, rasterised here.
 f=font(44);label='CIRCUS';box=d.textbbox((0,0),label,font=f);w=box[2]-box[0]
 d.text(((320-w)//2+2,28),label,font=f,fill=1,stroke_width=2,stroke_fill=1)
 d.text(((320-w)//2,25),label,font=f,fill=11,stroke_width=1,stroke_fill=0)
 d.line((57,79,263,79),fill=11)
 text(d,(140,74),'2',40,15,1)
 tag='THE GREATEST SHOW ON A BEE';pixfont.draw(im,(320-pixfont.width(tag,7))//2,119,tag,14,7)
 # Circus ring and spotlights use sparse dither, leaving typography clean.
 for y in range(125,210):
  reach=(y-125)//2
  for x in range(max(24,74-reach),min(296,75+reach)):
   if (x+y)%4==0:im.putpixel((x,y),4)
  for x in range(max(24,245-reach),min(296,246+reach)):
   if (x-y)%4==0:im.putpixel((x,y),5)
 d.ellipse((29,182,291,219),fill=1,outline=11,width=2)
 d.arc((40,188,280,215),0,180,fill=9,width=2)
 portrait(d,40,135);portrait(d,237,135)
 # Centre pedestal, ringmaster's hat and performing acrobat silhouette.
 d.polygon([(132,197),(143,174),(178,174),(190,197)],fill=9,outline=11)
 for x in range(140,188,8):d.line((x,180,x,195),fill=11)
 d.ellipse((141,167,179,177),fill=11)
 d.rectangle((148,136,172,165),fill=0,outline=14,width=2)
 d.rectangle((149,155,171,160),fill=9)
 d.ellipse((140,163,180,169),fill=14)
 for x,y,c in [(105,145,11),(115,158,13),(209,144,14),(201,164,11)]:
  d.ellipse((x-5,y-9,x+5,y+5),fill=c);d.line((x,y+6,x-2,y+19),fill=7)
 d.rounded_rectangle((24,220,295,239),radius=5,fill=0,outline=11,width=2)
 for x in range(33,290,16):d.point((x,222),fill=15);d.point((x,237),fill=15)
 go='SPACE - LET THE SHOW BEGIN';pixfont.draw(im,(320-pixfont.width(go,7))//2,224,go,15,7)
 keys='S SOUND  D LEVEL  M MONO  H HELP  T TOP';pixfont.draw(im,(320-pixfont.width(keys))//2,241,keys,14)
 return im
def arena(act):
 im=new();d=ImageDraw.Draw(im)
 # Motion area stays dark. Dense scenery is kept outside the collision corridor.
 accent=[11,13,14,11,9,14,13,11,15][act]
 velvet=[1,5,1,5,1,4,5,1,1][act]
 # Top rim: tightly tiled bulbs, with balloon rows occupying the dark space below.
 d.line((0,0,319,0),fill=accent)
 for x in range(4,320,16):d.rectangle((x,1,x+2,2),fill=accent)
 # Draped valance beneath the balloon canopy.
 y=102 if act not in (5,8) else 116
 for x in range(0,320,40):
  d.pieslice((x-5,y-15,x+45,y+10),0,180,fill=velvet)
  d.arc((x-5,y-15,x+45,y+10),0,180,fill=accent,width=1)
  d.ellipse((x+18,y+5,x+21,y+8),fill=accent)
 # Side curtains are separated from travelling performers by a black guard band.
 curtain(d,True,y+6,217,16,velvet);curtain(d,False,y+6,217,16,velvet)
 d.line((16,y+6,16,216),fill=accent);d.line((303,y+6,303,216),fill=accent)
 # Discrete lamp beams and twinkles at the margins, never across the clown's face.
 for yy in range(y+18,207):
  reach=(yy-y-18)//5
  for xx in range(20,min(20+reach,35)):
   if (xx+yy)%4==0:im.putpixel((xx,yy),4);im.putpixel((319-xx,yy),4)
 for x,yy in [(25,144),(293,158),(35,187),(282,197)]:star(d,x,yy,6,2)
 # Each act owns scenery, not just a palette swap.
 if act in (1,7):
  for x in (24,280):
   for yy,c in ((179,13),(193,10),(207,11)):
    d.rectangle((x,yy,x+13,yy+10),fill=c)
    d.line((x+6,yy,x+6,yy+10),fill=0,width=2);d.line((x,yy+4,x+13,yy+4),fill=0)
 elif act==2:
  for x in (25,290):
   d.line((x,122,x+3,210),fill=2)
   for yy in range(132,208,13):d.ellipse((x-5,yy,x+5,yy+5),fill=10)
 elif act==4:
  for x in (28,286):
   d.rectangle((x,178,x+3,213),fill=8)
   d.polygon([(x-5,179),(x+1,156),(x+6,173),(x+5,181)],fill=9)
   d.polygon([(x-1,178),(x+1,165),(x+4,179)],fill=11)
 elif act==5:
  for x in (25,282):
   d.ellipse((x,203,x+13,216),outline=7,width=2)
   d.line((x+2,205,x+10,213),fill=7);d.line((x+10,205,x+2,213),fill=7)
   d.polygon([(x-1,201),(x+3,194),(x+17,199),(x+14,205)],fill=8)
 elif act==6:
  d.ellipse((270,143,291,165),fill=11);d.ellipse((276,139,296,160),fill=0)
  for x,yy in ((33,160),(277,180),(39,199)):star(d,x,yy,15,3)
 elif act==8:
  for x,yy in ((39,151),(279,151)):
   for dx,dy in ((0,1),(1,0),(1,1),(1,-1)):
    d.line((x-dx*10,yy-dy*10,x+dx*10,yy+dy*10),fill=11)
   d.ellipse((x-3,yy-3,x+3,yy+3),fill=0)
   star(d,x,yy,15,2)
 # Audience silhouettes, padded stage edge and individual footlights.
 for x in range(18,302,12):
  d.ellipse((x,214,x+5,219),fill=5 if act%2 else 4)
  d.arc((x-2,218,x+8,227),180,360,fill=8,width=2)
 d.rectangle((0,226,319,229),fill=velvet)
 d.line((0,225,319,225),fill=accent)
 for x in range(4,320,16):d.rectangle((x,226,x+3,228),fill=11)
 d.line((0,230,319,230),fill=accent)
 # HUD is black, with a lower gold rule.
 d.line((0,249,319,249),fill=accent)
 return im
def quantise_cell(im,x,y,title_scene=False):
 pixels=[im.getpixel((x+xx,y+yy)) for yy in range(10) for xx in range(8)]
 count=Counter(pixels); bg=count.most_common(1)[0][0]
 # Rare bright linework is deliberately favoured over broad dim shading.
 others=[c for c in count if c!=bg]
 fg=max(others,key=lambda c:count[c]*(1.3 if c in (11,14,15) else 1)) if others else bg
 if fg==bg:fg=15 if bg==0 else 0
 rows=[];mono=[]
 for yy in range(10):
  rb=mb=0
  for xx in range(8):
   p=pixels[yy*8+xx]
   dist=lambda c:sum((PAL[p][k]-PAL[c][k])**2 for k in range(3))
   use=fg if dist(fg)<dist(bg) else bg
   if use==fg:rb|=128>>xx
   tone=TONE[use]
   if title_scene and (25<=y<130 or y>=220) and use in (11,14,15):tone=16
   if tone>BAYER[(y+yy)%4][(x+xx)%4]:mb|=128>>xx
  rows.append(rb);mono.append(mb)
 return bytes(rows+[0]*6),bytes(mono+[0]*6),(bg<<4)|fg
def render_map(tiles,maps,mono=False):
 im=Image.new('RGB',(320,250));data=maps
 for cell in range(1000):
  idx=(data[1000+cell]&15)*128+(data[cell]&127);co=data[2000+cell]
  fg,bg=(15,0) if mono else (co&15,co>>4)
  x=cell%40*8;y=cell//40*10
  for yy in range(10):
   b=tiles[idx][yy]
   for xx in range(8):im.putpixel((x+xx,y+yy),PAL[fg if b&(128>>xx) else bg])
 return im
def encode_scene(im,base_colour,base_mono,title_scene=False,recycle=None):
 colour=list(base_colour);mono=list(base_mono)
 ids={(a,b):i for i,(a,b) in enumerate(zip(colour,mono))}
 maps=bytearray(3000)
 for cell in range(1000):
  c,m,co=quantise_cell(im,cell%40*8,cell//40*10,title_scene)
  key=(c,m)
  if key not in ids:
   if recycle:
    i=recycle.pop(0);ids[key]=i;colour[i]=c;mono[i]=m
   else:ids[key]=len(colour);colour.append(c);mono.append(m)
  i=ids[key];maps[cell]=128+(i&127);maps[1000+cell]=i//128;maps[2000+cell]=co
 assert len(colour)<=2048,('PCG overflow',len(colour))
 return colour,mono,maps
def make_banks(common_colour,common_mono,font_ids):
 B=R/'build';maps=[];stats=[]
 for act in range(9):
  c,m,mp=encode_scene(arena(act),common_colour,common_mono)
  for block,t in [(4+act*2,c),(5+act*2,m)]:
   (B/f'B{block:02}.DAT').write_bytes(b''.join(t).ljust(32768,b'\0'))
  maps.append(mp);stats.append({'act':act+1,'pcg_tiles':len(c)})
  if act in (0,6,8):
   render_map(c,mp).resize((960,750),Image.Resampling.NEAREST).save(B/f'arena-art-{act+1}.png')
   render_map(m,mp,True).resize((960,750),Image.Resampling.NEAREST).save(B/f'arena-mono-{act+1}.png')
 tc=[t if i in font_ids else bytes(16) for i,t in enumerate(common_colour)]
 tm=[t if i in font_ids else bytes(16) for i,t in enumerate(common_mono)]
 c,m,mp=encode_scene(title(),tc,tm,True,[i for i in range(1,len(tc)) if i not in font_ids])
 for block,t in [(22,c),(23,m)]: (B/f'B{block:02}.DAT').write_bytes(b''.join(t).ljust(32768,b'\0'))
 maps.append(mp)
 (B/'B24.DAT').write_bytes(b''.join(maps).ljust(32768,b'\0'))
 render_map(c,mp).resize((960,750),Image.Resampling.NEAREST).save(B/'spectacle-title-colour.png')
 render_map(m,mp,True).resize((960,750),Image.Resampling.NEAREST).save(B/'spectacle-title-mono.png')
 (B/'spectacle-stats.json').write_text(json.dumps({'banked_art_bytes':21*32768,'ram_blocks':list(range(4,25)),'game_scenes':stats,'title_pcg_tiles':len(c)},indent=2))
