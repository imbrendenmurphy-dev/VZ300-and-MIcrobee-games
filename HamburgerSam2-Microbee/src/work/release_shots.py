"""Release screenshots -> release/screenshots (960x750, 3x nearest)."""
import shutil
from test_native import *
OUT = Path('release/screenshots'); OUT.mkdir(parents=True, exist_ok=True)
for f in OUT.glob('*.png'): f.unlink()
def save(b, name):
    b.shot('_rel'); shutil.move('outputs/_rel.png', OUT / f'{name}.png')
NAMES = ["sams_diner", "cheese_factory", "pickle_pantry", "night_grill", "salad_bar",
         "fry_up_factory", "midnight_feast", "burger_palace", "classic_1984"]
# title, colour and mono
b = Bee(); b.until('title_screen.l'); b.run(40); save(b, '01_title')
b.keys = {22}; b.call('read_input'); b.keys = set(); b.call('read_input'); b.run(60); save(b, '02_title_mono')
# attract pages
b = Bee(); b.until('title_screen.l')
want = {'how_to_play': '03_how_to_cook', 'meet_menu': '05_meet_the_menu'}
for lab, nm in want.items():
    b.until(lab, 4000); b.run(90); save(b, nm)
b.until('good_anim', 4000); b.run(60); save(b, '06_goodies')
# menu
b = Bee(); b.until('title_screen.l'); b.keys = {55}; b.until('main_menu.l', 3000); b.keys = set(); b.run(40); save(b, '07_menu')
# every kitchen in play
for k in range(9):
    for mono in ([0, 1] if k == 0 else [0]):
        b = Bee(); b.until('title_screen.l'); b.call('dl_reset'); M = b.m.memory
        M[sym['mono_mode']] = mono
        M[sym['kitchen']] = min(k, 7); M[sym['playclassic']] = int(k == 8)
        M[sym['mode']] = 1; M[sym['lives']] = 4; M[sym['peppers']] = 6
        b.m.a = k; b.call('load_kitchen'); b.call('draw_kitchen'); b.call('setup_round'); b.call('wipe_show')
        M[sym['godmode']] = 1; M[sym['autoplay']] = 1
        for i in range(90 + 25 * k): b.call('game_frame')
        save(b, f'{10 + k:02d}_kitchen{k + 1}_{NAMES[k]}' + ('_mono' if mono else ''))
# Order Up!
b = Bee(); b.until('title_screen.l'); M = b.m.memory
M[sym['autoplay']] = 1; M[sym['mode']] = 1
b.m.sp = 0xEF00; M[0xEF00:0xEF02] = bytes([0xFE, 0xEF]); b.m.pc = sym['order_up']
b.run(700); save(b, '20_order_up')
print('screenshots:', len(list(OUT.glob('*.png'))))
