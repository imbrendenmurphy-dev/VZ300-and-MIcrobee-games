"""Build build/STARHIVE.DS8: assembles the game and its CP/M loader, then
puts them on a Microbee DS80 disk with the level files and the README."""
import subprocess
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_disk

ROOT = Path(__file__).resolve().parent.parent
B = ROOT / 'build'


def asm(name, sym=None):
    cmd = [sys.executable, str(ROOT / 'tools' / 'zasm.py'), name]
    if sym:
        cmd.append('--sym=' + str(B / sym))
    r = subprocess.run(cmd, cwd=ROOT / 'src', capture_output=True, text=True)
    if r.returncode or 'error' in r.stdout:
        sys.exit(r.stdout + r.stderr)


def main():
    asm('starhive.asm', 'starhive.sym')
    asm('loader_game.asm')
    files = {'STARHIVE.COM': (B / 'STARHIVE.COM').read_bytes(),
             'STARHIVE.BIN': (B / 'STARHIVE.BIN').read_bytes()}
    for n in (B / 'game_files.txt').read_text().split():
        files[n] = (B / n).read_bytes()
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    txt = (ROOT / 'docs' / 'STARHIVE_README.TXT').read_text().replace('\r\n', '\n').replace('\n', '\r\n')
    files['README.TXT'] = txt.encode('ascii') + b'\x1a'
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    used = build_disk.build_disk(sysdisk, files, B / 'STARHIVE.DS8')
    print('STARHIVE.DS8: %d of 196 blocks used, %d files' % (used, len(files)))


if __name__ == '__main__':
    main()
