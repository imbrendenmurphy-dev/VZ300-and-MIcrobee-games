#!/usr/bin/env python3
"""Build EMPIRES.DS8: Microbee CP/M system tracks + CP/M directory + files.

Same format as The Lantern Deep's disk (checked there by booting the real
boot ROM): 80 tracks x 2 sides x 10 x 512 bytes = 819200 bytes, the first 4
track-sides hold the system, 4K allocation blocks, Microbee 3:1 skew.
No SHELL.SYS, so the disk boots straight to the A> prompt.

The system tracks and CCP.SYS are Microbee system files: they are read from
src/resources/ (not published; copy them from your own system disk).
"""
import math, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
SKEW = [1, 4, 7, 0, 3, 6, 9, 2, 5, 8]
DIRBASE = 20480          # 4 track-sides
BLOCKS = (819200 - DIRBASE) // 4096

def build_disk(files, out):
    b = bytearray([0xE5]) * 819200
    boot = (ROOT / 'src' / 'resources' / 'boot_tracks.bin').read_bytes()
    for t in range(4):
        for s, k in enumerate(SKEW):
            b[t*5120 + s*512:t*5120 + (s+1)*512] = boot[t*5120 + k*512:t*5120 + (k+1)*512]
    blk = 2                  # blocks 0-1 = directory (64 entries)
    entries = []
    for name, data in files.items():
        stem, ext = name.split('.')
        records = math.ceil(len(data) / 128)
        nblocks = math.ceil(len(data) / 4096)
        # one directory entry covers 16 blocks (64K); split larger files
        for ex in range(max(1, math.ceil(nblocks / 16))):
            e = bytearray(32)
            e[1:12] = (stem.ljust(8) + ext.ljust(3)).encode()
            first = ex * 16
            nb = min(16, nblocks - first)
            recs = min(records - ex * 512, 512)
            e[12] = (ex * 4) + (recs - 1) // 128
            e[15] = recs - ((recs - 1) // 128) * 128
            e[16:16 + nb] = bytes(range(blk + first, blk + first + nb))
            entries.append(e)
        b[DIRBASE + blk*4096:DIRBASE + blk*4096 + len(data)] = data
        blk += nblocks
    assert len(entries) <= 64 and blk <= BLOCKS, (len(entries), blk)
    for i, e in enumerate(entries):
        b[DIRBASE + i*32:DIRBASE + (i+1)*32] = e
    out_b = bytearray(len(b))
    for t in range(160):
        for s, k in enumerate(SKEW):
            out_b[t*5120 + k*512:t*5120 + (k+1)*512] = b[t*5120 + s*512:t*5120 + (s+1)*512]
    Path(out).write_bytes(out_b)
    return blk

if __name__ == '__main__':
    B = ROOT / 'build'
    txt = (ROOT / 'disk' / 'README.TXT').read_text().replace('\r\n', '\n').replace('\n', '\r\n')
    files = {
        'EMPIRES.COM': (B / 'EMPIRES.COM').read_bytes(),
        'CCP.SYS': (ROOT / 'src' / 'resources' / 'CCP.SYS').read_bytes(),
        'README.TXT': txt.encode('ascii') + b'\x1a',
    }
    assert not any(n.upper().startswith('SHELL') for n in files)
    used = build_disk(files, B / 'EMPIRES.DS8')
    print('EMPIRES.DS8: %d of %d blocks used' % (used, BLOCKS))
