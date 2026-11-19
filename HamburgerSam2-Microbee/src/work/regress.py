from test_native import *
import json,statistics
report={}
b=Bee();b.until('title_screen.l')
b.keys={22};b.call('read_input');b.keys=set();b.call('read_input')
assert b.peek(sym['mono_mode'])==1
b.shot('03-title-monochrome')
b.keys={22};b.call('read_input');b.keys=set();b.call('read_input')
assert b.peek(sym['mono_mode'])==0
b=Bee();b.until('title_screen.l');b.keys={55};b.until('main_menu.l');b.keys=set();b.run(35)
b.shot('04-menu')
b.keys={55};b.until('play_kitchen.loop');b.keys=set()
assert b.peek(sym['lives'])==4 and b.peek(sym['peppers'])==6
# Real input movement, pepper, pause and resume.
x=b.peek(sym['sx']);b.keys={13}
for _ in range(20):b.call('game_frame')
assert b.peek(sym['sx'])<x
b.keys={55}
for _ in range(3):b.call('game_frame')
assert b.peek(sym['peppers'])==5
b.keys=set()
report['keyboard_walk_and_pepper']=True
b.m.memory[sym['godmode']]=1;b.m.memory[sym['autoplay']]=1
times=[]
for i in range(500):
 t=b.call('game_frame');times.append(t)
assert b.peek(sym['drops'])>0,(b.peek(sym['sx']),b.peek(sym['sy']))
b.shot('05-gameplay-colour')
report['autoplay_drops']=b.peek(sym['drops']);report['median_frame_tstates']=statistics.median(times)
report['estimated_frame_rate_at_3_375MHz']=round(3375000/statistics.median(times),2)
# Every layout, including Classic, renders through the actual native Z80 code.
for k in range(9):
 b.call('dl_reset');b.m.memory[sym['kitchen']]=min(k,7);b.m.memory[sym['playclassic']]=int(k==8)
 b.m.a=k;b.call('load_kitchen');b.call('draw_kitchen');b.call('setup_round');b.call('wipe_show')
 for i in range(12):b.call('game_frame')
 assert b.peek(sym['npc'])>0
 if k in [3,7]:b.shot('kitchen-'+str(k+1))
report['nine_layouts']=True
b.call('dl_reset');b.m.memory[sym['mono_mode']]=1;b.m.memory[sym['playclassic']]=0;b.m.memory[sym['kitchen']]=0
b.m.a=0;b.call('load_kitchen');b.call('draw_kitchen');b.call('setup_round');b.call('wipe_show')
for i in range(70):b.call('game_frame')
b.shot('06-gameplay-monochrome')
assert all(c in (0,15) for c in b.colour[:1000])
report['mono_native_colour_ram']=True
assert any(b.pcg[0]) and any(b.pcg[8])
report['both_pcg_pages_used']=True
Path('work/regression.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))


