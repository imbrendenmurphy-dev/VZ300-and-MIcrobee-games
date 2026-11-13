"""Illustrated map and parchment reading surfaces at the native pixel grid."""
from PIL import Image,ImageDraw
import dracula_font
from native_detail import Painter,skull
from native_art import PAL

def page(kind,mono=False):
    p=Painter(PAL,(320,256),False);d=ImageDraw.Draw(p.im)
    def paper(box):
        x,y,r,b=box
        p.solid('rectangle',box,11)
        for yy in range(y+5,b-3):
            for xx in (x+1,x+2,x+3,r-3,r-2,r-1):
                if (xx+yy)%3==0:p.solid('point',(xx,yy),0)
        for xx in range(x+5,r-3):
            if xx%3==0:
                p.solid('point',(xx,y+3),0);p.solid('point',(xx,b-3),0)
        for cx,cy in ((x+4,y+3),(r-4,y+3),(x+4,b-3),(r-4,b-3)):
            p.solid('ellipse',(cx-7,cy-6,cx+7,cy+6),11)
            p.arc((cx-5,cy-4,cx+5,cy+4),20,320,0,2)
            p.arc((cx-2,cy-2,cx+2,cy+2),180,350,0)
    gold=tuple(int(v) for v in PAL[11])
    def leaf():
        # A dark leaf inside a gold rule, shared by the story and map pages:
        # light lettering on black reads the same on colour and one-colour
        # screens, with no inverse bars.
        d.rectangle((18,2,301,253),outline=gold,width=2)
        d.rectangle((23,7,296,248),outline=tuple(int(v) for v in PAL[3]))
        for cx,cy in ((18,2),(301,2),(18,253),(301,253)):
            p.solid('ellipse',(cx-6,cy-5,cx+6,cy+5),0)
            p.arc((cx-6,cy-5,cx+6,cy+5),0,359,11,2)
            p.solid('ellipse',(cx-2,cy-2,cx+2,cy+2),9)
        for x in (160,):
            for y in (2,253):
                p.solid('polygon',[(x-10,y),(x,y-2),(x+10,y),(x,y+2)],0)
                p.solid('polygon',[(x-7,y),(x,y-2),(x+7,y),(x,y+2)],9)
        for x in (6,313):
            p.line([(x,20),(x,236)],3,1)
            for y in range(24,236,24):p.solid('polygon',[(x,y),(x-4,y+5),(x,y+10),(x+4,y+5)],11)
    leaf()
    if kind=='story':
        return p.im
    # The castle map: a title, the area's name (drawn at run time, row 6),
    # the live 16x16 grid at cells (6..21, 10..25), a compass, the legend at
    # columns 25 and 27, rows 14..23, and the M: BACK tab at row 27.
    dracula_font.draw(p.im,(160,15),"DRACULA'S CASTLE",14,tuple(PAL[15]),center=True)
    def bat(cx,cy,s):
        p.solid('polygon',[(cx,cy),(cx-2*s,cy-s),(cx-s,cy),(cx-2*s,cy+s//2),(cx,cy+2),(cx+2*s,cy+s//2),(cx+s,cy),(cx+2*s,cy-s)],5)
    bat(54,22,5);bat(266,22,5)
    p.line([(40,42),(280,42)],3,1)
    # grid: a double gold frame with studs, black inside (unexplored)
    d.rectangle((41,73,182,214),outline=gold,width=2)
    d.rectangle((45,77,178,210),outline=tuple(int(v) for v in PAL[3]))
    for cx,cy in ((41,73),(182,73),(41,214),(182,214)):
        p.solid('ellipse',(cx-3,cy-3,cx+3,cy+3),11);p.solid('point',(cx,cy),9)
    d.rectangle((48,80,175,207),fill=(0,0,0))
    # compass rose
    cx,cy=248,86
    p.arc((cx-15,cy-15,cx+15,cy+15),0,359,3,1)
    p.solid('polygon',[(cx,cy-17),(cx+4,cy),(cx,cy+4),(cx-4,cy)],11)
    p.solid('polygon',[(cx,cy+17),(cx+3,cy),(cx-3,cy)],7)
    p.solid('polygon',[(cx-17,cy),(cx,cy-3),(cx,cy+3)],7)
    p.solid('polygon',[(cx+17,cy),(cx,cy-3),(cx,cy+3)],7)
    p.solid('ellipse',(cx-2,cy-2,cx+2,cy+2),9)
    dracula_font.draw(p.im,(cx,cy-29),'N',9,gold,center=True)
    # legend panel and the back tab
    d.rectangle((194,104,298,202),outline=gold,width=1)
    d.rectangle((196,106,296,200),outline=tuple(int(v) for v in PAL[3]))
    d.rectangle((200,212,296,236),outline=gold,width=1)
    for x in (200,296):
        for y in (104,202):p.solid('ellipse',(x-2,y-2,x+2,y+2),11) if x==296 else None
    # a candle at the foot of the page
    for cx in (70,150):
        p.solid('rectangle',(cx-2,226,cx+2,238),7)
        p.solid('polygon',[(cx,216),(cx+3,222),(cx,225),(cx-3,222)],11)
        p.solid('point',(cx,221),9)
        p.line([(cx-6,239),(cx+6,239)],3,1)
    skull(p,110,226,1)
    return p.im
