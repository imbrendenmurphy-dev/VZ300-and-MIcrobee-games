from test_port import *
import statistics,sys
def call(p,name):
 p.m.sp=0xee00;p.mem[0xee00:0xee02]=bytes([0,0x7f]);p.m.pc=S[name]
 assert p.run_until(0x7f00,500)==0x7f00,(name,hex(p.m.pc))
def game(act=0):
 p=new();p.mem[S['act']]=act;p.mem[S['difficulty']]=1;p.mem[S['lives']]=99;p.mem[S['nextlife']]=2
 call(p,'act_setup');call(p,'render');call(p,'present')
 p.m.sp=0xee00;p.m.pc=S['play_act'];return p
def frame(p):
 p.run_until(S['update'],100)
 t=p.ticks();p.run_until(S['play_act.loop'],100)
 p.run_until(S['update'],100)
 return p.ticks()-t
def main():
 report=[]
 for act in range(9):
  p=game(act);p.mem[S['demo']]=1
  times=[]
  for i in range(120):
   # Test demo AI without 30-second attract timeout or deaths ending this probe.
   p.mem[S['lives']]=99;p.mem[S['demo_timer']:S['demo_timer']+2]=bytes(2)
   times.append(frame(p))
  snap(p,f'act-{act+1}.png')
  row={'act':act+1,'median_frame_tstates':statistics.median(times),'max_frame_tstates':max(times),'mean_fps':3375000/statistics.mean(times),'score':bytes(p.mem[S['score']:S['score']+3]).hex(),'balloons_left':p.mem[S['balloons_left']]}
  report.append(row);print(row,flush=True)
 (R/'build/regression.json').write_text(json.dumps(report,indent=2))
if __name__=='__main__':main()
