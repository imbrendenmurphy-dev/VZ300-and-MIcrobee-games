import run, sys
from shoot import press
D = (run.BUILD / 'AUSOPEN.DS8').read_bytes()


def boot_disk(disk=D):
    import mbee
    pp = run.boot(disk=disk)
    return pp


if __name__ == '__main__':
    pp = boot_disk()
    pp.run_frames(80)
    press(pp, 'M')
    pp.run_frames(100)
    print('mono', pp.peek(pp.S['monomode']), 'sv_error', pp.peek(pp.S['sv_error']), 'fdc writes', run.L.mb_fdc_writes(pp.h) if hasattr(run, 'L') else '')
    d2 = pp.disk()
    pp2 = boot_disk(d2)
    pp2.run_frames(80)
    print('reloaded mono', pp2.peek(pp2.S['monomode']))
    pp2.png('/home/claude/aot/shots/mono1.png', 2)
    press(pp2, 'SPACE')
    pp2.run_frames(200)
    pp2.png('/home/claude/aot/shots/mono2.png', 2)
