"""Native 320x264 Premium PCG artwork, rendered from vector primitives.

No enlarged VZ bitmap is used for the monsters: their original vector drawing
commands are rasterised again at the target resolution with new colour roles.
Every exported cell has exactly two colours; monochrome has its own bitmap.
"""
from pathlib import Path
import sys, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import dracula_font
import native_detail
from functools import lru_cache

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'original/tools'))
import monsters as M

def compress_fast(data):
    """Bounded-chain LZ2 encoder; identical wire format to the game decoder."""
    recent={};out=bytearray();literal=bytearray();i=0
    def flush():
        while literal:
            chunk=literal[:128];del literal[:128];out.append(len(chunk)-1);out.extend(chunk)
    while i<len(data):
        key=data[i:i+3];best=0;offset=0
        if len(key)==3:
            for j in reversed(recent.get(key,[])[-64:]):
                if i-j>4096:continue
                size=3;limit=min(264,len(data)-i)
                while size<limit and data[j+size]==data[i+size]:size+=1
                if size>best:best,offset=size,i-j
                if size==limit:break
        count=best if best>=3 else 1
        if best>=3:
            flush();off=offset-1
            out.extend((0x80|(min(best-3,7)<<4)|(off>>8),off&255))
            if best>=10:out.append(best-10)
        else:
            literal.append(data[i])
            if len(literal)==128:flush()
        for p in range(i,i+count):
            key=data[p:p+3]
            chain=recent.setdefault(key,[]);chain.append(p)
            if len(chain)>64:del chain[0]
        i+=count
    flush();out.extend((0xF0,0,255));return bytes(out)

PAL=np.array([(0,0,0),(160,32,48),(32,144,64),(160,104,40),(32,40,128),(136,40,160),(32,144,160),(176,176,176),
              (72,72,88),(255,80,88),(104,232,104),(255,224,120),(104,112,240),(232,104,232),(104,232,240),(248,240,216)],dtype=np.int32)
HW=np.array([(0,0,0),(192,0,0),(0,192,0),(192,96,0),(0,0,192),(192,0,192),(0,192,192),(192,192,192),
             (96,96,96),(255,64,64),(64,255,64),(255,255,64),(64,64,255),(255,64,255),(64,255,255),(255,255,255)],dtype=np.uint8)
PAIRS=np.array([(a,b) for a in range(16) for b in range(a+1,16)])
DIST=((PAL[:,None,:]-PAL[None,:,:])**2).sum(2)
PAIR_COST=np.minimum(DIST[:,PAIRS[:,0]],DIST[:,PAIRS[:,1]])
BAYER=np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])

def font(size,bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/'+('georgiab.ttf' if bold else 'consola.ttf'),size)

class Canvas:
    roles=(10,15,0,5)
    def __init__(self,w=64,h=44,fill=-1):
        self.w,self.h=w,h
        self.sx,self.sy=2.5,4.0
        self.image=Image.new('RGBA',(round(w*self.sx),round(h*self.sy)),(0,0,0,0))
        if fill!=-1:self.image.paste(self.colour(fill),(0,0,*self.image.size))
    def colour(self,fill):
        if isinstance(fill,int):return tuple(PAL[self.roles[fill]])+(255,)
        a,b,*mode=fill;mix=mode[0] if mode and isinstance(mode[0],int) else 50
        return tuple(((PAL[self.roles[a]]*(100-mix)+PAL[self.roles[b]]*mix)//100).astype(int))+(255,)
    def xy(self,x,y):return (round(x*self.sx),round(y*self.sy))
    def ellipse(self,cx,cy,rx,ry,fill):
        ImageDraw.Draw(self.image).ellipse([self.xy(cx-rx,cy-ry),self.xy(cx+rx,cy+ry)],fill=self.colour(fill))
    def poly(self,pts,fill):ImageDraw.Draw(self.image).polygon([self.xy(x,y) for x,y in pts],fill=self.colour(fill))
    def line(self,x0,y0,x1,y1,fill,w=1):ImageDraw.Draw(self.image).line([self.xy(x0,y0),self.xy(x1,y1)],fill=self.colour(fill),width=max(1,round(w*2.5)))
    def rect(self,x0,y0,x1,y1,fill):ImageDraw.Draw(self.image).rectangle([self.xy(x0,y0),self.xy(x1+0.7,y1+0.7)],fill=self.colour(fill))
    def px(self,x,y,fill):self.rect(x,y,x+.2,y+.2,fill)
    def mirror_x(self,cx=32):
        x=round(cx*self.sx);part=self.image.crop((0,0,x,self.image.height)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        self.image.paste(part,(x,0))
    def outline(self,col,only_into=None):
        mask=self.image.getchannel('A');expanded=mask.filter(ImageFilter.MaxFilter(3))
        back=Image.new('RGBA',self.image.size,self.colour(col));back.putalpha(expanded)
        back.alpha_composite(self.image);self.image=back
    def shift(self,x,y):
        im=Image.new('RGBA',self.image.size);im.alpha_composite(self.image,self.xy(x,y));self.image=im

ROLES=[(6,15,0,5),(8,15,0,7),(15,14,0,12),(8,15,0,7),(9,15,0,13),(2,11,0,10),
       (10,15,0,2),(15,11,0,5),(8,15,0,7),(15,13,0,5),(7,15,0,1),(7,15,0,13)]

@lru_cache(None)
def monster(i,frame):
    import ghoulies
    if i in ghoulies.REDRAWS:
        return ghoulies.monster(i,frame,PAL)
    if i in native_detail.REDRAWS:
        return native_detail.REDRAWS[i](PAL,frame)
    # Keep original pose choreography, but replace the drawing surface.
    source=(ROOT/'original/tools/monsters.py').read_text()
    source=source[:source.index("if __name__ == '__main__':")]
    source=source.replace('c.p = [[T] * W for _ in range(4)] + c.p[:-4]','c.shift(0,4)')
    ns={'__name__':'native_monsters'};exec(source,ns)
    ns['Canvas']=Canvas;Canvas.roles=ROLES[i]
    canvas,_=ns['MONSTERS'][i][1](frame)
    return canvas.image

@lru_cache(None)
def backdrop(area,mono=False):
    if mono:
        # One-colour screens have only brightness to separate a monster from
        # the room, so the room sits well back behind it. Outdoors the sky
        # keeps its stars and moon; only the wall and ground are dimmed.
        im=backdrop(area).copy();top=108 if area==0 else 0
        im.paste(Image.eval(im.crop((0,top,320,264)),lambda v:int(v*.42)),(0,top))
        return im
    if area in range(6):
        return native_detail.backdrop(PAL,area)
    im=Image.new('RGB',(320,264),tuple(PAL[0]));d=ImageDraw.Draw(im)
    tones=[(4,6),(8,7),(3,11),(2,8),(3,7),(1,5)]
    shadow,lit=tones[area]
    d.rectangle((0,11,319,197),fill=tuple(PAL[shadow]//3))
    if area==0:
        d.ellipse((232,23,276,67),fill=tuple(PAL[11]));d.ellipse((223,18,263,58),fill=tuple(PAL[4]//3))
        for x in range(0,320,16):
            d.line((x,90,x,175),fill=tuple(PAL[8]),width=2);d.polygon([(x-3,94),(x,85),(x+3,94)],fill=tuple(PAL[7]))
        for x,y in [(17,149),(279,143),(44,156)]:
            d.rounded_rectangle((x,y,x+18,y+30),radius=6,fill=tuple(PAL[8]));d.line((x+9,y+5,x+9,y+17),fill=tuple(PAL[7]));d.line((x+4,y+10,x+14,y+10),fill=tuple(PAL[7]))
    elif area==2:
        for y in range(22,165,33):
            d.rectangle((0,y+24,319,y+28),fill=tuple(PAL[3]))
            for x in range(3,320,9):
                height=14+(x*7+y)%10;colour=(3,5,6,1,8)[(x//9+y)%5]
                d.rectangle((x,y+24-height,x+5,y+23),fill=tuple(PAL[colour]));d.line((x+1,y+27-height,x+4,y+27-height),fill=tuple(PAL[lit]))
    elif area==4:
        for cx,cy,r in [(35,53,25),(275,67,33),(49,132,18),(272,145,20)]:
            pts=[]
            for a in range(64):
                rr=r if a%4 in (0,3) else r+4;ang=a*math.pi/32
                pts.append((cx+math.cos(ang)*rr,cy+math.sin(ang)*rr))
            d.polygon(pts,fill=tuple(PAL[3]));d.ellipse((cx-r+6,cy-r+6,cx+r-6,cy+r-6),fill=(0,0,0),outline=tuple(PAL[11]),width=1)
            d.line((cx-r+7,cy,cx+r-7,cy),fill=tuple(PAL[7]),width=2);d.line((cx,cy-r+7,cx,cy+r-7),fill=tuple(PAL[7]),width=2)
    else:
        for y in range(11,175,22):
            d.line((0,y,319,y),fill=tuple(PAL[shadow]),width=1)
            for x in range(-22 if (y//22)%2 else 0,320,44):d.line((x,y,x,y+21),fill=tuple(PAL[shadow]),width=1)
        for x in (13,274):
            d.rounded_rectangle((x,28,x+31,151),radius=15,fill=(0,0,0),outline=tuple(PAL[lit]),width=2)
            if area==5:
                d.polygon([(x+16,36),(x+27,58),(x+16,83),(x+4,58)],fill=tuple(PAL[9]));d.line((x+16,36,x+16,139),fill=tuple(PAL[11]))
            elif area==3:
                for xx in range(x+7,x+30,8):d.line((xx,37,xx,145),fill=tuple(PAL[7]),width=2)
            else:d.line((x+16,36,x+16,140),fill=tuple(PAL[12]),width=2)
    d.rectangle((0,176,319,197),fill=tuple(PAL[shadow]//2))
    for x in range(-160,481,40):d.line((160,176,x,198),fill=tuple(PAL[shadow]))
    d.line((0,185,319,185),fill=tuple(PAL[shadow]));d.line((0,197,319,197),fill=tuple(PAL[lit]))
    return im

def half(sp):
    """Halve a cartoon sprite: a 2x2 block keeps its ink line if two of its
    pixels are black, otherwise its commonest colour."""
    a=np.asarray(sp);h,w=a.shape[0]//2,a.shape[1]//2
    out=np.zeros((h,w,4),np.uint8)
    for y in range(h):
        for x in range(w):
            blk=a[y*2:y*2+2,x*2:x*2+2].reshape(4,4)
            solid=blk[blk[:,3]>0]
            if len(solid)<2:continue
            dark=solid[solid[:,:3].sum(1)==0]
            if len(dark)>=2:out[y,x]=(0,0,0,255);continue
            lit=[tuple(p) for p in solid if p[:3].sum()>0]
            out[y,x]=max(set(lit),key=lit.count)
    return Image.fromarray(out,'RGBA')

def logo(im,text,y,scale=3,bands=(15,11,11,9,9,1),drips=False):
    """Big lettering: the display alphabet at triple size, filled in horizontal
    bands that change only on 8-pixel cell rows, a black keyline and drips."""
    m=dracula_font.mask(text);m=m.resize((m.width*scale,m.height*scale),Image.NEAREST)
    x0=160-m.width//2;a=np.asarray(m)>0;px=im.load()
    a=a.copy();a[:,1:]|=a[:,:-1].copy()            # one pixel bolder
    for yy in range(a.shape[0]):
        ink=tuple(int(v) for v in PAL[bands[min(len(bands)-1,((y+yy)//8)-(y//8))]])
        for xx in range(a.shape[1]):
            if a[yy,xx]:px[x0+xx,y+yy]=ink
    # drips of blood from the bottoms of strokes
    red=tuple(int(v) for v in PAL[9]);H=a.shape[0]
    for xx in (range(1,a.shape[1]-1,1) if drips else ()):
        if a[H-1,xx] and not a[H-1,xx-1]:
            n=(xx*7)%5
            if n<2:
                for k in range(4+n*5):
                    for dx in (0,1):px[x0+xx+dx,y+H+k]=red
                px[x0+xx,y+H+4+n*5]=red
    return x0,m.width

def title(mono=False):
    """The castle's cast under the logo. The logo changes colour only on cell
    rows, the moon and castle sit clear of it, and each ghoulie is pasted on
    the cell grid with its own black halo, so every 8x8 cell needs only two
    colours."""
    import ghoulies
    im=Image.new('RGB',(320,264),(0,0,0));d=ImageDraw.Draw(im);px=im.load()
    C=lambda i:tuple(int(v) for v in PAL[i])
    for i in range(90):
        x=(i*73+13)%320;y=(i*37+11)%150
        px[x,y]=C(15 if i%4==0 else 7)
    # crescent moon, top right
    for y in range(4,40):
        for x in range(286,318):
            dx,dy=(x-302)/15.0,(y-21)/13.0
            if dx*dx+dy*dy<1 and (dx+.45)**2+(dy+.25)**2>.72:px[x,y]=C(11)
    for bx,by,sz in ((296,50,4),(282,64,3),(14,22,4),(26,42,3),(10,60,3)):
        d.polygon([(bx,by),(bx-sz*2,by-sz),(bx-sz,by),(bx-sz*2,by+sz//2),(bx,by+2),(bx+sz*2,by+sz//2),(bx+sz,by),(bx+sz*2,by-sz)],fill=C(13))
    # a crimson banner with a dripping lower edge carries the logo
    crimson=C(0 if mono else 1)
    for x in range(40,280):
        bottom=84+int(2*math.sin(x/7.0))
        for y in range(0,bottom):px[x,y]=crimson
        if mono and (x%4==0 or x in (40,279)):
            px[x,0]=px[x,bottom-1]=C(7)
        k=(x*37)%23
        if k<3 and (44<x<84 or 236<x<276):
            n=6+(x*13)%9
            for y in range(bottom,bottom+n):
                for dx in (0,1,2):px[x+dx,y]=crimson
            for dx in (-1,0,1,2,3):px[x+dx,bottom+n]=crimson
    if mono:
        for y in range(0,84,4):px[40,y]=px[279,y]=C(7)
    logo(im,"DRACULA'S",6,bands=(15,11,11,11,9))
    logo(im,'CASTLE II',46,bands=(11,11,11,9,9))
    dracula_font.draw(im,(160,91),'THE CASTLE AWAKENS',11,C(14),center=True)
    # the cast, half size, on the cell grid with black halos
    cast=[(2,0,0,88),(1,2,56,104),(10,2,120,104),(5,0,184,104),(6,2,240,88)]
    for i,f,x,y in cast:
        sp=ghoulies.cellfix(half(ghoulies.monster(i,f,PAL)),PAL)
        im.paste(sp,(x,y),sp)
    return im

def encode(im,mono=False,cell_height=11):
    assert im.width==320 and im.height%cell_height==0
    rgb=np.asarray(im.convert('RGB'),dtype=np.int32)
    idx=((rgb[:,:,None,:]-PAL)**2).sum(3).argmin(2)
    glyphs=bytearray();colours=bytearray();preview=np.zeros((im.height,320,3),np.uint8)
    for ty in range(im.height//cell_height):
        for tx in range(40):
            y0=ty*cell_height
            cell=idx[y0:y0+cell_height,tx*8:tx*8+8]
            if mono:
                # Bright details remain solid; midtones use stable screen-space
                # patterns so shapes survive without a colour monitor.
                lum=(PAL[cell]*np.array([.24,.58,.18])).sum(2)
                yy,xx=np.indices((cell_height,8));threshold=(BAYER[(yy+y0)%4,xx%4]+.5)*12
                bits=(lum>threshold)&(lum>24);bg,fg=0,15
            else:
                hist=np.bincount(cell.ravel(),minlength=16).astype(float);hist[0]*=2
                bg,fg=PAIRS[(hist@PAIR_COST).argmin()]
                bits=DIST[cell,fg]<DIST[cell,bg]
            colours.append(int(bg)*16+int(fg))
            glyphs.extend(np.packbits(bits,axis=1).ravel().tobytes());glyphs.extend(bytes(16-cell_height))
            preview[y0:y0+cell_height,tx*8:tx*8+8]=np.where(bits[:,:,None],HW[fg],HW[bg])
    return bytes(glyphs+colours),Image.fromarray(preview)

def build():
    out=ROOT/'build/native';out.mkdir(parents=True,exist_ok=True)
    def titled(mono):
        ti=title(mono).crop((0,0,320,256))
        ImageDraw.Draw(ti).rectangle((0,184,319,255),fill=(0,0,0))
        credit=dracula_font.mask('VIBED BY BPM 2026')
        credit=credit.resize((credit.width,16),Image.Resampling.NEAREST)
        ImageDraw.Draw(ti).rectangle((84,176,236,191),fill=(0,0,0))
        ti.paste(tuple(PAL[15]),(160-credit.width//2,176,160-credit.width//2+credit.width,192),credit)
        return ti
    def gallery(mono):
        images=[('title',titled(mono))]
        for i,(name,*_) in enumerate(M.MONSTERS):
            for frame in range(3):
                im=backdrop(M.HOME_BBG.get(name,0),mono).crop((0,0,320,256));sp=monster(i,frame)
                im.paste(sp,(80,18),sp)
                d=ImageDraw.Draw(im);d.rectangle((0,200,319,255),fill=(0,0,0))
                dracula_font.draw(im,(12,207),name,22,tuple(PAL[15]))
                dracula_font.draw(im,(12,239),'SPACE: NEXT   P: BACK',11,tuple(PAL[11]))
                images.append((f'monster{i+1:02}-{frame}',im))
        return images
    entries=[];sheet=Image.new('RGB',(320*4,256*3))
    for mono in (False,True):
        for i,(name,im) in enumerate(gallery(mono)):
            raw,pic=encode(im,mono,8);packed=compress_fast(raw)
            stem=name+('-mono' if mono else '-colour')
            (out/(stem+'.lz')).write_bytes(packed);pic.save(out/(stem+'.png'))
            (out/(stem+'.raw')).write_bytes(raw)
            entries.append({'name':stem,'size':len(packed),'raw_size':len(raw)})
            if not mono and i>0 and (i-1)%3==0:sheet.paste(pic,(((i-1)//3%4)*320,((i-1)//3//4)*256))
            print(stem,len(packed),flush=True)
    sheet.save(out/'ghoulies-colour.png')
    for mono in (False,True):
        mode='mono' if mono else 'colour'
        for i,(name,*_) in enumerate(M.MONSTERS):
            for frame in range(4):
                im=backdrop(M.HOME_BBG.get(name,0),mono).crop((0,0,320,256))
                if frame<3:
                    sp=monster(i,frame);im.paste(sp,(80,18),sp)
                ImageDraw.Draw(im).rectangle((0,200,319,255),fill=(0,0,0))
                panel=ImageDraw.Draw(im)
                panel.line((1,199,318,199),fill=tuple(PAL[11]))
                panel.line((1,249,318,249),fill=tuple(PAL[11]))
                panel.line((1,199,1,249),fill=tuple(PAL[11]))
                panel.line((318,199,318,249),fill=tuple(PAL[11]))
                for x in (5,310):
                    for y in (204,220,236):
                        panel.polygon([(x,y),(x+3,y+4),(x,y+8),(x-3,y+4)],outline=tuple(PAL[12]))
                raw,pic=encode(im,mono,8)
                stem=f'battle{i+1:02}-{frame}-{mode}'
                (out/(stem+'.raw')).write_bytes(raw);pic.save(out/(stem+'.png'))
    (out/'manifest.json').write_text(json.dumps(entries,indent=2))

if __name__=='__main__':build()
