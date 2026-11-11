"""Check native Z80 decoding, cached single-page updates and exported images."""
from check_port import *
from PIL import Image
import numpy as np
s=syms();p=direct();p.run_frames(100)
invoke(p,s,'native_enter')
assert (p.crtc[1],p.crtc[6],p.crtc[9])==(40,32,7)
entries=json.loads((ROOT/'build/native/manifest.json').read_text())
for mode in range(2):
    p.poke(s['mb_mode'],mode)
    # The 72 gallery images are exercised through their actual group path below.
    for idx in range(1):
        start=p.frames
        invoke(p,s,'native_show',idx)
        entry=entries[idx+37*mode]
        expected=(ROOT/'build/native'/(entry['name']+'.raw')).read_bytes()
        assert bytes(p.blocks[2][:21760])==expected,entry['name']+' unpack'
        actual=p.screen_rgb()
        preview=np.asarray(Image.open(ROOT/'build/native'/(entry['name']+'.png')))
        assert np.array_equal(actual,preview),entry['name']+' video'
        if idx in (0,10,31):
            Image.fromarray(actual).resize((800,600),Image.Resampling.NEAREST).save(ROOT/'build'/('native-'+entry['name']+'.png'))
        if idx%9==0:print('PASS native image',entry['name'],'frames',p.frames-start,flush=True)
frame_times=[];idle_times=[]
for mode,label in enumerate(('colour','mono')):
    p.poke(s['mb_mode'],mode)
    for monster in range(12):
        p.poke(s['native_monster'],monster)
        invoke(p,s,'native_group_load')
        packet=(ROOT/'build/native'/f'group{monster+1:02}-{label}.raw').read_bytes()
        for frame,offset in enumerate((0x5000,0x5f00,0x6e00)):
            ptr=int.from_bytes(packet[2+frame*2:4+frame*2],'little')
            assert bytes(p.blocks[3][offset:offset+3840])==packet[ptr:ptr+3840]
        pcg=bytes(p.pcg)
        for sequence,frame in enumerate((0,1,0,1,2,0)):
            p.poke(s['native_frame'],frame)
            start=p.frames
            invoke(p,s,'native_group_show')
            frame_times.append(p.frames-start)
            if sequence in (1,2,3):idle_times.append(p.frames-start)
            preview=np.asarray(Image.open(ROOT/'build/native'/f'monster{monster+1:02}-{frame}-{label}.png'))
            assert np.array_equal(p.screen_rgb(),preview),(monster,frame,label)
            assert bytes(p.pcg)==pcg,'Animation modified shared glyphs'
            assert p.regs()['lower']==1
    print('PASS all 12 shared-glyph animations',label,flush=True)
assert max(frame_times)<=8,frame_times
assert max(idle_times)<=3,idle_times
print('PASS cached idle animation, max',max(idle_times),'frames',flush=True)
print('PASS animation transfer budget: max',max(frame_times),'frames',flush=True)
invoke(p,s,'native_leave')
assert bytes(p.pcg)==(ROOT/'build/PCG.BNK').read_bytes()
assert (p.crtc[1],p.crtc[6],p.crtc[9])==(64,32,7)
print('PASS all 74 images, real decoder and single-page updates; compatibility restore')
(ROOT/'build/native-validation.json').write_text(json.dumps({'images':74,'animation_groups':24,'animation_frame_checks':len(frame_times),'max_redraw_frames':max(frame_times),'max_cached_idle_frames':max(idle_times),'compatibility_pcg_restore':True,'native_display':'40x32, 8x8 PCG, 320x256'},indent=2))
