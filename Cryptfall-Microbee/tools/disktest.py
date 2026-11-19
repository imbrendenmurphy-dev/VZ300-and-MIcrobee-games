"""Disk tests in the model, from a cold boot through the real boot ROM and
the disk's own CP/M: auto-start, caves loaded on demand, the roll and the
furthest crypt saved to a writable disk, and a write-protected disk left
alone while the game carries on.

    python3 tools/disktest.py
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_disk as BD
import hiscore
from bot import Game, Dead, peek, peekw, poke, shot
from emu import cold_boot, tap, type_text, BUILD
from mechtest import screen_text

fails = []
TMP = BUILD / 'DISKTEST.DS8'


def check(what, cond):
    print('   %s %s' % ('ok  ' if cond else 'FAIL', what))
    if not cond:
        fails.append(what)


def hi_of(img):
    return hiscore.parse(BD.read_files(bytes(img))['CRYPT.HI'])


def lose_with_score(pp_game, points):
    """give Mort a score and one life, run the clock out, wait for game over"""
    pp = pp_game.pp
    s = '%06d' % (points // 10)
    for i in range(3):
        pp.poke(pp.S['score'] + i, int(s[i * 2:i * 2 + 2], 16))
    poke(pp, 'lives', 1)
    poke(pp, 'wards', 0)
    pp.poke(pp.S['time'], 1)
    pp.poke(pp.S['time'] + 1, 0)
    pp.keys = []
    for i in range(3000):
        pp.run_frames(1)
        if 'MORT IS NO MORE' in screen_text(pp):
            return True
    return False


def wait_text(pp, text, n=1500):
    for i in range(n):
        pp.run_frames(1)
        if text in screen_text(pp):
            return True
    return False


def main():
    img0 = (BUILD / 'CRYPTFAL.DS8').read_bytes()
    print('1 cold boot, writable disk')
    pp = cold_boot()
    check('the boot ROM and CP/M bring the game up by themselves (SHELL.SYS)', int(pp.crtc[1]) == 40)
    pp.run_frames(100)
    check('the title is showing', 'PRESS SPACE' in screen_text(pp) or 'VIBED BY BPM' in screen_text(pp))
    n = peekw(pp, 'ncaves')
    check('the caves file was found (%d crypts)' % n, n > 0)
    check('nothing has been written to the disk yet', pp.fdc_writes() == 0)
    g = Game(0, pp=pp)
    check('crypt 1 came off the disk', peek(pp, 'cave_w') >= 20 and g.alive())
    g.run('!X')
    nxt = g.finish()
    check('clearing it loads crypt 2', nxt == 1)
    for i in range(300):
        pp.run_frames(1)
    h = hi_of(pp.disk())
    check('the furthest crypt reached is saved at once (record valid, furthest = 2nd)', h['valid'] and h['furthest'] == 1)
    w1 = pp.fdc_writes()
    check('...by writing sectors (%d)' % w1, w1 > 0)
    g2 = Game.__new__(Game)
    g2.pp = pp
    check('game over arrives', lose_with_score(g2, 12340))
    check('a score for the roll asks for a name', wait_text(pp, 'TYPE YOUR NAME'))
    pp.run_frames(30)
    type_text(pp, 'BPM')
    pp.run_frames(10)
    check('the name shows as typed', 'BPM' in screen_text(pp))
    tap(pp, 'RET')
    check('the roll reports it was saved', wait_text(pp, 'THE ROLL IS SAVED', 600))
    h = hi_of(pp.disk())
    check('the disk now holds BPM 12340 at the top', h['valid'] and h['table'][0][:2] == ('BPM', 12340))
    shot(pp, BUILD / 'shot_roll.png')
    TMP.write_bytes(pp.disk())

    print('2 cold boot again from the disk as it was left')
    pp = cold_boot(TMP)
    pp.run_frames(60)
    check('the saved roll is read back at start-up', bytes(pp.peek(pp.S['hibuf'] + 10 + i) for i in range(3)) == b'BPM')
    check('...and the furthest crypt, so crypt 2 can be chosen on the title', pp.peek(pp.S['hibuf'] + 8) == 1)
    tap(pp, 'UP', 4, 8)
    check('UP on the title selects crypt 2', peek(pp, 'start_cave') == 1 and 'CRYPT 02' in screen_text(pp))
    tap(pp, 'SPACE', 4, 2)
    for i in range(600):
        pp.run_frames(1)
        if peek(pp, 'p_alive') and peek(pp, 'gstate') == 1:
            break
    check('the game starts there', peek(pp, 'cave_no') == 1 and peek(pp, 'p_alive') == 1)

    print('3 cold boot, write-protected disk')
    pp = cold_boot(wp=True)
    check('the game comes up from a protected disk', int(pp.crtc[1]) == 40)
    g = Game(0, pp=pp)
    g.run('!X')
    nxt = g.finish()
    check('crypts load and the game moves on to crypt 2', nxt == 1)
    for i in range(600):
        pp.run_frames(1)
        if peek(pp, 'p_alive') and peek(pp, 'gstate') == 1:
            break
    check('...and plays normally', peek(pp, 'p_alive') == 1 and peek(pp, 'cave_no') == 1)
    g2 = Game.__new__(Game)
    g2.pp = pp
    check('game over arrives', lose_with_score(g2, 54320))
    check('the name is asked for', wait_text(pp, 'TYPE YOUR NAME'))
    pp.run_frames(30)
    type_text(pp, 'WP')
    tap(pp, 'RET')
    check('the roll says the disk is protected', wait_text(pp, 'WRITE-PROTECTED', 600))
    shot(pp, BUILD / 'shot_protected.png')
    check('not one sector was written', pp.fdc_writes() == 0 and pp.disk() == img0)
    check('the system never complained (no BIOS message on the screen)', 'DISKETTE' not in pp.text().upper())
    check('the new score is on the roll for this session', bytes(pp.peek(pp.S['hibuf'] + 10 + i) for i in range(2)) == b'WP')
    check('back to the title afterwards', wait_text(pp, 'VIBED BY BPM', 1500))

    print('all disk tests passed' if not fails else '%d FAILED: %s' % (len(fails), fails))
    return not fails


if __name__ == '__main__':
    sys.exit(0 if main() else 1)
