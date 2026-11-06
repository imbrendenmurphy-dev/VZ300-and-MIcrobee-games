# materials.py - tone-ramp materials for the first-person view
import math
from walls import HOR, CX, floor_z, WB
from tone import *

def h2(a, b, s=0):
    n = (a * 374761393 + b * 668265263 + s * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

class Mat:
    css = 0
    fogk = 1
    def shade(self, rampname, idx, z, extra=0):
        r = self.ramps[rampname]
        i = min(len(r) - 1, max(0, idx + fogstep(z) * self.fogk + extra))
        return r[i]
    def colour(self, u, v, z, face, decor, only_decor=False):
        if decor:
            ul = u - face[1] if face[0] == 'side' else u
            t = decor(ul, v, z, face)
            if t is not None:
                rn, i = t
                return self.shade(rn, i, z)
            if only_decor: return None
        rn, i = self.wall(self.kind, u, v, z, face)
        return self.shade(rn, i, z)

class Grounds(Mat):
    ramps = {
        'hedge': ramp((G, Y, .5), (G, Y, .25), (G, G, 0), (G, B, .25), (G, B, .5), (G, B, .75), (B, B, 0)),
        'stone': ramp((Y, B, .25), (Y, B, .5), (Y, B, .75), (B, B, 0), (B, B, 0), (B, B, 0)),
        'moss':  ramp((G, Y, .25), (G, B, .25), (G, B, .5), (G, B, .75), (B, B, 0)),
        'brick': ramp((R, Y, .5), (R, R, 0), (R, B, .25), (R, B, .5), (R, B, .75), (B, B, 0)),
        'dark':  ramp((B, B, 0), (B, B, 0)),
        'gold':  ramp((Y, Y, 0), (Y, R, .25), (Y, R, .5), (R, B, .5), (B, B, 0)),
        'sky':   ramp((B, B, 0),),
        'grass': ramp((G, G, 0), (G, B, .25), (G, B, .5), (G, B, .75), (B, B, 0)),
        'red':   ramp((R, R, 0), (R, B, .25), (R, B, .5), (B, B, 0)),
        'yel':   ramp((Y, Y, 0), (Y, B, .25), (Y, B, .5), (B, B, 0)),
    }
    def wall(self, kind, u, v, z, face):
        if kind == 'B':  # graveyard stone wall
            bh = 0.25; row = int(math.floor(v / bh)); off = 0.5 if row & 1 else 0.0
            bu = u * 2.0 + off; col = int(math.floor(bu)); fu = bu - col; fv = v / bh - row
            if v > 1.38: return ('stone', 1)
            if fv < 0.14 or fu < 0.06: return ('dark', 0)
            mossy = (0.5 - v) * 3 + (h2(int(u * 6), int(v * 6), 3) - 0.5) * 1.6
            if mossy > 0.6: return ('moss', 1)
            if fv > 0.78: return ('stone', 1)
            return ('stone', 2)
        # hedge: staggered leafy clumps, lit from above
        if v > 1.42: return ('hedge', 1)
        cv = v * 6.5; row = int(cv); fv = cv - row
        cu = u * 5.0 + (0.5 if row & 1 else 0.0); col = int(cu); fu = cu - col
        n = h2(col, row, 1)
        dx = fu - 0.5 + (n - 0.5) * 0.2; dy = fv - 0.5
        dd = dx * dx + dy * dy * 1.2
        if dd < 0.10: i = 1 if dy > 0.08 else 2
        elif dd < 0.17: i = 2
        else: i = 3 + (1 if n < 0.3 else 0)
        if v < 0.12: i = 5
        return ('hedge', i)

    def bg(self, px, py, variant):
        sx, sy = int(px), int(py)
        if py < HOR:
            c = ('sky', 0)
            if h2(sx, sy, 7) > 0.975 and py < HOR - 5: c = ('yel', 0)
            mx, my = 62, 8
            dd = math.hypot((px - mx) * 0.66, py - my)
            if dd < 5.0:
                c = ('yel', 0)
                if math.hypot((px - mx + 2.5) * 0.66, py - my + 1.5) < 4.0: c = ('sky', 0)
            if variant == 1:
                x = px; h = 0
                if 22 < x < 58: h = 4 + (1 if (int(x) // 3) % 2 else 0)
                for tx, th, tw in ((26, 8, 2), (34, 11, 2), (46, 9, 2), (53, 7, 2)):
                    if tx - tw <= x <= tx + tw: h = max(h, th)
                    if abs(x - tx) <= tw + 1: h = max(h, th + 5 - abs(x - tx) * 5 / (tw + 1)) if abs(x - tx) <= tw + 1 else h
                if py > HOR - h:
                    c = ('red', 2)
                    if h2(int(x) // 2, int(py) // 2, 9) > 0.88 and py < HOR - 2: c = ('yel', 0)
            return self.ramps[c[0]][c[1]]
        z = floor_z(py, True)
        if z > 4.0: return (B, B, 0)
        wx = (px - CX) / (64.0 / max(z, 0.5))
        if abs(wx) < 0.2:
            r = 'stone'; i = 2 if (z * 3) % 1 > 0.2 else 4
        else:
            r = 'grass'; i = 0 if h2(int(wx * 10), int(z * 8), 4) > 0.3 else 1
        return self.shade(r, i, z - 0.3)

class Hall(Mat):
    ramps = {
        'stone': ramp((Y, B, .25), (Y, B, .5), (Y, B, .75), (B, B, 0), (B, B, 0)),
        'hi':    ramp((Y, Y, 0), (Y, B, .25), (Y, B, .5), (Y, B, .75), (B, B, 0)),
        'dark':  ramp((B, B, 0),),
        'paper': ramp((R, R, 0), (R, B, .25), (R, B, .5), (R, B, .75), (B, B, 0)),
        'gold':  ramp((Y, Y, 0), (Y, R, .5), (R, R, 0), (R, B, .5), (B, B, 0)),
        'wood':  ramp((R, Y, .25), (R, R, 0), (R, B, .25), (R, B, .5), (B, B, 0)),
        'carpet': ramp((R, R, 0), (R, B, .25), (R, B, .5), (B, B, 0)),
        'tileA': ramp((Y, B, .25), (Y, B, .5), (Y, B, .75), (B, B, 0)),
        'tileB': ramp((B, B, 0),),
        'beam':  ramp((R, B, .5), (R, B, .75), (B, B, 0)),
    }
    def wall(self, kind, u, v, z, face):
        if kind == 'B':  # red damask wallpaper over panelling
            if v < 0.45:
                if v > 0.39: return ('gold', 0)
                pu = (u * 4) % 1
                return ('wood', 2) if 0.08 < pu < 0.92 else ('wood', 3)
            if v > 1.36: return ('gold', 1)
            pu = (u * 4) % 1; pv = ((v - 0.45) * 4.4) % 1
            d = abs(pu - 0.5) + abs(pv - 0.5)
            if 0.40 < d < 0.52: return ('gold', 1)
            if d < 0.1: return ('gold', 1)
            return ('paper', 0)
        bh = 0.3; row = int(math.floor(v / bh)); off = 0.5 if row & 1 else 0.0
        bu = u * 2 + off; col = int(math.floor(bu)); fu = bu - col; fv = v / bh - row
        if fv < 0.11 or fu < 0.05: return ('dark', 0)
        if fv > 0.8: return ('hi', 1)
        return ('stone', 1)
    def bg(self, px, py, variant):
        if py < HOR:
            z = floor_z(py, False)
            if z > 4.0: return (B, B, 0)
            wx = (px - CX) / (64.0 / max(z, 0.5))
            if (z * 2) % 1 < 0.2: return self.shade('beam', 0, z - 0.5)
            return (B, B, 0)
        z = floor_z(py, True)
        if z > 4.0: return (B, B, 0)
        wx = (px - CX) / (64.0 / max(z, 0.5))
        if abs(wx) < 0.24:
            if abs(wx) > 0.19: return self.shade('gold', 0, z - 0.4)
            return self.shade('carpet', 0, z - 0.4)
        chk = (int(math.floor(wx * 3)) + int(math.floor(z * 3))) & 1
        return self.shade('tileA' if chk else 'tileB', 0, z - 0.4)

class Library(Mat):
    ramps = {
        'wood':  ramp((R, Y, .25), (R, R, 0), (R, B, .25), (R, B, .5), (R, B, .75), (B, B, 0)),
        'dark':  ramp((B, B, 0),),
        'bk0':   ramp((R, R, 0), (R, B, .25), (R, B, .5), (B, B, 0)),
        'bk1':   ramp((G, G, 0), (G, B, .25), (G, B, .5), (B, B, 0)),
        'bk2':   ramp((Y, Y, 0), (Y, B, .25), (Y, B, .5), (B, B, 0)),
        'bk3':   ramp((Y, R, .5), (R, B, .25), (R, B, .5), (B, B, 0)),
        'stone': ramp((Y, B, .25), (Y, B, .5), (Y, B, .75), (B, B, 0), (B, B, 0)),
        'hi':    ramp((Y, Y, 0), (Y, B, .25), (Y, B, .5), (Y, B, .75), (B, B, 0)),
        'gold':  ramp((Y, Y, 0), (Y, R, .5), (R, R, 0), (R, B, .5), (B, B, 0)),
        'floor': ramp((R, B, .25), (R, B, .5), (R, B, .75), (B, B, 0)),
        'rug':   ramp((G, B, .25), (G, B, .5), (G, B, .75), (B, B, 0)),
        'beam':  ramp((R, B, .5), (R, B, .75), (B, B, 0)),
    }
    def wall(self, kind, u, v, z, face):
        if kind == 'B':  # dark panelled stone
            if v < 0.5:
                if v > 0.44: return ('gold', 1)
                pu = (u * 3) % 1
                return ('wood', 2) if 0.1 < pu < 0.9 else ('wood', 4)
            bh = 0.3; row = int(math.floor((v - 0.5) / bh)); off = 0.5 if row & 1 else 0.0
            bu = u * 2 + off; col = int(math.floor(bu)); fu = bu - col; fv = (v - 0.5) / bh - row
            if fv < 0.12 or fu < 0.05: return ('dark', 0)
            if fv > 0.8: return ('hi', 2)
            return ('stone', 1)
        # bookshelf: wooden frame, 4 shelves of coloured spines
        if u < 0.06 or u > 0.94: return ('wood', 1)
        if v > 1.4: return ('wood', 1)
        sh = v / 0.35; row = int(sh); fv = sh - row
        if fv < 0.14: return ('wood', 1) if fv > 0.04 else ('wood', 0)
        if fv > 0.93: return ('dark', 0)
        bw = 0.075; uu = u + row * 0.37; col = int(uu / bw)
        n = h2(col, row, 11)
        if n < 0.12: return ('dark', 0)       # a gap on the shelf
        top = 0.6 + h2(col, row, 5) * 0.32   # uneven book heights
        if fv > top: return ('dark', 0)
        if uu % bw < 0.018: return ('dark', 0)
        bk = 'bk%d' % (col % 3 if n < 0.85 else 3)
        i = 2 if 0.3 < fv < 0.38 else 0      # a dark band across each spine
        return (bk, i)
    def bg(self, px, py, variant):
        if py < HOR:
            z = floor_z(py, False)
            if z > 4.0: return (B, B, 0)
            if (z * 2) % 1 < 0.22: return self.shade('beam', 0, z - 0.5)
            return (B, B, 0)
        z = floor_z(py, True)
        if z > 4.0: return (B, B, 0)
        wx = (px - CX) / (64.0 / max(z, 0.5))
        if abs(wx) < 0.3:
            if abs(wx) > 0.25: return self.shade('gold', 1, z - 0.4)
            return self.shade('rug', 0 if (int(z * 6) & 1) else 1, z - 0.4)
        if (z * 5) % 1 < 0.15: return self.shade('floor', 2, z - 0.4)
        return self.shade('floor', 0, z - 0.4)
