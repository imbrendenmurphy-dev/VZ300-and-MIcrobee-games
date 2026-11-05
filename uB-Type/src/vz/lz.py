# simple LZ for VZ-TYPE: ctrl<0x7f literal run (ctrl+1 bytes); 0x7f end;
# ctrl>=0x80 match len=(ctrl&0x7f)+3, followed by 16-bit distance (LE)
def pack(data):
    data=bytes(data); n=len(data); out=bytearray(); lit=bytearray(); i=0
    idx={}
    def flush():
        nonlocal lit
        while lit:
            k=min(len(lit),127); out.append(k-1); out.extend(lit[:k]); lit=lit[k:]
    while i<n:
        best=0; bd=0
        if i+3<=n:
            key=data[i:i+3]
            for j in reversed(idx.get(key,[])[-64:]):
                l=0
                while i+l<n and l<130 and data[j+l]==data[i+l]: l+=1
                if l>best: best=l; bd=i-j
                if l==130: break
        if best>=4 or (best==3 and bd<256):
            flush(); out.append(0x80|(best-3)); out+=bytes([bd&255,bd>>8])
            for k in range(best):
                if i+k+3<=n: idx.setdefault(data[i+k:i+k+3],[]).append(i+k)
            i+=best
        else:
            if i+3<=n: idx.setdefault(data[i:i+3],[]).append(i)
            lit.append(data[i]); i+=1
    flush(); out.append(0x7f)
    return bytes(out)
def unpack(p):
    o=bytearray(); i=0
    while True:
        c=p[i]; i+=1
        if c==0x7f: return bytes(o)
        if c<0x7f: o+=p[i:i+c+1]; i+=c+1
        else:
            l=(c&0x7f)+3; d=p[i]|(p[i+1]<<8); i+=2
            for k in range(l): o.append(o[-d])
if __name__=='__main__':
    import random
    for t in range(200):
        R=random.Random(t); d=bytes(R.choice([0,1,2,3,R.randrange(256)]) for _ in range(R.randrange(1,3000)))
        assert unpack(pack(d))==d
    print('lz ok')
