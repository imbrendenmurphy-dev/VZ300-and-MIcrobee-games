"""Mechanics tests: small test caves (tests/caves) on their own disk image,
played by script in the model, with the cave checked after each move.

    python3 tools/mechtest.py
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import caves as C
import build_disk as BD
from bot import Game, Dead, T, shot, peek, peekw, poke
from emu import cold_boot, tap, ROOT, BUILD

DISK = BUILD / 'TEST.DS8'
fails = []
GHOSTS = [T['GHOST'] + i for i in range(4)]
BATS = [T['BAT'] + i for i in range(4)]
KNIGHTS = [T['KNIGHT'] + i for i in range(4)]


def check(what, cond):
    print('   %s %s' % ('ok  ' if cond else 'FAIL', what))
    if not cond:
        fails.append(what)


def count(g, *tiles):
    return sum(t in tiles for r in g.grid() for t in r)


def screen_text(pp):
    start = pp.start_addr()
    out = []
    for r in range(25):
        line = ''
        for c in range(40):
            v = int(pp.scr[(start + r * 40 + c) & 0x7FF])
            line += chr(v - 0x80 + 32) if 0x80 <= v < 0xC0 else '?'
        out.append(line)
    return '\n'.join(out)


def main():
    C.MINW, C.MINH = 5, 5
    C.build(quiet=True, src=str(ROOT / 'tests' / 'caves'), out=str(BUILD / 'TESTCAVE.DAT'))
    BD.main(out=DISK, caves=BUILD / 'TESTCAVE.DAT')

    print('1 falling, rolling, pushing')
    g = Game(0, DISK)
    g.run('w12')
    G = g.grid()
    check('a stone over empty space falls to the floor', G[8][2] == T['BOULDER'] and G[2][2] == 0)
    check('a gem on a stone rolls off the free side and falls', G[8][15] == T['GEM'])
    check('a stone on earth stays put', G[2][5] == T['BOULDER'])
    g.run('R3D2R')
    check('a stone rests on Mort while he is under it', g.grid()[2][5] == T['BOULDER'] and g.pos() == (5, 3))
    g.run('Rw8')
    check('...and falls once he has stepped out', g.grid()[8][5] == T['BOULDER'])
    g.run('D3L2')
    g.run('L')
    check('leaning on a stone for one step does not move it', g.pos() == (4, 6) and g.grid()[6][3] == T['BOULDER'])
    g.run('L')
    check('the second step pushes it', g.pos() == (3, 6))
    g.run('w6')
    check('the pushed stone falls and comes to rest on the one below', g.grid()[7][2] == T['BOULDER'])

    print('2 ghosts, bats and knights under a falling stone')
    g = Game(1, DISK)
    g.run('@4,3 r L w7')
    G = g.grid()
    check('a stone on a ghost: a 3 x 3 blast that leaves nothing', count(g, *GHOSTS) == 0 and G[5][5] == 0 and G[4][4] == 0 and G[4][6] == 0)
    check('Mort stepped clear and lives, ward unused', g.alive() and g.v('wards') == 1)
    g.run('@10,3 r L w16')
    check('a stone on a bat: nine gems', count(g, T['GEM'], T['GEMF']) == 9 and count(g, *BATS) == 0)
    g.run('@16,3 r L w7')
    G = g.grid()
    check('a stone on a knight: blast', count(g, *KNIGHTS) == 0 and G[5][17] == 0)
    check('the steel border survives a blast', G[5][19] == T['STEEL1'])
    g.run('!')
    check('nine gems collected opens the gate', g.v('exit_open') == 1 and count(g, T['EXITO']) == 1)
    g.run('X')
    check('walking into the gate clears the crypt', g.done())

    print('3 powder kegs and cracked walls')
    g = Game(2, DISK)
    g.run('D2 r U2 w8')
    G = g.grid()
    check('a keg dropped on kegs: the chain of blasts breaks the brick', G[6][2] == 0 and G[5][4] == 0 and G[5][2] == 0)
    check('steel is not broken', G[6][6] == T['STEEL1'])
    check('Mort is clear of the chain', g.alive())
    g.run('@7,2 r w10')
    check('a falling stone breaks a cracked wall', g.grid()[4][8] != T['CRACKED'])
    g.run('@12,5 r w6')
    G = g.grid()
    check('a falling gem does not (it rolls off)', G[6][13] == T['CRACKED'] and count(g, T['GEM'], T['GEMF']) == 4)
    g.run('@2,8 @3,8')
    check('the gems behind the broken wall can be taken', g.v('gems') >= 2 and g.v('exit_open') == 1)

    print('4 the grate, slime, doors and charms')
    g = Game(3, DISK)
    g.run('w3')
    check('slime with nowhere to grow turns to gems', count(g, T['GEM']) == 6 and count(g, T['SLIME']) == 0)
    g.run('@3,2 r w9')
    check('a stone through the grate comes out a gem', g.grid()[8][4] == T['GEM'] and count(g, T['BOULDER']) == 1)
    g.run('@10,6 R R')
    check('a locked door stops Mort', g.pos() == (10, 6))
    t0 = g.time()
    g.run('@18,1')
    check('he picks up the key', g.v('keys_n') == 1)
    s0 = g.score()
    g.run('@10,6 R R')
    check('the key opens the door (and is used up)', g.pos() == (12, 6) and g.v('keys_n') == 0)
    check('the chalice is worth 500', g.score() - s0 == 500 and g.v('treasures') == 1)
    g.run('@8,7')
    check('a ward is added', g.v('wards') == 2)
    t1 = g.time()
    g.run('@9,7')
    check('the hourglass gives 20 seconds', 18 <= g.time() - t1 <= 20)
    g.run('@11,7')
    check('a heart gives a life', g.v('lives') == 6)

    print('5 the ward, the clock, lives and game over')
    g = Game(4, DISK)
    check('with nothing to collect the gate is open from the start', g.v('exit_open') == 1)
    g.run('R4')
    for i in range(12):
        if g.v('wards') == 0:
            break
        g.step('w')
    check('a ghost touching Mort is popped by his ward', g.v('wards') == 0 and g.alive() and count(g, *GHOSTS) == 0)
    died = False
    try:
        g.run('w140')
    except Dead:
        died = True
    check('when the clock runs out Mort dies', died and g.time() == 0)
    pp = g.pp
    for i in range(400):
        pp.run_frames(1)
        if peek(pp, 'lives') == 4 and peek(pp, 'p_alive'):
            break
    check('a life is lost and the crypt starts again', peek(pp, 'lives') == 4 and peekw(pp, 'time') > 8)
    check('...with a fresh ward', peek(pp, 'wards') == 1)
    poke(pp, 'lives', 1)
    for i in range(1500):
        pp.run_frames(1)
        if 'MORT IS NO MORE' in screen_text(pp):
            break
    check('the last life lost ends the game', 'MORT IS NO MORE' in screen_text(pp))

    print('6 slabs, urns, jewels, the crown, the skull and giving up')
    g = Game(5, DISK)
    g.run('w6')
    G = g.grid()
    check('a slab on a stone does not roll off', G[2][9] == T['SLAB'] and G[3][9] == T['BOULDER'])
    check('a stone on a slab does not roll off', G[2][12] == T['BOULDER'] and G[3][12] == T['SLAB'])
    check('a fallen urn breaks open on a gem', G[3][6] == T['GEM'] and count(g, T['URN'], T['URNF']) == 0)
    d0 = abs(g.find(T['SKULL'])[0][0] - g.pos()[0]) + abs(g.find(T['SKULL'])[0][1] - g.pos()[1])
    g.run('@2,3 r w16')
    G = g.grid()
    check('a falling slab breaks a cracked wall and goes on down', G[6][3] == 0 and T['SLAB'] in [G[y][3] for y in range(7, 9)])
    sk = g.find(T['SKULL'])[0]
    check('the skull has come nearer', abs(sk[0] - g.pos()[0]) + abs(sk[1] - g.pos()[1]) < d0)
    g.run('@6,3')
    n = g.v('gems'); s0 = g.score()
    g.run('@14,1 D')
    check('a ruby counts as two gems', g.v('gems') == n + 2 and g.score() - s0 == 20)
    g.run('U @16,1 D')
    check('an emerald counts as three', g.v('gems') == n + 5 and g.score() - s0 == 50)
    s0 = g.score()
    g.run('U @18,1 D')
    check('the crown is worth 1000', g.score() - s0 == 1000)
    pp = g.pp
    lives = peek(pp, 'lives')
    tap(pp, 'R', 4, 4)
    tap(pp, 'R', 4, 4)
    seen = set()
    for i in range(500):
        pp.run_frames(1)
        txt = screen_text(pp)
        for k in ('3', '2', '1'):
            if 'IN %s' % k in txt:
                seen.add(k)
        if peek(pp, 'p_dead'):
            break
    check('R twice counts down 3, 2, 1', seen == {'3', '2', '1'})
    jew = count(g, T['GEXPL1'], T['GEXPL2'], T['GEXPL3'])
    for i in range(12):
        pp.run_frames(1)
        jew = max(jew, count(g, T['GEXPL1'], T['GEXPL2'], T['GEXPL3']))
    check('...and Mort goes up in jewels', peek(pp, 'p_dead') and jew >= 4)
    for i in range(600):
        pp.run_frames(1)
        if peek(pp, 'p_alive') and not peek(pp, 'p_dead'):
            break
    check('the crypt starts again and no life is lost', peek(pp, 'p_alive') and peek(pp, 'lives') == lives)

    print('all mechanics tests passed' if not fails else '%d FAILED: %s' % (len(fails), fails))
    return not fails


if __name__ == '__main__':
    sys.exit(0 if main() else 1)
