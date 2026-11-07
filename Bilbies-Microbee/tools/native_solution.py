"""One original solution with the actual native renderer enabled."""
import json
import smoke

p=smoke.machine()
smoke.boot(p)
p.mem[smoke.S['v_lvl']]=0
p.m.pc=smoke.S['test_run']
hit=p.run_until(smoke.S['test_run.h'],180000)
result={'level':0,'renderer_enabled':True,'ended':bool(hit),
        'saved':p.peek(smoke.S['v_saved']),'required':5,'tstates':p.ticks()}
print(json.dumps(result),flush=True)
(smoke.OUT/'native-solution.json').write_text(json.dumps(result,indent=2))
p.save_png(smoke.OUT/'native-solution.png',1)
assert hit and result['saved']>=5
