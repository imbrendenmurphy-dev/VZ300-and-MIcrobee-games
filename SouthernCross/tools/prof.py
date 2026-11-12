import sys, struct, bisect
p=struct.unpack('<65536Q',open(sys.argv[1],'rb').read())
syms=sorted((int(a,16),n) for a,n in (l.split() for l in open(sys.argv[2])) if '.' not in n)
addrs=[a for a,_ in syms]; acc={}
for pc,t in enumerate(p):
    if not t: continue
    i=bisect.bisect_right(addrs,pc)-1; n=syms[i][1] if i>=0 else '?'
    if 0x5500<=pc<0x6100: n='BLIT_PF(sram)'
    acc[n]=acc.get(n,0)+t
tot=sum(acc.values())
for n,t in sorted(acc.items(),key=lambda x:-x[1])[:25]: print('%6.2f%% %10d %s'%(100*t/tot,t,n))
