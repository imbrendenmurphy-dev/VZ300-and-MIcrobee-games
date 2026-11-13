from harness import *
b,E=boot()
b.run(150); b.key('C')
hit=b.run_until(E['screen_map'],20); print('screen_map hit',hit, 'mono',b.peek(E['mono']),'col_and',b.peek(E['col_and']),b.peek(E['col_or']))
b.keys_up()
hit=b.run_until(E['title_texts'],20); print('title_texts hit',hit)
b2,E=boot()
b2.run(150); b2.key('C')
print(b2.run_until(E['screen_map'],20), hex(b2.peekw(b2.reg('sp'))))
inv={v:k for k,v in E.items()}
import bisect; ad=sorted(a for a in inv if a>=0x8000)
r=b2.peekw(b2.reg('sp')); print('return to', inv[ad[bisect.bisect_right(ad,r)-1]])
print(b2.run_until(E['page_redraw'],5))
print('page_texts',hex(b2.peekw(E['page_texts'])), hex(E['title_texts']))
