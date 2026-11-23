"""Start a game and jump to a level (for testing): the Warden is put on
level 1's down stairs with (level) set one short, so going down enters
the wanted level fresh. Returns a bot standing on its up stairs.

    import jump; b = jump.to(3, 'build/j')     # level index 0..3
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bot

MAP = 0xC800


def to(level, out, strong=True):
    b = bot.Bot(out)
    b.pp.run_frames(150)
    b.key('SPACE')
    b.pp.run_frames(60)
    S = b.pp.S
    if strong:
        for n, v in (('hp', 60), ('hpmax', 60), ('lvl', 6), ('atk', 12), ('def', 6), ('mp', 16), ('mpmax', 16),
                     ('sigils', 7), ('spells', 3), ('potions', 5)):
            b.pp.poke(S[n], v)
    if level == 0:
        return b
    b.pp.poke(S['level'], level - 1)
    o = MAP + (13 + 8) * 32 + 14 + 8          # level 1: (13,14), next to the stairs at (14,14)
    b.pp.poke(MAP + (14 + 8) * 32 + 13 + 8, 0)
    b.pp.poke(0xCC00 + (14 + 8) * 32 + 13 + 8, 0)
    o = MAP + (14 + 8) * 32 + 13 + 8
    b.pp.poke(S['ppos'], o & 255)
    b.pp.poke(S['ppos'] + 1, o >> 8)
    b.pp.poke(S['facing'], 1)
    b.key('UP')
    b.pp.run_frames(60)
    return b
