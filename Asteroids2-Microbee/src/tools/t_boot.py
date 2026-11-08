from harness import *
b,E=boot()
print('frames',b.frames,'pc %04x'%b.reg('pc'))
for i in range(6):
    b.run(50); b.image().save('/home/claude/ast/out/t%d.png'%i)
print(text(b)[:400]); print('fields',b.peek(E['fields']),'sp %04x'%b.reg('sp'))
