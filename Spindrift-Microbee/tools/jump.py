"""Test helpers: jump straight to a sector's Guardian or chance stage."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run


def to_boss(sector_index=1, mono=False):
    """start a game, then skip to the end of the sector's second wave"""
    pp = run.start_game(mono)
    S = pp.S
    pp.run_frames(80)
    pp.poke(S['sector'], sector_index)
    rec = S['sec%d' % (sector_index + 1)]
    pp.poke(S['sec_ptr'], rec & 255)
    pp.poke(S['sec_ptr'] + 1, rec >> 8)
    for a in range(0xD500, 0xD800):
        pp.poke(a, 0)
    pp.poke(S['nenemy'], 0)
    pp.poke(S['attackers'], 0)
    pp.poke(S['wave_on'], 0)
    pp.poke(S['wave'], 1)
    pp.poke(S['phase'], 2)
    pp.poke(S['ph_tim'], 1)
    pp.poke(S['hud_dirty'], 255)
    return pp


def to_sector(sector_index, wave=0, mono=False):
    """start a game, then skip to a sector's wave"""
    pp = run.start_game(mono)
    S = pp.S
    pp.run_frames(10)
    pp.poke(S['sector'], sector_index)
    rec = S['sec%d' % (sector_index + 1)]
    pp.poke(S['sec_ptr'], rec & 255)
    pp.poke(S['sec_ptr'] + 1, rec >> 8)
    for a in range(0xD500, 0xD800):
        pp.poke(a, 0)
    pp.poke(S['nenemy'], 0)
    pp.poke(S['attackers'], 0)
    pp.poke(S['wave_on'], 0)
    pp.poke(S['wave'], wave)
    pp.poke(S['phase'], 0)
    pp.poke(S['ph_tim'], 1)
    pp.poke(S['hud_dirty'], 255)
    return pp
