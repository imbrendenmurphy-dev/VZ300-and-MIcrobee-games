"""SPINDRIFT: build everything.   python3 tools/build.py

1. data blocks and generated includes (tools/mkdata.py, tools/mkmusic.py,
   tools/song.py for the title music)
2. the program (src/main.asm -> build/SPIN.BIN); a JR out of range is
   turned into a JP in the source and the build tried again
3. the CP/M loader (src/loader.asm -> build/SPIN.COM)
4. the disk: build/SPINDRIFT.DS8 (and a copy in release/)
"""
import os
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

FILES = [('STG_PROG', 'SPIN', 'BIN'), (4, 'TAB', 'BNK'), (5, 'ENM', 'BNK'), (6, 'PIC', 'BNK'), (7, 'MUS', 'BNK')]


def run(cmd, cwd):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def assemble_main():
    for _ in range(200):
        rc, out = run([sys.executable, str(HERE / 'zasm.py'), 'main.asm', '--sym=../build/main.sym'], SRC)
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
        src = f.read_text().split('\n')
        i = int(m.group(2)) - 1
        if 'djnz' in src[i]:
            src[i] = src[i].replace('djnz', 'dec b\n        jp nz,', 1)
        else:
            assert re.search(r'\bjr\b', src[i]), src[i]
            src[i] = re.sub(r'\bjr\b', 'jp', src[i], count=1)
        print('  long jump: %s:%d %s' % (f.name, i + 1, src[i].strip()))
        f.write_text('\n'.join(src))
    sys.exit('too many fixes')


def main():
    subprocess.check_call([sys.executable, str(HERE / 'mkdata.py')])
    subprocess.check_call([sys.executable, str(HERE / 'mkmusic.py')])
    subprocess.check_call([sys.executable, str(HERE / 'song.py')])
    (SRC / 'loadfiles.inc').write_text('\n'.join(
        '\tDB %s, $00, "%-8s%s"' % (b, n, e) for b, n, e in FILES) + '\n')
    assemble_main()
    size = (BUILD / 'SPIN.BIN').stat().st_size
    plen = (size + 255) // 256 * 256
    (SRC / 'proglen.inc').write_text('PROG_LEN    EQU $%04X\n' % plen)
    print('SPIN.BIN %d bytes (8000h-%04Xh)' % (size, 0x8000 + size))
    rc, out = run([sys.executable, str(HERE / 'zasm.py'), 'loader.asm', '--sym=../build/loader.sym'], SRC)
    if rc:
        print(out)
        sys.exit(rc)
    import build_disk as BD
    files = {'SPIN.COM': (BUILD / 'SPIN.COM').read_bytes()}
    for b, n, e in FILES:
        files['%s.%s' % (n, e)] = (BUILD / ('%s.%s' % (n, e))).read_bytes()
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    readme = ROOT / 'docs' / 'DISK_README.TXT'
    if readme.exists():
        files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    used = BD.build_disk(sysdisk, files, BUILD / 'SPINDRIFT.DS8')
    print('SPINDRIFT.DS8: %d of 196 blocks used, %d files' % (used, len(files)))
    (ROOT / 'release').mkdir(exist_ok=True)
    shutil.copy(BUILD / 'SPINDRIFT.DS8', ROOT / 'release' / 'SPINDRIFT.DS8')


if __name__ == '__main__':
    main()
