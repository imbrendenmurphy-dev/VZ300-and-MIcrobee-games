from harness import *
b,E=boot()
for k,f in enumerate((150,450,650,820,1020,1200)):
    b.run(f-(0 if k==0 else (150,450,650,820,1020,1200)[k-1])); b.image(scale=1).save('/home/claude/ast/out/a%d.png'%k)
print(text(b))
