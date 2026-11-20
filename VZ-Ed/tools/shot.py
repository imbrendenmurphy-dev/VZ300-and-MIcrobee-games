from PIL import Image
import vzrender
COL=[(7,255,0),(255,255,0),(59,8,255),(204,0,59)]
def gfx(vram,scale=3,border=16):
    W,H=256+2*border,192+2*border
    im=Image.new('RGB',(W,H),(0,0,0)); px=im.load()
    for y in range(64):
        for xb in range(32):
            b=vram[y*32+xb]
            for p in range(4):
                c=COL[(b>>(6-2*p))&3]
                for dy in range(3):
                    for dx in range(2): px[border+(xb*4+p)*2+dx,border+y*3+dy]=c
    return im.resize((W*scale,H*scale),Image.NEAREST)
def save(m,path):
    vram=bytes(m.z.mem[0x7000:0x7800])
    im=gfx(vram) if m.latch&8 else vzrender.render(vram)
    im.save(path); return path
