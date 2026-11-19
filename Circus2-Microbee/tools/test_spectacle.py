from regression import *
def main():
 p=new()
 p.keys={KEY['M']}
 assert p.run_until(S['wait_release'],200)==S['wait_release']
 p.keys=set()
 assert p.run_until(S['attract.wait'],200)==S['attract.wait']
 assert p.mem[S['mono_mode']]==1
 assert bytes(p.pcg)==(R/'build/B23.DAT').read_bytes()
 assert set(p.col[:1000])=={15}
 snap(p,'title-monochrome.png')
 report=[]
 for mono in (0,1):
  for act in range(9):
   p=new();p.mem[S['mono_mode']]=mono;p.mem[S['act']]=act;p.mem[S['lives']]=99;p.mem[S['nextlife']]=2
   call(p,'act_setup');call(p,'render');call(p,'present')
   assert bytes(p.pcg)==(R/'build'/f'B{4+act*2+mono:02}.DAT').read_bytes()
   p.m.sp=0xee00;p.m.pc=S['play_act'];p.mem[S['demo']]=1
   times=[]
   for i in range(100):
    p.mem[S['lives']]=99;p.mem[S['demo_timer']:S['demo_timer']+2]=bytes(2)
    times.append(frame(p))
   snap(p,f"{'mono' if mono else 'colour'}-act-{act+1}.png")
   row={'mono':mono,'act':act+1,'fps':3375000/statistics.mean(times),'score':bytes(p.mem[S['score']:S['score']+3]).hex()}
   report.append(row);print(row,flush=True)
 (R/'build/spectacle-tests.json').write_text(json.dumps(report,indent=2))
 print('M toggle, all 18 scene/mode combinations, PCG residency and AI gameplay passed')
if __name__=='__main__':main()
