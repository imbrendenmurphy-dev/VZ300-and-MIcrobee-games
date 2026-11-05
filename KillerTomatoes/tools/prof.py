import sys, struct, re
prof = struct.unpack('<65536Q', open(sys.argv[1],'rb').read())
syms=[]
for l in open(sys.argv[2]):
    m=re.match(r'(\S+): EQU 0x([0-9A-F]+)',l)
    if m and '.' not in m.group(1): syms.append((int(m.group(2),16),m.group(1)))
syms.sort()
import bisect
keys=[s[0] for s in syms]
acc={}
for pc,t in enumerate(prof):
    if t==0: continue
    i=bisect.bisect_right(keys,pc)-1
    n=syms[i][1] if i>=0 else '?'
    acc[n]=acc.get(n,0)+t
tot=sum(acc.values())
for n,t in sorted(acc.items(),key=lambda x:-x[1])[:25]:
    print('%-20s %5.1f%%'%(n,100*t/tot))
