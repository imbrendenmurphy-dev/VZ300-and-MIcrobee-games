import sys; sys.path.insert(0,'.')
from bee import *
U='/mnt/user-data/uploads/'
rom=open(U+'work/ubee-audio-check/roms/bn60.rom','rb').read()
chr_=open(U+'work/ubee-audio-check/roms/charrom.bin','rb').read()
disk=open(U+'outputs/Asteroids2-Microbee/build/AST2.DS8','rb').read()
b=Bee(rom,chr_,disk); b.set_pc(0x8000,0)
def text():
    s=b.video(0); c=[int(x) for x in b.crtc]; cols=c[1] or 64; rows=c[6] or 16; st=((c[12]&0x3f)<<8)|c[13]
    return '\n'.join(''.join(chr(s[(st+r*cols+x)&0x7ff]) if 32<=s[(st+r*cols+x)&0x7ff]<127 else ' ' for x in range(cols)).rstrip() for r in range(rows))
def typ(t):
    for ch in t:
        b.key('RET' if ch=='\r' else ch); b.run(4); b.keys_up(); b.run(4)
b.run(60); typ('B')
for i in range(80):
    b.run(10)
    if 'A>' in text(): break
print(text()); 
typ('AST2\r')
for i in range(400):
    b.run(10)
    if b.crtc[1]==64 and b.crtc[9]==15 and b.peek(0x8000)!=0xff: break
print('frames',b.frames, 'crtc',list(b.crtc[:16]))
b.run(100); b.image().save('../out/codex_title.png')
