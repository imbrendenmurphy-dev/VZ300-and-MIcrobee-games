import sys; sys.path.insert(0,'.')
import importlib, tiles; importlib.reload(tiles)
from PIL import Image
C0=[(0x30,0x30,0xd0),(0xe0,0xe0,0x40),(0xd0,0x30,0x30),(0x30,0xd0,0x30)]   # space,a,b,c for CSS0 (T=2,a=1,b=3,c=0)
C1=[(0xd0,0x40,0xd0),(0x40,0xd0,0xd0),(0xf0,0x90,0x20),(0xe0,0xe0,0xd0)]
cm={' ':0,'a':1,'b':2,'c':3}
ths=['hull','flesh','rock','cryst','ship']
im=Image.new('RGB',(64*2+8,len(ths)*(32+4)))
px=im.load()
for i,th in enumerate(ths):
    t=tiles.TEX[th]
    for p,pal in enumerate((C0,C1)):
        for y in range(32):
            for x in range(64):
                px[p*72+x,i*36+y]=pal[cm[t[y%16][x%16]]]
im.resize((im.size[0]*4,im.size[1]*6),Image.NEAREST).save('texprev.png')
