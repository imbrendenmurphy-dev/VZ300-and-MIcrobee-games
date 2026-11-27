"""Build outputs/BLACKOUT.DS8: a Microbee CP/M boot disk, double sided, 80 tracks.
Boot tracks + CCP.SYS come from resources/ (taken from a Microbee CP/M boot disk).
Run from the project root."""
from pathlib import Path
import hashlib

out = Path('outputs'); out.mkdir(exist_ok=True)
RES = Path('resources')
base = (RES / 'boot_tracks.bin').read_bytes()
# DS80: 80 cylinders x 2 heads x 10 x 512 = 800 KB; four reserved head-tracks,
# 4 KB allocation blocks, 128 directory entries, 3:1 sector interleave.
def build(out_name, boot, files):
    global image, nextblock, entry
    image = bytearray(b'\xe5' * 819200)
    if boot: image[:20480] = base[:20480]
    write_logical(0, b'\xe5' * 4096)
    nextblock = 1; entry = 0
    placed = {}
    for name, data in files:
        placed[name] = nextblock
        add(name, data)
    (out / out_name).write_bytes(image)
    print(out_name, 'written', hashlib.sha256(image).hexdigest()[:16])
    return placed
reverse = [4, 1, 8, 5, 2, 9, 6, 3, 10, 7]
forward = [reverse.index(i + 1) for i in range(10)]
def offset(sector):
    track, s = divmod(sector, 10)
    return 20480 + track * 5120 + forward[s] * 512
def write_logical(pos, data):
    for i, b in enumerate(data):
        sector, k = divmod(pos + i, 512); image[offset(sector) + k] = b
def read_logical(pos, n):
    return bytes(image[offset((pos + i) // 512) + (pos + i) % 512] for i in range(n))
def add(name, data):
    global nextblock, entry
    n = (len(data) + 4095) // 4096; blocks = list(range(nextblock, nextblock + n)); nextblock += n
    assert nextblock <= 196, 'disk full'
    write_logical(blocks[0] * 4096, data + b'\x1a' * ((-len(data)) % 4096))
    for k in range(0, n, 16):                      # DSM<256: sixteen 8-bit pointers, EXM=3
        chunk = blocks[k:k + 16]; size = min(len(data) - k * 4096, 65536); records = (size + 127) // 128
        e = bytearray(32); stem, ext = name.split('.')
        e[1:9] = stem.ljust(8).encode(); e[9:12] = ext.ljust(3).encode()
        extent = (k * 4096) // 16384 + (records - 1) // 128
        e[12] = extent & 31; e[14] = extent >> 5; e[15] = records - 128 * ((records - 1) // 128)
        e[16:16 + len(chunk)] = bytes(chunk); write_logical(entry * 32, e); entry += 1
    assert read_logical(blocks[0] * 4096, len(data)) == data
    print(' ', name, len(data), 'blocks', blocks[0], '-', blocks[-1])
# Disk A boots straight into the game: its CCP.SYS is our loader (src/autoboot.asm), not the
# CP/M command processor, and there is no SHELL.SYS (the Microbee shell is not used).
ccp = Path('build/CCP.SYS').read_bytes(); assert len(ccp) <= 4096 and ccp[2:4] == b'\x00\xcb'
readme = (b'BLACKOUT PROTOCOL\r\nMicrobee Premium Plus (1 MB RAM, 32 KB PCG RAM)\r\n'
          b'One disk: put BLACKOUT.DS8 in drive A and boot. The game starts by\r\n'
          b'itself (its CCP.SYS is a loader for BLACKOUT.COM; the Microbee shell\r\n'
          b'is not used). Saved games go in SAVES.DAT, so keep the disk writable.\r\n'
          b'From another CP/M boot disk you can also type BLACKOUT at A>.\r\n\x1a')
B = lambda n: Path('build/' + n).read_bytes()
# Everything on one disk (~240 KB of ~780 KB).  The game reads it all through CP/M at
# start-up; SAVES.DAT is read and written through CP/M too (src/save.asm).
placed = build('BLACKOUT.DS8', True, [('CCP.SYS', ccp), ('SAVES.DAT', bytes(4096)), ('BLACKOUT.COM', B('BLACKOUT.COM')),
      ('BLACKOUT.DAT', B('BLACKOUT.DAT')), ('BLACKOUT.OVL', B('BLACKOUT.OVL')), ('BLACKOUT.OV2', B('BLACKOUT.OV2')),
      ('WING2.DAT', B('WING2.DAT')), ('WING3.DAT', B('WING3.DAT')), ('WING4.DAT', B('WING4.DAT')),
      ('READ.ME', readme)])
