"""Instruction-level hot spots for the real Z80 backend, not a host estimate."""
from collections import Counter
import bisect
import json
import test_renderer as t
import z80

p=t.machine()
t.call(p,'n_terrain')
p.mem[t.S['n_count']]=40
p.m.sp=0xEFF0;p.mem[0xEFF0:0xEFF2]=b'\x00\x6f'
p.m.pc=t.S['n_sprites']
p.m.set_breakpoint(0x6F00)
cycles=Counter();instructions=0
while p.m.pc!=0x6F00:
    pc=p.m.pc;before=p.ticks()
    p.m.ticks_to_stop=1
    event=p.m.run()
    if event&z80.Z80Machine._END_OF_FRAME:p.frames+=1
    cycles[pc]+=p.ticks()-before
    instructions+=1
    assert instructions<1000000
labels=sorted((v,k) for k,v in t.S.items() if k.startswith('n_'))
addresses=[v for v,k in labels]
regions=Counter()
for pc,cost in cycles.items():
    regions[labels[bisect.bisect_right(addresses,pc)-1][1]]+=cost
report={'instructions':instructions,'tstates':sum(cycles.values()),
        'unique_cells':p.peek(t.S['n_slot']),
        'hotspots':regions.most_common(20)}
print(json.dumps(report,indent=2))
(t.OUT/'profile.json').write_text(json.dumps(report,indent=2))
