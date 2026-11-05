#!/usr/bin/env python3
import sys
binf, out, name, addr = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4], 16)
d = open(binf, 'rb').read()
nm = name.encode()[:16].ljust(16, b'\0') + b'\0'
hdr = b'VZF0' + nm + bytes([0xF1, addr & 255, addr >> 8])
open(out, 'wb').write(hdr + d)
print('%s: %d bytes, %04X-%04X' % (out, len(d), addr, addr + len(d) - 1))
