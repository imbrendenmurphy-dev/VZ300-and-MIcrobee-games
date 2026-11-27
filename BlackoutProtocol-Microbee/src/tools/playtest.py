"""Scripted completion run: writes test/complete.txt for ubemu.

In one game: into every shard's room (test hook dbg_goto), stand at its fitting and
search it with the real search code; at every wing's splice terminal open the puzzle
and enter the answer; then the Antechamber's right door, shaft L, the tunnel to the
core, and MERIDIAN's terminal.  Robots are put to sleep (this checks the game can be
finished, not how hard it is).

python tools/playtest.py && ubemu test/complete.txt
"""
import io, contextlib, runpy, json, sys
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path('tools/gen.py')
R, loot = g['rooms'], g['loot']
shards, splice = [], {}
for i, rm in enumerate(R):
    for (r, c), it in loot[i].items():
        if it >= 0x40: shards.append((it - 0x40, i, r, c))
    for r in range(22):
        for c in range(42):
            if rm.t[r][c] == 'splb' and rm.wing not in splice and i != 10: splice[rm.wing] = (i, r, c)
shards.sort()
TGT = [0b1010, 0b0110, 0b1011, 0b0101, 0b1110, 0b0011, 0b1101, 0b1100, 0b0111,
       0b0111, 0b1010, 0b1110, 0b0011, 0b1011, 0b0101, 0b1101, 0b1100, 0b0110]
L = ['crash', 'sym build\\game.sym'] + ['disk A: outputs\\BLACKOUT.DS8'] + \
    ['boot', 'until mus_play 4000',
     f'poke dbg_r {shards[0][1]}', 'poke dbg_side 0', 'pc dbg_room', 'until loop 900', 'fields 80']
cur = shards[0][1]
def goto(room):
    side = 0 if R[room].doors[0] is not None else 1
    return [f'poke dbg_r {room}', f'poke dbg_side {side}', 'pc dbg_goto', 'until loop 900', 'fields 80']
def stand(r, c):            # on the floor below fitting row r, column c, robots asleep
    return ['poke sleep_t $FF', 'poke sleep_t+1 $7F', 'poke wstate 0', f'poke wy {(r + 1) * 12 - 24}', f'poke wx {c * 4 - 4}', 'fields 4']
for k, room, r, c in shards:
    if room != cur: L += goto(room); cur = room
    L += [f'print SHARD {k} in {R[room].name}'] + stand(r, c) + ['down Q', 'fields 160', 'up Q', 'fields 6', 'peek shards 3']
for w in range(6):
    room, r, c = splice[w]
    L += goto(room) + [f'print SPLICE wing {w} in {R[room].name}'] + stand(r, c) + ['down Q', 'fields 6', 'up Q', 'seconds 2',
         f'poke sp_cur {TGT[3*w]}', f'poke sp_cur+1 {TGT[3*w+1]}', f'poke sp_cur+2 {TGT[3*w+2]}', 'until loop 3000', 'fields 20', 'peek keys_done 1']
ante = next(i for i, rm in enumerate(R) if rm.name == 'ANTECHAMBER')
L += ['print TO THE CORE'] + goto(ante) + ['poke sleep_t $FF', 'poke sleep_t+1 $7F', 'poke wx 140',
      f'poke wy {R[ante].doors[1] * 12 - 24}', 'fields 4', 'down P', 'untilmem gmode 1 600', 'untilmem cur_room 10 900', 'up P',
      'seconds 2', 'peek cur_room 1', 'screen test\\c_core.png 1 colour', 'poke wx 76', 'fields 4', 'down Q', 'fields 8', 'up Q',
      'seconds 6', 'screen test\\c_won.png 1 colour', 'peek keys_done 1']
open('test/complete.txt', 'w').write('\n'.join(L) + '\n')
print(f'{len(shards)} shards, {len(splice)} splice terminals, {len(L)} script lines')
