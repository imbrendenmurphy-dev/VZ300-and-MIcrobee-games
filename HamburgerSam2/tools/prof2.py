import struct,bisect,sys
p=struct.unpack('<65536Q',open(sys.argv[1],'rb').read())
nf=int(sys.argv[2])
syms=[]
for l in open('build/hamsam2.sym'):
    a,n=l.split(); a=int(a,16)
    if 0x7000<=a<0xF000 and not n.isupper(): syms.append((a,n))
syms.sort(); addrs=[a for a,_ in syms]
tot={}; top={}
for pc in range(65536):
    if p[pc]:
        i=bisect.bisect_right(addrs,pc)-1
        n=syms[i][1] if i>=0 else 'low'
        tot[n]=tot.get(n,0)+p[pc]
        t=n.split('.')[0]; top[t]=top.get(t,0)+p[pc]
for n,v in sorted(top.items(),key=lambda x:-x[1])[:14]: print("%-22s %7d T/frame"%(n, v//nf))
