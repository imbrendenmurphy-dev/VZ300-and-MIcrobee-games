# Minimal MZ-700 machine model for testing: RAM, VRAM, 8255 keyboard + VBLANK, PNG screenshots.
from z80 import Z80
from PIL import Image, ImageDraw, ImageFont
FIELD=70938            # T-states per 50Hz field at 3.546895 MHz
LINES=312
PAL=[(0,0,0),(0,0,255),(255,0,0),(255,0,255),(0,255,0),(0,255,255),(255,255,0),(255,255,255)]
# key matrix per row: dict name->bit  (MAME mz700 layout)
KEYS={'up':(7,5),'down':(7,4),'right':(7,3),'left':(7,2),'1':(5,7),'2':(5,6),'3':(5,5),'4':(5,4),'B':(4,6),
      'W':(2,1),'S':(2,5),'Q':(2,7),'A':(4,7),'D':(4,4),'E':(4,3),'M':(3,3),'SPACE':(6,4),'0':(6,3)}
class MZ:
    def __init__(s,load,data,exe):
        s.mem=bytearray(65536)
        s.mem[load:load+len(data)]=data
        s.row=0; s.held=set(); s.snd=[]
        # optional VRAM contention: extra T-states per write to D000-DFFF (MZ_VRAMWAIT env var).
        # 72 reproduces the Win32 emulator's benchmark results (76/85/125/134 fields) closely.
        import os; s.vwait=int(os.environ.get('MZ_VRAMWAIT','0'))
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
        if s.vwait and 0xD000<=a<0xE000: s.cpu.t+=s.vwait
        if 0xE000<=a<=0xE00F:
            if a==0xE000: s.row=v&0x0F
            if a in (0xE004,0xE007,0xE008): s.snd.append((s.cpu.t,a,v))
            return
        s.mem[a]=v
    def wav(s,fn,t0,t1,clk=894886,rate=22050):
        """Render the 8253 counter 0 square wave (gated by E008 bit 0) between T-states t0 and t1."""
        import wave,struct
        cpu_hz=3546895; ev=[e for e in s.snd if e[0]<t1]; i=0
        count=0; lo=None; gate=0; phase=0.0; out=bytearray()
        for n in range(int((t1-t0)*rate/cpu_hz)):
            t=t0+n*cpu_hz/rate
            while i<len(ev) and ev[i][0]<=t:
                _,a,v=ev[i]; i+=1
                if a==0xE007: lo=None
                elif a==0xE004:
                    if lo is None: lo=v
                    else: count=lo|v<<8; lo=None
                elif a==0xE008: gate=v&1
            if gate and count:
                phase=(phase+clk/count/rate)%1.0
                out+=struct.pack('<h',6000 if phase<0.5 else -6000)
            else: out+=struct.pack('<h',0)
        w=wave.open(fn,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(bytes(out)); w.close()
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
