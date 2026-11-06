import sys; sys.path.insert(0,'.')
from art import *
from PIL import Image
PAL={'g':(40,224,40),'y':(240,240,80),'b':(40,40,200),'r':(220,40,40),'.':(60,60,60)}
def img(grid, sx=4, sy=6):
    h=len(grid); w=len(grid[0])
    im=Image.new('RGB',(w*sx,h*sy))
    for y,row in enumerate(grid):
        for x,c in enumerate(row):
            for yy in range(sy):
                for xx in range(sx): im.putpixel((x*sx+xx,y*sy+yy),PAL.get(c,(255,0,255)))
    return im
def hero(fr, lv):
    t=ARMOUR_LEVELS[lv]; out=[]
    for b,a in fr:
        row=''
        for x in range(12):
            ac=a[x]; c=None
            if ac!='.' and t.get(ac): c=t[ac]
            if ac=='K' and b[x]!='.': c=None if not t.get('K') else None
            if c is None: c=BODY_COL[b[x]] or ('r' if (ac=='K' and t.get('K')) else '.')
            row+=c
        out.append(row)
    return out
W=Image.new('RGB',(900,700),(30,30,30))
x=0
for lv in range(6):
    for i,f in enumerate(HERO_FRAMES):
        W.paste(img(hero(f,lv),3,5),(i*40,lv*85))
y=520; x=0
for n,fs in SPRITES.items():
    if n in('bskull','bjaw'): continue
    for f in fs:
        im=img(f,3,5)
        if x+im.width>900: x=0; y+=90
        W.paste(im,(x,y)); x+=im.width+6
W.save('/tmp/claude-0/prev.png')
T=Image.new('RGB',(len(TILE_ORDER)*36,60),(0,0,0))
for i,n in enumerate(TILE_ORDER): T.paste(img(TILES[n],4,6),(i*36,0))
T.save('/tmp/claude-0/tiles.png')
