"""Drive the real game code in the emulator; compare every view with the Python reference."""
import sys,os,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from check_port import ROOT,direct,syms
from PIL import Image
import maze_native as MN
s=syms()
def call(p,name,a=None,frames=1500):
    p.keys=set();p.cpu.sp=0xEDFC;p.poke(0xEDFC,0xF0);p.poke(0xEDFD,0xE1);p.cpu.pc=s[name]
    if a is not None:p.cpu.a=a
    assert p.run_until(0xE1F0,frames)==0xE1F0,(name,hex(p.cpu.pc))
def expected(p,region):
    art=MN.build_area(region)
    view={};objs={}
    cells=[p.peek(s['view_cells']+i) for i in range(20)]
    for pos,(d,l) in enumerate(MN.POSITIONS):
        c=cells[pos];call(p,'classify',c);k=p.cpu.a;dec=p.cpu.c
        if k:view[d,l]=(k,dec)
        elif c&7==0 and c>>3 and l==0 and d:
            call(p,'event_sprite',c>>3)
            if p.cpu.a:objs[d]=p.cpu.a
    return np.asarray(MN.picture(MN.compose(art,view,objs,facing=p.peek(s['pdir'])),mono=False)),view,objs
if __name__=='__main__':
    out=str(ROOT/'build/maze-check');os.makedirs(out,exist_ok=True)
    modes=sys.argv[1] if len(sys.argv)>1 else 'C'
    for key in modes:
        mono=key=='M'
        p=direct(key);p.cpu.pc=s['new_game'];p.cpu.sp=0xEE00
        assert p.run_until(s['explore_loop'],3000)==s['explore_loop']
        Image.fromarray(p.screen_rgb(mono)).save(f'{out}/start-{key}.png')
        p.poke(s['show_intro'],0)
        for region in range(6):
            p.poke(s['cur_area'],region);p.poke(s['px'],255);call(p,'enter_area',frames=3000)
            cells=[i for i in range(256) if p.blocks[1][0x7c00+i]&7==0]
            ev=[i for i in cells if p.blocks[1][0x7c00+i]>>3]
            pos=[p.peek(s['py'])*16+p.peek(s['px'])]+cells[::max(1,len(cells)//24)]
            # stand next to every event cell as well, looking at it
            ims=[];bad=0;n=0;times=[]
            for cell in pos+ev:
                for d in range(4):
                    x,y=cell%16,cell//16
                    if cell in ev:
                        dx,dy=[(0,1),(-1,0),(0,-1),(1,0)][d]
                        x+=dx;y+=dy
                        if not(0<=x<16 and 0<=y<16) or p.blocks[1][0x7c00+y*16+x]&7:continue
                    p.poke(s['px'],x);p.poke(s['py'],y);p.poke(s['pdir'],d)
                    t=p.tick;call(p,'draw_explore_screen');times.append((p.tick-t)/67500)
                    got=p.screen_rgb(False)[:192,:208]
                    if not mono:
                        want,view,objs=expected(p,region)
                        diff=(got!=want).any(2).sum();n+=1
                        if diff:
                            bad+=1
                            if bad<=2:
                                Image.fromarray(np.hstack([got,want])).save(f'{out}/bad{region}-{bad}.png');print('  diff',region,x,y,d,diff,objs)
                    if len(ims)<24 and (cell in ev or len(ims)<8):ims.append(Image.fromarray(p.screen_rgb(mono)))
            w,h=ims[0].size;S=Image.new('RGB',(4*(w+4),((len(ims)+3)//4)*(h+4)),(50,50,50))
            for i,im in enumerate(ims):S.paste(im,((i%4)*(w+4),(i//4)*(h+4)))
            S.save(f'{out}/area{region}-{key}.png')
            print(key,'area',region,'views',n,'mismatched',bad,'full redraw frames min/mean/max',round(min(times),1),round(sum(times)/len(times),1),round(max(times),1),flush=True)
