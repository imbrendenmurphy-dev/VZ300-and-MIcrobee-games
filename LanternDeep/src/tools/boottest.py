"""End-to-end disk test: the real Microbee boot ROM boots CP/M from
LANTERN.DS8 in the model, LANTERN is typed at the CP/M prompt, the loader
fills the RAM banks through BDOS and starts the game."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import ppmodel
import sym

ROOT = Path(__file__).resolve().parent.parent


def boot_disk(disk=None):
    rom = (ROOT / 'resources' / 'bn60.rom').read_bytes()
    d = Path(disk) if disk else ROOT / 'build' / 'LANTERN.DS8'
    pp = ppmodel.PP(rom=rom, disk=d.read_bytes())
    pp.set_p50(0)
    pp.m.pc = 0x8000
    return pp


def type_text(pp, text, hold=4, gap=4):
    for ch in text:
        k = 'RET' if ch == '\r' else ('SPACE' if ch == ' ' else ch)
        pp.keys = {ppmodel.KEY[k]}
        pp.run_frames(hold)
        pp.keys = set()
        pp.run_frames(gap)


if __name__ == '__main__':
    S = sym.load()
    pp = boot_disk()
    pp.run_frames(60)
    type_text(pp, 'B')                     # boot ROM menu: Boot Diskette
    for i in range(80):
        pp.run_frames(10)
        t = pp.text()
        if 'A>' in t:
            break
    print('--- after boot (%d frames) ---' % (pp.frames))
    print('\n'.join(l for l in pp.text().splitlines() if l.strip())[-400:])
    type_text(pp, 'LANTERN\r')
    for i in range(400):
        pp.run_frames(10)
        if pp.m.pc < 0x8000 and pp.lower == 1 and pp.p50 in (0x07, 0x0F):
            # game is running in its home block
            pass
        t = pp.text()
        if pp.crtc[1] == 80 and pp.crtc[9] == 7:
            print('game took over the display after', pp.frames, 'frames')
            break
    print('\n'.join(l for l in pp.text().splitlines() if l.strip())[-300:]) if pp.crtc[1] != 80 else None
    pp.run_frames(20)
    pp.save_png(ROOT / 'out' / 'disk_monitor.png', 1)
    import run; run.answer(pp)
    pp.run_frames(150)
    pp.save_png(ROOT / 'out' / 'disk_boot.png', 1)
    print('pc %04X lower block %d port50 %02X' % (pp.m.pc, pp.lower, pp.p50))
    # then start a new game and walk into the next room
    import play
    play.tap(pp, 'RET', 10)
    pp.run_frames(200)
    play.go(pp, 79, 11)
    for i in range(4):
        play.hold(pp, ['RIGHT'], 4)
    pp.run_frames(60)
    pp.save_png(ROOT / 'out' / 'disk_room1.png', 1)
    print('room', pp.peek(S['cur_room']), 'pos', play.pos(pp))
