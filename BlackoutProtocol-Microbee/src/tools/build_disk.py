"""Build outputs/BLACKOUT.DS80: a Microbee CP/M boot disk, double sided, 80 tracks.
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
readme = (b'BLACKOUT PROTOCOL\r\nMicrobee Premium Plus (1MB, 32K PCG RAM)\r\n'
          b'Four disks: A (boot) in drive A, B in drive B, C in drive C, D in drive D.\r\n'
          b'Disk A boots straight into the game (its CCP.SYS is a loader for\r\n'
          b'BLACKOUT.COM; the Microbee shell is not used). From another CP/M\r\n'
          b'boot disk you can also type BLACKOUT at the A> prompt.\r\n\x1a')
placed = build('BA.DS8', True, [('CCP.SYS', ccp), ('SAVES.DAT', bytes(4096)), ('BLACKOUT.COM', Path('build/BLACKOUT.COM').read_bytes()),
      ('BLACKOUT.DAT', Path('build/BLACKOUT.DAT').read_bytes()),
      ('BLACKOUT.OVL', Path('build/BLACKOUT.OVL').read_bytes()), ('BLACKOUT.OV2', Path('build/BLACKOUT.OV2').read_bytes()),
      ('READ.ME', readme)])
assert placed['SAVES.DAT'] == 2       # the game reads and writes it at data-area logical sectors 16..19
# BT.DS8: a test boot disk with the ordinary A> prompt (the real CCP.SYS), FDCTEST.COM, and
# the game, which you can still run by typing BLACKOUT.  Put it in drive A instead of BA.
real_ccp = (RES / 'CCP.SYS').read_bytes(); assert len(real_ccp) == 2432
placed = build('BT.DS8', True, [('CCP.SYS', real_ccp), ('SAVES.DAT', bytes(4096)), ('BLACKOUT.COM', Path('build/BLACKOUT.COM').read_bytes()),
      ('BLACKOUT.DAT', Path('build/BLACKOUT.DAT').read_bytes()),
      ('BLACKOUT.OVL', Path('build/BLACKOUT.OVL').read_bytes()), ('BLACKOUT.OV2', Path('build/BLACKOUT.OV2').read_bytes()),
      ('FDCTEST.COM', Path('build/FDCTEST.COM').read_bytes()),
      ('READ.ME', b'BLACKOUT PROTOCOL test disk: boots to A>.  Try DIR B:, DIR C:, DIR D:,\r\n'
                  b'then FDCTEST, then BLACKOUT.\r\n\x1a')])
assert placed['SAVES.DAT'] == 2
for letter, fname in (('B', 'WING2.DAT'), ('C', 'WING3.DAT'), ('D', 'WING4.DAT')):
    placed = build(f'B{letter}.DS8', False, [(fname, Path('build/' + fname).read_bytes()),
                   ('READ.ME', b'BLACKOUT PROTOCOL - data disk ' + letter.encode() + b'\r\n\x1a')])
    assert placed[fname] == 1      # the game reads it from data-area logical sector 8
