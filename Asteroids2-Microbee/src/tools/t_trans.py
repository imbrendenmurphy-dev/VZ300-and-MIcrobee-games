from harness import *
import collections,bisect
b,E=boot()
for i in range(2000):
    b.run(1)
    if 'ENEMY' in ttext(b): break
# rerun to just before the page change
b,E=boot(); b.run(i-40); b.profile(True); b.run(50); p=b.prof()
inv={v:k for k,v in E.items() if v>=0x8000 and '.' not in k}; ad=sorted(inv); c=collections.Counter()
for a in range(0x8000,0x10000):
    if p[a]:
        j=bisect.bisect_right(ad,a)-1; c[inv[ad[j]]]+=p[a]
for k,v in c.most_common(25): print('%-16s %8.0f ms'%(k,v/3375))
