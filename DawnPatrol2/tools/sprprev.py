import sys; sys.path.insert(0,'.')
from art import *
from PIL import Image
PAL=[(0x07,0xff,0x00),(0xff,0xff,0x00),(0x3b,0x08,0xff),(0xcc,0x00,0x3b)]
S=10
x=4; ims=[]
W=sum(len(g[0])+2 for n,g in SPRITES)
im=Image.new("RGB",(900,600),(40,40,40))
x=4;y=4;rowh=0
for n,g in SPRITES:
    w=len(g[0]);h=len(g)
    if x+w*S>890: x=4;y+=rowh+6;rowh=0
    for j,r in enumerate(g):
        for i,c in enumerate(r):
            col=(0x3b,0x08,0xff) if c is None else PAL[c]
            for a in range(S-1):
                for b in range(S-1): im.putpixel((x+i*S+a,y+j*S+b),col if c is not None else (60,60,110))
    x+=w*S+8; rowh=max(rowh,h*S)
im.save('/home/claude/dp2/test/sprites.png')
