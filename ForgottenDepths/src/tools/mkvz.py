#!/usr/bin/env python3
import sys
binf, outf, name, addr = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4], 0)
d = open(binf, 'rb').read()
nm = name.upper().encode()[:16]
hdr = b'VZF0' + nm + b'\0' * (17 - len(nm)) + bytes([0xF1, addr & 255, addr >> 8])
open(outf, 'wb').write(hdr + d)
print(f'{outf}: {len(d)} bytes at {addr:04X}-{addr+len(d)-1:04X}')
