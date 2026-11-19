# Minimal MZ-700 machine model for testing: RAM, VRAM, 8255 keyboard + VBLANK, PNG screenshots.
from z80 import Z80
from PIL import Image, ImageDraw, ImageFont
FIELD=70938            # T-states per 50Hz field at 3.546895 MHz
LINES=312
PAL=[(0,0,0),(0,0,255),(255,0,0),(255,0,255),(0,255,0),(0,255,255),(255,255,0),(255,255,255)]
# key matrix per row: dict name->bit  (MAME mz700 layout)
KEYS={'up':(7,5),'down':(7,4),'right':(7,3),'left':(7,2),'1':(5,7),'2':(5,6),'3':(5,5),'4':(5,4),'B':(4,6),
      'W':(2,1),'S':(2,5),'Q':(2,7),'A':(4,7),'D':(4,4),'E':(4,3),'M':(3,3),'SPACE':(6,3)}
class MZ:
    def __init__(s,load,data,exe):
        s.mem=bytearray(65536)
        s.mem[load:load+len(data)]=data
        s.row=0; s.held=set()
        s.cpu=Z80(s.rd,s.wr); s.cpu.pc=exe
    def rd(s,a):
        if 0xE000<=a<=0xE00F:
            if a==0xE001:
                v=0xFF
                for k in s.held:
                    r,b=KEYS[k]
                    if r==s.row: v&=~(1<<b)
                return v
            if a==0xE002:
                line=(s.cpu.t%FIELD)*LINES//FIELD
                return 0x7F if line>=200 else 0xFF
            return 0xFF
        return s.mem[a]
    def wr(s,a,v):
        if a<0x1000: return
        if 0xE000<=a<=0xE00F:
            if a==0xE000: s.row=v&0x0F
            return
        s.mem[a]=v
    def run_t(s,tt):
        c=s.cpu; end=c.t+tt
        while c.t<end: c.step()
    def run_until(s,pc,maxt=10**9):
        c=s.cpu; end=c.t+maxt
        while c.pc!=pc and c.t<end: c.step()
        return c.pc==pc
    def shot(s,fn,scale=3):
        im=Image.new('RGB',(320,200)); dr=ImageDraw.Draw(im)
        try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',9)
        except: font=ImageFont.load_default()
        for r in range(25):
            for c in range(40):
                ch=s.mem[0xD000+r*40+c]; at=s.mem[0xD800+r*40+c]
                fg=PAL[(at>>4)&7]; bg=PAL[at&7]
                dr.rectangle([c*8,r*8,c*8+7,r*8+7],fill=bg)
                t=None
                if 1<=ch<=26: t=chr(64+ch)
                elif 0x20<=ch<=0x29: t=chr(48+ch-0x20)
                elif ch==0x2E: t='.'
                elif ch!=0: t='?'
                if t: dr.text((c*8+1,r*8-1),t,fill=fg,font=font)
        im.resize((320*scale,200*scale),Image.NEAREST).save(fn)
