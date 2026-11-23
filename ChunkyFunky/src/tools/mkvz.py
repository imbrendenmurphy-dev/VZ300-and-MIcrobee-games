#!/usr/bin/env python3
"""mkvz - wrap a raw binary as a .VZ file (machine code, type F1, or BASIC, type F0).
usage: py mkvz.py in.bin out.vz START [NAME] [--basic]"""
import sys

def main():
    a = [x for x in sys.argv[1:] if not x.startswith('--')]
    basic = '--basic' in sys.argv
    if len(a) < 3:
        print(__doc__); sys.exit(1)
    data = open(a[0], 'rb').read()
    start = int(a[2], 0)
    name = (a[3] if len(a) > 3 else a[1].split('/')[-1].split('\\')[-1].split('.')[0]).upper()[:16]
    hdr = b'VZF0' + name.encode('ascii').ljust(17, b'\0') + bytes([0xF0 if basic else 0xF1, start & 255, start >> 8])
    open(a[1], 'wb').write(hdr + data)
    print('%s: %s $%04X-$%04X (%d bytes)' % (a[1], 'BASIC' if basic else 'machine code', start, start + len(data) - 1, len(data)))

if __name__ == '__main__':
    main()
