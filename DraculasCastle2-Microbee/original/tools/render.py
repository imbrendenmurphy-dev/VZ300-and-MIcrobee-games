# render VRAM dumps (2048 bytes + latch) to PNG
import sys
from PIL import Image, ImageDraw, ImageFont
PAL=[(7,255,0),(255,255,0),(59,8,255),(204,0,59),(255,255,255),(7,227,153),(255,28,255),(255,129,0)]
def render(data, scale=4):
    vram=data[:2048]; latch=data[2048] if len(data)>2048 else 8
    css=(latch>>4)&1
    if latch&8:
        img=Image.new('RGB',(128,64))
        px=img.load()
        for y in range(64):
            for xb in range(32):
                b=vram[y*32+xb]
                for i in range(4):
                    px[xb*4+i,y]=PAL[css*4+((b>>(6-2*i))&3)]
        return img.resize((128*scale,64*scale*3//2),Image.NEAREST)
    img=Image.new('RGB',(256,192)); d=ImageDraw.Draw(img); f=ImageFont.load_default()
    fg=(0,64,0) if not css else (128,40,0); bg=(7,255,0) if not css else (255,129,0)
    for k in range(512):
        c=vram[k]; x=(k%32)*8; y=(k//32)*12
        if c&128:
            col=PAL[(c>>4)&7]
            for qi,(bx,by) in enumerate([(0,0),(4,0),(0,6),(4,6)]):
                d.rectangle([x+bx,y+by,x+bx+3,y+by+5],fill=col if c&(8>>qi) else (0,0,0))
        else:
            inv=c&64; ch=c&63; ch=ch+64 if ch<32 else ch
            d.rectangle([x,y,x+7,y+11],fill=fg if inv else bg)
            if ch!=32: d.text((x+1,y),chr(ch),fill=bg if inv else fg,font=f)
    return img.resize((256*scale//2,192*scale//2),Image.NEAREST)
if __name__=='__main__':
    for fn in sys.argv[1:]:
        render(open(fn,'rb').read()).save(fn.replace('.bin','.png'))
