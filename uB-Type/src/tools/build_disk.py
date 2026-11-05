"""Build UBTYPE.DS8: Microbee CP/M system tracks + a CP/M directory.

Geometry (as the earlier Premium conversions): 80 tracks x 2 sides x 10
sectors x 512 bytes = 819200 bytes. The first 4 track-sides hold the
system; the directory follows; allocation blocks are 4K; sectors are
stored with the Microbee 3:1 skew. The system tracks (resources/boot_tracks.bin,
in logical sector order) and CCP.SYS were taken from the Microbee boot disk
of The Lantern Deep. The disk boots
to the plain CP/M prompt: no SHELL.SYS menu is put on it."""
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKEW = [1, 4, 7, 0, 3, 6, 9, 2, 5, 8]
TRACK = 5120
DIR = 4 * TRACK          # directory / data area (logical offset)


def unskew(img):
    lg = bytearray(len(img))
    for t in range(len(img) // TRACK):
        for s, k in enumerate(SKEW):
            lg[t * TRACK + s * 512:t * TRACK + (s + 1) * 512] = img[t * TRACK + k * 512:t * TRACK + (k + 1) * 512]
    return lg


def skew(lg):
    img = bytearray(len(lg))
    for t in range(len(lg) // TRACK):
        for s, k in enumerate(SKEW):
            img[t * TRACK + k * 512:t * TRACK + (k + 1) * 512] = lg[t * TRACK + s * 512:t * TRACK + (s + 1) * 512]
    return img


def read_dir(lg):
    """{name: bytes} of a disk image's files (user 0)"""
    files = {}
    ext = {}
    for i in range(64):
        e = lg[DIR + i * 32:DIR + (i + 1) * 32]
        if e[0] != 0:
            continue
        name = e[1:9].decode('ascii', 'replace').strip() + '.' + bytes(b & 0x7F for b in e[9:12]).decode().strip()
        ext.setdefault(name, []).append(e)
    for name, es in ext.items():
        es.sort(key=lambda e: (e[14], e[12]))
        data = bytearray()
        total = 0
        for e in es:
            blocks = [b for b in e[16:32] if b]
            recs = e[12] % 4 * 128 + e[15] if False else None
            for b in blocks:
                data += lg[DIR + b * 4096:DIR + (b + 1) * 4096]
        last = es[-1]
        nrec = (last[12] & 3) * 128 + last[15] + (len([b for e in es[:-1] for b in e[16:32] if b]) * 32)
        files[name] = bytes(data[:nrec * 128])
    return files


def build_disk(system_lg, files, out):
    lg = bytearray([0xE5]) * 819200
    lg[:DIR] = system_lg[:DIR]
    blk = 1                      # block 0 = directory (2K used, 64 entries)
    entries = []
    for name, data in files.items():
        stem, ext = name.split('.')
        records = math.ceil(len(data) / 128)
        nblocks = math.ceil(len(data) / 4096)
        assert nblocks <= 16, name          # one directory entry (EXM 3)
        e = bytearray(32)
        e[1:12] = (stem.ljust(8) + ext.ljust(3)).encode()
        e[12] = (records - 1) // 128 if records else 0
        e[15] = records - e[12] * 128
        e[16:16 + nblocks] = bytes(range(blk, blk + nblocks))
        entries.append(e)
        lg[DIR + blk * 4096:DIR + blk * 4096 + len(data)] = data
        blk += nblocks
    assert len(entries) <= 64
    assert blk <= 196, 'disk full'
    for i, e in enumerate(entries):
        lg[DIR + i * 32:DIR + (i + 1) * 32] = e
    Path(out).write_bytes(skew(lg))
    return blk


if __name__ == '__main__':
    B = ROOT / 'build'
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    files = {'UBTYPE.COM': (B / 'UBTYPE.COM').read_bytes(),
             'UBTYPE.BIN': (B / 'UBTYPE.BIN').read_bytes(),
             'FRONT.BNK': (B / 'FRONT.BNK').read_bytes(),
             'GFX.BNK': (B / 'GFX.BNK').read_bytes(),
             'TITLE.BNK': (B / 'TITLE.BNK').read_bytes()}
    for n in range(8):
        files['STAGE%d.PCG' % n] = (B / ('STAGE%d.PCG' % n)).read_bytes()
        files['STAGE%d.TAB' % n] = (B / ('STAGE%d.TAB' % n)).read_bytes()
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    files['README.TXT'] = (ROOT / 'docs' / 'DISK_README.TXT').read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    assert not any(n.upper().startswith('SHELL') for n in files)
    used = build_disk(sysdisk, files, B / 'UBTYPE.DS8')
    print('UBTYPE.DS8: %d of 196 blocks used, %d files' % (used, len(files)))
