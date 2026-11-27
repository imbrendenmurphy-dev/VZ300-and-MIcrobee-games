"""Balance bot: every room, every difficulty level, in the real game (ubemu).

Per room: arrive through a door (dbg_goto), stand still 4 s (is the door safe?),
then run for the far side, vaulting every half second, for 12 s (a hurried
player who doesn't read the robots).  Deaths are counted for each phase, and
whether Wren got out of the far door.  Falls don't depend on the level, so the
difference between levels is the robots.

python tools/balance.py            -> test/balance.txt (table) + test/balance.json
"""
import io, contextlib, runpy, json, subprocess, sys, re

with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path('tools/gen.py')
R = g['rooms']
UBEMU = r'C:\Users\Owner\Documents\Microbee\uBonPC\ubemu.exe'
#        clk_frames pen_min gun_cool grace_n fast_pat slow_hunt  (= sk_tab in save.asm)
LEVELS = {'story': [32, 3, 150, 150, 0, 1, 1, 2], 'agent': [24, 6, 90, 100, 0, 0, 0, 1], 'ghost': [17, 12, 55, 60, 1, 0, 0, 0], 'asleep': [24, 6, 90, 100, 0, 0, 0, 1]}
VARS = ['clk_frames', 'pen_min', 'gun_cool', 'grace_n', 'fast_pat', 'slow_hunt', 'hunt_off', 'hb_trim']
rooms = [i for i in range(len(R)) if i != 10]          # (not MERIDIAN's core room)


def script(level):
    L = ['crash', 'sym build\\game.sym'] + ['disk A: outputs\\BLACKOUT.DS8'] + \
        ['boot', 'until mus_play 4000', 'poke dbg_r 1', 'poke dbg_side 0',
         'pc dbg_room', 'until loop 900']
    L += [f'poke {v} {x}' for v, x in zip(VARS, LEVELS[level])]
    for i in rooms:
        side = 0 if R[i].doors[0] is not None else 1
        run = 'P' if side == 0 else 'O'
        L += [f'print ROOM {i}', 'until loop 900', 'poke clk_h 8', 'poke wstate 0', f'poke dbg_r {i}', f'poke dbg_side {side}',
              'pc dbg_goto', 'until loop 900', 'poke deaths 0'] + (['poke sleep_t $FF', 'poke sleep_t+1 $7F'] if level == 'asleep' else []) + [ f'fields {200 + int(__import__("os").environ.get("BAL_SHIFT", 0))}', 'peek deaths 1', f'down {run}']
        for _ in range(24):
            L += ['fields 19', 'down SPACE', 'fields 6', 'up SPACE']
        L += [f'up {run}', 'fields 4', 'peek deaths 1', 'peek gmode 1']
    return L


def run(level):
    open(f'test/bal_{level}.txt', 'w').write('\n'.join(script(level)) + '\n')
    out = subprocess.run([UBEMU, f'test/bal_{level}.txt'], capture_output=True, text=True).stdout
    res, cur, vals = {}, None, []
    for line in out.splitlines():
        m = re.match(r'ROOM (\d+)', line)
        if m:
            if cur is not None: res[cur] = vals
            cur, vals = int(m.group(1)), []
            continue
        m = re.match(r'(deaths|gmode) \w+: (\w\w)', line)
        if m and cur is not None: vals.append(int(m.group(2), 16))
    if cur is not None: res[cur] = vals
    return res


if __name__ == '__main__':
    levels = sys.argv[1:] or list(LEVELS)
    old = json.load(open('test/balance.json')) if len(sys.argv) > 1 else {}
    data = {lv: run(lv) for lv in levels}
    old.update(data); data = {lv: {int(k): v for k, v in d.items()} for lv, d in old.items()}; levels = list(data)
    json.dump(data, open('test/balance.json', 'w'))
    rows = [f'{"room":<18}{"wing":>4} ' + ''.join(f'{lv:>16}' for lv in levels)]
    tot = {lv: [0, 0, 0] for lv in levels}
    for i in rooms:
        cells = []
        for lv in levels:
            v = data[lv].get(i, [])
            if len(v) < 3: cells.append(f'{"?":>16}'); continue
            door, after, out = v[0], v[1], v[2]
            tot[lv][0] += door; tot[lv][1] += after - door; tot[lv][2] += out
            cells.append(f'{"door " + str(door) if door else "":>7} run {after - door}{" out" if out else "    "}')
        rows.append(f'{R[i].name:<18}{R[i].wing:>4} ' + ''.join(f'{c:>16}' for c in cells))
    rows.append('TOTAL (door deaths / run deaths / got out)  ' +
                '  '.join(f'{lv}: {t[0]}/{t[1]}/{t[2]}' for lv, t in tot.items()))
    open('test/balance.txt', 'w').write('\n'.join(rows) + '\n')
    print('\n'.join(rows))
