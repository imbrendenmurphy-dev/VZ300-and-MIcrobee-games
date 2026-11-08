"""Release screenshots: the front end and info screens (shots/pkg/info_*.png)."""
import run, sys
from shoot import press
from flow import boot_disk
OUT = '/home/claude/aot/shots/pkg/'


def snap(pp, name, mono=False):
    pp.png(OUT + name + '.png', 2, mono=mono)
    print('shot', name, pp.frames)


def until(pp, label, maxf=3000):
    r = pp.run_until(pp.S[label], maxf)
    if r is None:
        print('!! never reached', label)
    return r


def attract():
    pp = boot_disk()
    pp.run_frames(80)
    snap(pp, 'info_01_monitor')
    press(pp, 'C')
    until(pp, 'title_screen'); pp.run_frames(150); snap(pp, 'info_02_title')
    until(pp, 'how_to_play'); pp.run_frames(40); snap(pp, 'info_03_how_to_play')
    until(pp, 'meet_tour'); pp.run_frames(40); snap(pp, 'info_04_meet_the_tour')
    pp.run_frames(900); snap(pp, 'info_05_meet_the_tour_2')
    pp.run_frames(1800); snap(pp, 'info_06_meet_the_tour_3')
    until(pp, 'hiscore_screen', 12000); pp.run_frames(40); snap(pp, 'info_07_hall_of_fame')
    press(pp, 'SPACE'); pp.run_frames(60); snap(pp, 'info_08_main_menu')
    press(pp, 'DOWN'); press(pp, 'DOWN'); press(pp, 'SPACE'); pp.run_frames(60)
    for k in range(3):
        press(pp, 'RIGHT')
    press(pp, 'DOWN'); press(pp, 'DOWN')
    pp.run_frames(60)
    snap(pp, 'info_09_exhibition')


def tour():
    pp = boot_disk()
    S = pp.S
    pp.run_frames(80)
    press(pp, 'C')
    pp.run_frames(60)
    press(pp, 'SPACE'); pp.run_frames(60)
    press(pp, 'SPACE')
    until(pp, 'bracket_screen'); pp.run_frames(100); snap(pp, 'info_10_bracket')
    pp.poke(S['autoplay'], 1)
    press(pp, 'SPACE'); pp.run_frames(150); snap(pp, 'info_11_opponent')
    until(pp, 'result_screen', 60000); pp.run_frames(150); snap(pp, 'info_12_match_result')


def slam():
    pp = boot_disk()
    S = pp.S
    pp.run_frames(80)
    press(pp, 'C')
    pp.run_frames(60)
    pp.poke(S['autoplay'], 1)
    pp.poke(S['tour_saved'], 1); pp.poke(S['tour_t'], 3); pp.poke(S['tour_r'], 2)
    press(pp, 'SPACE'); pp.run_frames(60)
    press(pp, 'DOWN'); pp.run_frames(10)
    press(pp, 'SPACE')
    shot_match = False
    for t in range(3000):
        pp.poke(S['pl0'] + 14, 1)          # (for the pictures) the champion misses
        if pp.run_until(S['trophy_screen'], 20):
            pp.run_frames(200); snap(pp, 'info_13_trophy')
            break
        if not shot_match and pp.peek(S['mode']) == 1 and pp.peek(S['ball_st']) == 2:
            pass
        if t % 5 == 0:
            press(pp, 'SPACE', 2)
    while pp.peek(S['tourn']) != 4:
        pp.run_frames(10)
    pp.run_frames(300); snap(pp, 'info_14_grand_slam')
    pp.run_frames(900); snap(pp, 'info_15_grand_slam_2')
    pp.run_frames(900); snap(pp, 'info_15b_grand_slam_3')
    for t in range(400):
        if pp.run_until(S['enter_hiscore'], 20):
            pp.run_frames(100)
            for k in 'BPM':
                press(pp, k)
            pp.run_frames(30); snap(pp, 'info_16_hall_of_fame_entry')
            break


if __name__ == '__main__':
    {'attract': attract, 'tour': tour, 'slam': slam}[sys.argv[1]]()
