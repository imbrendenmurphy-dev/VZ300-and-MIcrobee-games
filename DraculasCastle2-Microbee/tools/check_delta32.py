"""Measure actual Z80 40x32 changed-run transfers against model row deadlines."""
from pathlib import Path
import sys,json,ctypes as C
import numpy as np
from PIL import ImageDraw
import native_art as art
from mbee import Mbee,L,FRAME_T

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'original/tools'))
import zasm
out=ROOT/'build/mode32';out.mkdir(exist_ok=True)
L.mb_deadline_start.argtypes=[C.c_void_p]
L.mb_deadline_stat.argtypes=[C.c_void_p,C.c_int]
L.mb_deadline_stat.restype=C.c_int64
asm=zasm.Asm();code=asm.assemble(str(ROOT/'src/mb_delta32.asm'))
binary=bytes(code[i] for i in range(min(code),max(code)+1))
(out/'delta32.bin').write_bytes(binary)

def scene(monster,frame):
    name=art.M.MONSTERS[monster][0]
    im=art.backdrop(art.M.HOME_BBG.get(name,0)).crop((0,0,320,256))
    if frame<3:
        sp=art.monster(monster,frame);im.paste(sp,(80,18),sp)
    ImageDraw.Draw(im).rectangle((0,200,319,255),fill=(0,0,0))
    return im

def make_maps(raws):
    lookup={};glyphs=[];maps=[]
    for raw in raws:
        ids=[]
        for pos in range(0,20480,16):
            glyph=raw[pos:pos+16]
            if glyph not in lookup:lookup[glyph]=len(glyphs);glyphs.append(glyph)
            ids.append(lookup[glyph])
        maps.append(np.array([[(i&127)|128,i>>7,raw[20480+j]] for j,i in enumerate(ids)],dtype=np.uint8))
    assert len(glyphs)<1792,'Leave banks 14/15 for tall text'
    return b''.join(glyphs),maps

def pack_delta(old,new,force=False):
    changed=np.any(old!=new,axis=1) if not force else np.ones(1280,dtype=bool)
    packet=bytearray();runs=0;copied=0
    for row in range(32):
        indices=np.flatnonzero(changed[row*40:(row+1)*40])
        spans=[]
        for col in indices:
            if spans and col-spans[-1][1]<=3:spans[-1][1]=int(col)
            else:spans.append([int(col),int(col)])
        for left,right in spans:
            start=row*40+left;count=right-left+1
            packet.append(count);packet.extend((0xF000+start).to_bytes(2,'little'))
            packet.extend(new[start:start+count].T.tobytes())
            runs+=1;copied+=count
    packet.append(0)
    return packet,int(changed.sum()),copied,runs

def transfer(glyphs,old,new,force=False):
    packet,changed,copied,runs=pack_delta(old,new,force)
    p=Mbee();p.out(0x50,7);p.out(0x1c,0x80)
    for i,v in enumerate([53,40,44,0x34,38,0,32,35,0x48,7,0x20,0,0,0,0,0]):p.crtc[i]=v
    p.blocks[0][0x1000:0x1000+len(binary)]=list(binary)
    p.blocks[1][0x2000:0x2000+len(packet)]=list(packet)
    p.pcg[:len(glyphs)]=list(glyphs)
    p.scr[:1280]=list(old[:,0]);p.attr[:1280]=list(old[:,1]);p.col[:1280]=list(old[:,2])
    pcg=bytes(p.pcg)
    p.cpu.pc=0x9000;p.cpu.h=0x20;p.cpu.l=0;p.cpu.sp=0xEDFC
    p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1)
    L.mb_deadline_start(p.h)
    assert p.run_until(0xE1F0,5)==0xE1F0
    actual=np.stack([p.scr[:1280],p.attr[:1280],p.col[:1280]],axis=1)
    assert np.array_equal(actual,new)
    assert bytes(p.pcg)==pcg
    assert not any(p.scr[1280:]) and not any(p.attr[1280:]) and not any(p.col[1280:])
    return {'changed_cells':changed,'copied_cells':copied,'runs':runs,'transfer_tstates':p.tick-FRAME_T*256//312,
            'late_plane_writes':int(L.mb_deadline_stat(p.h,0)),'min_row_margin_tstates':int(L.mb_deadline_stat(p.h,2)),
            'plane_writes':int(L.mb_deadline_stat(p.h,1))}

results=[]
for mono in (False,True):
    for monster in range(12):
        raws=[]
        for frame in range(4):
            path=out/f'delta-source-{monster}-{frame}-{int(mono)}.raw'
            if not path.exists():path.write_bytes(art.encode(scene(monster,frame),mono,8)[0])
            raws.append(path.read_bytes())
        glyphs,maps=make_maps(raws)
        stem=f'{monster+1:02}-{"mono" if mono else "colour"}'
        (out/f'{stem}-glyphs.bin').write_bytes(glyphs)
        for i,m in enumerate(maps):(out/f'{stem}-frame{i}.bin').write_bytes(m.T.tobytes())
        for a,b,kind in [(0,1,'idle'),(1,0,'idle'),(0,2,'attack'),(2,0,'attack'),(0,3,'disappear')]:
            (out/f'{stem}-delta{a}{b}.bin').write_bytes(pack_delta(maps[a],maps[b])[0])
            r=transfer(glyphs,maps[a],maps[b]);r.update(monster=monster+1,mono=mono,kind=kind)
            results.append(r)
        # Conservative combined updates: attack pose plus full 32-character,
        # two-PCG-row HUD lines, then effect marks over the scene. The entire
        # three-plane run is transferred even if only its colour changed.
        combined=maps[2].copy()
        for row in (25,27,29):
            for col in range(4,36):
                combined[row*40+col]=[128+(col%64),14,0xF0]
                combined[(row+1)*40+col]=[128+(col%64),15,0xF0]
        effects={
            'attack+HUD':[],
            'attack+HUD+slash':[(2+i)*40+27-i for i in range(16)],
            'attack+HUD+fire':[(5+i)*40+16+i%8 for i in range(12)],
            'attack+HUD+holy':[2*40+11+i*57 for i in range(10)]}
        for kind,cells in effects.items():
            target=combined.copy()
            for cell in cells:target[cell]=[128+15,14,15]
            r=transfer(glyphs,maps[0],target);r.update(monster=monster+1,mono=mono,kind=kind)
            results.append(r)
        print('Checked delta32',monster+1,'mono' if mono else 'colour',flush=True)
control=transfer(glyphs,maps[0],maps[1],force=True)
assert control['late_plane_writes']>0,'Full redraw must expose the deadline limit'
unchanged=transfer(glyphs,maps[0],maps[0])
assert unchanged['plane_writes']==0
edges=maps[0].copy()
for cell in (0,39,40,1279):edges[cell,2]^=0xFF
boundary=transfer(glyphs,maps[0],edges)
assert boundary['late_plane_writes']==0 and boundary['changed_cells']==4
report={'status':'experimental Z80 backend, not integrated into game','transitions':results,'full_redraw_control':control,
        'empty_update':unchanged,'boundary_update':boundary,
        'max_changed_cells':max(r['changed_cells'] for r in results),'max_transfer_tstates':max(r['transfer_tstates'] for r in results),
        'late_transitions':sum(r['late_plane_writes']>0 for r in results),'hardware_tested':False,
        'caveat':'Exact Z80 instruction timing; simplified scanout. Excludes runtime dirty-list generation, music service and dynamic HUD/effect composition. Combined HUD/effect cases are conservative synthetic transfer loads.'}
(out/'delta32-validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ('transitions','full_redraw_control','empty_update','boundary_update')},indent=2))
