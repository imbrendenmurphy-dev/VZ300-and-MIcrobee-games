import sys; sys.path.insert(0,'.')
from sprites import S, COMMON, STAGE1
from vzpal import CSS0
from PIL import Image
names = COMMON + STAGE1
W=200; rows=[]; x=y=0; rowh=0; place=[]
for n in names:
    for f in S[n][0]:
        w=len(f[0]); h=len(f)
        if x+w+2>W: x=0; y+=rowh+3; rowh=0
        place.append((x,y,f)); x+=w+3; rowh=max(rowh,h)
H=y+rowh+2
im=Image.new('RGB',(W,H),(40,40,90))
for x,y,f in place:
    for r,row in enumerate(f):
        for c,v in enumerate(row):
            if v>=0: im.putpixel((x+c,y+r),CSS0[v])
im=im.resize((W*6,H*9),Image.NEAREST); im.save(sys.argv[1])
