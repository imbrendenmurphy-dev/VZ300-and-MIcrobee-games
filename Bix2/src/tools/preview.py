from PIL import Image
import art
PAL={'g':(0x30,0xd0,0x30),'.':(0x30,0xd0,0x30),'y':(0xf0,0xf0,0x50),'b':(0x30,0x40,0xd8),'r':(0xd8,0x30,0x30)}
def chk(name,rows,w,h):
    assert len(rows)==h,(name,len(rows))
    for r in rows: assert len(r)==w,(name,r)
for k,v in art.BIX.items(): chk(k,v,8,10)
for k,v in art.ENEMY.items(): chk(k,v,8,8)
for n,v,a in art.TILES: chk(n,v,8,8)
S=6
img=Image.new('RGB',(16*12*S,  10*S*2+40*S),(40,40,40))
def blit(rows,x,y,sky=True,scale=S):
    for j,r in enumerate(rows):
        for i,c in enumerate(r):
            col=PAL['b'] if (c=='.' and sky) else PAL[c]
            for a in range(scale):
                for b in range(scale): img.putpixel((x+i*scale+a,y+j*scale+b),col)
for i,k in enumerate(art.BIX_ORDER): blit(art.BIX[k],i*12*S,0)
for i,k in enumerate(art.ENEMY_ORDER): blit(art.ENEMY[k],i*12*S,12*S)
for i,(n,v,a) in enumerate(art.TILES): blit(v,(i%24)*8*S,24*S+(i//24)*8*S)
img.save('/home/claude/bix/sheet.png')
# native scale strip of bix on sky
im2=Image.new('RGB',(16*12,12),PAL['b'])
for i,k in enumerate(art.BIX_ORDER):
    for j,r in enumerate(art.BIX[k]):
        for x,c in enumerate(r):
            if c!='.': im2.putpixel((i*12+x,1+j),PAL[c])
im2.resize((16*12*3,36),Image.NEAREST).save('/home/claude/bix/native.png')
