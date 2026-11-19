# Screenshot gallery: builds test variants, runs scripted input in the harness,
# saves 4x PNGs of chosen fields.
import os, subprocess, shutil, glob
from PIL import Image
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'build', 'shots')
shutil.rmtree(OUT, ignore_errors=True); os.makedirs(OUT)
START = "0 -\n115 J\n121 -\n145 J\n151 -\n"
OFF = 45
# (name, env, keyscript-after-start, [(field, caption)...])
SHOTS = [
 ('', {}, "0 -\n", [(110, '01_title')]),
 ('', {}, "", [(170, '02_intro_1-1')]),
 ('', {}, "0 -\n115 J\n121 -\n145 R\n149 -\n", [(150, '02b_mode_menu')]),
 ('', {}, "0 -\n", [(620, '02c_high_scores')]),
 ('', {}, "0 -\n115 J\n121 -\n145 R\n149 -\n175 J\n181 -\n255 J\n261 -\n415 R\n", [(190, '02d_time_attack_menu'), (520, '02e_time_attack_run')]),
 ('', {'BIX_START': '27'}, "240 R\n", [(262, '03b_slopes')]),
 ('', {'BIX_LEVEL': '1'}, "240 L\n", [(160, '11b_way_back_intro'), (330, '11c_way_back')]),
 ('', {}, "300 R\n352 RJ\n372 R\n392 -\n396 D\n404 DR\n420 R\n452 RU\n462 RJ\n470 R\n",
     [(350, '03_gully'), (378, '04_gully_jump'), (440, '05_burrowing'), (470, '06_burst')]),
 ('', {'BIX_START': '62'}, "240 R\n252 -\n280 J\n281 RJ\n300 R\n",
     [(292, '07_mushroom_spring'), (330, '08_over_the_wall')]),
 ('', {'BIX_START': '95'}, "240 R\n247 RJ\n258 R\n264 -\n", [(262, '09_billabong')]),
 ('', {'BIX_START': '124'}, "240 R\n", [(296, '10_dropbear_forest')]),
 ('', {'BIX_START': '163'}, "240 R\n248 -\n250 D\n256 DR\n270 R\n", [(330, '11_secret_tunnel')]),
 ('', {'BIX_LEVEL': '2'}, "240 D\n246 DR\n256 R\n330 RJ\n345 -\n",
     [(170, '12_king_cane_intro'), (240, '13_king_cane'), (342, '14_king_cane_burst')]),
 ('', {'BIX_LEVEL': '3'}, "240 R\n", [(170, '15_caverns_intro'), (300, '16_crystal_caverns')]),
 ('', {'BIX_LEVEL': '3', 'BIX_START2': '36'}, "240 R\n", [(290, '17_stalactites')]),
 ('', {'BIX_LEVEL': '3', 'BIX_START2': '58'}, "240 R\n262 -\n264 D\n272 DR\n290 R\n",
     [(380, '18_dig_through_the_wall')]),
 ('', {'BIX_LEVEL': '3', 'BIX_START2': '94'}, "240 R\n252 RJ\n262 R\n", [(262, '19_underground_river')]),
 ('', {'BIX_LEVEL': '3', 'BIX_START2': '131'}, "240 R\n250 RJ\n262 R\n", [(266, '20_crystal_spikes')]),
 ('', {'BIX_LEVEL': '5'}, "240 D\n246 DR\n256 R\n300 -\n330 J\n345 -\n",
     [(170, '21_golem_intro'), (254, '22_geode_golem'), (408, '23_golem_shards')]),
 ('', {'BIX_LEVEL': '6'}, "240 R\n", [(170, '24_works_intro'), (300, '25_clockwork_works')]),
 ('', {'BIX_LEVEL': '6', 'BIX_START3': '38'}, "240 R\n", [(300, '26_conveyors')]),
 ('', {'BIX_LEVEL': '6', 'BIX_START3': '74'}, "240 R\n", [(282, '27_crusher_corridor')]),
 ('', {'BIX_LEVEL': '6', 'BIX_START3': '104'}, "240 R\n251 RJ\n262 R\n", [(266, '28_slag_pits')]),
 ('', {'BIX_LEVEL': '6', 'BIX_START3': '143'}, "240 R\n250 -\n252 D\n258 DR\n274 R\n",
     [(340, '29_scrap_mountain')]),
 ('', {'BIX_LEVEL': '8'}, "240 R\n250 -\n", [(170, '30_robot_intro'), (260, '31_rust_o_tron'), (380, '32_robot_landed')]),
 ('', {'BIX_LEVEL': '9'}, "240 R\n", [(170, '33_isles_intro'), (300, '34_skyward_isles'), (422, '35_updraft')]),
 ('', {'BIX_LEVEL': '9', 'BIX_START4': '100'}, "240 R\n", [(262, '36_drifting_clouds')]),
 ('', {'BIX_LEVEL': '9', 'BIX_START4': '193'}, "240 R\n250 -\n", [(300, '37_beanstalk')]),
 ('', {'BIX_LEVEL': '11'}, "240 R\n250 -\n", [(170, '38_hawk_intro'), (260, '39_thunderhawk'), (380, '40_hawk_dive')]),
 ('', {'BIX_LEVEL': '12'}, "240 R\n", [(170, '41_peaks_intro'), (300, '42_molten_peaks'), (470, '43_lava_river')]),
 ('', {'BIX_LEVEL': '12', 'BIX_START5': '104'}, "240 R\n250 RJ\n262 R\n", [(270, '44_heat_vents')]),
 ('', {'BIX_LEVEL': '12', 'BIX_START5': '143'}, "240 R\n250 -\n252 D\n258 DR\n274 R\n", [(340, '45_ash_mountain')]),
 ('', {'BIX_LEVEL': '14'}, "240 R\n250 -\n", [(170, '46_dragon_intro'), (290, '47_magma_dragon'), (440, '48_dragon_flight')]),
 ('', {'BIX_START': '276'}, "240 R\n", [(500, '49_level_clear'), (560, '50_time_bonus')]),
 ('', {'BIX_LEVEL': '4'}, "240 L\n", [(330, '51_caverns_way_back')]),
 ('', {'BIX_LEVEL': '10'}, "240 L\n", [(330, '52_isles_way_back')]),
 ('', {'BIX_LEVEL': '13'}, "240 L\n", [(330, '53_peaks_way_back')]),
]
emu = os.path.join(ROOT, 'tools', 'vzemu')
tmp = '/tmp/capture'
for _, env, keys, shots in SHOTS:
    e = dict(os.environ); e.update(env)
    subprocess.run([os.path.join(ROOT, 'build.sh')], env=e, check=True, stdout=subprocess.DEVNULL)
    shutil.rmtree(tmp, ignore_errors=True); os.makedirs(tmp)
    custom = keys.startswith('0 -')
    if not custom:
        keys = ''.join(f"{int(l.split()[0]) + OFF} {l.split()[1]}\n" for l in keys.strip().split('\n') if l.strip())
        shots = [(f + OFF, n) for f, n in shots]
    ks = (keys if custom else START + keys) + ''.join(f'S{f}\n' for f, _ in shots)
    open('/tmp/capture.keys', 'w').write(ks)
    last = max(f for f, _ in shots) + 2
    subprocess.run([emu, os.path.join(ROOT, 'build', 'BIX.VZ'), str(last), tmp, '/tmp/capture.keys'],
                   check=True, stderr=subprocess.DEVNULL)
    for f, name in shots:
        im = Image.open(f'{tmp}/f{f:05d}.ppm').resize((512, 256), Image.NEAREST)
        im.save(os.path.join(OUT, name + '.png'))
subprocess.run([os.path.join(ROOT, 'build.sh')], check=True, stdout=subprocess.DEVNULL)
files = sorted(glob.glob(OUT + '/*.png'))
cols = 3; rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (cols * 528 + 16, rows * 272 + 16), (24, 24, 28))
for i, fn in enumerate(files):
    sheet.paste(Image.open(fn), (16 + (i % cols) * 528, 16 + (i // cols) * 272))
sheet.save(os.path.join(ROOT, 'build', 'bix_screenshots.png'))
print(len(files), 'shots')
