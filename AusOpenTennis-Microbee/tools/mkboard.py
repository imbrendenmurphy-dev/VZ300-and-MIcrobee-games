"""The scrolling sponsor board (cell row 3): BPM's sponsor messages in the
LED font, pre-shifted for the game's 2-pixel scroll steps.

BOARD0..3.BNK, one per 2-pixel shift (RAM blocks 10, 11, 15, 16).
The board shows its glyphs starting at character c, shift k."""
import fonts

ORIGINAL = [
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
SPONSORS = [
    ('FAULTY TOWERS', 'SERVING DOUBLE FAULTS SINCE 1982'),
    ('ACE HARDWARE', 'WE KNOW HOW TO SERVE'),
    ('DEUCE BIGALOW', 'PROFESSIONAL BALL HANDLING'),
    ('NET PROFITS LTD', 'YOUR LOSS IS OUR GAIN'),
    ('LOVE ALL INSURANCE', 'LOVE MEANS NOTHING'),
    ('BALLS R US', 'TWO BALLS ARE BETTER THAN ONE'),
    ('THE RACKET', 'ORGANISED TENNIS SINCE 1984'),
    ('LOBOTOMY INC', 'GET IT OUT OF YOUR HEAD'),
    ('SMASHED AVOCADO', 'BREAKFAST OF CHAMPIONS'),
    ('DODGY BROTHERS', 'OFFICIAL LINE JUDGES'),
    ('OUT OF BOUNDS TRAVEL', "WE'LL TAKE YOU ANYWHERE"),
    ('UNFORCED ERRORS LTD', 'PROUD SPONSOR OF YOUR OPPONENT'),
]
RETRO = [
    '32K PCG - UNLIMITED IMAGINATION',
    "MICROBEE - WE'VE GOT CHARACTER",
    '640K? SHOW OFF.',
    'Z80 POWER - FEEL THE 4MHZ',
    'LOADING SPONSOR... PLEASE WAIT',
    'NO SPRITES WERE HARMED',
    'REAL ATHLETES USE 8 BITS',
    'VIBED BY BPM - PROUDLY UNTESTED',
    'YOUR NEXT OPPONENT IS ON DISK 2',
    'THIS AD USES TWO COLOURS',
]


def messages():
    """BPM's lines, the sponsors (name - slogan) and the retro jokes, dealt in turn"""
    spons = ['%s - %s' % s for s in SPONSORS]
    out = []
    for i in range(max(len(ORIGINAL), len(spons), len(RETRO))):
        for lst in (ORIGINAL, spons, RETRO):
            if i < len(lst):
                out.append(lst[i])
    return out


SEP = '   *   '
DATA = 0x0010           # BRD_DATA in each block
SHIFT_BLOCKS = (10, 11, 15, 16)     # BRD_BLOCKS in src/board.asm: one per shift


def build():
    """-> [4 block images] (shift 0, 2, 4, 6 px), N.
    Block: dw N, then (N + 64) glyphs x 16 bytes from DATA:
    glyph c at shift k = (char c << k) | (char c+1 >> 8-k), row by row."""
    text = SEP.join(messages()) + SEP
    n = len(text)
    loop = (text * 2)[:n + 65]
    F = fonts.FONTS['LED']
    g = [F[ord(ch) - 32] for ch in loop]
    blocks = []
    for s in (0, 2, 4, 6):
        out = bytearray(DATA)
        out[0:2] = n.to_bytes(2, 'little')
        for c in range(n + 64):
            for r in range(16):
                out.append((g[c][r] << s | g[c + 1][r] >> (8 - s)) & 0xFF if s else g[c][r])
        assert len(out) <= 0x8000, len(out)
        blocks.append(bytes(out))
    return blocks, n


if __name__ == '__main__':
    bl, n = build()
    print(n, 'characters,', len(bl[0]), 'bytes a shift')


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
