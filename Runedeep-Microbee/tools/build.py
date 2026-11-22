"""RUNEDEEP: build everything.   py tools/build.py [--nodata]

1. data: tiles, sprites, levels (mkdata.py), music (mkmusic.py), logo (title.py)
2. the program (src/main.asm -> build/RUNE.BIN); a JR out of range is
   turned into a JP in the source and the build tried again
3. the CP/M loader (src/loader.asm -> build/RUNEDEEP.COM)
4. the disk: build/RUNEDEEP.DS8 (and a copy in release/)
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SRC = ROOT / 'src'
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)
sys.path.insert(0, str(HERE))

# (block, name, ext) - the loader's file list
FILES = [('STG_PROG', 'RUNE', 'BIN'), (8, 'UI', 'BNK'), (9, 'TITLE', 'BNK'),
         (17, 'L1A', 'BNK'), (18, 'L1B', 'BNK'), (19, 'L2A', 'BNK'), (20, 'L2B', 'BNK'),
         (21, 'L3A', 'BNK'), (22, 'L3B', 'BNK'), (23, 'L4A', 'BNK'), (24, 'L4B', 'BNK')]


def run(cmd, cwd):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def assemble(src, sym):
    for _ in range(300):
        rc, out = run([sys.executable, str(HERE / 'zasm.py'), src, '--sym=' + sym], SRC)
        m = re.search(r'(\w+)\.asm:(\d+): relative jump out of range', out)
        if not m:
            if rc:
                print(out)
                sys.exit(rc)
            for line in out.splitlines():
                if 'program ends' in line:
                    print(line.strip())
            return
        f = SRC / (m.group(1) + '.asm')
        lines = f.read_text().split('\n')
        i = int(m.group(2)) - 1
        if 'djnz' in lines[i]:
            lines[i] = lines[i].replace('djnz', 'dec b\n        jp nz,', 1)
        else:
            assert re.search(r'\bjr\b', lines[i]), lines[i]
            lines[i] = re.sub(r'\bjr\b', 'jp', lines[i], count=1)
        print('  long jump: %s:%d %s' % (f.name, i + 1, lines[i].strip()))
        f.write_text('\n'.join(lines))
    sys.exit('too many fixes')


def main():
    if '--nodata' not in sys.argv:
        for t in ('mkdata.py', 'mkmusic.py', 'title.py'):
            subprocess.check_call([sys.executable, str(HERE / t)], cwd=HERE)
    (SRC / 'loadfiles.inc').write_text('\n'.join(
        '\tDB %s, "%-8s%s"' % (b, n, e) for b, n, e in FILES) + '\n')
    assemble('main.asm', '../build/main.sym')
    size = (BUILD / 'RUNE.BIN').stat().st_size
    plen = (size + 255) // 256 * 256
    (SRC / 'proglen.inc').write_text('PROG_LEN    EQU $%04X\n' % plen)
    print('RUNE.BIN %d bytes (8000h-%04Xh)' % (size, 0x8000 + size))
    assemble('loader.asm', '../build/loader.sym')
    import build_disk as BD
    files = {'RUNEDEEP.COM': (BUILD / 'RUNEDEEP.COM').read_bytes()}
    for b, n, e in FILES:
        files['%s.%s' % (n, e)] = (BUILD / ('%s.%s' % (n, e))).read_bytes()
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    readme = ROOT / 'docs' / 'DISK_README.TXT'
    if readme.exists():
        files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    assert not any(n.startswith('SHELL') for n in files)
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    used = BD.build_disk(sysdisk, files, BUILD / 'RUNEDEEP.DS8')
    print('RUNEDEEP.DS8: %d of 196 blocks used, %d files' % (used, len(files)))
    (ROOT / 'release').mkdir(exist_ok=True)
    shutil.copy(BUILD / 'RUNEDEEP.DS8', ROOT / 'release' / 'RUNEDEEP.DS8')


if __name__ == '__main__':
    main()
