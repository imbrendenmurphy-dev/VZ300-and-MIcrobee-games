"""Execute the bespoke Z80 backend and compare it with native-cell oracles."""
from pathlib import Path
import json
import re
import sys
import numpy as np
from PIL import Image
import assets

R=Path(__file__).resolve().parents[1]
B=R/'build/native'
OUT=R/'test-output/native'
OUT.mkdir(parents=True,exist_ok=True)
SW,SH=json.loads((B/'assets.json').read_text()).get('sprite_dimensions',[16,16])
assets.COMPACT=SH==8
CONFIG=json.loads((B/'build-config.json').read_text())
RAM=CONFIG['ram_background']
RES=CONFIG.get('resident_cache',False)
COMPILED=CONFIG.get('compiled_actors',False)
sys.path.insert(0,str(R/'tools'))
import ppmodel
from boot_test import type_text

S={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',(B/'engine.sym').read_text())}
RETURN=0xEFC0  # outside both banked executable sprite code and native scratch
PATCH_BUFFER=S['n_patch_buffer']


class Machine(ppmodel.PP):
    def vwrite(self,o,v):
        self.video_writes=getattr(self,'video_writes',0)+1
        super().vwrite(o,v)
    def screen_rgb(self,mono=False):
        out=super().screen_rgb(mono)
        font=(R/'resources/charrom.bin').read_bytes() if (R/'resources/charrom.bin').exists() else bytes(4096)
        cols=self.crtc[1] or 80; lines=(self.crtc[9]&31)+1
        for row in range(self.crtc[6] or 16):
            for col in range(cols):
                off=row*cols+col
                ch=self.scr[off]
                if ch&128: continue
                fg,bg=ppmodel.PALETTE[self.col[off]&15],ppmodel.PALETTE[self.col[off]>>4]
                for y in range(lines):
                    bits=font[ch*16+y]
                    for x in range(8):out[row*lines+y,col*8+x]=fg if bits&(128>>x) else bg
        return out


def machine():
    p=Machine(disk=(B/'BILBIES-NATIVE.DS8').read_bytes())
    p.set_p50(0x0F)
    code=(B/'ENGINE.HI').read_bytes()
    p.mem[0x8000:0x8000+len(code)]=code
    for block,name in [(8,'colour.pcg'),(9,'mono.pcg'),(10,'colour0.map'),
                       (11,'colour1.map'),(12,'mono0.map'),(13,'mono1.map'),
                       (14,'RENDER.BNK' if RES else 'sprite-code.bnk')]+(
                       [(24,'colour.raster.bnk'),(25,'mono.raster.bnk')] if RAM else [])+(
                       [(26,'sprite-code.bnk')] if RES else []):
        data=(B/name).read_bytes();p.blocks[block][:len(data)]=data
    if COMPILED:
        for i in range(8):p.blocks[16+i][:]=(B/f'ACTOR{i}.BNK').read_bytes()
    p.mem[0x7000:0x7800]=bytes([0xA5])*2048
    p.m.pc=S['n_boot']
    assert p.run_until(S['n_loop'],500),'native initialization timeout'
    return p


def call(p,label,frames=500):
    assert p.lower in (1,14) and p.p50&4
    p.m.sp=0xEFF0;p.mem[0xEFF0:0xEFF2]=RETURN.to_bytes(2,'little')
    p.m.pc=S[label]
    start=p.ticks()
    assert p.run_until(RETURN,frames),'timeout '+label
    return p.ticks()-start


def setword(p,name,v):p.mem[S[name]:S[name]+2]=v.to_bytes(2,'little')


def verify_map(p,camera,mono):
    name='mono' if mono else 'colour'
    data=(B/f'{name}{(camera&7)//4}.map').read_bytes()
    start=(camera&3)*6144+(camera>>3)
    for plane,actual in [(0,p.scr),(1,p.attr),(2,p.col)]:
        expected=b''.join(data[start+plane*2048+y*128:start+plane*2048+y*128+80] for y in range(14))
        assert bytes(actual[:1120])==expected,(camera,mono,plane)


def bitplane(p):
    result=np.zeros((224,640),dtype=np.uint8)
    for cell in range(1120):
        glyph=((p.attr[cell]&15)*128)+(p.scr[cell]&127)
        data=p.pcg[glyph*16:glyph*16+16]
        for y,v in enumerate(data):
            result[(cell//80)*16+y,(cell%80)*8:(cell%80)*8+8]=[(v>>(7-x))&1 for x in range(8)]
    return result


def reference_scene(camera,mono):
    name='mono' if mono else 'colour'
    data=(B/f'{name}{(camera&7)//4}.map').read_bytes()
    start=(camera&3)*6144+(camera>>3)
    planes=[b''.join(data[start+plane*2048+y*128:start+plane*2048+y*128+80]
                     for y in range(14)) for plane in range(3)]
    chars=np.frombuffer(planes[0],dtype=np.uint8).astype(np.uint16)
    attrs=np.frombuffer(planes[1],dtype=np.uint8).astype(np.uint16)
    glyphs=(chars&127)+(attrs&15)*128
    pcg=np.frombuffer((B/f'{name}.pcg').read_bytes(),dtype=np.uint8).reshape(2048,16)
    bits=np.unpackbits(pcg[glyphs],axis=1).reshape(14,80,16,8).transpose(0,2,1,3).reshape(224,640)
    return bits.copy(),bytearray(planes[2])


def verify_sprites(p,count,patches=b''):
    call(p,'n_terrain')
    camera=int.from_bytes(p.mem[S['n_camera']:S['n_camera']+2],'little')
    if not RES:verify_map(p,camera,p.peek(S['n_mono']))
    expected,expected_colours=reference_scene(camera,p.peek(S['n_mono']))
    touched=set()
    sprite_cells=set()
    p.mem[S['n_patch_count']]=len(patches)//19
    p.mem[PATCH_BUFFER:PATCH_BUFFER+len(patches)]=patches
    for i in range(len(patches)//19):
        record=patches[i*19:(i+1)*19]
        cell=int.from_bytes(record[:2],'little')
        touched.add(cell)
        expected_colours[cell]=15 if p.peek(S['n_mono']) else record[18]
        for yy,v in enumerate(record[2:18]):
            expected[(cell//80)*16+yy,(cell%80)*8:(cell%80)*8+8]=[(v>>(7-xx))&1 for xx in range(8)]
    frame=p.peek(S['n_anim'])&7
    camera=int.from_bytes(p.mem[S['n_camera']:S['n_camera']+2],'little')
    for i in range(count):
        ent=p.mem[S['n_entities']+i*4:S['n_entities']+i*4+4]
        x=ent[0]+ent[1]*256-camera;y=ent[2]
        if x < -SW or x>=640 or y>=225-SH:continue
        im=assets.bilby(frame)
        for yy in range(SH):
            for xx in range(SW):
                mask=any(im.getpixel((px,py)) for py in range(max(0,yy-1),min(16,yy+2)) for px in range(max(0,xx-1),min(16,xx+2)))
                if mask and 0<=x+xx<640:
                    expected[y+yy,x+xx]=im.getpixel((xx,yy))
                    cell=((y+yy)//16)*80+(x+xx)//8
                    touched.add(cell);sprite_cells.add(cell)
    p.mem[S['n_count']]=count
    cost=call(p,'n_sprites')
    actual=bitplane(p)
    if not np.array_equal(actual,expected):
        np.savez(OUT/'failure.npz',mem=np.array(p.mem),blocks=np.array(p.blocks),
                 scr=np.array(p.scr),attr=np.array(p.attr),col=np.array(p.col),pcg=np.array(p.pcg),
                 expected=expected,actual=actual)
    assert np.array_equal(actual,expected),(f'{np.count_nonzero(actual!=expected)} sprite bit mismatches; '
                                           f'first y/x {np.argwhere(actual!=expected)[:12].tolist()}')
    for cell in sprite_cells:
        expected_colours[cell]=(expected_colours[cell]&0xF0)|(15 if p.peek(S['n_mono']) else 8)
    assert bytes(p.col[:1120])==expected_colours,'ink/paper oracle mismatch'
    assert p.peek(S['n_slot'])==len(touched),'transparent cells consumed foreground slots'
    assert p.peek(S['n_overflow'])==0
    return cost


def main():
    p=machine(); costs=[]
    assert p.crtc[1]==80 and p.crtc[6]==16 and p.crtc[9]==15
    for mono in [0,1]:
        p.mem[S['n_mono']]=mono;call(p,'n_load_pcg');call(p,'n_hud')
        for phase in range(8) if RAM else []:
            name='mono' if mono else 'colour'
            raw=(B/f'{name}{phase}.raster').read_bytes()
            assert bytes(p.blocks[16+phase][:len(raw)])==raw,'native raster decompression mismatch'
        static=bytes(p.pcg[:14*2048])
        for camera in [0,1,2,3,4,5,6,7,8,9,383,384]:
            setword(p,'n_camera',camera)
            cost=call(p,'n_terrain')
            verify_map(p,camera,mono)
            assert bytes(p.pcg[:14*2048])==static,'scroll rewrote static PCG'
            costs.append(cost)
        setword(p,'n_camera',0)
        ten_cold=verify_sprites(p,10)
        ten=verify_sprites(p,10)
        p.save_png(OUT/f'{"mono" if mono else "colour"}-10.png',1)
        forty_cold=verify_sprites(p,40)
        forty=verify_sprites(p,40)
        p.save_png(OUT/f'{"mono" if mono else "colour"}-40.png',1)
        steady_terrain=call(p,'n_terrain')
        if not RES:verify_map(p,0,mono)
        assert bytes(p.pcg[:14*2048])==static,'sprite cache damaged terrain PCG'
        verify_sprites(p,40,(B/'patches.bin').read_bytes())
        if mono:assert set(p.col[:1280])=={15},'monochrome path leaked colour'
        assert bytes(p.scr[1120:1128])==b'BILBIES!', 'sprite/patch damaged fixed HUD'
        p.save_png(OUT/f'{"mono" if mono else "colour"}-terrain-patch.png',1)
        p.mem[S['n_patch_count']]=0
        verify_sprites(p,0)
        # Both viewport edges: partial sprites must clip, not pop off early.
        original=bytes(p.mem[S['n_entities']:S['n_entities']+160])
        p.mem[S['n_entities']:S['n_entities']+8]=b'\x00\x00\x20\x00\x86\x02\x20\x00'
        p.mem[S['n_entities']+8:S['n_entities']+12]=b'\x0a\x00\x20\x00'
        setword(p,'n_camera',7);verify_sprites(p,3)
        p.mem[S['n_entities']:S['n_entities']+160]=original
        setword(p,'n_camera',0)
        # Full compiled routines must match every gait frame, not just frame 0.
        for frame in range(8):
            p.mem[S['n_anim']]=frame
            verify_sprites(p,40)
        p.mem[S['n_anim']]=0
        for phase in range(8):
            for dy in [0,1,7,8,15]:
                for i in range(2):
                    x=80+phase+3*i;y=32+dy+i
                    p.mem[S['n_entities']+i*4:S['n_entities']+i*4+4]=bytes([x,0,y,0])
                verify_sprites(p,2)
        p.mem[S['n_entities']:S['n_entities']+160]=original
    assert bytes(p.mem[0x7000:0x7800])==bytes([0xA5])*2048,'legacy framebuffer touched'
    setword(p,'n_camera',0)
    p.keys={ppmodel.KEY['P']};call(p,'n_input')
    assert int.from_bytes(p.mem[S['n_camera']:S['n_camera']+2],'little')==1
    p.keys={ppmodel.KEY['O']};call(p,'n_input')
    assert int.from_bytes(p.mem[S['n_camera']:S['n_camera']+2],'little')==0
    p.keys={ppmodel.KEY['C']};call(p,'n_input');assert p.peek(S['n_mono'])==0
    p.keys={ppmodel.KEY['M']};call(p,'n_input');assert p.peek(S['n_mono'])==1
    p.keys={ppmodel.KEY['H']};call(p,'n_input');call(p,'n_input')
    assert p.peek(S['n_paused'])==1,'held pause key toggled twice'
    p.mem[S['n_anim']]=5;p.mem[S['n_frames']]=12;call(p,'n_demo_tick')
    assert p.peek(S['n_anim'])==5
    p.keys=set();call(p,'n_input')
    p.keys={ppmodel.KEY['H']};call(p,'n_input');assert p.peek(S['n_paused'])==0
    p.m.a=7;call(p,'n_show_time')
    hud=1120+S['n_hud_digits']-S['n_hud_text']
    assert bytes(p.scr[hud:hud+2])==b'07'
    assert bytes(p.pcg[:28672])==(B/'mono.pcg').read_bytes()[:28672], 'keyboard/mode HUD corrupted static PCG'
    p.keys=set()
    # Forty spatially separated actors exercise all 240 foreground glyphs.
    # This is a complete output test, distinct from deliberate exhaustion.
    for i in range(40):
        x=9+(i%20)*32;y=35+(i//20)*64
        p.mem[S['n_entities']+i*4:S['n_entities']+i*4+4]=bytes([x&255,x>>8,y,0])
    p.mem[S['n_patch_count']]=0
    spread=verify_sprites(p,40)
    # Select the phase/vertical alignment touching the most physical cells.
    shape=assets.bilby(0)
    active=[(x,y) for y in range(SH) for x in range(SW)
            if any(shape.getpixel((xx,yy)) for yy in range(max(0,y-1),min(16,y+2))
                   for xx in range(max(0,x-1),min(16,x+2)))]
    footprint,phase,dy=max((len({((y+dy)//16,(x+phase)//8) for x,y in active}),phase,dy)
                           for phase in range(8) for dy in range(16))
    setword(p,'n_camera',0);call(p,'n_terrain')
    static=bytes(p.pcg[:14*2048])
    for i in range(40):
        x=8+phase+(i%20)*32;y=32+dy+(i//20)*64
        p.mem[S['n_entities']+i*4:S['n_entities']+i*4+4]=bytes([x&255,x>>8,y,0])
    staggered=verify_sprites(p,40)
    assert p.peek(S['n_slot'])==40*footprint
    jobs=b''.join((13*80+i).to_bytes(2,'little')+bytes([255])*16+b'\x0f' for i in range(32))
    p.mem[PATCH_BUFFER:PATCH_BUFFER+len(jobs)]=jobs
    p.mem[S['n_patch_count']]=32;p.mem[S['n_count']]=40
    if footprint*40+32<=255:
        verify_sprites(p,40,jobs)
    else:
        call(p,'n_sprites')
        assert p.peek(S['n_overflow'])==1 and p.peek(S['n_slot'])==255
    assert bytes(p.pcg[:14*2048])==static
    # Force the allocator to its limit independently of an artwork footprint.
    p.m.a=14;call(p,'n_bank')
    map_address=0x9000 if COMPILED else 0x1000
    p.mem[map_address:map_address+1120]=bytes([255])*1120
    p.mem[S['n_slot']]=0;p.mem[S['n_overflow']]=0
    if RES:
        p.mem[S['n_pool_highwater']]=0;p.mem[S['n_free_count']]=0
        for cell in range(256):
            call(p,'n_new_slot');assert bool(p.m.f&1)==(cell==255)
        assert p.peek(S['n_pool_highwater'])==255 and p.peek(S['n_overflow'])==1
    else:
        for cell in range(256):
            p.m.hl=0xF000+cell
            p.m.de=p.mem[cell]+(p.mem[0x800+cell]<<8)
            call(p,'n_touch_cell')
            assert bool(p.m.f&1)==(cell==255)
        assert p.peek(S['n_slot'])==255 and p.peek(S['n_overflow'])==1
    call(p,'n_home')
    q=machine();q.mem[S['n_count']]=40
    moving=[]
    for frame in range(8):
        q.mem[S['n_anim']]=frame
        for i in range(40):
            x=32+i*14+frame*2
            q.mem[S['n_entities']+i*4:S['n_entities']+i*4+2]=x.to_bytes(2,'little')
        moving.append(call(q,'n_present'))
        rendered=bitplane(q)
        verify_sprites(q,40)
        assert np.array_equal(rendered,bitplane(q)), 'present skipped a changed frame'
        before=q.video_writes
        idle=call(q,'n_present')
        assert q.video_writes==before,'idle frame rewrote video/PCG'
        assert np.array_equal(rendered,bitplane(q))
    jobs=bytearray((B/'patches.bin').read_bytes())
    q.mem[S['n_patch_count']]=2;q.mem[PATCH_BUFFER:PATCH_BUFFER+len(jobs)]=jobs
    call(q,'n_present')
    jobs[2]^=1;q.mem[PATCH_BUFFER:PATCH_BUFFER+len(jobs)]=jobs
    before=q.video_writes;call(q,'n_present')
    assert q.video_writes>before,'same-sized terrain edit was skipped'
    patched=bitplane(q);verify_sprites(q,40,jobs)
    assert np.array_equal(patched,bitplane(q))
    call(q,'n_load_pcg');call(q,'n_present')
    assert np.array_equal(patched,bitplane(q)), 'same-mode PCG reload left cached sprites blank'
    report={'resolution':[640,256],'phase_map_cases':len(costs),'terrain_tstates':max(costs),
            'ram_background':RAM,
            'resident_cache':RES,
            'compiled_actors':COMPILED,
            'sprite_alignment_cases':80,'gait_frame_mode_cases':16,
            'sprite_dimensions':[SW,SH],
            'ten_sprite_tstates':ten,'forty_sprite_tstates':forty,
            'ten_cold_sprite_tstates':ten_cold,'forty_cold_sprite_tstates':forty_cold,
            'forty_spread_sprite_tstates':spread,
            'forty_staggered_sprite_tstates':staggered,
            'maximum_cells_per_actor':footprint,
            'steady_terrain_tstates':steady_terrain,
            'forty_steady_total_frames':(steady_terrain+forty)/67500,
            'moving_present_max_tstates':max(moving),'unchanged_present_tstates':idle,
            'moving_present_steady_max_tstates':max(moving[1:]),
            'moving_present_actor_count':40,
            'graphics_25hz_budget_tstates':135000,
            'graphics_25hz_worst_case_pass':staggered+max(costs)<=135000,
            'unchanged_present_video_writes':0,
            'terrain_frames':max(costs)/67500,'ten_total_frames':(max(costs)+ten)/67500,
            'forty_total_frames':(max(costs)+forty)/67500,
            'sprite_oracle':f'masked native {SW}x{SH}, 10 and 40 overlapping bilbies; all 8 gait frames',
            'legacy_framebuffer_untouched':True,'static_pcg_unchanged_during_scroll':True}
    report['native_terrain_patch_plus_40_sprites']='pixel oracle passed in both modes'
    report['monochrome_all_cells_white_on_black']=True
    report['native_keyboard_pan_and_mode_switch']=True
    report['pause_debounced_and_runtime_frame_counter']=True
    report['oversubscribed_foreground']='signals exhaustion; static PCG preserved; frame intentionally incomplete'
    (OUT/'results.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2),flush=True)
    # Real ROM and actual CP/M loader, not direct program injection.
    q=Machine(rom=(R/'resources/bn60.rom').read_bytes(),disk=(B/'BILBIES-NATIVE.DS8').read_bytes())
    q.m.pc=0x8000;q.run_frames(60);type_text(q,'B')
    for _ in range(100):
        q.run_frames(10)
        if 'A>' in q.text():break
    assert 'A>' in q.text()
    type_text(q,'BILBIES\r')
    for _ in range(500):
        q.run_frames(10)
        if q.crtc[1]==80 and q.crtc[9]==15:break
    assert q.crtc[1]==80 and q.crtc[9]==15,'disk launch failed'
    q.run_frames(200);q.save_png(OUT/'disk-boot.png',1)
    print('PASS native DS8 -> CP/M prompt -> renderer launch',flush=True)


if __name__=='__main__':main()




