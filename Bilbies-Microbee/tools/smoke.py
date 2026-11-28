"""Native engine execution tests in the repository's non-cycle-exact model."""
from pathlib import Path
import json
import re
import sys
import ppmodel

R = Path(__file__).resolve().parents[1]
B = R/'build'
OUT = R/'test-output'
OUT.mkdir(exist_ok=True)
S = {m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',(B/'bilbies.sym').read_text())}


def machine(disk=None):
    p = ppmodel.PP(disk=disk if disk is not None else (B/'BILBIES.DS8').read_bytes())
    p.set_p50(0x0F)
    data = (B/'BILBIES.HI').read_bytes()
    p.mem[0x8000:0x8000+len(data)] = data
    data = (B/'levels.bin').read_bytes()
    p.blocks[9][0x4000:0x4000+len(data)] = data
    data = (B/'PCG.BNK').read_bytes()
    p.blocks[8][:len(data)] = data
    p.m.pc = S['mb_boot']
    return p


def boot(p):
    assert p.run_until(S['mb_settings'],200)
    p.keys = {ppmodel.KEY['SPACE']}
    assert p.run_until(S['front_main'],200)
    p.keys = set()


if __name__ == '__main__':
    p = machine()
    boot(p)
    print('Native initialization reached front_main',hex(p.m.pc),flush=True)
    p.run_frames(400)
    p.save_png(OUT/'native-title.png',1)
    print('title PC',hex(p.m.pc),'bank',p.lower,flush=True)
    print('CRTC',p.crtc[:16],flush=True)
    # Directly invoke the original scripted test entry for a chosen level.
    p.mem[S['v_lvl']] = int(sys.argv[1]) if len(sys.argv)>1 else 0
    p.m.pc = S['test_run']
    p.run_frames(2000)
    p.save_png(OUT/'native-level.png',1)
    state = {k:p.peek(S[k]) for k in ('v_lvl','v_released','v_saved','v_lost','v_res','v_gtick')}
    state.update(pc=hex(p.m.pc), bank=p.lower, frame=p.frames)
    print(json.dumps(state),flush=True)
    (OUT/'smoke.json').write_text(json.dumps(state,indent=2))
