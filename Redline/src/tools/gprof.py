import sys,re,bisect
N=int(sys.argv[1])
syms=[]
for l in open('build/racer.sym'):
    m=re.match(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',l)
    if m and '.' not in m.group(1): syms.append((int(m.group(2),16),m.group(1)))
syms.sort(); addrs=[a for a,_ in syms]
groups={'roadline':['road_line','rl_','bnd','rl_write','rl_fill'],'proj':['draw_road','project','plog','record_k','prj_reset','stepdiv','kscale','fill_segment','seg_colours'],
 'sprites':['blit','draw_frame','draw_entry','draw_dl','draw_car','draw_scen','dl_','dla_','lerp','smul8','mul8u','build_dl','draw_gantry','g_rowadr','span','draw_player','ovl_frame'],
 'isr':['isr'],'wait':['present','maybe_ei'],'pano':['draw_pano','ldi','ldin','pn_'],'hud':['hud','bin3','bcd6','nib_mask','bb_','draw_msg'],
 'game':['game_update','upd_','advance','collide','car_','read_input','joy','rand','demo','cur_','offroad','clamp_hi','mul_s8','render'],'tunnel/fill':['fill_row','draw_roof','roof_row','grass_line']}
tot={}; T=0; det={}
for l in open('out/prof.txt'):
    a,c=l.split(); a=int(a,16); c=int(c); T+=c
    i=bisect.bisect_right(addrs,a)-1; n=syms[i][1] if i>=0 else '?'
    g='other:'+n
    for k,v in groups.items():
        if any(n.startswith(p) for p in v): g=k;break
    tot[g]=tot.get(g,0)+c; det[n]=det.get(n,0)+c
for g,c in sorted(tot.items(),key=lambda x:-x[1])[:12]: print('%-16s %7.0f'%(g,c/N))
print('total %.0f  active %.0f'%(T/N,(T-tot.get('wait',0))/N))
if len(sys.argv)>2:
    for n,c in sorted(det.items(),key=lambda x:-x[1])[:int(sys.argv[2])]: print('   %-18s %7.0f'%(n,c/N))
