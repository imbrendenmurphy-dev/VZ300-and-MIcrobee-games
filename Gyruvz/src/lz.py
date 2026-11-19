"""The packer for unlz (glue.asm).
  token 0..$7F    : token+1 literal bytes follow
  token $80..$FE  : copy token-$7D bytes (3..129) from dest - offset (2 bytes)
  token $FF       : end
"""


def pack(data):
    data = bytes(data)
    n = len(data)
    out = bytearray()
    lit = bytearray()
    heads = {}
    i = 0

    def flush():
        while lit:
            chunk = lit[:128]
            out.append(len(chunk) - 1)
            out.extend(chunk)
            del lit[:128]

    while i < n:
        best_len, best_off = 0, 0
        if i + 3 <= n:
            key = data[i:i + 3]
            for j in reversed(heads.get(key, [])[-64:]):
                L = 0
                while i + L < n and L < 129 and data[j + L] == data[i + L]:
                    L += 1
                if L > best_len:
                    best_len, best_off = L, i - j
                    if L == 129:
                        break
        if best_len >= 3:
            flush()
            out.append(0x7D + best_len)
            out += bytes((best_off & 255, best_off >> 8))
            for k in range(i, i + best_len):
                if k + 3 <= n:
                    heads.setdefault(data[k:k + 3], []).append(k)
            i += best_len
        else:
            lit.append(data[i])
            if i + 3 <= n:
                heads.setdefault(data[i:i + 3], []).append(i)
            i += 1
    flush()
    out.append(0xFF)
    return bytes(out)


def unpack(p):
    out = bytearray()
    i = 0
    while True:
        t = p[i]
        i += 1
        if t == 0xFF:
            return bytes(out)
        if t < 0x80:
            out += p[i:i + t + 1]
            i += t + 1
        else:
            L = t - 0x7D
            off = p[i] | (p[i + 1] << 8)
            i += 2
            for _ in range(L):
                out.append(out[-off])
