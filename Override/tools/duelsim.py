"""A model of the link duel (rules and droid AI as in src/xfer.asm) against a simulated player,
for balancing: py tools/duelsim.py prints win rates by class."""
import random
L=12; WIRE,BREAK,FORK,BOOST,REV,FORKED=range(6)
def board(r):
    g=[WIRE]*L; c=0
    while c<L:
        x=r.randrange(16)
        if x<4: g[c]=BREAK
        elif x<6:
            if c<L-1: g[c]=FORK; g[c+1]=FORKED; c+=1
        elif x<7: g[c]=BOOST
        elif x<9: g[c]=REV
        c+=1
    return g
def duel(pc, ec, r, P):
    gates=[board(r),board(r)]
    own=[1+(i%2) for i in range(L)]; lock=[0]*L
    pulses=[[0]*L,[0]*L]
    ch=[P['my']+pc, P['en']+ec+ec*P['half']//2]
    work=[sum(1 for x in gates[s] if x not in (BREAK,FORKED)) for s in (0,1)]
    side = (0 if work[0]>=work[1] else 1) if r.random()<P['sidesmart'] else r.randrange(2)
    sides=[side,1-side]   # sides[0]=player's side index
    def score(s,c):
        me=s+1
        if pulses[s][c] or gates[s][c] in (BREAK,FORKED): return None
        who = me^3 if gates[s][c]==REV else me
        def node(c):
            e=own[c]; b=lock[c]
            if b and who!=e: return 0
            if who==e: return 1 if (b<12 and me==e) else 0
            if who==me: return 2
            if e==me: return -3
            return 0
        v=node(c)
        if gates[s][c]==FORK: v+=node(c+1)
        return v
    def fire(who,s,c):
        if ch[who]<=0 or pulses[s][c] or gates[s][c]==FORKED: return
        ch[who]-=1; pulses[s][c]=1
    def take(s,c,lk):
        o=s+1
        if gates[s][c]==REV: o^=3
        if lock[c] and own[c]!=o: return
        lock[c]=lk; own[c]=o
    ait=0; pt=P['react']; cur=5; T=P['time']
    for t in range(T,0,-1):
        # player
        pt-=1
        if pt<=0 and ch[0]>0:
            s=sides[0]
            opts=[(score(s,c),c) for c in range(L)]
            opts=[(v,c) for v,c in opts if v is not None]
            if opts:
                if r.random()<P['err']: v,c=r.choice(opts)
                else: v,c=max(opts)
                if v>0 or r.random()<0.3:
                    fire(0,s,c); pt=P['react']+abs(c-cur)*P['move']; cur=c
                else: pt=4
            else: pt=4
        # ai
        ait-=1
        if ait<0:
            ait=P['ait'](ec)
            s=sides[1]
            if ch[1]>0 and (ch[1]>=2 or ec<P['savec'] or t<50):
                best=None
                for c in range(L):
                    v=score(s,c)
                    if v is not None and (best is None or v>best[0]): best=(v,c)
                if best and best[0]>0:
                    c=best[1]
                    if r.randrange(8)>ec*P['fumk'] and r.randrange(16)<L: c=r.randrange(16)
                    if c<L: fire(1,s,c)
        # step
        for i in range(L):
            if lock[i]: lock[i]-=1
        for s in (0,1):
            for c in range(L):
                if pulses[s][c]:
                    pulses[s][c]+=1
                    if pulses[s][c]>=17:
                        pulses[s][c]=0
                        g=gates[s][c]
                        if g==BREAK: continue
                        base=P.get('plock',P['lock']) if s==sides[0] else P['lock']
                        lk=base*2 if g==BOOST else base
                        take(s,c,lk)
                        if g==FORK: take(s,c+1,lk)
    mine=sum(1 for o in own if o==sides[0]+1); theirs=L-mine
    return 1 if mine>theirs else (0 if mine<theirs else 2)
OLD=dict(my=5,en=4,half=0,ait=lambda c:22-2*c,savec=0,lock=45,time=250,react=14,move=3,err=0.25,sidesmart=0.5,fumk=1)
def table(P,label,me=(0,3,5)):
    r=random.Random(1)
    print(label)
    for pc in me:
        row=[]
        for ec in range(1,10):
            res=[duel(pc,ec,r,P) for _ in range(300)]
            row.append('%3d' % (100*res.count(1)//len(res)))
        print('  you class %d vs 1-9: %s   (win %%)' % (pc,' '.join(row)))
NEW=dict(my=7,en=1,half=1,plock=70,ait=lambda c:30-2*c,savec=5,lock=45,time=250,react=14,move=2,err=0.25,sidesmart=0.7,fumk=1)
if __name__=='__main__':
    table(OLD,'v0.5 RULES')
    table(NEW,'v0.6 RULES')
    N=dict(NEW); N.update(err=0.5,sidesmart=0.4,react=18)
    table(N,'v0.6 RULES, novice player')
