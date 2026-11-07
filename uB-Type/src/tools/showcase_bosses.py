"""uB-TYPE showcase: screenshots and GIF frames from the emulator"""
import sys, pickle
sys.path.insert(0,'/home/claude/ubtype/tools')
import run, perfcmp, mbee
import numpy as np
from PIL import Image
OUT=sys.argv[1]
FR={}   # gif segments: name -> list of frames (512x384 RGB arrays)

def big(pp, mono=False):
    return Image.fromarray(pp.screen_rgb(mono)).resize((1024,768), Image.NEAREST)
def small(pp, mono=False):
    return np.array(Image.fromarray(pp.screen_rgb(mono)).resize((512,384), Image.NEAREST))
def rec(pp, name, nfr, mono=False, step=4):
    fr=FR.setdefault(name,[])
    for i in range(nfr):
        pp.run_frames(step); fr.append(small(pp,mono))

ONLY=sys.argv[2] if len(sys.argv)>2 else ''
if ONLY!='boss':
  pass
# ---------------- gameplay: the attract pilot flies each stage
def busy(pp,S):
    n=sum(1 for i in range(20) if pp.peek(S['ENTS']+16*i))
    n+=sum(1 for i in range(12) if pp.peek(S['BULS']+8*i))
    n+=sum(1 for i in range(10) if pp.peek(S['SHOTS']+8*i))
    return n
def fly(st, boss, mono=False, warm=60, look=500, gifname=None, gifn=36):
    pp=run.boot(st, mono=mono); S=pp.S
    pp.poke(S['demomode'],1); pp.poke(S['demotm'],255); pp.poke(S['demotm']+1,255)
    pp.run_until(S['prof_reset'],4000)
    if boss: perfcmp.poke_start(pp.poke, pp.peekw, S, True)
    pp.run_until(S['mainloop'],4000)
    pp.poke(S['demomode'],1); pp.poke(S['demotm'],255); pp.poke(S['demotm']+1,255)
    if boss:     # wait for the boss to arrive
        for i in range(300):
            pp.run_frames(10)
            if any(pp.peek(S['ENTS']+16*k)==13 for k in range(20)): break
    pp.run_frames(warm)
    best=(-1,None)
    for i in range(look//10):
        pp.run_frames(10)
        b=busy(pp,S)
        if b>best[0]: best=(b,big(pp,mono))
    if gifname: rec(pp,gifname,gifn,mono)
    return best[1]
names=['outer_hull','the_hive','rock_belt','crystal_vein','dreadnought','gut_caverns','deep_field','the_core']
for st in (0,2,4,7):
    fly(st,True,warm=60,look=400,gifname='b%d'%st).save(OUT+'/game_boss%d_%s.png'%(st+1,names[st]))
pickle.dump(FR,open(OUT+'/frames_boss.pkl','wb'))
print({k:len(v) for k,v in FR.items()})
