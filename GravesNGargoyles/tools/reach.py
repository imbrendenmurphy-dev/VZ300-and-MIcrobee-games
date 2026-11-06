#!/usr/bin/env python3
"""Reachability checker for GRAVES 'N' GARGOYLES levels.

Simulates the hero's real movement rules (from src/hero.asm) over a tile map:
2 px walk steps, jump velocity -$400, gravity $50, max fall $500, variable
jump height, leading-edge wall probes, feet probes for landing (one-way tiles
only from above), head bumps.  Returns every standing position reachable
from the start without taking damage, and every pixel position the hero's
body passes through (to decide which pickups can be touched).
"""
from collections import deque

JUMPV, GRAV, MAXFALL = 0x400, 0x50, 0x500

class World:
    def __init__(self, M, attr, W):
        self.M, self.attr, self.W = M, attr, W

    def tile(self, x, y):
        """attribute at pixel (x, y): 0 empty 1 solid 2 one-way 3 hazard"""
        if y < 0: return 0
        if y >= 56: return 1
        if x < 0: return 1
        c = x >> 3
        if c >= self.W: return 1
        return self.attr[self.M[y >> 3][c]]


def simulate(w, x, y, vy, plan, xlim, frames=80):
    """run the hero from (x, y, vy) with plan(frame) -> (dx, up_held).
    Yields positions; returns (x, y, landed_attr) at the end, or None."""
    yf = 0
    path = []
    on_ground = vy == 0 and False
    for f in range(frames):
        dx, up = plan(f)
        if dx:
            nx = x + 2 * dx
            if xlim[0] <= nx < xlim[1]:
                bx = nx + (9 if dx > 0 else 2)
                if w.tile(bx, y + 4) != 1 and w.tile(bx, y + 13) != 1:
                    x = nx
        if not up and vy < 0 and vy < -0x100:
            vy = -0x100
        vy = min(vy + GRAV, MAXFALL)
        old_feet = y + 16
        pos = (y << 8) + yf + vy
        y, yf = pos >> 8, pos & 255
        if vy >= 0:
            landed = None
            for px in (4, 7):
                a = w.tile(x + px, y + 16)
                if a in (1, 3) or (a == 2 and old_feet <= ((y + 16) & 0xF8)):
                    landed = a
                    break
            if landed is not None:
                y = ((y + 16) & 0xF8) - 16
                path.append((x, y))
                return x, y, landed, path
        else:
            if w.tile(x + 5, y + 2) == 1:
                vy = 0
                y = ((y + 2) & 0xF8) + 6
                yf = 0
        path.append((x, y))
        if y > 60:
            return None
    return None


def plans():
    """a set of input plans covering walking off edges, full and short jumps,
    and steering in the air"""
    P = []
    for d in (-1, 0, 1):
        P.append(('walk', d, None))
    for d in (-1, 0, 1):
        for k in (0, 6, 12, 18):         # direction held from frame k
            P.append(('jump', d, k))
        P.append(('hop', d, 0))
    for d in (-1, 1):
        for k in (8, 14):                # direction released at frame k
            P.append(('jumpstop', d, k))
    return P


def run_plan(w, x, y, p, xlim):
    kind, d, k = p
    if kind == 'walk':
        nx = x + 2 * d
        if d == 0 or not (xlim[0] <= nx < xlim[1]):
            return None
        bx = nx + (9 if d > 0 else 2)
        if w.tile(bx, y + 4) == 1 or w.tile(bx, y + 13) == 1:
            return None
        # still on the ground?
        for px in (4, 7):
            a = w.tile(nx + px, y + 16)
            if a in (1, 2, 3):
                return nx, y, a, [(nx, y)]
        return simulate(w, nx, y, 0, lambda f: (d, False), xlim)
    if kind == 'jump':
        return simulate(w, x, y, -JUMPV, lambda f: (d if f >= k else 0, True), xlim)
    if kind == 'jumpstop':
        return simulate(w, x, y, -JUMPV, lambda f: (d if f < k else 0, True), xlim)
    if kind == 'hop':
        return simulate(w, x, y, -JUMPV, lambda f: (d, f < 3), xlim)


def explore(w, start, xlim):
    """BFS over standing positions reachable without landing on hazards."""
    seen = {start}
    touched = set([start])
    hazard_landings = set()
    q = deque([start])
    P = plans()
    while q:
        x, y = q.popleft()
        for p in P:
            r = run_plan(w, x, y, p, xlim)
            if r is None:
                continue
            nx, ny, a, path = r
            touched.update(path)
            if a == 3:
                hazard_landings.add((nx, ny))
                continue
            if (nx, ny) not in seen:
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen, touched, hazard_landings


def can_touch(touched, bx, by, bw, bh):
    """hero body x+2..x+10, y..y+16 overlapping box"""
    for (x, y) in touched:
        if x + 2 < bx + bw and bx < x + 10 and y < by + bh and by < y + 16:
            return True
    return False


def traps(w, hazard_landings, xlim):
    """hazard landing spots from which no sequence of damage bounces
    (vy -$380, steerable) gets the hero back onto safe ground"""
    BOUNCE = 0x380
    P = [(d, k) for d in (-1, 0, 1) for k in (0, 6, 12)]
    memo = {}
    def escapes(start):
        seen = {start}
        q = deque([start])
        while q:
            x, y = q.popleft()
            for d, k in P:
                r = simulate(w, x, y, -BOUNCE, lambda f: (d if f >= k else 0, True), xlim)
                if r is None:
                    continue
                nx, ny, a, path = r
                if a != 3:
                    return True
                if (nx, ny) not in seen:
                    seen.add((nx, ny)); q.append((nx, ny))
        return False
    return [h for h in hazard_landings if not escapes(h)]
