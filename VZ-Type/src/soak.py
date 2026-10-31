import sys,subprocess
syms={}
for l in open('./sym.txt'):
    p=l.split()
    if len(p)>=3 and p[1]=='EQU': syms[p[0].rstrip(':').lower()]=int(p[2],16)
def S(n): return '%04x'%syms[n.lower()]
nfr=int(sys.argv[1]); shots=int(sys.argv[2]); pre=sys.argv[3]
lvl=int(sys.argv[4]) if len(sys.argv)>4 else 0
bossweak=int(sys.argv[5]) if len(sys.argv)>5 else 10**9
L=['vz','loadvz VZTYPE.VZ']
if lvl: L+=['frames 30','poke %s %02x'%(S('lvlnum'),lvl)]   # not effective before new_game resets; handled below
L+=['frames 60','key 4 4 1','frames 5','key 4 4 0']
if lvl:
    # set level after new_game cleared it: wait for stage intro start then poke
    L+=['frames 2','poke %s %02x'%(S('lvlnum'),lvl)]
k=0; step=nfr//shots
for i in range(nfr//20):
    L.append('poke %s ff'%S('pinv'))
    # fire pattern: tap/charge alternating
    if i%6==0: L.append('key 4 4 1')
    if i%6==4: L.append('key 4 4 0')
    # wobble up/down
    if i%10==0: L.append('key 0 4 1')
    if i%10==3: L.append('key 0 4 0')
    if i%10==5: L.append('key 1 4 1')
    if i%10==8: L.append('key 1 4 0')
    if i*20>=bossweak: L.append('pokep %s 3 01'%S('bossent'))
    L.append('frames 20')
    if (i*20)%step==0:
        L.append('vzshot %s%03d.vz'%(pre,k)); k+=1
L.append('regs'); L.append('peek %s 2'%S('scol')); L.append('peek %s 1'%S('lvlnum')); L.append('peek %s 3'%S('score'))
open('soak_%s.scr'%pre,'w').write('\n'.join(L)+'\n')
