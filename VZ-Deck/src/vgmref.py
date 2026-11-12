import struct
CLK=3579545
def mk_vgm(seconds=6):
    d=bytearray()
    def tone(ch,per): d.extend([0x50,0x80|(ch<<5)|(per&15),0x50,(per>>4)&63])
    def vol(ch,a): d.extend([0x50,0x90|(ch<<5)|a])
    def wait(n):
        while n>0:
            if n==735: d.append(0x62); n=0
            elif n==882: d.append(0x63); n=0
            elif n<=16: d.append(0x70+n-1); n=0
            else:
                k=min(n,65535); d.extend([0x61,k&255,k>>8]); n-=k
    f=lambda hz: int(round(CLK/(32*hz)))
    notes=[261.6,329.6,392,523.3,392,329.6]
    for ch in range(4): vol(ch,15)
    d.extend([0x4F,0xFF, 0x52,0x28,0x00, 0x67,0x66,0x00,4,0,0,0,1,2,3,4])   # other chips + data block
    t=0; i=0
    while t<seconds*44100:
        tone(0,f(notes[i%6])); vol(0,2)
        tone(1,f(notes[i%6]/2)); vol(1,4)
        if i%2==0:
            d.extend([0x50,0xE0|0x04|(i//2%3)]); vol(3,3)
        if i%3==0: tone(2,f(notes[(i+2)%6]*1.5)); vol(2,6)
        wait(735)
        vol(3,15); wait(5000-735)
        d.extend([0x50,0x80|(1<<5)|1])       # change only the low nibble of channel 1 (no data byte)
        wait(2000)
        if i%4==3: vol(2,15)
        wait(11)
        t+=735+4265+2000+11; i+=1
    d.append(0x66)
    gd3s=['VZ-DECK VGM TEST','','SN76489 Demo','','','','','','','','']
    g=b''.join(s.encode('utf-16-le')+b'\0\0' for s in gd3s)
    gd3=b'Gd3 '+struct.pack('<II',0x100,len(g))+g
    hdr=bytearray(0x80); hdr[0:4]=b'Vgm '; struct.pack_into('<I',hdr,8,0x150); struct.pack_into('<I',hdr,0x0C,CLK)
    struct.pack_into('<I',hdr,0x34,0x80-0x34)
    body=hdr+d; struct.pack_into('<I',body,0x14,len(body)-0x14); body+=gd3; struct.pack_into('<I',body,4,len(body)-4)
    return bytes(body)
class VGM:
    def __init__(s,d):
        s.d=d; ver=struct.unpack('<I',d[8:12])[0]; clk=struct.unpack('<I',d[12:16])[0]&0x3FFFFFFF
        s.k=3546800//(clk>>8) if False else None
        ch=(clk>>8)&0xFFFF; s.kscale=(0x361EB0)//ch
        s.pos=0x40
        if ver>=0x150:
            o=struct.unpack('<I',d[0x34:0x38])[0]
            if o: s.pos=0x34+o
        s.att=[15]*4; s.per=[0]*3; s.latch=0; s.wait=0; s.ended=False
    def getb(s):
        if s.pos>=len(s.d): s.ended=True; return 0x66
        b=s.d[s.pos]; s.pos+=1; return b
    def write(s,b):
        if b&0x80:
            s.latch=(b>>4)&7; c=b&15; ch=s.latch>>1
            if s.latch&1: s.att[ch]=c
            elif ch<3: s.per[ch]=(s.per[ch]&0x3F0)|c
        else:
            ch=s.latch>>1
            if s.latch&1: s.att[ch]=b&15
            elif ch<3: s.per[ch]=(s.per[ch]&15)|((b&63)<<4)
    def field(s):
        s.wait-=882
        if s.wait>=0: return s.out()
        while True:
            b=s.getb()
            if b==0x66: s.ended=True; return None
            if b==0x50: s.write(s.getb()); continue
            if b==0x61: n=s.getb(); n|=s.getb()<<8
            elif b==0x62: n=735
            elif b==0x63: n=882
            elif b&0xF0==0x70: n=(b&15)+1
            elif b&0xF0==0x80: n=b&15
            elif b==0x67:
                s.getb(); s.getb(); sz=s.getb()|s.getb()<<8|s.getb()<<16; s.getb(); s.pos+=sz; continue
            else:
                if b==0x4F or 0x30<=b<0x40: s.pos+=1
                elif 0x40<=b<0x60: s.pos+=2
                elif b==0x68: s.pos+=11
                elif 0xA0<=b<0xC0: s.pos+=2
                elif 0xC0<=b<0xE0: s.pos+=3
                elif b>=0xE0: s.pos+=4
                elif 0x90<=b<=0x95: s.pos+=[4,4,5,10,1,4][b-0x90]
                continue
            s.wait+=n
            if s.wait>0: return s.out()
    def out(s):
        r=[]
        for k in range(3):
            a=15-s.att[k]; per=(s.per[k]*s.kscale)>>8
            r.append((per,a,1 if a else 0))
        return r
