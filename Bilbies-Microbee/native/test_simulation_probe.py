"""Compare the relocated native simulation probe to the compatibility engine.

Both execute Z80 instructions. Compare collision, creatures and game variables
for walking, blocker, falling/bomb and terrain-modifying skill scenarios.
The probe intentionally does not render terrain or sound.
"""
from pathlib import Path
import json
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'native'))
import verify_blockers as v


def main():
    sim=v.symbols(ROOT/'build/native-simulation/simulation.sym')
    code=(ROOT/'build/native-simulation/SIM.BIN').read_bytes()
    results=[]
    for kind in ['one','unsupported','bomb','multiple','builder','digger']:
        original,old=v.machine();probe,_=v.machine()
        v.setup(original,old,'one' if kind in ('builder','digger') else kind)
        v.setup(probe,old,'one' if kind in ('builder','digger') else kind)
        if kind in ('builder','digger'):
            for p in [original,probe]:
                for i in range(8):
                    p.mem[old['CRT']+i*16]=7 if kind=='builder' else 11
                    p.mem[old['CRT']+i*16+5]=8
                    p.mem[old['CRT']+i*16+7]=12
        mask=bytes(probe.mem[old['MASK']:old['MASK']+5120])
        probe.mem[0x600:0x600+len(code)]=code
        probe.mem[sim['MASK']:sim['MASK']+5120]=mask
        costs=[]
        for tick in range(16):
            v.call(original,old,'game_tick')
            costs.append(v.call(probe,sim,'game_tick'))
            assert bytes(original.mem[old['CRT']:old['CRT']+640])==bytes(probe.mem[sim['CRT']:sim['CRT']+640]),(kind,tick,'creatures')
            assert bytes(original.mem[old['MASK']:old['MASK']+5120])==bytes(probe.mem[sim['MASK']:sim['MASK']+5120]),(kind,tick,'mask')
            for name in ['v_released','v_saved','v_lost','v_nblock','v_res','v_dug','v_seed','v_end']:
                assert original.peek(old[name])==probe.peek(sim[name]),(kind,tick,name)
        results.append({'case':kind,'matching_ticks':16,'max_tstates':max(costs)})
    print(json.dumps(results,indent=2))
    (ROOT/'test-output/native-simulation-results.json').write_text(json.dumps(results,indent=2))

if __name__=='__main__':main()
