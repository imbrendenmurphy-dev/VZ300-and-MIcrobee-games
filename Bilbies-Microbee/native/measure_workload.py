"""Sample original scripted solutions at game_tick entry; compatibility model only."""
from pathlib import Path
import argparse,json,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import smoke,ppmodel,z80
S=smoke.S
sys.path.insert(0,str(smoke.R/'original-tools'))
import levels

def sample(index):
 p=smoke.machine();smoke.boot(p);p.mem[S['mb_present']]=0xc9
 p.mem[S['v_lvl']]=index;p.m.pc=S['test_run']
 tick=S['game_tick'];end=S['test_run.h'];p.m.set_breakpoint(tick);p.m.set_breakpoint(end)
 count=0; peak=0;peak_visible=0;peak_128=0;peak_320=0; hist=[0]*41; visible_hist=[0]*41
 limit=p.ticks()+40000*ppmodel.FRAME_T
 while p.ticks()<limit:
  p.m.ticks_to_stop=ppmodel.FRAME_T;event=p.m.run()
  if event & z80.Z80Machine._END_OF_FRAME:p.frames+=1
  if not event & z80.Z80Machine._BREAKPOINT_HIT:continue
  if p.m.pc==end:break
  active=[]
  for i in range(40):
   addr=S['CRT']+16*i;state=p.mem[addr]
   if 1<=state<16:active.append((p.mem[addr+1]+256*p.mem[addr+2],p.mem[addr+3]))
  count+=1;peak=max(peak,len(active));hist[len(active)]+=1
  # Actual original camera, 128 logical-pixel view, including 7-pixel sprite clipping.
  x0=p.mem[S['v_scrb']]*4;y0=p.mem[S['v_scry']]
  vis=sum(x0-4<=x<x0+132 and y0-1<=y<y0+50 for x,y in active)
  peak_visible=max(peak_visible,vis);visible_hist[vis]+=1
  # Any hypothetical 128 logical-pixel window; ignores vertical clipping.
  xs=sorted(x for x,y in active);j=0
  for i,x in enumerate(xs):
   while xs[j]<x-135:j+=1
   peak_128=max(peak_128,i-j+1)
  j=0
  for i,x in enumerate(xs):
   while xs[j]<x-327:j+=1
   peak_320=max(peak_320,i-j+1)
  p.m.clear_breakpoint(tick);p.m.ticks_to_stop=1
  ev=p.m.run()
  if ev&z80.Z80Machine._END_OF_FRAME:p.frames+=1
  p.m.set_breakpoint(tick)
 p.m.clear_breakpoint(tick);p.m.clear_breakpoint(end)
 return {'level':index,'name':levels.LEVELS[index].name,'completed':p.m.pc==end,'ticks':count,
  'maximum_active':peak,'maximum_in_original_camera':peak_visible,'max_in_any_128_logical_pixel_window':peak_128,'max_in_any_320_logical_pixel_window':peak_320,
  'active_histogram':hist,'original_camera_histogram':visible_hist,'saved':p.peek(S['v_saved'])}
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('levels',nargs='*',type=int,default=[0,5,6,11,12,17,18,23]);args=a.parse_args()
 results=[]
 for i in args.levels:
  r=sample(i);results.append(r);print(json.dumps(r),flush=True)
 (smoke.OUT/'solution-workload.json').write_text(json.dumps(results,indent=2))
