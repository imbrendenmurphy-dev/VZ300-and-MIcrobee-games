"""Build the new renderer independently of the legacy port's build/entry."""
from pathlib import Path
import argparse
import json
import subprocess
import sys
import assets

R=Path(__file__).resolve().parents[1]
B=R/'build/native'
sys.path.insert(0,str(R/'tools'))
import disk


def run(*args,cwd=None):
    subprocess.run(args,cwd=cwd,check=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--reuse-assets',action='store_true')
    parser.add_argument('--compact-bilbies',action='store_true',help='benchmark native 12x8 artwork')
    parser.add_argument('--reuse-world',action='store_true',help='reuse unchanged world assets when rebuilding actors')
    parser.add_argument('--ram-background',action='store_true',help='slower experimental banked-raster renderer')
    parser.add_argument('--resident-cache',action='store_true',help='experimental persistent foreground glyph cache')
    parser.add_argument('--compiled-actors',action='store_true',help='banked precompiled actor alignment programs')
    parser.add_argument('--base',type=Path,default=R.parent/'LanternDeep/release/LANTERN.DS8')
    args=parser.parse_args()
    if sum([args.ram_background,args.resident_cache,args.compiled_actors])>1:parser.error('select only one experimental renderer')
    if not args.reuse_assets: assets.build(args.compact_bilbies,args.reuse_world,args.ram_background,args.resident_cache,args.compiled_actors)
    if args.compiled_actors:
        for name in ('colour','mono'):
            if (B/f'{name}.pcg').read_bytes()[:16] != bytes(16):
                raise ValueError(f'{name} glyph 0 must be blank for the compiled renderer')
    renderer='renderer_compiled.asm' if args.compiled_actors else ('renderer_resident.asm' if args.resident_cache else ('renderer_ram.asm' if args.ram_background else 'renderer.asm'))
    run('sjasmplus','--nologo','--sym=../build/native/engine.sym',
        '--lst=../build/native/engine.lst',renderer,cwd=R/'native')
    loader=(R/'src/loader.asm').read_text()
    start=loader.index('files:');end=loader.index('fail_bank:')
    loader=loader[:start]+'''files: DB 8,"NCOLOR  PCG"
        DB 9,"NMONO   PCG"
        DB 10,"NCOL0   MAP"
        DB 11,"NCOL1   MAP"
        DB 12,"NMON0   MAP"
        DB 13,"NMON1   MAP"
        DB 14,"NSPRITE BNK"
        DB 24,"NRCOLOR BNK"
        DB 25,"NRMONO  BNK"
        DB BLK_STAGE_HI,"ENGINE  HI "
        DB 0
'''+loader[end:]
    loader=loader.replace('../build/BILBIES.COM','BILBIES.COM')
    if not args.ram_background:
        loader=loader.replace('        DB 24,"NRCOLOR BNK"\n','').replace('        DB 25,"NRMONO  BNK"\n','')
    if args.resident_cache:
        loader=loader.replace('DB 14,"NSPRITE BNK"','DB 14,"RENDER  BNK"\n        DB 26,"NPOSES  BNK"')
    if args.compiled_actors:
        loader=loader.replace('        DB BLK_STAGE_HI', ''.join(f'        DB {16+i},"ACTOR{i}  BNK"\n' for i in range(8))+'        DB BLK_STAGE_HI')
    loader=loader.replace('N_BLOCKS    EQU 30','N_BLOCKS    EQU 32')
    loader=loader.replace('            ORG $0700','            ASSERT $ <= $0700\n            ORG $0700')
    (B/'loader.asm').write_text(loader)
    run('sjasmplus','--nologo','loader.asm',cwd=B)
    base=args.base.read_bytes()
    files={'CCP.SYS':disk.files(base)['CCP.SYS'],
           'BILBIES.COM':(B/'BILBIES.COM').read_bytes(),
           'ENGINE.HI':(B/'ENGINE.HI').read_bytes(),
           'NCOLOR.PCG':(B/'colour.pcg').read_bytes(),
           'NMONO.PCG':(B/'mono.pcg').read_bytes(),
           'NCOL0.MAP':(B/'colour0.map').read_bytes(),
           'NCOL1.MAP':(B/'colour1.map').read_bytes(),
           'NMON0.MAP':(B/'mono0.map').read_bytes(),
           'NMON1.MAP':(B/'mono1.map').read_bytes(),
           'NSPRITE.BNK':(B/'sprite-code.bnk').read_bytes(),
           'README.TXT':b'NATIVE MICROBEE RENDERER BENCHMARK\r\nType BILBIES. O/P: per-pixel pan. C/M: display. 1/4: 10/40 sprites.\r\nH: pause. GFX counts 50Hz frame edges during presentation (not CPU cycles).\r\nThis is a renderer test, not a completed game.\r\n\x1a'}
    if args.ram_background:
        files.update({'NRCOLOR.BNK':(B/'colour.raster.bnk').read_bytes(),
                      'NRMONO.BNK':(B/'mono.raster.bnk').read_bytes()})
    if args.resident_cache:
        del files['NSPRITE.BNK']
        files.update({'RENDER.BNK':(B/'RENDER.BNK').read_bytes(),
                      'NPOSES.BNK':(B/'sprite-code.bnk').read_bytes()})
    if args.compiled_actors:
        files.update({f'ACTOR{i}.BNK':(B/f'ACTOR{i}.BNK').read_bytes() for i in range(8)})
    image=disk.build(base,files)
    (B/'BILBIES-NATIVE.DS8').write_bytes(image)
    (B/'build-config.json').write_text(json.dumps({'ram_background':args.ram_background,
                                                'resident_cache':args.resident_cache,'compiled_actors':args.compiled_actors,'renderer':renderer},indent=2))
    print('Independent native renderer image:',len(image),'bytes')
