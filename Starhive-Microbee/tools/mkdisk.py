"""Build build/SCRLTEST.DS8 (DS80, CP/M, no shell) and check it reads back."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_disk import build_disk, unskew, read_dir
ROOT = Path(__file__).resolve().parent.parent
B = ROOT / 'build'
sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
files = {'SCRLTEST.COM': (B / 'SCRLTEST.COM').read_bytes(), 'SCRLTEST.BIN': (B / 'SCRLTEST.BIN').read_bytes(),
         'WORK.BNK': (B / 'WORK.BNK').read_bytes(), 'LEVEL1.BNK': (B / 'LEVEL1.BNK').read_bytes(),
         'CCP.SYS': (ROOT / 'resources' / 'CCP.SYS').read_bytes(),
         'README.TXT': (ROOT / 'docs' / 'SCRLTEST_README.TXT').read_text().replace('\n', '\r\n').encode('ascii') + b'\x1a'}
used = build_disk(sysdisk, files, B / 'SCRLTEST.DS8')
d = read_dir(unskew((B / 'SCRLTEST.DS8').read_bytes()))
for n, data in files.items():
    assert d[n][:len(data)] == data, n
print('SCRLTEST.DS8: %d blocks, %d files, verified' % (used, len(files)))
