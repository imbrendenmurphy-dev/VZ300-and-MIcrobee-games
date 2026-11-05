# render VZ screen dumps (latch byte + 2048 bytes VRAM) to PNG
# Mode 1 (CG2 128x64 4-colour) or Mode 0 (text 32x16 / SG4 semigraphics)
import sys, glob, os
from PIL import Image, ImageDraw, ImageFont
GREEN=(0x30,0xD2,0x00); YELLOW=(0xF5,0xF5,0x80); BLUE=(0x4C,0x3A,0xB4); RED=(0x9A,0x32,0x36)
BUFF=(0xD8,0xD8,0xD8); CYAN=(0x41,0xAF,0x71); MAGENTA=(0xD8,0x6E,0xF0); ORANGE=(0xD4,0x7F,0x00)
DKGREEN=(0x00,0x40,0x00); DKORANGE=(0x60,0x20,0x00); BLACK=(0x08,0x08,0x08)
SG=[GREEN,YELLOW,BLUE,RED,BUFF,CYAN,MAGENTA,ORANGE]
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',11)
CH='@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ !"#$%&\'()*+,-./0123456789:;<=>?'
def render(path, scale=4):
    d=open(path,'rb').read(); latch=d[0]; v=d[1:]
    css=(latch>>4)&1
    if latch & 8:
        pal=[GREEN,YELLOW,BLUE,RED] if css==0 else [BUFF,CYAN,MAGENTA,ORANGE]
        im=Image.new('RGB',(128,64))
        px=im.load()
        for y in range(64):
            for xb in range(32):
                b=v[y*32+xb]
                for k in range(4):
                    px[xb*4+k,y]=pal[(b>>(6-2*k))&3]
        im=im.resize((128*scale//2*2*1,64*scale*3//2*1), Image.NEAREST)  # approx 4:3 aspect
        return im
    im=Image.new('RGB',(256,192),BLACK); dr=ImageDraw.Draw(im)
    for r in range(16):
        for c in range(32):
            b=v[r*32+c]; x=c*8; y=r*12
            if b&0x80:
                col=SG[(b>>4)&7]
                for q,(qx,qy) in enumerate([(4,6),(0,6),(4,0),(0,0)]):
                    dr.rectangle([x+qx,y+qy,x+qx+3,y+qy+5],fill=col if b&(1<<q) else BLACK)
            else:
                inv=b&0x40; fg,bg=(DKGREEN,GREEN) if not inv else (GREEN,DKGREEN)
                if css: fg,bg=(DKORANGE,ORANGE) if not inv else (ORANGE,DKORANGE)
                dr.rectangle([x,y,x+7,y+11],fill=bg)
                dr.text((x+1,y),CH[b&63],fill=fg,font=font)
    return im.resize((512,384),Image.NEAREST)
if __name__=='__main__':
    for p in sys.argv[1:]:
        for f in sorted(glob.glob(p)):
            render(f).save(f[:-4]+'.png')
