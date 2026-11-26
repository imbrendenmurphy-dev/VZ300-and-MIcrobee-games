"""Can Agent Wren reach everything?  Checks every room the generator builds (see reachlib).
python tools/reach.py      (exit status 1 if anything can't be reached)
"""
import io, contextlib, runpy, sys
sys.path.insert(0, 'tools')
import reachlib
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path('tools/gen.py')
bad = 0
for i, rm in enumerate(g['rooms']):
    pr = reachlib.check(rm, g['SOLID'], 13 if rm.wing == 4 else 9)
    print(f'{i:2d} {rm.name:16s} wing {rm.wing} ' + ('ok' if not pr else f'{len(pr)} problem(s)'))
    for p_ in pr: print('     ', p_)
    bad += len(pr)
sys.exit(1 if bad else 0)
