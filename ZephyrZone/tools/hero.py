"""ZEPHYR - the hero, drawn as a posable puppet (original design).
Behind view: blue bubble helmet with a red goggle strap, red scarf streaming in the wind,
blue twin-nozzle jet-pack, yellow flight suit, red boots, a stubby blaster in the right hand."""
import sys, math
sys.path.insert(0, 'tools')
from draw import Canvas, crop, preview
G, Y, B, R = 0, 1, 2, 3
W, H = 26, 32          # canvas in output pixels

def hero(lean=0.0, pitch=0.0, legs=0.0, run=None, flame=0, fire=False, hurt=False, wave=0, arm_up=False, scale=0.78, squash=1.0):
    """lean: degrees (+ = banking right), pitch: -1 diving .. +1 climbing,
    legs: spread, run: None or phase 0..3 (running on the ground), flame: 0/1/2 (none/short/long)."""
    c = Canvas(W, H, W / 2, H - 1)
    c.push(0, -18 * scale * squash, lean, scale, scale * squash)
    c.push(0, 18)
    k = 1.0 - 0.25 * pitch        # climbing: legs hang lower (longer); diving: tucked up
    hip_y = -15
    # --- legs (behind the body from our view they hang towards us = lower on screen)
    if run is None:
        lspread = 3.5 + legs
        for sgn in (-1, 1):
            fx = sgn * (lspread + 1.5); fy = hip_y + 13 * k
            c.capsule(sgn * 2.6, hip_y, fx, fy, 2.6, Y, 2.4)
            c.ellipse(fx, fy + 1.0, 2.9, 2.2, R)              # boot sole
    else:
        ph = [0, 1, 0, -1][run % 4]
        for sgn in (-1, 1):
            lift = 4.5 if ph * sgn > 0 else 0.0
            fx = sgn * 3.6; fy = hip_y + 13 - lift
            c.capsule(sgn * 2.6, hip_y, fx, fy, 2.6, Y, 2.4)
            c.ellipse(fx, fy + 1.0, 2.9, 2.2 if lift == 0 else 1.6, R)
    # --- jet flames under the nozzles
    if flame:
        fl = 4.5 if flame == 2 else 2.5
        for sgn in (-1, 1):
            c.ellipse(sgn * 3.6, hip_y + 2 + fl * 0.6, 1.9, fl, R)
            c.ellipse(sgn * 3.6, hip_y + 1.5 + fl * 0.4, 1.0, fl * 0.6, Y)
    # --- arms (out to the sides, blaster in the right hand)
    sh_y = -27
    if hurt:
        c.capsule(-5.5, sh_y, -11, sh_y - 6, 2.2, Y)
        c.capsule(5.5, sh_y, 11, sh_y - 6, 2.2, Y)
    else:
        c.capsule(-5.5, sh_y, -10.5, sh_y + 6 - 2 * pitch, 2.3, Y)
        if arm_up:
            c.capsule(5.5, sh_y, 8.5, sh_y - 10, 2.3, Y)
            c.circle(8.5, sh_y - 11, 2.2, R)
        else:
            c.capsule(5.5, sh_y, 10, sh_y + 3 - 2 * pitch, 2.3, Y)
            c.rect(8.2, sh_y - 1 - 2 * pitch, 12.2, sh_y + 3 - 2 * pitch, B)   # blaster
            if fire:
                c.ellipse(10.2, sh_y - 3.5 - 2 * pitch, 3.6, 3.0, Y)
                c.ellipse(10.2, sh_y - 3.5 - 2 * pitch, 1.6, 1.4, R)
    # --- jet-pack / torso
    c.rect(-6.2, -30, 6.2, hip_y + 1, B)
    c.rect(-6.2, -30, 6.2, -28.4, Y)                      # yellow collar of the suit
    c.rect(-1.0, -27, 1.0, hip_y - 1, R)                  # centre seam
    for sgn in (-1, 1):
        c.rect(sgn * 3.6 - 1.8, hip_y - 1, sgn * 3.6 + 1.8, hip_y + 2.2, R)   # nozzles
        c.rect(sgn * 3.8 - 0.6, -26, sgn * 3.8 + 0.6, -24.5, Y)              # rivet lights
    # --- scarf streaming back towards us
    sw = math.sin(wave * math.pi / 2)
    c.capsule(1.5, -31, 6 + 2 * sw, -24 + 2 * pitch, 1.9, R, 1.4)
    c.capsule(6 + 2 * sw, -24 + 2 * pitch, 9 - sw, -18 + 3 * pitch, 1.4, R, 1.0)
    # --- helmet
    c.circle(0, -36, 6.4, B)
    c.ellipse(-2.4, -38.5, 2.2, 1.6, Y)                   # sheen
    c.rect(-6.6, -35.2, 6.6, -32.8, R)                    # goggle strap
    c.pop(); c.pop()
    g = c.resolve(prio=(R, Y, B, G))
    if hurt:   # flash: swap yellow/blue
        g = [[{Y: B, B: Y}.get(v, v) for v in r] for r in g]
    return g

POSES = {}
def build():
    P = []
    P.append(('fly', hero(flame=1)))
    P.append(('fly2', hero(flame=2, wave=1)))
    P.append(('bankL', hero(lean=-16, flame=1, wave=1)))
    P.append(('bankL2', hero(lean=-28, flame=2, wave=2)))
    P.append(('bankR', hero(lean=16, flame=1, wave=3)))
    P.append(('bankR2', hero(lean=28, flame=2)))
    P.append(('climb', hero(pitch=1, flame=2, legs=-1)))
    P.append(('dive', hero(pitch=-1, flame=0, legs=1)))
    P.append(('run0', hero(run=0, flame=0)))
    P.append(('run1', hero(run=1, flame=0)))
    P.append(('run2', hero(run=2, flame=0, wave=2)))
    P.append(('run3', hero(run=3, flame=0, wave=2)))
    P.append(('fire', hero(flame=1, fire=True)))
    P.append(('hurt', hero(hurt=True, flame=0, legs=2)))
    P.append(('cheer', hero(arm_up=True, flame=1)))
    # struck down: thrown back, toppling, flat on the ground
    P.append(('fall1', hero(hurt=True, lean=-20, legs=3, squash=0.85)))
    P.append(('fall2', hero(hurt=True, lean=-55, legs=4, squash=0.65)))
    P.append(('down', hero(hurt=True, lean=-86, legs=4, squash=0.5)))
    return P

if __name__ == '__main__':
    P = build()
    gs = [crop(g)[0] for n, g in P]
    preview(gs, 'build/hero.png', cols=8, scale=5)
    for n, g in P:
        cg = crop(g)[0]; print(n, len(cg[0]), 'x', len(cg))
