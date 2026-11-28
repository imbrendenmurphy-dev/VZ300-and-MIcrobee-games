"""Repeatable renderer workload survey. Costs are modelled Z80 T-states.

This is a renderer harness, not a playable level or integrated physics test.
Use after building each desired variant, and retain output under a unique name.
"""
import argparse
import json
import statistics
from pathlib import Path
import test_renderer as t


def scenario(count, pan, mono):
    p=t.machine()
    p.mem[t.S['n_mono']]=mono
    t.call(p,'n_load_pcg')
    original=bytes(p.mem[t.S['n_entities']:t.S['n_entities']+160])
    p.mem[t.S['n_count']]=count
    samples=[]
    for frame in range(18):
        p.mem[t.S['n_anim']]=frame%8
        for i in range(count):
            x=int.from_bytes(original[i*4:i*4+2],'little')+frame*2
            p.mem[t.S['n_entities']+i*4:t.S['n_entities']+i*4+2]=x.to_bytes(2,'little')
        t.setword(p,'n_camera',frame if pan else 0)
        samples.append(t.call(p,'n_present'))
        if frame in (0,9,17):
            before=t.bitplane(p)
            try:
                t.verify_sprites(p,count)
            except AssertionError as exc:
                raise AssertionError(f'count={count} pan={pan} mono={mono} frame={frame}: {exc}') from exc
            assert (before==t.bitplane(p)).all(), 'presentation mismatch'
    samples=samples[1:]
    return {'actors':count,'scrolling':pan,'monochrome':bool(mono),
            'samples':len(samples),'mean_tstates':round(statistics.mean(samples)),
            'max_tstates':max(samples),'min_tstates':min(samples),
            'sample_tstates':samples}


def main():
    a=argparse.ArgumentParser()
    a.add_argument('--output',type=Path,required=True)
    args=a.parse_args()
    cases=[scenario(n,pan,mono) for mono in (0,1) for pan in (False,True)
           for n in (10,20,30,40)]
    out={'resolution':[640,256],'sprite_dimensions':[t.SW,t.SH],
         'configuration':t.CONFIG,'clock_hz_assumed':3375000,
         'graphics_target_tstates':135000,'simulation_tick_tstates':270000,
         'scope':'Renderer only; evenly spaced moving actors, 17 measured frames; no simulation or input. Pan advances one pixel per frame.',
         'physics_and_graphics_combined':False,'hardware_verified':False,'cases':cases}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(out,indent=2))
    print(json.dumps(out,indent=2))


if __name__=='__main__':main()
