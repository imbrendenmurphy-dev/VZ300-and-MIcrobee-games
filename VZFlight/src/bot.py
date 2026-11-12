"""Robot test pilot: flies missions in the emulator using only the keyboard."""
import math, sys, time
from h2 import Sim, sheet

def angdiff(a, b):
    return (a - b + 180) % 360 - 180

class Pilot:
    def __init__(self, sim):
        self.s = sim
        self.vz = sim.vz
        self.S = sim.S
        self.log = []

    def frame(self, keys):
        vz = self.vz
        vz.release_all()
        if keys:
            vz.press(*keys)
        vz.step()
        try:
            vz.run_until(self.S['flyloop'], 60_000_000)
        except RuntimeError:
            self.left = True

    def goal(self):
        m, S = self.vz.m, self.S
        if m[S['goalcnt']] == 0 or m[S['mdone']]:
            return None
        p = m[S['goalp']] | m[S['goalp'] + 1] << 8
        w = lambda o: int.from_bytes(m[p + o:p + o + 2], 'little', signed=True)
        g = dict(type=m[p], x=w(1), z=w(3), r=w(5), ylo=w(7), yhi=w(9))
        if g['type'] >= 3:
            g['x'] += self.vz.ws(S['shipx']); g['z'] += self.vz.ws(S['shipz'])
        return g

    def fly(self, maxsec=600, shots=None, tag='m'):
        s, S, vz = self.s, self.S, self.vz
        heli = vz.m[S['heli']]
        t0 = vz.t
        shotn = 0
        nextshot = 0
        files = []
        lastgoal = -1
        while True:
            st = s.state()
            if vz.m[S['quitf']] or getattr(self, 'left', False):
                print('  LEFT FLIGHT (results screen)', st)
                break
            tsec = (vz.t - t0) / 3546900
            if tsec > maxsec:
                print('  TIMEOUT', st); break
            if shots and tsec >= nextshot:
                f = '%s_%02d.png' % (tag, shotn); s.shot(f); files.append(f); shotn += 1; nextshot += shots
            if st['goal'] != lastgoal:
                print('  goal %d at %.0fs  %s' % (st['goal'], tsec, st)); lastgoal = st['goal']
            g = self.goal()
            keys = self.heli_keys(st, g) if heli else self.plane_keys(st, g)
            self.frame(keys)
        print('  END quitf=%d  t=%ds crashes=%d' % (vz.m[S['quitf']], vz.ws(S['msec']), vz.m[S['crashes']]))
        return files

    # ------------------------------------------------------------ aeroplane
    def plane_keys(self, st, g):
        keys = []
        if st['crash'] or g is None:
            return keys
        dx, dz = g['x'] - st['x'], g['z'] - st['z']
        dist = math.hypot(dx, dz)
        brg = math.degrees(math.atan2(dx, dz)) % 360
        herr = angdiff(brg, st['hdg'])
        land = g['type'] in (2, 3)
        if st['gnd']:
            if land and st['goal'] == self.last_land_goal if hasattr(self, 'last_land_goal') else False:
                pass
            if land and dist < g['r'] and self.landing:
                keys.append('SPACE')
                if st['thr'] > 0: keys.append('S')
                return keys
            self.landing = False
            if st['thr'] < 250: keys.append('W')
            if st['spd'] > 30: keys.append('Q')
            if abs(herr) > 4 and st['spd'] > 2 and not land:
                keys.append(',' if herr > 0 else 'M')
            return keys
        # airborne
        if land:
            # approach: glide toward the runway, flare near the ground
            talt = max(0.0, (dist - 250) * 0.07)
            self.landing = True
            tthr = 120 if dist > 1500 else 70
            if st['y'] < 18 and dist < 1500:
                tthr = 0
        else:
            self.landing = False
            talt = (g['ylo'] + g['yhi']) / 2
            tthr = 190
        troll = max(-25, min(25, herr * 1.2))
        if st['rol'] < troll - 4: keys.append(',')
        elif st['rol'] > troll + 4: keys.append('M')
        tp = max(-8, min(9, (talt - st['y']) * 0.12))
        if land and st['y'] < 18:
            tp = 1.5
        if st['pit'] < tp - 1.5: keys.append('Q')
        elif st['pit'] > tp + 1.5: keys.append('A')
        if st['thr'] < tthr - 8: keys.append('W')
        elif st['thr'] > tthr + 8: keys.append('S')
        return keys

    # ------------------------------------------------------------ helicopter
    def heli_keys(self, st, g):
        keys = []
        if st['crash'] or g is None:
            return keys
        dx, dz = g['x'] - st['x'], g['z'] - st['z']
        land = g['type'] in (2, 3)
        lead = 0
        if g['type'] >= 3:
            dz += 6 * 6        # lead the moving ship a little
        dist = math.hypot(dx, dz)
        brg = math.degrees(math.atan2(dx, dz)) % 360
        herr = angdiff(brg, st['hdg'])
        if land:
            talt = 60 if dist > 400 else (30 + (dist / 400) * 30)
            if g['type'] == 3: talt += 16
        else:
            talt = (max(g['ylo'], 0) + g['yhi']) / 2
            if g['yhi'] < 60: talt = min(talt, 25)
        if dist > 40:
            if abs(herr) > 6: keys.append(',' if herr > 0 else 'M')
        # forward speed target
        if land:
            vt = min(40, dist * 0.12)
            if g['type'] == 3: vt = max(vt, 6.5 if dist > 25 else 6)
        else:
            vt = 40 if abs(herr) < 30 else 10
        if st['spd'] < vt - 2: tp = -12
        elif st['spd'] > vt + 2: tp = 8
        else: tp = -3 if vt > 5 else 0
        if abs(herr) > 60: tp = 4
        if st['pit'] < tp - 1.5: keys.append('Q')
        elif st['pit'] > tp + 1.5: keys.append('A')
        # collective: hold altitude, descend onto the pad when close
        if land and dist < g['r'] * 0.6 and abs(st['spd'] - (6 if g['type'] == 3 else 0)) < 3:
            tthr = 108
        else:
            tthr = 128 + max(-30, min(40, (talt - st['y']) * 1.0))
        if st['gnd'] and not (land and dist < g['r']):
            tthr = 175
        if st['thr'] < tthr - 5: keys.append('W')
        elif st['thr'] > tthr + 5: keys.append('S')
        return keys


def run_mission(loc, mis, tag, maxsec=600, shots=None):
    s = Sim()
    S, vz = s.S, s.vz
    s.fields(40)
    s.tap('SPACE'); s.fields(30)
    vz.m[S['locidx']] = loc; vz.m[S['misidx']] = mis
    s.tap('A'); s.tap('Q')            # redraw the menu with the new selection
    s.fields(10)
    s.tap('SPACE'); s.fields(30)
    s.shot('%s_brief.png' % tag)
    s.tap('SPACE', 6, 2)
    vz.run_until(S['flyloop'], 50_000_000)
    p = Pilot(s)
    p.landing = False
    print('mission', loc, mis, s.state())
    files = p.fly(maxsec, shots, tag)
    s.fields(60)
    s.shot('%s_result.png' % tag)
    return s, files

if __name__ == '__main__':
    loc, mis = int(sys.argv[1]), int(sys.argv[2])
    t = time.time()
    s, files = run_mission(loc, mis, 'r%d%d' % (loc, mis), shots=float(sys.argv[3]) if len(sys.argv) > 3 else None)
    print('wall %.0fs' % (time.time() - t))
    if files:
        sheet(files[:12] + ['r%d%d_result.png' % (loc, mis)], 'r%d%d_sheet.png' % (loc, mis), 3)
