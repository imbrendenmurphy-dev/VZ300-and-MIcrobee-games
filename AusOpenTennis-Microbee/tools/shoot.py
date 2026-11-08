import run, sys
def press(pp, k, n=4):
    pp.keys = {k}; pp.run_frames(n); pp.keys = set(); pp.run_frames(4)
if __name__ == '__main__':
    pp = run.boot()
    pp.run_frames(60)
    press(pp, 'C')
    seq = sys.argv[1:]
    for i, s in enumerate(seq):
        if s.startswith('w'):
            pp.run_frames(int(s[1:]))
        elif s.startswith('s:'):
            pp.png('/home/claude/aot/shots/' + s[2:] + '.png', 2)
            print('shot', s[2:], hex(pp.cpu.pc), pp.frames)
        else:
            press(pp, s)
