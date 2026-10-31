import sys,re
sym={}
for l in open(sys.argv[1]):
    m=re.match(r'(\w+): EQU 0x([0-9A-F]+)',l)
    if m: sym[m.group(1)]=int(m.group(2),16)
mem=open(sys.argv[2],'rb').read()
def b(n,k=1): return mem[sym[n]:sym[n]+k].hex()
for n in sys.argv[3].split(','): print(n,b(n,3 if n in('score','hiscore') else 1))
