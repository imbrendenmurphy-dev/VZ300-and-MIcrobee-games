import sys; sys.path.insert(0,'/home/claude/ast/tools')
from bee import *
U='/mnt/user-data/uploads/'
ROM=open(U+'work/ubee-audio-check/roms/bn60.rom','rb').read()
CHR=open(U+'work/ubee-audio-check/roms/charrom.bin','rb').read()
def text(b):
    s=b.video(0); c=[int(x) for x in b.crtc]; cols=c[1] or 64; rows=c[6] or 16; st=((c[12]&0x3f)<<8)|c[13]
    return '\n'.join(''.join(chr(s[(st+r*cols+x)&0x7ff]) if 32<=s[(st+r*cols+x)&0x7ff]<127 else ' ' for x in range(cols)).rstrip() for r in range(rows))
def typ(b,t):
    for ch in t:
        b.key('RET' if ch=='\r' else ch); b.run(4); b.keys_up(); b.run(4)
def boot(disk='/home/claude/ast/build/AST2.DS8'):
    b=Bee(ROM,CHR,open(disk,'rb').read()); b.set_pc(0x8000,0)
    b.run(60); typ(b,'B')
    for i in range(80):
        b.run(10)
        if 'A>' in text(b): break
    assert 'A>' in text(b), text(b)
    typ(b,'AST2\r')
    E=sym('/home/claude/ast/build/engine.sym')
    for i in range(600):
        b.run(5)
        if b.port(0x50)==7 and b.peek(0x8000)==0xC3 and b.reg('pc')>=0x8000: break
    return b,E
def ttext(b):
    m=b.block(0)[0x6000:0x6400]
    return '\n'.join(''.join(chr(c) if 32<=c<96 else ' ' for c in m[r*64:(r+1)*64]).rstrip() for r in range(16))
