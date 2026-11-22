"""build/sin.inc: 256 signed bytes, 63 sin(2 pi i / 256)."""
import math
from pathlib import Path

B = Path(__file__).resolve().parent.parent / 'build'


def main():
    v = [round(63 * math.sin(2 * math.pi * i / 256)) & 255 for i in range(256)]
    B.mkdir(exist_ok=True)
    (B / 'sin.inc').write_text(''.join('\tdb ' + ','.join('$%02X' % x for x in v[i:i + 16]) + '\n'
                                       for i in range(0, 256, 16)))


if __name__ == '__main__':
    main()
