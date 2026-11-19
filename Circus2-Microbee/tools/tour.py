"""Screenshot every screen of the game into build/tour-*.png for visual review."""
from regression import *

def at(p, label, limit=600):
    assert p.run_until(S[label], limit) == S[label], (label, hex(p.m.pc))

def press(p, key, label, limit=600):
    p.keys = {KEY[key]}
    at(p, 'wait_release')
    p.keys = set()
    at(p, label, limit)

def main():
    p = new(); snap(p, 'tour-01-title.png')
    press(p, 'H', 'howto_screen.wait'); snap(p, 'tour-02-help.png')
    p = new(); press(p, 'T', 'show_scores.wait'); snap(p, 'tour-03-scores.png')
    p = new(); press(p, 'D', 'attract.wait'); snap(p, 'tour-04-difficulty.png')
    # act intro card
    p = new(); p.keys = {KEY['SPACE']}; at(p, 'wait_release'); p.keys = set()
    at(p, 'play_jingle_wait'); snap(p, 'tour-05-intro.png')
    at(p, 'play_act.loop')
    for _ in range(40): frame(p)
    snap(p, 'tour-06-play.png')
    p.keys = {KEY['P']}; at(p, 'pause_game'); p.keys = set(); at(p, 'pause_game.wait')
    snap(p, 'tour-07-pause.png')
    # act clear celebration (part way)
    p = game(0); p.m.sp = 0xee00; p.mem[0xee00:0xee02] = bytes([0, 0x7f]); p.m.pc = S['act_clear']
    p.run_frames(60); snap(p, 'tour-08-clear.png')
    # game over (part way)
    p = game(2); p.m.sp = 0xee00; p.mem[0xee00:0xee02] = bytes([0, 0x7f]); p.m.pc = S['game_over']
    p.run_frames(60); snap(p, 'tour-09-gameover.png')
    # new high score entry
    p = game(4); p.mem[S['score']:S['score'] + 3] = bytes.fromhex('020000')
    p.m.pc = S['hiscore_check']; p.m.sp = 0xee00; p.mem[0xee00:0xee02] = bytes([0, 0x7f])
    at(p, 'hiscore_check.name')
    press(p, 'J', 'hiscore_check.name'); snap(p, 'tour-10-newhigh.png')
    for act in range(9):
        p = game(act)
        for _ in range(30): frame(p)
        snap(p, f'tour-act-{act + 1}.png')
    print('tour done')

if __name__ == '__main__':
    main()
