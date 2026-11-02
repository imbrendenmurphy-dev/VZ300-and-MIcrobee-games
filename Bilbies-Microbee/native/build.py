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
    parser.add_argument('--base',type=Path,default=R.parent/'LanternDeep/release/LANTERN.DS8')
    args=parser.parse_args()
    if not args.reuse_assets: assets.build()
    run('sjasmplus','--nologo','--sym=../build/native/engine.sym',
        '--lst=../build/native/engine.lst','renderer.asm',cwd=R/'native')
    loader=(R/'src/loader.asm').read_text()
    start=loader.index('files:');end=loader.index('fail_bank:')
    loader=loader[:start]+'''files: DB 8,"NCOLOR  PCG"
        DB 9,"NMONO   PCG"
        DB 10,"NCOL0   MAP"
        DB 11,"NCOL1   MAP"
        DB 12,"NMON0   MAP"
        DB 13,"NMON1   MAP"
        DB BLK_STAGE_HI,"ENGINE  HI "
        DB 0
'''+loader[end:]
    loader=loader.replace('../build/BILBIES.COM','BILBIES.COM')
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
           'README.TXT':b'NATIVE MICROBEE RENDERER BENCHMARK\r\nType BILBIES. O/P: per-pixel pan. C/M: display. 1/4: 10/40 sprites.\r\nThis is a renderer test, not a completed game.\r\n\x1a'}
    image=disk.build(base,files)
    (B/'BILBIES-NATIVE.DS8').write_bytes(image)
    print('Independent native renderer image:',len(image),'bytes')
