from harness import *
b,E=boot()
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(100)
import collections
for k in range(8):
    b.run_until(E['text_redraw'],10)
    pg=b.peek(E['back']); n=b.peekw(E['tqn%d'%pg]); base=E['tq%d'%pg]
    cells=[b.peekw(base+2*i) for i in range(min(n,1024))]
    c=collections.Counter(cells)
    print('page',pg,'queued',n,'unique',len(c),'rows',sorted(collections.Counter(x>>6 for x in cells).items())[:6])
    b.run(1)
