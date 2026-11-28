"""Play every level by its original solution script in the model; report wins."""
import sys, json
import run
from concurrent.futures import ProcessPoolExecutor

def one(i, mono=False):
    pp = run.boot(i, mono)
    S = pp.S
    for t in range(400):
        pp.run_frames(100)
        if pp.peek(S['boot_done']):
            break
    r = dict(level=i, saved=pp.peek(S['v_saved']), need=pp.peek(S['v_tosave']), n=pp.peek(S['v_ncrt']),
             lost=pp.peek(S['v_lost']), ticks=pp.peekw(S['v_gtick']), fields=pp.frames, ended=bool(pp.peek(S['v_end'])))
    r['win'] = r['ended'] and r['saved'] >= r['need']
    pp.png('/tmp/claude-0/lv%02d.png' % i, 1, aspect=1.8)
    return r

if __name__ == '__main__':
    lv = [int(a) for a in sys.argv[1:]] or list(range(24))
    with ProcessPoolExecutor(8) as ex:
        res = list(ex.map(one, lv))
    for r in res:
        print('%2d %-5s saved %2d/%2d need %2d lost %2d ticks %4d fields %5d %.2f f/tick' % (
            r['level'], 'WIN' if r['win'] else 'FAIL', r['saved'], r['n'], r['need'], r['lost'], r['ticks'], r['fields'], r['fields'] / max(1, r['ticks'])))
    print('wins: %d of %d' % (sum(r['win'] for r in res), len(res)))
    json.dump(res, open('/tmp/claude-0/levels.json', 'w'))
