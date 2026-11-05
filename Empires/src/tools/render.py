#!/usr/bin/env python3
"""render.py - turn a beeemu screen dump into a PNG as the Premium would display it.
usage: render.py dump.bin out.png [amber]
Dump layout: vram[2048] aram[2048] cram[2048] pcg[16][2048] crtc[32] p1c p08
Characters < 0x80 use an approximation of the character ROM (PIL bitmap font)."""
import sys
from PIL import Image, ImageDraw, ImageFont

PAL=[]
for i in range(16):
    if i==8: PAL.append((96,96,96)); continue
    lv=0xFF if i>=8 else 0xC0
    PAL.append(((lv if i&1 else 0),(lv if i&2 else 0),(lv if i&4 else 0)))
PAL[7]=(0xC0,0xC0,0xC0)

_font=None
def romfont():
    global _font
    if _font: return _font
    f=ImageFont.load_default()
    glyphs={}
    for c in range(32,127):
        im=Image.new('1',(8,11),0); d=ImageDraw.Draw(im)
        d.text((1,0),chr(c),fill=1,font=f)
        rows=[]
        for y in range(11):
            v=0
            for x in range(8): v=(v<<1)|(1 if im.getpixel((x,y)) else 0)
            rows.append(v)
        glyphs[c]=rows
    _font=glyphs; return glyphs

def render(dump, amber=False, cols=80, rows=24, chh=11):
    vram=dump[0:2048]; aram=dump[2048:4096]; cram=dump[4096:6144]
    pcg=[dump[6144+i*2048:6144+(i+1)*2048] for i in range(16)]
    font=romfont()
    W=cols*8; H=rows*chh
    im=Image.new('RGB',(W,H))
    px=im.load()
    for r in range(rows):
        for c in range(cols):
            a=r*cols+c
            ch=vram[a]; at=aram[a]; col=cram[a]
            fg=PAL[col&15]; bg=PAL[col>>4]
            if amber:
                def am(c):
                    l=(0.3*c[0]+0.59*c[1]+0.11*c[2])/255
                    return (int(20+235*l),int(10+166*l),int(0))
                fg=am(fg); bg=am(bg)
            inv=bool(at&0x40)
            for y in range(chh):
                if ch>=0x80:
                    bank=at&15
                    bits=pcg[bank][((ch&0x7f)<<4)|y]
                else:
                    bits=font.get(ch,[0]*11)[y] if ch>=32 else 0
                if inv: bits^=0xff
                for x in range(8):
                    px[c*8+x,r*chh+y]= fg if bits&(0x80>>x) else bg
    return im.resize((W, int(H*1.82)), Image.NEAREST)

if __name__=='__main__':
    d=open(sys.argv[1],'rb').read()
    am=len(sys.argv)>3 and sys.argv[3]=='amber'
    render(d,am).save(sys.argv[2])
    print('wrote',sys.argv[2])
