"""High score -> name entry -> SAVE.DAT on the disk image -> reload it."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from run import boot, peek, peekw, tap, BUILD, symbols, blk_port
from mbee import Mbee
disk = (BUILD / 'SKYLARK.DS8').read_bytes()

def boot_disk(d):
    import run
    S = symbols()
    pp = Mbee(disk=d)
    for f in BUILD.glob('B??.BNK'):
        b = int(f.stem[1:]); x = f.read_bytes()
        pp.blocks[b][0:len(x)] = np.frombuffer(x, np.uint8)
    x = (BUILD / 'SKY.BIN').read_bytes()
    pp.blocks[0][0:len(x)] = np.frombuffer(x, np.uint8)
    pp.out(0x50, blk_port(1)); pp.cpu.pc = 0x8000; pp.cpu.sp = 0xEFF0; pp.S = S
    return pp

pp = boot_disk(disk); S = pp.S
pp.run_frames(30); tap(pp, 'C'); pp.run_frames(40)
for i, v in enumerate((0x00, 0x09, 0x87, 0x65)):
    pp.poke(S['score'] + i, v)
pp.cpu.pc = S['game_end']
pp.run_frames(60)
print(pp.text().split('\n')[6:10])
for k in ('UP', 'UP', 'SPACE', 'DOWN', 'SPACE', 'SPACE'):
    tap(pp, k, 4)
pp.run_frames(100)
print('save error', peek(pp, 'sv_error') if 'sv_error' in S else '?')
d2 = pp.disk()
i = d2.find(b'SKYLARKSAVE1')
print('signature at', i, d2[i:i + 13 + 21])
# boot again from the written disk: is the hall of fame back?
pp2 = boot_disk(d2); S2 = pp2.S
pp2.run_frames(30); tap(pp2, 'C'); pp2.run_frames(40)
print('reloaded top entry', [hex(pp2.peek(S2['hof'] + k)) for k in range(4)], bytes(pp2.peek(S2['hof'] + 4 + k) for k in range(3)))
