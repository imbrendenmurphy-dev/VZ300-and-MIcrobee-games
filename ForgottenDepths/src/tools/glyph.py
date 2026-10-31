"""6847 screen-code helpers."""
G, Y, B, R, W, C, M, O = range(8)   # green yellow blue red buff(white) cyan magenta orange
BLK = 0x80


def T(ch):
    """normal text character (6847 code)"""
    c = ord(ch)
    if 64 <= c <= 95:
        return c - 64
    if 32 <= c <= 63:
        return c
    raise ValueError(ch)


def V(ch):
    """inverse text character"""
    return T(ch) | 0x40


def S(col, q):
    """semigraphic: q = 4 chars TL TR BL BR, any non '.' = set"""
    m = 0
    for bit, ch in zip((8, 4, 2, 1), q):
        if ch not in '. ':
            m |= bit
    if m == 0:
        return BLK
    return 0x80 | (col << 4) | m


def text(s):
    return bytes(T(ch) for ch in s.upper())
