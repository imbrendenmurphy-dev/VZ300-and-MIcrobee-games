"""End-to-end disk test in the Premium Plus model: the Microbee boot ROM boots CP/M
from RUNEAMOK.DS8, RUNEAMOK is typed at the A> prompt, the loader fills the RAM blocks
and starts the game; the craft is flown, then ESC must give back the CP/M prompt."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mbee import Mbee

ROOT = Path(__file__).resolve().parent.parent


def type_text(pp, text, hold=4, gap=4):
    for ch in text:
        k = 'RET' if ch == '\r' else ('SPACE' if ch == ' ' else ch)
        pp.keys = {k}
        pp.run_frames(hold)
        pp.keys = set()
        pp.run_frames(gap)


def show(pp):
    print('\n'.join(l for l in pp.text().splitlines() if l.strip()))


def boot(rom_path, disk=None, out=None):
    rom = Path(rom_path).read_bytes()
    disk = Path(disk) if disk else ROOT / 'build' / 'RUNEAMOK.DS8'
    pp = Mbee(rom=rom, disk=disk.read_bytes())
    pp.run_frames(60)
    type_text(pp, 'B')
    for i in range(100):
        pp.run_frames(10)
        if 'A>' in pp.text():
            break
    t0 = pp.frames
    print('CP/M prompt after %d frames' % t0)
    show(pp)
    type_text(pp, 'DIR\r')
    pp.run_frames(60)
    show(pp)
    before = pp.text()
    type_text(pp, 'RUNEAMOK\r')
    for i in range(1500):
        pp.run_frames(10)
        if pp.cpu.pc >= 0x8000 and pp.crtc[1] == 40:
            break
    print('game took the display %.1f s after RUNEAMOK was typed (pc %04X, crtc R1 %d)' % ((pp.frames - t0) / 50.0, pp.cpu.pc, pp.crtc[1]))
    pp.run_frames(100)
    if out:
        pp.png(Path(out) / 'boot_game.png', 1, aspect=1.83)
    type_text(pp, ' ')                       # past the title
    pp.run_frames(120)
    if out:
        pp.png(Path(out) / 'boot_play.png', 1, aspect=1.83)
    pp.keys = {'UP'}
    pp.run_frames(6)
    pp.keys = set()
    pp.run_frames(30)
    if out:
        pp.png(Path(out) / 'boot_game2.png', 1, aspect=1.83)
    print('flying: pc %04X' % pp.cpu.pc)
    pp.keys = {'ESC'}
    pp.run_frames(8)
    pp.keys = set()
    pp.run_frames(30)
    type_text(pp, 'Y')
    for i in range(100):
        pp.run_frames(10)
        if 'A>' in pp.text() and pp.crtc[1] == 80:
            break
    print('after ESC: crtc R1 = %d, pc %04X' % (pp.crtc[1], pp.cpu.pc))
    show(pp)
    if out:
        pp.png(Path(out) / 'boot_exit.png', 1, aspect=1.83)
    type_text(pp, 'DIR\r')
    pp.run_frames(60)
    show(pp)
    return pp


if __name__ == '__main__':
    boot(sys.argv[1], out=sys.argv[2] if len(sys.argv) > 2 else None)
