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

# ---------------- front end (colour)
pp=run.boot(None); pp.run_frames(60)
big(pp).save(OUT+'/attract_1_monitor_choice.png')
run.press(pp,{'C'},4)
pp.run_frames(40); rec(pp,'title',40)               # ~3.2 s of title
pp.run_frames(250-40-160); big(pp).save(OUT+'/attract_2_title.png')
pp.run_frames(650-250); rec(pp,'hof',22); big(pp).save(OUT+'/attract_3_hall_of_fame.png')
pp.run_frames(1000-650-88); rec(pp,'howto',22); big(pp).save(OUT+'/attract_4_how_to_play.png')
pp.run_frames(1350-1000-88); rec(pp,'powerups',22); big(pp).save(OUT+'/attract_5_power_ups.png')
pp.run_frames(2200-1350-88); big(pp).save(OUT+'/attract_6_demo.png'); rec(pp,'demo',30)
# ---------------- stage intro from a real start
pp=run.boot(None); pp.run_frames(60); run.press(pp,{'C'},4); pp.run_frames(100)
run.press(pp,{'SPACE'},10); pp.run_frames(20)
big(pp).save(OUT+'/attract_7_stage_intro.png'); rec(pp,'intro',22)
# ---------------- monochrome front end
pp=run.boot(None, mono=True); pp.run_frames(60); run.press(pp,{'M'},4); pp.run_frames(250)
big(pp,True).save(OUT+'/attract_8_title_mono.png')

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
    pp.run_frames(warm)
    best=(-1,None)
    for i in range(look//10):
        pp.run_frames(10)
        b=busy(pp,S)
        if b>best[0]: best=(b,big(pp,mono))
    if gifname: rec(pp,gifname,gifn,mono)
    return best[1]
names=['outer_hull','the_hive','rock_belt','crystal_vein','dreadnought','gut_caverns','deep_field','the_core']
for st in range(8):
    fly(st,False,gifname='s%d'%st if st in (0,1,3,4,6) else None).save(OUT+'/game_stage%d_%s.png'%(st+1,names[st]))
fly(5,False,mono=True,gifname='mono5').save(OUT+'/game_stage6_mono.png')
pickle.dump(FR,open(OUT+'/frames.pkl','wb'))
print({k:len(v) for k,v in FR.items()})
