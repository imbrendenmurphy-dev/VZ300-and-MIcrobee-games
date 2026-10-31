import sys
from PIL import Image, ImageDraw, ImageFont
C0=[(0x30,0xd0,0x30),(0xe0,0xe0,0x40),(0x30,0x30,0xd0),(0xd0,0x30,0x30)]
C1=[(0xe0,0xe0,0xd0),(0x40,0xd0,0xd0),(0xd0,0x40,0xd0),(0xf0,0x90,0x20)]
SEMI=[(0x30,0xd0,0x30),(0xe0,0xe0,0x40),(0x30,0x30,0xd0),(0xd0,0x30,0x30),(0xe0,0xe0,0xd0),(0x40,0xd0,0xd0),(0xd0,0x40,0xd0),(0xf0,0x90,0x20)]
def render(d):
    v=d[:2048]; latch=d[2048]
    if latch&8:
        pal=C1 if latch&16 else C0
        im=Image.new('RGB',(128,64))
        px=im.load()
        for y in range(64):
            for xb in range(32):
                b=v[y*32+xb]
                for k in range(4): px[xb*4+k,y]=pal[(b>>(6-2*k))&3]
        return im.resize((512,288),Image.NEAREST)
    im=Image.new('RGB',(256,192),(0,0,0)); dr=ImageDraw.Draw(im); px=im.load()
    fg=(0x30,0xd0,0x30) if not latch&16 else (0xf0,0x90,0x20); dk=(0,0x40,0) if not latch&16 else (0x40,0x20,0)
    for r in range(16):
        for c in range(32):
            b=v[r*32+c]
            if b&0x80:
                col=SEMI[(b>>4)&7]
                for q in range(4):
                    on=b&(8>>q)
                    x0=c*8+(q&1)*4; y0=r*12+(q>>1)*6
                    dr.rectangle([x0,y0,x0+3,y0+5],fill=col if on else (0,0,0))
            else:
                inv=b&0x40; code=b&0x3f
                ch=chr(code+64) if code<32 else chr(code)
                bg=fg if inv else dk; f=dk if inv else fg
                dr.rectangle([c*8,r*12,c*8+7,r*12+11],fill=bg)
                dr.text((c*8+1,r*12+1),ch,fill=f)
    return im.resize((512,384),Image.NEAREST)
if __name__=='__main__':
    ims=[render(open(f,'rb').read()) for f in sys.argv[2:]]
    W=max(i.size[0] for i in ims); H=sum(i.size[1] for i in ims)
    if len(ims)>1:
        cols=2; rows=(len(ims)+1)//2
        out=Image.new('RGB',(W*cols,max(i.size[1] for i in ims)*rows))
        for k,i in enumerate(ims): out.paste(i,((k%cols)*W,(k//cols)*max(j.size[1] for j in ims)))
    else: out=ims[0]
    out.save(sys.argv[1])
