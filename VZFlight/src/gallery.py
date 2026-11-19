"""Capture a clean numbered screenshot gallery for VZ FLIGHT: title/attract/tribute,
locale gameplay poses, menu/briefing/results. Saves to gallery/ as 2x-scaled PNGs."""
import os
from h2 import Sim
from prof import enter, pose
from z80emu import screenshot

OUT = 'gallery'
os.makedirs(OUT, exist_ok=True)
n = 0


def shot(s, name):
    global n
    n += 1
    f = os.path.join(OUT, '%02d-%s.png' % (n, name))
    screenshot(s.vz, f, scale=3)
    print(f)


# ---- attract sequence: title, tribute pages, controls, locale list, demo ----
s = Sim()
s.fields(60)
shot(s, 'title')               # orbiting Cessna + logo + marquee
s.tap('SPACE'); s.fields(90)
shot(s, 'tribute-1')           # Dick Smith tribute page 1
s.tap('SPACE'); s.fields(90)
shot(s, 'tribute-2')
s.tap('SPACE'); s.fields(90)
shot(s, 'tribute-3')
s.tap('SPACE'); s.fields(90)
shot(s, 'controls')
s.tap('SPACE'); s.fields(90)
shot(s, 'locale-list')
s.tap('SPACE'); s.fields(120)
shot(s, 'attract-demo')        # autopilot demo flight over Sydney Harbour

# ---- menu / briefing / results ----
s2 = Sim()
s2.fields(40); s2.tap('SPACE'); s2.fields(30)
shot(s2, 'menu-locale')
s2.vz.m[s2.S['locidx']] = 0
s2.tap('A'); s2.fields(10)
shot(s2, 'menu-mission')
s2.vz.m[s2.S['misidx']] = 0
s2.tap('Q'); s2.fields(10)
shot(s2, 'briefing')

# ---- gameplay poses per locale ----
poses = [
    (0, 0, 'sydney-bankstown', dict(x=-7600, z=0, y=150, hdg=90)),
    (0, 0, 'sydney-harbour-bridge', dict(x=0, z=0, y=220, hdg=0)),
    (1, 0, 'pacific-ship', dict(x=200, z=3000, y=90, hdg=200, spd=35)),
    (2, 0, 'redcentre-uluru', dict(x=800, z=600, y=260, hdg=250)),
    (3, 0, 'northpole-ridge', dict(x=0, z=-1500, y=200, hdg=30)),
]
for loc, mis, name, p in poses:
    s3 = enter(loc, mis)
    pose(s3, p['x'], p['z'], p['y'], p['hdg'], p.get('spd', 50))
    s3.vz.m[s3.S['msgtim']] = 0
    s3.fields(30)
    shot(s3, name)

# ---- banking demonstration (post-fix) ----
s4 = enter(0, 0)
pose(s4, -2800, 2200, 400, 60, 56)
s4.vz.m[s4.S['roll3']] = 0
a = s4.S['roll3']
v = int(35 * 65536 / 360) & 0xFFFF
s4.vz.m[a] = 0; s4.vz.m[a + 1] = v & 255; s4.vz.m[a + 2] = v >> 8
s4.vz.m[s4.S['msgtim']] = 0
s4.fields(16)
shot(s4, 'banking')

# ---- results screen ----
s5 = enter(0, 0)
s5.vz.m[s5.S['mdone']] = 1
sa = s5.S['score']
s5.vz.m[sa] = 850 & 255
s5.vz.m[sa + 1] = 850 >> 8
try:
    s5.vz.run_until(s5.S['results'], 20_000_000)
    s5.fields(30)
    shot(s5, 'results')
except Exception as e:
    print('results screen skipped:', e)

print('done,', n, 'shots in', OUT)
