import sys,struct,re
p=struct.unpack('<65536Q',open(sys.argv[1],'rb').read())
syms=[]
for l in open('../build/gh2.sym'):
    m=re.match(r'(\S+): EQU 0x([0-9A-F]+)',l)
    if m and '.' not in m.group(1):
        a=int(m.group(2),16)
        if 0x8000<=a<0xD200: syms.append((a,m.group(1)))
syms.sort()
tot={}
import bisect
addrs=[a for a,_ in syms]
for pc in range(65536):
    if p[pc]:
        i=bisect.bisect_right(addrs,pc)-1
        n=syms[i][1] if i>=0 and pc>=0x8000 else 'other'
        tot[n]=tot.get(n,0)+p[pc]
T=sum(tot.values())
for n,v in sorted(tot.items(),key=lambda x:-x[1])[:25]: print("%-20s %5.1f%%"%(n,100*v/T))
