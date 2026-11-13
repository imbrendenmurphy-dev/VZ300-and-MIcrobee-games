"""SLZ: a small byte LZ for BELLARIUS stage data (VIBED BY BPM 2026).

tokens:  0nnnnnnn               literal run of n+1 bytes (1..128) follows
         1lllllll oooo oooo     match: length l+3 (3..130), dw distance back (1..32767)
         1xxxxxxx 00 00         end (distance 0)
"""


def pack(data, window=32767):
    data = bytes(data)
    n = len(data)
    out = bytearray()
    heads = {}
    lit = bytearray()

    def flush():
        i = 0
        while i < len(lit):
            k = min(128, len(lit) - i)
            out.append(k - 1)
            out.extend(lit[i:i + k])
            i += k
        lit.clear()

    i = 0
    while i < n:
        best_len, best_d = 0, 0
        if i + 3 <= n:
            key = data[i:i + 3]
            cands = heads.get(key, [])
            for j in reversed(cands[-96:]):
                d = i - j
                if d > window:
                    break
                L = 3
                while i + L < n and L < 130 and data[j + L] == data[i + L]:
                    L += 1
                if L > best_len:
                    best_len, best_d = L, d
                    if L == 130:
                        break
        if best_len >= 3:
            flush()
            out.append(0x80 | (best_len - 3))
            out += best_d.to_bytes(2, 'little')
            for k in range(best_len):
                if i + k + 3 <= n:
                    heads.setdefault(data[i + k:i + k + 3], []).append(i + k)
            i += best_len
        else:
            if i + 3 <= n:
                heads.setdefault(data[i:i + 3], []).append(i)
            lit.append(data[i])
            i += 1
    flush()
    out += bytes([0x80, 0, 0])
    return bytes(out)


def unpack(src):
    out = bytearray()
    i = 0
    while True:
        t = src[i]
        i += 1
        if t < 0x80:
            out += src[i:i + t + 1]
            i += t + 1
        else:
            d = src[i] | (src[i + 1] << 8)
            i += 2
            if d == 0:
                return bytes(out)
            for k in range((t & 0x7F) + 3):
                out.append(out[-d])


if __name__ == '__main__':
    import os
    d = os.urandom(200) * 30 + bytes(range(256)) * 4
    p = pack(d)
    assert unpack(p) == d
    print(len(d), '->', len(p))
