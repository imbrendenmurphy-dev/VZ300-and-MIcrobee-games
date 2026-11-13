import sys, subprocess
sys.path.insert(0,'.'); sys.path.insert(0,'../tools')
import build_race as B
def run(half, secs=40, vlog=None):
    B.HALF_INIT = half
    src,_ = B.source(); asm, org, data, vz = B.assemble(src, 'MAXQ.VZ')
    args=[B.EMU, vz, str(int(70630*50*secs)), '--memdump','mem_game.bin']
    if vlog: args += ['--vramlog', vlog, '2']
    subprocess.run(args, capture_output=True, stdin=subprocess.DEVNULL)
    m=open('mem_game.bin','rb').read()
    w=lambda n: m[asm.sym[n]]|m[asm.sym[n]+1]<<8
    f,fr=w('FIELDS'),w('FRAMES')
    return f/max(1,fr), 50*fr/max(1,f)
for mode, name in ((0, 'game'), (2, 'game + M (HUD split)'), (1, 'attract (horizon split)')):
    B.ATTRACT_MODE = mode
    for half in ((0, 1) if mode == 0 else (1,)):
        fpf, fps = run(half)
        print(f'{name:24s} half {"on " if half else "off"}: {fpf:.2f} fields per frame = {fps:.1f} fps')
