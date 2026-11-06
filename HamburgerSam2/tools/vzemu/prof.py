import sys,struct,re,bisect
# usage: prof.py prof.bin symfile frames
p=struct.unpack('<65536Q',open(sys.argv[1],'rb').read())
syms=[]
for l in open(sys.argv[2]):
    m=re.match(r'(\S+): EQU 0x([0-9A-F]+)',l)
    if m:
        a=int(m.group(2),16)
        if 0x8000<=a<0xE000: syms.append((a,m.group(1)))
syms.sort(); addrs=[a for a,_ in syms]
tot={}
for pc in range(65536):
    if p[pc]:
        i=bisect.bisect_right(addrs,pc)-1
        n=syms[i][1] if i>=0 and pc>=0x8000 else 'other'
        n=n.split('.')[0]
        tot[n]=tot.get(n,0)+p[pc]
T=sum(tot.values()); nf=int(sys.argv[3]) if len(sys.argv)>3 else 1
for n,v in sorted(tot.items(),key=lambda x:-x[1])[:25]: print("%-24s %5.1f%%  %6d T/frame"%(n,100*v/T, v//nf))
