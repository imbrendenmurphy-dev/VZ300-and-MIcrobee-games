"""Paint every crypt (tools/crypts.py), play each one in the model, and set
its quota and clock from what can really be done there.

For each crypt the bot works the contraptions (those that go wrong are left
out), then collects everything it can.  The quota is a share of that (the
crypt's `frac`), the clock twice what the bot then needs to clear the crypt
plus 45 seconds, and the winning script is kept in the cave file as its
`; solve:` line for tools/solve.py.  Results are remembered in
build/tune.json, so only crypts that changed are played again.

    python3 tools/tune.py            all
    python3 tools/tune.py 7 12       crypts 7 and 12 again
"""
import os
import sys
import json
import zlib
import glob
import math
from multiprocessing import Pool
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
DISK = os.path.join(ROOT, 'build', 'TUNE.DS8')
CACHE = os.path.join(ROOT, 'build', 'tune.json')


def play(job):
    i, script, frac = job
    from bot import Game, Dead, poke
    g = Game(i, DISK)
    poke(g.pp, 'quota', 255)
    t0 = g.time()
    try:
        g.run(script.replace(' X', ''), explore=True)
    except (Dead, RuntimeError) as e:
        return dict(ok=False, why='exploring: %s' % e)
    got = g.v('gems')
    kept = ' '.join(s for s in script.split('] ') if 0) or script
    for s in g.skipped:
        kept = kept.replace(s, '').replace('  ', ' ')
    quota = max(1, int(got * frac))
    why = ''
    for attempt in range(4):
        g2 = Game(i, DISK)
        poke(g2.pp, 'quota', quota)
        try:
            g2.run(kept)
            if g2.done():
                used = t0 - g2.time()
                return dict(ok=True, quota=quota, got=got, used=used, steps=len(g2.log), solve=kept.strip(),
                            skipped=len(g.skipped), time=int(min(990, max(100, math.ceil((used * 2 + 45) / 10) * 10))))
            why = 'not at the gate'
        except (Dead, RuntimeError) as e:
            why = str(e)
        quota = max(1, int(quota * 0.8))
    return dict(ok=False, why=why, got=got)


def main(redo=()):
    import crypts
    import caves as C
    import build_disk as BD
    cs = crypts.build_all()
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    for f in glob.glob(os.path.join(ROOT, 'caves', '*.txt')):
        os.remove(f)
    paths = []
    for i, c in enumerate(cs):
        slug = ''.join(ch if ch.isalnum() else '_' for ch in c.name.lower()).strip('_')
        while '__' in slug:
            slug = slug.replace('__', '_')
        p = os.path.join(ROOT, 'caves', '%02d_%s.txt' % (i + 1, slug))
        paths.append(p)
        open(p, 'w').write(c.text())
    C.build(quiet=True, out=os.path.join(ROOT, 'build', 'TUNECAVE.DAT'))
    BD.main(out=DISK, caves=os.path.join(ROOT, 'build', 'TUNECAVE.DAT'))
    jobs, keys = [], []
    for i, c in enumerate(cs):
        k = '%08x' % zlib.crc32((c.text() + c.solve_script() + str(c.frac)).encode())
        keys.append(k)
        if k not in cache or not cache[k].get('ok') or (i + 1) in redo:
            jobs.append((i, c.solve_script(), c.frac))
    with Pool(2) as pool:
        for (i, _, _), r in zip(jobs, pool.map(play, jobs, chunksize=1)):
            cache[keys[i]] = r
    json.dump(cache, open(CACHE, 'w'), indent=1)
    bad = 0
    for i, c in enumerate(cs):
        r = cache[keys[i]]
        if r['ok']:
            if 'time' in c.kw:
                r = dict(r, time=c.kw['time'])
            open(paths[i], 'w').write(c.text(r['quota'], r['time'], r['solve']))
            print('%2d %-24s %2dx%2d  bot got %3d, quota %3d; %3d s used, clock %3d%s' % (
                i + 1, c.name, c.w, c.h, r['got'], r['quota'], r['used'], r['time'],
                '  (%d contraptions failed)' % r['skipped'] if r['skipped'] else ''))
        else:
            bad += 1
            print('%2d %-24s FAILED: %s' % (i + 1, c.name, r))
    return bad


if __name__ == '__main__':
    sys.exit(1 if main([int(a) for a in sys.argv[1:]]) else 0)
