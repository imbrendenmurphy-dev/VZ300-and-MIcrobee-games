"""Build CRYPTFAL.DS8: Microbee CP/M system tracks + a CP/M directory.

Geometry (DS80, as the earlier Premium Plus disks that boot on BPM's
machine): 80 tracks x 2 sides x 10 sectors x 512 bytes = 819200 bytes.
The first 4 track-sides hold the system; the directory follows; allocation
blocks are 4K; sectors are stored with the Microbee 3:1 skew.  The system
tracks (resources/boot_tracks.bin, in logical sector order) and CCP.SYS are
the ones from the earlier disks.  SHELL.SYS on the disk makes the system
run the game at boot instead of showing the A> prompt.
"""
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKEW = [1, 4, 7, 0, 3, 6, 9, 2, 5, 8]
TRACK = 5120
DIR = 4 * TRACK          # directory / data area (logical offset)
NBLOCKS = 196            # 4K blocks (block 0 = the directory)


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


def read_files(img):
    """{name: bytes} of a disk image's files (user 0)"""
    lg = unskew(img)
    ents = {}
    for i in range(128):
        e = lg[DIR + i * 32:DIR + (i + 1) * 32]
        if e[0] != 0:
            continue
        name = e[1:9].decode('ascii', 'replace').strip() + '.' + bytes(b & 0x7F for b in e[9:12]).decode().strip()
        ents.setdefault(name, []).append(e)
    files = {}
    for name, es in ents.items():
        es.sort(key=lambda e: (e[14], e[12]))
        data = bytearray()
        recs = 0
        for e in es:
            for b in e[16:32]:
                if b:
                    data += lg[DIR + b * 4096:DIR + (b + 1) * 4096]
            recs = (e[14] * 32 + e[12]) * 128 + e[15]
        files[name] = bytes(data[:recs * 128])
    return files


def build_disk(system_lg, files, out):
    lg = bytearray([0xE5]) * 819200
    lg[:DIR] = system_lg[:DIR]
    blk = 1
    entries = []
    for name, data in files.items():
        stem, ext = name.split('.')
        records = max(1, math.ceil(len(data) / 128))
        nblocks = math.ceil(records * 128 / 4096)
        lg[DIR + blk * 4096:DIR + blk * 4096 + len(data)] = data
        blocks = list(range(blk, blk + nblocks))
        blk += nblocks
        # one directory entry per 64K (16 blocks = 4 logical extents)
        for i in range(0, max(1, nblocks), 16):
            part = blocks[i:i + 16]
            recs = min(records - i * 32, 512)
            e = bytearray(32)
            e[1:12] = (stem.ljust(8) + ext.ljust(3)).encode()
            ex = (i // 16) * 4 + (recs - 1) // 128
            e[12] = ex & 31
            e[14] = ex >> 5
            e[15] = recs - ((recs - 1) // 128) * 128
            e[16:16 + len(part)] = bytes(part)
            entries.append(e)
    assert len(entries) <= 64, 'too many directory entries'
    assert blk <= NBLOCKS, 'disk full'
    for i, e in enumerate(entries):
        lg[DIR + i * 32:DIR + (i + 1) * 32] = e
    Path(out).write_bytes(skew(lg))
    return blk


def shell_sys(B):
    """SHELL.SYS = a copy of CCP.SYS's 128-byte header (with our length) + the stub"""
    ccp = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    code = (B / 'SHELL.BIN').read_bytes()
    hdr = bytearray(ccp[:128])
    hdr[4:6] = len(code).to_bytes(2, 'little')
    return bytes(hdr) + code


def hi_default():
    import hiscore
    return hiscore.default_record()


def main(out=None, autorun=True, caves=None, hi=None):
    B = ROOT / 'build'
    out = Path(out) if out else None
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    files = {}
    files['CRYPT.HI'] = hi or hi_default()
    if autorun:
        files['SHELL.SYS'] = shell_sys(B)
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    files['CRYPT.COM'] = (B / 'CRYPT.COM').read_bytes()
    files['CAVES.DAT'] = Path(caves or B / 'CAVES.DAT').read_bytes()
    if (B / 'DEMO.DAT').exists() and not caves:
        files['DEMO.DAT'] = (B / 'DEMO.DAT').read_bytes()
    readme = ROOT / 'docs' / 'DISK_README.TXT'
    if readme.exists():
        files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    out = out or (B / 'CRYPTFAL.DS8')
    used = build_disk(sysdisk, files, out)
    print('%s: %d of %d blocks used (%dK free), %d files' % (Path(out).name, used, NBLOCKS, (NBLOCKS - used) * 4, len(files)))


if __name__ == '__main__':
    main()
