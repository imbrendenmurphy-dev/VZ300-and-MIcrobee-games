"""Native-pixel redraws: material-specific stipple, carved forms and theatrical faces.

These shapes are authored directly at the Microbee's pixel size. They do not
scale or filter the VZ sprites. Palette indices are supplied by native_art.
"""
import math
import numpy as np
from PIL import Image,ImageDraw

ORDER=np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])

class Painter:
    def __init__(self,palette,size=(160,176),transparent=True):
        self.pal=palette
        self.im=Image.new('RGBA' if transparent else 'RGB',size,(0,0,0,0) if transparent else (0,0,0))
    def colour(self,i):return tuple(int(v) for v in self.pal[i])+( (255,) if self.im.mode=='RGBA' else ())
    def shape(self,kind,box,ink=15,density=16,material='stone',outline=0,width=1):
        mask=Image.new('L',self.im.size);d=ImageDraw.Draw(mask)
        getattr(d,kind)(box,fill=255)
        yy,xx=np.indices((self.im.height,self.im.width))
        if material=='cloth':rank=(xx+2*yy)%4*4
        elif material=='spectral':rank=ORDER[yy%4,xx%4]
        elif material=='flesh':rank=((xx%5)*3+(yy%7)*5)%16
        else:rank=((xx%8)*5+(yy%8)*3)%16
        # Bright upper-left planes give way to carved, stippled shadows.
        level=np.clip(density+(self.im.width/2-xx)/22-(yy-self.im.height/2)/35,2,16)
        pixels=np.where((rank<level)[:,:,None],np.array(self.colour(ink)),np.array(self.colour(0))).astype('uint8')
        self.im.paste(Image.fromarray(pixels,self.im.mode),(0,0),mask)
        if outline is not None:getattr(ImageDraw.Draw(self.im),kind)(box,outline=self.colour(outline),width=width)
    def line(self,points,ink=15,width=1):ImageDraw.Draw(self.im).line(points,fill=self.colour(ink),width=width)
    def solid(self,kind,box,ink):getattr(ImageDraw.Draw(self.im),kind)(box,fill=self.colour(ink))
    def arc(self,box,start,end,ink=15,width=1):ImageDraw.Draw(self.im).arc(box,start,end,fill=self.colour(ink),width=width)

def skull(p,x,y,scale=1):
    p.solid('ellipse',(x,y,x+10*scale,y+9*scale),15)
    p.solid('rectangle',(x+2*scale,y+6*scale,x+8*scale,y+11*scale),15)
    for dx in (2,6):p.solid('rectangle',(x+dx*scale,y+3*scale,x+(dx+2)*scale,y+5*scale),0)
    p.line([(x+5*scale,y+6*scale),(x+4*scale,y+8*scale)],0,scale)
    for dx in (3,5,7):p.line([(x+dx*scale,y+9*scale),(x+dx*scale,y+11*scale)],0,scale)

def gargoyle(pal,frame):
    p=Painter(pal);lift=(0,-3,-8)[frame]
    for side in (-1,1):
        def pts(v):return [(80+side*x,y) for x,y in v]
        wing=pts([(10,59),(54,12+lift),(68,17+lift),(78,53),(79,108),(65,88),(51,103),(42,80),(29,98),(19,74)])
        p.shape('polygon',wing,13,9,'cloth',15,1)
        for tip in ((54,12+lift),(78,53),(65,88),(51,103),(29,98)):
            p.line(pts([(10,61),tip]),0,4);p.line(pts([(10,60),tip]),15,1)
        p.arc((8 if side<0 else 96,44,64 if side<0 else 152,112),190,310,5)
    # Crouched haunches, shoulders and tapering, jointed forearms.
    p.shape('polygon',[(62,62),(99,61),(108,101),(101,137),(57,137),(51,101)],15,11)
    p.shape('ellipse',(39,100,73,151),15,11)
    p.shape('ellipse',(86,98,124,151),15,9)
    p.shape('ellipse',(57,68,82,98),15,15)
    p.shape('ellipse',(81,68,103,98),15,12)
    for y in (99,109,119):
        p.arc((65,y-6,98,y+9),10,170,0,2);p.line([(69,y),(76,y+2)],15)
    for side in (-1,1):
        reach=8 if frame==2 else 0
        poly=[(80+side*18,70),(80+side*(29+reach),83),(80+side*(22+reach),119),(80+side*(27+reach),142),(80+side*17,145),(80+side*12,119)]
        p.shape('polygon',poly,15,13)
        p.line([(80+side*20,82),(80+side*(21+reach),112)],0,2)
        for claw in range(3):
            x=80+side*(20+reach)+claw*4-4
            p.shape('polygon',[(x,136),(x+3,139),(x+5,151),(x+1,148)],15,16)
        for toe in range(3):
            x=80+side*29+toe*5-6
            p.shape('polygon',[(x,143),(x+4,143),(x+7,153),(x,151)],15,16)
    # Large pointed ears, carved brow, isolated red/black eye cells.
    hy=-3 if frame==2 else 0
    for side in (-1,1):
        p.shape('polygon',[(80+side*12,33+hy),(80+side*35,12+hy),(80+side*25,40+hy),(80+side*16,46+hy)],15,14)
    p.shape('polygon',[(65,29+hy),(92,29+hy),(103,43+hy),(97,64+hy),(81,74+hy),(62,62+hy),(57,43+hy)],15,13)
    p.line([(66,30+hy),(80,36+hy),(93,30+hy)],0,2)
    for x in (64,88):
        p.solid('rectangle',(x,38,x+7,45),0)
        p.solid('polygon',[(x,39),(x+7,41),(x+5,44),(x+2,43)],9)
        if frame==1:p.line([(x,39),(x+7,41)],15)
    p.shape('polygon',[(78,43),(83,43),(88,53),(76,54)],15,15)
    p.solid('polygon',[(68,56+hy),(93,56+hy),(90,68+hy+(frame==2)*4),(78,72+hy),(68,65+hy)],0)
    for x in (71,88):p.solid('polygon',[(x,57+hy),(x+3,57+hy),(x+1,65+hy)],15)
    p.line([(76,68+hy),(83,69+hy),(88,65+hy)],15)
    # Layered plinth, chiselled scrollwork and a central skull.
    p.shape('polygon',[(35,152),(124,152),(132,158),(27,158)],15,12)
    p.shape('rectangle',(31,159,128,175),15,6)
    p.line([(29,158),(130,158)],15,2);p.line([(33,173),(126,173)],15)
    for x in (40,100):
        p.arc((x,161,x+19,176),180,350,15,2);p.arc((x+5,163,x+15,173),0,250,15)
    skull(p,74,161)
    return p.im

def ghost(pal,frame,phase=None):
    p=Painter(pal);sway=(0,3,-3)[frame] if phase is None else (0,1,3,4,3,1,-1,-2)[phase]
    outline=[(80,8),(94,11),(106,24),(110,48),(120,68),(135,85),(145,112),(131,105),(126,122),
             (115,109),(111,143),(102+sway,166),(91,151),(82+sway,174),(70,151),(58+sway,167),(50,145),
             (43,116),(31,128),(33,109),(16,114),(26,90),(43,71),(50,46),(55,23),(66,12)]
    p.shape('polygon',outline,15,13,'spectral',None)
    for x in (53,66,92,106):
        p.line([(x,65),(x+sway,109),(x+sway//2-3,148)],0,2)
        p.line([(x-3,69),(x-2+sway,106),(x+sway//2-6,145)],15)
    # Use cyan in entire edge cells, keeping white/black face cells distinct.
    arr=np.asarray(p.im).copy();yy,xx=np.indices(arr.shape[:2])
    light=(arr[:,:,:3].sum(2)>0)&(arr[:,:,3]>0)
    cyan=((xx//8<7)|(xx//8>12))&light
    arr[cyan,:3]=pal[14];p.im=Image.fromarray(arr,'RGBA')
    for x in (63,87):
        eye=59 if frame!=1 else 49
        if phase is not None:eye=(59,59,57,51,41,51,57,59)[phase]
        p.solid('ellipse',(x,33,x+12,eye),0)
        if frame==2:p.solid('rectangle',(x+4,39,x+6,43),15)
    p.solid('ellipse',(69,68,94,98+(frame==2)*7),0)
    p.solid('rectangle',(72,86,79,93),0)
    p.solid('ellipse',(74,88,78,92),9)
    for x,y in ((37,127),(121,140),(55,172)):
        p.line([(x-2,y),(x+2,y)],14);p.line([(x,y-2),(x,y+2)],14)
    if phase is not None:
        shifted=Image.new('RGBA',p.im.size)
        shifted.alpha_composite(p.im,(0,(0,-1,-2,-1,0,1,2,1)[phase]))
        return shifted
    return p.im

def grell(pal,frame):
    p=Painter(pal)
    for k in range(7):
        pts=[]
        for j in range(17):
            y=83+j*5;x=43+k*12+math.sin(j*.38+k+frame*.7)*(4+j*.6)
            pts.append((round(x),y))
        p.line(pts,0,11);p.line(pts,13,7)
        p.line([(x-2,y) for x,y in pts],9,2)
        for j,(x,y) in enumerate(pts[2::2]):
            p.solid('ellipse',(x-1,y-1,x+1,y+1),11 if (j+k)%3==0 else 0)
    p.shape('ellipse',(28,8,132,105),13,12,'flesh',0,2)
    for x,y in ((41,22),(58,13),(97,14),(118,29),(35,66),(121,73)):
        p.arc((x-7,y-5,x+9,y+11),20,290,9,2)
    p.shape('ellipse',(39,19,121,94),15,16,'flesh',0,3)
    iris=80+(frame-1)*5
    p.shape('ellipse',(iris-18,31,iris+18,82),13,14,'flesh',0,1)
    p.solid('polygon',[(iris,33),(iris+6,48),(iris+3,74),(iris,81),(iris-4,66),(iris-5,46)],0)
    p.solid('ellipse',(iris-10,35,iris-3,42),15)
    if frame==1:
        p.shape('polygon',[(40,28),(61,19),(101,19),(120,32),(110,40),(83,32),(54,39)],13,12,'flesh',0,2)
    p.shape('polygon',[(70,94),(88,94),(82,112+(frame==2)*5),(76,106)],11,13,'stone',0,1)
    return p.im

def dracula(pal,frame):
    p=Painter(pal);flare=7 if frame==2 else 0
    p.shape('polygon',[(54,54),(106,54),(126+flare,98),(148,167),(116,161),(92,172),(70,169),(44,174),(12,166),(34-flare,99)],13,5,'cloth',0,2)
    for side in (-1,1):
        p.shape('polygon',[(80+side*14,59),(80+side*47,30),(80+side*64,44),(80+side*31,77)],9,13,'cloth',0,2)
        p.line([(80+side*47,32),(80+side*61,44),(80+side*29,72)],15)
        p.shape('polygon',[(80+side*20,82),(80+side*(41+flare),119),(80+side*58,164),(80+side*26,156)],9,7,'cloth',0)
        for k in range(3):p.line([(80+side*(15+k*5),90),(80+side*(26+k*9),165)],13,2)
    p.shape('polygon',[(66,59),(94,59),(101,144),(88,166),(72,166),(59,144)],15,5,'cloth',0)
    p.solid('polygon',[(67,62),(80,75),(93,62),(87,91),(72,91)],15)
    p.solid('polygon',[(72,72),(80,76),(88,72),(87,82),(80,78),(73,82)],9)
    for y in (99,113,127,141):p.solid('ellipse',(78,y,81,y+3),11)
    for side in (-1,1):
        handx=80+side*(49+flare);handy=(79,77,62)[frame]
        p.shape('polygon',[(80+side*20,73),(handx,handy+16),(handx+side*8,handy+6),(80+side*30,64)],13,8,'cloth',0)
        p.shape('ellipse',(handx-7,handy,handx+7,handy+13),15,15)
        for k in range(4):
            x=handx-6+k*4;p.line([(x,handy+5),(x-2,handy-5),(x-5,handy-3)],0,4)
            p.line([(x,handy+5),(x-2,handy-5),(x-5,handy-3)],15,2)
    p.shape('polygon',[(65,11),(94,11),(101,33),(92,55),(80,64),(67,55),(58,32)],15,15)
    for side in (-1,1):p.shape('polygon',[(80+side*17,26),(80+side*28,22),(80+side*20,40)],15,13)
    p.solid('polygon',[(62,12),(77,5),(94,10),(99,28),(88,18),(80,29),(72,18),(60,29)],0)
    p.line([(67,12),(76,9),(89,12)],12)
    for x in (64,88):
        p.solid('rectangle',(x,30,x+7,37),0);p.line([(x+1,33),(x+6,34)],9,2)
    p.line([(78,36),(75,44),(83,44)],0,2)
    p.solid('polygon',[(69,48),(92,47),(88,57+(frame==2)*3),(78,59),(70,54)],0)
    for x in (72,86):p.solid('polygon',[(x,49),(x+3,49),(x+1,56)],15)
    return p.im

def backdrop(pal,area):
    p=Painter(pal,(320,264),False)
    if area==0:
        p.shape('ellipse',(253,12,292,51),11,15,'spectral',None)
        for x in range(7,320,17):
            p.line([(x,108),(x,169)],12,2)
            p.solid('polygon',[(x,100),(x-4,111),(x+4,111)],12)
        for y in (121,151):p.line([(0,y),(319,y)],12,2)
        for x,y in ((21,136),(264,139),(53,151)):
            p.shape('rounded_rectangle',(x,y,x+27,181),15,5,'stone',12)
            p.line([(x+13,y+8),(x+13,y+29)],15,2);p.line([(x+6,y+17),(x+20,y+17)],15,2)
        for x in (9,307):
            p.line([(x,163),(x+(-1 if x>100 else 1)*6,82),(x,21)],15,2)
            for y in (35,59,83):
                p.line([(x,y+24),(x+19,y+8),(x+26,y-8)],12,2)
                p.line([(x,y+9),(x-17,y-4)],12,2)
        for y in range(177,200):
            for x in range(320):
                if (x*7+y*13)%19<3:p.solid('point',(x,y),12 if y%3 else 15)
        return p.im
    ink={1:12,2:3,3:6,4:3,5:13}[area]
    for y in range(16,176,16):
        for x in range(-16 if y%32 else 0,320,32):
            p.shape('rectangle',(x+1,y+1,x+30,y+14),ink,3,'stone',None)
            p.line([(x+2,y+2),(x+28,y+2)],ink)
            p.line([(x+1,y+4),(x+1,y+13)],ink)
            if (x//32+y//16)%3==0:p.line([(x+20,y+3),(x+17,y+7),(x+21,y+10)],0)
    # Perspective flagstones, repeated texture rather than random grain.
    for y in range(176,200,8):
        p.line([(0,y),(319,y)],ink)
        for x in range(0,320,32):
            p.shape('polygon',[(x,y+1),(x+26,y+1),(x+32,y+6),(x+3,y+6)],ink,5,'stone',None)
    if area==2:
        for y in (32,80,128):
            for x in list(range(0,80,8))+list(range(240,320,8)):
                colour=(9,13,14,11,6)[(x//8+y//16)%5]
                height=24+(x//8%2)*8
                p.solid('rectangle',(x+1,y+32-height,x+6,y+31),colour)
                for yy in (y+4,y+24):p.line([(x+1,yy),(x+6,yy)],0)
                p.line([(x+4,y+3),(x+4,y+27)],0)
            p.line([(0,y+33),(79,y+33)],11,2);p.line([(240,y+33),(319,y+33)],11,2)
        skull(p,18,170)
        for x,c in ((51,13),(272,14),(294,9)):
            p.shape('ellipse',(x,177,x+12,190),c,12,'flesh',0)
            p.solid('rectangle',(x+4,170,x+8,180),c);p.line([(x+3,170),(x+9,170)],11)
    else:
        for x in (8,280):
            p.solid('rounded_rectangle',(x,32,x+31,151),0)
            p.arc((x,32,x+31,63),180,360,11 if area==1 else 13,2)
            p.line([(x,48),(x,151),(x+31,151),(x+31,48)],11 if area==1 else 13,2)
            glass=12 if area==1 else 9
            for yy in range(48,144,8):
                p.shape('rectangle',(x+8,yy,x+23,yy+7),glass,10,'spectral',None)
            p.line([(x+15,48),(x+15,143)],0,2)
        # Distant castle and moon behind a mullioned centre window.
        p.solid('rounded_rectangle',(112,16,207,88),0)
        p.arc((112,16,207,88),180,360,15,2)
        p.shape('rectangle',(120,48,199,86),12,8,'spectral',None)
        p.solid('ellipse',(155,24,184,53),15)
        for x,h in ((139,18),(151,27),(165,21),(180,32)):
            p.solid('rectangle',(x,85-h,x+7,87),0)
            p.solid('polygon',[(x-2,85-h),(x+3,77-h),(x+9,85-h)],0)
        p.line([(160,17),(160,88)],0,3);p.line([(113,56),(206,56)],0,3)
        for x in (48,256):
            p.shape('polygon',[(x,32),(x+15,32),(x+15,75),(x+7,84),(x,75)],9,10,'cloth',11,1)
            p.line([(x+7,45),(x+7,69)],0,3);p.line([(x+3,53),(x+12,53)],0,3)
            flame=[(x,118),(x-2,109),(x+4,99),(x+2,90),(x+10,98),(x+9,106),(x+15,101),(x+14,115),(x+9,121)]
            p.shape('polygon',flame,11,14,'flesh',None)
            p.solid('polygon',[(x+3,117),(x+5,109),(x+8,104),(x+12,117)],9)
            p.shape('polygon',[(x-3,121),(x+18,121),(x+13,129),(x+2,129)],15,8)
            p.shape('rectangle',(x+5,130,x+10,165),15,8)
            p.line([(x,166),(x+15,166)],15,2)
        for anchor in (40,248):
            for k in range(7):
                x=anchor+k*4;y=16+(k%3)*4
                p.line([(x,16),(x+2,y+10)],10)
                p.solid('polygon',[(x,y),(x-3,y+5),(x,y+8),(x+3,y+3)],10)
    if area==4:
        for cx,cy,r in ((39,47,22),(279,48,24),(38,137,27),(280,139,20)):
            p.arc((cx-r,cy-r,cx+r,cy+r),0,359,11,4)
            for a in range(0,360,45):
                vx=math.cos(math.radians(a));vy=math.sin(math.radians(a))
                p.line([(cx+vx*6,cy+vy*6),(cx+vx*(r+4),cy+vy*(r+4))],11,3)
            p.solid('ellipse',(cx-4,cy-4,cx+4,cy+4),15)
    if area==3:
        for x in range(8,320,24):
            h=8+(x*7)%29
            p.solid('polygon',[(x,16),(x+9,16),(x+5,16+h)],10)
            p.line([(x+5,20),(x+5,12+h)],2)
    return p.im

def bat(pal,frame,lord=False):
    p=Painter(pal);lift=(0,-8,12)[frame]
    for side in (-1,1):
        def pts(v):return [(80+side*x,y) for x,y in v]
        p.shape('polygon',pts([(10,62),(48,12+lift),(72,24+lift),(79,101+lift),(64,82),(51,111),(39,93),(23,124),(14,101)]),13,8,'cloth',15,1)
        for tip in ((48,12+lift),(72,24+lift),(64,82),(51,111),(23,124)):
            p.line(pts([(12,67),tip]),0,4);p.line(pts([(12,66),tip]),13,2)
        p.line(pts([(11,65),(47,11+lift),(69,21+lift)]),15)
    p.shape('polygon',[(63,52),(96,52),(100,100),(86,145),(79,155),(70,140),(60,99)],13,10,'flesh',0)
    for y in range(81,135,8):p.line([(69,y),(80,y+5),(91,y)],0,2)
    p.shape('polygon',[(60,22),(74,48),(85,48),(101,20),(96,69),(83,84),(66,70)],13,13,'flesh',15)
    for x in (65,88):
        p.solid('rectangle',(x,54,x+7,61),0);p.line([(x+1,56),(x+6,58)],9 if lord else 11,2)
    p.solid('polygon',[(70,66),(90,66),(87,78),(80,82),(72,76)],0)
    for x in (72,86):p.solid('polygon',[(x,67),(x+3,67),(x+1,74)],15)
    for side in (-1,1):p.line([(80+side*5,139),(80+side*13,152),(80+side*8,157)],15,2)
    if lord:
        p.solid('polygon',[(65,46),(65,31),(74,39),(80,28),(87,39),(95,31),(95,46)],11)
        p.line([(67,44),(93,44)],0,2)
    return p.im

def skeleton(pal,frame,knight=False,king=False):
    p=Painter(pal);lean=(0,2,-3)[frame];x=80+lean
    if king:
        p.shape('polygon',[(58,50),(101,50),(126,164),(91,170),(70,168),(28,165)],13,7,'cloth',15)
        for a in range(5):p.line([(x-14+a*7,70),(39+a*19,163)],13,2)
    # Articulated legs, knees and feet with a dark contour around each bone.
    for side in (-1,1):
        hip=x+side*10;knee=x+side*(18 if frame!=2 else 24);foot=x+side*23
        p.line([(hip,108),(knee,135),(foot,163)],0,9)
        p.line([(hip,108),(knee,135),(foot,163)],15,5)
        p.shape('ellipse',(knee-5,130,knee+5,139),15,12)
        p.shape('polygon',[(foot-4,161),(foot+6,162),(foot+side*12,169),(foot-4,169)],15,14)
    p.shape('polygon',[(x-16,94),(x+17,94),(x+14,113),(x,120),(x-13,111)],15,10)
    p.line([(x,48),(x,105)],15,5)
    for y in range(58,94,9):
        p.arc((x-20,y-7,x+20,y+9),0,180,15,3)
        p.line([(x-19,y+1),(x-15,y+7)],15,2)
    for side in (-1,1):
        elbow=x+side*29;handx=x+side*39;handy=(81,78,55)[frame] if side==1 else 96
        p.line([(x+side*16,54),(elbow,78),(handx,handy)],0,9)
        p.line([(x+side*16,54),(elbow,78),(handx,handy)],15,4)
        p.shape('ellipse',(handx-5,handy-4,handx+5,handy+5),15,15)
    if knight:
        p.shape('polygon',[(x-20,50),(x+20,50),(x+17,96),(x,108),(x-17,96)],15,8)
        p.line([(x,53),(x,96),(x+15,89)],12,2)
        for side in (-1,1):p.shape('ellipse',(x+side*19-9,48,x+side*19+9,66),15,10)
        p.shape('polygon',[(x-15,11),(x,4),(x+17,13),(x+18,39),(x,48),(x-17,38)],15,11)
        p.solid('rectangle',(x-13,23,x+13,29),0)
        p.line([(x,14),(x,41)],12,2)
        for dx in (-10,-5,5,10):p.line([(x+dx,32),(x+dx,36)],0)
    else:
        p.shape('ellipse',(x-17,12,x+17,43),15,15)
        p.solid('rectangle',(x-11,34,x+11,49),15)
        for dx in (-9,8):p.solid('ellipse',(x+dx-5,23,x+dx+4,33),0)
        p.solid('polygon',[(x,33),(x-3,39),(x+3,39)],0)
        for dx in (-8,-3,2,7):p.line([(x+dx,43),(x+dx,49)],0)
    if king:
        p.solid('polygon',[(x-21,18),(x-23,0),(x-12,8),(x,0),(x+12,8),(x+23,0),(x+21,18)],11)
        p.line([(x-18,15),(x+18,15)],0,2)
        p.line([(126,31),(126,164)],11,4);p.shape('ellipse',(116,15,136,35),13,12,'stone',11,2)
    else:
        tip=(8,5,1)[frame];sx=124+(frame==2)*8
        p.shape('polygon',[(sx,tip),(sx+4,tip+12),(sx+3,89),(sx-3,89),(sx-4,tip+12)],15,14,'stone',12)
        p.line([(sx-10,91),(sx+10,91)],11,3);p.line([(sx,92),(sx,106)],11,4)
        p.shape('polygon',[(25,70),(43,62),(58,73),(54,109),(41,124),(27,107)],15,7,'stone',15,2)
        p.line([(41,68),(41,112)],15,3);p.line([(29,86),(53,86)],15,3)
    return p.im

def zombie(pal,frame):
    p=Painter(pal);sway=(0,3,-4)[frame]
    for side in (-1,1):
        x=80+side*16
        p.shape('polygon',[(x-6,110),(x+6,110),(x+side*11,154),(x+side*20,163),(x-5,166),(x-10,151)],10,9,'flesh',0)
    p.shape('polygon',[(59,47),(97,44),(112,112),(99,124),(93,111),(82,132),(74,114),(61,126),(47,112)],13,8,'cloth',0,2)
    for x in (60,71,92,101):p.line([(x,61),(x-5,101),(x+2,116)],0,3)
    for side in (-1,1):
        hx=80+side*(49+(frame==2)*8);hy=72+sway*side
        p.shape('polygon',[(80+side*18,51),(80+side*32,67),(hx,hy),(hx+side*3,hy+10),(80+side*28,81),(80+side*16,66)],10,10,'flesh',0,2)
        for k in range(4):
            x=hx-5+k*4;p.line([(x,hy+3),(x+side*7,hy+9),(x+side*8,hy+19)],0,5)
            p.line([(x,hy+3),(x+side*7,hy+9),(x+side*8,hy+19)],10,2)
    x=79+sway
    p.shape('polygon',[(x-14,9),(x+12,5),(x+22,19),(x+15,45),(x+4,56),(x-14,43),(x-20,22)],10,11,'flesh',0)
    for dx in (-10,10):p.solid('ellipse',(x+dx-6,22,x+dx+4,32),0)
    p.solid('ellipse',(x+6,24,x+10,28),9)
    p.solid('polygon',[(x-10,38),(x+13,35),(x+9,47),(x-6,45)],0)
    for dx in (-5,2,8):p.line([(x+dx,38),(x+dx,42)],15,2)
    p.line([(x-12,15),(x+3,12)],5,3)
    return p.im

def slime(pal,frame):
    p=Painter(pal);h=(0,-5,8)[frame]
    p.shape('ellipse',(16,141,148,172),10,6,'flesh',0)
    p.shape('polygon',[(21,150),(32,129),(34,91+h),(46,69+h),(68,60+h),(95,60+h),(120,77+h),(131,115),(136,143),(148,158),(117,166),(90,162),(68,169),(43,163),(17,164)],10,10,'spectral',10,2)
    for x,y,r in ((43,112,6),(99,90,7),(111,135,11),(60,151,8),(76,113,4)):
        p.shape('ellipse',(x-r,y-r+h,x+r,y+r+h),10,7,'spectral',0,2);p.arc((x-r,y-r+h,x+r,y+r+h),190,260,15,2)
    for x in (59,101):
        p.line([(x,67+h),(x,42+h)],10,5)
        p.solid('ellipse',(x-10,25+h,x+10,45+h),15)
        p.solid('ellipse',(x-3+(frame-1)*2,31+h,x+4+(frame-1)*2,39+h),0)
    p.arc((52,96+h,102,132+h),0,180,0,3)
    p.arc((41,72+h,81,111+h),190,250,15,4)
    return p.im

def bride(pal,frame):
    p=Painter(pal);s=(0,3,-3)[frame]
    p.shape('polygon',[(58+s,25),(80+s,6),(100+s,27),(122,88),(150,166),(117,158),(97,171),(75,168),(48,173),(12,163),(44,88)],15,6,'cloth',15)
    p.shape('polygon',[(67+s,53),(93+s,53),(98,96),(125,166),(102,160),(84,171),(61,165),(32,167),(63,93)],15,12,'cloth',0)
    for x in (45,60,75,90,105):p.line([(80+(x-75)//3,87),(x,165)],0,2)
    for side in (-1,1):
        hx=80+side*(43+(frame==2)*7);hy=(83,80,66)[frame]
        p.shape('polygon',[(80+side*13,57),(80+side*26,75),(hx,hy),(hx,hy+7),(80+side*21,86),(80+side*10,72)],15,14,'cloth',0)
        for k in range(4):p.line([(hx+k*3-5,hy),(hx+k*3-5,hy+12)],15,2)
    p.shape('ellipse',(65+s,19,95+s,56),15,15,'stone',0)
    p.shape('polygon',[(63+s,31),(69+s,13),(88+s,13),(100+s,38),(89+s,25),(80+s,20),(70+s,30)],15,7,'cloth',0)
    for x in (70+s,86+s):p.line([(x,34),(x+5,34)],0,2)
    p.line([(76+s,48),(84+s,48)],0,2)
    for x in (67,76,85,94):p.solid('ellipse',(x+s,16,x+4+s,20),13)
    p.solid('ellipse',(77,63,83,69),13)
    return p.im

REDRAWS={0:bat,1:skeleton,2:ghost,3:gargoyle,4:grell,5:zombie,6:slime,
         7:lambda p,f:skeleton(p,f,king=True),8:lambda p,f:skeleton(p,f,knight=True),
         9:lambda p,f:bat(p,f,lord=True),10:dracula,11:bride}
