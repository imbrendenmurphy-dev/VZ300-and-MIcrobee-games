"""Build REDBACK.DS8: Microbee CP/M system tracks + the game files.
Bootable, no SHELL.SYS menu: the disk comes up at the CP/M prompt and
REDBACK.COM is started by hand."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_disk as D

ROOT = D.ROOT
B = ROOT / 'build'
sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
files = {'REDBACK.COM': (B / 'REDBACK.COM').read_bytes(),
         'REDBACK.BIN': (B / 'REDBACK.BIN').read_bytes()}
for n in ['PAIRS', 'DECK'] + sorted(p.stem for p in B.glob('SPR*.BNK')):
    files[n + '.BNK'] = (B / (n + '.BNK')).read_bytes()
files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
files['README.TXT'] = (ROOT / 'docs' / 'DISK_README.TXT').read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
assert not any(n.upper().startswith('SHELL') for n in files)
used = D.build_disk(sysdisk, files, B / 'REDBACK.DS8')
print('REDBACK.DS8: %d of 196 blocks used, %d files, %d bytes' % (used, len(files), (B / 'REDBACK.DS8').stat().st_size))
