"""Check native combat command paths and flee/death exits with keyboard input."""
from check_port import *
from mbee import L

s=syms()
def start(mode,monster=12):
    p=direct(mode);invoke(p,s,'native_leave')
    p.cpu.pc=s['new_game'];p.cpu.sp=0xEE00
    assert p.run_until(s['explore_loop'],1000)==s['explore_loop']
    p.poke(s['hp'],100);p.poke(s['maxhp'],100);p.poke(s['def'],50)
    p.poke(s['battle_boss'],monster);p.poke(s['bt_loaded'],0)
    p.cpu.sp=0xEDFC;p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1)
    p.cpu.pc=s['battle']
    assert p.run_until(s['choose_command.l'],1000)==s['choose_command.l']
    assert p.peek(s['native_battle_active'])
    return p

def choose(p,cursor,target):
    p.poke(s['bt_cursor'],cursor)
    p.keys=set();p.run_frames(4);p.keys={'SPACE'}
    assert p.run_until(s[target],1000)==s[target],target
    p.keys=set()

def round_end(p):
    assert p.run_until(s['choose_command.l'],1000)==s['choose_command.l']
    assert p.peek(s['bt_turn'])==1
    assert p.peek(s['native_battle_active'])

def restored(p,result):
    assert p.cpu.a==result
    assert not p.peek(s['native_battle_active'])
    assert not p.peek(s['native_active'])
    assert bytes(p.pcg)==(ROOT/'build/PCG.BNK').read_bytes()
    assert (p.crtc[1],p.crtc[6],p.crtc[9])==(64,32,7)

for mode in ('C','M'):
    p=start(mode);p.poke(s['spells'],1);p.poke(s['mp'],12)
    hp=p.peek(s['bt_mhp']);choose(p,1,'fx_fire');round_end(p)
    assert p.peek(s['mp'])==8 and p.peek(s['bt_mhp'])<hp
    for item,key in ((1,'1'),(2,'2')):
        p=start(mode);p.poke(s['items']+item,2);p.poke(s['hp'],30)
        choose(p,2,'choose_item.w');p.keys={key}
        target='fx_heal' if item==1 else 'fx_holy'
        assert p.run_until(s[target],1000)==s[target]
        p.keys=set();round_end(p)
        assert p.peek(s['items']+item)==1
        if item==1:assert p.peek(s['hp'])>30
    p=start(mode);choose(p,3,'battle_run.defend');round_end(p)
    p=start(mode,1)
    L.mb_set_bp(p.h,0xE1F0,1)
    for attempt in range(20):
        p.poke(s['bt_cursor'],4)
        p.keys=set();p.run_frames(5)
        p.keys={'SPACE'}
        if p.run_frames(450)==0xE1F0:break
    L.mb_set_bp(p.h,0xE1F0,0)
    assert p.cpu.pc==0xE1F0,'Flee path never completed'
    restored(p,1)
    p=start(mode);p.poke(s['hp'],0)
    p.cpu.sp=0xEDFC;p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1)
    p.cpu.pc=s['battle_lost'];L.mb_set_bp(p.h,0xE1F0,1)
    for attempt in range(15):
        p.keys=set();hit=p.run_frames(100)
        if hit==0xE1F0:break
        p.keys={'SPACE'};hit=p.run_frames(30)
        if hit==0xE1F0:break
    L.mb_set_bp(p.h,0xE1F0,0)
    assert p.cpu.pc==0xE1F0
    restored(p,2)
    print('PASS native combat magic, potion, holy water, defend, flee and death:',mode,flush=True)
(ROOT/'build/combat-paths-validation.json').write_text(json.dumps({'modes':2,'paths':['magic','potion','holy water','defend','flee','death'],'flee_and_death_restore':True},indent=2))
