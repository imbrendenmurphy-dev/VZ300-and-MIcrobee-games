"""Measure the preserved rules in isolation; this is not native integration.

Requires the compatibility baseline in build/, generated separately with
build.ps1 -CompatibilityBaseline. A controlled flat mask isolates walking
and falling CPU costs without confusing rendering with simulation time.
"""
import json
import statistics
import sys
from pathlib import Path

R=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(R/'tools'))
import smoke
from verify_port import call


def measure(state,blocker=False,count=40):
    p=smoke.machine();smoke.boot(p)
    p.m.a=1;call(p,'level_load');call(p,'game_init')
    s=smoke.S
    # Flat platform at y=60; forty live, already released actors.
    p.mem[s['MASK']:s['MASK']+5120]=bytes(5120)
    p.mem[s['MASK']+60*64:s['MASK']+61*64]=bytes([255])*64
    p.mem[s['v_ncrt']]=count;p.mem[s['v_released']]=count
    for i in range(count):
        x=64+i*8;y=59 if state==1 else 20
        record=bytearray(16)
        record[:6]=bytes([state,x&255,x>>8,y,i&1,i&7])
        if blocker and i==count//2:record[0]=6
        if state==7:record[5]=8;record[7]=12
        p.mem[s['CRT']+16*i:s['CRT']+16*i+16]=record
    costs=[]
    for _ in range(8):
        start=p.ticks();call(p,'game_tick');costs.append(p.ticks()-start)
    return {'initial_state':state,'one_blocker':blocker,'actors':count,'ticks':8,'tstates':costs,
            'maximum':max(costs),'mean':statistics.mean(costs)}


if __name__=='__main__':
    report={'walking':measure(1),'falling':measure(2),
            'walking_with_blocker':measure(1,True),'building_first_stick':measure(7),
            'count_survey':[measure(1,b,n) for n in (10,20,30,40) for b in (False,True)],
            'scope':'original game_tick on a synthetic flat collision mask; no graphics or inputs',
            'native_renderer_integrated':False}
    print(json.dumps(report,indent=2))
    (R/'test-output/native/simulation-budget.json').write_text(json.dumps(report,indent=2))
