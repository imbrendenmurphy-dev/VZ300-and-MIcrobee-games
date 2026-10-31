ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
KEY = [19, 7, 28, 2, 13, 24]
def encode(ch, hpmax, mpmax, lvl, gems, staff=0, boots=0, sun=0, ring=0, blade=0):
    items = staff | boots << 1 | sun << 2 | ring << 3 | blade << 4
    b0 = ((ch - 1) & 3) | items << 2
    b1 = (hpmax & 15) | (mpmax << 4) & 0xF0
    b2 = ((lvl - 1) & 7) | (min(gems, 31) << 3)
    chk = (b0 + b1 * 3 + b2 * 7 + 0x2B) & 63
    v = b0 | b1 << 8 | b2 << 16 | chk << 24
    out, prev = '', 0
    for i in range(6):
        s = (v >> (5 * i)) & 31
        prev = (s + prev + KEY[i]) & 31
        out += ALPHA[prev]
    return out
if __name__ == '__main__':
    print(encode(1, 6, 4, 1, 0), 'expect VLZ3YN')
    print(encode(3, 10, 7, 5, 1, 1, 1, 1, 1, 1), '(chapter 3, all items)')
