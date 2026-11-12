"""Validate expanded pose RAM, eight-way deltas and actual Z80 scanout timing."""
from check_port import *
from PIL import Image
import numpy as np,ctypes as C
from mbee import L
import pcg_validate

L.mb_deadline_start.argtypes=[C.c_void_p]
L.mb_deadline_stat.argtypes=[C.c_void_p,C.c_int];L.mb_deadline_stat.restype=C.c_int64
s=syms();timings=[];slow=[];margins=[];checks=0;shots=[];loads=[]

def present(p,name):
    start=p.frames;p.cpu.sp=0xEDFC;p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1);p.cpu.pc=s[name]
    L.mb_set_bp(p.h,0xE1F0,1)
    hit=p.run_until(s['native32_delta.run'],1000)
    if hit==s['native32_delta.run']:
        L.mb_deadline_start(p.h)
        assert p.run_until(0xE1F0,1000)==0xE1F0
        assert L.mb_deadline_stat(p.h,0)==0,'Extended animation missed scanout deadline'
        if L.mb_deadline_stat(p.h,1):margins.append(int(L.mb_deadline_stat(p.h,2)))
    else:assert hit==0xE1F0,hex(p.cpu.pc)
    L.mb_set_bp(p.h,0xE1F0,0)
    assert bytes(p.scr[:1280])+bytes(p.attr[:1280])+bytes(p.col[:1280])==bytes(p.blocks[3][:3840])
    return p.frames-start

for mode,key in (('colour','C'),('mono','M')):
    for variant in ('monster',):
        p=direct(key)
        if variant=='battle':
            invoke(p,s,'battle_load',3);invoke(p,s,'set_css',p.peek(s['bt_css']))
            start=p.frames;invoke(p,s,'native_battle_enter');loads.append(p.frames-start)
            invoke(p,s,'draw_battle_ui')
        else:
            p.poke(s['native_monster'],2);start=p.frames;invoke(p,s,'native_group_load');loads.append(p.frames-start)
        assert p.peek(s['native_anim_enabled'])==1
        stem=ROOT/f'build/native/extended-{variant}03-{mode}'
        maps=stem.with_suffix('.maps').read_bytes();deltas=stem.with_suffix('.deltas').read_bytes();pcg=stem.with_suffix('.pcg').read_bytes()
        assert len(maps)==30720 and len(deltas)==14336 and len(pcg)<=1792*16
        assert bytes(p.blocks[30][:30720])==maps
        assert bytes(p.blocks[2][:14336])==deltas
        assert bytes(p.pcg[:len(pcg)])==pcg
        assert len({maps[i*3840:(i+1)*3840] for i in range(8)})==8
        for phase in range(8):
            frame=maps[phase*3840:(phase+1)*3840]
            preview=pcg_validate.planes(pcg,frame[:1280],frame[1280:2560],frame[2560:],max_glyphs=1792)
            expected=np.asarray(Image.open(ROOT/f'build/native/anim-{variant}03-{phase}-{mode}.png'))
            assert np.array_equal(np.asarray(preview),expected)
            # Reconstruct an incoming delta independently, including loop wrap.
            previous=(phase-1)%8;target=bytearray(maps[previous*3840:(previous+1)*3840]);at=phase*1792
            while deltas[at]:
                n=deltas[at];pos=int.from_bytes(deltas[at+1:at+3],'little')-0xf000;at+=3
                assert 0<n<=40 and pos//40==(pos+n-1)//40
                for plane in range(3):target[plane*1280+pos:plane*1280+pos+n]=deltas[at:at+n];at+=n
            assert target==frame
        initial_pcg=bytes(p.pcg)
        for i in range(24):
            phase=i%8
            if variant=='battle':
                p.poke(s['native_anim_phase'],phase);p.poke(s['bt_frame'],0);name='native_battle_present'
            else:p.poke(s['native_frame'],phase+4);name='native_group_show'
            elapsed=present(p,name)
            (timings if i else slow).append(elapsed)
            expected=np.asarray(Image.open(ROOT/f'build/native/anim-{variant}03-{phase}-{mode}.png'))
            actual=p.screen_rgb()
            assert np.array_equal(actual if variant=='monster' else actual[16:200],expected if variant=='monster' else expected[16:200]),(mode,variant,phase)
            assert bytes(p.pcg)==initial_pcg,'Idle loop rewrote PCGs'
            if mode=='colour' and variant=='monster' and i<8:shots.append(Image.fromarray(actual).resize((640,512),Image.Resampling.NEAREST))
            checks+=1
        # Nonsequential pose selection must stage a full map correctly.
        for phase in (2,6,1):
            if variant=='battle':p.poke(s['native_anim_phase'],phase)
            else:p.poke(s['native_frame'],phase+4)
            slow.append(present(p,name))
            actual=p.screen_rgb();expected=np.asarray(Image.open(ROOT/f'build/native/anim-{variant}03-{phase}-{mode}.png'))
            assert np.array_equal(actual[16:200],expected[16:200])
        # The real idle timer advances the extended phase instead of an 8px bob.
        if variant=='battle':
            previous=p.peek(s['native_anim_phase']);p.poke(s['bt_anim'],1)
            invoke(p,s,'idle_anim')
            assert p.peek(s['native_anim_phase'])==(previous+1)%8 and p.peek(s['bt_dy'])==0
        print('PASS eight-pose Ghost, expanded RAM, delta loop/wrap and scanout',variant,mode,flush=True)

# Combat: the Ghost's eight phases are laid into whichever room the fight is in.
import battle_rooms
from mbee import FRAME_T
battle_costs=[]
for mode,key in (('colour','C'),('mono','M')):
    p=direct(key)
    for area in (1,3):
        p.poke(s['cur_area'],area)
        invoke(p,s,'battle_load',3);invoke(p,s,'set_css',p.peek(s['bt_css']))
        invoke(p,s,'native_battle_enter');invoke(p,s,'draw_battle_ui')
        assert p.peek(s['native_anim_enabled'])==1
        for i in list(range(16))+[2,6,1]:
            phase=i%8 if i<16 else i
            p.poke(s['native_anim_phase'],phase);p.poke(s['bt_frame'],0)
            t=p.tick;invoke(p,s,'native_battle_present');battle_costs.append((p.tick-t)/FRAME_T)
            want=np.asarray(battle_rooms.preview(3,area,mode=='mono',3+phase))
            assert np.array_equal(p.screen_rgb()[16:200],want[16:200]),(mode,area,phase)
            checks+=1
        invoke(p,s,'native_battle_leave')
    print('PASS Ghost phases composed into rooms',mode,[round(x,1) for x in battle_costs[-19:]],flush=True)
assert max(timings)<=4,timings
shots[0].save(ROOT/'build/ghost-eight-poses.gif',save_all=True,append_images=shots[1:],duration=300,loop=0,disposal=2)
report={'pose_count':8,'scene_checks':checks,'frame_cache_bank':30,'frame_cache_bytes':30720,'delta_cache_bank':2,'delta_cache_bytes':14336,'max_cached_transition_frames':max(timings),'max_full_composition_frames':max(slow),'max_encounter_preload_frames':max(loads),'max_battle_phase_frames':round(max(battle_costs),2),'late_plane_writes':0,'transfer_checks':len(margins),'min_row_margin_tstates':min(margins),'pcg_unchanged_during_idle':True,'hardware_tested':False}
(ROOT/'build/animation-validation.json').write_text(json.dumps(report,indent=2));print(report)
