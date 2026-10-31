import sys,re
syms=[]
for l in open(sys.argv[1]):
    m=re.match(r'([A-Za-z_][\w]*): EQU 0x([0-9A-F]+)',l)
    if m and '.' not in m.group(1): syms.append((int(m.group(2),16),m.group(1)))
syms=sorted(s for s in syms if 0x8000<=s[0]<0xC800)
import bisect; keys=[s[0] for s in syms]; agg={}
tot=0
for l in open(sys.argv[2]):
    a,c=l.split(); a=int(a,16); c=int(c); tot+=c
    i=bisect.bisect_right(keys,a)-1; n=syms[i][1] if i>=0 and a>=0x8000 else '?'
    agg[n]=agg.get(n,0)+c
for n,c in sorted(agg.items(),key=lambda x:-x[1])[:int(sys.argv[3]) if len(sys.argv)>3 else 25]: print('%-22s %5.1f%%'%(n,100*c/tot))
