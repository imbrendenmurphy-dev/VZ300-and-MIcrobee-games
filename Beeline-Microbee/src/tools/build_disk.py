"""Build BEELINE.DS8: Microbee CP/M system tracks + a CP/M directory.

Disk builder from the earlier Premium Plus projects (BILBIES!, uB-TYPE,
The Lantern Deep), unchanged in format: 80 tracks x 2 sides x 10 sectors
x 512 bytes = 819200 bytes, 4 system track-sides, 4K blocks, Microbee
3:1 sector skew. resources/boot_tracks.bin and CCP.SYS come from those
disks. The disk boots to the plain CP/M prompt (no SHELL.SYS menu)."""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKEW = [1, 4, 7, 0, 3, 6, 9, 2, 5, 8]
TRACK = 5120
DIR = 4 * TRACK


def skew(lg):
    img = bytearray(len(lg))
    for t in range(len(lg) // TRACK):
        for s, k in enumerate(SKEW):
            img[t * TRACK + k * 512:t * TRACK + (k + 1) * 512] = lg[t * TRACK + s * 512:t * TRACK + (s + 1) * 512]
    return img


def unskew(img):
    lg = bytearray(len(img))
    for t in range(len(img) // TRACK):
        for s, k in enumerate(SKEW):
            lg[t * TRACK + s * 512:t * TRACK + (s + 1) * 512] = img[t * TRACK + k * 512:t * TRACK + (k + 1) * 512]
    return lg


def build_disk(system_lg, files, out):
    lg = bytearray([0xE5]) * 819200
    lg[:DIR] = system_lg[:DIR]
    blk = 1                      # block 0 = directory (64 entries)
    entries = []
    for name, data in files.items():
        stem, ext = name.split('.')
        records = math.ceil(len(data) / 128)
        nblocks = math.ceil(len(data) / 4096)
        assert nblocks <= 16, name          # one directory entry
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


def main():
    B = ROOT / 'build'
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    files = {}
    for n in ('BEELINE.COM', 'BEELINE.DAT', 'BENCH.COM', 'CUBE.COM'):
        files[n] = (B / n).read_bytes()
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    txt = (ROOT / 'docs' / 'DISK_README.TXT').read_text().replace('\r\n', '\n').replace('\n', '\r\n')
    files['README.TXT'] = txt.encode('ascii') + b'\x1a'
    used = build_disk(sysdisk, files, B / 'BEELINE.DS8')
    print('BEELINE.DS8: %d of 196 blocks used, %d files' % (used, len(files)))


if __name__ == '__main__':
    main()
