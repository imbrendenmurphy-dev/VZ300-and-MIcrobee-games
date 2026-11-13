#!/bin/sh
# fieldcheck.sh COM SYM [vwait] : compare program field count with true vblanks, report poll gaps and true fps
./build/beemu $1 -frames 500 -vwait ${3:-0} -keys tests/drive.keys -sym $2 -prof out/p.csv -vdump out/vr.bin 2>&1 | tail -1
python3 - "$2" <<PYEOF
import sys
d=open('out/vr.bin','rb').read(); ram=d[6144+0x8800:]
sym={l.split()[1]:int(l.split()[0],16) for l in open(sys.argv[1])}
print(' program counted fields:', ram[sym['fields']]|ram[sym['fields']+1]<<8)
rows=[l.strip().split(',') for l in open('out/p.csv')]
vb=[int(t) for fr,t,n in rows if n=='P_vb']; fr=[int(t) for fr,t,n in rows if n=='P_frame']
g=sorted(b-a for a,b in zip(vb,vb[1:]))
avg=(fr[-1]-fr[5])/(len(fr)-6)
print(' poll gap max %d T; true %.2f fps (%.2f fields/frame)'%(g[-1],3375000/avg,avg/67608))
PYEOF
