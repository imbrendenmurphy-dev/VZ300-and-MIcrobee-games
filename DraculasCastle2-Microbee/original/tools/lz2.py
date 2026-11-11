# LZ2: literal runs 1..128 (t<$80); match t=1LLLOOOO + lowoff : len=LLL+3 (LLL=7 -> +ext byte, ext=255 = END), off=OOOO:low +1 (1..4096)
def compress(data, lazy=True):
    data = bytes(data); n = len(data)
    # hash chains for speed
    head = {}; prev = [-1] * n
    def find(i):
        best_l = 0; best_o = 0
        if i + 3 > n: return 0, 0
        key = data[i:i + 3]
        j = head.get(key, -1); tries = 0
        while j >= 0 and i - j <= 4096 and tries < 256:
            l = 0
            while i + l < n and data[j + l] == data[i + l] and l < 264: l += 1
            if l > best_l: best_l, best_o = l, i - j
            j = prev[j]; tries += 1
        return best_l, best_o
    def insert(i):
        if i + 3 <= n:
            key = data[i:i + 3]; prev[i] = head.get(key, -1); head[key] = i
    out = bytearray(); lit = bytearray(); i = 0
    def flush():
        while lit:
            ch = lit[:128]; del lit[:128]
            out.append(len(ch) - 1); out.extend(ch)
    while i < n:
        l, o = find(i)
        if lazy and l >= 3 and i + 1 < n:
            insert(i)
            l2, o2 = find(i + 1)
            if l2 > l + 1:
                lit.append(data[i]); i += 1
                continue
            # undo not needed; insert again is harmless
        if l >= 3:
            flush()
            o1 = o - 1
            if l - 3 < 7:
                out.append(0x80 | ((l - 3) << 4) | (o1 >> 8)); out.append(o1 & 255)
            else:
                ext = l - 10
                out.append(0x80 | (7 << 4) | (o1 >> 8)); out.append(o1 & 255); out.append(ext)
            for k in range(l): insert(i + k)
            i += l
        else:
            insert(i); lit.append(data[i]); i += 1
    flush()
    out += bytes([0xF0, 0x00, 0xFF])
    return bytes(out)

def decompress(c):
    out = bytearray(); i = 0
    while True:
        t = c[i]; i += 1
        if t < 0x80:
            out += c[i:i + t + 1]; i += t + 1; continue
        o = ((t & 15) << 8 | c[i]) + 1; i += 1
        l = ((t >> 4) & 7) + 3
        if l == 10:
            e = c[i]; i += 1
            if e == 255: break
            l += e
        for _ in range(l): out.append(out[-o])
    return bytes(out)

def compress_opt(data):
    """optimal-parse LZ2 (same format as compress)"""
    data = bytes(data); n = len(data)
    INF = 1 << 30
    # candidate matches per position via hash chains
    head = {}; prev = [-1] * n
    cands = [None] * n
    for i in range(n):
        res = []
        if i + 3 <= n:
            key = data[i:i + 3]; j = head.get(key, -1); tries = 0; seen_len = 0
            while j >= 0 and i - j <= 4096 and tries < 64:
                l = 0
                while i + l < n and data[j + l] == data[i + l] and l < 264: l += 1
                if l > seen_len:
                    res.append((l, i - j)); seen_len = l
                j = prev[j]; tries += 1
            prev[i] = head.get(key, -1); head[key] = i
        cands[i] = res
    cost = [INF] * (n + 1); back = [None] * (n + 1); cost[0] = 0
    for i in range(n):
        c = cost[i]
        if c >= INF: continue
        for k in range(1, min(128, n - i) + 1):
            if c + 1 + k < cost[i + k]: cost[i + k] = c + 1 + k; back[i + k] = ('L', i)
        for (L, off) in cands[i]:
            lens = set(range(3, min(L, 12) + 1)); lens.add(L)
            for l in lens:
                cc = c + (2 if l < 10 else 3)
                if cc < cost[i + l]: cost[i + l] = cc; back[i + l] = ('M', i, off)
    toks = []; i = n
    while i > 0:
        b = back[i]
        if b[0] == 'L': toks.append(('L', b[1], i)); i = b[1]
        else: toks.append(('M', b[1], i - b[1], b[2])); i = b[1]
    toks.reverse()
    out = bytearray()
    for t in toks:
        if t[0] == 'L':
            s, e = t[1], t[2]
            out.append(e - s - 1); out += data[s:e]
        else:
            _, s, l, o = t; o1 = o - 1
            if l < 10: out += bytes([0x80 | ((l - 3) << 4) | (o1 >> 8), o1 & 255])
            else: out += bytes([0x80 | 0x70 | (o1 >> 8), o1 & 255, l - 10])
    out += bytes([0xF0, 0x00, 0xFF])
    return bytes(out)
