#!/usr/bin/env python3
# wrap a raw binary as a VZ snapshot (.VZ): 'VZF0' + 17-byte name + type $F1 + load addr
import sys
src, dst, name, addr = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4], 16)
data = open(src, 'rb').read()
hdr = b'VZF0' + name.encode()[:16].ljust(17, b'\0') + bytes([0xF1, addr & 255, addr >> 8])
open(dst, 'wb').write(hdr + data)
print(f'{dst}: {len(data)} bytes at ${addr:04X}-${addr+len(data)-1:04X}')
