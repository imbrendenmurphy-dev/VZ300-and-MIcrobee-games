"""Packs a program into a self-unpacking MZT, so it loads from tape (UniCMT) in much less time.

The packed MZT loads above the program, then a small unpacker runs and rebuilds the program at its
own address, byte for byte, and jumps to it. Nothing about the program itself changes.

Packed format, a stream of tokens:
  00-3F               literal run: (c+1) bytes follow, copied as they are
  40-7F  o            short match: (c&3F)+3 bytes copied from o+1 bytes back (1-256)
  80-FF  lo hi        long match: (c&7F)+3 bytes copied from (hi*256+lo) bytes back; 0 back = end
The unpacker works forward, in place: the packed data sits at the top, far enough above the
program's end that the output never runs over packed bytes it hasn't read yet (worked out below).
"""
from zasm import assemble

def _matches(data, i, heads, prev, depth):
    """Longest match at i with a distance <= 256, and longest at any distance."""
    n = len(data); best_s = (0, 0); best_l = (0, 0)
    lim = min(130, n - i)
    if lim < 3: return best_s, best_l
    j = heads.get(data[i:i+3]); k = 0
    while j is not None and k < depth:
        d = i - j
        if d > 65535: break
        L = 0
        while L < lim and data[j+L] == data[i+L]: L += 1
        if L > best_l[0]: best_l = (L, d)
        if d <= 256 and L > best_s[0]: best_s = (min(L, 66), d)
        if L == lim and best_s[0] == min(lim, 66): break
        j = prev[j]; k += 1
    return best_s, best_l

def pack(data, depth=256):
    data = bytes(data); n = len(data)
    heads = {}; prev = [None]*n; M = []
    for i in range(n):
        M.append(_matches(data, i, heads, prev, depth))
        key = data[i:i+3]
        if len(key) == 3:
            prev[i] = heads.get(key); heads[key] = i
    INF = 1 << 30
    cost = [INF]*(n+1); how = [None]*(n+1); cost[n] = 0
    for i in range(n-1, -1, -1):                # cheapest way to code data[i:]
        b = INF; h = None
        for L in range(1, min(64, n-i)+1):     # a literal run of L bytes
            c = 1 + L + cost[i+L]
            if c < b: b = c; h = ('lit', L)
        (ls, ds), (ll, dl) = M[i]
        for L in range(3, ls+1):
            c = 2 + cost[i+L]
            if c < b: b = c; h = ('short', L, ds)
        for L in range(3, ll+1):
            c = 3 + cost[i+L]
            if c < b: b = c; h = ('long', L, dl)
        cost[i] = b; how[i] = h
    out = bytearray(); marks = []              # (packed bytes read, output bytes written) after each token
    i = 0
    while i < n:
        h = how[i]
        if h[0] == 'lit':
            out.append(h[1]-1); out += data[i:i+h[1]]; i += h[1]
        elif h[0] == 'short':
            out += bytes([0x40 | (h[1]-3), h[2]-1]); i += h[1]
        else:
            out += bytes([0x80 | (h[1]-3), h[2] & 255, h[2] >> 8]); i += h[1]
        marks.append((len(out), i))
    out += bytes([0x80, 0, 0])
    assert unpack(out) == data
    return bytes(out), marks

def unpack(p):
    out = bytearray(); i = 0
    while True:
        c = p[i]; i += 1
        if c < 0x40: out += p[i:i+c+1]; i += c+1; continue
        if c < 0x80: L = (c & 0x3F)+3; d = p[i]+1; i += 1
        else:
            L = (c & 0x7F)+3; d = p[i] | p[i+1] << 8; i += 2
            if d == 0: return bytes(out)
        for _ in range(L): out.append(out[-d])

UNPACKER = '''
        org %d
unpack: di
        ld sp,0x1200
        xor a
        ld (0xE008),a           ; speaker off
        ld hl,%d                ; packed data
        ld de,%d                ; where the program goes
up_l:   ld a,(hl)
        inc hl
        cp 0x40
        jr nc,up_m
        inc a                   ; literal run
        ld c,a
        ld b,0
        ldir
        jr up_l
up_m:   ld b,0
        cp 0x80
        jr nc,up_g
        and 0x3F                ; short match
        add a,3
        ld c,a
        ld a,(hl)
        inc hl
        push hl
        cpl                     ; HL = DE - (o+1)
        ld l,a
        ld h,0xFF
        add hl,de
        ldir
        pop hl
        jr up_l
up_g:   and 0x7F                ; long match
        add a,3
        ld c,a
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,up_end
        ex (sp),hl              ; HL = output, stack = packed pointer
        push hl
        or a
        sbc hl,de
        pop de
        ldir
        pop hl
        jr up_l
up_end: pop de
        jp %d
'''

def packed_mzt(name, lo, data, exe, mzt):
    """Returns (MZT bytes, info). The MZT loads the packed data plus the unpacker above the program."""
    p, marks = pack(data)
    # the packed data must start far enough up that after every token the output end is at or
    # below the next unread packed byte
    gap = max([0] + [w - r for r, w in marks])
    start = lo + gap
    stub = start + len(p)
    code = UNPACKER % (stub, start, lo, exe)
    slo, sdata, ssym = assemble(code)
    assert slo == stub
    blob = p + sdata
    assert start + len(blob) <= 0xD000, 'packed program does not fit'
    return mzt(name, start, blob, stub), dict(packed=len(p), load=start, end=start+len(blob)-1,
                                               exec=stub, size=len(blob))
