"""Stone/marble Roman capitals for the EMPIRES title: 32 x 33 px per letter."""
from PIL import Image, ImageDraw, ImageFont
import math, random
FONT='/usr/share/texmf/fonts/opentype/public/lm/lmroman10-bold.otf'
def letter_bitmap(ch, W=32, H=33, cap=31):
    f=ImageFont.truetype(FONT, 46)
    big=Image.new('L',(120,120),0); d=ImageDraw.Draw(big)
    d.text((20,10),ch,font=f,fill=255)
    bb=big.getbbox(); g=big.crop(bb)
    # scale to cap height, keep aspect but squeeze wide letters into W
    w,h=g.size; s=cap/h; nw=min(W,max(1,round(w*s*1.05)))
    g=g.resize((nw,cap),Image.LANCZOS)
    out=Image.new('L',(W,H),0); out.paste(g,((W-nw)//2,1))
    return [[1 if out.getpixel((x,y))>110 else 0 for x in range(W)] for y in range(H)]
def marble(bm, seed):
    r=random.Random(seed); H=len(bm); W=len(bm[0])
    # two or three thin veins: wandering diagonal curves
    for v in range(3):
        x=r.uniform(-8,W); y=0.0; ang=r.uniform(0.5,1.2); 
        while y<H and -10<x<W+10:
            xi,yi=int(x),int(y)
            if 0<=xi<W and 0<=yi<H and bm[yi][xi]:
                # keep strokes readable: only cut where the stroke is at least 3 px wide
                if sum(bm[yi][max(0,xi-2):xi+3])>=4: bm[yi][xi]=0
            ang+=r.uniform(-0.35,0.35); ang=max(0.25,min(1.35,ang))
            x+=math.cos(ang)*0.9; y+=math.sin(ang)*0.9
    return bm
if __name__=='__main__':
    letters='EMPIRES'
    img=Image.new('RGB',(len(letters)*32+16,33+16),(96,96,96))
    for i,c in enumerate(letters):
        bm=marble(letter_bitmap(c),i*7+3)
        for y in range(33):
            for x in range(32):
                if bm[y][x]:
                    col=(255,255,255) if y<22 else (192,192,192)
                    img.putpixel((8+i*32+x,8+y),col)
    img.resize((img.width*4,int(img.height*4*1.82)),Image.NEAREST).save('/tmp/claude-0/-home-claude/97c433ef-8583-5a3b-b9a5-87fe5cdaf6a6/scratchpad/title_proto.png')
