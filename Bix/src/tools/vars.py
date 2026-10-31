import re,sys
mem=open('/tmp/vzmem.bin','rb').read()
sym={}
for l in open('/home/claude/bix/build/bix.sym'):
    m=re.match(r'(\S+): EQU 0x([0-9A-F]+)',l)
    if m: sym[m.group(1)]=int(m.group(2),16)
for n in sys.argv[1:]:
    w=n.endswith(':w'); n=n.split(':')[0]
    a=sym[n]; v=mem[a]|(mem[a+1]<<8) if w else mem[a]
    print(n, v, hex(v))
