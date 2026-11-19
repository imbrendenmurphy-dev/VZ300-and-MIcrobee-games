from pathlib import Path
import re,json
from PIL import Image
from ppmodel import PP,KEY
R=Path(__file__).resolve().parents[1]
S={k:int(v,16) for k,v in re.findall(r'^(\S+): EQU 0x([0-9A-F]+)',(R/'build/circus2.sym').read_text(),re.M)}
def snap(p,n):
 Image.fromarray(p.screen_rgb()).resize((960,750),Image.Resampling.NEAREST).save(R/'build'/n)
def new():
 p=PP();p.set_p50(12);d=(R/'build/CIRCUS2.COM').read_bytes();p.mem[256:256+len(d)]=d;p.m.pc=256
 p.mem[S['start']+3:S['start']+6]=bytes(3)
 for block in range(4,25):p.blocks[block][:]=(R/'build'/f'B{block:02}.DAT').read_bytes()
 assert p.run_until(S['attract.wait'],200)==S['attract.wait'],hex(p.m.pc)
 return p
def main():
 p=new();snap(p,'title-progress.png');print('Title initialized',flush=True)
 p.keys={KEY['SPACE']}
 assert p.run_until(S['wait_release'],100)==S['wait_release'],hex(p.m.pc)
 p.keys=set()
 assert p.run_until(S['play_act.loop'],600)==S['play_act.loop'],hex(p.m.pc)
 costs=[]
 for i in range(12):
  p.run_until(S['update'],100);t=p.ticks()
  assert p.run_until(S['play_act.loop'],100)==S['play_act.loop'],hex(p.m.pc)
  costs.append(p.ticks()-t)
 snap(p,'game-progress.png');print('render+update costs',costs,flush=True)
 (R/'build/initial-test.json').write_text(json.dumps({'render_update_tstates':costs,'code_end':S['code_end'],'mode':[p.crtc[1],p.crtc[6],p.crtc[9]+1]},indent=2))
if __name__=='__main__':main()
