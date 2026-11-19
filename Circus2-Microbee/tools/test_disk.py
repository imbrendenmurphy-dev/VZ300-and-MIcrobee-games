from test_port import *
import argparse
def type_text(p,t):
 for c in t:
  p.keys={KEY['RET' if c=='\r' else c]};p.run_frames(4);p.keys=set();p.run_frames(4)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--rom',required=True);a=ap.parse_args()
 p=PP(rom=Path(a.rom).read_bytes(),disk=(R/'build/CIRCUS2.DS8').read_bytes());p.m.pc=0x8000
 p.run_frames(60);type_text(p,'B');p.run_frames(800)
 assert 'A>' in p.text(),p.text()
 (R/'build/boot-prompt.txt').write_text(p.text());print('Booted to A>',flush=True)
 type_text(p,'CIRCUS2\r')
 assert p.run_until(S['attract.wait'],15000)==S['attract.wait'],(hex(p.m.pc),p.mem[S['asset_block']],p.mem[S['load_count']],p.text())
 pcg=(R/'build/B22.DAT').read_bytes();assert bytes(p.pcg)==pcg
 for block in range(4,25):assert bytes(p.blocks[block])==(R/'build'/f'B{block:02}.DAT').read_bytes(),block
 snap(p,'disk-title.png');print('Disk command loaded code and complete PCG',flush=True)
 p.keys={KEY['SPACE']};p.run_until(S['wait_release'],100);p.keys=set()
 assert p.run_until(S['play_act.loop'],600)==S['play_act.loop'],hex(p.m.pc)
 for i in range(10):p.run_until(S['update'],100);p.run_until(S['play_act.loop'],100)
 snap(p,'disk-gameplay.png')
 (R/'build/disk-validation.json').write_text(json.dumps({'prompt':True,'command':'CIRCUS2','pcg_loaded':True,'geometry':[80,2,10,512]},indent=2))
 print('Gameplay launched from disk',flush=True)
if __name__=='__main__':main()
