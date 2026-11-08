"""Pack scaled sprite sets for the Z80 blitter.
Record (per object, frame, level, phase): db wbytes, h, ax, ay ; then h rows of wbytes (mask, data) pairs.
mask has 11 where the background shows through. Phase 1 is shifted right by 2 pixels.
ax/ay: anchor in pixels from the record's left edge / top row."""
import sys
sys.path.insert(0, 'tools')
def to_bytes(g, ax, ay, shift):
    h = len(g); w = len(g[0])
    W = w + shift
    wb = (W + 3) // 4
    out = bytearray([wb, h, ax + shift, ay])
    for r in g:
        row = [-1] * shift + r + [-1] * (wb * 4 - W)
        for b in range(wb):
            m = d = 0
            for i in range(4):
                c = row[b * 4 + i]
                sh = 6 - 2 * i
                if c < 0: m |= 3 << sh
                else: d |= c << sh
            out += bytes([m, d])
    return bytes(out)
def trim(g, ax, ay):
    from draw import crop
    cg, dx, dy = crop(g)
    return cg, ax - dx, ay - dy
def pack_set(frames_levels):
    """frames_levels[f][k] = (grid, ax, ay) -> (bytes, offsets[f][k][phase])"""
    blob = bytearray(); offs = []
    for fl in frames_levels:
        of = []
        for (g, ax, ay) in fl:
            g, ax, ay = trim(g, ax, ay)
            p = []
            for ph in (0, 2):
                p.append(len(blob)); blob += to_bytes(g, ax, ay, ph)
            of.append(p)
        offs.append(of)
    return bytes(blob), offs
if __name__ == '__main__':
    import creatures as CR
    from geom import LEV_S, NLEV
    tot = 0
    for n, (fn, nf, w, h) in CR.OBJECTS.items():
        fl = []
        for f in range(nf):
            lv = []
            for k in range(NLEV):
                g = CR.render(n, f, LEV_S[k]); lv.append((g, len(g[0]) // 2, len(g) - 1))
            fl.append(lv)
        b, o = pack_set(fl)
        print('%-9s frames %d  bytes %5d' % (n, nf, len(b))); tot += len(b)
    print('total', tot)
