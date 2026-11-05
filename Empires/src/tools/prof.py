import struct,sys,bisect
sym=sorted((int(l.split()[0],16),l.split()[1]) for l in open('build/empires.sym'))
addrs=[a for a,_ in sym]
p=struct.unpack('<65536I',open('build/prof.bin','rb').read())
agg={}
for a,t in enumerate(p):
    if t:
        i=bisect.bisect_right(addrs,a)-1
        n=sym[i][1].split('.')[0]
        agg[n]=agg.get(n,0)+t
tot=sum(agg.values())
for n,t in sorted(agg.items(),key=lambda x:-x[1])[:12]: print('%-20s %7d %5.1f%%'%(n,t,100*t/tot))
