"""Independent Premium PCG validation: exact RGBI palette, 8x8 cells, 16-byte slots.

Checks exported images AND decodes the bytes that will be loaded into PCG RAM.
No quantisation or correction occurs here. Invalid art fails rather than being
silently repaired. CLI: pcg_validate.py image.png --out build/diagnostic [--grid].
"""
from pathlib import Path
import argparse,json
import numpy as np
from PIL import Image,ImageDraw

PALETTE=np.array([(0,0,0),(192,0,0),(0,192,0),(192,96,0),(0,0,192),(192,0,192),(0,192,192),(192,192,192),
 (96,96,96),(255,64,64),(64,255,64),(255,255,64),(64,64,255),(255,64,255),(64,255,255),(255,255,255)],dtype=np.uint8)

def inspect(image):
    rgb=np.asarray(image.convert('RGB'));height,width=rgb.shape[:2]
    if width%8 or height%8:raise ValueError('Image dimensions must be multiples of 8')
    allowed={tuple(c) for c in PALETTE.tolist()};bad=[];counts=[]
    for y in range(height//8):
        for x in range(width//8):
            colours=np.unique(rgb[y*8:y*8+8,x*8:x*8+8].reshape(-1,3),axis=0).tolist()
            outside=[c for c in colours if tuple(c) not in allowed]
            counts.append(len(colours))
            if len(colours)>2 or outside:
                bad.append({'x':x,'y':y,'colours':colours,'off_palette':outside,'count':len(colours)})
    total=(width//8)*(height//8)
    return {'width':width,'height':height,'cell_width':8,'cell_height':8,'total_cells':total,
            'valid_cells':total-len(bad),'invalid_cells':len(bad),'offending_cells':bad,'colour_counts':counts}

def diagnostic(image,report,path,grid=False):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    image=image.convert('RGB').resize((image.width*3,image.height*3),Image.Resampling.NEAREST)
    draw=ImageDraw.Draw(image);cols=report['width']//8
    if grid:
        for i,count in enumerate(report['colour_counts']):
            x=(i%cols)*24;y=(i//cols)*24
            draw.rectangle((x,y,x+23,y+23),outline=(70,70,70))
            draw.rectangle((x+1,y+1,x+8,y+10),fill=(0,0,0))
            draw.text((x+1,y),str(count),fill=(255,255,255))
    for cell in report['offending_cells']:
        x=cell['x']*24;y=cell['y']*24
        draw.rectangle((x,y,x+23,y+23),outline=(255,0,0),width=2)
        draw.rectangle((x+1,y+1,x+12,y+12),fill=(0,0,0))
        draw.text((x+2,y),str(cell['count']),fill=(255,0,0))
    image.save(path)

def planes(pcg,codes,attrs,colours,width=320,height=256,max_glyphs=2048):
    cells=width*height//64
    if len(pcg)%16 or len(pcg)>32768:raise ValueError('Invalid PCG allocation size')
    if any(len(p)!=cells for p in (codes,attrs,colours)):raise ValueError('Invalid video plane length')
    codes=np.frombuffer(bytes(codes),dtype=np.uint8).astype(int)
    attrs=np.frombuffer(bytes(attrs),dtype=np.uint8).astype(int)
    cols=np.frombuffer(bytes(colours),dtype=np.uint8).astype(int)
    if np.any(codes<128):raise ValueError('Native asset references character ROM')
    if np.any(attrs>15):raise ValueError('Unsupported attribute flags in native asset')
    indices=attrs*128+(codes&127)
    if np.any(indices>=min(len(pcg)//16,max_glyphs)):raise ValueError('PCG index exceeds allocated or reserved glyph range')
    glyphs=np.frombuffer(bytes(pcg),dtype=np.uint8).reshape(-1,16)[indices,:8]
    bits=(glyphs[:,:,None] & (128>>np.arange(8))[None,None,:])!=0
    pixels=np.where(bits[:,:,:,None],PALETTE[cols&15,None,None,:],PALETTE[cols>>4,None,None,:])
    pixels=pixels.reshape(height//8,width//8,8,8,3).transpose(0,2,1,3,4).reshape(height,width,3)
    return Image.fromarray(pixels.astype(np.uint8))

def unpack_raw(raw,width=320,height=256):
    cells=width*height//64
    if len(raw)!=cells*17:raise ValueError('Invalid raw PCG/colour length')
    glyphs=raw[:cells*16]
    if np.any(np.frombuffer(glyphs,dtype=np.uint8).reshape(-1,16)[:,8:]):
        raise ValueError('Nonzero hidden scanlines in an 8x8 asset')
    return planes(glyphs,bytes((i&127)|128 for i in range(cells)),bytes(i>>7 for i in range(cells)),raw[cells*16:],width,height)

def group_frames(packet,external_pcg=None):
    if len(packet)>32768 or len(packet)<10:raise ValueError('Group exceeds RAM bank or has no header')
    size=int.from_bytes(packet[:2],'little')
    if size%16 or size>1792*16:raise ValueError('Glyph dictionary exceeds banks 0..13')
    pcg=packet[10:10+size]
    if len(pcg)!=size:raise ValueError('Truncated glyph dictionary')
    if external_pcg is not None:
        if size or len(external_pcg)%16 or len(external_pcg)>1792*16:raise ValueError('Invalid external PCG dictionary')
        pcg=external_pcg
    if np.any(np.frombuffer(pcg,dtype=np.uint8).reshape(-1,16)[:,8:]):raise ValueError('Hidden PCG rows set')
    result=[];ranges=[]
    for n in range(4):
        offset=int.from_bytes(packet[2+n*2:4+n*2],'little')
        if not offset:continue
        if offset<10+size or offset+3840>len(packet):raise ValueError('Invalid frame-map pointer')
        if any(offset<end and offset+3840>start for start,end in ranges):raise ValueError('Overlapping frame maps')
        ranges.append((offset,offset+3840));m=packet[offset:offset+3840]
        result.append(planes(pcg,m[:1280],m[1280:2560],m[2560:],max_glyphs=1792))
    if len(result) not in (3,4):raise ValueError('Expected three animation maps and optional backdrop')
    return result

def world_packet(packet):
    """Validate the atlas header, glyph dictionary and every native cell run."""
    if len(packet)<64 or len(packet)>32768:raise ValueError('World atlas exceeds its RAM block')
    size=int.from_bytes(packet[:2],'little');start=int.from_bytes(packet[2:4],'little')
    if packet[44] not in (0,5) or size+packet[44]*2048>1792*16:raise ValueError('World dictionary overlaps reserved PCGs')
    count=43+20*(packet[4]+packet[5])
    layers=int.from_bytes(packet[6:8],'little')
    if layers and (packet[44]!=5 or layers<start+size or layers+(count+1)*3>len(packet)):
        raise ValueError('Invalid masked-layer reference table')
    if start!=64+2*count or size%16 or size>1792*16:raise ValueError('Invalid world dictionary allocation')
    pcg=packet[start:start+size]
    if len(pcg)!=size or not size:raise ValueError('Truncated world dictionary')
    if np.any(np.frombuffer(pcg,dtype=np.uint8).reshape(-1,16)[:,8:]):raise ValueError('World hidden PCG scanlines are set')
    cells=0
    def tile(code,attr):
        index=(attr-packet[44])*128+(code&127)
        if code<128 or attr>13 or not 0<=index<size//16:raise ValueError('World tile exceeds PCG allocation')
    for i in range(12):tile(packet[8+3*i],packet[9+3*i])
    for i in range(count):
        at=int.from_bytes(packet[64+i*2:66+i*2],'little')
        if not start+size<=at<len(packet):raise ValueError('World component pointer outside payload')
        while True:
            if at>=len(packet):raise ValueError('Unterminated world component')
            n=packet[at];at+=1
            if not n:break
            if at+2+n*3>len(packet):raise ValueError('Truncated world cell run')
            offset=int.from_bytes(packet[at:at+2],'little');at+=2
            if n>40 or offset+n>1280 or offset//40!=(offset+n-1)//40:raise ValueError('World cell run crosses a row')
            for x in range(n):tile(packet[at+x],packet[at+n+x])
            at+=n*3;cells+=n
    return {'components':count,'validated_cell_references':cells,'pcg_bytes':size,'ram_bytes':len(packet)}

def validate_assets(folder):
    folder=Path(folder);reports=[];failures=[]
    for rawpath in sorted(folder.glob('*.raw')):
        if rawpath.stem.startswith(('group','combat','delta')):continue
        png=rawpath.with_suffix('.png')
        if not png.exists():raise ValueError(f'Missing preview: {png}')
        encoded=unpack_raw(rawpath.read_bytes());preview=Image.open(png).convert('RGB')
        report=inspect(preview);report['asset']=rawpath.stem
        report['encoded_preview_match']=np.array_equal(np.asarray(encoded),np.asarray(preview))
        if report['invalid_cells'] or not report['encoded_preview_match']:
            diagnostic(preview,report,folder/'diagnostics'/(rawpath.stem+'.png'),True);failures.append(report)
        reports.append({k:v for k,v in report.items() if k not in ('colour_counts','offending_cells')})
    summary={'assets':len(reports),'total_cells':sum(r['total_cells'] for r in reports),
             'invalid_cells':sum(r['invalid_cells'] for r in reports),'failures':failures,'results':reports,
             'palette':'Microbee RGBI 16 colours; exact model palette','encoded_output_checked':True}
    (folder/'pcg-validation.json').write_text(json.dumps(summary,indent=2))
    if failures:raise ValueError(f'{len(failures)} invalid PCG assets; see diagnostics')
    return summary

def main():
    parser=argparse.ArgumentParser();parser.add_argument('image',type=Path)
    parser.add_argument('--out',type=Path,default=Path('build/pcg-diagnostic'));parser.add_argument('--grid',action='store_true')
    a=parser.parse_args();im=Image.open(a.image);report=inspect(im)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.with_suffix('.json').write_text(json.dumps(report,indent=2))
    diagnostic(im,report,a.out.with_suffix('.png'),a.grid)
    print(json.dumps({k:report[k] for k in ('total_cells','valid_cells','invalid_cells','offending_cells')},indent=2))
    raise SystemExit(1 if report['invalid_cells'] else 0)

if __name__=='__main__':main()
