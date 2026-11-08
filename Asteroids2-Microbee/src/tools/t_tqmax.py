from harness import *
b,E=boot(); m=b.block(0); mx=0
for i in range(2400):
    b.run(1)
    n=sum(1 for c in m[0x6000:0x6400] if c); mx=max(mx,n)
    q=b.peekw(E['tqn0']); q1=b.peekw(E['tqn1'])
    if i%200==0: print(i,n,q,q1)
print('max text cells',mx)
