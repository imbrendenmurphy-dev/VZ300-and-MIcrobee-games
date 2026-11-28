"""Measure integrated slice update work, excluding the deliberate 50Hz wait."""
import json
import re
import statistics
import test_renderer as t


def run(count, pan):
    p=t.machine()
    sym={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',
        (t.R/'build/native-simulation/simulation.sym').read_text())}
    bank=p.blocks[27]
    bank[sym['v_ncrt']]=count;bank[sym['v_released']]=count;bank[sym['v_hatch']]=16
    mask=bank[0x4000:0x5400]
    for i in range(count):
        x=24+i*7
        y=next((y-1 for y in range(1,80) if mask[y*64+x//8]&(128>>(x%8))),59)
        at=0x7b00+i*16
        bank[at:at+16]=bytes([1,x&255,x>>8,y,0,i&7])+bytes(10)
    p.m.a=27;t.call(p,'n_bank');t.call(p,'slice_convert');t.call(p,'slice_get_status');t.call(p,'n_home')
    costs=[];overflows=0
    for frame in range(18):
        if pan:t.setword(p,'n_camera',frame)
        costsum=0
        for name in ['slice_unmark','slice_input','slice_tick','slice_patches']:
            costsum+=t.call(p,name)
        if p.peek(t.S['slice_terrain_overflow']):overflows+=1;break
        costsum+=t.call(p,'n_present')
        if p.peek(t.S['n_overflow']):overflows+=1;break
        costsum+=t.call(p,'slice_mark')
        costs.append(costsum)
    data=costs[1:]
    return {'actors':count,'scrolling':pan,'samples':len(data),'overflow':overflows,
            'mean_tstates':round(statistics.mean(data)) if data else None,
            'max_tstates':max(data) if data else None,'sample_tstates':data}


def main():
    assert t.CONFIG.get('slice')
    cases=[run(count,pan) for pan in (False,True) for count in (10,20,40)]
    out={'mode':'colour','dimensions':[t.SW,t.SH],
         'scope':'Integrated keyboard scan, original simulation/clock bridge, terrain jobs, presentation and marker. Synthetic walking actors; no intentional wait or disk.',
         'hardware_verified':False,'graphics_target_tstates':135000,'cases':cases}
    (t.OUT/'slice-performance.json').write_text(json.dumps(out,indent=2))
    print(json.dumps(out,indent=2))


if __name__=='__main__':main()
