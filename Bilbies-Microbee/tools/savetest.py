"""Save tests in the model: save + reload, write protection, a disk with no
SAVE.DAT, and a damaged record. Runs save_game / load_game as subroutines
from the title screen."""
import run
from mbee import Mbee, L

S = run.symbols()
RET = S['boot_done'] + 1          # any code byte: we stop when PC gets here


def call(pp, name, max_frames=200):
    """run a subroutine as if called from where the CPU is now; the game
    carries on afterwards"""
    ret = pp.cpu.pc
    sp = (pp.cpu.sp - 2) & 0xFFFF
    pp.poke(sp, ret & 255)
    pp.poke(sp + 1, ret >> 8)
    pp.cpu.sp = sp
    pp.cpu.pc = S[name]
    return pp.run_until(ret, max_frames) is not None


def fresh(disk=None):
    pp = run.boot(mode=0)
    if disk is not None:
        L.mb_load_disk(pp.h, disk, len(disk)) if hasattr(L, 'mb_load_disk') else None
    pp.run_frames(40)          # at the monitor question, after load_game
    return pp


def state(pp):
    return dict(err=pp.peek(S['sv_error']), unlock=pp.peek(S['v_unlock']),
                mono=pp.peek(S['monomode']), snd=pp.peek(S['sfx_on']), lvl=pp.peek(S['v_lvl']))


def main():
    ok = True
    pp = fresh()
    print('fresh disk, load:', state(pp))
    for k, v in (('v_unlock', 7), ('monomode', 1), ('sfx_on', 0), ('v_lvl', 5)):
        pp.poke(S[k], v)
    r = call(pp, 'save_game')
    st = state(pp)
    print('save:', r, st)
    ok &= r and st['err'] == 0
    img = pp.disk()
    # reload from the written disk in a new machine
    pp2 = run.boot(mode=0)
    L.mb_set_disk(pp2.h, img, len(img)) if hasattr(L, 'mb_set_disk') else None
    for k in ('v_unlock', 'monomode', 'sfx_on', 'v_lvl'):
        pp2.poke(S[k], 0)
    r = call(pp2, 'load_game')
    st = state(pp2)
    print('reload:', r, st)
    ok &= st['unlock'] == 7 and st['mono'] == 1 and st['snd'] == 0 and st['lvl'] == 5
    # write protected
    L.mb_set_wp(pp2.h, 1)
    r = call(pp2, 'save_game')
    st = state(pp2)
    print('write protected save:', r, st)
    ok &= r and st['err'] == 2
    L.mb_set_wp(pp2.h, 0)
    # damaged record: defaults, no crash
    bad = bytearray(img)
    bad[OFS(26) + 13] ^= 0x55
    st = reload(bytes(bad))
    print('damaged record, load:', st)
    ok &= st['unlock'] == 1 and st['mono'] == 0 and st['snd'] == 1
    # no SAVE.DAT (entry erased): defaults; saving reports a disk error
    gone = bytearray(img)
    gone[OFS(22)] = 0xE5
    pp3 = run.boot(mode=0)
    L.mb_set_disk(pp3.h, bytes(gone), len(gone))
    call(pp3, 'load_game')
    st = state(pp3)
    print('no SAVE.DAT, load:', st)
    ok &= st['unlock'] == 1
    r = call(pp3, 'save_game')
    st = state(pp3)
    print('no SAVE.DAT, save:', r, st)
    ok &= r and st['err'] == 1 and pp3.disk() == bytes(gone)
    return pp, img, ok


def OFS(sec, track=2, side=0):
    return (track * 2 + side) * 5120 + (sec - 21) * 512


def reload(img):
    pp = run.boot(mode=0)
    L.mb_set_disk(pp.h, img, len(img))
    call(pp, 'load_game')
    return state(pp)


if __name__ == '__main__':
    print('OK' if main()[2] else 'FAILED')
