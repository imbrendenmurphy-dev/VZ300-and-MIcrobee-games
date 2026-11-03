"""Replay the original Up the Bank skill events through the slice bridge.

Actor selection is automated here; actual keyboard assignment is covered by
test_slice.py. Rendering is sampled, not timed as a full real-time playthrough.
"""
import json
import re
import test_renderer as t


def main():
    assert t.CONFIG.get('slice')
    s={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',
      (t.R/'build/native-simulation/simulation.sym').read_text())}
    p=t.machine();events=[[5,232,236,False],[410,256,264,False]]
    frames=0;render_checks=0
    while frames<4000 and not p.peek(t.S['slice_goal_end']):
        bank=p.blocks[27];gt=int.from_bytes(bank[s['v_gtick']:s['v_gtick']+2],'little')
        x=bank[0x7b01]+256*bank[0x7b02]
        for event in events:
            start,lo,hi,fired=event
            if not fired and gt>=start and lo<=x<=hi and bank[0x7b00]==1:
                n=p.peek(t.S['n_count']);slots=bytes(p.mem[t.S['slice_slots']:t.S['slice_slots']+n])
                assert 0 in slots,'scripted bilby missing from native records'
                p.mem[t.S['slice_selected']]=slots.index(0)
                p.mem[t.S['slice_skill']]=4
                before=bank[s['v_skill']+4]
                t.call(p,'slice_assign')
                assert p.blocks[27][s['v_skill']+4]==before-1
                event[3]=True
        t.call(p,'slice_tick');frames+=1
        if frames%40==0:
            t.call(p,'slice_patches')
            assert not p.m.f&1,'terrain jobs overflow during scripted solution'
            t.call(p,'n_present')
            assert not p.peek(t.S['n_overflow']),'glyph pool overflow during scripted solution'
            render_checks+=1
    saved=p.peek(t.S['slice_saved']);quota=p.peek(t.S['slice_quota'])
    assert all(e[3] for e in events) and p.peek(t.S['slice_goal_end']) and saved>=quota,(events,frames,saved,quota)
    result={'level':'UP THE BANK','simulation_ticks':frames//2,'saved':saved,'quota':quota,
            'original_script_events':events,'sampled_render_checks':render_checks,
            'scope':'Model, automated actor assignment, rendering sampled; not real-time full gameplay or hardware'}
    (t.OUT/'slice-solution.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))


if __name__=='__main__':main()
