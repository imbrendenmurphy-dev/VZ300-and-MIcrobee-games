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
sys.path.insert(0,str(R/'tools'))
import ppmodel
from boot_test import type_text

S={m[1]:int(m[2],16) for m in re.finditer(r'(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',(B/'engine.sym').read_text())}


class Machine(ppmodel.PP):
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
                       (11,'colour1.map'),(12,'mono0.map'),(13,'mono1.map')]:
        data=(B/name).read_bytes();p.blocks[block][:len(data)]=data
    p.mem[0x7000:0x7800]=bytes([0xA5])*2048
    p.m.pc=S['n_boot']
    assert p.run_until(S['n_loop'],500),'native initialization timeout'
    return p


def call(p,label,frames=100):
    assert p.p50&8
    p.m.sp=0xEFF0;p.mem[0xEFF0:0xEFF2]=b'\x00\x6f'
    p.m.pc=S[label]
    start=p.ticks()
    assert p.run_until(0x6F00,frames),'timeout '+label
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


def verify_sprites(p,count,patches=b''):
    call(p,'n_terrain')
    expected=bitplane(p)
    p.mem[S['n_patch_count']]=len(patches)//19
    p.mem[0x3000:0x3000+len(patches)]=patches
    for i in range(len(patches)//19):
        record=patches[i*19:(i+1)*19]
        cell=int.from_bytes(record[:2],'little')
        for yy,v in enumerate(record[2:18]):
            expected[(cell//80)*16+yy,(cell%80)*8:(cell%80)*8+8]=[(v>>(7-xx))&1 for xx in range(8)]
    frame=p.peek(S['n_anim'])&7
    camera=int.from_bytes(p.mem[S['n_camera']:S['n_camera']+2],'little')
    for i in range(count):
        ent=p.mem[S['n_entities']+i*4:S['n_entities']+i*4+4]
        x=ent[0]+ent[1]*256-camera;y=ent[2]
        if x < -16 or x>=640 or y>=209:continue
        im=assets.bilby(frame)
        for yy in range(16):
            for xx in range(16):
                mask=any(im.getpixel((px,py)) for py in range(max(0,yy-1),min(16,yy+2)) for px in range(max(0,xx-1),min(16,xx+2)))
                if mask and 0<=x+xx<640: expected[y+yy,x+xx]=im.getpixel((xx,yy))
    p.mem[S['n_count']]=count
    cost=call(p,'n_sprites')
    actual=bitplane(p)
    assert np.array_equal(actual,expected),f'{np.count_nonzero(actual!=expected)} sprite bit mismatches'
    assert p.peek(S['n_slot'])<=240+len(patches)//19
    assert p.peek(S['n_overflow'])==0
    return cost


def main():
    p=machine(); costs=[]
    assert p.crtc[1]==80 and p.crtc[6]==16 and p.crtc[9]==15
    for mono in [0,1]:
        p.mem[S['n_mono']]=mono;call(p,'n_load_pcg');call(p,'n_hud')
        static=bytes(p.pcg[:14*2048])
        for camera in [0,1,2,3,4,5,6,7,8,9,383,384]:
            setword(p,'n_camera',camera)
            cost=call(p,'n_terrain')
            verify_map(p,camera,mono)
            assert bytes(p.pcg[:14*2048])==static,'scroll rewrote static PCG'
            costs.append(cost)
        setword(p,'n_camera',0)
        ten=verify_sprites(p,10)
        p.save_png(OUT/f'{"mono" if mono else "colour"}-10.png',1)
        forty=verify_sprites(p,40)
        p.save_png(OUT/f'{"mono" if mono else "colour"}-40.png',1)
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
        setword(p,'n_camera',7);verify_sprites(p,2)
        p.mem[S['n_entities']:S['n_entities']+160]=original
        setword(p,'n_camera',0)
    assert bytes(p.mem[0x7000:0x7800])==bytes([0xA5])*2048,'legacy framebuffer touched'
    setword(p,'n_camera',0)
    p.keys={ppmodel.KEY['P']};call(p,'n_input')
    assert int.from_bytes(p.mem[S['n_camera']:S['n_camera']+2],'little')==1
    p.keys={ppmodel.KEY['O']};call(p,'n_input')
    assert int.from_bytes(p.mem[S['n_camera']:S['n_camera']+2],'little')==0
    p.keys={ppmodel.KEY['C']};call(p,'n_input');assert p.peek(S['n_mono'])==0
    p.keys={ppmodel.KEY['M']};call(p,'n_input');assert p.peek(S['n_mono'])==1
    p.keys=set()
    # Oversubscribed foreground jobs must signal exhaustion, never wrap into
    # terrain PCG. This is a bounded-failure test, not a full-render pass.
    setword(p,'n_camera',0);call(p,'n_terrain')
    static=bytes(p.pcg[:14*2048])
    for i in range(40):
        x=9+(i%20)*32;y=35+(i//20)*64
        p.mem[S['n_entities']+i*4:S['n_entities']+i*4+4]=bytes([x&255,x>>8,y,0])
    jobs=b''.join((13*80+i).to_bytes(2,'little')+bytes([255])*16+b'\x0f' for i in range(32))
    p.mem[0x3000:0x3000+len(jobs)]=jobs
    p.mem[S['n_patch_count']]=32;p.mem[S['n_count']]=40
    call(p,'n_sprites')
    assert p.peek(S['n_overflow'])==1 and p.peek(S['n_slot'])==255
    assert bytes(p.pcg[:14*2048])==static
    report={'resolution':[640,256],'phase_map_cases':len(costs),'terrain_tstates':max(costs),
            'ten_sprite_tstates':ten,'forty_sprite_tstates':forty,
            'terrain_frames':max(costs)/67500,'ten_total_frames':(max(costs)+ten)/67500,
            'forty_total_frames':(max(costs)+forty)/67500,
            'sprite_oracle':'masked native 16x16, 10 and 40 overlapping bilbies',
            'legacy_framebuffer_untouched':True,'static_pcg_unchanged_during_scroll':True}
    report['native_terrain_patch_plus_40_sprites']='pixel oracle passed in both modes'
    report['monochrome_all_cells_white_on_black']=True
    report['native_keyboard_pan_and_mode_switch']=True
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
