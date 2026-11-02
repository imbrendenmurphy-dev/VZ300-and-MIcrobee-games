"""Execute native Z80 builds, comparing all terrain pixels and save I/O.

--solutions executes the original solution scripts with only mb_present
replaced by RET. That is a simulation regression test, not display/timing QA.
"""
import argparse
import json
from pathlib import Path
import sys
import smoke
import disk

sys.path.insert(0,str(smoke.R/'original-tools'))
import levels
import lvlkit

S = smoke.S


def call(p, label, frames=500):
    p.m.sp = 0xFFF0
    p.mem[0xFFF0:0xFFF2] = b'\x00\x6f'
    p.m.pc = S[label]
    assert p.run_until(0x6F00,frames), 'routine timeout: '+label


def verify_maps():
    report=[]
    p=smoke.machine()
    smoke.boot(p)
    for i,lv in enumerate(levels.LEVELS+[levels.TITLE]):
        p.m.a=i
        call(p,'level_load')
        g,m=lvlkit.raster(lv)
        bad=0
        for y in range(lv.height):
            for x in range(lv.width):
                colour=(p.mem[0x4000+y*128+x//4]>>(6-2*(x&3)))&3
                solid=(p.mem[S['MASK']+y*64+x//8]>>(7-(x&7)))&1
                bad += colour != g[y][x] or solid != m[y][x]
        report.append({'level':i,'name':lv.name,'mismatches':bad})
        print(i,lv.name,'pixel/mask differences',bad,flush=True)
        assert bad==0,report[-1]
    return report


def verify_save():
    p=smoke.machine()
    smoke.boot(p)
    p.mem[S['mb_mono']]=1
    p.mem[S['v_unlock']]=8
    p.mem[S['v_lvl']]=7
    call(p,'save_game')
    assert p.peek(S['sv_error'])==0
    q=smoke.machine(disk=p.disk)
    smoke.boot(q)
    assert [q.peek(S[k]) for k in ('mb_mono','v_unlock','v_lvl')]==[1,8,7]
    q.run_frames(200)
    q.save_png(smoke.OUT/'monochrome-title.png',1)
    # Never inject a call while video RAM overlays the normal upper stack.
    assert q.run_until(S['frame_sync'],500)
    q.write_protect=True
    before=q.disk
    call(q,'save_game')
    assert q.peek(S['sv_error'])==1 and before==q.disk
    raw=bytearray(disk.logical(p.disk))
    raw[20480]=0xE5  # deleted SAVE.DAT entry; bytes still physically remain
    q=smoke.machine(disk=bytes(disk.physical(raw)))
    smoke.boot(q)
    before=q.disk
    call(q,'save_game')
    assert q.peek(S['sv_error'])==1 and before==q.disk
    print('Save/restart, monochrome preference, write protection, deleted-save refusal PASS',flush=True)
    return {'restart':True,'write_protected':True,'deleted_save':True}


def solutions():
    report=[]
    for i,lv in enumerate(levels.LEVELS):
        p=smoke.machine()
        smoke.boot(p)
        p.mem[S['mb_present']]=0xC9
        p.mem[S['v_lvl']]=i
        p.m.pc=S['test_run']
        hit=p.run_until(S['test_run.h'],40000)
        saved=p.peek(S['v_saved'])
        row={'level':i,'name':lv.name,'ended':bool(hit),'saved':saved,'required':lv.save}
        print('solution',row,flush=True)
        report.append(row)
    assert all(r['ended'] and r['saved']>=r['required'] for r in report)
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--solutions',action='store_true')
    args=parser.parse_args()
    report={'maps':verify_maps(),'save':verify_save()}
    (smoke.OUT/'verification.json').write_text(json.dumps(report,indent=2))
    if args.solutions:
        report['headless_solutions']=solutions()
    (smoke.OUT/'verification.json').write_text(json.dumps(report,indent=2))
