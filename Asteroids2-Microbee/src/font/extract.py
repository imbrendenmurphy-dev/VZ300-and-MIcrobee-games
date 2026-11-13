from PIL import Image; import numpy as np
im=np.array(Image.open('ref.png').convert('L')).astype(float)/255
ink=1-im
def segs(a,b):
    cols=(ink[a:b]>0.55).sum(0); out=[];inb=False
    for x,v in enumerate(cols):
        if v>0 and not inb: s=x;inb=True
        if v==0 and inb: out.append((s,x));inb=False
    return out
bands={'A':(6,56,'ABCDEFGHIJKLMNO'),'P':(90,140,'PQRSTUVWXYZ'),'2':(333,402,'234567890[$')}
G={}
for k,(a,b,chars) in bands.items():
    ss=segs(a,b)
    for ch,(x0,x1) in zip(chars,ss):
        G[ch]=(a,b,x0,x1)
# '1' from row 4 last segment, '.', ',', '!', '?' from row5
r5=segs(333,402); G['.']=(333,402)+r5[12]; G[',']=(333,402)+r5[13]; G['!']=(333,402)+r5[14]; G['?']=(333,402)+r5[15]
r4=segs(257,321); G['1']=(257,321)+r4[-1]
W,H=7,10
def glyph(ch,thr=0.42):
    a,b,x0,x1=G[ch]
    sub=ink[a:b,x0:x1]
    ys=np.where(sub.max(1)>0.5)[0]; sub=sub[ys[0]:ys[-1]+1]
    h,w=sub.shape
    if ch in '.,!': tw=max(2,round(w/39*W)); 
    else: tw=W
    th=H if ch not in '.,' else max(2,round(h/50*H))
    if ch in '.,': 
        g=np.array(Image.fromarray((sub*255).astype('uint8')).resize((tw,th),Image.BOX))/255>thr
    else:
        g=np.array(Image.fromarray((sub*255).astype('uint8')).resize((tw,th),Image.BOX))/255>thr
    return g
if __name__=='__main__':
    out=[]
    for ch in sorted(G):
        g=glyph(ch); print(ch); print('\n'.join(''.join('#' if v else '.' for v in r) for r in g))
