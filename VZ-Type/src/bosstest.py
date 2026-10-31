import sys
syms={}
for l in open('./sym.txt'):
    p=l.split()
    if len(p)>=3 and p[1]=='EQU': syms[p[0].rstrip(':').lower()]=int(p[2],16)
def S(n): return '%04x'%syms[n.lower()]
lvl=int(sys.argv[1]); nfr=int(sys.argv[2]); shots=int(sys.argv[3]); pre=sys.argv[4]
col=int(sys.argv[5]) if len(sys.argv)>5 else 560+lvl*20-60
aimy=int(sys.argv[6]) if len(sys.argv)>6 else -1
L=['vz','loadvz VZTYPE.VZ','frames 30','poke %s %02x'%(S('dbgcol'),col&255),'poke %04x %02x'%(syms['dbgcol']+1,col>>8),
   'frames 30','key 4 4 1','frames 5','key 4 4 0','frames 2','poke %s %02x'%(S('lvlnum'),lvl)]
k=0; step=max(1,nfr//shots)
for i in range(nfr//20):
    L.append('poke %s ff'%S('pinv'))
    if aimy>=0 and i>40: L.append('poke %s %02x'%(S('py'),aimy))
    if i%6==0: L.append('key 4 4 1')
    if i%6==4: L.append('key 4 4 0')
    if aimy<0 and i%12==0: L.append('key 0 4 1')
    if i%12==3: L.append('key 0 4 0')
    if aimy<0 and i%12==6: L.append('key 1 4 1')
    if i%12==9: L.append('key 1 4 0')
    L.append('frames 20')
    if (i*20)%step==0: L.append('vzshot %s%03d.vz'%(pre,k)); k+=1
L+=['regs','peek %s 1'%S('lvlnum'),'peek %s 3'%S('score')]
open('bt_%s.scr'%pre,'w').write('\n'.join(L)+'\n')
