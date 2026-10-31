# Human model: skeleton FK, keyframes (rising, tai chi, settling), sphere list,
# shaded 2bpp sphere sprites for VZ mode(1) (CSS0: 0 green,1 yellow,2 blue,3 red)
import math
import numpy as np

# ------------------------------------------------------------------ skeleton
J = ['pelvis','chest','neck','head','lsho','lelb','lhand','rsho','relb','rhand','lhip','lknee','lfoot','rhip','rknee','rfoot']
JI = {n:i for i,n in enumerate(J)}

def rx(a):
    c,s = math.cos(a), math.sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def ry(a):
    c,s = math.cos(a), math.sin(a); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def rz(a):
    c,s = math.cos(a), math.sin(a); return np.array([[c,-s,0],[s,c,0],[0,0,1]])
D = math.radians

BASE = dict(root_y=0, root_x=0, root_z=0, yaw=0, pitch=0, roll=0, lean=0, twist=0, head_yaw=0, head_pitch=0,
            lsf=0, lsa=8, leb=10, rsf=0, rsa=8, reb=10,          # shoulder flex (forward), abduct, elbow bend
            lhf=0, lha=4, lkb=4, rhf=0, rha=4, rkb=4,           # hip flex, abduct, knee bend
            lsr=0, rsr=0)                                        # shoulder inward rotation of forearm plane

def fk(p):
    q = dict(BASE); q.update(p)
    R0 = ry(D(q['yaw'])) @ rx(D(q['pitch'])) @ rz(D(q['roll']))
    root = np.array([q['root_x'], q['root_y'], q['root_z']], float)
    pts = {}
    pts['pelvis'] = root
    Rt = R0 @ ry(D(q['twist'])) @ rx(D(q['lean']))
    pts['chest'] = root + Rt @ [0, 14, 0]
    pts['neck'] = root + Rt @ [0, 23, 0]
    Rh = Rt @ ry(D(q['head_yaw'])) @ rx(D(q['head_pitch']))
    pts['head'] = pts['neck'] + Rh @ [0, 6.5, 0.6]
    for side, sx in (('l', 1), ('r', -1)):
        sho = root + Rt @ [8*sx, 21, 0]
        pts[side+'sho'] = sho
        # upper arm hangs down (-y); flex rotates forward (+z) about x; abduct rotates outward about z
        Ra = Rt @ rz(D(q[side+'sa'])*sx) @ rx(-D(q[side+'sf']))
        elb = sho + Ra @ [0, -11, 0]
        pts[side+'elb'] = elb
        Rf = Ra @ ry(D(q[side+'sr'])*sx) @ rx(-D(q[side+'eb']))
        pts[side+'hand'] = elb + Rf @ [0, -10, 0]
        hip = root + R0 @ [4*sx, -2, 0]
        pts[side+'hip'] = hip
        Rl = R0 @ rz(D(q[side+'ha'])*sx) @ rx(-D(q[side+'hf']))
        knee = hip + Rl @ [0, -17, 0]
        pts[side+'knee'] = knee
        Rk = Rl @ rx(D(q[side+'kb']))
        pts[side+'foot'] = knee + Rk @ [0, -17, 0]
    return np.array([pts[n] for n in J])

# standing: feet at y=-36 when legs straight -> pelvis at 0
def ground_fix(p, P):
    # keep the lowest foot on the ground (y=-36) unless explicitly airborne
    return P

POSES = {
 'lying':  dict(root_y=-31, pitch=-90, lsa=14, rsa=14, leb=8, reb=8, lha=3, rha=3, lkb=6, rkb=6, head_pitch=0),
 'situp':  dict(root_y=-31, pitch=0, lean=10, lhf=88, rhf=88, lkb=10, rkb=10, lsf=30, rsf=30, leb=30, reb=30, lsa=10, rsa=10),
 'kneel':  dict(root_y=-25, lhf=70, rhf=10, lkb=95, rkb=150, lean=15, lsf=20, rsf=20, leb=40, reb=40),
 'rise':   dict(root_y=-8, lhf=40, rhf=40, lkb=70, rkb=70, lean=20, lsf=10, rsf=10, leb=30, reb=30),
 'wuji':   dict(root_y=-1, lkb=6, rkb=6, lhf=3, rhf=3, lsa=10, rsa=10, leb=12, reb=12),
 'commence': dict(root_y=-1, lkb=6, rkb=6, lhf=3, rhf=3, lsf=80, rsf=80, lsa=14, rsa=14, leb=20, reb=20),
 'sink':   dict(root_y=-5, lkb=30, rkb=30, lhf=15, rhf=15, lsf=35, rsf=35, lsa=14, rsa=14, leb=55, reb=55),
 'wardoff': dict(root_y=-6, yaw=-10, twist=-25, lhf=35, lkb=40, rhf=-10, rkb=20, lha=8, rha=10,
                 lsf=70, lsa=30, leb=90, lsr=60, rsf=15, rsa=12, reb=30, root_z=3),
 'rollback': dict(root_y=-7, yaw=-10, twist=30, lhf=25, lkb=15, rhf=10, rkb=45, lha=8, rha=10,
                  lsf=55, lsa=25, leb=60, rsf=40, rsa=20, reb=70, root_z=-2),
 'press':  dict(root_y=-6, yaw=-10, twist=-10, lhf=35, lkb=40, rhf=-10, rkb=20, lha=8, rha=10,
                lsf=75, lsa=20, leb=80, lsr=50, rsf=75, rsa=10, reb=80, rsr=50, root_z=3),
 'push':   dict(root_y=-6, yaw=-10, lhf=35, lkb=40, rhf=-10, rkb=20, lha=8, rha=10,
                lsf=80, lsa=14, leb=25, rsf=80, rsa=14, reb=25, root_z=4),
 'whip':   dict(root_y=-9, yaw=-40, twist=-35, lhf=30, lkb=45, rhf=5, rkb=40, lha=22, rha=22,
                lsf=60, lsa=40, leb=35, rsf=30, rsa=80, reb=10, root_x=-2),
 'cloudA': dict(root_y=-8, twist=35, lhf=12, rhf=12, lkb=35, rkb=35, lha=16, rha=16,
                lsf=40, lsa=10, leb=60, rsf=85, rsa=25, reb=70, root_x=-3),
 'cloudB': dict(root_y=-8, twist=-35, lhf=12, rhf=12, lkb=35, rkb=35, lha=16, rha=16,
                lsf=85, lsa=25, leb=70, rsf=40, rsa=10, reb=60, root_x=3),
 'rooster': dict(root_y=-3, lhf=85, lkb=95, rhf=4, rkb=8, rha=3,
                 lsf=150, lsa=10, leb=60, rsf=10, rsa=20, reb=25),
 'closing': dict(root_y=-3, lkb=12, rkb=12, lhf=6, rhf=6, lsf=50, rsf=50, lsa=-10, rsa=-10, leb=70, reb=70),
 'seated': dict(root_y=-30, lhf=80, rhf=80, lha=40, rha=40, lkb=150, rkb=150, lean=5,
                lsf=30, rsf=30, lsa=12, rsa=12, leb=70, reb=70, head_pitch=12),
}

def lerp_pose(a, b, f):
    pa = dict(BASE); pa.update(POSES[a]); pb = dict(BASE); pb.update(POSES[b])
    f = f*f*(3-2*f)
    return {k: pa[k] + (pb[k]-pa[k])*f for k in pa}

def sequence(steps, frames_per_key=32):
    """steps: list of (pose, hold_frames, trans_frames)"""
    keys = []
    timeline = []
    for i in range(len(steps)-1):
        a, hold, trans = steps[i]
        b = steps[i+1][0]
        timeline += [(a, a, 0)] * hold + [(a, b, k/trans) for k in range(trans)]
    timeline += [(steps[-1][0], steps[-1][0], 0)] * steps[-1][1]
    for t in range(0, len(timeline), frames_per_key):
        a, b, f = timeline[t]
        keys.append(fk(lerp_pose(a, b, f)))
    return keys

# segment 0: lying (1 key)
LYING = [fk(dict(BASE, **POSES['lying']))]
# segment 1: rising (256 frames)
RISING = sequence([('lying', 16, 64), ('situp', 8, 64), ('kneel', 8, 48), ('rise', 0, 48), ('wuji', 32, 0)])
# segment 2: tai chi (2560 frames)
TAICHI = sequence([('wuji', 96, 160), ('commence', 64, 160), ('sink', 32, 160), ('wardoff', 64, 150),
                   ('rollback', 48, 150), ('press', 40, 120), ('push', 64, 160), ('whip', 96, 170),
                   ('cloudA', 24, 140), ('cloudB', 24, 140), ('rooster', 96, 170), ('closing', 96, 0)])
# segment 3: settle into stillness (wuji->seated, 320 frames)
SETTLE = sequence([('closing', 32, 96), ('kneel', 16, 96), ('seated', 96, 0)])

# --------------------------------------------------------------- spheres
# (jointA, jointB, t 0..255, radius*16 units)
SPH = [
 ('pelvis','pelvis',0, 100), ('pelvis','chest',100, 94), ('pelvis','chest',190, 100), ('chest','chest',0, 108), ('chest','neck',130, 92),
 ('neck','neck',0, 44), ('head','head',0, 90),
 ('lsho','lsho',0, 54), ('lsho','lelb',90, 48), ('lsho','lelb',180, 44), ('lelb','lelb',0, 40), ('lelb','lhand',90, 38), ('lelb','lhand',180, 36), ('lhand','lhand',0, 34),
 ('rsho','rsho',0, 54), ('rsho','relb',90, 48), ('rsho','relb',180, 44), ('relb','relb',0, 40), ('relb','rhand',90, 38), ('relb','rhand',180, 36), ('rhand','rhand',0, 34),
 ('lhip','lhip',0, 70), ('lhip','lknee',70, 66), ('lhip','lknee',150, 60), ('lknee','lknee',0, 52), ('lknee','lfoot',70, 48), ('lknee','lfoot',150, 44), ('lfoot','lfoot',0, 40),
 ('rhip','rhip',0, 70), ('rhip','rknee',70, 66), ('rhip','rknee',150, 60), ('rknee','rknee',0, 52), ('rknee','rfoot',70, 48), ('rknee','rfoot',150, 44), ('rfoot','rfoot',0, 40),
]
HEAD_SPHERE = 6            # index of head sphere in SPH

# face features in the lying frame, relative to head centre, fine units (1/4 body unit)
# a = across (toward person's left), b = along body axis toward top of head, c = face normal (up)
# kind: 0 shaded sphere, 1 solid red, 2 eye (closed red slit / open yellow+blue), 3 hair (solid red big)
FEAT = [
 (0, 6, -7, 92, 3),        # hair cap: back/top of head
 ( 20, 0, 1, 18, 0), (-20, 0, 1, 18, 0),     # ears
 ( 8, 3, 18, 13, 2), (-8, 3, 18, 13, 2),     # eyes
 ( 8, 9, 17, 9, 1), (-8, 9, 17, 9, 1),       # brows
 (0, -2, 22, 12, 0),       # nose
 (0, -10, 17, 11, 1),      # mouth
]

def to_bytes_keys(keys):
    out = []
    for P in keys:
        for x, y, z in P:
            for v in (x, y, z):
                iv = int(round(v)); assert -128 <= iv <= 127, P
                out.append(iv & 255)
    return out

# --------------------------------------------------------------- sprites
L = np.array([-0.42, 0.48, 0.77]); L /= np.linalg.norm(L)   # light from upper-left-front
BAYER = np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])/16.0

def sphere_pixels(r):
    W = int(round(1.5*r))
    inside = {}
    for dy in range(-r, r+1):
        for dx in range(-W, W+1):
            nx = dx/(1.5*r+0.5); ny = dy/(r+0.5)
            if nx*nx + ny*ny <= 1.0: inside[(dx, dy)] = (nx, ny)
    pix = {}
    for (dx, dy), (nx, ny) in inside.items():
        nz = math.sqrt(max(0, 1-nx*nx-ny*ny))
        I = nx*L[0] - ny*L[1] + nz*L[2]          # screen y is down
        th = (BAYER[dy % 4][dx % 4] - 0.5)*0.22
        edge = any((dx+ax, dy+ay) not in inside for ax, ay in ((1,0),(-1,0),(0,1),(0,-1)))
        if r <= 1: c = 1 if (dx, dy) == (-1, -1) else 0
        elif edge and I < 0.55: c = 3
        elif I + th > 0.80: c = 1
        elif I + th > 0.12: c = 0
        else: c = 3
        pix[(dx, dy)] = c
    return W, pix

def make_template(r, s, solid=None):
    W, pix = sphere_pixels(r)
    rows = []
    width_px = s + 2*W + 1
    nbytes = (width_px + 3)//4
    for dy in range(-r, r+1):
        masks = [0xFF]*nbytes; datas = [0]*nbytes
        for dx in range(-W, W+1):
            if (dx, dy) in pix:
                px = s + dx + W; b = px >> 2; sh = 6 - 2*(px & 3)
                masks[b] &= ~(3 << sh) & 0xFF
                datas[b] |= (pix[(dx, dy)] << sh)
        # trim
        lead = 0
        while lead < nbytes and masks[lead] == 0xFF: lead += 1
        tail = nbytes
        while tail > lead and masks[tail-1] == 0xFF: tail -= 1
        row = [lead, tail-lead]
        for b in range(lead, tail): row += [masks[b], datas[b]]
        rows.append(row)
    return W, rows

def templates(maxr=9):
    ptrs = []; blob = []
    for r in range(1, maxr+1):
        for s in range(4):
            W, rows = make_template(r, s)
            ptrs.append(len(blob))
            blob += [W, 2*r+1]
            for row in rows: blob += row
    return ptrs, blob

if __name__ == '__main__':
    p, b = templates()
    print('template bytes', len(b), 'keys', len(LYING), len(RISING), len(TAICHI), len(SETTLE))
    allk = LYING + RISING + TAICHI + SETTLE
    a = np.array(allk); print('range', a.min(), a.max())
    for r in (3, 6, 9):
        W, pix = sphere_pixels(r)
        for dy in range(-r, r+1):
            print(''.join('.gyBr'[pix[(dx,dy)]+1] if (dx,dy) in pix else ' ' for dx in range(-W, W+1)).replace('.',' '))
