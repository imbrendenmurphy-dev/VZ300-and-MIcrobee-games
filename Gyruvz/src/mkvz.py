#!/usr/bin/env python3
"""wrap a raw binary as a VZ .VZ file (type F1 = machine code, autorun at load address)"""
import sys
src, dst, name, addr = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4], 16)
data = open(src, 'rb').read()
hdr = b"VZF0" + name.upper().encode()[:16].ljust(17, b"\0") + bytes([0xF1, addr & 255, addr >> 8])
open(dst, 'wb').write(hdr + data)
print("%s: %d bytes, load %04X-%04X" % (dst, len(data), addr, addr + len(data) - 1))
