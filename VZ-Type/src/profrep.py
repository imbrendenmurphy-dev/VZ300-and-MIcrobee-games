import sys,struct
syms=[]
for l in open('./sym.txt'):
    p=l.split()
    if len(p)>=3 and p[1]=='EQU':
        n=p[0].rstrip(':')
        if '.' in n: continue
        syms.append((int(p[2],16),n))
syms.sort()
d=open(sys.argv[1],'rb').read(); v=struct.unpack('<65536I',d)
import bisect
keys=[a for a,_ in syms]
acc={}
tot=sum(v)
for pc in range(65536):
    if v[pc]:
        i=bisect.bisect_right(keys,pc)-1; n=syms[i][1] if i>=0 else '?'
        acc[n]=acc.get(n,0)+v[pc]
for n,t in sorted(acc.items(),key=lambda x:-x[1])[:25]: print('%-16s %6.1f%%'%(n,100*t/tot))
