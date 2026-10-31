import sys; sys.path.insert(0,'.')
from levels import *
from PIL import Image
C0=[(0x30,0xd0,0x30),(0xe0,0xe0,0x40),(0x30,0x30,0xd0),(0xd0,0x30,0x30)]
C1=[(0xe0,0xe0,0xd0),(0x40,0xd0,0xd0),(0xd0,0x40,0xd0),(0xf0,0x90,0x20)]
PAL=[(C0,[2,1,3,0]),(C1,[2,1,3,0])]
LV=make_levels()
li=int(sys.argv[1]); x0=int(sys.argv[2]); ncol=int(sys.argv[3])
L=LV[li]; T=tileset(L.theme); pal,mp=PAL[li&1]
im=Image.new('RGB',(ncol*4,56)); px=im.load()
cm={' ':0,'a':1,'b':2,'c':3}
for x in range(ncol):
    col=L.grid[x0+x]
    for ty in range(14):
        t=T[col[ty]]
        for yy in range(4):
            for xx in range(4):
                px[x*4+xx,ty*4+yy]=pal[mp[cm[t[yy][xx]]]]
im.resize((ncol*4*3,56*3*3//2),Image.NEAREST).save(sys.argv[4])
uniq=set(tuple(c) for c in L.grid); print('level',li,'cols',len(L.grid),'unique',len(uniq),'spawns',len(L.spawns))
