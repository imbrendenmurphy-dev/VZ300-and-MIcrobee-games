#!/bin/sh
# prof.sh [sector] -> where the time goes in a 60 s busy run
SEC=${1:-4}
cd "$(dirname "$0")/.."
CS=$(grep -E "^cont_sec:" build/starwhrl.sym | sed 's/.*0x0000//')
PI=$(grep -E "^pips:" build/starwhrl.sym | sed 's/.*0x0000//')
LV=$(grep -E "^lives:" build/starwhrl.sym | sed 's/.*0x0000//')
P="-poke 30:$CS:$SEC"; for f in $(seq 200 100 2900); do P="$P -poke $f:$PI:3 -poke $f:$LV:3"; done
./tools/vzemu/vzemu build/STARWHRL.VZ -bennvenn -frames 3000 -keys tools/stress_keys.txt -prof /tmp/prof.bin 300 $P 2>/dev/null
python3 - <<'P'
import struct,re,bisect
d=struct.unpack('<65536Q',open('/tmp/prof.bin','rb').read())
syms=[]
for l in open('build/starwhrl.sym'):
    m=re.match(r'([A-Za-z_][\w]*):\s+EQU\s+0x([0-9A-F]+)',l)
    if m and '.' not in m.group(1):
        a=int(m.group(2),16)
        if 0x8000<=a<0xF800: syms.append((a,m.group(1)))
syms.sort(); addrs=[a for a,_ in syms]
tot={}
for pc,c in enumerate(d):
    if not c: continue
    if 0x4800<=pc<0x6500: n='COPY(isr)'
    else:
        i=bisect.bisect_right(addrs,pc)-1
        n=syms[i][1] if i>=0 else '?'
    tot[n]=tot.get(n,0)+c
T=sum(tot.values()); F=2700
for n,c in sorted(tot.items(),key=lambda x:-x[1])[:22]: print('%-16s %5.1f%%  %6d T/field'%(n,100*c/T,c//F))
P
