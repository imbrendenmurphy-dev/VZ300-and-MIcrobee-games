"""Boot STORM.DS8 in the emulator from the disk's own boot sector, run
STORM at the A> prompt, and save pictures along the way.

    python3 tools/boottest.py [outdir]
"""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from mbee import Mbee
import bootrom

ROOT = HERE.parent


def boot(disk_path=ROOT / 'build' / 'STORM.DS8'):
    disk = Path(disk_path).read_bytes()
    pp = Mbee(disk=disk)
    assert bootrom.cold_boot(pp, disk), 'CP/M did not reach A>'
    return pp


def launch(pp, frames=400):
    bootrom.type_text(pp, 'STORM\r')
    pp.run_frames(frames)
    return pp


def shot(pp, path, mono=False):
    pp.frame_png(str(path), scale=2, mono=mono)


if __name__ == '__main__':
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / 'screenshots')
    out.mkdir(exist_ok=True)
    pp = boot()
    print(pp.text(64, 16))
    bootrom.type_text(pp, 'DIR\r')
    pp.run_frames(60)
    print(pp.text(64, 16))
    shot(pp, out / 'boot_dir.png')
    launch(pp)
    print('pc %04X' % pp.cpu.pc, pp.regs())
    shot(pp, out / 'title.png')
