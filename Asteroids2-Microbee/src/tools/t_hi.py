from harness import *
b,E=boot(); a=E['hi_score']
prev=None
def chk(tag):
    global prev
    v=bytes(b.block(0)[a-0x8000:a-0x8000+3]).hex()
    if v!=prev: print(tag,b.frames,v); prev=v
for i in range(400): b.run(1); chk('attract')
b.key('K'); b.run(4); b.keys_up()
for i in range(200): b.run(1); chk('keys')
for k in 'QWERTY':
    b.key(k); b.run(10); b.keys_up(); b.run(10); chk('key '+k)
for i in range(300): b.run(1); chk('after')
