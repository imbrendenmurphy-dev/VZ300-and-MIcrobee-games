"""Statistical profile of gameplay: sample PC every 97 T-states during autoplay."""
import bisect, collections, sys
from test_native import *
labels = sorted((v, k) for k, v in sym.items() if '.' not in k and 0x100 <= v < 0x10000)
addrs = [a for a, _ in labels]
def name(pc):
    i = bisect.bisect_right(addrs, pc) - 1
    return labels[i][1] if i >= 0 else '?'
kit = int(sys.argv[1]) if len(sys.argv) > 1 else 0
b = Bee(); b.until('title_screen.l'); b.call('dl_reset')
b.m.memory[sym['kitchen']] = kit; b.m.memory[sym['mode']] = 1; b.m.memory[sym['lives']] = 4; b.m.memory[sym['peppers']] = 6
b.m.a = kit; b.call('load_kitchen'); b.call('draw_kitchen'); b.call('setup_round'); b.call('wipe_show')
b.m.memory[sym['godmode']] = 1; b.m.memory[sym['autoplay']] = 1
for i in range(40): b.call('game_frame')
# sample
hits = collections.Counter(); total = 0
times = []
for f in range(150):
    b.m.sp = 0xEF00; b.m.memory[0xEF00:0xEF02] = bytes([0xFE, 0xEF]); b.m.pc = sym['game_frame']
    b.m.set_breakpoint(0xEFFE); t0 = b.elapsed; fr = collections.Counter()
    while True:
        b.run(ticks=97)
        n = name(b.m.pc); hits[n] += 1; total += 1; fr[n] += 1
        if b.m.pc == 0xEFFE: break
    b.m.clear_breakpoint(0xEFFE); times.append(b.elapsed - t0)
    if times[-1] > 8 * 67500:
        print('LONG frame', f, times[-1] // 67500, 'fields:', fr.most_common(6))
fh = collections.Counter(round(t / 67500) for t in times)
print('fields per displayed frame:', sorted(fh.items()), 'drops', b.peek(sym['drops']))
times.sort()
print('frame T median', times[len(times)//2], 'min', times[0], 'max', times[-1])
for k, v in hits.most_common(30):
    print(f'{100*v/total:5.1f}%  {k}')
