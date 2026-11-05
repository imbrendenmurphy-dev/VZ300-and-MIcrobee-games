"""uB-TYPE sprites: images at 4x the VZ sprite grid (so hit boxes and anchors
are unchanged), packed as half-cell pre-shifted PCG columns.

Each sprite has two horizontal variants (x offset 0 and 4 pixels: one VZ
pixel). Every column of a variant holds H data bytes then H AND-mask bytes;
the engine fills the lines above/below the sprite inside a cell itself.
Per cell an ink colour is precomputed (FFh = nothing to draw)."""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'vz'))
import art as VA
import mbart as A

PADT, PADB = 12, 16


def epx(img):
    h, w = img.shape
    out = np.zeros((h * 2, w * 2), img.dtype)
    p = np.pad(img, 1, mode='constant')
    for y in range(h):
        for x in range(w):
            P = p[y + 1, x + 1]
            Au, Cl, Dr, Bd = p[y, x + 1], p[y + 1, x], p[y + 1, x + 2], p[y + 2, x + 1]
            o1 = o2 = o3 = o4 = P
            if Cl == Au and Cl != Dr and Au != Bd:
                o1 = Au
            if Au == Dr and Au != Cl and Dr != Bd:
                o2 = Dr
            if Bd == Cl and Bd != Au and Cl != Dr:
                o3 = Cl
            if Dr == Bd and Dr != Au and Bd != Cl:
                o4 = Bd
            out[2 * y, 2 * x], out[2 * y, 2 * x + 1], out[2 * y + 1, 2 * x], out[2 * y + 1, 2 * x + 1] = o1, o2, o3, o4
    return out


# VZ logical colour -> Premium colour, per sprite family (prototype mapping)
CMAP = {
    'ship': {1: A.WHITE, 2: A.BRED, 3: A.BCYAN}, 'exh': {1: A.YELLOW, 2: A.BRED, 3: A.WHITE},
    'pod': {1: A.BCYAN, 2: A.WHITE, 3: A.BBLUE}, 'shot': {1: A.WHITE, 2: A.YELLOW, 3: A.BCYAN},
    'sprd': {2: A.BRED}, 'lance': {1: A.BCYAN}, 'cross': {3: A.YELLOW},
    'beam': {1: A.WHITE, 2: A.BCYAN, 3: A.YELLOW}, 'ebul': {1: A.WHITE, 2: A.BMAGENTA},
    'swim': {1: A.YELLOW, 2: A.BRED, 3: A.BGREEN}, 'dart': {1: A.WHITE, 2: A.BMAGENTA, 3: A.BRED},
    'tur': {1: A.YELLOW, 2: A.BRED, 3: A.GREY}, 'hop': {1: A.WHITE, 2: A.BRED, 3: A.BGREEN},
    'carr': {1: A.WHITE, 2: A.BCYAN, 3: A.GREY}, 'spin': {1: A.WHITE, 2: A.BMAGENTA},
    'guns': {1: A.WHITE, 2: A.BRED, 3: A.GREY}, 'spore': {1: A.WHITE, 2: A.BGREEN, 3: A.YELLOW},
    'frag': {2: A.BGREEN}, 'capw0': {1: A.WHITE, 2: A.BRED}, 'capw1': {1: A.WHITE, 3: A.BBLUE},
    'capw2': {1: A.YELLOW, 2: A.WHITE}, 'caps': {2: A.WHITE, 3: A.BGREEN}, 'caph': {2: A.BMAGENTA, 3: A.WHITE},
    'sat': {1: A.BCYAN, 2: A.WHITE}, 'expl': {1: A.WHITE, 2: A.YELLOW}, 'borb': {1: A.WHITE, 2: A.BMAGENTA},
    'life': {1: A.WHITE, 3: A.BCYAN}, 'core': {1: A.WHITE, 2: A.BRED, 3: A.YELLOW},
    'bgun': {1: A.WHITE, 2: A.BRED, 3: A.GREY}, 'hatch': {1: A.WHITE, 2: A.BRED, 3: A.GREY},
    'serp': {1: A.WHITE, 2: A.BRED, 3: A.BGREEN},
}


def cmap_for(name):
    for k in sorted(CMAP, key=len, reverse=True):
        if name.startswith(k):
            return CMAP[k]
    return {1: A.WHITE, 2: A.YELLOW, 3: A.BCYAN}


def image(name):
    rows = VA.SPR[name]
    w = max(len(r) for r in rows)
    small = np.array([[0 if ch == '.' else int(ch) for ch in r.ljust(w, '.')] for r in rows], np.uint8)
    big = epx(epx(small))
    cm = cmap_for(name)
    col = np.vectorize(lambda v: cm.get(int(v), A.WHITE) if v else 0)(big).astype(np.uint8)
    return col                       # H x W Premium colours (0 = transparent)


def variants(col, bits=None):
    H, W = col.shape
    on = col > 0
    lit = bits if bits is not None else on
    # outline mask: dilate by one pixel
    m = on.copy()
    m[1:, :] |= on[:-1, :]
    m[:-1, :] |= on[1:, :]
    m[:, 1:] |= on[:, :-1]
    m[:, :-1] |= on[:, 1:]
    out = []
    for s in range(2):
        Wc = ((W + 4 * s + 7) // 8)
        cv = np.zeros((H, Wc * 8), np.uint8)
        cb = np.zeros((H, Wc * 8), bool)
        cm = np.zeros((H, Wc * 8), bool)
        cv[:, 4 * s:4 * s + W] = col
        cb[:, 4 * s:4 * s + W] = lit
        cm[:, 4 * s:4 * s + W] = m
        if s == 1:
            cm[:, 3] |= on[:, 0]         # the outline left of the sprite fits here
        cols = []
        for j in range(Wc):
            d = np.zeros(H, np.uint8)
            mk = np.full(H, 255, np.uint8)
            for y in range(H):
                b = 0
                mm = 0
                for x in range(8):
                    if cb[y, j * 8 + x]:
                        b |= 0x80 >> x
                    if cm[y, j * 8 + x]:
                        mm |= 0x80 >> x
                d[y] = b
                mk[y] = (~mm) & 255
            cols.append((bytes(d), bytes(mk)))
        hcm = (12 + H + 15) // 16
        ctab = bytearray()
        for j in range(Wc):
            for yo in range(4):
                for k in range(hcm):
                    l0 = 16 * k - 4 * yo
                    seg = np.where(cb, cv, 0)[max(0, l0):max(0, min(H, l0 + 16)), j * 8:j * 8 + 8]
                    segm = cm[max(0, l0):max(0, min(H, l0 + 16)), j * 8:j * 8 + 8]
                    if seg.size == 0 or not segm.any():
                        ctab.append(0xFF)
                        continue
                    vals, cnt = np.unique(seg[seg > 0], return_counts=True)
                    ctab.append(int(vals[np.argmax(cnt)]) if len(vals) else A.WHITE)
        out.append(dict(W=Wc, cols=cols, ctab=bytes(ctab), hcm=hcm))
    return out, H


def build_all():
    import mbsprart
    art = mbsprart.build()
    lib = {}
    for name in VA.SPR:
        c = art[name]
        v, H = variants(c.col, c.bits())
        lib[name] = dict(v=v, H=H, img=c.col)
    return lib


def pack_set(lib, names, used, base, limit):
    """descriptors (16 bytes per sprite id) then data; absolute pointers"""
    n = len(names)
    blob = bytearray(16 * n)
    cnt = 0
    for idx, name in enumerate(names):
        if name not in used:
            continue
        e = lib[name]
        H = e['H']
        ptrs = []
        for s in range(2):
            v = e['v'][s]
            p_data = base + len(blob)
            for (d, mk) in v['cols']:
                blob += d + mk
            p_col = base + len(blob)
            blob += v['ctab']
            ptrs.append((p_data, p_col, v['W']))
        hcm = e['v'][0]['hcm']
        nk = (12 + H + 15) // 16
        desc = bytes([ptrs[0][2]]) + ptrs[0][0].to_bytes(2, 'little') + ptrs[0][1].to_bytes(2, 'little') + \
            bytes([ptrs[1][2]]) + ptrs[1][0].to_bytes(2, 'little') + ptrs[1][1].to_bytes(2, 'little') + \
            bytes([H, (2 * H) & 255, hcm, 4 * hcm, nk, 0])
        blob[idx * 16:idx * 16 + 16] = desc
        cnt += 1
    assert base + len(blob) <= limit, 'sprite set too big: %d' % len(blob)
    return dict(blob=bytes(blob), n=cnt)
