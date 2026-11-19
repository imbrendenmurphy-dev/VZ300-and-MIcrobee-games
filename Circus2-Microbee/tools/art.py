"""Draw original native-resolution PCG artwork; no VZ artwork is read."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
sprites={}
def canvas(w,h):
 im=Image.new('1',(w,h));return im,ImageDraw.Draw(im)
def save(n,im,c=15):sprites[n]=(im,c)
def build():
 for n,c in [('BAL_Y',11),('BAL_B',14),('BAL_R',13),('BAL_GIFT1',10),('BAL_STEEL',7),('BAL_GOLD',11),('BAL_BOMB1',9)]:
  im,d=canvas(12,20)
  if 'BOMB' in n:
   d.ellipse((1,5,10,15),fill=1);d.line((7,5,8,2,11,2),fill=1);d.line((10,0,10,4),fill=1);d.point((3,8),fill=0)
  else:
   d.ellipse((0,0,10,14),fill=1);d.line((3,3,2,6),fill=0,width=1);d.polygon([(5,14),(3,16),(7,16)],fill=1);d.line((5,17,6,18,5,19),fill=1)
   if 'GIFT' in n:
    d.line((1,8,9,8),fill=0,width=2);d.line((5,1,5,13),fill=0,width=2)
   if 'STEEL' in n:
    d.rectangle((3,5,7,9),fill=0);d.line((4,7,6,7),fill=1)
   if 'GOLD' in n:d.polygon([(5,4),(6,7),(8,7),(6,9),(5,12),(4,9),(2,7),(4,7)],fill=0)
  save(n,im,c)
 for pose in ['UP','FALL1','FALL2','FLIP','SIT','SIT2','WAVE','SPLAT']:
  im,d=canvas(18,32 if 'SIT' not in pose else 26)
  if pose=='SPLAT':
   im,d=canvas(24,12);d.ellipse((5,4,18,10),fill=1);d.line((0,4,8,8,3,11),fill=1,width=2);d.line((23,4,16,8,21,11),fill=1,width=2)
  else:
   d.rectangle((6,1,11,4),fill=1);d.line((3,5,14,5),fill=1)
   d.ellipse((1,6,5,11),fill=1);d.ellipse((13,6,17,11),fill=1)
   d.ellipse((5,6,13,14),fill=1);d.point((7,8),fill=0);d.point((11,8),fill=0)
   d.ellipse((8,10,10,11),fill=0);d.line((7,12,11,12),fill=0)
   d.polygon([(6,15),(11,15),(13,23),(4,23)],fill=1);d.rectangle((8,17,9,18),fill=0);d.rectangle((8,21,9,22),fill=0)
   if pose=='UP':d.line((5,16,1,11,0,5),fill=1,width=2);d.line((12,16,16,11,17,5),fill=1,width=2)
   elif pose=='WAVE':d.line((5,16,1,21),fill=1,width=2);d.line((12,16,16,10,16,6),fill=1,width=2)
   else:d.line((5,16,1,18,0,14),fill=1,width=2);d.line((12,16,16,18,17,14),fill=1,width=2)
   if 'SIT' in pose:d.line((5,23,2,24,0,24),fill=1,width=2);d.line((12,23,15,24,17,24),fill=1,width=2)
   else:
    d.line((5,24,4,29,1,30),fill=1,width=3);d.line((12,24,13,29,16,30),fill=1,width=3)
   if pose=='FLIP':im=im.transpose(Image.Transpose.ROTATE_180)
  save('CL_'+pose,im,15)
 for wide in [False,True]:
  w=76 if wide else 52
  for side in ['L','R']:
   im,d=canvas(w,32);d.polygon([(w//2,18),(w//2-8,31),(w//2+8,31)],outline=1);d.line((w//2,21,w//2,29),fill=1)
   d.line((1,22,w-2,2) if side=='L' else (1,2,w-2,22),fill=1,width=3)
   save(('SEEW_' if wide else 'SEE_')+side,im,11)
 for phase in [1,2]:
  im,d=canvas(20,30);d.ellipse((4,3,15,14),fill=1);d.ellipse((1,6,5,10),fill=1);d.ellipse((14,6,18,10),fill=1);d.rectangle((7,7,12,10),fill=0);d.point((8,8),fill=1);d.point((11,8),fill=1)
  d.ellipse((6,15,13,24),fill=1);d.line((6,17,2,12,0,1),fill=1,width=2);d.line((13,17,18,12,19,1),fill=1,width=2);d.line((8,23,4,29),fill=1,width=2);d.line((11,23,16,28-phase),fill=1,width=2);save('MONKEY'+str(phase),im,11)
  im,d=canvas(40,24);d.ellipse((1,7,38,22),outline=1,width=2)
  for x in range(3+phase,38,6):d.polygon([(x,8),(x+1,0),(x+4,8)],fill=1)
  save('HOOP'+str(phase),im,9 if phase==1 else 11)
 im,d=canvas(24,20);d.pieslice((0,0,23,23),180,360,fill=1);d.line((12,9,12,18,9,19),fill=1);save('UMBRELLA',im,14)
 im,d=canvas(12,10);d.ellipse((1,0,10,5),fill=1);d.polygon([(0,5),(11,5),(9,9),(2,9)],outline=1);save('PIE',im,15)
 im,d=canvas(16,8);d.ellipse((1,2,14,6),fill=1);d.line((0,0,14,7),fill=1);save('PIE_SPLAT',im,15)
 im,d=canvas(10,10);d.polygon([(4,0),(5,3),(9,4),(6,6),(7,9),(4,7),(1,9),(2,6),(0,4),(3,3)],fill=1);save('STAR',im,11)
 im,d=canvas(3,3);d.line((0,1,2,1),fill=1);d.line((1,0,1,2),fill=1);save('SPARK',im,11)
 im,d=canvas(20,5)
 for x in range(0,20,4):d.line((x,0,x+3,4),fill=1);d.line((x,4,x+3,0),fill=1)
 save('NET',im,14)
 font=ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',10)
 im,d=canvas(12,20);save('BAL_ERASE',im,0)
 for n,ch,c in [('WIDE','W',10),('SLOW','S',14),('NET','N',14),('X2','2',13),('UMB','U',14),('FIRE','F',9),('1UP','1',11)]:
  im,d=canvas(16,18);d.rounded_rectangle((0,0,14,16),radius=3,outline=1);d.text((4,2),ch,font=font,fill=1);save('TOK_'+n+'1',im,c)
 import pixfont
 for c in range(32,127):
  im,d=canvas(6,9)
  if pixfont.has(chr(c)):pixfont.draw(im,0,1,chr(c))
  else:d.text((0,-2),chr(c).upper(),font=font,fill=1)
  save('FONT_'+str(c),im,15)
 bigfont=ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf',15)
 for c in range(32,91):
  # Centre each serif glyph in its 12px slot so narrow letters (I, J) don't leave lopsided gaps.
  im,d=canvas(12,18);b=d.textbbox((0,0),chr(c),font=bigfont);dx=max(0,(12-(b[2]-b[0]))//2)-b[0] if c!=32 else 0
  d.text((dx,-3),chr(c),font=bigfont,fill=1);save('FONT_BIG_'+str(c),im,11)
 im,d=canvas(208,40);f=ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',38);d.text((1,-5),'CIRCUS 2',font=f,fill=1,stroke_width=0);save('LOGO',im,11)
 im,d=canvas(112,64);d.polygon([(55,0),(4,26),(106,26)],outline=1,width=2)
 for x in [4,24,44,66,86,106]:d.line((55,0,x,26),fill=1,width=2)
 d.rectangle((9,27,102,62),outline=1,width=2);d.polygon([(44,62),(55,32),(67,62)],outline=1,width=2)
 for x in [20,32,77,89]:d.line((x,28,x,61),fill=1,width=3)
 d.line((55,0,55,5),fill=1);save('TENT',im,13)
 del sprites['LOGO'];del sprites['TENT']
 lines=['; Native cached PCG sprites: x phases 0,2,4,6; y phases 0,5.']
 tiles=[bytes(16)]; mono_tiles=[bytes(16)]; ids={(tiles[0],mono_tiles[0]):0};font_ids=set()
 def tile_id(data,monodata):
  data=bytes(data);monodata=bytes(monodata);key=(data,monodata)
  if key not in ids:ids[key]=len(tiles);tiles.append(data);mono_tiles.append(monodata)
  return ids[key]
 for n,(im,c) in sprites.items():
  phases=[(0,0)] if n.startswith('FONT_') or n in ('LOGO','TENT') else [(x,y) for y in [0,3,6] for x in [0,2,4,6]]
  lines += [n+':',' dw '+','.join(n+'_'+str(i if len(phases)>1 else 0) for i in range(1 if n.startswith('FONT_') else 12))]
  for phase,(dx,dy) in enumerate(phases):
   if dy==3 and (n.startswith('SEE') or n.startswith('HOOP') or n.startswith('BAL_')):dy=0
   w=(im.width+dx+7)//8;h=(im.height+dy+9)//10
   lines += [n+'_'+str(phase)+':',f' db {w},{h}']
   vals=[]
   for ty in range(h):
    for tx in range(w):
     rows=[];mrows=[]
     for yy in range(10):
      bits=0;mbits=0
      for xx in range(8):
       sx=tx*8+xx-dx;sy=ty*10+yy-dy
       if 0<=sx<im.width and 0<=sy<im.height and im.getpixel((sx,sy)):
        bits|=128>>xx
        edge=any(not (0<=sx+ax<im.width and 0<=sy+ay<im.height) or not im.getpixel((sx+ax,sy+ay)) for ax,ay in ((1,0),(-1,0),(0,1),(0,-1)))
        density=16
        if n=='BAL_B':density=11
        if n=='BAL_R':density=7
        if n.startswith('CL_') and 15<=sy<24:density=10
        if edge or density>((0,8,2,10),(12,4,14,6),(3,11,1,9),(15,7,13,5))[sy%4][sx%4]:mbits|=128>>xx
      rows.append(bits);mrows.append(mbits)
     idx=tile_id(rows+[0]*6,mrows+[0]*6)
     if n.startswith('FONT_'):font_ids.add(idx)
     colour=c
     if n.startswith('CL_'):
      sy=ty*10+5-dy
      colour=15 if sy<15 else (9 if sy<24 else 14)
     if n.startswith('HOOP'):colour=11 if ty*10+5-dy<8 else 9
     if n=='TENT':colour=11 if ty<3 else 13
     vals += [128+(idx&127),idx//128,colour]
   for i in range(0,len(vals),96):lines += [' db '+','.join(map(str,vals[i:i+96]))]
 lines+=['font_ptrs:',' dw '+','.join('FONT_'+str(c) for c in range(32,127))]
 lines+=['bigfont_ptrs:',' dw '+','.join('FONT_BIG_'+str(c) for c in range(32,91))]
 import math,json
 lines+=['sintab:',' db '+','.join(str(round(math.sin(i*math.pi/16)*2)&255) for i in range(32))]
 banks=(len(tiles)+127)//128
 assert banks<=16,len(tiles)
 lines += ['PCG_BANKS EQU '+str(banks)]
 (R/'build/art-stats.json').write_text(json.dumps({'unique_tiles':len(tiles),'pcg_banks':banks,'pcg_bytes':banks*2048}))
 import spectacle
 spectacle.make_banks(tiles,mono_tiles,font_ids)
 (R/'src/art.inc').write_text('\n'.join(lines)+'\n')
if __name__=='__main__':build()
