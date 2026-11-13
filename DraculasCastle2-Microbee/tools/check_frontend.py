"""Exercise native menus with actual CRTC keyboard input and mode transitions."""
from check_port import *
from PIL import Image
import numpy as np

s=syms();p=direct()

def press(key,frames=8):
    p.keys=set();p.run_frames(4)
    p.keys={key};p.run_frames(frames)
    p.keys=set();p.run_frames(4)

press('M',40)
assert p.peek(s['mb_mode'])==1
press('C',40)
assert p.peek(s['mb_mode'])==0
sound=p.peek(s['music_on']);press('N')
assert p.peek(s['music_on'])!=sound
press('DOWN');press('DOWN')
assert p.peek(s['menu_sel'])==2
p.keys={'SPACE'}
assert p.run_until(s['native_gallery.wait'],200)==s['native_gallery.wait']
p.keys=set();p.run_frames(4)
for monster in range(12):
    assert p.peek(s['native_monster'])==monster
    # The expanded Ghost library has a separately measured preload budget.
    assert p.run_until(s['native_gallery.wait'],200 if monster==2 else 30)==s['native_gallery.wait']
    frame=p.peek(s['native_frame'])
    filename=f'anim-monster03-{frame-4}-colour.png' if monster==2 and frame>=4 else f'monster{monster+1:02}-{frame}-colour.png'
    expected=Image.open(ROOT/'build/native'/filename)
    assert np.array_equal(p.screen_rgb(),np.asarray(expected))
    press('RIGHT',60)
assert p.peek(s['native_monster'])==0
press('LEFT',60)
assert p.peek(s['native_monster'])==11
p.keys={'P'}
assert p.run_until(s['title_screen.loop'],200)==s['title_screen.loop']
p.keys=set();p.run_frames(4)
assert p.peek(s['native_active'])==1
assert p.peek(s['menu_sel'])==2
press('DOWN')
assert p.peek(s['menu_sel'])==0
p.keys={'SPACE'}
assert p.run_until(s['story_intro'],100)==s['story_intro']
assert not p.peek(s['native_active'])
assert bytes(p.pcg)==(ROOT/'build/PCG.BNK').read_bytes()
assert (p.crtc[1],p.crtc[6],p.crtc[9])==(64,32,7)
print('PASS title C/M, sound, gallery 12 monsters, wrap both ways, return and new-game transition')
(ROOT/'build/frontend-validation.json').write_text(json.dumps({'title_display_switch':True,'title_sound_switch':True,'gallery_keyboard_navigation':12,'gallery_wrap_both_ways':True,'gallery_return':True,'new_game_display_restore':True},indent=2))
