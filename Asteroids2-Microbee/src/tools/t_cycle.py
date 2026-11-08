from harness import *
b,E=boot()
b.run(150); b.key('SPACE'); b.run(4); b.keys_up()
seen=set()
for i in range(120):
    b.run(50)
    t=ttext(b)
    for k in ('HIGH SCORES','ENEMY FILES','TREASURE','ROCKS ARE BACK','NEW HIGH','GAME OVER'):
        if k in t or k.replace(' ','') in t.replace(' ',''): seen.add(k)
print(sorted(seen), 'pc %04x sp %04x'%(b.reg('pc'),b.reg('sp')))
b.image(scale=1).save('/home/claude/ast/out/cycle_end.png')
