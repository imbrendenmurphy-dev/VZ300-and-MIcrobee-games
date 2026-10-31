import run, warp, play, sym, ppmodel
from PIL import Image
import numpy as np
S = sym.load()
OUT = '../out/shots43/'
n = [0]
def shot(pp, name):
    img = np.asarray(pp.screen_rgb(), dtype=np.uint8)
    im = Image.fromarray(img)
    assert im.size == (640, 192), im.size
    im = im.resize((1280, 960), Image.NEAREST)      # 2x across, 5x down: 4:3
    n[0] += 1
    im.save(OUT + '%02d-%s.png' % (n[0], name))

# title screens
def key(pp, k):
    play.hold(pp, [k], 7); pp.run_frames(25)
pp = run.boot(); pp.run_frames(500); shot(pp, 'title')
key(pp, 'DOWN'); key(pp, 'DOWN'); key(pp, 'RET'); pp.run_frames(150); shot(pp, 'instructions')
key(pp, 'SPACE'); pp.run_frames(500)
key(pp, 'DOWN'); key(pp, 'RET'); pp.run_frames(150); shot(pp, 'credits')

# the Drowned Temple
pp = warp.warp(0, 2, 10, 0); pp.run_frames(250); play.go(pp, 16, 10); play.tap(pp, 'F', 2); pp.run_frames(16); shot(pp, 'lanternless-way-firebolt')
pp = warp.warp(0, 36, 10, 0); play.go(pp, 48, 12); pp.run_frames(40); shot(pp, 'drowned-hall')
pp = warp.warp(1, 10, 10, 0); play.go(pp, 30, 10); pp.run_frames(30); shot(pp, 'flooded-cloister')
pp = warp.warp(2, 39, 17, 0); play.go(pp, 39, 10); play.face(pp, 'UP'); pp.run_frames(20); shot(pp, 'shrine-of-the-keeper')
pp = warp.warp(3, 50, 12, 2); play.go(pp, 67, 11); play.face(pp, 'RIGHT'); play.tap(pp, 'SPACE', 30); shot(pp, 'iron-gate-opens')
# the Ossuary
pp = warp.warp(5, 20, 11, 0x02); play.go(pp, 45, 11); pp.run_frames(30); shot(pp, 'hall-of-tombs')
pp = warp.warp(7, 20, 11, 0x02); play.go(pp, 57, 11); play.face(pp, 'UP')
for i in range(3): play.tap(pp, 'SPACE', 14)
pp.run_frames(50); shot(pp, 'bone-colossus')
pp = warp.warp(8, 40, 11, 0x06); play.go(pp, 50, 11); play.face(pp, 'RIGHT'); play.tap(pp, 'SPACE', 30); shot(pp, 'sealed-stair-false-wall')
# the Crystal Caverns
pp = warp.warp(10, 30, 10, 0x0E); play.go(pp, 36, 12); pp.run_frames(30); shot(pp, 'prism-grotto')
pp = warp.warp(11, 39, 18, 0x0E); play.go(pp, 30, 12); pp.run_frames(30); shot(pp, 'mushroom-hollow')
pp = warp.warp(12, 20, 11, 0x0E); play.go(pp, 52, 11); pp.run_frames(30); shot(pp, 'river-crossing')
# the Ember Halls
pp = warp.warp(14, 5, 11, 0x0E); play.go(pp, 40, 11); pp.run_frames(30); shot(pp, 'magma-bridge')
pp = warp.warp(15, 39, 3, 0x0E); play.go(pp, 39, 11); play.face(pp, 'UP'); pp.run_frames(30); shot(pp, 'forge-of-the-vaunar')
pp = warp.warp(16, 10, 11, 0x1E); play.go(pp, 40, 11); pp.run_frames(30); shot(pp, 'fissure-walk')
# the Heart of the Deep
pp = warp.warp(17, 30, 11, 0x1E); play.go(pp, 45, 9); play.face(pp, 'UP'); pp.run_frames(30); shot(pp, 'threshold')
pp = warp.warp(18, 20, 11, 0x1E); play.go(pp, 38, 11); pp.run_frames(30); shot(pp, 'hall-of-echoes')
pp = warp.warp(19, 5, 11, 0x1E)
play.go(pp, 50, 10); play.face(pp, 'UP'); play.tap(pp, 'SPACE', 10); pp.run_frames(40); shot(pp, 'hollow-king')
for i in range(80):
    play.go(pp, 50, 9, limit=60); play.face(pp, 'UP'); play.tap(pp, 'SPACE', 14)
    pp.write(S['hp'], 5)
    if not pp.peek(S['boss_on']): break
play.go(pp, 65, 9); play.face(pp, 'RIGHT'); play.tap(pp, 'SPACE', 2)
pp.run_frames(150); shot(pp, 'heart-rekindled')
pp.run_frames(300); shot(pp, 'ending')
# the journal
pp = warp.warp(4, 6, 11, 0x06)
play.go(pp, 79, 11); play.hold(pp, ['RIGHT'], 8); pp.run_frames(40)
play.go(pp, 39, 21); play.hold(pp, ['DOWN'], 8); pp.run_frames(40)
play.hold(pp, ['M'], 6); pp.run_frames(20); shot(pp, 'journal')
# a life lost: waking at the region's start
pp = warp.warp(16, 10, 11, 0x0E)
pp.write(S['hp'], 1)
play.go(pp, 26, 11, limit=300)
pp.run_frames(330); shot(pp, 'a-life-lost')
print(n[0], 'shots')
