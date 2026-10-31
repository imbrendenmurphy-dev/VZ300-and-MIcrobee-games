import sys, struct, re, bisect
data = open('prof.bin','rb').read()
n = len(data)//8
counts = struct.unpack('<%dQ' % n, data)
syms = []
for line in open('../out/dp2.sym'):
    m = re.match(r'([A-Za-z_][\w]*):\s+EQU\s+0x([0-9A-F]+)', line)
    if m and '.' not in m.group(1):
        v = int(m.group(2),16)
        if 0x8000 <= v < 0xD400: syms.append((v, m.group(1)))
syms.sort()
addrs=[a for a,_ in syms]
tot={}
total=sum(counts)
for pc,c in enumerate(counts):
    if not c: continue
    i=bisect.bisect_right(addrs,pc)-1
    name=syms[i][1] if i>=0 else '?%04x'%pc
    if pc>=0x7f00 and pc < 0x8000: name='isrjp'
    tot[name]=tot.get(name,0)+c
frames=float(sys.argv[1]) if len(sys.argv)>1 else 1
for k,v in sorted(tot.items(), key=lambda x:-x[1])[:28]:
    print('%-22s %7.1f lines/frame  %5.1f%%' % (k, v/228/frames, 100*v/total))
