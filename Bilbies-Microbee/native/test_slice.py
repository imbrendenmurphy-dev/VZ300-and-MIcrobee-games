"""Exercise the built vertical slice with actual Z80 code and PP model keys."""
import json
import re
import test_renderer as t
from boot_test import type_text


def key(p, name):
    p.keys={t.ppmodel.KEY[name]};t.call(p,'slice_input')
    p.keys=set();t.call(p,'slice_input')


def main():
    assert t.CONFIG.get('slice') and t.COMPILED
    sim={m[1]:int(m[2],16) for m in re.finditer(
        r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',
        (t.R/'build/native-simulation/simulation.sym').read_text())}
    p=t.machine()
    assert p.lower==1 and p.peek(t.S['n_count'])==0
    before=bytes(p.blocks[27][0x4000:0x5400])
    for _ in range(52):t.call(p,'slice_tick')
    assert p.blocks[27][0x7b00]==1, 'first bilby did not walk'
    key(p,'5');key(p,'SPACE')
    assert p.blocks[27][0x7b00]==7, 'keyboard builder assignment failed'
    assert p.blocks[27][sim['v_skill']+4]==5, 'skill inventory did not decrease'
    costs=[]
    for _ in range(70):
        costs.append(t.call(p,'slice_tick'))
        if bytes(p.blocks[27][0x4000:0x5400])!=before:break
    assert bytes(p.blocks[27][0x4000:0x5400])!=before, 'builder did not change collision'
    patch_cost=t.call(p,'slice_patches')
    count=p.peek(t.S['n_patch_count'])
    assert count and not p.m.f&1, 'builder edit not translated to visible terrain'
    jobs=bytes(p.mem[t.PATCH_BUFFER:t.PATCH_BUFFER+19*count])
    t.call(p,'n_present')
    t.verify_sprites(p,p.peek(t.S['n_count']),jobs)
    oldcam=int.from_bytes(p.mem[t.S['n_camera']:t.S['n_camera']+2],'little')
    key(p,'P');assert int.from_bytes(p.mem[t.S['n_camera']:t.S['n_camera']+2],'little')==oldcam+1
    t.call(p,'slice_patches');assert p.peek(t.S['n_patch_count']) and not p.m.f&1
    key(p,'M');assert p.peek(t.S['n_mono'])==1
    t.call(p,'slice_patches');assert p.peek(t.S['n_patch_count']) and not p.m.f&1
    key(p,'H');tick=bytes(p.blocks[27][sim['v_gtick']:sim['v_gtick']+2])
    for _ in range(4):t.call(p,'slice_tick')
    assert bytes(p.blocks[27][sim['v_gtick']:sim['v_gtick']+2])==tick
    key(p,'R')
    assert bytes(p.blocks[27][0x4000:0x5400])==before, 'restart did not restore collision terrain'
    assert p.peek(t.S['n_paused'])==0 and p.peek(t.S['n_count'])==0
    t.call(p,'slice_patches');assert p.peek(t.S['n_patch_count'])==0
    # Real ROM, CP/M and loader path, not direct injection of the engine.
    q=t.Machine(rom=(t.R/'resources/bn60.rom').read_bytes(),disk=(t.B/'BILBIES-NATIVE.DS8').read_bytes())
    q.m.pc=0x8000;q.run_frames(60);type_text(q,'B')
    for _ in range(100):
        q.run_frames(10)
        if 'A>' in q.text():break
    assert 'A>' in q.text(), 'CP/M prompt not reached'
    type_text(q,'BILBIES\r')
    for _ in range(500):
        q.run_frames(10)
        if q.crtc[1]==80 and q.crtc[9]==15:break
    assert q.crtc[1]==80 and q.crtc[9]==15, 'slice launch failed'
    q.run_frames(300)
    q.save_png(t.OUT/'slice-disk-boot.png',1)
    report={'rom_cpm_launch':True,'keyboard_builder_assignment':True,
            'builder_collision_and_visible_patch':True,'patch_survives_pan_and_mono':True,
            'pause_stops_simulation':True,'restart_restores_terrain':True,'edit_patch_count':count,
            'edit_patch_tstates':patch_cost,'max_tick_bridge_tstates':max(costs),
            'model':'ppmodel + z80 1.2.0, not independent emulator or hardware'}
    (t.OUT/'slice-results.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
