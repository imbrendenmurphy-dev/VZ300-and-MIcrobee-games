"""Every test, on the disk image as built: mechanics, disk and save
behaviour, each crypt's solution, and the whole campaign in one sitting."""
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
bad = 0
for t in ('mechtest.py', 'disktest.py', 'solve.py', 'playthrough.py'):
    print('==== ' + t)
    bad += subprocess.call([sys.executable, os.path.join(HERE, t)]) != 0
print('==== ALL TESTS PASSED' if not bad else '==== %d TEST PROGRAMS FAILED' % bad)
sys.exit(bad)
