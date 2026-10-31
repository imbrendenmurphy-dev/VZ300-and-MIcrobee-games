import sys
sys.path.insert(0,'.')
from art import SPR
from PIL import Image
C0=[(0x30,0xd0,0x30),(0xe0,0xe0,0x40),(0x30,0x30,0xd0),(0xd0,0x30,0x30)]
C1=[(0xe0,0xe0,0xd0),(0x40,0xd0,0xd0),(0xd0,0x40,0xd0),(0xf0,0x90,0x20)]
def sheet(pal,space,mp,fn):
    W=200; x=2;y=2;rowh=0
    im=Image.new('RGB',(W,140),pal[space]); px=im.load()
    for n,rows in SPR.items():
        w=max(len(r) for r in rows); h=len(rows)
        if x+w>W-2: x=2; y+=rowh+3; rowh=0
        for j,r in enumerate(rows):
            for i,c in enumerate(r):
                if c!='.': px[x+i,y+j]=pal[mp[int(c)]]
        x+=w+3; rowh=max(rowh,h)
    im=im.resize((W*4,140*6),Image.NEAREST); im.save(fn)
sheet(C0,2,[2,1,3,0],'./spr0.png')
