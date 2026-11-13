#!/usr/bin/env python3
"""RED DUST RUMBLE roster: nine fighters drawn from posed skeletons, with
their moves, CPU habits and finishers, built into loadable fighter blocks.

A fighter block is position independent: every pointer in its header and in
its frame directory is an offset from the start of the block, turned into an
address by the game after loading.

  0  'R','D'           2  dw length        4  dw checksum (bytes 6..end)
  6  frames            7  fighter number
  8  walk fwd, walk back, jump vx fwd, jump vx back, jump length, hurt height
 14  finisher: first direction, second direction, pose move, launch vx, vy
 20  dw jump arc, moves, frame directory, CPU habits, name, finisher name,
        CPU extras, spare
 frame directory entry (10 bytes): dw plain, dw shifted (0 = none), db width,
        height, anchor x, rows below the ground, hand x, hand y
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
import art
from art import Canvas, solve, pose_base, crop, pack, ASPECT, CANVAS_W, CANVAS_H, OX, OY

Y, B = 1, 2

FRAME_NAMES = ['IDLE', 'WALK1', 'WALK2', 'CROUCH', 'JUMP', 'BLOCK', 'CBLOCK',
               'SA_W', 'SA_S', 'SB_W', 'SB_S', 'CA_S', 'CB_S', 'JA', 'JB',
               'HIT', 'DOWN', 'SP1_W', 'SP1_S', 'SP2_W', 'SP2_S', 'WIN',
               'IDLE2', 'TAUNT']
FR = {n: i for i, n in enumerate(FRAME_NAMES)}
# frames shown while the fighter slides or travels get a second copy moved
# 2 pixels right; the rest are only ever drawn standing still
SHIFTED = ('WALK1', 'WALK2', 'JUMP', 'JA', 'JB', 'HIT', 'BLOCK', 'CBLOCK', 'SP1_S', 'SP2_S')

# move flags (as in fight.asm)
LOW, HIGH, KD, SPEC, LIGHT, INVSU, RISE, AIR = 1, 2, 4, 8, 16, 32, 64, 128
# CPU actions (as in cpu.asm)
WAIT, FWD, BACK, BLOCK, CBLOCK, JFWD, JBACK, SA, SB, CA, CB, SP1, SP2, TAUNT = range(14)
DN, BK, FW = 2, 4, 8                       # finisher directions (relative to facing)


# ------------------------------------------------------------------ bodies
COMPACT = dict(thigh=9.5, shin=10, torso=14, neck=2.5, head=4.6, uarm=8, farm=8,
               leg_r=2.7, arm_r=2.5, torso_r=6.2, fist_r=3.1)
TALL = dict(thigh=11.5, shin=12, torso=15.5, neck=2.5, head=4.0, uarm=9.5, farm=9.5,
            leg_r=2.2, arm_r=2.1, torso_r=5.0, fist_r=2.3)


def body(base, **kw):
    d = dict(base)
    d.update(kw)
    return d


def boot(cv, foot, colour, r=1.9):
    cv.capsule(foot, (foot[0] + 3.2, foot[1] - 0.2), r, colour, True)


def draw(cv, f, J, p):
    """one generic figure; the costume comes from f['look']"""
    k = f['look']
    sleeve = k.get('sleeve', Y)
    legc = k.get('legs', B)
    bootc = k.get('boots', Y if legc == B else B)
    baggy = k.get('baggy', 0)
    torsoc = k.get('torso', B)
    hx, hy = J['hip']
    nx, ny = J['neck']
    lie = p['lie']
    # ---- cape, behind everything
    if k.get('cape') and not lie:
        ln = k['cape']
        sx, sy = J['sh']
        cv.poly([(sx - 1, sy + 2.5), (sx + 3, sy + 1), (hx - 2, hy - ln * 0.5),
                 (hx - 7 - ln * 0.35, hy - ln), (hx - 9 - ln * 0.2, hy - ln + 4)], B, False)
    # ---- back arm
    cv.capsule(J['sh'], J['eb'], f['arm_r'], sleeve, False)
    cv.capsule(J['eb'], J['hb'], f['arm_r'] - 0.2, sleeve)
    cv.ellipse(J['hb'][0], J['hb'][1], f['fist_r'], f['fist_r'], Y)
    # ---- back leg
    cv.capsule(J['hip'], J['kb'], f['leg_r'] + 0.4 + baggy, legc)
    cv.capsule(J['kb'], J['fb'], f['leg_r'] + baggy * 0.8, legc)
    boot(cv, J['fb'], bootc)
    # ---- coat tails (drawn before the front leg so the leg shows)
    if k.get('coat') and not lie:
        kfx, kfy = J['kf']; kbx, kby = J['kb']
        tail_y = min(kfy, kby) + 2.5
        cv.poly([(nx - 4.2, ny - 1.5), (nx + 4.2, ny - 1.5),
                 (max(hx + 5.5, kfx + 1.5), tail_y), (min(hx - 6.5, kbx - 2.5) - 2, tail_y + 1.0)], B)
    # ---- torso
    if k.get('coat'):
        cv.capsule(J['hip'], (nx, ny - 2), f['torso_r'], B, False)
    else:
        cv.capsule(J['hip'], (nx * 0.9, ny - 3), f['torso_r'], torsoc)
    # ---- front leg
    cv.capsule(J['hip'], J['kf'], f['leg_r'] + 0.4 + baggy, legc)
    cv.capsule(J['kf'], J['ff'], f['leg_r'] + baggy * 0.8, legc)
    boot(cv, J['ff'], bootc)
    # ---- skirt / kilt over the thighs
    if k.get('skirt') and not lie:
        ln = k['skirt']
        kfx, kfy = J['kf']; kbx, kby = J['kb']
        cv.poly([(hx - 5.5, hy + 2.5), (hx + 5.5, hy + 2.5),
                 (max(hx + 6.5, kfx + 2.5), hy - ln), (min(hx - 6.5, kbx - 2.5), hy - ln)],
                k.get('skirtc', B), k.get('skirtc', B) != torsoc)
    # ---- belt or sash
    belt = k.get('belt')
    if belt:
        cv.capsule((hx - 4.5, hy + 1.2), (hx + 4.5, hy + 1.2), 0.8, belt, False)
    if k.get('sash'):
        cv.capsule((J['sh'][0] + 3.0, J['sh'][1]), (hx - 4.0, hy + 2.5), 1.3, k['sash'], False)
    # ---- neck and head
    cv.capsule(J['neck'], J['head'], 2.0, Y, False)
    qx, qy = J['head']
    r = f['head']
    cv.ellipse(qx, qy, r, r * 1.05, Y)
    head = k.get('head', 'hair')
    if p['extra'] in ('hat_off', 'bare'):
        head = 'hair'
    if head == 'hair':            # a cap of short hair
        cv.shape(lambda x, y: ((x - qx) / (r + 0.6)) ** 2 + ((y - qy - 1.4) / (r * 0.8)) ** 2 < 1
                 and (y > qy + 1.5 or x < qx - 1.0), B, False)
    elif head == 'hat':           # wide-brimmed hat
        cv.ellipse(qx + 0.5, qy + 2.6, 8.5, 1.6, B, False)
        cv.ellipse(qx, qy + 4.8, 4.2, 3.0, B, False)
        cv.capsule((qx - 4.0, qy + 3.4), (qx + 4.0, qy + 3.4), 0.6, Y, False)
    elif head == 'tophat':        # tall top hat
        cv.ellipse(qx + 0.3, qy + 3.0, 7.0, 1.5, B, False)
        cv.poly([(qx - 3.8, qy + 3.0), (qx + 3.8, qy + 3.0), (qx + 4.3, qy + 9.5), (qx - 4.3, qy + 9.5)], B, False)
        cv.capsule((qx - 3.6, qy + 5.2), (qx + 3.6, qy + 5.2), 0.7, Y, False)
    elif head == 'crest':         # helmet with a horsehair crest
        cv.shape(lambda x, y: ((x - qx) / (r + 0.9)) ** 2 + ((y - qy - 0.8) / (r + 0.6)) ** 2 < 1
                 and (y > qy + 0.2 or x < qx - 0.5), B, False)
        cv.shape(lambda x, y: 1 < ((x - qx + 1.0) / (r + 3.0)) ** 2 + ((y - qy - 1.0) / (r + 3.6)) ** 2 < 2.0
                 and y > qy + 1.0 and x < qx + 4.5, B, False)
    elif head == 'ponytail':      # dark hair with a long tail
        cv.shape(lambda x, y: ((x - qx) / (r + 0.6)) ** 2 + ((y - qy - 1.2) / (r * 0.9)) ** 2 < 1
                 and (y > qy + 1.2 or x < qx - 1.5), B, False)
        cv.capsule((qx - r - 0.5, qy + 2.5), (qx - r - 5.5, qy - 2.0), 1.5, B, False)
        cv.capsule((qx - r - 5.5, qy - 2.0), (qx - r - 6.0, qy - 8.5), 1.2, B, False)
        cv.capsule((qx - r + 0.5, qy + 1.2), (qx + r - 0.2, qy + 1.2), 0.55, Y, False)   # headband
    elif head == 'nemes':         # striped royal headcloth
        cv.poly([(qx - 3.0, qy + r + 1.6), (qx + 3.6, qy + r + 1.6), (qx + 4.2, qy + 1.0),
                 (qx + 1.5, qy + 1.0), (qx - 0.5, qy - r - 4.5), (qx - 7.5, qy - r - 4.5)], B, False)
        cv.capsule((qx - 6.0, qy - r - 1.5), (qx - 1.5, qy - r - 1.5), 0.5, Y, False)
        cv.capsule((qx - 5.0, qy - 0.5), (qx - 1.8, qy - 0.5), 0.5, Y, False)
    elif head == 'braids':        # winged helmet and two long plaits
        cv.shape(lambda x, y: ((x - qx) / (r + 0.8)) ** 2 + ((y - qy - 1.0) / (r + 0.5)) ** 2 < 1
                 and y > qy + 0.8, B, False)
        cv.poly([(qx - 2.5, qy + r + 0.5), (qx - 6.5, qy + r + 5.5), (qx - 0.5, qy + r + 1.5)], B, False)
        cv.capsule((qx - r + 0.6, qy - 1.0), (qx - r - 0.6, qy - 11.0), 1.3, Y, False)
        cv.capsule((qx - r - 0.6, qy - 11.0), (qx - r - 0.6, qy - 12.5), 1.5, B, False)
    elif head == 'mask':          # wrestling mask: dark head, bright eye patch
        cv.ellipse(qx, qy, r + 0.5, r * 1.05 + 0.5, B, False)
        cv.ellipse(qx + 2.0, qy + 0.4, 1.9, 1.5, Y, False)
        cv.capsule((qx - r - 0.3, qy + 2.0), (qx - r - 3.2, qy + 0.5), 0.8, B, False)
    elif head == 'turban':        # a big wound turban with a jewel
        cv.ellipse(qx - 0.3, qy + 3.4, r + 2.4, 3.6, B, False)
        cv.ellipse(qx + 0.2, qy + 5.6, r + 0.4, 2.4, B, False)
        cv.ellipse(qx + 3.2, qy + 3.6, 1.2, 1.2, Y, False)
        cv.capsule((qx - 0.5, qy - 2.6), (qx + 3.0, qy - 2.2), 0.6, B, False)        # moustache
    # ---- front arm last
    cv.capsule(J['sh'], J['ef'], f['arm_r'], sleeve)
    cv.capsule(J['ef'], J['hf'], f['arm_r'] - 0.2, sleeve)
    cv.ellipse(J['hf'][0], J['hf'][1], f['fist_r'], f['fist_r'], Y)
    # ---- things in the hand
    ex = p['extra']
    h = J['hf']
    if ex == 'whip_coil':
        cv.ellipse(h[0] - 1.0, h[1] - 4.5, 3.0, 3.5, Y, False)
        cv.ellipse(h[0] - 1.0, h[1] - 4.5, 1.6, 2.0, 0, False)
    elif ex == 'whip_up':
        cv.capsule(h, (h[0] - 9, h[1] + 9), 0.7, Y, False)
        cv.capsule((h[0] - 9, h[1] + 9), (h[0] - 15, h[1] + 5), 0.7, Y, False)
    elif ex == 'speed':
        for dy, l in ((8, 10), (14, 14), (20, 9)):
            cv.capsule((hx - 9 - l, hy + dy - 8), (hx - 9, hy + dy - 8), 0.5, Y, False)
    elif ex == 'cane':            # a cane held upright, tip to the ground
        cv.capsule((h[0] + 0.5, h[1] + 3.0), (h[0] + 1.5, max(0.8, h[1] - 16.0)), 0.75, Y, False)
    elif ex == 'cane_up':
        cv.capsule((h[0], h[1] - 2.0), (h[0] - 5.0, h[1] + 13.0), 0.75, Y, False)
    elif ex == 'cane_out':
        cv.capsule((h[0] - 2.0, h[1]), (h[0] + 9.0, h[1] + 0.5), 0.75, Y, False)
    elif ex == 'staff':           # a tall staff planted on the ground
        cv.capsule((h[0] + 0.5, 0.8), (h[0] + 0.5, h[1] + 8.0), 0.8, Y, False)
        cv.ellipse(h[0] + 0.5, h[1] + 9.5, 1.8, 1.8, Y, False)
    elif ex == 'staff_up':
        cv.capsule((h[0] + 6.0, h[1] - 8.0), (h[0] - 8.0, h[1] + 10.0), 0.8, Y, False)
    elif ex == 'staff_out':
        cv.capsule((h[0] - 9.0, h[1] - 0.5), (h[0] + 8.0, h[1] + 0.5), 0.8, Y, False)
    elif ex == 'disc':            # a discus (or a ring) in the hand
        cv.ellipse(h[0] + 1.0, h[1] + 0.5, 3.4, 3.4, Y, False)
        cv.ellipse(h[0] + 1.0, h[1] + 0.5, 1.5, 1.5, B, False)
    elif ex == 'hat_off':         # top hat held out in the hand
        cv.poly([(h[0] - 1.0, h[1] + 2.5), (h[0] + 5.0, h[1] + 3.5), (h[0] + 6.0, h[1] - 3.0), (h[0] + 0.5, h[1] - 4.0)], B, False)
        cv.capsule((h[0] - 1.5, h[1] + 4.0), (h[0] - 0.0, h[1] - 6.0), 0.8, B, False)


# ------------------------------------------------------------------ poses
def boxer_poses():
    P = art.flick_poses()
    P['TAUNT'] = pose_base(lean=-4, lf=(16, -4), lb=(-14, -8), af=(75, 150), ab=(-20, 40))
    return P


def tall_poses():
    P = art.dusty_poses()
    P['TAUNT'] = pose_base(lean=-6, lf=(12, 0), lb=(-12, -6), af=(150, 205), ab=(15, 100))
    return P


def with_idle2(P):
    """a second idle pose: the same stance, sunk a little, arms relaxed"""
    a = dict(P['IDLE'])
    lf, lb = a['lf'], a['lb']
    a['lf'] = (lf[0] + 6, lf[1] - 7)
    a['lb'] = (lb[0] - 3, lb[1] - 8)
    a['lean'] = a['lean'] + 3
    a['af'] = (a['af'][0] - 6, a['af'][1] - 8)
    a['ab'] = (a['ab'][0] + 4, a['ab'][1] - 6)
    P['IDLE2'] = a
    return P


def flick():
    return with_idle2(boxer_poses())


def dusty():
    return with_idle2(tall_poses())


def nikos():
    P = boxer_poses()
    wide = dict(lf=(24, -2), lb=(-20, -8))
    P['IDLE'] = pose_base(lean=6, af=(30, 120), ab=(15, 110), **wide)
    P['SB_W'] = pose_base(lean=-10, af=(-60, 40), ab=(40, 140), **wide)
    P['SB_S'] = pose_base(lean=26, lf=(38, 4), lb=(-28, -18), af=(96, 110), ab=(-20, 50))
    # discus: wound up behind, then flung
    P['SP1_W'] = pose_base(lean=-14, lf=(20, -6), lb=(-24, -10), af=(-70, -30), ab=(60, 120), extra='disc')
    P['SP1_S'] = pose_base(lean=24, lf=(34, 2), lb=(-28, -16), af=(100, 96), ab=(-30, 30))
    # bull rush: head down, shoulder first
    P['SP2_W'] = pose_base(lean=30, lf=(60, -10), lb=(0, -60), af=(20, 120), ab=(30, 130))
    P['SP2_S'] = pose_base(lean=52, lf=(55, 15), lb=(-55, -50), af=(60, 150), ab=(-30, 20), extra='speed')
    P['TAUNT'] = pose_base(lean=-4, af=(120, 215), ab=(-120, -215), **wide)     # flexing both arms
    P['WIN'] = pose_base(lean=0, lf=(14, 4), lb=(-14, -4), af=(165, 178), ab=(-160, -178))
    return with_idle2(P)


def hana():
    P = boxer_poses()
    T = art.dusty_poses()
    guard = dict(af=(45, 140), ab=(10, 120))
    P['IDLE'] = pose_base(lean=4, lf=(26, -2), lb=(-18, -8), **guard)
    P['SB_W'] = pose_base(lean=-10, lf=(60, -30), lb=(-10, -10), **guard)
    P['SB_S'] = pose_base(lean=-14, lf=(88, 86), lb=(-8, -8), af=(30, 120), ab=(-40, 20))    # side kick
    P['CB_S'] = T['CB_S']
    P['JB'] = pose_base(lean=-12, lf=(110, 104), lb=(30, -50), af=(120, 150), ab=(-30, 60), air=True)
    # crane kick: knee up, then a flying kick
    P['SP1_W'] = pose_base(lean=0, lf=(95, -20), lb=(0, -4), af=(120, 170), ab=(-120, -170))
    P['SP1_S'] = pose_base(lean=-20, lf=(96, 94), lb=(40, -70), af=(60, 140), ab=(-60, 0), air=True)
    # swallow slide: low, leg first
    P['SP2_W'] = pose_base(lean=20, lf=(75, -15), lb=(10, -75), af=(40, 140), ab=(20, 130))
    P['SP2_S'] = pose_base(lean=-34, lf=(98, 95), lb=(70, -60), af=(-30, 40), ab=(-60, -10), extra='speed')
    P['TAUNT'] = pose_base(lean=38, lf=(6, 0), lb=(-6, 0), af=(40, 40), ab=(30, 30))          # a bow
    P['WIN'] = pose_base(lean=0, lf=(8, 2), lb=(-8, -2), af=(170, 178), ab=(20, 150))
    return with_idle2(P)


def amun():
    P = tall_poses()
    st = dict(lf=(14, 0), lb=(-12, -8))
    P['IDLE'] = pose_base(lean=2, af=(50, 110), ab=(15, 100), extra='staff', **st)
    P['WALK1'] = pose_base(lean=4, lf=(22, 6), lb=(-4, -14), af=(50, 110), ab=(15, 100), extra='staff')
    P['WALK2'] = pose_base(lean=4, lf=(2, -12), lb=(-18, -4), af=(50, 110), ab=(15, 100), extra='staff')
    P['SA_S'] = pose_base(lean=10, lf=(20, 2), lb=(-16, -10), af=(90, 90), ab=(10, 90), extra='staff_out')
    P['SA_W'] = pose_base(lean=0, af=(10, 110), ab=(15, 100), extra='staff_up', **st)
    # sun disc: both hands raised, then pushed out
    P['SP1_W'] = pose_base(lean=-8, af=(150, 180), ab=(-140, -175), extra='disc', **st)
    P['SP1_S'] = pose_base(lean=14, lf=(22, 2), lb=(-18, -12), af=(92, 92), ab=(70, 95))
    # cobra staff: a long straight thrust
    P['SP2_W'] = pose_base(lean=-10, lf=(10, -4), lb=(-18, -12), af=(-20, 80), ab=(20, 100), extra='staff_up')
    P['SP2_S'] = pose_base(lean=20, lf=(30, 2), lb=(-24, -14), af=(92, 90), ab=(40, 80), extra='staff_out')
    P['TAUNT'] = pose_base(lean=-4, af=(95, 250), ab=(80, 260), **st)                          # arms crossed
    P['WIN'] = pose_base(lean=0, lf=(10, 2), lb=(-12, -6), af=(50, 110), ab=(-150, -185), extra='staff')
    return with_idle2(P)


def sigrun():
    P = boxer_poses()
    wide = dict(lf=(22, -2), lb=(-20, -8))
    P['IDLE'] = pose_base(lean=6, af=(35, 130), ab=(20, 120), **wide)
    P['SB_W'] = pose_base(lean=-12, af=(160, 200), ab=(150, 190), **wide)                      # both fists high
    P['SB_S'] = pose_base(lean=30, lf=(36, 2), lb=(-26, -16), af=(80, 70), ab=(70, 60))        # hammer blow
    # glacier charge
    P['SP1_W'] = pose_base(lean=24, lf=(55, -10), lb=(-5, -55), af=(10, 150), ab=(20, 150))
    P['SP1_S'] = pose_base(lean=44, lf=(58, 18), lb=(-58, -55), af=(70, 160), ab=(60, 150), extra='speed')
    # geyser: a rising uppercut
    P['SP2_W'] = pose_base(lean=24, lf=(80, -10), lb=(10, -80), af=(-10, 100), ab=(40, 150))
    P['SP2_S'] = pose_base(lean=-8, lf=(8, -16), lb=(-22, -36), af=(172, 180), ab=(0, 70), air=True)
    P['TAUNT'] = pose_base(lean=-2, af=(-60, 60), ab=(60, -60), **wide)                        # fists on hips
    P['WIN'] = pose_base(lean=0, lf=(14, 4), lb=(-14, -4), af=(170, 178), ab=(-40, 40))
    return with_idle2(P)


def lupe():
    P = boxer_poses()
    guard = dict(af=(60, 130), ab=(-10, 100))
    P['IDLE'] = pose_base(lean=14, lf=(34, -8), lb=(-22, -14), **guard)                        # low, ready to spring
    P['SB_W'] = pose_base(lean=-6, lf=(70, -30), lb=(-10, -10), **guard)
    P['SB_S'] = pose_base(lean=-10, lf=(100, 98), lb=(-10, -12), af=(20, 120), ab=(-50, 10))   # high kick
    P['JA'] = pose_base(lean=40, lf=(60, 20), lb=(-20, -50), af=(120, 120), ab=(110, 110), air=True)
    # plancha: a flying body press
    P['SP1_W'] = pose_base(lean=18, lf=(80, -20), lb=(10, -80), af=(-30, -60), ab=(-40, -70))
    P['SP1_S'] = pose_base(lean=74, lf=(-10, -20), lb=(-40, -60), af=(150, 160), ab=(120, 140), air=True)
    # tope roll: tucked into a ball, low
    P['SP2_W'] = pose_base(lean=30, lf=(80, -20), lb=(10, -80), af=(40, 140), ab=(30, 130))
    P['SP2_S'] = pose_base(lean=80, lf=(120, -40), lb=(100, -60), af=(60, 150), ab=(40, 140), extra='speed')
    P['TAUNT'] = pose_base(lean=-6, lf=(18, 0), lb=(-16, -6), af=(172, 180), ab=(-60, 60))     # one finger to the sky
    P['WIN'] = pose_base(lean=0, lf=(18, 4), lb=(-18, -4), af=(160, 178), ab=(-160, -178))
    return with_idle2(P)


def ravi():
    P = boxer_poses()
    T = art.dusty_poses()
    guard = dict(af=(70, 170), ab=(30, 100))
    P['IDLE'] = pose_base(lean=2, lf=(18, -2), lb=(-14, -8), **guard)
    P['SB_W'] = T['SB_W']
    P['SB_S'] = pose_base(lean=-6, lf=(92, 90), lb=(-8, -10), af=(40, 130), ab=(-40, 20))
    # chakram: a flick of the wrist
    P['SP1_W'] = pose_base(lean=-8, lf=(16, -4), lb=(-16, -10), af=(-40, 120), ab=(30, 100), extra='disc')
    P['SP1_S'] = pose_base(lean=16, lf=(26, 0), lb=(-20, -12), af=(98, 92), ab=(-20, 40))
    # monsoon rise: a spinning rising kick
    P['SP2_W'] = pose_base(lean=14, lf=(80, -10), lb=(10, -80), af=(40, 140), ab=(20, 130))
    P['SP2_S'] = pose_base(lean=-16, lf=(150, 150), lb=(-10, -30), af=(60, 100), ab=(-80, -40), air=True)
    P['TAUNT'] = pose_base(lean=4, lf=(8, 0), lb=(-8, 0), af=(60, 165), ab=(55, 160))          # palms together
    P['WIN'] = pose_base(lean=0, lf=(10, 2), lb=(-10, -2), af=(60, 165), ab=(55, 160))
    return with_idle2(P)


def sable():
    P = tall_poses()
    st = dict(lf=(12, 0), lb=(-10, -6))
    P['IDLE'] = pose_base(lean=-2, af=(40, 80), ab=(-20, 60), extra='cane', **st)
    P['WALK1'] = pose_base(lean=0, lf=(22, 6), lb=(-4, -14), af=(40, 80), ab=(-20, 60), extra='cane')
    P['WALK2'] = pose_base(lean=0, lf=(2, -12), lb=(-18, -4), af=(40, 80), ab=(-20, 60), extra='cane')
    P['SA_W'] = pose_base(lean=0, af=(20, 110), ab=(-20, 60), extra='cane_up', **st)
    P['SA_S'] = pose_base(lean=10, lf=(20, 2), lb=(-16, -10), af=(90, 90), ab=(-20, 60), extra='cane_out')
    # top hat: doffed, then thrown
    P['SP1_W'] = pose_base(lean=-6, af=(120, 190), ab=(-20, 60), **st)
    P['SP1_S'] = pose_base(lean=16, lf=(24, 2), lb=(-18, -12), af=(96, 92), ab=(-30, 30), extra='bare')
    # cane flash
    P['SP2_W'] = pose_base(lean=-10, lf=(10, -4), lb=(-16, -10), af=(-30, 60), ab=(20, 100), extra='cane_up')
    P['SP2_S'] = pose_base(lean=22, lf=(30, 2), lb=(-24, -14), af=(92, 90), ab=(-40, 20), extra='cane_out')
    P['TAUNT'] = pose_base(lean=14, lf=(10, 0), lb=(-14, -4), af=(50, 120), ab=(-40, -10), extra='hat_off')   # a sweeping bow
    P['WIN'] = pose_base(lean=-2, lf=(10, 2), lb=(-12, -6), af=(40, 80), ab=(-150, -190), extra='cane')
    return with_idle2(P)


# ------------------------------------------------------------------ moves
def mv(su, ac, rc, dmg, box, fl, hs, bs, fr, fw, fs, vx=0, fx=0):
    return dict(su=su, ac=ac, rc=rc, dmg=dmg, box=box, fl=fl, hs=hs, bs=bs, fr=fr, fw=fw, fs=fs, vx=vx, fx=fx)


def normals(a, b, ca, cb, ja, jb):
    """six normal attacks from (startup, active, recovery, damage) each;
    hit boxes are measured from the drawn strike frames"""
    return [
        mv(*a, 'hand', LIGHT, 5, 3, 'SA_W', 'SA_W', 'SA_S'),
        mv(*b, 'auto', 0, 8, 5, 'SB_W', 'SB_W', 'SB_S'),
        mv(*ca, 'chand', LIGHT, 5, 3, 'CROUCH', 'CROUCH', 'CA_S', 0, 0x80),
        mv(*cb, 'sweep', LOW + KD, 0, 5, 'CROUCH', 'CROUCH', 'CB_S', 0, 0x80),
        mv(*ja, 'ja', HIGH + LIGHT + AIR, 5, 3, 'JUMP', 'JUMP', 'JA'),
        mv(*jb, 'jb', HIGH + AIR, 8, 5, 'JUMP', 'JUMP', 'JB'),
    ]


FAST = normals((2, 1, 2, 5), (4, 2, 5, 10), (2, 1, 3, 4), (4, 2, 7, 9), (2, 3, 0, 6), (2, 3, 0, 10))
SLOW = normals((3, 1, 3, 6), (6, 2, 7, 12), (3, 1, 4, 5), (6, 2, 9, 10), (3, 5, 0, 7), (3, 5, 0, 11))
MID = normals((3, 1, 2, 5), (5, 2, 6, 11), (3, 1, 3, 5), (5, 2, 8, 9), (2, 4, 0, 6), (3, 4, 0, 10))
HEAVY = normals((3, 2, 3, 7), (7, 2, 8, 14), (3, 1, 4, 6), (6, 2, 9, 11), (3, 4, 0, 8), (3, 5, 0, 12))
BOSS = normals((2, 2, 2, 7), (5, 2, 6, 13), (3, 1, 3, 6), (5, 2, 8, 11), (2, 4, 0, 8), (3, 5, 0, 12))

# projectile shapes
P_DISC, P_STAR, P_SUN, P_HAT = 0, 1, 2, 3


def proj(su, rc, dmg, speed, y, shape, frames=('SP1_S', 'SP1_W', 'SP1_S'), half=4, hs=9, bs=5):
    """a thrown thing: leaves the hand when the strike starts"""
    return mv(su, 2, rc, dmg, ('abs', 10, half, y - 4, y + 4), SPEC, hs, bs, *frames, vx=speed, fx=3 + (shape << 2))


def habits(near, mid, far, d1, d2):
    return [(d1, near), (d2, mid), (255, far)]


ROSTER = [
    dict(name='FLICK', country='AUSTRALIA', body=body(COMPACT), poses=flick,
         look=dict(sleeve=Y, legs=B, torso=B, belt=Y, head='hair'),
         walk=(8, 6), jump=(10, 8, 14, 17), hurt=30,
         moves=FAST + [
             mv(4, 6, 8, 14, ('abs', 2, 18, 12, 26), SPEC, 12, 5, 'SP1_W', 'SP1_W', 'SP1_S', 24),
             mv(2, 5, 12, 16, ('abs', 0, 14, 10, 42), SPEC + KD + INVSU + RISE, 0, 5, 'SP2_S', 'SP2_W', 'SP2_S')],
         specials=('BLADE RUN', 'TIN ROOF'),
         fin=('OUTBACK EXPRESS', DN, FW, 6, 20, 5),
         hab=habits([(50, SA), (35, CA), (30, SB), (35, CB), (14, SP2), (30, BACK), (30, BLOCK), (10, JBACK), (0, WAIT)],
                    [(70, FWD), (50, SP1), (30, JFWD), (20, SB), (30, WAIT), (24, BLOCK), (16, BACK), (0, FWD)],
                    [(140, FWD), (40, JFWD), (46, WAIT), (0, BACK)], 24, 56),
         aix=(24, SB, 48, SP1, SP2)),
    dict(name='DUSTY', country='USA', body=body(TALL), poses=dusty,
         look=dict(sleeve=B, legs=B, coat=True, head='hat'),
         walk=(5, 4), jump=(8, 7, 18, 18), hurt=34,
         moves=SLOW + [
             mv(9, 2, 14, 11, ('abs', 34, 56, 12, 30), SPEC, 10, 5, 'SP1_S', 'SP1_W', 'SP1_S', 0, 1),
             mv(9, 2, 15, 10, ('abs', 30, 50, 0, 6), SPEC + LOW + KD, 0, 5, 'SP2_S', 'SP2_W', 'SP2_S', 0, 0x82)],
         specials=('WHIP CRACK', 'ANKLE SNARE'),
         fin=('LAST ROUNDUP', BK, FW, 6, 20, 5),
         hab=habits([(40, SA), (40, CA), (30, SB), (30, CB), (50, BACK), (20, JBACK), (25, BLOCK), (0, WAIT)],
                    [(40, SP1), (24, SP2), (36, SB), (50, WAIT), (30, BACK), (26, CBLOCK), (0, FWD)],
                    [(120, FWD), (80, WAIT), (20, JFWD), (0, BACK)], 34, 58),
         aix=(34, SB, 56, SP1, SB)),
    dict(name='NIKOS', country='GREECE', body=body(COMPACT, torso_r=6.8, arm_r=2.8, leg_r=3.0, fist_r=3.3, torso=14.5),
         poses=nikos, look=dict(sleeve=Y, legs=Y, boots=B, torso=Y, sash=B, skirt=7.5, belt=Y, head='crest'),
         walk=(5, 4), jump=(8, 6, 15, 15), hurt=31,
         moves=HEAVY + [
             proj(7, 10, 9, 14, 20, P_DISC),
             mv(5, 7, 10, 15, ('abs', 2, 16, 8, 24), SPEC + KD, 0, 6, 'SP2_W', 'SP2_W', 'SP2_S', 20)],
         specials=('DISCUS', 'BULL RUSH'),
         fin=('OLYMPIC THROW', FW, BK, 6, 24, 4),
         hab=habits([(44, SA), (30, CA), (40, SB), (30, CB), (30, BLOCK), (30, BACK), (0, WAIT)],
                    [(50, SP2), (40, FWD), (30, SP1), (30, SB), (40, WAIT), (30, BLOCK), (0, FWD)],
                    [(90, SP1), (90, FWD), (40, WAIT), (0, JFWD)], 26, 60),
         aix=(26, SB, 60, SP2, SB)),
    dict(name='HANA', country='JAPAN', body=body(COMPACT, thigh=9.5, shin=10.5, torso=12.5, torso_r=5.0, arm_r=2.1, leg_r=2.3, fist_r=2.5, head=4.3),
         poses=hana, look=dict(sleeve=B, legs=B, baggy=1.0, torso=B, belt=Y, head='ponytail'),
         walk=(9, 7), jump=(11, 9, 14, 19), hurt=28,
         moves=FAST + [
             mv(3, 6, 9, 13, ('abs', 2, 24, 4, 24), SPEC + KD + RISE, 0, 5, 'CROUCH', 'SP1_W', 'SP1_S', 14),
             mv(3, 5, 9, 9, ('abs', 2, 26, 0, 6), SPEC + LOW + KD, 0, 5, 'CROUCH', 'SP2_W', 'SP2_S', 22, 0x80)],
         specials=('CRANE KICK', 'SWALLOW SLIDE'),
         fin=('SAKURA STORM', DN, BK, 6, 16, 6),
         hab=habits([(50, SA), (40, CA), (36, SB), (30, CB), (30, BACK), (30, BLOCK), (14, JBACK), (0, WAIT)],
                    [(60, FWD), (44, SP1), (40, SP2), (30, JFWD), (30, WAIT), (24, BLOCK), (0, FWD)],
                    [(140, FWD), (50, JFWD), (40, WAIT), (0, BACK)], 24, 54),
         aix=(24, SB, 50, SP2, SB)),
    dict(name='AMUN', country='EGYPT', body=body(TALL, torso_r=5.2), poses=amun,
         look=dict(sleeve=Y, legs=Y, boots=B, torso=Y, skirt=10, belt=Y, head='nemes'),
         walk=(6, 5), jump=(8, 7, 17, 17), hurt=35,
         moves=SLOW + [
             proj(8, 11, 10, 8, 22, P_SUN),
             mv(8, 2, 13, 11, ('abs', 14, 52, 14, 28), SPEC, 10, 5, 'SP2_S', 'SP2_W', 'SP2_S', 0, 5)],
         specials=('SUN DISC', 'COBRA STAFF'),
         fin=("PHARAOH'S CURSE", DN, DN, 6, 12, 6),
         hab=habits([(40, SA), (36, CA), (30, SB), (30, CB), (50, BACK), (30, BLOCK), (0, WAIT)],
                    [(50, SP2), (40, SP1), (30, SB), (50, WAIT), (30, BACK), (0, CBLOCK)],
                    [(110, SP1), (70, WAIT), (40, FWD), (0, BACK)], 30, 58),
         aix=(34, SB, 54, SP2, SB)),
    dict(name='SIGRUN', country='ICELAND', body=body(COMPACT, thigh=10.5, shin=11, torso=15, torso_r=6.6, arm_r=2.7, leg_r=2.9, fist_r=3.2),
         poses=sigrun, look=dict(sleeve=Y, legs=B, torso=B, cape=13, belt=Y, head='braids'),
         walk=(5, 4), jump=(7, 6, 16, 15), hurt=33,
         moves=HEAVY + [
             mv(6, 6, 11, 15, ('abs', 2, 18, 8, 28), SPEC + KD + INVSU, 0, 6, 'SP1_W', 'SP1_W', 'SP1_S', 18),
             mv(4, 5, 13, 18, ('abs', 0, 15, 10, 44), SPEC + KD + RISE, 0, 5, 'SP2_S', 'SP2_W', 'SP2_S')],
         specials=('GLACIER CHARGE', 'GEYSER'),
         fin=('RAGNAROK', FW, FW, 7, 18, 6),
         hab=habits([(44, SA), (30, CA), (44, SB), (30, CB), (16, SP2), (30, BLOCK), (26, BACK), (0, WAIT)],
                    [(60, SP1), (60, FWD), (30, SB), (40, WAIT), (36, BLOCK), (0, FWD)],
                    [(150, FWD), (50, WAIT), (0, JFWD)], 26, 58),
         aix=(26, SB, 56, SP1, SP2)),
    dict(name='LUPE', country='MEXICO', body=body(COMPACT, torso=13, torso_r=5.6, leg_r=2.6, arm_r=2.4, fist_r=2.8),
         poses=lupe, look=dict(sleeve=Y, legs=Y, boots=B, torso=B, cape=9, belt=Y, head='mask'),
         walk=(8, 6), jump=(12, 9, 15, 20), hurt=29,
         moves=MID + [
             mv(4, 6, 10, 14, ('abs', 0, 20, 2, 22), SPEC + KD + RISE + HIGH, 0, 5, 'CROUCH', 'SP1_W', 'SP1_S', 16),
             mv(3, 6, 9, 9, ('abs', 2, 16, 0, 12), SPEC + LOW + KD, 0, 5, 'CROUCH', 'SP2_W', 'SP2_S', 20, 0x80)],
         specials=('PLANCHA', 'TOPE ROLL'),
         fin=('GRAN FINAL', BK, BK, 6, 14, 7),
         hab=habits([(44, SA), (36, CA), (36, SB), (30, CB), (30, BACK), (30, BLOCK), (20, JBACK), (0, WAIT)],
                    [(50, SP1), (40, JFWD), (40, FWD), (36, SP2), (30, WAIT), (24, BLOCK), (0, FWD)],
                    [(110, FWD), (80, JFWD), (30, WAIT), (0, BACK)], 24, 56),
         aix=(24, SB, 50, SP2, SB)),
    dict(name='RAVI', country='INDIA', body=body(TALL, thigh=10.5, shin=11.5, torso=15, torso_r=4.6, arm_r=2.0, head=4.0),
         poses=ravi, look=dict(sleeve=Y, legs=B, baggy=1.3, torso=Y, sash=B, belt=B, head='turban'),
         walk=(7, 6), jump=(9, 8, 15, 18), hurt=31,
         moves=MID + [
             proj(5, 8, 7, 20, 18, P_STAR),
             mv(3, 5, 12, 14, ('abs', 0, 16, 8, 40), SPEC + KD + INVSU + RISE, 0, 5, 'SP2_S', 'SP2_W', 'SP2_S')],
         specials=('CHAKRAM', 'MONSOON RISE'),
         fin=("MONSOON'S END", FW, DN, 7, 16, 6),
         hab=habits([(44, SA), (36, CA), (34, SB), (30, CB), (14, SP2), (40, BACK), (30, BLOCK), (0, WAIT)],
                    [(60, SP1), (40, SB), (40, WAIT), (30, BACK), (30, FWD), (0, BLOCK)],
                    [(120, SP1), (60, WAIT), (40, FWD), (0, JFWD)], 28, 58),
         aix=(28, SB, 50, SA, SP2)),
    dict(name='SABLE', country='THE BIG TOP', body=body(TALL, torso_r=5.2, arm_r=2.2, leg_r=2.3, thigh=11.5, shin=12, farm=9, uarm=9), poses=sable,
         look=dict(sleeve=B, legs=B, coat=True, head='tophat'),
         walk=(7, 6), jump=(10, 8, 15, 18), hurt=35,
         moves=BOSS + [
             proj(6, 9, 11, 16, 22, P_HAT),
             mv(6, 3, 12, 13, ('abs', 12, 54, 12, 30), SPEC, 11, 5, 'SP2_S', 'SP2_W', 'SP2_S', 0, 5)],
         specials=('TOP HAT', 'CANE FLASH'),
         fin=('CURTAIN CALL', BK, DN, 7, 14, 7),
         hab=habits([(46, SA), (36, CA), (40, SB), (34, CB), (36, BACK), (36, BLOCK), (0, WAIT)],
                    [(60, SP2), (44, SP1), (36, SB), (30, FWD), (30, WAIT), (30, BLOCK), (0, BACK)],
                    [(110, SP1), (70, FWD), (40, WAIT), (0, JFWD)], 30, 58),
         aix=(32, SB, 56, SP2, SB)),
]


# ------------------------------------------------------------------ rendering
def render(f, p):
    cv = Canvas()
    J = solve(f['body'], p)
    b = dict(f['body']); b['look'] = f['look']
    draw(cv, b, J, p)
    return cv.px, J


def render_lying(f):
    p = pose_base(lean=0, lf=(4, 0), lb=(-4, 0), af=(170, 175), ab=(160, 170))
    up, _ = render(f, p)
    out = [[0] * CANVAS_W for _ in range(CANVAS_H)]
    for r in range(CANVAS_H):
        for c in range(CANVAS_W):
            x = c + 0.5 - OX
            y = (OY - r + 0.5) * ASPECT
            sy = -(x - 18)
            sx = y - 4.0
            sc = int(math.floor(sx + OX))
            sr = int(math.floor(OY + 0.5 - sy / ASPECT))
            if 0 <= sr < CANVAS_H and 0 <= sc < CANVAS_W:
                out[r][c] = up[sr][sc]
    return out


def frames_of(f):
    poses = f['poses']()
    out = []
    for name in FRAME_NAMES:
        if name == 'DOWN':
            px = render_lying(f)
            J = None
        else:
            px, J = render(f, poses[name])
        rows, ax, wb, below = crop(px)
        fr = dict(name=name, rows=rows, ax=ax, wb=wb, h=len(rows), below=below, hx=0, hy=0, fx=0, fy=0)
        if J:
            fr['hx'] = max(-60, min(60, int(round(J['hf'][0]))))
            fr['hy'] = max(0, min(60, int(round(J['hf'][1] / ASPECT))))
            fr['fx'] = int(round(J['ff'][0]))
            fr['fy'] = max(0, int(round(J['ff'][1] / ASPECT)))
        # how far the picture reaches forward of the feet origin
        fr['reach'] = max(c for row in rows for c, v in enumerate(row) if v) - ax
        out.append(fr)
    return out


def shifted(rows, wb):
    """the frame moved 2 pixels right, one byte wider"""
    return [[0, 0] + row + [0, 0] for row in rows]


def box_of(m, frames):
    """hit box (x0, x1, y0, y1) for a move"""
    b = m['box']
    if isinstance(b, tuple):
        return b[1:]
    fr = frames[FR[m['fs']]]
    reach = min(60, fr['reach'])
    if b == 'hand':
        return (4, reach, max(0, fr['hy'] - 6), fr['hy'] + 6)
    if b == 'chand':
        return (4, reach, 6, 14)
    if b == 'sweep':
        return (4, reach, 0, 5)
    if b == 'ja':
        return (0, max(16, reach - 2), 4, 20)
    if b == 'jb':
        return (0, max(18, reach - 2), 0, 16)
    # 'auto': a kick if the front foot is high and far forward, else a punch
    if fr['fx'] > fr['hx'] and fr['fy'] > 5:
        return (4, reach, max(0, fr['fy'] - 6), fr['fy'] + 7)
    return (4, reach, max(0, fr['hy'] - 7), fr['hy'] + 7)


def arc(n, peak):
    return [int(round(4 * peak * t * (n - t) / (n * n))) for t in range(1, n + 1)]


def block(idx, f, frames):
    """the loadable fighter block (bytes)"""
    HDR = 36
    data = bytearray(HDR)
    ptr = {}

    def add(key, bs):
        ptr[key] = len(data)
        data.extend(bs)

    jv = f['jump']
    add('jtab', arc(jv[2], jv[3]))
    mb = []
    for m in f['moves']:
        x0, x1, y0, y1 = box_of(m, frames)
        mb += [m['su'], m['ac'], m['rc'], m['dmg'], x0, x1, y0, y1, m['fl'] | (SPEC if len(mb) >= 96 else 0), m['hs'], m['bs'],
               FR[m['fr']], FR[m['fw']], FR[m['fs']], m['vx'] & 255, m['fx']]
    assert len(mb) == 128
    add('moves', mb)
    hb = []
    for lim, pairs in f['hab']:
        hb.append(lim)
        for w, a in pairs:
            hb += [w, a]
    add('hab', hb)
    add('name', f['name'].encode() + b'\0')
    add('finname', f['fin'][0].encode() + b'\0')
    add('aix', list(f['aix']))
    # frame directory, then the frames
    ptr['dir'] = len(data)
    data.extend(bytes(10 * len(frames)))
    for i, fr in enumerate(frames):
        d = ptr['dir'] + 10 * i
        plain = len(data)
        data.extend(pack(fr['rows']))
        sh = 0
        if fr['name'] in SHIFTED:
            sh = len(data)
            data.extend(pack(shifted(fr['rows'], fr['wb'])))
        data[d:d + 10] = bytes([plain & 255, plain >> 8, sh & 255, sh >> 8, fr['wb'], fr['h'], fr['ax'],
                                fr['below'], fr['hx'] & 255, fr['hy']])
    fin = f['fin']
    data[0:2] = b'RD'
    data[6] = len(frames)
    data[7] = idx
    data[8:14] = bytes([f['walk'][0], f['walk'][1], jv[0], jv[1], jv[2], f['hurt']])
    data[14:19] = bytes([fin[1], fin[2], fin[3], fin[4], fin[5]])
    for i, key in enumerate(('jtab', 'moves', 'dir', 'hab', 'name', 'finname', 'aix')):
        data[20 + 2 * i] = ptr[key] & 255
        data[21 + 2 * i] = ptr[key] >> 8
    n = len(data)
    data[2] = n & 255; data[3] = n >> 8
    s = sum(data[6:]) & 0xFFFF
    data[4] = s & 255; data[5] = s >> 8
    return bytes(data)


def build_all():
    out = []
    for i, f in enumerate(ROSTER):
        fr = frames_of(f)
        out.append((f, fr, block(i, f, fr)))
    return out


PAL = {0: (40, 160, 40), 1: (240, 230, 70), 2: (40, 60, 220), 3: (220, 40, 40)}


def sheet(frames, fn, colour=2):
    from PIL import Image
    scale = 4
    cw, ch = 56, 44
    per = 8
    rows_n = (len(frames) + per - 1) // per
    img = Image.new('RGB', (cw * scale * per, int(ch * ASPECT * scale) * rows_n), PAL[0])
    for i, fr in enumerate(frames):
        gx = (i % per) * cw * scale
        gy = (i // per) * int(ch * ASPECT * scale)
        for r, row in enumerate(fr['rows']):
            for c, v in enumerate(row):
                if not v:
                    continue
                col = PAL[colour if v == 2 else v]
                x0 = gx + (c + 24 - fr['ax']) * scale
                y0 = gy + int((ch - fr['h'] + r - 2 + fr['below']) * ASPECT * scale)
                for yy in range(int(ASPECT * scale)):
                    for xx in range(scale):
                        if 0 <= x0 + xx < img.width and 0 <= y0 + yy < img.height:
                            img.putpixel((x0 + xx, y0 + yy), col)
    img.save(fn)




def montage(fn, names=('IDLE', 'IDLE2', 'WALK1', 'SA_S', 'SB_S', 'CB_S', 'JB', 'SP1_W', 'SP1_S', 'SP2_W', 'SP2_S', 'TAUNT', 'WIN', 'HIT'), scale=3):
    from PIL import Image
    cw, ch = 46, 46
    allf = build_all()
    img = Image.new('RGB', (cw * scale * len(names), int(ch * ASPECT * scale) * len(allf)), PAL[0])
    for j, (f, frames, blk) in enumerate(allf):
        for i, n in enumerate(names):
            fr = frames[FR[n]]
            gx = i * cw * scale
            gy = j * int(ch * ASPECT * scale)
            for r, row in enumerate(fr['rows']):
                for c, v in enumerate(row):
                    if not v:
                        continue
                    col = PAL[(2 if j % 2 == 0 else 3) if v == 2 else v]
                    x0 = gx + (c + 18 - fr['ax']) * scale
                    y0 = gy + int((ch - fr['h'] + r - 2 + fr['below']) * ASPECT * scale)
                    for yy in range(int(ASPECT * scale) + 1):
                        for xx in range(scale):
                            if 0 <= x0 + xx < img.width and 0 <= y0 + yy < img.height:
                                img.putpixel((x0 + xx, y0 + yy), col)
    img.save(fn)


def _main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else None
    for i, (f, fr, blk) in enumerate(build_all()):
        print('%-7s %5d bytes  %s' % (f['name'], len(blk), 'TOO BIG' if len(blk) > 10240 else ''))
        if outdir:
            os.makedirs(outdir, exist_ok=True)
            sheet(fr, os.path.join(outdir, 'fighter_%d_%s.png' % (i + 1, f['name'].lower())), 2 if i % 2 == 0 else 3)

    if outdir:
        montage(os.path.join(outdir, 'roster.png'))


if __name__ == '__main__':
    _main()
