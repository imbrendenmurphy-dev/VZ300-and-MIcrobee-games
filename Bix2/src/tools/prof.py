import struct,re,sys
h=struct.unpack('65536Q',open('/tmp/vzprof.bin','rb').read())
syms=[]
for l in open('/home/claude/bix/build/bix.sym'):
    m=re.match(r'(\S+): EQU 0x([0-9A-F]+)',l)
    if m and '.' not in m.group(1): syms.append((int(m.group(2),16),m.group(1)))
syms.sort()
import bisect
acc={}
addrs=[a for a,_ in syms]
for pc,c in enumerate(h):
    if c==0: continue
    i=bisect.bisect_right(addrs,pc)-1
    n=syms[i][1] if i>=0 else '?'
    acc[n]=acc.get(n,0)+c
tot=sum(acc.values())
fields=float(sys.argv[1])
for n,c in sorted(acc.items(),key=lambda x:-x[1])[:25]:
    print(f'{n:20s} {c/fields:9.0f} T/field {100*c/tot:5.1f}%')
