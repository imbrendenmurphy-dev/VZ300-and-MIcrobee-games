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
    if kind=='story':
        # The 32-column text rectangle remains clean; wear is confined to edges.
        paper((24,1,295,254))
        for y in range(12,246,19):
            p.solid('polygon',[(24,y),(18,y+5),(24,y+10)],11)
            p.solid('polygon',[(295,y),(301,y+7),(295,y+13)],11)
            p.line([(25,y+3),(30,y+5)],3)
            p.line([(289,y+8),(294,y+4)],3)
        for x in (6,309):
            p.line([(x,16),(x,240)],3,2)
            for y in range(20,240,16):p.solid('polygon',[(x,y),(x-4,y+5),(x,y+10),(x+4,y+5)],11)
        return p.im
    # Blue stippled masonry behind a parchment map and separate legend scroll.
    for y in range(8,256,16):
        for x in range(-16 if y%32 else 0,320,32):
            p.shape('rectangle',(x+1,y+1,x+30,y+14),12,3,'stone',None)
    # Fluted columns, side windows and flame bowls.
    for x in (8,304):
        p.shape('rectangle',(x,47,x+8,234),15,7,'stone',15)
        for xx in (x+2,x+5):p.line([(xx,51),(xx,229)],0)
        p.shape('rectangle',(x-6,44,x+14,50),15,10,'stone',15)
        p.shape('rectangle',(x-6,230,x+14,237),15,10,'stone',15)
        p.line([(x+4,178),(x+4,212)],11,3)
        p.solid('polygon',[(x-3,186),(x+10,186),(x+7,192),(x,192)],15)
        p.solid('polygon',[(x-1,185),(x-3,178),(x+4,165),(x+5,173),(x+10,178),(x+8,185)],11)
        p.solid('polygon',[(x+2,184),(x+2,179),(x+5,173),(x+6,183)],9)
    # Small perched guardians: heads, horns, wings and hooked claws.
    for cx in (26,294):
        for side in (-1,1):
            p.shape('polygon',[(cx+side*3,24),(cx+side*12,3),(cx+side*22,2),(cx+side*29,30),(cx+side*18,22),(cx+side*10,35)],15,6-(160-cx)/22,'cloth',15)
            p.line([(cx+side*3,25),(cx+side*20,5)],15)
        p.shape('polygon',[(cx-8,19),(cx-10,10),(cx,18),(cx+10,10),(cx+8,29),(cx+12,40),(cx-12,40)],15,11-(160-cx)/22)
        p.solid('rectangle',(cx-5,22,cx+5,25),0)
        p.solid('point',(cx-3,23),9);p.solid('point',(cx+3,23),9)
        p.line([(cx-4,31),(cx,35),(cx+4,31)],0,2)
    # Header banner and moon/castle vignette.
    p.solid('ellipse',(246,1,277,32),15)
    p.solid('polygon',[(245,32),(245,20),(251,20),(251,11),(255,5),(259,11),(259,19),(265,19),(265,14),(269,9),(273,14),(273,32)],0)
    p.solid('polygon',[(56,28),(70,23),(246,23),(261,29),(253,39),(261,50),(243,56),(71,56),(56,49),(64,39)],0)
    p.line([(56,28),(70,23),(246,23),(261,29),(253,39),(261,50),(243,56),(71,56),(56,49),(64,39),(56,28)],11,2)
    dracula_font.draw(p.im,(80,31),"DRACULA'S",14,tuple(PAL[15]))
    dracula_font.draw(p.im,(184,31),'CASTLE',14,tuple(PAL[15 if mono else 9]))
    # Main map panel: the live 16x16 grid occupies (48,80)..(175,207).
    paper((32,59,190,221))
    p.solid('rectangle',(46,78,177,209),0)
    p.line([(45,77),(178,77),(178,210),(45,210),(45,77)],3)
    paper((194,104,302,207))
    # Hanging MAP plaque and back button, with cell-aligned black text fields.
    for box in ((202,72,294,95),(198,212,301,235)):
        x,y,r,b=box;p.solid('polygon',[(x+8,y),(r-8,y),(r,b//2+y//2),(r-8,b),(x+8,b),(x,(y+b)//2)],0)
        p.line([(x+8,y),(r-8,y),(r,(y+b)//2),(r-8,b),(x+8,b),(x,(y+b)//2),(x+8,y)],13,2)
    for x in (210,286):
        for y in range(56,72,6):p.arc((x,y,x+4,y+7),0,359,11)
    # Skull footer and curling stonework beneath the parchment.
    for x in (57,230):p.arc((x,231,x+34,251),0,330,15,2)
    skull(p,150,237,1)
    for x in (35,283):
        for y in (43,228):
            p.line([(x,y),(x+12,y+10)],10)
            for k in (0,5,10):p.solid('polygon',[(x+k,y+k),(x+k-4,y+k+4),(x+k,y+k+7),(x+k+4,y+k+3)],10)
    return p.im
