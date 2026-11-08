from harness import *
def enter():
    b,E=boot(); b.run(200)
    b.key('K'); b.run(4); b.keys_up()
    for i in range(100):
        b.run(5)
        if 'DEFINE KEYS' in ttext(b): break
    b.run(20); return b,E
def press(b,k,n=12):
    b.key(k); b.run(10); b.keys_up(); b.run(n)
def km(b,E): return [b.peek(E['keymap']+2*i) for i in range(6)]
b,E=enter()
press(b,'Q'); press(b,'Q',5); print('taken msg:', 'TAKEN' in ttext(b)); b.run(40)
press(b,'LEFT',5); print('alt taken:', 'TAKEN' in ttext(b)); b.run(40)
press(b,'W'); print('so far', km(b,E))
b.image(scale=1).save('/home/claude/ast/out/dk1.png')
press(b,'ESC',5); print('cancel:', 'CANCELLED' in ttext(b), km(b,E))
b.run(80); print('back to title:', 'ROCKS ARE' in ttext(b) or 'CONTROLS' in ttext(b))
b,E=enter()
for k in 'QWERTY': press(b,k)
print('set', km(b,E)); b.run(80)
b,E=enter(); press(b,'A'); press(b,'TAB',5); print('defaults:', 'DEFAULT' in ttext(b), km(b,E))
print('\n'.join(ttext(b).split('\n')[1:16]))
