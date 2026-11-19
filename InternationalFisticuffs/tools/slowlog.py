import sys
from collections import Counter
names=['STAND','CROUCH','PREJ','JUMP','LAND','ATK','HSTUN','BSTUN','KD','KO','WIN','FROZEN']
fr=['IDLE','WALK1','WALK2','CROUCH','JUMP','BLOCK','CBLOCK','SA_W','SA_S','SB_W','SB_S','CA_S','CB_S','JA','JB','HIT','DOWN','SP1_W','SP1_S','SP2_W','SP2_S','WIN']
c=Counter()
for line in open(sys.argv[1]):
    p=line.split(':')
    b=[int(x,16) for x in p[1].split()]
    def d(o): return '%s/%s/%s mv%d' % (['F','D'][b[o]&1], names[b[o+5]] if b[o+5]<12 else b[o+5], fr[b[o+13]] if b[o+13]<22 else b[o+13], b[o+7])
    c[d(0)+' | '+d(64)]+=1
for k,v in c.most_common(30): print(v,k)
