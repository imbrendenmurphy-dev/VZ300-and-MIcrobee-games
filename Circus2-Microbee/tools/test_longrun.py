from regression import *
import hashlib
def main():
 p=new();p.keys={KEY['SPACE']};p.run_until(S['wait_release'],100);p.keys=set()
 assert p.run_until(S['play_act.loop'],1500)==S['play_act.loop']
 for act in range(9):
  assert p.mem[S['act']]==act
  p.mem[S['lives']]=99;p.mem[S['endtimer']]=1;p.mem[S['gameresult']]=0
  assert p.run_until(S['act_clear'],400)==S['act_clear']
  assert p.run_until(S['game_main.actloop'],1500)==S['game_main.actloop'],(act,hex(p.m.pc))
  assert p.run_until(S['play_act.loop'],1500)==S['play_act.loop'],(act,hex(p.m.pc))
 assert p.mem[S['act']]==0 and p.mem[S['encore']]==1
 print('Forced complete sequence: nine acts, bonus transitions, encore passed',flush=True)
 for mono in (0,1):
  p=new();p.mem[S['mono_mode']]=mono;p.m.pc=S['attract'];p.m.sp=0xef00
  p.run_frames(7000)
  assert 0x100<=p.m.pc<0xf000
  for block in range(4,25):assert bytes(p.blocks[block])==(R/'build'/f'B{block:02}.DAT').read_bytes(),(mono,block)
  print('140-second attract soak and all bank integrity checks:',mono,flush=True)
 (R/'build/longrun-validation.json').write_text(json.dumps({'forced_act_transitions':9,'encore':True,'attract_seconds_per_mode':140,'asset_banks_unchanged':True},indent=2))
if __name__=='__main__':main()
