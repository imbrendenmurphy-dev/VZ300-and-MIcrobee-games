"""End-to-end disk test: the Microbee boot ROM (resources/rom/bn60.rom, the
user's own) boots CP/M from build/MEGA.DS8 in the Premium Plus model, MEGA
is typed at the A> prompt, the loader fills the RAM blocks and starts the
demo, colour (or mono) is chosen and the first part runs."""
import sys
import time
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


def boot(out=None, mono=False, frames=300):
    rom = (ROOT / 'resources' / 'rom' / 'bn60.rom').read_bytes()
    disk = ROOT / 'build' / 'MEGA.DS8'
    pp = Mbee(rom=rom, disk=disk.read_bytes())
    pp.run_frames(60)
    type_text(pp, 'B')
    for i in range(100):
        pp.run_frames(10)
        if 'A>' in pp.text():
            break
    t0 = pp.frames
    print('CP/M prompt after %d frames' % t0)
    type_text(pp, 'DIR\r')
    pp.run_frames(60)
    print('\n'.join(l for l in pp.text().splitlines() if l.strip()))
    type_text(pp, 'MEGA\r')
    S = run.symbols()
    for i in range(1200):
        pp.run_frames(10)
        if pp.cpu.pc >= 0x8000 and pp.cpu.pc < 0xE000 and pp.crtc[1] == 64 and pp.peek(0x8000) == 0xF3:
            if S['select_screen'] <= pp.cpu.pc < S['print']:
                break
    print('the demo took the display %.1f s after MEGA was typed' % ((pp.frames - t0) / 50.0))
    pp.run_frames(20)
    if out:
        pp.frame_png(Path(out) / 'boot_select.png')
    type_text(pp, 'M' if mono else 'C')
    pp.S = S
    pp.frame_lines()
    pp.run_to_frame(frames)
    fl = pp.frame_lines()
    bad = [x for x in fl if x != 313]
    print('%d frames: %d not 313 lines %s, overruns %d' % (len(fl), len(bad), bad[:8], pp.peek(S['overruns'])))
    if out:
        pp.frame_png(Path(out) / 'boot_part.png', mono=mono)
    return pp


if __name__ == '__main__':
    boot(out=sys.argv[1] if len(sys.argv) > 1 else None)
