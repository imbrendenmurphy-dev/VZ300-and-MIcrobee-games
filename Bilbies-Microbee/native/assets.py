"""Native Microbee artwork and PCG compiler. No VZ screen pixels as input.

Original level geometry supplies collision only. Every output cell is an
8x16 one-bit PCG glyph and a real Premium ink/paper pair. All eight horizontal
pixel phases are compiled together so scrolling does not rewrite terrain PCG.
"""
from pathlib import Path
import json
import math
import sys
import subprocess
import numpy as np
from collections import Counter
from PIL import Image, ImageDraw, ImageFont

R=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(R/'original-tools'))
import levels, lvlkit

B=R/'build/native'
W,H=1024,224
COMPACT=False
PAL=[(0,0,0),(192,0,0),(0,192,0),(192,192,0),(0,0,192),
     (192,0,192),(0,192,192),(192,192,192),(96,96,96),(255,0,0),
     (0,255,0),(255,255,0),(0,0,255),(255,0,255),(0,255,255),(255,255,255)]


def world(level):
    _,solid=lvlkit.raster(level)
    im=Image.new('P',(W+8,H),6)
    im.putpalette([c for rgb in PAL for c in rgb])
    d=ImageDraw.Draw(im)
    # Restrained patterns keep PCG reuse high through all eight pixel phases.
    for x,y in [(88,22),(210,35),(472,17),(750,31),(924,14)]:
        d.rounded_rectangle((x,y,x+54,y+10),radius=5,fill=7)
    d.ellipse((865,20,890,45),fill=11)
    for x,y in [(0,92),(190,100),(460,85),(770,98)]:
        d.polygon([(x,y+32),(x+86,y),(x+185,y+32)],fill=4)
    # Gum trees: pale branching trunks and broad, irregular crowns.
    for x in [66,562,930]:
        d.line([(x,176),(x-3,105),(x-20,80)],fill=8,width=5)
        d.line([(x+1,175),(x-1,106),(x-18,81)],fill=7,width=2)
        d.line([(x-2,123),(x+24,87)],fill=7,width=2)
        for dx,dy,rx in [(-26,0,30),(14,-9,33),(44,7,28)]:
            d.ellipse((x+dx-rx,64+dy,x+dx+rx,93+dy),fill=2)
            # Open eucalyptus foliage, with fine twigs rather than solid blobs.
            for leaf in range(0,rx*2,9):
                yy=70+dy+(leaf%11)
                d.line((x+dx-rx+leaf,yy,x+dx-rx+leaf+5,yy-4),fill=6,width=1)
        d.line((x-1,112,x-28,88),fill=7,width=1)
        d.line((x+5,109,x+36,83),fill=7,width=1)
    # Native artist source; compiler performs the RGBI/cell encoding. The
    # original generation is retained unchanged, with build-time raster data
    # sized for the Microbee's tall display pixels (approximately 1:2).
    house_source=R/'native/art/homestead-source.png'
    if house_source.exists():
        house=Image.open(house_source).convert('RGBA')
        house=house.crop(house.getchannel('A').getbbox()).resize((312,48),Image.Resampling.NEAREST)
        rgba=np.array(house)
        rgb=rgba[:,:,:3].astype(np.int32)
        palette=np.array(PAL,dtype=np.int32)
        ix=np.argmin(np.sum((rgb[:,:,None,:]-palette[None,None,:,:])**2,axis=3),axis=2).astype(np.uint8)
        indexed=Image.fromarray(ix,'P');indexed.putpalette([c for rgb in PAL for c in rgb])
        x=220
        ys=[yy for yy in range(80) if solid[yy][(x+156)//2]]
        base=64+2*(ys[0] if ys else 60)
        im.paste(indexed,(x,base-48),Image.fromarray((rgba[:,:,3]>=128).astype(np.uint8)*255))
    # Deterministic construction reference remains available if the artist
    # asset is absent; it is not used when the asset above is installed.
    x,y=268,128
    if house_source.exists():
        x,y=-500,-500
    d.rectangle((x,y,x+188,y+48),fill=7)
    for yy in range(y+2,y+47,5):d.line((x,yy,x+188,yy),fill=8)
    d.polygon([(x-12,y),(x+20,y-27),(x+161,y-27),(x+198,y)],fill=8)
    for yy in range(y-22,y-1,3): d.line((x+20,yy,x+161,yy),fill=7)
    d.line((x-12,y,x+198,y),fill=0,width=1)
    d.rectangle((x+145,y-45,x+154,y-20),fill=7)
    d.rectangle((x-7,y+17,x+196,y+20),fill=8)
    d.line((x-7,y+17,x+196,y+17),fill=15)
    for xx in range(x+10,x+187,28):
        d.rectangle((xx,y+20,xx+2,y+48),fill=0)
        d.line((xx,y+20,xx,y+48),fill=7)
    d.line((x+9,y+36,x+186,y+36),fill=8)
    for xx in range(x+11,x+186,7):d.line((xx,y+36,xx,y+47),fill=8)
    for xx in [x+23,x+61,x+128,x+162]:
        d.rectangle((xx,y+4,xx+14,y+15),fill=0)
        d.line((xx+7,y+4,xx+7,y+15),fill=7)
    d.rectangle((x+91,y+4,x+108,y+47),fill=1)
    d.point((x+104,y+28),fill=11)
    d.line((x-10,y+48,x+200,y+48),fill=7,width=2)
    # Native terrain follows collision, not the original colour bitmap.
    p=im.load()
    for sy in range(level.height):
        for sx in range(level.width):
            if not solid[sy][sx]: continue
            edge=sy==0 or not solid[sy-1][sx]
            for yy in range(2):
                for xx in range(2):
                    nx,ny=sx*2+xx,64+sy*2+yy
                    pebble=(nx%32,ny%16) in [(3,5),(4,5),(19,12)]
                    p[nx,ny]=2 if edge and yy==0 else (1 if pebble else 3)
    # Entry and burrow are genuine native art, positioned from original data.
    hx,hy=level.hatch; ex,ey=level.exit
    hx*=2; hy=64+hy*2; ex*=2; ey=64+ey*2
    d.rectangle((hx-5,hy-12,hx+18,hy-2),fill=3,outline=11)
    d.line((hx-4,hy-2,hx+17,hy-2),fill=0,width=2)
    d.ellipse((ex-9,ey-21,ex+19,ey+4),fill=3)
    d.ellipse((ex-3,ey-15,ex+13,ey+3),fill=0)
    d.line((ex-6,ey+3,ex+17,ey+3),fill=11,width=2)
    return im,solid


def cell(pixels,mono,phase=0):
    counts=Counter(pixels)
    bg,fg=(counts.most_common()+[(0,0),(15,0)])[:2]
    bg,fg=bg[0],fg[0]
    # Exact two-colour cells stay exact; others use nearest RGBI pair.
    if mono:
        # Material patterns and silhouettes, not a greyscale conversion.
        patterns={0:0,4:0,6:0,1:0xFF,2:0xFF,3:0x55,7:0xFF,8:0xAA,10:0xFF,11:0xFF,15:0xFF}
        rows=[]
        for y in range(16):
            v=0
            for x in range(8):
                c=pixels[y*8+x]
                bit=(y%4 != 0) if c==3 else (patterns.get(c,0xFF) >> ((x+phase+(y&1)*2)&7))&1
                v=(v<<1)|bit
            rows.append(v)
        return bytes(rows),15
    distance=lambda a,b:sum((PAL[a][i]-PAL[b][i])**2 for i in range(3))
    choices={c:distance(c,fg)<distance(c,bg) for c in counts}
    rows=[]
    for y in range(16):
        v=0
        for x in range(8):
            c=pixels[y*8+x]
            bit=choices[c]
            v=(v<<1)|bit
        rows.append(v)
    return bytes(rows),(bg<<4)|fg


def compile_world(im,mono,solid):
    glyphs=[]; index={}; maps=[]; protected=set(); uses=Counter()
    for phase in range(8):
        chars=bytearray(2048); attrs=bytearray(2048); colours=bytearray(2048)
        for row in range(14):
            for col in range(128):
                pix=[im.getpixel((col*8+phase+x,row*16+y)) for y in range(16) for x in range(8)]
                bits,colour=cell(pix,mono,phase)
                if bits not in index:
                    index[bits]=len(glyphs); glyphs.append(bits)
                n=index[bits]; off=row*128+col
                uses[n]+=1
                if row>=4 and any(solid[(row*16+yy-64)//2][min(511,(col*8+phase+xx)//2)] for yy in range(16) for xx in range(8)):
                    protected.add(n)
                chars[off]=0x80|(n&127); attrs[off]=n>>7; colours[off]=colour
        maps.append(bytes(chars+attrs+colours))
    # Rate-distortion dictionary packing: only non-collision artwork may share
    # an existing glyph differing by ONE native pixel. Keep target glyphs
    # immutable, so error never accumulates through chains. No block scaling.
    merges={}; retained=set(range(len(glyphs))); targets=set()
    words=[int.from_bytes(g,'big') for g in glyphs]
    for source in sorted(uses,key=uses.get):
        if len(retained)<=1792:break
        if source in protected or source in targets:continue
        for target in sorted(retained):
            if source==target or uses[target]<uses[source]:continue
            if (words[source]^words[target]).bit_count()==1:
                merges[source]=target;retained.remove(source);targets.add(target);break
    if merges:
        compact={n:i for i,n in enumerate(sorted(retained))}
        rebuilt=[]
        for data in maps:
            data=bytearray(data)
            for off in range(14*128):
                n=(data[off]&127)+(data[2048+off]<<7)
                n=compact[merges.get(n,n)]
                data[off]=128|(n&127);data[2048+off]=n>>7
            rebuilt.append(bytes(data))
        maps=rebuilt;glyphs=[glyphs[n] for n in sorted(retained)]
    print('mono' if mono else 'colour','PCG glyphs',len(glyphs),'one-pixel scenery merges',len(merges),flush=True)
    if len(glyphs)>1792:
        raise ValueError(f'{len(glyphs)} static glyphs exceed 1792-slot budget; art/cache must change')
    packing={'one_pixel_scenery_merges':len(merges),'collision_glyphs_protected':len(protected)}
    return glyphs,maps,packing


def compile_rasters(name,glyphs,maps):
    """Eight native column-major rasters, compressed in one bank-sized pack.

    Each decoded bank is 28672 bitmap bytes followed by 1792 colour bytes.
    These are the exact compiled Microbee glyph bits, including packing;
    neither original VZ pixels nor a PCG-as-framebuffer assumption is used.
    """
    pack=bytearray(32);sizes=[]
    for phase,data in enumerate(maps):
        bitmap=bytearray();colours=bytearray()
        for col in range(128):
            for row in range(14):
                off=row*128+col
                glyph=(data[off]&127)+(data[2048+off]<<7)
                bitmap.extend(glyphs[glyph]);colours.append(data[4096+off])
        raw=B/f'{name}{phase}.raster'
        raw.write_bytes(bitmap+colours)
        compressed=raw.with_suffix('.zx0')
        subprocess.run(['zx0','-q','-f',str(raw),str(compressed)],check=True,capture_output=True)
        payload=compressed.read_bytes()
        assert len(payload)<=12288, 'Mode staging buffer is 12K'
        at=phase*4
        pack[at:at+4]=len(pack).to_bytes(2,'little')+len(payload).to_bytes(2,'little')
        pack.extend(payload);sizes.append(len(payload))
    assert len(pack)<=32768, 'Native raster pack exceeds one expanded block'
    (B/f'{name}.raster.bnk').write_bytes(pack)
    return {'decoded_bank_bytes':30464,'compressed_phase_bytes':sizes,'pack_bytes':len(pack),
            'compressor':'ZX0 v2 quick'}


def bilby(frame,direction=0):
    """16x16 native silhouette: big ears, bright eye, long tail, eight gait frames."""
    im=Image.new('1',(16,16));d=ImageDraw.Draw(im)
    if COMPACT:
        d.line((3,4,2,0),fill=1,width=1)
        d.line((5,4,6,0),fill=1,width=1)
        d.ellipse((2,3,8,6),fill=1)
        d.polygon([(7,3),(10,5),(7,5)],fill=1)
        d.line((3,6,0,7),fill=1)
        d.point((7,4),fill=0)
        for x,p in [(4,0),(7,4)]:
            dx=[-1,0,1,1,0,-1,-1,0][(frame+p)&7]
            d.line((x,6,x+dx,7),fill=1)
        if direction:
            box=im.crop((0,0,12,8)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            im.paste(box,(0,0))
        return im
    bob=(frame//2)&1
    d.line((5,7+bob,4,0),fill=1,width=2)
    d.line((8,7+bob,10,1),fill=1,width=2)
    d.ellipse((4,6+bob,12,12+bob),fill=1)
    d.polygon([(11,8+bob),(15,10+bob),(10,11+bob)],fill=1)
    d.line((5,11+bob,0,13),fill=1,width=2)
    d.point((11,8+bob),fill=0)
    for fx,phase in [(6,0),(10,4)]:
        dx=[-2,-1,0,1,2,1,0,-1][(frame+phase)&7]
        d.line((fx,12+bob,fx+dx,15),fill=1,width=2)
    if direction: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return im


def compile_sprites(sprites,resident=False):
    """Bank-14 callable row programs, indexed by frame/phase/column.

    Scratch is column-major: a sprite column stays contiguous even across
    PCG-cell boundaries. Each routine draws all 16 rows with one call.
    """
    count=8*8*3
    code=bytearray() if resident else bytearray(0x2000+count*32)
    meta=bytearray(32768) if resident else code
    meta[0x1000:0x1460]=bytes([255])*1120
    for pose in range(64):
        meta[0x1460+pose*2:0x1462+pose*2]=(0x2000+pose*96).to_bytes(2,'little')
    for row in range(14):
        for col in range(80):
            cell=row*80+col
            address=0xA000+col*224+row*16
            meta[cell]=address&255
            meta[0x800+cell]=address>>8
    kinds=Counter()
    for column in range(count):
        table=len(code)
        rows=8 if COMPACT else 16
        active=[r for r in range(rows) if sprites[column*32+r*2:column*32+r*2+2]!=b'\xff\x00']
        first,last=(min(active),max(active)+1) if active else (0,0)
        at=0x2000+column*32
        meta[at:at+4]=table.to_bytes(2,'little')+bytes([first,last-first])
        for dy in range(16):
            meta[at+16+dy]=int(any(r+dy<16 for r in active))|2*int(any(r+dy>=16 for r in active))
        for row in range(first,last):
            mask,ink=sprites[column*32+row*2:column*32+row*2+2]
            if mask==255 and ink==0:
                kinds['transparent']+=1
            elif mask==0:
                code.extend([0x3E,ink,0x12])  # LD A,ink : LD (DE),A
                kinds['opaque']+=1
            else:
                code.extend([0x1A,0xE6,mask,0xF6,ink,0x12])
                kinds['masked']+=1
            code.append(0x13)  # INC DE: a column can cross a page boundary.
        code.append(0xC9)
    assert len(code)<=32768, len(code)
    (B/'sprite-code.bnk').write_bytes(code)
    if resident:(B/'sprite-meta.bnk').write_bytes(meta)
    return {'bank':26 if resident else 14,'origin':0 if resident else 0x2000,
            'bytes':len(code) if resident else len(code)-0x2000,
            'record_bytes':32,'vertical_phases':16,'directions':1,'frames':8,'rows':dict(kinds)}


def build(compact=False,reuse_world=False,ram_background=False,resident=False,compiled=False):
    global COMPACT
    COMPACT=compact
    B.mkdir(parents=True,exist_ok=True)
    width,height=(12,8) if compact else (16,16)
    (B/'config.inc').write_text(f'N_SPRITE_W EQU {width}\nN_SPRITE_H EQU {height}\n')
    level=levels.LEVELS[1]
    im,solid=world(level)
    im.crop((0,0,W,H)).save(B/'world.png')
    report={'sprite_dimensions':[width,height]}
    if reuse_world:
        cached=json.loads((B/'assets.json').read_text())
        for name in ['colour','mono']:
            if ram_background:assert (B/f'{name}.raster.bnk').exists()
            report[name]=cached[name]
    else:
        for mono,name in [(False,'colour'),(True,'mono')]:
            glyphs,maps,packing=compile_world(im,mono,solid)
            pcg=bytearray(b''.join(glyphs).ljust(32768,b'\0'))
            (B/f'{name}.pcg').write_bytes(pcg)
            for half in range(2):
                (B/f'{name}{half}.map').write_bytes(b''.join(maps[half*4:half*4+4]))
            report[name]={'static_glyphs':len(glyphs),'phase_map_bytes':sum(map(len,maps)),
                          'pcg_bytes':len(glyphs)*16,'dynamic_slots':255,**packing}
            if ram_background:report[name]['native_rasters']=compile_rasters(name,glyphs,maps)
    sprites=bytearray()
    for direction in range(2):
        for frame in range(8):
            sprite=bilby(frame,direction)
            mask=Image.new('1',(16,16))
            for y in range(16):
                for x in range(16):
                    mask.putpixel((x,y),any(sprite.getpixel((xx,yy)) for yy in range(max(0,y-1),min(16,y+2)) for xx in range(max(0,x-1),min(16,x+2))))
            # Preshifted rows of three bytes: cheap native AND/XOR compositor.
            for shift in range(8):
                rows=[]
                for y in range(16):
                    ink=sum(sprite.getpixel((x,y))<<(23-x-shift) for x in range(16)).to_bytes(3,'big')
                    outline=sum(mask.getpixel((x,y))<<(23-x-shift) for x in range(16)).to_bytes(3,'big')
                    rows.append((outline,ink))
                for col in range(3):
                    for outline,ink in rows:sprites.extend([outline[col]^255,ink[col]])
    (B/'sprites.bin').write_bytes(sprites)
    report['compiled_sprites']=compile_sprites(sprites,resident)
    if compiled:
        from compiled_actors import generate
        generate(B,sprites,height)
    mask=bytes(sum(bool(solid[y][x*8+b])<<(7-b) for b in range(8)) for y in range(80) for x in range(64))
    (B/'collision.bin').write_bytes(mask)
    (B/'parameters.bin').write_bytes(bytes(level.compile('NATIVE'))[:512].ljust(512,b'\0'))
    entities=bytearray()
    for i in range(40):
        x=32+i*14
        ys=[y for y in range(80) if solid[y][min(511,x//2)]]
        y=max(0,min(224-height,64+(ys[0] if ys else 70)*2-height))
        entities.extend(bytes([x&255,x>>8,y,0]))
    (B/'entities.bin').write_bytes(entities)
    jobs=bytearray()
    for tile in range(2):
        jobs.extend((12*80+54+tile).to_bytes(2,'little'))
        for y in range(16):
            v=0
            for x in range(8):
                v=(v<<1)|int((tile*8+x-7.5)**2+(y-7.5)**2>45)
            jobs.append(v)
        jobs.append(0x63)
    (B/'patches.bin').write_bytes(jobs)
    (B/'assets.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))


if __name__=='__main__':build()
