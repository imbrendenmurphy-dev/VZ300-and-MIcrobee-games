"""Build the DS8 disk: Microbee CP/M system tracks + a CP/M directory.

Geometry (as the earlier Premium conversions use, checked against the
boot ROM and BIOS in the test model): 80 tracks x 2 sides x 10 sectors x
512 bytes = 819200 bytes. The first 4 track-sides hold the system; the
directory follows; allocation blocks are 4K. Sectors are stored with the
Microbee 3:1 skew.
"""
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKEW = [1, 4, 7, 0, 3, 6, 9, 2, 5, 8]


def build_disk(files, out):
    b = bytearray([0xE5]) * 819200
    boot = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    for t in range(4):
        for s, k in enumerate(SKEW):
            b[t * 5120 + s * 512:t * 5120 + (s + 1) * 512] = boot[t * 5120 + k * 512:t * 5120 + (k + 1) * 512]
    blk = 1                      # block 0 = directory
    entries = []
    for name, data in files.items():
        stem, ext = name.split('.')
        records = math.ceil(len(data) / 128)
        nblocks = math.ceil(len(data) / 4096)
        assert nblocks <= 16, name
        e = bytearray(32)
        e[1:12] = (stem.ljust(8) + ext.ljust(3)).encode()
        e[12] = (records - 1) // 128 if records else 0
        e[15] = records - e[12] * 128
        e[16:16 + nblocks] = bytes(range(blk, blk + nblocks))
        entries.append(e)
        b[20480 + blk * 4096:20480 + blk * 4096 + len(data)] = data
        blk += nblocks
    assert len(entries) <= 64
    for i, e in enumerate(entries):
        b[20480 + i * 32:20480 + (i + 1) * 32] = e
    out_b = bytearray(len(b))
    for t in range(160):
        for s, k in enumerate(SKEW):
            out_b[t * 5120 + k * 512:t * 5120 + (k + 1) * 512] = b[t * 5120 + s * 512:t * 5120 + (s + 1) * 512]
    Path(out).write_bytes(out_b)
    return blk


if __name__ == '__main__':
    B = ROOT / 'build'
    # SAVE.DAT first: blocks 1-2, where the game's disk driver expects it
    # (tools/savemap.py). A signature marks it, so the game only ever writes
    # to sectors that really are this file.
    save = bytearray(8192)
    save[0:16] = b'LANTERN-DEEP-SAV'
    files = {
        'SAVE.DAT': bytes(save),
        'LANTERN.COM': (B / 'LANTERN.COM').read_bytes(),
        'LANTERN.LO': (B / 'LANTERN.LO').read_bytes(),
        'LANTERN.HI': (B / 'LANTERN.HI').read_bytes(),
        'GFX.BNK': (B / 'GFX.BNK').read_bytes(),
        'WORLD.BNK': (B / 'WORLD.BNK').read_bytes(),
        'TITLE.BNK': (B / 'TITLE.BNK').read_bytes(),
        'AUDIO.BNK': (B / 'AUDIO.BNK').read_bytes(),
        'WORLD2.BNK': (B / 'WORLD2.BNK').read_bytes(),
        'AUDIO2.BNK': (B / 'AUDIO2.BNK').read_bytes(),
        'AUDIO3.BNK': (B / 'AUDIO3.BNK').read_bytes(),
        'AUDIO4.BNK': (B / 'AUDIO4.BNK').read_bytes(),
        'AUDIO5.BNK': (B / 'AUDIO5.BNK').read_bytes(),
        'CCP.SYS': (ROOT / 'resources' / 'CCP.SYS').read_bytes(),
        'README.TXT': (ROOT / 'resources' / 'README.TXT').read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a',
    }
    for i in range(5):
        files['REGION%d.BNK' % i] = (B / ('REGION%d.BNK' % i)).read_bytes()
        files['ROOMS%d.BNK' % i] = (B / ('ROOMS%d.BNK' % i)).read_bytes()
    # the disk boots to the plain CP/M prompt: no Microbee SHELL.SYS menu
    assert not any(n.upper().startswith('SHELL') for n in files)
    used = build_disk(files, B / 'LANTERN.DS8')
    print('LANTERN.DS8: %d of 196 blocks used' % used)
