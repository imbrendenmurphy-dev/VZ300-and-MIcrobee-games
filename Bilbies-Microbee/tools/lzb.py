# LZB: bit-oriented LZ for VZ-TYPE stage data (my own simple format)
# stream: 16-byte table of frequent literals, 16-bit output length, then a bitstream (MSB first):
#   0 0 nnnn          short literal = table[nnnn]
#   0 1 bbbbbbbb      literal byte
#   1 <gamma len-1> 0 ooooooo        match, offset 1..128
#   1 <gamma len-1> 1 oooooooooooo   match, offset 1..4096
# gamma(n>=1): (k-1) zero bits, then the k-bit binary of n (MSB first)
class BW:
    def __init__(s): s.out=bytearray(); s.cur=0; s.n=0
    def bit(s,b):
        s.cur=(s.cur<<1)|b; s.n+=1
        if s.n==8: s.out.append(s.cur); s.cur=0; s.n=0
    def bits(s,v,k):
        for i in range(k-1,-1,-1): s.bit((v>>i)&1)
    def gamma(s,v):
        k=v.bit_length(); s.bits(0,k-1); s.bits(v,k)
    def flush(s):
        while s.n: s.bit(0)
        return bytes(s.out)
def glen(v): return 2*v.bit_length()-1
def pack(data):
    data=bytes(data); n=len(data)
    from collections import Counter
    tab=[b for b,_ in Counter(data).most_common(16)]
    tab+= [0]*(16-len(tab))
    tpos={b:i for i,b in enumerate(tab)}
    # optimal parse (cost in bits) backwards
    INF=10**9; cost=[INF]*(n+1); cost[n]=0; choice=[None]*(n+1)
    idx={}
    for i in range(n): idx.setdefault(data[i:i+2],[]).append(i)
    for i in range(n-1,-1,-1):
        lc=(6 if data[i] in tpos else 10)+cost[i+1]; cost[i]=lc; choice[i]=('L',)
        for j in reversed(idx.get(data[i:i+2],[])):
            if j>=i: continue
            d=i-j
            if d>4096: break
            l=0
            while i+l<n and data[j+l]==data[i+l] and l<255: l+=1
            ob=8 if d<=128 else 13
            for L in (l,) if l<2 else range(2,l+1):
                c=1+glen(L-1)+ob+cost[i+L]
                if c<cost[i]: cost[i]=c; choice[i]=('M',L,d)
    bw=BW(); i=0
    while i<n:
        ch=choice[i]
        if ch[0]=='L':
            b=data[i]
            if b in tpos: bw.bit(0); bw.bit(0); bw.bits(tpos[b],4)
            else: bw.bit(0); bw.bit(1); bw.bits(b,8)
            i+=1
        else:
            _,L,d=ch; bw.bit(1); bw.gamma(L-1)
            if d<=128: bw.bit(0); bw.bits(d-1,7)
            else: bw.bit(1); bw.bits(d-1,12)
            i+=L
    return bytes(tab)+bytes([n&255,n>>8])+bw.flush()
def unpack(p):
    tab=p[:16]; n=p[16]|(p[17]<<8); o=bytearray()
    pos=[18]; cur=[0]; left=[0]
    def bit():
        if left[0]==0: cur[0]=p[pos[0]]; pos[0]+=1; left[0]=8
        left[0]-=1; return (cur[0]>>left[0])&1
    def bits(k):
        v=0
        for _ in range(k): v=(v<<1)|bit()
        return v
    def gamma():
        k=1
        while bit()==0: k+=1
        v=1
        for _ in range(k-1): v=(v<<1)|bit()
        return v
    while len(o)<n:
        if bit()==0:
            if bit()==0: o.append(tab[bits(4)])
            else: o.append(bits(8))
        else:
            L=gamma()+1
            d=(bits(7) if bit()==0 else bits(12))+1
            for _ in range(L): o.append(o[-d])
    return bytes(o)
if __name__=='__main__':
    import random
    for t in range(100):
        R=random.Random(t); d=bytes(R.choice([0,1,2,3,R.randrange(256)]) for _ in range(R.randrange(1,2000)))
        assert unpack(pack(d))==d,t
    print('lzb ok')
