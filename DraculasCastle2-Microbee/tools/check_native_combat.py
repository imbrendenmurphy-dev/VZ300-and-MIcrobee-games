"""Validate native combat: room composition, every pose, HUD, movement, effects,
hit flash, the death dissolve, restoration, blanking and present cost."""
from check_port import *
from PIL import Image
import numpy as np
import battle_rooms
from mbee import FRAME_T

s=syms()
def call(p,name,a=None,frames=1000):
    invoke(p,s,name,a,frames)
def present(p):
    t=p.tick;call(p,'native_battle_present');return (p.tick-t)/FRAME_T
def scene(p):
    return p.screen_rgb()[16:200]

p=direct();invoke(p,s,'native_leave')
p.cpu.pc=s['new_game'];p.cpu.sp=0xEE00
assert p.run_until(s['explore_loop'],1000)==s['explore_loop']
checks=0;costs={'still':[],'moved':[],'stroke':[]}
plan=[(m,a) for m in range(1,13) for a in ((0,2,4) if m in battle_rooms.ORDINARY else (None,))]
for mode,label in enumerate(('colour','mono')):
    p.poke(s['mb_mode'],mode)
    refs={}
    for monster,area in plan:
        if area is not None:p.poke(s['cur_area'],area)
        call(p,'battle_load',monster)
        call(p,'set_css',p.peek(s['bt_css']))
        call(p,'native_battle_enter')
        assert p.crtc[1]==0,'scene stays blank until its first commit'
        assert bytes(p.pcg[14*2048:])==(ROOT/'src/gen/native_font.bin').read_bytes()
        call(p,'draw_battle_ui')
        pcg=bytes(p.pcg)
        poses=battle_rooms.poses(monster) if area is not None else None
        for frame in range(3):
            p.poke(s['bt_frame'],frame)
            present(p)
            assert (p.crtc[1],p.crtc[6],p.crtc[9])==(40,32,7)
            if area is None:
                want=np.asarray(Image.open(ROOT/'build/native'/f'battle{monster:02}-{frame}-{label}.png'))[16:200]
            else:
                pose=frame
                if monster==3 and frame<2:pose=3+p.peek(s['native_anim_phase'])
                key=(monster,area,pose)
                if key not in refs:refs[key]=np.asarray(battle_rooms.preview(monster,area,mode==1,pose))[16:200]
                want=refs[key]
            assert np.array_equal(scene(p),want),(label,monster,area,frame)
            assert bytes(p.pcg)==pcg and p.regs()['lower']==1
            checks+=1
        p.poke(s['bt_frame'],0);present(p)
        base=p.screen_rgb().copy()
        shadow=bytes(p.blocks[1][0x3100:0x3160])
        assert b'HP' in shadow and b'MP' in shadow and b'ATTACK' in shadow
        for dx,dy in ((1,0),(255,0),(0,1),(0,2)):
            p.poke(s['bt_dx'],dx);p.poke(s['bt_dy'],dy)
            costs['moved'].append(present(p))
            assert not np.array_equal(scene(p),base[16:200]),('movement',monster,dx,dy)
        p.poke(s['bt_dx'],0);p.poke(s['bt_dy'],0);present(p)
        assert np.array_equal(p.screen_rgb(),base),('movement restore',monster)
        for kind,steps in ((1,5),(2,10),(3,8)):
            for step in range(steps):
                p.poke(s['fx_kind'],kind);p.poke(s['fx_step'],step)
                costs['stroke'].append(present(p))
                assert not np.array_equal(scene(p),base[16:200]),('effect',kind,step)
                assert bytes(p.pcg)==pcg
        p.poke(s['fx_kind'],0);present(p)
        assert np.array_equal(p.screen_rgb(),base),('effect restore',monster)
        p.poke(s['bt_flash'],1);present(p)
        assert not np.array_equal(scene(p),base[16:200]),('hit flash',monster)
        p.poke(s['bt_flash'],0);costs['still'].append(present(p))
        call(p,'set_css',p.peek(s['bt_css'])^1)
        assert not np.array_equal(p.screen_rgb()[200:],base[200:]),'Player damage flash'
        call(p,'set_css',p.peek(s['bt_css']))
        assert np.array_equal(p.screen_rgb(),base),'Effects must restore the original scene'
        # Death: the slain monster stays until fx_death dissolves it into the room.
        p.poke(s['bt_mhp'],0);present(p)
        assert np.array_equal(p.screen_rgb()[16:200],base[16:200]),('slain monster vanished early',monster)
        call(p,'fx_death',frames=200)
        empty=np.asarray(Image.open(ROOT/'build/native'/f'battle{monster:02}-3-{label}.png'))[16:200] if area is None else \
              np.asarray(battle_rooms.encode_room(area,mode==1))[16:200]
        assert np.array_equal(scene(p),empty),('dissolve end',monster)
        call(p,'native_battle_leave')
        assert bytes(p.pcg)==(ROOT/'build/PCG.BNK').read_bytes()
        assert not p.peek(s['native_battle_active'])
        assert (p.crtc[1],p.crtc[6],p.crtc[9])==(64,32,7)
    print('PASS native combat:',len(plan),'monster/room pairs, poses, HUD, movement, spells, hit and death, restore',label,flush=True)
report={'native_scene_checks':checks,'native_combat_modes':2,'pairs':len(plan),'max_present_frames':{k:round(max(v),2) for k,v in costs.items()},
        'mean_present_frames':{k:round(sum(v)/len(v),2) for k,v in costs.items()}}
(ROOT/'build/combat-validation.json').write_text(json.dumps(report,indent=2))
print(report)
