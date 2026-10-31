import sys,re,bisect
syms=[]
for l in open(sys.argv[2]):
    m=re.match(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',l)
    if m and '.' not in m.group(1): syms.append((int(m.group(2),16),m.group(1)))
syms.sort(); addrs=[a for a,_ in syms]
tot={}; T=0
for l in open(sys.argv[1]):
    a,c=l.split(); a=int(a,16); c=int(c); T+=c
    i=bisect.bisect_right(addrs,a)-1; n=syms[i][1] if i>=0 else '?'
    tot[n]=tot.get(n,0)+c
fr=float(sys.argv[3]) if len(sys.argv)>3 else 1
for n,c in sorted(tot.items(),key=lambda x:-x[1])[:25]: print('%-20s %8.0f T/frame %5.1f%%'%(n,c/fr,100*c/T))
print('total %.0f T/frame'%(T/fr))
