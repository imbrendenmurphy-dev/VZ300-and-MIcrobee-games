from regression import *
def at(p,label,limit=300):
 assert p.run_until(S[label],limit)==S[label],(label,hex(p.m.pc))
def main():
 p=game();x=p.mem[S['see_x']]+256*p.mem[S['see_x']+1]
 p.keys={KEY['X']}
 for _ in range(5):frame(p)
 assert p.mem[S['see_x']]+256*p.mem[S['see_x']+1]>x
 p.keys=set();frame(p);tilt=p.mem[S['tilt']]
 p.keys={KEY['SPACE']};frame(p);frame(p);assert p.mem[S['tilt']]!=tilt
 p.keys={KEY['P']};at(p,'pause_game');p.keys=set();at(p,'pause_game.wait')
 tick=p.mem[S['tickpar']];p.run_frames(50);assert p.mem[S['tickpar']]==tick
 p.keys={KEY['P']};at(p,'wait_release');p.keys=set();at(p,'play_act.loop')
 assert p.mem[S['gameresult']]==0
 p.keys={KEY['P']};at(p,'pause_game');p.keys=set();at(p,'pause_game.wait')
 p.keys={KEY['Q']};assert p.run_until(0x7f00,200)==0x7f00
 assert p.mem[S['gameresult']]==2
 print('Move, flip, pause, resume and quit passed',flush=True)
 p=game();p.mem[S['score']:S['score']+3]=bytes.fromhex('999999');p.m.pc=S['hiscore_check'];p.m.sp=0xee00;p.mem[0xee00:0xee02]=bytes([0,0x7f])
 at(p,'hiscore_check.name')
 for i,ch in enumerate('ABC'):
  p.keys={KEY[ch]};at(p,'wait_release');p.keys=set()
  at(p,'hiscore_check.name' if i<2 else 'show_scores.wait')
 assert bytes(p.mem[S['hiscores']:S['hiscores']+6])==b'ABC'+bytes.fromhex('999999')
 assert bytes(p.mem[S['hiscores']+6:S['hiscores']+9])==b'BPM'
 snap(p,'top-clowns.png');print('High-score insertion, shifting, initials and table passed',flush=True)
 p=game();call(p,'curtain_close');snap(p,'curtain.png');print('Curtain transition passed',flush=True)
 report=[]
 for mono in (0,1):
  for act in (0,3,6,8):
   p=game(act);p.mem[S['mono_mode']]=mono
   p.m.a=act;call(p,'load_scene');call(p,'render');call(p,'present');p.m.pc=S['play_act'];p.m.sp=0xee00
   ts=[frame(p) for _ in range(90)]
   report.append({'mono':mono,'act':act+1,'mean_fps':3375000/statistics.mean(ts),'median_tstates':statistics.median(ts)})
 (R/'build/player-timing.json').write_text(json.dumps(report,indent=2));print(report,flush=True)
 p=game(3);t=p.ticks();before=int.from_bytes(p.mem[S['bonus_time']:S['bonus_time']+2],'little')
 p.run_frames(500)
 elapsed=(p.ticks()-t)/3375000
 after=int.from_bytes(p.mem[S['bonus_time']:S['bonus_time']+2],'little')
 updates=before-after
 assert abs(updates-elapsed*25)<5,(elapsed,updates)
 (R/'build/simulation-timing.json').write_text(json.dumps({'seconds':elapsed,'game_updates':updates,'target_hz':25},indent=2))
 print('Fixed 25 Hz rules / 50 Hz physics substeps:',elapsed,updates,flush=True)
if __name__=='__main__':main()
