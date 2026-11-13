import sys,os,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from check_maze import *
from mbee import FRAME_T
def run(key='C',prof=False):
    p=direct(key);p.cpu.pc=s['new_game'];p.cpu.sp=0xEE00
    assert p.run_until(s['explore_loop'],3000)==s['explore_loop']
    p.poke(s['show_intro'],0)
    res={}
    for region in range(6):
        p.poke(s['cur_area'],region);p.poke(s['px'],255);call(p,'enter_area',frames=3000)
        call(p,'draw_explore_screen')
        t=[]
        for turn in range(8):
            call(p,'read_input');p.cpu.pc=s['explore_loop'];p.cpu.sp=0xEE00
            start=p.tick;p.keys={'D'}
            assert p.run_until(s['after_move'],100)==s['after_move']
            a=p.tick
            if prof and region==1 and turn==3:p.profile(True)
            p.keys=set();assert p.run_until(s['explore_loop'],500)==s['explore_loop']
            if prof and region==1 and turn==3:
                p.profile(False);pr=p.prof()
                inv=sorted((v,k) for k,v in s.items())
                import bisect
                agg={}
                for pc in np.nonzero(pr)[0]:
                    i=bisect.bisect_right(inv,(pc,'~'))-1
                    name=inv[i][1].split('.')[0];agg[name]=agg.get(name,0)+int(pr[pc])
                print(sorted(agg.items(),key=lambda t:-t[1])[:14])
            t.append((p.tick-a)/FRAME_T)
        res[region]=(round(min(t),2),round(sum(t)/len(t),2),round(max(t),2))
    return res
if __name__=='__main__':
    print('turn redraw frames (min, mean, max) per area:',run('C',True))
