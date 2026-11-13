import math, sys
from PIL import Image
sys.path.insert(0,'.')
import ref3 as R, build_race as B
T = R.build_track()
CSS0 = [(40, 205, 40), (235, 235, 70), (45, 35, 205), (205, 30, 60)]
def setpx(img,x,y,c):
    if 0<=x<128 and 0<=y<64:
        i=y*32+(x>>2); sh=6-2*(x&3); img[i]=(img[i]&~(3<<sh)&255)|(c<<sh)
def getpx(img,x,y): return (img[y*32+(x>>2)]>>(6-2*(x&3)))&3
def text(img,s,x,y,c=1):
    for ch in s:
        g=B.FONT.get(ch,[0]*5)
        for r,bits in enumerate(g):
            for k in range(3):
                if bits&(4>>k): setpx(img,x+k,y+r,c)
        x+=4
def ridge(x):  # skyline height 0..8 over 256 px
    return 2.5+1.8*math.sin(x*2*math.pi/256*3+1)+1.6*math.sin(x*2*math.pi/256*7+2)+1.2*math.sin(x*2*math.pi/256*13)
def skyline(img, fr, split, scroll, ca, cb):
    for y in range(max(R.TOPROW,split-8), split):
        h = split - y
        for x in range(128):
            cl, cr = fr.CL[y], fr.CR[y]
            if cl != 255 and cl-64 <= x <= cr-64: continue
            if h <= ridge((x+scroll)&255)+1:
                c = ca if (x+y)&1 else cb
                if h <= ridge((x+scroll)&255)-1.5: c = ca
                setpx(img,x,y,c)
def frame(st, opt):
    sky = dict(A=[2,2,2,2,2], B=[2,2,3,7,1], C=R.SKY_CSS0)[opt]
    fr,hz = R.render(T, st, sky)
    img = R.compose(fr); R.draw_gates(img, fr)
    split=max(0,min(63,hz))
    hc = (T['H'][st['i']%R.N]+st['theta'])&255
    if opt=='A': skyline(img,fr,split,hc,1,2)
    if opt=='B': skyline(img,fr,split,hc,2,1)
    if opt=='C':
        text(img,"110 4.3FH AUTO",1,2); return img
    text(img,"SPEED 110   LAP 1",1,1); text(img,"TIME  65    POS 4",1,8)
    return img
def toim(img):
    im=Image.new('RGB',(128,64)); im.putdata([CSS0[getpx(img,x,y)] for y in range(64) for x in range(128)])
    return im.resize((512,256),Image.NEAREST)
states=[dict(i=40,f=100,lat=-30,theta=0),dict(i=96,f=0,lat=20,theta=8)]
sheet=Image.new('RGB',(1024+8,3*256+16),(255,255,255))
for col,st in enumerate(states):
    for row,opt in enumerate('CAB'):
        sheet.paste(toim(frame(st,opt)),(col*520,row*264))
sheet.save('hud_mock.png')
