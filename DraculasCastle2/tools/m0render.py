# Mini interpreter for the original's picture subroutines -> mode 0 PNG
import pickle,sys,re
from PIL import Image,ImageDraw,ImageFont
lines=pickle.load(open('/home/claude/dc2/orig/lines.pkl','rb'))
L={ln:(s,raw) for ln,s,raw in lines}
COL=[(0,255,0),(255,255,0),(0,0,255),(255,0,0),(255,240,200),(0,255,255),(255,0,255),(255,128,0)]
def run(a,b,name):
    scr=[[32,0]]*512; scr=[[32,0] for _ in range(512)]
    pos=0;col=0
    for ln in sorted(L):
        if ln<a or ln>b: continue
        raw=L[ln][1]; i=0
        # split statements by ':' outside quotes
        st=[];cur=[];q=False
        for c in raw:
            if c==34:q=not q
            if c==58 and not q: st.append(cur);cur=[]
            else: cur.append(c)
        st.append(cur)
        for s in st:
            if not s: continue
            t=s[0]
            if t==0x97: col=int(bytes(s[1:]).decode() or 1)-1  # COLOR
            elif t==0x84: scr=[[32,0] for _ in range(512)];pos=0
            elif t==0xB2:
                j=1
                if j<len(s) and s[j]==64:
                    j+=1;n=''
                    while s[j]!=44:n+=chr(s[j]);j+=1
                    j+=1;pos=int(n)
                semi=False
                while j<len(s):
                    if s[j]==34:
                        j+=1
                        while j<len(s) and s[j]!=34:
                            c=s[j]
                            if pos<512: scr[pos]=[c,col]
                            pos+=1;j+=1
                        j+=1
                        semi = (j<len(s) and s[j]==59)
                        if semi:j+=1
                    else: j+=1
                if not semi: pos=(pos//32+1)*32
                if pos>=512:
                    scr=scr[32:]+[[32,0] for _ in range(32)];pos-=32
    img=Image.new('RGB',(256,192));d=ImageDraw.Draw(img);f=ImageFont.load_default()
    for k,(c,cl) in enumerate(scr):
        x=(k%32)*8;y=(k//32)*12
        if c>=128:
            pat=c&15; cc=COL[(c>>4)&7] if (c&0x70) else COL[cl]
            for qi,(bx,by) in enumerate([(0,0),(4,0),(0,6),(4,6)]):
                on=pat&(8>>qi)
                d.rectangle([x+bx,y+by,x+bx+3,y+by+5],fill=cc if on else (0,0,0))
        else:
            d.rectangle([x,y,x+7,y+11],fill=(0,160,0))
            if c!=32: d.text((x+1,y),chr(c&127) if 32<=(c&127)<127 else '?',fill=(0,40,0),font=f)
    img.resize((512,384),Image.NEAREST).save(name)
for a,b,n in [(17,36,'title'),(50,64,'castle'),(179,184,'sunset'),(187,215,'turnL'),(251,275,'ahead'),(318,336,'grell'),(346,362,'ghoul'),(372,389,'plant'),(399,414,'slime'),(424,441,'zombie'),(451,482,'dracula'),(492,501,'stakes')]:
    run(a,b,'/home/claude/dc2/orig/%s.png'%n)
