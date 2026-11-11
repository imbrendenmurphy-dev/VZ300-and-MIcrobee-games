"""Native 8x8 exploration tiles, perspective pieces and framed text surfaces.

Maps contain PCG references, not scaled VZ pixels. A 32K atlas is loaded per
area. The runtime composites its cell runs from the unchanged game map.
"""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw
import native_art,pcg_validate
import area

ROOT=Path(__file__).resolve().parent.parent
WIDTH=[26,20,12,8,4]
TOP=[-2,0,5,8,10]
BOT=[27,24,20,17,15]

class Atlas:
    def __init__(self,region,mono):
        self.region=region;self.mono=mono;self.glyphs=[];self.lookup={};self.pieces=[]
        self.ink=[10,12,11,7,11,13][region]
        self.add(bytes(8)) # blank always slot zero
    def add(self,rows):
        glyph=bytes(rows)+bytes(8)
        if glyph not in self.lookup:self.lookup[glyph]=len(self.glyphs);self.glyphs.append(glyph)
        return self.lookup[glyph]
    def tile(self,rows,ink=None):
        i=self.add(rows)
        return ((i&127)|128,i>>7,15 if self.mono else (self.ink if ink is None else ink))
    def stone(self,x,y,side=False,kind=0):
        # Repeating masonry joints, chipped edges and sparse stone stipple.
        rows=[0xff,0x80,0x88,0x80,0x81,0x80,0x90,0x80] if (x+y//2)%2 else [0xff,1,0x21,1,0x09,1,1,0x41]
        if y%2:rows=[0,0x80,0x84,0x80,0x81,0x80,0x90,0x80] if x%2 else [0,1,0x11,1,1,0x41,1,1]
        if self.region==2 and kind:rows=[0xff,0xaa,0xaa,0xba,0xaa,0xaa,0xff,0]
        if self.region==4 and kind:rows=[0x18,0x7e,0x66,0xc3,0xc3,0x66,0x7e,0x18]
        ink=self.ink if not side else [2,4,3,8,3,5][self.region]
        if kind and self.region not in (2,4):ink=[7,7,3,6,7,9][self.region]
        return self.tile(rows,ink)
    def sprite(self,name,w,h):
        im=Image.new('1',(40,56));d=ImageDraw.Draw(im)
        if name in ('door','gate','stairs','window'):
            d.rounded_rectangle((3,1,36,55),radius=15,outline=1,width=2)
            if name=='stairs':
                for y in range(28,54,5):d.line((7,y,32,y),fill=1,width=2)
            elif name=='window':
                d.line((20,3,20,53),fill=1,width=2);d.line((5,27,35,27),fill=1,width=2)
                for y in range(9,51,7):d.point((11,y),fill=1);d.point((27,y+2),fill=1)
            else:
                for x in range(8,34,6):d.line((x,12,x,52),fill=1)
                for y in (24,43):d.rectangle((5,y,34,y+2),fill=1)
                d.ellipse((26,31,30,35),fill=1)
        elif name in ('torch','candles'):
            d.polygon([(20,1),(28,18),(23,28),(15,26),(10,17),(17,9)],fill=1)
            d.polygon([(19,10),(23,22),(18,24)],fill=0)
            d.rectangle((10,29,30,32),fill=1);d.rectangle((18,32,22,52),fill=1)
            d.line((12,54,28,54),fill=1,width=2)
        elif name in ('chest','chest_open','coffin','bench','lectern','easel','throne','throne2'):
            if name=='coffin':d.polygon([(12,1),(28,1),(36,15),(30,55),(10,55),(4,15)],outline=1,width=2);d.line((20,12,20,40),fill=1,width=2);d.line((12,22,28,22),fill=1,width=2)
            elif name in ('throne','throne2'):d.rectangle((8,3,31,51),outline=1,width=2);d.rectangle((3,32,36,45),outline=1,width=2);d.line((4,55,4,40,35,40,35,55),fill=1,width=2)
            elif name in ('lectern','easel'):d.polygon([(7,10),(32,8),(35,28),(4,30)],outline=1,width=2);d.line((20,30,20,53,8,55,31,55),fill=1,width=2)
            else:
                d.rounded_rectangle((2,23,37,53),radius=5,outline=1,width=2)
                d.line((3,35,36,35),fill=1,width=2)
                for x in (8,30):d.line((x,25,x,51),fill=1,width=2)
                d.rectangle((17,32,23,41),fill=1)
                if name=='chest_open':d.rectangle((4,25,35,34),fill=0);d.polygon([(3,23),(6,6),(34,6),(37,23)],outline=1,width=2)
        elif name in ('bones','grave','orb','bell','clock','plaque'):
            if name in ('orb','clock'):d.ellipse((2,5,37,40),outline=1,width=2);d.line((20,12,20,24,29,24),fill=1,width=2)
            elif name=='bell':d.polygon([(17,11),(23,11),(31,40),(36,44),(4,44),(9,40)],outline=1,width=2);d.ellipse((17,45,23,51),fill=1)
            elif name=='plaque':d.rectangle((2,13,37,36),outline=1,width=2);d.text((7,17),'RIP',fill=1)
            else:
                if name=='grave':d.rounded_rectangle((5,9,34,54),radius=12,outline=1,width=2)
                d.ellipse((10,20,29,36),fill=1);d.rectangle((14,34,25,40),fill=1)
                for x in (14,23):d.rectangle((x,26,x+3,30),fill=0)
                d.line((6,46,33,53),fill=1,width=3);d.line((6,53,33,46),fill=1,width=3)
        else:
            # Individual silhouettes for figures/statues, with face and folds.
            if name in ('angel','gargoyle','batlord'):
                d.polygon([(16,21),(0,9),(3,38),(15,32)],outline=1,width=2)
                d.polygon([(24,21),(39,9),(36,38),(25,32)],outline=1,width=2)
            if name=='portrait':d.rectangle((1,1,38,55),outline=1,width=2)
            d.ellipse((13,3,26,17),fill=1)
            for x in (16,23):d.point((x,9),fill=0)
            d.polygon([(12,18),(27,18),(33,51),(7,51)],outline=1,width=2)
            d.line((14,21,18,46,12,50),fill=1);d.line((24,22,22,48),fill=1)
            d.line((12,23,3,35),fill=1,width=2);d.line((27,23,36,35),fill=1,width=2)
            d.line((13,52,10,55,17,55),fill=1);d.line((25,52,29,55,22,55),fill=1)
            if name=='armour':d.rectangle((12,3,27,14),outline=1);d.line((35,12,35,49),fill=1,width=2)
        return im.resize((w,h),Image.Resampling.NEAREST)
    def stamp(self,cells,name,d,l,ink):
        if not d:return
        w=[0,40,24,16][d];h=[0,56,32,24][d]
        cx=13+l*WIDTH[d];x0=cx-w//16;y0=BOT[d]-h//8
        im=self.sprite(name,w,h)
        for y in range(h//8):
            for x in range(w//8):
                xx,yy=x0+x,y0+y
                if not (0<=xx<26 and 0<=yy<24):continue
                rows=[sum(bool(im.getpixel((x*8+px,y*8+py)))<<(7-px) for px in range(8)) for py in range(8)]
                cells[yy*40+xx]=self.tile(rows,ink)
    def wall(self,d,l,kind):
        cells={}
        if d and abs(l)<(3 if d==3 else 2):
            a=13-WIDTH[d]//2+l*WIDTH[d];b=a+WIDTH[d]
            for y in range(max(0,TOP[d]),min(24,BOT[d])):
                for x in range(max(0,a),min(26,b)):cells[y*40+x]=self.stone(x,y,False,kind)
        if l and (abs(l)==1 or (abs(l)==2 and d>=2)):
            k=abs(l)-.5;a=13-k*WIDTH[d];b=13-k*WIDTH[d+1]
            for x in range(max(0,math.floor(a)),min(26,math.ceil(b))):
                f=max(0,min(1,(x+.5-a)/(b-a)))
                top=round(TOP[d]*(1-f)+TOP[d+1]*f);bottom=round(BOT[d]*(1-f)+BOT[d+1]*f)
                for y in range(max(0,top),min(24,bottom)):
                    xx=x if l<0 else 25-x;cells[y*40+xx]=self.stone(xx,y,True,kind)
        return cells
    def base(self,mode):
        cells={i:self.tile(bytes(8),0) for i in range(1280)}
        if mode==0:
            for y in range(24):
                for x in range(26):
                    rows=[0]*8
                    if y>12:
                        rows=[0x11 if (x+y)%2 else 0x44,0,0,0,0,0,0,0xff if y%3==0 else 0]
                    elif self.region==0 and (x*11+y*7)%23==0:rows[2]=0x08
                    cells[y*40+x]=self.tile(rows,[2,4,3,8,3,5][self.region])
            if self.region==0:
                moon=Image.new('1',(24,24));d=ImageDraw.Draw(moon)
                d.ellipse((0,0,23,23),fill=1);d.ellipse((10,-2,26,18),fill=0)
                for yy in range(3):
                    for xx in range(3):
                        rows=[sum(bool(moon.getpixel((xx*8+x,yy*8+y)))<<(7-x) for x in range(8)) for y in range(8)]
                        cells[(yy+2)*40+xx+16]=self.tile(rows,11)
                for x in range(8,18):
                    for y in range(8+(x%3),13):
                        cells[y*40+x]=self.tile([0x7e,0x7e,0x66,0x66,0x7e,0x7e,0x7e,0xff],4)
            else:
                for x in range(8,18):cells[12*40+x]=self.tile([0,0,0,0,0xff,0,0,0],self.ink)
            for y in range(26):cells[y*40+26]=self.tile([0x18]*8,11)
            for x in range(40):cells[25*40+x]=self.tile([0xff,0,0x55,0,0,0,0,0],11)
        else:
            for x in range(40):
                for y in (0,31):cells[y*40+x]=self.tile([0xff,0x81,0x5a,0x24,0x24,0x5a,0x81,0xff],11)
            for y in range(1,31):
                for x in (0,39):cells[y*40+x]=self.tile([0x18,0x24,0x42,0x81,0x81,0x42,0x24,0x18],self.ink)
        return cells
    def encode_piece(self,cells):
        data=bytearray()
        for y in range(32):
            xs=sorted(i%40 for i in cells if i//40==y)
            while xs:
                left=xs.pop(0);run=[cells[y*40+left]]
                while xs and xs[0]==left+len(run):run.append(cells[y*40+xs.pop(0)])
                data.append(len(run));data.extend((y*40+left).to_bytes(2,'little'))
                for plane in range(3):data.extend(t[plane] for t in run)
        return bytes(data+b'\0')
    def build(self,surface=None):
        ad=area.AREAS[self.region]
        decors,objects=ad.decors,ad.objects
        pixels=not surface and self.region<2
        if surface:
            from world_pages import page
            raw,preview=native_art.encode(page(surface,self.mono),self.mono,8)
            cells={}
            for i in range(1280):
                glyph=self.add(raw[i*16:i*16+8]);cells[i]=((glyph&127)|128,glyph>>7,raw[20480+i])
            pieces=[cells,cells,cells]+[{} for _ in range(40)]
            decors,objects=[],[]
            preview.save(ROOT/'build/world'/(f'{surface}-base-'+('mono' if self.mono else 'colour')+'.png'))
        else:
            pieces=[self.base(i) for i in range(3)]
            for kind in range(2):
                for d in range(4):
                    for l in range(-2,3):pieces.append({} if pixels else self.wall(d,l,kind))
        # Each decor/object has 20 positions, matching d*5+l+2.
        for name in decors+objects:
            for d in range(4):
                for l in range(-2,3):
                    c={}
                    if not pixels and d and (l==0 or (d>=2 and abs(l)==1)):
                        self.stamp(c,name,d,l,11 if name in ('torch','candles','door','gate','stairs','chest','chest_open','bell') else 15)
                    pieces.append(c)
        # Map symbol cells share this dictionary; slots written to header.
        icons=[self.tile(rows,ink) for rows,ink in [([0]*8,0),([0xff,0x81,0x81,0xbd,0xa5,0xbd,0x81,0xff],12),([0xff,0x81,0xbd,0xa5,0xa5,0xbd,0x81,0xff],11),([0,0,0x18,0x3c,0x3c,0x18,0,0],13),([0,0,0,0x18,0x18,0,0,0],8),([0x18,0x3c,0x7e,0x18,0x18,0x18,0,0],11),([0,0x10,0x18,0x7c,0x7e,0x7c,0x18,0x10],11),([0,0,0x18,0x18,0x18,0x7e,0x3c,0x18],11),([0,8,0x18,0x3e,0x7e,0x3e,0x18,8],11)]]
        icons += [self.tile([0,0x7e,0x7e,0x7e,0x7e,0x7e,0x7e,0],9),self.tile([0,0x7e,0x42,0x42,0x42,0x42,0x7e,0],8),self.tile([0,0x7e,0x7e,0x7e,0x7e,0x7e,0x7e,0],14)]
        if pixels:
            pieces=[{pos:(code,attr+5,col) for pos,(code,attr,col) in c.items()} for c in pieces]
            icons=[(code,attr+5,col) for code,attr,col in icons]
        encoded=[self.encode_piece(c) for c in pieces]
        header=64+2*len(pieces);pcg=b''.join(self.glyphs)
        pos=header+len(pcg);pointers=[];stored={};unique=[]
        for e in encoded:
            if e not in stored:stored[e]=pos;pos+=len(e);unique.append(e)
            pointers.append(stored[e])
        packet=bytearray(64)
        packet[:2]=len(pcg).to_bytes(2,'little');packet[2:4]=header.to_bytes(2,'little')
        packet[4]=len(decors);packet[5]=len(objects)
        packet[44]=5 if pixels else 0
        packet[8:8+len(icons)*3]=bytes(v for t in icons for v in t)
        packet.extend(b''.join(p.to_bytes(2,'little') for p in pointers));packet.extend(pcg);packet.extend(b''.join(unique))
        assert len(self.glyphs)<=1792 and len(packet)<=32768,(self.region,self.mono,len(self.glyphs),len(packet))
        # Independently decode each authored tile through the PCG validator.
        for c in pieces:
            if not c:continue
            full=[c.get(i,(128,0,0)) for i in range(1280)]
            pcg_validate.planes((bytes(10240) if pixels else b'')+pcg,bytes(t[0] for t in full),bytes(t[1] for t in full),bytes(t[2] for t in full),max_glyphs=1792)
        return bytes(packet),{'area':surface or ad.name,'mono':self.mono,'glyphs':len(self.glyphs),'packet_bytes':len(packet),'pieces':len(pieces)}

def build():
    out=ROOT/'build/world';out.mkdir(exist_ok=True)
    reports=[]
    for mono in (False,True):
        for region in range(6):
            packet,report=Atlas(region,mono).build();stem=f'world{region}-'+('mono' if mono else 'colour')
            (out/(stem+'.raw')).write_bytes(packet);(out/(stem+'.lz')).write_bytes(native_art.compress_fast(packet))
            reports.append(report);print(stem,report['packet_bytes'],flush=True)
        for surface in ('story','map'):
            packet,report=Atlas(0,mono).build(surface);stem=f'ui-{surface}-'+('mono' if mono else 'colour')
            (out/(stem+'.raw')).write_bytes(packet);(out/(stem+'.lz')).write_bytes(native_art.compress_fast(packet))
            reports.append(report);print(stem,report['packet_bytes'],flush=True)
    (out/'validation.json').write_text(json.dumps(reports,indent=2))

if __name__=='__main__':build()
