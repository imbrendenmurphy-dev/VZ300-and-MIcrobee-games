import sys
from PIL import Image
sym={l.split()[1]:int(l.split()[0],16) for l in open('build/empires.sym')}
m=open(sys.argv[1],'rb').read(); T=sym['TERR']; O=sym['OBJ']; W=112
col={0:(0,0,150),1:(60,100,255),2:(120,200,255),3:(240,230,120),4:(60,170,60),5:(120,200,60),6:(20,110,20),7:(0,70,0),8:(150,140,60),9:(120,120,120),10:(250,250,250),11:(220,190,80),12:(70,140,120),13:(200,180,40),14:(90,90,90),15:(200,0,200)}
im=Image.new('RGB',(W,W))
for y in range(W):
  for x in range(W):
    t=m[T+y*W+x]; o=m[O+y*W+x]
    c=col[t&15]
    if o: c=(255,0,0) if o!=1 else (255,255,0)
    if not t&0x80: c=tuple(v//2 for v in c)
    im.putpixel((x,y),c)
im.resize((W*4,W*4),Image.NEAREST).save(sys.argv[2])
