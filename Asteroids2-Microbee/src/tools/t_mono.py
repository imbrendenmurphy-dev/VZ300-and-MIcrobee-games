from harness import *
b,E=boot()
b.run(150); b.key('C'); b.run(4); b.keys_up(); b.run(60)
b.image(mono=False,scale=1).save('/home/claude/ast/out/mono.png')
print('mono',b.peek(E['mono']))
c=b.video(2); print([hex(c[13*64+x]) for x in range(8,14)], [hex(c[1024+13*64+x]) for x in range(8,14)], [hex(c[8*64+x]) for x in range(20,24)])
print(text(b).split('\n')[0])
