"""Validate native combat scenes, UI, effects, movement and display restoration."""
from check_port import *
from PIL import Image
import numpy as np
from mbee import L
import ctypes as C

L.mb_deadline_start.argtypes=[C.c_void_p]
L.mb_deadline_stat.argtypes=[C.c_void_p,C.c_int]
L.mb_deadline_stat.restype=C.c_int64
basic_invoke=invoke;deadline_margins=[]
def invoke(p,s,name,a=None,frames=1000):
    if name not in ('native_battle_present','set_css') or not p.peek(s['native_battle_active']):
        return basic_invoke(p,s,name,a,frames)
    p.keys=set();p.out(0x0b,0);p.cpu.sp=0xEDFC
    p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1);p.cpu.pc=s[name]
    if a is not None:p.cpu.a=a
    L.mb_set_bp(p.h,0xE1F0,1)
    hit=p.run_until(s['native32_delta.run'],frames)
    if hit==s['native32_delta.run']:
        L.mb_deadline_start(p.h)
        assert p.run_until(0xE1F0,frames)==0xE1F0
        if L.mb_deadline_stat(p.h,1):
            assert L.mb_deadline_stat(p.h,0)==0,(name,'missed scanout deadline')
            deadline_margins.append(int(L.mb_deadline_stat(p.h,2)))
    else:assert hit==0xE1F0,(name,hex(p.cpu.pc))
    L.mb_set_bp(p.h,0xE1F0,0)
    target=bytes(p.blocks[3][:3840])
    assert bytes(p.scr[:1280])+bytes(p.attr[:1280])+bytes(p.col[:1280])==target,'Uncommitted composed cells'

s=syms();p=direct();invoke(p,s,'native_leave')
p.cpu.pc=s['new_game'];p.cpu.sp=0xEE00
assert p.run_until(s['explore_loop'],1000)==s['explore_loop']
checks=0;max_frames=0
for mode,label in enumerate(('colour','mono')):
    p.poke(s['mb_mode'],mode)
    for monster in range(1,13):
        invoke(p,s,'battle_load',monster)
        invoke(p,s,'set_css',p.peek(s['bt_css']))
        invoke(p,s,'native_battle_enter')
        assert (p.crtc[6],p.crtc[9])==(32,7)  # Scene stays blank until its first commit.
        assert bytes(p.pcg[14*2048:])==(ROOT/'src/gen/native_font.bin').read_bytes()
        invoke(p,s,'draw_battle_ui')
        packet=(ROOT/'build/native'/f'combat{monster:02}-{label}.raw').read_bytes()
        for frame,offset in enumerate((0x5000,0x5f00,0x6e00,0x2000)):
            ptr=int.from_bytes(packet[2+frame*2:4+frame*2],'little')
            assert bytes(p.blocks[3][offset:offset+3840])==packet[ptr:ptr+3840]
        pcg=bytes(p.pcg)
        for frame in range(3):
            p.poke(s['bt_frame'],frame)
            start=p.frames
            invoke(p,s,'native_battle_present')
            assert (p.crtc[1],p.crtc[6],p.crtc[9])==(40,32,7)
            max_frames=max(max_frames,p.frames-start)
            expected=np.asarray(Image.open(ROOT/'build/native'/f'battle{monster:02}-{frame}-{label}.png'))
            if monster==3 and frame<2:
                phase=p.peek(s['native_anim_phase'])
                expected=np.asarray(Image.open(ROOT/'build/native'/f'anim-battle03-{phase}-{label}.png'))
            assert np.array_equal(p.screen_rgb()[16:200],expected[16:200]),(label,monster,frame)
            assert bytes(p.pcg)==pcg
            assert p.regs()['lower']==1
            checks+=1
        if monster in (1,4,12):p.png(str(ROOT/f'build/combat-{monster:02}-{label}.png'),aspect=15/16)
        # Frames and UI are independently selected; selected commands reverse.
        shadow=bytes(p.blocks[1][0x3100:0x3160])
        assert b'HP' in shadow and b'MP' in shadow and b'ATTACK' in shadow
        p.poke(s['bt_frame'],0)
        invoke(p,s,'native_battle_present')
        base=p.screen_rgb().copy()
        for dx,dy in ((1,0),(255,0),(0,1),(0,2)):
            p.poke(s['bt_dx'],dx);p.poke(s['bt_dy'],dy)
            invoke(p,s,'native_battle_present')
            assert not np.array_equal(p.screen_rgb()[16:200],base[16:200]),('movement',monster,dx,dy)
        p.poke(s['bt_dx'],0);p.poke(s['bt_dy'],0)
        for kind,steps in ((1,5),(2,10),(3,8)):
            for step in range(steps):
                p.poke(s['fx_kind'],kind);p.poke(s['fx_step'],step)
                invoke(p,s,'native_battle_present')
                assert not np.array_equal(p.screen_rgb()[16:200],base[16:200]),('effect',kind,step)
                assert bytes(p.pcg)==pcg
        p.poke(s['fx_kind'],0)
        p.poke(s['bt_flash'],1);invoke(p,s,'native_battle_present')
        assert not np.array_equal(p.screen_rgb()[16:200],base[16:200])
        p.poke(s['bt_flash'],0)
        invoke(p,s,'set_css',p.peek(s['bt_css'])^1)
        assert not np.array_equal(p.screen_rgb()[200:],base[200:]),'Player damage flash'
        invoke(p,s,'set_css',p.peek(s['bt_css']))
        assert np.array_equal(p.screen_rgb(),base),'Effects must restore the original scene'
        p.poke(s['bt_mhp'],0);p.poke(s['bt_dying'],1)
        for step in range(12):invoke(p,s,'native_battle_present')
        p.poke(s['bt_dying'],0);invoke(p,s,'native_battle_present')
        backdrop=np.asarray(Image.open(ROOT/'build/native'/f'battle{monster:02}-3-{label}.png'))
        assert np.array_equal(p.screen_rgb()[16:200],backdrop[16:200])
        invoke(p,s,'native_battle_leave')
        assert bytes(p.pcg)==(ROOT/'build/PCG.BNK').read_bytes()
        assert not p.peek(s['native_battle_active'])
        assert (p.crtc[1],p.crtc[6],p.crtc[9])==(64,32,7)
    print('PASS native combat: 12 monsters, HUD, movement, spells, hit/death effects, restoration',label,flush=True)
(ROOT/'build/combat-validation.json').write_text(json.dumps({'native_scene_checks':checks,'native_combat_modes':2,'native_monsters':12,'all_spell_steps':True,'hit_and_death_effects':True,'displacement':True,'pcg_restore':True,'max_normal_redraw_frames':max_frames,'integrated_transfer_checks':len(deadline_margins),'late_plane_writes':0,'min_row_margin_tstates':min(deadline_margins)},indent=2))
print('Normal native combat redraw, max emulated frames:',max_frames)
