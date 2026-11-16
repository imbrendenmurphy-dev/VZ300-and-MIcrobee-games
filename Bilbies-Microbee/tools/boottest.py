"""End-to-end disk test: the Microbee boot ROM (bn60.rom, not included)
boots CP/M from BILBIES.DS8 in the Premium Plus model, BILBIES is typed at
the A> prompt, the loader fills the RAM blocks and starts the game; then
colour is chosen, the title runs and the first level is started."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mbee import Mbee
import run

ROOT = Path(__file__).resolve().parent.parent


def type_text(pp, text, hold=4, gap=4):
    for ch in text:
        k = 'RET' if ch == '\r' else ('SPACE' if ch == ' ' else ch)
        pp.keys = {k}
        pp.run_frames(hold)
        pp.keys = set()
        pp.run_frames(gap)


def boot(rom_path, disk=None, out=None):
    rom = Path(rom_path).read_bytes()
    disk = Path(disk) if disk else ROOT / 'build' / 'BILBIES.DS8'
    pp = Mbee(rom=rom, disk=disk.read_bytes())
    pp.run_frames(60)
    type_text(pp, 'B')                    # boot ROM menu: boot the diskette
    for i in range(100):
        pp.run_frames(10)
        if 'A>' in pp.text():
            break
    t0 = pp.frames
    print('CP/M prompt after %d frames' % t0)
    print('\n'.join(l for l in pp.text().splitlines() if l.strip()))
    if out:
        pp.png(Path(out) / 'boot_cpm.png', 1, aspect=1.83)
    type_text(pp, 'DIR\r')
    pp.run_frames(60)
    print('\n'.join(l for l in pp.text().splitlines() if l.strip()))
    type_text(pp, 'BILBIES\r')
    S = run.symbols()
    for i in range(900):
        pp.run_frames(10)
        if pp.cpu.pc >= 0x8000 and pp.crtc[1] == 64 and pp.crtc[9] == 15:
            break
    print('game took the display %.1f s after BILBIES was typed' % ((pp.frames - t0) / 50.0))
    pp.run_frames(60)
    if out:
        pp.png(Path(out) / 'boot_monitor.png', 1, aspect=1.8)
    type_text(pp, 'C')
    pp.run_frames(250)
    if out:
        pp.png(Path(out) / 'boot_title.png', 1, aspect=1.8)
    type_text(pp, ' ')
    pp.run_frames(60)
    type_text(pp, ' ')
    pp.run_frames(150)
    type_text(pp, ' ')
    pp.run_frames(400)
    pp.S = S
    print('playing level', pp.peek(S['v_lvl']) + 1, 'released', pp.peek(S['v_released']), 'pc %04X' % pp.cpu.pc)
    if out:
        pp.png(Path(out) / 'boot_game.png', 1, aspect=1.8)
    return pp


if __name__ == '__main__':
    boot(sys.argv[1], out=sys.argv[2] if len(sys.argv) > 2 else None)
