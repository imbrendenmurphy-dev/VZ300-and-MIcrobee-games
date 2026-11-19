# BIX-LZ: byte-aligned LZ for the Z80 loader.
#   0nnnnnnn            : n+1 literal bytes follow
#   1nnnnnnn oooooooo   : copy n+3 bytes from (dest - o - 1)   (o <= 255, n+3 <= 130)
def compress(data):
    out = bytearray(); lit = bytearray(); i = 0; n = len(data)
    def flush():
        nonlocal lit
        while lit:
            c = lit[:128]; out.append(len(c) - 1); out.extend(c); lit = lit[128:]
    while i < n:
        best_len = 0; best_off = 0
        lo = max(0, i - 256)
        for j in range(lo, i):
            l = 0
            while i + l < n and l < 130 and data[j + l] == data[i + l]:
                l += 1
            if l > best_len: best_len, best_off = l, i - j - 1
        if best_len >= 3:
            flush(); out.append(0x80 | (best_len - 3)); out.append(best_off); i += best_len
        else:
            lit.append(data[i]); i += 1
    flush()
    return bytes(out)

def decompress(comp, n):
    out = bytearray(); i = 0
    while len(out) < n:
        c = comp[i]; i += 1
        if c < 0x80:
            out += comp[i:i + c + 1]; i += c + 1
        else:
            l = (c & 0x7F) + 3; o = comp[i] + 1; i += 1
            for _ in range(l): out.append(out[-o])
    return bytes(out)
