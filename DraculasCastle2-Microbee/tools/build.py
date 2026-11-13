"""Build the playable port with native title, gallery and combat graphics."""
from pathlib import Path
import sys, re, subprocess, json, hashlib, shutil
from collections import Counter
import numpy as np  # Load stdlib inspect/dis before adding the upstream tools path.

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'original/tools'))
sys.path.insert(0, str(ROOT / 'tools'))
import port_source, disk

def write(path, data):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data) if isinstance(data, bytes) else path.write_text(data)

def patterns():
    # Compatibility quantisation only: choose two colours per 2x2 source block.
    # This is deliberately not described as the finished Microbee artwork.
    palettes = [(10,11,4,1),(15,14,13,3)]
    pcg = bytearray(); cols = []
    rgb = [(0,0,0),(192,0,0),(0,192,0),(192,96,0),(0,0,192),(192,0,192),(0,192,192),(192,192,192),
           (96,96,96),(255,64,64),(64,255,64),(255,255,64),(64,64,255),(255,64,255),(64,255,255),(255,255,255)]
    for pal in palettes:
        for v in range(256):
            px = [(v >> sh) & 3 for sh in (6,4,2,0)]
            ranked = sorted(range(4), key=lambda c: (-px.count(c),c))
            bg, fg = ranked[:2]
            cols.append(pal[bg]*16+pal[fg])
            for y in range(8):
                bits = 0
                for x in range(8):
                    c = px[(y//4)*2+x//4]
                    if c == bg: on = False
                    elif c == fg: on = True
                    else:
                        target, a, b = rgb[pal[c]],rgb[pal[bg]],rgb[pal[fg]]
                        da=sum((target[k]-a[k])**2 for k in range(3))
                        db=sum((target[k]-b[k])**2 for k in range(3))
                        on = ((x+y)&1) if abs(da-db)<25000 else db<da
                    bits = bits*2+bool(on)
                pcg.append(bits)
            pcg.extend(bytes(8))
    import font
    eggcol=[]
    for ch in range(256):
        if ch>=128:
            ink=(10,11,4,1,15,14,13,3)[(ch>>4)&7]
            tile=[[bool(ch & (8 >> ((y//8)*2+x//8))) for x in range(16)] for y in range(16)]
            eggcol.append(ink)
        else:
            asc=(ch&63);asc=asc+64 if asc<32 else asc
            glyph=font.F.get(chr(asc),font.F[' '])
            tile=[[False]*16 for _ in range(16)]
            for y,row in enumerate(glyph):
                for x,c in enumerate(row):
                    for yy in range(3):
                        for xx in range(3):tile[y*3+yy][3+x*3+xx]=c=='#'
            eggcol.append(0x0A if ch&64 else 0xA0)
        for q in range(4):
            for y in range(8):
                pcg.append(sum(int(tile[(q//2)*8+y][(q%2)*8+x])<<(7-x) for x in range(8)))
            pcg.extend(bytes(8))
    # Dedicated monochrome glyphs: preserve four source tones as textures,
    # independent of the two colours selected for the colour version.
    for css in range(2):
        for v in range(256):
            px=[(v>>sh)&3 for sh in (6,4,2,0)]
            for y in range(8):
                bits=0
                for x in range(8):
                    c=px[(y//4)*2+x//4]
                    if c==2:on=False
                    elif c==(1 if css==0 else 0):on=True
                    elif c==(0 if css==0 else 1):on=(x+y)%2==0
                    else:on=(x%2==0 and y%2==0)
                    bits=bits*2+on
                pcg.append(bits)
            pcg.extend(bytes(8))
    assert len(pcg)==32768
    write('build/PCG.BNK',bytes(pcg))
    write('src/gen/mb_colours.inc','mb_eggcolours:\n'+''.join('            db '+','.join(map(str,eggcol[i:i+16]))+'\n' for i in range(0,256,16)))

def keys():
    reference=(ROOT/'reference/hullbreach/src/input.asm').read_text()
    s=reference[reference.index('keytest:'):reference.index('read_input:')]
    s=s.replace('keytest:','mb_keytest:').replace('P_CRTCA','$0C').replace('P_CRTCD','$0D')
    # Emulate only the VZ rows actually referenced by game code.
    rows={'FE':'T W - E Q R','FD':'G S - D A F','EF':'N . - , SPACE M',
          'BF':'Y O RET I P U','7F':'H L - K - J','F7':'5 2 - 3 1 4'}
    keycodes={c:i+1 for i,c in enumerate('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}
    keycodes.update({str(n):32+n for n in range(10)})
    keycodes.update({'SPACE':55,'RET':52})
    for row, desc in rows.items():
        s+=f'\nmb_row_{row}:\n            push bc\n            push de\n            push hl\n            ld c,$3F\n            ld a,1\n            out ($0B),a\n'
        for bit,key in enumerate(desc.split()):
            if key not in keycodes: continue
            s+=f'            ld a,{keycodes[key]}\n            call mb_keytest\n            jr z,.k{bit}\n            res {bit},c\n.k{bit}:\n'
            if key in {'W','A','S','D'}:
                arrow={'W':56,'A':59,'S':58,'D':62}[key]
                s+=f'            ld a,{arrow}\n            call mb_keytest\n            jr z,.a{bit}\n            res {bit},c\n.a{bit}:\n'
        s+='            xor a\n            out ($0B),a\n            ld a,c\n            pop hl\n            pop de\n            pop bc\n            ret\n'
    s+='\nmb_any:     push bc\n            ld b,$3F\n'
    for row in rows:s+=f'            call mb_row_{row}\n            and b\n            ld b,a\n'
    s+='            pop bc\n            ret\n'
    write('src/mb_keys.asm',s)

def files():
    import area
    banks={}; entries={}; bank=4; buf=bytearray()
    for p in sorted((ROOT/'baseline-release').glob('*.DAT')):
        data=p.read_bytes()
        if re.fullmatch(r'DC2A\dP[12]|DC2MON\d+|DC2BBG\d|DC2TITLE',p.stem):
            # VZ wall, decoration and object bitmaps. Nothing draws them on the
            # Microbee, so one placeholder byte replaces each (about 69K freed).
            data=b'\0'
        elif re.fullmatch(r'DC2A\dP2',p.stem):
            # These original files contain absolute C800-based pointers.
            # Relocate only the defined pointer tables, never sprite pixels.
            ad=area.AREAS[int(p.stem[4])]
            data=bytearray(data)
            word=lambda off: int.from_bytes(data[off:off+2],'little')
            dt,ot=word(0)-0xC800,word(2)-0xC800
            offsets=[0,2]+list(range(dt,dt+12*len(ad.decors),2))+list(range(ot,ot+6*len(ad.objects),2))
            for off in offsets:
                value=word(off)
                if value:
                    assert 0xC800<=value<0xC800+len(data)
                    data[off:off+2]=(value-0xC800).to_bytes(2,'little')
            data=bytes(data)
        if len(buf)+len(data)>32768:
            banks[bank]=bytes(buf); bank+=1; buf=bytearray()
        entries[p.stem]=(len(data),bank,len(buf))
        buf.extend(data)
        buf.extend(bytes((-len(buf))%128))
    banks[bank]=bytes(buf)
    for b,data in banks.items(): write(f'build/DATA{b:02}.BNK',data)
    s=(ROOT/'original/src/gen/files.inc').read_text()
    def replace(m):
        name=m.group(3); size,b,off=entries[name]
        return f'{m.group(1)}: dw {size}\n            db {b}\n            dw {off}'
    s=re.sub(r'(\w+): dw (\d+)\s+db 34,"(\w+)",34,0',replace,s)
    write('src/gen/files.inc',s)
    write('build/assets.json',json.dumps(entries,indent=2))
    return banks

def native_files(used_banks=(),seed=None):
    import native_art
    import pcg_validate
    import battle_rooms
    folder=ROOT/'build/native';manifest=folder/'manifest.json'
    sources=[ROOT/'tools/native_art.py',ROOT/'tools/battle_fx.py',ROOT/'tools/native_detail.py',ROOT/'tools/ghoulies.py',ROOT/'tools/dracula_font.py',ROOT/'original/tools/monsters.py']
    if not manifest.exists() or any(p.stat().st_mtime>manifest.stat().st_mtime for p in sources):native_art.build()
    import animation_art
    stamp=folder/'animation.stamp'
    if not stamp.exists() or any((ROOT/'tools'/f).stat().st_mtime>stamp.stat().st_mtime for f in ('animation_art.py','native_detail.py','native_art.py','ghoulies.py')):animation_art.build()
    checked=pcg_validate.validate_assets(folder)
    print('PCG validation:',checked['assets'],'assets,',checked['total_cells'],'cells, no invalid cells')
    # 28: loader staging, then recent views. 30: decode/encounter workspace.
    # 31: decoded perspective pieces and viewport, accessed in the same bank.
    available=iter([b for b in (5,6,7,8,9,10,11,12,13,15,16,17,18,19,20,21,22,23,24,25,26,27,29) if b not in used_banks])
    banks={};table=[]
    # First fit: each packed asset goes in the first bank with room for it.
    pool={b:bytearray(d) for b,d in (seed or {}).items()}
    def place(data):
        for b,d in pool.items():
            if len(d)+len(data)<=32768:
                off=len(d);d.extend(data);return b,off
        b=next(available);pool[b]=bytearray(data);return b,0
    for entry in json.loads(manifest.read_text()):
        # Gallery/combat use shared-glyph groups; retain only standalone titles.
        if not entry['name'].startswith('title-'):continue
        data=(folder/(entry['name']+'.lz')).read_bytes()
        pb,po=place(data)
        table.append(f'            db {pb}\n            dw {po} ; {entry["name"]}\n')
    auxiliary={}
    def store_animation(data):
        if data in auxiliary:return auxiliary[data]
        packed=native_art.compress_fast(data)
        pb,po=place(packed)
        ref=f'            db {pb}\n            dw {po}\n'
        auxiliary[data]=ref
        return ref
    dictionaries={}
    for mode in ('colour','mono'):
        glyphs=[];lookup={}
        for variant in ('monster','battle'):
            stems=[f'{variant}03-{f}-{mode}' for f in range(4 if variant=='battle' else 3)]+[f'anim-{variant}03-{f}-{mode}' for f in range(8)]
            for stem in stems:
                raw=(folder/(stem+'.raw')).read_bytes()
                for pos in range(0,20480,16):
                    g=raw[pos:pos+16]
                    if g not in lookup:lookup[g]=len(glyphs);glyphs.append(g)
        assert len(glyphs)<=1792
        dictionaries[mode]=(glyphs,lookup)
    groups=[];idle_entries=[];allocations=[];animation_entries=[]
    for variant,mode in ((v,m) for v in ('monster','battle') for m in ('colour','mono')):
        for monster in range(1,13):
            if variant=='battle' and monster in battle_rooms.ORDINARY:
                # Composed at load time from the current room (battle_rooms.py).
                groups.append('            db 0\n            dw 0\n')
                idle_entries.append('            db 0\n            dw 0\n')
                animation_entries.append('            db 0,0,0,0,0,0,0,0,0\n')
                continue
            glyphs=[];lookup={};maps=[]
            if monster==3:glyphs,lookup=dictionaries[mode]
            for frame in range(4 if variant=='battle' else 3):
                raw=(folder/f'{variant}{monster:02}-{frame}-{mode}.raw').read_bytes()
                ids=[]
                for pos in range(0,20480,16):
                    glyph=raw[pos:pos+16]
                    if glyph not in lookup:
                        lookup[glyph]=len(glyphs);glyphs.append(glyph)
                    ids.append(lookup[glyph])
                maps.append(bytes((i&127)|128 for i in ids)+bytes(i>>7 for i in ids)+raw[20480:])
            full_pcg=b''.join(glyphs)
            length=0 if monster==3 else len(full_pcg)
            assert len(glyphs)<=1792  # Bank 14 reserved for combat effects.
            pointers=[10+length+f*3840 for f in range(len(maps))]
            pointers += [0]*(4-len(pointers))
            packet=length.to_bytes(2,'little')+b''.join(p.to_bytes(2,'little') for p in pointers)+(b'' if monster==3 else full_pcg)+b''.join(maps)
            assert len(packet)<=32768  # Working maps are cached in separate RAM block 3.
            pcg_validate.group_frames(packet,external_pcg=full_pcg if monster==3 else None)
            name=f'{"group" if variant=="monster" else "combat"}{monster:02}-{mode}'
            allocations.append({'name':name,'glyphs':len(glyphs),'pcg_bytes':len(full_pcg),'bundle_pcg_bytes':length,'external_dictionary':monster==3,'packet_bytes':len(packet)})
            (folder/(name+'.raw')).write_bytes(packet)
            data=native_art.compress_fast(packet)
            pb,po=place(data)
            groups.append(f'            db {pb}\n            dw {po} ; {name}\n')
            if monster!=3:
                animation_entries.append('            db 0,0,0,0,0,0,0,0,0\n')
            else:
                extended=[]
                for phase in range(8):
                    raw=(folder/f'anim-{variant}03-{phase}-{mode}.raw').read_bytes()
                    ids=[lookup[raw[pos:pos+16]] for pos in range(0,20480,16)]
                    extended.append(bytes((i&127)|128 for i in ids)+bytes(i>>7 for i in ids)+raw[20480:])
                deltas=bytearray()
                for phase in range(8):
                    old,new=extended[(phase-1)%8],extended[phase];stream=bytearray()
                    for row in range(32):
                        xs=[x for x in range(40) if any(old[row*40+x+k*1280]!=new[row*40+x+k*1280] for k in range(3))]
                        if not xs:continue
                        left,right=xs[0],xs[-1];count=right-left+1;start=row*40+left
                        stream.append(count);stream.extend((0xF000+start).to_bytes(2,'little'))
                        for k in range(3):stream.extend(new[start+k*1280:start+k*1280+count])
                    stream.append(0);assert len(stream)<=1792
                    deltas.extend(stream+bytes(1792-len(stream)))
                stem=f'extended-{variant}03-{mode}'
                for suffix,payload in (('pcg',full_pcg),('maps',b''.join(extended)),('deltas',bytes(deltas))):(folder/(stem+'.'+suffix)).write_bytes(payload)
                animation_entries.append(store_animation(len(full_pcg).to_bytes(2,'little')+full_pcg)+store_animation(b''.join(extended))+store_animation(bytes(deltas)))
            idle=bytearray()
            for previous,current in ((0,1),(1,0)):
                old,new=maps[previous],maps[current];stream=bytearray()
                for row in range(32):
                    changed=[x for x in range(40) if any(old[row*40+x+plane*1280]!=new[row*40+x+plane*1280] for plane in range(3))]
                    if not changed:continue
                    left,right=changed[0],changed[-1];count=right-left+1;start=row*40+left
                    stream.append(count);stream.extend((0xF000+start).to_bytes(2,'little'))
                    for plane in range(3):stream.extend(new[start+plane*1280:start+plane*1280+count])
                stream.append(0)
                assert len(stream)<=1728,(name,len(stream))
                idle.extend(stream+bytes(1728-len(stream)))
            data=native_art.compress_fast(bytes(idle))
            pb,po=place(data)
            idle_entries.append(f'            db {pb}\n            dw {po} ; {name}\n')
    room_entries=[];sprite_entries=[];room_report=[]
    for mode in ('colour','mono'):
        for area in range(6):
            raw,pic=battle_rooms.room(area,mode=='mono')
            pic.save(folder/f'room{area}-{mode}.png')
            room_entries.append(store_animation(raw));room_report.append({'room':area,'mode':mode,'glyphs':int.from_bytes(raw[:2],'little')//16})
    for mode in ('colour','mono'):
        for monster in range(1,13):
            if monster not in battle_rooms.ORDINARY:
                sprite_entries.append('            db 0\n            dw 0\n');continue
            raw=battle_rooms.sprite(monster,mode=='mono')
            sprite_entries.append(store_animation(raw));room_report.append({'sprite':monster,'mode':mode,'glyphs':int.from_bytes(raw[:2],'little')//16,'bytes':len(raw)})
    checked['battle_rooms']=room_report
    import battle_fx
    fx_entries=[]
    for kind in sorted(battle_fx.DRAW):
        data=battle_fx.blob(kind)
        pb,po=place(data)
        fx_entries.append(f'            db {pb}\n            dw {po},{len(data)}\n')
    import dracula_font
    import world_art
    import lz2
    import maze_atlas
    world_folder=ROOT/'build/world';world_folder.mkdir(exist_ok=True)
    world_entries=[];world_checks=[];second_entries=[];maze_report=[]
    def store(data):
        pb,po=place(data)
        return f'            db {pb}\n            dw {po}\n'
    # One atlas per area serves colour and one-colour screens alike.
    area_refs=[]
    for region in range(6):
        packet,second,report=maze_atlas.build(region)
        (world_folder/f'maze{region}.raw').write_bytes(packet);(world_folder/f'maze{region}-glyphs.raw').write_bytes(second)
        first=native_art.compress_fast(packet);other=native_art.compress_fast(second)
        assert lz2.decompress(first)==packet and lz2.decompress(other)==second
        area_refs.append(store(first));second_entries.append(store(other))
        report['compressed_bytes']=len(first)+len(other);maze_report.append(report);print(report,flush=True)
    world_entries=area_refs+area_refs
    (world_folder/'maze-validation.json').write_text(json.dumps(maze_report,indent=2))
    for mode in ('colour','mono'):
        for surface in ('story','map'):
            stem=f'ui-{surface}-{mode}'
            raw,report=world_art.Atlas(0,mode=='mono').build(surface)
            data=native_art.compress_fast(raw)
            (world_folder/(stem+'.raw')).write_bytes(raw)
            assert lz2.decompress(data)==raw
            world_checks.append(dict(surface=surface,mode=mode,**pcg_validate.world_packet(raw)))
            world_entries.append(store(data))
    (world_folder/'pcg-validation.json').write_text(json.dumps(world_checks,indent=2))
    from PIL import Image
    fontplanes=[bytearray(),bytearray()]
    for c in range(32,128):
        mask=dracula_font.mask(chr(c)).resize((8,16),Image.Resampling.NEAREST)
        pixels=[sum(bool(mask.getpixel((x,y)))<<(7-x) for x in range(8)) for y in range(16)]
        for half in range(2):fontplanes[half].extend(bytes(pixels[half*8:half*8+8])+bytes(8))
    fontdata=b''.join(bytes(p)+bytes(512) for p in fontplanes)
    pb,po=place(fontdata)
    fontentry=f'native_font_asset: db {pb}\n            dw {po}\n'
    banks.update({b:bytes(d) for b,d in pool.items()})
    assert all(len(data)<=32768 for data in banks.values())
    assert not {26,27,29}&set(banks),'RAM 26, 27 and 29 hold the battle room and monster caches'
    checked['group_allocations']=allocations
    checked['expanded_ram_bytes']=sum(map(len,banks.values()))
    checked['expanded_ram_banks']=list(banks)
    checked['max_group_pcg_bytes']=max(a['pcg_bytes'] for a in allocations)
    checked['max_group_packet_bytes']=max(a['packet_bytes'] for a in allocations)
    (folder/'pcg-validation.json').write_text(json.dumps(checked,indent=2))
    for b,data in banks.items():write(f'build/DATA{b:02}.BNK',data)
    assert all('db 0,0,0,0,0,0,0,0,0' in e for i,e in enumerate(animation_entries) if i not in (2,14))
    write('src/gen/native.inc','native_assets:\n'+''.join(table)+'native_groups:\n'+''.join(groups)+'native_idle_assets:\n'+''.join(idle_entries)+fontentry+'world_assets:\n'+''.join(world_entries)+'world_assets2:\n'+''.join(second_entries)+'native_anim_assets:\n'+animation_entries[2]+animation_entries[14]+'bt_rooms:\n'+''.join(room_entries)+'bt_sprites:\n'+''.join(sprite_entries)+'fx_assets:\n'+''.join(fx_entries))
    write('src/gen/native_font.bin',fontdata)
    return banks

def loader(banks, size):
    s=(ROOT/'reference/hullbreach/src/loader.asm').read_text()
    s=s.replace('PROG_LEN    EQU $5000',f'PROG_LEN    EQU ${size:04X}')
    s=s.replace('HULLBREACH',"DRACULA'S CASTLE II").replace('HULLBRCH-LOADSG!','DRACULA-LOADSIG!')
    s=s.replace('SAVEBIN "../build/HULL.COM"','SAVEBIN "../build/DRACULA.COM"')
    # Do not treat read errors as EOF, or allow an oversized bank file to
    # overwrite the loader. Check bounded record copying before mapping RAM.
    s=s.replace('.eof:       or a\n            ret','.eof:       cp 1\n            jr z,.ok_eof\n            scf\n            ret\n.ok_eof:    or a\n            ret')
    s=s.replace('di\n            ld a,(cur_blk)\n            call blk_port',
        'ld a,(dest+1)\n            cp $80\n            jr c,.fits\n            scf\n            ret\n.fits:      di\n            ld a,(cur_blk)\n            call blk_port')
    write('src/loader.asm',s)
    names=[(28,'GAME.BIN'),(14,'PCG.BNK')]+[(b,f'DATA{b:02}.BNK') for b in banks]
    write('src/loadfiles.inc','\n'.join('            DB %d,0,"%-8s%-3s"'%(b,*n.split('.')) for b,n in names)+'\n')
    # Assemble phase blocks with the project's portable Python assembler.
    # Logical run addresses stay A000/F000; the COM file stores them packed.
    import zasm
    portable=re.sub(r'^\s*DEVICE.*$','',s,flags=re.M)
    portable=portable.replace('DISP $A000','ORG $A000').replace('DISP $F000','ORG $F000')
    portable=portable.replace('            ENT','            ORG reloc+reloc_end-reloc_start',1)
    portable=portable.replace('            ENT','            ORG final_src+final_end-final_start',1)
    portable=re.sub(r'^\s*SAVEBIN.*$','',portable,flags=re.M)
    write('src/loader_portable.asm',portable)
    asm=zasm.Asm(); out=asm.assemble(str(ROOT/'src/loader_portable.asm'))
    binary=bytearray(out.get(i,0) for i in range(0x100,0x711))
    for name,start,end in [('reloc','reloc_start','reloc_end'),('final_src','final_start','final_end')]:
        base=asm.sym[name]-0x100
        block=bytes(out.get(i,0) for i in range(asm.sym[start],asm.sym[end]))
        binary[base:base+len(block)]=block
    write('build/DRACULA.COM',bytes(binary))
    write('build/loader.sym',''.join(f'{v:04X} {k}\n' for k,v in asm.sym.items()))

def main():
    port_source.generate(); patterns(); keys(); banks=files();banks.update(native_files(set(banks),banks))
    # Old packing attempts must not masquerade as active read-only asset banks.
    for old in (ROOT/'build').glob('DATA[0-9][0-9].BNK'):
        if int(old.stem[4:]) not in banks:old.unlink()
    delta=(ROOT/'src/mb_delta32.asm').read_text().replace('            org $9000','').replace('delta32','native32_delta')
    a=delta.index('.active:');b=delta.index('.run:',a)
    delta=delta[:a]+'            push hl\n            call wait_frame\n            pop hl\n'+delta[b:]
    write('src/gen/delta32.inc',delta)
    # Retune the unchanged music sequences for 3.375 MHz / 210 T tone loop.
    vals=[min(65535,round(440*2**((n+23-69)/12)*65536/(3375000/210))) for n in range(1,96)]
    write('src/gen/notes.inc','note_steps:\n            dw '+','.join(map(str,vals))+'\n')
    def assemble():
        subprocess.run([sys.executable,str(ROOT/'original/tools/zasm.py'),str(ROOT/'src/main.asm'),'-o',str(ROOT/'build/GAME.BIN'),'--sym',str(ROOT/'build/game.sym'),'--start','0x8000'],check=True)
        sym={}
        for line in (ROOT/'build/game.sym').read_text().splitlines():
            parts=line.split()
            if len(parts)>=2:sym[parts[1]]=int(parts[0],16)
        return (ROOT/'build/GAME.BIN').read_bytes(),sym
    # The combat overlay is assembled at the maze work buffer, then stored in
    # expanded RAM and copied there when a battle starts.
    write('src/gen/ovl.inc','ovl_asset:  db 0\n            dw 0\n            dw 0\n')
    image,sym=assemble()
    ovl=image[sym['ovl_start']-0x8000:sym['ovl_end']-0x8000]
    home=min((b for b in banks if b>=5 and len(banks[b])+len(ovl)<=32768),key=lambda b:32768-len(banks[b]))
    off=len(banks[home]);banks[home]=banks[home]+ovl
    write(f'build/DATA{home:02}.BNK',banks[home])
    write('src/gen/ovl.inc',f'ovl_asset:  db {home}\n            dw {off}\n            dw {len(ovl)}\n')
    image,sym2=assemble()
    assert sym2==sym and image[sym['ovl_start']-0x8000:sym['ovl_end']-0x8000]==ovl
    write('build/GAME.BIN',image[:sym['code_end']-0x8000])
    print('combat overlay',len(ovl),'bytes in RAM',home,'; resident code ends',hex(sym['code_end']))
    loader(banks,(ROOT/'build/GAME.BIN').stat().st_size)
    fs={'DRACULA.COM':(ROOT/'build/DRACULA.COM').read_bytes(),'GAME.BIN':(ROOT/'build/GAME.BIN').read_bytes(),'PCG.BNK':(ROOT/'build/PCG.BNK').read_bytes()}
    fs.update({f'DATA{b:02}.BNK':data for b,data in banks.items()})
    fs['CCP.SYS']=(ROOT/'resources/CCP.SYS').read_bytes()
    disk_readme=(b"DRACULA'S CASTLE II - THE CASTLE AWAKENS\r\n"
        b'Microbee Premium Plus (1MB RAM, 32K PCG). Vibed by BPM 2026.\r\n\r\n'
        b'Type DRACULA to play. C = colour, M = one-colour monitor\r\n'
        b'(also on the title and while paused).\r\n\r\n'
        b'W/I/up forward. A/J/left, D/L/right turn. S/K/down turn around.\r\n'
        b'SPACE/RETURN act. M map. E inventory. P pause. Q quit (paused).\r\n'
        b'N music on/off. - SOFT music (for the speaker), + VZ music.\r\n'
        b'Joystick on PIO port A. Saves are RAM checkpoints, lost at power-off.\r\n\x1a')
    write('build/DISK_README.TXT',disk_readme)
    system=disk.unskew((ROOT/'resources/DRVB.DS8').read_bytes())
    disk.build_disk(system,fs,ROOT/'build/DRACULA.DS8')
    reread=disk.read_dir(disk.unskew((ROOT/'build/DRACULA.DS8').read_bytes()))
    assert set(fs)==set(reread)
    for n,data in fs.items(): assert reread[n][:len(data)]==data,n
    print('Disk directory and every file verified:',len(fs),'files')

if __name__=='__main__':main()
