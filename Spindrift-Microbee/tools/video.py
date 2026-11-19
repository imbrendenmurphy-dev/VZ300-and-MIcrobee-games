"""Videos with sound from the Premium Plus model: the picture at 25 frames
a second, the speaker rendered by tools/audio.py, joined by ffmpeg.

    python3 tools/video.py title OUT.mp4 [seconds]    the title and its music
    python3 tools/video.py play OUT.mp4 [seconds]     a game, flown by the pilot
"""
import subprocess
import sys
import tempfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
import audio
import playtest


def record(pp, seconds, step, path):
    tmp = Path(tempfile.mkdtemp(dir='/tmp/claude-0'))
    pp.speaker(clear=True)
    t0 = pp.tick
    for f in range(int(seconds * 25)):
        step(pp, f)
        run.view(pp).save(tmp / ('f%05d.png' % f))
    audio.wav(pp, tmp / 'a.wav', t0, pp.tick)
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '25', '-i', str(tmp / 'f%05d.png'),
                           '-i', str(tmp / 'a.wav'), '-vf', 'scale=984:-2:flags=neighbor',
                           '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-c:a', 'aac', '-b:a', '160k',
                           '-shortest', str(path)])
    print('saved', path)


def title_step(pp, f):
    pp.poke(pp.S['scr_tim'], 0xFF)          # hold the title: no attract cycle
    pp.poke(pp.S['scr_tim'] + 1, 0x7F)
    pp.run_frames(2)


def play_step(pp, f):
    pp.keys = playtest.pilot(pp, f)
    pp.poke(pp.S['p_inv'], 40)
    pp.run_frames(2)


if __name__ == '__main__':
    kind, out = sys.argv[1], sys.argv[2]
    secs = float(sys.argv[3]) if len(sys.argv) > 3 else 30
    if kind == 'title':
        record(run.to_title(), secs, title_step, out)
    else:
        record(run.start_game(), secs, play_step, out)
