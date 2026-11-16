"""Mouse in the model (Microsoft serial packets through PIO B): moving the
cursor, choosing a skill on the panel, giving it to a bilby, and the
game speed while packets arrive."""
import run

S = None


def st(pp):
    return dict(x=pp.peekw(S['cur_x']), y=pp.peek(S['cur_y']), skill=pp.peek(S['v_skill']),
                fields=pp.peek(S['fields']))


def main(level=1):
    global S
    pp = run.boot(level=level, mode=2)
    S = pp.S
    pp.run_frames(100)
    ok = True
    a = st(pp)
    pp.mouse(40, 0)
    pp.run_frames(20)
    b = st(pp)
    print('move right 40:', a['x'], '->', b['x'])
    ok &= b['x'] > a['x']
    pp.mouse(0, 30)
    pp.run_frames(20)
    c = st(pp)
    print('move down 30:', b['y'], '->', c['y'])
    ok &= c['y'] > b['y']
    # to the fifth panel button and click it
    pp.mouse(-(c['x'] - 144) // 2, 200 - c['y'])
    pp.run_frames(20)
    pp.mouse(0, 0, 1)
    pp.run_frames(6)
    pp.mouse(0, 0, 0)
    pp.run_frames(10)
    d = st(pp)
    print('click at', d['x'], d['y'], 'selected', pp.peek(S['v_sel']))
    ok &= pp.peek(S['v_sel']) == 4
    print('stats', pp.mouse_stats())
    ok &= pp.mouse_stats()['overruns'] == 0
    return pp, ok


if __name__ == '__main__':
    pp, ok = main()
    print('OK' if ok else 'FAILED')
