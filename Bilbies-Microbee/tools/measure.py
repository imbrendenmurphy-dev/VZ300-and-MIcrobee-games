"""Measure executed T-states; do not confuse CPU throughput with monitor QA."""
import json
import smoke
from verify_port import call

p=smoke.machine()
smoke.boot(p)
p.m.a=0
call(p,'level_load')
call(p,'comp_terrain')
call(p,'blit_back')


def cost():
    start=p.ticks()
    call(p,'mb_present')
    return p.ticks()-start


p.mem[smoke.S['mb_force']]=1
forced=cost()
unchanged=cost()
p.mem[smoke.S['v_scrb']]=1
call(p,'comp_terrain')
call(p,'blit_back')
scroll=cost()
result={'cpu_hz':3375000,'frame_tstates':67500,
        'forced':forced,'unchanged':unchanged,'scroll_4_logical_pixels':scroll,
        'frames':{k:round(v/67500,3) for k,v in
                  [('forced',forced),('unchanged',unchanged),('scroll',scroll)]}}
print(json.dumps(result,indent=2))
(smoke.OUT/'performance.json').write_text(json.dumps(result,indent=2))
