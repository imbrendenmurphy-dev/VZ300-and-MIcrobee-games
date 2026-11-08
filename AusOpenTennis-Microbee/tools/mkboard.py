"""The scrolling sponsor board (cell row 3): BPM's sponsor messages in the
LED font, pre-shifted for the game's 2-pixel scroll steps.

BOARD.BNK (loaded into RAM block 17):
  dw N (characters in the loop)
  then 4 shifts (0, 2, 4, 6 px) x (N + 64) glyphs x 16 bytes, from BOARD_DATA:
  glyph c at shift k = (char c << k) | (char c+1 >> 8-k), row by row.
The board shows 64 glyphs starting at character c, shift k."""
import fonts

MESSAGES = [
    'YOUR AD HERE - CALL 555-ACE',
    'THIS SPACE INTENTIONALLY SOLD',
    'PLEASE IGNORE THE PIXELS',
    'NOW WITH 20% MORE TENNIS',
    'NO REFUNDS AFTER MATCH POINT',
    'THE UMPIRE IS A PAID ACTOR',
    'BALLS TESTED ON ANIMALS - THE PLAYERS',
    'SPONSORED BY QUESTIONABLE DECISIONS',
    'INSERT COIN TO DISAGREE',
    'THE CROWD IS JUST A BACKGROUND PATTERN',
    'PLEASE DO NOT FEED THE BALL BOYS',
    '100% ORGANIC SYNTHETIC GRASS',
]
SEP = '   *   '
HEADER = 2
DATA = 0x0010           # BOARD_DATA in the block


def build():
    text = SEP.join(MESSAGES) + SEP
    n = len(text)
    loop = (text * 3)[:n + 65]
    F = fonts.FONTS['LED']
    g = [F[ord(ch) - 32] for ch in loop]
    out = bytearray(DATA)
    out[0:2] = n.to_bytes(2, 'little')
    for s in (0, 2, 4, 6):
        for c in range(n + 64):
            for r in range(16):
                b = (g[c][r] << s | g[c + 1][r] >> (8 - s)) & 0xFF if s else g[c][r]
                out.append(b)
    assert len(out) <= 0x8000, len(out)
    return bytes(out), n


if __name__ == '__main__':
    d, n = build()
    print(n, 'characters,', len(d), 'bytes')


# ---------------------------------------------------------------- clouds
# Kooyong's sky (cell row 0, columns 16..63 = 384 pixels) as a loop of
# clouds the game drifts left a pixel at a time.
# CLOUD.BNK (RAM block 18): 16 bytes of mono sky dots (one per row), then
# 8 shifts x 16 rows x 96 bytes: byte i of row r at shift s = pixels
# 8i+s .. 8i+s+7 of the loop (twice round, so a 48-byte window never wraps).
SKY_W = 384


def cloud_strip():
    import numpy as np
    a = np.zeros((16, SKY_W), bool)
    yy, xx = np.mgrid[0:16, 0:SKY_W]
    for cx in (42, 132, 202, 292, 352, 250):
        for k in range(4):
            ex, ey = cx + k * 6 - 9, 8 - (k % 2) * 2 - (3 if cx == 250 else 0)
            rx, ry = (7, 3) if cx != 250 else (5, 2)
            dx = (xx - ex + SKY_W // 2) % SKY_W - SKY_W // 2
            a |= (dx / (rx + 0.5)) ** 2 + ((yy - ey) / (ry + 0.5)) ** 2 <= 1
    return a


def build_clouds():
    import numpy as np
    from cells import mono_bits
    import mkcourts
    a = cloud_strip()
    sky = mono_bits(np.full((16, 8), 14, np.uint8), mkcourts.MONO_LEVEL)   # BCYN
    out = bytearray(bytes(int(''.join('1' if v else '0' for v in sky[r]), 2) for r in range(16)))
    for s in range(8):
        for r in range(16):
            row = np.concatenate([a[r], a[r], a[r]])
            for i in range(96):
                bits = row[8 * i + s:8 * i + s + 8]
                out.append(int(''.join('1' if v else '0' for v in bits), 2))
    return bytes(out)
