"""MICROBEE MEGADEMO: build everything into build/.  python3 tools/build.py"""
import os, sys, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'src')
BUILD = os.path.join(ROOT, 'build')
sys.path.insert(0, HERE)
os.makedirs(BUILD, exist_ok=True)
import pp


def run(script):
    subprocess.check_call([sys.executable, os.path.join(HERE, script)], cwd=ROOT)


def assemble(name='main'):
    pp.run(SRC)
    subprocess.check_call([sys.executable, os.path.join(HERE, 'zasm.py'), name + '.s',
                           '--sym=../build/%s.sym' % name], cwd=SRC)


def loader():
    names = [('STG_PROG', 'MEGA', 'BIN')]
    i = 0
    while os.path.exists(os.path.join(BUILD, 'DATA%d.BNK' % i)):
        names.append(('%d' % (4 + i), 'DATA%d' % i, 'BNK'))
        i += 1
    lines = ['\tDB %s, "%-8s%s"' % (b, n, e) for b, n, e in names]
    open(os.path.join(SRC, 'loadfiles.inc'), 'w').write('\n'.join(lines) + '\n')
    sz = os.path.getsize(os.path.join(BUILD, 'MEGA.BIN'))
    plen = (sz + 255) // 256 * 256
    assert 0x8000 + plen <= 0xE000
    open(os.path.join(SRC, 'proglen.inc'), 'w').write('PROG_LEN    EQU $%04X\n' % plen)
    subprocess.check_call([sys.executable, os.path.join(HERE, 'zasm.py'), 'loader.s',
                           '--sym=../build/loader.sym'], cwd=SRC)


if __name__ == '__main__':
    run('mkmusic.py')
    run('assets.py')
    assemble()
    sz = os.path.getsize(os.path.join(BUILD, 'MEGA.BIN'))
    print('MEGA.BIN %d bytes (8000h-%04Xh)' % (sz, 0x8000 + sz))
    loader()
    import build_disk
    build_disk.main()
