import run, sym, ppmodel, play
S = sym.load()
def warp(room, x, y, items=0, pp=None, dirn=3):
    if pp is None:
        pp = run.boot()
        pp.run_frames(300)
    pp.write(S['ck_valid'], 1); pp.write(S['ck_room'], room)
    pp.write(S['ck_xy'], y); pp.write(S['ck_xy'] + 1, x); pp.write(S['ck_dir'], dirn)
    pp.write(S['items'], items)
    play.tap(pp, 'DOWN', 6)
    play.tap(pp, 'RET', 10)
    pp.run_frames(200)
    return pp
