"""Run combat through the real game routines and keyboard, with test-only stats."""
from check_port import *
from mbee import L

s=syms(); p=direct('M' if '--mono' in sys.argv else 'C');p.run_frames(130)
invoke(p,s,'native_leave')
# Reach the real exploration loop with a normal new-game initialization.
p.cpu.pc=s['new_game'];p.cpu.sp=0xEE00
assert p.run_until(s['explore_loop'],1000)==s['explore_loop']
p.poke(s['show_intro'],0)
for monster in range(1,13):
    p.poke(s['hp'],200);p.poke(s['maxhp'],200)
    p.poke(s['atk'],60);p.poke(s['def'],50)
    p.poke(s['battle_boss'],monster);p.poke(s['bt_loaded'],0)
    p.cpu.sp=0xEDFC;p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1)
    p.cpu.pc=s['battle'];p.keys=set();p.out(0x0B,0)
    L.mb_set_bp(p.h,0xE1F0,1)
    for attempt in range(80):
        p.keys={'SPACE'};hit=p.run_frames(40)
        if hit==0xE1F0:break
        p.keys=set();hit=p.run_frames(70)
        if hit==0xE1F0:break
    L.mb_set_bp(p.h,0xE1F0,0);p.keys=set()
    assert p.cpu.pc==0xE1F0,(monster,hex(p.cpu.pc))
    assert p.cpu.a==0,(monster,'result',p.cpu.a)
    assert bytes(p.pcg)==(ROOT/'build/PCG.BNK').read_bytes()
    print('PASS battle win',monster,'frames',p.frames,flush=True)

# Model a held/resting player for a longer run with periodic control changes.
p.poke(s['cur_area'],0);p.poke(s['px'],255);invoke(p,s,'enter_area')
p.cpu.pc=s['explore_loop'];p.cpu.sp=0xEE00
asset_banks={int(f.stem[4:]) for f in (ROOT/'build').glob('DATA*.BNK')}
for i in range(120):
    p.keys=({'A'} if i%4==0 else {'D'} if i%4==2 else set())
    p.run_frames(50)
    assert 0xE900<p.cpu.sp<=0xEE00,hex(p.cpu.sp)
    assert p.regs()['lower'] in asset_banks|{1,2,3,28,30,31}
    assert 0x8000<=p.cpu.pc<s['code_end'],hex(p.cpu.pc)
    assert p.peek(s['native_active']) and p.peek(s['world_loaded'])==1+(6 if '--mono' in sys.argv else 0)
    assert (p.crtc[6],p.crtc[9])==(32,7)
print('PASS 6000-frame native exploration/input soak',flush=True)
for f in (ROOT/'build').glob('DATA*.BNK'):
    data=f.read_bytes();assert bytes(p.blocks[int(f.stem[4:])][:len(data)])==data,'Read-only asset bank modified: '+f.name
report=json.loads((ROOT/'build/validation.json').read_text())
report.update(combat_wins=12,combat_test_stats='boosted hero, normal keyboard combat',soak_frames=6000)
if '--mono' in sys.argv:report.update(monochrome_combat_wins=12,monochrome_soak_frames=6000)
(ROOT/'build/validation.json').write_text(json.dumps(report,indent=2))
