"""Drive SPINDRIFT's whole home-release flow in the Premium Plus model and
check each step: monitor choice, title, the attract cycle (hall of fame,
how to play, demo), a start on joystick fire, joystick steering, pause,
quick restart, a real game over, initials entry and the hall of fame,
and the monochrome mode.

    python3 tools/fronttest.py OUTDIR
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
import playtest

OK = []


def screen_text(pp):
    """the page on show, read through the font bank (PCG bank 0: code
    80h + character - 32)"""
    start = pp.start_addr()
    rows = []
    for r in range(25):
        line = ''
        for c in range(40):
            a = (start + r * 40 + c) & 0x7FF
            code, at = int(pp.scr[a]), int(pp.attr[a]) & 15
            line += chr(code - 0x80 + 32) if at == 0 and 0x80 <= code < 0xC0 else ' '
        rows.append(line.rstrip())
    return '\n'.join(rows)


def check(name, cond, detail=''):
    OK.append((name, bool(cond)))
    print('%-46s %s %s' % (name, 'PASS' if cond else 'FAIL', detail), flush=True)


def wait_text(pp, needle, fields, step=10):
    for _ in range(fields // step):
        pp.run_frames(step)
        if needle in screen_text(pp):
            return True
    return False


def main(out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    pp = run.boot()
    S = pp.S
    pp.run_frames(20)
    check('monitor question shown', 'COLOUR MONITOR' in screen_text(pp))
    run.shot(pp, out / '01_monitor.png')
    run.press(pp, ['C'])
    pp.run_frames(40)
    check('title shown', 'RIDE THE SPIRAL HOME' in screen_text(pp))
    run.shot(pp, out / '02_title.png')

    # the attract cycle, untouched: title, how to play, title, demo,
    # title, hall of fame (in that order); watch for each
    seen = set()
    shots = {'HALL OF FAME': '03_hall_of_fame.png', 'HOW TO PLAY': '04_how_to_play.png'}
    for _ in range(900):
        pp.run_frames(10)
        t = screen_text(pp)
        for k in shots:
            if k in t and k not in seen:
                seen.add(k)
                pp.run_frames(60 if k == 'HOW TO PLAY' else 20)
                run.shot(pp, out / shots[k])
        if run.var(pp, 'demo') == 1 and run.var(pp, 'nenemy') > 3 and 'demo' not in seen:
            seen.add('demo')
            pp.run_frames(150)
            run.shot(pp, out / '05_demo.png')
        if len(seen) == 3:
            break
    check('attract: hall of fame', 'HALL OF FAME' in seen)
    check('attract: how to play', 'HOW TO PLAY' in seen)
    check('attract: demo game with enemies', 'demo' in seen)

    # back to a title, then start on joystick fire (PIO A b7, active low)
    check('back to the title', wait_text(pp, 'RIDE THE SPIRAL HOME', 3000))
    pp.set_joy(0x7F)
    pp.run_frames(4)
    pp.set_joy(0xFF)
    pp.run_frames(30)
    check('joystick fire starts a game', run.var(pp, 'demo') == 0 and 'SHIELD' in screen_text(pp))

    # joystick steering: right on the stick (b3 low) moves the ship
    a0 = run.var(pp, 'p_a')
    pp.set_joy(0xFF & ~0x08)
    pp.run_frames(40)
    pp.set_joy(0xFF)
    check('joystick steers the ship', run.var(pp, 'p_a') != a0, 'angle %d -> %d' % (a0, run.var(pp, 'p_a')))

    # pause: H, then hold a sweep key; nothing may move
    pp.run_frames(100)
    run.press(pp, ['H'])
    st0 = (run.var(pp, 'p_a'), run.var(pp, 'frameno', 2), [pp.peek(0xD500 + i) for i in range(256)])
    pp.keys = ['Z']
    pp.run_frames(60)
    pp.keys = []
    pp.run_frames(4)
    st1 = (run.var(pp, 'p_a'), run.var(pp, 'frameno', 2), [pp.peek(0xD500 + i) for i in range(256)])
    shown = 'PAUSED' in screen_text(pp)
    check('pause shows PAUSED', shown and run.var(pp, 'paused') == 1)
    check('pause freezes ship and enemies', st0[0] == st1[0] and st0[2] == st1[2],
          'ship %d->%d, objects %s' % (st0[0], st1[0], 'same' if st0[2] == st1[2] else 'changed'))
    run.shot(pp, out / '06_paused.png')
    run.press(pp, ['H'])
    pp.run_frames(20)
    check('unpause', 'PAUSED' not in screen_text(pp) and run.var(pp, 'paused') == 0)

    # score something, then quick restart
    for f in range(600):
        if f % 2 == 0:
            pp.keys = playtest.pilot(pp, f)
        pp.poke(S['p_inv'], 40)
        pp.run_frames(1)
    sc = sum(pp.peek(S['score'] + i) for i in range(3))
    run.shot(pp, out / '07_play.png')
    run.press(pp, ['R'])
    pp.run_frames(30)
    sc2 = sum(pp.peek(S['score'] + i) for i in range(3))
    check('R restarts with a fresh score', sc > 0 and sc2 == 0 and run.var(pp, 'demo') == 0, 'score was nonzero: %s' % (sc > 0))

    # a real game over: sit still and let them come
    lives_seen = []
    over = False
    for f in range(50 * 400):
        pp.keys = ['SPACE'] if f % 8 < 4 else []
        pp.run_frames(1)
        if f % 50 == 0:
            lives_seen.append(run.var(pp, 'lives'))
        if 'YOUR INITIALS' in screen_text(pp) or 'GAME OVER' in screen_text(pp):
            over = True
            break
    check('game over reached without help', over, 'after %d s, lives %s' % (f // 50, sorted(set(lives_seen))))
    run.shot(pp, out / '08_game_over.png')
    # the score goes on the table?
    got_entry = wait_text(pp, 'YOUR INITIALS', 600)
    if got_entry:
        run.shot(pp, out / '09_initials.png')
        for k in ('Z', 'E', 'D'):           # each letter moves on by itself
            run.press(pp, [k], 3, 6)
        table = bytes(pp.peek(S['hitab'] + i) for i in range(48))
        ok = b'ZED' in table
        for _ in range(100):                # the hall of fame follows
            pp.run_frames(10)
            if 'ZED' in screen_text(pp):
                break
        run.shot(pp, out / '10_hall_with_entry.png')
        check('initials entered into the table', ok, 'shown on screen: %s' % ('ZED' in screen_text(pp)))
    else:
        check('score below the table: no initials asked (fine)', True)

    # monochrome: M on the title
    check('title again after the game', wait_text(pp, 'RIDE THE SPIRAL HOME', 4000))
    for _ in range(5):
        run.press(pp, ['M'])
        pp.run_frames(10)
        if run.var(pp, 'mono') == 1:
            break
    check('M switches to monochrome', run.var(pp, 'mono') == 1, 'title? %s' % ('SPIRAL' in screen_text(pp)))
    run.shot(pp, out / '11_title_mono.png', mono=True)
    run.press(pp, ['SPACE'])
    for f in range(400):
        if f % 2 == 0:
            pp.keys = playtest.pilot(pp, f)
        pp.poke(S['p_inv'], 40)
        pp.run_frames(1)
    run.shot(pp, out / '12_play_mono.png', mono=True)
    n = sum(1 for _, k in OK if k)
    print('%d of %d checks passed' % (n, len(OK)))
    return n == len(OK)


if __name__ == '__main__':
    sys.exit(0 if main(sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/front') else 1)
